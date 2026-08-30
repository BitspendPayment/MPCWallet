//! Concurrent registry of per-user actors plus the tokio actor loop that owns + drives each.
//!
//! All signing keys + the FROST ceremony live in the per-actor `cosigner-actor` component;
//! the host keeps only non-secret `CosignerState` (policy, UTXOs, vtxos, history, sessions).
//! The registry is a `DashMap` of mpsc senders; lookup, dispatch, and stream fan-out are
//! lock-free across distinct users. Each user has exactly one actor: `run_cosigner` is a
//! tokio task that owns its `CosignerState` and processes commands serially. Per-command
//! host work runs inside `spawn_blocking`, so an idle actor is just memory, not a thread.
//! `CosignerState` lives behind `Arc<parking_lot::Mutex<>>` (no poison on panic), so a caught
//! handler panic leaves it consistent and the recv loop simply continues.

use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use dashmap::DashMap;
use futures::FutureExt;
use parking_lot::Mutex;
use tokio::sync::{mpsc, oneshot};
use tonic::Status;

use crate::shared::SharedServices;

use super::actor::CosignerActor;
use super::command::CosignerCommand;
use super::handle::{CosignerHandle, OwnedHandle};
use super::handlers;
use super::state::{CosignerState, DeviceToken};
use crate::cosigner::types::{
    ApplyDelegateSigs, ArkTxEntry, BoardingSettleOutcome, GenerateDelegate, SendVtxoStep1,
    SendVtxoStep2, SignStep1, SignStep2, VtxoInput,
};
use crate::wallet_proto::{
    send_vtxo_response, settle_delegate_response, settle_response, sign_step1_response,
    SendVtxoRequest, SendVtxoResponse, SettleDelegateRequest, SettleDelegateResponse,
    SettleRequest, SettleResponse, SignStep1Request, SignStep1Response, SignStep2Request,
    SignStep2Response,
};

fn now_secs() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Per-actor mailbox depth. Sized for normal request bursts plus a margin for
/// stream fan-in (VTXO updates, indexer events).
const MAILBOX_CAPACITY: usize = 256;

pub struct CosignerRegistry {
    shared: Arc<SharedServices>,
    /// Active actors keyed by user_id_hex. Each owns a native `CosignerActor` (keys + FROST
    /// ceremony + per-user state) — the cosigner runs in-process.
    actors: DashMap<String, OwnedHandle>,
    /// Reverse index: vtxo_script_hex → user_id_hex. Used by the global VTXO
    /// stream to route notifications to the right actor without scanning
    /// per-user persistence on every event.
    script_idx: DashMap<String, String>,
}

impl CosignerRegistry {
    pub fn new(shared: Arc<SharedServices>) -> Result<Arc<Self>, Box<dyn std::error::Error>> {
        Ok(Arc::new(Self {
            shared,
            actors: DashMap::new(),
            script_idx: DashMap::new(),
        }))
    }

    pub fn shared(&self) -> &Arc<SharedServices> {
        &self.shared
    }

    /// Get the existing actor handle for `group_key`, or spawn a new one.
    /// Cheap fast path when the actor already exists (DashMap read).
    pub fn get_or_spawn(self: &Arc<Self>, group_key: &str) -> Result<CosignerHandle, Status> {
        // Actors are keyed by their GROUP KEY (cosigner_id). A request addressed by a
        // member's verifying share resolves to the group's actor via `policy_owner_idx`,
        // so every member of a group shares one actor (one for a normal wallet, many
        // for a pairing). `CosignerState.cosigner_id` is then this canonical id.
        let canonical = self
            .shared
            .persistence
            .get("policy_owner_idx", group_key)
            .ok()
            .flatten()
            .unwrap_or_else(|| group_key.to_string());
        let group_key = canonical.as_str();
        if let Some(entry) = self.actors.get(group_key) {
            return Ok(entry.handle.clone());
        }
        // Slow path: only the `entry()` winner spawns. The actor rehydrates its own state on
        // startup, so no blocking I/O runs under the shard lock and there's no speculative
        // spawn/abort — a concurrent caller for the same key just reuses the winner's handle.
        match self.actors.entry(group_key.to_string()) {
            dashmap::mapref::entry::Entry::Occupied(e) => Ok(e.get().handle.clone()),
            dashmap::mapref::entry::Entry::Vacant(e) => {
                let (tx, rx) = mpsc::channel::<CosignerCommand>(MAILBOX_CAPACITY);
                let last_active = Arc::new(AtomicI64::new(now_secs()));
                tokio::spawn(run_cosigner(
                    group_key.to_string(),
                    rx,
                    self.shared.clone(),
                    self.clone(),
                    last_active.clone(),
                ));
                let handle = CosignerHandle::new(tx);
                e.insert(OwnedHandle {
                    handle: handle.clone(),
                    last_active,
                });
                tracing::info!("Spawned actor for user {group_key}");
                Ok(handle)
            }
        }
    }

    /// Evict an actor if it has been idle past the threshold. Atomic
    /// re-check inside `remove_if` prevents a race with a new `recv()`
    /// landing between the snapshot and the removal.
    ///
    /// On removal: best-effort `try_send(Shutdown)` to nudge the actor's
    /// recv loop to exit gracefully. Even if that fails, dropping the
    /// `OwnedHandle` drops the sender side; the actor's `rx.recv()` will
    /// return `None` once all senders are dropped and the task ends
    /// naturally.
    pub fn try_evict(&self, user_id_hex: &str, threshold_secs: i64) -> bool {
        let now = now_secs();
        let removed = self.actors.remove_if(user_id_hex, |_, owned| {
            now - owned.last_active_secs() >= threshold_secs
        });
        match removed {
            Some((_, owned)) => {
                let idle_for = now - owned.last_active_secs();
                tracing::info!("Evicting idle actor {user_id_hex} (idle for {idle_for}s)");
                let _ = owned.handle.try_send(CosignerCommand::Shutdown);
                // Drop the handle to release the last sender, so the actor's
                // recv loop unblocks if it's waiting.
                drop(owned);
                true
            }
            None => false,
        }
    }

    /// Send a command to the user's actor and await the typed reply.
    /// `make_cmd` receives the reply oneshot sender and returns the command to send.
    pub async fn dispatch<T, F>(self: &Arc<Self>, group_key: &str, make_cmd: F) -> Result<T, Status>
    where
        F: FnOnce(oneshot::Sender<Result<T, Status>>) -> CosignerCommand,
    {
        let handle = self.get_or_spawn(group_key)?;
        let (reply_tx, reply_rx) = oneshot::channel();
        let cmd = make_cmd(reply_tx);
        handle
            .send(cmd)
            .await
            .map_err(|_| Status::internal("user actor unavailable"))?;
        reply_rx
            .await
            .map_err(|_| Status::internal("user actor dropped reply"))?
    }

    // -------------------------------------------------------------------
    // Script ownership index — used by the global VTXO stream to route
    // events to the right actor without per-event persistence reads.
    // (Recovery lookups go straight to `policy_recovery_idx` in sled —
    // there's no in-memory cache for them; the lookup is rare and the cache
    // would have introduced a stale-after-restore-delete hazard.)
    // -------------------------------------------------------------------

