//! Concurrent registry of per-user actors. `DashMap` of mpsc senders;
//! lookup, dispatch, and stream fan-out are lock-free across distinct users.

use std::sync::Arc;

use dashmap::DashMap;
use tokio::sync::{mpsc, oneshot};
use tonic::Status;
use wasmtime::component::{Component, Linker};
use wasmtime::Engine;

use crate::shared::SharedServices;
use crate::wasm_manager::{ThresholdWorld, UserInstance, UserWasiView};

use super::actor::run_actor;
use super::command::UserCommand;
use super::handle::{OwnedHandle, UserHandle};
use super::state::UserState;

/// Per-actor mailbox depth. Sized for normal request bursts plus a margin for
/// stream fan-in (VTXO updates, indexer events).
const MAILBOX_CAPACITY: usize = 256;

pub struct UserRegistry {
    engine: Engine,
    component: Component,
    linker: Linker<UserWasiView>,
    shared: Arc<SharedServices>,
    /// Active actors keyed by user_id_hex.
    actors: DashMap<String, OwnedHandle>,
    /// Secondary index: recovery_id_hex → user_id_hex. Populated at startup
    /// from `policy_recovery_idx` persistence tree, kept in sync on policy
    /// create/update/delete.
    recovery_idx: DashMap<String, String>,
    /// Reverse index: vtxo_script_hex → user_id_hex. Used by the global VTXO
    /// stream to route notifications to the right actor.
    script_idx: DashMap<String, String>,
}

impl UserRegistry {
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
            recovery_idx: DashMap::new(),
            script_idx: DashMap::new(),
        }))
    }

    pub fn shared(&self) -> &Arc<SharedServices> {
        &self.shared
    }

    /// Get the existing actor handle for `user_id`, or spawn a new one.
    /// Cheap fast path when the actor already exists (DashMap read).
    pub fn get_or_spawn(self: &Arc<Self>, user_id: &str) -> Result<UserHandle, Status> {
        if let Some(entry) = self.actors.get(user_id) {
            return Ok(entry.handle.clone());
        }
        // Slow path: instantiate WASM and spawn the actor task.
        let (tx, rx) = mpsc::channel::<UserCommand>(MAILBOX_CAPACITY);
        let user = self
            .new_user_instance()
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let state = UserState::new();
        let shared = self.shared.clone();
        let registry = self.clone();
        let join = tokio::spawn(run_actor(user, state, rx, shared, registry));
        let handle = UserHandle::new(tx);
        let owned = OwnedHandle {
            handle: handle.clone(),
            join,
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

    /// Build a fresh `UserInstance` from the cached engine/component/linker.
    fn new_user_instance(&self) -> Result<UserInstance, Box<dyn std::error::Error>> {
        use wasmtime::Store;
        use wasmtime_wasi::{ResourceTable, WasiCtxBuilder};
        let wasi_ctx = WasiCtxBuilder::new().inherit_stdio().build();
        let view = UserWasiView::new(ResourceTable::new(), wasi_ctx);
        let mut store = Store::new(&self.engine, view);
        let bindings = ThresholdWorld::instantiate(&mut store, &self.component, &self.linker)?;
        let iface = bindings.component_threshold_types();
        let session = iface.threshold_session().call_constructor(&mut store)?;
        Ok(UserInstance {
            store,
            bindings,
            session: Some(session),
            round1_secret: None,
            round2_secret: None,
            signing_nonce: None,
            dkg_session: None,
            signing_session: None,
            refresh_session: None,
            dkg_sync: None,
            signing_sync: None,
            refresh_sync: None,
            script_path_spend: false,
            policy_state: None,
            utxo_state: None,
        })
    }

    /// Send a command to the user's actor and await the typed reply.
    /// `make_cmd` receives the reply oneshot sender and returns the command to send.
    pub async fn dispatch<T, F>(self: &Arc<Self>, user_id: &str, make_cmd: F) -> Result<T, Status>
    where
        F: FnOnce(oneshot::Sender<Result<T, Status>>) -> UserCommand,
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
    // Secondary indices
    // -------------------------------------------------------------------

    pub fn user_for_recovery_id(&self, recovery_id_hex: &str) -> Option<String> {
        self.recovery_idx.get(recovery_id_hex).map(|v| v.clone())
    }

    pub fn set_recovery_id(&self, recovery_id_hex: &str, user_id_hex: &str) {
        self.recovery_idx
            .insert(recovery_id_hex.to_string(), user_id_hex.to_string());
    }

    pub fn user_for_script(&self, script_hex: &str) -> Option<String> {
        self.script_idx.get(script_hex).map(|v| v.clone())
    }

    pub fn set_script_owner(&self, script_hex: &str, user_id_hex: &str) {
        self.script_idx
            .insert(script_hex.to_string(), user_id_hex.to_string());
    }

    /// Populate `recovery_idx` and `script_idx` from the persistence backend.
    /// Called once at startup so cross-user lookups (recovery_id, vtxo script)
    /// don't have to wake any actors.
    pub fn load_indices_from_persistence(&self) -> Result<(), Box<dyn std::error::Error>> {
        for (recovery_id, user_id) in self.shared.persistence.get_all("policy_recovery_idx")? {
            self.recovery_idx.insert(recovery_id, user_id);
        }
        for (script_hex, user_id) in self.shared.persistence.get_all("ark_script_to_user")? {
            self.script_idx.insert(script_hex, user_id);
        }
        Ok(())
    }
}
