//! Session-token authority.
//!
//! The cosigner runs the WebAuthn server itself (register/assert + PRF), and after a successful
//! assertion it MINTS a short-lived session token that the client then presents (as a Bearer
//! header) on subsequent requests. The cosigner both mints and verifies these tokens with its OWN
//! Ed25519 keypair, derived from a 32-byte secret read from the environment
//! (`WEBAUTH_TOKEN_SECRET`) — a 32-byte seed IS an Ed25519 private key; the public half is derived.
//!
//! Token format: a compact JWT-shaped `header.payload.signature`, EdDSA (Ed25519) over
//! `base64url(header) + "." + base64url(payload)`. Claims `{ sub: <group_key hex>, exp, iat, jti }`;
//! `sub` MUST equal the request's `user_id`, so a token authenticates only its own user.
//!
//! We sign/verify directly with `ed25519-dalek` (not `jsonwebtoken`) to avoid the ring/PKCS8 seed
//! friction — the cosigner is the only party that mints or verifies these tokens.

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};

/// Clock-skew leeway when checking `exp` (seconds).
const EXP_LEEWAY_SECS: i64 = 60;

/// Claims the cosigner signs into a session token.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionClaims {
    /// Authenticated user = the wallet's group key (compressed verifying-share hex).
    pub sub: String,
    /// Expiry (unix seconds). Enforced by [`SessionAuthority::verify`].
    pub exp: i64,
    /// Issued-at (unix seconds).
    #[serde(default)]
    pub iat: i64,
    /// Unique token id (for future revocation / audit).
    #[serde(default)]
    pub jti: String,
}

impl SessionClaims {
    /// Whether this (already signature+exp-verified) token authenticates `user_id`: its `sub` must
    /// equal the request's user id (the wallet's group key, hex). Binding the token to the user is
    /// what stops a valid token for user A from authorizing an action on user B.
    pub fn authenticates(&self, user_id: &[u8]) -> bool {
        self.sub.eq_ignore_ascii_case(&hex::encode(user_id))
    }
}

/// Mints and verifies session tokens with the cosigner's own Ed25519 keypair.
/// When no secret is configured (empty/invalid env) the authority is disabled: [`mint`] errors and
/// [`verify`] rejects every token, so callers fall back to the legacy Schnorr auth path.
pub struct SessionAuthority {
    signing: Option<SigningKey>,
    verifying: Option<VerifyingKey>,
}

impl SessionAuthority {
    /// Build from a 32-byte secret (hex, 64 chars) — the Ed25519 seed. Empty or malformed input
    /// yields a disabled authority ([`enabled`](Self::enabled) → false).
    pub fn from_secret_hex(secret_hex: &str) -> Self {
        let trimmed = secret_hex.trim();
        if trimmed.is_empty() {
            return Self { signing: None, verifying: None };
        }
        let seed = match hex::decode(trimmed) {
            Ok(b) if b.len() == 32 => b,
            _ => {
                tracing::warn!(
                    "WEBAUTH_TOKEN_SECRET is not 32 hex-encoded bytes; session-token auth disabled"
                );
                return Self { signing: None, verifying: None };
            }
        };
        let arr: [u8; 32] = seed.try_into().expect("length checked above");
        let signing = SigningKey::from_bytes(&arr);
        let verifying = signing.verifying_key();
        Self { signing: Some(signing), verifying: Some(verifying) }
    }

    /// Whether a usable keypair is configured.
    pub fn enabled(&self) -> bool {
        self.signing.is_some()
    }

