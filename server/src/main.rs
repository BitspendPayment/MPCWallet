use std::sync::Arc;

use clap::Parser;

use server::{bitcoin, config, cosigner, persistence, rest_api, shared, telemetry, vtxo_stream};

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
        "Config: bitcoin_rpc={}, electrum={}:{}, network={}",
        cfg.bitcoin_rpc_url,
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
    let bitcoin_rpc = Arc::new(bitcoin::BitcoinRpcClient::new(
        &cfg.bitcoin_rpc_url,
        &cfg.bitcoin_rpc_user,
        &cfg.bitcoin_rpc_password,
    ));

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

    let shared = Arc::new(shared::SharedServices::new(
        persistence,
        secret_store,
        bitcoin_rpc,
        bitcoin_history,
        asp_client,
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

    // REST server.
    let rest_port = args.port.unwrap_or_else(|| {
        std::env::var("PORT")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(7074)
    });
    let rest_app = axum::Router::new()
        .nest("/api", rest_api::routes(registry.clone()))
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
