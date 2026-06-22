//! Contract-create handler: a single key-preserving REFRESH of the wallet's normal key `V`
//! onto the always-online `{service, cosigner}` pairing. NO reshare, NO new key — contracts
//! reuse `V` and are bound by the cosigner GATE (WASM `evaluate` + verifying-share allowlist),
//! not by a distinct cryptographic key. The eVTXO cooperative leaf is scripted with `V`.
//!
//! The wallet signs contract spends with its existing normal `V` pairing (it falls through to
//! `normal_policy` at sign time); the always-online SERVICE co-signs with the `V` counter-share
//! produced by the refresh here. Owned and invoked by [`super::ContractManager`].

use std::collections::BTreeMap;

use rand::rngs::OsRng;
use tonic::Status;

use threshold::dkg;
use threshold::identifier::Identifier;
use threshold::keys::KeyPackage;

use crate::contract;
use crate::cosigner::handlers::{contract_gate, parsers};
use crate::policy::store::persist_policy;
use crate::policy::{ContractPolicy, CosignerShare, PolicyState};
use crate::shared::SharedServices;
use crate::wallet_proto::{ContractContext, ContractCreateRequest, ContractCreateResponse};

/// Register a contract under the gate and REFRESH the wallet's key `V` onto the
/// `{service, cosigner}` pairing (key unchanged) so the always-online service can co-sign.
/// Single round — the wallet has already computed its refresh slices locally and sends
/// `a@cosigner` (scalar) + `a@service·G` (point); `a@service` goes directly to the service.
pub fn contract_create(
    shared: &SharedServices,
    req: ContractCreateRequest,
) -> Result<ContractCreateResponse, Status> {
    let user_id_hex = parsers::user_id_hex(&req.user_id);
    tracing::info!("[{user_id_hex}] ContractCreate (refresh V onto service)");

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

    // --- the wallet's existing key V is the cooperative-leaf key (no V′) ---
    let policy = load_policy(shared, &user_id_hex)?;
    let cosigner_v_kp = KeyPackage::from_json(&policy.normal_policy.key_package_json)
        .map_err(|e| Status::internal(format!("normal kp: {e}")))?;
    let v_coop_xonly = xonly_from_vk(&parsers::extract_verifying_key(
        &policy.normal_policy.public_key_package_json,
    )?);

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

    // --- key-preserving REFRESH of V onto {service, cosigner} ---
    // The wallet (the only other current holder of V) dealt `a@cosigner` to us and the POINT
    // `a@service·G` for the service (we never see the scalar `a@service`, so we can't
    // reconstruct V). `refresh_to_receiver` mints our counter-share + the service's half.
    if req.service_vk.len() != 33 {
        return Err(Status::invalid_argument("service_vk must be 33 bytes"));
    }
    let service_vk = req.service_vk.clone();
    let service_vk_hex = hex::encode(&service_vk);
    let service_id = Identifier::derive(&service_vk)
        .map_err(|e| Status::internal(format!("derive service id: {e:?}")))?;
    let wallet_id = {
        let arr: [u8; 32] = req
            .identifier
            .as_slice()
            .try_into()
            .map_err(|_| Status::invalid_argument("identifier must be 32 bytes"))?;
        Identifier::deserialize(&arr).map_err(|e| Status::internal(format!("bad identifier: {e}")))?
    };
    let a_at_cosigner: [u8; 32] = req
        .a_at_cosigner
        .clone()
        .try_into()
        .map_err(|_| Status::invalid_argument("a_at_cosigner must be 32 bytes"))?;
    let a_at_service_point: [u8; 33] = req
        .a_at_service_point
        .clone()
        .try_into()
        .map_err(|_| Status::invalid_argument("a_at_service_point must be 33 bytes"))?;

    let mut id_partial_share = BTreeMap::new();
    id_partial_share.insert(wallet_id, a_at_cosigner);
    let receiver = dkg::Receiver {
        id: service_id,
        partial_verifying_share: a_at_service_point,
    };
    let pairing =
        dkg::refresh_to_receiver(&cosigner_v_kp, &receiver, &id_partial_share, 2, &mut OsRng)
            .map_err(|e| Status::internal(format!("refresh_to_receiver: {e:?}")))?;
    let pkp_b_json = pairing.pairing_pkp.to_json();

    // --- persist ContractPolicy: gate metadata + the service V counter-share ---
    let mut owner_pk = [0u8; 32];
    owner_pk.copy_from_slice(&req.owner_pk);
    let contract_policy = ContractPolicy {
        contract_id,
        wallet_vk: user_id_hex.clone(),
        exit_delay: req.exit_delay,
        owner_pk,
        shares: BTreeMap::from([(
            service_vk_hex,
            CosignerShare {
                key_package: pairing.my_kp,
                public_key_package: pairing.pairing_pkp.clone(),
            },
        )]),
    };
    let mut policy = load_policy(shared, &user_id_hex)?;
    policy.contracts.insert(spk_hex, contract_policy);
    persist_policy(shared, &user_id_hex, &policy)?;

    // --- service-delivery context (the wallet relays this to the always-online service) ---
    let context = ContractContext {
        contract_script_pubkey: spk.to_vec(),
        contract_id: contract_id.to_vec(),
        exit_delay: req.exit_delay,
        owner_pk: req.owner_pk.clone(),
        server_pk: req.server_pk.clone(),
        public_key_package_json: pkp_b_json,
        service_vk,
        cosigner_group_key: hex::decode(&policy.cosigner_id).unwrap_or_default(),
    };

    tracing::info!("[{user_id_hex}] ContractCreate complete (V reused; service pairing refreshed)");
    Ok(ContractCreateResponse {
        contract_script_pubkey: spk.to_vec(),
        b_at_service: pairing.receiver_half.to_vec(),
        context: Some(context),
    })
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn load_policy(shared: &SharedServices, user_id_hex: &str) -> Result<PolicyState, Status> {
    let json = match shared.persistence.get("policies", user_id_hex) {
        Ok(Some(j)) => j,
        _ => {
            let owner = shared
                .persistence
                .get("policy_owner_idx", user_id_hex)
                .ok()
                .flatten()
                .ok_or_else(|| Status::not_found("no policy for user"))?;
            shared
                .persistence
                .get("policies", &owner)
                .ok()
                .flatten()
                .ok_or_else(|| Status::not_found("no policy for user"))?
        }
    };
    serde_json::from_str(&json).map_err(|e| Status::internal(format!("parse policy: {e}")))
}

fn xonly_from_vk(vk_hex: &str) -> String {
    if vk_hex.len() == 66 {
        vk_hex[2..].to_string()
    } else {
        vk_hex.to_string()
    }
}
