//! REST/JSON API: extracts the `group_key` (the actor id) from the URL path, builds a `CosignerCommand`,
//! and dispatches via the per-user actor through `CosignerRegistry`.

use std::sync::Arc;

use axum::extract::{FromRef, Path, Query, State};
use axum::http::StatusCode;
use axum::response::sse::{Event, KeepAlive, Sse};
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde_json::{json, Value};
use tokio_stream::wrappers::BroadcastStream;
use tokio_stream::StreamExt;
use tonic::Status;

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
        // DKG — not actor-routed by path: the group key V doesn't exist yet, so these route by
        // the `user_id` in the body (the wallet's pre-DKG identity).
        .route("/dkg/step1", post(onboarding_step1))
        .route("/dkg/step2", post(onboarding_step2))
        .route("/dkg/step3", post(onboarding_step3))
        // Service enrolment: refresh V onto a `{service, cosigner}` pairing.
        .route("/u/{group_key}/service/enroll", post(service_enroll))
        .route("/u/{group_key}/service/list", post(service_list))
        .route("/u/{group_key}/service/revoke", post(service_revoke))
        // Request-to-pay. All signed by the wallet that owns `{group_key}` EXCEPT
        // `payment-request/create`, which is signed by the REQUESTER and routed to the PAYER's
        // actor — the payer's contact allowlist is what authorizes it.
        .route("/u/{group_key}/contacts/add", post(contact_add))
        .route("/u/{group_key}/contacts/remove", post(contact_remove))
        .route("/u/{group_key}/contacts/list", post(contact_list))
        .route(
            "/u/{group_key}/payment-request/create",
            post(payment_request_create),
        )
        .route(
            "/u/{group_key}/payment-request/list",
            post(payment_request_list),
        )
        .route(
            "/u/{group_key}/payment-request/decline",
            post(payment_request_decline),
        )
        // SSE event stream — a backend user holds this open and reacts to cosigner events.
        .route("/u/{group_key}/events", get(events_stream))
        // Signing
        .route("/u/{group_key}/sign/step1", post(sign_step1))
        .route("/u/{group_key}/sign/step2", post(sign_step2))
        // Ark
        .route("/u/{group_key}/ark/info", post(get_ark_info))
        .route("/u/{group_key}/ark/address", post(get_ark_address))
        .route(
            "/u/{group_key}/ark/boarding-address",
            post(get_boarding_address),
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
        // WebAuthn ceremonies — UNAUTHENTICATED at the boundary (they ARE the auth bootstrap that
        // mints a session token); no `auth_check`. The cosigner is its own Relying Party.
        .route("/passkey/register/begin", post(passkey_register_begin))
        .route("/passkey/register/finish", post(passkey_register_finish))
        .route("/passkey/assert/begin", post(passkey_assert_begin))
        .route("/passkey/assert/finish", post(passkey_assert_finish))
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

/// Extract + verify an upstream session token from the `Authorization: Bearer <jwt>` header.
/// Returns the verified claims, or `None` when the header is absent/malformed or the token fails
/// verification (disabled verifier, bad signature, expired) — in which case handlers transparently
/// fall back to the legacy Schnorr auth path. `shared` is the per-request `SharedServices` (from
/// `reg.shared()` / `coord.shared()`), which holds the cosigner's `session_authority`.
fn session_from_headers(
    headers: &axum::http::HeaderMap,
    shared: &crate::shared::SharedServices,
) -> Option<crate::auth::session::SessionClaims> {
    let tok = headers
        .get(axum::http::header::AUTHORIZATION)?
        .to_str()
        .ok()?
        .strip_prefix("Bearer ")?;
    shared.session_authority.verify(tok).ok()
}

/// The signer's verifying share for a sign request: the body `user_id` (the user or the service),
/// falling back to the URL `group_key` for callers that route by their own id.
fn signer_user_id(body: &Value, group_key: &str) -> Vec<u8> {
    let uid = hex_field(body, "user_id");
    if uid.is_empty() {
        user_id_bytes(group_key)
    } else {
        uid
    }
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

/// Dispatch an AUTHENTICATED command. Authentication runs HERE at the REST boundary — the request's
/// `user_id`/`signature`/`timestamp_ms` are verified against `$op` (a valid session token bound to
/// the user, else the Schnorr signature) BEFORE dispatch; the actor no longer re-checks. `$session`
/// is the verified upstream session token (or `None`).
macro_rules! dispatch_json {
    ($reg:ident, $group_key:ident, $variant:ident, $op:expr, $session:expr, $req:expr) => {{
        let req = $req;
        if let Err(status) = crate::cosigner::handlers::helpers::verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            $op,
            ($session).as_ref(),
        ) {
            return Err(status_to_response(status));
        }
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
    // No-session form for genuinely UNAUTHENTICATED variants (e.g. redeem_vtxo).
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

#[tracing::instrument(skip_all, name = "rest::dkg_step1")]
async fn onboarding_step1(
    State(coord): State<Arc<OnboardingManager>>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id_hex = str_field(&body, "user_id");
    let req = wallet_proto::DkgStep1Request {
        user_id: hex_field(&body, "user_id"),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
    };
    match coord.onboarding_step1(&user_id_hex, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::dkg_step2")]
async fn onboarding_step2(
    State(coord): State<Arc<OnboardingManager>>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id_hex = str_field(&body, "user_id");
    let req = wallet_proto::DkgStep2Request {
        user_id: hex_field(&body, "user_id"),
        identifier: hex_field(&body, "identifier"),
        round1_package: str_field(&body, "round1_package"),
    };
    match coord.onboarding_step2(&user_id_hex, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

#[tracing::instrument(skip_all, name = "rest::dkg_step3")]
async fn onboarding_step3(
    State(coord): State<Arc<OnboardingManager>>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id_hex = str_field(&body, "user_id");
    let req = wallet_proto::DkgStep3Request {
        user_id: hex_field(&body, "user_id"),
        identifier: hex_field(&body, "identifier"),
        round2_packages_for_others: map_field(&body, "round2_packages_for_others"),
    };
    match coord.onboarding_step3(&user_id_hex, req).await {
        Ok(resp) => Ok(Json(serde_json::to_value(resp).unwrap_or(json!({})))),
        Err(status) => Err(status_to_response(status)),
    }
}

// ---------------------------------------------------------------------------
// Service enrolment
// ---------------------------------------------------------------------------

/// Mint a `{service, cosigner}` share on a fresh refreshed polynomial.
///
/// The wallet deals its half (`a@service`, `a@cosigner`) and posts the cosigner's half plus the
/// point commitment to `a@service`; the cosigner verifies that dealing is internally consistent,
/// deals its own half, checks the resulting polynomial has never been used before, and seeds a
/// pairing actor keyed by the polynomial's id.
///
/// Delivery is deliberately wallet-relayed rather than inboxed: the cosigner returns `b@service`
/// ECIES-sealed to the service's key, and the wallet forwards both halves. The cosigner keeps no
/// delivery state, and a wallet that withholds only denies itself the service — it cannot forge
/// the cosigner's half, and the service verifies the sum against the pairing package regardless.
///
/// Authenticated: this dispatches a secret-share operation against the caller's wallet, so it
/// must not be reachable anonymously.
#[tracing::instrument(skip_all, name = "rest::service_enroll", fields(group_key = %group_key))]
async fn service_enroll(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let user_id = signer_user_id(&body, &group_key);
    crate::cosigner::handlers::helpers::verify_auth(
        &user_id,
        &hex_field(&body, "signature"),
        i64_field(&body, "timestamp_ms"),
        crate::auth::message::OP_SERVICE_ENROLL,
        session.as_ref(),
    )
    .map_err(status_to_response)?;

    let bad = |m: &str| status_to_response(Status::invalid_argument(m.to_string()));

    let service_id = hex_field(&body, "service_id");
    if service_id.len() != 33 {
        return Err(bad("service_id must be 33 bytes"));
    }
    let service_id_hex = hex::encode(&service_id);
    let frost_id = threshold::identifier::Identifier::derive(&service_id)
        .map_err(|e| bad(&format!("derive service id: {e:?}")))?;
    let receiver_id_hex = hex::encode(frost_id.serialize());

    let a_at_service_point = hex_field(&body, "a_at_service_point");
    if a_at_service_point.len() != 33 {
        return Err(bad("a_at_service_point must be 33 bytes"));
    }
    let a_at_cosigner = hex_field(&body, "a_at_cosigner");
    if a_at_cosigner.len() != 32 {
        return Err(bad("a_at_cosigner must be 32 bytes"));
    }
    let wallet_identifier = hex_field(&body, "identifier");
    if wallet_identifier.len() != 32 {
        return Err(bad("identifier must be 32 bytes"));
    }

    // The ceiling this pairing will sign under. Fail closed at the boundary too: an enrolment
    // that declares no destinations would produce a pairing that can never sign, which is far
    // more likely a caller bug than an intent.
    let allowed_destinations: Vec<String> = body
        .get("allowed_destinations")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|d| d.as_str().map(|s| s.to_ascii_lowercase()))
                .collect()
        })
        .unwrap_or_default();
    if allowed_destinations.is_empty() {
        return Err(bad(
            "allowed_destinations must be non-empty — a service with no declared reach cannot sign",
        ));
    }
    let max_sats_per_signature = body
        .get("max_sats_per_signature")
        .and_then(|v| v.as_u64())
        .unwrap_or(0);
    if max_sats_per_signature == 0 {
        return Err(bad("max_sats_per_signature must be greater than zero"));
    }

    // One dispatch, to the WALLET's own actor. The refresh is key-preserving, so the pairing
    // shares the wallet's group key `V` and has no actor of its own: the actor verifies the
    // wallet's dealing, deals its own half, installs its counter-share under the service's
    // verifying share, and seals — all before this returns.
    let service_id_bytes = service_id.clone();
    let refreshed = reg
        .dispatch(&group_key, move |reply| CosignerCommand::ServiceRefresh {
            receiver_id_hex,
            receiver_partial_point: a_at_service_point,
            wallet_id_hex: hex::encode(&wallet_identifier),
            a_at_cosigner,
            min_signers: 2,
            service_id: service_id_bytes,
            policy: crate::cosigner::types::ServicePolicy {
                allowed_destinations,
                max_sats_per_signature,
            },
            reply,
        })
        .await
        .map_err(status_to_response)?;

    let mut recipient = [0u8; 33];
    recipient.copy_from_slice(&service_id);
    let half: [u8; 32] = refreshed
        .receiver_half
        .as_slice()
        .try_into()
        .map_err(|_| status_to_response(Status::internal("receiver_half must be 32 bytes")))?;
    let sealed = threshold::ecies::encrypt(&half, &recipient, &mut rand::rngs::OsRng)
        .map_err(|e| status_to_response(Status::internal(format!("ecies b@service: {e:?}"))))?;

    let delivered = crate::service_delivery::push_half(
        reg.shared(),
        &service_id_hex,
        crate::service_delivery::Half {
            role: "cosigner",
            pairing_group_key: &group_key,
            service_verifying_share: &refreshed.service_verifying_share_hex,
            pairing_public_key_package_json: &refreshed.pairing_public_key_package_json,
            ecies_half: &to_hex(&sealed),
        },
    )
    .await;

    
    Ok(Json(json!({
        "pairing_group_key": group_key,
        "service_verifying_share": refreshed.service_verifying_share_hex,
        "pairing_public_key_package_json": refreshed.pairing_public_key_package_json,
        "cosigner_half_delivered": delivered,
    })))
}

/// What can sign for this wallet.
///
/// The pairing map is the only index there is, so this is the answer to "who did I delegate to?".
/// Wallet-authenticated: a service must not be able to enumerate its peers.
#[tracing::instrument(skip_all, name = "rest::service_list", fields(group_key = %group_key))]
async fn service_list(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    crate::cosigner::handlers::helpers::verify_auth(
        &user_id_bytes(&group_key),
        &hex_field(&body, "signature"),
        i64_field(&body, "timestamp_ms"),
        crate::auth::message::OP_SERVICE_LIST,
        session.as_ref(),
    )
    .map_err(status_to_response)?;

    let rows = reg
        .dispatch(&group_key, |reply| CosignerCommand::ListServicePairings { reply })
        .await
        .map_err(status_to_response)?;

    let services: Vec<Value> = rows
        .into_iter()
        .map(|(verifying_share, service_id)| {
            json!({
                "verifying_share": verifying_share,
                "service_id": service_id,
            })
        })
        .collect();
    Ok(Json(json!({ "services": services })))
}


#[tracing::instrument(skip_all, name = "rest::service_revoke", fields(group_key = %group_key))]
async fn service_revoke(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    crate::cosigner::handlers::helpers::verify_auth(
        &user_id_bytes(&group_key),
        &hex_field(&body, "signature"),
        i64_field(&body, "timestamp_ms"),
        crate::auth::message::OP_SERVICE_REVOKE,
        session.as_ref(),
    )
    .map_err(status_to_response)?;

    let verifying_share_hex = str_field(&body, "verifying_share").to_ascii_lowercase();
    if verifying_share_hex.is_empty() {
        return Err(status_to_response(Status::invalid_argument(
            "verifying_share is required",
        )));
    }

    let removed = reg
        .dispatch(&group_key, move |reply| CosignerCommand::RemoveServicePairing {
            verifying_share_hex,
            reply,
        })
        .await
        .map_err(status_to_response)?;

    Ok(Json(json!({ "revoked": removed })))
}


// ---------------------------------------------------------------------------
// Request-to-pay
// ---------------------------------------------------------------------------

/// Project a contact to JSON with HEX byte fields. `dispatch_json!` would serialise proto `bytes`
/// as a JSON number array; every other endpoint here emits hex, and the Dart client parses hex, so
/// these responses are built by hand to match.
fn contact_json(c: &wallet_proto::Contact) -> Value {
    json!({
        "verifying_key": to_hex(&c.verifying_key),
        "label": c.label,
        "added_at": c.added_at,
    })
}

/// Project a payment intent to JSON with HEX byte fields (see `contact_json`).
fn intent_json(i: &wallet_proto::PaymentIntent) -> Value {
    json!({
        "id": i.id,
        "from_verifying_key": to_hex(&i.from_verifying_key),
        "to_ark_address": i.to_ark_address,
        "amount_sats": i.amount_sats,
        "memo": i.memo,
        "created_at": i.created_at,
        "expires_at": i.expires_at,
        "status": i.status,
        "ark_txid": i.ark_txid,
    })
}

/// Authorize a party to bill this wallet. Signed by the owner.
#[tracing::instrument(skip_all, name = "rest::contact_add", fields(group_key = %group_key))]
async fn contact_add(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::ContactAddRequest {
        user_id: signer_user_id(&body, &group_key),
        contact_verifying_key: hex_field(&body, "contact_verifying_key"),
        label: body
            .get("label")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string(),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    dispatch_json!(
        reg,
        group_key,
        ContactAdd,
        crate::auth::message::OP_CONTACT_ADD,
        session,
        req
    )
}

/// Revoke a contact (also drops that contact's pending requests). Signed by the owner.
#[tracing::instrument(skip_all, name = "rest::contact_remove", fields(group_key = %group_key))]
async fn contact_remove(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::ContactRemoveRequest {
        user_id: signer_user_id(&body, &group_key),
        contact_verifying_key: hex_field(&body, "contact_verifying_key"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    dispatch_json!(
        reg,
        group_key,
        ContactRemove,
        crate::auth::message::OP_CONTACT_REMOVE,
        session,
        req
    )
}

/// List the wallet's authorized contacts. Signed by the owner.
#[tracing::instrument(skip_all, name = "rest::contact_list", fields(group_key = %group_key))]
async fn contact_list(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::ContactListRequest {
        user_id: signer_user_id(&body, &group_key),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    if let Err(status) = crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_CONTACT_LIST,
        session.as_ref(),
    ) {
        return Err(status_to_response(status));
    }
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::ContactList { req, reply })
        .await
    {
        Ok(r) => {
            let contacts: Vec<Value> = r.contacts.iter().map(contact_json).collect();
            Ok(Json(json!({ "contacts": contacts })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

/// Ask `{group_key}` to pay. **Signed by the REQUESTER, not the payer**: `user_id` in the body is
/// the requester's key, while the URL selects the payer's actor. `verify_auth` only proves the
/// caller holds that key — the payer's contact allowlist (checked in the actor) is the actual
/// authorization.
#[tracing::instrument(skip_all, name = "rest::payment_request_create", fields(group_key = %group_key))]
async fn payment_request_create(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::PaymentRequestCreateRequest {
        user_id: signer_user_id(&body, &group_key),
        amount_sats: body
            .get("amount_sats")
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        memo: body
            .get("memo")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string(),
        expires_in_secs: body
            .get("expires_in_secs")
            .and_then(|v| v.as_i64())
            .unwrap_or_default(),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    if let Err(status) = crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_PAYREQ_CREATE,
        session.as_ref(),
    ) {
        return Err(status_to_response(status));
    }
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::PaymentRequestCreate { req, reply })
        .await
    {
        Ok(r) => Ok(Json(json!({
            "intent": r.intent.as_ref().map(intent_json),
        }))),
        Err(status) => Err(status_to_response(status)),
    }
}

/// The payer's request inbox. Signed by the payer.
#[tracing::instrument(skip_all, name = "rest::payment_request_list", fields(group_key = %group_key))]
async fn payment_request_list(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::PaymentRequestListRequest {
        user_id: signer_user_id(&body, &group_key),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    if let Err(status) = crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_PAYREQ_LIST,
        session.as_ref(),
    ) {
        return Err(status_to_response(status));
    }
    match reg
        .dispatch(&group_key, move |reply| CosignerCommand::PaymentRequestList { req, reply })
        .await
    {
        Ok(r) => {
            let intents: Vec<Value> = r.intents.iter().map(intent_json).collect();
            Ok(Json(json!({ "intents": intents })))
        }
        Err(status) => Err(status_to_response(status)),
    }
}

/// The payer declines a pending request. Signed by the payer.
#[tracing::instrument(skip_all, name = "rest::payment_request_decline", fields(group_key = %group_key))]
async fn payment_request_decline(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::PaymentRequestDeclineRequest {
        user_id: signer_user_id(&body, &group_key),
        id: body
            .get("id")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string(),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    dispatch_json!(
        reg,
        group_key,
        PaymentRequestDecline,
        crate::auth::message::OP_PAYREQ_DECLINE,
        session,
        req
    )
}


// ---------------------------------------------------------------------------
// Event stream (Phase 3) — a backend user holds this SSE connection open and reacts to events
// about itself. Auth at connect via signed query params.
// ---------------------------------------------------------------------------

#[derive(serde::Deserialize)]
struct EventsAuth {
    signature: String,
    timestamp_ms: i64,
}

#[tracing::instrument(skip_all, name = "rest::events", fields(group_key = %group_key))]
async fn events_stream(
    State(coord): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    Query(q): Query<EventsAuth>,
    headers: axum::http::HeaderMap,
) -> Result<axum::response::Response, (StatusCode, Json<Value>)> {
    let user_id = user_id_bytes(&group_key);
    let signature = hex::decode(&q.signature).unwrap_or_default();
    // EventSource can't set headers, so auth is via signed query params; still offer a Bearer token
    // if one is somehow present (harmless — `None` for EventSource, then the query-param path runs).
    let session = session_from_headers(&headers, coord.shared());
    crate::cosigner::handlers::helpers::verify_auth(
        &user_id,
        &signature,
        q.timestamp_ms,
        crate::auth::message::OP_EVENTS_SUBSCRIBE,
        session.as_ref(),
    )
    .map_err(status_to_response)?;

    let rx = coord.shared().events.subscribe(&group_key);
    // Lagged (slow subscriber overran the buffer) → drop those events; the client catches up via
    // its durable record. Each event becomes an SSE frame `event: <kind>\ndata: <json>`.
    let stream = BroadcastStream::new(rx).filter_map(|ev| {
        ev.ok().map(|e| {
            Ok::<_, std::convert::Infallible>(Event::default().event(e.kind()).data(e.data_json()))
        })
    });
    Ok(Sse::new(stream)
        .keep_alive(KeepAlive::default())
        .into_response())
}

// ---------------------------------------------------------------------------
// Signing
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::sign_step1", fields(group_key = %group_key))]
async fn sign_step1(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    // Routing is by the URL path (`group_key` — the actor); `user_id` is the signer's verifying
    // share (the user or the service), used for auth. Defaults to the group_key for callers that
    // route by their own id.
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::SignStep1Request {
        user_id: signer_user_id(&body, &group_key),
        hiding_commitment: hex_field(&body, "hiding_commitment"),
        binding_commitment: hex_field(&body, "binding_commitment"),
        message_to_sign: hex_field(&body, "message_to_sign"),
        signature: hex_field(&body, "signature"),
        full_transaction: hex_field(&body, "full_transaction"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        script_path_spend: bool_field(&body, "script_path_spend"),
    };
    crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_SIGN_STEP1,
        session.as_ref(),
    )
    .map_err(status_to_response)?;
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::SignStep2Request {
        user_id: signer_user_id(&body, &group_key),
        signature_share: hex_field(&body, "signature_share"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
    };
    crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_SIGN_STEP2,
        session.as_ref(),
    )
    .map_err(status_to_response)?;
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
// Ark
// ---------------------------------------------------------------------------

#[tracing::instrument(skip_all, name = "rest::get_ark_info", fields(group_key = %group_key))]
async fn get_ark_info(
    State(reg): State<Arc<CosignerRegistry>>,
    Path(group_key): Path<String>,
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    dispatch_json!(
        reg,
        group_key,
        GetArkInfo,
        crate::auth::message::OP_GET_ARK_INFO,
        session,
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    dispatch_json!(
        reg,
        group_key,
        GetArkAddress,
        crate::auth::message::OP_GET_ARK_ADDRESS,
        session,
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    dispatch_json!(
        reg,
        group_key,
        GetBoardingAddress,
        crate::auth::message::OP_GET_BOARDING_ADDRESS,
        session,
        wallet_proto::GetBoardingAddressRequest {
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    dispatch_json!(
        reg,
        group_key,
        ListVtxos,
        crate::auth::message::OP_LIST_VTXOS,
        session,
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    dispatch_json!(
        reg,
        group_key,
        ListArkTransactions,
        crate::auth::message::OP_LIST_ARK_TXS,
        session,
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let req = wallet_proto::SendVtxoRequest {
        user_id: user_id_bytes(&group_key),
        recipient_ark_address: str_field(&body, "recipient_ark_address"),
        amount: u64_field(&body, "amount"),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
    };
    crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_SEND_VTXO,
        session.as_ref(),
    )
    .map_err(status_to_response)?;
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    let boarding_utxos = body
        .get("boarding_utxos")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .map(|u| wallet_proto::BoardingUtxo {
                    txid: str_field(u, "txid"),
                    vout: u.get("vout").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
                    amount_sats: u.get("amount_sats").and_then(|v| v.as_u64()).unwrap_or(0),
                })
                .collect()
        })
        .unwrap_or_default();
    let req = wallet_proto::SettleRequest {
        user_id: user_id_bytes(&group_key),
        signature: hex_field(&body, "signature"),
        timestamp_ms: i64_field(&body, "timestamp_ms"),
        signed_messages: hex_array_field(&body, "signed_messages"),
        boarding_utxos,
    };
    crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_SETTLE,
        session.as_ref(),
    )
    .map_err(status_to_response)?;
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
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
    crate::cosigner::handlers::helpers::verify_auth(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        crate::auth::message::OP_SETTLE_DELEGATE,
        session.as_ref(),
    )
    .map_err(status_to_response)?;
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    dispatch_json!(
        reg,
        group_key,
        SubmitArkSend,
        crate::auth::message::OP_SEND_VTXO,
        session,
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
    headers: axum::http::HeaderMap,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let session = session_from_headers(&headers, reg.shared());
    dispatch_json!(
        reg,
        group_key,
        RegisterDeviceToken,
        crate::auth::message::OP_REGISTER_DEVICE_TOKEN,
        session,
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

// ---------------------------------------------------------------------------
// WebAuthn ceremonies — the cosigner is its own Relying Party. UNAUTHENTICATED
// (they mint the session token that authenticates later requests). Each handler
// calls the WebauthnServer directly (no actor dispatch). The webauthn-rs
// challenge types serialize to the WebAuthn spec JSON, so we return them as-is.
// ---------------------------------------------------------------------------

/// 503 body used when `WEBAUTH_RP_*` was invalid so no WebauthnServer was built.
fn webauthn_disabled() -> (StatusCode, Json<Value>) {
    (
        StatusCode::SERVICE_UNAVAILABLE,
        Json(json!({ "error": "webauthn disabled" })),
    )
}

fn webauthn_bad_request(msg: String) -> (StatusCode, Json<Value>) {
    (StatusCode::BAD_REQUEST, Json(json!({ "error": msg })))
}

#[tracing::instrument(skip_all, name = "rest::passkey_register_begin")]
async fn passkey_register_begin(
    State(reg): State<Arc<CosignerRegistry>>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let server = reg.shared().webauthn.clone().ok_or_else(webauthn_disabled)?;
    let user_id = str_field(&body, "user_id");

    // Prove ownership of the wallet before attaching an authenticator to it.
    //
    // Without this the route was an account takeover: user_id came straight from
    // the body, group keys are public (they are the URL path segment and are
    // handed out for contacts), and register_begin APPENDS to a user that already
    // has a credential — excludeCredentials is only a client-side hint. Anyone
    // could register their own authenticator against someone else's wallet and
    // then mint a session token whose `sub` is that wallet, which verify_auth
    // accepts as full authentication for every operation.
    //
    // A Schnorr signature over the wallet's own signing key is the only proof
    // that works here: a session token is what a passkey MINTS, so accepting one
    // would be circular and would let a leaked token add a second authenticator.
    let user_id_bytes = hex::decode(&user_id)
        .map_err(|_| webauthn_bad_request("user_id must be hex".into()))?;
    let signature = hex::decode(str_field(&body, "signature"))
        .map_err(|_| webauthn_bad_request("signature must be hex".into()))?;
    let timestamp_ms = body
        .get("timestamp_ms")
        .and_then(|v| v.as_i64())
        .unwrap_or_default();
    crate::cosigner::handlers::helpers::verify_auth(
        &user_id_bytes,
        &signature,
        timestamp_ms,
        crate::auth::message::OP_PASSKEY_REGISTER,
        None,
    )
    .map_err(|e| (StatusCode::UNAUTHORIZED, Json(json!({ "error": e.message() }))))?;

    let (ceremony_id, options) = server
        .register_begin(&user_id)
        .map_err(webauthn_bad_request)?;
    Ok(Json(json!({ "ceremony_id": ceremony_id, "options": options })))
}

#[tracing::instrument(skip_all, name = "rest::passkey_register_finish")]
async fn passkey_register_finish(
    State(reg): State<Arc<CosignerRegistry>>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let server = reg.shared().webauthn.clone().ok_or_else(webauthn_disabled)?;
    let ceremony_id = str_field(&body, "ceremony_id");
    let credential = body
        .get("credential")
        .cloned()
        .ok_or_else(|| webauthn_bad_request("missing credential".into()))?;
    let credential = serde_json::from_value(credential)
        .map_err(|e| webauthn_bad_request(format!("bad credential: {e}")))?;
    server
        .register_finish(&ceremony_id, credential)
        .map_err(webauthn_bad_request)?;
    Ok(Json(json!({ "ok": true })))
}

#[tracing::instrument(skip_all, name = "rest::passkey_assert_begin")]
async fn passkey_assert_begin(
    State(reg): State<Arc<CosignerRegistry>>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let server = reg.shared().webauthn.clone().ok_or_else(webauthn_disabled)?;
    let user_id = str_field(&body, "user_id");
    let (ceremony_id, options) = server.assert_begin(&user_id).map_err(webauthn_bad_request)?;
    Ok(Json(json!({ "ceremony_id": ceremony_id, "options": options })))
}

#[tracing::instrument(skip_all, name = "rest::passkey_assert_finish")]
async fn passkey_assert_finish(
    State(reg): State<Arc<CosignerRegistry>>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let server = reg.shared().webauthn.clone().ok_or_else(webauthn_disabled)?;
    let ceremony_id = str_field(&body, "ceremony_id");
    let credential = body
        .get("credential")
        .cloned()
        .ok_or_else(|| webauthn_bad_request("missing credential".into()))?;
    let credential = serde_json::from_value(credential)
        .map_err(|e| webauthn_bad_request(format!("bad credential: {e}")))?;
    let token = server
        .assert_finish(&ceremony_id, credential)
        .map_err(webauthn_bad_request)?;
    Ok(Json(json!({ "token": token })))
}
