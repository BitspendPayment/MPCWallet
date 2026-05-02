//! AWS Nitro Enclave attestation document verification.
//!
//! Implements COSE Sign1 parsing and certificate chain validation
//! equivalent to the Go `nitrite` library.

use crate::error::{Error, Result};
use der::{Decode, Encode};
use p384::ecdsa::{Signature as P384Signature, VerifyingKey as P384VerifyingKey};
use sha2::{Digest, Sha384};
use std::collections::HashMap;
use x509_cert::Certificate;

/// AWS Nitro Enclaves root certificate (PEM).
/// https://aws-nitro-enclaves.amazonaws.com/AWS_NitroEnclaves_Root-G1.zip
const AWS_NITRO_ROOT_PEM: &str = "-----BEGIN CERTIFICATE-----\n\
MIICETCCAZagAwIBAgIRAPkxdWgbkK/hHUbMtOTn+FYwCgYIKoZIzj0EAwMwSTEL\n\
MAkGA1UEBhMCVVMxDzANBgNVBAoMBkFtYXpvbjEMMAoGA1UECwwDQVdTMRswGQYD\n\
VQQDDBJhd3Mubml0cm8tZW5jbGF2ZXMwHhcNMTkxMDI4MTMyODA1WhcNNDkxMDI4\n\
MTQyODA1WjBJMQswCQYDVQQGEwJVUzEPMA0GA1UECgwGQW1hem9uMQwwCgYDVQQL\n\
DANBV1MxGzAZBgNVBAMMEmF3cy5uaXRyby1lbmNsYXZlczB2MBAGByqGSM49AgEG\n\
BSuBBAAiA2IABPwCVOumCMHzaHDimtqQvkY4MpJzbolL//Zy2YlES1BR5TSksfbb\n\
48C8WBoyt7F2Bw7eEtaaP+ohG2bnUs990d0JX28TcPQXCEPZ3BABIeTPYwEoCWZE\n\
h8l5YoQwTcU/9KNCMEAwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUkCW1DdkF\n\
R+eWw5b6cp3PmanfS5YwDgYDVR0PAQH/BAQDAgGGMAoGCCqGSM49BAMDA2kAMGYC\n\
MQCjfy+Rocm9Xue4YnwWmNJVA44fA0P5W2OpYow9OYCVRaEevL8uO1XYru5xtMPW\n\
rfMCMQCi85sWBbJwKKXdS6BptQFuZbT73o/gBh1qUxl/nNr12UO8Yfwr6wPLb+6N\n\
IwLz3/Y=\n\
-----END CERTIFICATE-----";

/// Attestation document fields from the CBOR payload.
#[derive(Debug)]
pub(crate) struct AttestationDocument {
    pub module_id: String,
    pub timestamp: u64,
    pub digest: String,
    pub pcrs: HashMap<u32, Vec<u8>>,
    pub certificate: Vec<u8>,
    pub cabundle: Vec<Vec<u8>>,
    pub public_key: Option<Vec<u8>>,
    pub user_data: Option<Vec<u8>>,
    pub nonce: Option<Vec<u8>>,
}

/// Result of verifying an attestation document.
#[allow(dead_code)]
pub(crate) struct NitroVerifyResult {
    pub document: AttestationDocument,
    pub signature_ok: bool,
}

/// Verify a CBOR-encoded COSE Sign1 attestation document.
pub(crate) fn verify_attestation_document(data: &[u8]) -> Result<NitroVerifyResult> {
    // 1. CBOR-decode as COSE Sign1 array: [protected, unprotected, payload, signature]
    let cose_array: ciborium::Value =
        ciborium::from_reader(data).map_err(|e| Error::Cbor(format!("decode COSE: {e}")))?;

    let arr = match &cose_array {
        ciborium::Value::Tag(_tag, inner) => match inner.as_ref() {
            ciborium::Value::Array(a) => a,
            _ => return Err(Error::Cose("not a COSE Sign1 array".into())),
        },
        ciborium::Value::Array(a) => a,
        _ => return Err(Error::Cose("not a COSE Sign1 array".into())),
    };

    if arr.len() != 4 {
        return Err(Error::Cose(format!(
            "COSE Sign1 array has {} elements, expected 4",
            arr.len()
        )));
    }

    let protected = extract_bytes(&arr[0], "protected")?;
    let payload = extract_bytes(&arr[2], "payload")?;
    let signature = extract_bytes(&arr[3], "signature")?;

    if protected.is_empty() {
        return Err(Error::Cose("empty protected section".into()));
    }
    if payload.is_empty() {
        return Err(Error::Cose("empty payload section".into()));
    }
    if signature.is_empty() {
        return Err(Error::Cose("empty signature section".into()));
    }

    // 2. Verify algorithm is ES384 (COSE alg -35).
    verify_algorithm(&protected)?;

    // 3. CBOR-decode payload into AttestationDocument.
    let doc = parse_attestation_document(&payload)?;

    // 4. Validate mandatory fields.
    validate_document(&doc)?;

    // 5. Verify certificate chain.
    let leaf_pubkey = verify_cert_chain(&doc.certificate, &doc.cabundle)?;

    // 6. Build COSE Signature1 structure and verify ECDSA-P384 signature.
    let sig_ok = verify_cose_signature(&protected, &payload, &signature, &leaf_pubkey);

    if !sig_ok {
        return Err(Error::AttestationVerification(
            "COSE signature verification failed".into(),
        ));
    }

    Ok(NitroVerifyResult {
        document: doc,
        signature_ok: sig_ok,
    })
}

