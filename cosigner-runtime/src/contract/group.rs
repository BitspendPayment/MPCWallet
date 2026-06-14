//! Contract cosigner GROUP — the per-contract binding that enforces the
//! one-cosigner-one-user invariant for multi-user eVTXO contracts.
//!
//! Previously a single shared cosigner actor (keyed by the cooperative key `V′`)
//! held EVERY recipient's counter-share `C_i` plus an N-entry authorization
//! roster, so N parties wrote into one storage namespace. That defeats per-user
//! enclave rollback detection: a user cannot keep a coherent post-write checksum
//! chain when other parties interleave writes into the same actor's state.
//!
//! Now each party gets its OWN dedicated contract cosigner, keyed by a per-party
//! id `cc_id = sha256(DOMAIN || V′ || recipient_vk)`, holding ONLY that party's
//! `C_i` (a single-recipient policy) behind a single-entry roster — so the global
//! invariant holds for contracts too: 1 cosigner ⇔ 1 id (its group key) ⇔ 1 user,
//! each with its own isolated write stream.
//!
//! A `ContractCosignerGroup` (keyed by `V′`) binds the members together and
//! carries the cross-party onboarding context — the cosigner's canonical `V′`
//! key package and the eVTXO taptree params — which cannot belong to any single
//! party. Clients still address the group by `V′`; the host fans a cooperative
//! spend out to the spending party's `cc_id` (see `rest_api` sign routing).

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use tonic::Status;

use crate::contract::crypto_host;
use crate::persistence::KvStore;
use crate::policy::{EvtxoPolicy, NormalPolicy, PolicyState, RecipientCosignerShare};

/// Persistence tree: group id (`V′` compressed-pubkey hex) -> group JSON.
pub const CONTRACT_GROUPS_TREE: &str = "contract_groups";

/// Persistence tree mapping a cosigner id -> JSON array of authorized verifying
/// shares. Mirrors `helpers::GROUP_AUTH_TREE`; duplicated here to avoid a
/// handlers→contract dependency cycle.
const GROUP_AUTH_TREE: &str = "group_auth_idx";

/// Domain separator for the per-party cosigner id derivation.
const CC_ID_DOMAIN: &[u8] = b"merlin:contract-cosigner-group:v1";

/// One member of a contract cosigner group: a party's verifying share and the
/// dedicated per-party cosigner id (its group key) that holds its `C_i`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractMember {
    /// The party's main verifying share (hex) — the identity it authenticates as.
    pub recipient_vk_hex: String,
    /// The dedicated per-party contract cosigner id (hex) = `cc_id`.
    pub cc_id_hex: String,
}

/// The per-contract binding over the per-party cosigners. Persisted under
/// `contract_groups/<V′>`; replaces the single shared `is_contract` `V′` policy
/// as the home for cross-party onboarding state.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractCosignerGroup {
    /// Group id = cooperative key `V′` (compressed verifying-key hex). Clients
    /// address the group by this; the host fans spends out to a member `cc_id`.
    pub group_id_hex: String,
    /// The eVTXO scriptPubKey (hex) this group governs.
    pub spk_hex: String,
    /// Contract that gates cooperative spends: hex of sha256(component_wasm).
    pub contract_id_hex: String,
    /// `V′` x-only key (the cooperative-leaf key; same for every member).
    pub evtxo_pk_xonly_hex: String,
    /// The exit-leaf owner key (author's `V`, x-only hex) — members need it to
    /// rebuild the taptree when spending the cooperative leaf.
    pub owner_pk_xonly_hex: String,
    /// The eVTXO's unilateral-exit CSV delay.
    pub exit_delay: u32,
    /// The cosigner's canonical `V′` key package (its master share for `V′`),
    /// used to refresh per-party counter-shares during onboarding. Cross-party —
    /// lives on the group, never on a member.
    pub cosigner_vprime_kp_json: String,
    /// The author's (recipient[0]'s) `V′` identifier hex — the second original
    /// shareholder of `V′`, needed for the onboarding Lagrange coefficient.
    pub author_id_hex: String,
    /// The group roster: one dedicated cosigner per party.
    pub members: Vec<ContractMember>,
}

