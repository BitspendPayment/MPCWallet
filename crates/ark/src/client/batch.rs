//! Ark batch/settle protocol for boarding on-chain UTXOs into VTXOs.
//!
//! This module splits the settlement flow into discrete phases so that FROST
//! threshold signing can happen externally between phases.
//!
//! ## Phases
//!
//! 1. **Prepare intent** (`new_boarding`) -- build the intent proof PSBT, return
//!    sighashes that need FROST signing.
//! 2. **Register intent** (`register_with_signatures`) -- insert FROST signatures
//!    into the proof PSBT and register the intent with the ASP.
//! 3. **Drive batch** (`drive`) -- consume the ASP event stream: confirm
//!    registration, generate ephemeral nonces, sign tree txs, and extract
//!    commitment PSBT sighashes for FROST.
//! 4. **Complete** (`submit_commitment_signatures`) -- insert FROST signatures
//!    for the commitment PSBT and submit forfeit/commitment to the ASP.

use std::collections::HashMap;
use std::str::FromStr;

use ark_core::batch::{generate_nonce_tree, sign_batch_tree_tx, NonceKps, OnChainInput, aggregate_nonces};
use ark_core::intent::IntentMessage;
use ark_core::server::PartialSigTree;
use ark_core::{BoardingOutput, TxGraph, TxGraphChunk, VTXO_TAPROOT_KEY};

use bitcoin::absolute;
use bitcoin::base64::{self, Engine};
use bitcoin::hashes::sha256;
use bitcoin::hashes::Hash;
use bitcoin::key::{Keypair, Secp256k1};
use bitcoin::psbt::{self, PsbtSighashType};
use bitcoin::sighash::{Prevouts, SighashCache};
use bitcoin::taproot::{self, LeafVersion};
use bitcoin::transaction::Version;
use bitcoin::{
    Amount, Network, OutPoint, Psbt, ScriptBuf, Sequence, TapLeafHash, TapSighashType, Transaction,
    TxIn, TxOut, Txid, Witness, XOnlyPublicKey,
};

use crate::client::asp_client::AspClient;
use crate::client::proto;
use crate::client::proto::get_event_stream_response::Event;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Action the caller must take after calling [`SettleSession::drive`].
pub enum SettleAction {
    /// FROST signatures are needed on these sighashes (script-path, no tweak).
    NeedSignatures { sighashes: Vec<[u8; 32]> },
    /// Batch is still processing; poll `drive` again.
    WaitingForBatch,
    /// Settlement complete.
    Settled {
        commitment_txid: String,
        /// The VTXO tree leaf outpoint (txid, vout).
        vtxo_outpoint: Option<(String, u32)>,
    },
}

/// Internal phase of the settle session state machine.
enum Phase {
    /// Intent prepared, waiting for FROST signatures on intent proof.
    AwaitingIntentSignatures,
    /// Intent registered, driving the event stream.
    Driving,
    /// Commitment PSBT received, waiting for FROST signatures.
    AwaitingCommitmentSignatures,
    /// Settlement complete.
    Done,
}

/// A session for settling boarding UTXOs into Ark VTXOs.
///
/// Splits the batch protocol into phases so that FROST signing can happen
/// externally between each phase.
pub struct SettleSession {
    phase: Phase,

    // -- identity --
    owner_pk: XOnlyPublicKey,
    #[allow(dead_code)]
    asp_pk: XOnlyPublicKey,
    /// ASP's forfeit x-only public key (used for tree signing sweep scripts).
    forfeit_pk: XOnlyPublicKey,
    #[allow(dead_code)]
    network: Network,
    #[allow(dead_code)]
    exit_delay: Sequence,

    // -- boarding input --
    boarding_output: BoardingOutput,
    onchain_input: OnChainInput,

    // -- intent --
    intent_proof_psbt: Option<Psbt>,
    intent_message: Option<IntentMessage>,
    /// Sighash index -> (psbt input index, leaf_hash) for inserting sigs later.
    intent_sighash_meta: Vec<(usize, TapLeafHash)>,
    intent_id: Option<String>,

    // -- ephemeral cosigner (for tree signing, NOT FROST) --
    cosigner_kp: Keypair,

    // -- batch state --
    batch_id: Option<String>,
    batch_expiry: Option<Sequence>,
    event_stream: Option<tonic::Streaming<proto::GetEventStreamResponse>>,
    tx_graph_chunks: Vec<TxGraphChunk>,
    tx_graph: Option<TxGraph>,
    nonce_kps: Option<NonceKps>,
    commitment_psbt: Option<Psbt>,
    /// Accumulated raw nonces per tree txid (from TreeNonces events).
    /// We only sign + submit once ALL nonces for every node in the graph
    /// have been collected (matching the reference ark-client).
    pending_nonces: HashMap<Txid, HashMap<String, String>>,

    // -- commitment signing --
    commitment_sighash_meta: Vec<(usize, TapLeafHash)>,
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

impl SettleSession {
    /// Create a new settle session for boarding UTXOs.
    ///
    /// Returns `(session, sighashes)` where `sighashes` are the taproot
    /// script-path sighashes that need FROST signing for the intent proof.
    pub fn new_boarding(
        owner_pk_hex: &str,
        asp_pk_hex: &str,
        forfeit_pk_hex: &str,
        boarding_address: &str,
        boarding_utxo_txid: &str,
        boarding_utxo_vout: u32,
        boarding_utxo_amount_sat: u64,
        exit_delay: u32,
        network: &str,
        delegate_cosigner_secret_hex: &str,
    ) -> Result<(Self, Vec<[u8; 32]>), String> {
        let secp = Secp256k1::new();
        let network = parse_network(network)?;

        let owner_pk = parse_xonly(owner_pk_hex)?;
        let asp_pk = parse_xonly(asp_pk_hex)?;
        let forfeit_pk = parse_xonly(forfeit_pk_hex)?;

        let exit_seq = ark_core::server::parse_sequence_number(exit_delay as i64)
            .map_err(|e| format!("invalid exit_delay: {e}"))?;

        let boarding_output =
            BoardingOutput::new(&secp, asp_pk, owner_pk, exit_seq, network)
                .map_err(|e| format!("BoardingOutput::new: {e}"))?;

        // Verify the address matches what the caller expects.
        let derived_addr = boarding_output.address().to_string();
        if derived_addr != boarding_address {
            return Err(format!(
                "derived boarding address {derived_addr} != expected {boarding_address}"
            ));
        }

        let outpoint = OutPoint {
            txid: boarding_utxo_txid
                .parse()
                .map_err(|e| format!("invalid txid: {e}"))?,
            vout: boarding_utxo_vout,
        };

        let amount = Amount::from_sat(boarding_utxo_amount_sat);

        let onchain_input = OnChainInput::new(boarding_output.clone(), amount, outpoint);

        // Use the server's DKG secret as the delegate cosigner key for MuSig2
        // tree signing.  This avoids mixing FROST and MuSig2 by giving the
        // batch protocol a real, persistent single key.
        let cosigner_secret_bytes = hex_decode_32(delegate_cosigner_secret_hex)?;
        let cosigner_secret = bitcoin::secp256k1::SecretKey::from_slice(&cosigner_secret_bytes)
            .map_err(|e| format!("invalid delegate cosigner secret: {e}"))?;
        let cosigner_kp = Keypair::from_secret_key(&secp, &cosigner_secret);
        let cosigner_pk = cosigner_kp.public_key();

        // Build the intent message.
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|e| format!("time error: {e}"))?
            .as_secs();
        let expire_at = now + 120; // 2 minutes

