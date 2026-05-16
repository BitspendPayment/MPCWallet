//! JSON / hex conversion helpers for the native DKG path. Mirrors the
//! `cosigner/src/convert.rs` shapes so wire format stays identical to the
//! WASM-mediated path. Each helper returns `Result<_, Status>` so callers
//! can `?` directly into a handler.

use std::collections::BTreeMap;

use tonic::Status;

use threshold::dkg::{Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::scalar::scalar_from_bytes;

fn hex_decode(s: &str) -> Result<Vec<u8>, Status> {
    hex::decode(s).map_err(|e| Status::internal(format!("bad hex: {e}")))
}

fn hex_decode_32(s: &str) -> Result<[u8; 32], Status> {
    let bytes = hex_decode(s)?;
    if bytes.len() != 32 {
        return Err(Status::internal(format!(
            "expected 32 bytes, got {}",
            bytes.len()
        )));
    }
    let mut out = [0u8; 32];
    out.copy_from_slice(&bytes);
    Ok(out)
}

pub fn parse_identifier_hex(hex: &str) -> Result<Identifier, Status> {
    let bytes = hex_decode_32(hex)?;
    Identifier::deserialize(&bytes).map_err(|e| Status::internal(format!("bad identifier: {e}")))
}

pub fn parse_scalar_hex(hex: &str) -> Result<k256::Scalar, Status> {
    let bytes = hex_decode_32(hex)?;
    scalar_from_bytes(&bytes).map_err(|e| Status::internal(format!("bad scalar: {e}")))
}

pub fn parse_round1_pkgs_json(
    json_str: &str,
) -> Result<BTreeMap<Identifier, Round1Package>, Status> {
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| Status::internal(format!("bad JSON: {e}")))?;
    let obj = v
        .as_object()
        .ok_or_else(|| Status::internal("expected JSON object"))?;
    let mut map = BTreeMap::new();
    for (id_hex, pkg_val) in obj {
        let id = parse_identifier_hex(id_hex)?;
        let pkg = Round1Package::from_json_value(pkg_val)
            .map_err(|e| Status::internal(format!("bad R1 pkg: {e}")))?;
        map.insert(id, pkg);
    }
    Ok(map)
}

pub fn parse_round2_pkgs_json(
    json_str: &str,
) -> Result<BTreeMap<Identifier, Round2Package>, Status> {
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| Status::internal(format!("bad JSON: {e}")))?;
    let obj = v
        .as_object()
        .ok_or_else(|| Status::internal("expected JSON object"))?;
    let mut map = BTreeMap::new();
    for (id_hex, pkg_val) in obj {
        let id = parse_identifier_hex(id_hex)?;
        let pkg = Round2Package::from_json_value(pkg_val)
            .map_err(|e| Status::internal(format!("bad R2 pkg: {e}")))?;
        map.insert(id, pkg);
    }
    Ok(map)
}

pub fn parse_identifier_list_json(json_str: &str) -> Result<Vec<Identifier>, Status> {
    if json_str.is_empty() || json_str == "[]" {
        return Ok(Vec::new());
    }
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| Status::internal(format!("bad JSON: {e}")))?;
    let arr = v
        .as_array()
        .ok_or_else(|| Status::internal("expected JSON array"))?;
    let mut ids = Vec::new();
    for item in arr {
        let hex = item
            .as_str()
            .ok_or_else(|| Status::internal("expected hex string in array"))?;
        ids.push(parse_identifier_hex(hex)?);
    }
    Ok(ids)
}

pub fn serialize_round2_pkgs(pkgs: &BTreeMap<Identifier, Round2Package>) -> String {
    let mut obj = serde_json::Map::new();
    for (id, pkg) in pkgs {
        let id_hex = hex::encode(id.serialize());
        obj.insert(id_hex, pkg.to_json_value());
    }
    serde_json::to_string(&serde_json::Value::Object(obj)).unwrap_or_default()
}
