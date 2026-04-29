//! Ark address derivation.

use ark_core::{BoardingOutput, Vtxo};
use bitcoin::key::Secp256k1;
use bitcoin::{Network, XOnlyPublicKey};

/// Derive the Ark off-chain address for a given owner pubkey and ASP.
///
/// Uses `Vtxo::new_default().to_ark_address()` — identical to the reference client.
///
/// `owner_pk_hex` and `asp_pk_hex` are 64-char hex x-only public keys.
/// `exit_delay` is the raw exit delay value (will be BIP68-encoded internally).
pub fn ark_address(
    owner_pk_hex: &str,
    asp_pk_hex: &str,
    exit_delay: u32,
    network: Network,
) -> Result<String, String> {
    let secp = Secp256k1::new();
    let owner_pk = hex_to_xonly(owner_pk_hex)?;
    let asp_pk = hex_to_xonly(asp_pk_hex)?;

    let exit_seq = ark_core::server::parse_sequence_number(exit_delay as i64)
        .map_err(|e| format!("parse_sequence_number: {e}"))?;

    let vtxo = Vtxo::new_default(&secp, asp_pk, owner_pk, exit_seq, network)
        .map_err(|e| format!("Vtxo::new_default: {e}"))?;

    Ok(vtxo.to_ark_address().encode())
}

/// Derive the boarding address for on-chain funding.
///
/// Uses ark-core's `BoardingOutput` to ensure consistency with the batch protocol.
/// The boarding address is a P2TR address with a 2-leaf taptree:
/// - Forfeit leaf: `<asp_pk> CHECKSIGVERIFY <owner_pk> CHECKSIG`
/// - Exit leaf: `<owner_pk> CHECKSIGVERIFY <delay> CSV DROP`
///
/// This allows the boarding UTXO to be swept into the Ark in the next batch round.
pub fn boarding_address(
    owner_pk_hex: &str,
    asp_pk_hex: &str,
    exit_delay: u32,
    network: Network,
) -> Result<String, String> {
    let secp = Secp256k1::new();
    let owner_pk = hex_to_xonly(owner_pk_hex)?;
    let asp_pk = hex_to_xonly(asp_pk_hex)?;

    let exit_seq = ark_core::server::parse_sequence_number(exit_delay as i64)
        .map_err(|e| format!("parse_sequence_number: {e}"))?;

    let boarding = BoardingOutput::new(&secp, asp_pk, owner_pk, exit_seq, network)
        .map_err(|e| format!("BoardingOutput::new: {e}"))?;

    Ok(boarding.address().to_string())
}

/// Derive the VTXO scriptPubKey hex for a given owner + ASP.
///
/// This is used to match incoming stream VTXOs to users.
pub fn vtxo_script_pubkey_hex(
    owner_pk_hex: &str,
    asp_pk_hex: &str,
    exit_delay: u32,
    network: Network,
) -> Result<String, String> {
    let secp = Secp256k1::new();
    let owner_pk = hex_to_xonly(owner_pk_hex)?;
    let asp_pk = hex_to_xonly(asp_pk_hex)?;

    let exit_seq = ark_core::server::parse_sequence_number(exit_delay as i64)
        .map_err(|e| format!("parse_sequence_number: {e}"))?;

    let vtxo = Vtxo::new_default(&secp, asp_pk, owner_pk, exit_seq, network)
        .map_err(|e| format!("Vtxo::new_default: {e}"))?;

    let spk = vtxo.script_pubkey();
    Ok(spk.as_bytes().iter().map(|b| format!("{:02x}", b)).collect())
}

/// Map ASP network string to bitcoin::Network.
pub fn parse_network(network: &str) -> Result<Network, String> {
    match network {
        "bitcoin" | "mainnet" => Ok(Network::Bitcoin),
        "testnet" | "testnet3" => Ok(Network::Testnet),
        "signet" | "mutinynet" => Ok(Network::Signet),
        "regtest" => Ok(Network::Regtest),
        _ => Err(format!("unknown network: {network}")),
    }
}

// -- helpers --

/// Normalize a public key hex string to x-only (64 hex chars).
/// Accepts both 64-char (x-only) and 66-char (compressed with 02/03 prefix).
fn normalize_xonly(hex: &str) -> &str {
    if hex.len() == 66 && (hex.starts_with("02") || hex.starts_with("03")) {
        &hex[2..]
    } else {
        hex
    }
}

fn hex_to_32(hex: &str) -> Result<[u8; 32], String> {
    let hex = normalize_xonly(hex);
    if hex.len() != 64 {
        return Err(format!("expected 64 hex chars, got {}", hex.len()));
    }
    let mut out = [0u8; 32];
    for i in 0..32 {
        out[i] = u8::from_str_radix(&hex[i * 2..i * 2 + 2], 16)
            .map_err(|_| format!("invalid hex at offset {}", i * 2))?;
    }
    Ok(out)
}

fn hex_to_xonly(hex: &str) -> Result<XOnlyPublicKey, String> {
    let bytes = hex_to_32(normalize_xonly(hex))?;
    XOnlyPublicKey::from_slice(&bytes).map_err(|e| format!("invalid x-only pubkey: {e}"))
}

/// Parse a hex public key string (64 or 66 chars) into a compressed `PublicKey`.
pub fn parse_xonly_pubkey(hex: &str) -> Result<bitcoin::key::PublicKey, String> {
    let xonly = hex_to_xonly(hex)?;
    Ok(bitcoin::key::PublicKey::from(
        bitcoin::secp256k1::PublicKey::from_x_only_public_key(xonly, bitcoin::key::Parity::Even),
    ))
}
