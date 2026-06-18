//! Contract creation: reshare `V→V′` between {user, cosigner} (steps 1-3), then a
//! single key-preserving refresh of `V′` onto the always-online SERVICE pairing
//! (step 4). The result is a 2-of-2 `V′` with two signing pairings stored as a
//! `ContractPolicy` on the USER's own policy:
//!
//!   (user_share + cosigner_shareA)  ||  (service_share + cosigner_shareB)
//!
//! Either pairing reconstructs `V′`; the cosigner is mandatory in both and gates
//! both at spend time. There is NO ECIES and NO async pickup — the service is
//! always online, so the user sends its service half-scalar `a@service` DIRECTLY
//! to the service (only the point `a@service·G` reaches the cosigner, so the
//! cosigner alone can never reconstruct `V′`). The cosigner delivers its half
//! `b@service` to the service synchronously over HTTP.
//!
//! Reuses the shared FROST `ceremony` core via `ContractSession`.

use std::sync::Arc;
use std::time::{Duration, Instant};

use dashmap::DashMap;
use parking_lot::Mutex;
use tokio::sync::oneshot;
use tokio::time::{interval, MissedTickBehavior};
use tonic::Status;

use crate::shared::SharedServices;
use crate::wallet_proto::{
    AssembleContractShareRequest, ContractContext, ContractCreateStep1Request,
    ContractCreateStep1Response, ContractCreateStep2Request, ContractCreateStep2Response,
    ContractCreateStep3Request, ContractCreateStep3Response, ContractCreateStep4Request,
    ContractCreateStep4Response,
};

use super::handler;
use super::session::ContractSession;

const EVICTION_TICK: Duration = Duration::from_secs(30);
const EVICT_MSG: &str = "contract-create session evicted: restart from step1";

pub struct ContractManager {
    sessions: DashMap<String, Arc<Mutex<ContractSession>>>,
    shared: Arc<SharedServices>,
    ttl: Duration,
}

impl ContractManager {
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

    fn get_or_create(&self, user_id: &str) -> Arc<Mutex<ContractSession>> {
        self.sessions
            .entry(user_id.to_string())
            .or_insert_with(|| Arc::new(Mutex::new(ContractSession::new())))
            .clone()
    }

    pub async fn create_contract_step_1(
        self: &Arc<Self>,
        user_id: &str,
        req: ContractCreateStep1Request,
    ) -> Result<ContractCreateStep1Response, Status> {
        let (tx, rx) = oneshot::channel();
        let sess = self.get_or_create(user_id);
        {
            let mut g = sess.lock();
            handler::reshare_round1(&mut g, &self.shared, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("contract-create session dropped reply"))?
    }

    pub async fn create_contract_step_2(
        self: &Arc<Self>,
        user_id: &str,
        req: ContractCreateStep2Request,
    ) -> Result<ContractCreateStep2Response, Status> {
        let sess = self
            .sessions
            .get(user_id)
            .map(|e| e.clone())
            .ok_or_else(|| Status::aborted(EVICT_MSG))?;
        let (tx, rx) = oneshot::channel();
        {
            let mut g = sess.lock();
            handler::reshare_round2(&mut g, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("contract-create session dropped reply"))?
    }

    pub async fn create_contract_step_3(
        self: &Arc<Self>,
        user_id: &str,
        req: ContractCreateStep3Request,
    ) -> Result<ContractCreateStep3Response, Status> {
        let sess = self
            .sessions
            .get(user_id)
            .map(|e| e.clone())
            .ok_or_else(|| Status::aborted(EVICT_MSG))?;
        let (tx, rx) = oneshot::channel();
        {
            let mut g = sess.lock();
            handler::reshare_round3(&mut g, &self.shared, req, tx);
        }
        // The session is kept alive until step4 (it still holds `service_vk`).
        rx.await
            .map_err(|_| Status::internal("contract-create session dropped reply"))?
    }

    pub async fn create_contract_step_4(
        self: &Arc<Self>,
        user_id: &str,
        req: ContractCreateStep4Request,
    ) -> Result<ContractCreateStep4Response, Status> {
        let sess = self
            .sessions
            .get(user_id)
            .map(|e| e.clone())
            .ok_or_else(|| Status::aborted(EVICT_MSG))?;
        // Compute the cosigner's service half + finalize the policy under the lock,
        // then deliver `b@service` to the service over HTTP outside the lock.
        let (group_id, b_at_service, context) = {
            let mut g = sess.lock();
            handler::reshare_round4(&mut g, &self.shared, &req)?
        };
        self.deliver_to_service(&group_id, &b_at_service, context)
            .await?;
        self.sessions.remove(user_id);
        Ok(ContractCreateStep4Response { ok: true })
    }

    /// POST the cosigner's `b@service` half + context to the always-online service.
    async fn deliver_to_service(
        &self,
        group_id_hex: &str,
        b_at_service: &[u8],
        context: ContractContext,
    ) -> Result<(), Status> {
        let base = self
            .shared
            .service_url
            .as_ref()
            .ok_or_else(|| Status::unavailable("contract-signer service not configured"))?;
        let url = format!("{}/assemble-contract-share", base.trim_end_matches('/'));
        let body = AssembleContractShareRequest {
            contract_group_id: hex::decode(group_id_hex).unwrap_or_default(),
            half_scalar: b_at_service.to_vec(),
            role: "cosigner".to_string(),
            context: Some(context),
        };
        let resp = reqwest::Client::new()
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| Status::unavailable(format!("service call failed: {e}")))?;
        if !resp.status().is_success() {
            return Err(Status::internal(format!(
                "service rejected share: HTTP {}",
                resp.status()
            )));
        }
        Ok(())
    }

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
            self.sessions.remove(uid);
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
