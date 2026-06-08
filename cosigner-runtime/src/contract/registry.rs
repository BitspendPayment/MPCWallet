//! Content-addressed contract resolution + a compiled-component cache.
//!
//! A `ContractRegistry` maps an on-chain `contract_id` (= sha256 of the
//! component bytes) to the verified component bytes. Backends are swappable —
//! an in-memory map and a local directory now; a Warg (WebAssembly registry)
//! backend later, all content-addressed by the same sha256. `ContractHost`
//! combines a registry with the sandboxed `ContractEngine` and memoises the
//! compiled `Component` per id (compilation is expensive).

use std::collections::HashMap;
use std::path::PathBuf;

use parking_lot::Mutex;
use wasmtime::component::Component;

use super::crypto_host;
use super::{ContractEngine, EvalContext, Verdict};

/// On-chain contract identity: sha256(component_wasm), revealed in the spend
/// witness and committed (hashed once more) in the eVTXO tapleaf.
pub type ContractId = [u8; 32];

#[derive(Debug)]
pub enum RegistryError {
    NotFound,
    /// Fetched bytes did not hash to the requested id (content-address violation).
    HashMismatch,
    Backend(String),
}

impl core::fmt::Display for RegistryError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            RegistryError::NotFound => write!(f, "contract not found"),
            RegistryError::HashMismatch => write!(f, "content hash mismatch"),
            RegistryError::Backend(e) => write!(f, "registry backend: {e}"),
        }
    }
}

fn sha256_id(bytes: &[u8]) -> ContractId {
    let mut id = [0u8; 32];
    id.copy_from_slice(&crypto_host::sha256(bytes));
    id
}

/// Resolve a contract code-hash to its component bytes. Implementations MUST
/// verify the returned bytes hash to the requested id before returning.
pub trait ContractRegistry: Send + Sync {
    fn fetch(&self, id: &ContractId) -> Result<Vec<u8>, RegistryError>;
}

/// In-memory registry (tests, embedded contracts). `insert` keys by content hash.
#[derive(Default)]
pub struct InMemoryRegistry {
    map: HashMap<ContractId, Vec<u8>>,
}

impl InMemoryRegistry {
    pub fn new() -> Self {
        Self::default()
    }
    /// Insert bytes; returns the content id they are stored under.
    pub fn insert(&mut self, bytes: Vec<u8>) -> ContractId {
        let id = sha256_id(&bytes);
        self.map.insert(id, bytes);
        id
    }
}

impl ContractRegistry for InMemoryRegistry {
    fn fetch(&self, id: &ContractId) -> Result<Vec<u8>, RegistryError> {
        self.map.get(id).cloned().ok_or(RegistryError::NotFound)
    }
}

/// Local-directory registry: `<dir>/<hex(id)>.wasm`, re-verified on load.
pub struct LocalDirRegistry {
    dir: PathBuf,
}

impl LocalDirRegistry {
    pub fn new(dir: impl Into<PathBuf>) -> Self {
        Self { dir: dir.into() }
    }
}

impl ContractRegistry for LocalDirRegistry {
    fn fetch(&self, id: &ContractId) -> Result<Vec<u8>, RegistryError> {
        let path = self.dir.join(format!("{}.wasm", hex::encode(id)));
        let bytes = std::fs::read(&path).map_err(|e| match e.kind() {
            std::io::ErrorKind::NotFound => RegistryError::NotFound,
            _ => RegistryError::Backend(e.to_string()),
        })?;
        if &sha256_id(&bytes) != id {
            return Err(RegistryError::HashMismatch);
        }
        Ok(bytes)
    }
}

/// Build the Warg content-store URL for a content digest.
/// Warg content is addressed as `sha256:<hex>` under the registry's `/content/`.
fn warg_content_url(base_url: &str, id: &ContractId) -> String {
    format!(
        "{}/content/sha256:{}",
        base_url.trim_end_matches('/'),
        hex::encode(id)
    )
}

