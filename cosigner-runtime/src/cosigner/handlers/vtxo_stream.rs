//! Per-user VTXO stream handlers, invoked by the actor when the global
//! VTXO stream task (in `crate::vtxo_stream`) routes events to a specific user.

use tonic::Status;

use crate::shared::SharedServices;
use crate::cosigner::state::{CosignerState, VtxoEntry};
use crate::cosigner::types::ArkTxEntry;
use crate::cosigner::wasm::CosignerInstance;

use super::helpers::{
    get_user_xonly_pubkey, now_secs, save_user_ark_history, save_user_vtxos,
};

/// Resolve a VTXO's exit_delay by trying both candidates against its
/// scriptPubKey. Falls back to `boarding_exit_delay`.
fn resolve_exit_delay(
    owner_pk_hex: &str,
    asp_signer_pubkey: &str,
    vtxo_script: &str,
    info: &ark::client::types::ArkInfo,
    network: bitcoin::Network,
) -> u32 {
    for delay in [
        info.boarding_exit_delay as u32,
        info.unilateral_exit_delay as u32,
    ] {
        if let Ok(computed) =
            ark::client::vtxo_script_pubkey_hex(owner_pk_hex, asp_signer_pubkey, delay, network)
        {
            if computed == vtxo_script {
                return delay;
            }
        }
    }
    info.boarding_exit_delay as u32
}

/// Apply a `VtxoStreamUpdate` (or `IndexerUpdate`) to per-user state. Removes
/// spent entries, adds new spendable VTXOs with the correct exit_delay,
/// persists, and appends a "receive" history entry for any genuinely new VTXO.
///
/// Returns a list of newly-added outpoints — the caller (the global stream
/// task) uses this to fire FCM pushes so the recipient device wakes and
/// re-delegates.
///
/// Self-originated change VTXOs (from the user's own send/settle/board) are
/// not double-counted: the `send_vtxo` and `settle` handlers push the
/// resulting VTXO into `state.vtxos` synchronously before returning. Because
/// the actor processes commands serially, any stream notification queued
/// during that handler runs *after* the handler completes — so the
/// `(txid, vout)` already-present check below short-circuits past the entire
/// block, including the history append. No separate "active session" gate
/// is needed.
pub fn apply_stream_update(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    user_id_hex: &str,
    spent: Vec<ark::client::proto::Vtxo>,
    spendable: Vec<ark::client::proto::Vtxo>,
    info: ark::client::types::ArkInfo,
) -> Result<Vec<(String, u32)>, Status> {
    let mut delegate_invalidated = false;

    for v in &spent {
        if let Some(outpoint) = &v.outpoint {
            state
                .vtxos
                .retain(|e| !(e.txid == outpoint.txid && e.vout == outpoint.vout));
            if let Some(record) = &state.delegate_session {
                if record
                    .covered_outpoints
                    .iter()
                    .any(|(t, vt)| t == &outpoint.txid && *vt == outpoint.vout)
                {
                    delegate_invalidated = true;
                }
            }
        }
    }

    if spendable.is_empty() {
        if delegate_invalidated {
            state.delegate_session = None;
            super::helpers::delete_user_delegate(shared.persistence.as_ref(), user_id_hex);
            tracing::info!("[{user_id_hex}] delegate invalidated: covered VTXO spent");
        }
        save_user_vtxos(shared.persistence.as_ref(), user_id_hex, &state.vtxos);
        return Ok(Vec::new());
    }

    let owner_pk = get_user_xonly_pubkey(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        user_id_hex,
    )?;
    let network = match ark::client::parse_network(&info.network) {
        Ok(n) => n,
        Err(e) => return Err(Status::internal(e)),
    };

    let mut newly_added = Vec::new();

    for new in &spendable {
        if let Some(outpoint) = &new.outpoint {
            // If the handler that produced this VTXO (settle, send,
            // settle_delegate) has already pushed a placeholder, don't
            // append it again or re-record a "receive" — but DO patch in
            // the timestamps the handler couldn't know (`created_at` /
            // `expires_at` come from the ASP, not from our own settle
            // session). Without this patch, self-originated VTXOs would
            // permanently report expires_at=0 and the auto-settle tick
            // task would never fire on them.
            let existing_idx = state
                .vtxos
                .iter()
                .position(|e| e.txid == outpoint.txid && e.vout == outpoint.vout);
            if let Some(i) = existing_idx {
                let entry = &mut state.vtxos[i];
                if entry.created_at == 0 && new.created_at > 0 {
                    entry.created_at = new.created_at;
                }
                if entry.expires_at == 0 && new.expires_at > 0 {
                    entry.expires_at = new.expires_at;
                    tracing::info!(
                        "[{user_id_hex}] VTXO stream: backfilled expires_at={} for {}:{}",
                        new.expires_at,
                        outpoint.txid,
                        outpoint.vout,
                    );
                }
                continue;
            }
            let exit_delay = resolve_exit_delay(
                &owner_pk,
                &info.signer_pubkey,
                &new.script,
                &info,
                network,
            );
            tracing::info!(
                "[{user_id_hex}] VTXO stream: new spendable {}:{} amount={} exit_delay={exit_delay} expires_at={}",
                outpoint.txid,
                outpoint.vout,
                new.amount,
                new.expires_at,
            );
            state.vtxos.push(VtxoEntry {
                txid: outpoint.txid.clone(),
                vout: outpoint.vout,
                amount: new.amount,
                exit_delay,
                created_at: new.created_at,
                expires_at: new.expires_at,
            });
            // A new VTXO arriving makes the existing delegate's coverage
            // stale — the client must re-delegate to include it.
            delegate_invalidated = true;
            newly_added.push((outpoint.txid.clone(), outpoint.vout));
            state.ark_tx_history.push(ArkTxEntry {
                tx_type: "receive".into(),
                amount_sats: new.amount as i64,
                txid: outpoint.txid.clone(),
                timestamp: now_secs(),
            });
        }
    }

    if delegate_invalidated {
        state.delegate_session = None;
        super::helpers::delete_user_delegate(shared.persistence.as_ref(), user_id_hex);
    }

    save_user_vtxos(shared.persistence.as_ref(), user_id_hex, &state.vtxos);
    save_user_ark_history(
        shared.persistence.as_ref(),
        user_id_hex,
        &state.ark_tx_history,
    );
    Ok(newly_added)
}
