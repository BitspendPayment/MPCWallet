use std::sync::Arc;

use clap::Parser;

use cosigner_runtime::{
    bitcoin, config, contract, cosigner, fcm_client, onboarding, persistence, rest_api, shared,
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

    // Refuse to boot with an empty `bitcoin_network`. The client uses this
    // string verbatim as the HRP source for rendering wallet addresses; an
    // empty value would silently fall through to a wrong-network default
    // on the client side. ServerConfig::from_environment already defaults
    // to "regtest" on a missing var, so this check only fires when the
    // operator explicitly set BITCOIN_NETWORK="" (a configuration mistake).
    const VALID_NETWORKS: [&str; 5] = ["mainnet", "testnet", "signet", "mutinynet", "regtest"];
    if !VALID_NETWORKS.contains(&cfg.bitcoin_network.as_str()) {
        return Err(format!(
            "Invalid BITCOIN_NETWORK={:?}; expected one of {:?}",
            cfg.bitcoin_network, VALID_NETWORKS
        )
        .into());
    }

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
        let base_url_override = if cfg.fcm_base_url.is_empty() {
            None
        } else {
            Some(cfg.fcm_base_url.clone())
        };
        match fcm_client::FcmClient::from_service_account_json(
            &cfg.fcm_service_account_json,
            base_url_override,
        ) {
            Ok(client) => {
                if !cfg.fcm_base_url.is_empty() {
                    tracing::warn!(
                        "FCM_BASE_URL override active: {} — push traffic NOT going to real Firebase",
                        cfg.fcm_base_url
                    );
                }
                tracing::info!("FCM client initialized");
                Some(Arc::new(client))
            }
            Err(e) => {
                tracing::error!("FCM init failed: {e}; push notifications disabled");
                None
            }
        }
    };

    let service_url = if cfg.service_url.is_empty() {
        None
    } else {
        tracing::info!("Contract-signer service at {}", cfg.service_url);
        Some(cfg.service_url.clone())
    };
    let mut shared = shared::SharedServices::new(
        persistence,
        secret_store,
        bitcoin_history,
        asp_client,
        service_url,
        fcm,
        cfg.auto_settle_safety_margin_secs,
        cfg.actor_idle_threshold_secs,
    );
    if !cfg.asp_url.is_empty() {
        shared.asp_url = Some(cfg.asp_url.clone());
    }

    // Contracts are stored in the cosigner's own KV at eVTXO creation; the gate
    // resolves them from there. Gating is a no-op if the engine fails to init.
    let contract_registry: Box<dyn contract::ContractRegistry> =
        Box::new(contract::KvRegistry::new(shared.persistence.clone()));
    match contract::ContractHost::new(contract_registry) {
        Ok(host) => {
            tracing::info!("Contract engine ready");
            shared.contract_host = Some(Arc::new(host));
        }
        Err(e) => tracing::warn!("Contract engine disabled: {e}"),
    }

    let shared = Arc::new(shared);

    // The cosigner-guest WASM component (the only one): CLI > env > config default.
    let guest_wasm = args.wasm.unwrap_or(cfg.cosigner_guest_wasm_path.clone());
    tracing::info!("Loading cosigner-guest WASM component from: {}", guest_wasm);
    let registry = cosigner::CosignerRegistry::new(&guest_wasm, shared.clone())?;

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

    // Auto-settle tick: every 60s, find users with a stored delegate
    // intent in sled and send TickAutoSettle to their actor (cold-spawning
    // if needed).
    //
    // Sled is the source of truth for "this user has a stored intent the
    // cosigner needs to drive." Iterating the in-memory DashMap would miss
    // users whose actor isn't spawned — which is exactly the post-restart
    // case Phase 2 of the persistence work was meant to fix. Iterating
    // sled lets the tick fire for any user with a delegate row regardless
    // of whether they've made a request since the last cosigner-runtime
    // boot.
    //
    // Cost: `get_or_spawn` for a cold user instantiates a new WASM Store.
    // We only pay this for users with a delegate row — which is exactly
    // the set that has work to do. Auto-settle either succeeds (sled row
    // and in-memory record both clear, the actor settles back into idle
    // and eventually evicts) or fails (same outcome — client re-delegates
    // on next refresh).
    if shared.asp_client.is_some() {
        let registry_clone = registry.clone();
        let persistence_clone = shared.persistence.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
            // Skip the immediate fire so existing actors have time to finish boot.
            interval.tick().await;
            loop {
                interval.tick().await;
                let candidates = match persistence_clone.get_all("delegate_sessions") {
                    Ok(rows) => rows,
                    Err(e) => {
                        tracing::warn!("auto-settle tick: get_all delegate_sessions failed: {e}");
                        continue;
                    }
                };
                if candidates.is_empty() {
                    continue;
                }
                tracing::debug!(
                    "auto-settle tick: {} user(s) with stored delegate",
                    candidates.len()
                );
                for (user_id, _value) in candidates {
                    let handle = match registry_clone.get_or_spawn(&user_id) {
                        Ok(h) => h,
                        Err(e) => {
                            tracing::debug!("auto-settle tick: spawn {user_id} failed: {e}");
                            continue;
                        }
                    };
                    if let Err(e) = handle.try_send(cosigner::CosignerCommand::TickAutoSettle) {
                        tracing::debug!("auto-settle tick: skip {user_id}: {e}");
                    }
                }
            }
        });
    }

    // Idle-eviction sweep (issue #30 gap 3): every 60s, drop actors that
    // haven't recv'd anything for `ACTOR_IDLE_THRESHOLD_SECS`. Runs
    // independently of ASP — purely a memory-pressure relief mechanism.
    //
    // The auto-settle tick above now only sends to users with a stored
    // delegate row in sled, so it no longer keeps every spawned actor's
    // `last_active` fresh. Idle actors (no client RPCs, no stream events,
    // no stored delegate) will now eventually evict in production —
    // exactly the behaviour the sweep was designed for.
    {
        let registry_clone = registry.clone();
        let threshold = shared.actor_idle_threshold_secs;
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
            interval.tick().await; // skip immediate fire
            loop {
                interval.tick().await;
                let snapshot = registry_clone.snapshot_handles();
                for (user_id, _handle) in snapshot {
                    registry_clone.try_evict(&user_id, threshold);
                }
            }
        });
    }

    // DKG coordinator: short-lived per-user ceremony sessions, evicted on
    // TTL. Spawned independently of the per-user registry — the post-DKG
    // actor is lazy-spawned by the first sign/ark/refresh/policy call.
    let dkg_ttl = std::time::Duration::from_secs(cfg.dkg_session_ttl_secs);
    let onboarding_mgr =
        onboarding::OnboardingManager::with_registry(shared.clone(), registry.clone(), dkg_ttl);
    {
        let coord = onboarding_mgr.clone();
        tokio::spawn(async move {
            coord.run_eviction_loop().await;
        });
    }

    // Contract-creation coordinator (stateless: a single refresh of V onto the service pairing).
    let contract_mgr = contract::ContractManager::new(shared.clone());

    // REST server.
    let rest_port = args.port.unwrap_or_else(|| {
        std::env::var("PORT")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(7074)
    });
    let app_state = rest_api::AppState {
        registry: registry.clone(),
        onboarding_manager: onboarding_mgr.clone(),
        contract_manager: contract_mgr.clone(),
        server_info: std::sync::Arc::new(cosigner_runtime::wallet_proto::GetServerInfoResponse {
            bitcoin_network: cfg.bitcoin_network.clone(),
        }),
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
