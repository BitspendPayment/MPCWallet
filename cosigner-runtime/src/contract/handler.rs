//! Contract-create ceremony handlers — call `threshold::dkg::*` directly on the
//! typed round state in `ContractSession.rounds`. Steps 1-3 reshare `V→V′`
//! between {user, cosigner}; step 4 refreshes `V′` onto the always-online service
//! pairing and persists the `ContractPolicy` on the USER's policy.
//!
//! Strict 2-of-2 {user, cosigner} where the cosigner is the server and self-deals, so
//! every step completes on its single call — no rendezvous / parked replies. Owned and
//! invoked by [`super::ContractManager`].

use std::collections::BTreeMap;
use std::time::Instant;

use rand::rngs::OsRng;
use rand::Rng;
use tonic::Status;

use threshold::dkg;
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::random;

use crate::ceremony::{self, Reply};
use crate::contract;
use crate::cosigner::handlers::{contract_gate, parsers};
use crate::policy::store::persist_policy;
use crate::policy::{ContractPolicy, CosignerShare, PolicyState};
use crate::shared::SharedServices;
use crate::wallet_proto::{
    ContractContext, ContractCreateStep1Request, ContractCreateStep1Response,
    ContractCreateStep2Request, ContractCreateStep2Response, ContractCreateStep3Request,
    ContractCreateStep3Response, ContractCreateStep4Request,
};

use super::session::ContractSession;

const TOTAL_PARTICIPANTS: usize = 2; // user + cosigner — both dealers + final shareholders
const THRESHOLD_COUNT: usize = 2; // resulting key is 2-of-2

// ============================================================================
// Step 1 — register dealers; the cosigner self-deals a reshare polynomial.
// ============================================================================

pub fn reshare_round1(
    sess: &mut ContractSession,
    shared: &SharedServices,
    req: ContractCreateStep1Request,
    reply: Reply<ContractCreateStep1Response>,
) {
    sess.last_touch = Instant::now();

    if req.round1_package.is_empty() {
        let _ = reply.send(Err(Status::invalid_argument(
            "round1_package is required (contract creation always reshares)",
        )));
        return;
    }

    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!(
        "[{user_id_hex}] ContractCreateStep1 from {}",
        hex::encode(&req.identifier)
    );

    // Capture reshare context (contract + ASP + service params); validated at finalize.
    if !req.contract_id.is_empty() {
        sess.contract_id = req.contract_id.clone();
    }
    if !req.contract_wasm.is_empty() {
        sess.contract_wasm = req.contract_wasm.clone();
    }
    if !req.server_pk.is_empty() {
        sess.server_pk = req.server_pk.clone();
    }
    if req.exit_delay != 0 {
        sess.exit_delay = req.exit_delay;
    }
    if !req.owner_pk.is_empty() {
        sess.owner_pk = req.owner_pk.clone();
    }
    if !req.service_vk.is_empty() {
        sess.service_vk = req.service_vk.clone();
    }

    let (id, pkg) = match (
        ceremony::parse_identifier_hex(&hex::encode(&req.identifier)),
        ceremony::round1_pkg_from_json(&req.round1_package),
    ) {
        (Ok(id), Ok(pkg)) => (id, pkg),
        (Err(e), _) | (_, Err(e)) => {
            let _ = reply.send(Err(e));
            return;
        }
    };
    sess.rounds.round1_packages.insert(id, pkg);

    // The cosigner self-deals its own Δ (first caller only): it reshares from its
    // EXISTING share under its EXISTING identifier on a fresh non-zero Δ, so the
    // finalized key is V′ = V + Δ.
    if sess.rounds.round1_secret.is_none() {
        let dealt = (|| -> Result<(), Status> {
            let policy = load_policy(shared, &user_id_hex)?;
            let old_kp = KeyPackage::from_json(&policy.normal_policy.key_package_json)
                .map_err(|e| Status::internal(format!("old kp: {e}")))?;
            let old_pkp =
                PublicKeyPackage::from_json(&policy.normal_policy.public_key_package_json)
                    .map_err(|e| Status::internal(format!("old pkp: {e}")))?;
            let cosigner_id = old_kp.identifier.clone();

            let mut rng = OsRng;
            let secret = random::mod_n_random(&mut rng);
            let mut seed = [0u8; 32];
            rng.fill(&mut seed);
            let coefficients = random::generate_coefficients_seeded(THRESHOLD_COUNT - 1, &seed);
            let (r1_secret, r1_pub) = dkg::dkg_reshare_part1(
                &cosigner_id,
                TOTAL_PARTICIPANTS,
                THRESHOLD_COUNT,
                &secret,
                &coefficients,
                &mut rng,
            )
            .map_err(|e| Status::internal(format!("dkg_reshare_part1: {e}")))?;

            sess.rounds.server_id = Some(cosigner_id.clone());
            sess.rounds.round1_packages.insert(cosigner_id, r1_pub);
            sess.rounds.round1_secret = Some(r1_secret);
            sess.old_kp = Some(old_kp);
            sess.old_pkp = Some(old_pkp);
            Ok(())
        })();
        if let Err(e) = dealt {
            let _ = reply.send(Err(e));
            return;
        }
    }

    // 2-of-2 {user, cosigner}: the cosigner self-deals above, so both round-1 packages
    // are present on this single call — reply immediately (no rendezvous).
    let _ = reply.send(Ok(ContractCreateStep1Response {
        round1_packages: sess.rounds.round1_packages_wire(),
    }));
}

