//! Per-user mutable state. Owned by the user's actor task; never shared.

use std::collections::HashSet;

use tokio::sync::oneshot;
use tonic::Status;

use crate::wallet_proto::*;
use crate::cosigner::types::ArkTxEntry;

pub struct CosignerState {
    /// Schnorr-auth replay cache. Bounded LRU; keyed by `timestamp_ms` since
    /// the auth verifier already binds the signature to (timestamp, op, user).
    pub used_nonces: HashSet<i64>,

    /// Active settle (boarding) session: `(session, boarding_amount_sats, exit_delay)`.
    pub settle_session: Option<(ark::client::batch::SettleSession, u64, u32)>,
    /// Active delegate-settle session.
    pub delegate_session: Option<ark::client::batch::DelegateSettleSession>,
    /// Active send session: `(session, exit_delay)`.
    pub send_session: Option<(ark::client::send::SendSession, u32)>,

    /// VTXOs: `(txid, vout, amount_sats, exit_delay)`.
    pub vtxos: Vec<(String, u32, u64, u32)>,
    /// Ark transaction history (oldest first).
    pub ark_tx_history: Vec<ArkTxEntry>,
    /// VTXO scriptPubKeys this user owns. Used by the registry's reverse index.
    pub owned_scripts: Vec<String>,

    // Rendezvous: each multi-participant step stashes replies here until the
    // round completes, then drains and fulfils.
    pub pending_dkg_step1: Vec<oneshot::Sender<Result<DkgStep1Response, Status>>>,
    pub pending_dkg_step2: Vec<oneshot::Sender<Result<DkgStep2Response, Status>>>,
    /// `(caller_identifier_hex, reply)` — step3 needs the caller identifier
    /// to build the per-recipient relay package.
    pub pending_dkg_step3: Vec<(String, oneshot::Sender<Result<DkgStep3Response, Status>>)>,
    pub pending_sign_step1: Vec<oneshot::Sender<Result<SignStep1Response, Status>>>,
    pub pending_sign_step2: Vec<oneshot::Sender<Result<SignStep2Response, Status>>>,
    pub pending_refresh_step1: Vec<oneshot::Sender<Result<RefreshStep1Response, Status>>>,
    pub pending_refresh_step2: Vec<oneshot::Sender<Result<RefreshStep2Response, Status>>>,
    pub pending_refresh_step3: Vec<oneshot::Sender<Result<RefreshStep3Response, Status>>>,
}

impl CosignerState {
    pub fn new() -> Self {
        Self {
            used_nonces: HashSet::new(),
            settle_session: None,
            delegate_session: None,
            send_session: None,
            vtxos: Vec::new(),
            ark_tx_history: Vec::new(),
            owned_scripts: Vec::new(),
            pending_dkg_step1: Vec::new(),
            pending_dkg_step2: Vec::new(),
            pending_dkg_step3: Vec::new(),
            pending_sign_step1: Vec::new(),
            pending_sign_step2: Vec::new(),
            pending_refresh_step1: Vec::new(),
            pending_refresh_step2: Vec::new(),
            pending_refresh_step3: Vec::new(),
        }
    }

    /// Trim the nonce cache when it grows beyond `cap`. Cheap O(cap) clear when
    /// triggered; the auth verifier's timestamp window already prevents
    /// long-term replay so we don't need a true LRU.
    pub fn note_nonce(&mut self, ts: i64, cap: usize) {
        if self.used_nonces.len() >= cap {
            self.used_nonces.clear();
        }
        self.used_nonces.insert(ts);
    }
}

impl Default for CosignerState {
    fn default() -> Self {
        Self::new()
    }
}
