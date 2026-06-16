use serde::{Deserialize, Serialize};
use std::collections::HashMap;

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

/// A contract: a fresh contract key `V′` (derived by resharing `V`) bound to a
/// WASM contract. Spending the cooperative leaf requires `V′`, so the cosigner is
/// a mandatory signer and runs `contract_id`'s contract before co-signing.
///
/// `V′` is a 2-of-2 with TWO signing pairings — the cosigner is the common party,
/// and the counterparty is either the user or the always-online service:
///   (user_share + cosigner_shareA)  ||  (service_share + cosigner_shareB)
/// Each pairing's `CosignerShare` holds the cosigner's counter-share + the 2-entry
/// `V′` PKP for that pairing. `service_share` is `None` until the service is
/// onboarded (contract-create step 4).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractPolicy {
    /// Contract that governs cooperative spends: hex of sha256(component_wasm).
    pub contract_id_hex: String,
    /// `V′` x-only public key (the cooperative-leaf / contract key).
    pub contract_pk_xonly_hex: String,
    /// The cosigner's CANONICAL `V′` key package (JSON) — its share at `cosigner_id`.
    /// Used to refresh `V′` onto the service pairing.
    pub cosigner_vprime_kp_json: String,
    /// The user's `V′` identifier hex (the non-cosigner shareholder), needed for the
    /// Lagrange coefficient when refreshing onto the service.
    pub author_id_hex: String,
    /// Unilateral-exit CSV delay (the exit leaf).
    pub exit_delay: u32,
    /// User-supplied exit-leaf owner key (x-only hex), for the taptree.
    pub owner_pk_xonly_hex: String,

    /// The user's verifying share (hex) — the user signing-path identity (pairing A).
    pub user_vk_hex: String,
    /// The cosigner's counter-share for the USER pairing (`cosigner_shareA` + PKP_A).
    pub user_share: CosignerShare,
    /// The always-online service's verifying key (hex) — the service signing-path
    /// identity (pairing B).
    pub service_vk_hex: String,
    /// The cosigner's counter-share for the SERVICE pairing (`cosigner_shareB` +
    /// PKP_B). `None` until the service is onboarded.
    #[serde(default)]
    pub service_share: Option<CosignerShare>,
}

impl ContractPolicy {
    /// The verifying shares authorized to sign this contract: the user always, and
    /// the service once it has been onboarded.
    pub fn authorized_vks(&self) -> Vec<String> {
        let mut v = vec![self.user_vk_hex.clone()];
        if self.service_share.is_some() {
            v.push(self.service_vk_hex.clone());
        }
        v
    }

    /// The cosigner's counter-share for the given recipient verifying share, or
    /// `None` if it is not an (onboarded) recipient of this contract.
    pub fn share_for(&self, vk_hex: &str) -> Option<&CosignerShare> {
        if vk_hex == self.user_vk_hex {
            Some(&self.user_share)
        } else if vk_hex == self.service_vk_hex {
            self.service_share.as_ref()
        } else {
            None
        }
    }
}

/// The cosigner's `V′` counter-share for one signing pairing.
/// `public_key_package_json` is the 2-entry PKP `{recipient_id: P·G, cosigner_id:
/// C·G}` whose group key is `V′`; `key_package_json` is the cosigner's own `C`
/// key package.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CosignerShare {
    /// Cosigner's `V′` counter-share key package (JSON).
    pub key_package_json: String,
    /// 2-entry `V′` public key package (JSON) for this pairing.
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
