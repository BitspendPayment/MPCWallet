//! Key package operations (taproot tweak).

use threshold::keys::{KeyPackage, PublicKeyPackage};

use crate::exports::component::threshold::types::ThresholdError;
use crate::convert;

pub fn key_package_tweak(
    kp_json: String,
    merkle_root: Option<Vec<u8>>,
) -> Result<String, ThresholdError> {
    let kp = KeyPackage::from_json(&kp_json).map_err(convert::to_serde_error)?;
    let tweaked = kp.tweak(merkle_root.as_deref());
    Ok(tweaked.to_json())
}

pub fn pub_key_package_tweak(
    pkp_json: String,
    merkle_root: Option<Vec<u8>>,
) -> Result<String, ThresholdError> {
    let pkp = PublicKeyPackage::from_json(&pkp_json).map_err(convert::to_serde_error)?;
    let tweaked = pkp.tweak(merkle_root.as_deref());
    Ok(tweaked.to_json())
}
