//! Pure-verification library for AWS Nitro Enclave attestation.
//!
//! No HTTP, no async — callers (Dart, integration tests, other Rust
//! crates) fetch attestation documents and response signatures
//! themselves and pass bytes in.
//!
//! # Example
//!
//! ```no_run
//! use enclave_client::{verify_attestation_doc, verify_schnorr_signature};
//!
//! # fn main() -> Result<(), Box<dyn std::error::Error>> {
//! let doc_bytes: &[u8] = &[/* base64-decoded attestation doc */];
//! let pcr0 = "79f5fb125b00ad80...";
//! let nonce = [0u8; 20];
//!
//! let result = verify_attestation_doc(doc_bytes, pcr0, &nonce)?;
//! let app_key_hash_hex =
//!     enclave_client::extract_app_key_hash(&result.document)?;
//! // …caller fetches /v1/enclave-info to get the attestation pubkey,
//! //   compares SHA256(pubkey) to app_key_hash, then per response:
//! let body: &[u8] = b"{\"status\":\"ready\"}";
//! verify_schnorr_signature(body, "sig_hex…", "pubkey_hex…")?;
//! # Ok(())
//! # }
//! ```

mod error;
mod nitro;
mod verify;

pub use error::{Error, Result};
pub use nitro::{AttestationDocument, NitroVerifyResult};
pub use verify::{extract_app_key_hash, verify_attestation_doc, verify_schnorr_signature};
