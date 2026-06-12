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
    /// Programmable eVTXO policies, keyed by eVTXO scriptPubKey (hex). Each binds
    /// a resharing-derived 2-of-2 key V′ to a WASM contract.
    #[serde(default)]
    pub evtxo_policies: HashMap<String, EvtxoPolicy>,
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

/// A programmable eVTXO policy: a fresh 2-of-2 {wallet, cosigner} key `V′`
/// (derived by resharing, excluding the hardware signer) bound to a WASM
/// contract. Spending the eVTXO's cooperative leaf requires `V′`, so the cosigner
/// is a mandatory signer and runs `contract_id`'s contract before co-signing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvtxoPolicy {
    /// Contract that governs cooperative spends: hex of sha256(component_wasm).
    pub contract_id_hex: String,
    /// `V′` x-only public key (the cooperative-leaf key).
    pub evtxo_pk_xonly_hex: String,
    /// Cosigner's `V′` key package (JSON, from the reshare finalizer).
    pub key_package_json: String,
    /// `V′` public key package (JSON).
    pub public_key_package_json: String,
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
