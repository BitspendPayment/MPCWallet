//! Utility operations: identifiers, scalars, points, polynomials.

use rand::rngs::OsRng;
use threshold::identifier::Identifier;
use threshold::point;
use threshold::polynomial;
use threshold::random;
use threshold::scalar::scalar_to_bytes;

use crate::exports::component::threshold::types::ThresholdError;
use crate::convert;

pub fn identifier_derive(message: Vec<u8>) -> Result<String, ThresholdError> {
    let id = Identifier::derive(&message).map_err(convert::to_crypto_error)?;
    Ok(convert::hex_encode(&id.serialize()))
}

pub fn identifier_from_bigint(hex_str: String) -> Result<String, ThresholdError> {
    let bytes = convert::hex_decode_32(&hex_str).map_err(convert::to_input_error)?;
    let id = Identifier::deserialize(&bytes).map_err(convert::to_input_error)?;
    Ok(convert::hex_encode(&id.serialize()))
}

pub fn generate_coefficients(count: u32, seed: Vec<u8>) -> Result<String, ThresholdError> {
    let coeffs = if !seed.is_empty() {
        random::generate_coefficients_seeded(count as usize, &seed)
    } else {
        let mut rng = OsRng;
        random::generate_coefficients(count as usize, &mut rng)
    };

    let arr: Vec<serde_json::Value> = coeffs
        .iter()
        .map(|c| serde_json::Value::String(convert::hex_encode(&scalar_to_bytes(c))))
        .collect();
    Ok(serde_json::Value::Array(arr).to_string())
}

pub fn evaluate_polynomial(
    id_hex: String,
    coefficients_json: String,
) -> Result<String, ThresholdError> {
    let id_bytes = convert::hex_decode_32(&id_hex).map_err(convert::to_input_error)?;
    let id = Identifier::deserialize(&id_bytes).map_err(convert::to_input_error)?;

    let v: serde_json::Value =
        serde_json::from_str(&coefficients_json).map_err(|e| convert::to_serde_error(e))?;
    let arr = v
        .as_array()
        .ok_or_else(|| ThresholdError::SerializationError("expected JSON array".into()))?;

    let mut coeffs = Vec::new();
    for item in arr {
        let hex = item.as_str().ok_or_else(|| {
            ThresholdError::SerializationError("coefficient must be hex string".into())
        })?;
        coeffs.push(convert::parse_scalar_hex_allow_zero(hex).map_err(convert::to_input_error)?);
    }

    let result = polynomial::evaluate_polynomial(&id, &coeffs);
    Ok(convert::hex_encode(&scalar_to_bytes(&result)))
}

pub fn mod_n_random() -> Result<String, ThresholdError> {
    let mut rng = OsRng;
    let s = random::mod_n_random(&mut rng);
    Ok(convert::hex_encode(&scalar_to_bytes(&s)))
}

pub fn elem_base_mul(scalar_hex: String) -> Result<String, ThresholdError> {
    let scalar = convert::parse_scalar_hex(&scalar_hex).map_err(convert::to_input_error)?;
    let p = point::base_mul(&scalar);
    Ok(convert::hex_encode(&point::serialize_compressed(&p)))
}
