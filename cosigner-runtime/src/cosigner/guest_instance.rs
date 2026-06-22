//! Host-side driver for the native-async `cosigner-guest` component.
//!
//! The guest exports an async `handle(request) -> response`; the host calls it per
//! command and the instance's state persists across calls. The guest imports
//! `contract-gate` (async), which the host services in its isolated contract sandbox.
//! Request/response bodies are serialized cosigner-proto `GuestCommand`/`GuestResponse`.
//!
//! This replaces the WASI-0.2 stdio+framing `StreamGuest` (Phase T3).

use std::sync::Arc;

use anyhow::Result;
use http_body_util::BodyExt;
use hyper_util::rt::{TokioExecutor, TokioIo};
use wasmtime::component::{Component, Linker};
use wasmtime::{Config, Engine, Store};
use wasmtime_wasi::{ResourceTable, WasiCtx, WasiCtxBuilder, WasiCtxView, WasiView};
use wasmtime_wasi_http::p2::bindings::http::types::ErrorCode;
use wasmtime_wasi_http::p2::body::HyperOutgoingBody;
use wasmtime_wasi_http::p2::types::{
    HostFutureIncomingResponse, IncomingResponse, OutgoingRequestConfig,
};
use wasmtime_wasi_http::p2::{HttpResult, WasiHttpCtxView, WasiHttpHooks, WasiHttpView};
use wasmtime_wasi_http::WasiHttpCtx;

use cosigner_proto::{GuestCommand, GuestResponse};

use crate::shared::SharedServices;

wasmtime::component::bindgen!({
    path: "../cosigner/wit",
    world: "cosigner-guest",
    imports: { default: async },
    exports: { default: async },
});

/// Store data for a guest instance: WASI (the async ABI rides on wasi:io) + the shared
/// services the `contract-gate` import forwards to. `shared = None` ⇒ the gate allows
/// (used in tests / non-contract contexts).
pub struct GuestInstanceCtx {
    table: ResourceTable,
    wasi: WasiCtx,
    http: WasiHttpCtx,
    hooks: ArkH2Hooks,
    shared: Option<Arc<SharedServices>>,
}

impl WasiView for GuestInstanceCtx {
    fn ctx(&mut self) -> WasiCtxView<'_> {
        WasiCtxView {
            ctx: &mut self.wasi,
            table: &mut self.table,
        }
    }
}

impl WasiHttpView for GuestInstanceCtx {
    fn http(&mut self) -> WasiHttpCtxView<'_> {
        WasiHttpCtxView {
            ctx: &mut self.http,
            table: &mut self.table,
            hooks: &mut self.hooks,
        }
    }
}

/// Custom `wasi:http` outgoing hook: the guest composes gRPC requests and the host sends
/// them over **HTTP/2** (the stock wasi-http handler is HTTP/1.1-only; gRPC needs h2).
/// The host does the actual transport — keys never leave the guest.
struct ArkH2Hooks;

impl WasiHttpHooks for ArkH2Hooks {
    fn send_request(
        &mut self,
        request: hyper::Request<HyperOutgoingBody>,
        config: OutgoingRequestConfig,
    ) -> HttpResult<HostFutureIncomingResponse> {
        let handle = wasmtime_wasi::runtime::spawn(async move {
            Ok::<_, wasmtime::Error>(h2_send(request, config).await)
        });
        Ok(HostFutureIncomingResponse::pending(handle))
    }
}

