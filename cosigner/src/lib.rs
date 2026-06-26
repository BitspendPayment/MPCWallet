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
