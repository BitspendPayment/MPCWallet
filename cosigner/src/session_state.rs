//! WASM-side session state resources.
//!
//! All user session data lives in WASM linear memory. The host holds only
//! opaque `ResourceAny` handles and async coordination primitives.

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};

use crate::exports::component::threshold::types::*;

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

fn map_to_parsed_json_object(map: &HashMap<String, String>) -> String {
    let mut obj = serde_json::Map::new();
    for (k, v) in map {
        match serde_json::from_str::<serde_json::Value>(v) {
            Ok(val) => {
                obj.insert(k.clone(), val);
            }
            Err(_) => {
                obj.insert(k.clone(), serde_json::Value::String(v.clone()));
            }
        }
    }
    serde_json::Value::Object(obj).to_string()
}

fn set_to_json_array(set: &HashSet<String>) -> String {
    let arr: Vec<serde_json::Value> = set
        .iter()
        .map(|s| serde_json::Value::String(s.clone()))
        .collect();
    serde_json::Value::Array(arr).to_string()
}

fn json_to_map(json: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(json) {
        if let Some(obj) = v.as_object() {
            for (k, v) in obj {
                let s = if let Some(s) = v.as_str() {
                    s.to_string()
                } else {
                    v.to_string()
                };
                map.insert(k.clone(), s);
            }
        }
    }
    map
}

// ---------------------------------------------------------------------------
// DKG Session
// ---------------------------------------------------------------------------

pub struct DkgSessionState {
    round1_packages: RefCell<HashMap<String, String>>,
    receiver_identifiers: RefCell<HashSet<String>>,
    server_id_hex: RefCell<String>,
    server_internal_secret_hex: RefCell<String>,
    round2_received: RefCell<HashMap<String, String>>,
    round2_local: RefCell<HashMap<String, String>>,
    // sender_id -> { recipient_id -> pkg_json }
    round2_relay: RefCell<HashMap<String, HashMap<String, String>>>,
}

impl GuestDkgSession for DkgSessionState {
    fn new() -> Self {
        Self {
            round1_packages: RefCell::new(HashMap::new()),
            receiver_identifiers: RefCell::new(HashSet::new()),
            server_id_hex: RefCell::new(String::new()),
            server_internal_secret_hex: RefCell::new(String::new()),
            round2_received: RefCell::new(HashMap::new()),
            round2_local: RefCell::new(HashMap::new()),
            round2_relay: RefCell::new(HashMap::new()),
        }
    }

    fn reset(&self) {
        self.round1_packages.borrow_mut().clear();
        self.receiver_identifiers.borrow_mut().clear();
        *self.server_id_hex.borrow_mut() = String::new();
        *self.server_internal_secret_hex.borrow_mut() = String::new();
        self.round2_received.borrow_mut().clear();
        self.round2_local.borrow_mut().clear();
        self.round2_relay.borrow_mut().clear();
    }

    fn insert_round1_package(&self, id_hex: String, pkg_json: String) {
        self.round1_packages
            .borrow_mut()
            .insert(id_hex, pkg_json);
    }

    fn insert_receiver_identifier(&self, id_hex: String) {
        self.receiver_identifiers.borrow_mut().insert(id_hex);
    }

    fn total_participants(&self) -> u32 {
        (self.round1_packages.borrow().len() + self.receiver_identifiers.borrow().len()) as u32
    }

    fn is_receiver(&self, id_hex: String) -> bool {
        self.receiver_identifiers.borrow().contains(&id_hex)
    }

    fn get_round1_packages_json(&self) -> String {
        map_to_json_object(&self.round1_packages.borrow())
    }

    fn get_round1_packages_excluding_json(&self, exclude_id_hex: String) -> String {
        let pkgs = self.round1_packages.borrow();
        let mut obj = serde_json::Map::new();
        for (id, pkg_str) in pkgs.iter() {
            if id != &exclude_id_hex {
                match serde_json::from_str::<serde_json::Value>(pkg_str) {
                    Ok(val) => {
                        obj.insert(id.clone(), val);
                    }
                    Err(_) => {
                        obj.insert(id.clone(), serde_json::Value::String(pkg_str.clone()));
                    }
                }
            }
        }
        serde_json::Value::Object(obj).to_string()
    }

    fn get_receiver_ids_json(&self) -> String {
        set_to_json_array(&self.receiver_identifiers.borrow())
    }

