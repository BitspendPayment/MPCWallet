//! User actor: a tokio task that owns one user's `CosignerInstance` + `CosignerState`
//! and processes commands serially. Per-command WASM work runs inside
//! `spawn_blocking` so the actor task stays light — millions of idle actors fit
//! in memory; only currently-executing WASM consumes a blocking-pool thread.

use std::sync::Arc;

use tokio::sync::mpsc;
use tonic::Status;

use crate::shared::SharedServices;
use crate::cosigner::wasm::CosignerInstance;

use super::command::CosignerCommand;
use super::handlers;
use super::registry::CosignerRegistry;
use super::state::CosignerState;

/// Move `(user, state)` into a blocking closure, run `f`, reclaim ownership.
/// `f` returns the response payload; the user/state pair is paired back via
/// the spawn_blocking return tuple.
async fn run_blocking<F, T>(
    user: CosignerInstance,
    state: CosignerState,
    f: F,
) -> (CosignerInstance, CosignerState, Result<T, Status>)
where
    F: FnOnce(&mut CosignerInstance, &mut CosignerState) -> Result<T, Status> + Send + 'static,
    T: Send + 'static,
{
    tokio::task::spawn_blocking(move || {
        let mut user = user;
        let mut state = state;
        let res = f(&mut user, &mut state);
        (user, state, res)
    })
    .await
    .unwrap_or_else(|join_err| panic!("user actor blocking task panicked: {join_err:?}"))
}

/// Standard dispatch: handler returns `Result<Resp, Status>`; macro fires the
/// reply oneshot. Captures the current span and re-enters it inside
/// `spawn_blocking` so the handler's instrumented span stays in the trace tree.
macro_rules! dispatch {
    ($user:ident, $state:ident, $shared:ident, $registry:ident, $req:ident, $reply:ident, $handler:path) => {{
        let s = $shared.clone();
        let r = $registry.clone();
        let span = tracing::Span::current();
        let (u, st, res) = run_blocking($user, $state, move |user, state| {
            let _enter = span.enter();
            $handler(user, state, &s, &r, $req)
        })
        .await;
        $user = u;
        $state = st;
        let _ = $reply.send(res);
    }};
}

/// Rendezvous dispatch: handler owns the reply sender so it can fire inline or
/// stash it in `CosignerState.pending_*`. Used by multi-participant flows (DKG).
macro_rules! dispatch_rendezvous {
    ($user:ident, $state:ident, $shared:ident, $registry:ident, $req:ident, $reply:ident, $handler:path) => {{
        let s = $shared.clone();
        let r = $registry.clone();
        let span = tracing::Span::current();
        let (u, st) = tokio::task::spawn_blocking(move || {
            let _enter = span.enter();
            let mut user = $user;
            let mut state = $state;
            $handler(&mut user, &mut state, &s, &r, $req, $reply);
            (user, state)
        })
        .await
        .unwrap_or_else(|e| panic!("user actor blocking task panicked: {e:?}"));
        $user = u;
        $state = st;
    }};
}

