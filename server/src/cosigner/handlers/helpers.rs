//! Shared helpers for actor command handlers. Each function takes plain
//! references to `CosignerInstance`, `CosignerState`, and shared services so handlers
//! can compose without locking.

use std::time::{SystemTime, UNIX_EPOCH};

use tonic::Status;

use crate::auth::message::{build_auth_message, MAX_TIMESTAMP_DRIFT_MS};
use crate::crypto_ops;
use crate::persistence::{KvStore, SecretStore};
use crate::policy::PolicyState;
use crate::shared::SharedServices;
use crate::cosigner::registry::CosignerRegistry;
use crate::cosigner::state::CosignerState;
use crate::cosigner::wasm::CosignerInstance;

const NONCE_CACHE_CAP: usize = 10_000;

/// Per-user Schnorr-auth check. Replaces the global `AuthVerifier` for cases
/// that carry a single-key signature.
pub fn auth_check(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    user_id_bytes: &[u8],
    signature: &[u8],
    timestamp_ms: i64,
    operation: &str,
) -> Result<(), Status> {
    let user_id_hex = hex::encode(user_id_bytes);
    timestamp_check(state, timestamp_ms, &user_id_hex, operation)?;

    let pk_hex = hex::encode(user_id_bytes);
    let sig_hex = hex::encode(signature);
    let auth_message = build_auth_message(operation, timestamp_ms, &user_id_hex);

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
            &pk_hex,
            &auth_message,
            &sig_hex,
        )
        .map_err(|e| Status::internal(format!("WASM error: {e}")))?
        .map_err(|_| Status::internal("signature verification failed"))?;

    if !is_valid {
        tracing::warn!("[{user_id_hex}] Signature verification failed for {operation}");
        return Err(Status::unauthenticated("Invalid authentication signature"));
    }

    state.note_nonce(timestamp_ms, NONCE_CACHE_CAP);
    Ok(())
}

/// Timestamp-only check (no signature). Used for FROST-signed paths
/// (update_policy, delete_policy) where the signature is verified separately
/// against the user's group verifying key.
pub fn timestamp_check(
    state: &mut CosignerState,
    timestamp_ms: i64,
    user_id_hex: &str,
    operation: &str,
) -> Result<(), Status> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;
    let diff = (now - timestamp_ms).abs();
    if diff > MAX_TIMESTAMP_DRIFT_MS {
        tracing::warn!(
            "[{user_id_hex}] Timestamp validation failed for {operation}: diff={diff}ms"
        );
        return Err(Status::unauthenticated(
            "Request timestamp is outside acceptable range",
        ));
    }
    if state.used_nonces.contains(&timestamp_ms) {
        tracing::warn!("[{user_id_hex}] Replay detected for {operation}");
        return Err(Status::unauthenticated("Request replay detected"));
    }
    state.note_nonce(timestamp_ms, NONCE_CACHE_CAP);
    Ok(())
}

/// Load policy state from persistence into the user instance if not present.
///
/// Looks up under the request's `user_id_hex` first (the FROST verifying-share
/// for the standard post-DKG path). On miss, falls back through the
/// `policy_owner_idx` forward index — written at DKG step3 — which maps the
/// wallet's owner pubkey (the user_id used during DKG) to the canonical
/// verifying-share key. This lets the actor for the owner pubkey find its
/// policy on respawn, and lets clients use either identity in the URL.
pub fn ensure_policy_loaded(
    user: &mut CosignerInstance,
    persistence: &dyn KvStore,
    secret_store: &dyn SecretStore,
    user_id_hex: &str,
) -> Result<(), Status> {
    if user.policy_state.is_some() {
        return Ok(());
    }
    if try_load_policy(user, persistence, secret_store, user_id_hex)? {
        return Ok(());
    }
    if let Ok(Some(canonical)) = persistence.get("policy_owner_idx", user_id_hex) {
        if try_load_policy(user, persistence, secret_store, &canonical)? {
            tracing::info!(
                "[{user_id_hex}] Resolved via policy_owner_idx → {canonical}"
            );
            return Ok(());
        }
    }
    Err(Status::not_found(format!(
        "No policy state found for user {user_id_hex}"
    )))
}

/// Try to load a policy under the given key. Returns Ok(true) on hit,
/// Ok(false) on miss; bubble parse errors as warnings, treated as miss.
fn try_load_policy(
    user: &mut CosignerInstance,
    persistence: &dyn KvStore,
    secret_store: &dyn SecretStore,
    key: &str,
) -> Result<bool, Status> {
    if let Ok(Some(json_str)) = persistence.get("policies", key) {
        match serde_json::from_str::<PolicyState>(&json_str) {
            Ok(mut ps) => {
                if let Ok(Some(secret)) =
                    secret_store.get_secret(&format!("dkg-secret.{key}"))
                {
                    ps.server_dkg_secret_hex = Some(secret);
                }
                user.policy_state = Some(ps);
                tracing::info!("[{key}] Loaded policy from persistence");
                return Ok(true);
            }
            Err(e) => {
                tracing::warn!("[{key}] Error parsing policy: {e}");
            }
        }
    }
    Ok(false)
}

