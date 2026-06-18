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
use crate::persistence::KvStore;

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
    use crate::persistence::PersistenceError;
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
