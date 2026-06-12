//! Heavy Ark RPCs (send/redeem/settle/settle_delegate/submit_ark_send).
//! Each handler runs synchronously in `spawn_blocking`; ASP gRPC calls are
//! awaited via `Handle::current().block_on(...)` against the shared client.

use tokio::runtime::Handle;
use tonic::Status;

use crate::auth::message::{
    OP_REDEEM_VTXO, OP_SEND_VTXO, OP_SETTLE, OP_SETTLE_DELEGATE,
};
use crate::shared::SharedServices;
use crate::cosigner::state::{CosignerState, DelegateRecord, VtxoEntry};
use crate::wallet_proto::*;
use crate::cosigner::handlers::parsers;
use crate::cosigner::types::ArkTxEntry;
use crate::cosigner::cosigner::CosignerInstance;

use super::helpers::{
    auth_check, delete_user_delegate, get_user_ark_keys, get_user_xonly_pubkey, now_secs,
    save_user_ark_history, save_user_delegate, save_user_vtxos,
};

fn require_asp(
    shared: &SharedServices,
) -> Result<std::sync::Arc<tokio::sync::Mutex<ark::client::AspClient>>, Status> {
    shared
        .asp_client
        .clone()
        .ok_or_else(|| Status::unavailable("ASP not configured (set ASP_URL env var)"))
}

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

fn parse_signatures(messages: &[Vec<u8>]) -> Result<Vec<[u8; 64]>, Status> {
    messages
        .iter()
        .map(|s| {
            if s.len() != 64 {
                return Err(Status::invalid_argument(format!(
                    "signature must be 64 bytes, got {}",
                    s.len()
                )));
            }
            let mut arr = [0u8; 64];
            arr.copy_from_slice(s);
            Ok(arr)
        })
        .collect()
}

// =============================================================================
// send_vtxo
// =============================================================================

