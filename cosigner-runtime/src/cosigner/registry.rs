//! Concurrent registry of per-user actors plus the tokio actor loop that owns + drives each.
//!
//! All signing keys + the FROST ceremony live in the per-actor `cosigner-guest` component;
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
use wasmtime::component::{Component, Linker};
use wasmtime::Engine;

use crate::shared::SharedServices;

use super::command::CosignerCommand;
use super::guest_instance::GuestInstance;
use super::handle::{CosignerHandle, OwnedHandle};
use super::handlers;
use super::state::{CosignerState, DeviceToken};
use crate::wallet_proto::{
    send_vtxo_response, settle_delegate_response, sign_step1_response, SendVtxoRequest,
    SendVtxoResponse, SettleDelegateRequest, SettleDelegateResponse, SignStep1Request,
    SignStep1Response, SignStep2Request, SignStep2Response,
};
use cosigner_proto::{
    ApplyDelegateSigsWire, ArkTxEntryWire, ContractPairingWire, GenerateDelegateWire, GuestCommand,
    GuestResponse, SendVtxoStep2Wire, SignStep1Wire, SignStep2Wire,
};

/// Convert the host `ContractPairing` projection to the wire form carried into the guest's
/// `InstallPolicy` (Plan A 1C — the guest does the cooperative-leaf conditioning).
fn pairing_to_wire(p: &crate::policy::ContractPairing) -> ContractPairingWire {
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
    /// Native-async stack for the long-lived `cosigner-guest` — the only WASM component.
    /// It owns all signing keys, the FROST ceremony, and per-user state.
    guest_engine: Engine,
    guest_component: Component,
    guest_linker: Linker<super::guest_instance::GuestInstanceCtx>,
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
        guest_wasm_path: &str,
        shared: Arc<SharedServices>,
    ) -> Result<Arc<Self>, Box<dyn std::error::Error>> {
        let guest_engine = super::guest_instance::build_engine()?;
        let guest_component = Component::from_file(&guest_engine, guest_wasm_path)?;
        let guest_linker = super::guest_instance::build_linker(&guest_engine)?;

        Ok(Arc::new(Self {
            guest_engine,
            guest_component,
            guest_linker,
            shared,
            actors: DashMap::new(),
            script_idx: DashMap::new(),
        }))
    }

    /// Instantiate a fresh native-async `cosigner-guest` instance, wired to this
    /// registry's shared services (so its `contract-gate` import enforces real
    /// contracts). One per actor; its in-WASM state persists across `command` calls.
    pub async fn spawn_guest_instance(
        &self,
    ) -> anyhow::Result<super::guest_instance::GuestInstance> {
        super::guest_instance::GuestInstance::spawn(
            &self.guest_engine,
            &self.guest_component,
            &self.guest_linker,
            Some(self.shared.clone()),
        )
        .await
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
        // device_tokens) intact across a caught panic. All signing keys live in the guest.
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

        // Rehydrate a persisted delegate intent if one is present. The
        // sled row doesn't carry the cosigner secret (issue #31) — we look
        // it up from `SecretStore` here and pass it into `from_persisted`.
        // On any failure (missing secret, parse error, pubkey mismatch),
        // delete the sled row so the next actor spawn doesn't keep
        // retrying — the client will re-delegate on its next refresh.
        let mut delegate_loaded = false;
        if let Some(persisted_record) =
            super::handlers::helpers::load_user_delegate(persistence, group_key)
        {
            match self
                .shared
                .secret_store
                .get_secret(&format!("dkg-secret.{group_key}"))
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
                                    covered_outpoints: persisted_record.covered_outpoints.clone(),
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
                                "Rehydrate delegate for {group_key} failed: {e}; dropping sled row"
                            );
                            super::handlers::helpers::delete_user_delegate(persistence, group_key);
                        }
                    }
                }
                Ok(None) => {
                    tracing::warn!(
                        "Rehydrate delegate for {group_key}: SecretStore missing dkg-secret entry; dropping sled row"
                    );
                    super::handlers::helpers::delete_user_delegate(persistence, group_key);
                }
                Err(e) => {
                    tracing::warn!(
                        "Rehydrate delegate for {group_key}: SecretStore error {e}; leaving sled row in place"
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
// All signing keys + ceremony live in the per-actor `cosigner-guest`.
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
    // Per-actor native-async guest (lazily spawned on the first sign). Its in-WASM state
    // (keys + ceremony) persists across commands. ALL signing routes through it.
    let mut guest: Option<GuestInstance> = None;
    let mut guest_policy_installed = false;

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
        // through the native-async guest where the keys live. Runs outside the
        // catch_unwind below because the guest path surfaces errors as replies.
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
                    &mut guest,
                    &mut guest_policy_installed,
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
                    &mut guest,
                    &mut guest_policy_installed,
                )
                .await;
                continue;
            }
            CosignerCommand::SignStep2 { req, reply } => {
                route_sign_step2(
                    req,
                    reply,
                    &mut guest,
                    &mut guest_policy_installed,
                )
                .await;
                continue;
            }
            // SendVtxo: the session + signing live in the guest (keys never leave it); the
            // host only translates its VTXO projection in/out. Falls back to the legacy
            // host handler when the ASP URL isn't configured for the guest.
            CosignerCommand::SendVtxo { req, reply } if shared.asp_url.is_some() => {
                route_send_vtxo(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut guest,
                    &mut guest_policy_installed,
                )
                .await;
                continue;
            }
            // Delegate-settle: the cosigner secret + session live in the guest; the host
            // only relays. Falls back to the legacy host handler without ASP config.
            CosignerCommand::SettleDelegate { req, reply } if shared.asp_url.is_some() => {
                route_settle_delegate(
                    req,
                    reply,
                    &state,
                    &shared,
                    &registry,
                    &mut guest,
                    &mut guest_policy_installed,
                )
                .await;
                continue;
            }
            // Auto-settle tick: if this actor has a guest-routed delegate pending, drive it in
            // the guest. Otherwise fall through to the legacy host tick.
            CosignerCommand::TickAutoSettle
                if shared.asp_url.is_some() && state.lock().guest_delegate_threshold.is_some() =>
            {
                route_tick_auto_settle(
                    &state,
                    &shared,
                    &registry,
                    &mut guest,
                    &mut guest_policy_installed,
                )
                .await;
                continue;
            }
            // Seed freshly-computed policy material into the guest and seal it (onboarding /
            // contract-create). After this the keys live in the guest's sealed snapshot.
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
                    &mut guest,
                    &mut guest_policy_installed,
                )
                .await;
                continue;
            }
            other => other,
        };

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

