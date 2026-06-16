//! Contract creation: reshare `V→V′` between {user, cosigner} (steps 1-3), then a
//! single key-preserving refresh of `V′` onto the always-online SERVICE pairing
//! (step 4). The result is a 2-of-2 `V′` with two signing pairings stored as an
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
//! Reuses the DKG rendezvous infra (`DkgSession`, `conv`, drain helpers).

use std::collections::{BTreeMap, HashMap};
use std::sync::Arc;
use std::time::{Duration, Instant};

use dashmap::DashMap;
use parking_lot::Mutex;
use rand::rngs::OsRng;
use rand::Rng;
use tokio::sync::oneshot;
use tokio::time::{interval, MissedTickBehavior};
use tonic::Status;

use threshold::dkg;
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage, VerifyingKey};
use threshold::point;
use threshold::random;
use threshold::scalar::{scalar_from_bytes, scalar_to_bytes};

use crate::contract;
use crate::cosigner::handlers::{contract_gate, parsers};
use crate::policy::store::persist_policy;
use crate::policy::{ContractPolicy, CosignerShare, PolicyState};
use crate::shared::SharedServices;
use crate::wallet_proto::{
    AssembleContractShareRequest, ContractContext, ContractCreateStep1Request,
    ContractCreateStep1Response, ContractCreateStep2Request, ContractCreateStep2Response,
    ContractCreateStep3Request, ContractCreateStep3Response, ContractCreateStep4Request,
    ContractCreateStep4Response,
};

use crate::onboarding::conv;
use crate::onboarding::handlers::{drain_pairs_with_err, drain_with_err, Reply};
use crate::onboarding::session::DkgSession;

const EVICTION_TICK: Duration = Duration::from_secs(30);
const EVICT_MSG: &str = "contract-create session evicted: restart from step1";
const TOTAL_PARTICIPANTS: usize = 2; // user + cosigner — both dealers + final shareholders
const THRESHOLD_COUNT: usize = 2; // resulting key is 2-of-2

pub struct ContractCreateCoordinator {
    sessions: DashMap<String, Arc<Mutex<DkgSession>>>,
    shared: Arc<SharedServices>,
    ttl: Duration,
}

