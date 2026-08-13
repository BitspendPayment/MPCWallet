//! OnboardingManager lifecycle tests. These exercise session creation,
//! TTL eviction, concurrent step1 dedup, and missing-session step2/3 paths
//! without driving a full 3-participant ceremony (which is covered E2E by
//! `e2e/test/ark_e2e_test.dart` and `bin/load_tester.rs`).

mod common;

use std::sync::Arc;
use std::time::Duration;

use tonic::Code;

use cosigner_runtime::onboarding::OnboardingManager;
use cosigner_runtime::wallet_proto::{DkgStep1Request, DkgStep2Request, DkgStep3Request};

fn dummy_identifier(seed: u8) -> Vec<u8> {
    let mut id = vec![0u8; 32];
    id[31] = seed;
    id
}

fn step1_req(seed: u8) -> DkgStep1Request {
    DkgStep1Request {
        user_id: hex::decode("a1b2c3d4e5f6071829").unwrap(),
        identifier: dummy_identifier(seed),
        round1_package: String::new(), // empty = passive receiver
    }
}

/// Spawn `coord.onboarding_step1(...)`. step1 responds immediately with the server's round1
/// package but registers a session (kept for step2/3) that the TTL sweep can later evict; the
/// returned JoinHandle can be `.abort()`-ed to avoid leaking the task on test exit.
fn spawn_step1(
    coord: Arc<OnboardingManager>,
    user_id: &'static str,
    seed: u8,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        let _ = coord.onboarding_step1(user_id, step1_req(seed)).await;
    })
}

#[tokio::test]
async fn test_dkg_session_evicted_after_ttl() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let coord = OnboardingManager::new(shared, Duration::from_millis(50));

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
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let coord = OnboardingManager::new(shared, Duration::from_secs(300));

    let h = spawn_step1(coord.clone(), "fresh", 1);
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert_eq!(coord.active_session_count(), 1);
    assert_eq!(coord.sweep_stale(), 0);
    assert_eq!(coord.active_session_count(), 1);

    h.abort();
}

#[tokio::test]
async fn test_concurrent_step1_creates_one_session() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let coord = OnboardingManager::new(shared, Duration::from_secs(300));

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
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let coord = OnboardingManager::new(shared, Duration::from_secs(300));

    let req = DkgStep3Request {
        user_id: hex::decode("a1b2c3d4e5f6071829").unwrap(),
        identifier: dummy_identifier(5),
        round2_packages_for_others: Default::default(),
    };
    let err = coord
        .onboarding_step3("abad1dea", req)
        .await
        .expect_err("expected Status::aborted");
    assert_eq!(err.code(), Code::Aborted);
}

#[tokio::test]
async fn test_step2_with_no_session_returns_aborted() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let coord = OnboardingManager::new(shared, Duration::from_secs(300));

    let req = DkgStep2Request {
        user_id: hex::decode("a1b2c3d4e5f6071829").unwrap(),
        identifier: dummy_identifier(6),
        round1_package: String::new(),
    };
    let err = coord
        .onboarding_step2("00112233", req)
        .await
        .expect_err("expected Status::aborted");
    assert_eq!(err.code(), Code::Aborted);
}
