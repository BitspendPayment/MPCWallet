//! Dummy always-online contract-signer service for e2e.
//!
//! In the contract-eVTXO model the wallet's key `V` is key-preservingly REFRESHED onto a
//! `{service, cosigner}` pairing so this always-online service can co-sign when the wallet is
//! offline. Creation delivers two independent halves of the service's `V` share here:
//!   - wallet   → `a@service` (role="user"), POSTed directly so the cosigner never sees it.
//!   - cosigner → `b@service` (role="cosigner") + the contract `context`.
//! The service sums them into `s_service = a@service + b@service (mod n)`.
//!
//! Tier 2 (`/service-sign`): the service drives a FROST co-sign with the cosigner — with the
//! WALLET OFFLINE — by playing the "user" in the cosigner's normal `SignStep1/SignStep2` against
//! the `{service, cosigner}` pairing actor (keyed by the eVTXO spk). The cosigner is authoritative
//! about WHAT gets signed: it rebuilds + signs only the cooperative-leaf sighash of a spend of
//! that one eVTXO, so this service can never obtain a `V` signature on the wallet's normal funds.

use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use axum::{
    extract::State,
    routing::{get, post},
    Json, Router,
};
use clap::Parser;
use rand::rngs::OsRng;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use threshold::auth::AuthSigner;
use threshold::commitment::SigningPackage;
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::nonce::{self, SigningCommitments};
use threshold::point::{base_mul, deserialize_compressed, points_equal, serialize_compressed};
use threshold::scalar::{scalar_from_bytes_allow_zero, scalar_to_bytes};
use threshold::signing;

/// Fixed test keypair secret — any non-zero scalar < n (high byte 0x42 ⇒ well below n).
/// The verifying key derived from it is the `service_vk` both wallet and cosigner refresh onto.
const SERVICE_SECRET: [u8; 32] = [0x42; 32];

#[derive(Parser)]
#[command(name = "contract-service", about = "Dummy always-online contract-signer service (e2e)")]
struct Args {
    #[arg(long, default_value = "7075")]
    port: u16,
}

#[derive(Default)]
struct Entry {
    user_half: Option<[u8; 32]>,
    cosigner_half: Option<[u8; 32]>,
    context: Option<Value>,
}

/// The service's spendable share for one contract eVTXO (built once both halves assemble).
#[derive(Clone)]
struct ServiceSigner {
    s_service: [u8; 32],
    pkp_json: String,
}

#[derive(Clone)]
struct AppState {
    service_vk: Vec<u8>,
    entries: Arc<Mutex<HashMap<String, Entry>>>,
    signers: Arc<Mutex<HashMap<String, ServiceSigner>>>,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();

    let secret = scalar_from_bytes_allow_zero(&SERVICE_SECRET).expect("valid service secret");
    let service_vk = serialize_compressed(&base_mul(&secret)).to_vec();
    println!("contract-service vk = {}", hex::encode(&service_vk));

    let state = AppState {
        service_vk,
        entries: Arc::new(Mutex::new(HashMap::new())),
        signers: Arc::new(Mutex::new(HashMap::new())),
    };

    let app = Router::new()
        .route("/info", get(info))
        .route("/assemble-contract-share", post(assemble))
        .route("/service-sign", post(service_sign))
        .with_state(state);

    let addr = format!("0.0.0.0:{}", args.port);
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .expect("bind contract-service");
    println!("contract-service listening on {}", addr);
    axum::serve(listener, app).await.expect("serve");
}

/// Publish the service's verifying key so the wallet/cosigner can target it (service_vk).
async fn info(State(st): State<AppState>) -> Json<Value> {
    Json(json!({ "service_vk": hex::encode(&st.service_vk) }))
}

