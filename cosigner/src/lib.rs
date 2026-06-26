//! Long-lived cosigner guest as a native-async component (reactor). Exports async
//! `handle(request) -> response`; the host calls it per command and the instance's
//! state persists across calls (verified pattern, wasmtime 45). Request/response bodies
//! are serialized cosigner-proto `GuestCommand`/`GuestResponse`.
//!
//! All command handling lives in [`state::GuestState`] (transport-agnostic).

wit_bindgen::generate!({
    world: "cosigner-guest",
    path: "wit",
    async: true,
});

mod conditioning;
mod grpc;
mod state;

use std::cell::RefCell;

use cosigner_proto::{
    GenerateDelegateWire, GuestCommand, GuestResponse, SendVtxoStep1Wire, SendVtxoStep2Wire,
    SignStep1Wire, SignStep2Wire,
};
use state::GuestState;

thread_local! {
    /// The single per-instance guest state. wasm is single-threaded, so a thread-local
    /// is effectively instance-global and persists across `handle` calls.
    static STATE: RefCell<GuestState> = RefCell::new(GuestState::new());
}

struct Component;

impl Guest for Component {
    async fn handle(request: Vec<u8>) -> Vec<u8> {
        let response = match serde_json::from_slice::<GuestCommand>(&request) {
            // Async commands (they await wasi:http via the host's h2 hook) are handled
            // here, not in the sync `handle_command`. wstd needs to own its reactor, so we
            // drive the HTTP future with `wstd::runtime::block_on` (its wasi:io/poll calls
            // suspend the guest fiber, letting the host service the actual h2 request).
            // FROST sign is async-routed too: step2 calls the async `contract-gate` host
            // import (enforce) before producing the cosigner's share.
            Ok(GuestCommand::FrostSignStep1(req)) => {
                wstd::runtime::block_on(async move { frost_sign_step1(req).await })
            }
            Ok(GuestCommand::FrostSignStep2(req)) => {
                wstd::runtime::block_on(async move { frost_sign_step2(req).await })
            }
            Ok(GuestCommand::SendVtxoStep1(req)) => {
                wstd::runtime::block_on(async move { send_vtxo_step1(req).await })
            }
            Ok(GuestCommand::SendVtxoStep2(req)) => {
                wstd::runtime::block_on(async move { send_vtxo_step2(req).await })
            }
            Ok(GuestCommand::GenerateDelegate(req)) => {
                wstd::runtime::block_on(async move { generate_delegate(req).await })
            }
            Ok(GuestCommand::SettleDelegate { asp_url }) => {
                wstd::runtime::block_on(async move { settle_delegate(&asp_url).await })
            }
            Ok(GuestCommand::BoardingSettleStep1 {
                owner_pk_hex,
                signer_pubkey,
                forfeit_pubkey,
                boarding_address,
                boarding_txid,
                boarding_vout,
                boarding_amount_sats,
                exit_delay,
                network,
            }) => boarding_settle_step1(
                &owner_pk_hex,
                &signer_pubkey,
                &forfeit_pubkey,
                &boarding_address,
                &boarding_txid,
                boarding_vout,
                boarding_amount_sats,
                exit_delay,
                &network,
            ),
            Ok(GuestCommand::BoardingSettleStep2 {
                asp_url,
                intent_signatures,
            }) => wstd::runtime::block_on(async move {
                boarding_settle_step2(&asp_url, intent_signatures).await
            }),
            Ok(GuestCommand::BoardingSettleStep3 {
                asp_url,
                commitment_signatures,
            }) => wstd::runtime::block_on(async move {
                boarding_settle_step3(&asp_url, commitment_signatures).await
            }),
            Ok(cmd) => STATE.with(|s| s.borrow_mut().handle_command(cmd)),
            Err(e) => GuestResponse::Error(format!("undecodable command: {e}")),
        };
        serde_json::to_vec(&response).unwrap_or_else(|e| {
            serde_json::to_vec(&GuestResponse::Error(format!("unserializable response: {e}")))
                .expect("error response serializes")
        })
    }
}

