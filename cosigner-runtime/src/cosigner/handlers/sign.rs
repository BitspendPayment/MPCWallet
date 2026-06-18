//! 2-party (one client + server): each call completes inline; no rendezvous.

use tonic::Status;

use crate::auth::message::{OP_SIGN_STEP1, OP_SIGN_STEP2};
use crate::cosigner::handlers::parsers;
use crate::cosigner::registry::CosignerInstance;
use crate::cosigner::state::CosignerState;
use crate::shared::SharedServices;
use crate::wallet_proto::*;

use super::helpers::{auth_check, calculate_spent_amount, ensure_policy_loaded};

const THRESHOLD_COUNT: u32 = 2;

#[tracing::instrument(skip_all, name = "actor::sign_step1", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn sign_step1(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: SignStep1Request,
) -> Result<SignStep1Response, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] SignStep1");

    // Load the actor's OWN policy (keyed by its spawn id). For a contract actor this
    // is the V′ policy (GroupID), not the spending recipient's wallet.
    let own_id = state.cosigner_id.clone();
    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &own_id,
    )?;
    let policy_state = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?
        .clone();

    // Detect a contract spend up front: if any input spends a registered contract
    // scriptPubKey on this policy, this is a contract cooperative spend (V′), and
    // the claimed verifying share (req.user_id) must be one of THAT contract's
    // registered recipients — the user (pairing A) or the always-online service
    // (pairing B). A plain spend authenticates the wallet's single owner.
    let contract_spk =
        super::contract_gate::detect_contract_spend(&policy_state, &req.full_transaction);

    if let Some(spk_hex) = contract_spk.as_ref() {
        let authorized: Vec<String> = policy_state
            .contracts
            .get(spk_hex)
            .map(|cp| cp.authorized_verifying_keys())
            .unwrap_or_default();
        super::helpers::auth_check_group(
            user,
            state,
            &req.user_id,
            &authorized,
            &req.signature,
            req.timestamp_ms,
            OP_SIGN_STEP1,
        )?;
    } else {
        auth_check(
            user,
            state,
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_SIGN_STEP1,
        )?;
    }

    // Stash the spend for the contract gate: the cosigner wasm calls the
    // `contract-gate` host capability from inside frost_sign (step2) and refuses
    // to produce its share on Deny. The host evaluates the contract over this tx
    // in its isolated sandbox. (No host-side gate call here — the guest drives it.)
    user.store.data_mut().current_full_tx = Some(req.full_transaction.clone());

    // Select the signing key + PKP: a contract spend selects the authenticated
    // recipient's V′ counter-share (req.user_id = its verifying share); everything
    // else uses the normal 2-of-2 key.
    let is_contract_spend = contract_spk.is_some();
    let selected_policy_id = contract_spk.map(|spk_hex| {
        tracing::info!("[{user_id_hex}] SignStep1: contract cooperative spend — using V′ key");
        format!("evtxo:{spk_hex}")
    });
    let (server_kp_json, server_pkp_json) = parsers::resolve_signing_key(
        &policy_state,
        selected_policy_id.as_deref().unwrap_or(""),
        &user_id_hex,
    );

    // The recipient's V′ identifier: for a contract spend it is the non-cosigner
    // entry of the recipient's 2-entry V′ PKP. A normal wallet uses its stored
    // signing identifier (or a derived one).
    let user_identifier_hex = if is_contract_spend {
        let cosigner_id = parsers::extract_identifier(&server_kp_json)?;
        parsers::extract_recipient_identifier(&server_pkp_json, &cosigner_id)?
    } else {
        policy_state
            .user_signing_identifier_hex
            .clone()
            .unwrap_or_else(|| user.identifier_derive(&req.user_id).unwrap_or_default())
    };

    // PKP for spent-amount logging: the V′ PKP for a contract spend, else the wallet's.
    let pkp_json = if is_contract_spend {
        server_pkp_json.clone()
    } else {
        policy_state.normal_policy.public_key_package_json.clone()
    };

    let ft_len = req.full_transaction.len();
    let ft_is_psbt = ft_len > 5 && req.full_transaction[..5] == [0x70, 0x73, 0x62, 0x74, 0xff];
    tracing::info!(
        "[{user_id_hex}] SignStep1: fullTransaction len={ft_len}, is_psbt={ft_is_psbt}, script_path={}",
        req.script_path_spend
    );
    let spent_amount = calculate_spent_amount(user, &req.full_transaction, &pkp_json).unwrap_or(0);
    tracing::info!("[{user_id_hex}] SignStep1: spent_amount={spent_amount}");

    // The session lives for the whole instance; reset it for a fresh round (this also
    // clears any prior single-use nonce).
    let sign_h = user
        .session
        .ok_or_else(|| Status::internal("no session"))?;
    user.signing_session_reset(sign_h)
        .map_err(|e| Status::internal(format!("session reset: {e}")))?;

    user.signing_session_set_user_hiding_hex(sign_h, &hex::encode(&req.hiding_commitment))
        .map_err(|e| Status::internal(format!("set_hiding: {e}")))?;
    user.signing_session_set_user_binding_hex(sign_h, &hex::encode(&req.binding_commitment))
        .map_err(|e| Status::internal(format!("set_binding: {e}")))?;

    if let Some(ref policy_id) = selected_policy_id {
        user.signing_session_set_current_policy_id(sign_h, policy_id)
            .map_err(|e| Status::internal(format!("set_policy_id: {e}")))?;
    }
    user.signing_session_set_pending_amount(sign_h, spent_amount)
        .map_err(|e| Status::internal(format!("set_pending: {e}")))?;

    if req.script_path_spend {
        user.script_path_spend = true;
    }

    if !req.message_to_sign.is_empty() {
        let has_msg = user
            .signing_session_has_message(sign_h)
            .map_err(|e| Status::internal(format!("has_message: {e}")))?;
        if !has_msg {
            user.signing_session_set_message_to_sign(sign_h, &hex::encode(&req.message_to_sign))
                .map_err(|e| Status::internal(format!("set_message: {e}")))?;
        }
    }

    // Server nonce: generate this round's single-use nonce (held inside the session).
    tracing::info!("[{user_id_hex}] SignStep1: Server generating nonce");
    let secret_share_hex = parsers::extract_secret_share(&server_kp_json)?;
    let commitments_json = user
        .new_nonce(&secret_share_hex)
        .map_err(|e| Status::internal(format!("new_nonce: {e}")))?;
    user.signing_session_set_server_commitments_json(sign_h, &commitments_json)
        .map_err(|e| Status::internal(format!("set_server_comms: {e}")))?;

    let server_identifier_hex = parsers::extract_identifier(&server_kp_json)?;
    let user_hiding = user
        .signing_session_get_user_hiding_hex(sign_h)
        .map_err(|e| Status::internal(format!("get_hiding: {e}")))?;
    let has_server_comms = user
        .signing_session_has_server_commitments(sign_h)
        .map_err(|e| Status::internal(format!("has_server_comms: {e}")))?;

    if !user_hiding.is_empty() && has_server_comms {
        let user_binding = user
            .signing_session_get_user_binding_hex(sign_h)
            .map_err(|e| Status::internal(format!("get_binding: {e}")))?;
        let user_comms_json = serde_json::json!({
            "hiding": user_hiding,
            "binding": user_binding,
        })
        .to_string();
        let server_comms = user
            .signing_session_get_server_commitments_json(sign_h)
            .map_err(|e| Status::internal(format!("get_server_comms: {e}")))?;
        user.signing_session_insert_commitment(sign_h, &server_identifier_hex, &server_comms)
            .map_err(|e| Status::internal(format!("insert_commit: {e}")))?;
        user.signing_session_insert_commitment(sign_h, &user_identifier_hex, &user_comms_json)
            .map_err(|e| Status::internal(format!("insert_commit: {e}")))?;
    }

    // Build response.
    let comms_json = user
        .signing_session_get_commitments_json(sign_h)
        .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
    let comms_map = parsers::parse_json_string_map(&comms_json)?;
    let mut response = SignStep1Response::default();
    for (id_hex, comms_json_str) in &comms_map {
        let comms_val: serde_json::Value = serde_json::from_str(comms_json_str)
            .map_err(|e| Status::internal(format!("bad commitments JSON: {e}")))?;
        let hiding_hex = comms_val["hiding"]
            .as_str()
            .ok_or_else(|| Status::internal("missing hiding"))?;
        let binding_hex = comms_val["binding"]
            .as_str()
            .ok_or_else(|| Status::internal("missing binding"))?;
        let hiding_bytes = hex::decode(hiding_hex)
            .map_err(|e| Status::internal(format!("hex decode hiding: {e}")))?;
        let binding_bytes = hex::decode(binding_hex)
            .map_err(|e| Status::internal(format!("hex decode binding: {e}")))?;
        response.commitments.insert(
            id_hex.clone(),
            sign_step1_response::Commitment {
                hiding: hiding_bytes,
                binding: binding_bytes,
            },
        );
    }
    let msg_hex = user
        .signing_session_get_message_to_sign(sign_h)
        .map_err(|e| Status::internal(format!("get_message: {e}")))?;
    response.message_to_sign = if msg_hex.is_empty() {
        vec![]
    } else {
        hex::decode(&msg_hex).unwrap_or_default()
    };
    Ok(response)
}

