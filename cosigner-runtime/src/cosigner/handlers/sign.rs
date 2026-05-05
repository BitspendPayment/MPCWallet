//! 2-party (one client + server): each call completes inline; no rendezvous.

use tonic::Status;

use crate::auth::message::{OP_SIGN_STEP1, OP_SIGN_STEP2};
use crate::crypto_ops;
use crate::policy::SpendingEntry;
use crate::shared::SharedServices;
use crate::cosigner::state::CosignerState;
use crate::wallet_proto::*;
use crate::cosigner::handlers::parsers;
use crate::cosigner::wasm::CosignerInstance;

use super::helpers::{
    auth_check, calculate_spent_amount, ensure_policy_loaded, persist_policy,
};

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

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_SIGN_STEP1,
    )?;

    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let policy_state = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?
        .clone();

    let user_identifier_hex = policy_state
        .user_signing_identifier_hex
        .clone()
        .unwrap_or_else(|| crypto_ops::identifier_derive(user, &req.user_id).unwrap_or_default());

    let mut server_kp_json = policy_state.normal_policy.key_package_json.clone();
    let pkp_json = policy_state.normal_policy.public_key_package_json.clone();

    // Policy evaluation
    let ft_len = req.full_transaction.len();
    let ft_is_psbt =
        ft_len > 5 && req.full_transaction[..5] == [0x70, 0x73, 0x62, 0x74, 0xff];
    tracing::info!(
        "[{user_id_hex}] SignStep1: fullTransaction len={ft_len}, is_psbt={ft_is_psbt}, script_path={}",
        req.script_path_spend
    );
    let spent_amount =
        calculate_spent_amount(user, &req.full_transaction, &pkp_json).unwrap_or(0);
    tracing::info!("[{user_id_hex}] SignStep1: spent_amount={spent_amount}");
    let selected_policy_id =
        parsers::evaluate_policy_for_amount(&policy_state, spent_amount);
    tracing::info!(
        "[{user_id_hex}] SignStep1: selected_policy_id={:?}",
        selected_policy_id
    );
    if let Some(ref policy_id) = selected_policy_id {
        if let Some(pp) = policy_state.protected_policies.get(policy_id) {
            server_kp_json = pp.key_package_json.clone();
            tracing::info!("[{user_id_hex}] SignStep1: Using Protected Policy {policy_id}");
        }
    } else {
        tracing::info!("[{user_id_hex}] SignStep1: Using Normal Policy");
    }

    // Reset stale signing session from a previous (possibly failed) attempt.
    if let Some(h) = user.signing_session {
        crypto_ops::signing_session_reset(user, h)
            .map_err(|e| Status::internal(format!("signing_session_reset: {e}")))?;
        user.signing_nonce = None;
    }
    if user.signing_session.is_none() {
        let h = crypto_ops::signing_session_create(user)
            .map_err(|e| Status::internal(format!("signing_session_create: {e}")))?;
        user.signing_session = Some(h);
    }
    let sign_h = user.signing_session.unwrap();

    crypto_ops::signing_session_set_user_hiding_hex(
        user,
        sign_h,
        &hex::encode(&req.hiding_commitment),
    )
    .map_err(|e| Status::internal(format!("set_hiding: {e}")))?;
    crypto_ops::signing_session_set_user_binding_hex(
        user,
        sign_h,
        &hex::encode(&req.binding_commitment),
    )
    .map_err(|e| Status::internal(format!("set_binding: {e}")))?;

    if let Some(ref policy_id) = selected_policy_id {
        crypto_ops::signing_session_set_current_policy_id(user, sign_h, policy_id)
            .map_err(|e| Status::internal(format!("set_policy_id: {e}")))?;
    }
    crypto_ops::signing_session_set_pending_amount(user, sign_h, spent_amount)
        .map_err(|e| Status::internal(format!("set_pending: {e}")))?;

    if req.script_path_spend {
        user.script_path_spend = true;
    }

    if !req.message_to_sign.is_empty() {
        let has_msg = crypto_ops::signing_session_has_message(user, sign_h)
            .map_err(|e| Status::internal(format!("has_message: {e}")))?;
        if !has_msg {
            crypto_ops::signing_session_set_message_to_sign(
                user,
                sign_h,
                &hex::encode(&req.message_to_sign),
            )
            .map_err(|e| Status::internal(format!("set_message: {e}")))?;
        }
    }

    // Server nonce generation (once)
    if user.signing_nonce.is_none() {
        tracing::info!("[{user_id_hex}] SignStep1: Server generating nonce");
        let secret_share_hex = parsers::extract_secret_share(&server_kp_json)?;
        let nonce_result = crypto_ops::new_nonce(user, &secret_share_hex)
            .map_err(|e| Status::internal(format!("new_nonce: {e}")))?;
        user.signing_nonce = Some(nonce_result.nonce_handle);
        let sign_h = user.signing_session.unwrap();
        crypto_ops::signing_session_set_server_commitments_json(
            user,
            sign_h,
            &nonce_result.commitments_json,
        )
        .map_err(|e| Status::internal(format!("set_server_comms: {e}")))?;
    }

    let sign_h = user.signing_session.unwrap();
    let server_identifier_hex = parsers::extract_identifier(&server_kp_json)?;
    let user_hiding = crypto_ops::signing_session_get_user_hiding_hex(user, sign_h)
        .map_err(|e| Status::internal(format!("get_hiding: {e}")))?;
    let has_server_comms = crypto_ops::signing_session_has_server_commitments(user, sign_h)
        .map_err(|e| Status::internal(format!("has_server_comms: {e}")))?;

    if !user_hiding.is_empty() && has_server_comms {
        let user_binding = crypto_ops::signing_session_get_user_binding_hex(user, sign_h)
            .map_err(|e| Status::internal(format!("get_binding: {e}")))?;
        let user_comms_json = serde_json::json!({
            "hiding": user_hiding,
            "binding": user_binding,
        })
        .to_string();
        let server_comms = crypto_ops::signing_session_get_server_commitments_json(user, sign_h)
            .map_err(|e| Status::internal(format!("get_server_comms: {e}")))?;
        crypto_ops::signing_session_insert_commitment(
            user,
            sign_h,
            &server_identifier_hex,
            &server_comms,
        )
        .map_err(|e| Status::internal(format!("insert_commit: {e}")))?;
        crypto_ops::signing_session_insert_commitment(
            user,
            sign_h,
            &user_identifier_hex,
            &user_comms_json,
        )
        .map_err(|e| Status::internal(format!("insert_commit: {e}")))?;
    }

    // Build response.
    let comms_json = crypto_ops::signing_session_get_commitments_json(user, sign_h)
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
    let msg_hex = crypto_ops::signing_session_get_message_to_sign(user, sign_h)
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
    shared: &SharedServices,
    req: SignStep2Request,
) -> Result<SignStep2Response, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] SignStep2");

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_SIGN_STEP2,
    )?;

    let policy_state = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?
        .clone();

    let user_identifier_hex = policy_state
        .user_signing_identifier_hex
        .clone()
        .unwrap_or_else(|| crypto_ops::identifier_derive(user, &req.user_id).unwrap_or_default());

    let mut server_kp_json = policy_state.normal_policy.key_package_json.clone();
    let sign_h = user
        .signing_session
        .ok_or_else(|| Status::internal("no signing session"))?;

    let current_policy_id = crypto_ops::signing_session_get_current_policy_id(user, sign_h)
        .map_err(|e| Status::internal(format!("get_policy_id: {e}")))?;
    if !current_policy_id.is_empty() {
        if let Some(pp) = policy_state.protected_policies.get(&current_policy_id) {
            server_kp_json = pp.key_package_json.clone();
        }
    }
    let server_identifier_hex = parsers::extract_identifier(&server_kp_json)?;

    // Store user's signature share.
    let share_hex = hex::encode(&req.signature_share);
    crypto_ops::signing_session_insert_share(user, sign_h, &user_identifier_hex, &share_hex)
        .map_err(|e| Status::internal(format!("insert_share: {e}")))?;

    // Server signing (once).
    let has_server_share =
        crypto_ops::signing_session_has_share(user, sign_h, &server_identifier_hex)
            .map_err(|e| Status::internal(format!("has_share: {e}")))?;
    if !has_server_share && user.signing_nonce.is_some() {
        tracing::info!("[{user_id_hex}] SignStep2: Server computing share");
        let comms_json = crypto_ops::signing_session_get_commitments_json(user, sign_h)
            .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
        let msg_hex = crypto_ops::signing_session_get_message_to_sign(user, sign_h)
            .map_err(|e| Status::internal(format!("get_message: {e}")))?;
        let signing_pkg_json = parsers::build_signing_package_json(&comms_json, &msg_hex)?;

        let sign_kp_json = if user.script_path_spend {
            server_kp_json.clone()
        } else {
            crypto_ops::key_package_tweak(user, &server_kp_json, None)
                .map_err(|e| Status::internal(format!("key_package_tweak: {e}")))?
        };
        let nonce = user.signing_nonce.take().unwrap();
        let server_share_hex =
            crypto_ops::frost_sign(user, &signing_pkg_json, nonce, &sign_kp_json)
                .map_err(|e| Status::internal(format!("frost_sign: {e}")))?;
        let sign_h = user.signing_session.unwrap();
        crypto_ops::signing_session_insert_share(
            user,
            sign_h,
            &server_identifier_hex,
            &server_share_hex,
        )
        .map_err(|e| Status::internal(format!("insert_share: {e}")))?;
    }

    let sign_h = user.signing_session.unwrap();
    let share_count = crypto_ops::signing_session_share_count(user, sign_h)
        .map_err(|e| Status::internal(format!("share_count: {e}")))?;
    if share_count < THRESHOLD_COUNT {
        return Err(Status::internal("share count below threshold"));
    }

    // Aggregate.
    let mut server_pkp_json = policy_state.normal_policy.public_key_package_json.clone();
    if !current_policy_id.is_empty() {
        if let Some(pp) = policy_state.protected_policies.get(&current_policy_id) {
            server_pkp_json = pp.public_key_package_json.clone();
        }
    }
    let comms_json = crypto_ops::signing_session_get_commitments_json(user, sign_h)
        .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
    let msg_hex = crypto_ops::signing_session_get_message_to_sign(user, sign_h)
        .map_err(|e| Status::internal(format!("get_message: {e}")))?;
    let signing_pkg_json = parsers::build_signing_package_json(&comms_json, &msg_hex)?;
    let shares_json = crypto_ops::signing_session_get_shares_json(user, sign_h)
        .map_err(|e| Status::internal(format!("get_shares: {e}")))?;
    let pending = crypto_ops::signing_session_get_pending_amount(user, sign_h)
        .map_err(|e| Status::internal(format!("get_pending: {e}")))?;

    let agg_pkp_json = if user.script_path_spend {
        server_pkp_json.clone()
    } else {
        crypto_ops::pub_key_package_tweak(user, &server_pkp_json, None)
            .map_err(|e| Status::internal(format!("pub_key_package_tweak: {e}")))?
    };
    let agg_result_json =
        crypto_ops::frost_aggregate(user, &signing_pkg_json, &shares_json, &agg_pkp_json)
            .map_err(|e| Status::internal(format!("frost_aggregate: {e}")))?;
    let agg_val: serde_json::Value = serde_json::from_str(&agg_result_json)
        .map_err(|e| Status::internal(format!("parse aggregate: {e}")))?;
    let r_hex = agg_val["R"]
        .as_str()
        .ok_or_else(|| Status::internal("missing R"))?;
    let z_hex = agg_val["Z"]
        .as_str()
        .ok_or_else(|| Status::internal("missing Z"))?;
    let r_bytes =
        hex::decode(r_hex).map_err(|e| Status::internal(format!("hex decode R: {e}")))?;
    let z_bytes =
        hex::decode(z_hex).map_err(|e| Status::internal(format!("hex decode Z: {e}")))?;

    tracing::info!("[{user_id_hex}] SignStep2: Aggregated");

    // Record spending.
    if pending > 0 {
        if let Some(ps) = user.policy_state.as_mut() {
            ps.spending_history.push(SpendingEntry {
                timestamp_ms: parsers::now_ms(),
                amount_sats: pending,
            });
            let _ = persist_policy(shared, &user_id_hex, ps);
        }
    }

    // Reset session.
    let sign_h = user.signing_session.unwrap();
    crypto_ops::signing_session_reset(user, sign_h)
        .map_err(|e| Status::internal(format!("signing_session_reset: {e}")))?;
    user.signing_nonce = None;
    user.script_path_spend = false;

    Ok(SignStep2Response {
        r_point: r_bytes,
        z_scalar: z_bytes,
    })
}
