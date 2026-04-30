//! FFI functions for client-side Ark off-chain send building.
//!
//! Replicates the logic from `ark/src/client/send.rs` (SendSession) but
//! without async dependencies, suitable for FFI from Dart.

use std::collections::HashMap;
use std::str::FromStr;
use std::sync::Mutex;

use ark_core::send::{self, OffchainTransactions, VtxoInput};
use ark_core::server;

use bitcoin::base64::{self, Engine};
use bitcoin::hashes::Hash;
use bitcoin::key::Secp256k1;
use bitcoin::sighash::{Prevouts, SighashCache};
use bitcoin::taproot::{self};
use bitcoin::{
    Amount, Network, OutPoint, Psbt, ScriptBuf, TapLeafHash, TapSighashType, TxOut,
    XOnlyPublicKey,
};

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
pub struct BuildSendParams {
    pub owner_pk: String,
    pub vtxo_inputs: Vec<VtxoInputParam>,
    pub recipient_ark_address: String,
    pub amount: u64,
    pub change_ark_address: Option<String>,
    pub exit_delay: u32,
    pub ark_info: ArkInfoParam,
}

#[derive(Deserialize)]
pub struct VtxoInputParam {
    pub txid: String,
    pub vout: u32,
    pub amount: u64,
}

#[derive(Deserialize)]
pub struct ArkInfoParam {
    pub signer_pubkey: String,
    pub forfeit_pubkey: String,
    pub forfeit_address: String,
    pub checkpoint_tapscript: String,
    pub network: String,
    pub session_duration: i64,
    pub unilateral_exit_delay: i64,
    pub boarding_exit_delay: i64,
    pub vtxo_min_amount: i64,
    pub dust: i64,
}

#[derive(Serialize)]
pub struct BuildSendResult {
    pub handle: u64,
    pub sighashes: Vec<String>,
    pub ark_tx_bytes: String,
}

#[derive(Serialize)]
pub struct InsertSigsResult {
    pub signed_ark_tx_b64: String,
    pub signed_checkpoint_txs_b64: Vec<String>,
}

#[derive(Serialize)]
pub struct ChangeVtxoResult {
    pub txid: String,
    pub vout: u32,
    pub amount: u64,
}

enum SighashTarget {
    ArkTx(usize),
    Checkpoint(usize),
}

struct SighashEntry {
    target: SighashTarget,
    leaf_hash: TapLeafHash,
}

pub struct SendState {
    owner_pk: XOnlyPublicKey,
    ark_tx: Psbt,
    checkpoint_txs: Vec<Psbt>,
    sighash_entries: Vec<SighashEntry>,
}

// ---------------------------------------------------------------------------
// Global session store
// ---------------------------------------------------------------------------

static SESSIONS: Mutex<Option<HashMap<u64, SendState>>> = Mutex::new(None);
static NEXT_HANDLE: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);

fn get_sessions() -> std::sync::MutexGuard<'static, Option<HashMap<u64, SendState>>> {
    let mut guard = SESSIONS.lock().unwrap();
    if guard.is_none() {
        *guard = Some(HashMap::new());
    }
    guard
}

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------

