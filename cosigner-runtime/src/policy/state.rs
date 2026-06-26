use serde::{Deserialize, Serialize};
use std::collections::HashMap;


mod arr32_hex {
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(b: &[u8; 32], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&hex::encode(b))
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<[u8; 32], D::Error> {
        let h = String::deserialize(d)?;
        let bytes = hex::decode(&h).map_err(serde::de::Error::custom)?;
        bytes
            .try_into()
            .map_err(|_| serde::de::Error::custom("expected 32 bytes"))
    }
}

/// Per-user policy state. Mirrors `PolicyState` from `server/lib/state.dart`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PolicyState {
    /// This group's cosigner id (hex) = the GROUP KEY: `V` for a normal 2-of-2
    /// wallet, `V′` for a contract. Policies are keyed under it; clients addressing
    /// by a member's verifying share resolve here via `policy_owner_idx`.
    pub cosigner_id: String,
    /// The wallet's DKG identifier (may differ from Identifier::derive(userId)
    /// when the wallet is a passive receiver).
    pub user_signing_identifier_hex: Option<String>,
    /// Server's original DKG secret (hex-encoded 32-byte scalar).
    /// Persisted separately via SecretStore (not included in storage JSON).
    #[serde(skip)]
    pub server_dkg_secret_hex: Option<String>,
    /// The user's normal 2-of-2 {user, cosigner} spending key.
    pub normal_policy: NormalPolicy,
    /// Contracts created by this user, keyed by contract scriptPubKey (hex). Each
    /// binds a reshared 2-of-2 key V′ to a WASM contract, with the cosigner's
    /// counter-share for each signing pairing (the user and the always-online
    /// service).
    #[serde(default)]
    pub contracts: HashMap<String, ContractPolicy>,
    /// Set ONLY on a `{service, cosigner}` pairing actor (Tier 2 service co-sign).
    /// Its presence marks this actor as a service co-signer that may sign nothing
    /// EXCEPT a contract-approved spend of the one eVTXO named here: the sign path
    /// rebuilds the cooperative-leaf sighash from these params and signs only that,
    /// so a compromised service cannot co-sign a `V` spend of the wallet's normal
    /// funds. `normal_policy` holds the cosigner's pairing counter-share + the V PKP.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub contract_pairing: Option<ContractPairing>,
}

/// Association binding a `{service, cosigner}` pairing actor to the single eVTXO it
/// co-signs. All params needed to reconstruct the eVTXO cooperative-leaf script (and
/// thus the script-path sighash) host-side, independent of the spend PSBT.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractPairing {
    /// The eVTXO scriptPubKey hex this actor is allowed to co-sign spends of.
    pub evtxo_spk_hex: String,
    /// sha256(component_wasm) — the gate's contract id (also the leaf hashlock seed).
    #[serde(with = "arr32_hex")]
    pub contract_id: [u8; 32],
    /// ASP signer x-only key (cooperative leaf).
    #[serde(with = "arr32_hex")]
    pub server_pk: [u8; 32],
    /// Exit-leaf owner x-only key (part of the taptree).
    #[serde(with = "arr32_hex")]
    pub owner_pk: [u8; 32],
    /// Unilateral-exit CSV delay (part of the taptree).
    pub exit_delay: u32,
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

/// Hex of a compressed verifying key (a participant's verifying share / group key).
/// Kept as a `String` because it is a JSON map key (serde requires string keys) and is
/// compared directly against wire-provided verifying-key hex.
pub type VerifyingKeyHex = String;

/// A contract bound to a WASM `contract_id`. NO distinct key: the wallet's normal key `V` is
/// reused. The cosigner GATE is the sole binding — it co-signs a contract eVTXO spend only
/// when (1) the WASM `evaluate` returns Allow and (2) the requesting verifying share is on the
/// allowlist (`wallet_vk` ∪ `authorized_service_vks`).
///
/// The WALLET signs contract spends with its existing normal `V` pairing. The always-online
/// SERVICE gets a key-preserving REFRESH of `V` onto `{service, cosigner}` at create time; the
/// cosigner's counter-share lives in the SEPARATE pairing actor's guest (Plan A — never stored
/// here), so this struct holds only the gate's PUBLIC metadata + the authorized-signer allowlist.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractPolicy {
    /// Contract that governs cooperative spends: sha256(component_wasm).
    #[serde(with = "arr32_hex")]
    pub contract_id: [u8; 32],
    /// The WALLET's own verifying-share hex — an authorized signer that uses the normal `V`
    /// pairing. Included in the allowlist.
    pub wallet_vk: VerifyingKeyHex,
    /// Unilateral-exit CSV delay (the exit leaf).
    pub exit_delay: u32,
    /// User-supplied exit-leaf owner x-only key, for the taptree.
    #[serde(with = "arr32_hex")]
    pub owner_pk: [u8; 32],

    /// Service verifying keys authorized to co-sign this contract (the gate allowlist). Each has
    /// a `{service, cosigner}` pairing whose cosigner counter-share lives in its own guest actor.
    #[serde(default, alias = "shares")]
    pub authorized_service_vks: Vec<VerifyingKeyHex>,
}

impl ContractPolicy {
    /// The verifying shares authorized to sign this contract: the wallet (normal `V`) plus every
    /// authorized service. The gate co-signs only for these.
    pub fn authorized_verifying_keys(&self) -> Vec<VerifyingKeyHex> {
        let mut keys = vec![self.wallet_vk.clone()];
        keys.extend(self.authorized_service_vks.iter().cloned());
        keys
    }
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
