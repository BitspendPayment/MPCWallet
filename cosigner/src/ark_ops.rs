//! Ark protocol WASM operations.

use crate::exports::component::threshold::types::ThresholdError;
use crate::convert;

pub fn ark_default_vtxo_script_pubkey(
    server_pk_hex: String,
    owner_pk_hex: String,
    exit_delay: u32,
) -> Result<String, ThresholdError> {
    let server_pk = convert::hex_decode_32(&server_pk_hex).map_err(convert::to_input_error)?;
    let owner_pk = convert::hex_decode_32(&owner_pk_hex).map_err(convert::to_input_error)?;

    let tree = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);
    let spk = ark::vtxo_script_pubkey(&tree).map_err(convert::to_crypto_error)?;
    Ok(convert::hex_encode(&spk))
}

pub fn ark_forfeit_spend_info(
    server_pk_hex: String,
    owner_pk_hex: String,
    exit_delay: u32,
) -> Result<String, ThresholdError> {
    let server_pk = convert::hex_decode_32(&server_pk_hex).map_err(convert::to_input_error)?;
    let owner_pk = convert::hex_decode_32(&owner_pk_hex).map_err(convert::to_input_error)?;

    let (script, cb) = ark::forfeit_spend_info(&server_pk, &owner_pk, exit_delay)
        .ok_or_else(|| ThresholdError::CryptoError("forfeit_spend_info failed".into()))?;

    let json = format!(
        r#"{{"script_hex":"{}","control_block_hex":"{}"}}"#,
        convert::hex_encode(&script),
        convert::hex_encode(&cb.serialize()),
    );
    Ok(json)
}

pub fn ark_exit_spend_info(
    server_pk_hex: String,
    owner_pk_hex: String,
    exit_delay: u32,
) -> Result<String, ThresholdError> {
    let server_pk = convert::hex_decode_32(&server_pk_hex).map_err(convert::to_input_error)?;
    let owner_pk = convert::hex_decode_32(&owner_pk_hex).map_err(convert::to_input_error)?;

    let (script, cb) = ark::exit_spend_info(&server_pk, &owner_pk, exit_delay)
        .ok_or_else(|| ThresholdError::CryptoError("exit_spend_info failed".into()))?;

    let json = format!(
        r#"{{"script_hex":"{}","control_block_hex":"{}"}}"#,
        convert::hex_encode(&script),
        convert::hex_encode(&cb.serialize()),
    );
    Ok(json)
}