/// FROST sign round 1: store the client's commitments + the full tx, return the combined
/// commitments. (Sync logic; async only so it shares the routing with step2.)
async fn frost_sign_step1(req: SignStep1Wire) -> GuestResponse {
    STATE
        .with(|s| s.borrow_mut().sign_step1(req))
        .unwrap_or_else(GuestResponse::Error)
}

/// FROST sign round 2: enforce the bound contract (host `contract-gate` import) over the full
/// transaction BEFORE producing the cosigner's share — on Deny the guest refuses to sign.
/// `enforce` is a no-op (Ok) for non-contract spends. Then aggregate.
async fn frost_sign_step2(req: SignStep2Wire) -> GuestResponse {
    let full_tx = STATE.with(|s| s.borrow().pending_full_transaction());
    if let Err(e) = crate::cosigner::guest::contract_gate::enforce(full_tx).await {
        return GuestResponse::Error(format!("contract gate denied: {e}"));
    }
    STATE
        .with(|s| s.borrow_mut().sign_step2(req))
        .unwrap_or_else(GuestResponse::Error)
}

/// gRPC `GetInfo` → `ArkInfo` (proto field-for-field, same as the host's AspClient).
async fn grpc_get_info(asp_url: &str) -> Result<ark::client::types::ArkInfo, String> {
    use ark::client::proto::{GetInfoRequest, GetInfoResponse};
    use ark::client::types::ArkInfo;

    let r: GetInfoResponse = grpc::unary(asp_url, "/ark.v1.ArkService/GetInfo", &GetInfoRequest {})
        .await
        .map_err(|e| format!("GetInfo: {e}"))?;
    Ok(ArkInfo {
        signer_pubkey: r.signer_pubkey,
        forfeit_pubkey: r.forfeit_pubkey,
        forfeit_address: r.forfeit_address,
        checkpoint_tapscript: r.checkpoint_tapscript,
        network: r.network,
        session_duration: r.session_duration,
        unilateral_exit_delay: r.unilateral_exit_delay,
        boarding_exit_delay: r.boarding_exit_delay,
        vtxo_min_amount: r.vtxo_min_amount,
        dust: r.dust,
    })
}

/// Delegate phase 1: build the pre-authorized intent + forfeit PSBTs (after a gRPC `GetInfo`
/// for the ASP/forfeit keys) and return the sighashes the client must FROST-sign. The Ark
/// cosigner secret (installed via InstallPolicy) is used here and never leaves the guest.
async fn generate_delegate(req: GenerateDelegateWire) -> GuestResponse {
    use ark::client::batch::{DelegateOutput, DelegateSettleSession, DelegateVtxoInput};

    if let Err(e) = state::auth_check(
        &req.user_id,
        &req.signature,
        req.timestamp_ms,
        state::OP_SETTLE_DELEGATE,
    ) {
        return GuestResponse::Error(e);
    }
    let (owner_pk_hex, cosigner_secret_hex, vtxos) = match STATE.with(|s| {
        let st = s.borrow();
        let owner = st.owner_pk_hex()?;
        let secret = st
            .ark_cosigner_secret_hex()
            .ok_or("no Ark cosigner secret installed")?
            .to_string();
        Ok::<_, String>((owner, secret, st.vtxos().to_vec()))
    }) {
        Ok(v) => v,
        Err(e) => return GuestResponse::Error(e),
    };

    let info = match grpc_get_info(&req.asp_url).await {
        Ok(i) => i,
        Err(e) => return GuestResponse::Error(e),
    };

    if vtxos.is_empty() {
        return GuestResponse::Error("no VTXOs to settle".into());
    }
    // VTXOs come from the guest's own store; is_swept is always false (host never marks it).
    let vtxo_inputs: Vec<DelegateVtxoInput> = vtxos
        .iter()
        .map(|v| DelegateVtxoInput {
            txid: v.txid.clone(),
            vout: v.vout,
            amount_sats: v.amount_sats,
            is_swept: false,
        })
        .collect();

    // generate_delegate takes a single input exit_delay (used to reconstruct the existing
    // VTXO scripts) — require all inputs to share it (typical case: 1 VTXO).
    let input_exit_delay = vtxos[0].exit_delay;
    if vtxos.iter().any(|v| v.exit_delay != input_exit_delay) {
        return GuestResponse::Error("cannot settle VTXOs with mixed exit_delays".into());
    }

    // The settle is a self-refresh: the full balance lands back at the owner's own ark
    // address, in the tree (so output uses the unilateral exit delay).
    let network = match ark::client::parse_network(&info.network) {
        Ok(n) => n,
        Err(e) => return GuestResponse::Error(e),
    };
    let total: u64 = vtxos.iter().map(|v| v.amount_sats).sum();
    let owner_ark_address = match ark::client::ark_address(
        &owner_pk_hex,
        &info.signer_pubkey,
        info.unilateral_exit_delay as u32,
        network,
    ) {
        Ok(a) => a,
        Err(e) => return GuestResponse::Error(format!("ark_address: {e}")),
    };
    let outputs = vec![DelegateOutput {
        ark_address: owner_ark_address,
        amount_sats: total,
    }];

    match DelegateSettleSession::generate_delegate(
        &owner_pk_hex,
        &info.signer_pubkey,
        &info.forfeit_pubkey,
        &cosigner_secret_hex,
        &vtxo_inputs,
        &outputs,
        &info.forfeit_address,
        info.dust as u64,
        input_exit_delay,
        &info.network,
        req.intent_valid_at,
    ) {
        Ok((session, sighashes)) => {
            STATE.with(|s| s.borrow_mut().set_delegate_session(session));
            GuestResponse::DelegateSighashes {
                messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
            }
        }
        Err(e) => GuestResponse::Error(format!("generate_delegate: {e}")),
    }
}

