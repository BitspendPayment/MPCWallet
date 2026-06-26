//! Shared services held behind `Arc` and passed to every user actor.
//! These are upstreams that fundamentally serve all users from one connection
//! (ASP gRPC, Electrum, persistence backends).

use std::sync::Arc;

use crate::bitcoin::BitcoinHistoryService;
use crate::contract::ContractHost;
use crate::fcm_client::FcmClient;
use crate::resp_store::KvStore;

pub struct SharedServices {
    pub persistence: Arc<dyn KvStore>,
    /// Off-chain contract engine for eVTXO programmability. `None` disables
    /// contract gating (no contracts directory / engine init failed).
    pub contract_host: Option<Arc<ContractHost>>,
    pub bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
    pub asp_client: Option<Arc<tokio::sync::Mutex<ark::client::AspClient>>>,
    /// ASP gRPC endpoint URL (e.g. "http://localhost:7070"). Threaded to the WASM guest so
    /// it can speak gRPC to arkd itself over the host's HTTP/2 hook. `None`/empty disables
    /// guest-routed Ark flows. Set post-construction in `main` (see `contract_host`).
    pub asp_url: Option<String>,
    /// Contract-signer service base URL (the always-online service holding the
    /// service-side share of contract keys). `None`/empty disables contract creation.
    pub service_url: Option<String>,
    /// Push notifications. None when `FCM_SERVICE_ACCOUNT_CIPHERTEXT` is unset
    /// (auto-settle still works for users who open the app — pushes are the
    /// wake mechanism, not the only delegation path).
    pub fcm: Option<Arc<FcmClient>>,
    /// Auto-settle threshold: submit a stored intent when
    /// `now > earliest_expires_at - auto_settle_safety_margin_secs`.
    pub auto_settle_safety_margin_secs: i64,
    /// Per-user actor idle threshold (seconds). Read by the eviction sweep
    /// in the auto-settle tick task.
    pub actor_idle_threshold_secs: i64,
}

impl SharedServices {
    pub fn new(
        persistence: Arc<dyn KvStore>,
        bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
        asp_client: Option<ark::client::AspClient>,
        service_url: Option<String>,
        fcm: Option<Arc<FcmClient>>,
        auto_settle_safety_margin_secs: i64,
        actor_idle_threshold_secs: i64,
    ) -> Self {
        Self {
            persistence,
            contract_host: None,
            bitcoin_history,
            asp_client: asp_client.map(|c| Arc::new(tokio::sync::Mutex::new(c))),
            asp_url: None,
            service_url,
            fcm,
            auto_settle_safety_margin_secs,
            actor_idle_threshold_secs,
        }
    }
}
