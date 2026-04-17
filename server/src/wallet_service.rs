//! Client-facing gRPC service implementing `mpc_wallet.proto`.
//! This is the main service that replaces the Dart server.

use std::collections::HashMap;
use std::pin::Pin;
use std::sync::atomic::Ordering;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use rand::Rng;
use tokio::sync::Notify;
use tokio_stream::Stream;
use tonic::{Request, Response, Status};

use crate::auth::message::*;
use crate::auth::AuthVerifier;
use crate::bitcoin::{BitcoinHistoryService, BitcoinRpcClient};
use crate::crypto_ops;
use crate::persistence::{KvStore, SecretStore};
use crate::policy::engine::PolicyEngine;
use crate::policy::{
    NormalPolicy, PolicyState, ProtectedPolicy, SpendingEntry,
};
use crate::wallet_proto::mpc_wallet_server::MpcWallet;
use crate::wallet_proto::*;
use crate::wasm_manager::{StepSync, WasmManager};

const TOTAL_PARTICIPANTS: usize = 3;
const THRESHOLD_COUNT: u32 = 2;

#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub struct ArkTxEntry {
    pub tx_type: String,   // "board", "send", "receive", "settle"
    pub amount_sats: i64,  // positive for inflows, negative for outflows
    pub txid: String,
    pub timestamp: i64,    // seconds since epoch
}

fn now_secs() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as i64
}

pub struct WalletService {
    pub wasm_manager: Arc<Mutex<WasmManager>>,
    pub auth_verifier: Arc<AuthVerifier>,
    pub persistence: Arc<dyn KvStore>,
    pub secret_store: Arc<dyn SecretStore>,
    pub bitcoin_rpc: Arc<BitcoinRpcClient>,
    pub bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
    pub asp_client: Option<Arc<tokio::sync::Mutex<ark::client::AspClient>>>,
    /// Active settle sessions (boarding): user_id -> (session, boarding_amount_sats).
    pub settle_sessions: tokio::sync::Mutex<HashMap<String, (ark::client::batch::SettleSession, u64, u32)>>,
    /// Active delegate settle sessions: user_id -> session.
    pub delegate_sessions: tokio::sync::Mutex<HashMap<String, ark::client::batch::DelegateSettleSession>>,
    /// Active send sessions: user_id -> session.
    pub send_sessions: tokio::sync::Mutex<HashMap<String, (ark::client::send::SendSession, u32)>>,
    /// Simple in-memory VTXO store: user_id -> list of (txid, vout, amount_sats, exit_delay).
    pub vtxo_store: tokio::sync::Mutex<HashMap<String, Vec<(String, u32, u64, u32)>>>,
    /// Reverse lookup: VTXO scriptPubKey hex -> user_id_hex.
    /// Populated when users call get_ark_address.
    pub ark_script_to_user: tokio::sync::Mutex<HashMap<String, String>>,
    /// Ark transaction history: user_id_hex -> list of tx entries.
    pub ark_tx_history: tokio::sync::Mutex<HashMap<String, Vec<ArkTxEntry>>>,
}

impl WalletService {
    pub fn new(
        wasm_manager: Arc<Mutex<WasmManager>>,
        auth_verifier: Arc<AuthVerifier>,
        persistence: Arc<dyn KvStore>,
        secret_store: Arc<dyn SecretStore>,
        bitcoin_rpc: Arc<BitcoinRpcClient>,
        bitcoin_history: Arc<tokio::sync::Mutex<BitcoinHistoryService>>,
        asp_client: Option<ark::client::AspClient>,
    ) -> Self {
        Self {
            wasm_manager,
            auth_verifier,
            persistence,
            secret_store,
            bitcoin_rpc,
            bitcoin_history,
            asp_client: asp_client.map(|c| Arc::new(tokio::sync::Mutex::new(c))),
            settle_sessions: tokio::sync::Mutex::new(HashMap::new()),
            delegate_sessions: tokio::sync::Mutex::new(HashMap::new()),
            send_sessions: tokio::sync::Mutex::new(HashMap::new()),
            vtxo_store: tokio::sync::Mutex::new(HashMap::new()),
            ark_script_to_user: tokio::sync::Mutex::new(HashMap::new()),
            ark_tx_history: tokio::sync::Mutex::new(HashMap::new()),
        }
    }

    // -----------------------------------------------------------------------
    // Ark state persistence
    // -----------------------------------------------------------------------

    /// Load persisted Ark state (vtxo_store, ark_tx_history, ark_script_to_user)
    /// and validate the ASP signer pubkey hasn't changed.
    pub async fn load_ark_state(&self) {
        if self.asp_client.is_none() {
            tracing::info!("No ASP configured, skipping Ark state load");
            return;
        }

        // Check ASP signer pubkey
        let current_pubkey = {
            let asp = self.asp_client.as_ref().unwrap();
            let mut guard = asp.lock().await;
            match guard.get_info().await {
                Ok(info) => info.signer_pubkey.clone(),
                Err(e) => {
                    tracing::warn!("Failed to get ASP info for pubkey check: {e}");
                    return;
                }
            }
        };

        let stored_pubkey = match self.persistence.get("ark_meta", "asp_signer_pubkey") {
            Ok(v) => v,
            Err(e) => { tracing::warn!("Failed to read ark_meta: {e}"); return; }
        };
        if let Some(ref stored) = stored_pubkey {
            if stored != &current_pubkey {
                tracing::warn!(
                    "ASP signer pubkey changed ({stored} -> {current_pubkey}), wiping Ark state"
                );
                self.wipe_ark_state();
                if let Err(e) = self.persistence.put("ark_meta", "asp_signer_pubkey", &current_pubkey) {
                    tracing::warn!("persist ark_meta/asp_signer_pubkey failed: {e}");
                }
                return;
            }
        } else {
            if let Err(e) = self.persistence.put("ark_meta", "asp_signer_pubkey", &current_pubkey) {
                tracing::warn!("persist ark_meta/asp_signer_pubkey failed: {e}");
            }
        }

        // Load vtxo_store
        if let Ok(all) = self.persistence.get_all("vtxo_store") {
            let mut store = self.vtxo_store.lock().await;
            for (user_id, json) in all {
                if let Ok(vtxos) = serde_json::from_str::<Vec<(String, u32, u64, u32)>>(&json) {
                    tracing::info!("Loaded {} VTXOs for user {user_id}", vtxos.len());
                    store.insert(user_id, vtxos);
                }
            }
        }

        // Load ark_tx_history
        if let Ok(all) = self.persistence.get_all("ark_tx_history") {
            let mut history = self.ark_tx_history.lock().await;
            for (user_id, json) in all {
                if let Ok(entries) = serde_json::from_str::<Vec<ArkTxEntry>>(&json) {
                    tracing::info!("Loaded {} Ark tx entries for user {user_id}", entries.len());
                    history.insert(user_id, entries);
                }
            }
        }

        // Load ark_script_to_user
        if let Ok(all) = self.persistence.get_all("ark_script_to_user") {
            let mut map = self.ark_script_to_user.lock().await;
            tracing::info!("Loaded {} script-to-user mappings", all.len());
            for (script, user_id) in all {
                map.insert(script, user_id);
            }
        }

        tracing::info!("Ark state loaded from persistence");
    }

    fn wipe_ark_state(&self) {
        for tree_name in &["vtxo_store", "ark_tx_history", "ark_script_to_user", "ark_meta"] {
            if let Err(e) = self.persistence.clear(tree_name) {
                tracing::warn!("clear {tree_name} failed: {e}");
            }
        }
        tracing::info!("Ark state wiped");
    }

    fn save_user_vtxos(&self, user_id_hex: &str, vtxos: &[(String, u32, u64, u32)]) {
        if let Ok(json) = serde_json::to_string(vtxos) {
            if let Err(e) = self.persistence.put("vtxo_store", user_id_hex, &json) {
                tracing::warn!("persist vtxo_store/{user_id_hex} failed: {e}");
            }
        }
    }

    fn save_user_ark_history(&self, user_id_hex: &str, entries: &[ArkTxEntry]) {
        if let Ok(json) = serde_json::to_string(entries) {
            if let Err(e) = self.persistence.put("ark_tx_history", user_id_hex, &json) {
                tracing::warn!("persist ark_tx_history/{user_id_hex} failed: {e}");
            }
        }
    }

    fn save_script_to_user(&self, script: &str, user_id_hex: &str) {
        if let Err(e) = self.persistence.put("ark_script_to_user", script, user_id_hex) {
            tracing::warn!("persist ark_script_to_user/{script} failed: {e}");
        }
    }

    // -----------------------------------------------------------------------
    // VTXO stream sync
    // -----------------------------------------------------------------------

    /// Long-running task that subscribes to arkd's GetTransactionsStream
    /// and keeps vtxo_store up to date when VTXOs move during rounds.
    pub async fn run_vtxo_stream(&self) {
        tracing::info!("VTXO stream task started");
        loop {
            tracing::info!("VTXO stream: attempting connection...");
            match self.connect_and_stream().await {
                Ok(()) => tracing::info!("VTXO stream ended, reconnecting..."),
                Err(e) => tracing::warn!("VTXO stream error: {e}, reconnecting in 5s..."),
            }
            tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        }
    }

    async fn connect_and_stream(&self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        // Get ASP URL from the existing client's channel, then open a dedicated
        // connection for streaming so we don't hold the shared mutex.
        let asp_arc = self.asp_client.as_ref().ok_or("ASP not configured")?;
        let asp_url = {
            let asp = asp_arc.lock().await;
            // Get info to verify ASP is reachable (also caches info)
            drop(asp);
            // Use the ASP_URL env var directly for the dedicated stream connection
            std::env::var("ASP_URL").map_err(|_| "ASP_URL env var not set")?
        };

        tracing::info!("VTXO stream: connecting to ASP at {asp_url}");
        let mut stream_client = ark::client::AspClient::connect(&asp_url).await?;
        tracing::info!("VTXO stream: ASP connected, opening transaction stream...");
        let mut stream = stream_client.get_transactions_stream().await?;
        tracing::info!("VTXO stream: connected to arkd, listening for events");

        while let Some(event) = stream.message().await? {
            if let Some(data) = event.data {
                use ark::client::proto::get_transactions_stream_response::Data;
                match data {
                    Data::CommitmentTx(notif) | Data::ArkTx(notif) => {
                        self.process_tx_notification(&notif).await;
                    }
                    Data::Heartbeat(_) => {}
                }
            }
        }
        Ok(())
    }

    async fn process_tx_notification(&self, notif: &ark::client::proto::TxNotification) {
        let script_map = self.ark_script_to_user.lock().await;
        let mut store = self.vtxo_store.lock().await;
        let mut affected_users = std::collections::HashSet::new();

        // Remove spent VTXOs
        for spent in &notif.spent_vtxos {
            if let Some(user_id) = script_map.get(&spent.script) {
                if let Some(outpoint) = &spent.outpoint {
                    if let Some(user_vtxos) = store.get_mut(user_id) {
                        user_vtxos.retain(|(txid, vout, _, _)| {
                            !(txid == &outpoint.txid && *vout == outpoint.vout)
                        });
                        affected_users.insert(user_id.clone());
                    }
                }
            }
        }

        // Add new spendable VTXOs
        for new_vtxo in &notif.spendable_vtxos {
            if let Some(user_id) = script_map.get(&new_vtxo.script) {
                if let Some(outpoint) = &new_vtxo.outpoint {
                    // Avoid duplicates
                    let entry = store.entry(user_id.clone()).or_default();
                    let already_exists = entry.iter().any(|(t, v, _, _)| {
                        t == &outpoint.txid && *v == outpoint.vout
                    });
                    if !already_exists {
                        tracing::info!(
                            "[{user_id}] VTXO stream: new spendable {}:{} amount={}",
                            outpoint.txid, outpoint.vout, new_vtxo.amount
                        );
                        entry.push((
                            outpoint.txid.clone(),
                            outpoint.vout,
                            new_vtxo.amount,
                            0, // exit_delay — client gets this from ArkInfo
                        ));
                        affected_users.insert(user_id.clone());
                        // Log "receive" only if no active settle/send session for this user
                        // (avoids duplicate entries when boarding or sending to self).
                        let has_settle = self.settle_sessions.lock().await.contains_key(user_id);
                        let has_delegate = self.delegate_sessions.lock().await.contains_key(user_id);
                        let has_send = self.send_sessions.lock().await.contains_key(user_id);
                        if !has_settle && !has_delegate && !has_send {
                            let mut history = self.ark_tx_history.lock().await;
                            history.entry(user_id.clone()).or_default()
                                .push(ArkTxEntry {
                                    tx_type: "receive".into(),
                                    amount_sats: new_vtxo.amount as i64,
                                    txid: outpoint.txid.clone(),
                                    timestamp: now_secs(),
                                });
                            if let Some(entries) = history.get(user_id) {
                                self.save_user_ark_history(user_id, entries);
                            }
                        }
                    }
                }
            }
        }

        // Persist vtxo_store for affected users
        for user_id in &affected_users {
            if let Some(vtxos) = store.get(user_id) {
                self.save_user_vtxos(user_id, vtxos);
            }
        }
    }

    /// Register a user's VTXO scriptPubKey for stream matching.
    async fn register_user_vtxo_script(&self, user_id_hex: &str, owner_pk_hex: &str) {
        let asp = match self.asp_client.as_ref() {
            Some(a) => a,
            None => return,
        };
        let info = {
            let mut guard = asp.lock().await;
            match &guard.info {
                Some(i) => i.clone(),
                None => match guard.get_info().await {
                    Ok(i) => i,
                    Err(_) => return,
                },
            }
        };

        // Register for both exit delays (boarding + unilateral)
        for exit_delay in [info.unilateral_exit_delay as u32, info.boarding_exit_delay as u32] {
            let network = match ark::client::parse_network(&info.network) {
                Ok(n) => n,
                Err(_) => continue,
            };
            if let Ok(script_hex) = ark::client::vtxo_script_pubkey_hex(
                owner_pk_hex,
                &info.signer_pubkey,
                exit_delay,
                network,
            ) {
                let mut script_map = self.ark_script_to_user.lock().await;
                script_map.insert(script_hex.clone(), user_id_hex.to_string());
                self.save_script_to_user(&script_hex, user_id_hex);
            }
        }
    }

    /// Get the ASP client or return UNAVAILABLE.
    fn require_asp(&self) -> Result<&Arc<tokio::sync::Mutex<ark::client::AspClient>>, Status> {
        self.asp_client
            .as_ref()
            .ok_or_else(|| Status::unavailable("ASP not configured (set ASP_URL env var)"))
    }

