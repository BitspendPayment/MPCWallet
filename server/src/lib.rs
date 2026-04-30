//! Server library — exposes module internals for integration tests and any
//! future tooling that wants to reuse the actor model without the binary
//! entrypoint. The binary at `main.rs` re-uses these modules via `crate::`.

pub mod auth;
pub mod bitcoin;
pub mod config;
pub mod crypto_ops;
pub mod persistence;
pub mod policy;
pub mod rest_api;
pub mod shared;
pub mod telemetry;
pub mod user;
pub mod vtxo_stream;
pub mod wasm_manager;

/// Generated protobuf types. Re-exported here so the lib target compiles the
/// `tonic::include_proto!` once and tests can refer to it.
pub mod wallet_proto {
    tonic::include_proto!("mpc_wallet");
}
