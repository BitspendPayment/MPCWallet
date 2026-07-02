//! Thin, read-only esplora REST client — the cosigner's ONLY chain dependency,
//! used solely to watch user boarding addresses for deposits (so it can nudge
//! the device to board). The wallet still owns all on-chain money + broadcast.

use serde::Deserialize;

#[derive(Debug, Clone)]
pub struct EsploraUtxo {
    pub txid: String,
    pub vout: u32,
    pub value: u64,
    pub confirmed: bool,
}

#[derive(Deserialize)]
struct RawStatus {
    #[serde(default)]
    confirmed: bool,
}

#[derive(Deserialize)]
struct RawUtxo {
    txid: String,
    vout: u32,
    value: u64,
    status: RawStatus,
}

/// esplora REST client. `base_url` like `http://127.0.0.1:30000` (no trailing slash).
#[derive(Clone)]
pub struct EsploraClient {
    http: reqwest::Client,
    base_url: String,
}

impl EsploraClient {
    pub fn new(base_url: &str) -> Self {
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(15))
            .build()
            .unwrap_or_default();
        Self {
            http,
            base_url: base_url.trim_end_matches('/').to_string(),
        }
    }

    /// `GET /address/{addr}/utxo` — the unspent outputs at an address.
    pub async fn list_utxos(&self, address: &str) -> Result<Vec<EsploraUtxo>, String> {
        let url = format!("{}/address/{}/utxo", self.base_url, address);
        let resp = self
            .http
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("esplora GET {url}: {e}"))?;
        if !resp.status().is_success() {
            return Err(format!("esplora {url} returned {}", resp.status()));
        }
        let raw: Vec<RawUtxo> = resp
            .json()
            .await
            .map_err(|e| format!("esplora decode {url}: {e}"))?;
        Ok(raw
            .into_iter()
            .map(|u| EsploraUtxo {
                txid: u.txid,
                vout: u.vout,
                value: u.value,
                confirmed: u.status.confirmed,
            })
            .collect())
    }
}
