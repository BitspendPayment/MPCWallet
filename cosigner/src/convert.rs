//! Hex encoding/decoding and JSON parsing helpers shared across modules.

use std::collections::BTreeMap;

use threshold::dkg::{Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::scalar::{scalar_from_bytes, scalar_from_bytes_allow_zero};

use crate::exports::component::threshold::types::ThresholdError;

pub fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

pub fn hex_decode(s: &str) -> Result<Vec<u8>, String> {
    if s.len() % 2 != 0 {
        return Err("odd hex length".into());
    }
    let mut out = Vec::with_capacity(s.len() / 2);
    for i in (0..s.len()).step_by(2) {
        let byte =
            u8::from_str_radix(&s[i..i + 2], 16).map_err(|e| format!("bad hex at {i}: {e}"))?;
        out.push(byte);
    }
    Ok(out)
}

pub fn hex_decode_32(s: &str) -> Result<[u8; 32], String> {
    let bytes = hex_decode(s)?;
    if bytes.len() != 32 {
        return Err(format!("expected 32 bytes, got {}", bytes.len()));
    }
    let mut out = [0u8; 32];
    out.copy_from_slice(&bytes);
    Ok(out)
}

pub fn hex_decode_33(s: &str) -> Result<[u8; 33], String> {
    let bytes = hex_decode(s)?;
    if bytes.len() != 33 {
        return Err(format!("expected 33 bytes, got {}", bytes.len()));
    }
    let mut out = [0u8; 33];
    out.copy_from_slice(&bytes);
    Ok(out)
}

pub fn hex_decode_64(s: &str) -> Result<[u8; 64], String> {
    let bytes = hex_decode(s)?;
    if bytes.len() != 64 {
        return Err(format!("expected 64 bytes, got {}", bytes.len()));
    }
    let mut out = [0u8; 64];
    out.copy_from_slice(&bytes);
    Ok(out)
}

pub fn parse_identifier_hex(hex: &str) -> Result<Identifier, String> {
    let bytes = hex_decode_32(hex)?;
    Identifier::deserialize(&bytes).map_err(|e| format!("bad identifier: {e}"))
}

pub fn parse_scalar_hex(hex: &str) -> Result<k256::Scalar, String> {
    let bytes = hex_decode_32(hex)?;
    scalar_from_bytes(&bytes).map_err(|e| format!("bad scalar: {e}"))
}

pub fn parse_scalar_hex_allow_zero(hex: &str) -> Result<k256::Scalar, String> {
    let bytes = hex_decode_32(hex)?;
    scalar_from_bytes_allow_zero(&bytes).map_err(|e| format!("bad scalar: {e}"))
}

pub fn parse_coefficients_json(json_str: &str) -> Result<Vec<k256::Scalar>, String> {
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("bad JSON: {e}"))?;
    let arr = v.as_array().ok_or("coefficients must be array")?;
    let mut coefficients = Vec::new();
    for item in arr {
        let hex = item.as_str().ok_or("coefficient must be hex string")?;
        coefficients.push(parse_scalar_hex(hex)?);
    }
    Ok(coefficients)
}

pub fn parse_round1_pkgs_json(
    json_str: &str,
) -> Result<BTreeMap<Identifier, Round1Package>, String> {
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("bad JSON: {e}"))?;
    let obj = v.as_object().ok_or("expected JSON object")?;
    let mut map = BTreeMap::new();
    for (id_hex, pkg_val) in obj {
        let id = parse_identifier_hex(id_hex)?;
        let pkg =
            Round1Package::from_json_value(pkg_val).map_err(|e| format!("bad R1 pkg: {e}"))?;
        map.insert(id, pkg);
    }
    Ok(map)
}

pub fn parse_round2_pkgs_json(
    json_str: &str,
) -> Result<BTreeMap<Identifier, Round2Package>, String> {
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("bad JSON: {e}"))?;
    let obj = v.as_object().ok_or("expected JSON object")?;
    let mut map = BTreeMap::new();
    for (id_hex, pkg_val) in obj {
        let id = parse_identifier_hex(id_hex)?;
        let pkg =
            Round2Package::from_json_value(pkg_val).map_err(|e| format!("bad R2 pkg: {e}"))?;
        map.insert(id, pkg);
    }
    Ok(map)
}

pub fn parse_identifier_list_json(json_str: &str) -> Result<Vec<Identifier>, String> {
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("bad JSON: {e}"))?;
    let arr = v.as_array().ok_or("expected JSON array")?;
    let mut ids = Vec::new();
    for item in arr {
        let hex = item.as_str().ok_or("expected hex string in array")?;
        ids.push(parse_identifier_hex(hex)?);
    }
    Ok(ids)
}

pub fn serialize_round1_pkg(pkg: &Round1Package) -> String {
    serde_json::to_string(&pkg.to_json_value()).unwrap_or_default()
}

pub fn serialize_round2_pkgs(pkgs: &BTreeMap<Identifier, Round2Package>) -> String {
    let mut obj = serde_json::Map::new();
    for (id, pkg) in pkgs {
        let id_hex = hex_encode(&id.serialize());
        obj.insert(id_hex, pkg.to_json_value());
    }
    serde_json::to_string(&serde_json::Value::Object(obj)).unwrap_or_default()
}

pub fn serialize_dkg_result(
    kp: &threshold::keys::KeyPackage,
    pkp: &threshold::keys::PublicKeyPackage,
) -> (String, String) {
    (kp.to_json(), pkp.to_json())
}

/// Convert a string error into a ThresholdError variant.
pub fn to_crypto_error(e: impl std::fmt::Display) -> ThresholdError {
    ThresholdError::CryptoError(e.to_string())
}

pub fn to_input_error(e: impl std::fmt::Display) -> ThresholdError {
    ThresholdError::InvalidInput(e.to_string())
}

pub fn to_serde_error(e: impl std::fmt::Display) -> ThresholdError {
    ThresholdError::SerializationError(e.to_string())
}
