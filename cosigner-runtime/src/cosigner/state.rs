//! Per-user mutable state. Owned by the user's actor task; never shared.

use serde::{Deserialize, Serialize};

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
    /// This cosigner actor's id (hex), set by the registry at spawn time — the
    /// GROUP KEY it co-signs for: `V` for a normal 2-of-2 wallet, `V′` for a
    /// contract. NOT "one user": a contract actor serves many members, each
    /// authenticated by their own verifying share (see `group_auth_idx` +
    /// `EvtxoPolicy.recipient_shares`). Handlers use it to scope persistence keys
    /// and as the group id for `auth_check_group`.
    pub cosigner_id: String,

    /// Active settle (boarding) session: `(session, boarding_amount_sats, exit_delay)`.
    pub settle_session: Option<(ark::client::batch::SettleSession, u64, u32)>,
    /// Plan A: progress through the GUEST-driven boarding settle — `(step, amount_sats, exit_delay)`.
    /// step 1 = awaiting intent FROST sigs, 2 = awaiting commitment FROST sigs. The session + open
    /// stream live in the GUEST; the host only relays the two FROST rounds and records the result.
    pub guest_boarding: Option<(u8, u64, u32)>,
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

    /// Guest-routed delegate-settle marker: the threshold timestamp (`intent_valid_at`, i.e.
    /// earliest VTXO expiry − safety margin) at/after which `TickAutoSettle` should drive the
    /// guest's stored `ReadyToSettle` delegate. The delegate session itself lives in the
    /// guest (durable via the sealed snapshot); this is the non-secret "when to fire" gate.
    /// `Some(0)` means fire on the next tick (legacy short window). Cleared after settling.
    pub guest_delegate_threshold: Option<i64>,

    /// Non-secret policy metadata (FROST *public* key package JSON, signing identifier,
    /// cosigner_id) loaded from persistence. Used for routing + address/amount derivation;
    /// the signing keys themselves live in the guest. Formerly on `CosignerInstance`.
    pub policy_state: Option<crate::policy::PolicyState>,
    /// The user's UTXOs, for tx-parse / spent-amount calculation. Formerly on `CosignerInstance`.
    pub utxo_state: Option<crate::policy::state::UtxoState>,
}

impl CosignerState {
    pub fn new(cosigner_id: String) -> Self {
        Self {
            cosigner_id,
            settle_session: None,
            guest_boarding: None,
            delegate_session: None,
            send_session: None,
            vtxos: Vec::new(),
            ark_tx_history: Vec::new(),
            owned_scripts: Vec::new(),
            device_tokens: Vec::new(),
            guest_delegate_threshold: None,
            policy_state: None,
            utxo_state: None,
        }
    }
}

impl Default for CosignerState {
    fn default() -> Self {
        Self::new(String::new())
    }
}