impl ContractCosignerGroup {
    /// The dedicated cosigner id for `recipient_vk_hex`, if it is a member.
    pub fn member_cc_id(&self, recipient_vk_hex: &str) -> Option<String> {
        self.members
            .iter()
            .find(|m| m.recipient_vk_hex == recipient_vk_hex)
            .map(|m| m.cc_id_hex.clone())
    }

    /// Insert or replace a member (idempotent re-onboard).
    pub fn upsert_member(&mut self, recipient_vk_hex: &str, cc_id_hex: &str) {
        if let Some(m) = self
            .members
            .iter_mut()
            .find(|m| m.recipient_vk_hex == recipient_vk_hex)
        {
            m.cc_id_hex = cc_id_hex.to_string();
        } else {
            self.members.push(ContractMember {
                recipient_vk_hex: recipient_vk_hex.to_string(),
                cc_id_hex: cc_id_hex.to_string(),
            });
        }
    }
}

/// Derive the dedicated per-party cosigner id (hex) for `(group_id, recipient_vk)`.
/// Deterministic and collision-resistant: `sha256(DOMAIN || V′ || recipient_vk)`.
/// `group_id_hex` is the compressed `V′` hex; `recipient_vk_hex` the party's
/// verifying share hex. Distinct per (contract, party) and stable across calls.
pub fn derive_cc_id(group_id_hex: &str, recipient_vk_hex: &str) -> Result<String, Status> {
    let group = hex::decode(group_id_hex)
        .map_err(|e| Status::internal(format!("bad group_id hex: {e}")))?;
    let vk = hex::decode(recipient_vk_hex)
        .map_err(|e| Status::internal(format!("bad recipient_vk hex: {e}")))?;
    let mut preimage = Vec::with_capacity(CC_ID_DOMAIN.len() + group.len() + vk.len());
    preimage.extend_from_slice(CC_ID_DOMAIN);
    preimage.extend_from_slice(&group);
    preimage.extend_from_slice(&vk);
    Ok(hex::encode(crypto_host::sha256(&preimage)))
}

/// Load a contract cosigner group by its id (`V′` hex). `None` on miss or a
/// corrupt row (treated as "not a contract group").
pub fn load(persistence: &dyn KvStore, group_id_hex: &str) -> Option<ContractCosignerGroup> {
    match persistence.get(CONTRACT_GROUPS_TREE, group_id_hex) {
        Ok(Some(json)) => serde_json::from_str(&json).ok(),
        _ => None,
    }
}

/// Persist a contract cosigner group under `contract_groups/<V′>`.
pub fn save(persistence: &dyn KvStore, group: &ContractCosignerGroup) -> Result<(), Status> {
    let json = serde_json::to_string(group)
        .map_err(|e| Status::internal(format!("encode contract group: {e}")))?;
    persistence
        .put(CONTRACT_GROUPS_TREE, &group.group_id_hex, &json)
        .map_err(|e| Status::internal(format!("persist contract group: {e}")))
}

/// Resolve the dispatch route for a cooperative spend: a party addressing the
/// group by `V′` is fanned out to its dedicated cosigner `cc_id`. Returns `None`
/// when `group_id_hex` is not a contract group (e.g. a one-shot `V′==V` eVTXO,
/// or a normal wallet) or the signer is not a registered member — the caller
/// then dispatches to the addressed route unchanged.
pub fn spend_route(
    persistence: &dyn KvStore,
    group_id_hex: &str,
    recipient_vk_hex: &str,
) -> Option<String> {
    load(persistence, group_id_hex)?.member_cc_id(recipient_vk_hex)
}

