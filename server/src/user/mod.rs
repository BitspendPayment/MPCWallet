//! Per-user actor model. Each user gets a tokio task that owns its `UserInstance`
//! and `UserState`, processing commands one at a time. WASM calls run via
//! `spawn_blocking` so the actor's task stays light.

pub mod actor;
pub mod command;
pub mod handle;
pub mod handlers;
pub mod registry;
pub mod state;
pub mod types;

pub use command::UserCommand;
pub use handle::UserHandle;
pub use registry::UserRegistry;
pub use state::UserState;
pub use types::ArkTxEntry;
