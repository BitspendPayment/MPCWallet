//! Sled-backed policy persistence. Shared by `CosignerInstance` (via
//! `handlers::helpers::ensure_policy_loaded`) and `DkgCoordinator` (via
//! the DKG step3 finalize path).

use tonic::Status;

use crate::policy::PolicyState;
use crate::shared::SharedServices;

/// Persist policy state and the server's DKG secret (the latter via SecretStore,
/// keyed by the group key).
pub fn persist_policy(
    shared: &SharedServices,
    user_id_hex: &str,
    policy: &PolicyState,
) -> Result<(), Status> {
    // Policies are keyed by the GROUP KEY (cosigner_id). If a member's verifying
    // share is passed, resolve it to its group key via `policy_owner_idx` so updates
    // land on the canonical row instead of forking a divergent one.
    let key = shared
        .persistence
        .get("policy_owner_idx", user_id_hex)
        .ok()
        .flatten()
        .unwrap_or_else(|| user_id_hex.to_string());
    let user_id_hex = key.as_str();
    let json = serde_json::to_string(policy)
        .map_err(|e| Status::internal(format!("serialization error: {e}")))?;
    shared
        .persistence
        .put("policies", user_id_hex, &json)
        .map_err(|e| {
            tracing::error!(error = %e, user_id = %user_id_hex, "persistence put policies failed");
            Status::internal(format!("persistence write error: {e}"))
        })?;
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