/// Register a party as a dedicated per-party contract cosigner and add it to the
/// group. Mints `policies/<cc_id>` holding ONLY this party's counter-share
/// (single-recipient `EvtxoPolicy`), a single-entry roster
/// `group_auth_idx/<cc_id> = [recipient_vk]`, and a self-route
/// `policy_owner_idx/<cc_id> = cc_id`. Pushes the member onto `group` (caller
/// persists the group). Returns the new `cc_id`.
///
/// `c_kp_json` is the cosigner's `C_i` key package; `pkp_json` the 2-entry `V′`
/// public key package `{recipient_id: P_i·G, cosigner_id: C_i·G}` for this party.
pub fn register_member(
    persistence: &dyn KvStore,
    group: &mut ContractCosignerGroup,
    recipient_vk_hex: &str,
    c_kp_json: &str,
    pkp_json: &str,
) -> Result<String, Status> {
    let cc_id = derive_cc_id(&group.group_id_hex, recipient_vk_hex)?;

    // The dedicated cosigner holds exactly one recipient share for exactly one
    // eVTXO. The cross-party onboarding fields stay empty here — they live on the
    // group, not on a per-party member.
    let mut recipient_shares = HashMap::new();
    recipient_shares.insert(
        recipient_vk_hex.to_string(),
        RecipientCosignerShare {
            key_package_json: c_kp_json.to_string(),
            public_key_package_json: pkp_json.to_string(),
        },
    );
    let mut evtxo_policies = HashMap::new();
    evtxo_policies.insert(
        group.spk_hex.clone(),
        EvtxoPolicy {
            contract_id_hex: group.contract_id_hex.clone(),
            evtxo_pk_xonly_hex: group.evtxo_pk_xonly_hex.clone(),
            recipient_shares,
            cosigner_vprime_kp_json: String::new(),
            author_id_hex: String::new(),
            exit_delay: group.exit_delay,
            owner_pk_xonly_hex: group.owner_pk_xonly_hex.clone(),
        },
    );

    let policy = PolicyState {
        cosigner_id: cc_id.clone(),
        recovery_id: String::new(),
        user_signing_identifier_hex: None,
        server_dkg_secret_hex: None,
        normal_policy: NormalPolicy {
            id: String::new(),
            key_package_json: String::new(),
            public_key_package_json: String::new(),
        },
        evtxo_policies,
        is_contract: true,
    };
    let policy_json = serde_json::to_string(&policy)
        .map_err(|e| Status::internal(format!("encode member policy: {e}")))?;
    persistence
        .put("policies", &cc_id, &policy_json)
        .map_err(|e| Status::internal(format!("persist member policy: {e}")))?;

    // Single-entry roster: this cosigner authenticates exactly one user.
    let roster = serde_json::to_string(&[recipient_vk_hex])
        .map_err(|e| Status::internal(format!("encode member roster: {e}")))?;
    persistence
        .put(GROUP_AUTH_TREE, &cc_id, &roster)
        .map_err(|e| Status::internal(format!("persist member roster: {e}")))?;

    // Self-route so `/u/<cc_id>/` addressing resolves to this actor on respawn.
    persistence
        .put("policy_owner_idx", &cc_id, &cc_id)
        .map_err(|e| Status::internal(format!("persist member policy_owner_idx: {e}")))?;

    group.upsert_member(recipient_vk_hex, &cc_id);
    Ok(cc_id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::persistence::PersistenceError;
    use std::sync::Mutex as StdMutex;

    #[derive(Default)]
    struct MemStore(StdMutex<HashMap<String, String>>);
    impl KvStore for MemStore {
        fn get(&self, tree: &str, key: &str) -> Result<Option<String>, PersistenceError> {
            Ok(self.0.lock().unwrap().get(&format!("{tree}/{key}")).cloned())
        }
        fn put(&self, tree: &str, key: &str, value: &str) -> Result<(), PersistenceError> {
            self.0
                .lock()
                .unwrap()
                .insert(format!("{tree}/{key}"), value.to_string());
            Ok(())
        }
        fn delete(&self, tree: &str, key: &str) -> Result<(), PersistenceError> {
            self.0.lock().unwrap().remove(&format!("{tree}/{key}"));
            Ok(())
        }
        fn get_all(&self, _tree: &str) -> Result<HashMap<String, String>, PersistenceError> {
            Ok(HashMap::new())
        }
        fn clear(&self, _tree: &str) -> Result<(), PersistenceError> {
            Ok(())
        }
    }

    fn sample_group() -> ContractCosignerGroup {
        ContractCosignerGroup {
            group_id_hex: "02".to_string() + &"ab".repeat(32),
            spk_hex: "51".repeat(34),
            contract_id_hex: "cc".repeat(32),
            evtxo_pk_xonly_hex: "ab".repeat(32),
            owner_pk_xonly_hex: "cd".repeat(32),
            exit_delay: 144,
            cosigner_vprime_kp_json: "{}".to_string(),
            author_id_hex: "11".repeat(32),
            members: Vec::new(),
        }
    }

    #[test]
    fn cc_id_is_deterministic_and_per_party() {
        let g = sample_group();
        let alice = "02".to_string() + &"11".repeat(32);
        let bob = "02".to_string() + &"22".repeat(32);
        let a1 = derive_cc_id(&g.group_id_hex, &alice).unwrap();
        let a2 = derive_cc_id(&g.group_id_hex, &alice).unwrap();
        let b1 = derive_cc_id(&g.group_id_hex, &bob).unwrap();
        assert_eq!(a1, a2, "derivation must be stable");
        assert_ne!(a1, b1, "distinct parties get distinct cosigners");
        assert_eq!(a1.len(), 64, "cc_id is a 32-byte hash hex");
    }

    #[test]
    fn register_member_isolates_each_party() {
        let store = MemStore::default();
        let mut g = sample_group();
        let alice = "02".to_string() + &"11".repeat(32);
        let bob = "02".to_string() + &"22".repeat(32);

        let cc_alice = register_member(&store, &mut g, &alice, "{\"kp\":\"a\"}", "{\"pkp\":\"a\"}").unwrap();
        let cc_bob = register_member(&store, &mut g, &bob, "{\"kp\":\"b\"}", "{\"pkp\":\"b\"}").unwrap();
        save(&store, &g).unwrap();

        // Two members, two distinct dedicated cosigners.
        assert_eq!(g.members.len(), 2);
        assert_ne!(cc_alice, cc_bob);

        // Each cosigner's policy holds ONLY its own recipient share.
        let pa: PolicyState =
            serde_json::from_str(&store.get("policies", &cc_alice).unwrap().unwrap()).unwrap();
        assert!(pa.is_contract);
        let ep = pa.evtxo_policies.get(&g.spk_hex).unwrap();
        assert_eq!(ep.recipient_shares.len(), 1);
        assert!(ep.recipient_shares.contains_key(&alice));
        assert!(!ep.recipient_shares.contains_key(&bob));

        // Each roster authenticates exactly one user.
        let roster: Vec<String> =
            serde_json::from_str(&store.get(GROUP_AUTH_TREE, &cc_alice).unwrap().unwrap()).unwrap();
        assert_eq!(roster, vec![alice.clone()]);

        // Self-route + group fan-out resolve to the right cosigner.
        assert_eq!(store.get("policy_owner_idx", &cc_alice).unwrap().unwrap(), cc_alice);
        assert_eq!(spend_route(&store, &g.group_id_hex, &alice).unwrap(), cc_alice);
        assert_eq!(spend_route(&store, &g.group_id_hex, &bob).unwrap(), cc_bob);
        // A non-member does not resolve to any cosigner.
        assert!(spend_route(&store, &g.group_id_hex, &("02".to_string() + &"33".repeat(32))).is_none());
    }
}
