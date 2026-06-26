//! Simple Ark RPCs (info, address derivation, balance/list).
//! Heavier ones (settle/send/redeem) live in their own module.

use std::sync::Arc;

use tokio::runtime::Handle;
use tonic::Status;

use crate::auth::message::{
    OP_CHECK_BOARDING_BALANCE, OP_GET_ARK_ADDRESS, OP_GET_ARK_INFO, OP_GET_BOARDING_ADDRESS,
    OP_LIST_ARK_TXS, OP_LIST_VTXOS,
};
use crate::cosigner::command::CosignerCommand;
use crate::cosigner::handle::CosignerHandle;
use crate::cosigner::handlers::parsers;
use crate::cosigner::registry::CosignerRegistry;
use crate::cosigner::state::CosignerState;
use crate::shared::SharedServices;
use crate::wallet_proto::*;

use super::helpers::{auth_check, get_user_xonly_pubkey};

fn require_asp(
    shared: &SharedServices,
) -> Result<std::sync::Arc<tokio::sync::Mutex<ark::client::AspClient>>, Status> {
    shared
        .asp_client
        .clone()
        .ok_or_else(|| Status::unavailable("ASP not configured (set ASP_URL env var)"))
}

/// Fetch ASP info (sync wrapper). Caches on the ASP client itself.
fn fetch_asp_info(
    asp: &std::sync::Arc<tokio::sync::Mutex<ark::client::AspClient>>,
) -> Result<ark::client::types::ArkInfo, Status> {
    let asp = asp.clone();
    Handle::current().block_on(async move {
        let mut guard = asp.lock().await;
        match &guard.info {
            Some(i) => Ok(i.clone()),
            None => guard
                .get_info()
                .await
                .map_err(|e| Status::internal(format!("ASP get_info: {e}"))),
        }
    })
}

#[tracing::instrument(skip_all, name = "actor::get_ark_info", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn get_ark_info(
    state: &mut CosignerState,
    shared: &SharedServices,
    req: GetArkInfoRequest,
) -> Result<GetArkInfoResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] GetArkInfo");
    auth_check(
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_GET_ARK_INFO,
    )?;
    let asp = require_asp(shared)?;
    let info = fetch_asp_info(&asp)?;
    Ok(GetArkInfoResponse {
        signer_pubkey: info.signer_pubkey,
        forfeit_pubkey: info.forfeit_pubkey,
        network: info.network,
        session_duration: info.session_duration,
        unilateral_exit_delay: info.unilateral_exit_delay,
        boarding_exit_delay: info.boarding_exit_delay,
        vtxo_min_amount: info.vtxo_min_amount,
        dust: info.dust,
        checkpoint_tapscript: info.checkpoint_tapscript,
        forfeit_address: info.forfeit_address,
        auto_settle_safety_margin_secs: shared.auto_settle_safety_margin_secs,
    })
}

fn register_user_scripts(
    shared: &SharedServices,
    registry: &Arc<CosignerRegistry>,
    state: &mut CosignerState,
    user_id_hex: &str,
    owner_pk_hex: &str,
    info: &ark::client::types::ArkInfo,
) {
    if !state.owned_scripts.is_empty() {
        return;
    }

    let network = match ark::client::parse_network(&info.network) {
        Ok(n) => n,
        Err(_) => return,
    };

    let mut scripts = Vec::new();
    for exit_delay in [
        info.unilateral_exit_delay as u32,
        info.boarding_exit_delay as u32,
    ] {
        if let Ok(script_hex) = ark::client::vtxo_script_pubkey_hex(
            owner_pk_hex,
            &info.signer_pubkey,
            exit_delay,
            network,
        ) {
            registry.set_script_owner(&script_hex, user_id_hex);
            if let Err(e) = shared
                .persistence
                .put("ark_script_to_user", &script_hex, user_id_hex)
            {
                tracing::warn!("persist ark_script_to_user/{script_hex} failed: {e}");
            }
            scripts.push(script_hex);
        }
    }
    if scripts.is_empty() {
        return;
    }
    state.owned_scripts.extend(scripts.iter().cloned());

    let asp_arc = match shared.asp_client.as_ref() {
        Some(a) => a.clone(),
        None => return,
    };
    let rt = Handle::current();
    let subscription_id = match rt.block_on({
        let asp_arc = asp_arc.clone();
        let scripts = scripts.clone();
        async move {
            let mut guard = asp_arc.lock().await;
            guard.subscribe_for_scripts(scripts, None).await
        }
    }) {
        Ok(id) => id,
        Err(e) => {
            tracing::warn!("[{user_id_hex}] Indexer subscribe failed: {e}");
            return;
        }
    };
    tracing::info!("[{user_id_hex}] Indexer subscription: {subscription_id}");

    let user_handle = match registry.get_or_spawn(user_id_hex) {
        Ok(h) => h,
        Err(e) => {
            tracing::warn!("[{user_id_hex}] indexer get_or_spawn failed: {e}");
            return;
        }
    };

    // Dedicated connection so the long-lived subscription stream doesn't share
    // a lock with regular RPC traffic.
    let asp_url = std::env::var("ASP_URL").unwrap_or_default();
    if asp_url.is_empty() {
        tracing::warn!("[{user_id_hex}] ASP_URL not set; cannot spawn indexer listener");
        return;
    }
    let info_clone = info.clone();
    let user_id_owned = user_id_hex.to_string();
    rt.spawn(async move {
        run_indexer_subscription(
            user_id_owned,
            subscription_id,
            asp_url,
            info_clone,
            user_handle,
        )
        .await;
    });
}