    /// Mint a signed session token for `claims`.
    pub fn mint(&self, claims: &SessionClaims) -> Result<String, String> {
        let signing = self
            .signing
            .as_ref()
            .ok_or_else(|| "session-token authority disabled".to_string())?;
        let header = URL_SAFE_NO_PAD.encode(br#"{"alg":"EdDSA","typ":"JWT"}"#);
        let payload = URL_SAFE_NO_PAD.encode(
            serde_json::to_vec(claims).map_err(|e| format!("claims encode: {e}"))?,
        );
        let signing_input = format!("{header}.{payload}");
        let sig = signing.sign(signing_input.as_bytes());
        Ok(format!(
            "{signing_input}.{}",
            URL_SAFE_NO_PAD.encode(sig.to_bytes())
        ))
    }

    /// Verify a Bearer token: Ed25519 signature (our key) + `exp`. Returns the claims on success.
    /// The caller must still check `claims.authenticates(user_id)` before trusting it for that user.
    pub fn verify(&self, token: &str) -> Result<SessionClaims, String> {
        let verifying = self
            .verifying
            .as_ref()
            .ok_or_else(|| "session-token authority disabled".to_string())?;

        let mut parts = token.split('.');
        let header_b64 = parts.next().ok_or("malformed token")?;
        let payload_b64 = parts.next().ok_or("malformed token")?;
        let sig_b64 = parts.next().ok_or("malformed token")?;
        if parts.next().is_some() {
            return Err("malformed token".into());
        }

        let sig_bytes = URL_SAFE_NO_PAD
            .decode(sig_b64)
            .map_err(|e| format!("bad signature b64: {e}"))?;
        let sig_arr: [u8; 64] = sig_bytes
            .as_slice()
            .try_into()
            .map_err(|_| "signature must be 64 bytes")?;
        let sig = Signature::from_bytes(&sig_arr);

        let signing_input = format!("{header_b64}.{payload_b64}");
        verifying
            .verify(signing_input.as_bytes(), &sig)
            .map_err(|_| "invalid token signature".to_string())?;

        let claims_bytes = URL_SAFE_NO_PAD
            .decode(payload_b64)
            .map_err(|e| format!("bad payload b64: {e}"))?;
        let claims: SessionClaims =
            serde_json::from_slice(&claims_bytes).map_err(|e| format!("bad claims: {e}"))?;

        let now = now_secs();
        if claims.exp < now - EXP_LEEWAY_SECS {
            return Err("token expired".into());
        }
        Ok(claims)
    }
}

fn now_secs() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    // A throwaway 32-byte Ed25519 seed for tests.
    const SEED_HEX: &str = "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";

    fn claims(sub: &str, exp: i64) -> SessionClaims {
        SessionClaims { sub: sub.into(), exp, iat: exp - 300, jti: "t1".into() }
    }

    fn now() -> i64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64
    }

    #[test]
    fn mint_then_verify_round_trips() {
        let auth = SessionAuthority::from_secret_hex(SEED_HEX);
        assert!(auth.enabled());
        let token = auth.mint(&claims("02aabbcc", now() + 300)).unwrap();
        let got = auth.verify(&token).expect("valid token");
        assert_eq!(got.sub, "02aabbcc");
        assert!(got.authenticates(&hex::decode("02aabbcc").unwrap()));
        assert!(!got.authenticates(&hex::decode("02ffffff").unwrap()));
    }

    #[test]
    fn expired_token_rejected() {
        let auth = SessionAuthority::from_secret_hex(SEED_HEX);
        let token = auth.mint(&claims("02aabbcc", now() - 120)).unwrap();
        assert!(auth.verify(&token).is_err());
    }

    #[test]
    fn wrong_key_rejected() {
        let a = SessionAuthority::from_secret_hex(SEED_HEX);
        let b = SessionAuthority::from_secret_hex(
            "ff02030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20",
        );
        let token = a.mint(&claims("02aabbcc", now() + 300)).unwrap();
        assert!(b.verify(&token).is_err());
    }

    #[test]
    fn tampered_payload_rejected() {
        let auth = SessionAuthority::from_secret_hex(SEED_HEX);
        let token = auth.mint(&claims("02aabbcc", now() + 300)).unwrap();
        // Swap the payload segment for a forged one; signature must fail.
        let mut parts: Vec<&str> = token.split('.').collect();
        let forged = URL_SAFE_NO_PAD.encode(br#"{"sub":"02deadbeef","exp":9999999999}"#);
        parts[1] = &forged;
        assert!(auth.verify(&parts.join(".")).is_err());
    }

    #[test]
    fn disabled_authority_rejects() {
        let auth = SessionAuthority::from_secret_hex("");
        assert!(!auth.enabled());
        assert!(auth.mint(&claims("02aabbcc", now() + 300)).is_err());
        assert!(auth.verify("a.b.c").is_err());
    }

    #[test]
    fn bad_secret_length_disables() {
        assert!(!SessionAuthority::from_secret_hex("abcd").enabled());
    }
}
