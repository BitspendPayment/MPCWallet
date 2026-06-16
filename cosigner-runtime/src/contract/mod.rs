//! Off-chain WASM contract programmability. The native host instantiates a
//! user-supplied contract component in a strict NO-WASI sandbox, feeds it the
//! Bitcoin transaction for full introspection, and returns the allow/deny
//! verdict that gates the cosigner's FROST signature share.

pub mod create;
pub mod crypto_host;
mod engine;
mod registry;

pub use create::ContractCreateCoordinator;

pub use engine::{
    ContractEngine, EvalContext, Outpoint, PrevoutInfo, Transaction, Txin, Txout, Verdict,
};
pub use registry::{
    sha256_id, ContractHost, ContractId, ContractRegistry, InMemoryRegistry, KvRegistry,
    RegistryError, CONTRACT_WASM_TREE,
};
