//! Auto-settle tick handler. Driven from a global 60-second task in main.rs
//! that fans out `CosignerCommand::TickAutoSettle` to every spawned actor.
//!
//! The actor wakes here, checks its stored `DelegateRecord`, and submits the
//! signed intent into the next ASP batch when the earliest covered VTXO's
//! `expires_at` falls within `auto_settle_safety_margin_secs` of now.

use tokio::runtime::Handle;
use tonic::Status;

use crate::cosigner::state::{CosignerState, VtxoEntry};
use crate::cosigner::types::ArkTxEntry;
use crate::cosigner::wasm::CosignerInstance;
use crate::shared::SharedServices;

use super::helpers::{now_secs, save_user_ark_history, save_user_vtxos};

/// Per-actor tick. No-ops when there is nothing to do.
#[tracing::instrument(skip_all, name = "actor::tick_auto_settle", err)]
pub fn tick_auto_settle(
    _user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
) -> Result<(), Status> {
    let Some(record) = state.delegate_session.as_ref() else {
        return Ok(());
    };
    if record.earliest_expires_at == 0 {
        // Conservative: a covered VTXO has unknown expiry. The next stream
        // update with a known timestamp will replace this record; until then
        // we don't auto-settle.
        return Ok(());
    }
    let now = now_secs();
    let threshold = record
        .earliest_expires_at
        .saturating_sub(shared.auto_settle_safety_margin_secs);
    if now < threshold {
        return Ok(());
    }

    let Some(asp) = shared.asp_client.clone() else {
        tracing::warn!("tick_auto_settle: ASP not configured; cannot drive stored intent");
        return Ok(());
    };

    let record = state.delegate_session.take().expect("checked above");
    tracing::info!(
        "auto-settle: driving stored intent for {} VTXO(s), earliest_expires_at={} now={}",
        record.covered_outpoints.len(),
        record.earliest_expires_at,
        now
    );

    let mut session = record.session;
    let outcome = Handle::current().block_on(async move {
        let mut guard = asp.lock().await;
        let (commitment_txid, vtxo_outpoint) = session
            .settle(&mut *guard)
            .await
            .map_err(|e| Status::internal(format!("auto-settle: {e}")))?;
        let info = match &guard.info {
            Some(i) => i.clone(),
            None => guard
                .get_info()
                .await
                .map_err(|e| Status::internal(format!("get_info: {e}")))?,
        };
        Ok::<_, Status>((commitment_txid, vtxo_outpoint, info))
    });

    let (commitment_txid, vtxo_outpoint, info) = match outcome {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(
                "auto-settle drive failed: {e}; clearing stored intent so client can re-delegate"
            );
            return Ok(());
        }
    };

    let (vtxo_txid, vtxo_vout) =
        vtxo_outpoint.unwrap_or_else(|| (commitment_txid.clone(), 0));
    let total_amount: u64 = state.vtxos.iter().map(|e| e.amount).sum();
    state.vtxos.clear();
    let new_exit_delay = info.unilateral_exit_delay as u32;
    state.vtxos.push(VtxoEntry {
        txid: vtxo_txid.clone(),
        vout: vtxo_vout,
        amount: total_amount,
        exit_delay: new_exit_delay,
        created_at: now_secs(),
        expires_at: 0,
    });
    state.ark_tx_history.push(ArkTxEntry {
        tx_type: "settle".into(),
        amount_sats: total_amount as i64,
        txid: vtxo_txid.clone(),
        timestamp: now_secs(),
    });
    let user_id_hex = state.user_id_hex.clone();
    save_user_vtxos(shared.persistence.as_ref(), &user_id_hex, &state.vtxos);
    save_user_ark_history(
        shared.persistence.as_ref(),
        &user_id_hex,
        &state.ark_tx_history,
    );
    tracing::info!(
        "[{user_id_hex}] auto-settle: settled, new VTXO {vtxo_txid}:{vtxo_vout} amount={total_amount} commitment={commitment_txid}"
    );
    Ok(())
}