/// Drive a delegate/auto-settle batch entirely in the guest: register the pre-authorized
/// intent, open the ASP event stream, and run the MuSig2 tree-signing + forfeit loop to
/// completion over `grpc::unary` + `ServerStream`. The session's secret cosigner key and
/// MuSig2 nonces never leave the guest. Requires an installed `ReadyToSettle` session.
async fn settle_delegate(asp_url: &str) -> GuestResponse {
    use ark::client::proto::{
        get_event_stream_response::Event, ConfirmRegistrationRequest, ConfirmRegistrationResponse,
        GetEventStreamRequest, GetEventStreamResponse, Intent, RegisterIntentRequest,
        RegisterIntentResponse, SubmitSignedForfeitTxsRequest, SubmitSignedForfeitTxsResponse,
        SubmitTreeNoncesRequest, SubmitTreeNoncesResponse, SubmitTreeSignaturesRequest,
        SubmitTreeSignaturesResponse,
    };

    // Registration payload (scoped borrow — no await held).
    let (proof, message, topics) = match STATE.with(|s| {
        s.borrow()
            .delegate_session_ref()
            .ok_or_else(|| "no delegate session installed".to_string())
            .and_then(|sess| sess.register_payload())
    }) {
        Ok(v) => v,
        Err(e) => return GuestResponse::Error(e),
    };

    let reg: RegisterIntentResponse = match grpc::unary(
        asp_url,
        "/ark.v1.ArkService/RegisterIntent",
        &RegisterIntentRequest {
            intent: Some(Intent { proof, message }),
        },
    )
    .await
    {
        Ok(r) => r,
        Err(e) => return GuestResponse::Error(format!("RegisterIntent: {e}")),
    };
    let intent_id = reg.intent_id;
    eprintln!("settle_delegate: RegisterIntent ok intent_id={intent_id} topics={topics:?}");

    let mut stream = match grpc::ServerStream::open(
        asp_url,
        "/ark.v1.ArkService/GetEventStream",
        &GetEventStreamRequest { topics },
    )
    .await
    {
        Ok(s) => s,
        Err(e) => return GuestResponse::Error(format!("GetEventStream: {e}")),
    };
    eprintln!("settle_delegate: event stream opened, waiting for batch");

    loop {
        let resp: GetEventStreamResponse = match stream.next().await {
            Ok(Some(r)) => r,
            Ok(None) => return GuestResponse::Error("event stream ended unexpectedly".into()),
            Err(e) => return GuestResponse::Error(format!("event stream: {e}")),
        };
        let Some(event) = resp.event else { continue };

        // Each arm: run the (sync, secret-using) step method under a scoped STATE borrow to
        // get the submit payload, then `grpc::unary` it (no borrow held across the await).
        match event {
            Event::BatchStarted(e) => {
                if let Err(e) = STATE.with(|s| {
                    s.borrow_mut()
                        .delegate_session_mut()
                        .ok_or_else(|| "no delegate session".to_string())
                        .and_then(|sess| sess.on_batch_started(e))
                }) {
                    return GuestResponse::Error(e);
                }
                let _: ConfirmRegistrationResponse = match grpc::unary(
                    asp_url,
                    "/ark.v1.ArkService/ConfirmRegistration",
                    &ConfirmRegistrationRequest {
                        intent_id: intent_id.clone(),
                    },
                )
                .await
                {
                    Ok(r) => r,
                    Err(e) => return GuestResponse::Error(format!("ConfirmRegistration: {e}")),
                };
            }
            Event::TreeTx(e) => {
                if let Err(e) = STATE.with(|s| {
                    s.borrow_mut()
                        .delegate_session_mut()
                        .ok_or_else(|| "no delegate session".to_string())
                        .and_then(|sess| sess.on_tree_tx(e))
                }) {
                    return GuestResponse::Error(e);
                }
            }
            Event::TreeSigningStarted(e) => {
                let (batch_id, pubkey, tree_nonces) = match STATE.with(|s| {
                    s.borrow_mut()
                        .delegate_session_mut()
                        .ok_or_else(|| "no delegate session".to_string())
                        .and_then(|sess| sess.on_tree_signing_started(e))
                }) {
                    Ok(v) => v,
                    Err(e) => return GuestResponse::Error(e),
                };
                let _: SubmitTreeNoncesResponse = match grpc::unary(
                    asp_url,
                    "/ark.v1.ArkService/SubmitTreeNonces",
                    &SubmitTreeNoncesRequest {
                        batch_id,
                        pubkey,
                        tree_nonces,
                    },
                )
                .await
                {
                    Ok(r) => r,
                    Err(e) => return GuestResponse::Error(format!("SubmitTreeNonces: {e}")),
                };
            }
            Event::TreeNonces(e) => {
                let maybe = match STATE.with(|s| {
                    s.borrow_mut()
                        .delegate_session_mut()
                        .ok_or_else(|| "no delegate session".to_string())
                        .and_then(|sess| sess.on_tree_nonces(e))
                }) {
                    Ok(v) => v,
                    Err(e) => return GuestResponse::Error(e),
                };
                if let Some((batch_id, pubkey, tree_signatures)) = maybe {
                    let _: SubmitTreeSignaturesResponse = match grpc::unary(
                        asp_url,
                        "/ark.v1.ArkService/SubmitTreeSignatures",
                        &SubmitTreeSignaturesRequest {
                            batch_id,
                            pubkey,
                            tree_signatures,
                        },
                    )
                    .await
                    {
                        Ok(r) => r,
                        Err(e) => {
                            return GuestResponse::Error(format!("SubmitTreeSignatures: {e}"))
                        }
                    };
                }
            }
            Event::BatchFinalization(e) => {
                let maybe = match STATE.with(|s| {
                    s.borrow_mut()
                        .delegate_session_mut()
                        .ok_or_else(|| "no delegate session".to_string())
                        .and_then(|sess| sess.on_batch_finalization(e))
                }) {
                    Ok(v) => v,
                    Err(e) => return GuestResponse::Error(e),
                };
                if let Some(signed_forfeit_txs) = maybe {
                    let _: SubmitSignedForfeitTxsResponse = match grpc::unary(
                        asp_url,
                        "/ark.v1.ArkService/SubmitSignedForfeitTxs",
                        &SubmitSignedForfeitTxsRequest {
                            signed_forfeit_txs,
                            signed_commitment_tx: String::new(),
                        },
                    )
                    .await
                    {
                        Ok(r) => r,
                        Err(e) => {
                            return GuestResponse::Error(format!("SubmitSignedForfeitTxs: {e}"))
                        }
                    };
                }
            }
            Event::BatchFinalized(e) => {
                let finalized = STATE.with(|s| {
                    let mut st = s.borrow_mut();
                    let result = st
                        .delegate_session_mut()
                        .map(|sess| sess.on_batch_finalized(e));
                    st.clear_delegate_session();
                    result
                });
                return match finalized {
                    Some((commitment_txid, vtxo_outpoint)) => GuestResponse::SettleSubmitted {
                        commitment_txid,
                        vtxo_outpoint,
                    },
                    None => GuestResponse::Error("no delegate session at finalize".into()),
                };
            }
            Event::BatchFailed(e) => {
                return GuestResponse::Error(format!("batch failed: {}", e.reason))
            }
            // TreeNoncesAggregated, TreeSignature, Heartbeat, StreamStarted — no action.
            _ => {}
        }
    }
}

