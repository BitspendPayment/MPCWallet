//! Ark protocol: tx-building + signing math (available under `signing`, wasm-buildable)
//! plus the ASP gRPC transport (`asp_client`, only under `client`).

pub mod address;
#[cfg(feature = "client")]
pub mod asp_client;
pub mod batch;
pub mod send;
pub mod types;

/// Generated protobuf types for the arkd ArkService and IndexerService (both share
/// `package ark.v1`, so tonic-build merges them into one file). Included with a plain
/// `include!` (not `tonic::include_proto!`) so it needs no tonic at the include site:
/// under `signing` this is prost messages only; under `client` it also has the tonic
/// client (tonic is then in scope).
pub mod proto {
    include!(concat!(env!("OUT_DIR"), "/ark.v1.rs"));
}

// Re-exports for convenience.
pub use address::{
    ark_address, ark_address_script_pubkey_hex, boarding_address, parse_network,
    vtxo_script_pubkey_hex,
};
#[cfg(feature = "client")]
pub use asp_client::AspClient;
pub use types::{ArkInfo, StoredVtxo, VtxoStatus};
