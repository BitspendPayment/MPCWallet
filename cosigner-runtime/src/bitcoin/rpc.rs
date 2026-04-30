use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64;
use serde_json::{json, Value};

/// Bitcoin Core JSON-RPC client.
/// Mirrors `BitcoinService` from `server/lib/bitcoin.dart`.
pub struct BitcoinRpcClient {
    url: String,
    auth_header: String,
    client: reqwest::Client,
}

impl BitcoinRpcClient {
    pub fn new(url: &str, rpc_user: &str, rpc_password: &str) -> Self {
        let credentials = format!("{}:{}", rpc_user, rpc_password);
        let auth_header = format!("Basic {}", BASE64.encode(credentials.as_bytes()));
        Self {
            url: url.to_string(),
            auth_header,
            client: reqwest::Client::new(),
        }
    }

    /// Broadcast a raw transaction. Returns the txid.
    pub async fn send_raw_transaction(&self, tx_hex: &str) -> Result<String, String> {
        let result = self.call_rpc("sendrawtransaction", &[json!(tx_hex)]).await?;
        result
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| "unexpected RPC response type".to_string())
    }

    async fn call_rpc(&self, method: &str, params: &[Value]) -> Result<Value, String> {
        let payload = json!({
            "jsonrpc": "1.0",
            "id": "mpc_server",
            "method": method,
            "params": params,
        });

        let response = self
            .client
            .post(&self.url)
            .header("content-type", "text/plain")
            .header("authorization", &self.auth_header)
            .body(payload.to_string())
            .send()
            .await
            .map_err(|e| format!("Failed to connect to Bitcoind: {e}"))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(format!("Bitcoind RPC Error: {status} - {body}"));
        }

        let body: Value = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse RPC response: {e}"))?;

        if !body["error"].is_null() {
            return Err(format!("Bitcoind RPC Error: {}", body["error"]));
        }

        Ok(body["result"].clone())
    }
}
