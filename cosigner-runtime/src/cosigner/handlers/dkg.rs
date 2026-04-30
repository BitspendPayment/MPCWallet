//! 3-participant FROST DKG. Callers whose round isn't yet complete have their
//! reply oneshot stashed in `CosignerState.pending_dkg_*`; the participant whose
//! arrival completes the round fulfils every stashed sender.

use std::collections::HashMap;

use rand::Rng;
use tokio::sync::oneshot;
use tonic::Status;

use crate::crypto_ops;
use crate::policy::{NormalPolicy, PolicyState};
use crate::shared::SharedServices;
use crate::cosigner::registry::CosignerRegistry;
use crate::cosigner::state::CosignerState;
use crate::wallet_proto::*;
use crate::cosigner::handlers::parsers;
use crate::cosigner::wasm::CosignerInstance;

use super::helpers::persist_policy;

const TOTAL_PARTICIPANTS: usize = 3;
const THRESHOLD_COUNT: u32 = 2;

// ============================================================================
// DKG Step 1
// ============================================================================

#[tracing::instrument(skip_all, name = "actor::dkg_step1", fields(user_id = %parsers::user_id_hex(&req.user_id)))]
pub fn dkg_step1(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    _registry: &CosignerRegistry,
    req: DkgStep1Request,
    reply: oneshot::Sender<Result<DkgStep1Response, Status>>,
) {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] DKGStep1 from {identifier_hex}");

    // 1) Phase A — register/insert this participant.
    if let Err(e) = step1_register(user, &user_id_hex, &identifier_hex, &req) {
        let _ = reply.send(Err(e));
        return;
    }

    // 2) Phase B — server self-init (only first caller does it).
    let needs_init = user.round1_secret.is_none();
    if needs_init {
        if let Err(e) = step1_server_init(user, shared, &user_id_hex, req.is_restore) {
            let _ = reply.send(Err(e));
            return;
        }
    }

    // 3) Check completion: if all participants registered, build response and
    //    fulfill all stashed senders + own.
    let dkg_h = match user.dkg_session {
        Some(h) => h,
        None => {
            let _ = reply.send(Err(Status::internal("DKG session disappeared")));
            return;
        }
    };
    let total = match crypto_ops::dkg_session_total_participants(user, dkg_h) {
        Ok(t) => t as usize,
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("total_participants: {e}"))));
            return;
        }
    };

    if total >= TOTAL_PARTICIPANTS {
        // Round complete — build the response now.
        let response = match step1_build_response(user, dkg_h) {
            Ok(r) => r,
            Err(e) => {
                let _ = reply.send(Err(e));
                drain_with_err(&mut state.pending_dkg_step1, "step1 build failed");
                return;
            }
        };
        // Fulfill stashed senders.
        for s in state.pending_dkg_step1.drain(..) {
            let _ = s.send(Ok(response.clone()));
        }
        let _ = reply.send(Ok(response));
    } else {
        state.pending_dkg_step1.push(reply);
    }
}

