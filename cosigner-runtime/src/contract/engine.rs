//! The contract engine: the native host instantiates a user contract component
//! in a strict NO-WASI sandbox, feeds it the transaction, and returns its
//! allow/deny verdict. A wasm guest (the cosigner) cannot do this — only the
//! native wasmtime host can instantiate components — so this lives host-side and
//! gates the cosigner's signature (see handlers/sign.rs).

use wasmtime::component::{Component, Linker};
use wasmtime::{Config, Engine, Store, StoreLimits, StoreLimitsBuilder};

use crate::contract::crypto_host;

wasmtime::component::bindgen!({
    path: "wit/contract.wit",
    world: "contract",
    async: false,
});

// `EvalContext` and `Verdict` are already at this module's root (the world's
// `use tx.{…}`). Surface the remaining tx records so callers can build a context
// without knowing the generated WIT path.
pub use self::bitcoin::contract::tx::{Outpoint, PrevoutInfo, Transaction, Txin, Txout};

/// CPU bound (deterministic): contracts that exceed this are denied, never hang.
const MAX_FUEL: u64 = 1_000_000_000;
/// Linear-memory cap for a contract instance.
const MAX_MEMORY: usize = 64 * 1024 * 1024;

/// Per-evaluation store state: just the resource limiter. The contract gets no
/// host state beyond the `crypto` import.
struct ContractState {
    limits: StoreLimits,
}

impl self::bitcoin::contract::crypto::Host for ContractState {
    fn sha256(&mut self, data: Vec<u8>) -> Vec<u8> {
        crypto_host::sha256(&data)
    }
    fn hash256(&mut self, data: Vec<u8>) -> Vec<u8> {
        crypto_host::hash256(&data)
    }
    fn ripemd160(&mut self, data: Vec<u8>) -> Vec<u8> {
        crypto_host::ripemd160(&data)
    }
    fn hash160(&mut self, data: Vec<u8>) -> Vec<u8> {
        crypto_host::hash160(&data)
    }
    fn tagged_hash(&mut self, tag: String, msg: Vec<u8>) -> Vec<u8> {
        crypto_host::tagged_hash(&tag, &msg)
    }
    fn schnorr_verify(&mut self, pubkey: Vec<u8>, msg: Vec<u8>, sig: Vec<u8>) -> bool {
        crypto_host::schnorr_verify(&pubkey, &msg, &sig)
    }
}

/// Shared wasmtime engine for contract evaluation. Configured for sandboxing
/// (fuel + memory limits) and determinism (NaN canonicalization). Clone-cheap.
pub struct ContractEngine {
    engine: Engine,
}

impl ContractEngine {
    pub fn new() -> wasmtime::Result<Self> {
        let mut config = Config::new();
        config.wasm_component_model(true);
        config.consume_fuel(true);
        config.cranelift_nan_canonicalization(true);
        Ok(Self {
            engine: Engine::new(&config)?,
        })
    }

    /// Compile fetched contract bytes into a reusable `Component`. Callers cache
    /// the result keyed by content hash (compilation is expensive).
    pub fn compile(&self, wasm: &[u8]) -> wasmtime::Result<Component> {
        Component::from_binary(&self.engine, wasm)
    }

    /// Evaluate a contract against a transaction context in a NO-WASI sandbox.
    /// Any failure mode (forbidden wasi import, trap, OOM, out-of-fuel) maps to
    /// `Verdict::Deny` — fail-closed.
    pub fn evaluate(&self, component: &Component, ctx: &EvalContext) -> Verdict {
        let state = ContractState {
            // Memory + fuel are the real DoS bounds. A single component expands
            // to several core instances (component wrapper + inner module +
            // import adapters), so the instance cap only needs headroom.
            limits: StoreLimitsBuilder::new()
                .memory_size(MAX_MEMORY)
                .instances(64)
                .build(),
        };
        let mut store = Store::new(&self.engine, state);
        store.limiter(|s| &mut s.limits);
        if store.set_fuel(MAX_FUEL).is_err() {
            return Verdict::Deny("failed to set fuel".into());
        }

        // Strict linker: ONLY `crypto`. We deliberately never call
        // wasmtime_wasi::add_to_linker_sync, so any contract importing wasi:*
        // fails to instantiate below.
        let mut linker = Linker::new(&self.engine);
        if let Err(e) = self::bitcoin::contract::crypto::add_to_linker(&mut linker, |s| s) {
            return Verdict::Deny(format!("linker setup: {e}"));
        }

        let bindings = match Contract::instantiate(&mut store, component, &linker) {
            Ok(b) => b,
            Err(e) => return Verdict::Deny(format!("instantiate (forbidden import?): {e}")),
        };
        match bindings.call_evaluate(&mut store, ctx) {
            Ok(v) => v,
            Err(e) => Verdict::Deny(format!("trap/limit: {e}")),
        }
    }
}
