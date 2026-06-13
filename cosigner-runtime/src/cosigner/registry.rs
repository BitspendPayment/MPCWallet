//! Concurrent registry of per-user actors, plus the per-cosigner WASM instance
//! and the tokio actor loop that owns + drives it.
//!
//! `CosignerInstance` keeps all threshold-crypto state in WASM linear memory (only
//! persistent host state — policy, UTXOs — is mirrored on the host). The registry
//! is a `DashMap` of mpsc senders; lookup, dispatch, and stream fan-out are
//! lock-free across distinct users. Each user has exactly one actor: `run_cosigner`
//! is a tokio task that owns its `CosignerInstance` + `CosignerState` and processes
//! commands serially. Per-command WASM work runs inside `spawn_blocking`, so an idle
//! actor is just memory, not a thread. The instance + state live behind
//! `Arc<parking_lot::Mutex<>>` so the panic-recovery path in `run_cosigner` can
//! reseat a wedged WASM instance without losing user state (`parking_lot` doesn't
//! poison on panic, so the recovery reseat is clean).

use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use dashmap::DashMap;
use futures::FutureExt;
use parking_lot::Mutex;
use tokio::sync::{mpsc, oneshot};
use tonic::Status;
use wasmtime::component::{Component, Linker, ResourceAny};
use wasmtime::{Engine, Store};
use wasmtime_wasi::{ResourceTable, WasiCtx, WasiCtxBuilder, WasiView};

use crate::policy::{PolicyState, UtxoState};
use crate::shared::SharedServices;

use super::command::CosignerCommand;
use super::handle::{CosignerHandle, OwnedHandle};
use super::handlers;
use super::state::{CosignerState, DeviceToken};

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
    engine: Engine,
    component: Component,
    linker: Linker<CosignerWasiView>,
    shared: Arc<SharedServices>,
    /// Active actors keyed by user_id_hex.
    actors: DashMap<String, OwnedHandle>,
    /// Reverse index: vtxo_script_hex → user_id_hex. Used by the global VTXO
    /// stream to route notifications to the right actor without scanning
    /// per-user persistence on every event.
    script_idx: DashMap<String, String>,
}

impl CosignerRegistry {
    pub fn new(
        wasm_path: &str,
        shared: Arc<SharedServices>,
    ) -> Result<Arc<Self>, Box<dyn std::error::Error>> {
        let mut config = wasmtime::Config::new();
        config.wasm_component_model(true);
        let engine = Engine::new(&config)?;
        let component = Component::from_file(&engine, wasm_path)?;
        let mut linker = Linker::new(&engine);
        wasmtime_wasi::add_to_linker_sync(&mut linker)?;

        Ok(Arc::new(Self {
            engine,
            component,
            linker,
            shared,
            actors: DashMap::new(),
            script_idx: DashMap::new(),
        }))
    }

    pub fn shared(&self) -> &Arc<SharedServices> {
        &self.shared
    }