impl ContractCreateCoordinator {
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
            .or_insert_with(|| Arc::new(Mutex::new(DkgSession::new(user_id.to_string()))))
            .clone()
    }

    pub async fn step1(
        self: &Arc<Self>,
        user_id: &str,
        req: ContractCreateStep1Request,
    ) -> Result<ContractCreateStep1Response, Status> {
        let (tx, rx) = oneshot::channel();
        let sess = self.get_or_create(user_id);
        {
            let mut g = sess.lock();
            step1(&mut g, &self.shared, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("contract-create session dropped reply"))?
    }

    pub async fn step2(
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
            step2(&mut g, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("contract-create session dropped reply"))?
    }

    pub async fn step3(
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
            step3(&mut g, &self.shared, req, tx);
        }
        // The session is kept alive until step4 (it still holds `service_vk`).
        rx.await
            .map_err(|_| Status::internal("contract-create session dropped reply"))?
    }

    pub async fn step4(
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
            step4_finalize(&mut g, &self.shared, &req)?
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
            if let Some((_, sess_arc)) = self.sessions.remove(uid) {
                let mut s = sess_arc.lock();
                drain_with_err(&mut s.pending_contract_step1, EVICT_MSG);
                drain_with_err(&mut s.pending_contract_step2, EVICT_MSG);
                drain_pairs_with_err(&mut s.pending_contract_step3, EVICT_MSG);
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

// ============================================================================
// Step 1 — register dealers; the cosigner self-deals a reshare polynomial.
// ============================================================================

fn step1(
    sess: &mut DkgSession,
    shared: &SharedServices,
    req: ContractCreateStep1Request,
    reply: Reply<ContractCreateStep1Response>,
) {
    sess.last_touch = Instant::now();

    if req.round1_package.is_empty() {
        let _ = reply.send(Err(Status::invalid_argument(
            "round1_package is required (contract creation always reshares)",
        )));
        return;
    }

    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] ContractCreateStep1 from {identifier_hex}");

    // Capture reshare context (contract + ASP + service params); validated at finalize.
    if !req.contract_id.is_empty() {
        sess.reshare_contract_id = req.contract_id.clone();
    }
    if !req.contract_wasm.is_empty() {
        sess.reshare_contract_wasm = req.contract_wasm.clone();
    }
    if !req.server_pk.is_empty() {
        sess.reshare_server_pk = req.server_pk.clone();
    }
    if req.exit_delay != 0 {
        sess.reshare_exit_delay = req.exit_delay;
    }
    if !req.owner_pk.is_empty() {
        sess.reshare_owner_pk = req.owner_pk.clone();
    }
    if !req.service_vk.is_empty() {
        sess.reshare_service_vk = req.service_vk.clone();
    }

    sess.round1_packages
        .insert(identifier_hex, req.round1_package.clone());

    // The cosigner self-deals its own Δ (first caller only).
    if sess.round1_secret.is_none() {
        if let Err(e) = step1_cosigner_deal(sess, shared, &user_id_hex) {
            let _ = reply.send(Err(e));
            return;
        }
    }

    if sess.round1_packages.len() >= TOTAL_PARTICIPANTS {
        let response = ContractCreateStep1Response {
            round1_packages: sess.round1_packages.clone(),
        };
        for s in sess.pending_contract_step1.drain(..) {
            let _ = s.send(Ok(response.clone()));
        }
        let _ = reply.send(Ok(response));
    } else {
        sess.pending_contract_step1.push(reply);
    }
}

/// The cosigner reshares from its EXISTING share under its EXISTING identifier:
/// deals a fresh non-zero Δ so the finalized key is `V′ = V + Δ`.
fn step1_cosigner_deal(
    sess: &mut DkgSession,
    shared: &SharedServices,
    user_id_hex: &str,
) -> Result<(), Status> {
    let policy = load_policy(shared, user_id_hex)?;
    let old_kp_json = policy.normal_policy.key_package_json.clone();
    let old_pkp_json = policy.normal_policy.public_key_package_json.clone();
    let cosigner_id_hex = parsers::extract_identifier(&old_kp_json)?;
    let cosigner_id = conv::parse_identifier_hex(&cosigner_id_hex)?;

    let mut rng = OsRng;
    let secret = random::mod_n_random(&mut rng);
    let mut seed = [0u8; 32];
    rng.fill(&mut seed);
    let coefficients = random::generate_coefficients_seeded(THRESHOLD_COUNT - 1, &seed);
    let (r1_secret, r1_pub) = dkg::dkg_reshare_part1(
        &cosigner_id,
        TOTAL_PARTICIPANTS,
        THRESHOLD_COUNT,
        &secret,
        &coefficients,
        &mut rng,
    )
    .map_err(|e| Status::internal(format!("dkg_reshare_part1: {e}")))?;

    sess.server_id_hex = cosigner_id_hex.clone();
    sess.round1_packages.insert(cosigner_id_hex, r1_pub.to_json());
    sess.round1_secret = Some(r1_secret);
    sess.reshare_old_kp_json = old_kp_json;
    sess.reshare_old_pkp_json = old_pkp_json;
    Ok(())
}

// ============================================================================
// Step 2 — the cosigner computes its round-2 shares for the receivers.
// ============================================================================

fn step2(
    sess: &mut DkgSession,
    req: ContractCreateStep2Request,
    reply: Reply<ContractCreateStep2Response>,
) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] ContractCreateStep2");

    if sess.round1_secret.is_none() {
        let _ = reply.send(Err(Status::internal("no contract-create session")));
        return;
    }

    if sess.is_round2_local_empty() {
        if let Err(e) = step2_compute(sess) {
            let _ = reply.send(Err(e));
            drain_with_err(
                &mut sess.pending_contract_step2,
                "contract-create step2 compute failed",
            );
            return;
        }
    }

    let response = ContractCreateStep2Response {
        all_round1_packages: sess.round1_packages.clone(),
    };
    for s in sess.pending_contract_step2.drain(..) {
        let _ = s.send(Ok(response.clone()));
    }
    let _ = reply.send(Ok(response));
}

