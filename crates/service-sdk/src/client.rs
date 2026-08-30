//! HTTP to the cosigner, with the request authentication it expects.

use crate::error::{Error, Result};
use crate::share::ServiceShare;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

pub const OP_SIGN_STEP1: &str = "SIGN_STEP1";
pub const OP_SIGN_STEP2: &str = "SIGN_STEP2";

const AUTH_PREFIX: &str = "MPC_WALLET_AUTH_V1";

/// `sha256("MPC_WALLET_AUTH_V1:<op>:<timestamp_ms>:<user_id_hex>")` — must stay byte-identical to
/// the cosigner's `auth::message::build_auth_message`.
pub fn build_auth_message(operation: &str, timestamp_ms: i64, user_id_hex: &str) -> Vec<u8> {
    Sha256::digest(format!("{AUTH_PREFIX}:{operation}:{timestamp_ms}:{user_id_hex}").as_bytes())
        .to_vec()
}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// A client for one cosigner.
///
/// NOTE ON TRANSPORT: this speaks plain HTTP(S). The phone client additionally verifies the
/// enclave's attestation (PCR0 + response signatures) before trusting a cosigner, and a service
/// holding a share of the group key deserves the same. Attested transport is a deliberate gap
/// here — see `require_attestation` — not an oversight.
pub struct CosignerClient {
    base_url: String,
    http: reqwest::Client,
}

impl CosignerClient {
    pub fn new(base_url: impl Into<String>) -> Self {
        Self {
            base_url: base_url.into().trim_end_matches('/').to_string(),
            http: reqwest::Client::new(),
        }
    }

    /// Reject a non-TLS cosigner URL. Call this in anything that is not a local regtest run: a
    /// service share is half of a spending key, and plaintext transport leaks every ceremony.
    pub fn require_secure_transport(&self) -> Result<()> {
        if self.base_url.starts_with("https://") {
            return Ok(());
        }
        Err(Error::Config(format!(
            "refusing a non-TLS cosigner URL ({}); pass a https:// endpoint outside local testing",
            self.base_url
        )))
    }

    async fn post(&self, path: &str, body: Value) -> Result<Value> {
        let url = format!("{}{path}", self.base_url);
        let resp = self
            .http
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| Error::Transport(format!("POST {url}: {e}")))?;
        let status = resp.status();
        let text = resp
            .text()
            .await
            .map_err(|e| Error::Transport(format!("read {url}: {e}")))?;
        if !status.is_success() {
            return Err(Error::Cosigner(format!("{status}: {text}")));
        }
        serde_json::from_str(&text)
            .map_err(|e| Error::Transport(format!("undecodable response from {url}: {e} ({text})")))
    }

    /// Open a FROST ceremony on `group_key` with the service's commitments.
    #[allow(clippy::too_many_arguments)]
    pub async fn sign_step1(
        &self,
        share: &ServiceShare,
        group_key: &str,
        hiding: &[u8; 33],
        binding: &[u8; 33],
        message_to_sign: &[u8],
        full_transaction: &[u8],
        script_path_spend: bool,
    ) -> Result<SignStep1Response> {
        // Identity on the wire is the VERIFYING SHARE, proved by signing with the matching
        // secret share — the same convention the wallet uses for its own half of the 2-of-2.
        let ts = now_ms();
        let vk_hex = share.verifying_share_hex.clone();
        let sig = share
            .auth_signer()?
            .sign(&build_auth_message(OP_SIGN_STEP1, ts, &vk_hex));

        let v = self
            .post(
                &format!("/api/u/{group_key}/sign/step1"),
                json!({
                    "user_id": vk_hex,
                    "hiding_commitment": hex::encode(hiding),
                    "binding_commitment": hex::encode(binding),
                    "message_to_sign": hex::encode(message_to_sign),
                    "full_transaction": hex::encode(full_transaction),
                    "script_path_spend": script_path_spend,
                    "signature": hex::encode(sig),
                    "timestamp_ms": ts,
                }),
            )
            .await?;

        let commitments = v
            .get("commitments")
            .and_then(|c| c.as_object())
            .ok_or_else(|| Error::Transport("step1 response has no commitments".into()))?
            .iter()
            .map(|(k, c)| {
                (
                    k.clone(),
                    (
                        c.get("hiding").and_then(|x| x.as_str()).unwrap_or("").to_string(),
                        c.get("binding").and_then(|x| x.as_str()).unwrap_or("").to_string(),
                    ),
                )
            })
            .collect();

        Ok(SignStep1Response {
            commitments,
            message_to_sign: v
                .get("message_to_sign")
                .and_then(|m| m.as_str())
                .unwrap_or_default()
                .to_string(),
        })
    }

    /// Deliver the service's signature share and receive the aggregated signature.
    pub async fn sign_step2(
        &self,
        share: &ServiceShare,
        group_key: &str,
        signature_share: &[u8; 32],
    ) -> Result<[u8; 64]> {
        let ts = now_ms();
        let vk_hex = share.verifying_share_hex.clone();
        let sig = share
            .auth_signer()?
            .sign(&build_auth_message(OP_SIGN_STEP2, ts, &vk_hex));

        let v = self
            .post(
                &format!("/api/u/{group_key}/sign/step2"),
                json!({
                    "user_id": vk_hex,
                    "signature_share": hex::encode(signature_share),
                    "signature": hex::encode(sig),
                    "timestamp_ms": ts,
                }),
            )
            .await?;

        let r = hex::decode(v.get("r_point").and_then(|x| x.as_str()).unwrap_or_default())
            .map_err(|e| Error::Transport(format!("bad r_point: {e}")))?;
        let z = hex::decode(v.get("z_scalar").and_then(|x| x.as_str()).unwrap_or_default())
            .map_err(|e| Error::Transport(format!("bad z_scalar: {e}")))?;
        if r.len() != 32 || z.len() != 32 {
            return Err(Error::Transport(format!(
                "aggregated signature has the wrong shape (r={}B, z={}B)",
                r.len(),
                z.len()
            )));
        }
        let mut out = [0u8; 64];
        out[..32].copy_from_slice(&r);
        out[32..].copy_from_slice(&z);
        Ok(out)
    }
}

/// The cosigner's round-1 reply: every participant's commitments, and the message it will
/// actually sign — which for a conditioned pairing may differ from what was requested.
#[derive(Debug, Clone)]
pub struct SignStep1Response {
    /// identifier hex -> (hiding hex, binding hex)
    pub commitments: std::collections::BTreeMap<String, (String, String)>,
    pub message_to_sign: String,
}