#[tracing::instrument(skip_all, name = "actor::sign_step2", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn sign_step2(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    _shared: &SharedServices,
    req: SignStep2Request,
) -> Result<SignStep2Response, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] SignStep2");

    // Policy was loaded in sign_step1 and persists on the instance.
    let policy_state = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?
        .clone();

    // Recover the signing session + the policy id chosen in step1, so the auth
    // split matches step1: a contract spend (policy id "evtxo:<spk>") authorizes
    // the claimed recipient against that contract's recipient set; a normal spend
    // authenticates the wallet's single owner.
    let sign_h = user
        .session
        .ok_or_else(|| Status::internal("no session"))?;
    let current_policy_id = user
        .signing_session_get_current_policy_id(sign_h)
        .map_err(|e| Status::internal(format!("get_policy_id: {e}")))?;
    let contract_spk = current_policy_id
        .strip_prefix("evtxo:")
        .map(|s| s.to_string());
    let is_contract_spend = contract_spk.is_some();

    if let Some(spk_hex) = contract_spk.as_ref() {
        let authorized: Vec<String> = policy_state
            .contracts
            .get(spk_hex)
            .map(|cp| cp.authorized_verifying_keys())
            .unwrap_or_default();
        super::helpers::auth_check_group(
            user,
            state,
            &req.user_id,
            &authorized,
            &req.signature,
            req.timestamp_ms,
            OP_SIGN_STEP2,
        )?;
    } else {
        auth_check(
            user,
            state,
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_SIGN_STEP2,
        )?;
    }

    // Same resolution as sign_step1 (normal / contract V′) so the key + identifiers
    // stay consistent across both steps.
    let (server_kp_json, server_pkp_json) =
        parsers::resolve_signing_key(&policy_state, &current_policy_id, &user_id_hex);
    let server_identifier_hex = parsers::extract_identifier(&server_kp_json)?;

    // Recipient's V′ identifier id_i (see sign_step1) — read from the V′ PKP for a
    // contract spend, else the wallet's stored/derived identifier.
    let user_identifier_hex = if is_contract_spend {
        parsers::extract_recipient_identifier(&server_pkp_json, &server_identifier_hex)?
    } else {
        policy_state
            .user_signing_identifier_hex
            .clone()
            .unwrap_or_else(|| user.identifier_derive(&req.user_id).unwrap_or_default())
    };

    // Store user's signature share.
    let share_hex = hex::encode(&req.signature_share);
    user.signing_session_insert_share(sign_h, &user_identifier_hex, &share_hex)
        .map_err(|e| Status::internal(format!("insert_share: {e}")))?;

    // Server signing (once).
    let has_server_share = user
        .signing_session_has_share(sign_h, &server_identifier_hex)
        .map_err(|e| Status::internal(format!("has_share: {e}")))?;
    if !has_server_share {
        tracing::info!("[{user_id_hex}] SignStep2: Server computing share");
        let comms_json = user
            .signing_session_get_commitments_json(sign_h)
            .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
        let msg_hex = user
            .signing_session_get_message_to_sign(sign_h)
            .map_err(|e| Status::internal(format!("get_message: {e}")))?;
        let signing_pkg_json = parsers::build_signing_package_json(&comms_json, &msg_hex)?;

        let sign_kp_json = if user.script_path_spend {
            server_kp_json.clone()
        } else {
            user.key_package_tweak(&server_kp_json, None)
                .map_err(|e| Status::internal(format!("key_package_tweak: {e}")))?
        };
        // The session holds the single-use nonce generated in step1.
        let server_share_hex = user
            .frost_sign(&signing_pkg_json, &sign_kp_json)
            .map_err(|e| Status::internal(format!("frost_sign: {e}")))?;
        user.signing_session_insert_share(sign_h, &server_identifier_hex, &server_share_hex)
            .map_err(|e| Status::internal(format!("insert_share: {e}")))?;
    }

    let share_count = user
        .signing_session_share_count(sign_h)
        .map_err(|e| Status::internal(format!("share_count: {e}")))?;
    if share_count < THRESHOLD_COUNT {
        return Err(Status::internal("share count below threshold"));
    }

    // Aggregate.
    let server_pkp_json =
        parsers::resolve_signing_key(&policy_state, &current_policy_id, &user_id_hex).1;
    let comms_json = user
        .signing_session_get_commitments_json(sign_h)
        .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
    let msg_hex = user
        .signing_session_get_message_to_sign(sign_h)
        .map_err(|e| Status::internal(format!("get_message: {e}")))?;
    let signing_pkg_json = parsers::build_signing_package_json(&comms_json, &msg_hex)?;
    let shares_json = user
        .signing_session_get_shares_json(sign_h)
        .map_err(|e| Status::internal(format!("get_shares: {e}")))?;

    let agg_pkp_json = if user.script_path_spend {
        server_pkp_json.clone()
    } else {
        user.pub_key_package_tweak(&server_pkp_json, None)
            .map_err(|e| Status::internal(format!("pub_key_package_tweak: {e}")))?
    };
    let agg_result_json = user
        .frost_aggregate(&signing_pkg_json, &shares_json, &agg_pkp_json)
        .map_err(|e| Status::internal(format!("frost_aggregate: {e}")))?;
    let agg_val: serde_json::Value = serde_json::from_str(&agg_result_json)
        .map_err(|e| Status::internal(format!("parse aggregate: {e}")))?;
    let r_hex = agg_val["R"]
        .as_str()
        .ok_or_else(|| Status::internal("missing R"))?;
    let z_hex = agg_val["Z"]
        .as_str()
        .ok_or_else(|| Status::internal("missing Z"))?;
    let r_bytes = hex::decode(r_hex).map_err(|e| Status::internal(format!("hex decode R: {e}")))?;
    let z_bytes = hex::decode(z_hex).map_err(|e| Status::internal(format!("hex decode Z: {e}")))?;

    tracing::info!("[{user_id_hex}] SignStep2: Aggregated");

    // Reset session (clears commitments, shares, message, and the nonce).
    user.store.data_mut().current_full_tx = None;
    user.signing_session_reset(sign_h)
        .map_err(|e| Status::internal(format!("session reset: {e}")))?;
    user.script_path_spend = false;

    Ok(SignStep2Response {
        r_point: r_bytes,
        z_scalar: z_bytes,
    })
}
