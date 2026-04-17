//! REST/JSON API layer over the existing WalletService.
//!
//! Each route is a thin wrapper that:
//! 1. Extracts JSON fields from the request body
//! 2. Constructs the protobuf request type
//! 3. Calls the corresponding WalletService method via the MpcWallet trait
//! 4. Converts the response to JSON
//!
//! Byte fields are hex-encoded strings in JSON.

use std::sync::Arc;

use axum::extract::State;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};

use crate::wallet_proto::mpc_wallet_server::MpcWallet;
use crate::wallet_service::WalletService;

type AppState = Arc<WalletService>;

/// Build the axum router with all REST endpoints.
pub fn routes(service: AppState) -> Router {
    Router::new()
        // Health
        .route("/health", get(health))
        // DKG
        .route("/dkg/step1", post(dkg_step1))
        .route("/dkg/step2", post(dkg_step2))
        .route("/dkg/step3", post(dkg_step3))
        // Signing
        .route("/sign/step1", post(sign_step1))
        .route("/sign/step2", post(sign_step2))
        // Refresh
        .route("/refresh/step1", post(refresh_step1))
        .route("/refresh/step2", post(refresh_step2))
        .route("/refresh/step3", post(refresh_step3))
        // Policy
        .route("/policy/create", post(create_spending_policy))
        .route("/policy/get-id", post(get_policy_id))
        .route("/policy/update", post(update_policy))
        .route("/policy/delete", post(delete_policy))
        // Transactions
        .route("/tx/broadcast", post(broadcast_transaction))
        .route("/tx/history", post(fetch_history))
        .route("/tx/recent", post(fetch_recent_transactions))
        // Ark
        .route("/ark/info", post(get_ark_info))
        .route("/ark/address", post(get_ark_address))
        .route("/ark/boarding-address", post(get_boarding_address))
        .route("/ark/boarding-balance", post(check_boarding_balance))
        .route("/ark/vtxos", post(list_vtxos))
        .route("/ark/transactions", post(list_ark_transactions))
        .route("/ark/send", post(send_vtxo))
        .route("/ark/redeem", post(redeem_vtxo))
        .route("/ark/settle", post(settle))
        .route("/ark/settle-delegate", post(settle_delegate))
        .route("/ark/submit-send", post(submit_ark_send))
        .with_state(service)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convert a hex string to bytes. Returns empty vec if field is missing/empty.
fn hex_field(v: &Value, key: &str) -> Vec<u8> {
    v.get(key)
        .and_then(|s| s.as_str())
        .and_then(|s| hex::decode(s).ok())
        .unwrap_or_default()
}

/// Get a string field, defaulting to empty string.
fn str_field(v: &Value, key: &str) -> String {
    v.get(key)
        .and_then(|s| s.as_str())
        .unwrap_or("")
        .to_string()
}

/// Get an i64 field.
fn i64_field(v: &Value, key: &str) -> i64 {
    v.get(key).and_then(|n| n.as_i64()).unwrap_or(0)
}

/// Get a u64 field.
fn u64_field(v: &Value, key: &str) -> u64 {
    v.get(key).and_then(|n| n.as_u64()).unwrap_or(0)
}

/// Get a bool field.
fn bool_field(v: &Value, key: &str) -> bool {
    v.get(key).and_then(|b| b.as_bool()).unwrap_or(false)
}

/// Get a map<string,string> field.
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

/// Get a repeated hex-encoded bytes field.
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

/// Get a repeated string field.
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

/// Convert bytes to hex for JSON response.
fn to_hex(bytes: &[u8]) -> String {
    hex::encode(bytes)
}

/// Convert a tonic Status error to an axum JSON error response.
fn status_to_response(status: tonic::Status) -> (StatusCode, Json<Value>) {
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

/// Wrap a tonic gRPC call: build request, call service, return JSON.
macro_rules! rpc_handler {
    ($service:expr, $method:ident, $req:expr) => {{
        match $service.$method(tonic::Request::new($req)).await {
            Ok(resp) => Ok(Json(serde_json::to_value(resp.into_inner()).unwrap_or(json!({})))),
            Err(status) => Err(status_to_response(status)),
        }
    }};
}

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::health")]
async fn health() -> impl IntoResponse {
    Json(json!({"status": "ok"}))
}

// ---------------------------------------------------------------------------
// DKG
// ---------------------------------------------------------------------------

use crate::wallet_proto;

#[tracing::instrument(skip_all, name = "rest::dkg_step1")]
async fn dkg_step1(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep1Request {
        user_id: hex_field(&body, "user_id"),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
        is_restore: bool_field(&body, "is_restore"),
    };
    rpc_handler!(svc, dkg_step1, req)
}

#[tracing::instrument(skip_all, name = "rest::dkg_step2")]
async fn dkg_step2(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep2Request {
        user_id: hex_field(&body, "user_id"),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
    };
    rpc_handler!(svc, dkg_step2, req)
}

#[tracing::instrument(skip_all, name = "rest::dkg_step3")]
async fn dkg_step3(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep3Request {
        user_id: hex_field(&body, "user_id"),
        identifier: hex_field(&body, "identifier"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
    };
    rpc_handler!(svc, dkg_step3, req)
}

// ---------------------------------------------------------------------------
// Signing
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::sign_step1")]
async fn sign_step1(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SignStep1Request {
        user_id: hex_field(&body, "user_id"),
        hiding_commitment: hex_field(&body, "hiding_commitment"),
        binding_commitment: hex_field(&body, "binding_commitment"),
        message_to_sign: hex_field(&body, "message_to_sign"),
        signature: hex_field(&body, "signature"),
        full_transaction: hex_field(&body, "full_transaction"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        script_path_spend: bool_field(&body, "script_path_spend"),
    };
    // Custom response: commitments map has nested bytes → hex
    match svc.sign_step1(tonic::Request::new(req)).await {
        Ok(resp) => {
            let r = resp.into_inner();
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

#[tracing::instrument(skip_all, name = "rest::sign_step2")]
async fn sign_step2(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SignStep2Request {
        user_id: hex_field(&body, "user_id"),
        signature_share: hex_field(&body, "signature_share"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match svc.sign_step2(tonic::Request::new(req)).await {
        Ok(resp) => {
            let r = resp.into_inner();
            Ok(Json(json!({
                "r_point": to_hex(&r.r_point),
                "z_scalar": to_hex(&r.z_scalar),
            })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// Refresh
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::refresh_step1")]
async fn refresh_step1(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::RefreshStep1Request {
        user_id: hex_field(&body, "user_id"),
        round1_package: str_field(&body, "round1_package"),
        threshold_amount: i64_field(&body, "threshold_amount"),
        interval: i64_field(&body, "interval"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, refresh_step1, req)
}

#[tracing::instrument(skip_all, name = "rest::refresh_step2")]
async fn refresh_step2(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::RefreshStep2Request {
        user_id: hex_field(&body, "user_id"),
        round1_package: str_field(&body, "round1_package"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, refresh_step2, req)
}

#[tracing::instrument(skip_all, name = "rest::refresh_step3")]
async fn refresh_step3(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::RefreshStep3Request {
        user_id: hex_field(&body, "user_id"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, refresh_step3, req)
}

// ---------------------------------------------------------------------------
// Policy
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::create_spending_policy")]
async fn create_spending_policy(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::CreateSpendingPolicyRequest {
        user_id: hex_field(&body, "user_id"),
        threshold_sats: i64_field(&body, "threshold_sats"),
        start_time: i64_field(&body, "start_time"),
        interval_seconds: i64_field(&body, "interval_seconds"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, create_spending_policy, req)
}

#[tracing::instrument(skip_all, name = "rest::get_policy_id")]
async fn get_policy_id(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::GetPolicyIdRequest {
        user_id: hex_field(&body, "user_id"),
        tx_message: hex_field(&body, "tx_message"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, get_policy_id, req)
}

#[tracing::instrument(skip_all, name = "rest::update_policy")]
async fn update_policy(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::UpdatePolicyRequest {
        user_id: hex_field(&body, "user_id"),
        policy_id: str_field(&body, "policy_id"),
        threshold_sats: i64_field(&body, "threshold_sats"),
        interval_seconds: i64_field(&body, "interval_seconds"),
        frost_signature_r: hex_field(&body, "frost_signature_r"),
        frost_signature_z: hex_field(&body, "frost_signature_z"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, update_policy, req)
}

#[tracing::instrument(skip_all, name = "rest::delete_policy")]
async fn delete_policy(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DeletePolicyRequest {
        user_id: hex_field(&body, "user_id"),
        policy_id: str_field(&body, "policy_id"),
        frost_signature_r: hex_field(&body, "frost_signature_r"),
        frost_signature_z: hex_field(&body, "frost_signature_z"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, delete_policy, req)
}

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::broadcast_transaction")]
async fn broadcast_transaction(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::BroadcastTransactionRequest {
        user_id: hex_field(&body, "user_id"),
        tx_hex: str_field(&body, "tx_hex"),
    };
    rpc_handler!(svc, broadcast_transaction, req)
}

#[tracing::instrument(skip_all, name = "rest::fetch_history")]
async fn fetch_history(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::FetchHistoryRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, fetch_history, req)
}

#[tracing::instrument(skip_all, name = "rest::fetch_recent_transactions")]
async fn fetch_recent_transactions(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::FetchRecentTransactionsRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, fetch_recent_transactions, req)
}

// ---------------------------------------------------------------------------
// Ark Protocol
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::get_ark_info")]
async fn get_ark_info(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::GetArkInfoRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, get_ark_info, req)
}

#[tracing::instrument(skip_all, name = "rest::get_ark_address")]
async fn get_ark_address(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::GetArkAddressRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, get_ark_address, req)
}

#[tracing::instrument(skip_all, name = "rest::get_boarding_address")]
async fn get_boarding_address(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::GetBoardingAddressRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, get_boarding_address, req)
}

#[tracing::instrument(skip_all, name = "rest::check_boarding_balance")]
async fn check_boarding_balance(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::CheckBoardingBalanceRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, check_boarding_balance, req)
}

#[tracing::instrument(skip_all, name = "rest::list_vtxos")]
async fn list_vtxos(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::ListVtxosRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, list_vtxos, req)
}

#[tracing::instrument(skip_all, name = "rest::list_ark_transactions")]
async fn list_ark_transactions(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::ListArkTransactionsRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, list_ark_transactions, req)
}

#[tracing::instrument(skip_all, name = "rest::send_vtxo")]
async fn send_vtxo(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SendVtxoRequest {
        user_id: hex_field(&body, "user_id"),
        recipient_ark_address: str_field(&body, "recipient_ark_address"),
        amount: u64_field(&body, "amount"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match svc.send_vtxo(tonic::Request::new(req)).await {
        Ok(resp) => {
            let r = resp.into_inner();
            Ok(Json(json!({
                "status": r.status,
                "messages_to_sign": r.messages_to_sign.iter().map(|m| to_hex(m)).collect::<Vec<_>>(),
                "script_path_spend": r.script_path_spend,
                "ark_txid": r.ark_txid,
                "error_message": r.error_message,
                "policy_id": r.policy_id,
            })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::redeem_vtxo")]
async fn redeem_vtxo(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::RedeemVtxoRequest {
        user_id: hex_field(&body, "user_id"),
        on_chain_address: str_field(&body, "on_chain_address"),
        amount: u64_field(&body, "amount"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    rpc_handler!(svc, redeem_vtxo, req)
}

#[tracing::instrument(skip_all, name = "rest::settle")]
async fn settle(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SettleRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match svc.settle(tonic::Request::new(req)).await {
        Ok(resp) => {
            let r = resp.into_inner();
            Ok(Json(json!({
                "status": r.status,
                "messages_to_sign": r.messages_to_sign.iter().map(|m| to_hex(m)).collect::<Vec<_>>(),
                "script_path_spend": r.script_path_spend,
                "commitment_txid": r.commitment_txid,
                "error_message": r.error_message,
            })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::settle_delegate")]
async fn settle_delegate(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SettleDelegateRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match svc.settle_delegate(tonic::Request::new(req)).await {
        Ok(resp) => {
            let r = resp.into_inner();
            Ok(Json(json!({
                "status": r.status,
                "messages_to_sign": r.messages_to_sign.iter().map(|m| to_hex(m)).collect::<Vec<_>>(),
                "script_path_spend": r.script_path_spend,
                "commitment_txid": r.commitment_txid,
                "error_message": r.error_message,
            })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::submit_ark_send")]
async fn submit_ark_send(
    State(svc): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SubmitArkSendRequest {
        user_id: hex_field(&body, "user_id"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_ark_tx_b64: str_field(&body, "signed_ark_tx_b64"),
        signed_checkpoint_txs_b64: str_array_field(&body, "signed_checkpoint_txs_b64"),
        spent_outpoints: str_array_field(&body, "spent_outpoints"),
    };
    rpc_handler!(svc, submit_ark_send, req)
}
