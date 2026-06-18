//! WASM-side session state resources.
//!
//! All user session data lives in WASM linear memory. The host holds only
//! opaque `ResourceAny` handles and async coordination primitives.

use std::cell::RefCell;
use std::collections::HashMap;

use threshold::nonce::SigningNonce;

use crate::exports::component::threshold::types::*;
use crate::{key_ops, signing_ops, util_ops};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn map_to_json_object(map: &HashMap<String, String>) -> String {
    let obj: serde_json::Map<String, serde_json::Value> = map
        .iter()
        .map(|(k, v)| (k.clone(), serde_json::Value::String(v.clone())))
        .collect();
    serde_json::Value::Object(obj).to_string()
}


// ---------------------------------------------------------------------------
// Session — ceremony state + the single-use nonce + the signing/key/identifier ops
// ---------------------------------------------------------------------------

pub struct SessionState {
    user_hiding_hex: RefCell<String>,
    user_binding_hex: RefCell<String>,
    message_to_sign_hex: RefCell<String>,
    server_commitments_json: RefCell<String>,
    commitment_list: RefCell<HashMap<String, String>>,
    shares: RefCell<HashMap<String, String>>,
    current_policy_id: RefCell<String>,
    pending_amount: RefCell<i64>,
    /// Single-use signing nonce for the in-progress round (set by `new_nonce`,
    /// consumed by `frost_sign`).
    nonce: RefCell<Option<SigningNonce>>,
}

impl GuestSession for SessionState {
    fn new() -> Self {
        Self {
            user_hiding_hex: RefCell::new(String::new()),
            user_binding_hex: RefCell::new(String::new()),
            message_to_sign_hex: RefCell::new(String::new()),
            server_commitments_json: RefCell::new(String::new()),
            commitment_list: RefCell::new(HashMap::new()),
            shares: RefCell::new(HashMap::new()),
            current_policy_id: RefCell::new(String::new()),
            pending_amount: RefCell::new(0),
            nonce: RefCell::new(None),
        }
    }

    fn reset(&self) {
        *self.user_hiding_hex.borrow_mut() = String::new();
        *self.user_binding_hex.borrow_mut() = String::new();
        *self.message_to_sign_hex.borrow_mut() = String::new();
        *self.server_commitments_json.borrow_mut() = String::new();
        self.commitment_list.borrow_mut().clear();
        self.shares.borrow_mut().clear();
        *self.current_policy_id.borrow_mut() = String::new();
        *self.pending_amount.borrow_mut() = 0;
        *self.nonce.borrow_mut() = None;
    }

    fn set_user_hiding_hex(&self, hex: String) {
        *self.user_hiding_hex.borrow_mut() = hex;
    }

    fn get_user_hiding_hex(&self) -> String {
        self.user_hiding_hex.borrow().clone()
    }

    fn set_user_binding_hex(&self, hex: String) {
        *self.user_binding_hex.borrow_mut() = hex;
    }

    fn get_user_binding_hex(&self) -> String {
        self.user_binding_hex.borrow().clone()
    }

    fn set_message_to_sign(&self, msg_hex: String) {
        *self.message_to_sign_hex.borrow_mut() = msg_hex;
    }

    fn get_message_to_sign(&self) -> String {
        self.message_to_sign_hex.borrow().clone()
    }

    fn has_message(&self) -> bool {
        !self.message_to_sign_hex.borrow().is_empty()
    }

    fn set_server_commitments_json(&self, json: String) {
        *self.server_commitments_json.borrow_mut() = json;
    }

    fn get_server_commitments_json(&self) -> String {
        self.server_commitments_json.borrow().clone()
    }

    fn has_server_commitments(&self) -> bool {
        !self.server_commitments_json.borrow().is_empty()
    }

    fn insert_commitment(&self, id_hex: String, commitments_json: String) {
        self.commitment_list
            .borrow_mut()
            .insert(id_hex, commitments_json);
    }

    fn get_commitments_json(&self) -> String {
        map_to_json_object(&self.commitment_list.borrow())
    }

    fn insert_share(&self, id_hex: String, share_hex: String) {
        self.shares.borrow_mut().insert(id_hex, share_hex);
    }

    fn has_share(&self, id_hex: String) -> bool {
        self.shares.borrow().contains_key(&id_hex)
    }

    fn share_count(&self) -> u32 {
        self.shares.borrow().len() as u32
    }

    fn get_shares_json(&self) -> String {
        map_to_json_object(&self.shares.borrow())
    }

    fn set_current_policy_id(&self, id: String) {
        *self.current_policy_id.borrow_mut() = id;
    }

    fn get_current_policy_id(&self) -> String {
        self.current_policy_id.borrow().clone()
    }

    fn set_pending_amount(&self, amount: i64) {
        *self.pending_amount.borrow_mut() = amount;
    }

    fn get_pending_amount(&self) -> i64 {
        *self.pending_amount.borrow()
    }

    // ----- signing ops (nonce held in this session) -----

    fn new_nonce(&self, secret_hex: String) -> Result<String, ThresholdError> {
        let (commitments_json, nonce) = signing_ops::new_nonce(secret_hex)?;
        *self.nonce.borrow_mut() = Some(nonce);
        Ok(commitments_json)
    }

    fn frost_sign(
        &self,
        signing_package_json: String,
        key_package_json: String,
    ) -> Result<String, ThresholdError> {
        let nonce = self
            .nonce
            .borrow_mut()
            .take()
            .ok_or_else(|| ThresholdError::InvalidInput("no signing nonce; call new-nonce first".into()))?;
        signing_ops::frost_sign(signing_package_json, &nonce, key_package_json)
    }

    fn frost_aggregate(
        &self,
        signing_package_json: String,
        shares_json: String,
        public_key_package_json: String,
    ) -> Result<String, ThresholdError> {
        signing_ops::frost_aggregate(signing_package_json, shares_json, public_key_package_json)
    }

    // ----- key / identifier ops -----

    fn key_package_tweak(
        &self,
        kp_json: String,
        merkle_root: Option<Vec<u8>>,
    ) -> Result<String, ThresholdError> {
        key_ops::key_package_tweak(kp_json, merkle_root)
    }

    fn pub_key_package_tweak(
        &self,
        pkp_json: String,
        merkle_root: Option<Vec<u8>>,
    ) -> Result<String, ThresholdError> {
        key_ops::pub_key_package_tweak(pkp_json, merkle_root)
    }

    fn identifier_derive(&self, message: Vec<u8>) -> Result<String, ThresholdError> {
        util_ops::identifier_derive(message)
    }

    fn verify_schnorr_signature(
        &self,
        pk_hex: String,
        message: Vec<u8>,
        sig_hex: String,
    ) -> Result<bool, ThresholdError> {
        crate::auth_ops::verify_schnorr_signature(pk_hex, message, sig_hex)
    }
}

