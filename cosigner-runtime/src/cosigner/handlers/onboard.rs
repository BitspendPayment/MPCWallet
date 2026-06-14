//! Multi-user contract onboarding (Phase 4).
//!
//! `evtxo_onboard` runs on the CONTRACT actor (GroupID = V′). The author submits its
//! key-preserving refresh half for one participant; the cosigner computes its own
//! half, forms the participant's counter-share `C_i` + the 2-entry `V′` PKP, registers
//! the participant (`recipient_shares` + `group_auth_idx[V′]`), and routes BOTH ECIES
//! halves into the participant's pickup inbox. Neither side learns `P_i`.
//!
//! `evtxo_pending_shares` / `evtxo_ack_share` run on the PARTICIPANT's OWN actor: it
//! fetches (and later clears) the ciphertexts held for it. No FCM/poll — the inbox is
//! surfaced on the participant's next authenticated call.

use std::collections::BTreeMap;

use rand::rngs::OsRng;
use serde::{Deserialize, Serialize};
use tonic::Status;

use threshold::dkg;
use threshold::ecies;
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage, VerifyingKey};
use threshold::point;
use threshold::random;
use threshold::scalar::{scalar_from_bytes, scalar_to_bytes};

use crate::auth::message::{OP_EVTXO_ACK, OP_EVTXO_ONBOARD, OP_EVTXO_PENDING};
use crate::cosigner::registry::CosignerInstance;
use crate::cosigner::state::CosignerState;
use crate::shared::SharedServices;
use crate::wallet_proto::{
    EvtxoAckShareRequest, EvtxoAckShareResponse, EvtxoOnboardRequest, EvtxoOnboardResponse,
    EvtxoPendingSharesRequest, EvtxoPendingSharesResponse, PendingContractShare,
};

use super::helpers::{auth_check, auth_check_group, ensure_policy_loaded, load_group_auth};
use super::parsers;

const PENDING_TREE: &str = "pending_contract_shares";

/// A contract share held for a participant until it picks it up (ciphertext only).
#[derive(Serialize, Deserialize, Clone)]
struct PendingShareRecord {
    spk_hex: String,
    contract_group_id_hex: String,
    contract_id_hex: String,
    ecies_author_hex: String,
    ecies_cosigner_hex: String,
    pkp_json: String,
    exit_delay: u32,
    owner_pk_xonly_hex: String,
}

fn load_pending(persistence: &dyn crate::persistence::KvStore, vk_hex: &str) -> Vec<PendingShareRecord> {
    match persistence.get(PENDING_TREE, vk_hex) {
        Ok(Some(json)) => serde_json::from_str(&json).unwrap_or_default(),
        _ => Vec::new(),
    }
}

fn save_pending(
    persistence: &dyn crate::persistence::KvStore,
    vk_hex: &str,
    records: &[PendingShareRecord],
) -> Result<(), Status> {
    let json = serde_json::to_string(records)
        .map_err(|e| Status::internal(format!("encode pending shares: {e}")))?;
    persistence
        .put(PENDING_TREE, vk_hex, &json)
        .map_err(|e| Status::internal(format!("persist pending shares: {e}")))
}

fn parse_id(hex_str: &str) -> Result<Identifier, Status> {
    let bytes =
        hex::decode(hex_str).map_err(|e| Status::internal(format!("bad id hex: {e}")))?;
    let arr: [u8; 32] = bytes
        .try_into()
        .map_err(|_| Status::internal("identifier must be 32 bytes"))?;
    Identifier::deserialize(&arr).map_err(|e| Status::internal(format!("bad identifier: {e:?}")))
}

