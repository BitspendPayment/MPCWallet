//! Example contract TEMPLATE: same gate as `oracle-gate`, but the oracle token + spend limit
//! are NOT hardcoded — they are read as TYPED, per-instance config via the imported
//! `author:config/vars` interface (`get-bytes("oracle-token")`, `get-u64("max-sats")`). The
//! cosigner synthesizes a generic provider from the author's config and composes it into this
//! template before the contract is evaluated.
#![no_std]

extern crate alloc;

use alloc::format;

contract_sdk::runtime!();

wit_bindgen::generate!({
    world: "contract",
    path: "wit",
    generate_all,
});

use crate::bitcoin::contract::crypto;
use crate::oracle::gate::config;

fn bytes_eq(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

struct Component;

impl Guest for Component {
    fn evaluate(ctx: EvalContext) -> Verdict {
        // TYPED, NAMED, self-documenting per-instance config (set by the author at creation).
        let token = config::oracle_token();
        let limit = config::max_sats();
        if token.is_empty() {
            return Verdict::Deny("config missing oracle-token".into());
        }

        // Exercise the host `crypto` import (proves the no-WASI sandbox still grants hashing).
        let _digest = crypto::sha256(&ctx.contract_args);

        if !bytes_eq(&ctx.contract_args, &token) {
            return Verdict::Deny(format!(
                "oracle token mismatch ({} bytes supplied)",
                ctx.contract_args.len()
            ));
        }

        let total: u64 = ctx.tx.outputs.iter().map(|o| o.value).sum();
        if total > limit {
            Verdict::Deny(format!("total {total} sats exceeds limit {limit}"))
        } else {
            Verdict::Allow
        }
    }
}

export!(Component);