#[tracing::instrument(skip_all, name = "actor::send_vtxo", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn send_vtxo(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: SendVtxoRequest,
) -> Result<SendVtxoResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!(
        "[{user_id_hex}] SendVtxo to={} amount={}",
        req.recipient_ark_address,
        req.amount
    );
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_SEND_VTXO,
    )?;

    let asp = require_asp(shared)?;
    let has_signatures = !req.signed_messages.is_empty();
    let existing = state.send_session.take();

    match (existing, has_signatures) {
        // Phase 1: build session, return sighashes.
        (None, false) | (Some(_), false) => {
            let owner_pk_hex = get_user_xonly_pubkey(
                user,
                shared.persistence.as_ref(),
                shared.secret_store.as_ref(),
                &user_id_hex,
            )?;
            let info = fetch_asp_info(&asp)?;

            if state.vtxos.is_empty() {
                return Err(Status::failed_precondition(
                    "no VTXOs available for sending",
                ));
            }
            tracing::info!("[{user_id_hex}] SendVtxo: spending VTXOs: {:?}", state.vtxos);

            let total_available: u64 = state.vtxos.iter().map(|e| e.amount).sum();
            if total_available < req.amount {
                return Err(Status::failed_precondition(format!(
                    "insufficient balance: have {} sats, need {} sats",
                    total_available, req.amount
                )));
            }

            let vtxo_inputs: Vec<ark::client::send::SendVtxoInput> = state
                .vtxos
                .iter()
                .map(|e| ark::client::send::SendVtxoInput {
                    txid: e.txid.clone(),
                    vout: e.vout,
                    amount_sats: e.amount,
                })
                .collect();

            let exit_delay = state
                .vtxos
                .first()
                .map(|e| e.exit_delay)
                .unwrap_or(info.unilateral_exit_delay as u32);

            let network = ark::client::parse_network(&info.network).map_err(Status::internal)?;
            let change_exit_delay = info.unilateral_exit_delay as u32;
            let change_addr = if total_available > req.amount {
                Some(
                    ark::client::ark_address(
                        &owner_pk_hex,
                        &info.signer_pubkey,
                        change_exit_delay,
                        network,
                    )
                    .map_err(|e| Status::internal(format!("ark_address: {e}")))?,
                )
            } else {
                None
            };

            let (session, sighashes) = ark::client::send::SendSession::build(
                &owner_pk_hex,
                &vtxo_inputs,
                &req.recipient_ark_address,
                req.amount,
                change_addr.as_deref(),
                exit_delay,
                &info,
            )
            .map_err(|e| Status::internal(format!("SendSession::build: {e}")))?;

            state.send_session = Some((session, change_exit_delay));
            Ok(SendVtxoResponse {
                status: send_vtxo_response::Status::SigningRequired as i32,
                messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                script_path_spend: true,
                ark_txid: String::new(),
                error_message: String::new(),
            })
        }

        // Phase 2: sign + submit.
        (Some((mut session, change_exit_delay)), true) => {
            let signatures = parse_signatures(&req.signed_messages)?;
            session
                .sign_with_frost(signatures)
                .map_err(|e| Status::internal(format!("sign_with_frost: {e}")))?;

            let asp = asp.clone();
            let ark_txid = Handle::current()
                .block_on(async move {
                    let mut guard = asp.lock().await;
                    session
                        .submit(&mut *guard)
                        .await
                        .map(|txid| (txid, session))
                })
                .map_err(|e| Status::internal(format!("submit: {e}")))?;
            let (ark_txid, session) = ark_txid;

            // Update local VTXO state: drop spent, add change (if any), and
            // invalidate any stored delegate intent — the send consumed the
            // VTXOs the delegate authorized. Client must re-delegate.
            let change = session.change_vtxo();
            state.vtxos.clear();
            state.delegate_session = None;
            delete_user_delegate(shared.persistence.as_ref(), &user_id_hex);
            if let Some((change_txid, change_vout, change_amount)) = change {
                tracing::info!(
                    "[{user_id_hex}] SendVtxo: change VTXO txid={}, vout={}, amount={}, exit_delay={}",
                    change_txid, change_vout, change_amount, change_exit_delay
                );
                state.vtxos.push(VtxoEntry {
                    txid: change_txid,
                    vout: change_vout,
                    amount: change_amount,
                    exit_delay: change_exit_delay,
                    created_at: now_secs(),
                    expires_at: 0,
                });
            }
            tracing::info!("[{user_id_hex}] SendVtxo: sent, ark_txid={ark_txid}");
            save_user_vtxos(shared.persistence.as_ref(), &user_id_hex, &state.vtxos);
            state.ark_tx_history.push(ArkTxEntry {
                tx_type: "send".into(),
                amount_sats: -(req.amount as i64),
                txid: ark_txid.clone(),
                timestamp: now_secs(),
            });
            save_user_ark_history(
                shared.persistence.as_ref(),
                &user_id_hex,
                &state.ark_tx_history,
            );

            Ok(SendVtxoResponse {
                status: send_vtxo_response::Status::Settled as i32,
                messages_to_sign: vec![],
                script_path_spend: false,
                ark_txid,
                error_message: String::new(),
            })
        }

        (None, true) => Err(Status::failed_precondition("no active send session")),
    }
}

// =============================================================================
// redeem_vtxo (stub)
// =============================================================================

#[tracing::instrument(skip_all, name = "actor::redeem_vtxo", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn redeem_vtxo(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: RedeemVtxoRequest,
) -> Result<RedeemVtxoResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!(
        "[{user_id_hex}] RedeemVtxo to={} amount={}",
        req.on_chain_address,
        req.amount
    );
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_REDEEM_VTXO,
    )?;
    require_asp(shared)?;
    Err(Status::unimplemented("RedeemVtxo not yet implemented"))
}

// =============================================================================
// settle (boarding)
// =============================================================================

