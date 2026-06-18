//! Integration test: a full 2-of-2 FROST sign → aggregate round driven through the
//! cosigner guest's merged `session` resource.
//!
//! This exercises the exact path the session-merge refactor restructured: `new_nonce`
//! (which now stashes the single-use nonce *inside* the session), `frost_sign` (which
//! consumes that internal nonce — no nonce argument), and `frost_aggregate`. The
//! resulting signature is verified under the group key, so a regression in the
//! nonce handling or dispatch would fail here rather than only in a live e2e.
//!
//! The 2-of-2 key is produced host-side via `threshold::dkg` (the guest no longer does
//! DKG); only the signing operations go through the WASM guest.

use std::collections::BTreeMap;
use std::path::PathBuf;

use rand::rngs::OsRng;
use wasmtime::component::{Component, Linker, ResourceAny};
use wasmtime::{Config, Engine, Store};
use wasmtime_wasi::{ResourceTable, WasiCtx, WasiCtxBuilder, WasiView};

use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::point;
use threshold::random;
use threshold::scalar::{scalar_from_bytes, scalar_to_bytes};
use threshold::signature::Signature;

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

// The guest imports `contract-gate`; a 2-of-2 wallet spend isn't contract-gated, so a
// no-op (always-allow) host impl is correct here.
impl component::threshold::contract_gate::Host for TestWasiView {
    fn enforce(&mut self) -> Result<(), String> {
        Ok(())
    }
}

fn wasm_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip2/release/cosigner.wasm")
}

fn create_instance(
    engine: &Engine,
    component: &Component,
    linker: &Linker<TestWasiView>,
) -> (Store<TestWasiView>, ThresholdWorld) {
    let view = TestWasiView {
        table: ResourceTable::new(),
        ctx: WasiCtxBuilder::new().inherit_stdio().build(),
    };
    let mut store = Store::new(engine, view);
    let bindings = ThresholdWorld::instantiate(&mut store, component, linker).unwrap();
    (store, bindings)
}

/// Run a host-side 2-of-2 DKG via `threshold::dkg` and return the two even-Y-normalized
/// key packages plus the shared public-key package.
fn dkg_2of2() -> (Vec<KeyPackage>, PublicKeyPackage) {
    let mut rng = OsRng;
    let (min, max) = (2usize, 2usize);

    // Round 1.
    let mut r1_secrets = Vec::new();
    let mut r1_packages: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
    for _ in 0..max {
        let secret = random::mod_n_random(&mut rng);
        let coefficients: Vec<_> = (0..min - 1).map(|_| random::mod_n_random(&mut rng)).collect();
        let (secret_pkg, pub_pkg) =
            dkg::dkg_part1(max, min, &secret, &coefficients, &mut rng).expect("dkg_part1");
        r1_packages.insert(secret_pkg.identifier.clone(), pub_pkg);
        r1_secrets.push(secret_pkg);
    }

    // Round 2.
    let mut r2_secrets = Vec::new();
    let mut all_r2: Vec<BTreeMap<Identifier, Round2Package>> = Vec::new();
    for secret_pkg in &r1_secrets {
        let others: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != secret_pkg.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let (r2_secret, r2_out) = dkg::dkg_part2(secret_pkg, &others, &[]).expect("dkg_part2");
        r2_secrets.push(r2_secret);
        all_r2.push(r2_out);
    }

    // Round 3.
    let mut key_packages = Vec::new();
    let mut pkp_out: Option<PublicKeyPackage> = None;
    for (i, r2_secret) in r2_secrets.iter().enumerate() {
        let others_r1: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != r2_secret.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let mut our_r2: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
        for (j, r2_pkgs) in all_r2.iter().enumerate() {
            if j == i {
                continue;
            }
            if let Some(pkg) = r2_pkgs.get(&r2_secret.identifier) {
                our_r2.insert(r1_secrets[j].identifier.clone(), pkg.clone());
            }
        }
        let (kp, pkp) =
            dkg::dkg_part3(&r1_secrets[i], r2_secret, &others_r1, &our_r2, &[]).expect("dkg_part3");
        key_packages.push(kp.into_even_y());
        pkp_out = Some(pkp.into_even_y());
    }

    (key_packages, pkp_out.unwrap())
}

