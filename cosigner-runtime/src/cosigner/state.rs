//! Per-user mutable state. Owned by the user's actor task; never shared.

use std::collections::HashSet;

use serde::{Deserialize, Serialize};
use tokio::sync::oneshot;
use tonic::Status;

use crate::wallet_proto::*;
use crate::cosigner::types::ArkTxEntry;

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
}

impl Default for CosignerState {
    fn default() -> Self {
        Self::new(String::new())
    }
}