    pub fn user_for_script(&self, script_hex: &str) -> Option<String> {
        self.script_idx.get(script_hex).map(|v| v.clone())
    }

    pub fn set_script_owner(&self, script_hex: &str, user_id_hex: &str) {
        self.script_idx
            .insert(script_hex.to_string(), user_id_hex.to_string());
    }

    /// Populate `script_idx` from the persistence backend. Called once at
    /// startup so VTXO stream lookups don't have to wake any actors.
    pub fn load_indices_from_persistence(&self) -> Result<(), Box<dyn std::error::Error>> {
        for (script_hex, user_id) in self.shared.persistence.get_all("ark_script_to_user")? {
            self.script_idx.insert(script_hex, user_id);
        }
        Ok(())
    }

    /// Snapshot every spawned actor's mailbox sender. Used by the global
    /// auto-settle tick task to fan out `TickAutoSettle` without holding the
    /// DashMap across an `await`.
    pub fn snapshot_handles(&self) -> Vec<(String, CosignerHandle)> {
        self.actors
            .iter()
            .map(|e| (e.key().clone(), e.value().handle.clone()))
            .collect()
    }
}

// ===========================================================================
// The tokio actor that owns the per-cosigner `CosignerState` and drives it.
// All signing keys + ceremony live in the per-actor `cosigner-actor`.
// ===========================================================================

/// Lock `state` inside `spawn_blocking`, run `f`, return the typed
/// result. `(user, state)` ownership stays with the actor task across this
/// call; the mutex guards only protect against panic-recovery reseating the
/// instance.
///
/// On a handler panic, `spawn_blocking` returns `Err(JoinError::is_panic)`.
/// We surface that as `Err(Status::internal("handler panicked"))` so the
/// caller's oneshot reply fires with an error instead of hanging. The actor
/// task itself stays alive — its outer `catch_unwind` in `run_cosigner` reseats
/// the wedged WASM instance and drains in-flight rendezvous replies.
pub(crate) async fn run_blocking<F, T>(state: Arc<Mutex<CosignerState>>, f: F) -> Result<T, Status>
where
    F: FnOnce(&mut CosignerState) -> Result<T, Status> + Send + 'static,
    T: Send + 'static,
{
    let outcome = tokio::task::spawn_blocking(move || {
        let mut state = state.lock();
        f(&mut state)
    })
    .await;
    match outcome {
        Ok(res) => res,
        Err(join_err) if join_err.is_panic() => {
            tracing::error!("actor handler panicked: {join_err:?}");
            Err(Status::internal("handler panicked"))
        }
        Err(join_err) => Err(Status::internal(format!(
            "actor handler task error: {join_err:?}"
        ))),
    }
}

/// Rehydrate a fresh actor's durable state from persistence (vtxos, history, device tokens, and
/// the secret-free auto-settle delegate marker). Runs in the actor task on startup, so these
/// blocking loads happen off the spawn path — no DashMap lock is held across them (see get_or_spawn).
fn rehydrate_cosigner_state(group_key: &str, shared: &SharedServices) -> CosignerState {
    let persistence = shared.persistence.as_ref();
    let mut fresh_state = CosignerState::new(group_key.to_string());
    fresh_state.vtxos = super::handlers::helpers::load_user_vtxos(persistence, group_key);
    fresh_state.ark_tx_history =
        super::handlers::helpers::load_user_ark_history(persistence, group_key);
    fresh_state.device_tokens =
        super::handlers::helpers::load_user_device_tokens(persistence, group_key);

    let delegate_loaded =
        match super::handlers::helpers::load_guest_delegate_threshold(persistence, group_key) {
            Some(threshold) => {
                fresh_state.guest_delegate_threshold = Some(threshold);
                true
            }
            None => false,
        };

    if !fresh_state.vtxos.is_empty()
        || !fresh_state.ark_tx_history.is_empty()
        || !fresh_state.device_tokens.is_empty()
        || delegate_loaded
    {
        tracing::info!(
            "Rehydrated actor {group_key}: vtxos={}, history={}, device_tokens={}, delegate={}",
            fresh_state.vtxos.len(),
            fresh_state.ark_tx_history.len(),
            fresh_state.device_tokens.len(),
            delegate_loaded,
        );
    }
    fresh_state
}

