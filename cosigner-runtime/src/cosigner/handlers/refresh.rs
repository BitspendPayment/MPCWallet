//! 2-party (client + server, n=2): each step completes inline; no rendezvous.

use base64::Engine;
use rand::Rng;
use tonic::Status;

use crate::auth::message::{OP_REFRESH_STEP1, OP_REFRESH_STEP2, OP_REFRESH_STEP3};
use crate::crypto_ops;
use crate::policy::ProtectedPolicy;
use crate::shared::SharedServices;
use crate::cosigner::state::CosignerState;
use crate::wallet_proto::*;
use crate::cosigner::handlers::parsers;
use crate::cosigner::wasm::CosignerInstance;

use super::helpers::{auth_check, ensure_policy_loaded, persist_policy};

const THRESHOLD_COUNT: u32 = 2;

fn random_base64(bytes: usize) -> String {
    let mut rng = rand::thread_rng();
    let values: Vec<u8> = (0..bytes).map(|_| rng.gen()).collect();
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(&values)
}

#[tracing::instrument(skip_all, name = "actor::refresh_step1", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn refresh_step1(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: RefreshStep1Request,
) -> Result<RefreshStep1Response, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] RefreshStep1");

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_REFRESH_STEP1,
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

    // Auto-reset if a previous refresh completed (round1_secret is None means
    // step3 finalized; round2_secret None too). The strict marker is: if a
    // refresh_session exists AND round2_secret is None AND we're getting a
    // new round1 from the user — start fresh.
    if user.refresh_session.is_some() && user.round1_secret.is_none() && user.round2_secret.is_none()
    {
        tracing::info!("[{user_id_hex}] RefreshStep1: Resetting previous session");
        if let Some(h) = user.refresh_session {
            crypto_ops::refresh_session_reset(user, h)
                .map_err(|e| Status::internal(format!("refresh_reset: {e}")))?;
        }
    }

    if user.refresh_session.is_none() {
        let h = crypto_ops::refresh_session_create(user)
            .map_err(|e| Status::internal(format!("refresh_session_create: {e}")))?;
        user.refresh_session = Some(h);
    }
    let refresh_h = user.refresh_session.unwrap();

    crypto_ops::refresh_session_insert_round1_package(
        user,
        refresh_h,
        &user_identifier_hex,
        &req.round1_package,
    )
    .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;

    // Server init (once)
    if user.round1_secret.is_none() {
        tracing::info!("[{user_id_hex}] Server: Generating Refresh secrets");
        let server_identifier_hex =
            parsers::extract_identifier(&policy_state.normal_policy.key_package_json)?;
        let server_id_hex = parsers::extract_verifying_key(
            &policy_state.normal_policy.public_key_package_json,
        )?;
        let server_id_bytes = hex::decode(&server_id_hex)
            .map_err(|e| Status::internal(format!("hex decode: {e}")))?;

        let refresh_h = user.refresh_session.unwrap();
        crypto_ops::refresh_session_set_server_id(
            user,
            refresh_h,
            &hex::encode(&server_id_bytes),
        )
        .map_err(|e| Status::internal(format!("set_server_id: {e}")))?;
        crypto_ops::refresh_session_set_server_identifier_hex(
            user,
            refresh_h,
            &server_identifier_hex,
        )
        .map_err(|e| Status::internal(format!("set_server_id_hex: {e}")))?;

        let result = crypto_ops::dkg_refresh_part1(
            user,
            &server_identifier_hex,
            2,
            THRESHOLD_COUNT,
            &[],
        )
        .map_err(|e| Status::internal(format!("dkg_refresh_part1: {e}")))?;

        user.round1_secret = Some(result.secret_handle);

        let refresh_h = user.refresh_session.unwrap();
        let creation_ms = crypto_ops::refresh_session_get_refresh_creation_time_ms(user, refresh_h)
            .map_err(|e| Status::internal(format!("get_creation_time: {e}")))?;
        if creation_ms == 0 {
            crypto_ops::refresh_session_set_refresh_creation_time_ms(
                user,
                refresh_h,
                parsers::now_ms(),
            )
            .map_err(|e| Status::internal(format!("set_creation_time: {e}")))?;
            crypto_ops::refresh_session_set_refresh_id(user, refresh_h, &random_base64(32))
                .map_err(|e| Status::internal(format!("set_refresh_id: {e}")))?;
            crypto_ops::refresh_session_set_refresh_threshold_amount(
                user,
                refresh_h,
                req.threshold_amount,
            )
            .map_err(|e| Status::internal(format!("set_threshold: {e}")))?;
            crypto_ops::refresh_session_set_refresh_interval(user, refresh_h, req.interval)
                .map_err(|e| Status::internal(format!("set_interval: {e}")))?;
        }

        crypto_ops::refresh_session_insert_round1_package(
            user,
            refresh_h,
            &server_identifier_hex,
            &result.round1_package_json,
        )
        .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;
    }

    // Build response
    let refresh_h = user.refresh_session.unwrap();
    let round1_json = crypto_ops::refresh_session_get_round1_packages_json(user, refresh_h)
        .map_err(|e| Status::internal(format!("get_round1: {e}")))?;
    let pkgs = parsers::parse_json_string_map(&round1_json)?;
    let mut response = RefreshStep1Response::default();
    for (id_hex, pkg_json) in &pkgs {
        response
            .round1_packages
            .insert(id_hex.clone(), pkg_json.clone());
    }
    response.start_time =
        crypto_ops::refresh_session_get_refresh_creation_time_ms(user, refresh_h)
            .map_err(|e| Status::internal(format!("get_creation_time: {e}")))?;
    response.policy_id = crypto_ops::refresh_session_get_refresh_id(user, refresh_h)
        .map_err(|e| Status::internal(format!("get_refresh_id: {e}")))?;
    Ok(response)
}

