//! REST/JSON API: extracts the `group_key` (the actor id) from the URL path, builds a `CosignerCommand`,
//! and dispatches via the per-user actor through `CosignerRegistry`.

use std::sync::Arc;

use axum::extract::{FromRef, Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use tonic::Status;

use crate::contract::ContractManager;
use crate::cosigner::command::CosignerCommand;
use crate::cosigner::registry::CosignerRegistry;
use crate::onboarding::OnboardingManager;
use crate::wallet_proto::{self};

/// Per-route extractor types pull what they need from this struct via
/// `FromRef`, so handlers can keep narrow signatures (`State<Arc<...>>`).
#[derive(Clone)]
pub struct AppState {
    pub registry: Arc<CosignerRegistry>,
    pub onboarding_manager: Arc<OnboardingManager>,
    pub contract_manager: Arc<ContractManager>,
    /// Public deployment metadata served by `/api/server-info`. Built once
    /// at startup from `ServerConfig::bitcoin_network`.
    pub server_info: Arc<wallet_proto::GetServerInfoResponse>,
}

impl FromRef<AppState> for Arc<CosignerRegistry> {
    fn from_ref(s: &AppState) -> Self {
        s.registry.clone()
    }
}

impl FromRef<AppState> for Arc<OnboardingManager> {
    fn from_ref(s: &AppState) -> Self {
        s.onboarding_manager.clone()
    }
}

impl FromRef<AppState> for Arc<ContractManager> {
    fn from_ref(s: &AppState) -> Self {
        s.contract_manager.clone()
    }
}

impl FromRef<AppState> for Arc<wallet_proto::GetServerInfoResponse> {
    fn from_ref(s: &AppState) -> Self {
        s.server_info.clone()
    }
}

/// Build the axum router. All authenticated routes are nested under
/// `/u/{group_key}/...` so the dispatcher can route directly to the actor.
pub fn routes(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        // DKG
        .route("/u/{group_key}/dkg/step1", post(dkg_step1))
        .route("/u/{group_key}/dkg/step2", post(dkg_step2))
        .route("/u/{group_key}/dkg/step3", post(dkg_step3))
        // Contract creation (reshare V→V′ + service refresh)
        .route("/u/{group_key}/contract/step1", post(contract_create_step1))
        .route("/u/{group_key}/contract/step2", post(contract_create_step2))
        .route("/u/{group_key}/contract/step3", post(contract_create_step3))
        .route("/u/{group_key}/contract/step4", post(contract_create_step4))
        // Signing
        .route("/u/{group_key}/sign/step1", post(sign_step1))
        .route("/u/{group_key}/sign/step2", post(sign_step2))
        // Transactions
        .route("/u/{group_key}/tx/broadcast", post(broadcast_transaction))
        .route("/u/{group_key}/tx/history", post(fetch_history))
        .route("/u/{group_key}/tx/recent", post(fetch_recent_transactions))
        // Ark
        .route("/u/{group_key}/ark/info", post(get_ark_info))
        .route("/u/{group_key}/ark/address", post(get_ark_address))
        .route(
            "/u/{group_key}/ark/boarding-address",
            post(get_boarding_address),
        )
        .route(
            "/u/{group_key}/ark/boarding-balance",
            post(check_boarding_balance),
        )
        .route("/u/{group_key}/ark/vtxos", post(list_vtxos))
        .route(
            "/u/{group_key}/ark/transactions",
            post(list_ark_transactions),
        )
        .route("/u/{group_key}/ark/send", post(send_vtxo))
        .route("/u/{group_key}/ark/redeem", post(redeem_vtxo))
        .route("/u/{group_key}/ark/settle", post(settle))
        .route("/u/{group_key}/ark/settle-delegate", post(settle_delegate))
        .route("/u/{group_key}/ark/submit-send", post(submit_ark_send))
        // Push notifications
        .route(
            "/u/{group_key}/push/register-device-token",
            post(register_device_token),
        )
        // Server deployment metadata. Unauthenticated, not user-scoped.
        // Accepts both GET and POST so the enclave-FFI transport (which only
        // models POST) can reach it the same way regular HTTP clients do.
        .route("/server-info", get(get_server_info).post(get_server_info))
        .with_state(state)
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
    ($reg:ident, $group_key:ident, $variant:ident, $req:expr) => {{
        let req = $req;
        match $reg
            .dispatch(&$group_key, move |reply| CosignerCommand::$variant {
                req,
                reply,
            })
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
// Server info — unauthenticated, returns deployment metadata so clients can
// render addresses with the correct HRP without needing to know the network
// out-of-band. Serves the same struct that's pre-built at startup from
// `ServerConfig::bitcoin_network`.
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::get_server_info")]
async fn get_server_info(
    State(info): State<Arc<wallet_proto::GetServerInfoResponse>>,
) -> Json<Value> {
    Json(json!({
        "bitcoin_network": info.bitcoin_network,
    }))
}

// ---------------------------------------------------------------------------
// DKG
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::dkg_step1", fields(group_key = %group_key))]
async fn dkg_step1(
    State(coord): State<Arc<OnboardingManager>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep1Request {
        user_id: user_id_bytes(&group_key),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
    };
    match coord.onboarding_step1(&group_key, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::dkg_step2", fields(group_key = %group_key))]
async fn dkg_step2(
    State(coord): State<Arc<OnboardingManager>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep2Request {
        user_id: user_id_bytes(&group_key),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
    };
    match coord.onboarding_step2(&group_key, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::dkg_step3", fields(group_key = %group_key))]
async fn dkg_step3(
    State(coord): State<Arc<OnboardingManager>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep3Request {
        user_id: user_id_bytes(&group_key),
        identifier: hex_field(&body, "identifier"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
    };
    match coord.onboarding_step3(&group_key, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// Contract creation (reshare V→V′ + single service refresh)
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::contract_create_step1", fields(group_key = %group_key))]
async fn contract_create_step1(
    State(coord): State<Arc<ContractManager>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::ContractCreateStep1Request {
        user_id: user_id_bytes(&group_key),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
        contract_id: hex_field(&body, "contract_id"),
        contract_wasm: hex_field(&body, "contract_wasm"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        server_pk: hex_field(&body, "server_pk"),
        exit_delay: i64_field(&body, "exit_delay") as u32,
        owner_pk: hex_field(&body, "owner_pk"),
        service_vk: hex_field(&body, "service_vk"),
    };
    match coord.create_contract_step_1(&group_key, req).await {
        Ok(resp) => Ok(Json(json!({ "round1_packages": resp.round1_packages }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::contract_create_step2", fields(group_key = %group_key))]
async fn contract_create_step2(
    State(coord): State<Arc<ContractManager>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::ContractCreateStep2Request {
        user_id: user_id_bytes(&group_key),
        identifier: hex_field(&body, "identifier"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match coord.create_contract_step_2(&group_key, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::contract_create_step3", fields(group_key = %group_key))]
async fn contract_create_step3(
    State(coord): State<Arc<ContractManager>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::ContractCreateStep3Request {
        user_id: user_id_bytes(&group_key),
        identifier: hex_field(&body, "identifier"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match coord.create_contract_step_3(&group_key, req).await {
        Ok(resp) => Ok(Json(json!({
            "round2_packages_for_me": resp.round2_packages_for_me,
            "contract_script_pubkey": to_hex(&resp.contract_script_pubkey),
            "contract_group_id": to_hex(&resp.contract_group_id),
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::contract_create_step4", fields(group_key = %group_key))]
async fn contract_create_step4(
    State(coord): State<Arc<ContractManager>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::ContractCreateStep4Request {
        user_id: user_id_bytes(&group_key),
        identifier: hex_field(&body, "identifier"),
        contract_script_pubkey: hex_field(&body, "contract_script_pubkey"),
        a_at_cosigner: hex_field(&body, "a_at_cosigner"),
        a_at_service_point: hex_field(&body, "a_at_service_point"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match coord.create_contract_step_4(&group_key, req).await {
        Ok(resp) => Ok(Json(json!({ "ok": resp.ok }))),
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// Signing
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::sign_step1", fields(group_key = %group_key))]
async fn sign_step1(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    // Routing is by the URL path (`group_key` — the actor). For a contract spend,
    // `claimed_share` is the spending recipient (the user or the service); set
    // `req.user_id` to it so the actor authenticates it against the contract's
    // recipient set + selects that recipient's V′ counter-share.
    let claimed_share = hex_field(&body, "claimed_share");
    let req_user_id = if claimed_share.is_empty() {
        user_id_bytes(&group_key)
    } else {
        claimed_share.clone()
    };
    let req = wallet_proto::SignStep1Request {
        user_id: req_user_id,
        hiding_commitment: hex_field(&body, "hiding_commitment"),
        binding_commitment: hex_field(&body, "binding_commitment"),
        message_to_sign: hex_field(&body, "message_to_sign"),
        signature: hex_field(&body, "signature"),
        full_transaction: hex_field(&body, "full_transaction"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        script_path_spend: bool_field(&body, "script_path_spend"),
        claimed_share,
    };
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::SignStep1 {
            req,
            reply,
        })
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

#[tracing::instrument(skip_all, name = "rest::sign_step2", fields(group_key = %group_key))]
async fn sign_step2(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let claimed_share = hex_field(&body, "claimed_share");
    let req_user_id = if claimed_share.is_empty() {
        user_id_bytes(&group_key)
    } else {
        claimed_share.clone()
    };
    let req = wallet_proto::SignStep2Request {
        user_id: req_user_id,
        signature_share: hex_field(&body, "signature_share"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        claimed_share,
    };
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::SignStep2 {
            req,
            reply,
        })
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
// Transactions
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::broadcast_transaction", fields(group_key = %group_key))]
async fn broadcast_transaction(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        BroadcastTransaction,
        wallet_proto::BroadcastTransactionRequest {
            user_id: user_id_bytes(&group_key),
            tx_hex: str_field(&body, "tx_hex"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::fetch_history", fields(group_key = %group_key))]
async fn fetch_history(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        FetchHistory,
        wallet_proto::FetchHistoryRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::fetch_recent_transactions", fields(group_key = %group_key))]
async fn fetch_recent_transactions(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        FetchRecentTransactions,
        wallet_proto::FetchRecentTransactionsRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

// ---------------------------------------------------------------------------
// Ark
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::get_ark_info", fields(group_key = %group_key))]
async fn get_ark_info(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        GetArkInfo,
        wallet_proto::GetArkInfoRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::get_ark_address", fields(group_key = %group_key))]
async fn get_ark_address(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        GetArkAddress,
        wallet_proto::GetArkAddressRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::get_boarding_address", fields(group_key = %group_key))]
async fn get_boarding_address(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        GetBoardingAddress,
        wallet_proto::GetBoardingAddressRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::check_boarding_balance", fields(group_key = %group_key))]
async fn check_boarding_balance(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        CheckBoardingBalance,
        wallet_proto::CheckBoardingBalanceRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::list_vtxos", fields(group_key = %group_key))]
async fn list_vtxos(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        ListVtxos,
        wallet_proto::ListVtxosRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::list_ark_transactions", fields(group_key = %group_key))]
async fn list_ark_transactions(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        ListArkTransactions,
        wallet_proto::ListArkTransactionsRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::send_vtxo", fields(group_key = %group_key))]
async fn send_vtxo(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SendVtxoRequest {
        user_id: user_id_bytes(&group_key),
        recipient_ark_address: str_field(&body, "recipient_ark_address"),
        amount: u64_field(&body, "amount"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::SendVtxo {
            req,
            reply,
        })
        .await
    {
        Ok(r) => Ok(Json(json!({
            "status": r.status,
            "messages_to_sign": r.messages_to_sign.iter().map(|m| to_hex(m)).collect::<Vec<_>>(),
            "script_path_spend": r.script_path_spend,
            "ark_txid": r.ark_txid,
            "error_message": r.error_message,
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::redeem_vtxo", fields(group_key = %group_key))]
async fn redeem_vtxo(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        RedeemVtxo,
        wallet_proto::RedeemVtxoRequest {
            user_id: user_id_bytes(&group_key),
            on_chain_address: str_field(&body, "on_chain_address"),
            amount: u64_field(&body, "amount"),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::settle", fields(group_key = %group_key))]
async fn settle(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SettleRequest {
        user_id: user_id_bytes(&group_key),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::Settle {
            req,
            reply,
        })
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

#[tracing::instrument(skip_all, name = "rest::settle_delegate", fields(group_key = %group_key))]
async fn settle_delegate(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SettleDelegateRequest {
        user_id: user_id_bytes(&group_key),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
        store_only: body
            .get("store_only")
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    };
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::SettleDelegate {
            req,
            reply,
        })
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

#[tracing::instrument(skip_all, name = "rest::submit_ark_send", fields(group_key = %group_key))]
async fn submit_ark_send(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        SubmitArkSend,
        wallet_proto::SubmitArkSendRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
            signed_ark_tx_b64: str_field(&body, "signed_ark_tx_b64"),
            signed_checkpoint_txs_b64: str_array_field(&body, "signed_checkpoint_txs_b64"),
            spent_outpoints: str_array_field(&body, "spent_outpoints"),
        }
    )
}

#[tracing::instrument(skip_all, name = "rest::register_device_token", fields(group_key = %group_key))]
async fn register_device_token(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(
        reg,
        group_key,
        RegisterDeviceToken,
        wallet_proto::RegisterDeviceTokenRequest {
            user_id: user_id_bytes(&group_key),
            signature: hex_field(&body, "signature"),
            timestamp_ms: i64_field(&body, "timestamp_ms"),
            fcm_token: str_field(&body, "fcm_token"),
            platform: str_field(&body, "platform"),
            app_version: str_field(&body, "app_version"),
        }
    )
}