/// Extract bytes from a CBOR value (may be Bytes or Array).
fn extract_bytes(val: &ciborium::Value, name: &str) -> Result<Vec<u8>> {
    match val {
        ciborium::Value::Bytes(b) => Ok(b.clone()),
        _ => Err(Error::Cbor(format!("{name} is not bytes"))),
    }
}

/// Verify the COSE protected header algorithm is ES384 (-35).
fn verify_algorithm(protected: &[u8]) -> Result<()> {
    let header: ciborium::Value =
        ciborium::from_reader(protected).map_err(|e| Error::Cbor(format!("decode header: {e}")))?;

    let map = match header {
        ciborium::Value::Map(m) => m,
        _ => return Err(Error::Cose("protected header is not a map".into())),
    };

    for (key, val) in &map {
        // Key 1 = "alg" in COSE
        if let ciborium::Value::Integer(i) = key {
            let key_int: i128 = (*i).into();
            if key_int == 1 {
                match val {
                    ciborium::Value::Integer(alg) => {
                        let alg_int: i128 = (*alg).into();
                        if alg_int == -35 {
                            return Ok(());
                        }
                        return Err(Error::Cose(format!("unsupported algorithm: {alg_int}")));
                    }
                    ciborium::Value::Text(s) if s == "ES384" => return Ok(()),
                    _ => return Err(Error::Cose("bad algorithm value".into())),
                }
            }
        }
    }

    Err(Error::Cose("algorithm not found in protected header".into()))
}

/// Parse the CBOR attestation document payload.
fn parse_attestation_document(payload: &[u8]) -> Result<AttestationDocument> {
    let val: ciborium::Value =
        ciborium::from_reader(payload).map_err(|e| Error::Cbor(format!("decode document: {e}")))?;

    let map = match val {
        ciborium::Value::Map(m) => m,
        _ => return Err(Error::Cbor("document is not a map".into())),
    };

    let mut doc = AttestationDocument {
        module_id: String::new(),
        timestamp: 0,
        digest: String::new(),
        pcrs: HashMap::new(),
        certificate: Vec::new(),
        cabundle: Vec::new(),
        public_key: None,
        user_data: None,
        nonce: None,
    };

    for (key, val) in map {
        let key_str = match &key {
            ciborium::Value::Text(s) => s.as_str(),
            _ => continue,
        };

        match key_str {
            "module_id" => {
                if let ciborium::Value::Text(s) = val {
                    doc.module_id = s;
                }
            }
            "timestamp" => {
                if let ciborium::Value::Integer(i) = val {
                    let ts: i128 = i.into();
                    doc.timestamp = ts as u64;
                }
            }
            "digest" => {
                if let ciborium::Value::Text(s) = val {
                    doc.digest = s;
                }
            }
            "pcrs" => {
                if let ciborium::Value::Map(pcr_map) = val {
                    for (k, v) in pcr_map {
                        if let (ciborium::Value::Integer(idx), ciborium::Value::Bytes(bytes)) =
                            (k, v)
                        {
                            let idx: i128 = idx.into();
                            doc.pcrs.insert(idx as u32, bytes);
                        }
                    }
                }
            }
            "certificate" => {
                if let ciborium::Value::Bytes(b) = val {
                    doc.certificate = b;
                }
            }
            "cabundle" => {
                if let ciborium::Value::Array(arr) = val {
                    for item in arr {
                        if let ciborium::Value::Bytes(b) = item {
                            doc.cabundle.push(b);
                        }
                    }
                }
            }
            "public_key" => {
                if let ciborium::Value::Bytes(b) = val {
                    if !b.is_empty() {
                        doc.public_key = Some(b);
                    }
                }
            }
            "user_data" => {
                if let ciborium::Value::Bytes(b) = val {
                    if !b.is_empty() {
                        doc.user_data = Some(b);
                    }
                }
            }
            "nonce" => {
                if let ciborium::Value::Bytes(b) = val {
                    if !b.is_empty() {
                        doc.nonce = Some(b);
                    }
                }
            }
            _ => {}
        }
    }

    Ok(doc)
}

