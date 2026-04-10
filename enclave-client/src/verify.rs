//! Attestation verification, key binding, and Schnorr signature verification.

use crate::error::{Error, Result};
use crate::nitro::{self, AttestationDocument, NitroVerifyResult};
use crate::types::EnclaveInfoResponse;
use base64::Engine;
use sha2::{Digest, Sha256};

/// Fetch the attestation document from the enclave, verify it against the
/// AWS Nitro root certificate chain, check the nonce, and validate PCR0.
pub(crate) async fn fetch_and_verify_attestation(
    http_client: &reqwest::Client,
    base_url: &str,
    expected_pcr0: &str,
) -> Result<NitroVerifyResult> {
    // Generate a random nonce to prevent replay attacks.
    let nonce: [u8; 20] = rand::random();
    let nonce_hex = hex::encode(nonce);

    let url = format!(
        "{}/enclave/attestation?nonce={nonce_hex}",
        base_url.trim_end_matches('/')
    );

    let resp = http_client.get(&url).send().await?;
    let status = resp.status();

    if status != reqwest::StatusCode::OK {
        let body = resp.text().await.unwrap_or_default();
        return Err(Error::AttestationVerification(format!(
            "status {status}: {}",
            body.trim()
        )));
    }

    let payload = resp.text().await?;
    let payload = payload.trim();

    // The attestation may be returned as raw base64 or as JSON {"document":"..."}.
    let doc_b64 = if payload.starts_with('{') {
        #[derive(serde::Deserialize)]
        struct DocWrapper {
            #[serde(default)]
            document: String,
        }
        if let Ok(parsed) = serde_json::from_str::<DocWrapper>(payload) {
            if !parsed.document.is_empty() {
                parsed.document
            } else {
                payload.to_string()
            }
        } else {
            payload.to_string()
        }
    } else {
        payload.to_string()
    };

    let doc_bytes = base64::engine::general_purpose::STANDARD
        .decode(&doc_b64)
        .map_err(|e| Error::AttestationVerification(format!("decode attestation: {e}")))?;

    // Verify the COSE Sign1 document against the AWS Nitro root certs.
    let result = nitro::verify_attestation_document(&doc_bytes)?;

    // Verify the nonce to confirm freshness.
    let doc_nonce = result
        .document
        .nonce
        .as_ref()
        .ok_or(Error::MissingNonce)?;

    if doc_nonce.len() == 0 {
        return Err(Error::MissingNonce);
    }

    if *doc_nonce != nonce {
        return Err(Error::NonceMismatch);
    }

    // Verify PCR0 matches the expected enclave build measurement.
    let pcr0 = result
        .document
        .pcrs
        .get(&0)
        .ok_or(Error::MissingPCR0InDocument)?;

    if !hex::encode(pcr0).eq_ignore_ascii_case(expected_pcr0) {
        return Err(Error::PcrMismatch {
            index: 0,
            expected: expected_pcr0.to_string(),
            actual: hex::encode(pcr0),
        });
    }

    Ok(result)
}

/// Verify the enclave's ephemeral attestation key by checking that the
/// pubkey from /v1/enclave-info matches the appKeyHash in the attestation
/// document's UserData.
///
/// UserData format (nitriding): `[0x12, 0x20, tlsKeyHash:32] ++ [0x12, 0x20, appKeyHash:32]`
/// Total 68 bytes. appKeyHash is at bytes 36:68.
pub(crate) async fn verify_key_binding(
    http_client: &reqwest::Client,
    base_url: &str,
    document: &AttestationDocument,
) -> Result<String> {
    let user_data = match &document.user_data {
        Some(ud) if ud.len() >= 68 => ud,
        _ => return Ok(String::new()), // UserData too short, key binding not supported
    };

    // Check multihash prefix at offset 34.
    if user_data[34] != 0x12 || user_data[35] != 0x20 {
        return Err(Error::KeyBinding(format!(
            "UserData missing multihash prefix at offset 34 (got {:02x} {:02x})",
            user_data[34], user_data[35]
        )));
    }

    let app_key_hash = &user_data[36..68];

    // Check if appKeyHash is all zeros (key not yet registered).
    if app_key_hash.iter().all(|&b| b == 0) {
        return Err(Error::KeyBinding(
            "attestation key not yet registered (appKeyHash is all zeros)".into(),
        ));
    }

    // Fetch the attestation pubkey from the enclave.
    let info = fetch_enclave_info(http_client, base_url).await?;

    if info.attestation_pubkey.is_empty() {
        return Err(Error::KeyBinding(
            "enclave reports no attestation pubkey but appKeyHash is set".into(),
        ));
    }

    let attest_pubkey_bytes = hex::decode(&info.attestation_pubkey)?;

    // Verify that SHA256(pubkey) matches the appKeyHash from attestation.
    let expected_hash = Sha256::digest(&attest_pubkey_bytes);

    if &expected_hash[..] != app_key_hash {
        return Err(Error::KeyBinding(format!(
            "appKeyHash mismatch: expected SHA256({}) = {}, got {}",
            info.attestation_pubkey,
            hex::encode(expected_hash),
            hex::encode(app_key_hash)
        )));
    }

    Ok(info.attestation_pubkey)
}

