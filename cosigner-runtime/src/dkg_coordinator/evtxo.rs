//! eVTXO key-generation coordinator: a 3-party RESHARE ceremony that derives a
//! fresh 2-of-2 key `V′ = V + Δ` for {wallet, cosigner} bound to a contract,
//! with the hardware signer dealing but EXCLUDED from the result (so the cosigner
//! is mandatory on cooperative spends and runs the contract gate).
//!
//! Reuses the DKG rendezvous (`DkgSession`, `conv`, drain helpers). Differences
//! vs DKG: the cosigner deals with its EXISTING identifier + a non-zero Δ
//! (`dkg_reshare_part1`), the cosigner is also a final shareholder, and step3
//! finalizes via `dkg_reshare_part3` into an `EvtxoPolicy` + registers the eVTXO
//! (`contract_gate::register_evtxo`).
//!
//! Topology (3 participants): cosigner (local, dealer+receiver), hardware
//! (remote dealer, excluded from result), wallet (remote passive receiver).
//!
//! NOTE: like DKG, this coordinator path is currently unauthenticated — the
//! ceremony's integrity rests on requiring the legitimate wallet + hardware
//! shares to complete. Verifying the request signature against the existing key
//! is a follow-up (the proto carries `signature`/`timestamp_ms`).

use std::collections::HashMap;
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
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::random;

use crate::contract;
use crate::cosigner::handlers::{contract_gate, parsers};
use crate::policy::store::persist_policy;
use crate::policy::{EvtxoPolicy, PolicyState};
use crate::shared::SharedServices;
use crate::wallet_proto::{
    EvtxoKeygenStep1Request, EvtxoKeygenStep1Response, EvtxoKeygenStep2Request,
    EvtxoKeygenStep2Response, EvtxoKeygenStep3Request, EvtxoKeygenStep3Response,
};

use super::conv;
use super::handlers::{drain_pairs_with_err, drain_with_err, Reply};
use super::session::DkgSession;

const EVICTION_TICK: Duration = Duration::from_secs(30);
const EVICT_MSG: &str = "evtxo-keygen session evicted: restart from step1";
const TOTAL_PARTICIPANTS: usize = 3; // cosigner + hardware (dealers) + wallet (receiver)
const THRESHOLD_COUNT: usize = 2; // resulting key is 2-of-2 {wallet, cosigner}

pub struct EvtxoKeygenCoordinator {
    sessions: DashMap<String, Arc<Mutex<DkgSession>>>,
    shared: Arc<SharedServices>,
    ttl: Duration,
}

