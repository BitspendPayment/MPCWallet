use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

/// Configuration for the enclave client.
#[derive(Debug, Clone)]
pub struct Options {
    /// Hex-encoded PCR0 value to verify against.
    pub expected_pcr0: String,

    /// Hex-encoded SHA256 hashes of secret compressed public keys.
    /// Index 0 maps to PCR16, index 1 to PCR17, etc.
    pub expected_pcrs: Vec<String>,

    /// How long a verified attestation is cached. Default: 60s.
    pub cache_ttl: Duration,

    /// Skip TLS certificate verification. Default: true.
    pub insecure_tls: bool,

    /// Enable GitHub artifact attestation verification for the deployment manifest.
    pub verify_provenance: bool,

    /// Optional GitHub API token for verifying attestations on private repositories.
    pub github_token: Option<String>,
}

impl Default for Options {
    fn default() -> Self {
        Self {
            expected_pcr0: String::new(),
            expected_pcrs: Vec::new(),
            cache_ttl: Duration::from_secs(60),
            insecure_tls: true,
            verify_provenance: false,
            github_token: None,
        }
    }
}

/// Wraps an HTTP response with attestation verification metadata.
#[derive(Debug, Clone)]
pub struct Response {
    pub status_code: u16,
    pub headers: reqwest::header::HeaderMap,
    pub body: Vec<u8>,
    pub signature_verified: bool,
}

/// Contains the verified attestation state (internal cache).
#[derive(Debug, Clone)]
pub struct AttestationResult {
    pub pcr0: String,
    pub pcrs: HashMap<u32, String>,
    /// Hex-encoded compressed secp256k1 pubkey.
    pub attestation_key: String,
    pub verified: bool,
    /// Monotonic timestamp for TTL calculation.
    pub verified_at: Instant,
    /// Unix epoch seconds for serialization across FFI.
    pub verified_at_epoch: u64,
}

/// FFI-friendly attestation status. Serializable, no Instant.
/// Returned by `Client::attestation_status()` without network calls.
#[derive(Debug, Clone, Serialize)]
pub struct AttestationStatus {
    pub verified: bool,
    pub pcr0: String,
    pub attestation_key: String,
    pub verified_at_epoch_secs: u64,
    pub ttl_remaining_secs: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl AttestationStatus {
    /// Status when no attestation has been performed yet.
    pub fn unverified() -> Self {
        Self {
            verified: false,
            pcr0: String::new(),
            attestation_key: String::new(),
            verified_at_epoch_secs: 0,
            ttl_remaining_secs: 0,
            error: None,
        }
    }
}

/// Helper to get current Unix epoch seconds.
pub(crate) fn now_epoch_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Deployment metadata published as a GitHub Release asset (deployment.json).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub base_url: String,
    pub pcr0: String,
    #[serde(default)]
    pub pcr1: String,
    #[serde(default)]
    pub pcr2: String,
    #[serde(default)]
    pub timestamp: String,
    #[serde(default)]
    pub commit: String,
    #[serde(default)]
    pub repo: String,
}

/// JSON structure returned by /v1/enclave-info.
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub(crate) struct EnclaveInfoResponse {
    #[serde(default)]
    pub version: String,
    #[serde(default)]
    pub previous_pcr0: String,
    #[serde(default)]
    pub attestation_pubkey: String,
    #[serde(default)]
    pub error: String,
}
