//! Integration test: verify per-user WASM isolation.
//!
//! Tests that two users get independent WASM instances with isolated memory:
//! deterministic ops match across instances while random ops differ, and dropping
//! one instance leaves the other working.

use std::path::PathBuf;

use wasmtime::component::{Component, Linker};
use wasmtime::{Config, Engine, Store};
use wasmtime_wasi::{ResourceTable, WasiCtx, WasiCtxBuilder, WasiView};

// Reuse the bindgen from the main crate
wasmtime::component::bindgen!({
    path: "wit/world.wit",
    world: "threshold-world",
    async: false,
});

struct TestWasiView {
    table: ResourceTable,
    ctx: WasiCtx,
}

impl WasiView for TestWasiView {
    fn table(&mut self) -> &mut ResourceTable {
        &mut self.table
    }
    fn ctx(&mut self) -> &mut WasiCtx {
        &mut self.ctx
    }
}

// The guest imports `contract-gate`; these isolation tests don't exercise it, so
// satisfy the import with a no-op (always-allow) host impl.
impl component::threshold::contract_gate::Host for TestWasiView {
    fn enforce(&mut self) -> Result<(), String> {
        Ok(())
    }
}

fn wasm_path() -> PathBuf {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    manifest_dir
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip2/release/cosigner.wasm")
}

fn create_instance(
    engine: &Engine,
    component: &Component,
    linker: &Linker<TestWasiView>,
) -> (Store<TestWasiView>, ThresholdWorld) {
    let wasi_ctx = WasiCtxBuilder::new().inherit_stdio().build();
    let view = TestWasiView {
        table: ResourceTable::new(),
        ctx: wasi_ctx,
    };
    let mut store = Store::new(engine, view);
    let bindings = ThresholdWorld::instantiate(&mut store, component, linker).unwrap();
    (store, bindings)
}

#[test]
fn test_basic_session_ops() {
    let path = wasm_path();
    if !path.exists() {
        eprintln!(
            "WASM component not found at {:?}. Run `make cosigner-build` first.",
            path
        );
        return;
    }

    let mut config = Config::new();
    config.wasm_component_model(true);
    let engine = Engine::new(&config).unwrap();
    let component = Component::from_file(&engine, &path).unwrap();
    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker_sync(&mut linker).unwrap();
    component::threshold::contract_gate::add_to_linker(&mut linker, |v: &mut TestWasiView| v)
        .unwrap();

    let (mut store, bindings) = create_instance(&engine, &component, &linker);
    let iface = bindings.component_threshold_types();
    let session = iface.session().call_constructor(&mut store).unwrap();

    // identifier_derive: deterministic, 64-char hex.
    let id_hex = iface
        .session()
        .call_identifier_derive(&mut store, session, b"test-message")
        .unwrap()
        .unwrap();
    assert_eq!(id_hex.len(), 64, "identifier should be 64-char hex");
    let id_hex2 = iface
        .session()
        .call_identifier_derive(&mut store, session, b"test-message")
        .unwrap()
        .unwrap();
    assert_eq!(id_hex, id_hex2, "same input should give same identifier");

    // new_nonce: returns commitments JSON and stashes the single-use nonce internally.
    let secret = "0000000000000000000000000000000000000000000000000000000000000001";
    let comms1 = iface
        .session()
        .call_new_nonce(&mut store, session, secret)
        .unwrap()
        .unwrap();
    assert!(comms1.contains("hiding") && comms1.contains("binding"));
    let comms2 = iface
        .session()
        .call_new_nonce(&mut store, session, secret)
        .unwrap()
        .unwrap();
    assert_ne!(comms1, comms2, "each nonce's commitments should be fresh/random");

    // Ceremony-state round-trip.
    iface
        .session()
        .call_set_message_to_sign(&mut store, session, "deadbeef")
        .unwrap();
    assert!(iface.session().call_has_message(&mut store, session).unwrap());
    assert_eq!(
        iface
            .session()
            .call_get_message_to_sign(&mut store, session)
            .unwrap(),
        "deadbeef"
    );

    println!("Basic session ops test passed!");
}

#[test]
fn test_user_isolation() {
    let path = wasm_path();
    if !path.exists() {
        eprintln!(
            "WASM component not found at {:?}. Run `make cosigner-build` first.",
            path
        );
        return;
    }

    let mut config = Config::new();
    config.wasm_component_model(true);
    let engine = Engine::new(&config).unwrap();
    let component = Component::from_file(&engine, &path).unwrap();
    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker_sync(&mut linker).unwrap();
    component::threshold::contract_gate::add_to_linker(&mut linker, |v: &mut TestWasiView| v)
        .unwrap();

    // Two independent instances (simulating two users).
    let (mut store_a, bindings_a) = create_instance(&engine, &component, &linker);
    let (mut store_b, bindings_b) = create_instance(&engine, &component, &linker);

    let iface_a = bindings_a.component_threshold_types();
    let iface_b = bindings_b.component_threshold_types();
    let session_a = iface_a.session().call_constructor(&mut store_a).unwrap();
    let session_b = iface_b.session().call_constructor(&mut store_b).unwrap();

    // Deterministic op: same input → same output across instances (both work).
    let id_a = iface_a
        .session()
        .call_identifier_derive(&mut store_a, session_a, b"x")
        .unwrap()
        .unwrap();
    let id_b = iface_b
        .session()
        .call_identifier_derive(&mut store_b, session_b, b"x")
        .unwrap()
        .unwrap();
    assert_eq!(id_a, id_b, "deterministic op must agree across instances");

    // Memory isolation: state set in A must NOT be visible in B.
    iface_a
        .session()
        .call_set_message_to_sign(&mut store_a, session_a, "aabb")
        .unwrap();
    assert!(iface_a.session().call_has_message(&mut store_a, session_a).unwrap());
    assert!(
        !iface_b.session().call_has_message(&mut store_b, session_b).unwrap(),
        "instance B must not see instance A's message"
    );

    // Random op: nonces from different instances differ.
    let secret = "0000000000000000000000000000000000000000000000000000000000000001";
    let comms_a = iface_a
        .session()
        .call_new_nonce(&mut store_a, session_a, secret)
        .unwrap()
        .unwrap();
    let comms_b = iface_b
        .session()
        .call_new_nonce(&mut store_b, session_b, secret)
        .unwrap()
        .unwrap();
    assert_ne!(comms_a, comms_b, "nonces from different instances should differ");

    // Drop instance A — instance B still works.
    drop(store_a);
    drop(bindings_a);
    assert!(iface_b.session().call_has_message(&mut store_b, session_b).unwrap() == false);

    println!("User isolation test passed!");
}
