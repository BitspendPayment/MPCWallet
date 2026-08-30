//! The enrolled share, and the store that keeps the invariant true on the service's side.

use crate::error::{Error, Result};
use k256::Scalar;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::point;

/// One assembled service share.
///
/// Identity here is the FROST **verifying share** — the same convention the wallet uses for its
/// own half of the 2-of-2. It is what the service presents as `user_id`, what the cosigner files
/// its counter-share under, and what the service proves by signing with the matching secret.
#[derive(Clone, Serialize, Deserialize)]
pub struct ServiceShare {
    /// The actor to address for ceremonies. This is the WALLET's group key: the refresh is
    /// key-preserving, so the pairing shares the wallet's `V` and has no group key of its own.
    pub pairing_group_key: String,
    /// The service's verifying share hex — its `user_id` on the wire, and the key its pairing is
    /// filed under in the wallet's actor. Identity here is a FROST verifying share, exactly as it
    /// is for the wallet itself; the service proves it by signing with the matching secret share.
    pub verifying_share_hex: String,
    /// The service's FROST identifier, hex.
    pub identifier_hex: String,
    /// The service's summed secret share, hex. Never logged.
    pub secret_share_hex: String,
    /// The pairing's public key package, JSON.
    pub pairing_pkp_json: String,
}

// Redacting Debug: the secret share must never reach logs or panic output.
impl core::fmt::Debug for ServiceShare {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(
            f,
            "ServiceShare {{ verifying_share: {}, secret_share: <redacted> }}",
            self.verifying_share_hex
        )
    }
}

impl ServiceShare {
    pub fn identifier(&self) -> Result<Identifier> {
        let raw: [u8; 32] = hex::decode(&self.identifier_hex)
            .map_err(|e| Error::Store(format!("bad identifier hex: {e}")))?
            .try_into()
            .map_err(|_| Error::Store("identifier must be 32 bytes".into()))?;
        Ok(Identifier::deserialize(&raw)?)
    }

    pub fn secret(&self) -> Result<Scalar> {
        let raw: [u8; 32] = hex::decode(&self.secret_share_hex)
            .map_err(|e| Error::Store(format!("bad share hex: {e}")))?
            .try_into()
            .map_err(|_| Error::Store("secret share must be 32 bytes".into()))?;
        Ok(threshold::scalar::scalar_from_bytes(&raw)?)
    }

    pub fn pairing_pkp(&self) -> Result<PublicKeyPackage> {
        Ok(PublicKeyPackage::from_json(&self.pairing_pkp_json)?)
    }

    /// The auth signer for cosigner requests: the secret share itself.
    ///
    /// Same convention the wallet uses — `user_id` is the verifying share and the request is
    /// Schnorr-signed by the corresponding secret. A service therefore needs no separate signing
    /// identity; its enrolment key exists only to receive the sealed halves.
    pub fn auth_signer(&self) -> Result<threshold::auth::AuthSigner> {
        let secret = self.secret()?;
        Ok(threshold::auth::AuthSigner::from_secret_bytes(
            &threshold::scalar::scalar_to_bytes(&secret),
        )?)
    }

    /// Rebuild the FROST key package this share signs with.
    pub fn key_package(&self) -> Result<KeyPackage> {
        let pkp = self.pairing_pkp()?;
        let secret = self.secret()?;
        Ok(KeyPackage {
            identifier: self.identifier()?,
            secret_share: secret,
            verifying_share: point::base_mul(&secret),
            verifying_key: pkp.verifying_key,
            min_signers: crate::MIN_SIGNERS,
        })
    }
}

/// Where a service keeps its shares.
///
/// Keyed by verifying share, because that is the identity the whole protocol routes on. Two
/// different secrets can never share one verifying share, so a conflict here means local
/// corruption or a mixed-up store — worth refusing rather than overwriting.
pub trait ShareStore: Send + Sync {
    /// Persist a share. MUST fail if a different secret already exists under the same
    /// verifying share.
    fn put(&self, share: &ServiceShare) -> Result<()>;
    fn get(&self, verifying_share_hex: &str) -> Result<Option<ServiceShare>>;
    fn list(&self) -> Result<Vec<ServiceShare>>;
}

/// A JSON-file store. Adequate for a single-process service; swap it for something sealed before
/// a share is worth stealing.
pub struct FileShareStore {
    path: PathBuf,
    lock: std::sync::Mutex<()>,
}

impl FileShareStore {
    pub fn new(path: impl AsRef<Path>) -> Self {
        Self {
            path: path.as_ref().to_path_buf(),
            lock: std::sync::Mutex::new(()),
        }
    }

    fn read_all(&self) -> Result<BTreeMap<String, ServiceShare>> {
        match std::fs::read(&self.path) {
            Ok(bytes) => serde_json::from_slice(&bytes)
                .map_err(|e| Error::Store(format!("corrupt share store: {e}"))),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(BTreeMap::new()),
            Err(e) => Err(Error::Store(format!("read share store: {e}"))),
        }
    }

    fn write_all(&self, map: &BTreeMap<String, ServiceShare>) -> Result<()> {
        if let Some(dir) = self.path.parent() {
            std::fs::create_dir_all(dir)
                .map_err(|e| Error::Store(format!("create share dir: {e}")))?;
        }
        let bytes = serde_json::to_vec_pretty(map)
            .map_err(|e| Error::Store(format!("serialize share store: {e}")))?;
        // Write-then-rename: a crash mid-write must not leave a store that reads as empty, which
        // would look exactly like "never enrolled" and invite a second enrolment.
        let tmp = self.path.with_extension("tmp");
        std::fs::write(&tmp, &bytes).map_err(|e| Error::Store(format!("write shares: {e}")))?;
        std::fs::rename(&tmp, &self.path)
            .map_err(|e| Error::Store(format!("commit shares: {e}")))?;
        Ok(())
    }
}

impl ShareStore for FileShareStore {
    fn put(&self, share: &ServiceShare) -> Result<()> {
        let _guard = self.lock.lock().map_err(|_| Error::Store("poisoned".into()))?;
        let mut map = self.read_all()?;
        if let Some(existing) = map.get(&share.verifying_share_hex) {
            if existing.secret_share_hex == share.secret_share_hex {
                return Ok(()); // idempotent re-enrolment of the same share
            }
            return Err(Error::Store(format!(
                "already holding a DIFFERENT secret under verifying share {} — one public point \
                 cannot have two secrets, so this store is corrupt or mixed up",
                share.verifying_share_hex
            )));
        }
        map.insert(share.verifying_share_hex.clone(), share.clone());
        self.write_all(&map)
    }

    fn get(&self, verifying_share_hex: &str) -> Result<Option<ServiceShare>> {
        Ok(self.read_all()?.get(verifying_share_hex).cloned())
    }

    fn list(&self) -> Result<Vec<ServiceShare>> {
        Ok(self.read_all()?.into_values().collect())
    }
}
