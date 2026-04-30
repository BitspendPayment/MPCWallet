/// Authentication message format.
/// Mirrors the Dart `AuthMessage` from `threshold/lib/auth/auth_message.dart`.
///
/// Format: `MPC_WALLET_AUTH_V1:<operation>:<timestamp_ms>:<user_id_hex>`

pub const AUTH_PREFIX: &str = "MPC_WALLET_AUTH_V1";
pub const MAX_TIMESTAMP_DRIFT_MS: i64 = 5 * 60 * 1000; // 5 minutes

// Operation constants (must match client-side values in auth_message.dart)
pub const OP_SIGN_STEP1: &str = "SIGN_STEP1";
pub const OP_SIGN_STEP2: &str = "SIGN_STEP2";
pub const OP_REFRESH_STEP1: &str = "REFRESH_STEP1";
pub const OP_REFRESH_STEP2: &str = "REFRESH_STEP2";
pub const OP_REFRESH_STEP3: &str = "REFRESH_STEP3";
pub const OP_GET_POLICY_ID: &str = "GET_POLICY_ID";
pub const OP_FETCH_HISTORY: &str = "FETCH_HISTORY";
pub const OP_FETCH_RECENT_TXS: &str = "FETCH_RECENT_TXS";
pub const OP_SUBSCRIBE_HISTORY: &str = "SUBSCRIBE_HISTORY";
pub const OP_UPDATE_POLICY: &str = "UPDATE_POLICY";
pub const OP_DELETE_POLICY: &str = "DELETE_POLICY";
pub const OP_GET_ARK_INFO: &str = "GET_ARK_INFO";
pub const OP_GET_ARK_ADDRESS: &str = "GET_ARK_ADDRESS";
pub const OP_GET_BOARDING_ADDRESS: &str = "GET_BOARDING_ADDRESS";
pub const OP_LIST_VTXOS: &str = "LIST_VTXOS";
pub const OP_SEND_VTXO: &str = "SEND_VTXO";
pub const OP_REDEEM_VTXO: &str = "REDEEM_VTXO";
pub const OP_SETTLE: &str = "SETTLE";
pub const OP_SETTLE_DELEGATE: &str = "SETTLE_DELEGATE";
pub const OP_LIST_ARK_TXS: &str = "LIST_ARK_TXS";
pub const OP_CHECK_BOARDING_BALANCE: &str = "CHECK_BOARDING_BALANCE";

const RECOVERY_PREFIX: &str = "MPC_WALLET_RECOVERY_V1";

/// Build the auth message bytes that should have been signed.
/// Returns SHA-256 hash of the canonical message (matches Dart client's AuthMessage.messageBytes).
pub fn build_auth_message(operation: &str, timestamp_ms: i64, user_id_hex: &str) -> Vec<u8> {
    use sha2::{Digest, Sha256};
    let msg = format!("{}:{}:{}:{}", AUTH_PREFIX, operation, timestamp_ms, user_id_hex);
    Sha256::digest(msg.as_bytes()).to_vec()
}

/// Build the update-policy recovery message (SHA-256 hashed).
pub fn build_update_policy_message(
    policy_id: &str,
    threshold_sats: i64,
    interval_seconds: i64,
    timestamp_ms: i64,
    user_id_hex: &str,
) -> Vec<u8> {
    use sha2::{Digest, Sha256};
    let canonical = format!(
        "{}:UPDATE_POLICY:{}:{}:{}:{}:{}",
        RECOVERY_PREFIX, policy_id, threshold_sats, interval_seconds, timestamp_ms, user_id_hex
    );
    Sha256::digest(canonical.as_bytes()).to_vec()
}

/// Build the delete-policy recovery message (SHA-256 hashed).
pub fn build_delete_policy_message(
    policy_id: &str,
    timestamp_ms: i64,
    user_id_hex: &str,
) -> Vec<u8> {
    use sha2::{Digest, Sha256};
    let canonical = format!(
        "{}:DELETE_POLICY:{}:{}:{}",
        RECOVERY_PREFIX, policy_id, timestamp_ms, user_id_hex
    );
    Sha256::digest(canonical.as_bytes()).to_vec()
}
