//! Example contract: allow a spend only if the caller supplies the expected
//! oracle token in `contract_args` AND the total output value is within a fixed
//! limit. Demonstrates `contract_args` — the per-input off-chain caller data the
//! cosigner reads from the spend PSBT's proprietary map — alongside amount
//! introspection. `#![no_std]`, imports ONLY `crypto` (no WASI), exports
//! `evaluate`. Compiled to a wasm32-wasip2 component; its sha256 digest is the
//! on-chain `contract_id`.
#![no_std]

extern crate alloc;

use alloc::format;

// Global allocator + panic handler + cabi_realloc, all from the SDK.
contract_sdk::runtime!();

wit_bindgen::generate!({
    world: "contract",
    path: "wit",
});

use crate::bitcoin::contract::crypto;

/// The token the caller must present in `contract_args` (e.g. an oracle's
/// go-ahead packet) for the spend to be authorized.
const ORACLE_TOKEN: &[u8] = b"ORACLE-OK";

/// Maximum total output value (sats) this contract authorizes.
const SPEND_LIMIT_SATS: u64 = 100_000;

/// Constant-time byte equality. Written as an XOR-fold rather than `a == b` so
/// LLVM doesn't lower it to a libc `memcmp` (which a `#![no_std]` component
/// can't import).
fn bytes_eq(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

struct Component;

impl Guest for Component {
    fn evaluate(ctx: EvalContext) -> Verdict {
        // Exercise the host `crypto` import (proves the no-WASI sandbox still
        // grants hashing): bind a digest to the supplied caller data.
        let _digest = crypto::sha256(&ctx.contract_args);

        // Gate on the off-chain caller data: the spend is only authorized if the
        // caller presents the expected oracle token in `contract_args`.
        if !bytes_eq(&ctx.contract_args, ORACLE_TOKEN) {
            return Verdict::Deny(format!(
                "oracle token mismatch ({} bytes supplied)",
                ctx.contract_args.len()
            ));
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