#[tracing::instrument(skip_all, name = "actor::refresh_step2", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn refresh_step2(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    _shared: &SharedServices,
    req: RefreshStep2Request,
) -> Result<RefreshStep2Response, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] RefreshStep2");

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_REFRESH_STEP2,
    )?;

    let refresh_h = user
        .refresh_session
        .ok_or_else(|| Status::internal("no refresh session"))?;
    let server_identifier_hex =
        crypto_ops::refresh_session_get_server_identifier_hex(user, refresh_h)
            .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
    if server_identifier_hex.is_empty() {
        return Err(Status::internal("server identifier not set"));
    }

    let is_local_empty = crypto_ops::refresh_session_is_round2_local_empty(user, refresh_h)
        .map_err(|e| Status::internal(format!("is_local_empty: {e}")))?;
    if is_local_empty {
        tracing::info!("[{user_id_hex}] RefreshStep2: Server computing round2");
        let round1_pkgs_json = crypto_ops::refresh_session_get_round1_packages_excluding_json(
            user,
            refresh_h,
            &server_identifier_hex,
        )
        .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;
        let round1_secret = user
            .round1_secret
            .take()
            .ok_or_else(|| Status::internal("round1 secret missing"))?;
        let result = crypto_ops::dkg_refresh_part2(user, round1_secret, &round1_pkgs_json)
            .map_err(|e| Status::internal(format!("dkg_refresh_part2: {e}")))?;
        user.round2_secret = Some(result.secret_handle);
        let local_pkgs = parsers::parse_round2_result(&result.round2_packages_json)?;
        let local_json = serde_json::to_string(&local_pkgs)
            .map_err(|e| Status::internal(format!("serialize: {e}")))?;
        let refresh_h = user.refresh_session.unwrap();
        crypto_ops::refresh_session_set_round2_local_json(user, refresh_h, &local_json)
            .map_err(|e| Status::internal(format!("set_round2_local: {e}")))?;
    }

    let refresh_h = user.refresh_session.unwrap();
    let round1_json = crypto_ops::refresh_session_get_round1_packages_json(user, refresh_h)
        .map_err(|e| Status::internal(format!("get_round1: {e}")))?;
    let pkgs = parsers::parse_json_string_map(&round1_json)?;
    let mut response = RefreshStep2Response::default();
    for (id_hex, pkg_json) in &pkgs {
        response
            .all_round1_packages
            .insert(id_hex.clone(), pkg_json.clone());
    }
    Ok(response)
}

