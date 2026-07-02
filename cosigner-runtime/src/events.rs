//! Per-user event bus (Phase 3).
//!
//! A cosigner-side pub/sub so a user can SUBSCRIBE to events about itself and react in real time —
//! chiefly *"a contract share just landed in your inbox"*. One published event fans out to whatever
//! delivery channels are attached: an SSE HTTP stream (for a BACKEND user that holds a connection
//! open — e.g. a "service" running server-side) and, separately, an FCM push (for a mobile app).
//!
//! Semantics: a LIVE, best-effort nudge — NOT a durable queue. The durable source of truth stays the
//! inbox (`pending_contract_shares`). A subscriber that connects late, lags, or reconnects simply
//! drains `evtxo/pending` to catch up, then listens.

use std::collections::HashMap;
use std::sync::Mutex;

use serde_json::json;
use tokio::sync::broadcast;

/// An event the cosigner emits about a particular user (keyed by the user's verifying key hex).
#[derive(Debug, Clone)]
pub enum CosignerEvent {
    /// A contract share was relayed into this user's inbox (someone created a contract WITH it).
    ContractShare {
        spk_hex: String,
        contract_id_hex: String,
    },
}

impl CosignerEvent {
    /// SSE event name (the `event:` line).
    pub fn kind(&self) -> &'static str {
        match self {
            CosignerEvent::ContractShare { .. } => "contract_share",
        }
    }

    /// SSE `data:` payload (JSON).
    pub fn data_json(&self) -> String {
        match self {
            CosignerEvent::ContractShare {
                spk_hex,
                contract_id_hex,
            } => json!({
                "type": "contract_share",
                "evtxo_script_pubkey": spk_hex,
                "contract_id": contract_id_hex,
            })
            .to_string(),
        }
    }
}

/// Per-user broadcast channels. A channel is created lazily on first `subscribe` or `publish` and
/// kept while at least one entry exists (cheap; one `Sender` per user that ever subscribed).
pub struct EventBus {
    subs: Mutex<HashMap<String, broadcast::Sender<CosignerEvent>>>,
    capacity: usize,
}

impl EventBus {
    pub fn new() -> Self {
        Self {
            subs: Mutex::new(HashMap::new()),
            // Small per-user buffer; a slow subscriber that overruns it gets `Lagged` and catches up
            // via `evtxo/pending` rather than blocking the publisher.
            capacity: 64,
        }
    }

    fn sender(&self, vk_hex: &str) -> broadcast::Sender<CosignerEvent> {
        let mut subs = self.subs.lock().unwrap();
        subs.entry(vk_hex.to_string())
            .or_insert_with(|| broadcast::channel(self.capacity).0)
            .clone()
    }

    /// Subscribe to a user's events (for an SSE stream).
    pub fn subscribe(&self, vk_hex: &str) -> broadcast::Receiver<CosignerEvent> {
        self.sender(vk_hex).subscribe()
    }

    /// Publish an event for a user. Best-effort: returns the number of live receivers (0 if none —
    /// the event is simply missed live; the inbox remains the durable record).
    pub fn publish(&self, vk_hex: &str, event: CosignerEvent) -> usize {
        // Only touch the map if a channel already exists — no point creating one with no receivers.
        let sender = {
            let subs = self.subs.lock().unwrap();
            subs.get(vk_hex).cloned()
        };
        match sender {
            Some(tx) => tx.send(event).unwrap_or(0),
            None => 0,
        }
    }
}

impl Default for EventBus {
    fn default() -> Self {
        Self::new()
    }
}
