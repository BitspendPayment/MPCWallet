//! FFI bindings for the forked enclave-client crate.
//!
//! Thin C-ABI layer -- most logic lives in enclave-client.
//! The client manages its own attestation cache; no shadow cache here.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use enclave_client::{Client, Options};
use serde::Serialize;

/// Opaque client handle.
pub struct ClientHandle {
    client: Client,
    rt: tokio::runtime::Runtime,
}

/// JSON response for HTTP requests.
#[derive(Serialize)]
struct FfiResponse {
    status_code: u16,
    body: String,
    signature_verified: bool,
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

/// Create a new enclave client with eager attestation verification.
///
/// Returns null on error (enclave unreachable, PCR0 mismatch, etc.)
#[no_mangle]
pub extern "C" fn enclave_client_new(
    base_url: *const c_char,
    pcr0: *const c_char,
    cache_ttl_secs: u32,
) -> *mut ClientHandle {
    let base_url = from_c_str(base_url);
    let pcr0 = from_c_str(pcr0);
    let ttl = if cache_ttl_secs == 0 { 60 } else { cache_ttl_secs as u64 };

    let rt = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(_) => return std::ptr::null_mut(),
    };

    let opts = Options {
        expected_pcr0: pcr0,
        cache_ttl: std::time::Duration::from_secs(ttl),
        insecure_tls: true,
        ..Default::default()
    };

    // Use init() for eager verification + connection warmup.
    match rt.block_on(Client::init(&base_url, opts)) {
        Ok(client) => Box::into_raw(Box::new(ClientHandle { client, rt })),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Make a verified POST request. Returns JSON string.
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

    let resp = match handle.rt.block_on(handle.client.post(&path, body)) {
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

/// Make a verified GET request. Returns JSON string.
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

    let resp = match handle.rt.block_on(handle.client.get(&path)) {
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

/// Read cached attestation status (no network call).
#[no_mangle]
pub extern "C" fn enclave_client_attestation_status(
    handle: *mut ClientHandle,
) -> *mut c_char {
    let handle = unsafe {
        if handle.is_null() {
            return to_c_string(r#"{"verified":false,"pcr0":"","attestation_key":"","verified_at_epoch_secs":0,"ttl_remaining_secs":0}"#);
        }
        &*handle
    };

    let status = handle.client.attestation_status();
    to_c_string(&serde_json::to_string(&status).unwrap_or_default())
}

/// Force re-verification and return updated status.
#[no_mangle]
pub extern "C" fn enclave_client_verify(
    handle: *mut ClientHandle,
) -> *mut c_char {
    let handle = unsafe {
        if handle.is_null() {
            return to_c_string(r#"{"verified":false,"error":"null client handle"}"#);
        }
        &*handle
    };

    let _ = handle.rt.block_on(handle.client.verify_attestation());
    let status = handle.client.attestation_status();
    to_c_string(&serde_json::to_string(&status).unwrap_or_default())
}

/// Free a client handle.
#[no_mangle]
pub extern "C" fn enclave_client_free(handle: *mut ClientHandle) {
    if !handle.is_null() {
        unsafe { drop(Box::from_raw(handle)); }
    }
}

/// Free a string returned by FFI functions.
#[no_mangle]
pub extern "C" fn enclave_string_free(s: *mut c_char) {
    if !s.is_null() {
        unsafe { drop(CString::from_raw(s)); }
    }
}
