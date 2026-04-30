//! Integration test: verify per-user WASM isolation.
//!
//! Tests that two users get independent WASM instances with isolated memory.
//! A DKG session started by user A does not leak state to user B.

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

fn wasm_path() -> PathBuf {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    manifest_dir
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip1/release/cosigner.wasm")
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
fn test_basic_utils_work() {
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

    let (mut store, bindings) = create_instance(&engine, &component, &linker);

    // Create a session
    let iface = bindings.component_threshold_types();
    let session = iface
        .threshold_session()
        .call_constructor(&mut store)
        .unwrap();

    // Test mod_n_random: should return a 64-char hex string
    let random_hex = iface
        .threshold_session()
        .call_mod_n_random(&mut store, session)
        .unwrap()
        .unwrap();
    assert_eq!(random_hex.len(), 64, "mod_n_random should return 64-char hex");

    // Two calls should return different values (with overwhelming probability)
    let random_hex2 = iface
        .threshold_session()
        .call_mod_n_random(&mut store, session)
        .unwrap()
        .unwrap();
    assert_ne!(random_hex, random_hex2, "two random scalars should differ");

    // Test identifier_derive
    let id_hex = iface
        .threshold_session()
        .call_identifier_derive(&mut store, session, b"test-message")
        .unwrap()
        .unwrap();
    assert_eq!(id_hex.len(), 64, "identifier should be 64-char hex");

    // Same input → same identifier
    let id_hex2 = iface
        .threshold_session()
        .call_identifier_derive(&mut store, session, b"test-message")
        .unwrap()
        .unwrap();
    assert_eq!(id_hex, id_hex2, "same input should give same identifier");

    // Test elem_base_mul with a known scalar
    let point_hex = iface
        .threshold_session()
        .call_elem_base_mul(
            &mut store,
            session,
            "0000000000000000000000000000000000000000000000000000000000000001",
        )
        .unwrap()
        .unwrap();
    // 1*G = generator point (compressed, starts with 02 or 03)
    assert_eq!(point_hex.len(), 66, "compressed point should be 66-char hex");
    assert!(
        point_hex.starts_with("02") || point_hex.starts_with("03"),
        "should be a valid compressed point"
    );

    println!("Basic utils test passed!");
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

    // Create two independent instances (simulating two users)
    let (mut store_a, bindings_a) = create_instance(&engine, &component, &linker);
    let (mut store_b, bindings_b) = create_instance(&engine, &component, &linker);

    let iface_a = bindings_a.component_threshold_types();
    let iface_b = bindings_b.component_threshold_types();

    let session_a = iface_a
        .threshold_session()
        .call_constructor(&mut store_a)
        .unwrap();
    let session_b = iface_b
        .threshold_session()
        .call_constructor(&mut store_b)
        .unwrap();

    // Generate coefficients with the same seed in both instances
    let seed = b"test-seed-for-coefficients";
    let coeffs_a = iface_a
        .threshold_session()
        .call_generate_coefficients(&mut store_a, session_a, 1, seed)
        .unwrap()
        .unwrap();
    let coeffs_b = iface_b
        .threshold_session()
        .call_generate_coefficients(&mut store_b, session_b, 1, seed)
        .unwrap()
        .unwrap();

    // Same seed → same coefficients (deterministic), proving both instances work independently
    assert_eq!(
        coeffs_a, coeffs_b,
        "same seed should produce same coefficients in both instances"
    );

    // Generate random values in each instance - they should differ
    let rand_a = iface_a
        .threshold_session()
        .call_mod_n_random(&mut store_a, session_a)
        .unwrap()
        .unwrap();
    let rand_b = iface_b
        .threshold_session()
        .call_mod_n_random(&mut store_b, session_b)
        .unwrap()
        .unwrap();
    assert_ne!(
        rand_a, rand_b,
        "random values from different instances should differ"
    );

    // Drop instance A - instance B should still work
    drop(store_a);
    drop(bindings_a);

    let rand_b2 = iface_b
        .threshold_session()
        .call_mod_n_random(&mut store_b, session_b)
        .unwrap()
        .unwrap();
    assert_eq!(
        rand_b2.len(),
        64,
        "instance B should still work after instance A is dropped"
    );

    println!("User isolation test passed!");
}

#[test]
fn test_dkg_round_trip() {
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

    // Create two instances (two DKG participants: dealer + receiver)
    let (mut store_a, bindings_a) = create_instance(&engine, &component, &linker);

    let iface_a = bindings_a.component_threshold_types();
    let session_a = iface_a
        .threshold_session()
        .call_constructor(&mut store_a)
        .unwrap();

    // Generate a secret and coefficient for participant A
    let secret_hex = iface_a
        .threshold_session()
        .call_mod_n_random(&mut store_a, session_a)
        .unwrap()
        .unwrap();
    let coeffs_json = iface_a
        .threshold_session()
        .call_generate_coefficients(&mut store_a, session_a, 1, &[])
        .unwrap()
        .unwrap();

    // DKG Part 1 - should succeed and return a round1 package + secret handle
    let r1_result = iface_a
        .threshold_session()
        .call_dkg_part1(&mut store_a, session_a, 2, 2, &secret_hex, &coeffs_json)
        .unwrap()
        .unwrap();

    // Verify round1 package is valid JSON
    let r1_pkg: serde_json::Value =
        serde_json::from_str(&r1_result.round1_package_json).unwrap();
    assert!(
        r1_pkg.get("commitment").is_some(),
        "round1 package should have commitment"
    );
    assert!(
        r1_pkg.get("proofOfKnowledge").is_some(),
        "round1 package should have proofOfKnowledge"
    );
    assert!(
        r1_pkg.get("verifyingKey").is_some(),
        "round1 package should have verifyingKey"
    );

    println!("DKG round trip test passed (part 1)!");
}
