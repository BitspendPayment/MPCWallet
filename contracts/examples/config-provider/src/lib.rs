//! Generic config PROVIDER fixture. Exports the typed `author:config/vars` getters, backed by a
//! patchable key-value blob. The cosigner SYNTHESIZES a concrete provider by locating the 8-byte
//! magic marker in this component's bytes and overwriting the slot with `[len: u16 LE][kv-blob]`
//! — no compiler, just byte patching. Then it composes the patched provider into a template.
//!
//! KV-blob format (the cosigner encodes, this provider decodes):
//!   `[n: u16 LE]` then n × `[key_len: u8][key utf8][type: u8][val_len: u16 LE][val]`
//!   where type: 0 = bytes, 1 = u64 (val = 8 bytes LE), 2 = string (val = utf8).
//!
//! The slot is a `static mut` (so the compiler cannot const-fold the bytes away) initialized with
//! NON-zero padding (so it lands in a STORED active data segment whose bytes appear verbatim in the
//! component binary, making the magic findable + the whole slot patchable).
#![no_std]

extern crate alloc;

use alloc::vec::Vec;

contract_sdk::runtime!();

wit_bindgen::generate!({
    world: "provider",
    path: "wit",
});

/// Max KV blob the synthesized provider can carry.
const SLOT_CAP: usize = 4096;
/// Unique 8-byte marker the cosigner searches for to locate the slot.
const MAGIC: [u8; 8] = *b"CFGSLOT!";

/// Patchable slot: magic(8) + len(2, LE) + data(SLOT_CAP). `static mut` + 0xFF padding so it is a
/// stored, non-const-foldable data segment.
static mut CONFIG_SLOT: [u8; 8 + 2 + SLOT_CAP] = {
    let mut s = [0xFFu8; 8 + 2 + SLOT_CAP];
    s[0] = MAGIC[0];
    s[1] = MAGIC[1];
    s[2] = MAGIC[2];
    s[3] = MAGIC[3];
    s[4] = MAGIC[4];
    s[5] = MAGIC[5];
    s[6] = MAGIC[6];
    s[7] = MAGIC[7];
    s[8] = 0; // len LE byte 0
    s[9] = 0; // len LE byte 1
    s
};

/// Read the patched KV blob out of the slot (volatile so the compiler can't assume the bytes).
fn kv_blob() -> Vec<u8> {
    let slot = unsafe { core::ptr::read_volatile(core::ptr::addr_of!(CONFIG_SLOT)) };
    let len = u16::from_le_bytes([slot[8], slot[9]]) as usize;
    let len = if len > SLOT_CAP { 0 } else { len };
    slot[10..10 + len].to_vec()
}

/// Manual byte equality — avoids the `memcmp` libcall that slice `==` lowers to (a `#![no_std]`
/// wasm component can't import it).
fn slice_eq(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

/// Find `key` in the blob and return `(type_tag, value_bytes)`.
fn lookup(blob: &[u8], key: &str) -> Option<(u8, Vec<u8>)> {
    if blob.len() < 2 {
        return None;
    }
    let n = u16::from_le_bytes([blob[0], blob[1]]) as usize;
    let mut p = 2usize;
    for _ in 0..n {
        if p + 1 > blob.len() {
            return None;
        }
        let klen = blob[p] as usize;
        p += 1;
        if p + klen + 1 + 2 > blob.len() {
            return None;
        }
        let k = &blob[p..p + klen];
        p += klen;
        let ty = blob[p];
        p += 1;
        let vlen = u16::from_le_bytes([blob[p], blob[p + 1]]) as usize;
        p += 2;
        if p + vlen > blob.len() {
            return None;
        }
        let v = &blob[p..p + vlen];
        p += vlen;
        if slice_eq(k, key.as_bytes()) {
            return Some((ty, v.to_vec()));
        }
    }
    None
}

fn kv_bytes(key: &str) -> Option<Vec<u8>> {
    let (ty, v) = lookup(&kv_blob(), key)?;
    if ty == 0 {
        Some(v)
    } else {
        None
    }
}

fn kv_u64(key: &str) -> Option<u64> {
    let (ty, v) = lookup(&kv_blob(), key)?;
    if ty == 1 && v.len() == 8 {
        let mut b = [0u8; 8];
        b.copy_from_slice(&v);
        Some(u64::from_le_bytes(b))
    } else {
        None
    }
}

struct Component;

// Typed getters for the oracle-gate template, each backed by the patchable KV slot. (An SDK macro
// would generate this from the template's schema; spelled out for the spike.)
impl exports::oracle::gate::config::Guest for Component {
    fn oracle_token() -> Vec<u8> {
        kv_bytes("oracle-token").unwrap_or_default()
    }

    fn max_sats() -> u64 {
        kv_u64("max-sats").unwrap_or(0)
    }
}

export!(Component);
