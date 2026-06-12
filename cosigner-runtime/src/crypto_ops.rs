//! Threshold crypto operations via WASM.
//! Refactored from `grpc_service.rs` into plain functions (no gRPC trait).
//! Each function takes a `&mut CosignerInstance` and performs WASM dispatch.

use crate::cosigner::cosigner::CosignerInstance;
use crate::cosigner::cosigner::exports::component::threshold::types::ThresholdError;
use wasmtime::component::ResourceAny;

/// Convert a WASM threshold error into a string.
pub fn threshold_err_to_string(e: &ThresholdError) -> String {
    match e {
        ThresholdError::InvalidInput(msg) => format!("invalid input: {msg}"),
        ThresholdError::CryptoError(msg) => format!("crypto error: {msg}"),
        ThresholdError::SerializationError(msg) => format!("serialization error: {msg}"),
    }
}

// ---------------------------------------------------------------------------
// DKG
// ---------------------------------------------------------------------------

pub struct DkgPart1Result {
    pub round1_package_json: String,
    pub secret_handle: ResourceAny,
}

pub fn dkg_part1(
    user: &mut CosignerInstance,
    max_signers: u32,
    min_signers: u32,
    secret_hex: &str,
    coefficients_json: &str,
) -> Result<DkgPart1Result, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    let result = iface
        .threshold_session()
        .call_dkg_part1(
            &mut user.store,
            session,
            max_signers,
            min_signers,
            secret_hex,
            coefficients_json,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))?;

    Ok(DkgPart1Result {
        round1_package_json: result.round1_package_json,
        secret_handle: result.secret,
    })
}

pub struct DkgPart2Result {
    pub round2_packages_json: String,
    pub secret_handle: ResourceAny,
}

pub fn dkg_part2(
    user: &mut CosignerInstance,
    round1_secret: ResourceAny,
    round1_packages_json: &str,
    receiver_ids_json: &str,
) -> Result<DkgPart2Result, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    let result = iface
        .threshold_session()
        .call_dkg_part2(
            &mut user.store,
            session,
            round1_secret,
            round1_packages_json,
            receiver_ids_json,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))?;

    Ok(DkgPart2Result {
        round2_packages_json: result.round2_packages_json,
        secret_handle: result.secret,
    })
}

pub struct DkgPart3Result {
    pub key_package_json: String,
    pub public_key_package_json: String,
}

pub fn dkg_part3(
    user: &mut CosignerInstance,
    round2_secret: ResourceAny,
    round1_packages_json: &str,
    round2_packages_json: &str,
    receiver_ids_json: &str,
) -> Result<DkgPart3Result, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    let result = iface
        .threshold_session()
        .call_dkg_part3(
            &mut user.store,
            session,
            round2_secret,
            round1_packages_json,
            round2_packages_json,
            receiver_ids_json,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))?;

    Ok(DkgPart3Result {
        key_package_json: result.key_package_json,
        public_key_package_json: result.public_key_package_json,
    })
}

// ---------------------------------------------------------------------------
// Key Refresh
// ---------------------------------------------------------------------------

pub struct RefreshPart1Result {
    pub round1_package_json: String,
    pub secret_handle: ResourceAny,
}

pub fn dkg_refresh_part1(
    user: &mut CosignerInstance,
    id_hex: &str,
    max_signers: u32,
    min_signers: u32,
    seed: &[u8],
) -> Result<RefreshPart1Result, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    let result = iface
        .threshold_session()
        .call_dkg_refresh_part1(
            &mut user.store,
            session,
            id_hex,
            max_signers,
            min_signers,
            seed,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))?;

    Ok(RefreshPart1Result {
        round1_package_json: result.round1_package_json,
        secret_handle: result.secret,
    })
}

pub fn dkg_refresh_part2(
    user: &mut CosignerInstance,
    round1_secret: ResourceAny,
    round1_packages_json: &str,
) -> Result<DkgPart2Result, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    let result = iface
        .threshold_session()
        .call_dkg_refresh_part2(
            &mut user.store,
            session,
            round1_secret,
            round1_packages_json,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))?;

    Ok(DkgPart2Result {
        round2_packages_json: result.round2_packages_json,
        secret_handle: result.secret,
    })
}