// ---------------------------------------------------------------------------
// Boarding settle — fully GUEST-driven (Plan A). The guest owns the ASP event stream + MuSig2
// tree-signing; the host only scans the boarding UTXO + relays the two FROST rounds. The open
// stream + session are held in `GuestState.boarding_settle` across the commitment-FROST pause.
// ---------------------------------------------------------------------------

fn sigs_from_wire(wire: Vec<Vec<u8>>) -> Result<Vec<[u8; 64]>, String> {
    wire.into_iter()
        .map(|v| <[u8; 64]>::try_from(v.as_slice()).map_err(|_| "signature must be 64 bytes".to_string()))
        .collect()
}

/// Step 1 (sync): build the boarding session + tree-signer from the host's (public) scan + ASP
/// info, store it in flight, and return the intent-proof sighashes to FROST-sign.
#[allow(clippy::too_many_arguments)]
fn boarding_settle_step1(
    owner_pk_hex: &str,
    signer_pubkey: &str,
    forfeit_pubkey: &str,
    boarding_address: &str,
    boarding_txid: &str,
    boarding_vout: u32,
    boarding_amount_sats: u64,
    exit_delay: u32,
    network: &str,
) -> GuestResponse {
    let secret = match STATE.with(|s| s.borrow().ark_cosigner_secret_hex().map(str::to_string)) {
        Some(x) => x,
        None => return GuestResponse::Error("no Ark cosigner secret installed".into()),
    };
    let signer = match ark::client::batch::BoardingTreeSigner::new(&secret) {
        Ok(s) => s,
        Err(e) => return GuestResponse::Error(e),
    };
    let cosigner_pk_hex = signer.cosigner_pubkey_hex();
    let (session, sighashes) = match ark::client::batch::SettleSession::new_boarding(
        owner_pk_hex,
        signer_pubkey,
        forfeit_pubkey,
        boarding_address,
        boarding_txid,
        boarding_vout,
        boarding_amount_sats,
        exit_delay,
        network,
        &cosigner_pk_hex,
    ) {
        Ok(v) => v,
        Err(e) => return GuestResponse::Error(format!("new_boarding: {e}")),
    };
    STATE.with(|s| {
        s.borrow_mut().set_boarding_settle(state::BoardingSettleInFlight {
            session,
            signer,
            stream: None,
            amount_sats: boarding_amount_sats,
        })
    });
    GuestResponse::BoardingSettleSighashes {
        messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
    }
}