/// Drop the guest so the next normal sign respawns it from a clean state. Called when a
/// guest command traps/errors (the in-WASM ceremony may be wedged).
fn reseat_guest(guest: &mut Option<GuestInstance>, installed: &mut bool) {
    *guest = None;
    *installed = false;
}

/// Phase 4: opaque sealed-state tree (one blob per group key). The host stores it but
/// cannot read it (identity-sealed JSON today; enclave AEAD later). Keyed by group key.
const SEALED_STATE_TREE: &str = "sealed_state";

/// Persist the guest's snapshot blob after a state mutation (best-effort).
async fn persist_guest_snapshot(
    guest: &mut GuestInstance,
    shared: &SharedServices,
    group_key: &str,
) {
    match guest.command(GuestCommand::Snapshot).await {
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

/// Restore the guest's state from a persisted snapshot, if one exists (on spawn/reseat).
/// Returns `true` when a snapshot was restored — meaning the guest now holds its policy +
/// keys from the sealed blob, so the caller can SKIP `InstallPolicy` (no plaintext key read).
/// `false` when there's no stored blob (first run) or restore failed.
async fn restore_guest_snapshot(
    guest: &mut GuestInstance,
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
    match guest.command(GuestCommand::RestoreSnapshot { blob }).await {
        Ok(GuestResponse::Restored) => {
            tracing::info!("restored guest snapshot for {group_key}");
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

/// Route `ContractRefresh` (Plan A): ensure the wallet actor's guest is up + its policy
/// restored/installed, then refresh `V` onto the pairing INSIDE the guest. The host never reads
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
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) {
    if let Err(e) =
        ensure_guest_with_policy(state, shared, registry, guest, guest_policy_installed).await
    {
        let _ = reply.send(Err(e));
        return;
    }
    let result = guest
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
            reseat_guest(guest, guest_policy_installed);
        }
        Ok(other) => {
            let _ = reply.send(Err(Status::internal(format!("contract_refresh: {other:?}"))));
            reseat_guest(guest, guest_policy_installed);
        }
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("contract_refresh: {e}"))));
            reseat_guest(guest, guest_policy_installed);
        }
    }
}