impl EvtxoKeygenCoordinator {
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
        req: EvtxoKeygenStep1Request,
    ) -> Result<EvtxoKeygenStep1Response, Status> {
        let (tx, rx) = oneshot::channel();
        let sess = self.get_or_create(user_id);
        {
            let mut g = sess.lock();
            step1(&mut g, &self.shared, req, tx);
        }
        rx.await
            .map_err(|_| Status::internal("evtxo-keygen session dropped reply"))?
    }

    pub async fn step2(
        self: &Arc<Self>,
        user_id: &str,
        req: EvtxoKeygenStep2Request,
    ) -> Result<EvtxoKeygenStep2Response, Status> {
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
            .map_err(|_| Status::internal("evtxo-keygen session dropped reply"))?
    }

    pub async fn step3(
        self: &Arc<Self>,
        user_id: &str,
        req: EvtxoKeygenStep3Request,
    ) -> Result<EvtxoKeygenStep3Response, Status> {
        let sess = self
            .sessions
            .get(user_id)
            .map(|e| e.clone())
            .ok_or_else(|| Status::aborted(EVICT_MSG))?;
        let (tx, rx) = oneshot::channel();
        let finalized = {
            let mut g = sess.lock();
            step3(&mut g, &self.shared, req, tx)
        };
        if finalized {
            self.sessions.remove(user_id);
        }
        rx.await
            .map_err(|_| Status::internal("evtxo-keygen session dropped reply"))?
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
                drain_with_err(&mut s.pending_evtxo_step1, EVICT_MSG);
                drain_with_err(&mut s.pending_evtxo_step2, EVICT_MSG);
                drain_pairs_with_err(&mut s.pending_evtxo_step3, EVICT_MSG);
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
// Step 1 — register participants; the cosigner self-deals a reshare polynomial.
// ============================================================================

fn step1(
    sess: &mut DkgSession,
    shared: &SharedServices,
    req: EvtxoKeygenStep1Request,
    reply: Reply<EvtxoKeygenStep1Response>,
) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] EvtxoKeygenStep1 from {identifier_hex}");

    // Capture reshare context (contract + ASP params) from whichever caller has it.
    if !req.contract_id.is_empty() {
        sess.reshare_contract_id = req.contract_id.clone();
    }
    // Contract bytes are supplied at creation; validated + stored at finalize.
    if !req.contract_wasm.is_empty() {
        sess.reshare_contract_wasm = req.contract_wasm.clone();
    }
    if !req.server_pk.is_empty() {
        sess.reshare_server_pk = req.server_pk.clone();
    }
    if req.exit_delay != 0 {
        sess.reshare_exit_delay = req.exit_delay;
    }

    if req.round1_package.is_empty() {
        // Wallet = passive receiver.
        sess.receiver_identifiers.insert(identifier_hex);
    } else {
        // Hardware = remote dealer.
        sess.round1_packages.insert(identifier_hex, req.round1_package.clone());
    }

    // Cosigner self-deal (first caller only).
    if sess.round1_secret.is_none() {
        if let Err(e) = step1_cosigner_deal(sess, shared, &user_id_hex) {
            let _ = reply.send(Err(e));
            return;
        }
    }

    if sess.total_participants() >= TOTAL_PARTICIPANTS {
        let response = EvtxoKeygenStep1Response {
            round1_packages: sess.round1_packages.clone(),
        };
        for s in sess.pending_evtxo_step1.drain(..) {
            let _ = s.send(Ok(response.clone()));
        }
        let _ = reply.send(Ok(response));
    } else {
        sess.pending_evtxo_step1.push(reply);
    }
}

fn step1_cosigner_deal(
    sess: &mut DkgSession,
    shared: &SharedServices,
    user_id_hex: &str,
) -> Result<(), Status> {
    // The cosigner reshares from its EXISTING share under its EXISTING identifier.
    let policy = load_policy(shared, user_id_hex)?;
    let old_kp_json = policy.normal_policy.key_package_json.clone();
    let old_pkp_json = policy.normal_policy.public_key_package_json.clone();
    let cosigner_id_hex = parsers::extract_identifier(&old_kp_json)?;
    let cosigner_id = conv::parse_identifier_hex(&cosigner_id_hex)?;

    // Deal a fresh NON-zero polynomial (Δ) under the cosigner's existing id.
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

    // For the reshare, `server_id_hex` holds the cosigner's EXISTING identifier
    // directly (not a vk to derive from).
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

fn step2(sess: &mut DkgSession, req: EvtxoKeygenStep2Request, reply: Reply<EvtxoKeygenStep2Response>) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] EvtxoKeygenStep2");

    if sess.round1_secret.is_none() {
        let _ = reply.send(Err(Status::internal("no evtxo-keygen session")));
        return;
    }

    if sess.is_round2_local_empty() {
        if let Err(e) = step2_compute(sess) {
            let _ = reply.send(Err(e));
            drain_with_err(&mut sess.pending_evtxo_step2, "evtxo step2 compute failed");
            return;
        }
    }

    let response = EvtxoKeygenStep2Response {
        all_round1_packages: sess.round1_packages.clone(),
    };
    for s in sess.pending_evtxo_step2.drain(..) {
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
// Step 3 — exchange round-2 packages; on completion, finalize V′ + register.
// ============================================================================

fn step3(
    sess: &mut DkgSession,
    shared: &SharedServices,
    req: EvtxoKeygenStep3Request,
    reply: Reply<EvtxoKeygenStep3Response>,
) -> bool {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let sender_identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] EvtxoKeygenStep3 from {sender_identifier_hex}");

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
            return false;
        }
    };
    sess.insert_relay_packages(sender_identifier_hex.clone(), &sender_pkgs_json);

    if sess.relay_sender_count() < TOTAL_PARTICIPANTS - 1 {
        sess.pending_evtxo_step3.push((sender_identifier_hex, reply));
        return false;
    }

    sess.insert_relay_from_local(cosigner_id_hex);
    let evtxo_spk = match step3_finalize(sess, shared) {
        Ok(spk) => spk,
        Err(e) => {
            let _ = reply.send(Err(e));
            drain_pairs_with_err(&mut sess.pending_evtxo_step3, "evtxo step3 finalize failed");
            return false;
        }
    };

    let pending: Vec<(String, Reply<EvtxoKeygenStep3Response>)> =
        sess.pending_evtxo_step3.drain(..).collect();
    for (id_hex, sender) in pending {
        let _ = sender.send(build_step3_response(sess, &id_hex, &evtxo_spk));
    }
    let _ = reply.send(build_step3_response(sess, &sender_identifier_hex, &evtxo_spk));
    true
}

