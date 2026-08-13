//! `CosignerHandle` is the dispatcher's view of an actor: a typed mpsc sender.

use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Arc;

use tokio::sync::mpsc;

use super::command::CosignerCommand;

#[derive(Clone)]
pub struct CosignerHandle {
    tx: mpsc::Sender<CosignerCommand>,
}

impl CosignerHandle {
    pub(crate) fn new(tx: mpsc::Sender<CosignerCommand>) -> Self {
        Self { tx }
    }

    /// Send a command to the actor. Returns `Err` if the actor has shut down.
    pub async fn send(
        &self,
        cmd: CosignerCommand,
    ) -> Result<(), mpsc::error::SendError<CosignerCommand>> {
        self.tx.send(cmd).await
    }

    /// Try-send (non-blocking). Used by stream fan-out to avoid stalling the
    /// producer when one actor is slow.
    pub fn try_send(
        &self,
        cmd: CosignerCommand,
    ) -> Result<(), mpsc::error::TrySendError<CosignerCommand>> {
        self.tx.try_send(cmd)
    }
}

/// Owned by the registry; holds the actor's sender + last-active clock. The task stops
/// gracefully when its channel closes (all handles dropped) — not via abort.
pub(crate) struct OwnedHandle {
    pub handle: CosignerHandle,
    /// Unix seconds at the last `recv()` event on the actor. Shared so the
    /// actor task updates it inline and the eviction sweep reads it
    /// lock-free. Set to `now_secs()` at spawn time.
    pub last_active: Arc<AtomicI64>,
}

impl OwnedHandle {
    pub fn last_active_secs(&self) -> i64 {
        self.last_active.load(Ordering::Relaxed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn last_active_round_trips_through_atomic() {
        // The supplied AtomicI64 is shared with the actor task — the actor
        // updates it via `Ordering::Relaxed` on every recv(), and the
        // eviction sweep reads it the same way. This test proves the
        // accessor on OwnedHandle reflects writes made to the shared Arc.
        let last_active = Arc::new(AtomicI64::new(100));
        let (tx, _rx) = mpsc::channel::<CosignerCommand>(1);
        let handle = CosignerHandle::new(tx);
        // Construct an OwnedHandle without spawning a real actor task — we just
        // verify the atomic plumbing.
        let owned = OwnedHandle {
            handle,
            last_active: last_active.clone(),
        };

        assert_eq!(owned.last_active_secs(), 100);

        // The shared Arc lets an external writer (the actor task) move
        // last_active forward, and the read on OwnedHandle sees the new
        // value.
        last_active.store(200, Ordering::Relaxed);
        assert_eq!(owned.last_active_secs(), 200);
    }
}