pub async fn run_cosigner(
    group_key: String,
    mut rx: mpsc::Receiver<CosignerCommand>,
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
    last_active: Arc<AtomicI64>,
) {
    // Rehydrate durable state on startup (off the spawn path — see get_or_spawn).
    let state = Arc::new(Mutex::new(rehydrate_cosigner_state(&group_key, &shared)));

    // Per-actor native-async actor (lazily spawned on the first sign). Its in-WASM state
    // (keys + ceremony) persists across commands. ALL signing routes through it.
    let mut actor: Option<CosignerActor> = None;
    let mut actor_policy_installed = false;

    while let Some(cmd) = rx.recv().await {
        // Per issue #30 design choice: every recv() event counts as activity.
        // This includes TickAutoSettle / stream events, which means actors in
        // ASP-connected deployments effectively never idle out. Eviction is
        // dormant in normal operation by design.
        last_active.store(now_secs(), Ordering::Relaxed);

        if matches!(cmd, CosignerCommand::Shutdown) {
            break;
        }

        // Intercept signing: every spend (script-path, key-path tweak) routes
        // through the native-async actor where the keys live. Runs outside the
        // catch_unwind below because the actor path surfaces errors as replies.
        let cmd = match cmd {
            CosignerCommand::ServiceRefresh {
                receiver_id_hex,
                receiver_partial_point,
                wallet_id_hex,
                a_at_cosigner,
                min_signers,
                service_id,
                policy,
                reply,
            } => {
                route_service_refresh(
                    receiver_id_hex,
                    receiver_partial_point,
                    wallet_id_hex,
                    a_at_cosigner,
                    min_signers,
                    service_id,
                    policy,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            CosignerCommand::ListServicePairings { reply } => {
                if let Err(e) =
                    ensure_actor(&state, &shared, &registry, &mut actor, &mut actor_policy_installed)
                        .await
                {
                    let _ = reply.send(Err(e));
                    continue;
                }
                let _ = reply.send(Ok(actor.as_ref().unwrap().list_service_pairings()));
                continue;
            }
            CosignerCommand::RemoveServicePairing {
                verifying_share_hex,
                reply,
            } => {
                if let Err(e) =
                    ensure_actor(&state, &shared, &registry, &mut actor, &mut actor_policy_installed)
                        .await
                {
                    let _ = reply.send(Err(e));
                    continue;
                }
                match actor.as_mut().unwrap().remove_service_pairing(&verifying_share_hex) {
                    Ok(removed) => {
                        // Seal before replying: a revocation the caller believes succeeded must
                        // not come back after a restart.
                        if removed {
                            let gk = state.lock().cosigner_id.clone();
                            persist_actor_snapshot(actor.as_mut().unwrap(), &shared, &gk).await;
                        }
                        let _ = reply.send(Ok(removed));
                    }
                    Err(e) => {
                        let _ = reply.send(Err(Status::internal(e)));
                        reseat_actor(&mut actor, &mut actor_policy_installed);
                    }
                }
                continue;
            }
            CosignerCommand::SignStep1 { req, reply } => {
                route_sign_step1(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            CosignerCommand::SignStep2 { req, reply } => {
                route_sign_step2(req, reply, &mut actor, &mut actor_policy_installed).await;
                continue;
            }
            // SendVtxo: the session + signing live in the actor (keys never leave it); the
            // host only translates its VTXO projection in/out. Falls back to the legacy
            // host handler when the ASP URL isn't configured for the actor.
            CosignerCommand::SendVtxo { req, reply } => {
                route_send_vtxo(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            // Delegate-settle: the cosigner secret + session live in the actor; the host
            // only relays. Falls back to the legacy host handler without ASP config.
            CosignerCommand::SettleDelegate { req, reply } => {
                route_settle_delegate(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            // Boarding settle: the host drives the batch + stream + FROST rounds, but the MuSig2
            // tree-signing secret stays in the actor (Plan A Phase 2). Falls back to the legacy
            // host handler (plaintext dkg-secret) only when the ASP URL isn't configured.
            CosignerCommand::Settle { req, reply } => {
                route_settle_boarding(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            // Auto-settle tick: if this actor has a actor-routed delegate pending, drive it in
            // the actor. Otherwise fall through to the legacy host tick.
            CosignerCommand::TickAutoSettle if state.lock().guest_delegate_threshold.is_some() => {
                route_tick_auto_settle(
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            // Seed freshly-computed policy material into the actor and seal it (onboarding /
            // service enrolment). After this the keys live in the actor's sealed snapshot.
            CosignerCommand::SeedPolicy {
                key_package_json,
                public_key_package_json,
                user_signing_identifier_hex,
                server_dkg_secret_hex,
                reply,
            } => {
                route_seed_policy(
                    key_package_json,
                    public_key_package_json,
                    user_signing_identifier_hex,
                    server_dkg_secret_hex,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            // Request-to-pay writes. Intercepted here (not `actor.dispatch`) because each mutates
            // the actor's SEALED state and must therefore re-persist the snapshot.
            CosignerCommand::ContactAdd { req, reply } => {
                route_contact_add(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            CosignerCommand::ContactRemove { req, reply } => {
                route_contact_remove(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            CosignerCommand::PaymentRequestCreate { req, reply } => {
                route_payment_request_create(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            CosignerCommand::PaymentRequestDecline { req, reply } => {
                route_payment_request_decline(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            other => other,
        };

        // Plan A: the native actor is the source of `policy_state` (no `policies` sled tree) — ensure
        // it's loaded (cheap, in-process) so the sync handlers below see the projection. Best-effort:
        // policy-free commands (GetArkInfo, etc.) and pre-onboarding actors proceed on error.
        let _ = ensure_actor(
            &state,
            &shared,
            &registry,
            &mut actor,
            &mut actor_policy_installed,
        )
        .await;


        let dispatch_outcome = AssertUnwindSafe(
            actor
                .as_mut()
                .expect("ensure_actor created the actor above")
                .dispatch(cmd, registry.clone()),
        )
        .catch_unwind()
        .await;

        if dispatch_outcome.is_err() {
            tracing::error!("actor caught unwind during dispatch; continuing");
        }
    }
}

/// Drop the actor so the next normal sign respawns it from a clean state. Called when a
/// actor command traps/errors (the in-WASM ceremony may be wedged).
fn reseat_actor(actor: &mut Option<CosignerActor>, installed: &mut bool) {
    *actor = None;
    *installed = false;
}

/// Phase 4: opaque sealed-state tree (one blob per group key). The host stores it but
/// cannot read it (identity-sealed JSON today; enclave AEAD later). Keyed by group key.
const SEALED_STATE_TREE: &str = "sealed_state";

/// Persist the actor's snapshot blob after a state mutation (best-effort).
/// Re-seal an actor whose state changed outside a `route_*` fn.
pub(crate) async fn persist_actor_snapshot_for(
    actor: &mut CosignerActor,
    group_key: &str,
) {
    // The actor holds its own `shared`, so callers don't have to thread it through.
    let shared = actor.shared.clone();
    persist_actor_snapshot(actor, &shared, group_key).await;
}

async fn persist_actor_snapshot(
    actor: &mut CosignerActor,
    shared: &SharedServices,
    group_key: &str,
) {
    match actor.to_snapshot() {
        Ok(blob) => {
            if let Err(e) = shared
                .persistence
                .put(SEALED_STATE_TREE, group_key, &hex::encode(blob))
            {
                tracing::warn!("persist sealed_state/{group_key} failed: {e}");
            }
        }
        Err(e) => tracing::warn!("snapshot failed: {e}"),
    }
}

/// Restore the actor's state from a persisted snapshot, if one exists (on spawn/reseat).
/// Returns `true` when a snapshot was restored — meaning the actor now holds its policy +
/// keys from the sealed blob, so the caller can SKIP `InstallPolicy` (no plaintext key read).
/// `false` when there's no stored blob (first run) or restore failed.
async fn restore_actor_snapshot(
    actor: &mut CosignerActor,
    shared: &SharedServices,
    group_key: &str,
) -> bool {
    let stored = shared.persistence.get(SEALED_STATE_TREE, group_key);
    let Ok(Some(hex_blob)) = stored else {
        return false;
    };
    let Ok(blob) = hex::decode(&hex_blob) else {
        tracing::warn!("sealed_state/{group_key}: corrupt hex; ignoring");
        return false;
    };
    match actor.restore_snapshot(&blob) {
        Ok(()) => {
            tracing::info!("restored actor snapshot for {group_key}");
            true
        }
        Err(e) => {
            tracing::warn!("restore failed: {e}");
            false
        }
    }
}

/// Route `ServiceRefresh`: ensure the wallet's actor is up + its policy
/// restored/installed, then refresh `V` onto the pairing INSIDE the actor. The host never reads
/// `V`; it only relays the public PKP + the (transient, never-persisted) pairing key package.
#[allow(clippy::too_many_arguments)]
async fn route_service_refresh(
    receiver_id_hex: String,
    receiver_partial_point: Vec<u8>,
    wallet_id_hex: String,
    a_at_cosigner: Vec<u8>,
    min_signers: u32,
    service_id: Vec<u8>,
    policy: crate::cosigner::types::ServicePolicy,
    reply: oneshot::Sender<Result<crate::cosigner::command::ServiceRefreshOutput, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    let result = actor.as_mut().unwrap().service_refresh(
        &receiver_id_hex,
        &receiver_partial_point,
        &wallet_id_hex,
        &a_at_cosigner,
        min_signers as usize,
        &service_id,
        policy,
    );
    match result {
        Ok(refreshed) => {
            // Seal BEFORE replying. `service_refresh` just installed the cosigner's counter-share
            // into the actor's pairing map; handing the service its half while that record is
            // still only in memory would leave a service holding a share the cosigner forgets on
            // the next restart — a silently dead pairing.
            let group_key = state.lock().cosigner_id.clone();
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            let _ = reply.send(Ok(crate::cosigner::command::ServiceRefreshOutput {
                pairing_public_key_package_json: refreshed.pairing_public_key_package_json,
                receiver_half: refreshed.receiver_half,
                service_verifying_share_hex: refreshed.service_verifying_share_hex,
            }));
        }
        Err(msg) => {
            let _ = reply.send(Err(Status::internal(format!("service_refresh: {msg}"))));
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Route `SignStep1`: spends go to the native-async actor where the keys live (cooperative Ark
/// spends are always script-path). A `{service, cosigner}` pairing routes to its own actor, which
/// enforces its sealed ceiling before producing a share.
#[allow(clippy::too_many_arguments)]
async fn route_sign_step1(
    req: SignStep1Request,
    reply: oneshot::Sender<Result<SignStep1Response, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    _registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    // The group key is the actor's own id; signing routes to the actor, which restores keys +
    // state from its sealed snapshot. OPTIONAL host policy material (`Some` only for an actor the
    // host keeps a routing projection for — the normal wallet) is the InstallPolicy fallback for
    // the rare case there's no seal yet. A `{service, cosigner}` pairing actor has NO host
    // projection in Plan A 1C: it is eager-sealed at create and restores purely from its snapshot.
    let group_key = state.lock().cosigner_id.clone();
    let material = {
        let mut state_guard = state.lock();
        if handlers::helpers::ensure_policy_loaded(
            &mut state_guard,
            shared.persistence.as_ref(),
            &group_key,
        )
        .is_ok()
        {
            state_guard.policy_state.as_ref().map(|p| {
                (
                    p.normal_policy.key_package_json.clone(),
                    p.normal_policy.public_key_package_json.clone(),
                    p.user_signing_identifier_hex.clone(),
                    p.server_dkg_secret_hex.clone(),
                )
            })
        } else {
            None
        }
    };

    // Lazily create the native cosigner core, then install the policy once.
    if actor.is_none() {
        *actor = Some(CosignerActor::new(shared.clone(), state.clone()));
        *actor_policy_installed = false;
    }
    if !*actor_policy_installed {
        let gk = group_key.clone();

        if restore_actor_snapshot(actor.as_mut().unwrap(), shared, &gk).await {
            *actor_policy_installed = true;
        } else if let Some((
            key_package_json,
            public_key_package_json,
            user_identifier_hex,
            server_dkg_secret_hex,
        )) = material
        {
            // No snapshot yet but the host holds policy material (normal wallet, pre-seal edge):
            // install from it, then immediately seal so every later cold spawn restores instead.
            // A pairing actor never reaches here — it has no material and MUST restore from its seal.
            let result = actor.as_mut().unwrap().install_policy(
                group_key,
                &key_package_json,
                &public_key_package_json,
                user_identifier_hex.as_deref(),
                server_dkg_secret_hex,
            );
            match result {
                Ok(()) => *actor_policy_installed = true,
                Err(e) => {
                    let _ = reply.send(Err(Status::internal(format!("InstallPolicy: {e}"))));
                    reseat_actor(actor, actor_policy_installed);
                    return;
                }
            }
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &gk).await;
        } else {
            // No sealed snapshot and no host policy material.
            reseat_actor(actor, actor_policy_installed);
            let _ = reply.send(Err(Status::failed_precondition(
                "actor has no sealed snapshot and no policy material (not seeded)",
            )));
            return;
        }
    }

    let wire = SignStep1 {
        user_id: req.user_id,
        hiding_commitment: req.hiding_commitment,
        binding_commitment: req.binding_commitment,
        message_to_sign: req.message_to_sign,
        signature: req.signature,
        full_transaction: req.full_transaction,
        timestamp_ms: req.timestamp_ms,
        script_path_spend: req.script_path_spend,
    };
    match actor.as_mut().unwrap().sign_step1(wire) {
        Ok(out) => {
            let mut response = SignStep1Response::default();
            for c in out.commitments {
                response.commitments.insert(
                    c.identifier_hex,
                    sign_step1_response::Commitment {
                        hiding: c.hiding,
                        binding: c.binding,
                    },
                );
            }
            response.message_to_sign = out.message_to_sign;
            let _ = reply.send(Ok(response));
        }
        Err(msg) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Route `SignStep2` through the per-actor actor (the only sign path).
async fn route_sign_step2(
    req: SignStep2Request,
    reply: oneshot::Sender<Result<SignStep2Response, Status>>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if actor.is_none() {
        // The actor is established in step1; if it's gone (e.g. reseated mid-ceremony) the
        // client must restart from step1. The legacy in-WASM sign path no longer exists.
        let _ = reply.send(Err(Status::internal(
            "actor unavailable for sign step2; restart from step1",
        )));
        return;
    }

    let wire = SignStep2 {
        user_id: req.user_id,
        signature_share: req.signature_share,
        signature: req.signature,
        timestamp_ms: req.timestamp_ms,
    };
    match actor.as_mut().unwrap().sign_step2(wire) {
        Ok(out) => {
            let _ = reply.send(Ok(SignStep2Response {
                r_point: out.r_point,
                z_scalar: out.z_scalar,
            }));
        }
        Err(msg) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Seed freshly-computed policy material (from onboarding / service enrolment) into the
/// per-actor actor and seal it into the actor's snapshot. After this the keys live in the
/// actor's sealed blob, so later cold spawns restore them without a host-side plaintext key.
#[allow(clippy::too_many_arguments)]
#[allow(clippy::too_many_arguments)]
async fn route_seed_policy(
    key_package_json: String,
    public_key_package_json: String,
    user_signing_identifier_hex: Option<String>,
    server_dkg_secret_hex: Option<String>,
    reply: oneshot::Sender<Result<(), Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    let group_key = state.lock().cosigner_id.clone();
    // SeedPolicy is only ever called for a FRESH actor (onboarding wallet, or a new pairing actor),
    // The secret key + `service_pairing` install into the actor +
    // seal; the host keeps only this routing projection.
    {
        let mut s = state.lock();
        s.policy_state = Some(crate::cosigner::state::PolicyState {
            cosigner_id: group_key.clone(),
            user_signing_identifier_hex,
            server_dkg_secret_hex,
            normal_policy: crate::cosigner::state::NormalPolicy {
                id: "normal".to_string(),
                key_package_json,
                public_key_package_json,
            },
        });
    }
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
    let _ = reply.send(Ok(()));
}


// ---------------------------------------------------------------------------
// Request-to-pay. Each mutates the actor's SEALED state, so each re-persists the snapshot.
// ---------------------------------------------------------------------------

/// Authorize a party to bill this wallet. Signed by the owner (auth ran at the REST boundary).
#[allow(clippy::too_many_arguments)]
async fn route_contact_add(
    req: crate::wallet_proto::ContactAddRequest,
    reply: oneshot::Sender<Result<crate::wallet_proto::ContactAddResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    if let Err(e) = actor.as_ref().unwrap().require_owner(&req.user_id) {
        let _ = reply.send(Err(e));
        return;
    }
    let group_key = state.lock().cosigner_id.clone();
    // Normalise to the contact's GROUP key so the allowlist compares canonically, whichever of a
    // wallet's ids the caller used.
    let vk_hex = handlers::helpers::group_key_of(
        shared.persistence.as_ref(),
        &hex::encode(&req.contact_verifying_key),
    );
    match actor
        .as_mut()
        .unwrap()
        .add_contact(vk_hex, req.label, now_secs())
    {
        Ok(()) => {
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            let _ = reply.send(Ok(crate::wallet_proto::ContactAddResponse { ok: true }));
        }
        Err(e) => {
            let _ = reply.send(Err(Status::invalid_argument(e)));
        }
    }
}

/// Revoke a contact. Also drops that contact's pending requests — revoking must actually stop the
/// billing, not merely prevent new ones.
#[allow(clippy::too_many_arguments)]
async fn route_contact_remove(
    req: crate::wallet_proto::ContactRemoveRequest,
    reply: oneshot::Sender<Result<crate::wallet_proto::ContactRemoveResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    if let Err(e) = actor.as_ref().unwrap().require_owner(&req.user_id) {
        let _ = reply.send(Err(e));
        return;
    }
    let group_key = state.lock().cosigner_id.clone();
    let vk_hex = handlers::helpers::group_key_of(
        shared.persistence.as_ref(),
        &hex::encode(&req.contact_verifying_key),
    );
    match actor.as_mut().unwrap().remove_contact(&vk_hex) {
        Ok(()) => {
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            let _ = reply.send(Ok(crate::wallet_proto::ContactRemoveResponse { ok: true }));
        }
        Err(e) => {
            let _ = reply.send(Err(Status::not_found(e)));
        }
    }
}

/// Cross-user: `req.user_id` is the REQUESTER, this actor is the PAYER. `verify_auth` proves key
/// possession but does NOT bind the signer to this actor, so the allowlist is the only
/// authorization — checked before any state is touched.
#[allow(clippy::too_many_arguments)]
async fn route_payment_request_create(
    req: crate::wallet_proto::PaymentRequestCreateRequest,
    reply: oneshot::Sender<Result<crate::wallet_proto::PaymentRequestCreateResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    let group_key = state.lock().cosigner_id.clone();
    // Resolve whichever id the requester used to its GROUP key: the canonical allowlist identity,
    // and the key the payee address MUST derive from — a share key yields an address the requester
    // cannot spend, while the payment still appears to succeed.
    let from_vk_hex = handlers::helpers::group_key_of(
        shared.persistence.as_ref(),
        &hex::encode(&req.user_id),
    );

    // Authorization gate — before anything else.
    if !actor.as_ref().unwrap().is_contact(&from_vk_hex) {
        let _ = reply.send(Err(Status::permission_denied(
            "not an authorized contact of this wallet",
        )));
        return;
    }

    // Derive the payee address from the allowlisted key; never trust a supplied one, or a contact
    // could redirect the payment. x-only = compressed key minus its parity byte.
    if from_vk_hex.len() != 66 {
        let _ = reply.send(Err(Status::invalid_argument(
            "requester key must be a 33-byte compressed pubkey",
        )));
        return;
    }
    let owner_xonly = from_vk_hex[2..].to_string();
    let info = {
        let asp_arc = shared.asp_client.clone();
        let mut asp = asp_arc.lock().await;
        match asp.get_info().await {
            Ok(i) => i,
            Err(e) => {
                let _ = reply.send(Err(Status::unavailable(format!("ASP GetInfo: {e}"))));
                return;
            }
        }
    };
    let network = match ark::client::parse_network(&info.network) {
        Ok(n) => n,
        Err(e) => {
            let _ = reply.send(Err(Status::internal(e)));
            return;
        }
    };
    let to_ark_address = match ark::client::ark_address(
        &owner_xonly,
        &info.signer_pubkey,
        info.unilateral_exit_delay as u32,
        network,
    ) {
        Ok(a) => a,
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("derive ark address: {e}"))));
            return;
        }
    };

    let intent = match actor.as_mut().unwrap().create_payment_intent(
        from_vk_hex,
        to_ark_address,
        req.amount_sats,
        req.memo,
        req.expires_in_secs,
        now_secs(),
    ) {
        Ok(i) => i,
        Err(e) => {
            let _ = reply.send(Err(Status::invalid_argument(e)));
            return;
        }
    };
    persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;

    // Best-effort nudge on two channels; the sealed intent is the durable record, so a failed
    // notification must never fail the request.
    shared.events.publish(
        &group_key,
        crate::events::CosignerEvent::PaymentRequest {
            id: intent.id.clone(),
            from_vk_hex: intent.from_vk_hex.clone(),
            amount_sats: intent.amount_sats,
        },
    );
    if let Some(fcm) = shared.fcm.clone() {
        let persistence = shared.persistence.clone();
        let payer = group_key.clone();
        let amount = intent.amount_sats;
        let id = intent.id.clone();
        tokio::spawn(async move {
            let tokens = handlers::helpers::load_user_device_tokens(persistence.as_ref(), &payer);
            push_payment_request(&fcm, &payer, &tokens, &id, amount).await;
        });
    }

    let _ = reply.send(Ok(crate::wallet_proto::PaymentRequestCreateResponse {
        intent: Some(handlers::payment_request::intent_to_proto(
            &intent,
            now_secs(),
        )),
    }));
}

/// The payer declines a pending request.
#[allow(clippy::too_many_arguments)]
async fn route_payment_request_decline(
    req: crate::wallet_proto::PaymentRequestDeclineRequest,
    reply: oneshot::Sender<Result<crate::wallet_proto::PaymentRequestDeclineResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    if let Err(e) = actor.as_ref().unwrap().require_owner(&req.user_id) {
        let _ = reply.send(Err(e));
        return;
    }
    let group_key = state.lock().cosigner_id.clone();
    match actor.as_mut().unwrap().decline_intent(&req.id) {
        Ok(()) => {
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            let _ =
                reply.send(Ok(crate::wallet_proto::PaymentRequestDeclineResponse { ok: true }));
        }
        Err(e) => {
            let _ = reply.send(Err(Status::failed_precondition(e)));
        }
    }
}

/// Ensure the per-actor actor is spawned and its policy installed. On error, returns a
/// `Status` for the caller to reply with (the actor is reseated on install failure).
async fn ensure_actor(
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    _registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) -> Result<(), Status> {
    let group_key = state.lock().cosigner_id.clone();
    if actor.is_none() {
        *actor = Some(CosignerActor::new(shared.clone(), state.clone()));
        *actor_policy_installed = false;
    }
    if !*actor_policy_installed {
        // Restore-FIRST: the seal carries keys + durable state + the PUBLIC projection.
        if restore_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await {
            // Plan A: the actor IS the source of `policy_state` — load the host projection from it
            // (replaces the removed `policies` sled tree).
            load_policy_state_from_actor(state, actor.as_mut().unwrap()).await?;
            *actor_policy_installed = true;
        } else {
            // First run (no seal): `policy_state` must be pre-set (route_seed_policy). Install + seal.
            let material = {
                let st = state.lock();
                st.policy_state.as_ref().map(|p| {
                    (
                        p.cosigner_id.clone(),
                        p.normal_policy.key_package_json.clone(),
                        p.normal_policy.public_key_package_json.clone(),
                        p.user_signing_identifier_hex.clone(),
                        p.server_dkg_secret_hex.clone(),
                    )
                })
            };
            let Some((gk, kpj, pkpj, usih, secret)) = material else {
                return Err(Status::not_found(format!("no policy for {group_key}")));
            };
            let result = actor.as_mut().unwrap().install_policy(
                gk,
                &kpj,
                &pkpj,
                usih.as_deref(),
                secret,
            );
            if let Err(e) = result {
                reseat_actor(actor, actor_policy_installed);
                return Err(Status::internal(format!("InstallPolicy: {e}")));
            }
            *actor_policy_installed = true;
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
        }
    }
    Ok(())
}

/// Populate the host `policy_state` projection from the native actor (Plan A: the actor's seal is
/// the single source of truth — there is no `policies` sled tree). The host keeps no secret key
/// (`key_package_json` blank, `server_dkg_secret_hex` None); `service_pairing` stays in the actor.
async fn load_policy_state_from_actor(
    state: &Arc<Mutex<CosignerState>>,
    actor: &mut CosignerActor,
) -> Result<(), Status> {
    match actor.public_policy() {
        Ok(pp) => {
            let mut st = state.lock();
            st.policy_state = Some(crate::cosigner::state::PolicyState {
                cosigner_id: pp.group_key,
                user_signing_identifier_hex: pp.user_signing_identifier_hex,
                server_dkg_secret_hex: None,
                normal_policy: crate::cosigner::state::NormalPolicy {
                    id: "normal".to_string(),
                    key_package_json: String::new(),
                    public_key_package_json: pp.public_key_package_json,
                },
            });
            Ok(())
        }
        Err(e) => Err(Status::internal(format!("GetPublicPolicy: {e}"))),
    }
}

/// Route `SendVtxo` through the actor. Phase 1 (no signatures): build the step1 wire from
/// the host VTXO projection, get sighashes. Phase 2 (signatures present): sign + submit in
/// the actor, then apply the result to the host VTXO/history projection. The session and
/// keys live entirely in the actor; the host only moves bytes and updates its projection.
#[allow(clippy::too_many_arguments)]
async fn route_send_vtxo(
    req: SendVtxoRequest,
    reply: oneshot::Sender<Result<SendVtxoResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }

    if req.signed_messages.is_empty() {
        // Carry the current VTXO set in the wire; the actor selects + balance-checks it itself.
        let wire = {
            let st = state.lock();
            SendVtxoStep1 {
                user_id: req.user_id.clone(),
                signature: req.signature.clone(),
                timestamp_ms: req.timestamp_ms,
                recipient_ark_address: req.recipient_ark_address.clone(),
                amount: req.amount,
                vtxos: st
                    .vtxos
                    .iter()
                    .map(|e| VtxoInput {
                        txid: e.txid.clone(),
                        vout: e.vout,
                        amount_sats: e.amount,
                        exit_delay: e.exit_delay,
                    })
                    .collect(),
            }
        };
        let result = actor
            .as_mut()
            .unwrap()
            .send_vtxo_step1(wire)
            .await;
        match result {
            Ok(messages_to_sign) => {
                let _ = reply.send(Ok(SendVtxoResponse {
                    status: send_vtxo_response::Status::SigningRequired as i32,
                    messages_to_sign,
                    script_path_spend: true,
                    ark_txid: String::new(),
                    error_message: String::new(),
                }));
            }
            Err(msg) => {
                let _ = reply.send(Err(Status::internal(format!("send_vtxo step1: {msg}"))));
                reseat_actor(actor, actor_policy_installed);
            }
        }
    } else {
        let wire = SendVtxoStep2 {
            user_id: req.user_id.clone(),
            signature: req.signature.clone(),
            timestamp_ms: req.timestamp_ms,
            signed_messages: req.signed_messages.clone(),
        };
        match actor.as_mut().unwrap().send_vtxo_step2(wire).await {
            Ok(submitted) => {
                // Kept because `submitted.ark_txid` is moved into `apply_send_result` below.
                let sent_txid = submitted.ark_txid.clone();
                // Mirror the send into the actor's owned history (it owns the data for the
                // sealed snapshot); the host projection is still updated for live queries.
                let entry = ArkTxEntry {
                    tx_type: "send".to_string(),
                    amount_sats: -(req.amount as i64),
                    txid: submitted.ark_txid.clone(),
                    timestamp: now_secs(),
                };
                let resp = {
                    let mut st = state.lock();
                    handlers::ark_send::apply_send_result(
                        &mut st,
                        shared,
                        &req,
                        submitted.ark_txid,
                        submitted.change,
                    )
                };
                actor.as_mut().unwrap().append_history(entry);
                // Mark any request this send satisfies as paid, matched on the STORED intent's
                // destination + amount so the seal stays the authority.
                if let Some(id) = actor.as_mut().unwrap().fulfil_matching_intent(
                    &req.recipient_ark_address,
                    req.amount,
                    &sent_txid,
                ) {
                    tracing::info!("payment request {id} fulfilled by {sent_txid}");
                }
                // Phase 4: the send mutated actor VTXOs + history — persist the snapshot.
                let group_key = state.lock().cosigner_id.clone();
                persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
                let _ = reply.send(Ok(resp));
            }
            Err(msg) => {
                let _ = reply.send(Err(Status::internal(format!("send_vtxo step2: {msg}"))));
                reseat_actor(actor, actor_policy_installed);
            }
        }
    }
}

/// Route `SettleDelegate` through the actor. Phase 1 (no signatures): push VTXOs + build the
/// delegate (self-refresh) → sighashes. Phase 2 (signatures): insert them (→ ReadyToSettle),
/// then either store for the auto-settle tick (`store_only`, snapshot persisted) or drive the
/// batch immediately. The cosigner secret + session never leave the actor.
#[allow(clippy::too_many_arguments)]
async fn route_settle_delegate(
    req: SettleDelegateRequest,
    reply: oneshot::Sender<Result<SettleDelegateResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    let group_key = state.lock().cosigner_id.clone();

    if req.signed_messages.is_empty() {
        // Phase 1: push the VTXO set + host-computed renewal deadline, then build the delegate.
        let prep = {
            let st = state.lock();
            handlers::ark_send::build_delegate_step1(&st, shared)
        };
        let (vtxos, intent_valid_at) = match prep {
            Ok(v) => v,
            Err(e) => {
                let _ = reply.send(Err(e));
                return;
            }
        };
        actor.as_mut().unwrap().set_vtxos(vtxos);
        let wire = GenerateDelegate {
            user_id: req.user_id,
            signature: req.signature,
            timestamp_ms: req.timestamp_ms,
            intent_valid_at,
        };
        match actor.as_mut().unwrap().generate_delegate(wire).await {
            Ok(messages_to_sign) => {
                let _ = reply.send(Ok(SettleDelegateResponse {
                    status: settle_delegate_response::Status::SigningRequired as i32,
                    messages_to_sign,
                    script_path_spend: true,
                    commitment_txid: String::new(),
                    error_message: String::new(),
                }));
            }
            Err(msg) => {
                let _ = reply.send(Err(Status::internal(format!("GenerateDelegate: {msg}"))));
                reseat_actor(actor, actor_policy_installed);
            }
        }
        return;
    }

    // Phase 2: insert the client's signatures → ReadyToSettle.
    let apply = ApplyDelegateSigs {
        user_id: req.user_id,
        signature: req.signature,
        timestamp_ms: req.timestamp_ms,
        signed_messages: req.signed_messages,
    };
    if let Err(msg) = actor.as_mut().unwrap().apply_delegate_sigs(apply) {
        let _ = reply.send(Err(Status::internal(format!("ApplyDelegateSigs: {msg}"))));
        reseat_actor(actor, actor_policy_installed);
        return;
    }

    if req.store_only {
        // Auto-settle path: the durable ReadyToSettle delegate is sealed in the actor snapshot; the
        // host records a SECRET-FREE "fire at" threshold (earliest VTXO expiry − margin) — both
        // in-memory (for TickAutoSettle) and persisted (so it survives a runtime restart).
        let threshold = {
            let mut st = state.lock();
            let earliest = st
                .vtxos
                .iter()
                .filter_map(|e| (e.expires_at > 0).then_some(e.expires_at))
                .min()
                .unwrap_or(0);
            let margin = shared.auto_settle_safety_margin_secs;
            let threshold = (earliest - margin).max(0);
            st.guest_delegate_threshold = Some(threshold);
            threshold
        };
        persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
        handlers::helpers::save_guest_delegate_threshold(
            shared.persistence.as_ref(),
            &group_key,
            threshold,
        );
        let _ = reply.send(Ok(SettleDelegateResponse {
            status: settle_delegate_response::Status::Delegated as i32,
            messages_to_sign: vec![],
            script_path_spend: false,
            commitment_txid: String::new(),
            error_message: String::new(),
        }));
        return;
    }

    // Manual path: drive the batch immediately in the actor.
    match actor.as_mut().unwrap().settle_delegate().await {
        Ok(settled) => {
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            let _ = reply.send(Ok(SettleDelegateResponse {
                status: settle_delegate_response::Status::Settled as i32,
                messages_to_sign: vec![],
                script_path_spend: false,
                commitment_txid: settled.commitment_txid,
                error_message: String::new(),
            }));
        }
        Err(msg) => {
            let _ = reply.send(Err(Status::internal(format!("SettleDelegate drive: {msg}"))));
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Boarding settle, fully GUEST-driven (Plan A): the host scans the boarding UTXO (public chain) and
/// relays the two FROST rounds; the GUEST owns the ASP event stream + MuSig2 tree-signing. Phase 1
/// (no sigs): scan + `BoardingSettleStep1` → intent sighashes. Phase 2 (intent sigs):
/// `BoardingSettleStep2` → commitment sighashes (the actor holds the open stream across the pause).
/// Phase 3 (commitment sigs): `BoardingSettleStep3` → the new VTXO. Progress = `state.guest_boarding`.
#[allow(clippy::too_many_arguments)]
async fn route_settle_boarding(
    req: SettleRequest,
    reply: oneshot::Sender<Result<SettleResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    // Per-user auth (OP_SETTLE) ran at the REST boundary; the actor no longer re-checks it here.
    let user_id_hex = handlers::parsers::user_id_hex(&req.user_id);
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        let _ = reply.send(Err(e));
        return;
    }
    let group_key = state.lock().cosigner_id.clone();

    // One outpoint per settle: `boarding_settle_step1` builds the intent proof for a
    // single boarding output. Silently taking `.first()` of a longer list boarded one
    // deposit and stranded the rest while the caller was told the whole batch settled,
    // so refuse instead — the client settles them one at a time.
    if req.boarding_utxos.len() > 1 {
        let _ = reply.send(Err(Status::invalid_argument(format!(
            "settle accepts one boarding UTXO at a time, got {} — settle them individually",
            req.boarding_utxos.len()
        ))));
        return;
    }
    let boarding_utxo = req
        .boarding_utxos
        .first()
        .map(|u| (u.txid.clone(), u.vout, u.amount_sats));

    // The ACTOR owns the boarding-settle phase via its in-flight session: no sigs ⇒ start (the
    // actor derives owner-pk + ASP info + the boarding address itself), with sigs ⇒ advance. The
    // host only relays the request and persists the finalized VTXO.
    let resp = actor
        .as_mut()
        .unwrap()
        .boarding_settle(boarding_utxo, req.signed_messages)
        .await;

    match resp {
        Ok(BoardingSettleOutcome::Sighashes(messages_to_sign)) => {
            let _ = reply.send(Ok(SettleResponse {
                status: settle_response::Status::SigningRequired as i32,
                messages_to_sign,
                script_path_spend: true,
                commitment_txid: String::new(),
                error_message: String::new(),
            }));
        }
        Ok(BoardingSettleOutcome::Submitted(sub)) => {
            {
                let mut st = state.lock();
                st.vtxos
                    .retain(|e| !(e.txid == sub.vtxo_txid && e.vout == sub.vtxo_vout));
                st.vtxos.push(crate::cosigner::state::VtxoEntry {
                    txid: sub.vtxo_txid.clone(),
                    vout: sub.vtxo_vout,
                    amount: sub.amount_sats,
                    exit_delay: sub.exit_delay,
                    created_at: now_secs(),
                    expires_at: 0,
                });
                handlers::helpers::save_user_vtxos(
                    shared.persistence.as_ref(),
                    &user_id_hex,
                    &st.vtxos,
                );
                st.ark_tx_history.push(crate::cosigner::types::ArkTxEntry {
                    tx_type: "board".into(),
                    amount_sats: sub.amount_sats as i64,
                    txid: sub.vtxo_txid,
                    timestamp: now_secs(),
                });
                handlers::helpers::save_user_ark_history(
                    shared.persistence.as_ref(),
                    &user_id_hex,
                    &st.ark_tx_history,
                );
            }
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            let _ = reply.send(Ok(SettleResponse {
                status: settle_response::Status::Settled as i32,
                messages_to_sign: vec![],
                script_path_spend: false,
                commitment_txid: sub.commitment_txid,
                error_message: String::new(),
            }));
        }
        Err(m) => {
            reseat_actor(actor, actor_policy_installed);
            let _ = reply.send(Err(Status::internal(format!("BoardingSettle: {m}"))));
        }
    }
}

/// Guest-routed auto-settle: if a stored delegate's threshold has arrived, drive it in the
/// actor. Fire-and-forget (no reply). `ensure_actor` restores the delegate from
/// the snapshot if the actor was reseated; an alive actor already holds it.
#[allow(clippy::too_many_arguments)]
async fn route_tick_auto_settle(
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    let Some(threshold) = state.lock().guest_delegate_threshold else {
        return;
    };
    if now_secs() < threshold {
        return;
    }
    tracing::info!("auto-settle (actor): threshold reached, driving stored delegate");
    if let Err(e) = ensure_actor(state, shared, registry, actor, actor_policy_installed).await {
        tracing::warn!("auto-settle (actor): ensure actor failed: {e}");
        return;
    }
    let group_key = state.lock().cosigner_id.clone();
    match actor.as_mut().unwrap().settle_delegate().await {
        Ok(settled) => {
            let commitment_txid = settled.commitment_txid;
            let vtxo_outpoint = settled.vtxo_outpoint;
            let exit_delay = settled.exit_delay;
            {
                let mut st = state.lock();
                st.guest_delegate_threshold = None;
                // A cold-spawned actor skips the vtxo-stream, so update the host projection
                // directly from the settle result. exit_delay comes from the settle (the
                // unilateral_exit_delay the output was built with) — guessing it from the inputs
                // (a boarding input carries boarding_exit_delay) re-derives a wrong scriptPubKey
                // and the VTXO becomes unspendable (INVALID_PSBT_INPUT).
                if let Some((txid, vout)) = vtxo_outpoint {
                    let amount: u64 = st.vtxos.iter().map(|e| e.amount).sum();
                    let expires_at = st.vtxos.iter().map(|e| e.expires_at).max().unwrap_or(0);
                    st.vtxos.clear();
                    st.vtxos.push(crate::cosigner::state::VtxoEntry {
                        txid,
                        vout,
                        amount,
                        exit_delay,
                        created_at: now_secs(),
                        expires_at,
                    });
                    handlers::helpers::save_user_vtxos(
                        shared.persistence.as_ref(),
                        &group_key,
                        &st.vtxos,
                    );
                }
            }
            handlers::helpers::delete_guest_delegate_threshold(
                shared.persistence.as_ref(),
                &group_key,
            );
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            tracing::info!("auto-settle (actor): commitment_txid={commitment_txid}");
        }
        Err(msg) => {
            tracing::warn!("auto-settle (actor): {msg}");
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Send a "vtxo_received" VISIBLE notification to every registered device for
/// this user. The wallet share is passkey-gated, so the device can't silently
/// sign a fresh delegate from a background push — the notification asks the
/// user to open the app, where the Ark tab offers a delegate button (one
/// passkey gesture). Best-effort: failures are logged and ignored — the
/// stream handler has already persisted state, the open-app fallback closes
/// any gap.
pub(crate) async fn push_vtxo_received(
    shared: &SharedServices,
    user_id_hex: &str,
    tokens: &[DeviceToken],
) {
    let Some(fcm) = shared.fcm.as_ref() else {
        return;
    };
    if tokens.is_empty() {
        return;
    }
    let mut data = std::collections::HashMap::new();
    data.insert("type".to_string(), "vtxo_received".to_string());
    data.insert("user_id".to_string(), user_id_hex.to_string());
    for token in tokens {
        if let Err(e) = fcm
            .send_notification(
                &token.fcm_token,
                "Funds received",
                "Tap to activate auto-settle protection",
                &data,
            )
            .await
        {
            tracing::warn!("[{user_id_hex}] FCM push to {} failed: {e}", token.platform);
        }
    }
}

/// One pass of the boarding watcher: for every user with a recorded boarding
/// address, read its on-chain UTXOs from esplora and push a "tap to board"
/// notification for any newly-seen CONFIRMED deposit. The cosigner only OBSERVES
/// — the wallet still scans + signs the settle. Best-effort; dedup persists.
pub async fn boarding_watch_sweep(
    esplora: &crate::esplora::EsploraClient,
    persistence: &std::sync::Arc<dyn crate::kv_store::KvStore>,
    fcm: &std::sync::Arc<crate::fcm_client::FcmClient>,
) {
    let watches = match persistence.get_all("boarding_watches") {
        Ok(w) => w,
        Err(e) => {
            tracing::warn!("boarding watch: get_all boarding_watches failed: {e}");
            return;
        }
    };
    for (user_id_hex, boarding_addr) in watches {
        let utxos = match esplora.list_utxos(&boarding_addr).await {
            Ok(u) => u,
            Err(e) => {
                tracing::debug!("boarding watch [{user_id_hex}]: esplora: {e}");
                continue;
            }
        };
        // Self-cleaning seen-set: keep only outpoints still present on-chain
        // (settled ones drop out), then notify for new confirmed deposits.
        let present: std::collections::HashSet<String> = utxos
            .iter()
            .map(|u| format!("{}:{}", u.txid, u.vout))
            .collect();
        let mut seen =
            handlers::helpers::load_user_boarding_seen(persistence.as_ref(), &user_id_hex);
        seen.retain(|k| present.contains(k));

        let mut tokens: Option<Vec<DeviceToken>> = None;
        let mut changed = false;
        for u in utxos.iter().filter(|u| u.confirmed) {
            let key = format!("{}:{}", u.txid, u.vout);
            if seen.contains(&key) {
                continue;
            }
            let toks = tokens.get_or_insert_with(|| {
                handlers::helpers::load_user_device_tokens(persistence.as_ref(), &user_id_hex)
            });
            push_boarding_deposit(fcm, &user_id_hex, toks, u).await;
            seen.push(key);
            changed = true;
        }
        if changed || seen.len() != present.len() {
            handlers::helpers::save_user_boarding_seen(persistence.as_ref(), &user_id_hex, &seen);
        }
    }
}

/// Notify the payer that an allowlisted contact has asked them to pay. Best-effort — the intent is
/// already sealed, and the app also polls on resume.
pub async fn push_payment_request(
    fcm: &std::sync::Arc<crate::fcm_client::FcmClient>,
    payer_vk_hex: &str,
    tokens: &[DeviceToken],
    intent_id: &str,
    amount_sats: u64,
) {
    if tokens.is_empty() {
        return;
    }
    let mut data = std::collections::HashMap::new();
    data.insert("type".to_string(), "payment_request".to_string());
    data.insert("user_id".to_string(), payer_vk_hex.to_string());
    data.insert("id".to_string(), intent_id.to_string());
    data.insert("amount_sats".to_string(), amount_sats.to_string());
    let body = format!("{amount_sats} sats — tap to review");
    for token in tokens {
        if let Err(e) = fcm
            .send_notification(&token.fcm_token, "Payment requested", &body, &data)
            .await
        {
            tracing::warn!(
                "[{payer_vk_hex}] payment-request push to {} failed: {e}",
                token.platform
            );
        }
    }
}


/// User-visible "tap to board" notification for a detected boarding deposit.
async fn push_boarding_deposit(
    fcm: &std::sync::Arc<crate::fcm_client::FcmClient>,
    user_id_hex: &str,
    tokens: &[DeviceToken],
    utxo: &crate::esplora::EsploraUtxo,
) {
    if tokens.is_empty() {
        return;
    }
    let mut data = std::collections::HashMap::new();
    data.insert("type".to_string(), "boarding_deposit".to_string());
    data.insert("user_id".to_string(), user_id_hex.to_string());
    data.insert("txid".to_string(), utxo.txid.clone());
    data.insert("vout".to_string(), utxo.vout.to_string());
    data.insert("amount_sats".to_string(), utxo.value.to_string());
    for token in tokens {
        if let Err(e) = fcm
            .send_notification(
                &token.fcm_token,
                "Deposit received",
                "Tap to add to your balance",
                &data,
            )
            .await
        {
            tracing::warn!(
                "[{user_id_hex}] boarding push to {} failed: {e}",
                token.platform
            );
        }
    }
}
