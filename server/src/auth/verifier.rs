use std::collections::HashSet;
use std::sync::RwLock;
use std::time::{SystemTime, UNIX_EPOCH};

use tonic::Status;

use super::message::{build_auth_message, MAX_TIMESTAMP_DRIFT_MS};
use crate::cosigner::wasm::CosignerInstance;

/// Server-side authentication verifier.
/// Mirrors `AuthVerifier` from `server/lib/auth_verifier.dart`.
pub struct AuthVerifier {
    max_clock_skew_ms: i64,
    used_nonces: RwLock<HashSet<String>>,
    max_nonce_cache_size: usize,
}

impl AuthVerifier {
    pub fn new() -> Self {
        Self {
            max_clock_skew_ms: MAX_TIMESTAMP_DRIFT_MS,
            used_nonces: RwLock::new(HashSet::new()),
            max_nonce_cache_size: 10_000,
        }
    }

    /// Verify an authentication signature for a request.
    /// The signature is verified via the WASM instance's verify_schnorr_signature function.
    pub fn verify_auth(
        &self,
        user: &mut CosignerInstance,
        public_key_compressed_hex: &str,
        signature_hex: &str,
        operation: &str,
        timestamp_ms: i64,
        user_id_hex: &str,
    ) -> Result<(), Status> {
        // 1. Validate timestamp
        self.validate_timestamp(timestamp_ms, user_id_hex, operation)?;

        // 2. Build the auth message
        let auth_message = build_auth_message(operation, timestamp_ms, user_id_hex);

        // 3. Verify signature via WASM
        let session = user
            .session
            .as_ref()
            .ok_or_else(|| Status::internal("no session"))?;
        let iface = user.bindings.component_threshold_types();

        let is_valid = iface
            .threshold_session()
            .call_verify_schnorr_signature(
                &mut user.store,
                *session,
                public_key_compressed_hex,
                &auth_message,
                signature_hex,
            )
            .map_err(|e| Status::internal(format!("WASM error: {e}")))?
            .map_err(|_| Status::internal("signature verification failed"))?;

        if !is_valid {
            tracing::warn!("[{user_id_hex}] Signature verification failed for {operation}");
            return Err(Status::unauthenticated("Invalid authentication signature"));
        }

        // 4. Record nonce
        self.record_nonce(timestamp_ms, user_id_hex, operation);

        tracing::debug!("[{user_id_hex}] Auth verified for {operation}");
        Ok(())
    }

    /// Validate timestamp and record nonce without signature verification.
    /// Used for FROST-signed requests (policy update/delete).
    pub fn validate_request_timing(
        &self,
        timestamp_ms: i64,
        user_id_hex: &str,
        operation: &str,
    ) -> Result<(), Status> {
        self.validate_timestamp(timestamp_ms, user_id_hex, operation)?;
        self.record_nonce(timestamp_ms, user_id_hex, operation);
        Ok(())
    }

    fn validate_timestamp(
        &self,
        timestamp_ms: i64,
        user_id_hex: &str,
        operation: &str,
    ) -> Result<(), Status> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;
        let diff = (now - timestamp_ms).abs();

        if diff > self.max_clock_skew_ms {
            tracing::warn!(
                "[{user_id_hex}] Timestamp validation failed for {operation}: diff={diff}ms"
            );
            return Err(Status::unauthenticated(
                "Request timestamp is outside acceptable range",
            ));
        }

        // Check for replay
        let nonce_key = build_nonce_key(timestamp_ms, user_id_hex, operation);
        let nonces = self.used_nonces.read().unwrap();
        if nonces.contains(&nonce_key) {
            tracing::warn!("[{user_id_hex}] Replay detected for {operation}");
            return Err(Status::unauthenticated("Request replay detected"));
        }

        Ok(())
    }

    fn record_nonce(&self, timestamp_ms: i64, user_id_hex: &str, operation: &str) {
        let nonce_key = build_nonce_key(timestamp_ms, user_id_hex, operation);
        let mut nonces = self.used_nonces.write().unwrap();

        // Simple cache cleanup when too large
        if nonces.len() >= self.max_nonce_cache_size {
            let to_remove: Vec<String> = nonces.iter().take(self.max_nonce_cache_size / 2).cloned().collect();
            for key in to_remove {
                nonces.remove(&key);
            }
        }

        nonces.insert(nonce_key);
    }
}

fn build_nonce_key(timestamp_ms: i64, user_id_hex: &str, operation: &str) -> String {
    format!("{}:{}:{}", timestamp_ms, user_id_hex, operation)
}
