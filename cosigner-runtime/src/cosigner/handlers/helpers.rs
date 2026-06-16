//! Shared helpers for actor command handlers. Each function takes plain
//! references to `CosignerInstance`, `CosignerState`, and shared services so handlers
//! can compose without locking.

use std::time::{SystemTime, UNIX_EPOCH};

use tonic::Status;

use crate::auth::message::{build_auth_message, MAX_TIMESTAMP_DRIFT_MS};
use crate::cosigner::state::CosignerState;
use crate::cosigner::registry::CosignerInstance;
use crate::crypto_ops;
use crate::persistence::{KvStore, SecretStore};
use crate::policy::PolicyState;

/// Per-user Schnorr-auth check. Verifies a single-key BIP-340 signature
/// against the URL `user_id` (owner pubkey) via the actor's WASM session.
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
        .call_verify_schnorr_signature(&mut user.store, *session, &pk_hex, &auth_message, &sig_hex)
        .map_err(|e| Status::internal(format!("WASM error: {e}")))?
        .map_err(|_| Status::internal("signature verification failed"))?;

    if !is_valid {
        tracing::warn!("[{user_id_hex}] Signature verification failed for {operation}");
        return Err(Status::unauthenticated("Invalid authentication signature"));
    }

    Ok(())
}

/// Timestamp drift check (no signature, no replay cache). The signing nonce is
/// generated randomly per request, so replay of a captured (timestamp, sig) is
/// not a concern; we only reject requests outside the acceptable clock window.
pub fn timestamp_check(
    _state: &mut CosignerState,
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
    Ok(())
}

/// Whether `claimed_share_hex` is one of the group's authorized verifying shares.
pub fn is_authorized_share(authorized_shares: &[String], claimed_share_hex: &str) -> bool {
    authorized_shares.iter().any(|s| s == claimed_share_hex)
}

