//! The single persistence backend: a RESP (Redis-protocol) KV client.
//!
//! In the enclave the runtime reaches an external Redis-compatible server outbound (gvproxy); the
//! AUTH password is the framework's per-boot runtime token (the server only checks the password —
//! the username is ignored, so we connect as the `default` user: `redis://:<pass>@host`). For local
//! dev/tests the same client points at a docker Redis started with `--requirepass`.
//!
//! A logical "tree" (namespace) + key maps to the Redis key `"{tree}:{key}"`. The `KvStore` trait is
//! synchronous, so each method bridges to the async `redis` client via `block_in_place` + `block_on`
//! (the runtime is multi-threaded `tokio = ["full"]`) — the same pattern the old HTTP store used.

use std::collections::HashMap;
use std::fmt;
use std::future::Future;

use redis::aio::ConnectionManager;

/// Errors from the persistence layer.
#[derive(Debug)]
pub enum PersistenceError {
    Backend(String),
}

impl fmt::Display for PersistenceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PersistenceError::Backend(msg) => write!(f, "persistence error: {msg}"),
        }
    }
}

impl std::error::Error for PersistenceError {}

/// Abstract key-value persistence with named trees (namespaces). The RESP backend maps a
/// `(tree, key)` to the Redis key `"{tree}:{key}"`. (The single impl is `RespStore` below; the trait
/// is kept so callers depend on `Arc<dyn KvStore>` rather than the concrete type.)
pub trait KvStore: Send + Sync + 'static {
    /// Get a value by key from a named tree.
    fn get(&self, tree: &str, key: &str) -> Result<Option<String>, PersistenceError>;
    /// Put a key-value pair into a named tree.
    fn put(&self, tree: &str, key: &str, value: &str) -> Result<(), PersistenceError>;
    /// Delete a key from a named tree.
    fn delete(&self, tree: &str, key: &str) -> Result<(), PersistenceError>;
    /// Get all key-value pairs in a named tree. Use sparingly — prefer targeted gets.
    fn get_all(&self, tree: &str) -> Result<HashMap<String, String>, PersistenceError>;
    /// Delete all keys in a named tree.
    fn clear(&self, tree: &str) -> Result<(), PersistenceError>;
}

/// Number of keys per `SCAN` round in `get_all`/`clear`.
const SCAN_COUNT: usize = 500;

pub struct RespStore {
    conn: ConnectionManager,
}

impl RespStore {
    /// Connect to the Redis server at `url` (e.g. `redis://:<password>@host:6379`, `rediss://…` for
    /// TLS). Uses a `ConnectionManager` so the connection transparently reconnects.
    pub async fn connect(url: &str) -> Result<Self, PersistenceError> {
        let client = redis::Client::open(url)
            .map_err(|e| PersistenceError::Backend(format!("redis open: {e}")))?;
        let conn = ConnectionManager::new(client)
            .await
            .map_err(|e| PersistenceError::Backend(format!("redis connect: {e}")))?;
        Ok(Self { conn })
    }

    /// Run an async redis op to completion from a sync trait method.
    fn block<F: Future>(f: F) -> F::Output {
        tokio::task::block_in_place(|| tokio::runtime::Handle::current().block_on(f))
    }

    fn rediskey(tree: &str, key: &str) -> String {
        format!("{tree}:{key}")
    }

    /// `SCAN MATCH "{tree}:*"` cursor loop → the full set of matching Redis keys.
    async fn scan_keys(
        conn: &mut ConnectionManager,
        pattern: &str,
    ) -> Result<Vec<String>, PersistenceError> {
        let mut keys = Vec::new();
        let mut cursor: u64 = 0;
        loop {
            let (next, batch): (u64, Vec<String>) = redis::cmd("SCAN")
                .arg(cursor)
                .arg("MATCH")
                .arg(pattern)
                .arg("COUNT")
                .arg(SCAN_COUNT)
                .query_async(conn)
                .await
                .map_err(|e| PersistenceError::Backend(format!("redis scan: {e}")))?;
            keys.extend(batch);
            cursor = next;
            if cursor == 0 {
                break;
            }
        }
        Ok(keys)
    }
}

impl KvStore for RespStore {
    fn get(&self, tree: &str, key: &str) -> Result<Option<String>, PersistenceError> {
        let mut conn = self.conn.clone();
        let k = Self::rediskey(tree, key);
        Self::block(async move {
            redis::cmd("GET")
                .arg(&k)
                .query_async::<Option<String>>(&mut conn)
                .await
                .map_err(|e| PersistenceError::Backend(format!("redis get: {e}")))
        })
    }

    fn put(&self, tree: &str, key: &str, value: &str) -> Result<(), PersistenceError> {
        let mut conn = self.conn.clone();
        let k = Self::rediskey(tree, key);
        let value = value.to_string();
        Self::block(async move {
            redis::cmd("SET")
                .arg(&k)
                .arg(&value)
                .query_async::<()>(&mut conn)
                .await
                .map_err(|e| PersistenceError::Backend(format!("redis set: {e}")))
        })
    }

    fn delete(&self, tree: &str, key: &str) -> Result<(), PersistenceError> {
        let mut conn = self.conn.clone();
        let k = Self::rediskey(tree, key);
        Self::block(async move {
            redis::cmd("DEL")
                .arg(&k)
                .query_async::<i64>(&mut conn)
                .await
                .map(|_| ())
                .map_err(|e| PersistenceError::Backend(format!("redis del: {e}")))
        })
    }

    fn get_all(&self, tree: &str) -> Result<HashMap<String, String>, PersistenceError> {
        let mut conn = self.conn.clone();
        let pattern = format!("{tree}:*");
        let prefix = format!("{tree}:");
        Self::block(async move {
            let keys = Self::scan_keys(&mut conn, &pattern).await?;
            let mut result = HashMap::new();
            if keys.is_empty() {
                return Ok(result);
            }
            let values: Vec<Option<String>> = redis::cmd("MGET")
                .arg(&keys)
                .query_async(&mut conn)
                .await
                .map_err(|e| PersistenceError::Backend(format!("redis mget: {e}")))?;
            for (k, v) in keys.iter().zip(values) {
                if let Some(v) = v {
                    let short = k.strip_prefix(&prefix).unwrap_or(k).to_string();
                    result.insert(short, v);
                }
            }
            Ok(result)
        })
    }

    fn clear(&self, tree: &str) -> Result<(), PersistenceError> {
        let mut conn = self.conn.clone();
        let pattern = format!("{tree}:*");
        Self::block(async move {
            let keys = Self::scan_keys(&mut conn, &pattern).await?;
            if keys.is_empty() {
                return Ok(());
            }
            redis::cmd("DEL")
                .arg(&keys)
                .query_async::<i64>(&mut conn)
                .await
                .map(|_| ())
                .map_err(|e| PersistenceError::Backend(format!("redis del(clear): {e}")))
        })
    }
}
