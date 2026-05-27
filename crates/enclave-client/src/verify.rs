//! Pure attestation + signature verifiers.
//!
//! No HTTP, no async, no global state — callers fetch documents and
//! pass bytes in. The Rust side handles only the crypto-heavy work
//! (COSE_Sign1, X.509 chain, NIST P-384, BIP-340 Schnorr).

use crate::error::{Error, Result};
use crate::nitro::{self, AttestationDocument, NitroVerifyResult};
use sha2::{Digest, Sha256};

/// Verify a CBOR-encoded COSE_Sign1 attestation document against the
/// expected PCR0 and a freshly-generated nonce.
///
/// The caller is responsible for fetching the document
/// (`GET /enclave/attestation?nonce=<hex>`) and unwrapping any JSON
/// envelope (`{"document": "<b64>"}`) into raw bytes before calling.
pub fn verify_attestation_doc(
    doc_bytes: &[u8],
    expected_pcr0: &str,
    expected_nonce: &[u8],
) -> Result<NitroVerifyResult> {
    let result = nitro::verify_attestation_document(doc_bytes)?;

    let doc_nonce = result
        .document
        .nonce
        .as_ref()
        .ok_or(Error::MissingNonce)?;
    if doc_nonce.is_empty() {
        return Err(Error::MissingNonce);
    }
    if doc_nonce.as_slice() != expected_nonce {
        return Err(Error::NonceMismatch);
    }

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

/// Extract the `appKeyHash` from the attestation document's UserData,
/// validating the layout introduced by nitriding v1.4.2:
///
/// ```text
/// "sha256:" ++ tlsKeyHash(32) ++ ";" ++ "sha256:" ++ appKeyHash(32)
/// ```
///
/// Returns the 32-byte appKeyHash as a hex string. Callers fetch the
/// enclave's attestation pubkey separately (`GET /v1/enclave-info`)
/// and compare SHA256(pubkey_bytes) to this value — that comparison
/// is a single line of Dart and not worth a second FFI call.
pub fn extract_app_key_hash(document: &AttestationDocument) -> Result<String> {
    const HASH_PREFIX: &[u8] = b"sha256:";
    const HASH_SEP: &[u8] = b";";
    const TLS_HASH_END: usize = HASH_PREFIX.len() + 32;
    const APP_PREFIX_START: usize = TLS_HASH_END + HASH_SEP.len();
    const APP_HASH_START: usize = APP_PREFIX_START + HASH_PREFIX.len();
    const APP_HASH_END: usize = APP_HASH_START + 32;

    let user_data = match &document.user_data {
        Some(ud) if ud.len() >= APP_HASH_END => ud,
        _ => {
            return Err(Error::KeyBinding(
                "UserData too short for sha256:tls;sha256:app layout".into(),
            ))
        }
    };

    if &user_data[0..HASH_PREFIX.len()] != HASH_PREFIX {
        return Err(Error::KeyBinding("UserData missing leading 'sha256:'".into()));
    }
    if &user_data[TLS_HASH_END..APP_PREFIX_START] != HASH_SEP {
        return Err(Error::KeyBinding("UserData missing ';' separator".into()));
    }
    if &user_data[APP_PREFIX_START..APP_HASH_START] != HASH_PREFIX {
        return Err(Error::KeyBinding("UserData missing second 'sha256:'".into()));
    }

    let app_key_hash = &user_data[APP_HASH_START..APP_HASH_END];
    if app_key_hash.iter().all(|&b| b == 0) {
        return Err(Error::KeyBinding(
            "attestation key not yet registered (appKeyHash is all zeros)".into(),
        ));
    }

    Ok(hex::encode(app_key_hash))
}

/// Verify a BIP-340 Schnorr signature over `SHA256(body)` using the
/// hex-encoded compressed or x-only secp256k1 pubkey.
///
/// The server (`introspector-enclave`) signs `SHA256(response_body)`
/// using btcec's BIP-340 implementation, which treats the 32-byte hash
/// as the raw message — hence `verify_raw` here.
pub fn verify_schnorr_signature(
    body: &[u8],
    sig_hex: &str,
    attest_pubkey_hex: &str,
) -> Result<()> {
    let mut pubkey_bytes = hex::decode(attest_pubkey_hex)?;
    if pubkey_bytes.len() == 33 {
        pubkey_bytes = pubkey_bytes[1..].to_vec();
    }

    let verifying_key = k256::schnorr::VerifyingKey::from_bytes(&pubkey_bytes)
        .map_err(|e| Error::Other(format!("parse schnorr pubkey: {e}")))?;

    let sig_bytes = hex::decode(sig_hex)?;
    let signature = k256::schnorr::Signature::try_from(sig_bytes.as_slice())
        .map_err(|e| Error::Other(format!("parse schnorr signature: {e}")))?;

    let msg_hash = Sha256::digest(body);

    verifying_key
        .verify_raw(&msg_hash, &signature)
        .map_err(|_| Error::SignatureVerification)?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_schnorr_signature_verification() {
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

        assert!(verify_schnorr_signature(body, sig_hex, pubkey_hex).is_err());
    }

    #[test]
    fn test_schnorr_rejects_wrong_pubkey() {
        let body = b"{\"status\":\"ready\"}";
        let sig_hex = "f2f2c20eff91556cd3614fcf230a6e14b4d0574d3f91f8bf33b9acc76d61da40a691821f451e364385cbfed6ba6338e650f1de6fbca58c4a0cc7144185fa6eff";
        let pubkey_hex = "02aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

        assert!(verify_schnorr_signature(body, sig_hex, pubkey_hex).is_err());
    }
}
