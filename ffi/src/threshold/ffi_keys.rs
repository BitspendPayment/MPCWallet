//! Key package FFI functions (tweak, intoEvenY).

use super::{read_bytes, read_cstr, FfiResult};
use std::os::raw::c_char;

use threshold::keys::{KeyPackage, PublicKeyPackage};

// ---------------------------------------------------------------------------
// Key Package Tweak
// ---------------------------------------------------------------------------

/// Apply a taproot tweak to a KeyPackage.
///
/// - `kp_json`: JSON key package.
/// - `merkle_root_ptr`/`merkle_root_len`: optional merkle root bytes (null for key-only spend).
///
/// Returns FfiResult with `data` = tweaked KeyPackage JSON.
#[no_mangle]
pub extern "C" fn threshold_key_package_tweak(
    kp_json: *const c_char,
    merkle_root_ptr: *const u8,
    merkle_root_len: u32,
) -> *mut FfiResult {
    let result = (|| -> Result<String, String> {
        let kp_str = read_cstr(kp_json).ok_or("null kp_json")?;
        let kp =
            KeyPackage::from_json(&kp_str).map_err(|e| format!("bad key package: {e}"))?;

        let merkle_root = read_bytes(merkle_root_ptr, merkle_root_len);
        let tweaked = kp.tweak(merkle_root.as_deref());

        Ok(tweaked.to_json())
    })();

    match result {
        Ok(data) => FfiResult::ok(&data),
        Err(e) => FfiResult::err(&e),
    }
}

/// Apply a taproot tweak to a PublicKeyPackage.
///
/// - `pkp_json`: JSON public key package.
/// - `merkle_root_ptr`/`merkle_root_len`: optional merkle root bytes.
///
/// Returns FfiResult with `data` = tweaked PublicKeyPackage JSON.
#[no_mangle]
pub extern "C" fn threshold_pub_key_package_tweak(
    pkp_json: *const c_char,
    merkle_root_ptr: *const u8,
    merkle_root_len: u32,
) -> *mut FfiResult {
    let result = (|| -> Result<String, String> {
        let pkp_str = read_cstr(pkp_json).ok_or("null pkp_json")?;
        let pkp = PublicKeyPackage::from_json(&pkp_str)
            .map_err(|e| format!("bad public key package: {e}"))?;

        let merkle_root = read_bytes(merkle_root_ptr, merkle_root_len);
        let tweaked = pkp.tweak(merkle_root.as_deref());

        Ok(tweaked.to_json())
    })();

    match result {
        Ok(data) => FfiResult::ok(&data),
        Err(e) => FfiResult::err(&e),
    }
}

/// Normalize a KeyPackage to even Y (BIP-340).
///
/// Returns FfiResult with `data` = normalized KeyPackage JSON.
#[no_mangle]
pub extern "C" fn threshold_key_package_into_even_y(
    kp_json: *const c_char,
) -> *mut FfiResult {
    let result = (|| -> Result<String, String> {
        let kp_str = read_cstr(kp_json).ok_or("null kp_json")?;
        let kp =
            KeyPackage::from_json(&kp_str).map_err(|e| format!("bad key package: {e}"))?;
        Ok(kp.into_even_y().to_json())
    })();

    match result {
        Ok(data) => FfiResult::ok(&data),
        Err(e) => FfiResult::err(&e),
    }
}

/// Normalize a PublicKeyPackage to even Y (BIP-340).
///
/// Returns FfiResult with `data` = normalized PublicKeyPackage JSON.
#[no_mangle]
pub extern "C" fn threshold_pub_key_package_into_even_y(
    pkp_json: *const c_char,
) -> *mut FfiResult {
    let result = (|| -> Result<String, String> {
        let pkp_str = read_cstr(pkp_json).ok_or("null pkp_json")?;
        let pkp = PublicKeyPackage::from_json(&pkp_str)
            .map_err(|e| format!("bad public key package: {e}"))?;
        Ok(pkp.into_even_y().to_json())
    })();

    match result {
        Ok(data) => FfiResult::ok(&data),
        Err(e) => FfiResult::err(&e),
    }
}