/// Route `SignStep1`: non-contract spends (raw script-path AND key-path-tweaked) go to the
/// native-async guest where the keys live — every spend type (script-path, key-path tweak,
/// contract). The contract gate is enforced inside the guest's sign step2.
#[allow(clippy::too_many_arguments)]
async fn route_sign_step1(
    req: SignStep1Request,
    reply: oneshot::Sender<Result<SignStep1Response, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) {
    // The group key is the actor's own id; signing routes to the guest, which restores keys +
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
    // sighash; verify the arkd two-leg) now lives INSIDE the guest (`conditioning::*`), which holds
    // `contract_pairing` in its sealed policy. The host just forwards the spend (`full_transaction`
    // + `ark_tx`); the guest is authoritative about what it signs.

    // Lazily spawn the guest, then install the policy once.
    if guest.is_none() {
        match registry.spawn_guest_instance().await {
            Ok(g) => {
                *guest = Some(g);
                *guest_policy_installed = false;
            }
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("guest spawn: {e}"))));
                return;
            }
        }
    }
    if !*guest_policy_installed {
        let gk = group_key.clone();
        // Restore-FIRST: a sealed snapshot carries the keys AND durable state (VTXOs/history/
        // delegate/contract-pairing), so when it restores we skip `InstallPolicy` entirely — no
        // plaintext key is read on this path.
        if restore_guest_snapshot(guest.as_mut().unwrap(), shared, &gk).await {
            *guest_policy_installed = true;
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
            let result = guest
                .as_mut()
                .unwrap()
                .command(GuestCommand::InstallPolicy {
                    group_key,
                    key_package_json,
                    public_key_package_json,
                    user_signing_identifier_hex: user_identifier_hex,
                    server_dkg_secret_hex,
                    contract_pairing: None,
                })
                .await;
            match result {
                Ok(GuestResponse::PolicyInstalled) => *guest_policy_installed = true,
                Ok(other) => {
                    let _ = reply.send(Err(Status::internal(format!("InstallPolicy: {other:?}"))));
                    reseat_guest(guest, guest_policy_installed);
                    return;
                }
                Err(e) => {
                    let _ = reply.send(Err(Status::internal(format!("InstallPolicy: {e}"))));
                    reseat_guest(guest, guest_policy_installed);
                    return;
                }
            }
            persist_guest_snapshot(guest.as_mut().unwrap(), shared, &gk).await;
        } else {
            // No sealed snapshot and no host policy material — the actor was never seeded. Per
            // Plan A 1B/1C restore is the only path to the keys; there is no plaintext fallback.
            reseat_guest(guest, guest_policy_installed);
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
    let result = guest
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
            reseat_guest(guest, guest_policy_installed);
        }
        Ok(other) => {
            let _ = reply.send(Err(Status::internal(format!("sign_step1: {other:?}"))));
            reseat_guest(guest, guest_policy_installed);
        }
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("guest sign_step1: {e}"))));
            reseat_guest(guest, guest_policy_installed);
        }
    }
}

