//! Sled-backed policy persistence. Shared by `CosignerInstance` (via
//! `handlers::helpers::ensure_policy_loaded`) and `DkgCoordinator` (via
//! the DKG step3 finalize path).

use tonic::Status;

use crate::policy::PolicyState;
use crate::shared::SharedServices;

/// Persist policy state, the recovery-id index, and the DKG secret.
/// Recovery lookups read `policy_recovery_idx` from sled directly — no
/// in-memory cache to keep in sync.
pub fn persist_policy(
    shared: &SharedServices,
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
