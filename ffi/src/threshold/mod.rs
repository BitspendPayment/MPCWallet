//! C-ABI FFI bindings for the threshold cryptography library.
//!
//! All functions return a heap-allocated [`FfiResult`] that must be freed
//! with [`threshold_free_result`]. Opaque handles (for stateful types holding
//! secret material) must be freed with [`threshold_free_handle`].

mod ffi_auth;
mod ffi_dkg;
mod ffi_keys;
mod ffi_signing;
mod ffi_utils;
mod handles;

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use std::ptr;

// ---------------------------------------------------------------------------
// FfiResult
// ---------------------------------------------------------------------------

/// Result struct returned by every FFI function.
///
/// - `success`: true if the operation succeeded.
/// - `data`: JSON or hex string on success (null on failure).
/// - `error`: error message on failure (null on success).
/// - `handle`: opaque pointer to a heap-allocated Rust object (null if none).
#[repr(C)]
pub struct FfiResult {
    pub success: bool,
    pub data: *mut c_char,
    pub error: *mut c_char,
    pub handle: *mut c_void,
}

impl FfiResult {
    fn ok(data: &str) -> *mut Self {
        let c_data = CString::new(data).unwrap_or_default();
        Box::into_raw(Box::new(FfiResult {
            success: true,
            data: c_data.into_raw(),
            error: ptr::null_mut(),
            handle: ptr::null_mut(),
        }))
    }

    fn ok_with_handle(data: &str, handle: *mut c_void) -> *mut Self {
        let c_data = CString::new(data).unwrap_or_default();
        Box::into_raw(Box::new(FfiResult {
            success: true,
            data: c_data.into_raw(),
            error: ptr::null_mut(),
            handle,
        }))
    }

    fn err(msg: &str) -> *mut Self {
        let c_error = CString::new(msg).unwrap_or_default();
        Box::into_raw(Box::new(FfiResult {
            success: false,
            data: ptr::null_mut(),
            error: c_error.into_raw(),
            handle: ptr::null_mut(),
        }))
    }
}

// ---------------------------------------------------------------------------
// Memory management
// ---------------------------------------------------------------------------

/// Free an FfiResult returned by any threshold_* function.
#[no_mangle]
pub extern "C" fn threshold_free_result(ptr: *mut FfiResult) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let result = Box::from_raw(ptr);
        if !result.data.is_null() {
            drop(CString::from_raw(result.data));
        }
        if !result.error.is_null() {
            drop(CString::from_raw(result.error));
        }
        // handle is NOT freed here — use threshold_free_handle for that.
    }
}

/// Handle type identifiers for threshold_free_handle.
pub const HANDLE_ROUND1_SECRET: u32 = 1;
pub const HANDLE_ROUND2_SECRET: u32 = 2;
pub const HANDLE_SIGNING_NONCE: u32 = 3;
pub const HANDLE_AUTH_SIGNER: u32 = 4;

/// Free an opaque handle returned by a threshold_* function.
///
/// `type_id` identifies the Rust type:
///   1 = Round1SecretPackage
///   2 = Round2SecretPackage
///   3 = SigningNonce
///   4 = AuthSigner
#[no_mangle]
pub extern "C" fn threshold_free_handle(handle: *mut c_void, type_id: u32) {
    if handle.is_null() {
        return;
    }
    unsafe {
        match type_id {
            HANDLE_ROUND1_SECRET => {
                drop(Box::from_raw(
                    handle as *mut threshold::dkg::Round1SecretPackage,
                ));
            }
            HANDLE_ROUND2_SECRET => {
                drop(Box::from_raw(
                    handle as *mut threshold::dkg::Round2SecretPackage,
                ));
            }
            HANDLE_SIGNING_NONCE => {
                drop(Box::from_raw(
                    handle as *mut threshold::nonce::SigningNonce,
                ));
            }
            HANDLE_AUTH_SIGNER => {
                drop(Box::from_raw(
                    handle as *mut threshold::auth::AuthSigner,
                ));
            }
            _ => {} // Unknown type — ignore.
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Read a C string pointer as a &str. Returns None if null or invalid UTF-8.
pub(crate) fn read_cstr(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(ptr).to_str().ok().map(|s| s.to_string()) }
}

/// Read raw bytes from a pointer + length.
pub(crate) fn read_bytes(ptr: *const u8, len: u32) -> Option<Vec<u8>> {
    if ptr.is_null() || len == 0 {
        return None;
    }
    unsafe { Some(std::slice::from_raw_parts(ptr, len as usize).to_vec()) }
}
