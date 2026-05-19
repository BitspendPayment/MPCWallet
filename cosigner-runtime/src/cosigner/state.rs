//! Per-user mutable state. Owned by the user's actor task; never shared.

use std::collections::HashSet;

use serde::{Deserialize, Serialize};
use tokio::sync::oneshot;
use tonic::Status;

use crate::cosigner::types::ArkTxEntry;
use crate::wallet_proto::*;

/// One VTXO owned by the user. Persisted in `vtxo_store`. `created_at` and
/// `expires_at` come from the ASP `Vtxo` event and feed the auto-settle
/// threshold check; older rows lacking them deserialize to 0 (treated as
/// "unknown expiry" — auto-settle skips conservatively).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VtxoEntry {
    pub txid: String,
    pub vout: u32,
    pub amount: u64,
    pub exit_delay: u32,
    #[serde(default)]
    pub created_at: i64,
    #[serde(default)]
    pub expires_at: i64,
}

/// A signed `DelegateSettleSession` waiting for the auto-settle tick task to
/// drive it. `covered_outpoints` is the set of VTXOs the FROST signatures
/// authorize the cosigner to spend; if any of them is consumed by another
/// path (manual settle, send) the whole delegate is invalidated and the
/// client must re-delegate after the next receive.
pub struct DelegateRecord {
    pub session: ark::client::batch::DelegateSettleSession,
    pub covered_outpoints: Vec<(String, u32)>,
    /// Earliest `expires_at` across `covered_outpoints` — what the tick
    /// task compares `now` against.
    pub earliest_expires_at: i64,
    /// True while the cosigner is still waiting on the client's FROST
    /// signature shares for this delegate's sighashes — i.e. between
    /// `SettleDelegate` Phase 1 (returns sighashes) and Phase 2 (receives
    /// signatures). The sign-step1 policy bypass only applies during this
    /// window. Once signatures are stored, the record persists for the
    /// tick task but subsequent unrelated `SignStep1` calls (e.g. an
    /// off-chain Ark send) must again be policy-gated.
    pub awaiting_signatures: bool,
}

/// Sled-persisted projection of a `DelegateRecord`. Mirrors the in-memory
/// shape but uses `PersistedDelegate` (no cosigner secret — looked up from
/// `SecretStore` at rehydration time) so the on-disk JSON contains no
/// long-lived key material. See GitHub issue #31 for the rationale.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersistedDelegateRecord {
    pub session: ark::client::batch::PersistedDelegate,
    pub covered_outpoints: Vec<(String, u32)>,
    pub earliest_expires_at: i64,
}

/// One device the user has registered for FCM push notifications.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceToken {
    pub fcm_token: String,
    pub platform: String,
    pub registered_at: i64,
    #[serde(default)]
    pub app_version: String,
}

pub struct CosignerState {
    /// The user this actor belongs to, hex-encoded. Set by the registry at
    /// spawn time. Used by handlers that don't carry a request payload (e.g.
    /// `TickAutoSettle`) to scope persistence keys.
    pub user_id_hex: String,

    /// Schnorr-auth replay cache. Bounded LRU; keyed by `timestamp_ms` since
    /// the auth verifier already binds the signature to (timestamp, op, user).
    pub used_nonces: HashSet<i64>,

    /// Active settle (boarding) session: `(session, boarding_amount_sats, exit_delay)`.
    pub settle_session: Option<(ark::client::batch::SettleSession, u64, u32)>,
    /// Active delegate-settle session — stored signed intent + scope.
    pub delegate_session: Option<DelegateRecord>,
    /// Active send session: `(session, exit_delay)`.
    pub send_session: Option<(ark::client::send::SendSession, u32)>,

    pub vtxos: Vec<VtxoEntry>,
    /// Ark transaction history (oldest first).
    pub ark_tx_history: Vec<ArkTxEntry>,
    /// VTXO scriptPubKeys this user owns. Used by the registry's reverse index.
    pub owned_scripts: Vec<String>,
    /// Registered FCM/APNS device tokens. Pushes go to all of them.
    pub device_tokens: Vec<DeviceToken>,

