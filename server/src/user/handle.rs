//! `UserHandle` is the dispatcher's view of an actor: a typed mpsc sender plus
//! a JoinHandle for graceful shutdown.

use tokio::sync::mpsc;
use tokio::task::JoinHandle;

use super::command::UserCommand;

#[derive(Clone)]
pub struct UserHandle {
    tx: mpsc::Sender<UserCommand>,
}

impl UserHandle {
    pub(crate) fn new(tx: mpsc::Sender<UserCommand>) -> Self {
        Self { tx }
    }

    /// Send a command to the actor. Returns `Err` if the actor has shut down.
    pub async fn send(&self, cmd: UserCommand) -> Result<(), mpsc::error::SendError<UserCommand>> {
        self.tx.send(cmd).await
    }

    /// Try-send (non-blocking). Used by stream fan-out to avoid stalling the
    /// producer when one actor is slow.
    pub fn try_send(
        &self,
        cmd: UserCommand,
    ) -> Result<(), mpsc::error::TrySendError<UserCommand>> {
        self.tx.try_send(cmd)
    }
}

/// Owned by the registry; tracked alongside the sender so we can join the task
/// during shutdown or eviction.
pub(crate) struct OwnedHandle {
    pub handle: UserHandle,
    pub join: JoinHandle<()>,
}