// ============================================================================
// Step 2 — the cosigner computes its round-2 shares for the receivers.
// ============================================================================

pub fn reshare_round2(
    sess: &mut ContractSession,
    req: ContractCreateStep2Request,
    reply: Reply<ContractCreateStep2Response>,
) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] ContractCreateStep2");

    if sess.rounds.round1_secret.is_none() {
        let _ = reply.send(Err(Status::internal("no contract-create session")));
        return;
    }

    if sess.rounds.is_round2_local_empty() {
        let Some(cosigner_id) = sess.rounds.server_id.clone() else {
            let _ = reply.send(Err(Status::internal("server ID not initialized")));
            return;
        };
        let round1_pkgs = sess.rounds.round1_packages_excluding(&cosigner_id);
        let receiver_ids = sess.rounds.receiver_ids();
        let Some(round1_secret) = sess.rounds.round1_secret.take() else {
            let _ = reply.send(Err(Status::internal("round1 secret missing")));
            return;
        };
        let (r2_secret, r2_pkgs) = match dkg::dkg_part2(&round1_secret, &round1_pkgs, &receiver_ids)
        {
            Ok(v) => v,
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("dkg_part2: {e}"))));
                return;
            }
        };
        sess.rounds.round2_secret = Some(r2_secret);
        sess.rounds.round2_local = r2_pkgs;
    }

    let _ = reply.send(Ok(ContractCreateStep2Response {
        all_round1_packages: sess.rounds.round1_packages_wire(),
    }));
}

// ============================================================================
// Step 3 — exchange round-2; finalize V′; register + persist the user pairing.
// ============================================================================

