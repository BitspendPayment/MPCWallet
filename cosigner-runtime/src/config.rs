use std::env;

/// Server configuration loaded from environment variables.
/// Mirrors the Dart `ServerConfig` from `server/lib/config.dart`.
#[derive(Debug, Clone)]
pub struct ServerConfig {
    pub electrum_url: String,
    pub electrum_port: u16,
    /// RESP (Redis) connection URL for the single KV backend, e.g.
    /// `redis://:<password>@host:6379` (`rediss://…` for TLS). The server only checks the password
    /// (username ignored → `default` user). In the enclave the password is the runtime token.
    pub redis_url: String,
    /// ASP (Ark Service Provider) gRPC URL, e.g. "http://localhost:7070".
    /// When empty, Ark RPCs return UNAVAILABLE.
    pub asp_url: String,
    /// Contract-signer SERVICE base URL, e.g. "http://localhost:7080". The
    /// always-online signer that holds the service-side share of every contract
    /// key V′. When empty, contract creation returns UNAVAILABLE.
    pub service_url: String,
    /// Bitcoin network name (e.g. "regtest", "signet", "testnet", "mainnet").
    /// Used for logging; the authoritative network comes from the ASP's GetArkInfo.
    pub bitcoin_network: String,
    /// Auto-settle threshold: submit a stored delegate intent when
    /// `now > earliest_expires_at - this`. Default 30 minutes.
    pub auto_settle_safety_margin_secs: i64,
    /// Decrypted FCM service-account JSON. Empty = push disabled.
    /// In production this is filled by the enclave KMS-decrypt step before
    /// the runtime starts; in dev set `FCM_SERVICE_ACCOUNT_JSON` directly.
    pub fcm_service_account_json: String,
    /// Override the FCM base URL (default `https://fcm.googleapis.com`).
    /// Set in e2e tests to point at a local mock server. The OAuth token
    /// endpoint is overridden separately via the `token_uri` field of the
    /// service-account JSON itself.
    pub fcm_base_url: String,
    /// TTL for in-flight DKG ceremony sessions. After this many seconds of
    /// inactivity the session is evicted and any waiting participants get a
    /// "restart from step1" error. Default 300 (5 minutes).
    pub dkg_session_ttl_secs: u64,
    /// Per-user actor idle threshold. Actors with no `recv()` activity for
    /// this many seconds are evicted from the registry. Default 1800
    /// (30 min). With the auto-settle tick task firing every 60s and
    /// counting as activity, ASP-connected deployments effectively never
    /// idle out; the knob exists primarily for ASP-down deployments and
    /// for tests that exercise the eviction path.
    pub actor_idle_threshold_secs: i64,
}

impl ServerConfig {
    /// Load configuration from environment variables.
    /// Supports Docker secrets via `_FILE` suffix pattern.
    pub fn from_environment() -> Self {
        Self {
            electrum_url: env::var("ELECTRUM_URL").unwrap_or_else(|_| "127.0.0.1".to_string()),
            electrum_port: env::var("ELECTRUM_PORT")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(50001),
            redis_url: redis_url_from_env(),
            asp_url: env::var("ASP_URL").unwrap_or_default(),
            service_url: env::var("SERVICE_URL").unwrap_or_default(),
            bitcoin_network: env::var("BITCOIN_NETWORK").unwrap_or_else(|_| "regtest".to_string()),
            auto_settle_safety_margin_secs: env::var("AUTO_SETTLE_SAFETY_MARGIN_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(1800),
            fcm_service_account_json: env::var("FCM_SERVICE_ACCOUNT_JSON").unwrap_or_default(),
            fcm_base_url: env::var("FCM_BASE_URL").unwrap_or_default(),
            dkg_session_ttl_secs: env::var("DKG_SESSION_TTL_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(300),
            actor_idle_threshold_secs: env::var("ACTOR_IDLE_THRESHOLD_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(1800),
        }
    }
}

/// Build the RESP (Redis) URL. `REDIS_URL` wins; otherwise compose
/// `redis[s]://:<password>@<host>:<port>` (default user — the server only checks the password) with
/// the password being `REDIS_PASSWORD`, else the enclave's `ENCLAVE_RUNTIME_TOKEN`. The password is
/// hex (enclave token) or test-controlled, so it needs no URL-encoding.
fn redis_url_from_env() -> String {
    if let Ok(url) = env::var("REDIS_URL") {
        if !url.is_empty() {
            return url;
        }
    }
    let host = env::var("REDIS_HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let port = env::var("REDIS_PORT").unwrap_or_else(|_| "6379".to_string());
    let scheme = if matches!(env::var("REDIS_TLS").as_deref(), Ok("1") | Ok("true")) {
        "rediss"
    } else {
        "redis"
    };
    let password = env::var("REDIS_PASSWORD")
        .ok()
        .filter(|s| !s.is_empty())
        .or_else(|| env::var("ENCLAVE_RUNTIME_TOKEN").ok().filter(|s| !s.is_empty()));
    match password {
        Some(pw) => format!("{scheme}://:{pw}@{host}:{port}"),
        None => format!("{scheme}://{host}:{port}"),
    }
}
