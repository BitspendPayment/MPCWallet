//! Per-cosigner actor model. Each user has one native `CosignerActor` (keys + FROST ceremony +
//! Ark sessions); a tokio task owns it + its mutable host state, processing commands serially.

pub mod actor;
pub mod command;
pub mod handle;
pub mod handlers;
pub mod registry;
pub mod state;
pub mod types;
pub mod wire;

pub use actor::CosignerActor;
pub use command::CosignerCommand;
pub use handle::CosignerHandle;
pub use registry::CosignerRegistry;
pub use state::CosignerState;
pub use types::ArkTxEntry;
