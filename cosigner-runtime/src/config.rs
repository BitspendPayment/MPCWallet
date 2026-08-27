use std::env;

/// Server configuration loaded from environment variables.
/// Mirrors the Dart `ServerConfig` from `server/lib/config.dart`.
#[derive(Debug, Clone)]
pub struct ServerConfig {
    /// Filesystem path to the SQLite database backing the single KV store, e.g.
    /// `/var/lib/cosigner/state.db`. Parent directories are created at open. `:memory:` gives an
    /// ephemeral store (tests). Env `SQLITE_PATH`.
    pub sqlite_path: String,
    /// ASP (Ark Service Provider) gRPC URL, e.g. "http://localhost:7070".
    /// When empty, Ark RPCs return UNAVAILABLE.
    pub asp_url: String,
    /// Where to push a newly dealt service half, keyed by the service's identity hex.
    ///
    /// Env `SERVICE_ENDPOINTS`, formatted `<service_id_hex>=<url>` separated by commas or
    /// whitespace. A service whose key is absent gets no push and its enrolment simply does not
    /// complete.
    ///
    /// OPERATOR-CONFIGURED ON PURPOSE. The obvious alternative — let the enrolling wallet name the
    /// URL — turns this cosigner into an SSRF gadget: an attacker enrols a throwaway service and
    /// aims the enclave's outbound HTTP at anything it can reach. Services are deployed
    /// infrastructure, so their addresses belong in deployment config, not in a request body.
    pub service_endpoints: std::collections::BTreeMap<String, String>,
    /// Bitcoin network name (e.g. "regtest", "signet", "testnet", "mainnet").
    /// Used for logging; the authoritative network comes from the ASP's GetArkInfo.
    pub bitcoin_network: String,
    /// esplora REST base URL (e.g. "http://127.0.0.1:30000"). The cosigner's ONLY
    /// chain dependency — a read-only watcher of user boarding addresses so it can
    /// nudge the device to board. Empty ⇒ the boarding watcher is disabled.
    pub esplora_url: String,
    /// Boarding-watch sweep interval (seconds). Default 60; e2e sets it low.
    pub boarding_watch_interval_secs: u64,
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
    /// 32-byte secret (hex) seeding the cosigner's OWN Ed25519 keypair, used to mint + verify the
    /// session tokens it issues after a WebAuthn assertion. Empty ⇒ session-token auth disabled
    /// (Schnorr-only). Env `WEBAUTH_TOKEN_SECRET`.
    pub webauth_token_secret: String,
    /// WebAuthn Relying Party ID (the effective domain the passkey is scoped to). Env `WEBAUTH_RP_ID`,
    /// default `"localhost"`.
    pub webauth_rp_id: String,
    /// WebAuthn RP origin URL — the https origin matching `webauth_rp_id`, e.g.
    /// `https://vtxos.com`. Env `WEBAUTH_RP_ORIGIN`, default `"http://localhost"`.
    pub webauth_rp_origin: String,
    /// Additional allowed origin for Android Credential-Manager assertions: the app's
    /// `android:apk-key-hash:<b64url-sha256-of-signing-cert>`. Empty ⇒ web/https-only. Env
    /// `WEBAUTH_ANDROID_ORIGIN`.
    pub webauth_android_origin: String,
    /// Human-readable RP name shown in the passkey UI. Env `WEBAUTH_RP_NAME`, default `"MPC Wallet"`.
    pub webauth_rp_name: String,
}

impl ServerConfig {
    /// Load configuration from environment variables.
    /// Supports Docker secrets via `_FILE` suffix pattern.
    pub fn from_environment() -> Self {
        Self {
            sqlite_path: env::var("SQLITE_PATH")
                .ok()
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| DEFAULT_SQLITE_PATH.to_string()),
            asp_url: env::var("ASP_URL").unwrap_or_default(),
            service_endpoints: parse_service_endpoints(
                &env::var("SERVICE_ENDPOINTS").unwrap_or_default(),
            ),
            bitcoin_network: env::var("BITCOIN_NETWORK").unwrap_or_else(|_| "regtest".to_string()),
            esplora_url: env::var("ESPLORA_URL").unwrap_or_default(),
            boarding_watch_interval_secs: env::var("BOARDING_WATCH_INTERVAL_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(60),
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
            webauth_token_secret: env::var("WEBAUTH_TOKEN_SECRET").unwrap_or_default(),
            webauth_rp_id: env::var("WEBAUTH_RP_ID").unwrap_or_else(|_| "localhost".to_string()),
            webauth_rp_origin: env::var("WEBAUTH_RP_ORIGIN")
                .unwrap_or_else(|_| "http://localhost".to_string()),
            webauth_android_origin: env::var("WEBAUTH_ANDROID_ORIGIN").unwrap_or_default(),
            webauth_rp_name: env::var("WEBAUTH_RP_NAME").unwrap_or_else(|_| "MPC Wallet".to_string()),
        }
    }
}

/// Where the KV database lives when `SQLITE_PATH` is unset. A relative path so a bare `cargo run`
/// works without root; deployments point this at the mounted data volume.
const DEFAULT_SQLITE_PATH: &str = "data/cosigner.db";

/// Parse `SERVICE_ENDPOINTS`: `<service_id_hex>=<url>` entries separated by commas or whitespace.
///
/// Malformed entries are dropped with a warning rather than aborting startup — a typo in one
/// service's address should not take the cosigner down for every wallet.
fn parse_service_endpoints(raw: &str) -> std::collections::BTreeMap<String, String> {
    let mut out = std::collections::BTreeMap::new();
    for entry in raw.split([',', ' ', '\t', '\n']).filter(|e| !e.is_empty()) {
        match entry.split_once('=') {
            Some((vk, url)) if !vk.is_empty() && !url.is_empty() => {
                out.insert(vk.trim().to_ascii_lowercase(), url.trim().to_string());
            }
            _ => tracing::warn!("SERVICE_ENDPOINTS: ignoring malformed entry {entry:?}"),
        }
    }
    out
}

#[cfg(test)]
mod service_endpoint_tests {
    use super::parse_service_endpoints;

    #[test]
    fn parses_comma_and_whitespace_separated_entries() {
        let m = parse_service_endpoints("AA=https://a.example, bb=https://b.example\ncc=https://c");
        assert_eq!(m.len(), 3);
        assert_eq!(m["aa"], "https://a.example", "keys normalize to lowercase hex");
        assert_eq!(m["bb"], "https://b.example");
    }

    #[test]
    fn drops_malformed_entries_without_losing_the_good_ones() {
        let m = parse_service_endpoints("good=https://x, garbage, =https://y, z=");
        assert_eq!(m.len(), 1);
        assert!(m.contains_key("good"));
    }

    #[test]
    fn an_unset_variable_is_simply_no_services() {
        assert!(parse_service_endpoints("").is_empty());
    }
}
