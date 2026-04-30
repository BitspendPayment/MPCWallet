use std::collections::HashMap;
use std::path::Path;

use super::traits::{KvStore, PersistenceError, SecretStore};

/// Sled-based key-value persistence store for local development and testing.
pub struct SledStore {
    db: sled::Db,
}

impl SledStore {
    /// Open or create the store at the given path.
    pub fn open(path: &Path) -> Result<Self, sled::Error> {
        let db = sled::open(path)?;
        Ok(Self { db })
    }
}

impl KvStore for SledStore {
    fn get(&self, tree: &str, key: &str) -> Result<Option<String>, PersistenceError> {
        let tree = self.db.open_tree(tree).map_err(|e| PersistenceError::Backend(e.to_string()))?;
        tree.get(key.as_bytes())
            .map(|opt| opt.map(|v| String::from_utf8_lossy(&v).to_string()))
            .map_err(|e| PersistenceError::Backend(e.to_string()))
    }

    fn put(&self, tree: &str, key: &str, value: &str) -> Result<(), PersistenceError> {
        let tree = self.db.open_tree(tree).map_err(|e| PersistenceError::Backend(e.to_string()))?;
        tree.insert(key.as_bytes(), value.as_bytes())
            .map_err(|e| PersistenceError::Backend(e.to_string()))?;
        Ok(())
    }

    fn delete(&self, tree: &str, key: &str) -> Result<(), PersistenceError> {
        let tree = self.db.open_tree(tree).map_err(|e| PersistenceError::Backend(e.to_string()))?;
        tree.remove(key.as_bytes())
            .map_err(|e| PersistenceError::Backend(e.to_string()))?;
        Ok(())
    }

    fn get_all(&self, tree: &str) -> Result<HashMap<String, String>, PersistenceError> {
        let tree = self.db.open_tree(tree).map_err(|e| PersistenceError::Backend(e.to_string()))?;
        let mut result = HashMap::new();
        for item in tree.iter() {
            let (k, v) = item.map_err(|e| PersistenceError::Backend(e.to_string()))?;
            let key = String::from_utf8_lossy(&k).to_string();
            let value = String::from_utf8_lossy(&v).to_string();
            result.insert(key, value);
        }
        Ok(result)
    }

    fn clear(&self, tree: &str) -> Result<(), PersistenceError> {
        let tree = self.db.open_tree(tree).map_err(|e| PersistenceError::Backend(e.to_string()))?;
        tree.clear().map_err(|e| PersistenceError::Backend(e.to_string()))?;
        Ok(())
    }
}

impl SecretStore for SledStore {
    fn get_secret(&self, name: &str) -> Result<Option<String>, PersistenceError> {
        self.get("_secrets", name)
    }

    fn put_secret(&self, name: &str, value: &str) -> Result<(), PersistenceError> {
        self.put("_secrets", name, value)
    }

    fn delete_secret(&self, name: &str) -> Result<(), PersistenceError> {
        self.delete("_secrets", name)
    }
}
