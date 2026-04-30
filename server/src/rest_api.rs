//! REST/JSON API: extracts `user_id` from the URL path, builds a `UserCommand`,
//! and dispatches via the per-user actor through `UserRegistry`.

use std::sync::Arc;

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use tonic::Status;

use crate::user::command::UserCommand;
use crate::user::registry::UserRegistry;
use crate::wallet_proto::{self};

type AppState = Arc<UserRegistry>;

/// Build the axum router. All authenticated routes are nested under
/// `/u/{user_id}/...` so the dispatcher can route directly to the actor.
pub fn routes(registry: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        // DKG
        .route("/u/{user_id}/dkg/step1", post(dkg_step1))
        .route("/u/{user_id}/dkg/step2", post(dkg_step2))
        .route("/u/{user_id}/dkg/step3", post(dkg_step3))
        // Signing
        .route("/u/{user_id}/sign/step1", post(sign_step1))
        .route("/u/{user_id}/sign/step2", post(sign_step2))
        // Refresh
        .route("/u/{user_id}/refresh/step1", post(refresh_step1))
        .route("/u/{user_id}/refresh/step2", post(refresh_step2))
        .route("/u/{user_id}/refresh/step3", post(refresh_step3))
        // Policy
        .route("/u/{user_id}/policy/create", post(create_spending_policy))
        .route("/u/{user_id}/policy/get-id", post(get_policy_id))
        .route("/u/{user_id}/policy/update", post(update_policy))
        .route("/u/{user_id}/policy/delete", post(delete_policy))
        // Transactions
        .route("/u/{user_id}/tx/broadcast", post(broadcast_transaction))
        .route("/u/{user_id}/tx/history", post(fetch_history))
        .route("/u/{user_id}/tx/recent", post(fetch_recent_transactions))
        // Ark
        .route("/u/{user_id}/ark/info", post(get_ark_info))
        .route("/u/{user_id}/ark/address", post(get_ark_address))
        .route("/u/{user_id}/ark/boarding-address", post(get_boarding_address))
        .route("/u/{user_id}/ark/boarding-balance", post(check_boarding_balance))
        .route("/u/{user_id}/ark/vtxos", post(list_vtxos))
        .route("/u/{user_id}/ark/transactions", post(list_ark_transactions))
        .route("/u/{user_id}/ark/send", post(send_vtxo))
        .route("/u/{user_id}/ark/redeem", post(redeem_vtxo))
        .route("/u/{user_id}/ark/settle", post(settle))
        .route("/u/{user_id}/ark/settle-delegate", post(settle_delegate))
        .route("/u/{user_id}/ark/submit-send", post(submit_ark_send))
        .with_state(registry)
}

// ---------------------------------------------------------------------------
// Field extractors
// ---------------------------------------------------------------------------

fn hex_field(v: &Value, key: &str) -> Vec<u8> {
    v.get(key)
        .and_then(|s| s.as_str())
        .and_then(|s| hex::decode(s).ok())
        .unwrap_or_default()
}

fn str_field(v: &Value, key: &str) -> String {
    v.get(key)
        .and_then(|s| s.as_str())
        .unwrap_or("")
        .to_string()
}

fn i64_field(v: &Value, key: &str) -> i64 {
    v.get(key).and_then(|n| n.as_i64()).unwrap_or(0)
}

fn u64_field(v: &Value, key: &str) -> u64 {
    v.get(key).and_then(|n| n.as_u64()).unwrap_or(0)
}

fn bool_field(v: &Value, key: &str) -> bool {
    v.get(key).and_then(|b| b.as_bool()).unwrap_or(false)
}

fn map_field(v: &Value, key: &str) -> std::collections::HashMap<String, String> {
    v.get(key)
        .and_then(|m| m.as_object())
        .map(|m| {
            m.iter()
                .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                .collect()
        })
        .unwrap_or_default()
}

fn hex_array_field(v: &Value, key: &str) -> Vec<Vec<u8>> {
    v.get(key)
        .and_then(|a| a.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|s| s.as_str().and_then(|h| hex::decode(h).ok()))
                .collect()
        })
        .unwrap_or_default()
}

