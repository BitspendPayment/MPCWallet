//! Native-Rust DKG handlers — call `threshold::dkg::*` directly, store
//! aggregator state on `DkgSession`, persist `policy_state` to sled on
//! step3 success.
//!
//! Rendezvous pattern (unchanged from the old WASM-mediated path): every
//! caller whose round isn't yet complete has its reply oneshot stashed in
//! `DkgSession.pending_*`; the participant whose arrival closes the round
//! fulfils every stashed sender, then its own.
//!
//! DKG handlers deliberately do NOT call `auth_check`/`timestamp_check`
//! (the per-RPC Schnorr-auth path in `cosigner/handlers/helpers.rs`).
//! The user's owner key only exists once DKG completes, so there's no
//! shared secret to verify a request signature against during the
//! ceremony. Integrity comes from FROST itself (verifiable secret shares
//! in round1, commitment proofs in round2) plus TTL-bounded session
//! state — see `DkgCoordinator::sweep_stale`.

use std::collections::HashMap;
use std::time::Instant;

use rand::rngs::OsRng;
use rand::Rng;
use tokio::sync::oneshot;
use tonic::Status;

use threshold::dkg::{self, Round1SecretPackage};
use threshold::identifier::Identifier;
use threshold::random;
use threshold::scalar::scalar_to_bytes;

use crate::cosigner::handlers::parsers;
use crate::policy::{NormalPolicy, PolicyState};
use crate::policy::store::persist_policy;
use crate::shared::SharedServices;
use crate::wallet_proto::{
    DkgStep1Request, DkgStep1Response, DkgStep2Request, DkgStep2Response, DkgStep3Request,
    DkgStep3Response,
};

use super::conv;
use super::session::DkgSession;

// Real 2-of-2 {wallet, cosigner}: both parties deal, both hold a share, no
// recovery/hardware third party. `receiver_identifiers` stays empty — each side's
// only round1 package is the other's (dkg_part2/3 require pkgs+receivers == n-1).
const TOTAL_PARTICIPANTS: usize = 2;
const THRESHOLD_COUNT: usize = 2;

pub(super) type Reply<T> = oneshot::Sender<Result<T, Status>>;

// ============================================================================
// DKG Step 1
// ============================================================================

#[tracing::instrument(skip_all, name = "dkg::step1", fields(user_id = %parsers::user_id_hex(&req.user_id)))]
pub fn dkg_step1(
    sess: &mut DkgSession,
    shared: &SharedServices,
    req: DkgStep1Request,
    reply: Reply<DkgStep1Response>,
) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] DKGStep1 from {identifier_hex}");

    // 1) Phase A — register/insert this participant.
    if let Err(e) = step1_register(sess, &user_id_hex, &identifier_hex, &req) {
        let _ = reply.send(Err(e));
        return;
    }

    // 2) Phase B — server self-init (only the first caller does the work).
    let needs_init = sess.round1_secret.is_none();
    if needs_init {
        if let Err(e) = step1_server_init(sess, shared, &user_id_hex, req.is_restore) {
            let _ = reply.send(Err(e));
            return;
        }
    }

    // 3) Completion check: if all participants registered, build response
    //    and fulfill every stashed sender + own.
    let total = sess.total_participants();
    if total >= TOTAL_PARTICIPANTS {
        let response = match step1_build_response(sess) {
            Ok(r) => r,
            Err(e) => {
                let _ = reply.send(Err(e));
                drain_with_err(&mut sess.pending_step1, "step1 build failed");
                return;
            }
        };
        for s in sess.pending_step1.drain(..) {
            let _ = s.send(Ok(response.clone()));
        }
        let _ = reply.send(Ok(response));
    } else {
        sess.pending_step1.push(reply);
    }
}

fn step1_register(
    sess: &mut DkgSession,
    user_id_hex: &str,
    identifier_hex: &str,
    req: &DkgStep1Request,
) -> Result<(), Status> {
    if req.round1_package.is_empty() {
        tracing::info!("[{user_id_hex}] DKGStep1: Registered passive receiver {identifier_hex}");
        sess.receiver_identifiers.insert(identifier_hex.to_string());
    } else {
        tracing::info!("[{user_id_hex}] DKGStep1: Received round1 from {identifier_hex}");
        sess.round1_packages
            .insert(identifier_hex.to_string(), req.round1_package.clone());
    }
    Ok(())
}