/// Step 2 (async): insert the intent FROST sigs, RegisterIntent + open the event stream, drive the
/// batch (tree-signing in-guest) to BatchFinalization, return the commitment sighashes (pause).
async fn boarding_settle_step2(asp_url: &str, intent_sigs_wire: Vec<Vec<u8>>) -> GuestResponse {
    use ark::client::proto::{
        GetEventStreamRequest, Intent, RegisterIntentRequest, RegisterIntentResponse,
    };
    let intent_sigs = match sigs_from_wire(intent_sigs_wire) {
        Ok(s) => s,
        Err(e) => return GuestResponse::Error(e),
    };
    let mut inflight = match STATE.with(|s| s.borrow_mut().take_boarding_settle()) {
        Some(b) => b,
        None => return GuestResponse::Error("no boarding settle in flight".into()),
    };
    if let Err(e) = inflight.session.insert_intent_signatures(intent_sigs) {
        return GuestResponse::Error(e);
    }
    let (proof, message, topics) = match inflight.session.register_payload() {
        Ok(v) => v,
        Err(e) => return GuestResponse::Error(e),
    };
    let reg: RegisterIntentResponse = match grpc::unary(
        asp_url,
        "/ark.v1.ArkService/RegisterIntent",
        &RegisterIntentRequest {
            intent: Some(Intent { proof, message }),
        },
    )
    .await
    {
        Ok(r) => r,
        Err(e) => return GuestResponse::Error(format!("RegisterIntent: {e}")),
    };
    let intent_id = reg.intent_id;
    let mut stream = match grpc::ServerStream::open(
        asp_url,
        "/ark.v1.ArkService/GetEventStream",
        &GetEventStreamRequest { topics },
    )
    .await
    {
        Ok(s) => s,
        Err(e) => return GuestResponse::Error(format!("GetEventStream: {e}")),
    };
    match drive_boarding(
        &mut inflight.session,
        &mut inflight.signer,
        &mut stream,
        &intent_id,
        asp_url,
    )
    .await
    {
        Ok(sighashes) => {
            // Drop the event stream before returning: holding an open wasi:io stream resource across
            // the block_on teardown stalls the guest call from completing. Step3 finalizes
            // optimistically (no stream read), so the stream isn't needed past the pause.
            drop(stream);
            inflight.stream = None;
            STATE.with(|s| s.borrow_mut().set_boarding_settle(inflight));
            GuestResponse::BoardingSettleSighashes {
                messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
            }
        }
        Err(e) => GuestResponse::Error(e),
    }
}