fn step1_register(
    user: &mut CosignerInstance,
    user_id_hex: &str,
    identifier_hex: &str,
    req: &DkgStep1Request,
) -> Result<(), Status> {
    if user.dkg_session.is_none() {
        let h = crypto_ops::dkg_session_create(user)
            .map_err(|e| Status::internal(format!("dkg_session_create: {e}")))?;
        user.dkg_session = Some(h);
    }
    let dkg_h = user.dkg_session.unwrap();

    // Restore reset: if a previous DKG completed (policy_state already set),
    // blow away any leftover session state before starting the new round.
    // We use policy_state as the marker — concurrent calls within the SAME
    // round don't touch it (only step3's finalize does), so this won't false-
    // positive on the second arriving call when round1_secret was just set
    // by the first.
    if req.is_restore && user.policy_state.is_some() {
        tracing::info!("[{user_id_hex}] DKGStep1: Resetting stale session for restore");
        crypto_ops::dkg_session_reset(user, dkg_h)
            .map_err(|e| Status::internal(format!("dkg_session_reset: {e}")))?;
        user.round1_secret = None;
        user.round2_secret = None;
        user.policy_state = None;
    }

    if req.round1_package.is_empty() {
        tracing::info!("[{user_id_hex}] DKGStep1: Registered passive receiver {identifier_hex}");
        crypto_ops::dkg_session_insert_receiver_identifier(user, dkg_h, identifier_hex)
            .map_err(|e| Status::internal(format!("insert_receiver: {e}")))?;
    } else {
        tracing::info!("[{user_id_hex}] DKGStep1: Received round1 from {identifier_hex}");
        crypto_ops::dkg_session_insert_round1_package(
            user,
            dkg_h,
            identifier_hex,
            &req.round1_package,
        )
        .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;
    }
    Ok(())
}

fn step1_server_init(
    user: &mut CosignerInstance,
    shared: &SharedServices,
    user_id_hex: &str,
    is_restore: bool,
) -> Result<(), Status> {
    let secret_hex = if is_restore {
        tracing::info!("[{user_id_hex}] Server: Restore — looking up stored DKG secret");
        let policy = lookup_policy_by_recovery_id(shared, user_id_hex)?
            .ok_or_else(|| {
                Status::not_found(format!("No policy for recovery ID {user_id_hex}"))
            })?;
        policy
            .server_dkg_secret_hex
            .clone()
            .ok_or_else(|| Status::internal("Existing policy has no stored DKG secret"))?
    } else {
        tracing::info!("[{user_id_hex}] Server: Generating DKG secrets");
        crypto_ops::mod_n_random(user)
            .map_err(|e| Status::internal(format!("mod_n_random: {e}")))?
    };

    let mut seed = [0u8; 32];
    rand::thread_rng().fill(&mut seed);
    let coefficients_json =
        crypto_ops::generate_coefficients(user, THRESHOLD_COUNT - 1, &seed)
            .map_err(|e| Status::internal(format!("generate_coefficients: {e}")))?;

    let result = crypto_ops::dkg_part1(
        user,
        TOTAL_PARTICIPANTS as u32,
        THRESHOLD_COUNT,
        &secret_hex,
        &coefficients_json,
    )
    .map_err(|e| Status::internal(format!("dkg_part1: {e}")))?;

    let server_id_hex = crypto_ops::elem_base_mul(user, &secret_hex)
        .map_err(|e| Status::internal(format!("elem_base_mul: {e}")))?;
    let server_id_bytes = hex::decode(&server_id_hex)
        .map_err(|e| Status::internal(format!("hex decode: {e}")))?;
    let server_identifier_hex = crypto_ops::identifier_derive(user, &server_id_bytes)
        .map_err(|e| Status::internal(format!("identifier_derive: {e}")))?;

    user.round1_secret = Some(result.secret_handle);
    let dkg_h = user.dkg_session.unwrap();
    crypto_ops::dkg_session_set_server_id(user, dkg_h, &server_id_hex)
        .map_err(|e| Status::internal(format!("set_server_id: {e}")))?;
    crypto_ops::dkg_session_set_server_internal_secret_hex(user, dkg_h, &secret_hex)
        .map_err(|e| Status::internal(format!("set_secret: {e}")))?;
    crypto_ops::dkg_session_insert_round1_package(
        user,
        dkg_h,
        &server_identifier_hex,
        &result.round1_package_json,
    )
    .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;
    Ok(())
}