/// Group auth: the request is signed by ONE of the group's authorized verifying
/// shares (any participant of a contract cosigner). Verifies the BIP-340
/// signature against `claimed_share` AND asserts it is in `authorized_shares`.
/// Each signer signs as herself — the auth message binds her own share, which is
/// both the pubkey the signature is checked against and the identity in the
/// canonical message, so this reduces to the per-key `auth_check`.
pub fn auth_check_group(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    claimed_share_bytes: &[u8],
    authorized_shares: &[String],
    signature: &[u8],
    timestamp_ms: i64,
    operation: &str,
) -> Result<(), Status> {
    let claimed_hex = hex::encode(claimed_share_bytes);
    if !is_authorized_share(authorized_shares, &claimed_hex) {
        tracing::warn!("[{claimed_hex}] not an authorized signer for {operation}");
        return Err(Status::unauthenticated("signer not authorized for this group"));
    }
    auth_check(
        user,
        state,
        claimed_share_bytes,
        signature,
        timestamp_ms,
        operation,
    )
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
            tracing::info!("[{user_id_hex}] Resolved via policy_owner_idx → {canonical}");
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
                if let Ok(Some(secret)) = secret_store.get_secret(&format!("dkg-secret.{key}")) {
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

pub use crate::policy::store::persist_policy;

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

/// Resolve an addressing id (a member's verifying share) to its GROUP KEY
/// (`cosigner_id`) via `policy_owner_idx`, so all of a group's per-user data is keyed
/// by the one group key. Identity for a group key, or any id with no index entry.
pub fn group_key_of(persistence: &dyn KvStore, id: &str) -> String {
    persistence
        .get("policy_owner_idx", id)
        .ok()
        .flatten()
        .unwrap_or_else(|| id.to_string())
}

/// Persist a user's VTXO list (best-effort; logs and ignores errors).
pub fn save_user_vtxos(
    persistence: &dyn KvStore,
    user_id_hex: &str,
    vtxos: &[crate::cosigner::state::VtxoEntry],
) {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    if let Ok(json) = serde_json::to_string(vtxos) {
        if let Err(e) = persistence.put("vtxo_store", user_id_hex, &json) {
            tracing::warn!("persist vtxo_store/{user_id_hex} failed: {e}");
        }
    }
}

/// Persist a user's registered device tokens.
pub fn save_user_device_tokens(
    persistence: &dyn KvStore,
    user_id_hex: &str,
    tokens: &[crate::cosigner::state::DeviceToken],
) {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    if let Ok(json) = serde_json::to_string(tokens) {
        if let Err(e) = persistence.put("device_tokens", user_id_hex, &json) {
            tracing::warn!("persist device_tokens/{user_id_hex} failed: {e}");
        }
    }
}

/// Persist a user's Ark transaction history.
pub fn save_user_ark_history(
    persistence: &dyn KvStore,
    user_id_hex: &str,
    entries: &[crate::cosigner::types::ArkTxEntry],
) {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    if let Ok(json) = serde_json::to_string(entries) {
        if let Err(e) = persistence.put("ark_tx_history", user_id_hex, &json) {
            tracing::warn!("persist ark_tx_history/{user_id_hex} failed: {e}");
        }
    }
}

/// Read back a user's Ark transaction history from persistence. Returns an
/// empty vec on miss or parse failure (best-effort — history isn't safety-
/// critical, just user-facing).
pub fn load_user_ark_history(
    persistence: &dyn KvStore,
    user_id_hex: &str,
) -> Vec<crate::cosigner::types::ArkTxEntry> {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    match persistence.get("ark_tx_history", user_id_hex) {
        Ok(Some(json)) => match serde_json::from_str(&json) {
            Ok(entries) => entries,
            Err(e) => {
                tracing::warn!("parse ark_tx_history/{user_id_hex} failed: {e}");
                Vec::new()
            }
        },
        _ => Vec::new(),
    }
}

/// Read back a user's stored VTXOs from persistence. Returns an empty vec on
/// miss or parse failure. The vtxo_stream subscription will reconcile via its
/// own dedup as ASP events arrive, so a stale read here is self-healing.
pub fn load_user_vtxos(
    persistence: &dyn KvStore,
    user_id_hex: &str,
) -> Vec<crate::cosigner::state::VtxoEntry> {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    match persistence.get("vtxo_store", user_id_hex) {
        Ok(Some(json)) => match serde_json::from_str(&json) {
            Ok(vtxos) => vtxos,
            Err(e) => {
                tracing::warn!("parse vtxo_store/{user_id_hex} failed: {e}");
                Vec::new()
            }
        },
        _ => Vec::new(),
    }
}

/// Read back a user's registered FCM device tokens from persistence. Closes
/// the gap from TODO #4 — without this, pushes silently no-op after a
/// cosigner restart for any user who hasn't reopened the app since.
pub fn load_user_device_tokens(
    persistence: &dyn KvStore,
    user_id_hex: &str,
) -> Vec<crate::cosigner::state::DeviceToken> {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    match persistence.get("device_tokens", user_id_hex) {
        Ok(Some(json)) => match serde_json::from_str(&json) {
            Ok(tokens) => tokens,
            Err(e) => {
                tracing::warn!("parse device_tokens/{user_id_hex} failed: {e}");
                Vec::new()
            }
        },
        _ => Vec::new(),
    }
}

/// Persist a stored signed delegate intent. The on-disk record carries no
/// secret material — the cosigner secret stays in `SecretStore` and is
/// reattached only at rehydration time (issue #31).
pub fn save_user_delegate(
    persistence: &dyn KvStore,
    user_id_hex: &str,
    record: &crate::cosigner::state::PersistedDelegateRecord,
) {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    match serde_json::to_string(record) {
        Ok(json) => {
            if let Err(e) = persistence.put("delegate_sessions", user_id_hex, &json) {
                tracing::warn!("persist delegate_sessions/{user_id_hex} failed: {e}");
            }
        }
        Err(e) => {
            tracing::warn!("serialize delegate_sessions/{user_id_hex} failed: {e}");
        }
    }
}

/// Read back a stored delegate. Returns `None` on miss, parse failure, or
/// any other error — caller treats absence as "no delegate, client should
/// re-delegate on next refresh."
pub fn load_user_delegate(
    persistence: &dyn KvStore,
    user_id_hex: &str,
) -> Option<crate::cosigner::state::PersistedDelegateRecord> {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    match persistence.get("delegate_sessions", user_id_hex) {
        Ok(Some(json)) => match serde_json::from_str(&json) {
            Ok(record) => Some(record),
            Err(e) => {
                tracing::warn!("parse delegate_sessions/{user_id_hex} failed: {e}");
                None
            }
        },
        _ => None,
    }
}

/// Drop the stored delegate. Called from every invalidation site — once
/// the in-memory `DelegateRecord` is cleared, the sled row must go too,
/// otherwise the next actor spawn would rehydrate a stale intent that no
/// longer matches `state.vtxos`.
pub fn delete_user_delegate(persistence: &dyn KvStore, user_id_hex: &str) {
    let user_id_hex = &group_key_of(persistence, user_id_hex);
    if let Err(e) = persistence.delete("delegate_sessions", user_id_hex) {
        tracing::warn!("delete delegate_sessions/{user_id_hex} failed: {e}");
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
            // The user's change script is whatever script their spent inputs
            // reside under — for Ark redeems all of the user's VTXOs share a
            // single script tied to their group key. Reading it from the
            // PSBT's witness_utxo is safe: any tampering also tampers the
            // sighash the FROST signature commits to, so a compromised
            // client can't silently mislabel inputs without producing a
            // signature that won't verify or won't broadcast.
            //
            // Outputs whose script matches the user's input script are
            // change; the spent (recipient) amount is everything else.
            let user_input_scripts: std::collections::HashSet<_> = psbt
                .inputs
                .iter()
                .filter_map(|i| i.witness_utxo.as_ref())
                .map(|utxo| utxo.script_pubkey.clone())
                .collect();
            let change_amount: u64 = psbt
                .unsigned_tx
                .output
                .iter()
                .filter(|out| user_input_scripts.contains(&out.script_pubkey))
                .map(|out| out.value.to_sat())
                .sum();
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
        user.utxo_state
            .as_ref()
            .map(|u| &u.utxos[..])
            .unwrap_or(&[]),
    )
    .map_err(|e| Status::internal(format!("tx parse: {e}")))?;
    Ok(spent)
}

#[cfg(test)]
mod tests {
    use super::is_authorized_share;

    #[test]
    fn authorized_share_membership() {
        let roster = vec!["aa".to_string(), "bb".to_string()];
        assert!(is_authorized_share(&roster, "aa"));
        assert!(is_authorized_share(&roster, "bb"));
        assert!(!is_authorized_share(&roster, "cc"));
        // Empty roster authorizes nobody.
        assert!(!is_authorized_share(&[], "aa"));
    }
}
