//! `register_device_token` handler. Stores an FCM token on the user's actor
//! state so the cosigner can wake the device when a new VTXO arrives via
//! `vtxo_stream`.

use tonic::Status;

use crate::auth::message::OP_REGISTER_DEVICE_TOKEN;
use crate::cosigner::handlers::parsers;
use crate::cosigner::registry::CosignerInstance;
use crate::cosigner::state::{CosignerState, DeviceToken};
use crate::shared::SharedServices;
use crate::wallet_proto::*;

use super::helpers::{auth_check, now_secs, save_user_device_tokens};

const MAX_TOKEN_AGE_SECS: i64 = 60 * 24 * 60 * 60; // 60 days

#[tracing::instrument(
    skip_all,
    name = "actor::register_device_token",
    fields(user_id = %parsers::user_id_hex(&req.user_id)),
    err
)]
pub fn register_device_token(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: RegisterDeviceTokenRequest,
) -> Result<RegisterDeviceTokenResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_REGISTER_DEVICE_TOKEN,
    )?;

    if req.fcm_token.trim().is_empty() {
        return Err(Status::invalid_argument("fcm_token must not be empty"));
    }
    if req.platform != "android" && req.platform != "ios" {
        return Err(Status::invalid_argument(
            "platform must be one of: android, ios",
        ));
    }

    let now = now_secs();
    state
        .device_tokens
        .retain(|t| t.fcm_token != req.fcm_token && now - t.registered_at < MAX_TOKEN_AGE_SECS);
    state.device_tokens.push(DeviceToken {
        fcm_token: req.fcm_token.clone(),
        platform: req.platform.clone(),
        registered_at: now,
        app_version: req.app_version.clone(),
    });

    save_user_device_tokens(
        shared.persistence.as_ref(),
        &user_id_hex,
        &state.device_tokens,
    );
    tracing::info!(
        "[{user_id_hex}] register_device_token: platform={} version={} token_count={}",
        req.platform,
        req.app_version,
        state.device_tokens.len()
    );
    Ok(RegisterDeviceTokenResponse { ok: true })
}