pub fn reshare_round3(
    sess: &mut ContractSession,
    shared: &SharedServices,
    req: ContractCreateStep3Request,
    reply: Reply<ContractCreateStep3Response>,
) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let sender_id = match ceremony::parse_identifier_hex(&hex::encode(&req.identifier)) {
        Ok(id) => id,
        Err(e) => {
            let _ = reply.send(Err(e));
            return;
        }
    };
    tracing::info!(
        "[{user_id_hex}] ContractCreateStep3 from {}",
        hex::encode(&req.identifier)
    );

    let cosigner_id = match sess.rounds.server_id.clone() {
        Some(id) => id,
        None => {
            let _ = reply.send(Err(Status::internal("server ID not initialized")));
            return;
        }
    };
    let pkgs = match ceremony::round2_pkgs_from_wire(&req.round2_packages_for_others) {
        Ok(p) => p,
        Err(e) => {
            let _ = reply.send(Err(e));
            return;
        }
    };
    if let Some(for_cosigner) = pkgs.get(&cosigner_id) {
        sess.rounds
            .round2_received
            .insert(sender_id.clone(), for_cosigner.clone());
    }
    sess.rounds.insert_relay_packages(sender_id.clone(), pkgs);
    sess.rounds.insert_relay_from_local(cosigner_id);
    // Finalize the reshare: derive V′, register the contract spk (user-supplied exit
    // key), and persist the ContractPolicy (user pairing only) on the USER's policy.
    let finalized = (|| -> Result<(Vec<u8>, String), Status> {
        let cosigner_id = sess
            .rounds
            .server_id
            .clone()
            .ok_or_else(|| Status::internal("server ID not initialized"))?;
        let cosigner_id_hex = hex::encode(cosigner_id.serialize());

        let old_kp = sess
            .old_kp
            .clone()
            .ok_or_else(|| Status::internal("old kp missing"))?;
        let old_pkp = sess
            .old_pkp
            .clone()
            .ok_or_else(|| Status::internal("old pkp missing"))?;

        let round1_pkgs = sess.rounds.round1_packages_excluding(&cosigner_id);
        let final_ids: Vec<Identifier> = sess.rounds.round1_packages.keys().cloned().collect();
        let r2_secret = sess
            .rounds
            .round2_secret
            .take()
            .ok_or_else(|| Status::internal("round2 secret missing"))?;

        let (kp, pkp) = dkg::dkg_reshare_part3(
            &r2_secret,
            &round1_pkgs,
            &sess.rounds.round2_received,
            &old_pkp,
            &old_kp,
            &final_ids,
        )
        .map_err(|e| Status::internal(format!("dkg_reshare_part3: {e}")))?;

        let pkp_json = pkp.to_json();
        let coop_pk_xonly = xonly_from_vk(&parsers::extract_verifying_key(&pkp_json)?);
        // The unilateral-exit key is USER-SUPPLIED (not derived from V).
        if sess.owner_pk.len() != 32 {
            return Err(Status::invalid_argument(
                "owner_pk must be a 32-byte x-only key",
            ));
        }
        let owner_pk_xonly = hex::encode(&sess.owner_pk);
        let server_pk_xonly = hex::encode(&sess.server_pk);

        if sess.contract_id.len() != 32 {
            return Err(Status::invalid_argument("contract_id must be 32 bytes"));
        }
        let mut contract_id = [0u8; 32];
        contract_id.copy_from_slice(&sess.contract_id);

        if sess.contract_wasm.is_empty() {
            return Err(Status::invalid_argument(
                "contract_wasm is required when creating a contract",
            ));
        }
        if contract::sha256_id(&sess.contract_wasm) != contract_id {
            return Err(Status::invalid_argument(
                "contract_wasm does not match contract_id (sha256 mismatch)",
            ));
        }
        if let Some(host) = shared.contract_host.as_ref() {
            host.validate(&sess.contract_wasm)
                .map_err(|e| Status::invalid_argument(format!("invalid contract: {e}")))?;
        }
        shared
            .persistence
            .put(
                contract::CONTRACT_WASM_TREE,
                &hex::encode(contract_id),
                &hex::encode(&sess.contract_wasm),
            )
            .map_err(|e| Status::internal(format!("store contract wasm: {e}")))?;

        let spk = contract_gate::register_contract(
            shared.persistence.as_ref(),
            &server_pk_xonly,
            &coop_pk_xonly,
            &owner_pk_xonly,
            sess.exit_delay,
            &contract_id,
        )?;
        let spk_hex = hex::encode(&spk);
        let group_id = parsers::extract_verifying_key(&pkp_json)?; // V′

        // The user's V′ identifier (the non-cosigner entry of the 2-entry PKP), needed
        // for the service refresh's Lagrange coefficient.
        let author_id = ceremony::parse_identifier_hex(&parsers::extract_recipient_identifier(
            &pkp_json,
            &cosigner_id_hex,
        )?)?;

        // Persist pairing A (the user) on the USER's policy; the service pairing is
        // added at step4. `user_id_hex` is the request's user id (the session owner).
        let contract_pk: [u8; 32] = hex::decode(&coop_pk_xonly)
            .ok()
            .and_then(|b| b.try_into().ok())
            .ok_or_else(|| Status::internal("contract_pk must be 32-byte x-only"))?;
        let owner_pk: [u8; 32] = sess
            .owner_pk
            .clone()
            .try_into()
            .map_err(|_| Status::internal("owner_pk must be 32 bytes"))?;
        let contract_policy = ContractPolicy {
            contract_id,
            contract_pk,
            cosigner_key_package: kp.clone(),
            author_id,
            exit_delay: sess.exit_delay,
            owner_pk,
            // Pairing A: the author/user, keyed by its verifying-share hex (= user_id).
            shares: BTreeMap::from([(
                user_id_hex.clone(),
                CosignerShare {
                    key_package: kp,
                    public_key_package: pkp,
                },
            )]),
        };

        let mut policy = load_policy(shared, &user_id_hex)?;
        policy.contracts.insert(spk_hex, contract_policy);
        persist_policy(shared, &user_id_hex, &policy)?;

        tracing::info!("[{user_id_hex}] ContractCreate reshare complete; V′={group_id}");
        Ok((spk, group_id))
    })();
    let (spk, group_id) = match finalized {
        Ok(v) => v,
        Err(e) => {
            let _ = reply.send(Err(e));
            return;
        }
    };

    let _ = reply.send(Ok(ContractCreateStep3Response {
        round2_packages_for_me: sess.rounds.relay_packages_for(&sender_id),
        contract_script_pubkey: spk.to_vec(),
        contract_group_id: hex::decode(&group_id).unwrap_or_default(),
    }));
}

// ============================================================================
// Step 4 — refresh V′ onto the service pairing; persist + deliver b@service.
// ============================================================================

