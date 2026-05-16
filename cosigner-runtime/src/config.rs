use std::env;

/// Server configuration loaded from environment variables.
/// Mirrors the Dart `ServerConfig` from `server/lib/config.dart`.
#[derive(Debug, Clone)]
pub struct ServerConfig {
    pub electrum_url: String,
    pub electrum_port: u16,
    pub data_dir: String,
    /// ASP (Ark Service Provider) gRPC URL, e.g. "http://localhost:7070".
    /// When empty, Ark RPCs return UNAVAILABLE.
    pub asp_url: String,
    /// Bitcoin network name (e.g. "regtest", "signet", "testnet", "mainnet").
    /// Used for logging; the authoritative network comes from the ASP's GetArkInfo.
    pub bitcoin_network: String,
    /// Persistence backend: "sled" (local) or "enclave" (HTTP KV store).
    pub persistence_backend: String,
    /// Enclave supervisor base URL (only used when persistence_backend = "enclave").
    pub supervisor_url: String,
    /// Enclave management token for supervisor API auth.
    pub enclave_mgmt_token: String,
    /// Path to the cosigner WASM component file.
    pub cosigner_wasm_path: String,
    /// Auto-settle threshold: submit a stored delegate intent when
    /// `now > earliest_expires_at - this`. Default 30 minutes.
    pub auto_settle_safety_margin_secs: i64,
    /// Decrypted FCM service-account JSON. Empty = push disabled.
    /// In production this is filled by the enclave KMS-decrypt step before
    /// the runtime starts; in dev set `FCM_SERVICE_ACCOUNT_JSON` directly.
    pub fcm_service_account_json: String,
    /// TTL for in-flight DKG ceremony sessions. After this many seconds of
    /// inactivity the session is evicted and any waiting participants get a
    /// "restart from step1" error. Default 300 (5 minutes).
    pub dkg_session_ttl_secs: u64,
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
            data_dir: env::var("DATA_DIR").unwrap_or_else(|_| {
                let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
                format!("{}/.mpc_wallet/server", home)
            }),
            asp_url: env::var("ASP_URL").unwrap_or_default(),
            bitcoin_network: env::var("BITCOIN_NETWORK")
                .unwrap_or_else(|_| "regtest".to_string()),
            persistence_backend: env::var("PERSISTENCE_BACKEND")
                .unwrap_or_else(|_| "sled".to_string()),
            supervisor_url: env::var("SUPERVISOR_URL")
                .unwrap_or_else(|_| "http://127.0.0.1:7073".to_string()),
            enclave_mgmt_token: env::var("ENCLAVE_RUNTIME_TOKEN").unwrap_or_default(),
            cosigner_wasm_path: env::var("COSIGNER_WASM_PATH")
                .unwrap_or_else(|_| "../cosigner/target/wasm32-wasip1/release/cosigner.wasm".to_string()),
            auto_settle_safety_margin_secs: env::var("AUTO_SETTLE_SAFETY_MARGIN_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(1800),
            fcm_service_account_json: env::var("FCM_SERVICE_ACCOUNT_JSON")
                .unwrap_or_default(),
            dkg_session_ttl_secs: env::var("DKG_SESSION_TTL_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(300),
        }
    }
}