/// Outbound HTTP/2 send (cleartext h2c for now; a TLS branch mirroring the stock
/// `default_send_request_handler` is added when wiring real arkd over https).
async fn h2_send(
    mut request: hyper::Request<HyperOutgoingBody>,
    config: OutgoingRequestConfig,
) -> std::result::Result<IncomingResponse, ErrorCode> {
    let authority = request
        .uri()
        .authority()
        .map(|a| {
            if a.port().is_some() {
                a.to_string()
            } else {
                format!("{a}:80")
            }
        })
        .ok_or(ErrorCode::HttpRequestUriInvalid)?;

    let tcp = tokio::net::TcpStream::connect(&authority)
        .await
        .map_err(|_| ErrorCode::ConnectionRefused)?;
    let (mut sender, conn) =
        hyper::client::conn::http2::handshake(TokioExecutor::new(), TokioIo::new(tcp))
            .await
            .map_err(|_| ErrorCode::HttpProtocolError)?;
    let worker = wasmtime_wasi::runtime::spawn(async move {
        let _ = conn.await;
    });

    // On the wire, an h2 request carries only path+query (scheme/authority are pseudo-headers).
    *request.uri_mut() = http::Uri::builder()
        .path_and_query(
            request
                .uri()
                .path_and_query()
                .map(|p| p.as_str())
                .unwrap_or("/"),
        )
        .build()
        .expect("valid path");

    let resp = sender
        .send_request(request)
        .await
        .map_err(|_| ErrorCode::HttpProtocolError)?
        .map(|body| body.map_err(|_| ErrorCode::HttpProtocolError).boxed_unsync());

    Ok(IncomingResponse {
        resp,
        worker: Some(worker),
        between_bytes_timeout: config.between_bytes_timeout,
    })
}

// Host implementation of the `contract-gate` capability the guest imports. The guest
// passes the full transaction it holds; the host evaluates the bound contract in its
// isolated sandbox and returns allow/deny.
impl cosigner::guest::contract_gate::Host for GuestInstanceCtx {
    async fn enforce(&mut self, full_tx: Vec<u8>) -> Result<(), String> {
        match &self.shared {
            Some(shared) => {
                crate::cosigner::handlers::contract_gate::enforce_contracts(shared, &full_tx)
                    .map_err(|s| s.message().to_string())
            }
            None => Ok(()),
        }
    }
}

/// Build an async component-model engine for the guest.
pub fn build_engine() -> Result<Engine> {
    let mut config = Config::new();
    config.wasm_component_model(true);
    config.wasm_component_model_async(true);
    Ok(Engine::new(&config)?)
}

/// Build the linker: WASI (async) + the `contract-gate` host import.
pub fn build_linker(engine: &Engine) -> Result<Linker<GuestInstanceCtx>> {
    let mut linker = Linker::new(engine);
    wasmtime_wasi::p2::add_to_linker_async(&mut linker)?;
    // Only the wasi:http interfaces (wasi already added wasi:io/etc.) + our custom h2
    // outgoing hook (wired via the Ctx's WasiHttpView::http().hooks).
    wasmtime_wasi_http::p2::add_only_http_to_linker_async(&mut linker)?;
    cosigner::guest::contract_gate::add_to_linker::<
        GuestInstanceCtx,
        wasmtime::component::HasSelf<GuestInstanceCtx>,
    >(&mut linker, |c: &mut GuestInstanceCtx| c)?;
    Ok(linker)
}

/// A live, stateful guest instance. One per user/actor; its in-WASM state persists
/// across `command` calls.
pub struct GuestInstance {
    store: Store<GuestInstanceCtx>,
    bindings: CosignerGuest,
}

impl GuestInstance {
    /// Instantiate the guest. Must run within a tokio runtime (instantiation is async).
    pub async fn spawn(
        engine: &Engine,
        component: &Component,
        linker: &Linker<GuestInstanceCtx>,
        shared: Option<Arc<SharedServices>>,
    ) -> Result<Self> {
        let wasi = WasiCtxBuilder::new().inherit_stderr().build();
        let ctx = GuestInstanceCtx {
            table: ResourceTable::new(),
            wasi,
            http: WasiHttpCtx::new(),
            hooks: ArkH2Hooks,
            shared,
        };
        let mut store = Store::new(engine, ctx);
        let bindings = CosignerGuest::instantiate_async(&mut store, component, linker).await?;
        Ok(Self { store, bindings })
    }

    /// Send one command and await its response.
    pub async fn command(&mut self, cmd: GuestCommand) -> Result<GuestResponse> {
        let request = serde_json::to_vec(&cmd)?;
        let response = self.bindings.call_handle(&mut self.store, &request).await?;
        Ok(serde_json::from_slice(&response)?)
    }
}