    /// Get the user's group x-only public key (64 hex chars) for Ark address derivation.
    ///
    /// This is the untweaked group verifying key from the normal policy's public key package.
    /// The compressed public key is 33 bytes (66 hex); we strip the leading parity byte to
    /// get the 32-byte x-only representation.
    fn get_user_xonly_pubkey(&self, user_id_hex: &str) -> Result<String, Status> {
        let mut mgr = self.wasm_manager.lock().unwrap();
        self.load_policy_state(&mut mgr, user_id_hex)?;
        let user = mgr
            .get_or_create_user(user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let ps = user
            .policy_state
            .as_ref()
            .ok_or_else(|| Status::not_found("no policy state"))?;
        let vk_hex = Self::extract_verifying_key(&ps.normal_policy.public_key_package_json)?;
        // vk_hex is a 66-char compressed pubkey (02/03 prefix + 32 bytes).
        // Extract x-only (last 64 chars).
        if vk_hex.len() == 66 {
            Ok(vk_hex[2..].to_string())
        } else if vk_hex.len() == 64 {
            Ok(vk_hex)
        } else {
            Err(Status::internal(format!(
                "unexpected verifying key length: {}",
                vk_hex.len()
            )))
        }
    }

    /// Get both the user's x-only pubkey and the server's DKG secret hex.
    fn get_user_ark_keys(&self, user_id_hex: &str) -> Result<(String, String), Status> {
        let mut mgr = self.wasm_manager.lock().unwrap();
        self.load_policy_state(&mut mgr, user_id_hex)?;
        let user = mgr
            .get_or_create_user(user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let ps = user
            .policy_state
            .as_ref()
            .ok_or_else(|| Status::not_found("no policy state"))?;
        let vk_hex = Self::extract_verifying_key(&ps.normal_policy.public_key_package_json)?;
        let xonly = if vk_hex.len() == 66 {
            vk_hex[2..].to_string()
        } else if vk_hex.len() == 64 {
            vk_hex
        } else {
            return Err(Status::internal(format!(
                "unexpected verifying key length: {}",
                vk_hex.len()
            )));
        };
        let dkg_secret = ps
            .server_dkg_secret_hex
            .clone()
            .ok_or_else(|| Status::internal("missing server_dkg_secret_hex"))?;
        Ok((xonly, dkg_secret))
    }

    fn user_id_hex(user_id: &[u8]) -> String {
        hex::encode(user_id)
    }

    /// Verify single-key Schnorr auth. user_id bytes = compressed public key.
    fn verify_auth(
        &self,
        user_id: &[u8],
        signature: &[u8],
        timestamp_ms: i64,
        operation: &str,
    ) -> Result<(), Status> {
        let user_id_hex = Self::user_id_hex(user_id);
        let pk_hex = hex::encode(user_id);
        let sig_hex = hex::encode(signature);

        let mut mgr = self.wasm_manager.lock().unwrap();
        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

        self.auth_verifier
            .verify_auth(user, &pk_hex, &sig_hex, operation, timestamp_ms, &user_id_hex)
    }

    /// Load policy state from UserInstance or persistence.
    #[tracing::instrument(skip(self, mgr), fields(user_id = %user_id_hex))]
    fn load_policy_state(
        &self,
        mgr: &mut WasmManager,
        user_id_hex: &str,
    ) -> Result<(), Status> {
        let user = mgr
            .get_or_create_user(user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

        if user.policy_state.is_some() {
            return Ok(());
        }

        // Try loading from persistence
        if let Ok(Some(json_str)) = self.persistence.get("policies", user_id_hex) {
            match serde_json::from_str::<PolicyState>(&json_str) {
                Ok(mut ps) => {
                    // Load DKG secret from SecretStore (skipped in JSON)
                    if let Ok(Some(secret)) = self.secret_store.get_secret(
                        &format!("dkg-secret.{user_id_hex}"),
                    ) {
                        ps.server_dkg_secret_hex = Some(secret);
                    }
                    user.policy_state = Some(ps);
                    tracing::info!("[{user_id_hex}] Loaded policy from persistence");
                    return Ok(());
                }
                Err(e) => {
                    tracing::warn!("[{user_id_hex}] Error parsing policy: {e}");
                }
            }
        }

        Err(Status::not_found(format!(
            "No policy state found for user {user_id_hex}"
        )))
    }

    /// Find a policy by recovery_id across all users.
    #[tracing::instrument(skip(self, mgr), fields(recovery_id = %recovery_id_hex))]
    fn find_policy_by_recovery_id(
        &self,
        mgr: &mut WasmManager,
        recovery_id_hex: &str,
    ) -> Result<Option<PolicyState>, Status> {
        // Check in-memory first
        for (_, user) in mgr.iter_users() {
            if let Some(ps) = &user.policy_state {
                if ps.recovery_id == recovery_id_hex {
                    return Ok(Some(ps.clone()));
                }
            }
        }

        // Look up via secondary index
        if let Ok(Some(user_id)) = self.persistence.get("policy_recovery_idx", recovery_id_hex) {
            if let Ok(Some(json_str)) = self.persistence.get("policies", &user_id) {
                if let Ok(mut ps) = serde_json::from_str::<PolicyState>(&json_str) {
                    // Load DKG secret from SecretStore
                    if let Ok(Some(secret)) = self.secret_store.get_secret(
                        &format!("dkg-secret.{user_id}"),
                    ) {
                        ps.server_dkg_secret_hex = Some(secret);
                    }
                    if let Ok(user) = mgr.get_or_create_user(&user_id) {
                        user.policy_state = Some(ps.clone());
                    }
                    return Ok(Some(ps));
                }
            }
        }

        Ok(None)
    }

    /// Save policy state to persistence (with recovery_id secondary index).
    /// DKG secret is stored separately via SecretStore.
    #[tracing::instrument(skip(self, policy), fields(user_id = %user_id_hex, policy_bytes), err)]
    fn persist_policy(&self, user_id_hex: &str, policy: &PolicyState) -> Result<(), Status> {
        let json = serde_json::to_string(policy)
            .map_err(|e| Status::internal(format!("serialization error: {e}")))?;
        tracing::Span::current().record("policy_bytes", json.len());
        self.persistence.put("policies", user_id_hex, &json)
            .map_err(|e| {
                tracing::error!(error = %e, user_id = %user_id_hex, "persistence put policies failed");
                Status::internal(format!("persistence write error: {e}"))
            })?;
        // Maintain secondary index: recovery_id -> user_id
        if !policy.recovery_id.is_empty() {
            if let Err(e) = self.persistence.put("policy_recovery_idx", &policy.recovery_id, user_id_hex) {
                tracing::warn!("persist policy_recovery_idx/{} failed: {e}", policy.recovery_id);
            }
        }
        // Store DKG secret separately via SecretStore
        if let Some(ref secret) = policy.server_dkg_secret_hex {
            if let Err(e) = self.secret_store.put_secret(
                &format!("dkg-secret.{user_id_hex}"),
                secret,
            ) {
                tracing::error!("persist dkg-secret.{user_id_hex} failed: {e} — wallet may not be restorable");
            }
        }
        Ok(())
    }

    /// Parse the WASM round2 packages result into individual entries.
    fn parse_round2_result(
        json_str: &str,
    ) -> Result<HashMap<String, String>, Status> {
        let v: serde_json::Value = serde_json::from_str(json_str)
            .map_err(|e| Status::internal(format!("bad round2 result: {e}")))?;
        let obj = v.as_object().ok_or_else(|| {
            Status::internal("expected round2 packages object")
        })?;
        let mut result = HashMap::new();
        for (k, v) in obj {
            result.insert(k.clone(), v.to_string());
        }
        Ok(result)
    }

    /// Extract secretShare hex from a key package JSON.
    fn extract_secret_share(kp_json: &str) -> Result<String, Status> {
        let v: serde_json::Value = serde_json::from_str(kp_json)
            .map_err(|e| Status::internal(format!("bad key package JSON: {e}")))?;
        v["secretShare"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| Status::internal("missing secretShare in key package"))
    }

    /// Extract identifier hex from a key package JSON.
    fn extract_identifier(kp_json: &str) -> Result<String, Status> {
        let v: serde_json::Value = serde_json::from_str(kp_json)
            .map_err(|e| Status::internal(format!("bad key package JSON: {e}")))?;
        v["identifier"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| Status::internal("missing identifier in key package"))
    }

    /// Extract verifyingKey hex from a public key package JSON.
    fn extract_verifying_key(pkp_json: &str) -> Result<String, Status> {
        let v: serde_json::Value = serde_json::from_str(pkp_json)
            .map_err(|e| Status::internal(format!("bad public key package JSON: {e}")))?;
        v["verifyingKey"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| Status::internal("missing verifyingKey in public key package"))
    }

    /// Extract a verifying share for a specific identifier from public key package JSON.
    fn extract_verifying_share(pkp_json: &str, id_hex: &str) -> Result<String, Status> {
        let v: serde_json::Value = serde_json::from_str(pkp_json)
            .map_err(|e| Status::internal(format!("bad public key package JSON: {e}")))?;
        v["verifyingShares"][id_hex]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| {
                Status::internal(format!(
                    "missing verifying share for {id_hex}"
                ))
            })
    }

    /// Build signing package JSON from commitments (parsed) and message hex.
    fn build_signing_package_json(
        commitments_json: &str,
        message_hex: &str,
    ) -> Result<String, Status> {
        // commitments_json from WASM is {"id": "comms_json_str", ...}
        // We need to parse each inner value for the signing package
        let comms_val: serde_json::Value = serde_json::from_str(commitments_json)
            .map_err(|e| Status::internal(format!("bad commitments JSON: {e}")))?;
        let comms_obj = comms_val
            .as_object()
            .ok_or_else(|| Status::internal("commitments not an object"))?;

        let mut parsed_comms = serde_json::Map::new();
        for (id, val) in comms_obj {
            let inner_json = val
                .as_str()
                .ok_or_else(|| Status::internal("commitment value not a string"))?;
            let parsed: serde_json::Value = serde_json::from_str(inner_json)
                .map_err(|e| Status::internal(format!("bad inner commitment JSON: {e}")))?;
            parsed_comms.insert(id.clone(), parsed);
        }

        let pkg = serde_json::json!({
            "commitments": serde_json::Value::Object(parsed_comms),
            "message": message_hex,
        });
        Ok(pkg.to_string())
    }

    /// Calculate spending amount from a transaction.
    fn calculate_spent_amount(
        &self,
        mgr: &mut WasmManager,
        full_tx: &[u8],
        pkp_json: &str,
        user_id_hex: &str,
    ) -> Result<i64, Status> {
        if full_tx.is_empty() {
            return Ok(0);
        }

        // PSBT format (Ark off-chain sends pass serialized PSBT as fullTransaction).
        // PSBT magic: 0x70736274ff ("psbt" + 0xff)
        if full_tx.len() > 5 && full_tx[..5] == [0x70, 0x73, 0x62, 0x74, 0xff] {
            if let Ok(psbt) = bitcoin::Psbt::deserialize(full_tx) {
                // Net spend = sum(inputs) - sum(outputs going back to user).
                // Ark tx structure: [recipient_out(s)..., change_out, anchor(0)]
                // Input total from witness_utxo = user's VTXO value.
                // Change output = second-to-last output (if >= 3 outputs).
                // Net spend = input_total - change_amount (anchor is 0).
                let input_total: u64 = psbt.inputs.iter()
                    .filter_map(|i| i.witness_utxo.as_ref())
                    .map(|utxo| utxo.value.to_sat())
                    .sum();
                let outputs = &psbt.unsigned_tx.output;
                let change_amount = if outputs.len() >= 3 {
                    // Second-to-last output is change back to user
                    outputs[outputs.len() - 2].value.to_sat()
                } else {
                    0
                };
                let net_spend = input_total.saturating_sub(change_amount);
                tracing::info!("PSBT policy eval: inputs={input_total}, change={change_amount}, net_spend={net_spend}");
                return Ok(net_spend as i64);
            }
        }

        // Legacy: explicit amount via "ARK_AMOUNT:<sats>" prefix.
        if full_tx.starts_with(b"ARK_AMOUNT:") {
            let amount_str = std::str::from_utf8(&full_tx[11..])
                .map_err(|e| Status::internal(format!("invalid ARK_AMOUNT: {e}")))?;
            let amount: i64 = amount_str.parse()
                .map_err(|e| Status::internal(format!("invalid ARK_AMOUNT value: {e}")))?;
            return Ok(amount);
        }

        let user = mgr
            .get_or_create_user(user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

        // Get tweaked public key package for P2TR script matching
        let tweaked_pkp_json = crypto_ops::pub_key_package_tweak(user, pkp_json, None)
            .map_err(|e| Status::internal(format!("tweak error: {e}")))?;

        let vk_hex = Self::extract_verifying_key(&tweaked_pkp_json)?;

        // Use bitcoin tx_parser
        let script_hex = crate::bitcoin::tx_parser::derive_p2tr_script_hex(&vk_hex)
            .map_err(|e| Status::internal(format!("P2TR derivation: {e}")))?;
        let spent = crate::bitcoin::tx_parser::calculate_spent_amount(
            full_tx,
            &script_hex,
            user.utxo_state.as_ref().map(|u| &u.utxos[..]).unwrap_or(&[]),
        )
        .map_err(|e| Status::internal(format!("tx parse: {e}")))?;

        Ok(spent)
    }

    /// Evaluate policy for a transaction spending amount.
    fn evaluate_policy_for_amount(
        policy_state: &PolicyState,
        spending_amount: i64,
    ) -> Option<String> {
        PolicyEngine::evaluate_policy(policy_state, spending_amount)
    }

    /// Generate a random base64url string for policy IDs.
    fn random_base64(bytes: usize) -> String {
        use base64::Engine;
        let mut rng = rand::thread_rng();
        let values: Vec<u8> = (0..bytes).map(|_| rng.gen()).collect();
        base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(&values)
    }

    fn now_ms() -> i64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64
    }

    /// Parse a JSON object of string-wrapped values into a HashMap.
    /// Used for parsing WASM resource JSON responses where values are JSON strings.
    fn parse_json_string_map(json: &str) -> Result<HashMap<String, String>, Status> {
        let v: serde_json::Value = serde_json::from_str(json)
            .map_err(|e| Status::internal(format!("bad JSON: {e}")))?;
        let obj = v
            .as_object()
            .ok_or_else(|| Status::internal("expected JSON object"))?;
        let mut result = HashMap::new();
        for (k, v) in obj {
            let s = v.as_str().map(|s| s.to_string()).unwrap_or_else(|| v.to_string());
            result.insert(k.clone(), s);
        }
        Ok(result)
    }
}

type ResponseStream =
    Pin<Box<dyn Stream<Item = Result<TransactionNotification, Status>> + Send>>;

#[tonic::async_trait]
impl MpcWallet for WalletService {
    // -----------------------------------------------------------------------
    // DKG
    // -----------------------------------------------------------------------

    #[tracing::instrument(skip_all, name = "svc::dkg_step1", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn dkg_step1(
        &self,
        request: Request<DkgStep1Request>,
    ) -> Result<Response<DkgStep1Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        let identifier_hex = hex::encode(&req.identifier);

        tracing::info!("[{user_id_hex}] DKGStep1 from {identifier_hex}");

        let step1_notify: Arc<Notify>;
        let step1_done: Arc<std::sync::atomic::AtomicBool>;

        {
            let mut mgr = self.wasm_manager.lock().unwrap();

            // Scope 1: Session setup + register participant
            {
                let user = mgr
                    .get_or_create_user(&user_id_hex)
                    .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

                if user.dkg_session.is_none() {
                    let h = crypto_ops::dkg_session_create(user)
                        .map_err(|e| Status::internal(format!("dkg_session_create: {e}")))?;
                    user.dkg_session = Some(h);
                    user.dkg_sync = Some((StepSync::new(), StepSync::new(), StepSync::new()));
                }
                let dkg_h = user.dkg_session.unwrap();

                // Only reset for restore when a previous DKG step1 completed.
                // Using step1.done (not round1_secret) avoids double-reset when
                // two concurrent restore calls race: the first resets and creates
                // fresh sync (done=false), so the second sees done=false and skips.
                let stale_session = req.is_restore
                    && user
                        .dkg_sync
                        .as_ref()
                        .map_or(false, |(s1, _, _)| s1.done.load(Ordering::SeqCst));
                if stale_session {
                    tracing::info!(
                        "[{user_id_hex}] DKGStep1: Resetting stale session for restore"
                    );
                    crypto_ops::dkg_session_reset(user, dkg_h)
                        .map_err(|e| Status::internal(format!("dkg_session_reset: {e}")))?;
                    user.dkg_sync =
                        Some((StepSync::new(), StepSync::new(), StepSync::new()));
                    user.round1_secret = None;
                    user.round2_secret = None;
                }

                if req.round1_package.is_empty() {
                    tracing::info!(
                        "[{user_id_hex}] DKGStep1: Registered passive receiver {identifier_hex}"
                    );
                    crypto_ops::dkg_session_insert_receiver_identifier(
                        user,
                        dkg_h,
                        &identifier_hex,
                    )
                    .map_err(|e| Status::internal(format!("insert_receiver: {e}")))?;
                } else {
                    tracing::info!(
                        "[{user_id_hex}] DKGStep1: Received round1 from {identifier_hex}"
                    );
                    crypto_ops::dkg_session_insert_round1_package(
                        user,
                        dkg_h,
                        &identifier_hex,
                        &req.round1_package,
                    )
                    .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;
                }
            }

            // Scope 2: Server init (if round1_secret not yet set)
            let needs_init = {
                let user = mgr
                    .get_or_create_user(&user_id_hex)
                    .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
                user.round1_secret.is_none()
            };

            if needs_init {
                let secret_hex = if req.is_restore {
                    tracing::info!(
                        "[{user_id_hex}] Server: Restore — looking up stored DKG secret"
                    );
                    let existing =
                        self.find_policy_by_recovery_id(&mut mgr, &user_id_hex)?;
                    let policy = existing.ok_or_else(|| {
                        Status::not_found(format!(
                            "No policy for recovery ID {user_id_hex}"
                        ))
                    })?;
                    policy.server_dkg_secret_hex.clone().ok_or_else(|| {
                        Status::internal("Existing policy has no stored DKG secret")
                    })?
                } else {
                    tracing::info!("[{user_id_hex}] Server: Generating DKG secrets");
                    let user = mgr
                        .get_or_create_user(&user_id_hex)
                        .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
                    crypto_ops::mod_n_random(user)
                        .map_err(|e| Status::internal(format!("mod_n_random: {e}")))?
                };

                // Scope 3: DKG part1 computation
                let user = mgr
                    .get_or_create_user(&user_id_hex)
                    .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

                let mut seed = [0u8; 32];
                rand::thread_rng().fill(&mut seed);
                let coefficients_json =
                    crypto_ops::generate_coefficients(user, THRESHOLD_COUNT - 1, &seed)
                        .map_err(|e| {
                            Status::internal(format!("generate_coefficients: {e}"))
                        })?;

                let result = crypto_ops::dkg_part1(
                    user,
                    TOTAL_PARTICIPANTS as u32,
                    THRESHOLD_COUNT,
                    &secret_hex,
                    &coefficients_json,
                )
                .map_err(|e| Status::internal(format!("dkg_part1: {e}")))?;

                let server_id_hex = crypto_ops::elem_base_mul(user, &secret_hex)
                    .map_err(|e| Status::internal(format!("elem_base_mul: {e}")))?;
                let server_id_bytes = hex::decode(&server_id_hex)
                    .map_err(|e| Status::internal(format!("hex decode: {e}")))?;

                let server_identifier_hex =
                    crypto_ops::identifier_derive(user, &server_id_bytes)
                        .map_err(|e| {
                            Status::internal(format!("identifier_derive: {e}"))
                        })?;

                user.round1_secret = Some(result.secret_handle);
                let dkg_h = user.dkg_session.unwrap();
                crypto_ops::dkg_session_set_server_id(user, dkg_h, &server_id_hex)
                    .map_err(|e| Status::internal(format!("set_server_id: {e}")))?;
                crypto_ops::dkg_session_set_server_internal_secret_hex(
                    user,
                    dkg_h,
                    &secret_hex,
                )
                .map_err(|e| Status::internal(format!("set_secret: {e}")))?;
                crypto_ops::dkg_session_insert_round1_package(
                    user,
                    dkg_h,
                    &server_identifier_hex,
                    &result.round1_package_json,
                )
                .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;
            }

            // Scope 4: Check if all participants ready
            {
                let user = mgr
                    .get_or_create_user(&user_id_hex)
                    .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
                let dkg_h = user.dkg_session.unwrap();
                let total = crypto_ops::dkg_session_total_participants(user, dkg_h)
                    .map_err(|e| Status::internal(format!("total_participants: {e}")))?;

                if total as usize >= TOTAL_PARTICIPANTS {
                    let (ref step1, _, _) = user
                        .dkg_sync
                        .as_ref()
                        .ok_or_else(|| Status::internal("no dkg sync"))?;
                    step1.done.store(true, Ordering::SeqCst);
                    step1.complete.notify_waiters();
                }

                let (ref step1, _, _) = user
                    .dkg_sync
                    .as_ref()
                    .ok_or_else(|| Status::internal("no dkg sync"))?;
                step1_notify = step1.complete.clone();
                step1_done = step1.done.clone();
            }
        }

        if !step1_done.load(Ordering::SeqCst) {
            step1_notify.notified().await;
        }

        // Build response
        let mut mgr = self.wasm_manager.lock().unwrap();
        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let dkg_h = user
            .dkg_session
            .ok_or_else(|| Status::internal("DKG session disappeared"))?;

        let round1_json = crypto_ops::dkg_session_get_round1_packages_json(user, dkg_h)
            .map_err(|e| Status::internal(format!("get_round1_packages: {e}")))?;
        let pkgs = Self::parse_json_string_map(&round1_json)?;

        let mut response = DkgStep1Response::default();
        for (id_hex, pkg_json) in &pkgs {
            response
                .round1_packages
                .insert(id_hex.clone(), pkg_json.clone());
        }

        Ok(Response::new(response))
    }

