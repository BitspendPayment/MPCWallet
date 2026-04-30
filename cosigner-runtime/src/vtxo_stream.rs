//! Global ASP transaction-stream task. One connection to arkd's
//! `GetTransactionsStream` for the whole server; events get fanned out to the
//! per-user actor via `registry.user_for_script()` lookup +
//! `CosignerCommand::VtxoStreamUpdate`.

use std::collections::HashMap;
use std::sync::Arc;

use crate::shared::SharedServices;
use crate::cosigner::command::CosignerCommand;
use crate::cosigner::registry::CosignerRegistry;

pub async fn run_vtxo_stream(registry: Arc<CosignerRegistry>, shared: Arc<SharedServices>) {
    if shared.asp_client.is_none() {
        tracing::info!("VTXO stream: ASP not configured, task exiting");
        return;
    }
    tracing::info!("VTXO stream task started");
    loop {
        tracing::info!("VTXO stream: attempting connection...");
        match connect_and_stream(&registry, &shared).await {
            Ok(()) => tracing::info!("VTXO stream ended, reconnecting..."),
            Err(e) => tracing::warn!("VTXO stream error: {e}, reconnecting in 5s..."),
        }
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
    }
}

async fn connect_and_stream(
    registry: &Arc<CosignerRegistry>,
    shared: &Arc<SharedServices>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let asp_url = std::env::var("ASP_URL").map_err(|_| "ASP_URL env var not set")?;
    tracing::info!("VTXO stream: connecting to ASP at {asp_url}");
    let mut stream_client = ark::client::AspClient::connect(&asp_url).await?;
    tracing::info!("VTXO stream: ASP connected, opening transaction stream...");
    let mut stream = stream_client.get_transactions_stream().await?;
    tracing::info!("VTXO stream: connected to arkd, listening for events");

    while let Some(event) = stream.message().await? {
        if let Some(data) = event.data {
            use ark::client::proto::get_transactions_stream_response::Data;
            match data {
                Data::CommitmentTx(notif) | Data::ArkTx(notif) => {
                    process_notification(registry, shared, &notif).await;
                }
                Data::Heartbeat(_) => {}
            }
        }
    }
    Ok(())
}

async fn process_notification(
    registry: &Arc<CosignerRegistry>,
    shared: &Arc<SharedServices>,
    notif: &ark::client::proto::TxNotification,
) {
    // Resolve ASP info; bail if not yet cached (the indexer-subscription path
    // also handles VTXO discovery, so dropping a notification here is recoverable).
    let info = {
        let asp = match shared.asp_client.as_ref() {
            Some(a) => a,
            None => return,
        };
        let guard = asp.lock().await;
        match guard.info.as_ref() {
            Some(i) => i.clone(),
            None => {
                tracing::warn!("ASP info not cached, skipping VTXO stream notification");
                return;
            }
        }
    };

    // Group events by owning user.
    let mut per_user: HashMap<
        String,
        (Vec<ark::client::proto::Vtxo>, Vec<ark::client::proto::Vtxo>),
    > = HashMap::new();

    for v in &notif.spent_vtxos {
        if let Some(uid) = registry.user_for_script(&v.script) {
            per_user.entry(uid).or_default().0.push(v.clone());
        }
    }
    for v in &notif.spendable_vtxos {
        if let Some(uid) = registry.user_for_script(&v.script) {
            per_user.entry(uid).or_default().1.push(v.clone());
        }
    }

    // Fan out one command per affected user.
    for (user_id_hex, (spent, spendable)) in per_user {
        let handle = match registry.get_or_spawn(&user_id_hex) {
            Ok(h) => h,
            Err(e) => {
                tracing::warn!("[{user_id_hex}] VTXO stream: spawn failed: {e}");
                continue;
            }
        };
        let cmd = CosignerCommand::VtxoStreamUpdate {
            user_id_hex: user_id_hex.clone(),
            spent,
            spendable,
            info: info.clone(),
        };
        if let Err(e) = handle.send(cmd).await {
            tracing::warn!("[{user_id_hex}] VTXO stream: actor mailbox send failed: {e}");
        }
    }
}
