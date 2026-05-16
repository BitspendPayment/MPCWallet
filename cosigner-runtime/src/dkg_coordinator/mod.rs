//! Native-Rust DKG coordinator. Owns short-lived `DkgSession`s keyed by
//! `user_id_hex`, evicts stale ones, and persists `policy_state` to sled on
//! step3 success. The long-lived per-user actor in `CosignerRegistry` is
//! spawned lazily on the first post-DKG request, never during DKG itself.

mod conv;
pub mod coordinator;
mod handlers;
pub mod session;

pub use coordinator::DkgCoordinator;