pub fn build_send_tx(params_json: &str) -> Result<String, String> {
    let params: BuildSendParams =
        serde_json::from_str(params_json).map_err(|e| format!("JSON parse: {e}"))?;

    let secp = Secp256k1::new();
    let network = parse_network(&params.ark_info.network)?;
    let owner_pk = parse_xonly(&params.owner_pk)?;
    let asp_pk = parse_xonly(&params.ark_info.signer_pubkey)?;

    let exit_seq = server::parse_sequence_number(params.exit_delay as i64)
        .map_err(|e| format!("invalid exit_delay: {e}"))?;
    eprintln!("[ark-ffi] exit_delay={}, exit_seq={}, is_time={:?}",
        params.exit_delay, exit_seq.0, exit_seq.to_relative_lock_time());

    // Reconstruct VTXO for spend info
    let vtxo = ark_core::Vtxo::new_default(&secp, asp_pk, owner_pk, exit_seq, network)
        .map_err(|e| format!("Vtxo::new_default: {e}"))?;
    let (spend_script, control_block) = vtxo
        .forfeit_spend_info()
        .map_err(|e| format!("forfeit_spend_info: {e}"))?;
    let tapscripts = vtxo.tapscripts();
    let vtxo_script_pubkey = vtxo.script_pubkey();

    // Build VtxoInputs
    let send_inputs: Vec<VtxoInput> = params
        .vtxo_inputs
        .iter()
        .map(|vi| {
            let outpoint = OutPoint {
                txid: vi.txid.parse().map_err(|e| format!("invalid txid: {e}"))?,
                vout: vi.vout,
            };
            Ok(VtxoInput::new(
                spend_script.clone(),
                None,
                control_block.clone(),
                tapscripts.clone(),
                vtxo_script_pubkey.clone(),
                Amount::from_sat(vi.amount),
                outpoint,
            ))
        })
        .collect::<Result<Vec<_>, String>>()?;

    // Parse addresses
    let recipient: ark_core::ArkAddress = params
        .recipient_ark_address
        .parse()
        .map_err(|e| format!("invalid recipient: {e}"))?;
    let outputs = vec![(&recipient, Amount::from_sat(params.amount))];

    let change_addr: Option<ark_core::ArkAddress> = params
        .change_ark_address
        .as_deref()
        .map(|a| a.parse().map_err(|e| format!("invalid change addr: {e}")))
        .transpose()?;
    let change_ref = change_addr.as_ref();

    // Build server::Info
    let server_info = build_server_info(&params.ark_info, network)?;

    // Build transactions
    let OffchainTransactions {
        ark_tx,
        checkpoint_txs,
    } = send::build_offchain_transactions(&outputs, change_ref, &send_inputs, &server_info)
        .map_err(|e| format!("build_offchain_transactions: {e}"))?;

    // Compute sighashes
    let mut sighashes = Vec::new();
    let mut sighash_entries = Vec::new();

    collect_ark_tx_sighashes(&ark_tx, &mut sighashes, &mut sighash_entries)?;
    for (ci, cp_psbt) in checkpoint_txs.iter().enumerate() {
        collect_checkpoint_sighash(cp_psbt, ci, &mut sighashes, &mut sighash_entries)?;
    }

    // Serialize ark_tx as raw bytes (hex) for fullTransaction passthrough
    let ark_tx_bytes_hex = hex_encode(&ark_tx.serialize());

    // Store session
    let handle = NEXT_HANDLE.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let state = SendState {
        owner_pk,
        ark_tx,
        checkpoint_txs,
        sighash_entries,
    };
    get_sessions().as_mut().unwrap().insert(handle, state);

    let result = BuildSendResult {
        handle,
        sighashes: sighashes.iter().map(|s| hex_encode(s)).collect(),
        ark_tx_bytes: ark_tx_bytes_hex,
    };
    serde_json::to_string(&result).map_err(|e| format!("JSON serialize: {e}"))
}

// ---------------------------------------------------------------------------
// Insert signatures
// ---------------------------------------------------------------------------

pub fn insert_send_signatures(handle: u64, signatures_json: &str) -> Result<String, String> {
    let sig_hexes: Vec<String> =
        serde_json::from_str(signatures_json).map_err(|e| format!("JSON parse: {e}"))?;

    let mut sessions = get_sessions();
    let state = sessions
        .as_mut()
        .unwrap()
        .get_mut(&handle)
        .ok_or("invalid session handle")?;

    if sig_hexes.len() != state.sighash_entries.len() {
        return Err(format!(
            "expected {} sigs, got {}",
            state.sighash_entries.len(),
            sig_hexes.len()
        ));
    }

    // Parse and insert signatures
    for (hex_sig, entry) in sig_hexes.iter().zip(state.sighash_entries.iter()) {
        let sig_bytes = hex_decode(hex_sig)?;
        if sig_bytes.len() != 64 {
            return Err(format!("expected 64-byte sig, got {}", sig_bytes.len()));
        }
        let schnorr_sig = bitcoin::secp256k1::schnorr::Signature::from_slice(&sig_bytes)
            .map_err(|e| format!("invalid schnorr sig: {e}"))?;

        let sig = taproot::Signature {
            signature: schnorr_sig,
            sighash_type: TapSighashType::Default,
        };

        match &entry.target {
            SighashTarget::ArkTx(input_idx) => {
                if *input_idx >= state.ark_tx.inputs.len() {
                    return Err(format!("ark tx input index {} out of bounds (len={})", input_idx, state.ark_tx.inputs.len()));
                }
                state.ark_tx.inputs[*input_idx].tap_script_sigs
                    .insert((state.owner_pk, entry.leaf_hash), sig);
            }
            SighashTarget::Checkpoint(cp_idx) => {
                if *cp_idx >= state.checkpoint_txs.len() {
                    return Err(format!("checkpoint index {} out of bounds (len={})", cp_idx, state.checkpoint_txs.len()));
                }
                if state.checkpoint_txs[*cp_idx].inputs.is_empty() {
                    return Err(format!("checkpoint {} has no inputs", cp_idx));
                }
                state.checkpoint_txs[*cp_idx].inputs[0].tap_script_sigs
                    .insert((state.owner_pk, entry.leaf_hash), sig);
            }
        }
    }

    // Encode results as base64
    let b64 = base64::engine::general_purpose::STANDARD;
    let signed_ark_tx_b64 = b64.encode(state.ark_tx.serialize());
    let signed_checkpoint_txs_b64: Vec<String> = state
        .checkpoint_txs
        .iter()
        .map(|cp| b64.encode(cp.serialize()))
        .collect();

    let result = InsertSigsResult {
        signed_ark_tx_b64,
        signed_checkpoint_txs_b64,
    };
    serde_json::to_string(&result).map_err(|e| format!("JSON serialize: {e}"))
}