/// Route `SignStep2` through the per-actor guest (the only sign path).
async fn route_sign_step2(
    req: SignStep2Request,
    reply: oneshot::Sender<Result<SignStep2Response, Status>>,
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) {
    if guest.is_none() {
        // The guest is established in step1; if it's gone (e.g. reseated mid-ceremony) the
        // client must restart from step1. The legacy in-WASM sign path no longer exists.
        let _ = reply.send(Err(Status::internal(
            "guest unavailable for sign step2; restart from step1",
        )));
        return;
    }

    let wire = SignStep2Wire {
        user_id: req.user_id,
        signature_share: req.signature_share,
        signature: req.signature,
        timestamp_ms: req.timestamp_ms,
    };
    let result = guest
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
            reseat_guest(guest, guest_policy_installed);
        }
        Ok(other) => {
            let _ = reply.send(Err(Status::internal(format!("sign_step2: {other:?}"))));
            reseat_guest(guest, guest_policy_installed);
        }
        Err(e) => {
            let _ = reply.send(Err(Status::internal(format!("guest sign_step2: {e}"))));
            reseat_guest(guest, guest_policy_installed);
        }
    }
}

/// Seed freshly-computed policy material (from onboarding / contract-create) into the
/// per-actor guest and seal it into the guest's snapshot. After this the keys live in the
/// guest's sealed blob, so later cold spawns restore them without a host-side plaintext key.
#[allow(clippy::too_many_arguments)]
#[allow(clippy::too_many_arguments)]
async fn route_seed_policy(
    key_package_json: String,
    public_key_package_json: String,
    user_signing_identifier_hex: Option<String>,
    server_dkg_secret_hex: Option<String>,
    contract_pairing: Option<crate::policy::ContractPairing>,
    reply: oneshot::Sender<Result<(), Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) {
    let group_key = state.lock().cosigner_id.clone();
    // The SeedPolicy args carry the fresh key material + (for a pairing actor) the conditioning
    // params. The secret key + `contract_pairing` are installed into the guest + sealed; the host
    // keeps only a routing projection. `contracts` (if any) come from a prior persisted projection.
    let contracts = shared
        .persistence
        .get("policies", &group_key)
        .ok()
        .flatten()
        .and_then(|j| serde_json::from_str::<crate::policy::PolicyState>(&j).ok())
        .map(|p| p.contracts)
        .unwrap_or_default();
    {
        let mut s = state.lock();
        s.policy_state = Some(crate::policy::PolicyState {
            cosigner_id: group_key.clone(),
            user_signing_identifier_hex,
            server_dkg_secret_hex,
            normal_policy: crate::policy::NormalPolicy {
                id: "normal".to_string(),
                key_package_json,
                public_key_package_json,
            },
            contracts,
            contract_pairing,
        });
    }
    if let Err(e) =
        ensure_guest_with_policy(state, shared, registry, guest, guest_policy_installed).await
    {
        let _ = reply.send(Err(e));
        return;
    }
    persist_guest_snapshot(guest.as_mut().unwrap(), shared, &group_key).await;
    let _ = reply.send(Ok(()));
}