pub fn dkg_refresh_part3(
    user: &mut CosignerInstance,
    round2_secret: ResourceAny,
    round1_packages_json: &str,
    round2_packages_json: &str,
    old_pkp_json: &str,
    old_kp_json: &str,
) -> Result<DkgPart3Result, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    let result = iface
        .threshold_session()
        .call_dkg_refresh_part3(
            &mut user.store,
            session,
            round2_secret,
            round1_packages_json,
            round2_packages_json,
            old_pkp_json,
            old_kp_json,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))?;

    Ok(DkgPart3Result {
        key_package_json: result.key_package_json,
        public_key_package_json: result.public_key_package_json,
    })
}

// ---------------------------------------------------------------------------
// Signing
// ---------------------------------------------------------------------------

pub struct NewNonceResult {
    pub commitments_json: String,
    pub nonce_handle: ResourceAny,
}

pub fn new_nonce(user: &mut CosignerInstance, secret_hex: &str) -> Result<NewNonceResult, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    let result = iface
        .threshold_session()
        .call_new_nonce(&mut user.store, session, secret_hex)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))?;

    Ok(NewNonceResult {
        commitments_json: result.commitments_json,
        nonce_handle: result.nonce,
    })
}

pub fn frost_sign(
    user: &mut CosignerInstance,
    signing_package_json: &str,
    nonce: ResourceAny,
    key_package_json: &str,
) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_frost_sign(
            &mut user.store,
            session,
            signing_package_json,
            nonce,
            key_package_json,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

pub fn frost_aggregate(
    user: &mut CosignerInstance,
    signing_package_json: &str,
    shares_json: &str,
    public_key_package_json: &str,
) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_frost_aggregate(
            &mut user.store,
            session,
            signing_package_json,
            shares_json,
            public_key_package_json,
        )
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

// ---------------------------------------------------------------------------
// Key Operations
// ---------------------------------------------------------------------------

pub fn key_package_tweak(
    user: &mut CosignerInstance,
    kp_json: &str,
    merkle_root: Option<&[u8]>,
) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_key_package_tweak(&mut user.store, session, kp_json, merkle_root)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

pub fn pub_key_package_tweak(
    user: &mut CosignerInstance,
    pkp_json: &str,
    merkle_root: Option<&[u8]>,
) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_pub_key_package_tweak(&mut user.store, session, pkp_json, merkle_root)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

// ---------------------------------------------------------------------------
// Utils
// ---------------------------------------------------------------------------

pub fn mod_n_random(user: &mut CosignerInstance) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_mod_n_random(&mut user.store, session)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

pub fn identifier_derive(user: &mut CosignerInstance, message: &[u8]) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_identifier_derive(&mut user.store, session, message)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

pub fn generate_coefficients(
    user: &mut CosignerInstance,
    count: u32,
    seed: &[u8],
) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_generate_coefficients(&mut user.store, session, count, seed)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

pub fn elem_base_mul(user: &mut CosignerInstance, scalar_hex: &str) -> Result<String, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_elem_base_mul(&mut user.store, session, scalar_hex)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

pub fn verify_schnorr_signature(
    user: &mut CosignerInstance,
    pk_hex: &str,
    message: &[u8],
    sig_hex: &str,
) -> Result<bool, String> {
    let session = user.session.ok_or("no session")?;
    let iface = user.bindings.component_threshold_types();

    iface
        .threshold_session()
        .call_verify_schnorr_signature(&mut user.store, session, pk_hex, message, sig_hex)
        .map_err(|e| e.to_string())?
        .map_err(|e| threshold_err_to_string(&e))
}

// ---------------------------------------------------------------------------
// DKG Session resource
// ---------------------------------------------------------------------------

pub fn dkg_session_create(user: &mut CosignerInstance) -> Result<ResourceAny, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_constructor(&mut user.store)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_reset(user: &mut CosignerInstance, h: ResourceAny) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_reset(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_insert_round1_package(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str, pkg_json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_insert_round1_package(&mut user.store, h, id_hex, pkg_json)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_insert_receiver_identifier(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_insert_receiver_identifier(&mut user.store, h, id_hex)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_total_participants(user: &mut CosignerInstance, h: ResourceAny) -> Result<u32, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_total_participants(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_is_receiver(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str) -> Result<bool, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_is_receiver(&mut user.store, h, id_hex)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_get_round1_packages_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_get_round1_packages_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_get_round1_packages_excluding_json(user: &mut CosignerInstance, h: ResourceAny, exclude_id: &str) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_get_round1_packages_excluding_json(&mut user.store, h, exclude_id)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_get_receiver_ids_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_get_receiver_ids_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_set_server_id(user: &mut CosignerInstance, h: ResourceAny, server_id_hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_set_server_id(&mut user.store, h, server_id_hex)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_get_server_id(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_get_server_id(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_set_server_internal_secret_hex(user: &mut CosignerInstance, h: ResourceAny, secret_hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_set_server_internal_secret_hex(&mut user.store, h, secret_hex)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_get_server_internal_secret_hex(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_get_server_internal_secret_hex(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_insert_round2_received(user: &mut CosignerInstance, h: ResourceAny, sender_id: &str, pkg_json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_insert_round2_received(&mut user.store, h, sender_id, pkg_json)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_get_round2_received_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_get_round2_received_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_set_round2_local_json(user: &mut CosignerInstance, h: ResourceAny, json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_set_round2_local_json(&mut user.store, h, json)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_is_round2_local_empty(user: &mut CosignerInstance, h: ResourceAny) -> Result<bool, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_is_round2_local_empty(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_insert_relay_packages(user: &mut CosignerInstance, h: ResourceAny, sender_id: &str, packages_json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_insert_relay_packages(&mut user.store, h, sender_id, packages_json)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_insert_relay_from_local(user: &mut CosignerInstance, h: ResourceAny, server_id: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_insert_relay_from_local(&mut user.store, h, server_id)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_relay_sender_count(user: &mut CosignerInstance, h: ResourceAny) -> Result<u32, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_relay_sender_count(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn dkg_session_get_relay_packages_for(user: &mut CosignerInstance, h: ResourceAny, recipient_id: &str) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.dkg_session().call_get_relay_packages_for(&mut user.store, h, recipient_id)
        .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Signing Session resource
// ---------------------------------------------------------------------------

pub fn signing_session_create(user: &mut CosignerInstance) -> Result<ResourceAny, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_constructor(&mut user.store)
        .map_err(|e| e.to_string())
}

pub fn signing_session_reset(user: &mut CosignerInstance, h: ResourceAny) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_reset(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_set_user_hiding_hex(user: &mut CosignerInstance, h: ResourceAny, hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_set_user_hiding_hex(&mut user.store, h, hex)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_user_hiding_hex(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_user_hiding_hex(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_set_user_binding_hex(user: &mut CosignerInstance, h: ResourceAny, hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_set_user_binding_hex(&mut user.store, h, hex)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_user_binding_hex(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_user_binding_hex(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_set_message_to_sign(user: &mut CosignerInstance, h: ResourceAny, msg_hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_set_message_to_sign(&mut user.store, h, msg_hex)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_message_to_sign(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_message_to_sign(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_has_message(user: &mut CosignerInstance, h: ResourceAny) -> Result<bool, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_has_message(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_set_server_commitments_json(user: &mut CosignerInstance, h: ResourceAny, json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_set_server_commitments_json(&mut user.store, h, json)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_server_commitments_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_server_commitments_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_has_server_commitments(user: &mut CosignerInstance, h: ResourceAny) -> Result<bool, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_has_server_commitments(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_insert_commitment(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str, commitments_json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_insert_commitment(&mut user.store, h, id_hex, commitments_json)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_commitments_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_commitments_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_insert_share(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str, share_hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_insert_share(&mut user.store, h, id_hex, share_hex)
        .map_err(|e| e.to_string())
}

pub fn signing_session_has_share(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str) -> Result<bool, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_has_share(&mut user.store, h, id_hex)
        .map_err(|e| e.to_string())
}

pub fn signing_session_share_count(user: &mut CosignerInstance, h: ResourceAny) -> Result<u32, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_share_count(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_shares_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_shares_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_set_current_policy_id(user: &mut CosignerInstance, h: ResourceAny, id: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_set_current_policy_id(&mut user.store, h, id)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_current_policy_id(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_current_policy_id(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn signing_session_set_pending_amount(user: &mut CosignerInstance, h: ResourceAny, amount: i64) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_set_pending_amount(&mut user.store, h, amount)
        .map_err(|e| e.to_string())
}

pub fn signing_session_get_pending_amount(user: &mut CosignerInstance, h: ResourceAny) -> Result<i64, String> {
    let iface = user.bindings.component_threshold_types();
    iface.signing_session().call_get_pending_amount(&mut user.store, h)
        .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Refresh Session resource
// ---------------------------------------------------------------------------

pub fn refresh_session_create(user: &mut CosignerInstance) -> Result<ResourceAny, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_constructor(&mut user.store)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_reset(user: &mut CosignerInstance, h: ResourceAny) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_reset(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_insert_round1_package(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str, pkg_json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_insert_round1_package(&mut user.store, h, id_hex, pkg_json)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_round1_count(user: &mut CosignerInstance, h: ResourceAny) -> Result<u32, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_round1_count(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_round1_packages_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_round1_packages_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_round1_packages_excluding_json(user: &mut CosignerInstance, h: ResourceAny, exclude_id: &str) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_round1_packages_excluding_json(&mut user.store, h, exclude_id)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_set_server_id(user: &mut CosignerInstance, h: ResourceAny, server_id_hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_set_server_id(&mut user.store, h, server_id_hex)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_set_server_identifier_hex(user: &mut CosignerInstance, h: ResourceAny, id_hex: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_set_server_identifier_hex(&mut user.store, h, id_hex)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_server_identifier_hex(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_server_identifier_hex(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_insert_round2_received(user: &mut CosignerInstance, h: ResourceAny, sender_id: &str, pkg_json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_insert_round2_received(&mut user.store, h, sender_id, pkg_json)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_round2_received_json(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_round2_received_json(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_set_round2_local_json(user: &mut CosignerInstance, h: ResourceAny, json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_set_round2_local_json(&mut user.store, h, json)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_is_round2_local_empty(user: &mut CosignerInstance, h: ResourceAny) -> Result<bool, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_is_round2_local_empty(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_insert_relay_packages(user: &mut CosignerInstance, h: ResourceAny, sender_id: &str, packages_json: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_insert_relay_packages(&mut user.store, h, sender_id, packages_json)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_insert_relay_from_local(user: &mut CosignerInstance, h: ResourceAny, server_id: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_insert_relay_from_local(&mut user.store, h, server_id)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_relay_sender_count(user: &mut CosignerInstance, h: ResourceAny) -> Result<u32, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_relay_sender_count(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_relay_packages_for(user: &mut CosignerInstance, h: ResourceAny, recipient_id: &str) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_relay_packages_for(&mut user.store, h, recipient_id)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_set_refresh_creation_time_ms(user: &mut CosignerInstance, h: ResourceAny, ms: i64) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_set_refresh_creation_time_ms(&mut user.store, h, ms)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_refresh_creation_time_ms(user: &mut CosignerInstance, h: ResourceAny) -> Result<i64, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_refresh_creation_time_ms(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_set_refresh_id(user: &mut CosignerInstance, h: ResourceAny, id: &str) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_set_refresh_id(&mut user.store, h, id)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_refresh_id(user: &mut CosignerInstance, h: ResourceAny) -> Result<String, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_refresh_id(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_set_refresh_threshold_amount(user: &mut CosignerInstance, h: ResourceAny, amount: i64) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_set_refresh_threshold_amount(&mut user.store, h, amount)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_refresh_threshold_amount(user: &mut CosignerInstance, h: ResourceAny) -> Result<i64, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_refresh_threshold_amount(&mut user.store, h)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_set_refresh_interval(user: &mut CosignerInstance, h: ResourceAny, interval: i64) -> Result<(), String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_set_refresh_interval(&mut user.store, h, interval)
        .map_err(|e| e.to_string())
}

pub fn refresh_session_get_refresh_interval(user: &mut CosignerInstance, h: ResourceAny) -> Result<i64, String> {
    let iface = user.bindings.component_threshold_types();
    iface.refresh_session().call_get_refresh_interval(&mut user.store, h)
        .map_err(|e| e.to_string())
}
