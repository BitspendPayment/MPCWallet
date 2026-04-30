use std::collections::HashMap;
use std::sync::atomic::AtomicBool;
use std::sync::{Arc, Mutex};

use tokio::sync::Notify;
use wasmtime::component::{Component, Linker, ResourceAny};
use wasmtime::{Config, Engine, Store};
use wasmtime_wasi::{ResourceTable, WasiCtx, WasiCtxBuilder, WasiView};

use crate::policy::{PolicyState, UtxoState};

// Generate host-side bindings from WIT
wasmtime::component::bindgen!({
    path: "wit/world.wit",
    world: "threshold-world",
    async: false,
});

pub struct UserWasiView {
    table: ResourceTable,
    ctx: WasiCtx,
}

impl UserWasiView {
    pub fn new(table: ResourceTable, ctx: WasiCtx) -> Self {
        Self { table, ctx }
    }
}

impl WasiView for UserWasiView {
    fn table(&mut self) -> &mut ResourceTable {
        &mut self.table
    }
    fn ctx(&mut self) -> &mut WasiCtx {
        &mut self.ctx
    }
}

/// Host-side step synchronization primitive.
/// Cannot live in WASM — these are Tokio async primitives.
pub struct StepSync {
    pub complete: Arc<Notify>,
    pub done: Arc<AtomicBool>,
}

impl StepSync {
    pub fn new() -> Self {
        Self {
            complete: Arc::new(Notify::new()),
            done: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn reset(&mut self) {
        self.complete = Arc::new(Notify::new());
        self.done = Arc::new(AtomicBool::new(false));
    }
}

/// Per-user instance with WASM isolation.
/// All user data lives in WASM linear memory as ResourceAny handles.
/// Only async coordination primitives remain on the host.
pub struct UserInstance {
    // --- WASM engine ---
    pub store: Store<UserWasiView>,
    pub bindings: ThresholdWorld,

    // --- All user data as WASM resources ---
    /// The threshold-session resource (crypto operations namespace).
    pub session: Option<ResourceAny>,
    /// Opaque round1-secret handle (lives between DKG/refresh steps).
    pub round1_secret: Option<ResourceAny>,
    /// Opaque round2-secret handle (lives between DKG/refresh steps).
    pub round2_secret: Option<ResourceAny>,
    /// Opaque signing-nonce handle (lives between sign steps).
    pub signing_nonce: Option<ResourceAny>,
    /// DKG session state (round packages, identifiers, server state, relay).
    pub dkg_session: Option<ResourceAny>,
    /// Signing session state (commitments, shares, message, policy metadata).
    pub signing_session: Option<ResourceAny>,
    /// Refresh session state (round packages, relay, policy metadata).
    pub refresh_session: Option<ResourceAny>,

    // --- Host-only async coordination (NOT user data) ---
    /// DKG step sync: (step1, step2, step3).
    pub dkg_sync: Option<(StepSync, StepSync, StepSync)>,
    /// Signing step sync: (step1, step2).
    pub signing_sync: Option<(StepSync, StepSync)>,
    /// Refresh step sync: (step1, step2, step3).
    pub refresh_sync: Option<(StepSync, StepSync, StepSync)>,

    // --- Signing mode ---
    /// If true, the current signing session uses script-path (no tweak).
    pub script_path_spend: bool,

    // --- Persistent state (stays host-side for now) ---
    pub policy_state: Option<PolicyState>,
    pub utxo_state: Option<UtxoState>,
}

/// Registry of per-user WASM instances backed by Wasmtime.
///
/// Today this is a `HashMap` behind a global `Mutex`; the migration plan replaces
/// the map with a concurrent structure and per-user actors. The public surface
/// (`new`, `get_or_create_user`, `iter_users`) stays stable across that work.
pub struct UserRegistry {
    engine: Engine,
    component: Component,
    linker: Linker<UserWasiView>,
    users: HashMap<String, UserInstance>,
}

impl UserRegistry {
    pub fn new(wasm_path: &str) -> Result<Arc<Mutex<Self>>, Box<dyn std::error::Error>> {
        let mut config = Config::new();
        config.wasm_component_model(true);
        let engine = Engine::new(&config)?;

        let component = Component::from_file(&engine, wasm_path)?;

        let mut linker = Linker::new(&engine);
        wasmtime_wasi::add_to_linker_sync(&mut linker)?;

        Ok(Arc::new(Mutex::new(Self {
            engine,
            component,
            linker,
            users: HashMap::new(),
        })))
    }

    /// Get or create a user instance. Returns a mutable reference to the UserInstance.
    pub fn get_or_create_user(
        &mut self,
        user_id: &str,
    ) -> Result<&mut UserInstance, Box<dyn std::error::Error>> {
        if !self.users.contains_key(user_id) {
            let wasi_ctx = WasiCtxBuilder::new().inherit_stdio().build();
            let view = UserWasiView {
                table: ResourceTable::new(),
                ctx: wasi_ctx,
            };
            let mut store = Store::new(&self.engine, view);

            let bindings =
                ThresholdWorld::instantiate(&mut store, &self.component, &self.linker)?;

            // Create the threshold-session resource
            let iface = bindings.component_threshold_types();
            let session = iface.threshold_session().call_constructor(&mut store)?;

            self.users.insert(
                user_id.to_string(),
                UserInstance {
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
                },
            );
            tracing::info!("Created WASM instance for user: {}", user_id);
        }
        Ok(self.users.get_mut(user_id).unwrap())
    }

    /// Iterate all users (for policy lookup by recovery_id).
    pub fn iter_users(&self) -> impl Iterator<Item = (&String, &UserInstance)> {
        self.users.iter()
    }

}
