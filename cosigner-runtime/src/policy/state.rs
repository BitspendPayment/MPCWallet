use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap};

use threshold::keys::{KeyPackage, PublicKeyPackage};

// serde adapters: persist the threshold crypto types through their existing
// Dart-compatible `to_json`/`from_json` (as a nested JSON object / hex string),
// so the policy holds the real types instead of pre-serialized String blobs.
mod kp_json {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    use threshold::keys::KeyPackage;

    pub fn serialize<S: Serializer>(kp: &KeyPackage, s: S) -> Result<S::Ok, S::Error> {
        let v: serde_json::Value =
            serde_json::from_str(&kp.to_json()).map_err(serde::ser::Error::custom)?;
        v.serialize(s)
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<KeyPackage, D::Error> {
        let v = serde_json::Value::deserialize(d)?;
        KeyPackage::from_json(&v.to_string())
            .map_err(|e| serde::de::Error::custom(format!("{e:?}")))
    }
}

mod pkp_json {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    use threshold::keys::PublicKeyPackage;

    pub fn serialize<S: Serializer>(pkp: &PublicKeyPackage, s: S) -> Result<S::Ok, S::Error> {
        let v: serde_json::Value =
            serde_json::from_str(&pkp.to_json()).map_err(serde::ser::Error::custom)?;
        v.serialize(s)
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<PublicKeyPackage, D::Error> {
        let v = serde_json::Value::deserialize(d)?;
        PublicKeyPackage::from_json(&v.to_string())
            .map_err(|e| serde::de::Error::custom(format!("{e:?}")))
    }
}


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
/// allowlist (`wallet_vk` ∪ `shares.keys()`).
///
/// The WALLET signs contract spends with its existing normal `V` pairing (no per-contract
/// counter-share needed — it falls through to `normal_policy` in `resolve_signing_key`). The
/// always-online SERVICE gets a key-preserving REFRESH of `V` onto `{service, cosigner}` at
/// create time, stored as the one `CosignerShare` in `shares`, so it can co-sign without the
/// wallet online.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractPolicy {
    /// Contract that governs cooperative spends: sha256(component_wasm).
    #[serde(with = "arr32_hex")]
    pub contract_id: [u8; 32],
    /// The WALLET's own verifying-share hex — an authorized signer that uses the normal `V`
    /// pairing (no counter-share in `shares`). Included in the allowlist.
    pub wallet_vk: VerifyingKeyHex,
    /// Unilateral-exit CSV delay (the exit leaf).
    pub exit_delay: u32,
    /// User-supplied exit-leaf owner x-only key, for the taptree.
    #[serde(with = "arr32_hex")]
    pub owner_pk: [u8; 32],

    /// The cosigner's `V` counter-share per service pairing, keyed by the service's verifying
    /// key hex. Added by `ContractCreate` (refresh of `V` onto `{service, cosigner}`).
    pub shares: BTreeMap<VerifyingKeyHex, CosignerShare>,
}

impl ContractPolicy {
    /// The verifying shares authorized to sign this contract: the wallet (signs with normal
    /// `V`) plus every service pairing in `shares`. The gate co-signs only for these.
    pub fn authorized_verifying_keys(&self) -> Vec<VerifyingKeyHex> {
        let mut keys = vec![self.wallet_vk.clone()];
        keys.extend(self.shares.keys().cloned());
        keys
    }

    /// The cosigner's `V` counter-share for the given recipient verifying key, or `None` when
    /// the recipient signs with the normal `V` pairing (the wallet) rather than a service share.
    pub fn share_for(&self, verifying_key_hex: &str) -> Option<&CosignerShare> {
        self.shares.get(verifying_key_hex)
    }
}

/// The cosigner's `V` counter-share for one service signing pairing. `public_key_package` is
/// the 2-entry PKP `{service_id: P·G, cosigner_id: C·G}` whose group key is `V`; `key_package`
/// is the cosigner's own `C` key package.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CosignerShare {
    #[serde(with = "kp_json")]
    pub key_package: KeyPackage,
    #[serde(with = "pkp_json")]
    pub public_key_package: PublicKeyPackage,
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
