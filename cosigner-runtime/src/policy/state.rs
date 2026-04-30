use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Per-user policy state. Mirrors `PolicyState` from `server/lib/state.dart`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PolicyState {
    pub user_id: String,
    /// Recovery ID: hex of HW signer's verifying key (for wallet restore lookup).
    pub recovery_id: String,
    /// The wallet's DKG identifier (may differ from Identifier::derive(userId)
    /// when the wallet is a passive receiver).
    pub user_signing_identifier_hex: Option<String>,
    /// Server's original DKG secret (hex-encoded 32-byte scalar).
    /// Persisted separately via SecretStore (not included in storage JSON).
    #[serde(skip)]
    pub server_dkg_secret_hex: Option<String>,
    /// Normal (default) spending policy.
    pub normal_policy: NormalPolicy,
    /// Protected spending policies (policy_id -> ProtectedPolicy).
    #[serde(default)]
    pub protected_policies: HashMap<String, ProtectedPolicy>,
    /// Spending history entries.
    #[serde(default)]
    pub spending_history: Vec<SpendingEntry>,
}

/// Normal (default) spending policy.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NormalPolicy {
    pub id: String,
    /// Key package as JSON string (from WASM).
    pub key_package_json: String,
    /// Public key package as JSON string (from WASM).
    pub public_key_package_json: String,
}

/// Protected spending policy with threshold and time interval.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProtectedPolicy {
    pub id: String,
    pub threshold_sats: i64,
    pub start_time_ms: i64,
    pub interval_seconds: i64,
    /// Key package as JSON string.
    pub key_package_json: String,
    /// Public key package as JSON string.
    pub public_key_package_json: String,
}

/// A spending history entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpendingEntry {
    pub timestamp_ms: i64,
    pub amount_sats: i64,
}

/// Per-user UTXO cache.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct UtxoState {
    pub user_id: String,
    pub utxos: Vec<Utxo>,
}

/// A single unspent transaction output.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Utxo {
    pub tx_hash: String,
    pub vout: u32,
    pub amount_sats: i64,
}
