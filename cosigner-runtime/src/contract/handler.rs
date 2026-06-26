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
use crate::wallet_proto::{ContractContext, ContractCreateRequest, ContractCreateResponse};

/// Register a contract under the gate and REFRESH the wallet's key `V` onto the
/// `{service, cosigner}` pairing (key unchanged) so the always-online service can co-sign.
/// Single round — the wallet has already computed its refresh slices locally and sends
/// `a@cosigner` (scalar) + `a@service·G` (point); `a@service` goes directly to the service.
pub fn contract_create(
    shared: &SharedServices,
    req: ContractCreateRequest,
    refresh: crate::cosigner::command::ContractRefreshOutput,
) -> Result<ContractCreateResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] ContractCreate (V refreshed onto service IN-GUEST)");

    // --- contract id / wasm: verify sha256(wasm) == contract_id, validate + store ---
    if req.contract_id.len() != 32 {
        return Err(Status::invalid_argument("contract_id must be 32 bytes"));
    }
    let mut contract_id = [0u8; 32];
    contract_id.copy_from_slice(&req.contract_id);
    if req.contract_wasm.is_empty() {
        return Err(Status::invalid_argument("contract_wasm is required"));
    }
    if contract::sha256_id(&req.contract_wasm) != contract_id {
        return Err(Status::invalid_argument(
            "contract_wasm does not match contract_id (sha256 mismatch)",
        ));
    }
    if let Some(host) = shared.contract_host.as_ref() {
        host.validate(&req.contract_wasm)
            .map_err(|e| Status::invalid_argument(format!("invalid contract: {e}")))?;
    }
    shared
        .persistence
        .put(
            contract::CONTRACT_WASM_TREE,
            &hex::encode(contract_id),
            &hex::encode(&req.contract_wasm),
        )
        .map_err(|e| Status::internal(format!("store contract wasm: {e}")))?;

    // --- the wallet's existing key V is the cooperative-leaf key. The group key (cosigner_id) IS the
    //     compressed V; resolve it from the request id via `policy_owner_idx` — no `policies` read. ---
    let group_key =
        crate::cosigner::handlers::helpers::group_key_of(shared.persistence.as_ref(), &user_id_hex);
    let v_coop_xonly = xonly_from_vk(&group_key);

    if req.owner_pk.len() != 32 {
        return Err(Status::invalid_argument("owner_pk must be a 32-byte x-only key"));
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

    // --- the key-preserving REFRESH of V onto {service, cosigner} already ran INSIDE the guest
    //     (see `route_contract_refresh`); `refresh` carries only PUBLIC material + the receiver's
    //     half + the cosigner's pairing key package as an OPAQUE JSON string (never parsed here). ---
    if req.service_vk.len() != 33 {
        return Err(Status::invalid_argument("service_vk must be 33 bytes"));
    }
    let service_vk = req.service_vk.clone();

    // --- the ContractPolicy (gate metadata + authorized-service allowlist) is added to the wallet
    //     actor's SEALED state by `manager::create_contract` (CosignerCommand::AddContract) — the
    //     actor is the single source of the projection; nothing goes to a host `policies` tree. ---
    let _ = &spk_hex;

    // --- the {service, cosigner} pairing ACTOR (Tier 2 service-driven co-sign) ---
    // A SEPARATE actor keyed by the eVTXO spk. Plan A 1C: the host persists NOTHING for it — its
    // pairing key AND its conditioning params (`contract_pairing`) are eager-sealed into the
    // actor's own guest by `manager::create_contract`, which is then the single source of truth.
    // The guest alone decides what the pairing may co-sign (a spend of this one eVTXO).

    // --- service-delivery context (the wallet relays this to the always-online service) ---
    let context = ContractContext {
        contract_script_pubkey: spk.to_vec(),
        contract_id: contract_id.to_vec(),
        exit_delay: req.exit_delay,
        owner_pk: req.owner_pk.clone(),
        server_pk: req.server_pk.clone(),
        public_key_package_json: refresh.pairing_public_key_package_json,
        service_vk,
        cosigner_group_key: hex::decode(&group_key).unwrap_or_default(),
    };

    tracing::info!("[{user_id_hex}] ContractCreate complete (V reused; service pairing refreshed in-guest)");
    Ok(ContractCreateResponse {
        contract_script_pubkey: spk.to_vec(),
        b_at_service: refresh.receiver_half,
        context: Some(context),
    })
}


fn xonly_from_vk(vk_hex: &str) -> String {
    if vk_hex.len() == 66 {
        vk_hex[2..].to_string()
    } else {
        vk_hex.to_string()
    }
}
