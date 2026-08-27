//! The shape every Merlin service takes.

use crate::client::CosignerClient;
use crate::error::Result;
use crate::identity::ServiceIdentity;
use crate::share::ShareStore;
use std::sync::Arc;
use std::time::Duration;

/// What a service is handed on every tick.
pub struct ServiceCtx {
    pub identity: Arc<ServiceIdentity>,
    pub client: Arc<CosignerClient>,
    pub store: Arc<dyn ShareStore>,
}

/// An always-online service.
///
/// One method, called on a cadence. Services that react to rounds evaluate on every tick; whether
/// they ACT on every tick is their own business, and mostly they should not — see the rebalancer,
/// where acting each round would churn a position that only needs correcting at the edges.
#[allow(async_fn_in_trait)]
pub trait Service {
    /// Human-readable name, used in logs.
    fn name(&self) -> &str;

    /// Called once per tick. Returning an error is logged and the loop continues — a service that
    /// cannot make progress this tick should not take the process down.
    async fn on_tick(&mut self, ctx: &ServiceCtx) -> Result<()>;
}

/// Run a service forever on a fixed cadence.
pub async fn run<S: Service>(mut service: S, ctx: ServiceCtx, interval: Duration) -> ! {
    let mut ticker = tokio::time::interval(interval);
    ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        ticker.tick().await;
        if let Err(e) = service.on_tick(&ctx).await {
            tracing::warn!(service = service.name(), error = %e, "tick failed");
        }
    }
}
