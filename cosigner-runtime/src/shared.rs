//! Shared services held behind `Arc` and passed to every user actor.
//! These are upstreams that fundamentally serve all users from one connection
//! (ASP gRPC, Bitcoin RPC, Electrum, persistence backends).

use std::sync::Arc;

use crate::bitcoin::{BitcoinHistoryService, BitcoinRpcClient};
use crate::persistence::{KvStore, SecretStore};

pub struct SharedServices {
    pub persistence: Arc<dyn KvStore>,
    pub secret_store: Arc<dyn SecretStore>,
    pub bitcoin_rpc: Arc<BitcoinRpcClient>,
    pub bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
    pub asp_client: Option<Arc<tokio::sync::Mutex<ark::client::AspClient>>>,
}

impl SharedServices {
    pub fn new(
        persistence: Arc<dyn KvStore>,
        secret_store: Arc<dyn SecretStore>,
        bitcoin_rpc: Arc<BitcoinRpcClient>,
        bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
        asp_client: Option<ark::client::AspClient>,
    ) -> Self {
        Self {
            persistence,
            secret_store,
            bitcoin_rpc,
            bitcoin_history,
            asp_client: asp_client.map(|c| Arc::new(tokio::sync::Mutex::new(c))),
        }
    }
}
