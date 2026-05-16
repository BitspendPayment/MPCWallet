use std::sync::Arc;

use clap::Parser;

use cosigner_runtime::{
    bitcoin, config, cosigner, dkg_coordinator, fcm_client, persistence, rest_api, shared,
    telemetry, vtxo_stream,
};

#[derive(Parser)]
#[command(
    name = "server",
    about = "MPC Wallet Server with per-user WASM crypto isolation"
)]
struct Args {
    /// Path to the cosigner WASM component.
    /// Falls back to COSIGNER_WASM_PATH env var, then the local build path.
    #[arg(long)]
    wasm: Option<String>,

    /// REST/JSON listen port (HTTP/1.1). Defaults to PORT env var or 7074.
    #[arg(long)]
    port: Option<u16>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut telemetry_guard = telemetry::init();

    let args = Args::parse();

    let cfg = config::ServerConfig::from_environment();
    tracing::info!(
        "Config: electrum={}:{}, network={}",
        cfg.electrum_url,
        cfg.electrum_port,
        cfg.bitcoin_network
    );

    // Persistence backend.
    let (persistence, secret_store): (
        Arc<dyn persistence::KvStore>,
        Arc<dyn persistence::SecretStore>,
    ) = match cfg.persistence_backend.as_str() {
        #[cfg(feature = "enclave-backend")]
        "enclave" => {
            tracing::info!("Persistence: enclave supervisor at {}", cfg.supervisor_url);
            let store = Arc::new(persistence::EnclaveStore::new(
                cfg.supervisor_url.clone(),
                cfg.enclave_mgmt_token.clone(),
            ));
            (store.clone(), store)
        }
        #[cfg(feature = "sled-backend")]
        _ => {
            let data_dir = std::path::Path::new(&cfg.data_dir);
            std::fs::create_dir_all(data_dir)?;
            tracing::info!("Persistence: Sled at {}", cfg.data_dir);
            let store = Arc::new(persistence::SledStore::open(data_dir)?);
            (store.clone(), store)
        }
        #[cfg(not(feature = "sled-backend"))]
        other => {
            panic!("Unknown persistence backend: {other}");
        }
    };

    // Bitcoin services.
    let electrum_client = bitcoin::ElectrumClient::new(&cfg.electrum_url, cfg.electrum_port);
    let bitcoin_history = Arc::new(tokio::sync::Mutex::new(
        bitcoin::BitcoinHistoryService::new(electrum_client),
    ));

    // Initialize Electrum connection in background.
    let bh = bitcoin_history.clone();
    tokio::spawn(async move {
        let service = bh.lock().await;
        if let Err(e) = service.init().await {
            tracing::error!("Failed to initialize Electrum: {e}");
        }
    });

    // Optional ASP connection.
    let asp_client = if !cfg.asp_url.is_empty() {
        tracing::info!("Connecting to ASP at {}", cfg.asp_url);
        match ark::client::AspClient::connect(&cfg.asp_url).await {
            Ok(client) => {
                tracing::info!("Connected to ASP");
                Some(client)
            }
            Err(e) => {
                tracing::warn!("Failed to connect to ASP: {e} (Ark RPCs will be unavailable)");
                None
            }
        }
    } else {
        tracing::info!("ASP_URL not set, Ark RPCs disabled");
        None
    };

    // FCM push client (optional; auto-settle still works without it).
    let fcm = if cfg.fcm_service_account_json.trim().is_empty() {
        tracing::warn!(
            "FCM_SERVICE_ACCOUNT_JSON not set; push notifications disabled — \
             auto-settle will only fire for users who open the app"
        );
        None
    } else {
        match fcm_client::FcmClient::from_service_account_json(&cfg.fcm_service_account_json) {
            Ok(client) => {
                tracing::info!("FCM client initialized");
                Some(Arc::new(client))
            }
            Err(e) => {
                tracing::error!("FCM init failed: {e}; push notifications disabled");
                None
            }
        }
    };