    fn set_server_id(&self, server_id_hex: String) {
        *self.server_id_hex.borrow_mut() = server_id_hex;
    }

    fn get_server_id(&self) -> String {
        self.server_id_hex.borrow().clone()
    }

    fn set_server_internal_secret_hex(&self, secret_hex: String) {
        *self.server_internal_secret_hex.borrow_mut() = secret_hex;
    }

    fn get_server_internal_secret_hex(&self) -> String {
        self.server_internal_secret_hex.borrow().clone()
    }

    fn insert_round2_received(&self, sender_id_hex: String, pkg_json: String) {
        self.round2_received
            .borrow_mut()
            .insert(sender_id_hex, pkg_json);
    }

    fn get_round2_received_json(&self) -> String {
        map_to_parsed_json_object(&self.round2_received.borrow())
    }

    fn set_round2_local_json(&self, json: String) {
        *self.round2_local.borrow_mut() = json_to_map(&json);
    }

    fn get_round2_local_json(&self) -> String {
        map_to_json_object(&self.round2_local.borrow())
    }

    fn is_round2_local_empty(&self) -> bool {
        self.round2_local.borrow().is_empty()
    }

    fn insert_relay_packages(&self, sender_id_hex: String, packages_json: String) {
        let pkgs = json_to_map(&packages_json);
        self.round2_relay
            .borrow_mut()
            .insert(sender_id_hex, pkgs);
    }

    fn insert_relay_from_local(&self, server_id_hex: String) {
        let local = self.round2_local.borrow().clone();
        self.round2_relay
            .borrow_mut()
            .insert(server_id_hex, local);
    }

    fn relay_sender_count(&self) -> u32 {
        self.round2_relay.borrow().len() as u32
    }

    fn get_relay_packages_for(&self, recipient_id_hex: String) -> String {
        let relay = self.round2_relay.borrow();
        let mut obj = serde_json::Map::new();
        for (sender, sender_pkgs) in relay.iter() {
            if let Some(pkg) = sender_pkgs.get(&recipient_id_hex) {
                obj.insert(sender.clone(), serde_json::Value::String(pkg.clone()));
            }
        }
        serde_json::Value::Object(obj).to_string()
    }
}

// ---------------------------------------------------------------------------
// Signing Session
// ---------------------------------------------------------------------------

pub struct SigningSessionState {
    user_hiding_hex: RefCell<String>,
    user_binding_hex: RefCell<String>,
    message_to_sign_hex: RefCell<String>,
    server_commitments_json: RefCell<String>,
    commitment_list: RefCell<HashMap<String, String>>,
    shares: RefCell<HashMap<String, String>>,
    current_policy_id: RefCell<String>,
    pending_amount: RefCell<i64>,
}

impl GuestSigningSession for SigningSessionState {
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
}

// ---------------------------------------------------------------------------
// Refresh Session
// ---------------------------------------------------------------------------

pub struct RefreshSessionState {
    round1_packages: RefCell<HashMap<String, String>>,
    server_id_hex: RefCell<String>,
    server_identifier_hex: RefCell<String>,
    round2_received: RefCell<HashMap<String, String>>,
    round2_local: RefCell<HashMap<String, String>>,
    round2_relay: RefCell<HashMap<String, HashMap<String, String>>>,
    refresh_creation_time_ms: RefCell<i64>,
    refresh_id: RefCell<String>,
    refresh_threshold_amount: RefCell<i64>,
    refresh_interval: RefCell<i64>,
}

impl GuestRefreshSession for RefreshSessionState {
    fn new() -> Self {
        Self {
            round1_packages: RefCell::new(HashMap::new()),
            server_id_hex: RefCell::new(String::new()),
            server_identifier_hex: RefCell::new(String::new()),
            round2_received: RefCell::new(HashMap::new()),
            round2_local: RefCell::new(HashMap::new()),
            round2_relay: RefCell::new(HashMap::new()),
            refresh_creation_time_ms: RefCell::new(0),
            refresh_id: RefCell::new(String::new()),
            refresh_threshold_amount: RefCell::new(0),
            refresh_interval: RefCell::new(0),
        }
    }

    fn reset(&self) {
        self.round1_packages.borrow_mut().clear();
        *self.server_id_hex.borrow_mut() = String::new();
        *self.server_identifier_hex.borrow_mut() = String::new();
        self.round2_received.borrow_mut().clear();
        self.round2_local.borrow_mut().clear();
        self.round2_relay.borrow_mut().clear();
        *self.refresh_creation_time_ms.borrow_mut() = 0;
        *self.refresh_id.borrow_mut() = String::new();
        *self.refresh_threshold_amount.borrow_mut() = 0;
        *self.refresh_interval.borrow_mut() = 0;
    }