fn str_array_field(v: &Value, key: &str) -> Vec<String> {
    v.get(key)
        .and_then(|a| a.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|s| s.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default()
}

fn to_hex(bytes: &[u8]) -> String {
    hex::encode(bytes)
}

fn user_id_bytes(path: &str) -> Vec<u8> {
    hex::decode(path).unwrap_or_default()
}

fn status_to_response(status: Status) -> (StatusCode, Json<Value>) {
    let http_code = match status.code() {
        tonic::Code::NotFound => StatusCode::NOT_FOUND,
        tonic::Code::InvalidArgument => StatusCode::BAD_REQUEST,
        tonic::Code::Unauthenticated => StatusCode::UNAUTHORIZED,
        tonic::Code::PermissionDenied => StatusCode::FORBIDDEN,
        tonic::Code::Unavailable => StatusCode::SERVICE_UNAVAILABLE,
        _ => StatusCode::INTERNAL_SERVER_ERROR,
    };
    (
        http_code,
        Json(json!({
            "error": status.message(),
            "code": status.code() as i32,
        })),
    )
}

/// Dispatch a command and serialize the response with `serde`.
macro_rules! dispatch_json {
    ($reg:ident, $user_id:ident, $variant:ident, $req:expr) => {{
        let req = $req;
        match $reg
            .dispatch(&$user_id, move |reply| UserCommand::$variant { req, reply })
            .await
        {
            Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
            Err(status) => Err(status_to_response(status)),
        }
    }};
}

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

async fn health() -> impl IntoResponse {
    Json(json!({"status": "ok"}))
}

// ---------------------------------------------------------------------------
// DKG
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::dkg_step1", fields(user_id = %user_id))]
async fn dkg_step1(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, DkgStep1, wallet_proto::DkgStep1Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
        is_restore: bool_field(&body, "is_restore"),
    })
}

#[tracing::instrument(skip_all, name = "rest::dkg_step2", fields(user_id = %user_id))]
async fn dkg_step2(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, DkgStep2, wallet_proto::DkgStep2Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
    })
}

#[tracing::instrument(skip_all, name = "rest::dkg_step3", fields(user_id = %user_id))]
async fn dkg_step3(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, DkgStep3, wallet_proto::DkgStep3Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
    })
}

