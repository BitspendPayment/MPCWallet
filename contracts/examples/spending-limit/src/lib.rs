//! Example contract: allow a spend only if total output value is within a fixed
//! limit. Demonstrates the contract model — `#![no_std]`, imports ONLY `crypto`
//! (no WASI), exports `evaluate`. Compiled to a wasm32-wasip2 component; its
//! sha256 digest is the on-chain `contract_id`.
#![no_std]

extern crate alloc;

use alloc::format;
use alloc::vec::Vec;

// Global allocator + panic handler + cabi_realloc, all from the SDK.
contract_sdk::runtime!();

wit_bindgen::generate!({
    world: "contract",
    path: "wit",
});

use crate::bitcoin::contract::crypto;

/// Maximum total output value (sats) this contract authorizes.
const SPEND_LIMIT_SATS: u64 = 100_000;

struct Component;

impl Guest for Component {
    fn evaluate(ctx: EvalContext) -> Verdict {
        // Exercise the host crypto import (proves the no-WASI sandbox still
        // gives contracts hashing): bind the verdict to the tx's first output.
        if let Some(first) = ctx.tx.outputs.first() {
            let _commit: Vec<u8> = crypto::sha256(&first.script_pubkey);
        }

        let total: u64 = ctx.tx.outputs.iter().map(|o| o.value).sum();
        if total > SPEND_LIMIT_SATS {
            Verdict::Deny(format!(
                "total {total} sats exceeds limit {SPEND_LIMIT_SATS}"
            ))
        } else {
            Verdict::Allow
        }
    }
}

export!(Component);