    /// Get the existing actor handle for `user_id`, or spawn a new one.
    /// Cheap fast path when the actor already exists (DashMap read).
    pub fn get_or_spawn(self: &Arc<Self>, user_id: &str) -> Result<CosignerHandle, Status> {
        // Actors are keyed by their GROUP KEY (cosigner_id). A request addressed by a
        // member's verifying share resolves to the group's actor via `policy_owner_idx`,
        // so every member of a group shares one actor (one for a normal wallet, many
        // for a contract). `CosignerState.cosigner_id` is then this canonical id.
        let canonical = self
            .shared
            .persistence
            .get("policy_owner_idx", user_id)
            .ok()
            .flatten()
            .unwrap_or_else(|| user_id.to_string());
        let user_id = canonical.as_str();
        if let Some(entry) = self.actors.get(user_id) {
            return Ok(entry.handle.clone());
        }
        // Slow path: instantiate WASM and spawn the actor task. State and
        // instance are wrapped in `Arc<Mutex<>>` so the actor's panic-recovery
        // path can rebuild the wedged WASM instance while keeping the
        // `CosignerState` (vtxos, delegate_session, history, device_tokens)
        // intact across a caught panic.
        let (tx, rx) = mpsc::channel::<CosignerCommand>(MAILBOX_CAPACITY);
        let user = self
            .new_user_instance()
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let user = Arc::new(Mutex::new(user));

        // Rehydrate persistable state from sled. `vtxos` is also reconciled
        // by the vtxo_stream subscription as events arrive, but loading the
        // last-saved set keeps the actor coherent for any RPC that fires
        // before the first stream event. `ark_tx_history` and
        // `device_tokens` have no other reconstruction path — without these
        // loads they would be empty until new events accrued (history) or
        // the client re-registered (push tokens).
        let persistence = self.shared.persistence.as_ref();
        let mut fresh_state = CosignerState::new(user_id.to_string());
        fresh_state.vtxos = super::handlers::helpers::load_user_vtxos(persistence, user_id);
        fresh_state.ark_tx_history =
            super::handlers::helpers::load_user_ark_history(persistence, user_id);
        fresh_state.device_tokens =
            super::handlers::helpers::load_user_device_tokens(persistence, user_id);

        // Rehydrate a persisted delegate intent if one is present. The
        // sled row doesn't carry the cosigner secret (issue #31) — we look
        // it up from `SecretStore` here and pass it into `from_persisted`.
        // On any failure (missing secret, parse error, pubkey mismatch),
        // delete the sled row so the next actor spawn doesn't keep
        // retrying — the client will re-delegate on its next refresh.
        let mut delegate_loaded = false;
        if let Some(persisted_record) =
            super::handlers::helpers::load_user_delegate(persistence, user_id)
        {
            match self
                .shared
                .secret_store
                .get_secret(&format!("dkg-secret.{user_id}"))
            {
                Ok(Some(dkg_secret_hex)) => {
                    match ark::client::batch::DelegateSettleSession::from_persisted(
                        &persisted_record.session,
                        &dkg_secret_hex,
                    ) {
                        Ok(session) => {
                            fresh_state.delegate_session =
                                Some(crate::cosigner::state::DelegateRecord {
                                    session,
                                    covered_outpoints: persisted_record
                                        .covered_outpoints
                                        .clone(),
                                    earliest_expires_at: persisted_record.earliest_expires_at,
                                    // Rehydrated records carry signed
                                    // sighashes already — the bypass must
                                    // not fire on unrelated SignStep1.
                                    awaiting_signatures: false,
                                });
                            delegate_loaded = true;
                        }
                        Err(e) => {
                            tracing::warn!(
                                "Rehydrate delegate for {user_id} failed: {e}; dropping sled row"
                            );
                            super::handlers::helpers::delete_user_delegate(persistence, user_id);
                        }
                    }
                }
                Ok(None) => {
                    tracing::warn!(
                        "Rehydrate delegate for {user_id}: SecretStore missing dkg-secret entry; dropping sled row"
                    );
                    super::handlers::helpers::delete_user_delegate(persistence, user_id);
                }
                Err(e) => {
                    tracing::warn!(
                        "Rehydrate delegate for {user_id}: SecretStore error {e}; leaving sled row in place"
                    );
                }
            }
        }

        if !fresh_state.vtxos.is_empty()
            || !fresh_state.ark_tx_history.is_empty()
            || !fresh_state.device_tokens.is_empty()
            || delegate_loaded
        {
            tracing::info!(
                "Rehydrated actor {user_id}: vtxos={}, history={}, device_tokens={}, delegate={}",
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
            user,
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
        match self.actors.entry(user_id.to_string()) {
            dashmap::mapref::entry::Entry::Occupied(e) => {
                // Race: another caller spawned. Cancel our spawn and use theirs.
                drop(handle);
                owned.join.abort();
                Ok(e.get().handle.clone())
            }
            dashmap::mapref::entry::Entry::Vacant(e) => {
                tracing::info!("Spawned actor for user {user_id}");
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

    /// Build a fresh `CosignerInstance` from the cached engine/component/linker.
    /// Public(crate) so the actor's panic-recovery path can rebuild a wedged
    /// WASM instance without losing the actor's `CosignerState`.
    pub(crate) fn new_user_instance(&self) -> Result<CosignerInstance, Box<dyn std::error::Error>> {
        let wasi_ctx = WasiCtxBuilder::new().inherit_stdio().build();
        let view = CosignerWasiView::new(ResourceTable::new(), wasi_ctx);
        let mut store = Store::new(&self.engine, view);
        let bindings = ThresholdWorld::instantiate(&mut store, &self.component, &self.linker)?;
        let iface = bindings.component_threshold_types();
        let session = iface.threshold_session().call_constructor(&mut store)?;
        Ok(CosignerInstance {
            store,
            bindings,
            session: Some(session),
            round1_secret: None,
            round2_secret: None,
            signing_nonce: None,
            signing_session: None,
            refresh_session: None,
            script_path_spend: false,
            policy_state: None,
            utxo_state: None,
        })
    }

    /// Send a command to the user's actor and await the typed reply.
    /// `make_cmd` receives the reply oneshot sender and returns the command to send.
    pub async fn dispatch<T, F>(self: &Arc<Self>, user_id: &str, make_cmd: F) -> Result<T, Status>
    where
        F: FnOnce(oneshot::Sender<Result<T, Status>>) -> CosignerCommand,
    {
        let handle = self.get_or_spawn(user_id)?;
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
// Per-cosigner WASM instance + the tokio actor that owns and drives it.
// (Merged from the former cosigner.rs — same actor model, one file.)
// ===========================================================================

wasmtime::component::bindgen!({
    path: "wit/world.wit",
    world: "threshold-world",
    async: false,
});

pub struct CosignerWasiView {
    table: ResourceTable,
    ctx: WasiCtx,
}

impl CosignerWasiView {
    pub fn new(table: ResourceTable, ctx: WasiCtx) -> Self {
        Self { table, ctx }
    }
}

impl WasiView for CosignerWasiView {
    fn table(&mut self) -> &mut ResourceTable {
        &mut self.table
    }
    fn ctx(&mut self) -> &mut WasiCtx {
        &mut self.ctx
    }
}

/// Per-cosigner WASM instance. All threshold-crypto state lives in WASM
/// linear memory as `ResourceAny` handles; only persistent host state
/// (policy, UTXOs) is mirrored on the host.
pub struct CosignerInstance {
    pub store: Store<CosignerWasiView>,
    pub bindings: ThresholdWorld,

    pub session: Option<ResourceAny>,
    /// Round1 secret handle, lives between refresh steps.
    pub round1_secret: Option<ResourceAny>,
    /// Round2 secret handle, lives between refresh steps.
    pub round2_secret: Option<ResourceAny>,
    /// Signing nonce handle, lives between sign step1 and step2.
    pub signing_nonce: Option<ResourceAny>,
    pub signing_session: Option<ResourceAny>,
    pub refresh_session: Option<ResourceAny>,

    /// True when the current signing session uses script-path (no tweak).
    pub script_path_spend: bool,

    pub policy_state: Option<PolicyState>,
    pub utxo_state: Option<UtxoState>,
}

/// Lock `user` and `state` inside `spawn_blocking`, run `f`, return the typed
/// result. `(user, state)` ownership stays with the actor task across this
/// call; the mutex guards only protect against panic-recovery reseating the
/// instance.
///
/// On a handler panic, `spawn_blocking` returns `Err(JoinError::is_panic)`.
/// We surface that as `Err(Status::internal("handler panicked"))` so the
/// caller's oneshot reply fires with an error instead of hanging. The actor
/// task itself stays alive — its outer `catch_unwind` in `run_cosigner` reseats
/// the wedged WASM instance and drains in-flight rendezvous replies.
async fn run_blocking<F, T>(
    user: Arc<Mutex<CosignerInstance>>,
    state: Arc<Mutex<CosignerState>>,
    f: F,
) -> Result<T, Status>
where
    F: FnOnce(&mut CosignerInstance, &mut CosignerState) -> Result<T, Status> + Send + 'static,
    T: Send + 'static,
{
    let outcome = tokio::task::spawn_blocking(move || {
        let mut user = user.lock();
        let mut state = state.lock();
        f(&mut user, &mut state)
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
    ($user:ident, $state:ident, $shared:ident, $req:ident, $reply:ident, $handler:path) => {{
        let s = $shared.clone();
        let span = tracing::Span::current();
        let res = run_blocking($user.clone(), $state.clone(), move |user, state| {
            let _enter = span.enter();
            $handler(user, state, &s, $req)
        })
        .await;
        let _ = $reply.send(res);
    }};
}

/// Like `dispatch!` but also passes a registry handle. Only used by the two
/// ark address handlers that need to update `script_idx` for VTXO routing.
macro_rules! dispatch_with_registry {
    ($user:ident, $state:ident, $shared:ident, $registry:ident, $req:ident, $reply:ident, $handler:path) => {{
        let s = $shared.clone();
        let r = $registry.clone();
        let span = tracing::Span::current();
        let res = run_blocking($user.clone(), $state.clone(), move |user, state| {
            let _enter = span.enter();
            $handler(user, state, &s, &r, $req)
        })
        .await;
        let _ = $reply.send(res);
    }};
}

pub async fn run_cosigner(
    user: Arc<Mutex<CosignerInstance>>,
    state: Arc<Mutex<CosignerState>>,
    mut rx: mpsc::Receiver<CosignerCommand>,
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
    last_active: Arc<AtomicI64>,
) {
    while let Some(cmd) = rx.recv().await {
        // Per issue #30 design choice: every recv() event counts as activity.
        // This includes TickAutoSettle / stream events, which means actors in
        // ASP-connected deployments effectively never idle out. Eviction is
        // dormant in normal operation by design.
        last_active.store(now_secs(), Ordering::Relaxed);

        if matches!(cmd, CosignerCommand::Shutdown) {
            break;
        }

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
        // `AssertUnwindSafe` is necessary because `CosignerInstance` (wasmtime
        // Store) isn't naturally UnwindSafe. The safety claim is sound: we
        // unconditionally rebuild the instance after a caught panic, so no
        // potentially-inconsistent wasm state survives the boundary.
        let dispatch_outcome = AssertUnwindSafe(dispatch_one(
            cmd,
            user.clone(),
            state.clone(),
            shared.clone(),
            registry.clone(),
        ))
        .catch_unwind()
        .await;

        if dispatch_outcome.is_err() {
            tracing::error!("actor caught unwind during dispatch; rebuilding WASM instance");
            match registry.new_user_instance() {
                Ok(fresh) => {
                    *user.lock() = fresh;
                }
                Err(e) => {
                    tracing::error!("failed to rebuild WASM instance: {e}; actor exiting");
                    break;
                }
            }
            state
                .lock()
                .drain_pending_replies_with_err("actor recovering from panic");
        }
    }
}

/// Per-command dispatch helper. Extracted so the outer `catch_unwind` in
/// `run_cosigner` can wrap a single async unit cleanly. `Shutdown` is handled
/// directly in `run_cosigner` (it breaks the loop) and never reaches here.
async fn dispatch_one(
    cmd: CosignerCommand,
    user: Arc<Mutex<CosignerInstance>>,
    state: Arc<Mutex<CosignerState>>,
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
) {
    match cmd {
        CosignerCommand::Shutdown => {
            // Already filtered out by run_cosigner; reaching this arm would be a
            // bug. Logging it makes it visible without panicking.
            tracing::error!("dispatch_one received Shutdown; expected to be filtered by run_cosigner");
        }

        // -------- Signing --------
        CosignerCommand::SignStep1 { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::sign::sign_step1);
        }
        CosignerCommand::SignStep2 { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::sign::sign_step2);
        }

        // -------- Transactions --------
        CosignerCommand::BroadcastTransaction { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::tx::broadcast_transaction
            );
        }
        CosignerCommand::FetchHistory { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::tx::fetch_history);
        }
        CosignerCommand::FetchRecentTransactions { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::tx::fetch_recent_transactions
            );
        }

        // -------- Ark (lookups) --------
        CosignerCommand::GetArkInfo { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::ark::get_ark_info);
        }
        CosignerCommand::GetArkAddress { req, reply } => {
            dispatch_with_registry!(
                user,
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
                user,
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
                user,
                state,
                shared,
                req,
                reply,
                handlers::ark::check_boarding_balance
            );
        }
        CosignerCommand::ListVtxos { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::ark::list_vtxos);
        }
        CosignerCommand::ListArkTransactions { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::ark::list_ark_transactions
            );
        }
        CosignerCommand::SendVtxo { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::ark_send::send_vtxo
            );
        }
        CosignerCommand::RedeemVtxo { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::ark_send::redeem_vtxo
            );
        }
        CosignerCommand::Settle { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::ark_send::settle);
        }
        CosignerCommand::SettleDelegate { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::ark_send::settle_delegate
            );
        }
        CosignerCommand::SubmitArkSend { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::ark_send::submit_ark_send
            );
        }
        CosignerCommand::EvtxoOnboard { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::onboard::evtxo_onboard);
        }
        CosignerCommand::EvtxoPendingShares { req, reply } => {
            dispatch!(
                user,
                state,
                shared,
                req,
                reply,
                handlers::onboard::evtxo_pending_shares
            );
        }
        CosignerCommand::EvtxoAckShare { req, reply } => {
            dispatch!(user, state, shared, req, reply, handlers::onboard::evtxo_ack_share);
        }

        // -------- Push registration --------
        CosignerCommand::RegisterDeviceToken { req, reply } => {
            dispatch!(
                user,
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
            let res = run_blocking(user.clone(), state.clone(), move |user, state| {
                let _enter = span.enter();
                handlers::auto_settle::tick_auto_settle(user, state, &s)
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
            let user_lock = user.clone();
            let state_lock = state.clone();
            let blocking_outcome = tokio::task::spawn_blocking(move || {
                let _enter = span.enter();
                let mut user = user_lock.lock();
                let mut state = state_lock.lock();
                let added = match handlers::vtxo_stream::apply_stream_update(
                    &mut user,
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
            let user_lock = user.clone();
            let state_lock = state.clone();
            let blocking_outcome = tokio::task::spawn_blocking(move || {
                let _enter = span.enter();
                let mut user = user_lock.lock();
                let mut state = state_lock.lock();
                let added = match handlers::vtxo_stream::apply_stream_update(
                    &mut user,
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
