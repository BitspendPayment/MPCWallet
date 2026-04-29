//! Merged C-ABI FFI surface for the MPC wallet.
//!
//! Each sub-module owns its own `#[no_mangle] extern "C"` symbols and its own
//! result/response struct. The C-ABI is symbol-name based, so the disjoint
//! `ark_*`, `threshold_*`, `enclave_*` prefixes guarantee no link-time
//! collision between modules.

mod ark;
mod enclave;
mod threshold;