#[tracing::instrument(skip_all, name = "actor::settle", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn settle(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: SettleRequest,
) -> Result<SettleResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] Settle");
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_SETTLE,
    )?;

    let asp = require_asp(shared)?;
    let has_signatures = !req.signed_messages.is_empty();
    let existing = state.settle_session.take();

    // A client polling without sigs while a session exists has abandoned
    // a prior Phase 1 (force-quit, network drop). Drop the stale session
    // so the match falls into Phase 1 rebuild — pre-fix this deadlocked
    // because the (Some, false) arm parked the session back.
    let existing = if existing.is_some() && !has_signatures {
        tracing::info!(
            "[{user_id_hex}] Settle: dropping stale session on poll-without-sigs, rebuilding Phase 1"
        );
        None
    } else {
        existing
    };

    match (existing, has_signatures) {
        // Phase 1: build session by scanning boarding UTXOs.
        (None, false) => {
            let (owner_pk_hex, dkg_secret_hex) = get_user_ark_keys(
                user,
                shared.persistence.as_ref(),
                shared.secret_store.as_ref(),
                &user_id_hex,
            )?;
            tracing::info!("[{user_id_hex}] Settle: awaiting asp.get_info()");
            let info = fetch_asp_info(&asp)?;
            let network = ark::client::parse_network(&info.network).map_err(Status::internal)?;
            let exit_delay = info.boarding_exit_delay as u32;
            let boarding_addr = ark::client::boarding_address(
                &owner_pk_hex,
                &info.signer_pubkey,
                exit_delay,
                network,
            )
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

            tracing::info!(
                "[{user_id_hex}] Settle: scanning electrum for boarding={boarding_addr} script_hex={script_hex} script_hash={script_hash}"
            );
            let bh = shared.bitcoin_history.clone();
            let user_id_for_log = user_id_hex.clone();
            let utxos = Handle::current()
                .block_on(async move {
                    tracing::info!("[{user_id_for_log}] Settle: awaiting electrum.list_unspent");
                    let guard = bh.lock().await;
                    guard.list_unspent_by_script_hash(&script_hash).await
                })
                .map_err(|e| Status::internal(format!("list_unspent: {e}")))?;

            if utxos.is_empty() {
                tracing::warn!(
                    "[{user_id_hex}] Settle: electrum returned 0 UTXOs for boarding={boarding_addr}"
                );
                return Err(Status::failed_precondition("no UTXOs at boarding address"));
            }
            let utxo = &utxos[0];
            tracing::info!(
                "[{user_id_hex}] Settle: boarding UTXO {}:{} amount={}",
                utxo.tx_hash,
                utxo.vout,
                utxo.amount_sats
            );

            let boarding_amount = utxo.amount_sats as u64;
            let (session, sighashes) = ark::client::batch::SettleSession::new_boarding(
                &owner_pk_hex,
                &info.signer_pubkey,
                &info.forfeit_pubkey,
                &boarding_addr,
                &utxo.tx_hash,
                utxo.vout,
                boarding_amount,
                exit_delay,
                &info.network,
                &dkg_secret_hex,
            )
            .map_err(|e| Status::internal(format!("SettleSession: {e}")))?;

            state.settle_session = Some((session, boarding_amount, exit_delay));
            Ok(SettleResponse {
                status: settle_response::Status::SigningRequired as i32,
                messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                script_path_spend: true,
                commitment_txid: String::new(),
                error_message: String::new(),
            })
        }

        // Phase 2/3: register intent or submit commitment sigs, then drive.
        (Some((session, boarding_amount, exit_delay)), true) => {
            let signatures = parse_signatures(&req.signed_messages)?;
            let asp = asp.clone();
            let user_id_for_log = user_id_hex.clone();
            // Drive the batch state machine inside one block_on so the
            // ASP guard stays held across drive() iterations.
            let outcome = Handle::current().block_on(async move {
                tracing::info!("[{user_id_for_log}] Settle: awaiting asp.lock()");
                let mut guard = asp.lock().await;
                tracing::info!("[{user_id_for_log}] Settle: got asp.lock()");
                let mut session = session;

                // Try register first; fall back to submit_commitment_sigs if the
                // session is in the wrong phase.
                tracing::info!("[{user_id_for_log}] Settle: register_with_signatures");
                let registered = match session
                    .register_with_signatures(&mut *guard, signatures.clone())
                    .await
                {
                    Ok(()) => true,
                    Err(e) if e.contains("wrong phase") => {
                        tracing::info!(
                            "[{user_id_for_log}] Settle: register wrong phase, falling back to submit_commitment_signatures"
                        );
                        session
                            .submit_commitment_signatures(&mut *guard, signatures)
                            .await
                            .map_err(|e| {
                                Status::internal(format!("submit_commitment_sigs: {e}"))
                            })?;
                        false
                    }
                    Err(e) => return Err(Status::internal(format!("register error: {e}"))),
                };
                if registered {
                    tracing::info!("[{user_id_for_log}] Settle: intent registered, driving batch");
                } else {
                    tracing::info!(
                        "[{user_id_for_log}] Settle: commitment sigs submitted, driving to finalize"
                    );
                }

                let mut iter: u64 = 0;
                loop {
                    iter += 1;
                    tracing::info!("[{user_id_for_log}] Settle: drive() iter={iter}");
                    match session.drive(&mut *guard).await {
                        Ok(ark::client::batch::SettleAction::WaitingForBatch) => {
                            tracing::info!(
                                "[{user_id_for_log}] Settle: drive() iter={iter} → WaitingForBatch"
                            );
                            continue;
                        }
                        Ok(ark::client::batch::SettleAction::NeedSignatures { sighashes }) => {
                            tracing::info!(
                                "[{user_id_for_log}] Settle: drive() iter={iter} → NeedSignatures ({} sighashes)",
                                sighashes.len()
                            );
                            return Ok(SettleOutcome::NeedSignatures { sighashes, session });
                        }
                        Ok(ark::client::batch::SettleAction::Settled {
                            commitment_txid,
                            vtxo_outpoint,
                        }) => {
                            tracing::info!(
                                "[{user_id_for_log}] Settle: drive() iter={iter} → Settled commitment_txid={commitment_txid}"
                            );
                            return Ok(SettleOutcome::Settled {
                                commitment_txid,
                                vtxo_outpoint,
                            });
                        }
                        Err(e) => return Err(Status::internal(format!("drive error: {e}"))),
                    }
                }
            })?;

            match outcome {
                SettleOutcome::NeedSignatures { sighashes, session } => {
                    state.settle_session = Some((session, boarding_amount, exit_delay));
                    Ok(SettleResponse {
                        status: settle_response::Status::SigningRequired as i32,
                        messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                        script_path_spend: true,
                        commitment_txid: String::new(),
                        error_message: String::new(),
                    })
                }
                SettleOutcome::Settled {
                    commitment_txid,
                    vtxo_outpoint,
                } => {
                    let (vtxo_txid, vtxo_vout) =
                        vtxo_outpoint.unwrap_or_else(|| (commitment_txid.clone(), 0));
                    state
                        .vtxos
                        .retain(|e| !(e.txid == vtxo_txid && e.vout == vtxo_vout));
                    state.vtxos.push(VtxoEntry {
                        txid: vtxo_txid.clone(),
                        vout: vtxo_vout,
                        amount: boarding_amount,
                        exit_delay,
                        created_at: now_secs(),
                        expires_at: 0,
                    });
                    tracing::info!(
                        "[{user_id_hex}] Settle: VTXO recorded vtxo_txid={vtxo_txid}:{vtxo_vout} amount={boarding_amount} exit_delay={exit_delay}"
                    );
                    save_user_vtxos(shared.persistence.as_ref(), &user_id_hex, &state.vtxos);
                    state.ark_tx_history.push(ArkTxEntry {
                        tx_type: "board".into(),
                        amount_sats: boarding_amount as i64,
                        txid: vtxo_txid,
                        timestamp: now_secs(),
                    });
                    save_user_ark_history(
                        shared.persistence.as_ref(),
                        &user_id_hex,
                        &state.ark_tx_history,
                    );
                    Ok(SettleResponse {
                        status: settle_response::Status::Settled as i32,
                        messages_to_sign: vec![],
                        script_path_spend: false,
                        commitment_txid,
                        error_message: String::new(),
                    })
                }
            }
        }

        (None, true) => Err(Status::failed_precondition("no active settle session")),
        (Some(_), false) => unreachable!("coerced to (None, false) by recovery guard above"),
    }
}

