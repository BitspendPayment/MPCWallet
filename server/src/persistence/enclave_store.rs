use std::collections::HashMap;

use super::traits::{KvStore, PersistenceError, SecretStore};

/// Enclave supervisor-backed persistence store.
///
/// Talks to the enclave supervisor at `http://127.0.0.1:7073` (or configured URL).
/// All requests carry `Authorization: Bearer {mgmt_token}`.
///
/// Storage API (`/v1/storage/`):
///   GET    /v1/storage/{key}           -> 200 + body | 404
///   PUT    /v1/storage/{key}           -> 200  (body = value)
///   DELETE /v1/storage/{key}           -> 200
///   GET    /v1/storage?prefix={pfx}    -> 200 + JSON list of keys
///
/// Secrets API (`/v1/secrets/`):
///   GET    /v1/secrets/{name}          -> 200 + JSON { "value": "..." } | 404
///   PUT    /v1/secrets/{name}          -> 200  (body = JSON { "value": "..." })
///   DELETE /v1/secrets/{name}          -> 200
pub struct EnclaveStore {
    client: reqwest::Client,
    base_url: String,
    mgmt_token: String,
}

impl EnclaveStore {
    pub fn new(supervisor_url: String, mgmt_token: String) -> Self {
        let client = reqwest::Client::new();
        Self {
            client,
            base_url: supervisor_url.trim_end_matches('/').to_string(),
            mgmt_token,
        }
    }

    /// Storage key: tree name is used as a prefix, e.g. `policies/abc123`.
    fn storage_url(&self, tree: &str, key: &str) -> String {
        format!("{}/v1/storage/{tree}/{key}", self.base_url)
    }

    fn auth_header(&self) -> (&str, String) {
        ("Authorization", format!("Bearer {}", self.mgmt_token))
    }

    /// Run an async block synchronously using block_in_place.
    fn block_on<F: std::future::Future<Output = T>, T>(f: F) -> T {
        let rt = tokio::runtime::Handle::current();
        tokio::task::block_in_place(|| rt.block_on(f))
    }
}

impl KvStore for EnclaveStore {
    #[tracing::instrument(skip(self), fields(tree = %tree, key = %key), err)]
    fn get(&self, tree: &str, key: &str) -> Result<Option<String>, PersistenceError> {
        let (h, v) = self.auth_header();
        Self::block_on(async {
            let resp = self.client
                .get(&self.storage_url(tree, key))
                .header(h, &v)
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave get: {e}")))?;

            let status = resp.status();
            tracing::debug!(http_status = %status, "enclave get response");
            if status == reqwest::StatusCode::NOT_FOUND {
                return Ok(None);
            }
            if !status.is_success() {
                let body = resp.text().await.unwrap_or_default();
                return Err(PersistenceError::Backend(
                    format!("enclave get: status {status} body={body}"),
                ));
            }
            let body = resp.text().await
                .map_err(|e| PersistenceError::Backend(format!("enclave get body: {e}")))?;
            Ok(Some(body))
        })
    }

    #[tracing::instrument(skip(self, value), fields(tree = %tree, key = %key, value_bytes = value.len()), err)]
    fn put(&self, tree: &str, key: &str, value: &str) -> Result<(), PersistenceError> {
        let (h, v) = self.auth_header();
        Self::block_on(async {
            let resp = self.client
                .put(&self.storage_url(tree, key))
                .header(h, &v)
                .body(value.to_string())
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave put: {e}")))?;

            let status = resp.status();
            tracing::debug!(http_status = %status, "enclave put response");
            if !status.is_success() {
                let body = resp.text().await.unwrap_or_default();
                return Err(PersistenceError::Backend(
                    format!("enclave put: status {status} body={body}"),
                ));
            }
            Ok(())
        })
    }

    #[tracing::instrument(skip(self), fields(tree = %tree, key = %key), err)]
    fn delete(&self, tree: &str, key: &str) -> Result<(), PersistenceError> {
        let (h, v) = self.auth_header();
        Self::block_on(async {
            let resp = self.client
                .delete(&self.storage_url(tree, key))
                .header(h, &v)
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave delete: {e}")))?;

            let status = resp.status();
            if !status.is_success() {
                let body = resp.text().await.unwrap_or_default();
                return Err(PersistenceError::Backend(
                    format!("enclave delete: status {status} body={body}"),
                ));
            }
            Ok(())
        })
    }

