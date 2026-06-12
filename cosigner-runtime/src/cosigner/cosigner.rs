//! Per-user cosigner: the WASM instance that holds the threshold-crypto state,
//! plus the tokio actor that owns it and drives it.
//!
//! `CosignerInstance` keeps all threshold state in WASM linear memory (only
//! persistent host state — policy, UTXOs — is mirrored on the host). Each user
//! has exactly one instance; `run_actor` is a tokio task that owns it + its
//! `CosignerState` and processes commands serially. Per-command WASM work runs
//! inside `spawn_blocking`, so an idle actor is just memory, not a thread. The
//! instance + state live behind `Arc<parking_lot::Mutex<>>` so the panic-recovery
//! path in `run_actor` can reseat a wedged WASM instance without losing user
//! state (`parking_lot` doesn't poison on panic, so the recovery reseat is clean).

use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use futures::FutureExt;
use parking_lot::Mutex;
use tokio::sync::mpsc;
use tonic::Status;
use wasmtime::component::ResourceAny;
use wasmtime::Store;
use wasmtime_wasi::{ResourceTable, WasiCtx, WasiView};

use crate::policy::{PolicyState, UtxoState};
use crate::shared::SharedServices;

use super::command::CosignerCommand;
use super::handlers;
use super::registry::CosignerRegistry;
use super::state::{CosignerState, DeviceToken};

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

fn now_secs() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Lock `user` and `state` inside `spawn_blocking`, run `f`, return the typed
/// result. `(user, state)` ownership stays with the actor task across this
/// call; the mutex guards only protect against panic-recovery reseating the
/// instance.
///
/// On a handler panic, `spawn_blocking` returns `Err(JoinError::is_panic)`.
/// We surface that as `Err(Status::internal("handler panicked"))` so the
/// caller's oneshot reply fires with an error instead of hanging. The actor
/// task itself stays alive — its outer `catch_unwind` in `run_actor` reseats
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

pub async fn run_actor(
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
/// `run_actor` can wrap a single async unit cleanly. `Shutdown` is handled
/// directly in `run_actor` (it breaks the loop) and never reaches here.
async fn dispatch_one(
    cmd: CosignerCommand,
    user: Arc<Mutex<CosignerInstance>>,
    state: Arc<Mutex<CosignerState>>,
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
) {
    match cmd {
        CosignerCommand::Shutdown => {
            // Already filtered out by run_actor; reaching this arm would be a
            // bug. Logging it makes it visible without panicking.
            tracing::error!("dispatch_one received Shutdown; expected to be filtered by run_actor");
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