    let shared = Arc::new(shared::SharedServices::new(
        persistence,
        secret_store,
        bitcoin_history,
        asp_client,
        fcm,
        cfg.auto_settle_safety_margin_secs,
    ));

    // WASM source: CLI > env > config default.
    let wasm_source = args.wasm.unwrap_or(cfg.cosigner_wasm_path.clone());
    tracing::info!("Loading WASM component from: {}", wasm_source);
    let registry = cosigner::CosignerRegistry::new(&wasm_source, shared.clone())?;

    // Populate cross-user secondary indices from persistence so restore /
    // VTXO-stream lookups don't need to wake any actor.
    if let Err(e) = registry.load_indices_from_persistence() {
        tracing::warn!("Failed to load registry indices from persistence: {e}");
    }

    // Spawn the global VTXO stream task if ASP is configured.
    if shared.asp_client.is_some() {
        let registry_clone = registry.clone();
        let shared_clone = shared.clone();
        tokio::spawn(async move {
            vtxo_stream::run_vtxo_stream(registry_clone, shared_clone).await;
        });
    }

    // Auto-settle tick: every 60 seconds, fan TickAutoSettle out to all
    // spawned actors. Only meaningful when ASP is configured.
    //
    // TODO: under lazy actor spawn, users without a live actor are skipped
    // here. `delegate_session` is in-memory only today, so behaviour matches
    // the pre-restart status quo. When `DelegateRecord` is persisted to sled,
    // switch this loop to iterate sled and `get_or_spawn` per user.
    if shared.asp_client.is_some() {
        let registry_clone = registry.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
            interval.set_missed_tick_behavior(
                tokio::time::MissedTickBehavior::Delay,
            );
            // Skip the immediate fire so existing actors have time to finish boot.
            interval.tick().await;
            loop {
                interval.tick().await;
                for (user_id, handle) in registry_clone.snapshot_handles() {
                    if let Err(e) = handle.try_send(cosigner::CosignerCommand::TickAutoSettle) {
                        tracing::debug!("auto-settle tick: skip {user_id}: {e}");
                    }
                }
            }
        });
    }

    // DKG coordinator: short-lived per-user ceremony sessions, evicted on
    // TTL. Spawned independently of the per-user registry — the post-DKG
    // actor is lazy-spawned by the first sign/ark/refresh/policy call.
    let dkg_ttl = std::time::Duration::from_secs(cfg.dkg_session_ttl_secs);
    let dkg_coord = dkg_coordinator::DkgCoordinator::new(shared.clone(), dkg_ttl);
    {
        let coord = dkg_coord.clone();
        tokio::spawn(async move {
            coord.run_eviction_loop().await;
        });
    }

    // REST server.
    let rest_port = args.port.unwrap_or_else(|| {
        std::env::var("PORT")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(7074)
    });
    let app_state = rest_api::AppState {
        registry: registry.clone(),
        dkg_coordinator: dkg_coord.clone(),
        server_info: std::sync::Arc::new(
            cosigner_runtime::wallet_proto::GetServerInfoResponse {
                bitcoin_network: cfg.bitcoin_network.clone(),
            },
        ),
    };
    let rest_app = axum::Router::new()
        .nest("/api", rest_api::routes(app_state))
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .layer(tower_http::cors::CorsLayer::permissive());
    let rest_addr = format!("0.0.0.0:{rest_port}");
    tracing::info!("MPC Wallet Server listening on {rest_addr} (REST/HTTP1.1)");
    let listener = tokio::net::TcpListener::bind(&rest_addr).await?;
    let serve_result = axum::serve(listener, rest_app)
        .with_graceful_shutdown(shutdown_signal())
        .await;

    telemetry_guard.shutdown();
    serve_result?;
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };
    #[cfg(unix)]
    let terminate = async {
        if let Ok(mut s) = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        {
            s.recv().await;
        }
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
    tracing::info!("Shutdown signal received, flushing telemetry...");
}
