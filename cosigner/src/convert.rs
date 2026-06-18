//! Hex encoding/decoding and JSON parsing helpers shared across modules.

use threshold::identifier::Identifier;
use threshold::scalar::scalar_from_bytes;

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
