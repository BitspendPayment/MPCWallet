//! `DkgCoordinator` — process-global owner of in-flight DKG ceremonies.
//!
//! - One `DkgSession` per `user_id_hex`, wrapped in a `parking_lot::Mutex`
//!   inside a `DashMap`.
//! - DKG computations are sub-millisecond pure-Rust (no WASM); the lock is
//!   never held across `await`, so we don't need `spawn_blocking`.
//! - Sessions are evicted by a background sweep after `ttl` of inactivity,
//!   or removed immediately when step3 finalizes.

use std::sync::Arc;
use std::time::{Duration, Instant};

use dashmap::DashMap;
use parking_lot::Mutex;
use tokio::sync::oneshot;
use tokio::time::{interval, MissedTickBehavior};
use tonic::Status;

use crate::shared::SharedServices;
use crate::wallet_proto::{
    DkgStep1Request, DkgStep1Response, DkgStep2Request, DkgStep2Response, DkgStep3Request,
    DkgStep3Response,
};

use super::handlers::{self, drain_pairs_with_err, drain_with_err};
use super::session::DkgSession;

const EVICTION_TICK: Duration = Duration::from_secs(30);
const EVICT_MSG: &str = "dkg session evicted: restart from step1";

pub struct DkgCoordinator {
    sessions: DashMap<String, Arc<Mutex<DkgSession>>>,
    shared: Arc<SharedServices>,
    ttl: Duration,
}

impl DkgCoordinator {
    pub fn new(shared: Arc<SharedServices>, ttl: Duration) -> Arc<Self> {
        Arc::new(Self {
            sessions: DashMap::new(),
            shared,
            ttl,
        })
    }

    pub fn active_session_count(&self) -> usize {
        self.sessions.len()
    }

    fn get_or_create(&self, user_id: &str) -> Arc<Mutex<DkgSession>> {
        self.sessions
            .entry(user_id.to_string())
            .or_insert_with(|| {
                tracing::info!(
                    user_id = %user_id,
                    dkg_session_event = "created",
                    "DKG session created"
                );
                Arc::new(Mutex::new(DkgSession::new(user_id.to_string())))
            })
            .clone()
    }

    pub async fn dkg_step1(
        self: &Arc<Self>,
        user_id: &str,
        req: DkgStep1Request,
    ) -> Result<DkgStep1Response, Status> {
        let (tx, rx) = oneshot::channel();
        let sess = self.get_or_create(user_id);
        {
            let mut guard = sess.lock();
            handlers::dkg_step1(&mut guard, &self.shared, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("dkg session dropped reply"))?
    }

    pub async fn dkg_step2(
        self: &Arc<Self>,
        user_id: &str,
        req: DkgStep2Request,
    ) -> Result<DkgStep2Response, Status> {
        let sess = self
            .sessions
            .get(user_id)
            .map(|e| e.clone())
            .ok_or_else(|| Status::aborted(EVICT_MSG))?;
        let (tx, rx) = oneshot::channel();
        {
            let mut guard = sess.lock();
            handlers::dkg_step2(&mut guard, &self.shared, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("dkg session dropped reply"))?
    }

    pub async fn dkg_step3(
        self: &Arc<Self>,
        user_id: &str,
        req: DkgStep3Request,
    ) -> Result<DkgStep3Response, Status> {
        let sess = self
            .sessions
            .get(user_id)
            .map(|e| e.clone())
            .ok_or_else(|| Status::aborted(EVICT_MSG))?;
        let (tx, rx) = oneshot::channel();
        let finalized = {
            let mut guard = sess.lock();
            handlers::dkg_step3(&mut guard, &self.shared, req, tx)
        };
        if finalized {
            self.sessions.remove(user_id);
            tracing::info!(
                user_id = %user_id,
                dkg_session_event = "completed",
                "DKG session completed"
            );
        }
        rx.await
            .map_err(|_| Status::internal("dkg session dropped reply"))?
    }

    /// Run one eviction sweep: remove and drain any session whose
    /// `last_touch` is older than `ttl`. Returns the number of sessions
    /// evicted. Exposed publicly so tests can drive eviction without
    /// waiting for the 30s production tick.
    pub fn sweep_stale(&self) -> usize {
        let now = Instant::now();
        let stale: Vec<String> = self
            .sessions
            .iter()
            .filter_map(|e| {
                let s = e.value().lock();
                if now.duration_since(s.last_touch) > self.ttl {
                    Some(e.key().clone())
                } else {
                    None
                }
            })
            .collect();
        let n = stale.len();
        for uid in &stale {
            if let Some((_, sess_arc)) = self.sessions.remove(uid) {
                let mut s = sess_arc.lock();
                drain_with_err(&mut s.pending_step1, EVICT_MSG);
                drain_with_err(&mut s.pending_step2, EVICT_MSG);
                drain_pairs_with_err(&mut s.pending_step3, EVICT_MSG);
                tracing::info!(
                    user_id = %uid,
                    dkg_session_event = "evicted",
                    "DKG session evicted"
                );
            }
        }
        n
    }

    pub async fn run_eviction_loop(self: Arc<Self>) {
        let mut tick = interval(EVICTION_TICK);
        tick.set_missed_tick_behavior(MissedTickBehavior::Delay);
        loop {
            tick.tick().await;
            self.sweep_stale();
        }
    }
}
