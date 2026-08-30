use serde_json::json;

use crate::shared::SharedServices;

/// One dealer's contribution, as the service's `/enroll/half` route expects it.
pub struct Half<'a> {
    pub role: &'a str,
    pub pairing_group_key: &'a str,
    pub service_verifying_share: &'a str,
    pub pairing_public_key_package_json: &'a str,
    pub ecies_half: &'a str,
}


pub async fn push_half(shared: &SharedServices, service_id_hex: &str, half: Half<'_>) -> bool {
    let Some(base) = shared.service_endpoints.get(&service_id_hex.to_ascii_lowercase()) else {
        tracing::warn!(
            service_id = %service_id_hex,
            "no SERVICE_ENDPOINTS entry; the cosigner's half will not be delivered"
        );
        return false;
    };
    let url = format!("{}/enroll/half", base.trim_end_matches('/'));

    let body = json!({
        "role": half.role,
        "pairing_group_key": half.pairing_group_key,
        "service_verifying_share": half.service_verifying_share,
        "pairing_public_key_package_json": half.pairing_public_key_package_json,
        "ecies_half": half.ecies_half,
    });

    // Bounded: an unreachable service must not hold an enrolment request open.
    let client = match reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!(error = %e, "could not build the delivery client");
            return false;
        }
    };

    match client.post(&url).json(&body).send().await {
        Ok(resp) if resp.status().is_success() => {
            tracing::info!(%url, "delivered the cosigner's half");
            true
        }
        Ok(resp) => {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            tracing::warn!(%url, %status, %body, "the service rejected the cosigner's half");
            false
        }
        Err(e) => {
            tracing::warn!(%url, error = %e, "could not reach the service");
            false
        }
    }
}