        let intent_message = IntentMessage::Register {
            onchain_output_indexes: vec![],
            valid_at: now,
            expire_at,
            own_cosigner_pks: vec![cosigner_pk],
        };

        // Build the BIP-322-like proof PSBT manually since
        // `build_proof_psbt` is pub(crate) in ark-core.
        let (forfeit_script, forfeit_cb) = boarding_output.forfeit_spend_info();
        let script_pubkey = boarding_output.script_pubkey();
        let tapscripts = boarding_output.tapscripts();

        let message_json = intent_message
            .encode()
            .map_err(|e| format!("encode intent message: {e}"))?;

        // BIP-322 "to_spend" transaction.
        let to_spend_tx = build_to_spend_tx(&message_json, &script_pubkey);
        let fake_outpoint = OutPoint {
            txid: to_spend_tx.compute_txid(),
            vout: 0,
        };

        // "to_sign" proof PSBT: input 0 = fake BIP-322 input, input 1 = boarding.
        let proof_tx = Transaction {
            version: Version::TWO,
            lock_time: absolute::LockTime::ZERO,
            input: vec![
                TxIn {
                    previous_output: fake_outpoint,
                    script_sig: ScriptBuf::new(),
                    sequence: Sequence::MAX,
                    witness: Witness::default(),
                },
                TxIn {
                    previous_output: outpoint,
                    script_sig: ScriptBuf::new(),
                    sequence: Sequence::MAX,
                    witness: Witness::default(),
                },
            ],
            output: vec![TxOut {
                value: amount,
                script_pubkey: boarding_output
                    .to_ark_address(network, asp_pk)
                    .to_p2tr_script_pubkey(),
            }],
        };

        let mut proof_psbt = Psbt::from_unsigned_tx(proof_tx)
            .map_err(|e| format!("Psbt::from_unsigned_tx: {e}"))?;

        // Populate witness UTXOs and sighash types.
        proof_psbt.inputs[0].witness_utxo = Some(to_spend_tx.output[0].clone());
        proof_psbt.inputs[0].sighash_type = Some(PsbtSighashType::from_u32(1));
        proof_psbt.inputs[0].witness_script = Some(forfeit_script.clone());

        proof_psbt.inputs[1].witness_utxo = Some(TxOut {
            value: amount,
            script_pubkey: script_pubkey.clone(),
        });
        proof_psbt.inputs[1].sighash_type = Some(PsbtSighashType::from_u32(1));
        proof_psbt.inputs[1].witness_script = Some(forfeit_script.clone());

        // Populate tap_scripts for both inputs.
        // Input 0 (BIP-322 fake) uses the same spend info as the boarding input.
        proof_psbt.inputs[0].tap_scripts.insert(
            forfeit_cb.clone(),
            (forfeit_script.clone(), LeafVersion::TapScript),
        );

        // Input 1 (boarding): add tap_scripts and taptree encoding.
        proof_psbt.inputs[1].tap_scripts.insert(
            forfeit_cb.clone(),
            (forfeit_script.clone(), LeafVersion::TapScript),
        );
        let taptree_bytes = encode_taptree(&tapscripts);
        proof_psbt.inputs[1].unknown.insert(
            psbt::raw::Key {
                type_value: 222,
                key: VTXO_TAPROOT_KEY.to_vec(),
            },
            taptree_bytes,
        );

        // Compute sighashes for every input in the proof PSBT.
        let prevouts: Vec<TxOut> = proof_psbt
            .inputs
            .iter()
            .filter_map(|i| i.witness_utxo.clone())
            .collect();

        let mut sighashes = Vec::new();
        let mut sighash_meta = Vec::new();

        for (i, proof_input) in proof_psbt.inputs.iter().enumerate() {
            let (_, (script, leaf_version)) = proof_input
                .tap_scripts
                .first_key_value()
                .ok_or_else(|| format!("missing tap_scripts for input {i}"))?;

            let leaf_hash = TapLeafHash::from_script(script, *leaf_version);
            let prevs = Prevouts::All(&prevouts);

            let tap_sighash = SighashCache::new(&proof_psbt.unsigned_tx)
                .taproot_script_spend_signature_hash(
                    i,
                    &prevs,
                    leaf_hash,
                    TapSighashType::Default,
                )
                .map_err(|e| format!("sighash error input {i}: {e}"))?;

            sighashes.push(tap_sighash.to_raw_hash().to_byte_array());
            sighash_meta.push((i, leaf_hash));
        }

        let session = SettleSession {
            phase: Phase::AwaitingIntentSignatures,
            owner_pk,
            asp_pk,
            forfeit_pk,
            network,
            exit_delay: exit_seq,
            boarding_output,
            onchain_input,
            intent_proof_psbt: Some(proof_psbt),
            intent_message: Some(intent_message),
            intent_sighash_meta: sighash_meta,
            intent_id: None,
            cosigner_kp,
            batch_id: None,
            batch_expiry: None,
            event_stream: None,
            tx_graph_chunks: Vec::new(),
            tx_graph: None,
            nonce_kps: None,
            commitment_psbt: None,
            pending_nonces: HashMap::new(),
            commitment_sighash_meta: Vec::new(),
        };

        Ok((session, sighashes))
    }
}

// ---------------------------------------------------------------------------
// Phase transitions
// ---------------------------------------------------------------------------

impl SettleSession {
    /// Submit FROST signatures for the intent proof and register with the ASP.
    ///
    /// `signatures` must be in the same order as the sighashes returned by
    /// `new_boarding`.
    pub async fn register_with_signatures(
        &mut self,
        asp: &mut AspClient,
        signatures: Vec<[u8; 64]>,
    ) -> Result<(), String> {
        if !matches!(self.phase, Phase::AwaitingIntentSignatures) {
            return Err("register_with_signatures called in wrong phase".into());
        }

        let proof_psbt = self
            .intent_proof_psbt
            .as_mut()
            .ok_or("missing intent proof PSBT")?;

        if signatures.len() != self.intent_sighash_meta.len() {
            return Err(format!(
                "expected {} signatures, got {}",
                self.intent_sighash_meta.len(),
                signatures.len()
            ));
        }

        // Insert each FROST signature into the proof PSBT.
        for (sig_bytes, (input_idx, leaf_hash)) in
            signatures.iter().zip(self.intent_sighash_meta.iter())
        {
            let schnorr_sig =
                bitcoin::secp256k1::schnorr::Signature::from_slice(sig_bytes)
                    .map_err(|e| format!("invalid schnorr sig: {e}"))?;

            let sig = taproot::Signature {
                signature: schnorr_sig,
                sighash_type: TapSighashType::Default,
            };

            proof_psbt.inputs[*input_idx]
                .tap_script_sigs
                .insert((self.owner_pk, *leaf_hash), sig);
        }

        // Serialize the proof and message for registration.
        let proof_b64 = encode_psbt_b64(proof_psbt);

        let message_json = self
            .intent_message
            .as_ref()
            .ok_or("missing intent message")?
            .encode()
            .map_err(|e| format!("encode intent message: {e}"))?;

        let intent_id = asp
            .register_intent(proof_b64, message_json)
            .await
            .map_err(|e| format!("register_intent: {e}"))?;

        self.intent_id = Some(intent_id);
        self.phase = Phase::Driving;

        // Open the event stream with outpoint + cosigner key topics
        // (matching the reference ark-client implementation).
        let outpoint_topic = self.onchain_input.outpoint().to_string();
        let cosigner_bytes = self.cosigner_kp.public_key().serialize();
        let cosigner_topic = cosigner_bytes.iter()
            .map(|b| format!("{b:02x}"))
            .collect::<String>();
        eprintln!(
            "event stream topics: outpoint={outpoint_topic}, cosigner={cosigner_topic}"
        );
        let stream = asp
            .get_event_stream(vec![outpoint_topic, cosigner_topic])
            .await
            .map_err(|e| format!("get_event_stream: {e}"))?;
        self.event_stream = Some(stream);

        Ok(())
    }

