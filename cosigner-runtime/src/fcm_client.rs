//! Firebase Cloud Messaging HTTP v1 client.
//!
//! Sends data-only push notifications to wake the recipient device after a
//! VTXO arrives, so the app can re-delegate while still in the background.
//!
//! Auth: Google service account JWT-bearer flow. The service account JSON
//! lives in the enclave KMS-encrypted secret bundle (`FCM_SERVICE_ACCOUNT_CIPHERTEXT`),
//! decrypted at startup. Access tokens are minted on demand and cached for
//! 1 hour minus 5-minute slack.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

const FCM_SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const SAFETY_SLACK_SECS: i64 = 5 * 60;

#[derive(Debug, Clone, Deserialize)]
pub struct ServiceAccount {
    pub project_id: String,
    pub client_email: String,
    pub private_key: String,
    pub token_uri: Option<String>,
}

struct CachedToken {
    access_token: String,
    expires_at: i64,
}

pub struct FcmClient {
    sa: ServiceAccount,
    http: reqwest::Client,
    encoding_key: EncodingKey,
    cache: Arc<Mutex<Option<CachedToken>>>,
}

impl FcmClient {
    /// Parse a service-account JSON string and build a client.
    pub fn from_service_account_json(json: &str) -> Result<Self, String> {
        let sa: ServiceAccount =
            serde_json::from_str(json).map_err(|e| format!("parse service account: {e}"))?;
        let encoding_key = EncodingKey::from_rsa_pem(sa.private_key.as_bytes())
            .map_err(|e| format!("parse RSA private key: {e}"))?;
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(15))
            .build()
            .map_err(|e| format!("build reqwest client: {e}"))?;
        Ok(Self {
            sa,
            http,
            encoding_key,
            cache: Arc::new(Mutex::new(None)),
        })
    }

    /// Send a data-only push to one FCM token. Errors are surfaced so the
    /// caller can log them; failures don't propagate further.
    pub async fn send_data(
        &self,
        target_token: &str,
        data: &HashMap<String, String>,
    ) -> Result<(), String> {
        let access = self.access_token().await?;
        let url = format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            self.sa.project_id
        );
        let body = serde_json::json!({
            "message": {
                "token": target_token,
                "data": data,
                // Android: high priority + content-available so the device wakes
                // for background processing.
                "android": {
                    "priority": "HIGH",
                },
                // iOS: silent push (content-available=1) + apns-priority=5
                // (Apple requires <=5 for content-available). Without this APNS
                // drops the message rather than waking the app.
                "apns": {
                    "headers": {
                        "apns-priority": "5",
                        "apns-push-type": "background",
                    },
                    "payload": {
                        "aps": {
                            "content-available": 1,
                        }
                    }
                }
            }
        });
        let resp = self
            .http
            .post(&url)
            .bearer_auth(&access)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("FCM POST: {e}"))?;
        let status = resp.status();
        if !status.is_success() {
            let body = resp.text().await.unwrap_or_default();
            return Err(format!("FCM send returned {status}: {body}"));
        }
        Ok(())
    }

    async fn access_token(&self) -> Result<String, String> {
        let now = unix_secs();
        {
            let cache = self.cache.lock().await;
            if let Some(t) = cache.as_ref() {
                if t.expires_at - SAFETY_SLACK_SECS > now {
                    return Ok(t.access_token.clone());
                }
            }
        }
        let new = self.mint_token().await?;
        let mut cache = self.cache.lock().await;
        *cache = Some(CachedToken {
            access_token: new.access_token.clone(),
            expires_at: now + new.expires_in,
        });
        Ok(new.access_token)
    }

    async fn mint_token(&self) -> Result<TokenResponse, String> {
        let now = unix_secs();
        let claims = JwtClaims {
            iss: self.sa.client_email.clone(),
            scope: FCM_SCOPE.to_string(),
            aud: self.sa.token_uri.clone().unwrap_or_else(|| TOKEN_URL.to_string()),
            iat: now,
            exp: now + 3600,
        };
        let header = Header::new(Algorithm::RS256);
        let jwt = encode(&header, &claims, &self.encoding_key)
            .map_err(|e| format!("sign JWT: {e}"))?;
        let resp = self
            .http
            .post(TOKEN_URL)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
                ("assertion", &jwt),
            ])
            .send()
            .await
            .map_err(|e| format!("OAuth POST: {e}"))?;
        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(format!("OAuth token mint {status}: {body}"));
        }
        resp.json::<TokenResponse>()
            .await
            .map_err(|e| format!("parse OAuth response: {e}"))
    }
}

#[derive(Debug, Serialize)]
struct JwtClaims {
    iss: String,
    scope: String,
    aud: String,
    iat: i64,
    exp: i64,
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: i64,
}

fn unix_secs() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}
