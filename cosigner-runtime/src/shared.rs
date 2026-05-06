//! Shared services held behind `Arc` and passed to every user actor.
//! These are upstreams that fundamentally serve all users from one connection
//! (ASP gRPC, Electrum, persistence backends).

use std::sync::Arc;

use crate::bitcoin::BitcoinHistoryService;
use crate::fcm_client::FcmClient;
use crate::persistence::{KvStore, SecretStore};

pub struct SharedServices {
    pub persistence: Arc<dyn KvStore>,
    pub secret_store: Arc<dyn SecretStore>,
    pub bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
    pub asp_client: Option<Arc<tokio::sync::Mutex<ark::client::AspClient>>>,
    /// Push notifications. None when `FCM_SERVICE_ACCOUNT_CIPHERTEXT` is unset
    /// (auto-settle still works for users who open the app — pushes are the
    /// wake mechanism, not the only delegation path).
    pub fcm: Option<Arc<FcmClient>>,
    /// Auto-settle threshold: submit a stored intent when
    /// `now > earliest_expires_at - auto_settle_safety_margin_secs`.
    pub auto_settle_safety_margin_secs: i64,
}

impl SharedServices {
    pub fn new(
        persistence: Arc<dyn KvStore>,
        secret_store: Arc<dyn SecretStore>,
        bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
        asp_client: Option<ark::client::AspClient>,
        fcm: Option<Arc<FcmClient>>,
        auto_settle_safety_margin_secs: i64,
    ) -> Self {
        Self {
            persistence,
            secret_store,
            bitcoin_history,
            asp_client: asp_client.map(|c| Arc::new(tokio::sync::Mutex::new(c))),
            fcm,
            auto_settle_safety_margin_secs,
        }
    }
}