pub async fn run_actor(
    mut user: CosignerInstance,
    mut state: CosignerState,
    mut rx: mpsc::Receiver<CosignerCommand>,
    shared: Arc<SharedServices>,
    registry: Arc<CosignerRegistry>,
) {
    while let Some(cmd) = rx.recv().await {
        match cmd {
            CosignerCommand::Shutdown => break,

            // -------- Policy --------
            CosignerCommand::CreateSpendingPolicy { req, reply } => {
                dispatch!(
                    user,
                    state,
                    shared,
                    registry,
                    req,
                    reply,
                    handlers::policy::create_spending_policy
                );
            }
            CosignerCommand::GetPolicyId { req, reply } => {
                dispatch!(
                    user,
                    state,
                    shared,
                    registry,
                    req,
                    reply,
                    handlers::policy::get_policy_id
                );
            }
            CosignerCommand::UpdatePolicy { req, reply } => {
                dispatch!(
                    user,
                    state,
                    shared,
                    registry,
                    req,
                    reply,
                    handlers::policy::update_policy
                );
            }
            CosignerCommand::DeletePolicy { req, reply } => {
                dispatch!(
                    user,
                    state,
                    shared,
                    registry,
                    req,
                    reply,
                    handlers::policy::delete_policy
                );
            }

            // -------- DKG (rendezvous) --------
            CosignerCommand::DkgStep1 { req, reply } => {
                dispatch_rendezvous!(user, state, shared, registry, req, reply, handlers::dkg::dkg_step1);
            }
            CosignerCommand::DkgStep2 { req, reply } => {
                dispatch_rendezvous!(user, state, shared, registry, req, reply, handlers::dkg::dkg_step2);
            }
            CosignerCommand::DkgStep3 { req, reply } => {
                dispatch_rendezvous!(user, state, shared, registry, req, reply, handlers::dkg::dkg_step3);
            }

            // -------- Signing --------
            CosignerCommand::SignStep1 { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::sign::sign_step1);
            }
            CosignerCommand::SignStep2 { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::sign::sign_step2);
            }

            // -------- Refresh --------
            CosignerCommand::RefreshStep1 { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::refresh::refresh_step1);
            }
            CosignerCommand::RefreshStep2 { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::refresh::refresh_step2);
            }
            CosignerCommand::RefreshStep3 { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::refresh::refresh_step3);
            }

            // -------- Transactions --------
            CosignerCommand::BroadcastTransaction { req, reply } => {
                dispatch!(
                    user,
                    state,
                    shared,
                    registry,
                    req,
                    reply,
                    handlers::tx::broadcast_transaction
                );
            }
            CosignerCommand::FetchHistory { req, reply } => {
                dispatch!(
                    user,
                    state,
                    shared,
                    registry,
                    req,
                    reply,
                    handlers::tx::fetch_history
                );
            }
            CosignerCommand::FetchRecentTransactions { req, reply } => {
                dispatch!(
                    user,
                    state,
                    shared,
                    registry,
                    req,
                    reply,
                    handlers::tx::fetch_recent_transactions
                );
            }

            // -------- Ark (lookups) --------
            CosignerCommand::GetArkInfo { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark::get_ark_info);
            }
            CosignerCommand::GetArkAddress { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark::get_ark_address);
            }
            CosignerCommand::GetBoardingAddress { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark::get_boarding_address);
            }
            CosignerCommand::CheckBoardingBalance { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark::check_boarding_balance);
            }
            CosignerCommand::ListVtxos { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark::list_vtxos);
            }
            CosignerCommand::ListArkTransactions { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark::list_ark_transactions);
            }
            CosignerCommand::SendVtxo { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark_send::send_vtxo);
            }
            CosignerCommand::RedeemVtxo { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark_send::redeem_vtxo);
            }
            CosignerCommand::Settle { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark_send::settle);
            }
            CosignerCommand::SettleDelegate { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark_send::settle_delegate);
            }
            CosignerCommand::SubmitArkSend { req, reply } => {
                dispatch!(user, state, shared, registry, req, reply, handlers::ark_send::submit_ark_send);
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
                let (u, st) = tokio::task::spawn_blocking(move || {
                    let _enter = span.enter();
                    let mut user = user;
                    let mut state = state;
                    if let Err(e) = handlers::vtxo_stream::apply_stream_update(
                        &mut user, &mut state, &s, &user_id_hex, spent, spendable, info,
                    ) {
                        tracing::warn!("[{user_id_hex}] VTXO stream apply failed: {e}");
                    }
                    (user, state)
                })
                .await
                .unwrap_or_else(|e| panic!("user actor blocking task panicked: {e:?}"));
                user = u;
                state = st;
            }
            CosignerCommand::IndexerUpdate {
                user_id_hex,
                new_vtxos,
                spent_vtxos,
                info,
            } => {
                let s = shared.clone();
                let span = tracing::info_span!("actor::indexer_update", user_id = %user_id_hex);
                let (u, st) = tokio::task::spawn_blocking(move || {
                    let _enter = span.enter();
                    let mut user = user;
                    let mut state = state;
                    if let Err(e) = handlers::vtxo_stream::apply_stream_update(
                        &mut user, &mut state, &s, &user_id_hex, spent_vtxos, new_vtxos, info,
                    ) {
                        tracing::warn!("[{user_id_hex}] Indexer apply failed: {e}");
                    }
                    (user, state)
                })
                .await
                .unwrap_or_else(|e| panic!("user actor blocking task panicked: {e:?}"));
                user = u;
                state = st;
            }
        }
    }
    drop((user, state));
}