fn step2_compute(sess: &mut DkgSession) -> Result<(), Status> {
    let cosigner_id_hex = sess.server_id_hex.clone();
    let round1_pkgs =
        conv::parse_round1_pkgs_json(&sess.round1_packages_excluding_json(&cosigner_id_hex))?;
    let receiver_ids = conv::parse_identifier_list_json(&sess.receiver_ids_json())?;
    let round1_secret = sess
        .round1_secret
        .take()
        .ok_or_else(|| Status::internal("round1 secret missing"))?;

    let (r2_secret, r2_pkgs) = dkg::dkg_part2(&round1_secret, &round1_pkgs, &receiver_ids)
        .map_err(|e| Status::internal(format!("dkg_part2: {e}")))?;

    sess.round2_secret = Some(r2_secret);
    let local_json = conv::serialize_round2_pkgs(&r2_pkgs);
    let local_pkgs = parsers::parse_round2_result(&local_json)?;
    let local_re_json = serde_json::to_string(&local_pkgs)
        .map_err(|e| Status::internal(format!("serialize: {e}")))?;
    sess.set_round2_local_json(&local_re_json);
    Ok(())
}

// ============================================================================
// Step 3 — exchange round-2; finalize V′; register + persist the user pairing.
// ============================================================================

fn step3(
    sess: &mut DkgSession,
    shared: &SharedServices,
    req: ContractCreateStep3Request,
    reply: Reply<ContractCreateStep3Response>,
) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let sender_identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] ContractCreateStep3 from {sender_identifier_hex}");

    let cosigner_id_hex = sess.server_id_hex.clone();
    for (recipient_hex, pkg_json) in &req.round2_packages_for_others {
        if recipient_hex == &cosigner_id_hex {
            sess.round2_received
                .insert(sender_identifier_hex.clone(), pkg_json.clone());
        }
    }
    let sender_pkgs_json = match serde_json::to_string(&req.round2_packages_for_others) {
        Ok(s) => s,
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("serialize: {e}"))));
            return;
        }
    };
    sess.insert_relay_packages(sender_identifier_hex.clone(), &sender_pkgs_json);

    if sess.relay_sender_count() < TOTAL_PARTICIPANTS - 1 {
        sess.pending_contract_step3.push((sender_identifier_hex, reply));
        return;
    }

    sess.insert_relay_from_local(cosigner_id_hex);
    let (spk, group_id) = match step3_finalize(sess, shared) {
        Ok(v) => v,
        Err(e) => {
            let _ = reply.send(Err(e));
            drain_pairs_with_err(
                &mut sess.pending_contract_step3,
                "contract-create step3 finalize failed",
            );
            return;
        }
    };

    let pending: Vec<(String, Reply<ContractCreateStep3Response>)> =
        sess.pending_contract_step3.drain(..).collect();
    for (id_hex, sender) in pending {
        let _ = sender.send(build_step3_response(sess, &id_hex, &spk, &group_id));
    }
    let _ = reply.send(build_step3_response(sess, &sender_identifier_hex, &spk, &group_id));
}