fn step1_server_init(
    sess: &mut DkgSession,
    shared: &SharedServices,
    user_id_hex: &str,
    is_restore: bool,
) -> Result<(), Status> {
    let secret_hex = if is_restore {
        tracing::info!("[{user_id_hex}] Server: Restore — looking up stored DKG secret");
        let policy = lookup_policy_by_recovery_id(shared, user_id_hex)?
            .ok_or_else(|| Status::not_found(format!("No policy for recovery ID {user_id_hex}")))?;
        policy
            .server_dkg_secret_hex
            .clone()
            .ok_or_else(|| Status::internal("Existing policy has no stored DKG secret"))?
    } else {
        tracing::info!("[{user_id_hex}] Server: Generating DKG secrets");
        let mut rng = OsRng;
        hex::encode(scalar_to_bytes(&random::mod_n_random(&mut rng)))
    };

    let mut rng = OsRng;
    let mut seed = [0u8; 32];
    rng.fill(&mut seed);
    let coefficients = random::generate_coefficients_seeded(THRESHOLD_COUNT - 1, &seed);

    let secret = conv::parse_scalar_hex(&secret_hex)?;
    let (r1_secret, r1_pub) = dkg::dkg_part1(
        TOTAL_PARTICIPANTS,
        THRESHOLD_COUNT,
        &secret,
        &coefficients,
        &mut rng,
    )
    .map_err(|e| Status::internal(format!("dkg_part1: {e}")))?;

    let server_id_bytes = r1_pub.verifying_key.serialize();
    let server_id_hex = hex::encode(server_id_bytes);
    let server_identifier_hex = hex::encode(r1_secret.identifier.serialize());
    let round1_package_json = r1_pub.to_json();

    sess.server_id_hex = server_id_hex;
    sess.server_internal_secret_hex = secret_hex;
    sess.round1_packages
        .insert(server_identifier_hex, round1_package_json);
    sess.round1_secret = Some(r1_secret);
    Ok(())
}

fn step1_build_response(sess: &DkgSession) -> Result<DkgStep1Response, Status> {
    let pkgs = parsers::parse_json_string_map(&sess.round1_packages_json())?;
    let mut response = DkgStep1Response::default();
    for (id_hex, pkg_json) in &pkgs {
        response
            .round1_packages
            .insert(id_hex.clone(), pkg_json.clone());
    }
    Ok(response)
}

// ============================================================================
// DKG Step 2
// ============================================================================

#[tracing::instrument(skip_all, name = "dkg::step2", fields(user_id = %parsers::user_id_hex(&req.user_id)))]
pub fn dkg_step2(
    sess: &mut DkgSession,
    _shared: &SharedServices,
    req: DkgStep2Request,
    reply: Reply<DkgStep2Response>,
) {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] DKGStep2");

    // step2 has no "register" — every caller drives the SAME server-side
    // round2 computation. The first caller does the work; the others piggy-
    // back and immediately get the response.
    if sess.round1_secret.is_none() {
        let _ = reply.send(Err(Status::internal("no DKG session")));
        return;
    }

    let needs_compute = sess.is_round2_local_empty();
    if needs_compute {
        if let Err(e) = step2_compute(sess, &user_id_hex) {
            let _ = reply.send(Err(e));
            drain_with_err(&mut sess.pending_step2, "step2 compute failed");
            return;
        }
    }

    match step2_build_response(sess) {
        Ok(response) => {
            for s in sess.pending_step2.drain(..) {
                let _ = s.send(Ok(response.clone()));
            }
            let _ = reply.send(Ok(response));
        }
        Err(e) => {
            let _ = reply.send(Err(e));
            drain_with_err(&mut sess.pending_step2, "step2 build failed");
        }
    }
}

