use std::collections::HashMap;

use tokio::runtime::Handle;
use tonic::Status;

use crate::auth::message::{OP_FETCH_HISTORY, OP_FETCH_RECENT_TXS};
use crate::cosigner::handlers::parsers;
use crate::cosigner::registry::CosignerInstance;
use crate::cosigner::state::CosignerState;
use crate::shared::SharedServices;
use crate::wallet_proto::*;

use super::helpers::{auth_check, ensure_policy_loaded};

#[tracing::instrument(skip_all, name = "actor::broadcast_transaction", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn broadcast_transaction(
    _user: &mut CosignerInstance,
    _state: &mut CosignerState,
    shared: &SharedServices,
    req: BroadcastTransactionRequest,
) -> Result<BroadcastTransactionResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] BroadcastTransaction");
    let bh = shared.bitcoin_history.clone();
    let tx_id = Handle::current()
        .block_on(async move {
            let guard = bh.lock().await;
            guard.broadcast_transaction(&req.tx_hex).await
        })
        .map_err(|e| Status::internal(format!("broadcast error: {e}")))?;
    tracing::info!("[{user_id_hex}] Broadcast txid: {tx_id}");
    Ok(BroadcastTransactionResponse { tx_id })
}

#[tracing::instrument(skip_all, name = "actor::fetch_history", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn fetch_history(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: FetchHistoryRequest,
) -> Result<FetchHistoryResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] FetchHistory");

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_FETCH_HISTORY,
    )?;

    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let (policy_state_clone, tweaked_map) = build_tweaked_map(user)?;

    let tweaked_fn = move |pkp_json: &str| -> Result<String, String> {
        tweaked_map
            .get(pkp_json)
            .cloned()
            .ok_or_else(|| "no tweaked key for pkp".to_string())
    };

    let bh = shared.bitcoin_history.clone();
    let utxos = Handle::current()
        .block_on(async move {
            let guard = bh.lock().await;
            guard.get_utxos(&policy_state_clone, &tweaked_fn).await
        })
        .map_err(|e| Status::internal(format!("electrum error: {e}")))?;

    let response_utxos: Vec<UtxoInfo> = utxos
        .into_iter()
        .map(|u| UtxoInfo {
            tx_hash: u.tx_hash,
            vout: u.vout as i32,
            amount: u.amount_sats,
        })
        .collect();
    Ok(FetchHistoryResponse {
        utxos: response_utxos,
    })
}

#[tracing::instrument(skip_all, name = "actor::fetch_recent_transactions", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn fetch_recent_transactions(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: FetchRecentTransactionsRequest,
) -> Result<FetchRecentTransactionsResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] FetchRecentTransactions");

    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_FETCH_RECENT_TXS,
    )?;

    ensure_policy_loaded(
        user,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let (policy_state_clone, tweaked_map) = build_tweaked_map(user)?;
    let tweaked_fn = move |pkp_json: &str| -> Result<String, String> {
        tweaked_map
            .get(pkp_json)
            .cloned()
            .ok_or_else(|| "no tweaked key for pkp".to_string())
    };

    let bh = shared.bitcoin_history.clone();
    let txs = Handle::current()
        .block_on(async move {
            let guard = bh.lock().await;
            guard
                .get_recent_transactions(&policy_state_clone, &tweaked_fn)
                .await
        })
        .map_err(|e| Status::internal(format!("electrum error: {e}")))?;

    let response_txs: Vec<TransactionSummary> = txs
        .into_iter()
        .map(|t| TransactionSummary {
            tx_hash: t.tx_hash,
            amount_sats: t.amount_sats,
            timestamp: t.timestamp as i64,
            is_pending: t.is_pending,
        })
        .collect();

    Ok(FetchRecentTransactionsResponse {
        transactions: response_txs,
    })
}

fn build_tweaked_map(
    user: &mut CosignerInstance,
) -> Result<(crate::policy::PolicyState, HashMap<String, String>), Status> {
    let ps = user
        .policy_state
        .clone()
        .ok_or_else(|| Status::not_found("no policy state"))?;

    let mut map = HashMap::new();

    let tweaked = user
        .pub_key_package_tweak(&ps.normal_policy.public_key_package_json, None)
        .map_err(|e| Status::internal(format!("tweak error: {e}")))?;
    let vk = parsers::extract_verifying_key(&tweaked)?;
    map.insert(ps.normal_policy.public_key_package_json.clone(), vk);

    Ok((ps, map))
}