/// Finalize the reshare: derive `V′`, register the contract spk (user-supplied
/// exit key), persist the `EvtxoPolicy` (user pairing only) on the USER's policy.
/// Returns `(contract_spk, V′_group_id_hex)`.
fn step3_finalize(sess: &mut DkgSession, shared: &SharedServices) -> Result<(Vec<u8>, String), Status> {
    let cosigner_id_hex = sess.server_id_hex.clone();

    let old_kp = KeyPackage::from_json(&sess.reshare_old_kp_json)
        .map_err(|e| Status::internal(format!("old kp: {e}")))?;
    let old_pkp = PublicKeyPackage::from_json(&sess.reshare_old_pkp_json)
        .map_err(|e| Status::internal(format!("old pkp: {e}")))?;

    let round1_pkgs =
        conv::parse_round1_pkgs_json(&sess.round1_packages_excluding_json(&cosigner_id_hex))?;
    let round2_received = conv::parse_round2_pkgs_json(&sess.round2_received_json())?;
    let r2_secret = sess
        .round2_secret
        .take()
        .ok_or_else(|| Status::internal("round2 secret missing"))?;

    let final_ids: Vec<_> = sess
        .round1_packages
        .keys()
        .map(|h| conv::parse_identifier_hex(h))
        .collect::<Result<_, _>>()?;

    let (kp, pkp) = dkg::dkg_reshare_part3(
        &r2_secret,
        &round1_pkgs,
        &round2_received,
        &old_pkp,
        &old_kp,
        &final_ids,
    )
    .map_err(|e| Status::internal(format!("dkg_reshare_part3: {e}")))?;

    let kp_json = kp.to_json();
    let pkp_json = pkp.to_json();
    let coop_pk_xonly = xonly_from_vk(&parsers::extract_verifying_key(&pkp_json)?);
    // The unilateral-exit key is USER-SUPPLIED (not derived from V).
    if sess.reshare_owner_pk.len() != 32 {
        return Err(Status::invalid_argument("owner_pk must be a 32-byte x-only key"));
    }
    let owner_pk_xonly = hex::encode(&sess.reshare_owner_pk);
    let server_pk_xonly = hex::encode(&sess.reshare_server_pk);

    if sess.reshare_contract_id.len() != 32 {
        return Err(Status::invalid_argument("contract_id must be 32 bytes"));
    }
    let mut contract_id = [0u8; 32];
    contract_id.copy_from_slice(&sess.reshare_contract_id);

    if sess.reshare_contract_wasm.is_empty() {
        return Err(Status::invalid_argument(
            "contract_wasm is required when creating a contract",
        ));
    }
    if contract::sha256_id(&sess.reshare_contract_wasm) != contract_id {
        return Err(Status::invalid_argument(
            "contract_wasm does not match contract_id (sha256 mismatch)",
        ));
    }
    if let Some(host) = shared.contract_host.as_ref() {
        host.validate(&sess.reshare_contract_wasm)
            .map_err(|e| Status::invalid_argument(format!("invalid contract: {e}")))?;
    }
    shared
        .persistence
        .put(
            contract::CONTRACT_WASM_TREE,
            &hex::encode(contract_id),
            &hex::encode(&sess.reshare_contract_wasm),
        )
        .map_err(|e| Status::internal(format!("store contract wasm: {e}")))?;

    let spk = contract_gate::register_evtxo(
        shared.persistence.as_ref(),
        &server_pk_xonly,
        &coop_pk_xonly,
        &owner_pk_xonly,
        sess.reshare_exit_delay,
        &contract_id,
    )?;
    let spk_hex = hex::encode(&spk);
    let group_id = parsers::extract_verifying_key(&pkp_json)?; // V′

    // The cosigner's canonical V′ key package + the user's V′ identifier (the
    // non-cosigner entry of the 2-entry PKP), needed for the service refresh.
    let cosigner_vprime_kp_json = kp_json.clone();
    let author_id_hex = parsers::extract_recipient_identifier(&pkp_json, &cosigner_id_hex)?;

    // Persist on the USER's policy: pairing A (user) only; the service pairing
    // (service_share) is added in step4. `service_vk_hex` is recorded now so the
    // contract knows its intended service.
    let user_id_hex = sess.user_id_hex.clone();
    let contract_policy = ContractPolicy {
        contract_id_hex: hex::encode(contract_id),
        contract_pk_xonly_hex: coop_pk_xonly,
        cosigner_vprime_kp_json,
        author_id_hex,
        exit_delay: sess.reshare_exit_delay,
        owner_pk_xonly_hex: owner_pk_xonly,
        user_vk_hex: user_id_hex.clone(),
        user_share: CosignerShare {
            key_package_json: kp_json,
            public_key_package_json: pkp_json,
        },
        service_vk_hex: hex::encode(&sess.reshare_service_vk),
        service_share: None,
    };

    let mut policy = load_policy(shared, &user_id_hex)?;
    policy.contracts.insert(spk_hex, contract_policy);
    persist_policy(shared, &user_id_hex, &policy)?;

    tracing::info!("[{user_id_hex}] ContractCreate reshare complete; V′={group_id}");
    Ok((spk, group_id))
}

