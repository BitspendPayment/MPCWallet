use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;

use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpStream;
use tokio::sync::{broadcast, Mutex, oneshot};

/// Electrum TCP JSON-RPC client with notification support and automatic reconnection.
pub struct ElectrumClient {
    writer: Arc<Mutex<Option<tokio::io::WriteHalf<TcpStream>>>>,
    pending: Arc<Mutex<HashMap<u64, oneshot::Sender<Value>>>>,
    notification_tx: broadcast::Sender<ElectrumNotification>,
    next_id: AtomicU64,
    domain: String,
    port: u16,
    connected: Arc<AtomicBool>,
}

#[derive(Debug, Clone)]
pub struct ElectrumNotification {
    pub _method: String,
    pub _params: Vec<Value>,
}

impl ElectrumClient {
    pub fn new(domain: &str, port: u16) -> Self {
        let (notification_tx, _) = broadcast::channel(256);
        Self {
            writer: Arc::new(Mutex::new(None)),
            pending: Arc::new(Mutex::new(HashMap::new())),
            notification_tx,
            next_id: AtomicU64::new(0),
            domain: domain.to_string(),
            port,
            connected: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Returns true if the client believes it is connected.
    pub fn is_connected(&self) -> bool {
        self.connected.load(Ordering::Relaxed)
    }

    /// Connect to the Electrum server. Safe to call multiple times (reconnect).
    pub async fn connect(&self) -> Result<(), String> {
        // Clean up any previous connection state.
        self.connected.store(false, Ordering::Relaxed);
        *self.writer.lock().await = None;
        // Fail all pending requests from the previous connection.
        {
            let mut pending = self.pending.lock().await;
            for (_, sender) in pending.drain() {
                let _ = sender.send(json!({"error": "connection reset"}));
            }
        }

        let addr = format!("{}:{}", self.domain, self.port);
        tracing::info!("Connecting to Electrum at {addr}...");

        let stream = TcpStream::connect(&addr)
            .await
            .map_err(|e| format!("Failed to connect to Electrum: {e}"))?;

        let (reader, writer) = tokio::io::split(stream);
        *self.writer.lock().await = Some(writer);
        self.connected.store(true, Ordering::Relaxed);

        // Spawn reader task
        let pending = self.pending.clone();
        let notification_tx = self.notification_tx.clone();
        let connected = self.connected.clone();
        tokio::spawn(async move {
            let mut lines = BufReader::new(reader).lines();
            while let Ok(Some(line)) = lines.next_line().await {
                if line.is_empty() {
                    continue;
                }
                match serde_json::from_str::<Value>(&line) {
                    Ok(msg) => {
                        if let Some(id) = msg.get("id").and_then(|v| v.as_u64()) {
                            // Response to a request
                            let mut pending = pending.lock().await;
                            if let Some(sender) = pending.remove(&id) {
                                let _ = sender.send(msg);
                            }
                        } else if let Some(method) = msg.get("method").and_then(|v| v.as_str()) {
                            // Notification
                            if method.ends_with(".subscribe") {
                                let params = msg
                                    .get("params")
                                    .and_then(|v| v.as_array())
                                    .cloned()
                                    .unwrap_or_default();
                                let _ = notification_tx.send(ElectrumNotification {
                                    _method: method.to_string(),
                                    _params: params,
                                });
                            }
                        }
                    }
                    Err(e) => {
                        tracing::warn!("Electrum JSON parse error: {e}");
                    }
                }
            }
            // TCP connection dropped -- mark disconnected and fail all pending requests.
            tracing::warn!("Electrum connection lost");
            connected.store(false, Ordering::Relaxed);
            let mut pending = pending.lock().await;
            for (_, sender) in pending.drain() {
                let _ = sender.send(json!({"error": "Electrum connection lost"}));
            }
        });

        tracing::info!("Connected to Electrum at {addr}");
        Ok(())
    }

    /// Attempt to reconnect if disconnected. Returns Ok if already connected.
    async fn ensure_connected(&self) -> Result<(), String> {
        if self.is_connected() {
            return Ok(());
        }
        tracing::info!("Electrum disconnected, attempting reconnect...");
        self.connect().await
    }

    /// Send a JSON-RPC request and wait for the response.
    /// Automatically reconnects if disconnected, and applies a 30-second timeout.
    pub async fn request(&self, method: &str, params: &[Value]) -> Result<Value, String> {
        // Reconnect if needed.
        self.ensure_connected().await?;

        let id = self.next_id.fetch_add(1, Ordering::SeqCst);
        let payload = json!({
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": id,
        });

        let (tx, rx) = oneshot::channel();
        self.pending.lock().await.insert(id, tx);

        let msg = format!("{}\n", payload);
        {
            let mut writer_guard = self.writer.lock().await;
            let writer = writer_guard
                .as_mut()
                .ok_or_else(|| "Not connected to Electrum".to_string())?;
            writer
                .write_all(msg.as_bytes())
                .await
                .map_err(|e| format!("Failed to write to Electrum: {e}"))?;
            writer
                .flush()
                .await
                .map_err(|e| format!("Failed to flush to Electrum: {e}"))?;
        }

        // Wait for response with a 30-second timeout.
        let response = tokio::time::timeout(std::time::Duration::from_secs(30), rx)
            .await
            .map_err(|_| format!("Electrum request timed out: {method}"))?
            .map_err(|_| "Electrum request cancelled".to_string())?;

        if let Some(error) = response.get("error") {
            if !error.is_null() {
                return Err(format!("Electrum error: {error}"));
            }
        }

        Ok(response.get("result").cloned().unwrap_or(Value::Null))
    }

    /// List unspent outputs for a script hash.
    pub async fn list_unspent(&self, script_hash: &str) -> Result<Vec<ElectrumUtxo>, String> {
        let result = self
            .request("blockchain.scripthash.listunspent", &[json!(script_hash)])
            .await?;

        let utxos: Vec<ElectrumUtxo> = serde_json::from_value(result)
            .map_err(|e| format!("Failed to parse listunspent: {e}"))?;
        Ok(utxos)
    }

    /// Get transaction history for a script hash.
    pub async fn get_history(
        &self,
        script_hash: &str,
    ) -> Result<Vec<ElectrumHistoryItem>, String> {
        let result = self
            .request("blockchain.scripthash.get_history", &[json!(script_hash)])
            .await?;

        let items: Vec<ElectrumHistoryItem> = serde_json::from_value(result)
            .map_err(|e| format!("Failed to parse history: {e}"))?;
        Ok(items)
    }

    /// Get raw transaction hex by hash.
    pub async fn get_transaction(&self, tx_hash: &str) -> Result<String, String> {
        let result = self
            .request("blockchain.transaction.get", &[json!(tx_hash)])
            .await?;

        result
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| "unexpected transaction response".to_string())
    }

    /// Broadcast a raw transaction via Electrum. Returns the txid.
    pub async fn broadcast_transaction(&self, tx_hex: &str) -> Result<String, String> {
        let result = self
            .request("blockchain.transaction.broadcast", &[json!(tx_hex)])
            .await?;
        result
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| "unexpected broadcast response".to_string())
    }

    /// Get block header hex at a given height.
    pub async fn get_block_header(&self, height: u32) -> Result<String, String> {
        let result = self
            .request("blockchain.block.header", &[json!(height)])
            .await?;

        result
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| "unexpected header response".to_string())
    }

}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct ElectrumUtxo {
    pub tx_hash: String,
    pub tx_pos: u32,
    pub value: i64,
    #[allow(dead_code)]
    pub height: i64,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct ElectrumHistoryItem {
    pub tx_hash: String,
    pub height: i64,
}
