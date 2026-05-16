use wasmtime::component::ResourceAny;
use wasmtime::Store;
use wasmtime_wasi::{ResourceTable, WasiCtx, WasiView};

use crate::policy::{PolicyState, UtxoState};

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