/// Step 3 (async): insert the commitment FROST sigs, submit the signed commitment, and drive to
/// BatchFinalized — returning the new VTXO.
async fn boarding_settle_step3(asp_url: &str, commitment_sigs_wire: Vec<Vec<u8>>) -> GuestResponse {
    use ark::client::proto::{SubmitSignedForfeitTxsRequest, SubmitSignedForfeitTxsResponse};
    let commitment_sigs = match sigs_from_wire(commitment_sigs_wire) {
        Ok(s) => s,
        Err(e) => return GuestResponse::Error(e),
    };
    let mut inflight = match STATE.with(|s| s.borrow_mut().take_boarding_settle()) {
        Some(b) => b,
        None => return GuestResponse::Error("no boarding settle in flight".into()),
    };
    // Keep the event stream HELD (its open connection stops the ASP dropping us during the pause),
    // but we don't READ it again: finalize optimistically instead of resuming a mid-batch stream
    // across the commitment-FROST pause (which wstd's no-op-waker reactor can't reliably do).
    let _stream = inflight.stream.take();
    let signed_commitment_b64 = match inflight.session.insert_commitment_signatures(commitment_sigs) {
        Ok(v) => v,
        Err(e) => return GuestResponse::Error(e),
    };
    let _: SubmitSignedForfeitTxsResponse = match grpc::unary(
        asp_url,
        "/ark.v1.ArkService/SubmitSignedForfeitTxs",
        &SubmitSignedForfeitTxsRequest {
            signed_forfeit_txs: vec![],
            signed_commitment_tx: signed_commitment_b64,
        },
    )
    .await
    {
        Ok(r) => r,
        Err(e) => return GuestResponse::Error(format!("SubmitSignedForfeitTxs: {e}")),
    };
    let (commitment_txid, vtxo) = match inflight.session.finalize_optimistic() {
        Ok(v) => v,
        Err(e) => return GuestResponse::Error(e),
    };
    let (vtxo_txid, vtxo_vout) = vtxo.unwrap_or_else(|| (commitment_txid.clone(), 0));
    GuestResponse::BoardingSettleSubmitted {
        commitment_txid,
        vtxo_txid,
        vtxo_vout,
        amount_sats: inflight.amount_sats,
    }
}