    // Rendezvous: each multi-participant step stashes replies here until the
    // round completes, then drains and fulfils.
    pub pending_sign_step1: Vec<oneshot::Sender<Result<SignStep1Response, Status>>>,
    pub pending_sign_step2: Vec<oneshot::Sender<Result<SignStep2Response, Status>>>,
    pub pending_refresh_step1: Vec<oneshot::Sender<Result<RefreshStep1Response, Status>>>,
    pub pending_refresh_step2: Vec<oneshot::Sender<Result<RefreshStep2Response, Status>>>,
    pub pending_refresh_step3: Vec<oneshot::Sender<Result<RefreshStep3Response, Status>>>,
}

impl CosignerState {
    pub fn new(user_id_hex: String) -> Self {
        Self {
            user_id_hex,
            used_nonces: HashSet::new(),
            settle_session: None,
            delegate_session: None,
            send_session: None,
            vtxos: Vec::new(),
            ark_tx_history: Vec::new(),
            owned_scripts: Vec::new(),
            device_tokens: Vec::new(),
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

    /// Drain every `pending_*` rendezvous queue, fulfilling each parked
    /// reply with `Err(Status::internal(msg))`. Called from the actor's
    /// panic-recovery path so multi-party callers (sign, refresh) get a
    /// definitive error instead of hanging on a reply that will never come.
    pub fn drain_pending_replies_with_err(&mut self, msg: &str) {
        fn drain<T>(pool: &mut Vec<oneshot::Sender<Result<T, Status>>>, msg: &str) {
            for tx in pool.drain(..) {
                let _ = tx.send(Err(Status::internal(msg.to_string())));
            }
        }
        drain(&mut self.pending_sign_step1, msg);
        drain(&mut self.pending_sign_step2, msg);
        drain(&mut self.pending_refresh_step1, msg);
        drain(&mut self.pending_refresh_step2, msg);
        drain(&mut self.pending_refresh_step3, msg);
    }
}

impl Default for CosignerState {
    fn default() -> Self {
        Self::new(String::new())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn drain_pending_replies_sends_err_to_every_parked_sender() {
        let mut state = CosignerState::default();

        // Stage one parked sender per pending_* pool so we can prove every
        // pool drains, not just the first one.
        let (tx_s1, rx_s1) = oneshot::channel::<Result<SignStep1Response, Status>>();
        let (tx_s2, rx_s2) = oneshot::channel::<Result<SignStep2Response, Status>>();
        let (tx_r1, rx_r1) = oneshot::channel::<Result<RefreshStep1Response, Status>>();
        let (tx_r2, rx_r2) = oneshot::channel::<Result<RefreshStep2Response, Status>>();
        let (tx_r3, rx_r3) = oneshot::channel::<Result<RefreshStep3Response, Status>>();
        state.pending_sign_step1.push(tx_s1);
        state.pending_sign_step2.push(tx_s2);
        state.pending_refresh_step1.push(tx_r1);
        state.pending_refresh_step2.push(tx_r2);
        state.pending_refresh_step3.push(tx_r3);

        state.drain_pending_replies_with_err("test panic");

        // All pools emptied.
        assert!(state.pending_sign_step1.is_empty());
        assert!(state.pending_sign_step2.is_empty());
        assert!(state.pending_refresh_step1.is_empty());
        assert!(state.pending_refresh_step2.is_empty());
        assert!(state.pending_refresh_step3.is_empty());

        // Every parked receiver resolves with the expected error.
        // (Each oneshot is monomorphic in its response type, so we can't
        //  fold these into a single closure call without erasing types.)
        macro_rules! assert_drained {
            ($rx:expr) => {{
                let inner = $rx.blocking_recv().expect("sender dropped");
                let status = inner.expect_err("expected Err, got Ok");
                assert_eq!(status.code(), tonic::Code::Internal);
                assert_eq!(status.message(), "test panic");
            }};
        }
        assert_drained!(rx_s1);
        assert_drained!(rx_s2);
        assert_drained!(rx_r1);
        assert_drained!(rx_r2);
        assert_drained!(rx_r3);
    }

    #[test]
    fn drain_pending_replies_is_idempotent() {
        let mut state = CosignerState::default();
        // No pending replies — drain should be a no-op and not panic.
        state.drain_pending_replies_with_err("no-op test");
        state.drain_pending_replies_with_err("second drain");
        assert!(state.pending_sign_step1.is_empty());
    }
}
