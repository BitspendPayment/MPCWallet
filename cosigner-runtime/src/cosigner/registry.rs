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

use super::command::CosignerCommand;
use super::actor::CosignerActor;
use super::handle::{CosignerHandle, OwnedHandle};
use super::handlers;
use super::state::{CosignerState, DeviceToken};
use crate::wallet_proto::{
    send_vtxo_response, settle_delegate_response, settle_response, sign_step1_response,
    SendVtxoRequest, SendVtxoResponse, SettleDelegateRequest, SettleDelegateResponse, SettleRequest,
    SettleResponse, SignStep1Request, SignStep1Response, SignStep2Request, SignStep2Response,
};
use crate::cosigner::wire::{
    ApplyDelegateSigsWire, ArkTxEntryWire, ContractPairingWire, GenerateDelegateWire, GuestCommand,
    GuestResponse, SendVtxoStep2Wire, SignStep1Wire, SignStep2Wire,
};

/// Convert the host `ContractPairing` projection to the wire form carried into the actor's
/// `InstallPolicy` (Plan A 1C — the actor does the cooperative-leaf conditioning).
fn pairing_to_wire(p: &crate::cosigner::state::ContractPairing) -> ContractPairingWire {
    ContractPairingWire {
        evtxo_spk_hex: p.evtxo_spk_hex.clone(),
        contract_id: p.contract_id.to_vec(),
        server_pk: p.server_pk.to_vec(),
        owner_pk: p.owner_pk.to_vec(),
        exit_delay: p.exit_delay,
    }
}

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
    /// ceremony + per-user state) — the cosigner runs in-process; only the contract is WASM.
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
        // for a contract). `CosignerState.cosigner_id` is then this canonical id.
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
        // Slow path: spawn the actor task. `CosignerState` is wrapped in `Arc<Mutex<>>` so the
        // actor's panic-recovery path keeps user state (policy, vtxos, delegate, history,
        // device_tokens) intact across a caught panic. All signing keys live in the actor.
        let (tx, rx) = mpsc::channel::<CosignerCommand>(MAILBOX_CAPACITY);

        // Rehydrate persistable state from sled. `vtxos` is also reconciled
        // by the vtxo_stream subscription as events arrive, but loading the
        // last-saved set keeps the actor coherent for any RPC that fires
        // before the first stream event. `ark_tx_history` and
        // `device_tokens` have no other reconstruction path — without these
        // loads they would be empty until new events accrued (history) or
        // the client re-registered (push tokens).
        let persistence = self.shared.persistence.as_ref();
        let mut fresh_state = CosignerState::new(group_key.to_string());
        fresh_state.vtxos = super::handlers::helpers::load_user_vtxos(persistence, group_key);
        fresh_state.ark_tx_history =
            super::handlers::helpers::load_user_ark_history(persistence, group_key);
        fresh_state.device_tokens =
            super::handlers::helpers::load_user_device_tokens(persistence, group_key);

        // Plan A Phase 2: restore the actor-delegate auto-settle threshold from its SECRET-FREE
        // marker, so a stored delegate survives a runtime restart. The delegate itself lives in the
        // actor's sealed snapshot (restored on first actor spawn) — the host keeps no key. (This
        // replaces the legacy host-delegate rehydration that read `dkg-secret` from the SecretStore.)
        let delegate_loaded = match super::handlers::helpers::load_guest_delegate_threshold(
            persistence,
            group_key,
        ) {
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
        let state = Arc::new(Mutex::new(fresh_state));

        let last_active = Arc::new(AtomicI64::new(now_secs()));
        let shared = self.shared.clone();
        let registry = self.clone();
        let last_active_for_task = last_active.clone();
        let join = tokio::spawn(run_cosigner(
            state,
            rx,
            shared,
            registry,
            last_active_for_task,
        ));
        let handle = CosignerHandle::new(tx);
        let owned = OwnedHandle {
            handle: handle.clone(),
            join,
            last_active,
        };
        // Insert; if a concurrent caller beat us to it, drop ours and use theirs.
        match self.actors.entry(group_key.to_string()) {
            dashmap::mapref::entry::Entry::Occupied(e) => {
                // Race: another caller spawned. Cancel our spawn and use theirs.
                drop(handle);
                owned.join.abort();
                Ok(e.get().handle.clone())
            }
            dashmap::mapref::entry::Entry::Vacant(e) => {
                tracing::info!("Spawned actor for user {group_key}");
                e.insert(owned);
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
async fn run_blocking<F, T>(state: Arc<Mutex<CosignerState>>, f: F) -> Result<T, Status>
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

/// Standard dispatch: handler returns `Result<Resp, Status>`; macro fires the
/// reply oneshot. Captures the current span and re-enters it inside
/// `spawn_blocking` so the handler's instrumented span stays in the trace tree.
macro_rules! dispatch {
    ($state:ident, $shared:ident, $req:ident, $reply:ident, $handler:path) => {{
        let s = $shared.clone();
        let span = tracing::Span::current();
        let res = run_blocking($state.clone(), move |state| {
            let _enter = span.enter();
            $handler(state, &s, $req)
        })
        .await;
        let _ = $reply.send(res);
    }};
}

/// Like `dispatch!` but also passes a registry handle. Only used by the two
/// ark address handlers that need to update `script_idx` for VTXO routing.
macro_rules! dispatch_with_registry {
    ($state:ident, $shared:ident, $registry:ident, $req:ident, $reply:ident, $handler:path) => {{
        let s = $shared.clone();
        let r = $registry.clone();
        let span = tracing::Span::current();
        let res = run_blocking($state.clone(), move |state| {
            let _enter = span.enter();
            $handler(state, &s, &r, $req)
        })
        .await;
        let _ = $reply.send(res);
    }};
}

pub async fn run_cosigner(
    state: Arc<Mutex<CosignerState>>,
    mut rx: mpsc::Receiver<CosignerCommand>,
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
    last_active: Arc<AtomicI64>,
) {
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

        // Intercept signing: every spend (script-path, key-path tweak, contract) routes
        // through the native-async actor where the keys live. Runs outside the
        // catch_unwind below because the actor path surfaces errors as replies.
        let cmd = match cmd {
            CosignerCommand::ContractRefresh {
                receiver_id_hex,
                receiver_partial_point,
                wallet_id_hex,
                a_at_cosigner,
                min_signers,
                reply,
            } => {
                route_contract_refresh(
                    receiver_id_hex,
                    receiver_partial_point,
                    wallet_id_hex,
                    a_at_cosigner,
                    min_signers,
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
                route_sign_step2(
                    req,
                    reply,
                    &mut actor,
                    &mut actor_policy_installed,
                )
                .await;
                continue;
            }
            // SendVtxo: the session + signing live in the actor (keys never leave it); the
            // host only translates its VTXO projection in/out. Falls back to the legacy
            // host handler when the ASP URL isn't configured for the actor.
            CosignerCommand::SendVtxo { req, reply } if shared.asp_url.is_some() => {
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
            CosignerCommand::SettleDelegate { req, reply } if shared.asp_url.is_some() => {
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
            CosignerCommand::Settle { req, reply } if shared.asp_url.is_some() => {
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
            CosignerCommand::TickAutoSettle
                if shared.asp_url.is_some() && state.lock().guest_delegate_threshold.is_some() =>
            {
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
            // contract-create). After this the keys live in the actor's sealed snapshot.
            CosignerCommand::SeedPolicy {
                key_package_json,
                public_key_package_json,
                user_signing_identifier_hex,
                server_dkg_secret_hex,
                contract_pairing,
                reply,
            } => {
                route_seed_policy(
                    key_package_json,
                    public_key_package_json,
                    user_signing_identifier_hex,
                    server_dkg_secret_hex,
                    contract_pairing,
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
            CosignerCommand::AddContract {
                spk_hex,
                contract_policy_json,
                reply,
            } => {
                route_add_contract(
                    spk_hex,
                    contract_policy_json,
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
        let _ =
            ensure_actor(&state, &shared, &registry, &mut actor, &mut actor_policy_installed).await;

        // Gap 2: wrap each command dispatch in `catch_unwind`. After Gap 1's
        // fix, handler panics already reach us as `Err(Status::internal(...))`
        // via `run_blocking`. This outer catch is belt-and-suspenders against
        // any panic that escapes the macros / async glue (rare, but cheap to
        // guard). On catch:
        //   1. Rebuild the WASM instance — its session handles may be wedged.
        //   2. Drain `pending_*` rendezvous replies so multi-party callers
        //      don't hang on a reply that will never come.
        //   3. Keep the recv loop running for the next command.
        //
        // `AssertUnwindSafe` is sound here: `parking_lot::Mutex` doesn't poison on panic, and
        // `CosignerState` holds only plain data (no wasm Store), so a caught panic leaves it
        // consistent and the recv loop simply continues with the next command.
        let dispatch_outcome = AssertUnwindSafe(dispatch_one(
            cmd,
            state.clone(),
            shared.clone(),
            registry.clone(),
        ))
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
async fn persist_actor_snapshot(
    actor: &mut CosignerActor,
    shared: &SharedServices,
    group_key: &str,
) {
    match actor.command(GuestCommand::Snapshot).await {
        Ok(GuestResponse::Snapshot { blob }) => {
            if let Err(e) =
                shared
                    .persistence
                    .put(SEALED_STATE_TREE, group_key, &hex::encode(blob))
            {
                tracing::warn!("persist sealed_state/{group_key} failed: {e}");
            }
        }
        Ok(other) => tracing::warn!("snapshot: unexpected response {other:?}"),
        Err(e) => tracing::warn!("snapshot command failed: {e}"),
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
    match actor.command(GuestCommand::RestoreSnapshot { blob }).await {
        Ok(GuestResponse::Restored) => {
            tracing::info!("restored actor snapshot for {group_key}");
            true
        }
        Ok(other) => {
            tracing::warn!("restore: unexpected response {other:?}");
            false
        }
        Err(e) => {
            tracing::warn!("restore command failed: {e}");
            false
        }
    }
}

/// Route `ContractRefresh` (Plan A): ensure the wallet actor's actor is up + its policy
/// restored/installed, then refresh `V` onto the pairing INSIDE the actor. The host never reads
/// `V`; it only relays the public PKP + the (transient, never-persisted) pairing key package.
#[allow(clippy::too_many_arguments)]
async fn route_contract_refresh(
    receiver_id_hex: String,
    receiver_partial_point: Vec<u8>,
    wallet_id_hex: String,
    a_at_cosigner: Vec<u8>,
    min_signers: u32,
    reply: oneshot::Sender<Result<crate::cosigner::command::ContractRefreshOutput, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    if let Err(e) =
        ensure_actor(state, shared, registry, actor, actor_policy_installed).await
    {
        let _ = reply.send(Err(e));
        return;
    }
    let result = actor
        .as_mut()
        .unwrap()
        .command(GuestCommand::ContractRefresh {
            receiver_id_hex,
            receiver_partial_point,
            wallet_id_hex,
            a_at_cosigner,
            min_signers,
        })
        .await;
    match result {
        Ok(GuestResponse::ContractRefreshed {
            pairing_public_key_package_json,
            receiver_half,
            my_key_package_json,
        }) => {
            let _ = reply.send(Ok(crate::cosigner::command::ContractRefreshOutput {
                pairing_public_key_package_json,
                receiver_half,
                my_key_package_json,
            }));
        }
        Ok(GuestResponse::Error(msg)) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_actor(actor, actor_policy_installed);
        }
        Ok(other) => {
            let _ = reply.send(Err(Status::internal(format!("contract_refresh: {other:?}"))));
            reseat_actor(actor, actor_policy_installed);
        }
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("contract_refresh: {e}"))));
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Route `SignStep1`: non-contract spends (raw script-path AND key-path-tweaked) go to the
/// native-async actor where the keys live — every spend type (script-path, key-path tweak,
/// contract). The contract gate is enforced inside the actor's sign step2.
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
            shared.secret_store.as_ref(),
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

    // Plan A 1C: the service-co-sign conditioning (rebuild + bind the eVTXO cooperative-leaf
    // sighash; verify the arkd two-leg) now lives INSIDE the actor (`conditioning::*`), which holds
    // `contract_pairing` in its sealed policy. The host just forwards the spend (`full_transaction`
    // + `ark_tx`); the actor is authoritative about what it signs.

    // Lazily create the native cosigner core, then install the policy once.
    if actor.is_none() {
        *actor = Some(CosignerActor::new(shared.clone()));
        *actor_policy_installed = false;
    }
    if !*actor_policy_installed {
        let gk = group_key.clone();
        // Restore-FIRST: a sealed snapshot carries the keys AND durable state (VTXOs/history/
        // delegate/contract-pairing), so when it restores we skip `InstallPolicy` entirely — no
        // plaintext key is read on this path.
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
            let result = actor
                .as_mut()
                .unwrap()
                .command(GuestCommand::InstallPolicy {
                    group_key,
                    key_package_json,
                    public_key_package_json,
                    user_signing_identifier_hex: user_identifier_hex,
                    server_dkg_secret_hex,
                    contract_pairing: None,
                    contracts_json: String::new(),
                })
                .await;
            match result {
                Ok(GuestResponse::PolicyInstalled) => *actor_policy_installed = true,
                Ok(other) => {
                    let _ = reply.send(Err(Status::internal(format!("InstallPolicy: {other:?}"))));
                    reseat_actor(actor, actor_policy_installed);
                    return;
                }
                Err(e) => {
                    let _ = reply.send(Err(Status::internal(format!("InstallPolicy: {e}"))));
                    reseat_actor(actor, actor_policy_installed);
                    return;
                }
            }
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &gk).await;
        } else {
            // No sealed snapshot and no host policy material — the actor was never seeded. Per
            // Plan A 1B/1C restore is the only path to the keys; there is no plaintext fallback.
            reseat_actor(actor, actor_policy_installed);
            let _ = reply.send(Err(Status::failed_precondition(
                "actor has no sealed snapshot and no policy material (not seeded)",
            )));
            return;
        }
    }

    let wire = SignStep1Wire {
        user_id: req.user_id,
        hiding_commitment: req.hiding_commitment,
        binding_commitment: req.binding_commitment,
        message_to_sign: req.message_to_sign,
        signature: req.signature,
        full_transaction: req.full_transaction,
        timestamp_ms: req.timestamp_ms,
        script_path_spend: req.script_path_spend,
        ark_tx: req.ark_tx,
    };
    let result = actor
        .as_mut()
        .unwrap()
        .command(GuestCommand::FrostSignStep1(wire))
        .await;
    match result {
        Ok(GuestResponse::SignStep1 {
            commitments,
            message_to_sign,
        }) => {
            let mut response = SignStep1Response::default();
            for c in commitments {
                response.commitments.insert(
                    c.identifier_hex,
                    sign_step1_response::Commitment {
                        hiding: c.hiding,
                        binding: c.binding,
                    },
                );
            }
            response.message_to_sign = message_to_sign;
            let _ = reply.send(Ok(response));
        }
        Ok(GuestResponse::Error(msg)) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_actor(actor, actor_policy_installed);
        }
        Ok(other) => {
            let _ = reply.send(Err(Status::internal(format!("sign_step1: {other:?}"))));
            reseat_actor(actor, actor_policy_installed);
        }
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("actor sign_step1: {e}"))));
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

    let wire = SignStep2Wire {
        user_id: req.user_id,
        signature_share: req.signature_share,
        signature: req.signature,
        timestamp_ms: req.timestamp_ms,
    };
    let result = actor
        .as_mut()
        .unwrap()
        .command(GuestCommand::FrostSignStep2(wire))
        .await;
    match result {
        Ok(GuestResponse::SignStep2 { r_point, z_scalar }) => {
            let _ = reply.send(Ok(SignStep2Response { r_point, z_scalar }));
        }
        Ok(GuestResponse::Error(msg)) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_actor(actor, actor_policy_installed);
        }
        Ok(other) => {
            let _ = reply.send(Err(Status::internal(format!("sign_step2: {other:?}"))));
            reseat_actor(actor, actor_policy_installed);
        }
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("actor sign_step2: {e}"))));
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Seed freshly-computed policy material (from onboarding / contract-create) into the
/// per-actor actor and seal it into the actor's snapshot. After this the keys live in the
/// actor's sealed blob, so later cold spawns restore them without a host-side plaintext key.
#[allow(clippy::too_many_arguments)]
#[allow(clippy::too_many_arguments)]
async fn route_seed_policy(
    key_package_json: String,
    public_key_package_json: String,
    user_signing_identifier_hex: Option<String>,
    server_dkg_secret_hex: Option<String>,
    contract_pairing: Option<crate::cosigner::state::ContractPairing>,
    reply: oneshot::Sender<Result<(), Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    actor: &mut Option<CosignerActor>,
    actor_policy_installed: &mut bool,
) {
    let group_key = state.lock().cosigner_id.clone();
    // SeedPolicy is only ever called for a FRESH actor (onboarding wallet, or a new pairing actor),
    // so there are no prior contracts. The secret key + `contract_pairing` install into the actor +
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
            contracts: Default::default(),
            contract_pairing,
        });
    }
    if let Err(e) =
        ensure_actor(state, shared, registry, actor, actor_policy_installed).await
    {
        let _ = reply.send(Err(e));
        return;
    }
    persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
    let _ = reply.send(Ok(()));
}

/// Add a gate `ContractPolicy` to the WALLET actor's sealed `contracts` projection + re-seal
/// (Plan A: the actor is the single source — no host `policies` tree). Updates the host
/// `policy_state.contracts` (so `detect_contract_spend` sees it) and pushes the full map to the
/// actor via `SetContracts`, then snapshots.
#[allow(clippy::too_many_arguments)]
async fn route_add_contract(
    spk_hex: String,
    contract_policy_json: String,
    reply: oneshot::Sender<Result<(), Status>>,
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
    let contract_policy: crate::cosigner::state::ContractPolicy = match serde_json::from_str(&contract_policy_json)
    {
        Ok(p) => p,
        Err(e) => {
            let _ = reply.send(Err(Status::invalid_argument(format!("bad contract policy: {e}"))));
            return;
        }
    };
    let contracts_json = {
        let mut st = state.lock();
        match st.policy_state.as_mut() {
            Some(ps) => {
                ps.contracts.insert(spk_hex, contract_policy);
                serde_json::to_string(&ps.contracts).unwrap_or_default()
            }
            None => {
                let _ = reply.send(Err(Status::not_found("no policy state")));
                return;
            }
        }
    };
    match actor
        .as_mut()
        .unwrap()
        .command(GuestCommand::SetContracts { contracts_json })
        .await
    {
        Ok(GuestResponse::PolicyInstalled) => {}
        Ok(other) => {
            let _ = reply.send(Err(Status::internal(format!("SetContracts: {other:?}"))));
            return;
        }
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("SetContracts: {e}"))));
            return;
        }
    }
    persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
    let _ = reply.send(Ok(()));
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
        *actor = Some(CosignerActor::new(shared.clone()));
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
                        p.contract_pairing.clone(),
                        serde_json::to_string(&p.contracts).unwrap_or_default(),
                    )
                })
            };
            let Some((gk, kpj, pkpj, usih, secret, pairing, contracts_json)) = material else {
                return Err(Status::not_found(format!("no policy for {group_key}")));
            };
            let result = actor
                .as_mut()
                .unwrap()
                .command(GuestCommand::InstallPolicy {
                    group_key: gk,
                    key_package_json: kpj,
                    public_key_package_json: pkpj,
                    user_signing_identifier_hex: usih,
                    server_dkg_secret_hex: secret,
                    contract_pairing: pairing.as_ref().map(pairing_to_wire),
                    contracts_json,
                })
                .await;
            match result {
                Ok(GuestResponse::PolicyInstalled) => *actor_policy_installed = true,
                Ok(other) => {
                    reseat_actor(actor, actor_policy_installed);
                    return Err(Status::internal(format!("InstallPolicy: {other:?}")));
                }
                Err(e) => {
                    reseat_actor(actor, actor_policy_installed);
                    return Err(Status::internal(format!("InstallPolicy: {e}")));
                }
            }
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
        }
    }
    Ok(())
}