/// Drive the boarding batch event stream: confirm, tree-sign (in-guest), and stop at either
/// BatchFinalization, returning the commitment-tx sighashes the client must FROST-sign (the pause).
/// Mirrors `settle_delegate` but uses the boarding `SettleSession` step methods + the in-guest
/// `BoardingTreeSigner`. The batch reaching BatchFinalized here (before the commitment FROST) is an
/// error — Step3 finalizes optimistically after submitting the signed commitment.
async fn drive_boarding(
    session: &mut ark::client::batch::SettleSession,
    signer: &mut ark::client::batch::BoardingTreeSigner,
    stream: &mut grpc::ServerStream,
    intent_id: &str,
    asp_url: &str,
) -> Result<Vec<[u8; 32]>, String> {
    use ark::client::batch::SettleAction;
    use ark::client::proto::{
        get_event_stream_response::Event, ConfirmRegistrationRequest, ConfirmRegistrationResponse,
        GetEventStreamResponse, SubmitTreeNoncesRequest, SubmitTreeNoncesResponse,
        SubmitTreeSignaturesRequest, SubmitTreeSignaturesResponse,
    };
    loop {
        let resp: GetEventStreamResponse = match stream.next().await {
            Ok(Some(r)) => r,
            Ok(None) => return Err("event stream ended unexpectedly".into()),
            Err(e) => return Err(format!("event stream: {e}")),
        };
        let Some(event) = resp.event else { continue };
        match event {
            Event::BatchStarted(e) => {
                session.on_batch_started(e)?;
                let _: ConfirmRegistrationResponse = grpc::unary(
                    asp_url,
                    "/ark.v1.ArkService/ConfirmRegistration",
                    &ConfirmRegistrationRequest {
                        intent_id: intent_id.to_string(),
                    },
                )
                .await
                .map_err(|e| format!("ConfirmRegistration: {e}"))?;
            }
            Event::TreeTx(e) => {
                session.handle_tree_tx(e)?;
            }
            Event::TreeSigningStarted(e) => {
                if let SettleAction::NeedTreeNonces {
                    tree_tx_chunks,
                    commitment_psbt_b64,
                } = session.on_tree_signing_started(e)?
                {
                    let (pubkey, nonce_map) =
                        signer.gen_nonces(&tree_tx_chunks, &commitment_psbt_b64)?;
                    let _: SubmitTreeNoncesResponse = grpc::unary(
                        asp_url,
                        "/ark.v1.ArkService/SubmitTreeNonces",
                        &SubmitTreeNoncesRequest {
                            batch_id: session.batch_id(),
                            pubkey,
                            tree_nonces: nonce_map.into_iter().collect(),
                        },
                    )
                    .await
                    .map_err(|e| format!("SubmitTreeNonces: {e}"))?;
                }
            }
            Event::TreeNonces(e) => {
                if let Some(SettleAction::NeedTreeSign {
                    pending_nonces,
                    batch_expiry,
                    forfeit_pk_hex,
                }) = session.on_tree_nonces(e)?
                {
                    let (pubkey, sig_map) =
                        signer.sign(&pending_nonces, batch_expiry, &forfeit_pk_hex)?;
                    let _: SubmitTreeSignaturesResponse = grpc::unary(
                        asp_url,
                        "/ark.v1.ArkService/SubmitTreeSignatures",
                        &SubmitTreeSignaturesRequest {
                            batch_id: session.batch_id(),
                            pubkey,
                            tree_signatures: sig_map.into_iter().collect(),
                        },
                    )
                    .await
                    .map_err(|e| format!("SubmitTreeSignatures: {e}"))?;
                }
            }
            Event::BatchFinalization(e) => {
                return session.handle_batch_finalization(e);
            }
            Event::BatchFinalized(_) => {
                return Err("batch finalized before commitment signing".into());
            }
            Event::BatchFailed(e) => {
                return Err(format!("batch failed: {}", e.reason));
            }
            _ => {}
        }
    }
}

