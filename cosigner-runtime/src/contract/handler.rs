//! Contract-create handler: a single key-preserving REFRESH of the wallet's normal key `V`
//! onto the always-online `{service, cosigner}` pairing. NO reshare, NO new key — contracts
//! reuse `V` and are bound by the cosigner GATE (WASM `evaluate` + verifying-share allowlist),
//! not by a distinct cryptographic key. The eVTXO cooperative leaf is scripted with `V`.
//!
//! The wallet signs contract spends with its existing normal `V` pairing (it falls through to
//! `normal_policy` at sign time); the always-online SERVICE co-signs with the `V` counter-share
//! produced by the refresh here. Owned and invoked by [`super::ContractManager`].

use tonic::Status;

use crate::contract;
use crate::cosigner::handlers::{contract_gate, parsers};
use crate::shared::SharedServices;
use crate::wallet_proto::{ContractCreateRequest, ContractCreateResponse};

/// Register a contract eVTXO under the gate (cooperative leaf = the wallet's key `V`). The
/// key-preserving REFRESH of `V` onto the `{receiver, cosigner}` pairing already ran inside the
/// guest (`route_contract_refresh`); `manager::create_contract` seeds the pairing actor + relays
/// the receiver's two ECIES half-shares. This step only stores/validates the wasm and registers
/// the eVTXO scriptPubKey.
pub fn contract_create(
    shared: &SharedServices,
    req: ContractCreateRequest,
) -> Result<ContractCreateResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] ContractCreate (V refreshed onto receiver IN-GUEST)");

    // --- the contract bytes + id. Phase 2: when `template_id` is set, COMPOSE the contract from a
    //     published template + the author's typed config (the composed sha256 is the bound id, so the
    //     variables are committed). Phase 1: a single supplied wasm whose sha256 == contract_id. ---
    let (contract_id, contract_wasm) = if !req.template_id.is_empty() {
        let template = contract::get_template_wasm(shared.persistence.as_ref(), &req.template_id)
            .ok_or_else(|| {
            Status::not_found(format!("unknown template_id {}", req.template_id))
        })?;
        let stub = contract::get_template_wasm(shared.persistence.as_ref(), &req.stub_id)
            .ok_or_else(|| Status::not_found(format!("unknown stub_id {}", req.stub_id)))?;
        let provider = contract::compose::synthesize_provider(&stub, &req.config_blob)
            .map_err(|e| Status::invalid_argument(format!("synthesize provider: {e}")))?;
        let composed = contract::compose::compose(&template, &provider)
            .map_err(|e| Status::invalid_argument(format!("compose contract: {e}")))?;
        let id = contract::sha256_id(&composed);
        (id, composed)
    } else {
        if req.contract_id.len() != 32 {
            return Err(Status::invalid_argument("contract_id must be 32 bytes"));
        }
        let mut id = [0u8; 32];
        id.copy_from_slice(&req.contract_id);
        if req.contract_wasm.is_empty() {
            return Err(Status::invalid_argument("contract_wasm is required"));
        }
        if contract::sha256_id(&req.contract_wasm) != id {
            return Err(Status::invalid_argument(
                "contract_wasm does not match contract_id (sha256 mismatch)",
            ));
        }
        (id, req.contract_wasm.clone())
    };
    // The bound contract (composed or supplied) must import ONLY `crypto` — the strict validator
    // proves the template's config import was satisfied internally by composition.
    if let Some(host) = shared.contract_host.as_ref() {
        host.validate(&contract_wasm)
            .map_err(|e| Status::invalid_argument(format!("invalid contract: {e}")))?;
    }
    shared
        .persistence
        .put(
            contract::CONTRACT_WASM_TREE,
            &hex::encode(contract_id),
            &hex::encode(&contract_wasm),
        )
        .map_err(|e| Status::internal(format!("store contract wasm: {e}")))?;

    // --- the wallet's existing key V is the cooperative-leaf key. The group key (cosigner_id) IS the
    //     compressed V; resolve it from the request id via `policy_owner_idx` — no `policies` read. ---
    let group_key =
        crate::cosigner::handlers::helpers::group_key_of(shared.persistence.as_ref(), &user_id_hex);
    let v_coop_xonly = xonly_from_vk(&group_key);

    if req.owner_pk.len() != 32 {
        return Err(Status::invalid_argument(
            "owner_pk must be a 32-byte x-only key",
        ));
    }
    let owner_pk_xonly = hex::encode(&req.owner_pk);
    let server_pk_xonly = hex::encode(&req.server_pk);

    // --- register the eVTXO under the gate (cooperative leaf = V) ---
    let spk = contract_gate::register_contract(
        shared.persistence.as_ref(),
        &server_pk_xonly,
        &v_coop_xonly,
        &owner_pk_xonly,
        req.exit_delay,
        &contract_id,
    )?;
    let spk_hex = hex::encode(&spk);

    // --- the ContractPolicy (gate metadata + authorized-receiver allowlist) is added to the wallet
    //     actor's SEALED state by `manager::create_contract` (CosignerCommand::AddContract), which
    //     also seeds the {receiver, cosigner} pairing ACTOR (keyed by the eVTXO spk) into its own
    //     guest and relays the receiver's two ECIES half-shares. The host persists nothing for the
    //     pairing — its key + conditioning params are eager-sealed into that actor's guest. ---
    let _ = &spk_hex;
    let _ = &group_key;

    tracing::info!(
        "[{user_id_hex}] ContractCreate complete (V reused; receiver pairing refreshed in-guest)"
    );
    Ok(ContractCreateResponse {
        contract_script_pubkey: spk.to_vec(),
        contract_id: contract_id.to_vec(),
    })
}

fn xonly_from_vk(vk_hex: &str) -> String {
    if vk_hex.len() == 66 {
        vk_hex[2..].to_string()
    } else {
        vk_hex.to_string()
    }
}