enum SettleOutcome {
    NeedSignatures {
        sighashes: Vec<[u8; 32]>,
        session: ark::client::batch::SettleSession,
    },
    Settled {
        commitment_txid: String,
        vtxo_outpoint: Option<(String, u32)>,
    },
}

// =============================================================================
// settle_delegate
// =============================================================================

#[tracing::instrument(skip_all, name = "actor::settle_delegate", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn settle_delegate(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: SettleDelegateRequest,
) -> Result<SettleDelegateResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] SettleDelegate");
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_SETTLE_DELEGATE,
    )?;

    let asp = require_asp(shared)?;
    let has_signatures = !req.signed_messages.is_empty();
    let existing = state.delegate_session.take();

    match (existing, has_signatures) {
        // Phase 1: generate delegate.
        (None, false) => {
            let (owner_pk_hex, dkg_secret_hex) = get_user_ark_keys(
                user,
                shared.persistence.as_ref(),
                shared.secret_store.as_ref(),
                &user_id_hex,
            )?;
            let info = fetch_asp_info(&asp)?;

            if state.vtxos.is_empty() {
                return Err(Status::failed_precondition("no VTXOs to settle"));
            }
            let vtxo_inputs: Vec<ark::client::batch::DelegateVtxoInput> = state
                .vtxos
                .iter()
                .map(|e| ark::client::batch::DelegateVtxoInput {
                    txid: e.txid.clone(),
                    vout: e.vout,
                    amount_sats: e.amount,
                    is_swept: false,
                })
                .collect();
            let total_amount: u64 = state.vtxos.iter().map(|e| e.amount).sum();

            let network = ark::client::parse_network(&info.network).map_err(Status::internal)?;
            // Two different delays in play:
            //   * `input_exit_delay` — used to reconstruct the EXISTING VTXO's
            //     script in the PSBT input. A freshly-boarded VTXO has
            //     `boarding_exit_delay`; a refreshed one has
            //     `unilateral_exit_delay`. `vtxo_stream::resolve_exit_delay`
            //     stores the correct value per VTXO. `generate_delegate` only
            //     accepts a single exit_delay so we require all inputs to share
            //     it (typical case: 1 VTXO).
            //   * `output_exit_delay` — `unilateral_exit_delay`, always: the
            //     refreshed VTXO landing post-settle is in the tree, not at the
            //     boarding script.
            let input_exit_delay = state
                .vtxos
                .first()
                .map(|e| e.exit_delay)
                .unwrap_or(info.unilateral_exit_delay as u32);
            if state.vtxos.iter().any(|e| e.exit_delay != input_exit_delay) {
                return Err(Status::failed_precondition(
                    "settle_delegate cannot mix VTXOs with different exit_delays; \
                     refresh first by sending a no-op or by manual settle",
                ));
            }
            let output_exit_delay = info.unilateral_exit_delay as u32;
            let ark_addr = ark::client::ark_address(
                &owner_pk_hex,
                &info.signer_pubkey,
                output_exit_delay,
                network,
            )
            .map_err(|e| Status::internal(format!("ark_address: {e}")))?;
            let outputs = vec![ark::client::batch::DelegateOutput {
                ark_address: ark_addr,
                amount_sats: total_amount,
            }];

            // The ASP publishes its canonical forfeit address via `getInfo`.
            // Reconstructing it from `info.forfeit_pubkey` as a plain P2TR
            // keyspend can drift from what the ASP actually uses (taproot
            // script-tree differences yield a different output script and
            // thus a different forfeit txid). Always use the address the ASP
            // gives us directly.
            if info.forfeit_address.is_empty() {
                return Err(Status::internal(
                    "ASP info missing forfeit_address; cannot build forfeit PSBTs",
                ));
            }

            // Earliest expiry across the covered VTXOs sets the intent's
            // renewal time. We sign with valid_at = expiry - safety_margin and
            // expire_at = 0 (no expiry): arkd rejects settling before the
            // renewal time, and the stored proof never goes stale. When the
            // expiry isn't known yet, fall back to the legacy 2-minute window.
            let earliest_expires_at = state
                .vtxos
                .iter()
                .filter_map(|e| if e.expires_at > 0 { Some(e.expires_at) } else { None })
                .min()
                .unwrap_or(0);
            let margin = shared.auto_settle_safety_margin_secs;
            let intent_valid_at = if earliest_expires_at > margin {
                Some((earliest_expires_at - margin) as u64)
            } else {
                None
            };

            let (session, sighashes) =
                ark::client::batch::DelegateSettleSession::generate_delegate(
                    &owner_pk_hex,
                    &info.signer_pubkey,
                    &info.forfeit_pubkey,
                    &dkg_secret_hex,
                    &vtxo_inputs,
                    &outputs,
                    &info.forfeit_address,
                    info.dust as u64,
                    input_exit_delay,
                    &info.network,
                    intent_valid_at,
                )
                .map_err(|e| Status::internal(format!("generate_delegate: {e}")))?;

            // Capture the scope of this delegate so the auto-settle tick task
            // and the conflict-invalidation hooks can reason about it without
            // re-reading the session internals.
            let covered_outpoints: Vec<(String, u32)> = state
                .vtxos
                .iter()
                .map(|e| (e.txid.clone(), e.vout))
                .collect();

            state.delegate_session = Some(DelegateRecord {
                session,
                covered_outpoints,
                earliest_expires_at,
                awaiting_signatures: true,
            });
            Ok(SettleDelegateResponse {
                status: settle_delegate_response::Status::SigningRequired as i32,
                messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                script_path_spend: true,
                commitment_txid: String::new(),
                error_message: String::new(),
            })
        }

        // Phase 2: sign with FROST. Either store the signed intent
        // (`store_only=true`, used by the auto-trigger after a receive) or
        // drive the batch immediately (the existing manual-settle path).
        (Some(mut record), true) => {
            let signatures = parse_signatures(&req.signed_messages)?;
            record
                .session
                .sign_with_frost(signatures)
                .map_err(|e| Status::internal(format!("sign_with_frost: {e}")))?;
            // Sign-with-frost succeeded; this record is no longer in the
            // "client is signing my sighashes right now" state, so the
            // sign-step1 policy bypass must stop applying to subsequent
            // unrelated sign calls (e.g. off-chain Ark sends).
            record.awaiting_signatures = false;

            if req.store_only {
                tracing::info!(
                    "[{user_id_hex}] SettleDelegate: stored signed intent for {} VTXO(s), earliest_expires_at={}",
                    record.covered_outpoints.len(),
                    record.earliest_expires_at
                );
                // Persist the intent so it survives a cosigner-runtime
                // restart. `to_persisted` only succeeds in ReadyToSettle
                // phase — `sign_with_frost` above just moved us there.
                // Best-effort: if persistence fails we still keep the
                // in-memory copy so the current process can fire it.
                match record.session.to_persisted() {
                    Ok(persisted_session) => {
                        let persisted = crate::cosigner::state::PersistedDelegateRecord {
                            session: persisted_session,
                            covered_outpoints: record.covered_outpoints.clone(),
                            earliest_expires_at: record.earliest_expires_at,
                        };
                        save_user_delegate(
                            shared.persistence.as_ref(),
                            &user_id_hex,
                            &persisted,
                        );
                    }
                    Err(e) => {
                        tracing::warn!(
                            "[{user_id_hex}] failed to serialize delegate for persistence: {e}; in-memory only"
                        );
                    }
                }
                state.delegate_session = Some(record);
                return Ok(SettleDelegateResponse {
                    status: settle_delegate_response::Status::Delegated as i32,
                    messages_to_sign: vec![],
                    script_path_spend: false,
                    commitment_txid: String::new(),
                    error_message: String::new(),
                });
            }

            let asp_for_call = asp.clone();
            let mut session = record.session;
            let (commitment_txid, vtxo_outpoint, info) = Handle::current()
                .block_on(async move {
                    let mut guard = asp_for_call.lock().await;
                    let (commitment_txid, vtxo_outpoint) = session
                        .settle(&mut *guard)
                        .await
                        .map_err(|e| Status::internal(format!("settle: {e}")))?;
                    let info = match &guard.info {
                        Some(i) => i.clone(),
                        None => guard
                            .get_info()
                            .await
                            .map_err(|e| Status::internal(format!("get_info: {e}")))?,
                    };
                    Ok::<_, Status>((commitment_txid, vtxo_outpoint, info))
                })?;

            let (vtxo_txid, vtxo_vout): (String, u32) =
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
            tracing::info!(
                "[{user_id_hex}] SettleDelegate: settled, new VTXO txid={vtxo_txid}:{vtxo_vout} amount={total_amount}"
            );
            save_user_vtxos(shared.persistence.as_ref(), &user_id_hex, &state.vtxos);
            // The session was consumed by `settle()` — its sled row (if
            // any from a previous store_only) must go too.
            delete_user_delegate(shared.persistence.as_ref(), &user_id_hex);
            state.ark_tx_history.push(ArkTxEntry {
                tx_type: "settle".into(),
                amount_sats: total_amount as i64,
                txid: vtxo_txid,
                timestamp: now_secs(),
            });
            save_user_ark_history(
                shared.persistence.as_ref(),
                &user_id_hex,
                &state.ark_tx_history,
            );

            Ok(SettleDelegateResponse {
                status: settle_delegate_response::Status::Settled as i32,
                messages_to_sign: vec![],
                script_path_spend: false,
                commitment_txid,
                error_message: String::new(),
            })
        }

        // Session exists but no signatures.
        (Some(record), false) => {
            state.delegate_session = Some(record);
            Err(Status::failed_precondition(
                "delegate session exists; provide signatures",
            ))
        }
        (None, true) => Err(Status::failed_precondition("no active delegate session")),
    }
}

