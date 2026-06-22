//! Phase 2b-ii foundation: the `CosignerRegistry` owns the native-async guest stack and
//! can instantiate a `GuestInstance` wired to its shared services (so the guest's
//! `contract-gate` import enforces real contracts). Verifies a round-trip through a
//! registry-spawned guest. The actual SignStep1/2 reroute builds on this.

use std::path::PathBuf;
use std::sync::Arc;

use tempfile::TempDir;
use tokio::sync::Mutex as AsyncMutex;

use cosigner_proto::{GuestCommand, GuestResponse};
use cosigner_runtime::bitcoin::{BitcoinHistoryService, ElectrumClient};
use cosigner_runtime::cosigner::registry::CosignerRegistry;
use cosigner_runtime::persistence::SledStore;
use cosigner_runtime::shared::SharedServices;

fn guest_wasm_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip2/release/cosigner.wasm")
}

fn make_shared() -> (Arc<SharedServices>, TempDir) {
    let tmp = TempDir::new().unwrap();
    let store = Arc::new(SledStore::open(tmp.path()).unwrap());
    let electrum = ElectrumClient::new("127.0.0.1", 50001);
    let bitcoin_history = Arc::new(AsyncMutex::new(BitcoinHistoryService::new(electrum)));
    let shared = Arc::new(SharedServices::new(
        store.clone(),
        store,
        bitcoin_history,
        None,
        None,
        None,
        1800,
        1800,
    ));
    (shared, tmp)
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn registry_spawns_guest_and_round_trips() {
    let guest = guest_wasm_path();
    if !guest.exists() {
        eprintln!("cosigner-guest not built ({guest:?}); skipping.");
        return;
    }
    let (shared, _tmp) = make_shared();
    let registry = CosignerRegistry::new(guest.to_str().unwrap(), shared).unwrap();

    // Instantiate a guest from the registry's async stack (contract-gate wired to shared).
    let mut guest = registry.spawn_guest_instance().await.unwrap();
    let resp = guest.command(GuestCommand::Ping).await.unwrap();
    assert!(matches!(resp, GuestResponse::Pong), "got {resp:?}");
}