/// Lean Warg backend: fetch a component by its content digest straight from the
/// registry's content endpoint, then re-hash to verify (content-addressed). The
/// on-chain hashlock already commits the exact bytes, so this gives full
/// integrity; it deliberately skips Warg's transparency-log/provenance checks to
/// keep the enclave TCB small (no extra dependencies — reuses `reqwest`).
pub struct WargRegistry {
    base_url: String,
    client: reqwest::Client,
    handle: tokio::runtime::Handle,
}

impl WargRegistry {
    /// Construct against a Warg registry base URL. Must be called from within a
    /// Tokio runtime (it captures the current `Handle` to drive async fetches
    /// from the synchronous gate).
    pub fn new(base_url: impl Into<String>) -> Self {
        Self {
            base_url: base_url.into(),
            client: reqwest::Client::new(),
            handle: tokio::runtime::Handle::current(),
        }
    }
}

impl ContractRegistry for WargRegistry {
    fn fetch(&self, id: &ContractId) -> Result<Vec<u8>, RegistryError> {
        let url = warg_content_url(&self.base_url, id);
        let client = self.client.clone();
        // The gate runs inside spawn_blocking, so block_on on the captured
        // handle is the safe sync→async bridge (same pattern as other I/O here).
        let bytes = self.handle.block_on(async move {
            let resp = client
                .get(&url)
                .send()
                .await
                .map_err(|e| RegistryError::Backend(e.to_string()))?;
            if resp.status() == reqwest::StatusCode::NOT_FOUND {
                return Err(RegistryError::NotFound);
            }
            if !resp.status().is_success() {
                return Err(RegistryError::Backend(format!("HTTP {}", resp.status())));
            }
            resp.bytes()
                .await
                .map(|b| b.to_vec())
                .map_err(|e| RegistryError::Backend(e.to_string()))
        })?;

        if sha256_id(&bytes) != *id {
            return Err(RegistryError::HashMismatch);
        }
        Ok(bytes)
    }
}

/// Combines a registry with the sandboxed engine and a compiled-component cache.
/// This is what the signing gate calls: `evaluate_by_id(contract_id, ctx)`.
pub struct ContractHost {
    engine: ContractEngine,
    registry: Box<dyn ContractRegistry>,
    cache: Mutex<HashMap<ContractId, Component>>,
}

impl ContractHost {
    pub fn new(registry: Box<dyn ContractRegistry>) -> wasmtime::Result<Self> {
        Ok(Self {
            engine: ContractEngine::new()?,
            registry,
            cache: Mutex::new(HashMap::new()),
        })
    }

    /// Fetch (if needed), compile (cached), and evaluate the contract against
    /// `ctx`. Any registry/compile failure is fail-closed (`Verdict::Deny`).
    pub fn evaluate_by_id(&self, id: &ContractId, ctx: &EvalContext) -> Verdict {
        let component = {
            let mut cache = self.cache.lock();
            if let Some(c) = cache.get(id) {
                c.clone()
            } else {
                let bytes = match self.registry.fetch(id) {
                    Ok(b) => b,
                    Err(e) => return Verdict::Deny(format!("registry: {e}")),
                };
                let component = match self.engine.compile(&bytes) {
                    Ok(c) => c,
                    Err(e) => return Verdict::Deny(format!("compile: {e}")),
                };
                cache.insert(*id, component.clone());
                component
            }
        };
        self.engine.evaluate(&component, ctx)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn warg_content_url_is_sha256_addressed() {
        let id = [0xabu8; 32];
        let expected = format!("https://reg.example.com/content/sha256:{}", "ab".repeat(32));
        // trailing slash trimmed exactly once
        assert_eq!(warg_content_url("https://reg.example.com/", &id), expected);
        assert_eq!(warg_content_url("https://reg.example.com", &id), expected);
    }
}