/// Validate mandatory fields in the attestation document.
fn validate_document(doc: &AttestationDocument) -> Result<()> {
    if doc.module_id.is_empty()
        || doc.digest.is_empty()
        || doc.timestamp == 0
        || doc.pcrs.is_empty()
        || doc.certificate.is_empty()
        || doc.cabundle.is_empty()
    {
        return Err(Error::AttestationVerification(
            "mandatory fields missing".into(),
        ));
    }

    if doc.digest != "SHA384" {
        return Err(Error::AttestationVerification(
            "digest is not SHA384".into(),
        ));
    }

    if doc.pcrs.is_empty() || doc.pcrs.len() > 32 {
        return Err(Error::AttestationVerification("bad PCR count".into()));
    }

    for (idx, val) in &doc.pcrs {
        if *idx > 31 {
            return Err(Error::AttestationVerification(format!(
                "PCR index {idx} out of range"
            )));
        }
        if val.is_empty() || !(val.len() == 32 || val.len() == 48 || val.len() == 64) {
            return Err(Error::AttestationVerification(format!(
                "PCR{idx} has invalid length {}",
                val.len()
            )));
        }
    }

    if doc.cabundle.is_empty() {
        return Err(Error::AttestationVerification(
            "cabundle is empty".into(),
        ));
    }

    for (i, item) in doc.cabundle.iter().enumerate() {
        if item.is_empty() || item.len() > 1024 {
            return Err(Error::AttestationVerification(format!(
                "cabundle[{i}] has invalid length {}",
                item.len()
            )));
        }
    }

    Ok(())
}

/// Parse PEM to DER bytes.
fn pem_to_der(pem: &str) -> Result<Vec<u8>> {
    let pem = pem
        .replace("-----BEGIN CERTIFICATE-----", "")
        .replace("-----END CERTIFICATE-----", "")
        .replace('\n', "");
    base64::Engine::decode(&base64::engine::general_purpose::STANDARD, &pem)
        .map_err(|e| Error::Certificate(format!("PEM decode: {e}")))
}

/// Extract the P-384 public key from a DER-encoded X.509 certificate.
fn extract_p384_pubkey(cert_der: &[u8]) -> Result<P384VerifyingKey> {
    let cert = Certificate::from_der(cert_der)
        .map_err(|e| Error::Certificate(format!("parse certificate: {e}")))?;

    let spki = cert.tbs_certificate.subject_public_key_info;
    let pubkey_bytes = spki
        .subject_public_key
        .as_bytes()
        .ok_or_else(|| Error::Certificate("missing public key bits".into()))?;

    P384VerifyingKey::from_sec1_bytes(pubkey_bytes)
        .map_err(|e| Error::Certificate(format!("parse P-384 pubkey: {e}")))
}

/// Verify the certificate chain: leaf → intermediates → root.
///
/// The cabundle is ordered from closest to root to closest to leaf
/// (same as the Go nitrite library expects).
fn verify_cert_chain(leaf_der: &[u8], cabundle: &[Vec<u8>]) -> Result<P384VerifyingKey> {
    let root_der = pem_to_der(AWS_NITRO_ROOT_PEM)?;

    // Build the chain: leaf cert is signed by last cabundle entry,
    // first cabundle entry is signed by root.
    // Verify from root down to leaf.
    let mut chain: Vec<&[u8]> = Vec::new();
    chain.push(&root_der);
    for cert in cabundle {
        chain.push(cert);
    }
    chain.push(leaf_der);

    // Verify each pair: chain[i] signs chain[i+1]
    for i in 0..chain.len() - 1 {
        let parent_key = extract_p384_pubkey(chain[i])?;
        let child = Certificate::from_der(chain[i + 1])
            .map_err(|e| Error::Certificate(format!("parse cert[{}]: {e}", i + 1)))?;

        let tbs_bytes = child
            .tbs_certificate
            .to_der()
            .map_err(|e| Error::Certificate(format!("encode TBS: {e}")))?;

        let sig_bytes = child
            .signature
            .as_bytes()
            .ok_or_else(|| Error::Certificate("missing signature bits".into()))?;

        let signature = P384Signature::from_der(sig_bytes)
            .map_err(|e| Error::Certificate(format!("parse signature: {e}")))?;

        let hash = Sha384::digest(&tbs_bytes);
        use p384::ecdsa::signature::hazmat::PrehashVerifier;
        parent_key
            .verify_prehash(&hash, &signature)
            .map_err(|e| Error::Certificate(format!("cert chain signature verification failed at depth {i}: {e}")))?;
    }

    // Return the leaf's public key for COSE signature verification.
    extract_p384_pubkey(leaf_der)
}