/// Ensure the per-actor guest is spawned and its policy installed. On error, returns a
/// `Status` for the caller to reply with (the guest is reseated on install failure).
async fn ensure_guest_with_policy(
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) -> Result<(), Status> {
    let (
        key_package_json,
        public_key_package_json,
        user_identifier_hex,
        group_key,
        server_dkg_secret_hex,
        contract_pairing,
    ) = {
        let cosigner_id = state.lock().cosigner_id.clone();
        let mut state_guard = state.lock();
        handlers::helpers::ensure_policy_loaded(
            &mut state_guard,
            shared.persistence.as_ref(),
            shared.secret_store.as_ref(),
            &cosigner_id,
        )?;
        let policy = state_guard
            .policy_state
            .as_ref()
            .ok_or_else(|| Status::not_found("no policy state"))?;
        (
            policy.normal_policy.key_package_json.clone(),
            policy.normal_policy.public_key_package_json.clone(),
            policy.user_signing_identifier_hex.clone(),
            policy.cosigner_id.clone(),
            policy.server_dkg_secret_hex.clone(),
            policy.contract_pairing.clone(),
        )
    };

    if guest.is_none() {
        let g = registry
            .spawn_guest_instance()
            .await
            .map_err(|e| Status::internal(format!("guest spawn: {e}")))?;
        *guest = Some(g);
        *guest_policy_installed = false;
    }
    if !*guest_policy_installed {
        let gk = group_key.clone();
        // Restore-FIRST: a sealed snapshot carries keys + durable state, so skip the plaintext
        // `InstallPolicy` when it restores.
        if restore_guest_snapshot(guest.as_mut().unwrap(), shared, &gk).await {
            *guest_policy_installed = true;
        } else {
            // First run (no snapshot): install from policy material, then seal immediately so
            // later cold spawns restore from the snapshot instead.
            let result = guest
                .as_mut()
                .unwrap()
                .command(GuestCommand::InstallPolicy {
                    group_key,
                    key_package_json,
                    public_key_package_json,
                    user_signing_identifier_hex: user_identifier_hex,
                    server_dkg_secret_hex,
                    contract_pairing: contract_pairing.as_ref().map(pairing_to_wire),
                })
                .await;
            match result {
                Ok(GuestResponse::PolicyInstalled) => *guest_policy_installed = true,
                Ok(other) => {
                    reseat_guest(guest, guest_policy_installed);
                    return Err(Status::internal(format!("InstallPolicy: {other:?}")));
                }
                Err(e) => {
                    reseat_guest(guest, guest_policy_installed);
                    return Err(Status::internal(format!("InstallPolicy: {e}")));
                }
            }
            persist_guest_snapshot(guest.as_mut().unwrap(), shared, &gk).await;
        }
    }
    Ok(())
}

/// Route `SendVtxo` through the guest. Phase 1 (no signatures): build the step1 wire from
/// the host VTXO projection, get sighashes. Phase 2 (signatures present): sign + submit in
/// the guest, then apply the result to the host VTXO/history projection. The session and
/// keys live entirely in the guest; the host only moves bytes and updates its projection.
#[allow(clippy::too_many_arguments)]
async fn route_send_vtxo(
    req: SendVtxoRequest,
    reply: oneshot::Sender<Result<SendVtxoResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) {
    let Some(asp_url) = shared.asp_url.clone() else {
        let _ = reply.send(Err(Status::unavailable("ASP not configured (set ASP_URL)")));
        return;
    };
    if let Err(e) =
        ensure_guest_with_policy(state, shared, registry, guest, guest_policy_installed).await
    {
        let _ = reply.send(Err(e));
        return;
    }

    if req.signed_messages.is_empty() {
        // Phase 1: push the VTXO set into the guest, then build → sighashes.
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
        match guest
            .as_mut()
            .unwrap()
            .command(GuestCommand::SetVtxos { vtxos })
            .await
        {
            Ok(GuestResponse::VtxosSet) => {}
            Ok(other) => {
                let _ = reply.send(Err(Status::internal(format!("SetVtxos: {other:?}"))));
                reseat_guest(guest, guest_policy_installed);
                return;
            }
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("guest SetVtxos: {e}"))));
                reseat_guest(guest, guest_policy_installed);
                return;
            }
        }
        let result = guest
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
                reseat_guest(guest, guest_policy_installed);
            }
            Ok(other) => {
                let _ = reply.send(Err(Status::internal(format!("send_vtxo step1: {other:?}"))));
                reseat_guest(guest, guest_policy_installed);
            }
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("guest send_vtxo step1: {e}"))));
                reseat_guest(guest, guest_policy_installed);
            }
        }
    } else {
        // Phase 2: sign + submit in the guest, then apply to the host projection.
        let wire = SendVtxoStep2Wire {
            user_id: req.user_id.clone(),
            signature: req.signature.clone(),
            timestamp_ms: req.timestamp_ms,
            asp_url,
            signed_messages: req.signed_messages.clone(),
        };
        let result = guest
            .as_mut()
            .unwrap()
            .command(GuestCommand::SendVtxoStep2(wire))
            .await;
        match result {
            Ok(GuestResponse::SendVtxoSubmitted { ark_txid, change }) => {
                // Mirror the send into the guest's owned history (it owns the data for the
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
                let _ = guest
                    .as_mut()
                    .unwrap()
                    .command(GuestCommand::AppendHistory { entry })
                    .await;
                // Phase 4: the send mutated guest VTXOs + history — persist the snapshot.
                let group_key = state.lock().cosigner_id.clone();
                persist_guest_snapshot(guest.as_mut().unwrap(), shared, &group_key).await;
                let _ = reply.send(Ok(resp));
            }
            Ok(GuestResponse::Error(msg)) => {
                let _ = reply.send(Err(Status::internal(msg)));
                reseat_guest(guest, guest_policy_installed);
            }
            Ok(other) => {
                let _ = reply.send(Err(Status::internal(format!("send_vtxo step2: {other:?}"))));
                reseat_guest(guest, guest_policy_installed);
            }
            Err(e) => {
                let _ = reply.send(Err(Status::internal(format!("guest send_vtxo step2: {e}"))));
                reseat_guest(guest, guest_policy_installed);
            }
        }
    }
}