#[test]
fn cosigner_full_2of2_sign_and_aggregate() {
    let path = wasm_path();
    if !path.exists() {
        eprintln!("WASM component not found at {path:?}. Build the guest first.");
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

    // 2-of-2 key (host-side DKG).
    let (kps, pkp) = dkg_2of2();
    let pkp_json = pkp.to_json();
    let message = b"cosigner integration test: 2-of-2 spend";
    let message_hex = hex::encode(message);

    // Each signer gets its own guest instance + session, and generates its single-use
    // nonce there (stored inside the session). Collect (id_hex, kp_json, commitments).
    struct Signer {
        store: Store<TestWasiView>,
        bindings: ThresholdWorld,
        session: ResourceAny,
        id_hex: String,
        kp_json: String,
    }
    let mut signers = Vec::new();
    let mut commitments: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();

    for kp in &kps {
        let (mut store, bindings) = create_instance(&engine, &component, &linker);
        let session = bindings
            .component_threshold_types()
            .session()
            .call_constructor(&mut store)
            .unwrap();

        let id_hex = hex::encode(kp.identifier.serialize());
        let secret_hex = hex::encode(scalar_to_bytes(&kp.secret_share));

        let comms_json = bindings
            .component_threshold_types()
            .session()
            .call_new_nonce(&mut store, session, &secret_hex)
            .unwrap()
            .expect("new_nonce");
        let comms: serde_json::Value = serde_json::from_str(&comms_json).unwrap();
        commitments.insert(id_hex.clone(), comms);

        signers.push(Signer {
            store,
            bindings,
            session,
            id_hex,
            kp_json: kp.to_json(),
        });
    }

    // Build the signing package shared by both signers.
    let signing_package_json = serde_json::json!({
        "commitments": commitments,
        "message": message_hex,
    })
    .to_string();

    // Each signer produces its share via the session's stored nonce (no nonce arg).
    let mut shares: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();
    for s in &mut signers {
        let share_hex = s
            .bindings
            .component_threshold_types()
            .session()
            .call_frost_sign(&mut s.store, s.session, &signing_package_json, &s.kp_json)
            .unwrap()
            .expect("frost_sign");
        shares.insert(s.id_hex.clone(), serde_json::Value::String(share_hex));
    }
    let shares_json = serde_json::Value::Object(shares).to_string();

    // Aggregate on the first signer's session.
    let first = &mut signers[0];
    let agg_json = first
        .bindings
        .component_threshold_types()
        .session()
        .call_frost_aggregate(&mut first.store, first.session, &signing_package_json, &shares_json, &pkp_json)
        .unwrap()
        .expect("frost_aggregate");

    // Parse {R, Z} and verify under the group key.
    let agg: serde_json::Value = serde_json::from_str(&agg_json).unwrap();
    let r_bytes = hex::decode(agg["R"].as_str().unwrap()).unwrap();
    let z_bytes = hex::decode(agg["Z"].as_str().unwrap()).unwrap();
    let r_arr: [u8; 33] = r_bytes.try_into().expect("R is 33 bytes");
    let z_arr: [u8; 32] = z_bytes.try_into().expect("Z is 32 bytes");
    let r = point::deserialize_compressed(&r_arr).unwrap();
    let z = scalar_from_bytes(&z_arr).unwrap();
    let signature = Signature::new(r, z);

    signature
        .verify(&pkp.verifying_key, message)
        .expect("aggregated 2-of-2 signature must verify under the group key");

    println!("cosigner 2-of-2 sign + aggregate verified!");
}