fn step1_build_response(
    user: &mut CosignerInstance,
    dkg_h: wasmtime::component::ResourceAny,
) -> Result<DkgStep1Response, Status> {
    let round1_json = crypto_ops::dkg_session_get_round1_packages_json(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_round1_packages: {e}")))?;
    let pkgs = parsers::parse_json_string_map(&round1_json)?;
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

#[tracing::instrument(skip_all, name = "actor::dkg_step2", fields(user_id = %parsers::user_id_hex(&req.user_id)))]
pub fn dkg_step2(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    _shared: &SharedServices,
    _registry: &CosignerRegistry,
    req: DkgStep2Request,
    reply: oneshot::Sender<Result<DkgStep2Response, Status>>,
) {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] DKGStep2");

    // step2 has no "register" — every caller drives the SAME server-side
    // round2 computation. The first caller does the work; the others piggy-back
    // and immediately get the response. Rendezvous reduces to "compute once,
    // respond to all."
    let dkg_h = match user.dkg_session {
        Some(h) => h,
        None => {
            let _ = reply.send(Err(Status::internal("no DKG session")));
            return;
        }
    };

    // If the local round2 packages haven't been computed yet, do so now.
    let needs_compute = match crypto_ops::dkg_session_is_round2_local_empty(user, dkg_h) {
        Ok(b) => b,
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("is_round2_local_empty: {e}"))));
            return;
        }
    };
    if needs_compute {
        if let Err(e) = step2_compute(user, dkg_h, &user_id_hex) {
            let _ = reply.send(Err(e));
            drain_with_err(&mut state.pending_dkg_step2, "step2 compute failed");
            return;
        }
    }

    // Build response and fulfill everyone (no further wait — round2 either was
    // already computed or just got computed by the first caller).
    match step2_build_response(user, dkg_h) {
        Ok(response) => {
            for s in state.pending_dkg_step2.drain(..) {
                let _ = s.send(Ok(response.clone()));
            }
            let _ = reply.send(Ok(response));
        }
        Err(e) => {
            let _ = reply.send(Err(e));
            drain_with_err(&mut state.pending_dkg_step2, "step2 build failed");
        }
    }
}