/// Route `SettleDelegate` through the guest. Phase 1 (no signatures): push VTXOs + build the
/// delegate (self-refresh) → sighashes. Phase 2 (signatures): insert them (→ ReadyToSettle),
/// then either store for the auto-settle tick (`store_only`, snapshot persisted) or drive the
/// batch immediately. The cosigner secret + session never leave the guest.
#[allow(clippy::too_many_arguments)]
async fn route_settle_delegate(
    req: SettleDelegateRequest,
    reply: oneshot::Sender<Result<SettleDelegateResponse, Status>>,
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) {
    let Some(asp_url) = shared.asp_url.clone() else {
        let _ = reply.send(Err(Status::unavailable("ASP not configured (set ASP_URL)")));
        return;
    };
    if let Err(e) =
        ensure_guest_with_policy(state, shared, registry, guest, guest_policy_installed).await
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
        match guest
            .as_mut()
            .unwrap()
            .command(GuestCommand::SetVtxos { vtxos })
            .await
        {
            Ok(GuestResponse::VtxosSet) => {}
            other => {
                let _ = reply.send(Err(Status::internal(format!("SetVtxos: {other:?}"))));
                reseat_guest(guest, guest_policy_installed);
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
        match guest
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
                reseat_guest(guest, guest_policy_installed);
            }
            other => {
                let _ = reply.send(Err(Status::internal(format!("GenerateDelegate: {other:?}"))));
                reseat_guest(guest, guest_policy_installed);
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
    match guest
        .as_mut()
        .unwrap()
        .command(GuestCommand::ApplyDelegateSigs(apply))
        .await
    {
        Ok(GuestResponse::DelegateReady) => {}
        Ok(GuestResponse::Error(msg)) => {
            let _ = reply.send(Err(Status::internal(msg)));
            reseat_guest(guest, guest_policy_installed);
            return;
        }
        other => {
            let _ = reply.send(Err(Status::internal(format!("ApplyDelegateSigs: {other:?}"))));
            reseat_guest(guest, guest_policy_installed);
            return;
        }
    }

    if req.store_only {
        // Auto-settle path: persist the durable ReadyToSettle delegate + record the host-side
        // "when to fire" marker (earliest VTXO expiry − margin) for TickAutoSettle.
        {
            let mut st = state.lock();
            let earliest = st
                .vtxos
                .iter()
                .filter_map(|e| (e.expires_at > 0).then_some(e.expires_at))
                .min()
                .unwrap_or(0);
            let margin = shared.auto_settle_safety_margin_secs;
            st.guest_delegate_threshold = Some((earliest - margin).max(0));
        }
        persist_guest_snapshot(guest.as_mut().unwrap(), shared, &group_key).await;
        let _ = reply.send(Ok(SettleDelegateResponse {
            status: settle_delegate_response::Status::Delegated as i32,
            messages_to_sign: vec![],
            script_path_spend: false,
            commitment_txid: String::new(),
            error_message: String::new(),
        }));
        return;
    }

    // Manual path: drive the batch immediately in the guest.
    match guest
        .as_mut()
        .unwrap()
        .command(GuestCommand::SettleDelegate { asp_url })
        .await
    {
        Ok(GuestResponse::SettleSubmitted { commitment_txid, .. }) => {
            persist_guest_snapshot(guest.as_mut().unwrap(), shared, &group_key).await;
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
            reseat_guest(guest, guest_policy_installed);
        }
        other => {
            let _ = reply.send(Err(Status::internal(format!("SettleDelegate drive: {other:?}"))));
            reseat_guest(guest, guest_policy_installed);
        }
    }
}

/// Guest-routed auto-settle: if a stored delegate's threshold has arrived, drive it in the
/// guest. Fire-and-forget (no reply). `ensure_guest_with_policy` restores the delegate from
/// the snapshot if the actor was reseated; an alive actor already holds it.
async fn route_tick_auto_settle(
    state: &Arc<Mutex<CosignerState>>,
    shared: &Arc<SharedServices>,
    registry: &Arc<CosignerRegistry>,
    guest: &mut Option<GuestInstance>,
    guest_policy_installed: &mut bool,
) {
    let Some(threshold) = state.lock().guest_delegate_threshold else {
        return;
    };
    if now_secs() < threshold {
        return;
    }
    let Some(asp_url) = shared.asp_url.clone() else { return };
    if let Err(e) =
        ensure_guest_with_policy(state, shared, registry, guest, guest_policy_installed).await
    {
        tracing::warn!("auto-settle (guest): ensure guest failed: {e}");
        return;
    }
    let group_key = state.lock().cosigner_id.clone();
    match guest
        .as_mut()
        .unwrap()
        .command(GuestCommand::SettleDelegate { asp_url })
        .await
    {
        Ok(GuestResponse::SettleSubmitted { commitment_txid, .. }) => {
            state.lock().guest_delegate_threshold = None;
            persist_guest_snapshot(guest.as_mut().unwrap(), shared, &group_key).await;
            tracing::info!("auto-settle (guest): commitment_txid={commitment_txid}");
        }
        Ok(GuestResponse::Error(msg)) => {
            tracing::warn!("auto-settle (guest): {msg}");
            reseat_guest(guest, guest_policy_installed);
        }
        other => {
            tracing::warn!("auto-settle (guest): unexpected {other:?}");
            reseat_guest(guest, guest_policy_installed);
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
        // Handled in the guest-routed match (it `continue`s); never reaches the legacy path.
        CosignerCommand::ContractRefresh { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "ContractRefresh must be guest-routed, not dispatched to the legacy handler",
            )));
        }

        // -------- Signing --------
        // Both steps are intercepted in run_cosigner and routed to the guest (the only sign
        // path); reaching these arms would be a bug.
        CosignerCommand::SignStep1 { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "SignStep1 reached dispatch_one; should be routed to the guest",
            )));
        }
        CosignerCommand::SignStep2 { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "SignStep2 reached dispatch_one; should be routed to the guest",
            )));
        }
        // Intercepted in run_cosigner (spawns guest + installs + seals); reaching here is a bug.
        CosignerCommand::SeedPolicy { reply, .. } => {
            let _ = reply.send(Err(Status::internal(
                "SeedPolicy reached dispatch_one; should be intercepted in run_cosigner",
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
        CosignerCommand::SendVtxo { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::ark_send::send_vtxo
            );
        }
        CosignerCommand::RedeemVtxo { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::ark_send::redeem_vtxo
            );
        }
        CosignerCommand::Settle { req, reply } => {
            dispatch!(state, shared, req, reply, handlers::ark_send::settle);
        }
        CosignerCommand::SettleDelegate { req, reply } => {
            dispatch!(
                state,
                shared,
                req,
                reply,
                handlers::ark_send::settle_delegate
            );
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
