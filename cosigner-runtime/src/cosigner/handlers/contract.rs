//! Peer-contract share inbox.
//!
//! When a wallet creates a contract WITH a receiver (another user), the cosigner drops both
//! ECIES halves of the receiver's refreshed share — the wallet's `a@receiver` and the
//! cosigner's `b@receiver` — into the receiver's pickup inbox, keyed by the receiver's
//! verifying key. `evtxo_pending_shares` / `evtxo_ack_share` run on the RECEIVER's OWN actor:
//! it fetches the ciphertexts, decrypts BOTH with its signing secret, sums them into its share
//! `P = a@receiver + b@receiver`, then acks to clear. Neither the author nor the cosigner ever
//! learns `P`. The inbox write itself lives in `contract::manager::create_contract`.

use serde::{Deserialize, Serialize};
use tonic::Status;

use crate::cosigner::actor::CosignerActor;
use crate::cosigner::handlers::parsers;
use crate::cosigner::registry::run_blocking;
use crate::kv_store::KvStore;
use crate::wallet_proto::{
    EvtxoAckShareRequest, EvtxoAckShareResponse, EvtxoPendingSharesRequest,
    EvtxoPendingSharesResponse, PendingContractShare,
};

pub const PENDING_TREE: &str = "pending_contract_shares";

/// One contract-share held for a receiver until it picks it up (ciphertext only).
#[derive(Serialize, Deserialize, Clone)]
pub struct PendingShareRecord {
    pub spk_hex: String,
    pub contract_id_hex: String,
    pub ecies_author_hex: String,
    pub ecies_cosigner_hex: String,
    pub pkp_json: String,
    pub exit_delay: u32,
    pub server_pk_xonly_hex: String,
    pub owner_pk_xonly_hex: String,
}

pub fn load_pending(persistence: &dyn KvStore, vk_hex: &str) -> Vec<PendingShareRecord> {
    match persistence.get(PENDING_TREE, vk_hex) {
        Ok(Some(json)) => serde_json::from_str(&json).unwrap_or_default(),
        _ => Vec::new(),
    }
}

pub fn save_pending(
    persistence: &dyn KvStore,
    vk_hex: &str,
    records: &[PendingShareRecord],
) -> Result<(), Status> {
    let json = serde_json::to_string(records)
        .map_err(|e| Status::internal(format!("encode pending shares: {e}")))?;
    persistence
        .put(PENDING_TREE, vk_hex, &json)
        .map_err(|e| Status::internal(format!("persist pending shares: {e}")))
}

/// Drop (or replace) a contract-share into the receiver's inbox. Called by contract-create
/// once both ECIES halves are in hand.
pub fn write_pending_share(
    persistence: &dyn KvStore,
    receiver_vk_hex: &str,
    record: PendingShareRecord,
) -> Result<(), Status> {
    let mut pending = load_pending(persistence, receiver_vk_hex);
    pending.retain(|r| r.spk_hex != record.spk_hex); // one per eVTXO
    pending.push(record);
    save_pending(persistence, receiver_vk_hex, &pending)
}

/// Fetch the contract shares held for the calling receiver (its own actor's inbox).
impl CosignerActor {
    pub async fn evtxo_pending_shares(
        &mut self,
        req: EvtxoPendingSharesRequest,
    ) -> Result<EvtxoPendingSharesResponse, Status> {
        let shared = self.shared.clone();
        let span = tracing::info_span!("actor::evtxo_pending_shares", user_id = %parsers::user_id_hex(&req.user_id));
        run_blocking(self.state.clone(), move |_state| {
            let _enter = span.enter();
            let shared = shared.as_ref();
            let user_id_hex = parsers::user_id_hex(&req.user_id);
            // Auth (OP_EVTXO_PENDING) ran at the REST boundary.

            let pending = load_pending(shared.persistence.as_ref(), &user_id_hex);
            let shares = pending
                .into_iter()
                .map(|r| PendingContractShare {
                    evtxo_script_pubkey: hex::decode(&r.spk_hex).unwrap_or_default(),
                    contract_id: hex::decode(&r.contract_id_hex).unwrap_or_default(),
                    ecies_half_author: hex::decode(&r.ecies_author_hex).unwrap_or_default(),
                    ecies_half_cosigner: hex::decode(&r.ecies_cosigner_hex).unwrap_or_default(),
                    public_key_package_json: r.pkp_json,
                    exit_delay: r.exit_delay,
                    server_pk: hex::decode(&r.server_pk_xonly_hex).unwrap_or_default(),
                    owner_pk: hex::decode(&r.owner_pk_xonly_hex).unwrap_or_default(),
                })
                .collect();
            Ok(EvtxoPendingSharesResponse { shares })
        })
        .await
    }
}

/// Clear a picked-up contract share from the receiver's inbox.
impl CosignerActor {
    pub async fn evtxo_ack_share(
        &mut self,
        req: EvtxoAckShareRequest,
    ) -> Result<EvtxoAckShareResponse, Status> {
        let shared = self.shared.clone();
        let span = tracing::info_span!("actor::evtxo_ack_share", user_id = %parsers::user_id_hex(&req.user_id));
        run_blocking(self.state.clone(), move |_state| {
            let _enter = span.enter();
            let shared = shared.as_ref();
            let user_id_hex = parsers::user_id_hex(&req.user_id);
            // Auth (OP_EVTXO_ACK) ran at the REST boundary.

            let spk_hex = hex::encode(&req.evtxo_script_pubkey);
            let mut pending = load_pending(shared.persistence.as_ref(), &user_id_hex);
            pending.retain(|r| r.spk_hex != spk_hex);
            save_pending(shared.persistence.as_ref(), &user_id_hex, &pending)?;
            Ok(EvtxoAckShareResponse { ok: true })
        })
        .await
    }
}
