//! Per-cosigner actor model. Each user has one cosigner instance; a tokio task
//! owns that instance + its mutable state, processing commands serially. WASM
//! calls run via `spawn_blocking` so the task stays light.

pub mod command;
pub mod cosigner;
pub mod handle;
pub mod handlers;
pub mod registry;
pub mod state;
pub mod types;

pub use command::CosignerCommand;
pub use cosigner::{CosignerInstance, CosignerWasiView};
pub use handle::CosignerHandle;
pub use registry::CosignerRegistry;
pub use state::CosignerState;
pub use types::ArkTxEntry;
