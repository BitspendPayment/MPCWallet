//! Minimal bitcoind JSON-RPC for regtest — enough to fund + confirm a boarding UTXO from the REPL.
//! Defaults to the host-mapped node in `docker-compose.ark.yml`; override with `BITCOIN_RPC_URL` /
//! `BITCOIN_RPC_WALLET`.

use anyhow::{anyhow, Context, Result};
use serde_json::{json, Value};

pub struct BitcoinRpc {
    http: reqwest::Client,
    base: String,
    wallet: String,
}

impl BitcoinRpc {
    pub fn from_env() -> Self {
        Self {
            http: reqwest::Client::new(),
            base: std::env::var("BITCOIN_RPC_URL")
                .unwrap_or_else(|_| "http://admin1:123@127.0.0.1:18443".to_string()),
            wallet: std::env::var("BITCOIN_RPC_WALLET").unwrap_or_else(|_| "default".to_string()),
        }
    }

    async fn call(&self, url: &str, method: &str, params: Value) -> Result<Value> {
        let resp = self
            .http
            .post(url)
            .json(&json!({ "jsonrpc": "1.0", "id": "merlin", "method": method, "params": params }))
            .send()
            .await
            .with_context(|| format!("bitcoind rpc {method} (is the regtest node up?)"))?;
        let body: Value = resp.json().await.context("bitcoind rpc: bad JSON")?;
        if let Some(err) = body.get("error").filter(|e| !e.is_null()) {
            return Err(anyhow!("bitcoind {method}: {err}"));
        }
        Ok(body.get("result").cloned().unwrap_or(Value::Null))
    }

    /// Node-scoped call (no wallet), e.g. `getrawtransaction`.
    async fn node(&self, method: &str, params: Value) -> Result<Value> {
        let url = self.base.clone();
        self.call(&url, method, params).await
    }

    /// Wallet-scoped call, e.g. `sendtoaddress`.
    async fn wallet(&self, method: &str, params: Value) -> Result<Value> {
        let url = format!("{}/wallet/{}", self.base, self.wallet);
        self.call(&url, method, params).await
    }

    /// Send `sats` to `address` and mine one block to confirm. Returns the funding txid.
    pub async fn send_to(&self, address: &str, sats: u64) -> Result<String> {
        let btc = format!("{}.{:08}", sats / 100_000_000, sats % 100_000_000);
        let txid = self
            .wallet("sendtoaddress", json!([address, btc]))
            .await?
            .as_str()
            .ok_or_else(|| anyhow!("sendtoaddress returned no txid"))?
            .to_string();
        // Confirm it — the boarding scan and the cosigner both want a mined UTXO.
        let miner = self
            .wallet("getnewaddress", json!(["", "bech32m"]))
            .await?
            .as_str()
            .unwrap_or_default()
            .to_string();
        self.node("generatetoaddress", json!([1, miner])).await?;
        Ok(txid)
    }

    /// Find the `(vout, sats)` in `txid` paying `address`. Read AFTER a confirmation.
    pub async fn find_output(&self, txid: &str, address: &str) -> Result<(u32, u64)> {
        let tx = self.node("getrawtransaction", json!([txid, true])).await?;
        let vouts = tx
            .get("vout")
            .and_then(|v| v.as_array())
            .ok_or_else(|| anyhow!("tx {txid} has no vout"))?;
        for out in vouts {
            let spk = out.get("scriptPubKey");
            let addr = spk.and_then(|s| s.get("address")).and_then(|a| a.as_str());
            if addr == Some(address) {
                let n = out.get("n").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                // value is BTC as a float in JSON; round to sats.
                let btc = out.get("value").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let sats = (btc * 100_000_000.0).round() as u64;
                return Ok((n, sats));
            }
        }
        Err(anyhow!("no output paying {address} in tx {txid}"))
    }
}
