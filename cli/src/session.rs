//! Session tokens.
//!
//! The `ark/*` routes authenticate against the wallet's GROUP key, whose private half nobody holds
//! — a Schnorr signature is impossible there, so they are token-only. The app gets its token from
//! the passkey flow; a regtest driver can't, so it mints one with the dev `WEBAUTH_TOKEN_SECRET`
//! the Makefile pins. Regtest-only, not an auth bypass.
//!
//! Format matches `auth::session::SessionAuthority::mint` (EdDSA JWT).

use anyhow::{anyhow, Result};
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine as _;
use ed25519_dalek::{Signer, SigningKey};
use serde_json::json;

/// The dev secret the Makefile pins for `software-ark` / `regtest-ark`.
const DEV_TOKEN_SECRET: &str = "6d706377616c6c65742d6465762d746f6b656e2d7365637265742d3332622121";

/// Mint a session token whose `sub` is `group_key`, valid for `ttl_secs`.
pub fn mint(group_key: &str, ttl_secs: i64) -> Result<String> {
    let secret_hex =
        std::env::var("WEBAUTH_TOKEN_SECRET").unwrap_or_else(|_| DEV_TOKEN_SECRET.to_string());
    let seed: [u8; 32] = hex::decode(secret_hex.trim())
        .map_err(|e| anyhow!("WEBAUTH_TOKEN_SECRET is not hex: {e}"))?
        .as_slice()
        .try_into()
        .map_err(|_| anyhow!("WEBAUTH_TOKEN_SECRET must be 32 bytes of hex"))?;
    let signing = SigningKey::from_bytes(&seed);

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    let claims = json!({
        "sub": group_key,          // the runtime compares this to hex(user_id)
        "exp": now + ttl_secs,
        "iat": now,
        "jti": format!("merlin-cli-{now}"),
    });

    let header = URL_SAFE_NO_PAD.encode(br#"{"alg":"EdDSA","typ":"JWT"}"#);
    let payload = URL_SAFE_NO_PAD.encode(serde_json::to_vec(&claims)?);
    let signing_input = format!("{header}.{payload}");
    let sig = signing.sign(signing_input.as_bytes());
    Ok(format!(
        "{signing_input}.{}",
        URL_SAFE_NO_PAD.encode(sig.to_bytes())
    ))
}
