//! `OnboardingManager` — process-global owner of in-flight Onboarding ceremonies.
//!
//! - One `OnboardingSession` per `user_id_hex`, wrapped in a `parking_lot::Mutex`
//!   inside a `DashMap`.
//! - Onboarding computations are sub-millisecond pure-Rust (no WASM); the lock is
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

use super::ceremony::{drain_pairs_with_err, drain_with_err};

use super::handlers;
use super::session::OnboardingSession;

const EVICTION_TICK: Duration = Duration::from_secs(30);
const EVICT_MSG: &str = "onboarding session evicted: restart from step1";

pub struct OnboardingManager {
    sessions: DashMap<String, Arc<Mutex<OnboardingSession>>>,
    shared: Arc<SharedServices>,
    /// Per-actor registry, used to seed freshly-created policy into the guest + seal it after
    /// DKG. `None` in unit tests that exercise the DKG handlers without the actor stack.
    registry: Option<Arc<crate::cosigner::registry::CosignerRegistry>>,
    ttl: Duration,
}

impl OnboardingManager {
    pub fn new(shared: Arc<SharedServices>, ttl: Duration) -> Arc<Self> {
        Self::new_inner(shared, None, ttl)
    }

    /// Production constructor: wires the registry so completed onboardings seed + seal the
    /// policy into the per-actor guest (no plaintext key kept host-side long-term).
    pub fn with_registry(
        shared: Arc<SharedServices>,
        registry: Arc<crate::cosigner::registry::CosignerRegistry>,
        ttl: Duration,
    ) -> Arc<Self> {
        Self::new_inner(shared, Some(registry), ttl)
    }

    fn new_inner(
        shared: Arc<SharedServices>,
        registry: Option<Arc<crate::cosigner::registry::CosignerRegistry>>,
        ttl: Duration,
    ) -> Arc<Self> {
        Arc::new(Self {
            sessions: DashMap::new(),
            shared,
            registry,
            ttl,
        })
    }

    pub fn active_session_count(&self) -> usize {
        self.sessions.len()
    }

    fn get_or_create(&self, user_id: &str) -> Arc<Mutex<OnboardingSession>> {
        self.sessions
            .entry(user_id.to_string())
            .or_insert_with(|| {
                tracing::info!(
                    user_id = %user_id,
                    onboarding_session_event = "created",
                    "onboarding session created"
                );
                Arc::new(Mutex::new(OnboardingSession::new(user_id.to_string())))
            })
            .clone()
    }

    pub async fn onboarding_step1(
        self: &Arc<Self>,
        user_id: &str,
        req: DkgStep1Request,
    ) -> Result<DkgStep1Response, Status> {
        let (tx, rx) = oneshot::channel();
        let sess = self.get_or_create(user_id);
        {
            let mut guard = sess.lock();
            handlers::onboarding_step1(&mut guard, &self.shared, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("onboarding session dropped reply"))?
    }

    pub async fn onboarding_step2(
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
            handlers::onboarding_step2(&mut guard, &self.shared, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("onboarding session dropped reply"))?
    }

    pub async fn onboarding_step3(
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
        let (finalized, seed_material) = {
            let mut guard = sess.lock();
            let f = handlers::onboarding_step3(&mut guard, &self.shared, req, tx);
            (f, guard.seed_material.take())
        };
        if finalized {
            self.sessions.remove(user_id);
            tracing::info!(
                user_id = %user_id,
                onboarding_session_event = "completed",
                "onboarding session completed"
            );
            // MANDATORY seed (Plan A): install the freshly-minted key INTO the guest from the
            // in-memory material + seal it. There is NO plaintext fallback — `policies` holds only
            // the public projection — so if this fails the wallet has no usable cosigner key and
            // onboarding MUST fail (the user re-onboards; no funds exist yet).
            if let Some(registry) = self.registry.clone() {
                let mat = seed_material
                    .ok_or_else(|| Status::internal("onboarding finalized without seed material"))?;
                self.seed_guest_mandatory(&registry, &mat).await?;
            }
        }
        rx.await
            .map_err(|_| Status::internal("onboarding session dropped reply"))?
    }

    /// Install the just-created policy into the per-actor guest + seal it (best-effort).
    /// Seed the freshly-minted key INTO the guest from the IN-MEMORY material + seal it. The key
    /// is never read back from `policies` (which holds only the public projection). Returns Err on
    /// failure so onboarding fails — there is no plaintext fallback (Plan A).
    async fn seed_guest_mandatory(
        self: &Arc<Self>,
        registry: &Arc<crate::cosigner::registry::CosignerRegistry>,
        mat: &crate::onboarding::session::SeedMaterial,
    ) -> Result<(), Status> {
        let group_key = mat.group_key.clone();
        let kp = mat.key_package_json.clone();
        let pkp = mat.public_key_package_json.clone();
        let usid = mat.user_signing_identifier_hex.clone();
        let secret = mat.server_dkg_secret_hex.clone();
        registry
            .dispatch(&group_key, |reply| {
                crate::cosigner::command::CosignerCommand::SeedPolicy {
                    key_package_json: kp,
                    public_key_package_json: pkp,
                    user_signing_identifier_hex: usid,
                    server_dkg_secret_hex: secret,
                    contract_pairing: None, // a normal wallet actor has no pairing conditioning
                    reply,
                }
            })
            .await
            .map_err(|e| {
                tracing::error!("[{group_key}] onboarding seed-into-guest FAILED: {e}");
                Status::internal(format!("onboarding seed-into-guest failed: {e}"))
            })?;
        tracing::info!("[{group_key}] onboarding seeded key into guest + sealed");
        Ok(())
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
                drain_pairs_with_err(&mut s.pending_step3, EVICT_MSG);
                tracing::info!(
                    user_id = %uid,
                    onboarding_session_event = "evicted",
                    "onboarding session evicted"
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