    #[tracing::instrument(skip_all, name = "svc::dkg_step2", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn dkg_step2(
        &self,
        request: Request<DkgStep2Request>,
    ) -> Result<Response<DkgStep2Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] DKGStep2");

        // Wait for step1
        let (step1_notify, step1_done) = {
            let mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .iter_users()
                .find(|(k, _)| *k == &user_id_hex)
                .map(|(_, u)| u)
                .ok_or_else(|| Status::internal("no user instance"))?;
            let (ref step1, _, _) = user
                .dkg_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no DKG sync"))?;
            (step1.complete.clone(), step1.done.clone())
        };

        if !step1_done.load(Ordering::SeqCst) {
            step1_notify.notified().await;
        }

        // Server round2 computation
        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let dkg_h = user
                .dkg_session
                .ok_or_else(|| Status::internal("no DKG session"))?;

            let server_id_hex = crypto_ops::dkg_session_get_server_id(user, dkg_h)
                .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
            if server_id_hex.is_empty() {
                return Err(Status::internal("server ID not initialized"));
            }
            let server_id_bytes = hex::decode(&server_id_hex)
                .map_err(|e| Status::internal(format!("hex decode: {e}")))?;

            let server_identifier_hex = crypto_ops::identifier_derive(user, &server_id_bytes)
                .map_err(|e| Status::internal(format!("identifier_derive: {e}")))?;

            let is_local_empty = crypto_ops::dkg_session_is_round2_local_empty(user, dkg_h)
                .map_err(|e| Status::internal(format!("is_round2_local_empty: {e}")))?;

            if is_local_empty {
                tracing::info!("[{user_id_hex}] DKGStep2: Server computing round2");

                let round1_pkgs_json =
                    crypto_ops::dkg_session_get_round1_packages_excluding_json(
                        user,
                        dkg_h,
                        &server_identifier_hex,
                    )
                    .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;
                let receiver_ids_json =
                    crypto_ops::dkg_session_get_receiver_ids_json(user, dkg_h)
                        .map_err(|e| Status::internal(format!("get_receiver_ids: {e}")))?;

                let round1_secret = user
                    .round1_secret
                    .take()
                    .ok_or_else(|| Status::internal("round1 secret missing"))?;

                let result = crypto_ops::dkg_part2(
                    user,
                    round1_secret,
                    &round1_pkgs_json,
                    &receiver_ids_json,
                )
                .map_err(|e| Status::internal(format!("dkg_part2: {e}")))?;

                user.round2_secret = Some(result.secret_handle);
                let local_pkgs = Self::parse_round2_result(&result.round2_packages_json)?;
                let local_json = serde_json::to_string(&local_pkgs)
                    .map_err(|e| Status::internal(format!("serialize: {e}")))?;
                crypto_ops::dkg_session_set_round2_local_json(user, dkg_h, &local_json)
                    .map_err(|e| Status::internal(format!("set_round2_local: {e}")))?;
            }

            let (_, ref step2, _) = user
                .dkg_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no dkg sync"))?;
            step2.done.store(true, Ordering::SeqCst);
            step2.complete.notify_waiters();
        }

        // Build response
        let mut mgr = self.wasm_manager.lock().unwrap();
        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let dkg_h = user
            .dkg_session
            .ok_or_else(|| Status::internal("DKG session disappeared"))?;

        let round1_json = crypto_ops::dkg_session_get_round1_packages_json(user, dkg_h)
            .map_err(|e| Status::internal(format!("get_round1_packages: {e}")))?;
        let pkgs = Self::parse_json_string_map(&round1_json)?;

        let mut response = DkgStep2Response::default();
        for (id_hex, pkg_json) in &pkgs {
            response
                .all_round1_packages
                .insert(id_hex.clone(), pkg_json.clone());
        }

        Ok(Response::new(response))
    }

    #[tracing::instrument(skip_all, name = "svc::dkg_step3", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn dkg_step3(
        &self,
        request: Request<DkgStep3Request>,
    ) -> Result<Response<DkgStep3Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        let sender_identifier_hex = hex::encode(&req.identifier);

        tracing::info!("[{user_id_hex}] DKGStep3 from {sender_identifier_hex}");

        // Wait for step2
        let (step2_notify, step2_done) = {
            let mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .iter_users()
                .find(|(k, _)| *k == &user_id_hex)
                .map(|(_, u)| u)
                .ok_or_else(|| Status::internal("no user instance"))?;
            let (_, ref step2, _) = user
                .dkg_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no DKG sync"))?;
            (step2.complete.clone(), step2.done.clone())
        };

        if !step2_done.load(Ordering::SeqCst) {
            step2_notify.notified().await;
        }

        // Process round2 packages and compute server key
        let step3_notify: Arc<Notify>;
        let step3_done: Arc<std::sync::atomic::AtomicBool>;
        let packages_for_me: HashMap<String, String>;

        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let dkg_h = user
                .dkg_session
                .ok_or_else(|| Status::internal("no DKG session"))?;

            let server_id_hex = crypto_ops::dkg_session_get_server_id(user, dkg_h)
                .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
            let server_id_bytes = hex::decode(&server_id_hex)
                .map_err(|e| Status::internal(format!("hex decode: {e}")))?;
            let server_identifier_hex_local =
                crypto_ops::identifier_derive(user, &server_id_bytes)
                    .map_err(|e| Status::internal(format!("identifier_derive: {e}")))?;

            // Store round2 packages from sender
            for (recipient_hex, pkg_json) in &req.round2_packages_for_others {
                if recipient_hex == &server_identifier_hex_local {
                    crypto_ops::dkg_session_insert_round2_received(
                        user,
                        dkg_h,
                        &sender_identifier_hex,
                        pkg_json,
                    )
                    .map_err(|e| Status::internal(format!("insert_round2: {e}")))?;
                }
            }

            // Insert all sender packages into relay
            let sender_pkgs_json = serde_json::to_string(&req.round2_packages_for_others)
                .map_err(|e| Status::internal(format!("serialize: {e}")))?;
            crypto_ops::dkg_session_insert_relay_packages(
                user,
                dkg_h,
                &sender_identifier_hex,
                &sender_pkgs_json,
            )
            .map_err(|e| Status::internal(format!("insert_relay: {e}")))?;

            // Check completion
            let relay_count = crypto_ops::dkg_session_relay_sender_count(user, dkg_h)
                .map_err(|e| Status::internal(format!("relay_sender_count: {e}")))?;

            if relay_count as usize >= TOTAL_PARTICIPANTS - 1 {
                crypto_ops::dkg_session_insert_relay_from_local(
                    user,
                    dkg_h,
                    &server_identifier_hex_local,
                )
                .map_err(|e| Status::internal(format!("insert_relay_from_local: {e}")))?;

                let (_, _, ref step3) = user
                    .dkg_sync
                    .as_ref()
                    .ok_or_else(|| Status::internal("no dkg sync"))?;
                step3.done.store(true, Ordering::SeqCst);
                step3.complete.notify_waiters();
            }

            let (_, _, ref step3) = user
                .dkg_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no dkg sync"))?;
            step3_notify = step3.complete.clone();
            step3_done = step3.done.clone();
        }

        // Wait for all participants to submit before fetching relay packages
        if !step3_done.load(Ordering::SeqCst) {
            step3_notify.notified().await;
        }

        // Now fetch relay packages (all participants have submitted)
        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
            let dkg_h = user
                .dkg_session
                .ok_or_else(|| Status::internal("no DKG session"))?;
            let relay_json = crypto_ops::dkg_session_get_relay_packages_for(
                user,
                dkg_h,
                &sender_identifier_hex,
            )
            .map_err(|e| Status::internal(format!("get_relay_for: {e}")))?;
            packages_for_me = Self::parse_json_string_map(&relay_json)?;
        }

        // Server key computation (once, when round2_secret is available)
        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            if user.round2_secret.is_some() {
                tracing::info!("[{user_id_hex}] DKGStep3: Server computing KeyPackage");

                let dkg_h = user.dkg_session.unwrap();

                let server_id_hex = crypto_ops::dkg_session_get_server_id(user, dkg_h)
                    .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
                let server_id_bytes = hex::decode(&server_id_hex)
                    .map_err(|e| Status::internal(format!("hex decode: {e}")))?;
                let server_identifier_hex_local =
                    crypto_ops::identifier_derive(user, &server_id_bytes)
                        .map_err(|e| Status::internal(format!("identifier_derive: {e}")))?;

                // Extract recovery ID from first non-server dealer's round1 package
                let round1_all_json =
                    crypto_ops::dkg_session_get_round1_packages_json(user, dkg_h)
                        .map_err(|e| Status::internal(format!("get_round1: {e}")))?;
                let round1_all: serde_json::Value = serde_json::from_str(&round1_all_json)
                    .map_err(|e| Status::internal(format!("parse round1: {e}")))?;

                let mut user_recovery_id_hex: Option<String> = None;
                if let Some(obj) = round1_all.as_object() {
                    for (id_hex, pkg_val_raw) in obj {
                        if id_hex != &server_identifier_hex_local {
                            let is_recv =
                                crypto_ops::dkg_session_is_receiver(user, dkg_h, id_hex)
                                    .map_err(|e| {
                                        Status::internal(format!("is_receiver: {e}"))
                                    })?;
                            if !is_recv {
                                // pkg_val_raw is a string-wrapped JSON; parse inner
                                let pkg_str =
                                    pkg_val_raw.as_str().unwrap_or("{}");
                                if let Ok(pkg_val) =
                                    serde_json::from_str::<serde_json::Value>(pkg_str)
                                {
                                    // verifyingKey is {"E": [byte, byte, ...]}
                                    if let Some(e_arr) = pkg_val["verifyingKey"]["E"].as_array() {
                                        let bytes: Vec<u8> = e_arr
                                            .iter()
                                            .filter_map(|v| v.as_u64().map(|n| n as u8))
                                            .collect();
                                        if !bytes.is_empty() {
                                            user_recovery_id_hex = Some(hex::encode(&bytes));
                                        }
                                    }
                                }
                                break;
                            }
                        }
                    }
                }

                let round1_pkgs_json =
                    crypto_ops::dkg_session_get_round1_packages_excluding_json(
                        user,
                        dkg_h,
                        &server_identifier_hex_local,
                    )
                    .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;
                let round2_received_json =
                    crypto_ops::dkg_session_get_round2_received_json(user, dkg_h)
                        .map_err(|e| Status::internal(format!("get_round2: {e}")))?;
                let receiver_ids_json =
                    crypto_ops::dkg_session_get_receiver_ids_json(user, dkg_h)
                        .map_err(|e| Status::internal(format!("get_receiver_ids: {e}")))?;

                let round2_secret = user.round2_secret.take().unwrap();
                let result = crypto_ops::dkg_part3(
                    user,
                    round2_secret,
                    &round1_pkgs_json,
                    &round2_received_json,
                    &receiver_ids_json,
                )
                .map_err(|e| Status::internal(format!("dkg_part3: {e}")))?;

                // Determine policy user ID
                let dkg_h = user.dkg_session.unwrap();
                let receiver_ids_json_raw =
                    crypto_ops::dkg_session_get_receiver_ids_json(user, dkg_h)
                        .map_err(|e| Status::internal(format!("get_receiver_ids: {e}")))?;
                let receiver_ids: Vec<String> =
                    serde_json::from_str(&receiver_ids_json_raw).unwrap_or_default();

                let policy_user_id: String;
                let user_signing_identifier_hex: Option<String>;

                if !receiver_ids.is_empty() {
                    let receiver_id_hex = &receiver_ids[0];
                    let vs_hex = Self::extract_verifying_share(
                        &result.public_key_package_json,
                        receiver_id_hex,
                    )?;
                    policy_user_id = vs_hex;
                    user_signing_identifier_hex = Some(receiver_id_hex.clone());
                } else {
                    policy_user_id = user_id_hex.clone();
                    user_signing_identifier_hex = None;
                }

                let server_dkg_secret_hex =
                    crypto_ops::dkg_session_get_server_internal_secret_hex(user, dkg_h)
                        .map_err(|e| Status::internal(format!("get_secret: {e}")))?;
                let recovery_id = user_recovery_id_hex.unwrap_or_default();

                // Check for restore — preserve spending history
                let mut preserved_history = Vec::new();
                for (_, u) in mgr.iter_users() {
                    if let Some(ps) = &u.policy_state {
                        if ps.recovery_id == recovery_id {
                            preserved_history = ps.spending_history.clone();
                            break;
                        }
                    }
                }
                if preserved_history.is_empty() {
                    // Look up old policy via recovery index
                    if let Ok(Some(old_user_id)) = self.persistence.get("policy_recovery_idx", &recovery_id) {
                        if let Ok(Some(json_str)) = self.persistence.get("policies", &old_user_id) {
                            if let Ok(ps) = serde_json::from_str::<PolicyState>(&json_str) {
                                if ps.recovery_id == recovery_id {
                                    preserved_history = ps.spending_history.clone();
                                    if let Err(e) = self.persistence.delete("policies", &old_user_id) {
                                        tracing::warn!("delete policies/{old_user_id} failed: {e}");
                                    }
                                    if let Err(e) = self.persistence.delete("policy_recovery_idx", &recovery_id) {
                                        tracing::warn!("delete policy_recovery_idx/{recovery_id} failed: {e}");
                                    }
                                    if let Err(e) = self.secret_store.delete_secret(&format!("dkg-secret.{old_user_id}")) {
                                        tracing::warn!("delete dkg-secret.{old_user_id} failed: {e}");
                                    }
                                }
                            }
                        }
                    }
                }

                let normal_policy = NormalPolicy {
                    id: "normal policies".to_string(),
                    key_package_json: result.key_package_json,
                    public_key_package_json: result.public_key_package_json,
                };

                let policy_state = PolicyState {
                    user_id: policy_user_id.clone(),
                    recovery_id,
                    user_signing_identifier_hex,
                    server_dkg_secret_hex: Some(server_dkg_secret_hex),
                    normal_policy,
                    protected_policies: HashMap::new(),
                    spending_history: preserved_history,
                };

                let _ = self.persist_policy(&policy_user_id, &policy_state);

                let user = mgr
                    .get_or_create_user(&user_id_hex)
                    .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
                user.policy_state = Some(policy_state);

                tracing::info!("[{user_id_hex}] DKG Complete");
            }
        }

        let mut response = DkgStep3Response::default();
        for (id_hex, pkg_json) in &packages_for_me {
            response
                .round2_packages_for_me
                .insert(id_hex.clone(), pkg_json.clone());
        }

        Ok(Response::new(response))
    }

    // -----------------------------------------------------------------------
    // Signing
    // -----------------------------------------------------------------------

    #[tracing::instrument(skip_all, name = "svc::sign_step1", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn sign_step1(
        &self,
        request: Request<SignStep1Request>,
    ) -> Result<Response<SignStep1Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] SignStep1");

        // Verify authentication
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_SIGN_STEP1)?;

        let step1_notify: Arc<Notify>;
        let step1_done: Arc<std::sync::atomic::AtomicBool>;

        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            self.load_policy_state(&mut mgr, &user_id_hex)?;

            let (policy_state, user_identifier_hex) = {
                let user = mgr
                    .get_or_create_user(&user_id_hex)
                    .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
                let ps = user
                    .policy_state
                    .as_ref()
                    .ok_or_else(|| Status::not_found("no policy state"))?
                    .clone();
                let uid = ps.user_signing_identifier_hex.clone().unwrap_or_else(|| {
                    crypto_ops::identifier_derive(user, &req.user_id).unwrap_or_default()
                });
                (ps, uid)
            };
            // user borrow dropped here — mgr is free again

            let mut server_kp_json = policy_state.normal_policy.key_package_json.clone();
            let pkp_json = policy_state.normal_policy.public_key_package_json.clone();

            // Policy evaluation: server independently evaluates from fullTransaction
            let ft_len = req.full_transaction.len();
            let ft_is_psbt = ft_len > 5 && req.full_transaction[..5] == [0x70, 0x73, 0x62, 0x74, 0xff];
            tracing::info!("[{user_id_hex}] SignStep1: fullTransaction len={ft_len}, is_psbt={ft_is_psbt}, script_path={}", req.script_path_spend);
            let spent_amount = self
                .calculate_spent_amount(&mut mgr, &req.full_transaction, &pkp_json, &user_id_hex)
                .unwrap_or(0);
            tracing::info!("[{user_id_hex}] SignStep1: spent_amount={spent_amount}");
            let selected_policy_id =
                Self::evaluate_policy_for_amount(&policy_state, spent_amount);
            tracing::info!("[{user_id_hex}] SignStep1: selected_policy_id={:?}", selected_policy_id);

            if let Some(ref policy_id) = selected_policy_id {
                if let Some(pp) = policy_state.protected_policies.get(policy_id) {
                    server_kp_json = pp.key_package_json.clone();
                    tracing::info!(
                        "[{user_id_hex}] SignStep1: Using Protected Policy {policy_id}"
                    );
                }
            } else {
                tracing::info!("[{user_id_hex}] SignStep1: Using Normal Policy");
            }

            // Re-acquire user ref from mgr (previous borrow was dropped for policy eval)
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            // Reset any stale signing session from a previous (possibly failed) attempt.
            // This mirrors the Dart server's `session.reset()` in signStep2's catch block,
            // ensuring each sign_step1 starts with a clean slate.
            if let Some(h) = user.signing_session {
                crypto_ops::signing_session_reset(user, h)
                    .map_err(|e| Status::internal(format!("signing_session_reset: {e}")))?;
                if let Some((ref mut s1, ref mut s2)) = user.signing_sync {
                    s1.reset();
                    s2.reset();
                }
                user.signing_nonce = None;
            }

            // Get or create signing session
            if user.signing_session.is_none() {
                let h = crypto_ops::signing_session_create(user)
                    .map_err(|e| Status::internal(format!("signing_session_create: {e}")))?;
                user.signing_session = Some(h);
                user.signing_sync = Some((StepSync::new(), StepSync::new()));
            }
            let sign_h = user.signing_session.unwrap();

            crypto_ops::signing_session_set_user_hiding_hex(
                user,
                sign_h,
                &hex::encode(&req.hiding_commitment),
            )
            .map_err(|e| Status::internal(format!("set_hiding: {e}")))?;
            crypto_ops::signing_session_set_user_binding_hex(
                user,
                sign_h,
                &hex::encode(&req.binding_commitment),
            )
            .map_err(|e| Status::internal(format!("set_binding: {e}")))?;

            if let Some(ref policy_id) = selected_policy_id {
                crypto_ops::signing_session_set_current_policy_id(user, sign_h, policy_id)
                    .map_err(|e| Status::internal(format!("set_policy_id: {e}")))?;
            }
            crypto_ops::signing_session_set_pending_amount(user, sign_h, spent_amount)
                .map_err(|e| Status::internal(format!("set_pending: {e}")))?;

            // Store script-path flag for SignStep2
            if req.script_path_spend {
                user.script_path_spend = true;
            }

            if !req.message_to_sign.is_empty() {
                let has_msg = crypto_ops::signing_session_has_message(user, sign_h)
                    .map_err(|e| Status::internal(format!("has_message: {e}")))?;
                if !has_msg {
                    crypto_ops::signing_session_set_message_to_sign(
                        user,
                        sign_h,
                        &hex::encode(&req.message_to_sign),
                    )
                    .map_err(|e| Status::internal(format!("set_message: {e}")))?;
                }
            }

            // Server nonce generation (once)
            if user.signing_nonce.is_none() {
                tracing::info!("[{user_id_hex}] SignStep1: Server generating nonce");
                let secret_share_hex = Self::extract_secret_share(&server_kp_json)?;
                let nonce_result = crypto_ops::new_nonce(user, &secret_share_hex)
                    .map_err(|e| Status::internal(format!("new_nonce: {e}")))?;

                user.signing_nonce = Some(nonce_result.nonce_handle);
                let sign_h = user.signing_session.unwrap();
                crypto_ops::signing_session_set_server_commitments_json(
                    user,
                    sign_h,
                    &nonce_result.commitments_json,
                )
                .map_err(|e| Status::internal(format!("set_server_comms: {e}")))?;
            }

            let sign_h = user.signing_session.unwrap();
            let server_identifier_hex = Self::extract_identifier(&server_kp_json)?;

            let user_hiding = crypto_ops::signing_session_get_user_hiding_hex(user, sign_h)
                .map_err(|e| Status::internal(format!("get_hiding: {e}")))?;
            let has_server_comms =
                crypto_ops::signing_session_has_server_commitments(user, sign_h)
                    .map_err(|e| Status::internal(format!("has_server_comms: {e}")))?;

            if !user_hiding.is_empty() && has_server_comms {
                let user_binding =
                    crypto_ops::signing_session_get_user_binding_hex(user, sign_h)
                        .map_err(|e| Status::internal(format!("get_binding: {e}")))?;
                let user_comms_json = serde_json::json!({
                    "hiding": user_hiding,
                    "binding": user_binding,
                })
                .to_string();

                let server_comms =
                    crypto_ops::signing_session_get_server_commitments_json(user, sign_h)
                        .map_err(|e| Status::internal(format!("get_server_comms: {e}")))?;

                crypto_ops::signing_session_insert_commitment(
                    user,
                    sign_h,
                    &server_identifier_hex,
                    &server_comms,
                )
                .map_err(|e| Status::internal(format!("insert_commit: {e}")))?;
                crypto_ops::signing_session_insert_commitment(
                    user,
                    sign_h,
                    &user_identifier_hex,
                    &user_comms_json,
                )
                .map_err(|e| Status::internal(format!("insert_commit: {e}")))?;

                let (ref step1, _) = user
                    .signing_sync
                    .as_ref()
                    .ok_or_else(|| Status::internal("no signing sync"))?;
                step1.done.store(true, Ordering::SeqCst);
                step1.complete.notify_waiters();
            }

            let (ref step1, _) = user
                .signing_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no signing sync"))?;
            step1_notify = step1.complete.clone();
            step1_done = step1.done.clone();
        }

        if !step1_done.load(Ordering::SeqCst) {
            step1_notify.notified().await;
        }

        // Build response
        let mut mgr = self.wasm_manager.lock().unwrap();
        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let sign_h = user
            .signing_session
            .ok_or_else(|| Status::internal("signing session disappeared"))?;

        let comms_json = crypto_ops::signing_session_get_commitments_json(user, sign_h)
            .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
        let comms_map = Self::parse_json_string_map(&comms_json)?;

        let mut response = SignStep1Response::default();
        for (id_hex, comms_json_str) in &comms_map {
            let comms_val: serde_json::Value = serde_json::from_str(comms_json_str)
                .map_err(|e| Status::internal(format!("bad commitments JSON: {e}")))?;
            let hiding_hex = comms_val["hiding"]
                .as_str()
                .ok_or_else(|| Status::internal("missing hiding"))?;
            let binding_hex = comms_val["binding"]
                .as_str()
                .ok_or_else(|| Status::internal("missing binding"))?;

            let hiding_bytes = hex::decode(hiding_hex)
                .map_err(|e| Status::internal(format!("hex decode hiding: {e}")))?;
            let binding_bytes = hex::decode(binding_hex)
                .map_err(|e| Status::internal(format!("hex decode binding: {e}")))?;

            response.commitments.insert(
                id_hex.clone(),
                sign_step1_response::Commitment {
                    hiding: hiding_bytes,
                    binding: binding_bytes,
                },
            );
        }

        let msg_hex = crypto_ops::signing_session_get_message_to_sign(user, sign_h)
            .map_err(|e| Status::internal(format!("get_message: {e}")))?;
        response.message_to_sign = if msg_hex.is_empty() {
            vec![]
        } else {
            hex::decode(&msg_hex).unwrap_or_default()
        };

        Ok(Response::new(response))
    }

    #[tracing::instrument(skip_all, name = "svc::sign_step2", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn sign_step2(
        &self,
        request: Request<SignStep2Request>,
    ) -> Result<Response<SignStep2Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] SignStep2");

        // Verify authentication
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_SIGN_STEP2)?;

        let step2_notify: Arc<Notify>;
        let step2_done: Arc<std::sync::atomic::AtomicBool>;

        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let policy_state = user
                .policy_state
                .as_ref()
                .ok_or_else(|| Status::not_found("no policy state"))?
                .clone();

            let user_identifier_hex = policy_state
                .user_signing_identifier_hex
                .clone()
                .unwrap_or_else(|| {
                    crypto_ops::identifier_derive(user, &req.user_id).unwrap_or_default()
                });

            let mut server_kp_json = policy_state.normal_policy.key_package_json.clone();

            let sign_h = user
                .signing_session
                .ok_or_else(|| Status::internal("no signing session"))?;

            let current_policy_id =
                crypto_ops::signing_session_get_current_policy_id(user, sign_h)
                    .map_err(|e| Status::internal(format!("get_policy_id: {e}")))?;

            if !current_policy_id.is_empty() {
                if let Some(pp) = policy_state.protected_policies.get(&current_policy_id) {
                    server_kp_json = pp.key_package_json.clone();
                }
            }

            let server_identifier_hex = Self::extract_identifier(&server_kp_json)?;

            // Store user's signature share
            let share_hex = hex::encode(&req.signature_share);
            crypto_ops::signing_session_insert_share(
                user,
                sign_h,
                &user_identifier_hex,
                &share_hex,
            )
            .map_err(|e| Status::internal(format!("insert_share: {e}")))?;

            // Server signing (once)
            let has_server_share =
                crypto_ops::signing_session_has_share(user, sign_h, &server_identifier_hex)
                    .map_err(|e| Status::internal(format!("has_share: {e}")))?;

            if !has_server_share && user.signing_nonce.is_some() {
                tracing::info!("[{user_id_hex}] SignStep2: Server computing share");

                let comms_json =
                    crypto_ops::signing_session_get_commitments_json(user, sign_h)
                        .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
                let msg_hex =
                    crypto_ops::signing_session_get_message_to_sign(user, sign_h)
                        .map_err(|e| Status::internal(format!("get_message: {e}")))?;

                let signing_pkg_json = Self::build_signing_package_json(&comms_json, &msg_hex)?;

                // Tweak server key for Taproot key path spending (skip for script-path)
                let sign_kp_json = if user.script_path_spend {
                    server_kp_json.clone()
                } else {
                    crypto_ops::key_package_tweak(user, &server_kp_json, None)
                        .map_err(|e| Status::internal(format!("key_package_tweak: {e}")))?
                };

                let nonce = user.signing_nonce.take().unwrap();
                let server_share_hex =
                    crypto_ops::frost_sign(user, &signing_pkg_json, nonce, &sign_kp_json)
                        .map_err(|e| Status::internal(format!("frost_sign: {e}")))?;

                let sign_h = user.signing_session.unwrap();
                crypto_ops::signing_session_insert_share(
                    user,
                    sign_h,
                    &server_identifier_hex,
                    &server_share_hex,
                )
                .map_err(|e| Status::internal(format!("insert_share: {e}")))?;
            }

            let sign_h = user.signing_session.unwrap();
            let share_count = crypto_ops::signing_session_share_count(user, sign_h)
                .map_err(|e| Status::internal(format!("share_count: {e}")))?;

            if share_count >= THRESHOLD_COUNT {
                let (_, ref step2) = user
                    .signing_sync
                    .as_ref()
                    .ok_or_else(|| Status::internal("no signing sync"))?;
                step2.done.store(true, Ordering::SeqCst);
                step2.complete.notify_waiters();
            }

            let (_, ref step2) = user
                .signing_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no signing sync"))?;
            step2_notify = step2.complete.clone();
            step2_done = step2.done.clone();
        }

        if !step2_done.load(Ordering::SeqCst) {
            step2_notify.notified().await;
        }

        // Aggregate
        let mut mgr = self.wasm_manager.lock().unwrap();
        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

        let policy_state = user
            .policy_state
            .as_ref()
            .ok_or_else(|| Status::not_found("no policy state"))?
            .clone();

        let mut server_pkp_json = policy_state.normal_policy.public_key_package_json.clone();

        let sign_h = user
            .signing_session
            .ok_or_else(|| Status::internal("no signing session"))?;

        let current_policy_id =
            crypto_ops::signing_session_get_current_policy_id(user, sign_h)
                .map_err(|e| Status::internal(format!("get_policy_id: {e}")))?;

        if !current_policy_id.is_empty() {
            if let Some(pp) = policy_state.protected_policies.get(&current_policy_id) {
                server_pkp_json = pp.public_key_package_json.clone();
            }
        }

        let comms_json = crypto_ops::signing_session_get_commitments_json(user, sign_h)
            .map_err(|e| Status::internal(format!("get_commitments: {e}")))?;
        let msg_hex = crypto_ops::signing_session_get_message_to_sign(user, sign_h)
            .map_err(|e| Status::internal(format!("get_message: {e}")))?;

        let signing_pkg_json = Self::build_signing_package_json(&comms_json, &msg_hex)?;

        let shares_json = crypto_ops::signing_session_get_shares_json(user, sign_h)
            .map_err(|e| Status::internal(format!("get_shares: {e}")))?;
        let pending = crypto_ops::signing_session_get_pending_amount(user, sign_h)
            .map_err(|e| Status::internal(format!("get_pending: {e}")))?;

        // Tweak public package for aggregation (skip for script-path)
        let agg_pkp_json = if user.script_path_spend {
            server_pkp_json.clone()
        } else {
            crypto_ops::pub_key_package_tweak(user, &server_pkp_json, None)
                .map_err(|e| Status::internal(format!("pub_key_package_tweak: {e}")))?
        };

        let agg_result_json = crypto_ops::frost_aggregate(
            user,
            &signing_pkg_json,
            &shares_json,
            &agg_pkp_json,
        )
        .map_err(|e| Status::internal(format!("frost_aggregate: {e}")))?;

        let agg_val: serde_json::Value = serde_json::from_str(&agg_result_json)
            .map_err(|e| Status::internal(format!("parse aggregate: {e}")))?;
        let r_hex = agg_val["R"]
            .as_str()
            .ok_or_else(|| Status::internal("missing R"))?;
        let z_hex = agg_val["Z"]
            .as_str()
            .ok_or_else(|| Status::internal("missing Z"))?;
        let r_bytes =
            hex::decode(r_hex).map_err(|e| Status::internal(format!("hex decode R: {e}")))?;
        let z_bytes =
            hex::decode(z_hex).map_err(|e| Status::internal(format!("hex decode Z: {e}")))?;

        tracing::info!("[{user_id_hex}] SignStep2: Aggregated");

        // Record spending
        if pending > 0 {
            if let Some(ps) = user.policy_state.as_mut() {
                ps.spending_history.push(SpendingEntry {
                    timestamp_ms: Self::now_ms(),
                    amount_sats: pending,
                });
                let _ = self.persist_policy(&user_id_hex, ps);
            }
        }

        // Reset session
        let sign_h = user.signing_session.unwrap();
        crypto_ops::signing_session_reset(user, sign_h)
            .map_err(|e| Status::internal(format!("signing_session_reset: {e}")))?;
        if let Some((ref mut s1, ref mut s2)) = user.signing_sync {
            s1.reset();
            s2.reset();
        }
        user.signing_nonce = None;
        user.script_path_spend = false;

        Ok(Response::new(SignStep2Response {
            r_point: r_bytes,
            z_scalar: z_bytes,
        }))
    }

    // -----------------------------------------------------------------------
    // Refresh
    // -----------------------------------------------------------------------

    #[tracing::instrument(skip_all, name = "svc::refresh_step1", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn refresh_step1(
        &self,
        request: Request<RefreshStep1Request>,
    ) -> Result<Response<RefreshStep1Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] RefreshStep1");

        self.verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_REFRESH_STEP1,
        )?;

        let step1_notify: Arc<Notify>;
        let step1_done: Arc<std::sync::atomic::AtomicBool>;

        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            self.load_policy_state(&mut mgr, &user_id_hex)?;

            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let policy_state = user
                .policy_state
                .as_ref()
                .ok_or_else(|| Status::not_found("no policy state"))?
                .clone();

            let user_identifier_hex = policy_state
                .user_signing_identifier_hex
                .clone()
                .unwrap_or_else(|| {
                    crypto_ops::identifier_derive(user, &req.user_id).unwrap_or_default()
                });

            // Auto-reset if previous refresh completed
            let prev_done = user
                .refresh_sync
                .as_ref()
                .map_or(false, |(_, _, step3)| step3.done.load(Ordering::SeqCst));

            if prev_done {
                tracing::info!("[{user_id_hex}] RefreshStep1: Resetting previous session");
                if let Some(h) = user.refresh_session {
                    crypto_ops::refresh_session_reset(user, h)
                        .map_err(|e| Status::internal(format!("refresh_reset: {e}")))?;
                }
                if let Some((s1, s2, s3)) = user.refresh_sync.as_mut() {
                    s1.reset();
                    s2.reset();
                    s3.reset();
                }
                user.round1_secret = None;
                user.round2_secret = None;
            }

            if user.refresh_session.is_none() {
                let h = crypto_ops::refresh_session_create(user)
                    .map_err(|e| Status::internal(format!("refresh_session_create: {e}")))?;
                user.refresh_session = Some(h);
                user.refresh_sync =
                    Some((StepSync::new(), StepSync::new(), StepSync::new()));
            }
            let refresh_h = user.refresh_session.unwrap();

            crypto_ops::refresh_session_insert_round1_package(
                user,
                refresh_h,
                &user_identifier_hex,
                &req.round1_package,
            )
            .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;

            // Server init (once)
            if user.round1_secret.is_none() {
                tracing::info!("[{user_id_hex}] Server: Generating Refresh secrets");

                let server_identifier_hex =
                    Self::extract_identifier(&policy_state.normal_policy.key_package_json)?;
                let server_id_hex = Self::extract_verifying_key(
                    &policy_state.normal_policy.public_key_package_json,
                )?;
                let server_id_bytes = hex::decode(&server_id_hex)
                    .map_err(|e| Status::internal(format!("hex decode: {e}")))?;

                let refresh_h = user.refresh_session.unwrap();
                crypto_ops::refresh_session_set_server_id(
                    user,
                    refresh_h,
                    &hex::encode(&server_id_bytes),
                )
                .map_err(|e| Status::internal(format!("set_server_id: {e}")))?;
                crypto_ops::refresh_session_set_server_identifier_hex(
                    user,
                    refresh_h,
                    &server_identifier_hex,
                )
                .map_err(|e| Status::internal(format!("set_server_id_hex: {e}")))?;

                let result = crypto_ops::dkg_refresh_part1(
                    user,
                    &server_identifier_hex,
                    2,
                    THRESHOLD_COUNT,
                    &[],
                )
                .map_err(|e| Status::internal(format!("dkg_refresh_part1: {e}")))?;

                user.round1_secret = Some(result.secret_handle);

                let refresh_h = user.refresh_session.unwrap();
                let creation_ms =
                    crypto_ops::refresh_session_get_refresh_creation_time_ms(user, refresh_h)
                        .map_err(|e| Status::internal(format!("get_creation_time: {e}")))?;
                if creation_ms == 0 {
                    crypto_ops::refresh_session_set_refresh_creation_time_ms(
                        user,
                        refresh_h,
                        Self::now_ms(),
                    )
                    .map_err(|e| Status::internal(format!("set_creation_time: {e}")))?;
                    crypto_ops::refresh_session_set_refresh_id(
                        user,
                        refresh_h,
                        &Self::random_base64(32),
                    )
                    .map_err(|e| Status::internal(format!("set_refresh_id: {e}")))?;
                    crypto_ops::refresh_session_set_refresh_threshold_amount(
                        user,
                        refresh_h,
                        req.threshold_amount,
                    )
                    .map_err(|e| Status::internal(format!("set_threshold: {e}")))?;
                    crypto_ops::refresh_session_set_refresh_interval(
                        user,
                        refresh_h,
                        req.interval,
                    )
                    .map_err(|e| Status::internal(format!("set_interval: {e}")))?;
                }

                crypto_ops::refresh_session_insert_round1_package(
                    user,
                    refresh_h,
                    &server_identifier_hex,
                    &result.round1_package_json,
                )
                .map_err(|e| Status::internal(format!("insert_round1: {e}")))?;
            }

            let refresh_h = user.refresh_session.unwrap();
            let round1_count = crypto_ops::refresh_session_round1_count(user, refresh_h)
                .map_err(|e| Status::internal(format!("round1_count: {e}")))?;

            if round1_count >= 2 {
                let (ref step1, _, _) = user
                    .refresh_sync
                    .as_ref()
                    .ok_or_else(|| Status::internal("no refresh sync"))?;
                step1.done.store(true, Ordering::SeqCst);
                step1.complete.notify_waiters();
            }

            let (ref step1, _, _) = user
                .refresh_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no refresh sync"))?;
            step1_notify = step1.complete.clone();
            step1_done = step1.done.clone();
        }

        if !step1_done.load(Ordering::SeqCst) {
            step1_notify.notified().await;
        }

        let mut mgr = self.wasm_manager.lock().unwrap();
        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let refresh_h = user
            .refresh_session
            .ok_or_else(|| Status::internal("refresh session disappeared"))?;

        let round1_json =
            crypto_ops::refresh_session_get_round1_packages_json(user, refresh_h)
                .map_err(|e| Status::internal(format!("get_round1: {e}")))?;
        let pkgs = Self::parse_json_string_map(&round1_json)?;

        let mut response = RefreshStep1Response::default();
        for (id_hex, pkg_json) in &pkgs {
            response
                .round1_packages
                .insert(id_hex.clone(), pkg_json.clone());
        }
        response.start_time =
            crypto_ops::refresh_session_get_refresh_creation_time_ms(user, refresh_h)
                .map_err(|e| Status::internal(format!("get_creation_time: {e}")))?;
        response.policy_id = crypto_ops::refresh_session_get_refresh_id(user, refresh_h)
            .map_err(|e| Status::internal(format!("get_refresh_id: {e}")))?;

        Ok(Response::new(response))
    }

    #[tracing::instrument(skip_all, name = "svc::refresh_step2", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn refresh_step2(
        &self,
        request: Request<RefreshStep2Request>,
    ) -> Result<Response<RefreshStep2Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] RefreshStep2");

        self.verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_REFRESH_STEP2,
        )?;

        // Wait for step1
        let (step1_notify, step1_done) = {
            let mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .iter_users()
                .find(|(k, _)| *k == &user_id_hex)
                .map(|(_, u)| u)
                .ok_or_else(|| Status::internal("no user instance"))?;
            let (ref step1, _, _) = user
                .refresh_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no refresh sync"))?;
            (step1.complete.clone(), step1.done.clone())
        };

        if !step1_done.load(Ordering::SeqCst) {
            step1_notify.notified().await;
        }

        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let refresh_h = user
                .refresh_session
                .ok_or_else(|| Status::internal("no refresh session"))?;

            let server_identifier_hex =
                crypto_ops::refresh_session_get_server_identifier_hex(user, refresh_h)
                    .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;
            if server_identifier_hex.is_empty() {
                return Err(Status::internal("server identifier not set"));
            }

            let is_local_empty =
                crypto_ops::refresh_session_is_round2_local_empty(user, refresh_h)
                    .map_err(|e| Status::internal(format!("is_local_empty: {e}")))?;

            if is_local_empty {
                tracing::info!("[{user_id_hex}] RefreshStep2: Server computing round2");

                let round1_pkgs_json =
                    crypto_ops::refresh_session_get_round1_packages_excluding_json(
                        user,
                        refresh_h,
                        &server_identifier_hex,
                    )
                    .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;

                let round1_secret = user
                    .round1_secret
                    .take()
                    .ok_or_else(|| Status::internal("round1 secret missing"))?;

                let result =
                    crypto_ops::dkg_refresh_part2(user, round1_secret, &round1_pkgs_json)
                        .map_err(|e| Status::internal(format!("dkg_refresh_part2: {e}")))?;

                user.round2_secret = Some(result.secret_handle);
                let local_pkgs = Self::parse_round2_result(&result.round2_packages_json)?;
                let local_json = serde_json::to_string(&local_pkgs)
                    .map_err(|e| Status::internal(format!("serialize: {e}")))?;
                let refresh_h = user.refresh_session.unwrap();
                crypto_ops::refresh_session_set_round2_local_json(
                    user,
                    refresh_h,
                    &local_json,
                )
                .map_err(|e| Status::internal(format!("set_round2_local: {e}")))?;
            }

            let (_, ref step2, _) = user
                .refresh_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no refresh sync"))?;
            step2.done.store(true, Ordering::SeqCst);
            step2.complete.notify_waiters();
        }

        let mut mgr = self.wasm_manager.lock().unwrap();
        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let refresh_h = user
            .refresh_session
            .ok_or_else(|| Status::internal("refresh session disappeared"))?;

        let round1_json =
            crypto_ops::refresh_session_get_round1_packages_json(user, refresh_h)
                .map_err(|e| Status::internal(format!("get_round1: {e}")))?;
        let pkgs = Self::parse_json_string_map(&round1_json)?;

        let mut response = RefreshStep2Response::default();
        for (id_hex, pkg_json) in &pkgs {
            response
                .all_round1_packages
                .insert(id_hex.clone(), pkg_json.clone());
        }

        Ok(Response::new(response))
    }

    #[tracing::instrument(skip_all, name = "svc::refresh_step3", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn refresh_step3(
        &self,
        request: Request<RefreshStep3Request>,
    ) -> Result<Response<RefreshStep3Response>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] RefreshStep3");

        self.verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_REFRESH_STEP3,
        )?;

        // Wait for step2
        let (step2_notify, step2_done) = {
            let mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .iter_users()
                .find(|(k, _)| *k == &user_id_hex)
                .map(|(_, u)| u)
                .ok_or_else(|| Status::internal("no user instance"))?;
            let (_, ref step2, _) = user
                .refresh_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no refresh sync"))?;
            (step2.complete.clone(), step2.done.clone())
        };

        if !step2_done.load(Ordering::SeqCst) {
            step2_notify.notified().await;
        }

        let step3_notify: Arc<Notify>;
        let step3_done: Arc<std::sync::atomic::AtomicBool>;
        let packages_for_me: HashMap<String, String>;

        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let policy_state = user
                .policy_state
                .as_ref()
                .ok_or_else(|| Status::not_found("no policy state"))?
                .clone();

            let user_identifier_hex = policy_state
                .user_signing_identifier_hex
                .clone()
                .unwrap_or_else(|| {
                    crypto_ops::identifier_derive(user, &req.user_id).unwrap_or_default()
                });

            let refresh_h = user
                .refresh_session
                .ok_or_else(|| Status::internal("no refresh session"))?;

            let server_identifier_hex =
                crypto_ops::refresh_session_get_server_identifier_hex(user, refresh_h)
                    .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;

            // Store round2 packages from user
            for (recipient_hex, pkg_json) in &req.round2_packages_for_others {
                if recipient_hex == &server_identifier_hex {
                    crypto_ops::refresh_session_insert_round2_received(
                        user,
                        refresh_h,
                        &user_identifier_hex,
                        pkg_json,
                    )
                    .map_err(|e| Status::internal(format!("insert_round2: {e}")))?;
                }
            }

            // Insert into relay
            let sender_pkgs_json = serde_json::to_string(&req.round2_packages_for_others)
                .map_err(|e| Status::internal(format!("serialize: {e}")))?;
            crypto_ops::refresh_session_insert_relay_packages(
                user,
                refresh_h,
                &user_identifier_hex,
                &sender_pkgs_json,
            )
            .map_err(|e| Status::internal(format!("insert_relay: {e}")))?;

            // n=2 for refresh
            let relay_count =
                crypto_ops::refresh_session_relay_sender_count(user, refresh_h)
                    .map_err(|e| Status::internal(format!("relay_count: {e}")))?;

            if relay_count >= 1 {
                crypto_ops::refresh_session_insert_relay_from_local(
                    user,
                    refresh_h,
                    &server_identifier_hex,
                )
                .map_err(|e| Status::internal(format!("insert_relay_from_local: {e}")))?;

                let (_, _, ref step3) = user
                    .refresh_sync
                    .as_ref()
                    .ok_or_else(|| Status::internal("no refresh sync"))?;
                step3.done.store(true, Ordering::SeqCst);
                step3.complete.notify_waiters();
            }

            let (_, _, ref step3) = user
                .refresh_sync
                .as_ref()
                .ok_or_else(|| Status::internal("no refresh sync"))?;
            step3_notify = step3.complete.clone();
            step3_done = step3.done.clone();

            // Build packages for the requester
            let relay_json = crypto_ops::refresh_session_get_relay_packages_for(
                user,
                refresh_h,
                &user_identifier_hex,
            )
            .map_err(|e| Status::internal(format!("get_relay_for: {e}")))?;
            packages_for_me = Self::parse_json_string_map(&relay_json)?;
        }

        if !step3_done.load(Ordering::SeqCst) {
            step3_notify.notified().await;
        }

        // Server key computation
        {
            let mut mgr = self.wasm_manager.lock().unwrap();
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            if user.round2_secret.is_some() {
                tracing::info!("[{user_id_hex}] RefreshStep3: Server computing new key");

                let policy_state = user
                    .policy_state
                    .as_ref()
                    .ok_or_else(|| Status::not_found("no policy state"))?
                    .clone();

                let refresh_h = user.refresh_session.unwrap();
                let server_identifier_hex =
                    crypto_ops::refresh_session_get_server_identifier_hex(user, refresh_h)
                        .map_err(|e| Status::internal(format!("get_server_id: {e}")))?;

                let round1_pkgs_json =
                    crypto_ops::refresh_session_get_round1_packages_excluding_json(
                        user,
                        refresh_h,
                        &server_identifier_hex,
                    )
                    .map_err(|e| Status::internal(format!("get_round1_excluding: {e}")))?;
                let round2_received_json =
                    crypto_ops::refresh_session_get_round2_received_json(user, refresh_h)
                        .map_err(|e| Status::internal(format!("get_round2: {e}")))?;

                let old_pkp_json =
                    policy_state.normal_policy.public_key_package_json.clone();
                let old_kp_json = policy_state.normal_policy.key_package_json.clone();

                let round2_secret = user.round2_secret.take().unwrap();
                let result = crypto_ops::dkg_refresh_part3(
                    user,
                    round2_secret,
                    &round1_pkgs_json,
                    &round2_received_json,
                    &old_pkp_json,
                    &old_kp_json,
                )
                .map_err(|e| Status::internal(format!("dkg_refresh_part3: {e}")))?;

                // Verify group key invariant
                let old_vk = Self::extract_verifying_key(&old_pkp_json)?;
                let new_vk =
                    Self::extract_verifying_key(&result.public_key_package_json)?;
                if old_vk != new_vk {
                    tracing::error!(
                        "[{user_id_hex}] CRITICAL: Group key changed during refresh!"
                    );
                    return Err(Status::internal(
                        "Protocol violation: Group key changed during refresh",
                    ));
                }

                let refresh_h = user.refresh_session.unwrap();
                let refresh_id =
                    crypto_ops::refresh_session_get_refresh_id(user, refresh_h)
                        .map_err(|e| Status::internal(format!("get_refresh_id: {e}")))?;
                let refresh_threshold =
                    crypto_ops::refresh_session_get_refresh_threshold_amount(user, refresh_h)
                        .map_err(|e| Status::internal(format!("get_threshold: {e}")))?;
                let refresh_creation_ms =
                    crypto_ops::refresh_session_get_refresh_creation_time_ms(user, refresh_h)
                        .map_err(|e| Status::internal(format!("get_creation_time: {e}")))?;
                let refresh_interval =
                    crypto_ops::refresh_session_get_refresh_interval(user, refresh_h)
                        .map_err(|e| Status::internal(format!("get_interval: {e}")))?;

                let new_policy = ProtectedPolicy {
                    id: refresh_id,
                    threshold_sats: refresh_threshold,
                    start_time_ms: refresh_creation_ms,
                    interval_seconds: refresh_interval,
                    key_package_json: result.key_package_json,
                    public_key_package_json: result.public_key_package_json,
                };

                if let Some(ps) = user.policy_state.as_mut() {
                    ps.protected_policies
                        .insert(new_policy.id.clone(), new_policy);
                    let _ = self.persist_policy(&user_id_hex, ps);
                }

                tracing::info!("[{user_id_hex}] RefreshStep3: New policy created");
            }
        }

        let mut response = RefreshStep3Response::default();
        for (id_hex, pkg_json) in &packages_for_me {
            response
                .round2_packages_for_me
                .insert(id_hex.clone(), pkg_json.clone());
        }

        Ok(Response::new(response))
    }

    // -----------------------------------------------------------------------
    // Policy
    // -----------------------------------------------------------------------

    async fn create_spending_policy(
        &self,
        _request: Request<CreateSpendingPolicyRequest>,
    ) -> Result<Response<CreateSpendingPolicyResponse>, Status> {
        Err(Status::unimplemented(
            "Use Refresh flow to create spending policies",
        ))
    }

    #[tracing::instrument(skip_all, name = "svc::get_policy_id", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn get_policy_id(
        &self,
        request: Request<GetPolicyIdRequest>,
    ) -> Result<Response<GetPolicyIdResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] GetPolicyId");

        self.verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_GET_POLICY_ID,
        )?;

        let mut mgr = self.wasm_manager.lock().unwrap();
        self.load_policy_state(&mut mgr, &user_id_hex)?;

        let pkp_json = {
            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
            user.policy_state
                .as_ref()
                .unwrap()
                .normal_policy
                .public_key_package_json
                .clone()
        };

        let spent_amount = self
            .calculate_spent_amount(&mut mgr, &req.tx_message, &pkp_json, &user_id_hex)
            .unwrap_or(0);

        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;
        let policy_state = user.policy_state.as_ref().unwrap();
        let policy_id =
            Self::evaluate_policy_for_amount(policy_state, spent_amount).unwrap_or_default();

        Ok(Response::new(GetPolicyIdResponse { policy_id }))
    }

    #[tracing::instrument(skip_all, name = "svc::update_policy", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn update_policy(
        &self,
        request: Request<UpdatePolicyRequest>,
    ) -> Result<Response<UpdatePolicyResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] UpdatePolicy: policy={}", req.policy_id);

        self.auth_verifier
            .validate_request_timing(req.timestamp_ms, &user_id_hex, OP_UPDATE_POLICY)?;

        let mut mgr = self.wasm_manager.lock().unwrap();
        self.load_policy_state(&mut mgr, &user_id_hex)?;

        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

        // Extract owned values from policy_state before mutable borrow
        let (vk_hex, existing) = {
            let policy_state = user
                .policy_state
                .as_ref()
                .ok_or_else(|| Status::not_found("no policy state"))?;

            if !policy_state.protected_policies.contains_key(&req.policy_id) {
                return Err(Status::not_found(format!(
                    "Policy {} not found",
                    req.policy_id
                )));
            }

            let vk = Self::extract_verifying_key(
                &policy_state.normal_policy.public_key_package_json,
            )?;
            let existing = policy_state
                .protected_policies
                .get(&req.policy_id)
                .unwrap()
                .clone();
            (vk, existing)
        };

        // Verify FROST signature
        let message = build_update_policy_message(
            &req.policy_id,
            req.threshold_sats,
            req.interval_seconds,
            req.timestamp_ms,
            &user_id_hex,
        );

        let r_hex = hex::encode(&req.frost_signature_r);
        let z_hex = hex::encode(&req.frost_signature_z);
        let sig_hex = format!("{}{}", r_hex, z_hex);

        let is_valid = crypto_ops::verify_schnorr_signature(user, &vk_hex, &message, &sig_hex)
            .map_err(|e| Status::internal(format!("verify error: {e}")))?;
        if !is_valid {
            return Err(Status::unauthenticated("Invalid recovery signature"));
        }
        let updated = ProtectedPolicy {
            id: existing.id,
            threshold_sats: req.threshold_sats,
            start_time_ms: existing.start_time_ms,
            interval_seconds: req.interval_seconds,
            key_package_json: existing.key_package_json,
            public_key_package_json: existing.public_key_package_json,
        };

        if let Some(ps) = user.policy_state.as_mut() {
            ps.protected_policies.insert(updated.id.clone(), updated);
            self.persist_policy(&user_id_hex, ps)?;
        }

        tracing::info!("[{user_id_hex}] UpdatePolicy: success");
        Ok(Response::new(UpdatePolicyResponse { success: true }))
    }

    #[tracing::instrument(skip_all, name = "svc::delete_policy", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn delete_policy(
        &self,
        request: Request<DeletePolicyRequest>,
    ) -> Result<Response<DeletePolicyResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] DeletePolicy: policy={}", req.policy_id);

        self.auth_verifier
            .validate_request_timing(req.timestamp_ms, &user_id_hex, OP_DELETE_POLICY)?;

        let mut mgr = self.wasm_manager.lock().unwrap();
        self.load_policy_state(&mut mgr, &user_id_hex)?;

        let user = mgr
            .get_or_create_user(&user_id_hex)
            .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

        let policy_state = user
            .policy_state
            .as_ref()
            .ok_or_else(|| Status::not_found("no policy state"))?;

        if !policy_state.protected_policies.contains_key(&req.policy_id) {
            return Err(Status::not_found(format!(
                "Policy {} not found",
                req.policy_id
            )));
        }

        let message = build_delete_policy_message(&req.policy_id, req.timestamp_ms, &user_id_hex);

        let r_hex = hex::encode(&req.frost_signature_r);
        let z_hex = hex::encode(&req.frost_signature_z);
        let sig_hex = format!("{}{}", r_hex, z_hex);

        let vk_hex =
            Self::extract_verifying_key(&policy_state.normal_policy.public_key_package_json)?;

        let is_valid = crypto_ops::verify_schnorr_signature(user, &vk_hex, &message, &sig_hex)
            .map_err(|e| Status::internal(format!("verify error: {e}")))?;
        if !is_valid {
            return Err(Status::unauthenticated("Invalid recovery signature"));
        }

        if let Some(ps) = user.policy_state.as_mut() {
            ps.protected_policies.remove(&req.policy_id);
            self.persist_policy(&user_id_hex, ps)?;
        }

        tracing::info!("[{user_id_hex}] DeletePolicy: success");
        Ok(Response::new(DeletePolicyResponse { success: true }))
    }

    // -----------------------------------------------------------------------
    // Bitcoin
    // -----------------------------------------------------------------------

    #[tracing::instrument(skip_all, name = "svc::broadcast_transaction", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn broadcast_transaction(
        &self,
        request: Request<BroadcastTransactionRequest>,
    ) -> Result<Response<BroadcastTransactionResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] BroadcastTransaction");

        let tx_id = self
            .bitcoin_history
            .lock()
            .await
            .broadcast_transaction(&req.tx_hex)
            .await
            .map_err(|e| Status::internal(format!("broadcast error: {e}")))?;

        tracing::info!("[{user_id_hex}] Broadcast txid: {tx_id}");

        Ok(Response::new(BroadcastTransactionResponse { tx_id }))
    }

    #[tracing::instrument(skip_all, name = "svc::fetch_history", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn fetch_history(
        &self,
        request: Request<FetchHistoryRequest>,
    ) -> Result<Response<FetchHistoryResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] FetchHistory");

        self.verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_FETCH_HISTORY,
        )?;

        // Pre-compute tweaked pubkeys for all policies while holding the lock
        let (policy_state_clone, tweaked_map) = {
            let mut mgr = self.wasm_manager.lock().unwrap();
            self.load_policy_state(&mut mgr, &user_id_hex)?;

            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let ps = user
                .policy_state
                .clone()
                .ok_or_else(|| Status::not_found("no policy state"))?;

            let mut map = std::collections::HashMap::new();

            // Normal policy
            let tweaked = crypto_ops::pub_key_package_tweak(
                user,
                &ps.normal_policy.public_key_package_json,
                None,
            )
            .map_err(|e| Status::internal(format!("tweak error: {e}")))?;
            let vk = Self::extract_verifying_key(&tweaked)?;
            map.insert(ps.normal_policy.public_key_package_json.clone(), vk);

            // Protected policies
            for pp in ps.protected_policies.values() {
                let tweaked = crypto_ops::pub_key_package_tweak(
                    user,
                    &pp.public_key_package_json,
                    None,
                )
                .map_err(|e| Status::internal(format!("tweak error: {e}")))?;
                let vk = Self::extract_verifying_key(&tweaked)?;
                map.insert(pp.public_key_package_json.clone(), vk);
            }

            (ps, map)
        };
        // Lock dropped

        let tweaked_fn = move |pkp_json: &str| -> Result<String, String> {
            tweaked_map
                .get(pkp_json)
                .cloned()
                .ok_or_else(|| format!("no tweaked key for pkp"))
        };

        let bh = self.bitcoin_history.lock().await;
        let utxos = bh
            .get_utxos(&policy_state_clone, &tweaked_fn)
            .await
            .map_err(|e| Status::internal(format!("electrum error: {e}")))?;

        let response_utxos: Vec<UtxoInfo> = utxos
            .into_iter()
            .map(|u| UtxoInfo {
                tx_hash: u.tx_hash,
                vout: u.vout as i32,
                amount: u.amount_sats,
            })
            .collect();

        Ok(Response::new(FetchHistoryResponse {
            utxos: response_utxos,
        }))
    }

    #[tracing::instrument(skip_all, name = "svc::fetch_recent_transactions", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn fetch_recent_transactions(
        &self,
        request: Request<FetchRecentTransactionsRequest>,
    ) -> Result<Response<FetchRecentTransactionsResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] FetchRecentTransactions");

        self.verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_FETCH_RECENT_TXS,
        )?;

        // Pre-compute tweaked pubkeys while holding the lock
        let (policy_state_clone, tweaked_map) = {
            let mut mgr = self.wasm_manager.lock().unwrap();
            self.load_policy_state(&mut mgr, &user_id_hex)?;

            let user = mgr
                .get_or_create_user(&user_id_hex)
                .map_err(|e| Status::internal(format!("WASM init error: {e}")))?;

            let ps = user
                .policy_state
                .clone()
                .ok_or_else(|| Status::not_found("no policy state"))?;

            let mut map = std::collections::HashMap::new();

            let tweaked = crypto_ops::pub_key_package_tweak(
                user,
                &ps.normal_policy.public_key_package_json,
                None,
            )
            .map_err(|e| Status::internal(format!("tweak error: {e}")))?;
            let vk = Self::extract_verifying_key(&tweaked)?;
            map.insert(ps.normal_policy.public_key_package_json.clone(), vk);

            for pp in ps.protected_policies.values() {
                let tweaked = crypto_ops::pub_key_package_tweak(
                    user,
                    &pp.public_key_package_json,
                    None,
                )
                .map_err(|e| Status::internal(format!("tweak error: {e}")))?;
                let vk = Self::extract_verifying_key(&tweaked)?;
                map.insert(pp.public_key_package_json.clone(), vk);
            }

            (ps, map)
        };

        let tweaked_fn = move |pkp_json: &str| -> Result<String, String> {
            tweaked_map
                .get(pkp_json)
                .cloned()
                .ok_or_else(|| format!("no tweaked key for pkp"))
        };

        let bh = self.bitcoin_history.lock().await;
        let txs = bh
            .get_recent_transactions(&policy_state_clone, &tweaked_fn)
            .await
            .map_err(|e| Status::internal(format!("electrum error: {e}")))?;

        let response_txs: Vec<TransactionSummary> = txs
            .into_iter()
            .map(|t| TransactionSummary {
                tx_hash: t.tx_hash,
                amount_sats: t.amount_sats,
                timestamp: t.timestamp as i64,
                is_pending: t.is_pending,
            })
            .collect();

        Ok(Response::new(FetchRecentTransactionsResponse {
            transactions: response_txs,
        }))
    }

    type SubscribeToHistoryStream = ResponseStream;

    async fn subscribe_to_history(
        &self,
        request: Request<SubscribeToHistoryRequest>,
    ) -> Result<Response<Self::SubscribeToHistoryStream>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);

        tracing::info!("[{user_id_hex}] SubscribeToHistory");

        self.verify_auth(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_SUBSCRIBE_HISTORY,
        )?;

        // Create a notification stream channel
        let (tx, rx) = tokio::sync::mpsc::channel(32);

        // Keep sender alive until client disconnects
        tokio::spawn(async move {
            let _ = tx;
            tokio::signal::ctrl_c().await.ok();
        });

        let stream = tokio_stream::wrappers::ReceiverStream::new(rx);
        Ok(Response::new(
            Box::pin(stream) as Self::SubscribeToHistoryStream
        ))
    }

    // -----------------------------------------------------------------------
    // Ark
    // -----------------------------------------------------------------------

    #[tracing::instrument(skip_all, name = "svc::get_ark_info", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn get_ark_info(
        &self,
        request: Request<GetArkInfoRequest>,
    ) -> Result<Response<GetArkInfoResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!("[{user_id_hex}] GetArkInfo");
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_GET_ARK_INFO)?;

        let asp = self.require_asp()?;
        let info = asp.lock().await.get_info().await
            .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?;

        Ok(Response::new(GetArkInfoResponse {
            signer_pubkey: info.signer_pubkey,
            forfeit_pubkey: info.forfeit_pubkey,
            network: info.network,
            session_duration: info.session_duration,
            unilateral_exit_delay: info.unilateral_exit_delay,
            boarding_exit_delay: info.boarding_exit_delay,
            vtxo_min_amount: info.vtxo_min_amount,
            dust: info.dust,
            checkpoint_tapscript: info.checkpoint_tapscript,
            forfeit_address: info.forfeit_address,
        }))
    }

    #[tracing::instrument(skip_all, name = "svc::get_ark_address", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn get_ark_address(
        &self,
        request: Request<GetArkAddressRequest>,
    ) -> Result<Response<GetArkAddressResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!("[{user_id_hex}] GetArkAddress");
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_GET_ARK_ADDRESS)?;

        let asp = self.require_asp()?;
        let mut asp_guard = asp.lock().await;

        // Ensure we have ASP info cached
        let info = match &asp_guard.info {
            Some(i) => i.clone(),
            None => asp_guard.get_info().await
                .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?,
        };
        drop(asp_guard);

        // Get the user's group x-only pubkey from policy state
        let owner_pk_hex = self.get_user_xonly_pubkey(&user_id_hex)?;
        // Compute scriptPubKey for debugging
        if let Ok(spk_hex) = ark::client::vtxo_script_pubkey_hex(
            &owner_pk_hex, &info.signer_pubkey, info.unilateral_exit_delay as u32,
            ark::client::parse_network(&info.network).unwrap_or(bitcoin::Network::Regtest),
        ) {
            tracing::info!("[{user_id_hex}] GetArkAddress: owner_pk={owner_pk_hex}, exit_delay={}, script_pubkey={spk_hex}", info.unilateral_exit_delay);
        } else {
            tracing::info!("[{user_id_hex}] GetArkAddress: owner_pk={owner_pk_hex}, exit_delay={}", info.unilateral_exit_delay);
        }

        let network = ark::client::parse_network(&info.network)
            .map_err(|e| Status::internal(e))?;

        let exit_delay = info.unilateral_exit_delay as u32;
        let ark_addr = ark::client::ark_address(
            &owner_pk_hex,
            &info.signer_pubkey,
            exit_delay,
            network,
        ).map_err(|e| Status::internal(format!("ark_address: {e}")))?;

        // Register script for VTXO stream matching
        self.register_user_vtxo_script(&user_id_hex, &owner_pk_hex).await;

        Ok(Response::new(GetArkAddressResponse {
            ark_address: ark_addr,
        }))
    }

    #[tracing::instrument(skip_all, name = "svc::get_boarding_address", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn get_boarding_address(
        &self,
        request: Request<GetBoardingAddressRequest>,
    ) -> Result<Response<GetBoardingAddressResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!("[{user_id_hex}] GetBoardingAddress");
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_GET_BOARDING_ADDRESS)?;

        let asp = self.require_asp()?;
        let mut asp_guard = asp.lock().await;

        let info = match &asp_guard.info {
            Some(i) => i.clone(),
            None => asp_guard.get_info().await
                .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?,
        };
        drop(asp_guard);

        let owner_pk_hex = self.get_user_xonly_pubkey(&user_id_hex)?;

        let network = ark::client::parse_network(&info.network)
            .map_err(|e| Status::internal(e))?;

        let exit_delay = info.boarding_exit_delay as u32;
        let boarding_addr = ark::client::boarding_address(
            &owner_pk_hex,
            &info.signer_pubkey,
            exit_delay,
            network,
        ).map_err(|e| Status::internal(format!("boarding_address: {e}")))?;

        Ok(Response::new(GetBoardingAddressResponse {
            boarding_address: boarding_addr,
        }))
    }

    #[tracing::instrument(skip_all, name = "svc::check_boarding_balance", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn check_boarding_balance(
        &self,
        request: Request<CheckBoardingBalanceRequest>,
    ) -> Result<Response<CheckBoardingBalanceResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_CHECK_BOARDING_BALANCE)?;

        let asp = self.require_asp()?;
        let mut asp_guard = asp.lock().await;
        let info = match &asp_guard.info {
            Some(i) => i.clone(),
            None => asp_guard.get_info().await
                .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?,
        };
        drop(asp_guard);

        let owner_pk_hex = self.get_user_xonly_pubkey(&user_id_hex)?;
        let network = ark::client::parse_network(&info.network)
            .map_err(|e| Status::internal(e))?;
        let exit_delay = info.boarding_exit_delay as u32;
        let boarding_addr = ark::client::boarding_address(
            &owner_pk_hex, &info.signer_pubkey, exit_delay, network,
        ).map_err(|e| Status::internal(format!("boarding_address: {e}")))?;

        let addr: bitcoin::Address<bitcoin::address::NetworkUnchecked> = boarding_addr.parse()
            .map_err(|e| Status::internal(format!("parse addr: {e}")))?;
        let addr = addr.require_network(network)
            .map_err(|e| Status::internal(format!("network mismatch: {e}")))?;
        let script_hex = hex::encode(addr.script_pubkey().as_bytes());
        let script_hash = crate::bitcoin::tx_parser::derive_script_hash(&script_hex)
            .map_err(|e| Status::internal(format!("script_hash: {e}")))?;

        let history = self.bitcoin_history.lock().await;
        let utxos = history.list_unspent_by_script_hash(&script_hash).await
            .map_err(|e| Status::internal(format!("list_unspent: {e}")))?;
        drop(history);

        let balance: u64 = utxos.iter().map(|u| u.amount_sats as u64).sum();
        let utxo_count = utxos.len() as u32;
        tracing::info!("[{user_id_hex}] CheckBoardingBalance: {utxo_count} UTXOs, balance={balance}");

        Ok(Response::new(CheckBoardingBalanceResponse {
            balance,
            utxo_count,
        }))
    }

    #[tracing::instrument(skip_all, name = "svc::list_vtxos", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn list_vtxos(
        &self,
        request: Request<ListVtxosRequest>,
    ) -> Result<Response<ListVtxosResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_LIST_VTXOS)?;

        self.require_asp()?;

        let store = self.vtxo_store.lock().await;
        let user_vtxos = store.get(&user_id_hex);
        let mut vtxos = Vec::new();
        let mut total_balance: u64 = 0;
        if let Some(entries) = user_vtxos {
            for (txid, vout, amount, exit_delay) in entries.iter() {
                total_balance += amount;
                tracing::info!("[{user_id_hex}] ListVtxos: vtxo {txid}:{vout} amount={amount} exit_delay={exit_delay}");
                vtxos.push(VtxoInfo {
                    txid: txid.clone(),
                    vout: *vout,
                    amount: *amount,
                    created_at: 0,
                    expires_at: 0,
                    status: "confirmed".to_string(),
                    is_preconfirmed: false,
                    exit_delay: *exit_delay,
                });
            }
        }
        tracing::info!("[{user_id_hex}] ListVtxos: returning {} vtxos, balance={total_balance}", vtxos.len());

        Ok(Response::new(ListVtxosResponse {
            vtxos,
            total_balance,
        }))
    }

    #[tracing::instrument(skip_all, name = "svc::list_ark_transactions", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn list_ark_transactions(
        &self,
        request: Request<ListArkTransactionsRequest>,
    ) -> Result<Response<ListArkTransactionsResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_LIST_ARK_TXS)?;

        let history = self.ark_tx_history.lock().await;
        let transactions = history.get(&user_id_hex)
            .map(|entries| entries.iter().map(|e| ArkTransactionSummary {
                tx_type: e.tx_type.clone(),
                amount_sats: e.amount_sats,
                txid: e.txid.clone(),
                timestamp: e.timestamp,
            }).collect())
            .unwrap_or_default();

        Ok(Response::new(ListArkTransactionsResponse { transactions }))
    }

    #[tracing::instrument(skip_all, name = "svc::send_vtxo", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn send_vtxo(
        &self,
        request: Request<SendVtxoRequest>,
    ) -> Result<Response<SendVtxoResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!(
            "[{user_id_hex}] SendVtxo to={} amount={}",
            req.recipient_ark_address, req.amount
        );
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_SEND_VTXO)?;

        let asp_arc = self.require_asp()?.clone();
        let has_signatures = !req.signed_messages.is_empty();

        // Check for existing send session.
        let mut sessions = self.send_sessions.lock().await;
        let existing = sessions.remove(&user_id_hex);
        drop(sessions);

        match (existing, has_signatures) {
            // Phase 1: No session (or stale session) -> build transactions, return sighashes
            (None, false) | (Some(_), false) => {
                let (owner_pk_hex, _dkg_secret_hex) = self.get_user_ark_keys(&user_id_hex)?;

                let mut asp = asp_arc.lock().await;
                let info = match &asp.info {
                    Some(i) => i.clone(),
                    None => asp.get_info().await
                        .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?,
                };
                drop(asp);

                // Gather user's confirmed VTXOs for coin selection.
                let store = self.vtxo_store.lock().await;
                let user_vtxos = store.get(&user_id_hex).cloned().unwrap_or_default();
                drop(store);

                tracing::info!(
                    "[{user_id_hex}] SendVtxo: spending VTXOs: {:?}",
                    user_vtxos
                );
                if user_vtxos.is_empty() {
                    return Err(Status::failed_precondition("no VTXOs available for sending"));
                }

                // Simple coin selection: use all VTXOs.
                let total_available: u64 = user_vtxos.iter().map(|(_, _, a, _)| a).sum();
                if total_available < req.amount {
                    return Err(Status::failed_precondition(format!(
                        "insufficient balance: have {} sats, need {} sats",
                        total_available, req.amount
                    )));
                }

                let vtxo_inputs: Vec<ark::client::send::SendVtxoInput> = user_vtxos
                    .iter()
                    .map(|(txid, vout, amount, _)| ark::client::send::SendVtxoInput {
                        txid: txid.clone(),
                        vout: *vout,
                        amount_sats: *amount,
                    })
                    .collect();

                // Use the exit_delay from the first VTXO (all VTXOs in a send
                // should have the same type: boarding or refreshed).
                let exit_delay = user_vtxos.first().map(|(_, _, _, d)| *d)
                    .unwrap_or(info.unilateral_exit_delay as u32);

                // Build change address (send change back to self).
                // Always use unilateral_exit_delay for change, like the reference client.
                let network = ark::client::parse_network(&info.network)
                    .map_err(|e| Status::internal(e))?;
                let change_exit_delay = info.unilateral_exit_delay as u32;
                let change_addr = if total_available > req.amount {
                    let addr = ark::client::ark_address(
                        &owner_pk_hex, &info.signer_pubkey, change_exit_delay, network,
                    ).map_err(|e| Status::internal(format!("ark_address: {e}")))?;
                    Some(addr)
                } else {
                    None
                };

                let (session, sighashes) = ark::client::send::SendSession::build(
                    &owner_pk_hex,
                    &vtxo_inputs,
                    &req.recipient_ark_address,
                    req.amount,
                    change_addr.as_deref(),
                    exit_delay,
                    &info,
                ).map_err(|e| Status::internal(format!("SendSession::build: {e}")))?;

                // Evaluate spending policy for this amount
                let send_policy_id = {
                    let mut mgr = self.wasm_manager.lock().unwrap();
                    self.load_policy_state(&mut mgr, &user_id_hex).ok();
                    let policy_id = if let Ok(user) = mgr.get_or_create_user(&user_id_hex) {
                        if let Some(ps) = user.policy_state.as_ref() {
                            Self::evaluate_policy_for_amount(ps, req.amount as i64)
                        } else {
                            None
                        }
                    } else {
                        None
                    };
                    policy_id.unwrap_or_default()
                };

                if !send_policy_id.is_empty() {
                    tracing::info!(
                        "[{user_id_hex}] SendVtxo: policy triggered: {send_policy_id}"
                    );
                }

                let mut sessions = self.send_sessions.lock().await;
                sessions.insert(user_id_hex, (session, change_exit_delay));

                Ok(Response::new(SendVtxoResponse {
                    status: send_vtxo_response::Status::SigningRequired as i32,
                    messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                    script_path_spend: true,
                    ark_txid: String::new(),
                    error_message: String::new(),
                    policy_id: send_policy_id,
                }))
            }

            // Phase 2: Has session + signatures -> sign + submit to ASP
            (Some((mut session, change_exit_delay)), true) => {
                let signatures: Vec<[u8; 64]> = req.signed_messages.iter().map(|s| {
                    if s.len() != 64 {
                        return Err(Status::invalid_argument(
                            format!("signature must be 64 bytes, got {}", s.len())
                        ));
                    }
                    let mut arr = [0u8; 64];
                    arr.copy_from_slice(s);
                    Ok(arr)
                }).collect::<Result<Vec<_>, _>>()?;

                session.sign_with_frost(signatures)
                    .map_err(|e| Status::internal(format!("sign_with_frost: {e}")))?;

                let mut asp = asp_arc.lock().await;
                let ark_txid = session.submit(&mut asp).await
                    .map_err(|e| Status::internal(format!("submit: {e}")))?;

                // Update VTXO store: replace spent VTXOs with change (if any).
                let change = session.change_vtxo();
                let mut store = self.vtxo_store.lock().await;
                store.remove(&user_id_hex);
                if let Some((change_txid, change_vout, change_amount)) = change {
                    tracing::info!(
                        "[{user_id_hex}] SendVtxo: change VTXO txid={}, vout={}, amount={}, exit_delay={}",
                        change_txid, change_vout, change_amount, change_exit_delay
                    );
                    store.entry(user_id_hex.clone()).or_default()
                        .push((change_txid, change_vout, change_amount, change_exit_delay));
                }
                tracing::info!(
                    "[{user_id_hex}] SendVtxo: sent, ark_txid={ark_txid}"
                );
                // Persist vtxo_store
                if let Some(vtxos) = store.get(&user_id_hex) {
                    self.save_user_vtxos(&user_id_hex, vtxos);
                }
                {
                    let mut history = self.ark_tx_history.lock().await;
                    history.entry(user_id_hex.clone()).or_default()
                        .push(ArkTxEntry {
                            tx_type: "send".into(),
                            amount_sats: -(req.amount as i64),
                            txid: ark_txid.clone(),
                            timestamp: now_secs(),
                        });
                    if let Some(entries) = history.get(&user_id_hex) {
                        self.save_user_ark_history(&user_id_hex, entries);
                    }
                }

                Ok(Response::new(SendVtxoResponse {
                    status: send_vtxo_response::Status::Settled as i32,
                    messages_to_sign: vec![],
                    script_path_spend: false,
                    ark_txid,
                    error_message: String::new(),
                    policy_id: String::new(),
                }))
            }

            // No session but has signatures -> error
            (None, true) => {
                Err(Status::failed_precondition("no active send session"))
            }
        }
    }

    #[tracing::instrument(skip_all, name = "svc::redeem_vtxo", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn redeem_vtxo(
        &self,
        request: Request<RedeemVtxoRequest>,
    ) -> Result<Response<RedeemVtxoResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!("[{user_id_hex}] RedeemVtxo to={} amount={}", req.on_chain_address, req.amount);
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_REDEEM_VTXO)?;

        self.require_asp()?;
        Err(Status::unimplemented("RedeemVtxo not yet implemented"))
    }

    #[tracing::instrument(skip_all, name = "svc::settle", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn settle(
        &self,
        request: Request<SettleRequest>,
    ) -> Result<Response<SettleResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!("[{user_id_hex}] Settle");
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_SETTLE)?;

        let asp_arc = self.require_asp()?.clone();
        let has_signatures = !req.signed_messages.is_empty();

        // Check for existing session
        let mut sessions = self.settle_sessions.lock().await;
        let existing = sessions.remove(&user_id_hex);
        drop(sessions);

        match (existing, has_signatures) {
            // Phase 1: No session, no signatures -> create session, return intent sighashes
            (None, false) => {
                let (owner_pk_hex, dkg_secret_hex) = self.get_user_ark_keys(&user_id_hex)?;

                let mut asp = asp_arc.lock().await;
                let info = match &asp.info {
                    Some(i) => i.clone(),
                    None => asp.get_info().await
                        .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?,
                };
                drop(asp);

                let network = ark::client::parse_network(&info.network)
                    .map_err(|e| Status::internal(e))?;
                let exit_delay = info.boarding_exit_delay as u32;
                let boarding_addr = ark::client::boarding_address(
                    &owner_pk_hex, &info.signer_pubkey, exit_delay, network,
                ).map_err(|e| Status::internal(format!("boarding_address: {e}")))?;

                // Scan for UTXOs at boarding address
                let addr: bitcoin::Address<bitcoin::address::NetworkUnchecked> = boarding_addr.parse()
                    .map_err(|e| Status::internal(format!("parse addr: {e}")))?;
                let addr = addr.require_network(network)
                    .map_err(|e| Status::internal(format!("network mismatch: {e}")))?;
                let script_hex = hex::encode(addr.script_pubkey().as_bytes());
                let script_hash = crate::bitcoin::tx_parser::derive_script_hash(&script_hex)
                    .map_err(|e| Status::internal(format!("script_hash: {e}")))?;

                let history = self.bitcoin_history.lock().await;
                let utxos = history.list_unspent_by_script_hash(&script_hash).await
                    .map_err(|e| Status::internal(format!("list_unspent: {e}")))?;
                drop(history);

                if utxos.is_empty() {
                    return Err(Status::failed_precondition("no UTXOs at boarding address"));
                }

                let utxo = &utxos[0];
                tracing::info!(
                    "[{user_id_hex}] Settle: boarding UTXO {}:{} amount={}",
                    utxo.tx_hash, utxo.vout, utxo.amount_sats
                );

                let boarding_amount = utxo.amount_sats as u64;
                let (session, sighashes) = ark::client::batch::SettleSession::new_boarding(
                    &owner_pk_hex, &info.signer_pubkey, &info.forfeit_pubkey,
                    &boarding_addr,
                    &utxo.tx_hash, utxo.vout, boarding_amount,
                    exit_delay, &info.network, &dkg_secret_hex,
                ).map_err(|e| Status::internal(format!("SettleSession: {e}")))?;

                // Store session with boarding amount
                let mut sessions = self.settle_sessions.lock().await;
                sessions.insert(user_id_hex, (session, boarding_amount, exit_delay));

                Ok(Response::new(SettleResponse {
                    status: settle_response::Status::SigningRequired as i32,
                    messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                    script_path_spend: true,
                    commitment_txid: String::new(),
                    error_message: String::new(),
                }))
            }

            // Phase 2/3: Has session + signatures -> register intent or submit commitment sigs
            (Some((mut session, boarding_amount, exit_delay)), true) => {
                let signatures: Vec<[u8; 64]> = req.signed_messages.iter().map(|s| {
                    if s.len() != 64 {
                        return Err(Status::invalid_argument(
                            format!("signature must be 64 bytes, got {}", s.len())
                        ));
                    }
                    let mut arr = [0u8; 64];
                    arr.copy_from_slice(s);
                    Ok(arr)
                }).collect::<Result<Vec<_>, _>>()?;

                let mut asp = asp_arc.lock().await;

                // Determine phase from the session state by trying register first
                match session.register_with_signatures(&mut asp, signatures.clone()).await {
                    Ok(()) => {
                        tracing::info!("[{user_id_hex}] Settle: intent registered, driving batch");
                        // Drive until we need more signatures or settle
                        loop {
                            match session.drive(&mut asp).await {
                                Ok(ark::client::batch::SettleAction::WaitingForBatch) => continue,
                                Ok(ark::client::batch::SettleAction::NeedSignatures { sighashes }) => {
                                    drop(asp);
                                    let mut sessions = self.settle_sessions.lock().await;
                                    sessions.insert(user_id_hex, (session, boarding_amount, exit_delay));
                                    return Ok(Response::new(SettleResponse {
                                        status: settle_response::Status::SigningRequired as i32,
                                        messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                                        script_path_spend: true,
                                        commitment_txid: String::new(),
                                        error_message: String::new(),
                                    }));
                                }
                                Ok(ark::client::batch::SettleAction::Settled { commitment_txid, vtxo_outpoint }) => {
                                    // Record VTXO using tree leaf outpoint (not commitment txid).
                                    let (vtxo_txid, vtxo_vout) = vtxo_outpoint
                                        .unwrap_or_else(|| (commitment_txid.clone(), 0));
                                    let mut store = self.vtxo_store.lock().await;
                                    let entry = store.entry(user_id_hex.clone()).or_default();
                                    entry.retain(|(t, v, _, _)| !(t == &vtxo_txid && *v == vtxo_vout));
                                    entry.push((vtxo_txid.clone(), vtxo_vout, boarding_amount, exit_delay));
                                    tracing::info!("[{user_id_hex}] Settle: VTXO recorded vtxo_txid={vtxo_txid}:{vtxo_vout} amount={boarding_amount}");
                                    if let Some(vtxos) = store.get(&user_id_hex) {
                                        self.save_user_vtxos(&user_id_hex, vtxos);
                                    }
                                    {
                                        let mut history = self.ark_tx_history.lock().await;
                                        history.entry(user_id_hex.clone()).or_default()
                                            .push(ArkTxEntry {
                                                tx_type: "board".into(),
                                                amount_sats: boarding_amount as i64,
                                                txid: vtxo_txid,
                                                timestamp: now_secs(),
                                            });
                                        if let Some(entries) = history.get(&user_id_hex) {
                                            self.save_user_ark_history(&user_id_hex, entries);
                                        }
                                    }
                                    return Ok(Response::new(SettleResponse {
                                        status: settle_response::Status::Settled as i32,
                                        messages_to_sign: vec![],
                                        script_path_spend: false,
                                        commitment_txid,
                                        error_message: String::new(),
                                    }));
                                }
                                Err(e) => {
                                    return Err(Status::internal(format!("drive error: {e}")));
                                }
                            }
                        }
                    }
                    Err(e) if e.contains("wrong phase") => {
                        // Must be AwaitingCommitmentSignatures
                        session.submit_commitment_signatures(&mut asp, signatures).await
                            .map_err(|e| Status::internal(format!("submit_commitment_sigs: {e}")))?;

                        tracing::info!("[{user_id_hex}] Settle: commitment sigs submitted, driving to finalize");
                        loop {
                            match session.drive(&mut asp).await {
                                Ok(ark::client::batch::SettleAction::WaitingForBatch) => continue,
                                Ok(ark::client::batch::SettleAction::Settled { commitment_txid, vtxo_outpoint }) => {
                                    // Record VTXO using tree leaf outpoint (not commitment txid).
                                    let (vtxo_txid, vtxo_vout) = vtxo_outpoint
                                        .unwrap_or_else(|| (commitment_txid.clone(), 0));
                                    let mut store = self.vtxo_store.lock().await;
                                    let entry = store.entry(user_id_hex.clone()).or_default();
                                    entry.retain(|(t, v, _, _)| !(t == &vtxo_txid && *v == vtxo_vout));
                                    entry.push((vtxo_txid.clone(), vtxo_vout, boarding_amount, exit_delay));
                                    tracing::info!("[{user_id_hex}] Settle: VTXO recorded vtxo_txid={vtxo_txid}:{vtxo_vout} amount={boarding_amount}");
                                    if let Some(vtxos) = store.get(&user_id_hex) {
                                        self.save_user_vtxos(&user_id_hex, vtxos);
                                    }
                                    {
                                        let mut history = self.ark_tx_history.lock().await;
                                        history.entry(user_id_hex.clone()).or_default()
                                            .push(ArkTxEntry {
                                                tx_type: "board".into(),
                                                amount_sats: boarding_amount as i64,
                                                txid: vtxo_txid,
                                                timestamp: now_secs(),
                                            });
                                        if let Some(entries) = history.get(&user_id_hex) {
                                            self.save_user_ark_history(&user_id_hex, entries);
                                        }
                                    }
                                    return Ok(Response::new(SettleResponse {
                                        status: settle_response::Status::Settled as i32,
                                        messages_to_sign: vec![],
                                        script_path_spend: false,
                                        commitment_txid,
                                        error_message: String::new(),
                                    }));
                                }
                                Ok(ark::client::batch::SettleAction::NeedSignatures { sighashes }) => {
                                    drop(asp);
                                    let mut sessions = self.settle_sessions.lock().await;
                                    sessions.insert(user_id_hex, (session, boarding_amount, exit_delay));
                                    return Ok(Response::new(SettleResponse {
                                        status: settle_response::Status::SigningRequired as i32,
                                        messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                                        script_path_spend: true,
                                        commitment_txid: String::new(),
                                        error_message: String::new(),
                                    }));
                                }
                                Err(e) => {
                                    return Err(Status::internal(format!("drive error: {e}")));
                                }
                            }
                        }
                    }
                    Err(e) => {
                        return Err(Status::internal(format!("register error: {e}")));
                    }
                }
            }

            // Session exists but no signatures -> poll
            (Some((session, boarding_amount, exit_delay)), false) => {
                // Put it back, nothing to do without signatures
                let mut sessions = self.settle_sessions.lock().await;
                sessions.insert(user_id_hex, (session, boarding_amount, exit_delay));
                Ok(Response::new(SettleResponse {
                    status: settle_response::Status::WaitingForBatch as i32,
                    messages_to_sign: vec![],
                    script_path_spend: false,
                    commitment_txid: String::new(),
                    error_message: String::new(),
                }))
            }

            // No session but has signatures -> error
            (None, true) => {
                Err(Status::failed_precondition("no active settle session"))
            }
        }
    }

    #[tracing::instrument(skip_all, name = "svc::settle_delegate", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn settle_delegate(
        &self,
        request: Request<SettleDelegateRequest>,
    ) -> Result<Response<SettleDelegateResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!("[{user_id_hex}] SettleDelegate");
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_SETTLE_DELEGATE)?;

        let asp_arc = self.require_asp()?.clone();
        let has_signatures = !req.signed_messages.is_empty();

        // Check for existing delegate session.
        let mut sessions = self.delegate_sessions.lock().await;
        let existing = sessions.remove(&user_id_hex);
        drop(sessions);

        match (existing, has_signatures) {
            // Phase 1: No session -> generate delegate, return sighashes
            (None, false) => {
                let (owner_pk_hex, dkg_secret_hex) = self.get_user_ark_keys(&user_id_hex)?;

                let mut asp = asp_arc.lock().await;
                let info = match &asp.info {
                    Some(i) => i.clone(),
                    None => asp.get_info().await
                        .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?,
                };
                drop(asp);

                // Gather user's confirmed VTXOs.
                let store = self.vtxo_store.lock().await;
                let user_vtxos = store.get(&user_id_hex)
                    .cloned()
                    .unwrap_or_default();
                drop(store);

                if user_vtxos.is_empty() {
                    return Err(Status::failed_precondition("no VTXOs to settle"));
                }

                let vtxo_inputs: Vec<ark::client::batch::DelegateVtxoInput> = user_vtxos
                    .iter()
                    .map(|(txid, vout, amount, _)| ark::client::batch::DelegateVtxoInput {
                        txid: txid.clone(),
                        vout: *vout,
                        amount_sats: *amount,
                        is_swept: false,
                    })
                    .collect();

                let total_amount: u64 = user_vtxos.iter().map(|(_, _, a, _)| a).sum();

                // Output: settle all to self (same ark address = refresh).
                let network = ark::client::parse_network(&info.network)
                    .map_err(|e| Status::internal(e))?;
                let exit_delay = info.unilateral_exit_delay as u32;
                let ark_addr = ark::client::ark_address(
                    &owner_pk_hex, &info.signer_pubkey, exit_delay, network,
                ).map_err(|e| Status::internal(format!("ark_address: {e}")))?;

                let outputs = vec![ark::client::batch::DelegateOutput {
                    ark_address: ark_addr,
                    amount_sats: total_amount,
                }];

                // Derive forfeit address from ASP forfeit pubkey.
                let forfeit_pk = ark::client::address::parse_xonly_pubkey(&info.forfeit_pubkey)
                    .map_err(|e| Status::internal(format!("forfeit_pubkey: {e}")))?;
                let secp = bitcoin::key::Secp256k1::new();
                let (forfeit_xonly, _) = forfeit_pk.inner.x_only_public_key();
                let forfeit_addr = bitcoin::Address::p2tr(&secp, forfeit_xonly, None, network);

                let (session, sighashes) = ark::client::batch::DelegateSettleSession::generate_delegate(
                    &owner_pk_hex,
                    &info.signer_pubkey,
                    &info.forfeit_pubkey,
                    &dkg_secret_hex,
                    &vtxo_inputs,
                    &outputs,
                    &forfeit_addr.to_string(),
                    info.dust as u64,
                    exit_delay,
                    &info.network,
                ).map_err(|e| Status::internal(format!("generate_delegate: {e}")))?;

                let mut sessions = self.delegate_sessions.lock().await;
                sessions.insert(user_id_hex, session);

                Ok(Response::new(SettleDelegateResponse {
                    status: settle_delegate_response::Status::SigningRequired as i32,
                    messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                    script_path_spend: true,
                    commitment_txid: String::new(),
                    error_message: String::new(),
                }))
            }

            // Phase 2: Has session + signatures -> sign + settle autonomously
            (Some(mut session), true) => {
                let signatures: Vec<[u8; 64]> = req.signed_messages.iter().map(|s| {
                    if s.len() != 64 {
                        return Err(Status::invalid_argument(
                            format!("signature must be 64 bytes, got {}", s.len())
                        ));
                    }
                    let mut arr = [0u8; 64];
                    arr.copy_from_slice(s);
                    Ok(arr)
                }).collect::<Result<Vec<_>, _>>()?;

                session.sign_with_frost(signatures)
                    .map_err(|e| Status::internal(format!("sign_with_frost: {e}")))?;

                let mut asp = asp_arc.lock().await;
                let (commitment_txid, vtxo_outpoint) = session.settle(&mut asp).await
                    .map_err(|e| Status::internal(format!("settle: {e}")))?;

                // Get info for exit_delay.
                let delegate_info = match &asp.info {
                    Some(i) => i.clone(),
                    None => asp.get_info().await
                        .map_err(|e| Status::internal(format!("ASP get_info: {e}")))?,
                };

                // Update VTXO store: mark old VTXOs spent, add new one.
                let (vtxo_txid, vtxo_vout) = vtxo_outpoint
                    .unwrap_or_else(|| (commitment_txid.clone(), 0));
                let mut store = self.vtxo_store.lock().await;
                let old_vtxos = store.remove(&user_id_hex).unwrap_or_default();
                let total_amount: u64 = old_vtxos.iter().map(|(_, _, a, _)| a).sum();
                // Delegate-settled VTXOs use unilateral_exit_delay (refreshed).
                let new_exit_delay = delegate_info.unilateral_exit_delay as u32;
                store.entry(user_id_hex.clone())
                    .or_default()
                    .push((vtxo_txid.clone(), vtxo_vout, total_amount, new_exit_delay));
                tracing::info!(
                    "[{user_id_hex}] SettleDelegate: settled, new VTXO txid={vtxo_txid}:{vtxo_vout} amount={total_amount}"
                );
                if let Some(vtxos) = store.get(&user_id_hex) {
                    self.save_user_vtxos(&user_id_hex, vtxos);
                }
                {
                    let mut history = self.ark_tx_history.lock().await;
                    history.entry(user_id_hex.clone()).or_default()
                        .push(ArkTxEntry {
                            tx_type: "settle".into(),
                            amount_sats: total_amount as i64,
                            txid: vtxo_txid,
                            timestamp: now_secs(),
                        });
                    if let Some(entries) = history.get(&user_id_hex) {
                        self.save_user_ark_history(&user_id_hex, entries);
                    }
                }

                Ok(Response::new(SettleDelegateResponse {
                    status: settle_delegate_response::Status::Settled as i32,
                    messages_to_sign: vec![],
                    script_path_spend: false,
                    commitment_txid,
                    error_message: String::new(),
                }))
            }

            // Session exists but no signatures -> error
            (Some(session), false) => {
                let mut sessions = self.delegate_sessions.lock().await;
                sessions.insert(user_id_hex, session);
                Err(Status::failed_precondition("delegate session exists; provide signatures"))
            }

            // No session but has signatures -> error
            (None, true) => {
                Err(Status::failed_precondition("no active delegate session"))
            }
        }
    }

    #[tracing::instrument(skip_all, name = "svc::submit_ark_send", fields(user_id = %hex::encode(&request.get_ref().user_id)), err)]
    async fn submit_ark_send(
        &self,
        request: Request<SubmitArkSendRequest>,
    ) -> Result<Response<SubmitArkSendResponse>, Status> {
        let req = request.into_inner();
        let user_id_hex = Self::user_id_hex(&req.user_id);
        tracing::info!("[{user_id_hex}] SubmitArkSend");
        self.verify_auth(&req.user_id, &req.signature, req.timestamp_ms, OP_SEND_VTXO)?;

        let asp_arc = self.require_asp()?.clone();

        // Decode client's signed ark tx (base64 PSBT)
        use bitcoin::base64::{self, Engine};
        let signed_ark_bytes = base64::engine::general_purpose::STANDARD
            .decode(&req.signed_ark_tx_b64)
            .map_err(|e| Status::invalid_argument(format!("invalid ark tx base64: {e}")))?;
        let signed_ark_psbt = bitcoin::Psbt::deserialize(&signed_ark_bytes)
            .map_err(|e| Status::invalid_argument(format!("invalid ark tx PSBT: {e}")))?;

        // Log PSBT inputs for debugging
        for (i, input) in signed_ark_psbt.unsigned_tx.input.iter().enumerate() {
            tracing::info!(
                "[{user_id_hex}] SubmitArkSend: PSBT input[{i}] = {}:{}",
                input.previous_output.txid, input.previous_output.vout
            );
        }

        // Keep client-signed checkpoints for both ASP submission and counter-signing.
        // The reference SDK sends checkpoints WITH owner signatures to submit_tx.
        let mut client_signed_checkpoints = Vec::new();
        let mut signed_checkpoint_b64s = Vec::new();
        for cp_b64 in &req.signed_checkpoint_txs_b64 {
            let cp_bytes = base64::engine::general_purpose::STANDARD
                .decode(cp_b64)
                .map_err(|e| Status::invalid_argument(format!("invalid checkpoint base64: {e}")))?;
            let cp = bitcoin::Psbt::deserialize(&cp_bytes)
                .map_err(|e| Status::invalid_argument(format!("invalid checkpoint PSBT: {e}")))?;
            client_signed_checkpoints.push(cp);
            // Send checkpoints as-is (with owner FROST sigs), matching reference SDK
            signed_checkpoint_b64s.push(cp_b64.clone());
        }

        // Encode signed ark tx as base64
        let signed_ark_b64 = base64::engine::general_purpose::STANDARD
            .encode(&signed_ark_psbt.serialize());

        // Submit to ASP
        let mut asp = asp_arc.lock().await;
        tracing::info!("[{user_id_hex}] SubmitArkSend: calling asp.submit_tx");
        let response = asp.submit_tx(signed_ark_b64, signed_checkpoint_b64s).await
            .map_err(|e| {
                tracing::error!("[{user_id_hex}] SubmitArkSend: asp.submit_tx failed: {e}");
                Status::internal(format!("submit_tx: {e}"))
            })?;

        let ark_txid = response.ark_txid;

        // Counter-sign: merge client FROST sigs onto ASP-returned checkpoints
        let mut final_checkpoints = Vec::new();
        for asp_cp_b64 in &response.signed_checkpoint_txs {
            let asp_cp_bytes = base64::engine::general_purpose::STANDARD
                .decode(asp_cp_b64)
                .map_err(|e| Status::internal(format!("invalid ASP checkpoint: {e}")))?;
            let mut asp_cp = bitcoin::Psbt::deserialize(&asp_cp_bytes)
                .map_err(|e| Status::internal(format!("invalid ASP checkpoint PSBT: {e}")))?;

            // Find matching client checkpoint by txid
            let cp_txid = asp_cp.unsigned_tx.compute_txid();
            if let Some(client_cp) = client_signed_checkpoints.iter()
                .find(|cp| cp.unsigned_tx.compute_txid() == cp_txid)
            {
                // Restore witness_script if stripped by ASP
                if let Some(ws) = &client_cp.inputs[0].witness_script {
                    asp_cp.inputs[0].witness_script = Some(ws.clone());
                }
                // Restore tap_scripts if stripped
                if asp_cp.inputs[0].tap_scripts.is_empty() {
                    asp_cp.inputs[0].tap_scripts = client_cp.inputs[0].tap_scripts.clone();
                }
                // Copy client FROST sigs onto ASP-signed checkpoint
                for ((pk, lh), sig) in &client_cp.inputs[0].tap_script_sigs {
                    asp_cp.inputs[0].tap_script_sigs.insert((*pk, *lh), sig.clone());
                }
            }

            let final_bytes = asp_cp.serialize();
            final_checkpoints.push(
                base64::engine::general_purpose::STANDARD.encode(&final_bytes)
            );
        }

        // Finalize
        asp.finalize_tx(ark_txid.clone(), final_checkpoints).await
            .map_err(|e| Status::internal(format!("finalize_tx: {e}")))?;

        // Compute change VTXO from ark tx
        let outputs = &signed_ark_psbt.unsigned_tx.output;
        let (change_txid, change_vout, change_amount) = if outputs.len() >= 3 {
            let txid = signed_ark_psbt.unsigned_tx.compute_txid().to_string();
            let idx = (outputs.len() - 2) as u32;
            let amt = outputs[idx as usize].value.to_sat();
            (txid, idx, amt)
        } else {
            (String::new(), 0, 0)
        };

        // Update vtxo_store: remove spent, add change
        let mut store = self.vtxo_store.lock().await;
        // Compute spent total before removing
        let spent_total: u64 = store.get(&user_id_hex)
            .map(|vtxos| vtxos.iter()
                .filter(|(txid, vout, _, _)| req.spent_outpoints.contains(&format!("{txid}:{vout}")))
                .map(|(_, _, amount, _)| amount)
                .sum())
            .unwrap_or(0);
        if let Some(user_vtxos) = store.get_mut(&user_id_hex) {
            user_vtxos.retain(|(txid, vout, _, _)| {
                let outpoint = format!("{}:{}", txid, vout);
                !req.spent_outpoints.contains(&outpoint)
            });
        }
        if change_amount > 0 {
            let exit_delay = {
                let info = asp.get_info().await
                    .map_err(|e| Status::internal(format!("get_info: {e}")))?;
                info.unilateral_exit_delay as u32
            };
            store.entry(user_id_hex.clone()).or_default()
                .push((change_txid.clone(), change_vout, change_amount, exit_delay));
        }

        tracing::info!(
            "[{user_id_hex}] SubmitArkSend: ark_txid={ark_txid}, change=({change_txid}, {change_vout}, {change_amount})"
        );
        // Persist vtxo_store
        if let Some(vtxos) = store.get(&user_id_hex) {
            self.save_user_vtxos(&user_id_hex, vtxos);
        }
        let sent_amount = spent_total.saturating_sub(change_amount);
        {
            let mut history = self.ark_tx_history.lock().await;
            history.entry(user_id_hex.clone()).or_default()
                .push(ArkTxEntry {
                    tx_type: "send".into(),
                    amount_sats: -(sent_amount as i64),
                    txid: ark_txid.clone(),
                    timestamp: now_secs(),
                });
            if let Some(entries) = history.get(&user_id_hex) {
                self.save_user_ark_history(&user_id_hex, entries);
            }
        }

        Ok(Response::new(SubmitArkSendResponse {
            ark_txid,
            change_txid,
            change_vout,
            change_amount,
        }))
    }
}
