//! REST/JSON API: extracts `user_id` from the URL path, builds a `CosignerCommand`,
//! and dispatches via the per-user actor through `CosignerRegistry`.

use std::sync::Arc;

use axum::extract::{FromRef, Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use tonic::Status;

use crate::cosigner::command::CosignerCommand;
use crate::cosigner::registry::CosignerRegistry;
use crate::onboarding::{DkgCoordinator, EvtxoKeygenCoordinator};
use crate::wallet_proto::{self};

/// Per-route extractor types pull what they need from this struct via
/// `FromRef`, so handlers can keep narrow signatures (`State<Arc<...>>`).
#[derive(Clone)]
pub struct AppState {
    pub registry: Arc<CosignerRegistry>,
    pub dkg_coordinator: Arc<DkgCoordinator>,
    pub evtxo_coordinator: Arc<EvtxoKeygenCoordinator>,
    /// Public deployment metadata served by `/api/server-info`. Built once
    /// at startup from `ServerConfig::bitcoin_network`.
    pub server_info: Arc<wallet_proto::GetServerInfoResponse>,
}

impl FromRef<AppState> for Arc<CosignerRegistry> {
    fn from_ref(s: &AppState) -> Self {
        s.registry.clone()
    }
}

impl FromRef<AppState> for Arc<DkgCoordinator> {
    fn from_ref(s: &AppState) -> Self {
        s.dkg_coordinator.clone()
    }
}

impl FromRef<AppState> for Arc<EvtxoKeygenCoordinator> {
    fn from_ref(s: &AppState) -> Self {
        s.evtxo_coordinator.clone()
    }
}

impl FromRef<AppState> for Arc<wallet_proto::GetServerInfoResponse> {
    fn from_ref(s: &AppState) -> Self {
        s.server_info.clone()
    }
}

/// Build the axum router. All authenticated routes are nested under
/// `/u/{user_id}/...` so the dispatcher can route directly to the actor.
pub fn routes(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        // DKG
        .route("/u/{user_id}/dkg/step1", post(dkg_step1))
        .route("/u/{user_id}/dkg/step2", post(dkg_step2))
        .route("/u/{user_id}/dkg/step3", post(dkg_step3))
        // eVTXO key generation (resharing)
        .route("/u/{user_id}/evtxo-keygen/step1", post(evtxo_keygen_step1))
        .route("/u/{user_id}/evtxo-keygen/step2", post(evtxo_keygen_step2))
        .route("/u/{user_id}/evtxo-keygen/step3", post(evtxo_keygen_step3))
        .route("/u/{user_id}/evtxo/onboard", post(evtxo_onboard))
        .route("/u/{user_id}/evtxo/pending-shares", post(evtxo_pending_shares))
        .route("/u/{user_id}/evtxo/ack-share", post(evtxo_ack_share))
        // Signing
        .route("/u/{user_id}/sign/step1", post(sign_step1))
        .route("/u/{user_id}/sign/step2", post(sign_step2))
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
        // Push notifications
        .route("/u/{user_id}/push/register-device-token", post(register_device_token))
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
    ($reg:ident, $user_id:ident, $variant:ident, $req:expr) => {{
        let req = $req;
        match $reg
            .dispatch(&$user_id, move |reply| CosignerCommand::$variant { req, reply })
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

#[tracing::instrument(skip_all, name = "rest::dkg_step1", fields(user_id = %user_id))]
async fn dkg_step1(
    State(coord): State<Arc<DkgCoordinator>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep1Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
        is_restore: bool_field(&body, "is_restore"),
    };
    match coord.dkg_step1(&user_id, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::dkg_step2", fields(user_id = %user_id))]
async fn dkg_step2(
    State(coord): State<Arc<DkgCoordinator>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep2Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
    };
    match coord.dkg_step2(&user_id, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::dkg_step3", fields(user_id = %user_id))]
async fn dkg_step3(
    State(coord): State<Arc<DkgCoordinator>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::DkgStep3Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
    };
    match coord.dkg_step3(&user_id, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// eVTXO key generation (resharing)
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::evtxo_keygen_step1", fields(user_id = %user_id))]
async fn evtxo_keygen_step1(
    State(coord): State<Arc<EvtxoKeygenCoordinator>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::EvtxoKeygenStep1Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
        contract_id: hex_field(&body, "contract_id"),
        contract_wasm: hex_field(&body, "contract_wasm"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        server_pk: hex_field(&body, "server_pk"),
        exit_delay: i64_field(&body, "exit_delay") as u32,
    };
    match coord.step1(&user_id, req).await {
        // Reshare: return both dealers' round1 packages (id_hex -> JSON) so the
        // author can run dkg_part2. One-shot register (V′ == V) leaves the map
        // empty and returns the eVTXO spk (hex, per the REST convention).
        Ok(resp) => Ok(Json(json!({
            "round1_packages": resp.round1_packages,
            "evtxo_script_pubkey": to_hex(&resp.evtxo_script_pubkey),
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::evtxo_keygen_step2", fields(user_id = %user_id))]
async fn evtxo_keygen_step2(
    State(coord): State<Arc<EvtxoKeygenCoordinator>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::EvtxoKeygenStep2Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match coord.step2(&user_id, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::evtxo_keygen_step3", fields(user_id = %user_id))]
async fn evtxo_keygen_step3(
    State(coord): State<Arc<EvtxoKeygenCoordinator>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::EvtxoKeygenStep3Request {
        user_id: user_id_bytes(&user_id),
        identifier: hex_field(&body, "identifier"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match coord.step3(&user_id, req).await {
        // Hand-build with hex-encoded bytes (the REST convention; cf. sign_step2).
        // Generic serde would emit `evtxo_script_pubkey` as a JSON array, which the
        // Dart client decodes as hex.
        Ok(resp) => Ok(Json(json!({
            "round2_packages_for_me": resp.round2_packages_for_me,
            "evtxo_address": resp.evtxo_address,
            "evtxo_script_pubkey": to_hex(&resp.evtxo_script_pubkey),
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// Signing
// ---------------------------------------------------------------------------

/// Resolve the actor to dispatch a (possibly contract) spend to. A party
/// addressing a contract cosigner GROUP by `V′` (URL route) with its own
/// `claimed_share` is fanned out to its dedicated per-party cosigner `cc_id`, so
/// the spend lands on an isolated single-user actor. All other routes — normal
/// wallets, and one-shot `V′==V` eVTXOs that aren't groups — are unchanged.
fn spend_dispatch_route(reg: &CosignerRegistry, route: &str, claimed_share: &[u8]) -> String {
    if claimed_share.is_empty() {
        return route.to_string();
    }
    crate::contract::group::spend_route(
        reg.shared().persistence.as_ref(),
        route,
        &hex::encode(claimed_share),
    )
    .unwrap_or_else(|| route.to_string())
}

#[tracing::instrument(skip_all, name = "rest::sign_step1", fields(user_id = %user_id))]
async fn sign_step1(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    // Routing is by the URL path (`user_id`). For a contract eVTXO spend the path is
    // the contract actor V′ and `claimed_share` is the spending recipient — set
    // `req.user_id` to it so the actor authenticates + selects the recipient's share.
    let claimed_share = hex_field(&body, "claimed_share");
    let req_user_id = if claimed_share.is_empty() {
        user_id_bytes(&user_id)
    } else {
        claimed_share.clone()
    };
    let route = spend_dispatch_route(&reg, &user_id, &claimed_share);
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
        .dispatch(&route, move |reply| CosignerCommand::SignStep1 { req, reply })
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
    State(reg): State<Arc<CosignerRegistry>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let claimed_share = hex_field(&body, "claimed_share");
    let req_user_id = if claimed_share.is_empty() {
        user_id_bytes(&user_id)
    } else {
        claimed_share.clone()
    };
    let route = spend_dispatch_route(&reg, &user_id, &claimed_share);
    let req = wallet_proto::SignStep2Request {
        user_id: req_user_id,
        signature_share: hex_field(&body, "signature_share"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        claimed_share,
    };
    match reg
        .dispatch(&route, move |reply| CosignerCommand::SignStep2 { req, reply })
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
// Multi-user contract onboarding
// ---------------------------------------------------------------------------

/// Author onboards a participant. URL path = the contract actor (V′); body `user_id`
/// = the author (the claimed group member).
#[tracing::instrument(skip_all, name = "rest::evtxo_onboard", fields(group = %user_id))]
async fn evtxo_onboard(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::EvtxoOnboardRequest {
        user_id: hex_field(&body, "user_id"),
        evtxo_script_pubkey: hex_field(&body, "evtxo_script_pubkey"),
        recipient_vk: hex_field(&body, "recipient_vk"),
        a_at_cosigner: hex_field(&body, "a_at_cosigner"),
        a_at_participant_point: hex_field(&body, "a_at_participant_point"),
        ecies_a_at_participant: hex_field(&body, "ecies_a_at_participant"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        // Routing is by the URL path (the contract actor V′); this field is only the
        // client-side routing hint and is unused server-side.
        contract_group_id: hex_field(&body, "contract_group_id"),
    };
    match reg
        .dispatch(&user_id, move |reply| CosignerCommand::EvtxoOnboard { req, reply })
        .await
    {
        Ok(r) => Ok(Json(json!({ "ok": r.ok }))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::evtxo_pending_shares", fields(user_id = %user_id))]
async fn evtxo_pending_shares(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::EvtxoPendingSharesRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match reg
        .dispatch(&user_id, move |reply| CosignerCommand::EvtxoPendingShares { req, reply })
        .await
    {
        Ok(r) => {
            let shares: Vec<Value> = r
                .shares
                .iter()
                .map(|s| {
                    json!({
                        "evtxo_script_pubkey": to_hex(&s.evtxo_script_pubkey),
                        "contract_group_id": to_hex(&s.contract_group_id),
                        "contract_id": to_hex(&s.contract_id),
                        "ecies_half_author": to_hex(&s.ecies_half_author),
                        "ecies_half_cosigner": to_hex(&s.ecies_half_cosigner),
                        "public_key_package_json": s.public_key_package_json,
                        "exit_delay": s.exit_delay,
                        "server_pk": to_hex(&s.server_pk),
                        "owner_pk": to_hex(&s.owner_pk),
                    })
                })
                .collect();
            Ok(Json(json!({ "shares": shares })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::evtxo_ack_share", fields(user_id = %user_id))]
async fn evtxo_ack_share(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::EvtxoAckShareRequest {
        user_id: user_id_bytes(&user_id),
        evtxo_script_pubkey: hex_field(&body, "evtxo_script_pubkey"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    match reg
        .dispatch(&user_id, move |reply| CosignerCommand::EvtxoAckShare { req, reply })
        .await
    {
        Ok(r) => Ok(Json(json!({ "ok": r.ok }))),
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::broadcast_transaction", fields(user_id = %user_id))]
async fn broadcast_transaction(
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
        .dispatch(&user_id, move |reply| CosignerCommand::SendVtxo { req, reply })
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

#[tracing::instrument(skip_all, name = "rest::redeem_vtxo", fields(user_id = %user_id))]
async fn redeem_vtxo(
    State(reg): State<Arc<CosignerRegistry>>,
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
    State(reg): State<Arc<CosignerRegistry>>,
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
        .dispatch(&user_id, move |reply| CosignerCommand::Settle { req, reply })
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
    State(reg): State<Arc<CosignerRegistry>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let req = wallet_proto::SettleDelegateRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
        store_only: body
            .get("store_only")
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    };
    match reg
        .dispatch(&user_id, move |reply| CosignerCommand::SettleDelegate { req, reply })
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
    State(reg): State<Arc<CosignerRegistry>>,
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

#[tracing::instrument(skip_all, name = "rest::register_device_token", fields(user_id = %user_id))]
async fn register_device_token(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(user_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    dispatch_json!(reg, user_id, RegisterDeviceToken, wallet_proto::RegisterDeviceTokenRequest {
        user_id: user_id_bytes(&user_id),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        fcm_token: str_field(&body, "fcm_token"),
        platform: str_field(&body, "platform"),
        app_version: str_field(&body, "app_version"),
    })
}