// ---------------------------------------------------------------------------
// Change VTXO
// ---------------------------------------------------------------------------

pub fn get_change_vtxo(handle: u64) -> Result<String, String> {
    let sessions = get_sessions();
    let state = sessions
        .as_ref()
        .unwrap()
        .get(&handle)
        .ok_or("invalid session handle")?;

    let outputs = &state.ark_tx.unsigned_tx.output;
    if outputs.len() < 3 {
        return Ok("null".to_string());
    }
    let txid = state.ark_tx.unsigned_tx.compute_txid().to_string();
    let change_idx = outputs.len() - 2;
    let amount = outputs[change_idx].value.to_sat();
    if amount == 0 {
        return Ok("null".to_string());
    }

    let result = ChangeVtxoResult {
        txid,
        vout: change_idx as u32,
        amount,
    };
    serde_json::to_string(&result).map_err(|e| format!("JSON serialize: {e}"))
}

// ---------------------------------------------------------------------------
// Free session
// ---------------------------------------------------------------------------

pub fn free_send_session(handle: u64) {
    if let Ok(mut sessions) = SESSIONS.lock() {
        if let Some(map) = sessions.as_mut() {
            map.remove(&handle);
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers (replicated from ark/src/client/send.rs)
// ---------------------------------------------------------------------------

fn collect_ark_tx_sighashes(
    psbt: &Psbt,
    sighashes: &mut Vec<[u8; 32]>,
    entries: &mut Vec<SighashEntry>,
) -> Result<(), String> {
    let prevouts: Vec<TxOut> = psbt
        .inputs
        .iter()
        .map(|i| {
            i.witness_utxo
                .clone()
                .ok_or("missing witness_utxo in ark tx input".to_string())
        })
        .collect::<Result<Vec<_>, _>>()?;

    let mut cache = SighashCache::new(&psbt.unsigned_tx);

    for (idx, input) in psbt.inputs.iter().enumerate() {
        let leaf_hash = input
            .tap_script_sigs
            .keys()
            .next()
            .map(|(_, lh)| *lh)
            .or_else(|| {
                input
                    .tap_scripts
                    .values()
                    .next()
                    .map(|(script, ver)| TapLeafHash::from_script(script, *ver))
            })
            .ok_or_else(|| format!("no leaf hash for ark tx input {idx}"))?;

        let hash = cache
            .taproot_script_spend_signature_hash(
                idx,
                &Prevouts::All(&prevouts),
                leaf_hash,
                TapSighashType::Default,
            )
            .map_err(|e| format!("sighash for ark tx input {idx}: {e}"))?;

        sighashes.push(hash.to_byte_array());
        entries.push(SighashEntry {
            target: SighashTarget::ArkTx(idx),
            leaf_hash,
        });
    }
    Ok(())
}

fn collect_checkpoint_sighash(
    psbt: &Psbt,
    checkpoint_idx: usize,
    sighashes: &mut Vec<[u8; 32]>,
    entries: &mut Vec<SighashEntry>,
) -> Result<(), String> {
    let prevout = psbt.inputs[0]
        .witness_utxo
        .clone()
        .ok_or("missing witness_utxo in checkpoint input")?;

    let leaf_hash = psbt.inputs[0]
        .tap_script_sigs
        .keys()
        .next()
        .map(|(_, lh)| *lh)
        .or_else(|| {
            psbt.inputs[0]
                .tap_scripts
                .values()
                .next()
                .map(|(script, ver)| TapLeafHash::from_script(script, *ver))
        })
        .ok_or_else(|| format!("no leaf hash for checkpoint {checkpoint_idx}"))?;

    let mut cache = SighashCache::new(&psbt.unsigned_tx);
    let hash = cache
        .taproot_script_spend_signature_hash(
            0,
            &Prevouts::All(&[prevout]),
            leaf_hash,
            TapSighashType::Default,
        )
        .map_err(|e| format!("sighash for checkpoint {checkpoint_idx}: {e}"))?;

    sighashes.push(hash.to_byte_array());
    entries.push(SighashEntry {
        target: SighashTarget::Checkpoint(checkpoint_idx),
        leaf_hash,
    });
    Ok(())
}

fn build_server_info(info: &ArkInfoParam, network: Network) -> Result<server::Info, String> {
    let signer_pk_hex = if info.signer_pubkey.len() == 64 {
        format!("02{}", info.signer_pubkey)
    } else {
        info.signer_pubkey.clone()
    };
    let signer_pk = bitcoin::secp256k1::PublicKey::from_slice(&hex_decode(&signer_pk_hex)?)
        .map_err(|e| format!("invalid signer_pubkey: {e}"))?;

    let forfeit_pk_hex = if info.forfeit_pubkey.len() == 64 {
        format!("02{}", info.forfeit_pubkey)
    } else {
        info.forfeit_pubkey.clone()
    };
    let forfeit_pk = bitcoin::secp256k1::PublicKey::from_slice(&hex_decode(&forfeit_pk_hex)?)
        .map_err(|e| format!("invalid forfeit_pubkey: {e}"))?;

    let forfeit_address: bitcoin::Address<bitcoin::address::NetworkUnchecked> = info
        .forfeit_address
        .parse()
        .map_err(|e| format!("invalid forfeit_address: {e}"))?;
    let forfeit_address = forfeit_address
        .require_network(network)
        .map_err(|e| format!("forfeit_address network mismatch: {e}"))?;

    let checkpoint_tapscript = ScriptBuf::from_bytes(hex_decode(&info.checkpoint_tapscript)?);

    let exit_delay = server::parse_sequence_number(info.unilateral_exit_delay)
        .map_err(|e| format!("invalid unilateral_exit_delay: {e}"))?;
    let boarding_delay = server::parse_sequence_number(info.boarding_exit_delay)
        .map_err(|e| format!("invalid boarding_exit_delay: {e}"))?;

    Ok(server::Info {
        version: String::new(),
        signer_pk,
        forfeit_pk,
        forfeit_address,
        checkpoint_tapscript,
        network,
        session_duration: info.session_duration as u64,
        unilateral_exit_delay: exit_delay,
        boarding_exit_delay: boarding_delay,
        utxo_min_amount: None,
        utxo_max_amount: None,
        vtxo_min_amount: if info.vtxo_min_amount > 0 {
            Some(Amount::from_sat(info.vtxo_min_amount as u64))
        } else {
            None
        },
        vtxo_max_amount: None,
        dust: Amount::from_sat(info.dust as u64),
        fees: None,
        scheduled_session: None,
        deprecated_signers: vec![],
        service_status: HashMap::new(),
        digest: String::new(),
    })
}

fn parse_xonly(hex: &str) -> Result<XOnlyPublicKey, String> {
    let hex = if hex.len() == 66 && (hex.starts_with("02") || hex.starts_with("03")) {
        &hex[2..]
    } else {
        hex
    };
    XOnlyPublicKey::from_str(hex).map_err(|e| format!("invalid x-only pubkey: {e}"))
}

fn parse_network(network: &str) -> Result<Network, String> {
    match network {
        "bitcoin" | "mainnet" => Ok(Network::Bitcoin),
        "testnet" | "testnet3" => Ok(Network::Testnet),
        "signet" | "mutinynet" => Ok(Network::Signet),
        "regtest" => Ok(Network::Regtest),
        _ => Err(format!("unknown network: {network}")),
    }
}

fn hex_decode(hex: &str) -> Result<Vec<u8>, String> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).map_err(|e| format!("hex: {e}")))
        .collect()
}

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}
