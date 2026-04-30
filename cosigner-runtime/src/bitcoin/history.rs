use std::collections::HashMap;

use super::electrum::ElectrumClient;
use super::tx_parser;
use crate::policy::PolicyState;

/// Bitcoin history service for UTXO fetching and transaction history.
/// Mirrors `BitcoinHistoryService` from `server/lib/bitcoin_service.dart`.
pub struct BitcoinHistoryService {
    electrum: ElectrumClient,
    block_time_cache: HashMap<u32, u32>,
}

impl BitcoinHistoryService {
    pub fn new(electrum: ElectrumClient) -> Self {
        Self {
            electrum,
            block_time_cache: HashMap::new(),
        }
    }

    /// Broadcast a raw transaction via the Electrum server.
    pub async fn broadcast_transaction(&self, tx_hex: &str) -> Result<String, String> {
        self.electrum.broadcast_transaction(tx_hex).await
    }

    /// Connect to Electrum with retry loop.
    pub async fn init(&self) -> Result<(), String> {
        loop {
            match self.electrum.connect().await {
                Ok(()) => {
                    tracing::info!("Connected to Electrum");
                    return Ok(());
                }
                Err(e) => {
                    tracing::warn!("Waiting for Electrum: {e}");
                    tokio::time::sleep(std::time::Duration::from_secs(5)).await;
                }
            }
        }
    }

    /// List unspent outputs for a given electrum script hash.
    pub async fn list_unspent_by_script_hash(&self, script_hash: &str) -> Result<Vec<UtxoInfo>, String> {
        let utxos = self.electrum.list_unspent(script_hash).await?;
        Ok(utxos
            .into_iter()
            .map(|u| UtxoInfo {
                tx_hash: u.tx_hash,
                vout: u.tx_pos,
                amount_sats: u.value,
            })
            .collect())
    }

    /// Fetch UTXOs for a user across all policies.
    /// Returns list of (tx_hash, vout, amount_sats) tuples.
    pub async fn get_utxos(
        &self,
        policy_state: &PolicyState,
        wasm_tweaked_pubkey_hex_fn: impl Fn(&str) -> Result<String, String>,
    ) -> Result<Vec<UtxoInfo>, String> {
        let mut all_utxos = Vec::new();

        // Normal policy
        let pkp_json = &policy_state.normal_policy.public_key_package_json;
        all_utxos.extend(self.fetch_utxos_for_policy(pkp_json, &wasm_tweaked_pubkey_hex_fn).await?);

        // Protected policies
        for policy in policy_state.protected_policies.values() {
            let pkp_json = &policy.public_key_package_json;
            all_utxos.extend(self.fetch_utxos_for_policy(pkp_json, &wasm_tweaked_pubkey_hex_fn).await?);
        }

        Ok(all_utxos)
    }

    async fn fetch_utxos_for_policy(
        &self,
        pkp_json: &str,
        tweaked_pubkey_hex_fn: &impl Fn(&str) -> Result<String, String>,
    ) -> Result<Vec<UtxoInfo>, String> {
        // Get the tweaked compressed pubkey hex via WASM
        let tweaked_hex = tweaked_pubkey_hex_fn(pkp_json)?;
        let script_hex = tx_parser::derive_p2tr_script_hex(&tweaked_hex)?;
        let script_hash = tx_parser::derive_script_hash(&script_hex)?;

        let utxos = self.electrum.list_unspent(&script_hash).await?;

        Ok(utxos
            .into_iter()
            .map(|u| UtxoInfo {
                tx_hash: u.tx_hash,
                vout: u.tx_pos,
                amount_sats: u.value,
            })
            .collect())
    }

