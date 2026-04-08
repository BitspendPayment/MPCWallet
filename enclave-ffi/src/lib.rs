//! FFI bindings for the enclave-client crate.
//!
//! Exposes the verified HTTP client for AWS Nitro Enclaves to Dart/Flutter
//! via C-ABI functions. Follows the same FFI pattern as threshold-ffi and ark-ffi.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::Arc;
use std::time::Duration;

use enclave_client::{Client, Options};
use serde::Serialize;

/// Opaque client handle.
struct ClientHandle {
    client: Client,
    rt: tokio::runtime::Runtime,
    cache_ttl: Duration,
}

/// JSON response returned to Dart for HTTP requests.
#[derive(Serialize)]
struct FfiResponse {
    status_code: u16,
    body: String,
    signature_verified: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

/// JSON response returned to Dart for attestation status queries.
#[derive(Serialize)]
struct FfiAttestationStatus {
    verified: bool,
    pcr0: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    last_verified_at_secs: Option<u64>,
    ttl_remaining_secs: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    attestation_pubkey: Option<String>,
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

/// Create a new enclave client.
///
/// # Arguments
/// * `base_url` - HTTPS URL of the enclave (e.g. "https://1.2.3.4")
/// * `pcr0` - Expected PCR0 hex string (96 chars, SHA-384)
/// * `cache_ttl_secs` - Attestation cache TTL in seconds (0 = default 60s)
///
/// # Returns
/// Opaque pointer to client, or null on error.
#[no_mangle]
pub extern "C" fn enclave_client_new(
    base_url: *const c_char,
    pcr0: *const c_char,
    cache_ttl_secs: u32,
) -> *mut ClientHandle {
    let base_url = from_c_str(base_url);
    let pcr0 = from_c_str(pcr0);
    let ttl = if cache_ttl_secs == 0 {
        Duration::from_secs(60)
    } else {
        Duration::from_secs(cache_ttl_secs as u64)
    };

    let rt = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(_) => return std::ptr::null_mut(),
    };

    let opts = Options {
        expected_pcr0: pcr0,
        cache_ttl: ttl,
        insecure_tls: true, // Enclaves use self-signed certs
        ..Default::default()
    };

    match Client::new(&base_url, opts) {
        Ok(client) => Box::into_raw(Box::new(ClientHandle { client, rt, cache_ttl: ttl })),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Make a verified POST request.
///
/// Returns a JSON string with `{status_code, body, signature_verified, error}`.
/// Caller must free the returned string with `enclave_string_free`.
#[no_mangle]
pub extern "C" fn enclave_client_post(
    handle: *mut ClientHandle,
    path: *const c_char,
    body: *const c_char,
) -> *mut c_char {
    let handle = unsafe {
        if handle.is_null() {
            return to_c_string(r#"{"error":"null client handle"}"#);
        }
        &*handle
    };
    let path = from_c_str(path);
    let body = from_c_str(body);

    let result = handle.rt.block_on(async {
        handle.client.post(&path, body).await
    });

    let resp = match result {
        Ok(r) => FfiResponse {
            status_code: r.status_code,
            body: String::from_utf8_lossy(&r.body).into_owned(),
            signature_verified: r.signature_verified,
            error: None,
        },
        Err(e) => FfiResponse {
            status_code: 0,
            body: String::new(),
            signature_verified: false,
            error: Some(e.to_string()),
        },
    };

    to_c_string(&serde_json::to_string(&resp).unwrap_or_default())
}

/// Make a verified GET request.
///
/// Returns a JSON string. Caller must free with `enclave_string_free`.
#[no_mangle]
pub extern "C" fn enclave_client_get(
    handle: *mut ClientHandle,
    path: *const c_char,
) -> *mut c_char {
    let handle = unsafe {
        if handle.is_null() {
            return to_c_string(r#"{"error":"null client handle"}"#);
        }
        &*handle
    };
    let path = from_c_str(path);

    let result = handle.rt.block_on(async {
        handle.client.get(&path).await
    });

    let resp = match result {
        Ok(r) => FfiResponse {
            status_code: r.status_code,
            body: String::from_utf8_lossy(&r.body).into_owned(),
            signature_verified: r.signature_verified,
            error: None,
        },
        Err(e) => FfiResponse {
            status_code: 0,
            body: String::new(),
            signature_verified: false,
            error: Some(e.to_string()),
        },
    };

    to_c_string(&serde_json::to_string(&resp).unwrap_or_default())
}

/// Get the current attestation status.
///
/// Returns JSON: `{verified, pcr0, last_verified_at_secs, ttl_remaining_secs, attestation_pubkey}`.
/// Caller must free with `enclave_string_free`.
#[no_mangle]
pub extern "C" fn enclave_client_attestation_status(
    handle: *mut ClientHandle,
) -> *mut c_char {
    let handle = unsafe {
        if handle.is_null() {
            return to_c_string(r#"{"verified":false,"error":"null client handle"}"#);
        }
        &*handle
    };

    let result = handle.rt.block_on(async {
        // Try to read cached state without triggering a new verification
        handle.client.verify_attestation().await
    });

    let status = match result {
        Ok(attest) => {
            let elapsed = attest.verified_at.elapsed();
            let ttl = handle.cache_ttl;
            let remaining = ttl.as_secs() as i64 - elapsed.as_secs() as i64;

            FfiAttestationStatus {
                verified: attest.verified,
                pcr0: attest.pcr0,
                last_verified_at_secs: Some(elapsed.as_secs()),
                ttl_remaining_secs: remaining.max(0),
                attestation_pubkey: Some(attest.attestation_key),
                error: None,
            }
        }
        Err(e) => FfiAttestationStatus {
            verified: false,
            pcr0: String::new(),
            last_verified_at_secs: None,
            ttl_remaining_secs: 0,
            attestation_pubkey: None,
            error: Some(e.to_string()),
        },
    };

    to_c_string(&serde_json::to_string(&status).unwrap_or_default())
}

/// Force re-verification of attestation.
///
/// Returns JSON attestation status. Caller must free with `enclave_string_free`.
#[no_mangle]
pub extern "C" fn enclave_client_verify(
    handle: *mut ClientHandle,
) -> *mut c_char {
    enclave_client_attestation_status(handle)
}

/// Free a client handle.
#[no_mangle]
pub extern "C" fn enclave_client_free(handle: *mut ClientHandle) {
    if !handle.is_null() {
        unsafe {
            drop(Box::from_raw(handle));
        }
    }
}

/// Free a string returned by the FFI functions.
#[no_mangle]
pub extern "C" fn enclave_string_free(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            drop(CString::from_raw(s));
        }
    }
}