    /// Drive the event stream forward.
    ///
    /// Call this repeatedly until it returns [`SettleAction::Settled`] or
    /// [`SettleAction::NeedSignatures`] (for the commitment PSBT).
    pub async fn drive(&mut self, asp: &mut AspClient) -> Result<SettleAction, String> {
        match self.phase {
            Phase::AwaitingIntentSignatures => {
                return Err("call register_with_signatures first".into());
            }
            Phase::AwaitingCommitmentSignatures => {
                return Err("call submit_commitment_signatures first".into());
            }
            Phase::Done => {
                return Err("session already complete".into());
            }
            Phase::Driving => {}
        }

        let stream = self.event_stream.as_mut().ok_or("event stream not open")?;

        use tokio_stream::StreamExt;
        let msg = stream
            .next()
            .await
            .ok_or("event stream ended unexpectedly")?
            .map_err(|e| format!("stream error: {e}"))?;

        let event = match msg.event {
            Some(e) => e,
            None => return Ok(SettleAction::WaitingForBatch),
        };

        match event {
            Event::BatchStarted(e) => {
                eprintln!("event: BatchStarted id={}", e.id);
                self.handle_batch_started(asp, e).await?;
                Ok(SettleAction::WaitingForBatch)
            }
            Event::TreeSigningStarted(e) => {
                eprintln!(
                    "event: TreeSigningStarted id={} cosigners={} chunks_so_far={}",
                    e.id, e.cosigners_pubkeys.len(), self.tx_graph_chunks.len()
                );
                self.handle_tree_signing_started(asp, e).await?;
                Ok(SettleAction::WaitingForBatch)
            }
            Event::TreeNoncesAggregated(e) => {
                eprintln!("event: TreeNoncesAggregated id={}", e.id);
                // Signing already done in handle_tree_nonces_and_sign.
                Ok(SettleAction::WaitingForBatch)
            }
            Event::TreeTx(e) => {
                eprintln!(
                    "event: TreeTx id={} txid={} topic={:?}",
                    e.id, e.txid, e.topic
                );
                self.handle_tree_tx(e)?;
                Ok(SettleAction::WaitingForBatch)
            }
            Event::TreeNonces(e) => {
                eprintln!(
                    "event: TreeNonces id={} txid={} nonces_count={}",
                    e.id, e.txid, e.nonces.len()
                );
                self.handle_tree_nonces(asp, e).await?;
                Ok(SettleAction::WaitingForBatch)
            }
            Event::TreeSignature(_) => {
                // Per-tx signature events from other cosigners; ignored.
                Ok(SettleAction::WaitingForBatch)
            }
            Event::BatchFinalization(e) => {
                eprintln!("event: BatchFinalization id={}", e.id);
                let sighashes = self.handle_batch_finalization(e)?;
                self.phase = Phase::AwaitingCommitmentSignatures;
                Ok(SettleAction::NeedSignatures { sighashes })
            }
            Event::BatchFinalized(e) => {
                eprintln!("event: BatchFinalized txid={}", e.commitment_txid);
                self.phase = Phase::Done;
                // Extract the VTXO leaf outpoint from the tree graph.
                let vtxo_outpoint = self.tx_graph.as_ref().map(|g| {
                    let leaf = first_tree_leaf(g);
                    (leaf.unsigned_tx.compute_txid().to_string(), 0u32)
                });
                Ok(SettleAction::Settled {
                    commitment_txid: e.commitment_txid,
                    vtxo_outpoint,
                })
            }
            Event::BatchFailed(e) => Err(format!("batch failed: {}", e.reason)),
            Event::Heartbeat(_) | Event::StreamStarted(_) => Ok(SettleAction::WaitingForBatch),
        }
    }