/// Finalize the reshare: derive V′, register the eVTXO, persist the EvtxoPolicy.
/// Returns the registered scriptPubKey.
fn step3_finalize(sess: &mut DkgSession, shared: &SharedServices) -> Result<Vec<u8>, Status> {
    let cosigner_id_hex = sess.server_id_hex.clone();
    let cosigner_id = conv::parse_identifier_hex(&cosigner_id_hex)?;

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

    // Final shareholders = passive receivers (wallet) + the cosigner.
    let mut final_ids = conv::parse_identifier_list_json(&sess.receiver_ids_json())?;
    final_ids.push(cosigner_id);

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
    let evtxo_pk_xonly = xonly_from_vk(&parsers::extract_verifying_key(&pkp_json)?);
    let owner_pk_xonly = xonly_from_vk(&parsers::extract_verifying_key(&sess.reshare_old_pkp_json)?);
    let server_pk_xonly = hex::encode(&sess.reshare_server_pk);

    if sess.reshare_contract_id.len() != 32 {
        return Err(Status::invalid_argument("contract_id must be 32 bytes"));
    }
    let mut contract_id = [0u8; 32];
    contract_id.copy_from_slice(&sess.reshare_contract_id);

    // Require the bytes, verify they match the committed id, and persist them so
    // the gate can resolve the contract at spend time.
    if sess.reshare_contract_wasm.is_empty() {
        return Err(Status::invalid_argument(
            "contract_wasm is required when creating an eVTXO",
        ));
    }
    if contract::sha256_id(&sess.reshare_contract_wasm) != contract_id {
        return Err(Status::invalid_argument(
            "contract_wasm does not match contract_id (sha256 mismatch)",
        ));
    }
    // Reject a malformed or WASI-grabbing contract now, not as a permanent Deny at spend.
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
        &evtxo_pk_xonly,
        &owner_pk_xonly,
        sess.reshare_exit_delay,
        &contract_id,
    )?;
    let spk_hex = hex::encode(&spk);

    // Persist the EvtxoPolicy under the user's policy (keyed by eVTXO spk).
    let user_id_hex = sess.user_id_hex.clone();
    let mut policy = load_policy(shared, &user_id_hex)?;
    policy.evtxo_policies.insert(
        spk_hex,
        EvtxoPolicy {
            contract_id_hex: hex::encode(&contract_id),
            evtxo_pk_xonly_hex: evtxo_pk_xonly,
            key_package_json: kp_json,
            public_key_package_json: pkp_json,
        },
    );
    persist_policy(shared, &user_id_hex, &policy)?;

    tracing::info!("[{user_id_hex}] EvtxoKeygen complete");
    Ok(spk)
}

fn build_step3_response(
    sess: &DkgSession,
    recipient_id_hex: &str,
    evtxo_spk: &[u8],
) -> Result<EvtxoKeygenStep3Response, Status> {
    let relay_json = sess.relay_packages_for(recipient_id_hex);
    Ok(EvtxoKeygenStep3Response {
        round2_packages_for_me: parse_string_map(&relay_json),
        evtxo_address: String::new(), // client derives the bech32m address from the spk
        evtxo_script_pubkey: evtxo_spk.to_vec(),
    })
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Load the user's policy directly, or via the HW-VK -> owner index.
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