// =============================================================================
// submit_ark_send
// =============================================================================

#[tracing::instrument(skip_all, name = "actor::submit_ark_send", fields(user_id = %parsers::user_id_hex(&req.user_id)), err)]
pub fn submit_ark_send(
    user: &mut CosignerInstance,
    state: &mut CosignerState,
    shared: &SharedServices,
    req: SubmitArkSendRequest,
) -> Result<SubmitArkSendResponse, Status> {
    use bitcoin::base64::{self, Engine as _};

    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] SubmitArkSend");
    auth_check(
        user,
        state,
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        OP_SEND_VTXO,
    )?;

    let asp = require_asp(shared)?;

    // Decode client's signed ark tx (base64 PSBT).
    let signed_ark_bytes = base64::engine::general_purpose::STANDARD
        .decode(&req.signed_ark_tx_b64)
        .map_err(|e| Status::invalid_argument(format!("invalid ark tx base64: {e}")))?;
    let signed_ark_psbt = bitcoin::Psbt::deserialize(&signed_ark_bytes)
        .map_err(|e| Status::invalid_argument(format!("invalid ark tx PSBT: {e}")))?;

    for (i, input) in signed_ark_psbt.unsigned_tx.input.iter().enumerate() {
        tracing::info!(
            "[{user_id_hex}] SubmitArkSend: PSBT input[{i}] = {}:{}",
            input.previous_output.txid,
            input.previous_output.vout
        );
    }

    let mut client_signed_checkpoints = Vec::new();
    let mut signed_checkpoint_b64s = Vec::new();
    for cp_b64 in &req.signed_checkpoint_txs_b64 {
        let cp_bytes = base64::engine::general_purpose::STANDARD
            .decode(cp_b64)
            .map_err(|e| Status::invalid_argument(format!("invalid checkpoint base64: {e}")))?;
        let cp = bitcoin::Psbt::deserialize(&cp_bytes)
            .map_err(|e| Status::invalid_argument(format!("invalid checkpoint PSBT: {e}")))?;
        client_signed_checkpoints.push(cp);
        signed_checkpoint_b64s.push(cp_b64.clone());
    }

    let signed_ark_b64 =
        base64::engine::general_purpose::STANDARD.encode(&signed_ark_psbt.serialize());

    // Submit + finalize against the ASP, then return the response data we need
    // back to the sync side.
    let asp_for_call = asp.clone();
    let log_user = user_id_hex.clone();
    let (ark_txid, response_signed_checkpoint_txs, info) = Handle::current().block_on(
        async move {
            let mut guard = asp_for_call.lock().await;
            tracing::info!("[{log_user}] SubmitArkSend: calling asp.submit_tx");
            let response = guard
                .submit_tx(signed_ark_b64, signed_checkpoint_b64s)
                .await
                .map_err(|e| {
                    tracing::error!(
                        "[{log_user}] SubmitArkSend: asp.submit_tx failed: {e}"
                    );
                    Status::internal(format!("submit_tx: {e}"))
                })?;
            let ark_txid = response.ark_txid.clone();
            // Hold off on info fetch until after counter-signing is decided.
            Ok::<_, Status>((ark_txid, response.signed_checkpoint_txs, guard.info.clone()))
        },
    )?;

    // Counter-sign: merge client FROST sigs onto ASP-returned checkpoints.
    let mut final_checkpoints = Vec::new();
    for asp_cp_b64 in &response_signed_checkpoint_txs {
        let asp_cp_bytes = base64::engine::general_purpose::STANDARD
            .decode(asp_cp_b64)
            .map_err(|e| Status::internal(format!("invalid ASP checkpoint: {e}")))?;
        let mut asp_cp = bitcoin::Psbt::deserialize(&asp_cp_bytes)
            .map_err(|e| Status::internal(format!("invalid ASP checkpoint PSBT: {e}")))?;

        let cp_txid = asp_cp.unsigned_tx.compute_txid();
        if let Some(client_cp) = client_signed_checkpoints
            .iter()
            .find(|cp| cp.unsigned_tx.compute_txid() == cp_txid)
        {
            if let Some(ws) = &client_cp.inputs[0].witness_script {
                asp_cp.inputs[0].witness_script = Some(ws.clone());
            }
            if asp_cp.inputs[0].tap_scripts.is_empty() {
                asp_cp.inputs[0].tap_scripts = client_cp.inputs[0].tap_scripts.clone();
            }
            // arkd drops the client's `condition` witness field when it re-serializes
            // the checkpoint, yet re-evaluates the condition at FinalizeTx — carry it back.
            for (k, v) in &client_cp.inputs[0].unknown {
                asp_cp.inputs[0]
                    .unknown
                    .entry(k.clone())
                    .or_insert_with(|| v.clone());
            }
            for ((pk, lh), sig) in &client_cp.inputs[0].tap_script_sigs {
                asp_cp.inputs[0]
                    .tap_script_sigs
                    .insert((*pk, *lh), sig.clone());
            }
        }

        let final_bytes = asp_cp.serialize();
        final_checkpoints.push(base64::engine::general_purpose::STANDARD.encode(&final_bytes));
    }

    // Finalize.
    let asp_for_finalize = asp.clone();
    let ark_txid_for_finalize = ark_txid.clone();
    Handle::current().block_on(async move {
        let mut guard = asp_for_finalize.lock().await;
        guard
            .finalize_tx(ark_txid_for_finalize, final_checkpoints)
            .await
            .map_err(|e| Status::internal(format!("finalize_tx: {e}")))
    })?;

    // Compute change VTXO.
    let outputs = &signed_ark_psbt.unsigned_tx.output;
    let (change_txid, change_vout, change_amount) = if outputs.len() >= 3 {
        let txid = signed_ark_psbt.unsigned_tx.compute_txid().to_string();
        let idx = (outputs.len() - 2) as u32;
        let amt = outputs[idx as usize].value.to_sat();
        (txid, idx, amt)
    } else {
        (String::new(), 0, 0)
    };

    // Update local VTXO state. The off-chain send consumed VTXOs, so any
    // stored delegate intent is now stale — invalidate it.
    let spent_total: u64 = state
        .vtxos
        .iter()
        .filter(|e| req.spent_outpoints.contains(&format!("{}:{}", e.txid, e.vout)))
        .map(|e| e.amount)
        .sum();
    state.vtxos.retain(|e| {
        !req.spent_outpoints.contains(&format!("{}:{}", e.txid, e.vout))
    });
    if let Some(record) = &state.delegate_session {
        let any_covered_spent = record.covered_outpoints.iter().any(|(t, v)| {
            req.spent_outpoints.contains(&format!("{t}:{v}"))
        });
        if any_covered_spent {
            state.delegate_session = None;
            delete_user_delegate(shared.persistence.as_ref(), &user_id_hex);
            tracing::info!(
                "[{user_id_hex}] delegate invalidated: covered VTXO consumed by off-chain send"
            );
        }
    }
    if change_amount > 0 {
        let exit_delay = match info {
            Some(i) => i.unilateral_exit_delay as u32,
            None => fetch_asp_info(&asp)?.unilateral_exit_delay as u32,
        };
        state.vtxos.push(VtxoEntry {
            txid: change_txid.clone(),
            vout: change_vout,
            amount: change_amount,
            exit_delay,
            created_at: now_secs(),
            expires_at: 0,
        });
    }

    tracing::info!(
        "[{user_id_hex}] SubmitArkSend: ark_txid={ark_txid}, change=({change_txid}, {change_vout}, {change_amount})"
    );
    save_user_vtxos(shared.persistence.as_ref(), &user_id_hex, &state.vtxos);

    let sent_amount = spent_total.saturating_sub(change_amount);
    state.ark_tx_history.push(ArkTxEntry {
        tx_type: "send".into(),
        amount_sats: -(sent_amount as i64),
        txid: ark_txid.clone(),
        timestamp: now_secs(),
    });
    save_user_ark_history(
        shared.persistence.as_ref(),
        &user_id_hex,
        &state.ark_tx_history,
    );

    Ok(SubmitArkSendResponse {
        ark_txid,
        change_txid,
        change_vout,
        change_amount,
    })
}
