//! Library target. Exposes module internals so integration tests and future
//! tooling can reuse them without going through the `main.rs` binary.

pub mod auth;
pub mod bitcoin;
pub mod config;
pub mod cosigner;
pub mod crypto_ops;
pub mod dkg_coordinator;
pub mod fcm_client;
pub mod persistence;
pub mod policy;
pub mod rest_api;
pub mod shared;
pub mod telemetry;
pub mod vtxo_stream;

pub mod wallet_proto {
    tonic::include_proto!("mpc_wallet");
}
