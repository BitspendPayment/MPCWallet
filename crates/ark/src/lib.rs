#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

#[cfg(feature = "client")]
pub mod client;

use alloc::vec::Vec;
use threshold::taptree::{ControlBlock, TapLeaf, TapNode, UNSPENDABLE_KEY_X_ONLY};

// Re-export taptree types for convenience
pub use threshold::taptree;

// Bitcoin script opcodes
const OP_CHECKSIG: u8 = 0xac;
const OP_CHECKSIGVERIFY: u8 = 0xad;
const OP_CSV: u8 = 0xb2;  // OP_CHECKSEQUENCEVERIFY
const OP_DROP: u8 = 0x75;

/// Build forfeit/cooperative script:
/// `<server_pk> OP_CHECKSIGVERIFY <owner_pk> OP_CHECKSIG`
///
/// Both keys must be 32-byte x-only pubkeys.
pub fn multisig_script(server_pk: &[u8; 32], owner_pk: &[u8; 32]) -> Vec<u8> {
    let mut script = Vec::with_capacity(68); // 1+32 + 1 + 1+32 + 1
    script.push(0x20); // OP_PUSHBYTES_32
    script.extend_from_slice(server_pk);
    script.push(OP_CHECKSIGVERIFY);
    script.push(0x20); // OP_PUSHBYTES_32
    script.extend_from_slice(owner_pk);
    script.push(OP_CHECKSIG);
    script
}

/// Build unilateral exit script:
/// `<owner_pk> OP_CHECKSIGVERIFY <sequence> OP_CHECKSEQUENCEVERIFY OP_DROP`
///
/// `owner_pk` must be a 32-byte x-only pubkey.
/// `exit_delay` is encoded as a Bitcoin script number (minimal push).
pub fn csv_sig_script(exit_delay: u32, owner_pk: &[u8; 32]) -> Vec<u8> {
    let seq_bytes = script_number_encode(exit_delay as i64);
    let mut script = Vec::with_capacity(35 + seq_bytes.len() + 2);
    script.push(0x20); // OP_PUSHBYTES_32
    script.extend_from_slice(owner_pk);
    script.push(OP_CHECKSIGVERIFY);
    push_script_number(&mut script, &seq_bytes);
    script.push(OP_CSV);
    script.push(OP_DROP);
    script
}

/// Build a default Ark VTXO taproot tree with two leaves at depth 1:
/// - Leaf 0 (forfeit): `<server_pk> OP_CHECKSIGVERIFY <owner_pk> OP_CHECKSIG`
/// - Leaf 1 (exit): `<owner_pk> OP_CHECKSIGVERIFY <sequence> OP_CSV OP_DROP`
pub fn default_vtxo_tree(
    server_pk: &[u8; 32],
    owner_pk: &[u8; 32],
    exit_delay: u32,
) -> TapNode {
    let forfeit = TapLeaf::new(multisig_script(server_pk, owner_pk));
    let exit = TapLeaf::new(csv_sig_script(exit_delay, owner_pk));
    TapNode::Branch(
        alloc::boxed::Box::new(TapNode::Leaf(forfeit)),
        alloc::boxed::Box::new(TapNode::Leaf(exit)),
    )
}

/// Derive the tweaked output key for a VTXO (using UNSPENDABLE_KEY as internal key).
/// Returns the 33-byte compressed tweaked key.
pub fn vtxo_output_key(tree: &TapNode) -> Result<[u8; 33], threshold::error::Error> {
    threshold::taptree::tweaked_output_key_from_x_only(&UNSPENDABLE_KEY_X_ONLY, tree)
}

/// Derive the script pubkey (OP_1 <x-only tweaked key>) for a VTXO.
/// Returns 34 bytes: [0x51, 0x20, ...32 bytes x-only key].
pub fn vtxo_script_pubkey(tree: &TapNode) -> Result<[u8; 34], threshold::error::Error> {
    let compressed = vtxo_output_key(tree)?;
    let mut spk = [0u8; 34];
    spk[0] = 0x51; // OP_1 (witness version 1)
    spk[1] = 0x20; // OP_PUSHBYTES_32
    spk[2..].copy_from_slice(&compressed[1..33]); // x-only
    Ok(spk)
}

/// Get forfeit spend info: (script_bytes, control_block).
pub fn forfeit_spend_info(
    server_pk: &[u8; 32],
    owner_pk: &[u8; 32],
    exit_delay: u32,
) -> Option<(Vec<u8>, ControlBlock)> {
    let tree = default_vtxo_tree(server_pk, owner_pk, exit_delay);
    let forfeit_leaf = TapLeaf::new(multisig_script(server_pk, owner_pk));
    let cb = ControlBlock::new(&UNSPENDABLE_KEY_X_ONLY, &forfeit_leaf, &tree)?;
    Some((forfeit_leaf.script, cb))
}

/// Get exit spend info: (script_bytes, control_block).
pub fn exit_spend_info(
    server_pk: &[u8; 32],
    owner_pk: &[u8; 32],
    exit_delay: u32,
) -> Option<(Vec<u8>, ControlBlock)> {
    let tree = default_vtxo_tree(server_pk, owner_pk, exit_delay);
    let exit_leaf = TapLeaf::new(csv_sig_script(exit_delay, owner_pk));
    let cb = ControlBlock::new(&UNSPENDABLE_KEY_X_ONLY, &exit_leaf, &tree)?;
    Some((exit_leaf.script, cb))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Encode a positive integer as a minimal Bitcoin script number.
fn script_number_encode(n: i64) -> Vec<u8> {
    if n == 0 {
        return Vec::new();
    }

    let negative = n < 0;
    let mut abs = if negative { -n } else { n } as u64;
    let mut result = Vec::new();

    while abs > 0 {
        result.push((abs & 0xff) as u8);
        abs >>= 8;
    }

    // If the high bit is set, add an extra byte for the sign.
    if result.last().map_or(false, |b| b & 0x80 != 0) {
        result.push(if negative { 0x80 } else { 0x00 });
    } else if negative {
        let last = result.last_mut().unwrap();
        *last |= 0x80;
    }

    result
}

/// Push a script number onto the script with the appropriate opcode.
fn push_script_number(script: &mut Vec<u8>, data: &[u8]) {
    let len = data.len();
    if len == 0 {
        script.push(0x00); // OP_0
    } else if len == 1 && data[0] <= 16 && data[0] >= 1 {
        // OP_1 through OP_16
        script.push(0x50 + data[0]);
    } else if len < 0x4c {
        script.push(len as u8); // direct push
        script.extend_from_slice(data);
    } else if len <= 0xff {
        script.push(0x4c); // OP_PUSHDATA1
        script.push(len as u8);
        script.extend_from_slice(data);
    } else {
        script.push(0x4d); // OP_PUSHDATA2
        script.extend_from_slice(&(len as u16).to_le_bytes());
        script.extend_from_slice(data);
    }
}