    fn insert_round1_package(&self, id_hex: String, pkg_json: String) {
        self.round1_packages
            .borrow_mut()
            .insert(id_hex, pkg_json);
    }

    fn round1_count(&self) -> u32 {
        self.round1_packages.borrow().len() as u32
    }

    fn get_round1_packages_json(&self) -> String {
        map_to_json_object(&self.round1_packages.borrow())
    }

    fn get_round1_packages_excluding_json(&self, exclude_id_hex: String) -> String {
        let pkgs = self.round1_packages.borrow();
        let mut obj = serde_json::Map::new();
        for (id, pkg_str) in pkgs.iter() {
            if id != &exclude_id_hex {
                match serde_json::from_str::<serde_json::Value>(pkg_str) {
                    Ok(val) => {
                        obj.insert(id.clone(), val);
                    }
                    Err(_) => {
                        obj.insert(id.clone(), serde_json::Value::String(pkg_str.clone()));
                    }
                }
            }
        }
        serde_json::Value::Object(obj).to_string()
    }

    fn set_server_id(&self, server_id_hex: String) {
        *self.server_id_hex.borrow_mut() = server_id_hex;
    }

    fn get_server_id(&self) -> String {
        self.server_id_hex.borrow().clone()
    }

    fn set_server_identifier_hex(&self, id_hex: String) {
        *self.server_identifier_hex.borrow_mut() = id_hex;
    }

    fn get_server_identifier_hex(&self) -> String {
        self.server_identifier_hex.borrow().clone()
    }

    fn insert_round2_received(&self, sender_id_hex: String, pkg_json: String) {
        self.round2_received
            .borrow_mut()
            .insert(sender_id_hex, pkg_json);
    }

    fn get_round2_received_json(&self) -> String {
        map_to_parsed_json_object(&self.round2_received.borrow())
    }

    fn set_round2_local_json(&self, json: String) {
        *self.round2_local.borrow_mut() = json_to_map(&json);
    }

    fn get_round2_local_json(&self) -> String {
        map_to_json_object(&self.round2_local.borrow())
    }

    fn is_round2_local_empty(&self) -> bool {
        self.round2_local.borrow().is_empty()
    }

    fn insert_relay_packages(&self, sender_id_hex: String, packages_json: String) {
        let pkgs = json_to_map(&packages_json);
        self.round2_relay
            .borrow_mut()
            .insert(sender_id_hex, pkgs);
    }

    fn insert_relay_from_local(&self, server_id_hex: String) {
        let local = self.round2_local.borrow().clone();
        self.round2_relay
            .borrow_mut()
            .insert(server_id_hex, local);
    }

    fn relay_sender_count(&self) -> u32 {
        self.round2_relay.borrow().len() as u32
    }

    fn get_relay_packages_for(&self, recipient_id_hex: String) -> String {
        let relay = self.round2_relay.borrow();
        let mut obj = serde_json::Map::new();
        for (sender, sender_pkgs) in relay.iter() {
            if let Some(pkg) = sender_pkgs.get(&recipient_id_hex) {
                obj.insert(sender.clone(), serde_json::Value::String(pkg.clone()));
            }
        }
        serde_json::Value::Object(obj).to_string()
    }

    fn set_refresh_creation_time_ms(&self, ms: i64) {
        *self.refresh_creation_time_ms.borrow_mut() = ms;
    }

    fn get_refresh_creation_time_ms(&self) -> i64 {
        *self.refresh_creation_time_ms.borrow()
    }

    fn set_refresh_id(&self, id: String) {
        *self.refresh_id.borrow_mut() = id;
    }

    fn get_refresh_id(&self) -> String {
        self.refresh_id.borrow().clone()
    }

    fn set_refresh_threshold_amount(&self, amount: i64) {
        *self.refresh_threshold_amount.borrow_mut() = amount;
    }

    fn get_refresh_threshold_amount(&self) -> i64 {
        *self.refresh_threshold_amount.borrow()
    }

    fn set_refresh_interval(&self, interval: i64) {
        *self.refresh_interval.borrow_mut() = interval;
    }

    fn get_refresh_interval(&self) -> i64 {
        *self.refresh_interval.borrow()
    }
}
