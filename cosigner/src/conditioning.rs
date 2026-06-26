//! Plan A 1C: the cosigner-guest is authoritative about WHAT it signs for a `{service, cosigner}`
//! pairing actor. It rebuilds the contract eVTXO's cooperative-leaf sighash from its OWN sealed
//! params and signs only that — so a compromised host/service can't make it co-sign anything but a
//! contract-approved spend of its associated eVTXO. (Ported from the former host-side
//! `contract_gate::pairing_coop_sighash` / `arktx_leg_sighash`; runs entirely in the guest now.)

use bitcoin::hashes::Hash;
use bitcoin::sighash::{Prevouts, SighashCache};
use bitcoin::taproot::LeafVersion;
use bitcoin::{TapLeafHash, TapSighashType};
use sha2::{Digest, Sha256};
use threshold::keys::PublicKeyPackage;

/// Binds a pairing actor to the single eVTXO it may co-sign. All params needed to rebuild the
/// cooperative-leaf script (and thus the script-path sighash), carried into the guest via
/// `InstallPolicy` and sealed in the snapshot.
#[derive(Clone, Debug)]
pub struct ContractPairing {
    pub evtxo_spk_hex: String,
    pub contract_id: [u8; 32],
    pub server_pk: [u8; 32],
    pub owner_pk: [u8; 32],
    pub exit_delay: u32,
}

/// LEG 1: the cooperative-leaf script-path sighash of the input that spends this actor's eVTXO.
/// The leaf is rebuilt from the cosigner's own registration params (NOT the client PSBT scripts),
/// so the only thing this can ever produce a signature over is a spend of its own eVTXO. `pkp` is
/// the pairing PKP (its group key is `V`, the cooperative key). Errs if the spend doesn't touch it.
pub fn pairing_coop_sighash(
    pairing: &ContractPairing,
    pkp: &PublicKeyPackage,
    full_transaction: &[u8],
) -> Result<[u8; 32], String> {
    let psbt =
        bitcoin::Psbt::deserialize(full_transaction).map_err(|e| format!("not a PSBT: {e}"))?;

    let prevouts: Vec<bitcoin::TxOut> = psbt
        .inputs
        .iter()
        .map(|i| {
            i.witness_utxo.clone().unwrap_or_else(|| bitcoin::TxOut {
                value: bitcoin::Amount::from_sat(0),
                script_pubkey: bitcoin::ScriptBuf::new(),
            })
        })
        .collect();
    let input_idx = prevouts
        .iter()
        .position(|p| hex::encode(p.script_pubkey.as_bytes()) == pairing.evtxo_spk_hex)
        .ok_or("service pairing may only co-sign a spend of its own eVTXO")?;

    let commit: [u8; 32] = Sha256::digest(pairing.contract_id).into();
    let evtxo_pk = threshold::point::serialize_x_only(&pkp.verifying_key.point);
    let (coop_script, _cb) = ark::evtxo_cooperative_spend_info(
        &commit,
        &pairing.server_pk,
        &evtxo_pk,
        &pairing.owner_pk,
        pairing.exit_delay,
    )
    .ok_or("evtxo_cooperative_spend_info failed")?;
    let coop_script_buf = bitcoin::ScriptBuf::from_bytes(coop_script);

    let leaf_hash = TapLeafHash::from_script(&coop_script_buf, LeafVersion::TapScript);
    let sighash = SighashCache::new(&psbt.unsigned_tx)
        .taproot_script_spend_signature_hash(
            input_idx,
            &Prevouts::All(&prevouts),
            leaf_hash,
            TapSighashType::Default,
        )
        .map_err(|e| format!("coop sighash: {e}"))?;
    Ok(sighash.to_byte_array())
}

/// LEG 2 (service spend THROUGH arkd): the script-path sighash of the `ark_tx` input that spends an
/// OUTPUT of the verified `checkpoint_tx`. We don't re-derive ark-core's protocol; we CHAIN leg 2
/// to leg 1 — the `ark_tx` input's prevout must be an output of the same checkpoint leg 1 verified
/// spends the eVTXO. That binds the bundle to the eVTXO. The checkpoint output is `V`+server and
/// arkd validates the ark_tx independently, so taking the leaf from the PSBT is safe.
pub fn arktx_leg_sighash(checkpoint_tx: &[u8], ark_tx: &[u8]) -> Result<[u8; 32], String> {
    let cp = bitcoin::Psbt::deserialize(checkpoint_tx)
        .map_err(|e| format!("checkpoint not a PSBT: {e}"))?;
    let at = bitcoin::Psbt::deserialize(ark_tx).map_err(|e| format!("ark_tx not a PSBT: {e}"))?;
    let cp_txid = cp.unsigned_tx.compute_txid();

    let prevouts: Vec<bitcoin::TxOut> = at
        .inputs
        .iter()
        .map(|i| {
            i.witness_utxo
                .clone()
                .ok_or_else(|| "ark_tx input missing witness_utxo".to_string())
        })
        .collect::<Result<_, _>>()?;

    let idx = at
        .unsigned_tx
        .input
        .iter()
        .enumerate()
        .find_map(|(i, txin)| {
            if txin.previous_output.txid != cp_txid {
                return None;
            }
            let cp_out = cp.unsigned_tx.output.get(txin.previous_output.vout as usize)?;
            (prevouts.get(i)?.script_pubkey == cp_out.script_pubkey).then_some(i)
        })
        .ok_or("ark_tx does not spend the verified checkpoint's output")?;

    let input = &at.inputs[idx];
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
        .ok_or("ark_tx input has no tap leaf")?;

    let sighash = SighashCache::new(&at.unsigned_tx)
        .taproot_script_spend_signature_hash(
            idx,
            &Prevouts::All(&prevouts),
            leaf_hash,
            TapSighashType::Default,
        )
        .map_err(|e| format!("ark_tx sighash: {e}"))?;
    Ok(sighash.to_byte_array())
}