/// Build the cosigner's service counter-share `C_B`, the service verifying share
/// `service_share·G`, persist the service pairing, and return
/// `(V′_group_id_hex, b@service_bytes, context)` for delivery to the service.
pub fn reshare_round4(
    sess: &mut ContractSession,
    shared: &SharedServices,
    req: &ContractCreateStep4Request,
) -> Result<(String, Vec<u8>, ContractContext), Status> {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let spk_hex = hex::encode(&req.contract_script_pubkey);

    if sess.service_vk.len() != 33 {
        return Err(Status::invalid_argument("service_vk must be 33 bytes"));
    }
    let service_vk = sess.service_vk.clone();
    let service_vk_hex = hex::encode(&service_vk);

    let mut policy = load_policy(shared, &user_id_hex)?;
    let cp = policy
        .contracts
        .get(&spk_hex)
        .ok_or_else(|| Status::not_found("no such contract for this user"))?
        .clone();

    // The cosigner's canonical V′ key package + the user's V′ identifier (the other holder).
    let holder_kp = cp.cosigner_key_package.clone();
    let author_id = cp.author_id.clone();

    let service_id = Identifier::derive(&service_vk)
        .map_err(|e| Status::internal(format!("derive service id: {e:?}")))?;

    let a_at_cosigner: [u8; 32] = req
        .a_at_cosigner
        .clone()
        .try_into()
        .map_err(|_| Status::invalid_argument("a_at_cosigner must be 32 bytes"))?;
    let a_at_service_point: [u8; 33] = req
        .a_at_service_point
        .clone()
        .try_into()
        .map_err(|_| Status::invalid_argument("a_at_service_point must be 33 bytes"))?;

    // The cosigner (a V′ holder) deals its half + assembles the {service, cosigner}
    // 2-of-2 pairing for V′. Here the user is the only other holder: it dealt `a@cosigner`
    // to us and the POINT `a@service·G` for the service (we never see `a@service`, so we
    // can't reconstruct v′).
    let mut id_partial_share = BTreeMap::new();
    id_partial_share.insert(author_id, a_at_cosigner);
    let receiver = dkg::Receiver {
        id: service_id,
        partial_verifying_share: a_at_service_point,
    };
    let pairing = dkg::refresh_to_receiver(&holder_kp, &receiver, &id_partial_share, 2, &mut OsRng)
        .map_err(|e| Status::internal(format!("refresh_to_receiver: {e:?}")))?;
    let pkp_b_json = pairing.pairing_pkp.to_json();

    // Add pairing B (the service) to the contract policy, keyed by its verifying-share hex.
    {
        let cp_mut = policy
            .contracts
            .get_mut(&spk_hex)
            .ok_or_else(|| Status::internal("contract vanished"))?;
        cp_mut.shares.insert(
            service_vk_hex,
            CosignerShare {
                key_package: pairing.my_kp.clone(),
                public_key_package: pairing.pairing_pkp.clone(),
            },
        );
    }
    persist_policy(shared, &user_id_hex, &policy)?;

    let group_id = hex::encode(cp.contract_pk); // V′ x-only (correlation key for the service)
    let context = ContractContext {
        contract_script_pubkey: req.contract_script_pubkey.clone(),
        contract_id: cp.contract_id.to_vec(),
        exit_delay: cp.exit_delay,
        owner_pk: cp.owner_pk.to_vec(),
        server_pk: sess.server_pk.clone(),
        public_key_package_json: pkp_b_json,
        service_vk,
        cosigner_group_key: hex::decode(&policy.cosigner_id).unwrap_or_default(),
    };

    tracing::info!("[{user_id_hex}] ContractCreate service pairing added; V′={group_id}");
    Ok((group_id, pairing.receiver_half.to_vec(), context))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn load_policy(shared: &SharedServices, user_id_hex: &str) -> Result<PolicyState, Status> {
    let json = match shared.persistence.get("policies", user_id_hex) {
        Ok(Some(j)) => j,
        _ => {
            let owner = shared
                .persistence
                .get("policy_owner_idx", user_id_hex)
                .ok()
                .flatten()
                .ok_or_else(|| Status::not_found("no policy for user"))?;
            shared
                .persistence
                .get("policies", &owner)
                .ok()
                .flatten()
                .ok_or_else(|| Status::not_found("no policy for user"))?
        }
    };
    serde_json::from_str(&json).map_err(|e| Status::internal(format!("parse policy: {e}")))
}

fn xonly_from_vk(vk_hex: &str) -> String {
    if vk_hex.len() == 66 {
        vk_hex[2..].to_string()
    } else {
        vk_hex.to_string()
    }
}
