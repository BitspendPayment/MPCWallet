//! Content-addressed contract resolution + a compiled-component cache.
//!
//! A `ContractRegistry` maps an on-chain `contract_id` (= sha256 of the
//! component bytes) to the verified component bytes. Backends are swappable —
//! an in-memory map and a local directory now; a Warg (WebAssembly registry)
//! backend later, all content-addressed by the same sha256. `ContractHost`
//! combines a registry with the sandboxed `ContractEngine` and memoises the
//! compiled `Component` per id (compilation is expensive).

use std::collections::HashMap;
use std::sync::Arc;

use parking_lot::Mutex;
use wasmtime::component::Component;

use super::crypto_host;
use super::{ContractEngine, EvalContext, Verdict};
use crate::resp_store::KvStore;

/// Persistence tree holding contract bytes: hex(contract_id) -> hex(wasm).
/// Populated at eVTXO creation; the gate resolves contracts from it.
pub const CONTRACT_WASM_TREE: &str = "contract_wasm";

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

pub fn sha256_id(bytes: &[u8]) -> ContractId {
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

/// Resolves contract bytes from the cosigner's own KV (the `contract_wasm` tree),
/// stored at eVTXO creation. Re-verified (sha256) on load.
pub struct KvRegistry {
    store: Arc<dyn KvStore>,
}

impl KvRegistry {
    pub fn new(store: Arc<dyn KvStore>) -> Self {
        Self { store }
    }
}

impl ContractRegistry for KvRegistry {
    fn fetch(&self, id: &ContractId) -> Result<Vec<u8>, RegistryError> {
        let hex_id = hex::encode(id);
        let hex_bytes = self
            .store
            .get(CONTRACT_WASM_TREE, &hex_id)
            .map_err(|e| RegistryError::Backend(e.to_string()))?
            .ok_or(RegistryError::NotFound)?;
        let bytes = hex::decode(&hex_bytes)
            .map_err(|e| RegistryError::Backend(format!("decode stored wasm: {e}")))?;
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

    /// Statically validate contract bytes (compile + no-WASI import check) without
    /// running them. Used at eVTXO creation to reject a malformed or
    /// capability-grabbing contract before it is stored + funded.
    pub fn validate(&self, wasm: &[u8]) -> Result<(), String> {
        self.engine.validate(wasm)
    }

    /// Validate a contract TEMPLATE (Phase 2): a valid component with no `wasi:*` import. A template
    /// also imports its per-instance config interface, satisfied by composition (the composed result
    /// still passes the strict `validate`).
    pub fn validate_template(&self, wasm: &[u8]) -> Result<(), String> {
        self.engine.validate_template(wasm)
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
    use crate::resp_store::PersistenceError;
    use std::sync::Mutex as StdMutex;

    #[derive(Default)]
    struct MemStore(StdMutex<HashMap<String, String>>);
    impl KvStore for MemStore {
        fn get(&self, tree: &str, key: &str) -> Result<Option<String>, PersistenceError> {
            Ok(self
                .0
                .lock()
                .unwrap()
                .get(&format!("{tree}/{key}"))
                .cloned())
        }
        fn put(&self, tree: &str, key: &str, value: &str) -> Result<(), PersistenceError> {
            self.0
                .lock()
                .unwrap()
                .insert(format!("{tree}/{key}"), value.to_string());
            Ok(())
        }
        fn delete(&self, tree: &str, key: &str) -> Result<(), PersistenceError> {
            self.0.lock().unwrap().remove(&format!("{tree}/{key}"));
            Ok(())
        }
        fn get_all(&self, _tree: &str) -> Result<HashMap<String, String>, PersistenceError> {
            Ok(HashMap::new())
        }
        fn clear(&self, _tree: &str) -> Result<(), PersistenceError> {
            Ok(())
        }
    }

    #[test]
    fn kv_registry_round_trips_and_verifies() {
        let store = Arc::new(MemStore::default());
        let bytes = b"\x00asm\x01\x00\x00\x00 some contract bytes".to_vec();
        let id = sha256_id(&bytes);
        store
            .put(CONTRACT_WASM_TREE, &hex::encode(id), &hex::encode(&bytes))
            .unwrap();

        let reg = KvRegistry::new(store.clone());
        assert_eq!(reg.fetch(&id).unwrap(), bytes);

        // Unknown id → NotFound.
        assert!(matches!(
            reg.fetch(&[0u8; 32]),
            Err(RegistryError::NotFound)
        ));

        // Corrupted stored bytes (hash no longer matches the key) → HashMismatch.
        store
            .put(
                CONTRACT_WASM_TREE,
                &hex::encode(id),
                &hex::encode(b"tampered"),
            )
            .unwrap();
        assert!(matches!(reg.fetch(&id), Err(RegistryError::HashMismatch)));
    }
}

// ---------------------------------------------------------------------------
// Contract template directory (PEER model).
//
// Beyond content-addressed wasm storage (above), the registry also indexes published
// TEMPLATES by their author's verifying key (the CosignerID), so users can browse the
// directory — `CosignerID -> [Contract Template, VerifyingShare]` — and create a contract
// WITH a chosen author as the receiver. Public read; the publish path stores + addresses
// the wasm in the same `CONTRACT_WASM_TREE`.
// ---------------------------------------------------------------------------

/// `author_vk_hex` (CosignerID) -> JSON list of that author's published templates.
pub const REGISTRY_TREE: &str = "contract_registry";

/// One published template (metadata; the template + provider-stub wasm live in `CONTRACT_WASM_TREE`).
#[derive(serde::Serialize, serde::Deserialize, Clone, Default)]
pub struct RegistryEntry {
    pub contract_id_hex: String,
    pub name: String,
    pub description: String,
    /// Phase 2: content id of the template's provider STUB (exports its typed config interface,
    /// reading values from a patchable slot). Empty for a Phase-1 single-wasm contract.
    #[serde(default)]
    pub stub_id_hex: String,
    /// Phase 2: the typed config SCHEMA (JSON: `[{name,type}]`) the app renders as a form. Empty
    /// when the template takes no per-instance config.
    #[serde(default)]
    pub schema_json: String,
}

/// A directory row: the author (CosignerID = VerifyingShare) and one of its templates.
#[derive(serde::Serialize, Clone)]
pub struct DirectoryRow {
    pub author_vk_hex: String,
    pub contract_id_hex: String,
    pub name: String,
    pub description: String,
    pub stub_id_hex: String,
    pub schema_json: String,
}

fn load_registry(persistence: &dyn KvStore, author_vk_hex: &str) -> Vec<RegistryEntry> {
    match persistence.get(REGISTRY_TREE, author_vk_hex) {
        Ok(Some(json)) => serde_json::from_str(&json).unwrap_or_default(),
        _ => Vec::new(),
    }
}

/// Publish (or replace) a contract template under `author_vk_hex`. Validates `sha256(wasm) ==
/// contract_id` + the template sandbox (no wasi), stores the template + its provider STUB
/// content-addressed, and indexes the template (with the config schema) by the author's verifying
/// key. `stub_wasm`/`schema_json` are empty for a Phase-1 contract that takes no per-instance config.
pub fn register_template(
    persistence: &dyn KvStore,
    host: Option<&ContractHost>,
    author_vk_hex: &str,
    contract_id: &[u8],
    wasm: &[u8],
    stub_wasm: &[u8],
    schema_json: &str,
    name: &str,
    description: &str,
) -> Result<(), tonic::Status> {
    if contract_id.len() != 32 {
        return Err(tonic::Status::invalid_argument(
            "contract_id must be 32 bytes",
        ));
    }
    if wasm.is_empty() {
        return Err(tonic::Status::invalid_argument("contract_wasm is required"));
    }
    if sha256_id(wasm).as_slice() != contract_id {
        return Err(tonic::Status::invalid_argument(
            "contract_wasm does not match contract_id (sha256 mismatch)",
        ));
    }
    if let Some(host) = host {
        host.validate_template(wasm)
            .map_err(|e| tonic::Status::invalid_argument(format!("invalid template: {e}")))?;
        if !stub_wasm.is_empty() {
            host.validate_template(stub_wasm).map_err(|e| {
                tonic::Status::invalid_argument(format!("invalid provider stub: {e}"))
            })?;
        }
    }
    let contract_id_hex = hex::encode(contract_id);
    persistence
        .put(CONTRACT_WASM_TREE, &contract_id_hex, &hex::encode(wasm))
        .map_err(|e| tonic::Status::internal(format!("store template wasm: {e}")))?;

    let stub_id_hex = if stub_wasm.is_empty() {
        String::new()
    } else {
        let id = hex::encode(sha256_id(stub_wasm));
        persistence
            .put(CONTRACT_WASM_TREE, &id, &hex::encode(stub_wasm))
            .map_err(|e| tonic::Status::internal(format!("store stub wasm: {e}")))?;
        id
    };

    let mut entries = load_registry(persistence, author_vk_hex);
    entries.retain(|e| e.contract_id_hex != contract_id_hex);
    entries.push(RegistryEntry {
        contract_id_hex,
        name: name.to_string(),
        description: description.to_string(),
        stub_id_hex,
        schema_json: schema_json.to_string(),
    });
    let json = serde_json::to_string(&entries)
        .map_err(|e| tonic::Status::internal(format!("encode registry: {e}")))?;
    persistence
        .put(REGISTRY_TREE, author_vk_hex, &json)
        .map_err(|e| tonic::Status::internal(format!("persist registry: {e}")))?;
    Ok(())
}

/// Browse the whole directory: every author's published templates, flattened to rows.
pub fn list_templates(persistence: &dyn KvStore) -> Vec<DirectoryRow> {
    let all = persistence.get_all(REGISTRY_TREE).unwrap_or_default();
    let mut rows = Vec::new();
    for (author_vk_hex, json) in all {
        let entries: Vec<RegistryEntry> = serde_json::from_str(&json).unwrap_or_default();
        for e in entries {
            rows.push(DirectoryRow {
                author_vk_hex: author_vk_hex.clone(),
                contract_id_hex: e.contract_id_hex,
                name: e.name,
                description: e.description,
                stub_id_hex: e.stub_id_hex,
                schema_json: e.schema_json,
            });
        }
    }
    rows
}

/// Fetch a template's wasm bytes by its content id (sha256 hex).
pub fn get_template_wasm(persistence: &dyn KvStore, contract_id_hex: &str) -> Option<Vec<u8>> {
    match persistence.get(CONTRACT_WASM_TREE, contract_id_hex) {
        Ok(Some(hex_str)) => hex::decode(hex_str).ok(),
        _ => None,
    }
}