    /// Submit FROST signatures for the commitment PSBT and finalize.
    pub async fn submit_commitment_signatures(
        &mut self,
        asp: &mut AspClient,
        signatures: Vec<[u8; 64]>,
    ) -> Result<(), String> {
        if !matches!(self.phase, Phase::AwaitingCommitmentSignatures) {
            return Err("submit_commitment_signatures called in wrong phase".into());
        }

        let commitment_psbt = self
            .commitment_psbt
            .as_mut()
            .ok_or("missing commitment PSBT")?;

        if signatures.len() != self.commitment_sighash_meta.len() {
            return Err(format!(
                "expected {} commitment sigs, got {}",
                self.commitment_sighash_meta.len(),
                signatures.len()
            ));
        }

        // Insert FROST signatures into the commitment PSBT.
        for (sig_bytes, (input_idx, leaf_hash)) in
            signatures.iter().zip(self.commitment_sighash_meta.iter())
        {
            let schnorr_sig =
                bitcoin::secp256k1::schnorr::Signature::from_slice(sig_bytes)
                    .map_err(|e| format!("invalid schnorr sig: {e}"))?;

            let sig = taproot::Signature {
                signature: schnorr_sig,
                sighash_type: TapSighashType::Default,
            };

            commitment_psbt.inputs[*input_idx]
                .tap_script_sigs
                .insert((self.owner_pk, *leaf_hash), sig);
        }

        // Serialize the signed commitment PSBT.
        let signed_commitment_b64 = encode_psbt_b64(commitment_psbt);

        // For boarding-only (no existing VTXOs being forfeited), there are no
        // forfeit txs to sign.
        asp.submit_signed_forfeit_txs(vec![], signed_commitment_b64)
            .await
            .map_err(|e| format!("submit_signed_forfeit_txs: {e}"))?;

        // Return to driving phase so the caller can poll for BatchFinalized.
        self.phase = Phase::Driving;

        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Event handlers
// ---------------------------------------------------------------------------

impl SettleSession {
    async fn handle_batch_started(
        &mut self,
        asp: &mut AspClient,
        event: proto::BatchStartedEvent,
    ) -> Result<(), String> {
        self.batch_id = Some(event.id.clone());

        if event.batch_expiry > 0 {
            self.batch_expiry = Some(
                ark_core::server::parse_sequence_number(event.batch_expiry)
                    .map_err(|e| format!("parse batch_expiry: {e}"))?,
            );
        }

        // Confirm our registration.
        let intent_id = self
            .intent_id
            .as_ref()
            .ok_or("no intent_id to confirm")?
            .clone();

        asp.confirm_registration(intent_id)
            .await
            .map_err(|e| format!("confirm_registration: {e}"))?;

        Ok(())
    }

    async fn handle_tree_signing_started(
        &mut self,
        asp: &mut AspClient,
        event: proto::TreeSigningStartedEvent,
    ) -> Result<(), String> {
        // Use batch_id from BatchStarted if available, otherwise fall back to
        // the TreeSigningStarted event id (public ASPs may skip BatchStarted).
        if self.batch_id.is_none() {
            self.batch_id = Some(event.id.clone());
        }
        let batch_id = self.batch_id.as_ref().ok_or("no batch_id set")?.clone();

        // Decode the unsigned commitment PSBT.
        let commitment_psbt = decode_psbt_b64(&event.unsigned_commitment_tx)?;

        // Build TxGraph from collected chunks.
        if self.tx_graph_chunks.is_empty() {
            return Err("no tree tx chunks collected yet".into());
        }

        let tx_graph = TxGraph::new(self.tx_graph_chunks.drain(..).collect())
            .map_err(|e| format!("TxGraph::new: {e}"))?;

        // Generate ephemeral nonces (no FROST needed).
        let cosigner_pk = self.cosigner_kp.public_key();
        let nonce_kps = {
            let mut rng = rand::thread_rng();
            generate_nonce_tree(&mut rng, &tx_graph, cosigner_pk, &commitment_psbt)
                .map_err(|e| format!("generate_nonce_tree: {e}"))?
        };

        // Convert nonces to proto format and submit.
        let nonce_pks = nonce_kps.to_nonce_pks();
        let nonce_map = nonce_pks.encode();
        let cosigner_pk_hex = cosigner_pk.to_string();

        asp.submit_tree_nonces(&batch_id, cosigner_pk_hex, nonce_map)
            .await
            .map_err(|e| format!("submit_tree_nonces: {e}"))?;

        self.nonce_kps = Some(nonce_kps);
        self.tx_graph = Some(tx_graph);
        self.commitment_psbt = Some(commitment_psbt);

        Ok(())
    }

    /// Handle a TreeNonces event: accumulate nonces, and once all tree nodes
    /// have nonces, sign ALL at once and submit in a single call.
    /// This matches the reference ark-client which waits for all nonces before signing.
    async fn handle_tree_nonces(
        &mut self,
        asp: &mut AspClient,
        event: proto::TreeNoncesEvent,
    ) -> Result<(), String> {
        let txid: Txid = event
            .txid
            .parse()
            .map_err(|e| format!("invalid txid {}: {e}", event.txid))?;

        // Store the raw nonces for this txid.
        self.pending_nonces.insert(txid, event.nonces);

        let tx_graph = self.tx_graph.as_ref().ok_or("no tx_graph built")?;
        let expected = tx_graph.nb_of_nodes();

        eprintln!(
            "  accumulated nonces for txid={txid}, {}/{} collected",
            self.pending_nonces.len(),
            expected
        );

        // Only sign once ALL nonces for every tree node have been collected.
        if self.pending_nonces.len() < expected {
            return Ok(());
        }

        let batch_id = self.batch_id.as_ref().ok_or("no batch_id set")?.clone();
        let commitment_psbt = self.commitment_psbt.as_ref().ok_or("no commitment_psbt")?;
        let nonce_kps = self.nonce_kps.as_mut().ok_or("no nonce_kps generated")?;
        let batch_expiry = self.batch_expiry.ok_or("no batch_expiry")?;
        let forfeit_xonly = self.forfeit_pk;

        // Sign ALL tree txids at once.
        let mut combined_sigs = PartialSigTree::default();

        for (tree_txid, _) in tx_graph.as_map() {
            let raw_nonces = self.pending_nonces.get(&tree_txid).ok_or_else(|| {
                format!("missing nonces for tree txid {tree_txid}")
            })?;

            let tree_tx_nonce_pks =
                ark_core::server::TreeTxNoncePks::decode(raw_nonces.clone())
                    .map_err(|e| format!("decode TreeTxNoncePks for {tree_txid}: {e}"))?;

            let agg_nonce = aggregate_nonces(tree_tx_nonce_pks);

            let partial_sig = sign_batch_tree_tx(
                tree_txid,
                batch_expiry,
                forfeit_xonly,
                &self.cosigner_kp,
                agg_nonce,
                tx_graph,
                commitment_psbt,
                nonce_kps,
            )
            .map_err(|e| format!("sign_batch_tree_tx {tree_txid}: {e}"))?;

            combined_sigs.0.extend(partial_sig.0);
        }

        // Submit ALL signatures in a single call.
        let sig_map = combined_sigs.encode();
        let cosigner_pk_hex = self.cosigner_kp.public_key().to_string();

        asp.submit_tree_signatures(&batch_id, cosigner_pk_hex, sig_map)
            .await
            .map_err(|e| format!("submit_tree_signatures: {e}"))?;

        self.pending_nonces.clear();
        Ok(())
    }

    fn handle_tree_tx(&mut self, event: proto::TreeTxEvent) -> Result<(), String> {
        let psbt = decode_psbt_b64(&event.tx)?;

        let children: HashMap<u32, Txid> = event
            .children
            .into_iter()
            .map(|(vout, txid_str)| {
                let txid: Txid = txid_str
                    .parse()
                    .map_err(|e| format!("invalid child txid: {e}"))?;
                Ok((vout, txid))
            })
            .collect::<Result<_, String>>()?;

        let txid = if event.txid.is_empty() {
            None
        } else {
            Some(
                event
                    .txid
                    .parse()
                    .map_err(|e| format!("invalid txid: {e}"))?,
            )
        };

        self.tx_graph_chunks.push(TxGraphChunk {
            txid,
            tx: psbt,
            children,
        });

        Ok(())
    }

    fn handle_batch_finalization(
        &mut self,
        event: proto::BatchFinalizationEvent,
    ) -> Result<Vec<[u8; 32]>, String> {
        // Decode the commitment PSBT from the finalization event.
        let commitment_psbt = decode_psbt_b64(&event.commitment_tx)?;

        let (forfeit_script, forfeit_cb) = self.boarding_output.forfeit_spend_info();
        let boarding_outpoint = self.onchain_input.outpoint();

        let prevouts: Vec<TxOut> = commitment_psbt
            .inputs
            .iter()
            .filter_map(|i| i.witness_utxo.clone())
            .collect();

        let mut sighashes = Vec::new();
        let mut sighash_meta = Vec::new();

        // Find our boarding input(s) in the commitment PSBT and compute sighashes.
        for (i, _psbt_input) in commitment_psbt.inputs.iter().enumerate() {
            let prev_outpoint = commitment_psbt.unsigned_tx.input[i].previous_output;

            if prev_outpoint == boarding_outpoint {
                let leaf_version = forfeit_cb.leaf_version;
                let leaf_hash = TapLeafHash::from_script(&forfeit_script, leaf_version);
                let prevs = Prevouts::All(&prevouts);

                let tap_sighash = SighashCache::new(&commitment_psbt.unsigned_tx)
                    .taproot_script_spend_signature_hash(
                        i,
                        &prevs,
                        leaf_hash,
                        TapSighashType::Default,
                    )
                    .map_err(|e| format!("commitment sighash: {e}"))?;

                sighashes.push(tap_sighash.to_raw_hash().to_byte_array());
                sighash_meta.push((i, leaf_hash));
            }
        }

        if sighashes.is_empty() {
            return Err("boarding input not found in commitment PSBT".into());
        }

        // Store the commitment PSBT and sighash metadata.
        // Also insert tap_scripts for our inputs so finalization can proceed.
        let mut commitment_psbt = commitment_psbt;
        for &(input_idx, _) in &sighash_meta {
            let leaf_version = forfeit_cb.leaf_version;
            commitment_psbt.inputs[input_idx].tap_scripts.insert(
                forfeit_cb.clone(),
                (forfeit_script.clone(), leaf_version),
            );
        }

        self.commitment_psbt = Some(commitment_psbt);
        self.commitment_sighash_meta = sighash_meta;

        Ok(sighashes)
    }
}

// ===========================================================================
// DelegateSettleSession — settle existing VTXOs via the delegate pattern.
//
// The delegate pattern cleanly separates FROST (owner key) from MuSig2
// (tree signing):
//   Phase 1: generate_delegate() → build intent + forfeit PSBTs, return sighashes
//   Phase 2: sign_with_frost() → insert FROST signatures
//   Phase 3: settle() → register intent, drive batch with delegate cosigner key
// ===========================================================================

/// Input VTXO descriptor for delegate settle. The server passes these from
/// its VTXO store; the `DelegateSettleSession` reconstructs the `ark_core`
/// types needed for `prepare_delegate_psbts`.
pub struct DelegateVtxoInput {
    pub txid: String,
    pub vout: u32,
    pub amount_sats: u64,
    /// Whether this VTXO was already swept by the ASP.
    pub is_swept: bool,
}

/// Output descriptor for delegate settle.
pub struct DelegateOutput {
    /// Ark address string (bech32m encoded).
    pub ark_address: String,
    pub amount_sats: u64,
}

/// Phase of the delegate session state machine.
enum DelegatePhase {
    AwaitingSignatures,
    ReadyToSettle,
    Settling,
    Done,
}

/// A session for settling existing VTXOs using the delegate pattern.
///
/// Unlike `SettleSession` (boarding), this requires only a single round of
/// FROST signatures upfront.  The server then drives the batch autonomously
/// using its DKG private key for MuSig2 tree signing.
pub struct DelegateSettleSession {
    phase: DelegatePhase,

    // -- identity --
    owner_pk: XOnlyPublicKey,
    #[allow(dead_code)]
    asp_pk: XOnlyPublicKey,
    /// ASP's forfeit x-only public key (used for tree signing sweep scripts).
    forfeit_pk: XOnlyPublicKey,
    #[allow(dead_code)]
    network: Network,
    #[allow(dead_code)]
    exit_delay: Sequence,

    // -- delegate data --
    delegate: ark_core::batch::Delegate,
    delegate_cosigner_kp: Keypair,

    // -- sighash metadata for FROST --
    sighash_meta: Vec<SighashEntry>,

    // -- batch state --
    batch_id: Option<String>,
    batch_expiry: Option<Sequence>,
    vtxo_graph_chunks: Vec<TxGraphChunk>,
    connector_graph_chunks: Vec<TxGraphChunk>,
    vtxo_graph: Option<TxGraph>,
    nonce_kps: Option<NonceKps>,
    commitment_psbt: Option<Psbt>,
    /// Accumulated raw nonces per tree txid (from TreeNonces events).
    pending_nonces: HashMap<Txid, HashMap<String, String>>,
}

/// Tracks which PSBT and input index a sighash belongs to.
struct SighashEntry {
    /// 0 = intent proof PSBT, 1..N = forfeit PSBT index + 1
    psbt_type: usize,
    input_idx: usize,
    leaf_hash: TapLeafHash,
}

// ---------------------------------------------------------------------------
// DelegateSettleSession – construction
// ---------------------------------------------------------------------------

impl DelegateSettleSession {
    /// Generate a delegate for existing VTXOs.
    ///
    /// Reconstructs `ark_core::Vtxo` objects from the provided metadata,
    /// calls `prepare_delegate_psbts`, and returns sighashes that need
    /// FROST signing (intent proof + all forfeit PSBTs).
    pub fn generate_delegate(
        owner_pk_hex: &str,
        asp_pk_hex: &str,
        forfeit_pk_hex: &str,
        delegate_cosigner_secret_hex: &str,
        vtxo_inputs: &[DelegateVtxoInput],
        outputs: &[DelegateOutput],
        forfeit_address: &str,
        dust_sats: u64,
        exit_delay: u32,
        network_str: &str,
    ) -> Result<(Self, Vec<[u8; 32]>), String> {
        let secp = Secp256k1::new();
        let network = parse_network(network_str)?;

        let owner_pk = parse_xonly(owner_pk_hex)?;
        let asp_pk = parse_xonly(asp_pk_hex)?;
        let forfeit_pk = parse_xonly(forfeit_pk_hex)?;

        let exit_seq = ark_core::server::parse_sequence_number(exit_delay as i64)
            .map_err(|e| format!("invalid exit_delay: {e}"))?;

        // Build delegate cosigner keypair from server's DKG secret.
        let cosigner_secret_bytes = hex_decode_32(delegate_cosigner_secret_hex)?;
        let cosigner_secret = bitcoin::secp256k1::SecretKey::from_slice(&cosigner_secret_bytes)
            .map_err(|e| format!("invalid delegate cosigner secret: {e}"))?;
        let delegate_cosigner_kp = Keypair::from_secret_key(&secp, &cosigner_secret);
        let delegate_cosigner_pk = delegate_cosigner_kp.public_key();

        // Reconstruct default VTXO for spend info.
        let vtxo = ark_core::Vtxo::new_default(&secp, asp_pk, owner_pk, exit_seq, network)
            .map_err(|e| format!("Vtxo::new_default: {e}"))?;
        let forfeit_spend_info = vtxo
            .forfeit_spend_info()
            .map_err(|e| format!("forfeit_spend_info: {e}"))?;
        let tapscripts = vtxo.tapscripts();
        let vtxo_script_pubkey = vtxo.script_pubkey();

        // Build intent::Input for each VTXO.
        let intent_inputs: Vec<ark_core::intent::Input> = vtxo_inputs
            .iter()
            .map(|vi| {
                let outpoint = OutPoint {
                    txid: vi.txid.parse().map_err(|e| format!("invalid txid: {e}"))?,
                    vout: vi.vout,
                };
                Ok(ark_core::intent::Input::new(
                    outpoint,
                    exit_seq,
                    None,
                    TxOut {
                        value: Amount::from_sat(vi.amount_sats),
                        script_pubkey: vtxo_script_pubkey.clone(),
                    },
                    tapscripts.clone(),
                    forfeit_spend_info.clone(),
                    false, // is_onchain = false (existing VTXOs)
                    vi.is_swept,
                ))
            })
            .collect::<Result<Vec<_>, String>>()?;

        // Build intent::Output for each destination.
        let intent_outputs: Vec<ark_core::intent::Output> = outputs
            .iter()
            .map(|o| {
                let ark_addr: ark_core::ArkAddress = o.ark_address.parse()
                    .map_err(|e| format!("invalid ark address: {e}"))?;
                Ok(ark_core::intent::Output::Offchain(TxOut {
                    value: Amount::from_sat(o.amount_sats),
                    script_pubkey: ark_addr.to_p2tr_script_pubkey(),
                }))
            })
            .collect::<Result<Vec<_>, String>>()?;

        // Parse forfeit address.
        let forfeit_addr: bitcoin::Address<bitcoin::address::NetworkUnchecked> =
            forfeit_address.parse()
                .map_err(|e| format!("invalid forfeit address: {e}"))?;
        let forfeit_addr = forfeit_addr.require_network(network)
            .map_err(|e| format!("forfeit address network mismatch: {e}"))?;

        // Prepare delegate PSBTs (intent proof + forfeit PSBTs).
        let delegate = ark_core::batch::prepare_delegate_psbts(
            intent_inputs,
            intent_outputs,
            delegate_cosigner_pk,
            &forfeit_addr,
            Amount::from_sat(dust_sats),
        ).map_err(|e| format!("prepare_delegate_psbts: {e}"))?;

        // Compute all sighashes that need FROST signing.
        let mut sighashes = Vec::new();
        let mut sighash_meta = Vec::new();

        // Intent proof PSBT sighashes.
        Self::collect_psbt_sighashes(
            &delegate.intent.proof,
            0, // psbt_type = intent
            &mut sighashes,
            &mut sighash_meta,
        )?;

        // Forfeit PSBT sighashes.
        for (fi, forfeit_psbt) in delegate.forfeit_psbts.iter().enumerate() {
            Self::collect_forfeit_psbt_sighashes(
                forfeit_psbt,
                fi + 1, // psbt_type = forfeit index + 1
                &mut sighashes,
                &mut sighash_meta,
            )?;
        }

        let session = DelegateSettleSession {
            phase: DelegatePhase::AwaitingSignatures,
            owner_pk,
            asp_pk,
            forfeit_pk,
            network,
            exit_delay: exit_seq,
            delegate,
            delegate_cosigner_kp,
            sighash_meta,
            batch_id: None,
            batch_expiry: None,
            vtxo_graph_chunks: Vec::new(),
            connector_graph_chunks: Vec::new(),
            vtxo_graph: None,
            nonce_kps: None,
            commitment_psbt: None,
            pending_nonces: HashMap::new(),
        };

        Ok((session, sighashes))
    }

    /// Compute taproot script-path sighashes for intent proof PSBT inputs.
    fn collect_psbt_sighashes(
        psbt: &Psbt,
        psbt_type: usize,
        sighashes: &mut Vec<[u8; 32]>,
        meta: &mut Vec<SighashEntry>,
    ) -> Result<(), String> {
        let prevouts: Vec<TxOut> = psbt
            .inputs
            .iter()
            .filter_map(|i| i.witness_utxo.clone())
            .collect();

        for (i, psbt_input) in psbt.inputs.iter().enumerate() {
            let (_, (script, leaf_version)) = match psbt_input.tap_scripts.first_key_value() {
                Some(kv) => kv,
                None => continue, // skip inputs without tap_scripts
            };

            let leaf_hash = TapLeafHash::from_script(script, *leaf_version);
            let prevs = Prevouts::All(&prevouts);

            let tap_sighash = SighashCache::new(&psbt.unsigned_tx)
                .taproot_script_spend_signature_hash(
                    i,
                    &prevs,
                    leaf_hash,
                    TapSighashType::Default,
                )
                .map_err(|e| format!("intent sighash error input {i}: {e}"))?;

            sighashes.push(tap_sighash.to_raw_hash().to_byte_array());
            meta.push(SighashEntry {
                psbt_type,
                input_idx: i,
                leaf_hash,
            });
        }
        Ok(())
    }

    /// Compute taproot script-path sighashes for forfeit PSBT inputs
    /// (using SIGHASH_ALL | ANYONECANPAY).
    fn collect_forfeit_psbt_sighashes(
        psbt: &Psbt,
        psbt_type: usize,
        sighashes: &mut Vec<[u8; 32]>,
        meta: &mut Vec<SighashEntry>,
    ) -> Result<(), String> {
        // Forfeit PSBTs have a single VTXO input at index 0.
        if psbt.inputs.is_empty() {
            return Ok(());
        }

        let psbt_input = &psbt.inputs[0];
        let (_, (script, leaf_version)) = psbt_input
            .tap_scripts
            .first_key_value()
            .ok_or("forfeit PSBT missing tap_scripts")?;

        let leaf_hash = TapLeafHash::from_script(script, *leaf_version);

        let prevouts: Vec<TxOut> = psbt
            .inputs
            .iter()
            .filter_map(|i| i.witness_utxo.clone())
            .collect();
        let prevs = Prevouts::All(&prevouts);

        let tap_sighash = SighashCache::new(&psbt.unsigned_tx)
            .taproot_script_spend_signature_hash(
                0,
                &prevs,
                leaf_hash,
                TapSighashType::AllPlusAnyoneCanPay,
            )
            .map_err(|e| format!("forfeit sighash error: {e}"))?;

        sighashes.push(tap_sighash.to_raw_hash().to_byte_array());
        meta.push(SighashEntry {
            psbt_type,
            input_idx: 0,
            leaf_hash,
        });
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// DelegateSettleSession – FROST signature insertion
// ---------------------------------------------------------------------------

impl DelegateSettleSession {
    /// Insert FROST signatures into the intent proof and forfeit PSBTs.
    ///
    /// `signatures` must match the sighashes returned by `generate_delegate`.
    pub fn sign_with_frost(
        &mut self,
        signatures: Vec<[u8; 64]>,
    ) -> Result<(), String> {
        if !matches!(self.phase, DelegatePhase::AwaitingSignatures) {
            return Err("sign_with_frost called in wrong phase".into());
        }
        if signatures.len() != self.sighash_meta.len() {
            return Err(format!(
                "expected {} signatures, got {}",
                self.sighash_meta.len(),
                signatures.len()
            ));
        }

        for (sig_bytes, entry) in signatures.iter().zip(self.sighash_meta.iter()) {
            let schnorr_sig = bitcoin::secp256k1::schnorr::Signature::from_slice(sig_bytes)
                .map_err(|e| format!("invalid schnorr sig: {e}"))?;

            let sighash_type = if entry.psbt_type == 0 {
                TapSighashType::Default
            } else {
                TapSighashType::AllPlusAnyoneCanPay
            };

            let sig = taproot::Signature {
                signature: schnorr_sig,
                sighash_type,
            };

            let psbt_input = if entry.psbt_type == 0 {
                &mut self.delegate.intent.proof.inputs[entry.input_idx]
            } else {
                let fi = entry.psbt_type - 1;
                &mut self.delegate.forfeit_psbts[fi].inputs[entry.input_idx]
            };

            psbt_input
                .tap_script_sigs
                .insert((self.owner_pk, entry.leaf_hash), sig);
        }

        self.phase = DelegatePhase::ReadyToSettle;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// DelegateSettleSession – batch driving
// ---------------------------------------------------------------------------

impl DelegateSettleSession {
    /// Drive the entire batch protocol autonomously.
    ///
    /// This registers the pre-signed intent, subscribes to the event stream,
    /// and handles all batch events including MuSig2 tree signing (using the
    /// delegate cosigner key) and forfeit completion.
    ///
    /// Returns `(commitment_txid, vtxo_outpoint)` on success.
    pub async fn settle(&mut self, asp: &mut AspClient) -> Result<(String, Option<(String, u32)>), String> {
        if !matches!(self.phase, DelegatePhase::ReadyToSettle) {
            return Err("settle called in wrong phase".into());
        }
        self.phase = DelegatePhase::Settling;

        // Register the pre-signed intent.
        let proof_b64 = encode_psbt_b64(&self.delegate.intent.proof);
        let message_json = self.delegate.intent.serialize_message()
            .map_err(|e| format!("serialize intent message: {e}"))?;

        let intent_id = asp
            .register_intent(proof_b64, message_json)
            .await
            .map_err(|e| format!("register_intent: {e}"))?;

        // Open event stream with VTXO outpoint + cosigner key topics.
        let mut topics = Vec::new();

        // Add VTXO input outpoints as topics.
        for input in &self.delegate.intent.proof.unsigned_tx.input {
            topics.push(input.previous_output.to_string());
        }

        // Add cosigner public key as hex topic.
        let cosigner_bytes = self.delegate_cosigner_kp.public_key().serialize();
        let cosigner_topic: String = cosigner_bytes.iter()
            .map(|b| format!("{b:02x}"))
            .collect();
        topics.push(cosigner_topic);

        eprintln!("delegate: event stream topics: {topics:?}");

        let mut stream = asp
            .get_event_stream(topics)
            .await
            .map_err(|e| format!("get_event_stream: {e}"))?;

        // Event loop.
        use tokio_stream::StreamExt;
        loop {
            let msg = stream
                .next()
                .await
                .ok_or("event stream ended unexpectedly")?
                .map_err(|e| format!("stream error: {e}"))?;

            let event = match msg.event {
                Some(e) => e,
                None => continue,
            };

            match event {
                Event::BatchStarted(e) => {
                    eprintln!("delegate: BatchStarted id={}", e.id);
                    self.batch_id = Some(e.id.clone());
                    if e.batch_expiry > 0 {
                        self.batch_expiry = Some(
                            ark_core::server::parse_sequence_number(e.batch_expiry)
                                .map_err(|e| format!("parse batch_expiry: {e}"))?,
                        );
                    }
                    asp.confirm_registration(intent_id.clone())
                        .await
                        .map_err(|e| format!("confirm_registration: {e}"))?;
                }
                Event::TreeTx(e) => {
                    eprintln!("delegate: TreeTx txid={} topic={:?}", e.txid, e.topic);
                    let psbt = decode_psbt_b64(&e.tx)?;
                    let children: HashMap<u32, Txid> = e
                        .children
                        .into_iter()
                        .map(|(vout, txid_str)| {
                            let txid: Txid = txid_str
                                .parse()
                                .map_err(|e| format!("invalid child txid: {e}"))?;
                            Ok((vout, txid))
                        })
                        .collect::<Result<_, String>>()?;
                    let txid = if e.txid.is_empty() {
                        None
                    } else {
                        Some(e.txid.parse().map_err(|e| format!("invalid txid: {e}"))?)
                    };

                    // Determine if this is a VTXO graph chunk or connector chunk.
                    // Connector chunks have topic containing the cosigner key.
                    let cosigner_pk_hex = self.delegate_cosigner_kp.public_key().to_string();
                    let chunk = TxGraphChunk { txid, tx: psbt, children };
                    if e.topic.iter().any(|t| t == &cosigner_pk_hex) {
                        self.connector_graph_chunks.push(chunk);
                    } else {
                        self.vtxo_graph_chunks.push(chunk);
                    }
                }
                Event::TreeSigningStarted(e) => {
                    eprintln!(
                        "delegate: TreeSigningStarted cosigners={} vtxo_chunks={} connector_chunks={}",
                        e.cosigners_pubkeys.len(),
                        self.vtxo_graph_chunks.len(),
                        self.connector_graph_chunks.len(),
                    );

                    let commitment_psbt = decode_psbt_b64(&e.unsigned_commitment_tx)?;

                    if self.vtxo_graph_chunks.is_empty() {
                        return Err("no VTXO tree tx chunks collected".into());
                    }

                    let vtxo_graph =
                        TxGraph::new(self.vtxo_graph_chunks.drain(..).collect())
                            .map_err(|e| format!("TxGraph::new: {e}"))?;

                    let cosigner_pk = self.delegate_cosigner_kp.public_key();
                    let nonce_kps = {
                        let mut rng = rand::thread_rng();
                        generate_nonce_tree(&mut rng, &vtxo_graph, cosigner_pk, &commitment_psbt)
                            .map_err(|e| format!("generate_nonce_tree: {e}"))?
                    };

                    let nonce_pks = nonce_kps.to_nonce_pks();
                    let nonce_map = nonce_pks.encode();
                    let batch_id = self.batch_id.as_ref().ok_or("no batch_id")?.clone();
                    let cosigner_pk_hex = cosigner_pk.to_string();

                    asp.submit_tree_nonces(&batch_id, cosigner_pk_hex, nonce_map)
                        .await
                        .map_err(|e| format!("submit_tree_nonces: {e}"))?;

                    self.nonce_kps = Some(nonce_kps);
                    self.vtxo_graph = Some(vtxo_graph);
                    self.commitment_psbt = Some(commitment_psbt);
                }
                Event::TreeNonces(e) => {
                    let txid: Txid = e.txid.parse()
                        .map_err(|e| format!("invalid txid: {e}"))?;

                    // Accumulate raw nonces per txid.
                    self.pending_nonces.insert(txid, e.nonces);

                    let vtxo_graph = self.vtxo_graph.as_ref().ok_or("no vtxo_graph")?;
                    let expected = vtxo_graph.nb_of_nodes();

                    eprintln!(
                        "delegate: TreeNonces txid={txid}, {}/{} collected",
                        self.pending_nonces.len(),
                        expected
                    );

                    // Only sign once ALL nonces collected.
                    if self.pending_nonces.len() >= expected {
                        let batch_id = self.batch_id.as_ref().ok_or("no batch_id")?.clone();
                        let commitment_psbt = self.commitment_psbt.as_ref().ok_or("no commitment_psbt")?;
                        let nonce_kps = self.nonce_kps.as_mut().ok_or("no nonce_kps")?;
                        let batch_expiry = self.batch_expiry.ok_or("no batch_expiry")?;

                        let mut combined_sigs = PartialSigTree::default();

                        for (tree_txid, _) in vtxo_graph.as_map() {
                            let raw_nonces = self.pending_nonces.get(&tree_txid)
                                .ok_or_else(|| format!("missing nonces for {tree_txid}"))?;

                            let tree_tx_nonce_pks =
                                ark_core::server::TreeTxNoncePks::decode(raw_nonces.clone())
                                    .map_err(|e| format!("decode TreeTxNoncePks: {e}"))?;
                            let agg_nonce = aggregate_nonces(tree_tx_nonce_pks);

                            let partial_sig = sign_batch_tree_tx(
                                tree_txid,
                                batch_expiry,
                                self.forfeit_pk,
                                &self.delegate_cosigner_kp,
                                agg_nonce,
                                vtxo_graph,
                                commitment_psbt,
                                nonce_kps,
                            )
                            .map_err(|e| format!("sign_batch_tree_tx: {e}"))?;

                            combined_sigs.0.extend(partial_sig.0);
                        }

                        let sig_map = combined_sigs.encode();
                        let cosigner_pk_hex = self.delegate_cosigner_kp.public_key().to_string();

                        asp.submit_tree_signatures(&batch_id, cosigner_pk_hex, sig_map)
                            .await
                            .map_err(|e| format!("submit_tree_signatures: {e}"))?;

                        self.pending_nonces.clear();
                    }
                }
                Event::TreeNoncesAggregated(_) | Event::TreeSignature(_) => {
                    // Already handled signing in TreeNonces.
                }
                Event::BatchFinalization(e) => {
                    eprintln!("delegate: BatchFinalization id={}", e.id);

                    // Build connectors graph from collected connector chunks.
                    let connector_leaves: Vec<Psbt> = self
                        .connector_graph_chunks
                        .iter()
                        .map(|c| c.tx.clone())
                        .collect();
                    let connector_refs: Vec<&Psbt> =
                        connector_leaves.iter().collect();

                    // Complete the pre-signed forfeit PSBTs by adding connector inputs.
                    let completed_forfeits =
                        ark_core::batch::complete_delegate_forfeit_txs(
                            &self.delegate.forfeit_psbts,
                            &connector_refs,
                        )
                        .map_err(|e| format!("complete_delegate_forfeit_txs: {e}"))?;

                    // Serialize completed forfeits.
                    let signed_forfeits: Vec<String> = completed_forfeits
                        .iter()
                        .map(|p| encode_psbt_b64(p))
                        .collect();

                    // No commitment signing needed — forfeits handle it.
                    asp.submit_signed_forfeit_txs(signed_forfeits, String::new())
                        .await
                        .map_err(|e| format!("submit_signed_forfeit_txs: {e}"))?;
                }
                Event::BatchFinalized(e) => {
                    eprintln!("delegate: BatchFinalized txid={}", e.commitment_txid);
                    self.phase = DelegatePhase::Done;
                    let vtxo_outpoint = self.vtxo_graph.as_ref().map(|g| {
                        let leaf = first_tree_leaf(g);
                        (leaf.unsigned_tx.compute_txid().to_string(), 0u32)
                    });
                    return Ok((e.commitment_txid, vtxo_outpoint));
                }
                Event::BatchFailed(e) => {
                    return Err(format!("batch failed: {}", e.reason));
                }
                Event::Heartbeat(_) | Event::StreamStarted(_) => {}
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn parse_xonly(hex: &str) -> Result<XOnlyPublicKey, String> {
    // Accept both 64-char x-only and 66-char compressed.
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

fn decode_psbt_b64(b64: &str) -> Result<Psbt, String> {
    let engine = base64::engine::GeneralPurpose::new(
        &base64::alphabet::STANDARD,
        base64::engine::GeneralPurposeConfig::new(),
    );
    let bytes = engine
        .decode(b64)
        .map_err(|e| format!("base64 decode: {e}"))?;
    Psbt::deserialize(&bytes).map_err(|e| format!("PSBT deserialize: {e}"))
}

fn encode_psbt_b64(psbt: &Psbt) -> String {
    let engine = base64::engine::GeneralPurpose::new(
        &base64::alphabet::STANDARD,
        base64::engine::GeneralPurposeConfig::new(),
    );
    engine.encode(psbt.serialize())
}

/// Compute the BIP-322 intent message hash using the same tagged hash
/// construction as ark-core.
fn intent_message_hash(message: &[u8]) -> sha256::Hash {
    const TAG: &[u8] = b"ark-intent-proof-message";
    let hashed_tag = sha256::Hash::hash(TAG);

    let mut v = Vec::new();
    v.extend_from_slice(hashed_tag.as_byte_array());
    v.extend_from_slice(hashed_tag.as_byte_array());
    v.extend_from_slice(message);

    sha256::Hash::hash(&v)
}

/// Build the BIP-322 "to_spend" transaction for intent proofs.
fn build_to_spend_tx(message_json: &str, script_pubkey: &ScriptBuf) -> Transaction {
    let hash = intent_message_hash(message_json.as_bytes());

    let script_sig = ScriptBuf::builder()
        .push_opcode(bitcoin::opcodes::OP_0)
        .push_slice(hash.as_byte_array())
        .into_script();

    Transaction {
        version: Version::non_standard(0),
        lock_time: absolute::LockTime::ZERO,
        input: vec![TxIn {
            previous_output: OutPoint {
                txid: Txid::all_zeros(),
                vout: 0xFFFFFFFF,
            },
            script_sig,
            sequence: Sequence::ZERO,
            witness: Witness::default(),
        }],
        output: vec![TxOut {
            value: Amount::ZERO,
            script_pubkey: script_pubkey.clone(),
        }],
    }
}

/// Encode a list of tapscripts in the format used by ark-core's PSBT
/// unknown field (key type 222, key "taptree").
///
/// Format: for each script: [depth=1] [leaf_version=0xc0] [compact_size(len)]
/// [script_bytes].
fn encode_taptree(tapscripts: &[ScriptBuf]) -> Vec<u8> {
    let mut buf = Vec::new();
    for script in tapscripts {
        buf.push(1); // depth
        buf.push(0xc0); // leaf version (base tapscript)
        write_compact_size(&mut buf, script.len() as u64);
        buf.extend(script.as_bytes());
    }
    buf
}

/// Write a Bitcoin compact-size uint.
fn write_compact_size(w: &mut Vec<u8>, val: u64) {
    if val < 253 {
        w.push(val as u8);
    } else if val < 0x10000 {
        w.push(253);
        w.extend_from_slice(&(val as u16).to_le_bytes());
    } else if val < 0x100000000 {
        w.push(254);
        w.extend_from_slice(&(val as u32).to_le_bytes());
    } else {
        w.push(255);
        w.extend_from_slice(&val.to_le_bytes());
    }
}

/// Get the first leaf PSBT from a TxGraph.
fn first_tree_leaf(graph: &TxGraph) -> &Psbt {
    let leaves = graph.leaves();
    leaves.into_iter().next().unwrap_or_else(|| graph.root())
}

/// Decode a 64-char hex string into a 32-byte array.
fn hex_decode_32(hex: &str) -> Result<[u8; 32], String> {
    if hex.len() != 64 {
        return Err(format!("expected 64 hex chars, got {}", hex.len()));
    }
    let mut out = [0u8; 32];
    for i in 0..32 {
        out[i] = u8::from_str_radix(&hex[i * 2..i * 2 + 2], 16)
            .map_err(|e| format!("hex decode error at byte {i}: {e}"))?;
    }
    Ok(out)
}