/// Receive one refresh half (user or cosigner) keyed by the contract scriptPubKey. Once both
/// are in, sum them into the service's `V` share, verify `s_service·G` against the contract PKP's
/// verifying share for `service_id`, and stash the share for later `/service-sign`.
async fn assemble(State(st): State<AppState>, Json(body): Json<Value>) -> Json<Value> {
    let group_id = body["contract_group_id"].as_str().unwrap_or_default().to_string();
    let role = body["role"].as_str().unwrap_or_default();
    let half = match body["half_scalar"].as_str().and_then(decode32) {
        Some(h) => h,
        None => return Json(json!({ "ok": false, "error": "bad half_scalar" })),
    };

    let mut entries = st.entries.lock().unwrap();
    let entry = entries.entry(group_id.clone()).or_default();
    match role {
        "user" => entry.user_half = Some(half),
        "cosigner" => {
            entry.cosigner_half = Some(half);
            if !body["context"].is_null() {
                entry.context = Some(body["context"].clone());
            }
        }
        _ => return Json(json!({ "ok": false, "error": "bad role" })),
    }

    // Wait until both halves have arrived (deliveries race; either order is fine).
    let (Some(a), Some(b)) = (entry.user_half, entry.cosigner_half) else {
        return Json(json!({ "ok": true, "service_share_point": "" }));
    };

    let s_service = scalar_from_bytes_allow_zero(&a).unwrap() + scalar_from_bytes_allow_zero(&b).unwrap();
    let point = base_mul(&s_service);
    let point_hex = hex::encode(serialize_compressed(&point));

    let pkp_json = entry
        .context
        .as_ref()
        .and_then(|c| c["public_key_package_json"].as_str())
        .map(|s| s.to_string());

    // Best-effort correctness check: the summed share must match the PKP's service share.
    if let Some(pkp_json) = pkp_json.as_deref() {
        if let (Ok(pkp), Ok(service_id)) = (
            PublicKeyPackage::from_json(pkp_json),
            Identifier::derive(&st.service_vk),
        ) {
            match pkp.verifying_shares.get(&service_id) {
                Some(expected) if !points_equal(expected, &point) => {
                    return Json(json!({ "ok": false, "error": "service share mismatch vs PKP" }));
                }
                Some(_) => println!("[{}] share verified against PKP", short(&group_id)),
                None => println!("[{}] warn: service_id absent from PKP", short(&group_id)),
            }
        }
    }

    // Stash the spendable share for Tier 2 service-driven co-sign.
    if let Some(pkp_json) = pkp_json {
        st.signers.lock().unwrap().insert(
            group_id.clone(),
            ServiceSigner { s_service: scalar_to_bytes(&s_service), pkp_json },
        );
    }

    println!("[{}] assembled service share", short(&group_id));
    Json(json!({ "ok": true, "service_share_point": point_hex }))
}

/// Tier 2: co-sign a spend of the eVTXO `evtxo_script_pubkey` with the cosigner — NO wallet. The
/// service plays the "user" in the cosigner's `SignStep1/SignStep2` against the pairing actor
/// (group key = the spk), authenticating as `service_vk`. Returns the aggregated `V` signature.
/// Body: `{evtxo_script_pubkey, full_transaction, cosigner_base_url}`.
async fn service_sign(State(st): State<AppState>, Json(body): Json<Value>) -> Json<Value> {
    let spk_hex = body["evtxo_script_pubkey"].as_str().unwrap_or_default().to_string();
    let full_tx_hex = body["full_transaction"].as_str().unwrap_or_default().to_string();
    let cosigner_base = body["cosigner_base_url"]
        .as_str()
        .unwrap_or_default()
        .trim_end_matches('/')
        .to_string();
    // arkd two-leg mode: a specific leg sighash to sign + the ark_tx (leg 2). Empty ⇒ on-chain
    // single-leg mode (the cosigner overrides the message with leg 1).
    let message_hex = body["message"].as_str().unwrap_or_default().to_string();
    let ark_tx_hex = body["ark_tx"].as_str().unwrap_or_default().to_string();

    let signer = match st.signers.lock().unwrap().get(&spk_hex).cloned() {
        Some(s) => s,
        None => return Json(json!({ "ok": false, "error": "no service signer for that eVTXO" })),
    };

    match drive_cosign(&st, &spk_hex, &full_tx_hex, &message_hex, &ark_tx_hex, &cosigner_base, &signer).await {
        Ok((r_hex, z_hex, sighash_hex)) => {
            Json(json!({ "ok": true, "r_point": r_hex, "z_scalar": z_hex, "sighash": sighash_hex }))
        }
        Err(e) => Json(json!({ "ok": false, "error": e })),
    }
}

