//! FFI bindings for the pure-verification `enclave-client` crate.
//!
//! Three stateless C-ABI functions — no handles, no async, no HTTP.
//! Callers (Dart, integration tests) drive the attestation and request
//! protocol themselves and pass bytes in for crypto verification.

use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::slice;

use enclave_client::{
    extract_app_key_hash, verify_attestation_doc as verify_doc,
    verify_schnorr_signature as verify_sig,
};
use serde::Serialize;

#[derive(Serialize)]
struct AttestationVerifyResult {
    ok: bool,
    /// Hex-encoded PCR0 from the verified document.
    #[serde(skip_serializing_if = "String::is_empty")]
    pcr0: String,
    /// Map of PCR index → hex-encoded PCR value (only non-empty PCRs).
    #[serde(skip_serializing_if = "HashMap::is_empty")]
    pcrs: HashMap<String, String>,
    /// SHA-256 hex of the enclave's attestation pubkey, extracted from
    /// the document's UserData. Empty when key binding isn't supported.
    #[serde(skip_serializing_if = "String::is_empty")]
    app_key_hash: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Serialize)]
struct SignatureVerifyResult {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

fn to_c_string(s: &str) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

fn from_c_str(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_string_lossy()
        .into_owned()
}

fn from_bytes<'a>(ptr: *const u8, len: usize) -> &'a [u8] {
    if ptr.is_null() || len == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(ptr, len) }
    }
}

/// Verify a CBOR-encoded COSE_Sign1 AWS Nitro attestation document.
///
/// `doc_ptr`/`doc_len` — raw bytes of the attestation document (already
///   base64-decoded by the caller).
/// `expected_pcr0` — hex-encoded PCR0 the caller wants enforced.
/// `nonce_ptr`/`nonce_len` — the 20-byte nonce the caller put in the
///   GET query when fetching the document; the verifier asserts the
///   embedded nonce matches.
///
/// Returns a JSON string:
///   `{ "ok": true,  "pcr0": "...", "pcrs": {...}, "app_key_hash": "..." }`
///   `{ "ok": false, "error": "..." }`
///
/// The returned string must be freed with `enclave_string_free`.
#[no_mangle]
pub extern "C" fn enclave_verify_attestation_doc(
    doc_ptr: *const u8,
    doc_len: usize,
    expected_pcr0: *const c_char,
    nonce_ptr: *const u8,
    nonce_len: usize,
) -> *mut c_char {
    let doc = from_bytes(doc_ptr, doc_len);
    let pcr0 = from_c_str(expected_pcr0);
    let nonce = from_bytes(nonce_ptr, nonce_len);

    let result = match verify_doc(doc, &pcr0, nonce) {
        Ok(r) => r,
        Err(e) => {
            return to_c_string(
                &serde_json::to_string(&AttestationVerifyResult {
                    ok: false,
                    pcr0: String::new(),
                    pcrs: HashMap::new(),
                    app_key_hash: String::new(),
                    error: Some(e.to_string()),
                })
                .unwrap_or_default(),
            );
        }
    };

    // Try to extract the appKeyHash — if the document predates the
    // nitriding key-binding format, return ok with empty app_key_hash
    // and let the caller decide how to handle it.
    let app_key_hash = extract_app_key_hash(&result.document).unwrap_or_default();

    let mut pcrs = HashMap::new();
    for (idx, bytes) in &result.document.pcrs {
        if !bytes.is_empty() {
            pcrs.insert(idx.to_string(), hex::encode(bytes));
        }
    }

    let pcr0_hex = result
        .document
        .pcrs
        .get(&0)
        .map(hex::encode)
        .unwrap_or_default();

    to_c_string(
        &serde_json::to_string(&AttestationVerifyResult {
            ok: true,
            pcr0: pcr0_hex,
            pcrs,
            app_key_hash,
            error: None,
        })
        .unwrap_or_default(),
    )
}

/// Verify a BIP-340 Schnorr signature over `SHA256(body)` using the
/// hex-encoded secp256k1 attestation pubkey (compressed or x-only).
///
/// Returns a JSON string:
///   `{ "ok": true }`
///   `{ "ok": false, "error": "..." }`
///
/// The returned string must be freed with `enclave_string_free`.
#[no_mangle]
pub extern "C" fn enclave_verify_schnorr_signature(
    body_ptr: *const u8,
    body_len: usize,
    sig_hex: *const c_char,
    pubkey_hex: *const c_char,
) -> *mut c_char {
    let body = from_bytes(body_ptr, body_len);
    let sig = from_c_str(sig_hex);
    let pk = from_c_str(pubkey_hex);

    let result = match verify_sig(body, &sig, &pk) {
        Ok(()) => SignatureVerifyResult { ok: true, error: None },
        Err(e) => SignatureVerifyResult {
            ok: false,
            error: Some(e.to_string()),
        },
    };

    to_c_string(&serde_json::to_string(&result).unwrap_or_default())
}

/// Free a string returned by any of the verifier FFI functions.
#[no_mangle]
pub extern "C" fn enclave_string_free(s: *mut c_char) {
    if !s.is_null() {
        unsafe { drop(CString::from_raw(s)); }
    }
}
