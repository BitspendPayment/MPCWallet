pub mod traits;

#[cfg(feature = "sled-backend")]
pub mod sled_store;

#[cfg(feature = "enclave-backend")]
pub mod enclave_store;

pub use traits::{KvStore, PersistenceError, SecretStore};

#[cfg(feature = "sled-backend")]
pub use sled_store::SledStore;

#[cfg(feature = "enclave-backend")]
pub use enclave_store::EnclaveStore;
