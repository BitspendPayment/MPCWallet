//! Sled-backed policy persistence. Shared by `CosignerInstance` (via
//! `handlers::helpers::ensure_policy_loaded`) and `OnboardingManager` (via
//! the DKG step3 finalize path).

use tonic::Status;

use crate::policy::PolicyState;
use crate::shared::SharedServices;

/// Persist the PUBLIC policy projection. Plan A Phase 2: the server's Ark/MuSig2 `dkg-secret` is NO
/// LONGER written to the host `SecretStore` — it lives only in the guest's sealed snapshot (seeded
/// via `SeedPolicy` at onboarding). The host keeps no plaintext key copy.
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
    Ok(())
}
