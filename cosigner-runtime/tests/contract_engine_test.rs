//! Exercises the contract engine end-to-end against the real `spending-limit`
//! example component. Proves: (1) a no_std contract importing ONLY `crypto`
//! instantiates in the strict NO-WASI linker, (2) the host `crypto` import works
//! through that sandbox, (3) allow/deny logic is honoured.
//!
//! Requires the example to be built first:
//!   (cd contracts/examples/spending-limit && cargo build --release)

use cosigner_runtime::contract::{
    ContractEngine, ContractHost, EvalContext, InMemoryRegistry, Transaction, Txout, Verdict,
};

fn wasm_path() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("contracts/examples/spending-limit/target/wasm32-wasip2/release/spending_limit.wasm")
}

fn ctx_with_total(value: u64) -> EvalContext {
    EvalContext {
        tx: Transaction {
            version: 2,
            lock_time: 0,
            inputs: vec![],
            outputs: vec![Txout {
                value,
                script_pubkey: vec![0x51], // OP_1
            }],
        },
        prevouts: vec![],
        input_index: 0,
        contract_args: vec![],
    }
}

#[test]
fn spending_limit_allows_under_and_denies_over() {
    let path = wasm_path();
    let wasm = std::fs::read(&path).unwrap_or_else(|_| {
        panic!(
            "contract not built at {}\n  run: (cd contracts/examples/spending-limit && cargo build --release)",
            path.display()
        )
    });

    let engine = ContractEngine::new().expect("engine");
    // If the contract imported any wasi:* this compile+instantiate path would
    // fail; success proves the strict no-WASI sandbox accepts it.
    let component = engine.compile(&wasm).expect("compile component");

    match engine.evaluate(&component, &ctx_with_total(50_000)) {
        Verdict::Allow => {}
        Verdict::Deny(r) => panic!("expected allow for 50_000 sats, got deny: {r}"),
    }

    match engine.evaluate(&component, &ctx_with_total(200_000)) {
        Verdict::Deny(_) => {}
        Verdict::Allow => panic!("expected deny for 200_000 sats (over 100_000 limit)"),
    }
}

#[test]
fn contract_host_resolves_by_id_and_gates() {
    let wasm = std::fs::read(wasm_path()).expect("build the spending-limit contract first");

    let mut reg = InMemoryRegistry::new();
    let id = reg.insert(wasm); // id == sha256(component bytes) == the on-chain contract_id
    let host = ContractHost::new(Box::new(reg)).expect("host");

    // Resolve-by-id, compile (cached), evaluate — the exact path the gate uses.
    assert!(matches!(
        host.evaluate_by_id(&id, &ctx_with_total(50_000)),
        Verdict::Allow
    ));
    assert!(matches!(
        host.evaluate_by_id(&id, &ctx_with_total(200_000)),
        Verdict::Deny(_)
    ));

    // Unknown id → fail-closed deny (registry NotFound), never a panic.
    assert!(matches!(
        host.evaluate_by_id(&[0u8; 32], &ctx_with_total(1)),
        Verdict::Deny(_)
    ));
}

#[test]
fn rejects_non_component_bytes() {
    let engine = ContractEngine::new().expect("engine");
    // Garbage / non-component bytes must not compile into a usable contract.
    assert!(engine.compile(b"not a wasm component").is_err());
}