/// Onboard one participant to a contract eVTXO. Runs on the V′ contract actor.
pub fn evtxo_onboard(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: EvtxoOnboardRequest,
) -> Result<EvtxoOnboardResponse, Status> {
    let own_id = state.cosigner_id.clone(); // V′
    tracing::info!("[{own_id}] EvtxoOnboard recipient={}", hex::encode(&req.recipient_vk));

    // Load the contract policy (by the actor's own id) and authenticate the author as
    // a registered member of this group.
    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &own_id,
    )?;
    let is_contract = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?
        .is_contract;
    if !is_contract {
        return Err(Status::failed_precondition("not a contract actor"));
    }
    // Onboarding authenticates the AUTHOR (the only entry on the coordinator's
    // roster) — the group owner who deals refresh halves for new participants.
    let authorized = load_group_auth(shared.persistence.as_ref(), &own_id);
    auth_check_group(
        user,
        state,
        &req.user_id,
        &authorized,
        &req.signature,
        req.timestamp_ms,
        OP_EVTXO_ONBOARD,
    )?;

    // The cross-party onboarding context lives on the contract GROUP record, not on
    // any single party's policy.
    let mut group = crate::contract::group::load(shared.persistence.as_ref(), &own_id)
        .ok_or_else(|| Status::not_found("no contract group for this actor"))?;
    let spk_hex = hex::encode(&req.evtxo_script_pubkey);
    if spk_hex != group.spk_hex {
        return Err(Status::not_found("no such eVTXO on this contract"));
    }
    if group.cosigner_vprime_kp_json.is_empty() || group.author_id_hex.is_empty() {
        return Err(Status::failed_precondition(
            "contract does not support onboarding (one-shot V′==V)",
        ));
    }

    // The cosigner's canonical V′ key package + the original shareholder id-set.
    let holder_kp = KeyPackage::from_json(&group.cosigner_vprime_kp_json)
        .map_err(|e| Status::internal(format!("bad cosigner V′ kp: {e}")))?;
    let cosigner_id = holder_kp.identifier.clone();
    let author_id = parse_id(&group.author_id_hex)?;
    let id_set = [author_id, cosigner_id.clone()];

    // The participant's V′ identifier id_i = derive(recipient_vk) — must match what the
    // participant's wallet derives so its FROST share lands at the right identifier.
    let participant_id = Identifier::derive(&req.recipient_vk)
        .map_err(|e| Status::internal(format!("derive participant id: {e:?}")))?;

    // Cosigner's refresh half b_i = (b@id_i, b@cosigner) on a fresh polynomial through v′.
    let mut rng = OsRng;
    let slope_b = random::mod_n_random(&mut rng);
    let (b_at_p, b_at_c) =
        dkg::refresh_share_to_id(&holder_kp, &id_set, &participant_id, &cosigner_id, &slope_b)
            .map_err(|e| Status::internal(format!("refresh_share_to_id: {e:?}")))?;

    // C_i = a@cosigner + b@cosigner (the cosigner's counter-share for this participant).
    let a_at_c = scalar_from_bytes(
        &req.a_at_cosigner
            .clone()
            .try_into()
            .map_err(|_| Status::invalid_argument("a_at_cosigner must be 32 bytes"))?,
    )
    .map_err(|e| Status::invalid_argument(format!("bad a_at_cosigner: {e:?}")))?;
    let c_i = a_at_c + b_at_c;
    let c_i_point = point::base_mul(&c_i);

    // P_i·G = a@id_i·G (author's point) + b@id_i·G — the cosigner builds the verifying
    // share WITHOUT learning a@id_i (only its point), so it never learns P_i.
    let a_at_p_bytes: [u8; 33] = req
        .a_at_participant_point
        .clone()
        .try_into()
        .map_err(|_| Status::invalid_argument("a_at_participant_point must be 33 bytes"))?;
    let a_at_p_point = point::deserialize_compressed(&a_at_p_bytes)
        .map_err(|e| Status::invalid_argument(format!("bad a_at_participant_point: {e:?}")))?;
    let p_i_point = point::point_add(&a_at_p_point, &point::base_mul(&b_at_p));

    // V′ verifying key (even-Y ⇒ compressed prefix 0x02 over the x-only key).
    let mut vprime_bytes = [0u8; 33];
    vprime_bytes[0] = 0x02;
    let xonly = hex::decode(&group.evtxo_pk_xonly_hex)
        .map_err(|e| Status::internal(format!("bad evtxo_pk_xonly: {e}")))?;
    if xonly.len() != 32 {
        return Err(Status::internal("evtxo_pk_xonly must be 32 bytes"));
    }
    vprime_bytes[1..].copy_from_slice(&xonly);
    let vprime_point = point::deserialize_compressed(&vprime_bytes)
        .map_err(|e| Status::internal(format!("bad V′ point: {e:?}")))?;
    let vprime_vk = VerifyingKey::new(vprime_point);

    // The cosigner's C_i key package + the participant's 2-entry V′ PKP.
    let c_kp = KeyPackage {
        identifier: cosigner_id.clone(),
        secret_share: c_i,
        verifying_share: c_i_point,
        verifying_key: vprime_vk.clone(),
        min_signers: 2,
    };
    let mut verifying_shares: BTreeMap<Identifier, _> = BTreeMap::new();
    verifying_shares.insert(participant_id.clone(), p_i_point);
    verifying_shares.insert(cosigner_id.clone(), c_i_point);
    let pkp = PublicKeyPackage {
        verifying_shares,
        verifying_key: vprime_vk,
    };
    let pkp_json = pkp.to_json();

    // Mint the participant's OWN dedicated contract cosigner `cc_id` (single
    // recipient share, single-user roster) and add it to the group. No share is
    // written into a shared actor — the participant gets an isolated cosigner, so
    // 1 cosigner ⇔ 1 id ⇔ 1 user holds for it too.
    let recipient_vk_hex = hex::encode(&req.recipient_vk);
    crate::contract::group::register_member(
        shared.persistence.as_ref(),
        &mut group,
        &recipient_vk_hex,
        &c_kp.to_json(),
        &pkp_json,
    )?;
    crate::contract::group::save(shared.persistence.as_ref(), &group)?;

    // ECIES the cosigner's half b@id_i to the participant; hold both halves (the
    // author's + the cosigner's) in the participant's pickup inbox.
    let mut recipient_pk = [0u8; 33];
    if req.recipient_vk.len() != 33 {
        return Err(Status::invalid_argument("recipient_vk must be 33 bytes"));
    }
    recipient_pk.copy_from_slice(&req.recipient_vk);
    let ecies_cosigner = ecies::encrypt(&scalar_to_bytes(&b_at_p), &recipient_pk, &mut rng)
        .map_err(|e| Status::internal(format!("ecies encrypt: {e:?}")))?;

    let mut pending = load_pending(shared.persistence.as_ref(), &recipient_vk_hex);
    pending.retain(|r| r.spk_hex != spk_hex); // replace any prior for this eVTXO
    pending.push(PendingShareRecord {
        spk_hex: spk_hex.clone(),
        contract_group_id_hex: own_id.clone(),
        contract_id_hex: group.contract_id_hex.clone(),
        ecies_author_hex: hex::encode(&req.ecies_a_at_participant),
        ecies_cosigner_hex: hex::encode(ecies_cosigner),
        pkp_json,
        exit_delay: group.exit_delay,
        owner_pk_xonly_hex: group.owner_pk_xonly_hex.clone(),
    });
    save_pending(shared.persistence.as_ref(), &recipient_vk_hex, &pending)?;

    tracing::info!("[{own_id}] EvtxoOnboard complete for {recipient_vk_hex}");
    Ok(EvtxoOnboardResponse { ok: true })
}