async fn run_indexer_subscription(
    user_id_hex: String,
    subscription_id: String,
    asp_url: String,
    info: ark::client::types::ArkInfo,
    user_handle: CosignerHandle,
) {
    let mut stream_client = match ark::client::AspClient::connect(&asp_url).await {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!("[{user_id_hex}] Indexer subscription connect failed: {e}");
            return;
        }
    };
    let mut stream = match stream_client.get_subscription(subscription_id).await {
        Ok(s) => s,
        Err(e) => {
            tracing::warn!("[{user_id_hex}] Indexer get_subscription failed: {e}");
            return;
        }
    };
    tracing::info!("[{user_id_hex}] Indexer subscription stream started");

    use ark::client::proto::get_subscription_response::Data;
    while let Ok(Some(event)) = stream.message().await {
        if let Some(data) = event.data {
            match data {
                Data::Event(e) => {
                    let cmd = CosignerCommand::IndexerUpdate {
                        user_id_hex: user_id_hex.clone(),
                        new_vtxos: e.new_vtxos.into_iter().map(indexer_to_vtxo).collect(),
                        spent_vtxos: e.spent_vtxos.into_iter().map(indexer_to_vtxo).collect(),
                        info: info.clone(),
                    };
                    if let Err(send_err) = user_handle.send(cmd).await {
                        tracing::warn!(
                            "[{user_id_hex}] indexer dispatch failed: {send_err}; ending subscription"
                        );
                        break;
                    }
                }
                Data::Heartbeat(_) => {}
            }
        }
    }
    tracing::info!("[{user_id_hex}] Indexer subscription stream ended");
}

fn indexer_to_vtxo(v: ark::client::proto::IndexerVtxo) -> ark::client::proto::Vtxo {
    ark::client::proto::Vtxo {
        outpoint: v.outpoint.map(|o| ark::client::proto::Outpoint {
            txid: o.txid,
            vout: o.vout,
        }),
        amount: v.amount,
        script: v.script,
        created_at: v.created_at,
        expires_at: v.expires_at,
        is_preconfirmed: v.is_preconfirmed,
        is_swept: v.is_swept,
        is_unrolled: v.is_unrolled,
        is_spent: v.is_spent,
        spent_by: v.spent_by,
        commitment_txids: v.commitment_txids,
        settled_by: v.settled_by,
        ark_txid: v.ark_txid,
        assets: Vec::new(),
    }
}

#[tracing::instrument(skip_all, name = "actor::get_ark_address", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn get_ark_address(
    state: &mut CosignerState,
    shared: &SharedServices,
    registry: &Arc<CosignerRegistry>,
    req: GetArkAddressRequest,
) -> Result<GetArkAddressResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] GetArkAddress");
    auth_check(
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_GET_ARK_ADDRESS,
    )?;
    let asp = require_asp(shared)?;
    let info = fetch_asp_info(&asp)?;

    let owner_pk_hex = get_user_xonly_pubkey(
        state,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let network = ark::client::parse_network(&info.network).map_err(Status::internal)?;
    let exit_delay = info.unilateral_exit_delay as u32;
    let ark_addr =
        ark::client::ark_address(&owner_pk_hex, &info.signer_pubkey, exit_delay, network)
            .map_err(|e| Status::internal(format!("ark_address: {e}")))?;

    register_user_scripts(shared, registry, state, &user_id_hex, &owner_pk_hex, &info);

    Ok(GetArkAddressResponse {
        ark_address: ark_addr,
    })
}

#[tracing::instrument(skip_all, name = "actor::get_boarding_address", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn get_boarding_address(
    state: &mut CosignerState,
    shared: &SharedServices,
    registry: &Arc<CosignerRegistry>,
    req: GetBoardingAddressRequest,
) -> Result<GetBoardingAddressResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] GetBoardingAddress");
    auth_check(
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_GET_BOARDING_ADDRESS,
    )?;
    let asp = require_asp(shared)?;
    let info = fetch_asp_info(&asp)?;
    let owner_pk_hex = get_user_xonly_pubkey(
        state,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;
    let network = ark::client::parse_network(&info.network).map_err(Status::internal)?;
    let exit_delay = info.boarding_exit_delay as u32;
    let boarding_addr =
        ark::client::boarding_address(&owner_pk_hex, &info.signer_pubkey, exit_delay, network)
            .map_err(|e| Status::internal(format!("boarding_address: {e}")))?;
    register_user_scripts(shared, registry, state, &user_id_hex, &owner_pk_hex, &info);
    Ok(GetBoardingAddressResponse {
        boarding_address: boarding_addr,
    })
}