    /// Fetch recent transactions for a user.
    pub async fn get_recent_transactions(
        &self,
        policy_state: &PolicyState,
        wasm_tweaked_pubkey_hex_fn: impl Fn(&str) -> Result<String, String>,
    ) -> Result<Vec<TransactionSummary>, String> {
        let pkp_json = &policy_state.normal_policy.public_key_package_json;
        let tweaked_hex = wasm_tweaked_pubkey_hex_fn(pkp_json)?;
        let script_hex = tx_parser::derive_p2tr_script_hex(&tweaked_hex)?;
        let script_hash = tx_parser::derive_script_hash(&script_hex)?;

        let history = self.electrum.get_history(&script_hash).await?;

        let mut summaries = Vec::new();
        for item in &history {
            match self.process_transaction(&item.tx_hash, item.height, &script_hash).await {
                Ok(summary) => summaries.push(summary),
                Err(e) => tracing::warn!("Error processing tx {}: {e}", item.tx_hash),
            }
        }

        // Sort by timestamp desc
        summaries.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
        Ok(summaries)
    }

    async fn process_transaction(
        &self,
        tx_hash: &str,
        height: i64,
        script_hash: &str,
    ) -> Result<TransactionSummary, String> {
        let tx_hex = self.electrum.get_transaction(tx_hash).await?;
        let tx_bytes = hex::decode(&tx_hex).map_err(|e| format!("hex decode: {e}"))?;
        let tx: bitcoin::Transaction = bitcoin::consensus::deserialize(&tx_bytes)
            .map_err(|e| format!("tx deserialize: {e}"))?;

        let mut my_outputs: i64 = 0;
        let mut my_inputs: i64 = 0;

        // Check outputs
        for output in &tx.output {
            let output_script_hex = hex::encode(output.script_pubkey.as_bytes());
            let output_script_hash = tx_parser::derive_script_hash(&output_script_hex)
                .unwrap_or_default();
            if output_script_hash == script_hash {
                my_outputs += output.value.to_sat() as i64;
            }
        }

        // Check inputs (need to fetch previous transactions)
        for input in &tx.input {
            let prev_txid = input.previous_output.txid.to_string();
            if let Ok(prev_hex) = self.electrum.get_transaction(&prev_txid).await {
                if let Ok(prev_bytes) = hex::decode(&prev_hex) {
                    if let Ok(prev_tx) = bitcoin::consensus::deserialize::<bitcoin::Transaction>(&prev_bytes) {
                        let vout = input.previous_output.vout as usize;
                        if vout < prev_tx.output.len() {
                            let prev_out = &prev_tx.output[vout];
                            let prev_script_hex = hex::encode(prev_out.script_pubkey.as_bytes());
                            let prev_script_hash = tx_parser::derive_script_hash(&prev_script_hex)
                                .unwrap_or_default();
                            if prev_script_hash == script_hash {
                                my_inputs += prev_out.value.to_sat() as i64;
                            }
                        }
                    }
                }
            }
        }

        let net = my_outputs - my_inputs;

        let timestamp = if height > 0 {
            self.fetch_block_time(height as u32).await.unwrap_or(0) as i64
        } else {
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs() as i64
        };

        Ok(TransactionSummary {
            tx_hash: tx_hash.to_string(),
            amount_sats: net,
            timestamp,
            is_pending: height <= 0,
        })
    }

    async fn fetch_block_time(&self, height: u32) -> Result<u32, String> {
        if let Some(&time) = self.block_time_cache.get(&height) {
            return Ok(time);
        }

        let header_hex = self.electrum.get_block_header(height).await?;
        let header_bytes = hex::decode(&header_hex).map_err(|e| format!("hex decode: {e}"))?;

        if header_bytes.len() >= 72 {
            // Time is at offset 68 (4 bytes LE) in standard bitcoin header
            let time_bytes = &header_bytes[68..72];
            let time = u32::from_le_bytes([
                time_bytes[0],
                time_bytes[1],
                time_bytes[2],
                time_bytes[3],
            ]);
            // Note: can't mutate cache without &mut self, we'll skip caching for now
            return Ok(time);
        }

        Err("Header too short".to_string())
    }
}

#[derive(Debug, Clone)]
pub struct UtxoInfo {
    pub tx_hash: String,
    pub vout: u32,
    pub amount_sats: i64,
}

#[derive(Debug, Clone)]
pub struct TransactionSummary {
    pub tx_hash: String,
    pub amount_sats: i64,
    pub timestamp: i64,
    pub is_pending: bool,
}
