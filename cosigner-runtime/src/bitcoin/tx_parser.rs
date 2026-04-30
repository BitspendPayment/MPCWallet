use bitcoin::consensus::deserialize;
use bitcoin::Transaction;

use crate::policy::Utxo;

/// Parse a transaction from raw hex bytes and calculate the spent amount.
///
/// Computes the sum of outputs NOT going to our own script (i.e., non-change outputs).
/// This approach doesn't require knowing input amounts from UTXO state.
pub fn calculate_spent_amount(
    tx_bytes: &[u8],
    my_script_hex: &str,
    _known_utxos: &[Utxo],
) -> Result<i64, String> {
    let tx: Transaction =
        deserialize(tx_bytes).map_err(|e| format!("Failed to deserialize transaction: {e}"))?;

    // Sum outputs NOT going to our script (= amount leaving the wallet)
    let mut total_spent: i64 = 0;
    for output in &tx.output {
        let output_script_hex = hex::encode(output.script_pubkey.as_bytes());
        if output_script_hex != my_script_hex {
            total_spent += output.value.to_sat() as i64;
        }
    }

    Ok(total_spent)
}

/// Derive the P2TR script hex from a compressed public key hex.
/// The public key should be the tweaked verifying key from the public key package.
pub fn derive_p2tr_script_hex(compressed_pubkey_hex: &str) -> Result<String, String> {
    let pubkey_bytes =
        hex::decode(compressed_pubkey_hex).map_err(|e| format!("Invalid hex: {e}"))?;

    if pubkey_bytes.len() != 33 {
        return Err("Expected 33-byte compressed public key".to_string());
    }

    // Extract x-only (drop the prefix byte)
    let x_only = &pubkey_bytes[1..];

    // P2TR witness program: OP_1 OP_PUSH32 <x-only-pubkey>
    let mut script = Vec::with_capacity(34);
    script.push(0x51); // OP_1 (witness version 1)
    script.push(0x20); // Push 32 bytes
    script.extend_from_slice(x_only);

    Ok(hex::encode(&script))
}

/// Derive the Electrum-compatible script hash from a P2TR script.
/// Script hash = reversed SHA256 of the script bytes.
pub fn derive_script_hash(script_hex: &str) -> Result<String, String> {
    use sha2::{Digest, Sha256};

    let script_bytes = hex::decode(script_hex).map_err(|e| format!("Invalid hex: {e}"))?;
    let hash = Sha256::digest(&script_bytes);

    // Electrum uses reversed hash
    let mut reversed: Vec<u8> = hash.to_vec();
    reversed.reverse();

    Ok(hex::encode(&reversed))
}