/// Verify a BIP-340 Schnorr signature over SHA256(body) using the
/// hex-encoded compressed secp256k1 pubkey.
pub(crate) fn verify_schnorr_signature(
    body: &[u8],
    sig_hex: &str,
    attest_pubkey_hex: &str,
) -> Result<()> {
    let mut pubkey_bytes = hex::decode(attest_pubkey_hex)?;

    // The attestation pubkey is compressed (33 bytes). Extract x-only (32 bytes)
    // by dropping the prefix byte for Schnorr verification.
    if pubkey_bytes.len() == 33 {
        pubkey_bytes = pubkey_bytes[1..].to_vec();
    }

    let verifying_key = k256::schnorr::VerifyingKey::from_bytes(&pubkey_bytes)
        .map_err(|e| Error::Other(format!("parse schnorr pubkey: {e}")))?;

    let sig_bytes = hex::decode(sig_hex)?;
    let signature = k256::schnorr::Signature::try_from(sig_bytes.as_slice())
        .map_err(|e| Error::Other(format!("parse schnorr signature: {e}")))?;

    let msg_hash = Sha256::digest(body);

    // The Go btcec library passes the SHA256 hash as the raw 32-byte message
    // to BIP-340 Schnorr verify. Use verify_raw which treats the input as
    // the pre-hashed message (BIP-340 then applies tagged_hash("BIP0340/challenge", ...)).
    verifying_key
        .verify_raw(&msg_hash, &signature)
        .map_err(|_| Error::SignatureVerification)?;

    Ok(())
}

/// Fetch the /v1/enclave-info endpoint.
pub(crate) async fn fetch_enclave_info(
    http_client: &reqwest::Client,
    base_url: &str,
) -> Result<EnclaveInfoResponse> {
    let url = format!("{}/v1/enclave-info", base_url.trim_end_matches('/'));

    let resp = http_client.get(&url).send().await?;
    let status = resp.status();

    if status != reqwest::StatusCode::OK {
        let body = resp.text().await.unwrap_or_default();
        return Err(Error::Other(format!(
            "enclave-info status {status}: {}",
            body.trim()
        )));
    }

    let body = resp.bytes().await?;
    let info: EnclaveInfoResponse = serde_json::from_slice(&body)?;

    if !info.error.is_empty() {
        return Err(Error::Other(format!("enclave init error: {}", info.error)));
    }

    Ok(info)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_schnorr_signature_verification() {
        // Real test vector captured from a running enclave.
        // Note: response body includes trailing newline.
        let body = b"{\"status\":\"ready\"}\n";
        let sig_hex = "f2f2c20eff91556cd3614fcf230a6e14b4d0574d3f91f8bf33b9acc76d61da40a691821f451e364385cbfed6ba6338e650f1de6fbca58c4a0cc7144185fa6eff";
        let pubkey_hex = "028d0bcf2b3384781e74e647351c01c0852775b59f063cde314d67328927d20dd0";

        let result = verify_schnorr_signature(body, sig_hex, pubkey_hex);
        assert!(result.is_ok(), "Schnorr verification failed: {result:?}");
    }

    #[test]
    fn test_schnorr_rejects_wrong_body() {
        let body = b"{\"status\":\"tampered\"}";
        let sig_hex = "f2f2c20eff91556cd3614fcf230a6e14b4d0574d3f91f8bf33b9acc76d61da40a691821f451e364385cbfed6ba6338e650f1de6fbca58c4a0cc7144185fa6eff";
        let pubkey_hex = "028d0bcf2b3384781e74e647351c01c0852775b59f063cde314d67328927d20dd0";

        let result = verify_schnorr_signature(body, sig_hex, pubkey_hex);
        assert!(result.is_err());
    }

    #[test]
    fn test_schnorr_rejects_wrong_pubkey() {
        let body = b"{\"status\":\"ready\"}";
        let sig_hex = "f2f2c20eff91556cd3614fcf230a6e14b4d0574d3f91f8bf33b9acc76d61da40a691821f451e364385cbfed6ba6338e650f1de6fbca58c4a0cc7144185fa6eff";
        // Completely different pubkey (different x-coordinate).
        let pubkey_hex = "02aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

        let result = verify_schnorr_signature(body, sig_hex, pubkey_hex);
        assert!(result.is_err());
    }
}