#[tracing::instrument(skip_all, name = "actor::refresh_step3", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn refresh_step3(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: RefreshStep3Request,
) -> Result<RefreshStep3Response, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] RefreshStep3");

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_REFRESH_STEP3,
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

    let refresh_h = user
        .refresh_session
        .ok_or_else(|| Status::internal("no refresh session"))?;
    let server_identifier_hex =
        crypto_ops::refresh_session_get_server_identifier_hex(user, refresh_h)
            .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;

    // Store round2 packages from user
    for (recipient_hex, pkg_json) in &req.round2_packages_for_others {
        if recipient_hex == &server_identifier_hex {
            crypto_ops::refresh_session_insert_round2_received(
                user,
                refresh_h,
                &user_identifier_hex,
                pkg_json,
            )
            .map_err(|e| Status::internal(format!("insert_round2: {e}")))?;
        }
    }
    let sender_pkgs_json = serde_json::to_string(&req.round2_packages_for_others)
        .map_err(|e| Status::internal(format!("serialize: {e}")))?;
    crypto_ops::refresh_session_insert_relay_packages(
        user,
        refresh_h,
        &user_identifier_hex,
        &sender_pkgs_json,
    )
    .map_err(|e| Status::internal(format!("insert_relay: {e}")))?;

    let relay_count = crypto_ops::refresh_session_relay_sender_count(user, refresh_h)
        .map_err(|e| Status::internal(format!("relay_count: {e}")))?;

    if relay_count >= 1 {
        crypto_ops::refresh_session_insert_relay_from_local(user, refresh_h, &server_identifier_hex)
            .map_err(|e| Status::internal(format!("insert_relay_from_local: {e}")))?;
    }

    // Build packages for the requester
    let relay_json = crypto_ops::refresh_session_get_relay_packages_for(
        user,
        refresh_h,
        &user_identifier_hex,
    )
    .map_err(|e| Status::internal(format!("get_relay_for: {e}")))?;
    let packages_for_me = parsers::parse_json_string_map(&relay_json)?;

    // Server key derivation
    if user.round2_secret.is_some() {
        tracing::info!("[{user_id_hex}] RefreshStep3: Server computing new key");
        let refresh_h = user.refresh_session.unwrap();
        let server_identifier_hex =
            crypto_ops::refresh_session_get_server_identifier_hex(user, refresh_h)
                .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
        let round1_pkgs_json = crypto_ops::refresh_session_get_round1_packages_excluding_json(
            user,
            refresh_h,
            &server_identifier_hex,
        )
        .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;
        let round2_received_json =
            crypto_ops::refresh_session_get_round2_received_json(user, refresh_h)
                .map_err(|e| Status::internal(format!("get_round2: {e}")))?;
        let old_pkp_json = policy_state.normal_policy.public_key_package_json.clone();
        let old_kp_json = policy_state.normal_policy.key_package_json.clone();

        let round2_secret = user.round2_secret.take().unwrap();
        let result = crypto_ops::dkg_refresh_part3(
            user,
            round2_secret,
            &round1_pkgs_json,
            &round2_received_json,
            &old_pkp_json,
            &old_kp_json,
        )
        .map_err(|e| Status::internal(format!("dkg_refresh_part3: {e}")))?;

        let old_vk = parsers::extract_verifying_key(&old_pkp_json)?;
        let new_vk = parsers::extract_verifying_key(&result.public_key_package_json)?;
        if old_vk != new_vk {
            tracing::error!("[{user_id_hex}] CRITICAL: Group key changed during refresh!");
            return Err(Status::internal(
                "Protocol violation: Group key changed during refresh",
            ));
        }

        let refresh_h = user.refresh_session.unwrap();
        let refresh_id = crypto_ops::refresh_session_get_refresh_id(user, refresh_h)
            .map_err(|e| Status::internal(format!("get_refresh_id: {e}")))?;
        let refresh_threshold =
            crypto_ops::refresh_session_get_refresh_threshold_amount(user, refresh_h)
                .map_err(|e| Status::internal(format!("get_threshold: {e}")))?;
        let refresh_creation_ms =
            crypto_ops::refresh_session_get_refresh_creation_time_ms(user, refresh_h)
                .map_err(|e| Status::internal(format!("get_creation_time: {e}")))?;
        let refresh_interval = crypto_ops::refresh_session_get_refresh_interval(user, refresh_h)
            .map_err(|e| Status::internal(format!("get_interval: {e}")))?;

        let new_policy = ProtectedPolicy {
            id: refresh_id,
            threshold_sats: refresh_threshold,
            start_time_ms: refresh_creation_ms,
            interval_seconds: refresh_interval,
            key_package_json: result.key_package_json,
            public_key_package_json: result.public_key_package_json,
        };

        if let Some(ps) = user.policy_state.as_mut() {
            ps.protected_policies
                .insert(new_policy.id.clone(), new_policy);
            let _ = persist_policy(shared, &user_id_hex, ps);
        }
        tracing::info!("[{user_id_hex}] RefreshStep3: New policy created");
    }

    let mut response = RefreshStep3Response::default();
    for (id_hex, pkg_json) in &packages_for_me {
        response
            .round2_packages_for_me
            .insert(id_hex.clone(), pkg_json.clone());
    }
    Ok(response)
}
