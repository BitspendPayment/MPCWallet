//! FROST signing operations.

use std::collections::BTreeMap;

use rand::rngs::OsRng;
use threshold::commitment::SigningPackage;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::nonce::{self, SigningCommitments, SigningNonce};
use threshold::point;
use threshold::scalar::scalar_to_bytes;
use threshold::signing;

use crate::exports::component::threshold::types::*;
use crate::convert;

/// Generate a fresh single-use signing nonce; returns its commitments JSON plus the
/// secret nonce (the caller — the session — stores the nonce for `frost_sign`).
pub fn new_nonce(secret_hex: String) -> Result<(String, SigningNonce), ThresholdError> {
    let secret = convert::parse_scalar_hex(&secret_hex).map_err(convert::to_input_error)?;

    let mut rng = OsRng;
    let nonce = nonce::new_nonce(&mut rng, &secret);

    let hiding = convert::hex_encode(&point::serialize_compressed(&nonce.commitments.hiding));
    let binding = convert::hex_encode(&point::serialize_compressed(&nonce.commitments.binding));

    let commitments_json = serde_json::json!({
        "hiding": hiding,
        "binding": binding,
    })
    .to_string();

    Ok((commitments_json, nonce))
}

pub fn frost_sign(
    signing_package_json: String,
    nonce: &SigningNonce,
    key_package_json: String,
) -> Result<String, ThresholdError> {
    // Contract gate (host capability): the host evaluates the contract bound to
    // the spend being signed, in its own sandbox, over the tx it holds for this
    // session. Refuse to produce a share if it denies.
    crate::component::threshold::contract_gate::enforce().map_err(ThresholdError::CryptoError)?;

    let signing_pkg =
        parse_signing_package_json(&signing_package_json).map_err(convert::to_serde_error)?;
    let kp =
        KeyPackage::from_json(&key_package_json).map_err(convert::to_serde_error)?;

    let share =
        signing::sign(&signing_pkg, nonce, &kp).map_err(convert::to_crypto_error)?;

    Ok(convert::hex_encode(&scalar_to_bytes(&share.s)))
}

pub fn frost_aggregate(
    signing_package_json: String,
    shares_json: String,
    public_key_package_json: String,
) -> Result<String, ThresholdError> {
    let signing_pkg =
        parse_signing_package_json(&signing_package_json).map_err(convert::to_serde_error)?;

    let shares_val: serde_json::Value =
        serde_json::from_str(&shares_json).map_err(|e| convert::to_serde_error(e))?;
    let shares_obj = shares_val
        .as_object()
        .ok_or_else(|| ThresholdError::SerializationError("expected shares object".into()))?;
    let mut shares = BTreeMap::new();
    for (id_hex, share_val) in shares_obj {
        let id = convert::parse_identifier_hex(id_hex).map_err(convert::to_input_error)?;
        let share_hex = share_val
            .as_str()
            .ok_or_else(|| ThresholdError::SerializationError("share must be hex string".into()))?;
        let s = convert::parse_scalar_hex(share_hex).map_err(convert::to_input_error)?;
        shares.insert(id, signing::SignatureShare { s });
    }

    let pkp = PublicKeyPackage::from_json(&public_key_package_json)
        .map_err(convert::to_serde_error)?;

    let signature =
        signing::aggregate(&signing_pkg, &shares, &pkp).map_err(convert::to_crypto_error)?;

    let r_hex = convert::hex_encode(&point::serialize_compressed(&signature.r));
    let z_hex = convert::hex_encode(&scalar_to_bytes(&signature.z));

    let data = serde_json::json!({
        "R": r_hex,
        "Z": z_hex,
    })
    .to_string();

    Ok(data)
}

// ---------------------------------------------------------------------------
// Signing package parser (same format as FFI)
// ---------------------------------------------------------------------------

fn parse_signing_package_json(json_str: &str) -> Result<SigningPackage, String> {
    let v: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("bad JSON: {e}"))?;

    let comms_obj = v["commitments"]
        .as_object()
        .ok_or("expected commitments object")?;
    let mut commitments = BTreeMap::new();
    for (id_hex, comm_val) in comms_obj {
        let id = convert::parse_identifier_hex(id_hex)?;
        let hiding_hex = comm_val["hiding"].as_str().ok_or("expected hiding hex")?;
        let binding_hex = comm_val["binding"].as_str().ok_or("expected binding hex")?;

        let hiding_bytes = convert::hex_decode_33(hiding_hex)?;
        let binding_bytes = convert::hex_decode_33(binding_hex)?;

        let hiding = point::deserialize_compressed(&hiding_bytes)
            .map_err(|e| format!("bad hiding point: {e}"))?;
        let binding = point::deserialize_compressed(&binding_bytes)
            .map_err(|e| format!("bad binding point: {e}"))?;

        commitments.insert(id, SigningCommitments { binding, hiding });
    }

    let message_hex = v["message"].as_str().ok_or("expected message hex")?;
    let message = convert::hex_decode(message_hex)?;

    Ok(SigningPackage::new(commitments, message))
}