fn build_step3_response(
    sess: &DkgSession,
    recipient_id_hex: &str,
    spk: &[u8],
    group_id_hex: &str,
) -> Result<ContractCreateStep3Response, Status> {
    let relay_json = sess.relay_packages_for(recipient_id_hex);
    Ok(ContractCreateStep3Response {
        round2_packages_for_me: parse_string_map(&relay_json),
        contract_script_pubkey: spk.to_vec(),
        contract_group_id: hex::decode(group_id_hex).unwrap_or_default(),
    })
}

// ============================================================================
// Step 4 — refresh V′ onto the service pairing; persist + deliver b@service.
// ============================================================================

/// Build the cosigner's service counter-share `C_B`, the service verifying share
/// `service_share·G`, persist the service pairing, and return
/// `(V′_group_id_hex, b@service_bytes, context)` for delivery to the service.
fn step4_finalize(
    sess: &mut DkgSession,
    shared: &SharedServices,
    req: &ContractCreateStep4Request,
) -> Result<(String, Vec<u8>, ContractContext), Status> {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let spk_hex = hex::encode(&req.contract_script_pubkey);

    if sess.reshare_service_vk.len() != 33 {
        return Err(Status::invalid_argument("service_vk must be 33 bytes"));
    }
    let service_vk = sess.reshare_service_vk.clone();
    let service_vk_hex = hex::encode(&service_vk);

    let mut policy = load_policy(shared, &user_id_hex)?;
    let cp = policy
        .contracts
        .get(&spk_hex)
        .ok_or_else(|| Status::not_found("no such contract for this user"))?
        .clone();

    // The cosigner's canonical V′ key package + the original {user, cosigner} id-set.
    let holder_kp = KeyPackage::from_json(&cp.cosigner_vprime_kp_json)
        .map_err(|e| Status::internal(format!("cosigner V′ kp: {e}")))?;
    let cosigner_id = holder_kp.identifier.clone();
    let author_id = conv::parse_identifier_hex(&cp.author_id_hex)?;
    let id_set = [author_id, cosigner_id.clone()];

    let service_id = Identifier::derive(&service_vk)
        .map_err(|e| Status::internal(format!("derive service id: {e:?}")))?;

    // Cosigner's refresh half on a fresh polynomial through v′.
    let mut rng = OsRng;
    let slope_b = random::mod_n_random(&mut rng);
    let (b_at_service, b_at_cosigner) =
        dkg::refresh_share_to_id(&holder_kp, &id_set, &service_id, &cosigner_id, &slope_b)
            .map_err(|e| Status::internal(format!("refresh_share_to_id: {e:?}")))?;

    // C_B = a@cosigner + b@cosigner (the cosigner's counter-share for the service).
    let a_at_cosigner = scalar_from_bytes(
        &req.a_at_cosigner
            .clone()
            .try_into()
            .map_err(|_| Status::invalid_argument("a_at_cosigner must be 32 bytes"))?,
    )
    .map_err(|e| Status::invalid_argument(format!("bad a_at_cosigner: {e:?}")))?;
    let c_b = a_at_cosigner + b_at_cosigner;
    let c_b_point = point::base_mul(&c_b);

    // service_share·G = a@service·G + b@service·G — the cosigner builds the service
    // verifying share WITHOUT learning a@service (only its point).
    let a_at_service_point: [u8; 33] = req
        .a_at_service_point
        .clone()
        .try_into()
        .map_err(|_| Status::invalid_argument("a_at_service_point must be 33 bytes"))?;
    let a_at_service_point = point::deserialize_compressed(&a_at_service_point)
        .map_err(|e| Status::invalid_argument(format!("bad a_at_service_point: {e:?}")))?;
    let service_share_point = point::point_add(&a_at_service_point, &point::base_mul(&b_at_service));

    // V′ verifying key (even-Y ⇒ compressed prefix 0x02 over the x-only key).
    let mut vprime_bytes = [0u8; 33];
    vprime_bytes[0] = 0x02;
    let xonly = hex::decode(&cp.contract_pk_xonly_hex)
        .map_err(|e| Status::internal(format!("bad contract_pk_xonly: {e}")))?;
    if xonly.len() != 32 {
        return Err(Status::internal("contract_pk_xonly must be 32 bytes"));
    }
    vprime_bytes[1..].copy_from_slice(&xonly);
    let vprime_point = point::deserialize_compressed(&vprime_bytes)
        .map_err(|e| Status::internal(format!("bad V′ point: {e:?}")))?;
    let vprime_vk = VerifyingKey::new(vprime_point);

    // The cosigner's C_B key package + the service's 2-entry V′ PKP.
    let c_kp = KeyPackage {
        identifier: cosigner_id.clone(),
        secret_share: c_b,
        verifying_share: c_b_point,
        verifying_key: vprime_vk.clone(),
        min_signers: 2,
    };
    let mut verifying_shares: BTreeMap<Identifier, _> = BTreeMap::new();
    verifying_shares.insert(service_id.clone(), service_share_point);
    verifying_shares.insert(cosigner_id.clone(), c_b_point);
    let pkp_b = PublicKeyPackage {
        verifying_shares,
        verifying_key: vprime_vk,
    };
    let pkp_b_json = pkp_b.to_json();

    // Register the service pairing (pairing B) on the contract policy. `service_vk_hex`
    // was already recorded at step3; here we fill in its counter-share.
    {
        let cp_mut = policy
            .contracts
            .get_mut(&spk_hex)
            .ok_or_else(|| Status::internal("contract vanished"))?;
        debug_assert_eq!(cp_mut.service_vk_hex, service_vk_hex);
        cp_mut.service_share = Some(CosignerShare {
            key_package_json: c_kp.to_json(),
            public_key_package_json: pkp_b_json.clone(),
        });
    }
    persist_policy(shared, &user_id_hex, &policy)?;

    let group_id = cp.contract_pk_xonly_hex.clone(); // V′ x-only (correlation key for the service)
    let context = ContractContext {
        contract_script_pubkey: req.contract_script_pubkey.clone(),
        contract_id: hex::decode(&cp.contract_id_hex).unwrap_or_default(),
        exit_delay: cp.exit_delay,
        owner_pk: hex::decode(&cp.owner_pk_xonly_hex).unwrap_or_default(),
        server_pk: sess.reshare_server_pk.clone(),
        public_key_package_json: pkp_b_json,
        service_vk,
    };

    tracing::info!("[{user_id_hex}] ContractCreate service pairing added; V′={group_id}");
    Ok((group_id, scalar_to_bytes(&b_at_service).to_vec(), context))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn load_policy(shared: &SharedServices, user_id_hex: &str) -> Result<PolicyState, Status> {
    let json = match shared.persistence.get("policies", user_id_hex) {
        Ok(Some(j)) => j,
        _ => {
            let owner = shared
                .persistence
                .get("policy_owner_idx", user_id_hex)
                .ok()
                .flatten()
                .ok_or_else(|| Status::not_found("no policy for user"))?;
            shared
                .persistence
                .get("policies", &owner)
                .ok()
                .flatten()
                .ok_or_else(|| Status::not_found("no policy for user"))?
        }
    };
    serde_json::from_str(&json).map_err(|e| Status::internal(format!("parse policy: {e}")))
}

fn xonly_from_vk(vk_hex: &str) -> String {
    if vk_hex.len() == 66 {
        vk_hex[2..].to_string()
    } else {
        vk_hex.to_string()
    }
}

fn parse_string_map(json: &str) -> HashMap<String, String> {
    let mut out = HashMap::new();
    if let Ok(serde_json::Value::Object(obj)) = serde_json::from_str::<serde_json::Value>(json) {
        for (k, v) in obj {
            let s = v
                .as_str()
                .map(|s| s.to_string())
                .unwrap_or_else(|| v.to_string());
            out.insert(k, s);
        }
    }
    out
}
