//! Verified HTTP client for AWS Nitro Enclaves.
//!
//! Every request first verifies the enclave's attestation document (PCR0,
//! optional secret PCRs, attestation key binding) and then verifies the
//! Schnorr response signature. This ensures the enclave is running the
//! expected code and that responses haven't been tampered with.
//!
//! # Usage
//!
//! ```no_run
//! use enclave_client::{Client, Options};
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     // Option A: Manual configuration.
//!     let client = Client::new("https://1.2.3.4", Options {
//!         expected_pcr0: "79f5fb125b00ad80...".into(),
//!         ..Default::default()
//!     })?;
//!
//!     let resp = client.get("/my-endpoint").await?;
//!     println!("status: {}, verified: {}", resp.status_code, resp.signature_verified);
//!
//!     // Option B: From deployment manifest (GitHub Releases).
//!     let client = Client::from_manifest(
//!         &enclave_client::manifest_url("myorg/my-app", "latest"),
//!         Options::default(),
//!     ).await?;
//!
//!     Ok(())
//! }
//! ```

mod client;
mod error;
mod manifest;
mod nitro;
mod types;
mod verify;

pub use client::Client;
pub use error::{Error, Result};
pub use manifest::{fetch_manifest, manifest_url, verify_manifest_provenance};
pub use types::{AttestationResult, AttestationStatus, Manifest, Options, Response};