async fn drive_cosign(
    st: &AppState,
    spk_hex: &str,
    full_tx_hex: &str,
    message_hex: &str,
    ark_tx_hex: &str,
    cosigner_base: &str,
    sgn: &ServiceSigner,
) -> Result<(String, String, String), String> {
    let pkp = PublicKeyPackage::from_json(&sgn.pkp_json).map_err(|e| format!("bad pkp: {e:?}"))?;
    let service_id = Identifier::derive(&st.service_vk).map_err(|e| format!("derive id: {e:?}"))?;
    let s_scalar =
        scalar_from_bytes_allow_zero(&sgn.s_service).map_err(|e| format!("bad share: {e:?}"))?;
    let service_kp = KeyPackage {
        identifier: service_id,
        secret_share: s_scalar,
        verifying_share: base_mul(&s_scalar),
        verifying_key: pkp.verifying_key.clone(),
        min_signers: 2,
    };

    // Round 1: our nonce + commitment.
    let mut rng = OsRng;
    let nonce = nonce::new_nonce(&mut rng, &s_scalar);

    let auth = AuthSigner::from_secret_bytes(&SERVICE_SECRET).map_err(|e| format!("auth: {e:?}"))?;
    let vk_hex = hex::encode(&st.service_vk);
    let client = reqwest::Client::new();

    let ts1 = now_ms();
    let body1 = json!({
        "hiding_commitment": hex::encode(serialize_compressed(&nonce.commitments.hiding)),
        "binding_commitment": hex::encode(serialize_compressed(&nonce.commitments.binding)),
        "message_to_sign": message_hex,              // empty ⇒ cosigner overrides (on-chain leg 1);
                                                     // set ⇒ a specific arkd leg the cosigner VERIFIES
        "signature": hex::encode(auth.sign(&auth_message("SIGN_STEP1", ts1, &vk_hex))),
        "full_transaction": full_tx_hex,
        "ark_tx": ark_tx_hex,                         // leg 2 (ark_tx) for the arkd two-leg check
        "timestamp_ms": ts1,
        "script_path_spend": true,                   // cooperative leaf = raw V (no taproot tweak)
        "user_id": vk_hex,                            // the service's verifying share (auth)
    });
    let resp1 = post_json(&client, &format!("{cosigner_base}/api/u/{spk_hex}/sign/step1"), &body1)
        .await
        .map_err(|e| format!("step1: {e}"))?;

    // The cosigner is authoritative about the message: it returns the cooperative-leaf sighash.
    let message = hex::decode(resp1["message_to_sign"].as_str().unwrap_or_default())
        .map_err(|e| format!("message hex: {e}"))?;
    let mut commitments = BTreeMap::new();
    for (id_hex, c) in resp1["commitments"].as_object().ok_or("step1: no commitments")? {
        let id = Identifier::deserialize(&decode32(id_hex).ok_or("bad id hex")?)
            .map_err(|e| format!("id: {e:?}"))?;
        let hiding = deserialize_compressed(&decode33(c["hiding"].as_str().unwrap_or_default())?)
            .map_err(|e| format!("hiding pt: {e:?}"))?;
        let binding = deserialize_compressed(&decode33(c["binding"].as_str().unwrap_or_default())?)
            .map_err(|e| format!("binding pt: {e:?}"))?;
        commitments.insert(id, SigningCommitments { hiding, binding });
    }

    let package = SigningPackage::new(commitments, message.clone());
    let share = signing::sign(&package, &nonce, &service_kp).map_err(|e| format!("share: {e:?}"))?;

    // Round 2: hand our share over; the cosigner runs the gate, adds its share + aggregates.
    let ts2 = now_ms();
    let body2 = json!({
        "signature_share": hex::encode(scalar_to_bytes(&share.s)),
        "signature": hex::encode(auth.sign(&auth_message("SIGN_STEP2", ts2, &vk_hex))),
        "timestamp_ms": ts2,
        "user_id": vk_hex,
    });
    let resp2 = post_json(&client, &format!("{cosigner_base}/api/u/{spk_hex}/sign/step2"), &body2)
        .await
        .map_err(|e| format!("step2: {e}"))?;

    Ok((
        resp2["r_point"].as_str().unwrap_or_default().to_string(),
        resp2["z_scalar"].as_str().unwrap_or_default().to_string(),
        hex::encode(&message),
    ))
}

/// POST JSON, surfacing the response body text on a non-2xx (so gate/conditioning denials carry
/// their reason back to the caller).
async fn post_json(client: &reqwest::Client, url: &str, body: &Value) -> Result<Value, String> {
    let resp = client.post(url).json(body).send().await.map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        let status = resp.status();
        let text = resp.text().await.unwrap_or_default();
        return Err(format!("HTTP {status}: {text}"));
    }
    resp.json().await.map_err(|e| e.to_string())
}

fn auth_message(operation: &str, timestamp_ms: i64, user_id_hex: &str) -> Vec<u8> {
    let msg = format!("MPC_WALLET_AUTH_V1:{operation}:{timestamp_ms}:{user_id_hex}");
    Sha256::digest(msg.as_bytes()).to_vec()
}

fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64
}

fn decode32(h: &str) -> Option<[u8; 32]> {
    let v = hex::decode(h).ok()?;
    <[u8; 32]>::try_from(v.as_slice()).ok()
}

fn decode33(h: &str) -> Result<[u8; 33], String> {
    let v = hex::decode(h).map_err(|e| e.to_string())?;
    <[u8; 33]>::try_from(v.as_slice()).map_err(|_| "expected 33 bytes".to_string())
}

fn short(s: &str) -> &str {
    &s[..s.len().min(12)]
}