/// Build the COSE Sig_structure and verify the ECDSA-P384 signature.
fn verify_cose_signature(
    protected: &[u8],
    payload: &[u8],
    signature: &[u8],
    leaf_key: &P384VerifyingKey,
) -> bool {
    // Build Sig_structure: ["Signature1", protected, b"", payload]
    // per RFC 8152 Section 4.4
    let sig_structure = ciborium::Value::Array(vec![
        ciborium::Value::Text("Signature1".to_string()),
        ciborium::Value::Bytes(protected.to_vec()),
        ciborium::Value::Bytes(Vec::new()),
        ciborium::Value::Bytes(payload.to_vec()),
    ]);

    let mut sig_struct_bytes = Vec::new();
    if ciborium::into_writer(&sig_structure, &mut sig_struct_bytes).is_err() {
        return false;
    }

    // SHA-384 hash of the Sig_structure
    let hash = Sha384::digest(&sig_struct_bytes);

    // Parse the ECDSA signature (r || s, each 48 bytes for P-384)
    if signature.len() != 96 {
        return false;
    }

    let sig = match P384Signature::from_slice(signature) {
        Ok(s) => s,
        Err(_) => return false,
    };

    use p384::ecdsa::signature::hazmat::PrehashVerifier;
    leaf_key.verify_prehash(&hash, &sig).is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pem_to_der() {
        let der = pem_to_der(AWS_NITRO_ROOT_PEM).unwrap();
        assert!(!der.is_empty());
        // Should be a valid X.509 certificate
        let cert = Certificate::from_der(&der).unwrap();
        let cn = cert.tbs_certificate.subject.to_string();
        assert!(cn.contains("aws.nitro-enclaves"));
    }

    #[test]
    fn test_extract_root_pubkey() {
        let der = pem_to_der(AWS_NITRO_ROOT_PEM).unwrap();
        let key = extract_p384_pubkey(&der);
        assert!(key.is_ok());
    }

    #[test]
    fn test_verify_real_attestation_document() {
        // Real attestation document captured from a running AWS Nitro Enclave.
        let b64 = include_str!("../tests/fixtures/attestation.b64");
        let cbor_bytes = base64::Engine::decode(
            &base64::engine::general_purpose::STANDARD,
            b64.trim(),
        )
        .expect("decode base64");

        let result = verify_attestation_document(&cbor_bytes).expect("verify attestation");

        // Verify document fields.
        assert!(result.signature_ok);
        assert_eq!(result.document.digest, "SHA384");
        assert!(!result.document.module_id.is_empty());
        assert!(result.document.timestamp > 0);

        // Verify PCR0 is present and matches expected value.
        let pcr0 = result.document.pcrs.get(&0).expect("PCR0 present");
        assert_eq!(
            hex::encode(pcr0),
            "834837d8fdff29f35317acc40ba4e1e505b71a3cf7374ebba016a38e05c43784a01f0c1e88bf2b6174e4dbfc6f679ba9"
        );

        // Verify nonce matches what we sent.
        let nonce = result.document.nonce.as_ref().expect("nonce present");
        assert_eq!(
            hex::encode(nonce),
            "deadbeefcafebabe1234567890abcdef01020304"
        );

        // Verify UserData is present (79 bytes for nitriding v1.4.2).
        let user_data = result.document.user_data.as_ref().expect("user_data present");
        assert!(user_data.len() >= 79);

        // Verify certificate chain was valid (signature_ok).
        assert!(result.signature_ok);
    }

    #[test]
    fn test_verify_attestation_rejects_tampered_document() {
        let b64 = include_str!("../tests/fixtures/attestation.b64");
        let mut cbor_bytes = base64::Engine::decode(
            &base64::engine::general_purpose::STANDARD,
            b64.trim(),
        )
        .expect("decode base64");

        // Tamper with the document by flipping a byte near the end (in the signature).
        if let Some(last) = cbor_bytes.last_mut() {
            *last ^= 0xff;
        }

        // Should fail verification.
        let result = verify_attestation_document(&cbor_bytes);
        assert!(result.is_err());
    }
}