fn step2_compute(sess: &mut DkgSession, user_id_hex: &str) -> Result<(), Status> {
    let server_id_hex = sess.server_id_hex.clone();
    if server_id_hex.is_empty() {
        return Err(Status::internal("server ID not initialized"));
    }
    let server_id_bytes =
        hex::decode(&server_id_hex).map_err(|e| Status::internal(format!("hex decode: {e}")))?;
    let server_identifier =
        Identifier::derive(&server_id_bytes).map_err(|e| Status::internal(format!("derive: {e}")))?;
    let server_identifier_hex = hex::encode(server_identifier.serialize());

    tracing::info!("[{user_id_hex}] DKGStep2: Server computing round2");

    let round1_pkgs_json = sess.round1_packages_excluding_json(&server_identifier_hex);
    let receiver_ids_json = sess.receiver_ids_json();

    let round1_pkgs = conv::parse_round1_pkgs_json(&round1_pkgs_json)?;
    let receiver_ids = conv::parse_identifier_list_json(&receiver_ids_json)?;

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

fn step2_build_response(sess: &DkgSession) -> Result<DkgStep2Response, Status> {
    let pkgs = parsers::parse_json_string_map(&sess.round1_packages_json())?;
    let mut response = DkgStep2Response::default();
    for (id_hex, pkg_json) in &pkgs {
        response
            .all_round1_packages
            .insert(id_hex.clone(), pkg_json.clone());
    }
    Ok(response)
}

// ============================================================================
// DKG Step 3
// ============================================================================

/// Returns `(reply_was_sent, finalized)`. `finalized=true` means the session
/// should be removed from the coordinator's map by the caller.
#[tracing::instrument(skip_all, name = "dkg::step3", fields(user_id = %parsers::user_id_hex(&req.user_id)))]
pub fn dkg_step3(
    sess: &mut DkgSession,
    shared: &SharedServices,
    req: DkgStep3Request,
    reply: Reply<DkgStep3Response>,
) -> bool {
    sess.last_touch = Instant::now();
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let sender_identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] DKGStep3 from {sender_identifier_hex}");

    // Phase A — register the sender's round2 packages and relay them.
    let server_identifier_hex = match step3_register(sess, &req, &sender_identifier_hex) {
        Ok(s) => s,
        Err(e) => {
            let _ = reply.send(Err(e));
            return false;
        }
    };

    let round_complete = sess.relay_sender_count() >= TOTAL_PARTICIPANTS - 1;

    if !round_complete {
        sess.pending_step3
            .push((sender_identifier_hex.clone(), reply));
        return false;
    }

    // Round just completed. Insert server-local round2 packages into relay,
    // then run server key derivation + persist policy. Finalize is unconditional —
    // a missing round2 secret here means step2 didn't run (or already finalized),
    // which is a protocol violation; surface as an error instead of returning Ok
    // with no persistence. (`step3_finalize_server_key` errors on `None`.)
    sess.insert_relay_from_local(server_identifier_hex);
    if let Err(e) = step3_finalize_server_key(sess, shared, &user_id_hex) {
        let _ = reply.send(Err(e));
        drain_pairs_with_err(&mut sess.pending_step3, "step3 finalize failed");
        return false;
    }

    // Per-caller responses: the just-arrived caller plus every stashed one.
    let pending: Vec<(String, Reply<DkgStep3Response>)> = sess.pending_step3.drain(..).collect();
    for (id_hex, sender) in pending {
        match step3_build_response(sess, &id_hex) {
            Ok(r) => {
                let _ = sender.send(Ok(r));
            }
            Err(e) => {
                let _ = sender.send(Err(e));
            }
        }
    }
    match step3_build_response(sess, &sender_identifier_hex) {
        Ok(r) => {
            let _ = reply.send(Ok(r));
        }
        Err(e) => {
            let _ = reply.send(Err(e));
        }
    }
    true
}

fn step3_register(
    sess: &mut DkgSession,
    req: &DkgStep3Request,
    sender_identifier_hex: &str,
) -> Result<String, Status> {
    let server_id_bytes =
        hex::decode(&sess.server_id_hex).map_err(|e| Status::internal(format!("hex decode: {e}")))?;
    let server_identifier = Identifier::derive(&server_id_bytes)
        .map_err(|e| Status::internal(format!("derive: {e}")))?;
    let server_identifier_hex = hex::encode(server_identifier.serialize());

    // Store round2 packages addressed to the server.
    for (recipient_hex, pkg_json) in &req.round2_packages_for_others {
        if recipient_hex == &server_identifier_hex {
            sess.round2_received
                .insert(sender_identifier_hex.to_string(), pkg_json.clone());
        }
    }

    // Insert all sender packages into relay.
    let sender_pkgs_json = serde_json::to_string(&req.round2_packages_for_others)
        .map_err(|e| Status::internal(format!("serialize: {e}")))?;
    sess.insert_relay_packages(sender_identifier_hex.to_string(), &sender_pkgs_json);

    Ok(server_identifier_hex)
}