/// SendVtxo phase 1: build the off-chain send tx (after a gRPC `GetInfo`) and return the
/// sighashes the client must FROST-sign. The keys + session live in the guest.
async fn send_vtxo_step1(req: SendVtxoStep1Wire) -> GuestResponse {
    if let Err(e) =
        state::auth_check(&req.user_id, &req.signature, req.timestamp_ms, state::OP_SEND_VTXO)
    {
        return GuestResponse::Error(e);
    }
    let (owner_pk_hex, vtxos) = match STATE.with(|s| {
        let st = s.borrow();
        st.owner_pk_hex().map(|owner| (owner, st.vtxos().to_vec()))
    }) {
        Ok(v) => v,
        Err(e) => return GuestResponse::Error(e),
    };
    let info = match grpc_get_info(&req.asp_url).await {
        Ok(i) => i,
        Err(e) => return GuestResponse::Error(e),
    };
    match state::build_send(&owner_pk_hex, &vtxos, &req, &info) {
        Ok((session, change_exit_delay, sighashes)) => {
            STATE.with(|s| s.borrow_mut().set_send_session(session, change_exit_delay));
            GuestResponse::SendVtxoSighashes {
                messages_to_sign: sighashes,
            }
        }
        Err(e) => GuestResponse::Error(format!("build send: {e}")),
    }
}

/// SendVtxo phase 2: insert the client's signatures, then submit + finalize via gRPC.
async fn send_vtxo_step2(req: SendVtxoStep2Wire) -> GuestResponse {
    use ark::client::proto::{FinalizeTxRequest, FinalizeTxResponse, SubmitTxRequest, SubmitTxResponse};

    if let Err(e) =
        state::auth_check(&req.user_id, &req.signature, req.timestamp_ms, state::OP_SEND_VTXO)
    {
        return GuestResponse::Error(e);
    }
    let signatures: Result<Vec<[u8; 64]>, String> = req
        .signed_messages
        .iter()
        .map(|m| {
            m.as_slice()
                .try_into()
                .map_err(|_| "signature must be 64 bytes".to_string())
        })
        .collect();
    let signatures = match signatures {
        Ok(s) => s,
        Err(e) => return GuestResponse::Error(e),
    };

    let (ark_b64, checkpoints) = match STATE.with(|s| s.borrow_mut().send_sign_and_prepare(signatures)) {
        Ok(x) => x,
        Err(e) => return GuestResponse::Error(format!("prepare submit: {e}")),
    };

    let submit: SubmitTxResponse = match grpc::unary(
        &req.asp_url,
        "/ark.v1.ArkService/SubmitTx",
        &SubmitTxRequest {
            signed_ark_tx: ark_b64,
            checkpoint_txs: checkpoints,
        },
    )
    .await
    {
        Ok(r) => r,
        Err(e) => return GuestResponse::Error(format!("SubmitTx: {e}")),
    };

    let final_checkpoints =
        match STATE.with(|s| s.borrow().send_finalize_checkpoints(&submit.signed_checkpoint_txs)) {
            Ok(c) => c,
            Err(e) => return GuestResponse::Error(format!("finalize checkpoints: {e}")),
        };

    let _: FinalizeTxResponse = match grpc::unary(
        &req.asp_url,
        "/ark.v1.ArkService/FinalizeTx",
        &FinalizeTxRequest {
            ark_txid: submit.ark_txid.clone(),
            final_checkpoint_txs: final_checkpoints,
        },
    )
    .await
    {
        Ok(r) => r,
        Err(e) => return GuestResponse::Error(format!("FinalizeTx: {e}")),
    };

    let change = STATE.with(|s| {
        let mut st = s.borrow_mut();
        let change = st.send_change_vtxo();
        st.send_done();
        // Guest is now the VTXO source of truth: spent all, re-add change.
        st.apply_send_change(change.clone());
        change
    });
    GuestResponse::SendVtxoSubmitted {
        ark_txid: submit.ark_txid,
        change,
    }
}

export!(Component);