/// Populate the host `policy_state` projection from the native actor (Plan A: the actor's seal is
/// the single source of truth — there is no `policies` sled tree). The host keeps no secret key
/// (`key_package_json` blank, `server_dkg_secret_hex` None); `contract_pairing` stays in the actor.
async fn load_policy_state_from_actor(
    state: &Arc<Mutex<CosignerState>>,
    actor: &mut CosignerActor,
) -> Result<(), Status> {
    match actor.command(GuestCommand::GetPublicPolicy).await {
        Ok(GuestResponse::PublicPolicy {
            group_key,
            public_key_package_json,
            user_signing_identifier_hex,
            contract_pairing: _,
            contracts_json,
        }) => {
            let contracts = if contracts_json.is_empty() {
                Default::default()
            } else {
                serde_json::from_str(&contracts_json)
                    .map_err(|e| Status::internal(format!("bad contracts json: {e}")))?
            };
            let mut st = state.lock();
            st.policy_state = Some(crate::cosigner::state::PolicyState {
                cosigner_id: group_key,
                user_signing_identifier_hex,
                server_dkg_secret_hex: None,
                normal_policy: crate::cosigner::state::NormalPolicy {
                    id: "normal".to_string(),
                    key_package_json: String::new(),
                    public_key_package_json,
                },
                contracts,
                contract_pairing: None,
            });
            Ok(())
        }
        Ok(other) => Err(Status::internal(format!("GetPublicPolicy: {other:?}"))),
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
    let Some(asp_url) = shared.asp_url.clone() else {
        let _ = reply.send(Err(Status::unavailable("ASP not configured (set ASP_URL)")));
        return;
    };
    if let Err(e) =
        ensure_actor(state, shared, registry, actor, actor_policy_installed).await
    {
        let _ = reply.send(Err(e));
        return;
    }

    if req.signed_messages.is_empty() {
        // Phase 1: push the VTXO set into the actor, then build → sighashes.
        let built = {
            let st = state.lock();
            handlers::ark_send::build_send_step1_wire(&st, asp_url, &req)
        };
        let (wire, vtxos) = match built {
            Ok(w) => w,
            Err(e) => {
                let _ = reply.send(Err(e));
                return;
            }
        };
        match actor
            .as_mut()
            .unwrap()
            .command(GuestCommand::SetVtxos { vtxos })
            .await
        {
            Ok(GuestResponse::VtxosSet) => {}
            Ok(other) => {
                let _ = reply.send(Err(Status::internal(format!("SetVtxos: {other:?}"))));
                reseat_actor(actor, actor_policy_installed);
                return;
            }
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("actor SetVtxos: {e}"))));
                reseat_actor(actor, actor_policy_installed);
                return;
            }
        }
        let result = actor
            .as_mut()
            .unwrap()
            .command(GuestCommand::SendVtxoStep1(wire))
            .await;
        match result {
            Ok(GuestResponse::SendVtxoSighashes { messages_to_sign }) => {
                let _ = reply.send(Ok(SendVtxoResponse {
                    status: send_vtxo_response::Status::SigningRequired as i32,
                    messages_to_sign,
                    script_path_spend: true,
                    ark_txid: String::new(),
                    error_message: String::new(),
                }));
            }
            Ok(GuestResponse::Error(msg)) => {
                let _ = reply.send(Err(Status::internal(msg)));
                reseat_actor(actor, actor_policy_installed);
            }
            Ok(other) => {
                let _ = reply.send(Err(Status::internal(format!("send_vtxo step1: {other:?}"))));
                reseat_actor(actor, actor_policy_installed);
            }
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("actor send_vtxo step1: {e}"))));
                reseat_actor(actor, actor_policy_installed);
            }
        }
    } else {
        // Phase 2: sign + submit in the actor, then apply to the host projection.
        let wire = SendVtxoStep2Wire {
            user_id: req.user_id.clone(),
            signature: req.signature.clone(),
            timestamp_ms: req.timestamp_ms,
            asp_url,
            signed_messages: req.signed_messages.clone(),
        };
        let result = actor
            .as_mut()
            .unwrap()
            .command(GuestCommand::SendVtxoStep2(wire))
            .await;
        match result {
            Ok(GuestResponse::SendVtxoSubmitted { ark_txid, change }) => {
                // Mirror the send into the actor's owned history (it owns the data for the
                // sealed snapshot); the host projection is still updated for live queries.
                let entry = ArkTxEntryWire {
                    tx_type: "send".to_string(),
                    amount_sats: -(req.amount as i64),
                    txid: ark_txid.clone(),
                    timestamp: now_secs(),
                };
                let resp = {
                    let mut st = state.lock();
                    handlers::ark_send::apply_send_result(&mut st, shared, &req, ark_txid, change)
                };
                let _ = actor
                    .as_mut()
                    .unwrap()
                    .command(GuestCommand::AppendHistory { entry })
                    .await;
                // Phase 4: the send mutated actor VTXOs + history — persist the snapshot.
                let group_key = state.lock().cosigner_id.clone();
                persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
                let _ = reply.send(Ok(resp));
            }
            Ok(GuestResponse::Error(msg)) => {
                let _ = reply.send(Err(Status::internal(msg)));
                reseat_actor(actor, actor_policy_installed);
            }
            Ok(other) => {
                let _ = reply.send(Err(Status::internal(format!("send_vtxo step2: {other:?}"))));
                reseat_actor(actor, actor_policy_installed);
            }
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("actor send_vtxo step2: {e}"))));
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
    let Some(asp_url) = shared.asp_url.clone() else {
        let _ = reply.send(Err(Status::unavailable("ASP not configured (set ASP_URL)")));
        return;
    };
    if let Err(e) =
        ensure_actor(state, shared, registry, actor, actor_policy_installed).await
    {
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
        match actor
            .as_mut()
            .unwrap()
            .command(GuestCommand::SetVtxos { vtxos })
            .await
        {
            Ok(GuestResponse::VtxosSet) => {}
            other => {
                let _ = reply.send(Err(Status::internal(format!("SetVtxos: {other:?}"))));
                reseat_actor(actor, actor_policy_installed);
                return;
            }
        }
        let wire = GenerateDelegateWire {
            user_id: req.user_id,
            signature: req.signature,
            timestamp_ms: req.timestamp_ms,
            asp_url,
            intent_valid_at,
        };
        match actor
            .as_mut()
            .unwrap()
            .command(GuestCommand::GenerateDelegate(wire))
            .await
        {
            Ok(GuestResponse::DelegateSighashes { messages_to_sign }) => {
                let _ = reply.send(Ok(SettleDelegateResponse {
                    status: settle_delegate_response::Status::SigningRequired as i32,
                    messages_to_sign,
                    script_path_spend: true,
                    commitment_txid: String::new(),
                    error_message: String::new(),
                }));
            }
            Ok(GuestResponse::Error(msg)) => {
                let _ = reply.send(Err(Status::internal(msg)));
                reseat_actor(actor, actor_policy_installed);
            }
            other => {
                let _ = reply.send(Err(Status::internal(format!("GenerateDelegate: {other:?}"))));
                reseat_actor(actor, actor_policy_installed);
            }
        }
        return;
    }

    // Phase 2: insert the client's signatures → ReadyToSettle.
    let apply = ApplyDelegateSigsWire {
        user_id: req.user_id,
        signature: req.signature,
        timestamp_ms: req.timestamp_ms,
        signed_messages: req.signed_messages,
    };
    match actor
        .as_mut()
        .unwrap()
        .command(GuestCommand::ApplyDelegateSigs(apply))
        .await
    {
        Ok(GuestResponse::DelegateReady) => {}
        Ok(GuestResponse::Error(msg)) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_actor(actor, actor_policy_installed);
            return;
        }
        other => {
            let _ = reply.send(Err(Status::internal(format!("ApplyDelegateSigs: {other:?}"))));
            reseat_actor(actor, actor_policy_installed);
            return;
        }
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
    match actor
        .as_mut()
        .unwrap()
        .command(GuestCommand::SettleDelegate { asp_url })
        .await
    {
        Ok(GuestResponse::SettleSubmitted { commitment_txid, .. }) => {
            persist_actor_snapshot(actor.as_mut().unwrap(), shared, &group_key).await;
            let _ = reply.send(Ok(SettleDelegateResponse {
                status: settle_delegate_response::Status::Settled as i32,
                messages_to_sign: vec![],
                script_path_spend: false,
                commitment_txid,
                error_message: String::new(),
            }));
        }
        Ok(GuestResponse::Error(msg)) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_actor(actor, actor_policy_installed);
        }
        other => {
            let _ = reply.send(Err(Status::internal(format!("SettleDelegate drive: {other:?}"))));
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
    let user_id_hex = handlers::parsers::user_id_hex(&req.user_id);
    {
        let mut st = state.lock();
        if let Err(e) = handlers::helpers::auth_check(
            &mut st,
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            crate::auth::message::OP_SETTLE,
        ) {
            let _ = reply.send(Err(e));
            return;
        }
    }
    let Some(asp_url) = shared.asp_url.clone() else {
        let _ = reply.send(Err(Status::unavailable("ASP not configured")));
        return;
    };
    if let Err(e) =
        ensure_actor(state, shared, registry, actor, actor_policy_installed).await
    {
        let _ = reply.send(Err(e));
        return;
    }
    let group_key = state.lock().cosigner_id.clone();

    let has_signatures = !req.signed_messages.is_empty();
    let progress = {
        let mut st = state.lock();
        let p = st.guest_boarding;
        if p.is_some() && !has_signatures {
            st.guest_boarding = None; // poll-without-sigs ⇒ abandon, restart at Phase 1
            None
        } else {
            p
        }
    };

    macro_rules! settle_err {
        ($e:expr) => {{
            state.lock().guest_boarding = None;
            let _ = reply.send(Err($e));
            reseat_actor(actor, actor_policy_installed);
            return;
        }};
    }

    match (progress.map(|(s, _, _)| s), has_signatures) {
        // ---- Phase 1: scan the boarding UTXO + BoardingSettleStep1 (actor builds the session) ----
        (None, false) => {
            let owner_pk_hex = {
                let mut st = state.lock();
                match handlers::helpers::get_user_xonly_pubkey(
                    &mut st,
                    shared.persistence.as_ref(),
                    shared.secret_store.as_ref(),
                    &user_id_hex,
                ) {
                    Ok(p) => p,
                    Err(e) => {
                        let _ = reply.send(Err(e));
                        return;
                    }
                }
            };
            let info = {
                let asp = match handlers::ark_send::require_asp(shared) {
                    Ok(a) => a,
                    Err(e) => {
                        let _ = reply.send(Err(e));
                        return;
                    }
                };
                let mut g = asp.lock().await;
                match g.info.clone() {
                    Some(i) => i,
                    None => match g.get_info().await {
                        Ok(i) => i,
                        Err(e) => {
                            let _ = reply.send(Err(Status::internal(format!("ASP get_info: {e}"))));
                            return;
                        }
                    },
                }
            };
            let network = match ark::client::parse_network(&info.network) {
                Ok(n) => n,
                Err(e) => {
                    let _ = reply.send(Err(Status::internal(e)));
                    return;
                }
            };
            let exit_delay = info.boarding_exit_delay as u32;
            let boarding_addr = match ark::client::boarding_address(
                &owner_pk_hex,
                &info.signer_pubkey,
                exit_delay,
                network,
            ) {
                Ok(a) => a,
                Err(e) => {
                    let _ = reply.send(Err(Status::internal(format!("boarding_address: {e}"))));
                    return;
                }
            };
            let addr: bitcoin::Address<bitcoin::address::NetworkUnchecked> =
                match boarding_addr.parse() {
                    Ok(a) => a,
                    Err(e) => {
                        let _ = reply.send(Err(Status::internal(format!("parse addr: {e}"))));
                        return;
                    }
                };
            let addr = match addr.require_network(network) {
                Ok(a) => a,
                Err(e) => {
                    let _ = reply.send(Err(Status::internal(format!("network mismatch: {e}"))));
                    return;
                }
            };
            let script_hex = hex::encode(addr.script_pubkey().as_bytes());
            let script_hash = match crate::bitcoin::tx_parser::derive_script_hash(&script_hex) {
                Ok(h) => h,
                Err(e) => {
                    let _ = reply.send(Err(Status::internal(format!("script_hash: {e}"))));
                    return;
                }
            };
            let utxos = {
                let guard = shared.bitcoin_history.lock().await;
                match guard.list_unspent_by_script_hash(&script_hash).await {
                    Ok(u) => u,
                    Err(e) => {
                        let _ = reply.send(Err(Status::internal(format!("list_unspent: {e}"))));
                        return;
                    }
                }
            };
            if utxos.is_empty() {
                let _ = reply.send(Err(Status::failed_precondition("no UTXOs at boarding address")));
                return;
            }
            let utxo = &utxos[0];
            let boarding_amount = utxo.amount_sats as u64;
            let messages_to_sign = match actor
                .as_mut()
                .unwrap()
                .command(GuestCommand::BoardingSettleStep1 {
                    owner_pk_hex,
                    signer_pubkey: info.signer_pubkey.clone(),
                    forfeit_pubkey: info.forfeit_pubkey.clone(),
                    boarding_address: boarding_addr,
                    boarding_txid: utxo.tx_hash.clone(),
                    boarding_vout: utxo.vout,
                    boarding_amount_sats: boarding_amount,
                    exit_delay,
                    network: info.network.clone(),
                })
                .await
            {
                Ok(GuestResponse::BoardingSettleSighashes { messages_to_sign }) => messages_to_sign,
                Ok(GuestResponse::Error(m)) => settle_err!(Status::internal(m)),
                other => settle_err!(Status::internal(format!("BoardingSettleStep1: {other:?}"))),
            };
            state.lock().guest_boarding = Some((1, boarding_amount, exit_delay));
            let _ = reply.send(Ok(SettleResponse {
                status: settle_response::Status::SigningRequired as i32,
                messages_to_sign,
                script_path_spend: true,
                commitment_txid: String::new(),
                error_message: String::new(),
            }));
        }

        // ---- Phase 2: intent FROST sigs → BoardingSettleStep2 → commitment sighashes ----
        (Some(1), true) => {
            let (amount, exit_delay) = progress.map(|(_, a, e)| (a, e)).unwrap();
            let messages_to_sign = match actor
                .as_mut()
                .unwrap()
                .command(GuestCommand::BoardingSettleStep2 {
                    asp_url: asp_url.clone(),
                    intent_signatures: req.signed_messages,
                })
                .await
            {
                Ok(GuestResponse::BoardingSettleSighashes { messages_to_sign }) => messages_to_sign,
                Ok(GuestResponse::Error(m)) => settle_err!(Status::internal(m)),
                other => settle_err!(Status::internal(format!("BoardingSettleStep2: {other:?}"))),
            };
            state.lock().guest_boarding = Some((2, amount, exit_delay));
            let _ = reply.send(Ok(SettleResponse {
                status: settle_response::Status::SigningRequired as i32,
                messages_to_sign,
                script_path_spend: true,
                commitment_txid: String::new(),
                error_message: String::new(),
            }));
        }

        // ---- Phase 3: commitment FROST sigs → BoardingSettleStep3 → the new VTXO ----
        (Some(2), true) => {
            let exit_delay = progress.map(|(_, _, e)| e).unwrap();
            let (commitment_txid, vtxo_txid, vtxo_vout, amount_sats) = match actor
                .as_mut()
                .unwrap()
                .command(GuestCommand::BoardingSettleStep3 {
                    asp_url,
                    commitment_signatures: req.signed_messages,
                })
                .await
            {
                Ok(GuestResponse::BoardingSettleSubmitted {
                    commitment_txid,
                    vtxo_txid,
                    vtxo_vout,
                    amount_sats,
                }) => (commitment_txid, vtxo_txid, vtxo_vout, amount_sats),
                Ok(GuestResponse::Error(m)) => settle_err!(Status::internal(m)),
                other => settle_err!(Status::internal(format!("BoardingSettleStep3: {other:?}"))),
            };
            {
                let mut st = state.lock();
                st.guest_boarding = None;
                st.vtxos.retain(|e| !(e.txid == vtxo_txid && e.vout == vtxo_vout));
                st.vtxos.push(crate::cosigner::state::VtxoEntry {
                    txid: vtxo_txid.clone(),
                    vout: vtxo_vout,
                    amount: amount_sats,
                    exit_delay,
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
                    amount_sats: amount_sats as i64,
                    txid: vtxo_txid,
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
                commitment_txid,
                error_message: String::new(),
            }));
        }

        (None, true) => {
            let _ = reply.send(Err(Status::failed_precondition("no active boarding settle")));
        }
        _ => {
            let _ = reply.send(Err(Status::internal("unexpected boarding settle state")));
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
    let Some(asp_url) = shared.asp_url.clone() else { return };
    if let Err(e) =
        ensure_actor(state, shared, registry, actor, actor_policy_installed).await
    {
        tracing::warn!("auto-settle (actor): ensure actor failed: {e}");
        return;
    }
    let group_key = state.lock().cosigner_id.clone();
    match actor
        .as_mut()
        .unwrap()
        .command(GuestCommand::SettleDelegate { asp_url })
        .await
    {
        Ok(GuestResponse::SettleSubmitted { commitment_txid, vtxo_outpoint }) => {
            {
                let mut st = state.lock();
                st.guest_delegate_threshold = None;
                // The delegate settle consolidated this actor's VTXOs into one refreshed VTXO. A
                // cold-spawned actor has NO cached ASP info, so the indexer VTXO-stream notification is
                // skipped — update the host projection directly from the settle result (balance is
                // preserved by the refresh; exit delay carries over from the consolidated inputs).
                if let Some((txid, vout)) = vtxo_outpoint {
                    let amount: u64 = st.vtxos.iter().map(|e| e.amount).sum();
                    let exit_delay = st.vtxos.first().map(|e| e.exit_delay).unwrap_or(0);
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
        Ok(GuestResponse::Error(msg)) => {
            tracing::warn!("auto-settle (actor): {msg}");
            reseat_actor(actor, actor_policy_installed);
        }
        other => {
            tracing::warn!("auto-settle (actor): unexpected {other:?}");
            reseat_actor(actor, actor_policy_installed);
        }
    }
}

/// Per-command dispatch helper. Extracted so the outer `catch_unwind` in
/// `run_cosigner` can wrap a single async unit cleanly. `Shutdown` is handled
/// directly in `run_cosigner` (it breaks the loop) and never reaches here.
async fn dispatch_one(
    cmd: CosignerCommand,
    state: Arc<Mutex<CosignerState>>,
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
) {
    match cmd {
        CosignerCommand::Shutdown => {
            // Already filtered out by run_cosigner; reaching this arm would be a
            // bug. Logging it makes it visible without panicking.
            tracing::error!(
                "dispatch_one received Shutdown; expected to be filtered by run_cosigner"
            );
        }
        // Handled in the actor-routed match (it `continue`s); never reaches the legacy path.
        CosignerCommand::ContractRefresh { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "ContractRefresh must be actor-routed, not dispatched to the legacy handler",
            )));
        }

        // -------- Signing --------
        // Both steps are intercepted in run_cosigner and routed to the actor (the only sign
        // path); reaching these arms would be a bug.
        CosignerCommand::SignStep1 { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "SignStep1 reached dispatch_one; should be routed to the actor",
            )));
        }
        CosignerCommand::SignStep2 { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "SignStep2 reached dispatch_one; should be routed to the actor",
            )));
        }
        // Intercepted in run_cosigner (spawns actor + installs + seals); reaching here is a bug.
        CosignerCommand::SeedPolicy { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "SeedPolicy reached dispatch_one; should be intercepted in run_cosigner",
            )));
        }
        CosignerCommand::AddContract { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "AddContract reached dispatch_one; should be intercepted in run_cosigner",
            )));
        }

        // -------- Transactions --------
        CosignerCommand::BroadcastTransaction { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::tx::broadcast_transaction
            );
        }
        CosignerCommand::FetchHistory { req, reply } => {
            dispatch!(state, shared, req, reply, handlers::tx::fetch_history);
        }
        CosignerCommand::FetchRecentTransactions { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::tx::fetch_recent_transactions
            );
        }

        // -------- Ark (lookups) --------
        CosignerCommand::GetArkInfo { req, reply } => {
            dispatch!(state, shared, req, reply, handlers::ark::get_ark_info);
        }
        CosignerCommand::GetArkAddress { req, reply } => {
            dispatch_with_registry!(
                state,
                shared,
                registry,
                req,
                reply,
                handlers::ark::get_ark_address
            );
        }
        CosignerCommand::GetBoardingAddress { req, reply } => {
            dispatch_with_registry!(
                state,
                shared,
                registry,
                req,
                reply,
                handlers::ark::get_boarding_address
            );
        }
        CosignerCommand::CheckBoardingBalance { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::ark::check_boarding_balance
            );
        }
        CosignerCommand::ListVtxos { req, reply } => {
            dispatch!(state, shared, req, reply, handlers::ark::list_vtxos);
        }
        CosignerCommand::ListArkTransactions { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::ark::list_ark_transactions
            );
        }
        // Plan A Phase 2: SendVtxo / RedeemVtxo / Settle / SettleDelegate are actor-routed (the keys
        // never leave the actor) and require the ASP URL. The legacy host paths that signed with a
        // plaintext dkg-secret are gone; without ASP_URL there is no fallback.
        CosignerCommand::SendVtxo { req: _, reply } => {
            let _ = reply.send(Err(Status::unavailable("send requires ASP_URL (actor-routed)")));
        }
        CosignerCommand::RedeemVtxo { req: _, reply } => {
            let _ = reply.send(Err(Status::unimplemented("RedeemVtxo not implemented")));
        }
        CosignerCommand::Settle { req: _, reply } => {
            let _ = reply.send(Err(Status::unavailable(
                "boarding settle requires ASP_URL (actor-routed)",
            )));
        }
        CosignerCommand::SettleDelegate { req: _, reply } => {
            let _ = reply.send(Err(Status::unavailable(
                "delegate settle requires ASP_URL (actor-routed)",
            )));
        }
        CosignerCommand::SubmitArkSend { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::ark_send::submit_ark_send
            );
        }
        // -------- Push registration --------
        CosignerCommand::RegisterDeviceToken { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::device_token::register_device_token
            );
        }

        // -------- Auto-settle tick --------
        CosignerCommand::TickAutoSettle => {
            let s = shared.clone();
            let span = tracing::info_span!("actor::tick_auto_settle");
            let res = run_blocking(state.clone(), move |state| {
                let _enter = span.enter();
                handlers::auto_settle::tick_auto_settle(state, &s)
            })
            .await;
            if let Err(e) = res {
                tracing::warn!("tick_auto_settle: {e}");
            }
        }

        // -------- Stream fan-in (no reply) --------
        CosignerCommand::VtxoStreamUpdate {
            user_id_hex,
            spent,
            spendable,
            info,
        } => {
            let s = shared.clone();
            let span = tracing::info_span!("actor::vtxo_stream_update", user_id = %user_id_hex);
            let user_id_for_push = user_id_hex.clone();
            let state_lock = state.clone();
            let blocking_outcome = tokio::task::spawn_blocking(move || {
                let _enter = span.enter();
                let mut state = state_lock.lock();
                let added = match handlers::vtxo_stream::apply_stream_update(
                    &mut state,
                    &s,
                    &user_id_hex,
                    spent,
                    spendable,
                    info,
                ) {
                    Ok(added) => added,
                    Err(e) => {
                        tracing::warn!("[{user_id_hex}] VTXO stream apply failed: {e}");
                        Vec::new()
                    }
                };
                let tokens = state.device_tokens.clone();
                (added, tokens)
            })
            .await;
            let (newly_added, device_tokens) = match blocking_outcome {
                Ok(x) => x,
                Err(join_err) if join_err.is_panic() => {
                    tracing::error!("[{user_id_for_push}] VtxoStreamUpdate panicked: {join_err:?}");
                    (Vec::new(), Vec::new())
                }
                Err(join_err) => {
                    tracing::error!(
                        "[{user_id_for_push}] VtxoStreamUpdate task error: {join_err:?}"
                    );
                    (Vec::new(), Vec::new())
                }
            };
            if !newly_added.is_empty() {
                push_vtxo_received(shared.as_ref(), &user_id_for_push, &device_tokens).await;
            }
        }
        CosignerCommand::IndexerUpdate {
            user_id_hex,
            new_vtxos,
            spent_vtxos,
            info,
        } => {
            let s = shared.clone();
            let span = tracing::info_span!("actor::indexer_update", user_id = %user_id_hex);
            let user_id_for_push = user_id_hex.clone();
            let state_lock = state.clone();
            let blocking_outcome = tokio::task::spawn_blocking(move || {
                let _enter = span.enter();
                let mut state = state_lock.lock();
                let added = match handlers::vtxo_stream::apply_stream_update(
                    &mut state,
                    &s,
                    &user_id_hex,
                    spent_vtxos,
                    new_vtxos,
                    info,
                ) {
                    Ok(added) => added,
                    Err(e) => {
                        tracing::warn!("[{user_id_hex}] Indexer apply failed: {e}");
                        Vec::new()
                    }
                };
                let tokens = state.device_tokens.clone();
                (added, tokens)
            })
            .await;
            let (newly_added, device_tokens) = match blocking_outcome {
                Ok(x) => x,
                Err(join_err) if join_err.is_panic() => {
                    tracing::error!("[{user_id_for_push}] IndexerUpdate panicked: {join_err:?}");
                    (Vec::new(), Vec::new())
                }
                Err(join_err) => {
                    tracing::error!("[{user_id_for_push}] IndexerUpdate task error: {join_err:?}");
                    (Vec::new(), Vec::new())
                }
            };
            if !newly_added.is_empty() {
                push_vtxo_received(shared.as_ref(), &user_id_for_push, &device_tokens).await;
            }
        }
    }
}

/// Send a "vtxo_received" data-only push to every registered device for this
/// user. Best-effort: failures are logged and ignored — the stream handler
/// has already persisted state, the open-app fallback closes any gap.
async fn push_vtxo_received(shared: &SharedServices, user_id_hex: &str, tokens: &[DeviceToken]) {
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
        if let Err(e) = fcm.send_data(&token.fcm_token, &data).await {
            tracing::warn!("[{user_id_hex}] FCM push to {} failed: {e}", token.platform);
        }
    }
}