// ---------------------------------------------------------------------------
// Signing
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::sign_step1", fields(user_id = %user_id))]
async fn sign_step1(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SignStep1Request {
        user_id: user_id_bytes(&user_id),
        hiding_commitment: hex_field(&body, "hiding_commitment"),
        binding_commitment: hex_field(&body, "binding_commitment"),
        message_to_sign: hex_field(&body, "message_to_sign"),
        signature: hex_field(&body, "signature"),
        full_transaction: hex_field(&body, "full_transaction"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        script_path_spend: bool_field(&body, "script_path_spend"),
    };
    match reg
        .dispatch(&user_id, move |reply| UserCommand::SignStep1 { req, reply })
        .await
    {
        Ok(r) => {
            let comms: Value = r
                .commitments
                .iter()
                .map(|(k, c)| {
                    (
                        k.clone(),
                        json!({"hiding": to_hex(&c.hiding), "binding": to_hex(&c.binding)}),
                    )
                })
                .collect::<serde_json::Map<String, Value>>()
                .into();
            Ok(Json(json!({
                "commitments": comms,
                "message_to_sign": to_hex(&r.message_to_sign),
                "used_key_index": r.used_key_index,
            })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::sign_step2", fields(user_id = %user_id))]
async fn sign_step2(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SignStep2Request {
        user_id: user_id_bytes(&user_id),
        signature_share: hex_field(&body, "signature_share"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match reg
        .dispatch(&user_id, move |reply| UserCommand::SignStep2 { req, reply })
        .await
    {
        Ok(r) => Ok(Json(json!({
            "r_point": to_hex(&r.r_point),
            "z_scalar": to_hex(&r.z_scalar),
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// Refresh
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::refresh_step1", fields(user_id = %user_id))]
async fn refresh_step1(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, RefreshStep1, wallet_proto::RefreshStep1Request {
        user_id: user_id_bytes(&user_id),
        round1_package: str_field(&body, "round1_package"),
        threshold_amount: i64_field(&body, "threshold_amount"),
        interval: i64_field(&body, "interval"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::refresh_step2", fields(user_id = %user_id))]
async fn refresh_step2(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, RefreshStep2, wallet_proto::RefreshStep2Request {
        user_id: user_id_bytes(&user_id),
        round1_package: str_field(&body, "round1_package"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::refresh_step3", fields(user_id = %user_id))]
async fn refresh_step3(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, RefreshStep3, wallet_proto::RefreshStep3Request {
        user_id: user_id_bytes(&user_id),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

// ---------------------------------------------------------------------------
// Policy
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::create_spending_policy", fields(user_id = %user_id))]
async fn create_spending_policy(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, CreateSpendingPolicy, wallet_proto::CreateSpendingPolicyRequest {
        user_id: user_id_bytes(&user_id),
        threshold_sats: i64_field(&body, "threshold_sats"),
        start_time: i64_field(&body, "start_time"),
        interval_seconds: i64_field(&body, "interval_seconds"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::get_policy_id", fields(user_id = %user_id))]
async fn get_policy_id(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, GetPolicyId, wallet_proto::GetPolicyIdRequest {
        user_id: user_id_bytes(&user_id),
        tx_message: hex_field(&body, "tx_message"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::update_policy", fields(user_id = %user_id))]
async fn update_policy(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, UpdatePolicy, wallet_proto::UpdatePolicyRequest {
        user_id: user_id_bytes(&user_id),
        policy_id: str_field(&body, "policy_id"),
        threshold_sats: i64_field(&body, "threshold_sats"),
        interval_seconds: i64_field(&body, "interval_seconds"),
        frost_signature_r: hex_field(&body, "frost_signature_r"),
        frost_signature_z: hex_field(&body, "frost_signature_z"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::delete_policy", fields(user_id = %user_id))]
async fn delete_policy(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, DeletePolicy, wallet_proto::DeletePolicyRequest {
        user_id: user_id_bytes(&user_id),
        policy_id: str_field(&body, "policy_id"),
        frost_signature_r: hex_field(&body, "frost_signature_r"),
        frost_signature_z: hex_field(&body, "frost_signature_z"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::broadcast_transaction", fields(user_id = %user_id))]
async fn broadcast_transaction(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, BroadcastTransaction, wallet_proto::BroadcastTransactionRequest {
        user_id: user_id_bytes(&user_id),
        tx_hex: str_field(&body, "tx_hex"),
    })
}

#[tracing::instrument(skip_all, name = "rest::fetch_history", fields(user_id = %user_id))]
async fn fetch_history(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, FetchHistory, wallet_proto::FetchHistoryRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::fetch_recent_transactions", fields(user_id = %user_id))]
async fn fetch_recent_transactions(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, FetchRecentTransactions, wallet_proto::FetchRecentTransactionsRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

// ---------------------------------------------------------------------------
// Ark
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::get_ark_info", fields(user_id = %user_id))]
async fn get_ark_info(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, GetArkInfo, wallet_proto::GetArkInfoRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::get_ark_address", fields(user_id = %user_id))]
async fn get_ark_address(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, GetArkAddress, wallet_proto::GetArkAddressRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::get_boarding_address", fields(user_id = %user_id))]
async fn get_boarding_address(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, GetBoardingAddress, wallet_proto::GetBoardingAddressRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::check_boarding_balance", fields(user_id = %user_id))]
async fn check_boarding_balance(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, CheckBoardingBalance, wallet_proto::CheckBoardingBalanceRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::list_vtxos", fields(user_id = %user_id))]
async fn list_vtxos(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, ListVtxos, wallet_proto::ListVtxosRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::list_ark_transactions", fields(user_id = %user_id))]
async fn list_ark_transactions(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, ListArkTransactions, wallet_proto::ListArkTransactionsRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::send_vtxo", fields(user_id = %user_id))]
async fn send_vtxo(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SendVtxoRequest {
        user_id: user_id_bytes(&user_id),
        recipient_ark_address: str_field(&body, "recipient_ark_address"),
        amount: u64_field(&body, "amount"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match reg
        .dispatch(&user_id, move |reply| UserCommand::SendVtxo { req, reply })
        .await
    {
        Ok(r) => Ok(Json(json!({
            "status": r.status,
            "messages_to_sign": r.messages_to_sign.iter().map(|m| to_hex(m)).collect::<Vec<_>>(),
            "script_path_spend": r.script_path_spend,
            "ark_txid": r.ark_txid,
            "error_message": r.error_message,
            "policy_id": r.policy_id,
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::redeem_vtxo", fields(user_id = %user_id))]
async fn redeem_vtxo(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, RedeemVtxo, wallet_proto::RedeemVtxoRequest {
        user_id: user_id_bytes(&user_id),
        on_chain_address: str_field(&body, "on_chain_address"),
        amount: u64_field(&body, "amount"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    })
}

#[tracing::instrument(skip_all, name = "rest::settle", fields(user_id = %user_id))]
async fn settle(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SettleRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match reg
        .dispatch(&user_id, move |reply| UserCommand::Settle { req, reply })
        .await
    {
        Ok(r) => Ok(Json(json!({
            "status": r.status,
            "messages_to_sign": r.messages_to_sign.iter().map(|m| to_hex(m)).collect::<Vec<_>>(),
            "script_path_spend": r.script_path_spend,
            "commitment_txid": r.commitment_txid,
            "error_message": r.error_message,
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::settle_delegate", fields(user_id = %user_id))]
async fn settle_delegate(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SettleDelegateRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match reg
        .dispatch(&user_id, move |reply| UserCommand::SettleDelegate { req, reply })
        .await
    {
        Ok(r) => Ok(Json(json!({
            "status": r.status,
            "messages_to_sign": r.messages_to_sign.iter().map(|m| to_hex(m)).collect::<Vec<_>>(),
            "script_path_spend": r.script_path_spend,
            "commitment_txid": r.commitment_txid,
            "error_message": r.error_message,
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::submit_ark_send", fields(user_id = %user_id))]
async fn submit_ark_send(
    State(reg): State<AppState>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, SubmitArkSend, wallet_proto::SubmitArkSendRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_ark_tx_b64: str_field(&body, "signed_ark_tx_b64"),
        signed_checkpoint_txs_b64: str_array_field(&body, "signed_checkpoint_txs_b64"),
        spent_outpoints: str_array_field(&body, "spent_outpoints"),
    })
}