fn step2_compute(
    user: &mut CosignerInstance,
    dkg_h: wasmtime::component::ResourceAny,
    user_id_hex: &str,
) -> Result<(), Status> {
    let server_id_hex = crypto_ops::dkg_session_get_server_id(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
    if server_id_hex.is_empty() {
        return Err(Status::internal("server ID not initialized"));
    }
    let server_id_bytes = hex::decode(&server_id_hex)
        .map_err(|e| Status::internal(format!("hex decode: {e}")))?;
    let server_identifier_hex = crypto_ops::identifier_derive(user, &server_id_bytes)
        .map_err(|e| Status::internal(format!("identifier_derive: {e}")))?;

    tracing::info!("[{user_id_hex}] DKGStep2: Server computing round2");

    let round1_pkgs_json = crypto_ops::dkg_session_get_round1_packages_excluding_json(
        user,
        dkg_h,
        &server_identifier_hex,
    )
    .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;
    let receiver_ids_json = crypto_ops::dkg_session_get_receiver_ids_json(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_receiver_ids: {e}")))?;

    let round1_secret = user
        .round1_secret
        .take()
        .ok_or_else(|| Status::internal("round1 secret missing"))?;

    let result = crypto_ops::dkg_part2(user, round1_secret, &round1_pkgs_json, &receiver_ids_json)
        .map_err(|e| Status::internal(format!("dkg_part2: {e}")))?;

    user.round2_secret = Some(result.secret_handle);
    let local_pkgs = parsers::parse_round2_result(&result.round2_packages_json)?;
    let local_json = serde_json::to_string(&local_pkgs)
        .map_err(|e| Status::internal(format!("serialize: {e}")))?;
    crypto_ops::dkg_session_set_round2_local_json(user, dkg_h, &local_json)
        .map_err(|e| Status::internal(format!("set_round2_local: {e}")))?;
    Ok(())
}

fn step2_build_response(
    user: &mut CosignerInstance,
    dkg_h: wasmtime::component::ResourceAny,
) -> Result<DkgStep2Response, Status> {
    let round1_json = crypto_ops::dkg_session_get_round1_packages_json(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_round1_packages: {e}")))?;
    let pkgs = parsers::parse_json_string_map(&round1_json)?;
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

#[tracing::instrument(skip_all, name = "actor::dkg_step3", fields(user_id = %parsers::user_id_hex(&req.user_id)))]
pub fn dkg_step3(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    registry: &CosignerRegistry,
    req: DkgStep3Request,
    reply: oneshot::Sender<Result<DkgStep3Response, Status>>,
) {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    let sender_identifier_hex = hex::encode(&req.identifier);
    tracing::info!("[{user_id_hex}] DKGStep3 from {sender_identifier_hex}");

    // Phase A — register sender's round2 packages and relay them.
    let server_identifier_hex = match step3_register(user, &req, &sender_identifier_hex) {
        Ok(s) => s,
        Err(e) => {
            let _ = reply.send(Err(e));
            return;
        }
    };

    let dkg_h = match user.dkg_session {
        Some(h) => h,
        None => {
            let _ = reply.send(Err(Status::internal("no DKG session")));
            return;
        }
    };

    let relay_count = match crypto_ops::dkg_session_relay_sender_count(user, dkg_h) {
        Ok(n) => n,
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("relay_sender_count: {e}"))));
            return;
        }
    };

    let round_complete = relay_count as usize >= TOTAL_PARTICIPANTS - 1;

    if !round_complete {
        // Stash the reply with its caller identifier so we can target the
        // right relay packages when the round completes.
        state
            .pending_dkg_step3
            .push((sender_identifier_hex.clone(), reply));
        return;
    }

    // Round just completed. Insert local server packages into relay, then run
    // server key derivation + persist policy.
    if let Err(e) =
        crypto_ops::dkg_session_insert_relay_from_local(user, dkg_h, &server_identifier_hex)
    {
        let _ = reply.send(Err(Status::internal(format!("insert_relay_from_local: {e}"))));
        drain_pairs_with_err(&mut state.pending_dkg_step3, "step3 finalize failed");
        return;
    }
    if user.round2_secret.is_some() {
        if let Err(e) = step3_finalize_server_key(user, shared, registry, &user_id_hex) {
            let _ = reply.send(Err(e));
            drain_pairs_with_err(&mut state.pending_dkg_step3, "step3 finalize failed");
            return;
        }
    }

    // Per-caller responses: the just-arrived caller plus every stashed one.
    // Build each from the relay table keyed by THEIR identifier.
    let pending: Vec<(String, oneshot::Sender<Result<DkgStep3Response, Status>>)> =
        state.pending_dkg_step3.drain(..).collect();
    for (id_hex, sender) in pending {
        match step3_build_response(user, dkg_h, &id_hex) {
            Ok(r) => {
                let _ = sender.send(Ok(r));
            }
            Err(e) => {
                let _ = sender.send(Err(e));
            }
        }
    }
    match step3_build_response(user, dkg_h, &sender_identifier_hex) {
        Ok(r) => {
            let _ = reply.send(Ok(r));
        }
        Err(e) => {
            let _ = reply.send(Err(e));
        }
    }
}

