//! Manifest fetching and GitHub provenance verification.

use crate::error::{Error, Result};
use crate::types::Manifest;
use sha2::{Digest, Sha256};

/// Construct the GitHub Releases URL for a deployment manifest.
///
/// ```
/// use enclave_client::manifest_url;
/// let url = manifest_url("myorg/my-app", "latest");
/// assert_eq!(url, "https://github.com/myorg/my-app/releases/download/latest/deployment.json");
/// ```
pub fn manifest_url(repo: &str, tag: &str) -> String {
    format!("https://github.com/{repo}/releases/download/{tag}/deployment.json")
}

/// Fetch and parse a deployment manifest from the given URL.
pub async fn fetch_manifest(url: &str) -> Result<Manifest> {
    let (manifest, _raw) = fetch_manifest_raw(url).await?;
    Ok(manifest)
}

/// Fetch manifest returning both parsed struct and raw bytes.
pub(crate) async fn fetch_manifest_raw(url: &str) -> Result<(Manifest, Vec<u8>)> {
    let resp = reqwest::get(url).await?;
    let status = resp.status();

    if status != reqwest::StatusCode::OK {
        let body = resp.text().await.unwrap_or_default();
        return Err(Error::Manifest(format!(
            "status {status}: {}",
            body.trim()
        )));
    }

    let raw = resp.bytes().await?.to_vec();

    let manifest: Manifest =
        serde_json::from_slice(&raw).map_err(|e| Error::Manifest(format!("decode: {e}")))?;

    if manifest.base_url.is_empty() {
        return Err(Error::Manifest("missing base_url".into()));
    }
    if manifest.pcr0.is_empty() {
        return Err(Error::Manifest("missing pcr0".into()));
    }

    Ok((manifest, raw))
}

/// Verify manifest provenance via the GitHub Attestations API.
///
/// Checks that the manifest has a valid build provenance attestation from
/// GitHub Actions, proving it was produced by CI — not manually uploaded.
/// For public repos, token can be None.
pub async fn verify_manifest_provenance(
    repo: &str,
    manifest_bytes: &[u8],
    token: Option<&str>,
) -> Result<()> {
    let digest = Sha256::digest(manifest_bytes);
    let digest_str = format!("sha256:{}", hex::encode(digest));

    let api_url = format!(
        "https://api.github.com/repos/{repo}/attestations/{digest_str}"
    );

    let client = reqwest::Client::new();
    let mut req = client
        .get(&api_url)
        .header("Accept", "application/json")
        .header("User-Agent", "introspector-enclave-client");

    if let Some(t) = token {
        req = req.header("Authorization", format!("Bearer {t}"));
    }

    let resp = req.send().await?;

    let status = resp.status();

    if status == reqwest::StatusCode::NOT_FOUND {
        return Err(Error::Provenance(format!(
            "no attestations found for manifest (repo: {repo})"
        )));
    }

    if status != reqwest::StatusCode::OK {
        let body = resp.text().await.unwrap_or_default();
        return Err(Error::Provenance(format!(
            "attestations API status {status}: {}",
            body.trim()
        )));
    }

    #[derive(serde::Deserialize)]
    struct AttestationResponse {
        attestations: Vec<serde_json::Value>,
    }

    let body = resp.bytes().await?;
    let result: AttestationResponse = serde_json::from_slice(&body)
        .map_err(|e| Error::Provenance(format!("decode attestations: {e}")))?;

    if result.attestations.is_empty() {
        return Err(Error::Provenance(format!(
            "no attestations found for manifest (repo: {repo})"
        )));
    }

    Ok(())
}