    #[tracing::instrument(skip(self), fields(tree = %tree), err)]
    fn get_all(&self, tree: &str) -> Result<HashMap<String, String>, PersistenceError> {
        let (h, v) = self.auth_header();
        let prefix = format!("{tree}/");
        Self::block_on(async {
            // List keys with the tree prefix
            let list_url = format!("{}/v1/storage?prefix={}", self.base_url, prefix);
            let resp = self.client
                .get(&list_url)
                .header(h, &v)
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave list: {e}")))?;

            if !resp.status().is_success() {
                return Err(PersistenceError::Backend(
                    format!("enclave list: status {}", resp.status()),
                ));
            }

            // Supervisor returns {"keys": ["key1", "key2", ...]}.
            #[derive(serde::Deserialize)]
            struct ListResponse { keys: Vec<String> }
            let list: ListResponse = resp.json().await
                .map_err(|e| PersistenceError::Backend(format!("enclave list parse: {e}")))?;
            let keys = list.keys;

            let mut result = HashMap::new();
            let (ah, av) = ("Authorization", format!("Bearer {}", self.mgmt_token));
            for full_key in keys {
                let short_key = full_key.strip_prefix(&prefix)
                    .unwrap_or(&full_key)
                    .to_string();
                if short_key.is_empty() {
                    continue;
                }
                let get_url = format!("{}/v1/storage/{}", self.base_url, full_key);
                match self.client.get(&get_url).header(ah, &av).send().await {
                    Ok(r) if r.status().is_success() => {
                        if let Ok(val) = r.text().await {
                            result.insert(short_key, val);
                        }
                    }
                    _ => continue,
                }
            }
            Ok(result)
        })
    }

    #[tracing::instrument(skip(self), fields(tree = %tree), err)]
    fn clear(&self, tree: &str) -> Result<(), PersistenceError> {
        let (h, v) = self.auth_header();
        let prefix = format!("{tree}/");
        Self::block_on(async {
            let list_url = format!("{}/v1/storage?prefix={}", self.base_url, prefix);
            let resp = self.client
                .get(&list_url)
                .header(h, &v)
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave clear list: {e}")))?;

            if !resp.status().is_success() {
                return Err(PersistenceError::Backend(
                    format!("enclave clear list: status {}", resp.status()),
                ));
            }

            #[derive(serde::Deserialize)]
            struct ListResponse { keys: Vec<String> }
            let list: ListResponse = resp.json().await
                .map_err(|e| PersistenceError::Backend(format!("enclave clear parse: {e}")))?;
            let keys = list.keys;

            let (ah, av) = ("Authorization", format!("Bearer {}", self.mgmt_token));
            for full_key in keys {
                let del_url = format!("{}/v1/storage/{}", self.base_url, full_key);
                let _ = self.client.delete(&del_url).header(ah, &av).send().await;
            }
            Ok(())
        })
    }
}

impl SecretStore for EnclaveStore {
    #[tracing::instrument(skip(self), fields(name = %name), err)]
    fn get_secret(&self, name: &str) -> Result<Option<String>, PersistenceError> {
        let (h, v) = self.auth_header();
        let url = format!("{}/v1/secrets/{name}", self.base_url);
        Self::block_on(async {
            let resp = self.client
                .get(&url)
                .header(h, &v)
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave get_secret: {e}")))?;

            if resp.status() == reqwest::StatusCode::NOT_FOUND {
                return Ok(None);
            }
            if !resp.status().is_success() {
                return Err(PersistenceError::Backend(
                    format!("enclave get_secret: status {}", resp.status()),
                ));
            }
            let body: serde_json::Value = resp.json().await
                .map_err(|e| PersistenceError::Backend(format!("enclave get_secret parse: {e}")))?;
            Ok(body["value"].as_str().map(|s| s.to_string()))
        })
    }

    #[tracing::instrument(skip(self, value), fields(name = %name, value_bytes = value.len()), err)]
    fn put_secret(&self, name: &str, value: &str) -> Result<(), PersistenceError> {
        let (h, v) = self.auth_header();
        let url = format!("{}/v1/secrets/{name}", self.base_url);
        let body = serde_json::json!({ "value": value });
        Self::block_on(async {
            let resp = self.client
                .put(&url)
                .header(h, &v)
                .json(&body)
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave put_secret: {e}")))?;

            if !resp.status().is_success() {
                return Err(PersistenceError::Backend(
                    format!("enclave put_secret: status {}", resp.status()),
                ));
            }
            Ok(())
        })
    }

    #[tracing::instrument(skip(self), fields(name = %name), err)]
    fn delete_secret(&self, name: &str) -> Result<(), PersistenceError> {
        let (h, v) = self.auth_header();
        let url = format!("{}/v1/secrets/{name}", self.base_url);
        Self::block_on(async {
            let resp = self.client
                .delete(&url)
                .header(h, &v)
                .send()
                .await
                .map_err(|e| PersistenceError::Backend(format!("enclave delete_secret: {e}")))?;

            if !resp.status().is_success() {
                return Err(PersistenceError::Backend(
                    format!("enclave delete_secret: status {}", resp.status()),
                ));
            }
            Ok(())
        })
    }
}