fn step3_register(
    user: &mut CosignerInstance,
    req: &DkgStep3Request,
    sender_identifier_hex: &str,
) -> Result<String, Status> {
    let dkg_h = user
        .dkg_session
        .ok_or_else(|| Status::internal("no DKG session"))?;

    let server_id_hex = crypto_ops::dkg_session_get_server_id(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
    let server_id_bytes = hex::decode(&server_id_hex)
        .map_err(|e| Status::internal(format!("hex decode: {e}")))?;
    let server_identifier_hex = crypto_ops::identifier_derive(user, &server_id_bytes)
        .map_err(|e| Status::internal(format!("identifier_derive: {e}")))?;

    // Store round2 packages addressed to the server.
    for (recipient_hex, pkg_json) in &req.round2_packages_for_others {
        if recipient_hex == &server_identifier_hex {
            crypto_ops::dkg_session_insert_round2_received(
                user,
                dkg_h,
                sender_identifier_hex,
                pkg_json,
            )
            .map_err(|e| Status::internal(format!("insert_round2: {e}")))?;
        }
    }

    // Insert all sender packages into relay.
    let sender_pkgs_json = serde_json::to_string(&req.round2_packages_for_others)
        .map_err(|e| Status::internal(format!("serialize: {e}")))?;
    crypto_ops::dkg_session_insert_relay_packages(
        user,
        dkg_h,
        sender_identifier_hex,
        &sender_pkgs_json,
    )
    .map_err(|e| Status::internal(format!("insert_relay: {e}")))?;

    Ok(server_identifier_hex)
}

fn step3_finalize_server_key(
    user: &mut CosignerInstance,
    shared: &SharedServices,
    registry: &CosignerRegistry,
    user_id_hex: &str,
) -> Result<(), Status> {
    tracing::info!("[{user_id_hex}] DKGStep3: Server computing KeyPackage");
    let dkg_h = user
        .dkg_session
        .ok_or_else(|| Status::internal("no DKG session"))?;

    let server_id_hex = crypto_ops::dkg_session_get_server_id(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
    let server_id_bytes = hex::decode(&server_id_hex)
        .map_err(|e| Status::internal(format!("hex decode: {e}")))?;
    let server_identifier_hex = crypto_ops::identifier_derive(user, &server_id_bytes)
        .map_err(|e| Status::internal(format!("identifier_derive: {e}")))?;

    // Extract recovery ID from the first non-server, non-receiver dealer's
    // round1 package's `verifyingKey.E` field.
    let round1_all_json = crypto_ops::dkg_session_get_round1_packages_json(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_round1: {e}")))?;
    let round1_all: serde_json::Value = serde_json::from_str(&round1_all_json)
        .map_err(|e| Status::internal(format!("parse round1: {e}")))?;

    let mut user_recovery_id_hex: Option<String> = None;
    if let Some(obj) = round1_all.as_object() {
        for (id_hex, pkg_val_raw) in obj {
            if id_hex != &server_identifier_hex {
                let is_recv = crypto_ops::dkg_session_is_receiver(user, dkg_h, id_hex)
                    .map_err(|e| Status::internal(format!("is_receiver: {e}")))?;
                if !is_recv {
                    let pkg_str = pkg_val_raw.as_str().unwrap_or("{}");
                    if let Ok(pkg_val) = serde_json::from_str::<serde_json::Value>(pkg_str) {
                        if let Some(e_arr) = pkg_val["verifyingKey"]["E"].as_array() {
                            let bytes: Vec<u8> = e_arr
                                .iter()
                                .filter_map(|v| v.as_u64().map(|n| n as u8))
                                .collect();
                            if !bytes.is_empty() {
                                user_recovery_id_hex = Some(hex::encode(&bytes));
                            }
                        }
                    }
                    break;
                }
            }
        }
    }

    let round1_pkgs_json = crypto_ops::dkg_session_get_round1_packages_excluding_json(
        user,
        dkg_h,
        &server_identifier_hex,
    )
    .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;
    let round2_received_json = crypto_ops::dkg_session_get_round2_received_json(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_round2: {e}")))?;
    let receiver_ids_json = crypto_ops::dkg_session_get_receiver_ids_json(user, dkg_h)
        .map_err(|e| Status::internal(format!("get_receiver_ids: {e}")))?;

    let round2_secret = user.round2_secret.take().unwrap();
    let result = crypto_ops::dkg_part3(
        user,
        round2_secret,
        &round1_pkgs_json,
        &round2_received_json,
        &receiver_ids_json,
    )
    .map_err(|e| Status::internal(format!("dkg_part3: {e}")))?;

    // Decide policy_user_id (and signing identifier) from receiver list.
    let receiver_ids: Vec<String> =
        serde_json::from_str(&receiver_ids_json).unwrap_or_default();
    let (policy_user_id, user_signing_identifier_hex) = if !receiver_ids.is_empty() {
        let receiver_id_hex = &receiver_ids[0];
        let vs_hex = parsers::extract_verifying_share(
            &result.public_key_package_json,
            receiver_id_hex,
        )?;
        (vs_hex, Some(receiver_id_hex.clone()))
    } else {
        (user_id_hex.to_string(), None)
    };

    let server_dkg_secret_hex =
        crypto_ops::dkg_session_get_server_internal_secret_hex(user, dkg_h)
            .map_err(|e| Status::internal(format!("get_secret: {e}")))?;
    let recovery_id = user_recovery_id_hex.unwrap_or_default();

    // Restore: if this recovery_id was previously associated with another
    // user_id, preserve their spending history (via persistence — registry's
    // recovery_idx might be cold for an evicted actor). Then clean up the old
    // policy entries.
    let preserved_history = if !recovery_id.is_empty() {
        let mut preserved = Vec::new();
        if let Ok(Some(old_user_id)) = shared.persistence.get("policy_recovery_idx", &recovery_id) {
            if let Ok(Some(json_str)) = shared.persistence.get("policies", &old_user_id) {
                if let Ok(ps) = serde_json::from_str::<PolicyState>(&json_str) {
                    if ps.recovery_id == recovery_id {
                        preserved = ps.spending_history.clone();
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
        preserved
    } else {
        Vec::new()
    };

    let normal_policy = NormalPolicy {
        id: "normal policies".to_string(),
        key_package_json: result.key_package_json,
        public_key_package_json: result.public_key_package_json,
    };
    let policy_state = PolicyState {
        user_id: policy_user_id.clone(),
        recovery_id,
        user_signing_identifier_hex,
        server_dkg_secret_hex: Some(server_dkg_secret_hex),
        normal_policy,
        protected_policies: HashMap::new(),
        spending_history: preserved_history,
    };

    persist_policy(shared, registry, &policy_user_id, &policy_state)?;

    // Forward index: the URL/auth user_id used during DKG is the wallet's
    // owner pubkey, but the policy is persisted under the FROST verifying-share
    // (since post-DKG auth signatures verify against that share). This index
    // lets the actor for the owner pubkey find its canonical policy on respawn,
    // and lets clients use either identity in the URL.
    if policy_user_id != user_id_hex {
        if let Err(e) =
            shared
                .persistence
                .put("policy_owner_idx", user_id_hex, &policy_user_id)
        {
            tracing::warn!("persist policy_owner_idx/{user_id_hex} failed: {e}");
        }
    }

    user.policy_state = Some(policy_state);
    tracing::info!("[{user_id_hex}] DKG Complete");
    Ok(())
}

fn step3_build_response(
    user: &mut CosignerInstance,
    dkg_h: wasmtime::component::ResourceAny,
    sender_identifier_hex: &str,
) -> Result<DkgStep3Response, Status> {
    let relay_json =
        crypto_ops::dkg_session_get_relay_packages_for(user, dkg_h, sender_identifier_hex)
            .map_err(|e| Status::internal(format!("get_relay_for: {e}")))?;
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

fn drain_with_err<T>(pool: &mut Vec<oneshot::Sender<Result<T, Status>>>, msg: &str) {
    for s in pool.drain(..) {
        let _ = s.send(Err(Status::internal(msg.to_string())));
    }
}

fn drain_pairs_with_err<K, T>(
    pool: &mut Vec<(K, oneshot::Sender<Result<T, Status>>)>,
    msg: &str,
) {
    for (_, s) in pool.drain(..) {
        let _ = s.send(Err(Status::internal(msg.to_string())));
    }
}