/// Fetch the contract shares held for the calling participant (its own actor).
pub fn evtxo_pending_shares(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: EvtxoPendingSharesRequest,
) -> Result<EvtxoPendingSharesResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_EVTXO_PENDING,
    )?;

    let pending = load_pending(shared.persistence.as_ref(), &user_id_hex);
    let shares = pending
        .into_iter()
        .map(|r| PendingContractShare {
            evtxo_script_pubkey: hex::decode(&r.spk_hex).unwrap_or_default(),
            contract_group_id: hex::decode(&r.contract_group_id_hex).unwrap_or_default(),
            contract_id: hex::decode(&r.contract_id_hex).unwrap_or_default(),
            ecies_half_author: hex::decode(&r.ecies_author_hex).unwrap_or_default(),
            ecies_half_cosigner: hex::decode(&r.ecies_cosigner_hex).unwrap_or_default(),
            public_key_package_json: r.pkp_json,
            exit_delay: r.exit_delay,
            server_pk: Vec::new(), // the participant reads server_pk from GetArkInfo
            owner_pk: hex::decode(&r.owner_pk_xonly_hex).unwrap_or_default(),
        })
        .collect();
    Ok(EvtxoPendingSharesResponse { shares })
}

/// Clear a picked-up contract share from the participant's inbox.
pub fn evtxo_ack_share(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: EvtxoAckShareRequest,
) -> Result<EvtxoAckShareResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_EVTXO_ACK,
    )?;

    let spk_hex = hex::encode(&req.evtxo_script_pubkey);
    let mut pending = load_pending(shared.persistence.as_ref(), &user_id_hex);
    pending.retain(|r| r.spk_hex != spk_hex);
    save_pending(shared.persistence.as_ref(), &user_id_hex, &pending)?;
    Ok(EvtxoAckShareResponse { ok: true })
}