fn step3_finalize_server_key(
    sess: &mut DkgSession,
    shared: &SharedServices,
    user_id_hex: &str,
) -> Result<(), Status> {
    tracing::info!("[{user_id_hex}] DKGStep3: Server computing KeyPackage");

    let server_id_bytes = hex::decode(&sess.server_id_hex)
        .map_err(|e| Status::internal(format!("hex decode: {e}")))?;
    let server_identifier = Identifier::derive(&server_id_bytes)
        .map_err(|e| Status::internal(format!("derive: {e}")))?;
    let server_identifier_hex = hex::encode(server_identifier.serialize());

    // 2-of-2 {wallet, cosigner}: the wallet is the only non-server dealer. Its
    // FROST verifying share is the canonical user_id the client authenticates as;
    // there is no recovery identity (no hardware/backup third party).
    let wallet_identifier_hex = sess
        .round1_packages
        .keys()
        .find(|id| *id != &server_identifier_hex)
        .cloned()
        .ok_or_else(|| Status::internal("2-of-2 DKG: wallet dealer not found"))?;

    let round1_pkgs_json = sess.round1_packages_excluding_json(&server_identifier_hex);
    let round2_received_json = sess.round2_received_json();
    let receiver_ids_json = sess.receiver_ids_json();

    let round1_pkgs = conv::parse_round1_pkgs_json(&round1_pkgs_json)?;
    let round2_pkgs = conv::parse_round2_pkgs_json(&round2_received_json)?;
    let receiver_ids = conv::parse_identifier_list_json(&receiver_ids_json)?;

    let r2_secret = sess
        .round2_secret
        .take()
        .ok_or_else(|| Status::internal("round2 secret missing"))?;

    // dkg_part3 ignores its first arg (Round1SecretPackage) per the threshold
    // crate contract; pass a stub built from r2_secret's commitment.
    let dummy_r1 = Round1SecretPackage {
        identifier: r2_secret.identifier.clone(),
        coefficients: Vec::new(),
        commitment: r2_secret.commitment.clone(),
        min_signers: r2_secret.min_signers,
        max_signers: r2_secret.max_signers,
    };

    let (kp, pkp) = dkg::dkg_part3(&dummy_r1, &r2_secret, &round1_pkgs, &round2_pkgs, &receiver_ids)
        .map_err(|e| Status::internal(format!("dkg_part3: {e}")))?;

    let kp_json = kp.to_json();
    let pkp_json = pkp.to_json();

    // The wallet's FROST verifying share is the canonical user_id (the client
    // authenticates as it). No recovery identity in a 2-of-2.
    let policy_user_id = parsers::extract_verifying_share(&pkp_json, &wallet_identifier_hex)?;
    let user_signing_identifier_hex = Some(wallet_identifier_hex);

    let server_dkg_secret_hex = sess.server_internal_secret_hex.clone();
    let recovery_id = String::new();

    // Restore: if this recovery_id was previously associated with another
    // user_id, clean up the old policy entries (read straight from sled —
    // there's no in-memory recovery index).
    if !recovery_id.is_empty() {
        if let Ok(Some(old_user_id)) = shared.persistence.get("policy_recovery_idx", &recovery_id) {
            if let Ok(Some(json_str)) = shared.persistence.get("policies", &old_user_id) {
                if let Ok(ps) = serde_json::from_str::<PolicyState>(&json_str) {
                    if ps.recovery_id == recovery_id {
                        let _ = shared.persistence.delete("policies", &old_user_id);
                        let _ = shared
                            .persistence
                            .delete("policy_recovery_idx", &recovery_id);
                        let _ = shared
                            .secret_store
                            .delete_secret(&format!("dkg-secret.{old_user_id}"));
                    }
                }
            }
        }
    }

    // The actor's cosigner id = the GROUP KEY `V` (the 2-of-2 {wallet, cosigner}
    // key). Policies + per-user data are keyed under it, unifying a normal wallet
    // with a contract (a contract is the same shape keyed by `V′`). The wallet is the
    // sole MEMBER; it addresses by its verifying share (`policy_user_id`) and resolves
    // to this actor via `policy_owner_idx`.
    let group_key = parsers::extract_verifying_key(&pkp_json)?;

    let normal_policy = NormalPolicy {
        id: "normal policies".to_string(),
        key_package_json: kp_json,
        public_key_package_json: pkp_json,
    };
    let policy_state: PolicyState = PolicyState {
        cosigner_id: group_key.clone(),
        recovery_id,
        user_signing_identifier_hex,
        server_dkg_secret_hex: Some(server_dkg_secret_hex),
        normal_policy,
        evtxo_policies: HashMap::new(),
        is_contract: false,
    };

    // Persist under the group key (pass it directly — `policy_owner_idx` isn't written
    // for it yet, so the resolver in `persist_policy` would no-op anyway).
    persist_policy(shared, &group_key, &policy_state)?;

    // Register the wallet member in the group, and map both its verifying share and
    // the DKG-time HW verifying key (recovery addressing) → the group key, so client
    // requests addressed by either resolve to this `V`-keyed actor.
    crate::cosigner::handlers::helpers::persist_group_auth(
        shared.persistence.as_ref(),
        &group_key,
        &[policy_user_id.clone()],
    )?;
    for member_id in [policy_user_id.as_str(), user_id_hex] {
        if member_id != group_key {
            shared
                .persistence
                .put("policy_owner_idx", member_id, &group_key)
                .map_err(|e| {
                    tracing::error!("persist policy_owner_idx/{member_id} failed: {e}");
                    Status::internal(format!("persist policy_owner_idx failed: {e}"))
                })?;
        }
    }

    tracing::info!("[{user_id_hex}] DKG Complete; cosigner_id (group key)={group_key}");
    Ok(())
}

