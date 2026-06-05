//! Authentication operations.

use threshold::auth;

use crate::exports::component::threshold::types::ThresholdError;
use crate::convert;

pub fn verify_schnorr_signature(
    pk_hex: String,
    message: Vec<u8>,
    sig_hex: String,
) -> Result<bool, ThresholdError> {
    let pk_bytes = convert::hex_decode_33(&pk_hex).map_err(convert::to_input_error)?;
    let sig_bytes = convert::hex_decode_64(&sig_hex).map_err(convert::to_input_error)?;
    Ok(auth::verify_schnorr_signature(&pk_bytes, &message, &sig_bytes))
}