#[tracing::instrument(skip_all, name = "actor::check_boarding_balance", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn check_boarding_balance(
    state: &mut CosignerState,
    shared: &SharedServices,
    req: CheckBoardingBalanceRequest,
) -> Result<CheckBoardingBalanceResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    auth_check(
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_CHECK_BOARDING_BALANCE,
    )?;
    let asp = require_asp(shared)?;
    let info = fetch_asp_info(&asp)?;

    let owner_pk_hex = get_user_xonly_pubkey(
        state,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;
    let network = ark::client::parse_network(&info.network).map_err(Status::internal)?;
    let exit_delay = info.boarding_exit_delay as u32;
    let boarding_addr =
        ark::client::boarding_address(&owner_pk_hex, &info.signer_pubkey, exit_delay, network)
            .map_err(|e| Status::internal(format!("boarding_address: {e}")))?;

    let addr: bitcoin::Address<bitcoin::address::NetworkUnchecked> = boarding_addr
        .parse()
        .map_err(|e| Status::internal(format!("parse addr: {e}")))?;
    let addr = addr
        .require_network(network)
        .map_err(|e| Status::internal(format!("network mismatch: {e}")))?;
    let script_hex = hex::encode(addr.script_pubkey().as_bytes());
    let script_hash = crate::bitcoin::tx_parser::derive_script_hash(&script_hex)
        .map_err(|e| Status::internal(format!("script_hash: {e}")))?;

    let bh = shared.bitcoin_history.clone();
    let utxos = Handle::current()
        .block_on(async move {
            let guard = bh.lock().await;
            guard.list_unspent_by_script_hash(&script_hash).await
        })
        .map_err(|e| Status::internal(format!("list_unspent: {e}")))?;

    let balance: u64 = utxos.iter().map(|u| u.amount_sats as u64).sum();
    let utxo_count = utxos.len() as u32;
    tracing::info!("[{user_id_hex}] CheckBoardingBalance: {utxo_count} UTXOs, balance={balance}");
    Ok(CheckBoardingBalanceResponse {
        balance,
        utxo_count,
    })
}

#[tracing::instrument(skip_all, name = "actor::list_vtxos", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn list_vtxos(
    state: &mut CosignerState,
    shared: &SharedServices,
    req: ListVtxosRequest,
) -> Result<ListVtxosResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    auth_check(
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_LIST_VTXOS,
    )?;

    let asp = require_asp(shared)?;
    let info = fetch_asp_info(&asp)?;
    let network = ark::client::parse_network(&info.network).map_err(Status::internal)?;

    let owner_pk_hex = get_user_xonly_pubkey(
        state,
        shared.persistence.as_ref(),
        shared.secret_store.as_ref(),
        &user_id_hex,
    )?;

    let mut vtxos = Vec::new();
    let mut total_balance: u64 = 0;
    for entry in state.vtxos.iter() {
        let script = ark::client::vtxo_script_pubkey_hex(
            &owner_pk_hex,
            &info.signer_pubkey,
            entry.exit_delay,
            network,
        )
        .unwrap_or_default();
        total_balance += entry.amount;
        vtxos.push(VtxoInfo {
            txid: entry.txid.clone(),
            vout: entry.vout,
            amount: entry.amount,
            created_at: entry.created_at,
            expires_at: entry.expires_at,
            status: "confirmed".to_string(),
            is_preconfirmed: false,
            exit_delay: entry.exit_delay,
            script,
        });
    }
    // Plan A Phase 2: a delegate is "active" if the guest holds a pending one (its `fire at`
    // threshold is set — restored from the secret-free marker on spawn) OR the legacy host session
    // is loaded. The guest path is the live one; the host `delegate_session` is the dead legacy.
    let has_active_delegate =
        state.guest_delegate_threshold.is_some() || state.delegate_session.is_some();
    tracing::info!(
        "[{user_id_hex}] ListVtxos: returning {} vtxos, balance={total_balance}, has_active_delegate={has_active_delegate}",
        vtxos.len()
    );
    Ok(ListVtxosResponse {
        vtxos,
        total_balance,
        has_active_delegate,
    })
}

#[tracing::instrument(skip_all, name = "actor::list_ark_transactions", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn list_ark_transactions(
    state: &mut CosignerState,
    _shared: &SharedServices,
    req: ListArkTransactionsRequest,
) -> Result<ListArkTransactionsResponse, Status> {
    let _user_id_hex = parsers::user_id_hex(&req.user_id);
    auth_check(
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_LIST_ARK_TXS,
    )?;
    let transactions = state
        .ark_tx_history
        .iter()
        .map(|e| ArkTransactionSummary {
            tx_type: e.tx_type.clone(),
            amount_sats: e.amount_sats,
            txid: e.txid.clone(),
            timestamp: e.timestamp,
        })
        .collect();
    Ok(ListArkTransactionsResponse { transactions })
}
