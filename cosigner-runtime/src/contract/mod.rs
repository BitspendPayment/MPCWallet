//! Off-chain WASM contract programmability. The native host instantiates a
//! user-supplied contract component in a strict NO-WASI sandbox, feeds it the
//! Bitcoin transaction for full introspection, and returns the allow/deny
//! verdict that gates the cosigner's FROST signature share.

pub mod compose;
pub mod crypto_host;
mod engine;
mod handler;
pub mod manager;
mod registry;

pub use manager::ContractManager;

pub use engine::{
    ContractEngine, EvalContext, Outpoint, PrevoutInfo, Transaction, Txin, Txout, Verdict,
};
pub use registry::{
    get_template_wasm, list_templates, register_template, sha256_id, ContractHost, ContractId,
    ContractRegistry, DirectoryRow, InMemoryRegistry, KvRegistry, RegistryEntry, RegistryError,
    CONTRACT_WASM_TREE,
};
