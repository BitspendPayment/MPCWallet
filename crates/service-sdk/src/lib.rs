//! Build an always-online Merlin service.
//!
//! A *service* is a third FROST participant. The wallet and the cosigner run a key-preserving
//! refresh onto a fresh polynomial, each deals the service one half of a share, and the service
//! sums them — so it can co-sign with the cosigner while the phone is offline. The group key never
//! changes, so nothing on-chain moves when a service is added or removed.
//!
//! # The invariant this crate rests on
//!
//! Because the refresh preserves the key, every service polynomial has the same constant term,
//! and at `min_signers = 2` it is a line — the polynomial IS its slope. Two services minted on one
//! slope hold two points on one line and **interpolate the group secret outright**, with neither
//! the cosigner nor the wallet involved.
//!
//! Nothing tracks that, and nothing needs to: the slope is `r_user + r_cosigner`, and the
//! cosigner's half is drawn fresh from the OS CSPRNG on every enrolment. A collision requires that
//! CSPRNG to repeat — at which point FROST nonce reuse has already broken the wallet, on exactly
//! the same assumption. What [`enrollment::verify`] does check is the share it actually assembled:
//! that it matches the pairing package the cosigner will aggregate against, and that it is not the
//! group key itself.
//!
//! # How a service is addressed
//!
//! The refresh is KEY-PRESERVING, so a pairing has no group key of its own — it shares the
//! wallet's. A service therefore talks to the WALLET's actor and identifies itself by its FROST
//! **verifying share**, signing the request with the matching secret share. That is the same
//! convention the wallet uses for its own half, and it means the cosigner's routing decision and
//! its authorization decision are one lookup. The enrolment key ([`ServiceIdentity`]) exists only
//! to receive the ECIES-sealed halves and to derive the FROST identifier; it never signs.
//!
//! # Getting a service running
//!
//! ```no_run
//! use service_sdk::{enrollment, share::FileShareStore, CosignerClient, ServiceIdentity};
//! # async fn go() -> service_sdk::Result<()> {
//! let identity = ServiceIdentity::from_secret_hex("…")?;
//! let store = FileShareStore::new("/var/lib/my-service/shares.json");
//! let client = CosignerClient::new("https://cosigner.example");
//!
//! // The wallet enrols the service and relays this bundle.
//! let bundle: enrollment::EnrollmentBundle = todo!();
//! let share = enrollment::accept(&identity, &store, &bundle)?;
//!
//! let sig = service_sdk::signing::cosign(
//!     &client, &share, /*message*/ &[], /*tx*/ &[], true,
//! ).await?;
//! # Ok(()) }
//! ```

pub mod client;
pub mod enrollment;
pub mod error;
pub mod identity;
pub mod intake;
pub mod service;
pub mod server;
pub mod share;
pub mod signing;

pub use client::CosignerClient;
pub use error::{Error, Result};
pub use identity::ServiceIdentity;
pub use intake::{EnrollmentHalf, EnrollmentInbox, HalfRole, Intake};
pub use server::{enrollment_router, EnrollmentState};
pub use service::{run, Service, ServiceCtx};
pub use share::{FileShareStore, ServiceShare, ShareStore};

/// A service pairing is always `{service, cosigner}` 2-of-2.
///
/// This is not a tunable. The polynomial-identity derivation in `threshold::service_poly` is only
/// well-defined at degree 1, and the cosigner refuses any other threshold.
pub const MIN_SIGNERS: usize = 2;
