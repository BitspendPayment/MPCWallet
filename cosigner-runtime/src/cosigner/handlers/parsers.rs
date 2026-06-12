//! Pure JSON / hex parsing helpers used across handlers. All static — no
//! `&self`, no shared services.

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use tonic::Status;

use crate::policy::PolicyState;

pub fn user_id_hex(user_id: &[u8]) -> String {
    hex::encode(user_id)
}

pub fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64
}

pub fn parse_round2_result(json_str: &str) -> Result<HashMap<String, String>, Status> {
    let v: serde_json::Value = serde_json::from_str(json_str)
        .map_err(|e| Status::internal(format!("bad round2 result: {e}")))?;
    let obj = v
        .as_object()
        .ok_or_else(|| Status::internal("expected round2 packages object"))?;
    let mut result = HashMap::new();
    for (k, v) in obj {
        result.insert(k.clone(), v.to_string());
    }
    Ok(result)
}

pub fn extract_secret_share(kp_json: &str) -> Result<String, Status> {
    let v: serde_json::Value = serde_json::from_str(kp_json)
        .map_err(|e| Status::internal(format!("bad key package JSON: {e}")))?;
    v["secretShare"]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| Status::internal("missing secretShare in key package"))
}

pub fn extract_identifier(kp_json: &str) -> Result<String, Status> {
    let v: serde_json::Value = serde_json::from_str(kp_json)
        .map_err(|e| Status::internal(format!("bad key package JSON: {e}")))?;
    v["identifier"]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| Status::internal("missing identifier in key package"))
}

pub fn extract_verifying_key(pkp_json: &str) -> Result<String, Status> {
    let v: serde_json::Value = serde_json::from_str(pkp_json)
        .map_err(|e| Status::internal(format!("bad public key package JSON: {e}")))?;
    v["verifyingKey"]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| Status::internal("missing verifyingKey in public key package"))
}

pub fn extract_verifying_share(pkp_json: &str, id_hex: &str) -> Result<String, Status> {
    let v: serde_json::Value = serde_json::from_str(pkp_json)
        .map_err(|e| Status::internal(format!("bad public key package JSON: {e}")))?;
    v["verifyingShares"][id_hex]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| Status::internal(format!("missing verifying share for {id_hex}")))
}

/// Build the signing package JSON consumed by `frost_sign` / `frost_aggregate`.
/// `commitments_json` is `{"id": "comms_json_str", ...}` (string-wrapped values).
pub fn build_signing_package_json(
    commitments_json: &str,
    message_hex: &str,
) -> Result<String, Status> {
    let comms_val: serde_json::Value = serde_json::from_str(commitments_json)
        .map_err(|e| Status::internal(format!("bad commitments JSON: {e}")))?;
    let comms_obj = comms_val
        .as_object()
        .ok_or_else(|| Status::internal("commitments not an object"))?;

    let mut parsed_comms = serde_json::Map::new();
    for (id, val) in comms_obj {
        let inner_json = val
            .as_str()
            .ok_or_else(|| Status::internal("commitment value not a string"))?;
        let parsed: serde_json::Value = serde_json::from_str(inner_json)
            .map_err(|e| Status::internal(format!("bad inner commitment JSON: {e}")))?;
        parsed_comms.insert(id.clone(), parsed);
    }
    let pkg = serde_json::json!({
        "commitments": serde_json::Value::Object(parsed_comms),
        "message": message_hex,
    });
    Ok(pkg.to_string())
}

/// Resolve the `(key_package_json, public_key_package_json)` a signing session
/// uses for `policy_id`, consistently across sign_step1 and sign_step2:
/// - `"evtxo:<spk_hex>"` -> the V′ `EvtxoPolicy` for that eVTXO (contract-gated),
/// - empty / unknown -> the normal policy.
pub fn resolve_signing_key(policy_state: &PolicyState, policy_id: &str) -> (String, String) {
    if let Some(spk_hex) = policy_id.strip_prefix("evtxo:") {
        if let Some(ep) = policy_state.evtxo_policies.get(spk_hex) {
            return (
                ep.key_package_json.clone(),
                ep.public_key_package_json.clone(),
            );
        }
    }
    (
        policy_state.normal_policy.key_package_json.clone(),
        policy_state.normal_policy.public_key_package_json.clone(),
    )
}

/// Parse a JSON object of string-wrapped values into a HashMap.
pub fn parse_json_string_map(json: &str) -> Result<HashMap<String, String>, Status> {
    let v: serde_json::Value = serde_json::from_str(json)
        .map_err(|e| Status::internal(format!("bad JSON: {e}")))?;
    let obj = v
        .as_object()
        .ok_or_else(|| Status::internal("expected JSON object"))?;
    let mut result = HashMap::new();
    for (k, v) in obj {
        let s = v
            .as_str()
            .map(|s| s.to_string())
            .unwrap_or_else(|| v.to_string());
        result.insert(k.clone(), s);
    }
    Ok(result)
}
