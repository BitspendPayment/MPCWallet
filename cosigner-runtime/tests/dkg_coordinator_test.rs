//! DkgCoordinator lifecycle tests. These exercise session creation,
//! TTL eviction, concurrent step1 dedup, and missing-session step2/3 paths
//! without driving a full 3-participant ceremony (which is covered E2E by
//! `e2e/test/ark_e2e_test.dart` and `bin/load_tester.rs`).

use std::sync::Arc;
use std::time::Duration;

use tempfile::TempDir;
use tokio::sync::Mutex as AsyncMutex;
use tonic::Code;

use cosigner_runtime::bitcoin::{BitcoinHistoryService, ElectrumClient};
use cosigner_runtime::dkg_coordinator::DkgCoordinator;
use cosigner_runtime::persistence::SledStore;
use cosigner_runtime::shared::SharedServices;
use cosigner_runtime::wallet_proto::{DkgStep1Request, DkgStep2Request, DkgStep3Request};

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
        1800,
    ));
    (shared, tmp)
}

fn dummy_identifier(seed: u8) -> Vec<u8> {
    let mut id = vec![0u8; 32];
    id[31] = seed;
    id
}

fn step1_req(seed: u8, is_restore: bool) -> DkgStep1Request {
    DkgStep1Request {
        user_id: hex::decode("a1b2c3d4e5f6071829").unwrap(),
        identifier: dummy_identifier(seed),
        round1_package: String::new(), // empty = passive receiver
        is_restore,
    }
}

/// Spawn `coord.dkg_step1(...)` and return immediately. step1 parks in
/// `pending_step1` waiting for the 2nd + 3rd participant; the returned
/// JoinHandle can be `.abort()`-ed to avoid leaking the task on test exit.
fn spawn_step1(
    coord: Arc<DkgCoordinator>,
    user_id: &'static str,
    seed: u8,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        let _ = coord.dkg_step1(user_id, step1_req(seed, false)).await;
    })
}

#[tokio::test]
async fn test_dkg_session_evicted_after_ttl() {
    let (shared, _tmp) = make_shared();
    let coord = DkgCoordinator::new(shared, Duration::from_millis(50));

    let h = spawn_step1(coord.clone(), "deadbeef", 1);
    // Let step1 actually run and register the session.
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert_eq!(coord.active_session_count(), 1);

    // Wait past TTL, then sweep.
    tokio::time::sleep(Duration::from_millis(100)).await;
    let evicted = coord.sweep_stale();
    assert_eq!(evicted, 1, "one session should evict");
    assert_eq!(coord.active_session_count(), 0);

    h.abort();
}

#[tokio::test]
async fn test_sweep_does_not_evict_fresh_sessions() {
    let (shared, _tmp) = make_shared();
    let coord = DkgCoordinator::new(shared, Duration::from_secs(300));

    let h = spawn_step1(coord.clone(), "fresh", 1);
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert_eq!(coord.active_session_count(), 1);
    assert_eq!(coord.sweep_stale(), 0);
    assert_eq!(coord.active_session_count(), 1);

    h.abort();
}

#[tokio::test]
async fn test_concurrent_step1_creates_one_session() {
    let (shared, _tmp) = make_shared();
    let coord = DkgCoordinator::new(shared, Duration::from_secs(300));

    // Two concurrent step1 calls for the same uid must dedupe through
    // DashMap::entry().or_insert_with. Both calls park; we just check count.
    let h1 = spawn_step1(coord.clone(), "cafebabe", 1);
    let h2 = spawn_step1(coord.clone(), "cafebabe", 2);

    tokio::time::sleep(Duration::from_millis(50)).await;
    assert_eq!(coord.active_session_count(), 1);

    h1.abort();
    h2.abort();
}

#[tokio::test]
async fn test_step3_with_no_session_returns_aborted() {
    let (shared, _tmp) = make_shared();
    let coord = DkgCoordinator::new(shared, Duration::from_secs(300));

    let req = DkgStep3Request {
        user_id: hex::decode("a1b2c3d4e5f6071829").unwrap(),
        identifier: dummy_identifier(5),
        round2_packages_for_others: Default::default(),
    };
    let err = coord
        .dkg_step3("abad1dea", req)
        .await
        .expect_err("expected Status::aborted");
    assert_eq!(err.code(), Code::Aborted);
}

#[tokio::test]
async fn test_step2_with_no_session_returns_aborted() {
    let (shared, _tmp) = make_shared();
    let coord = DkgCoordinator::new(shared, Duration::from_secs(300));

    let req = DkgStep2Request {
        user_id: hex::decode("a1b2c3d4e5f6071829").unwrap(),
        identifier: dummy_identifier(6),
        round1_package: String::new(),
    };
    let err = coord
        .dkg_step2("00112233", req)
        .await
        .expect_err("expected Status::aborted");
    assert_eq!(err.code(), Code::Aborted);
}

#[tokio::test]
async fn test_restore_with_unknown_recovery_id_returns_not_found() {
    let (shared, _tmp) = make_shared();
    let coord = DkgCoordinator::new(shared, Duration::from_secs(300));

    // `is_restore=true` with no prior policy in sled →
    // `step1_server_init::lookup_policy_by_recovery_id` returns `Ok(None)` →
    // step1 errors with NotFound (sent through reply, not stashed). This
    // exercises the path where the old WASM-mediated handler used
    // `user.policy_state.is_some()` as a reset guard; with the split that
    // guard is gone, but the lookup itself still fails cleanly.
    let err = coord
        .dkg_step1("11223344", step1_req(7, true))
        .await
        .expect_err("expected NotFound for unknown recovery id");
    assert_eq!(err.code(), Code::NotFound);
}