fn step3_build_response(
    sess: &DkgSession,
    sender_identifier_hex: &str,
) -> Result<DkgStep3Response, Status> {
    let relay_json = sess.relay_packages_for(sender_identifier_hex);
    let packages_for_me = parsers::parse_json_string_map(&relay_json)?;

    let mut response = DkgStep3Response::default();
    for (id_hex, pkg_json) in &packages_for_me {
        response
            .round2_packages_for_me
            .insert(id_hex.clone(), pkg_json.clone());
    }
    Ok(response)
}

// ============================================================================
// Helpers
// ============================================================================

fn lookup_policy_by_recovery_id(
    shared: &SharedServices,
    recovery_id_hex: &str,
) -> Result<Option<PolicyState>, Status> {
    let user_id = match shared.persistence.get("policy_recovery_idx", recovery_id_hex) {
        Ok(Some(uid)) => uid,
        _ => return Ok(None),
    };
    let json_str = match shared.persistence.get("policies", &user_id) {
        Ok(Some(j)) => j,
        _ => return Ok(None),
    };
    let mut ps: PolicyState = serde_json::from_str(&json_str)
        .map_err(|e| Status::internal(format!("parse policy: {e}")))?;
    if let Ok(Some(secret)) = shared
        .secret_store
        .get_secret(&format!("dkg-secret.{user_id}"))
    {
        ps.server_dkg_secret_hex = Some(secret);
    }
    Ok(Some(ps))
}

pub(super) fn drain_with_err<T>(pool: &mut Vec<oneshot::Sender<Result<T, Status>>>, msg: &str) {
    for s in pool.drain(..) {
        let _ = s.send(Err(Status::aborted(msg.to_string())));
    }
}

pub(super) fn drain_pairs_with_err<K, T>(
    pool: &mut Vec<(K, oneshot::Sender<Result<T, Status>>)>,
    msg: &str,
) {
    for (_, s) in pool.drain(..) {
        let _ = s.send(Err(Status::aborted(msg.to_string())));
    }
}
