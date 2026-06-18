//! Utility operations: identifier derivation.

use threshold::identifier::Identifier;

use crate::exports::component::threshold::types::ThresholdError;
use crate::convert;

pub fn identifier_derive(message: Vec<u8>) -> Result<String, ThresholdError> {
    let id = Identifier::derive(&message).map_err(convert::to_crypto_error)?;
    Ok(convert::hex_encode(&id.serialize()))
}
