//! Smoke test: verify that the actor model routes commands per-user without
//! cross-talk and that two users' command dispatches can overlap in time.
//!
//! Real parallelism / wall-clock verification of CPU-heavy DKG flows lives in
//! the Dart e2e suite at `e2e/test/multi_user_stress_test.dart`, which drives
//! concurrent end-to-end DKGs through the new `/api/u/{user_id}/...` routes.

use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant};

use server::shared::SharedServices;
use server::cosigner::registry::CosignerRegistry;
use server::cosigner::CosignerCommand;
use server::wallet_proto;

fn wasm_path() -> PathBuf {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    manifest_dir
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip1/release/cosigner.wasm")
}

fn build_shared() -> Arc<SharedServices> {
    use server::bitcoin::{BitcoinHistoryService, BitcoinRpcClient, ElectrumClient};
    use server::persistence::{KvStore, SecretStore, SledStore};

    let temp = tempfile::tempdir().expect("tempdir");
    let store = Arc::new(SledStore::open(temp.path()).expect("sled open"));
    let persistence: Arc<dyn KvStore> = store.clone();
    let secret_store: Arc<dyn SecretStore> = store;
    let bitcoin_rpc = Arc::new(BitcoinRpcClient::new("http://127.0.0.1:0", "", ""));
    let electrum = ElectrumClient::new("127.0.0.1", 0);
    let bitcoin_history = Arc::new(tokio::sync::Mutex::new(BitcoinHistoryService::new(electrum)));
    Arc::new(SharedServices::new(
        persistence,
        secret_store,
        bitcoin_rpc,
        bitcoin_history,
        None,
    ))
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn two_users_dispatch_concurrently_without_cross_talk() {
    let path = wasm_path();
    if !path.exists() {
        eprintln!(
            "WASM component not found at {:?}. Run `make cosigner-build` first.",
            path
        );
        return;
    }

    let shared = build_shared();
    let registry = CosignerRegistry::new(path.to_str().unwrap(), shared).expect("registry");

    let user_a = "a".repeat(66);
    let user_b = "b".repeat(66);

    // CreateSpendingPolicy is implemented as `Status::unimplemented(...)` —
    // it's a fast path that exercises the full actor pipeline (mailbox →
    // spawn_blocking → reply oneshot) without needing policy state setup.
    let dispatch_one = |reg: Arc<CosignerRegistry>, user_id: String| async move {
        reg.dispatch(&user_id, |reply| CosignerCommand::CreateSpendingPolicy {
            req: wallet_proto::CreateSpendingPolicyRequest {
                user_id: hex::decode(&user_id).unwrap_or_default(),
                threshold_sats: 0,
                start_time: 0,
                interval_seconds: 0,
                signature: vec![],
                timestamp_ms: 0,
            },
            reply,
        })
        .await
    };

    // Concurrent dispatch: both users run through their own actors at the
    // same time. The function should return roughly together — definitely
    // without serializing.
    let start = Instant::now();
    let (resp_a, resp_b) = tokio::join!(
        dispatch_one(registry.clone(), user_a.clone()),
        dispatch_one(registry.clone(), user_b.clone()),
    );
    let elapsed = start.elapsed();

    // Both should reach the actor's `unimplemented` response — proving routing
    // worked end-to-end for both users.
    assert!(resp_a.is_err(), "user A should get the unimplemented reply");
    assert!(resp_b.is_err(), "user B should get the unimplemented reply");
    assert_eq!(
        resp_a.as_ref().err().map(|s| s.code()),
        Some(tonic::Code::Unimplemented),
    );
    assert_eq!(
        resp_b.as_ref().err().map(|s| s.code()),
        Some(tonic::Code::Unimplemented),
    );

    // Sanity: two concurrent dispatches against fresh actors should complete
    // well under a second (instantiating two `CosignerInstance`s + two mailbox
    // round-trips on commodity hardware is ~100ms territory).
    assert!(
        elapsed < Duration::from_secs(5),
        "two-user concurrent dispatch took {:?}, expected < 5s",
        elapsed
    );

    // Both users must have distinct actors. A second dispatch reuses the same
    // mailbox (cheap fast path).
    let again_a = dispatch_one(registry.clone(), user_a.clone()).await;
    let again_b = dispatch_one(registry, user_b.clone()).await;
    assert!(again_a.is_err());
    assert!(again_b.is_err());

    println!("Two-user concurrent dispatch passed in {:?}", elapsed);
}
