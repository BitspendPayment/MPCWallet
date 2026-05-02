use tonic::Status;

use crate::auth::message::{
    build_delete_policy_message, build_update_policy_message, OP_DELETE_POLICY,
    OP_GET_POLICY_ID, OP_UPDATE_POLICY,
};
use crate::crypto_ops;
use crate::policy::ProtectedPolicy;
use crate::shared::SharedServices;
use crate::cosigner::registry::CosignerRegistry;
use crate::cosigner::state::CosignerState;
use crate::wallet_proto::*;
use crate::cosigner::handlers::parsers;
use crate::cosigner::wasm::CosignerInstance;

use super::helpers::{
    auth_check, calculate_spent_amount, ensure_policy_loaded, persist_policy, timestamp_check,
};

#[tracing::instrument(skip_all, name = "actor::get_policy_id", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn get_policy_id(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    _registry: &CosignerRegistry,
    req: GetPolicyIdRequest,
) -> Result<GetPolicyIdResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] GetPolicyId");

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_GET_POLICY_ID,
    )?;

    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let pkp_json = user
        .policy_state
        .as_ref()
        .unwrap()
        .normal_policy
        .public_key_package_json
        .clone();

    let spent_amount = calculate_spent_amount(user, &req.tx_message, &pkp_json).unwrap_or(0);

    let policy_state = user.policy_state.as_ref().unwrap();
    let policy_id =
        parsers::evaluate_policy_for_amount(policy_state, spent_amount).unwrap_or_default();

    Ok(GetPolicyIdResponse { policy_id })
}

#[tracing::instrument(skip_all, name = "actor::update_policy", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn update_policy(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    registry: &CosignerRegistry,
    req: UpdatePolicyRequest,
) -> Result<UpdatePolicyResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] UpdatePolicy: policy={}", req.policy_id);

    timestamp_check(state, req.timestamp_ms, &user_id_hex, OP_UPDATE_POLICY)?;

    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let (vk_hex, existing) = {
        let ps = user
            .policy_state
            .as_ref()
            .ok_or_else(|| Status::not_found("no policy state"))?;
        if !ps.protected_policies.contains_key(&req.policy_id) {
            return Err(Status::not_found(format!(
                "Policy {} not found",
                req.policy_id
            )));
        }
        let vk = parsers::extract_verifying_key(&ps.normal_policy.public_key_package_json)?;
        let existing = ps.protected_policies.get(&req.policy_id).unwrap().clone();
        (vk, existing)
    };

    let message = build_update_policy_message(
        &req.policy_id,
        req.threshold_sats,
        req.interval_seconds,
        req.timestamp_ms,
        &user_id_hex,
    );
    let r_hex = hex::encode(&req.frost_signature_r);
    let z_hex = hex::encode(&req.frost_signature_z);
    let sig_hex = format!("{}{}", r_hex, z_hex);

    let is_valid = crypto_ops::verify_schnorr_signature(user, &vk_hex, &message, &sig_hex)
        .map_err(|e| Status::internal(format!("verify error: {e}")))?;
    if !is_valid {
        return Err(Status::unauthenticated("Invalid recovery signature"));
    }

    let updated = ProtectedPolicy {
        id: existing.id,
        threshold_sats: req.threshold_sats,
        start_time_ms: existing.start_time_ms,
        interval_seconds: req.interval_seconds,
        key_package_json: existing.key_package_json,
        public_key_package_json: existing.public_key_package_json,
    };

    if let Some(ps) = user.policy_state.as_mut() {
        ps.protected_policies.insert(updated.id.clone(), updated);
        persist_policy(shared, registry, &user_id_hex, ps)?;
    }

    tracing::info!("[{user_id_hex}] UpdatePolicy: success");
    Ok(UpdatePolicyResponse { success: true })
}

#[tracing::instrument(skip_all, name = "actor::delete_policy", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn delete_policy(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    registry: &CosignerRegistry,
    req: DeletePolicyRequest,
) -> Result<DeletePolicyResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] DeletePolicy: policy={}", req.policy_id);

    timestamp_check(state, req.timestamp_ms, &user_id_hex, OP_DELETE_POLICY)?;

    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let policy_state = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?;
    if !policy_state.protected_policies.contains_key(&req.policy_id) {
        return Err(Status::not_found(format!(
            "Policy {} not found",
            req.policy_id
        )));
    }

    let message = build_delete_policy_message(&req.policy_id, req.timestamp_ms, &user_id_hex);
    let r_hex = hex::encode(&req.frost_signature_r);
    let z_hex = hex::encode(&req.frost_signature_z);
    let sig_hex = format!("{}{}", r_hex, z_hex);
    let vk_hex =
        parsers::extract_verifying_key(&policy_state.normal_policy.public_key_package_json)?;

    let is_valid = crypto_ops::verify_schnorr_signature(user, &vk_hex, &message, &sig_hex)
        .map_err(|e| Status::internal(format!("verify error: {e}")))?;
    if !is_valid {
        return Err(Status::unauthenticated("Invalid recovery signature"));
    }

    if let Some(ps) = user.policy_state.as_mut() {
        ps.protected_policies.remove(&req.policy_id);
        persist_policy(shared, registry, &user_id_hex, ps)?;
    }

    tracing::info!("[{user_id_hex}] DeletePolicy: success");
    Ok(DeletePolicyResponse { success: true })
}