/// Persist policy state, the recovery-id index, and the DKG secret.
/// Also updates the registry's in-memory `recovery_idx` so concurrent restore
/// flows can find this policy without restarting the process.
pub fn persist_policy(
    shared: &SharedServices,
    registry: &CosignerRegistry,
    user_id_hex: &str,
    policy: &PolicyState,
) -> Result<(), Status> {
    let json = serde_json::to_string(policy)
        .map_err(|e| Status::internal(format!("serialization error: {e}")))?;
    shared
        .persistence
        .put("policies", user_id_hex, &json)
        .map_err(|e| {
            tracing::error!(error = %e, user_id = %user_id_hex, "persistence put policies failed");
            Status::internal(format!("persistence write error: {e}"))
        })?;
    if !policy.recovery_id.is_empty() {
        if let Err(e) =
            shared
                .persistence
                .put("policy_recovery_idx", &policy.recovery_id, user_id_hex)
        {
            tracing::warn!(
                "persist policy_recovery_idx/{} failed: {e}",
                policy.recovery_id
            );
        } else {
            registry.set_recovery_id(&policy.recovery_id, user_id_hex);
        }
    }
    if let Some(ref secret) = policy.server_dkg_secret_hex {
        if let Err(e) = shared
            .secret_store
            .put_secret(&format!("dkg-secret.{user_id_hex}"), secret)
        {
            tracing::error!(
                "persist dkg-secret.{user_id_hex} failed: {e} — wallet may not be restorable"
            );
        }
    }
    Ok(())
}

/// Fetch the user's group x-only pubkey (64 hex chars) for Ark address derivation.
/// The compressed key from the policy is 33 bytes (66 hex); strip the parity byte.
pub fn get_user_xonly_pubkey(
    user: &mut CosignerInstance,
    persistence: &dyn KvStore,
    secret_store: &dyn SecretStore,
    user_id_hex: &str,
) -> Result<String, Status> {
    ensure_policy_loaded(user, persistence, secret_store, user_id_hex)?;
    let ps = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?;
    let vk_hex = crate::cosigner::handlers::parsers::extract_verifying_key(
        &ps.normal_policy.public_key_package_json,
    )?;
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

/// Return `(xonly_owner_pk_hex, server_dkg_secret_hex)` from the user's policy.
pub fn get_user_ark_keys(
    user: &mut CosignerInstance,
    persistence: &dyn KvStore,
    secret_store: &dyn SecretStore,
    user_id_hex: &str,
) -> Result<(String, String), Status> {
    ensure_policy_loaded(user, persistence, secret_store, user_id_hex)?;
    let ps = user
        .policy_state
        .as_ref()
        .ok_or_else(|| Status::not_found("no policy state"))?;
    let vk_hex = crate::cosigner::handlers::parsers::extract_verifying_key(
        &ps.normal_policy.public_key_package_json,
    )?;
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

/// Persist a user's VTXO list (best-effort; logs and ignores errors).
pub fn save_user_vtxos(
    persistence: &dyn KvStore,
    user_id_hex: &str,
    vtxos: &[(String, u32, u64, u32)],
) {
    if let Ok(json) = serde_json::to_string(vtxos) {
        if let Err(e) = persistence.put("vtxo_store", user_id_hex, &json) {
            tracing::warn!("persist vtxo_store/{user_id_hex} failed: {e}");
        }
    }
}

/// Persist a user's Ark transaction history.
pub fn save_user_ark_history(
    persistence: &dyn KvStore,
    user_id_hex: &str,
    entries: &[crate::cosigner::types::ArkTxEntry],
) {
    if let Ok(json) = serde_json::to_string(entries) {
        if let Err(e) = persistence.put("ark_tx_history", user_id_hex, &json) {
            tracing::warn!("persist ark_tx_history/{user_id_hex} failed: {e}");
        }
    }
}

/// Seconds since the Unix epoch.
pub fn now_secs() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

/// Calculate spent amount from a transaction (PSBT or raw tx) for policy eval.
pub fn calculate_spent_amount(
    user: &mut CosignerInstance,
    full_tx: &[u8],
    pkp_json: &str,
) -> Result<i64, Status> {
    if full_tx.is_empty() {
        return Ok(0);
    }
    if full_tx.len() > 5 && full_tx[..5] == [0x70, 0x73, 0x62, 0x74, 0xff] {
        if let Ok(psbt) = bitcoin::Psbt::deserialize(full_tx) {
            let input_total: u64 = psbt
                .inputs
                .iter()
                .filter_map(|i| i.witness_utxo.as_ref())
                .map(|utxo| utxo.value.to_sat())
                .sum();
            let outputs = &psbt.unsigned_tx.output;
            let change_amount = if outputs.len() >= 3 {
                outputs[outputs.len() - 2].value.to_sat()
            } else {
                0
            };
            let net_spend = input_total.saturating_sub(change_amount);
            tracing::info!(
                "PSBT policy eval: inputs={input_total}, change={change_amount}, net_spend={net_spend}"
            );
            return Ok(net_spend as i64);
        }
    }
    if full_tx.starts_with(b"ARK_AMOUNT:") {
        let amount_str = std::str::from_utf8(&full_tx[11..])
            .map_err(|e| Status::internal(format!("invalid ARK_AMOUNT: {e}")))?;
        let amount: i64 = amount_str
            .parse()
            .map_err(|e| Status::internal(format!("invalid ARK_AMOUNT value: {e}")))?;
        return Ok(amount);
    }
    let tweaked_pkp_json = crypto_ops::pub_key_package_tweak(user, pkp_json, None)
        .map_err(|e| Status::internal(format!("tweak error: {e}")))?;
    let vk_hex = crate::cosigner::handlers::parsers::extract_verifying_key(&tweaked_pkp_json)?;
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
