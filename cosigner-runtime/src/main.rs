use std::sync::Arc;

use clap::Parser;

use cosigner_runtime::{
    config, contract, cosigner, esplora, fcm_client, onboarding, resp_store, rest_api, shared,
    telemetry, vtxo_stream, webauthn_server,
};

#[derive(Parser)]
#[command(
    name = "server",
    about = "MPC Wallet Server with per-user WASM crypto isolation"
)]
struct Args {
    /// REST/JSON listen port (HTTP/1.1). Defaults to PORT env var or 7074.
    #[arg(long)]
    port: Option<u16>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut telemetry_guard = telemetry::init();

    let args = Args::parse();

    let cfg = config::ServerConfig::from_environment();
    tracing::info!("Config: network={}", cfg.bitcoin_network);

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

    // Persistence: the single RESP (Redis) KV backend. In the enclave the AUTH password is the
    // runtime token; the server only checks the password (username ignored → default user).
    tracing::info!("Persistence: RESP/Redis KV backend");
    let persistence: Arc<dyn resp_store::KvStore> =
        Arc::new(resp_store::RespStore::connect(&cfg.redis_url).await?);

    // ASP connection — REQUIRED. The cosigner is an Ark wallet co-signer; it cannot serve without
    // an ASP, so a missing URL or a failed connect is a hard startup error, not a soft fallback.
    if cfg.asp_url.is_empty() {
        return Err("ASP_URL is required".into());
    }
    tracing::info!("Connecting to ASP at {}", cfg.asp_url);
    let asp_client = ark::client::AspClient::connect(&cfg.asp_url)
        .await
        .map_err(|e| format!("Failed to connect to ASP at {}: {e}", cfg.asp_url))?;
    tracing::info!("Connected to ASP");

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

    let session_authority = std::sync::Arc::new(
        cosigner_runtime::auth::session::SessionAuthority::from_secret_hex(&cfg.webauth_token_secret),
    );
    if session_authority.enabled() {
        tracing::info!("Session-token auth enabled (WEBAUTH_TOKEN_SECRET configured)");
    } else {
        // Not merely informational: a passkey-GATED wallet authenticates by
        // session token alone (its Schnorr signature is empty), so without a
        // token secret every request from a gated wallet is rejected.
        tracing::warn!(
            "Session-token auth DISABLED (no WEBAUTH_TOKEN_SECRET); Schnorr-only — \
             passkey-gated wallets cannot authenticate against this deployment"
        );
    }

    let mut shared = shared::SharedServices::new(
        persistence,
        asp_client,
        fcm,
        cfg.auto_settle_safety_margin_secs,
        cfg.actor_idle_threshold_secs,
        session_authority,
    );

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

    // WebAuthn ceremony server: the cosigner is its own Relying Party (register/assert + session
    // token mint). Disabled (None) if the RP config is invalid, rather than aborting startup.
    match webauthn_server::WebauthnServer::new(
        webauthn_server::RpConfig {
            rp_id: &cfg.webauth_rp_id,
            rp_origin: &cfg.webauth_rp_origin,
            android_origin: &cfg.webauth_android_origin,
            rp_name: &cfg.webauth_rp_name,
        },
        shared.persistence.clone(),
        shared.session_authority.clone(),
    ) {
        Ok(server) => {
            tracing::info!(
                "WebAuthn server ready (rp_id={}, origin={})",
                cfg.webauth_rp_id,
                cfg.webauth_rp_origin
            );
            shared.webauthn = Some(Arc::new(server));
        }
        Err(e) => tracing::warn!("WebAuthn server disabled: {e}"),
    }

    let shared = Arc::new(shared);

    // The cosigner runs natively in-process (no WASM guest); only the contract is sandboxed WASM.
    let registry = cosigner::CosignerRegistry::new(shared.clone())?;

    // Populate cross-user secondary indices from persistence so restore /
    // VTXO-stream lookups don't need to wake any actor.
    if let Err(e) = registry.load_indices_from_persistence() {
        tracing::warn!("Failed to load registry indices from persistence: {e}");
    }

    // Spawn the global VTXO stream task.
    {
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
    {
        let registry_clone = registry.clone();
        let persistence_clone = shared.persistence.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
            // Skip the immediate fire so existing actors have time to finish boot.
            interval.tick().await;
            loop {
                interval.tick().await;
                // spawn + tick every actor with a pending guest-delegate threshold
                // marker, so a stored delegate auto-settles even after a runtime
                // restart.
                let candidates = match persistence_clone.get_all("guest_delegate_thresholds") {
                    Ok(rows) => rows,
                    Err(e) => {
                        tracing::warn!(
                            "auto-settle tick: get_all guest_delegate_thresholds failed: {e}"
                        );
                        continue;
                    }
                };
                if candidates.is_empty() {
                    continue;
                }
                tracing::debug!(
                    "auto-settle tick: {} user(s) with stored guest-delegate marker",
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

    // Boarding watcher: every 60s, poll each user's recorded boarding address
    // via esplora and push a "tap to board" notification for new confirmed
    // deposits. The cosigner's ONLY chain dependency — read-only, opt-in via
    // ESPLORA_URL, and inert without FCM. The wallet still scans + signs.
    if !cfg.esplora_url.is_empty() {
        if let Some(fcm) = shared.fcm.clone() {
            let persistence_clone = shared.persistence.clone();
            let esplora_client = esplora::EsploraClient::new(&cfg.esplora_url);
            let interval_secs = cfg.boarding_watch_interval_secs.max(1);
            tracing::info!(
                "Boarding watcher enabled (esplora {}, every {interval_secs}s)",
                cfg.esplora_url
            );
            tokio::spawn(async move {
                let mut interval =
                    tokio::time::interval(std::time::Duration::from_secs(interval_secs));
                interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
                interval.tick().await;
                loop {
                    interval.tick().await;
                    cosigner::registry::boarding_watch_sweep(
                        &esplora_client,
                        &persistence_clone,
                        &fcm,
                    )
                    .await;
                }
            });
        } else {
            tracing::warn!("ESPLORA_URL set but FCM unconfigured; boarding watcher disabled");
        }
    }

    // every 24 hr, drop actors that haven't recv'd anything for `ACTOR_IDLE_THRESHOLD_SECS`. Runs
    // independently of ASP — purely a memory-pressure relief mechanism.
    //
    // The auto-settle tick above now only sends to users with a stored
    // delegate row in store, so it no longer keeps every spawned actor's
    // `last_active` fresh. Idle actors (no client RPCs, no stream events,
    // no stored delegate) will now eventually evict in production —
    // exactly the behaviour the sweep was designed for.
    {
        let registry_clone = registry.clone();
        let threshold = shared.actor_idle_threshold_secs;
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(60 * 60 * 24));
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

    // Onboarding coordinator: short-lived per-user ceremony sessions, evicted on
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

    // Contract-creation coordinator: refreshes V onto the service pairing INSIDE the wallet's
    // guest (Plan A — the host never reads V), so it needs the actor registry to dispatch.
    let contract_mgr = contract::ContractManager::new(shared.clone(), registry.clone());

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
