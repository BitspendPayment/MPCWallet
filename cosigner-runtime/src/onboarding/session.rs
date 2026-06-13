//! Per-user DKG ceremony state. Native Rust — no WASM. Owned by the
//! `DkgCoordinator`, accessed under a `parking_lot::Mutex`, evicted on TTL
//! or after step3 finalizes.

use std::collections::{HashMap, HashSet};
use std::time::Instant;

use tokio::sync::oneshot;
use tonic::Status;

use threshold::dkg::{Round1SecretPackage, Round2SecretPackage};

use crate::wallet_proto::{
    DkgStep1Response, DkgStep2Response, DkgStep3Response, EvtxoKeygenStep1Response,
    EvtxoKeygenStep2Response, EvtxoKeygenStep3Response,
};

pub struct DkgSession {
    pub user_id_hex: String,

    // Aggregator state (mirrors cosigner/src/session_state.rs::DkgSessionState
    // but without the RefCell; we hold a &mut self while operating).
    pub round1_packages: HashMap<String, String>,
    pub receiver_identifiers: HashSet<String>,
    pub server_id_hex: String,
    pub server_internal_secret_hex: String,
    pub round2_received: HashMap<String, String>,
    pub round2_local: HashMap<String, String>,
    /// sender_id -> { recipient_id -> pkg_json }
    pub round2_relay: HashMap<String, HashMap<String, String>>,

    // Typed cross-round secrets from the threshold crate.
    pub round1_secret: Option<Round1SecretPackage>,
    pub round2_secret: Option<Round2SecretPackage>,

    // eVTXO resharing context (empty/None for a normal DKG session). When set,
    // the ceremony reshares the existing key into a new 2-of-2 V′ bound to a
    // contract; the cosigner is both a dealer and a final shareholder.
    pub reshare_contract_id: Vec<u8>,
    pub reshare_contract_wasm: Vec<u8>,
    pub reshare_old_kp_json: String,
    pub reshare_old_pkp_json: String,
    pub reshare_server_pk: Vec<u8>,
    pub reshare_exit_delay: u32,

    // Rendezvous pools: oneshot replies for participants waiting on the
    // arrival of others before a round can complete.
    pub pending_step1: Vec<oneshot::Sender<Result<DkgStep1Response, Status>>>,
    pub pending_step2: Vec<oneshot::Sender<Result<DkgStep2Response, Status>>>,
    pub pending_step3: Vec<(String, oneshot::Sender<Result<DkgStep3Response, Status>>)>,

    // Rendezvous pools for the eVTXO reshare ceremony (typed for its responses).
    pub pending_evtxo_step1: Vec<oneshot::Sender<Result<EvtxoKeygenStep1Response, Status>>>,
    pub pending_evtxo_step2: Vec<oneshot::Sender<Result<EvtxoKeygenStep2Response, Status>>>,
    pub pending_evtxo_step3:
        Vec<(String, oneshot::Sender<Result<EvtxoKeygenStep3Response, Status>>)>,

    pub last_touch: Instant,
}

impl DkgSession {
    pub fn new(user_id_hex: String) -> Self {
        Self {
            user_id_hex,
            round1_packages: HashMap::new(),
            receiver_identifiers: HashSet::new(),
            server_id_hex: String::new(),
            server_internal_secret_hex: String::new(),
            round2_received: HashMap::new(),
            round2_local: HashMap::new(),
            round2_relay: HashMap::new(),
            round1_secret: None,
            round2_secret: None,
            reshare_contract_id: Vec::new(),
            reshare_contract_wasm: Vec::new(),
            reshare_old_kp_json: String::new(),
            reshare_old_pkp_json: String::new(),
            reshare_server_pk: Vec::new(),
            reshare_exit_delay: 0,
            pending_step1: Vec::new(),
            pending_step2: Vec::new(),
            pending_step3: Vec::new(),
            pending_evtxo_step1: Vec::new(),
            pending_evtxo_step2: Vec::new(),
            pending_evtxo_step3: Vec::new(),
            last_touch: Instant::now(),
        }
    }

    pub fn total_participants(&self) -> usize {
        self.round1_packages.len() + self.receiver_identifiers.len()
    }

    pub fn is_receiver(&self, id_hex: &str) -> bool {
        self.receiver_identifiers.contains(id_hex)
    }

    pub fn relay_sender_count(&self) -> usize {
        self.round2_relay.len()
    }

    pub fn is_round2_local_empty(&self) -> bool {
        self.round2_local.is_empty()
    }

    /// All round1 packages as a `{id_hex: pkg_json_string}` JSON object.
    pub fn round1_packages_json(&self) -> String {
        map_to_json_object(&self.round1_packages)
    }

    /// Round1 packages excluding one sender (the server's own, when feeding
    /// `dkg_part2`).
    pub fn round1_packages_excluding_json(&self, exclude_id_hex: &str) -> String {
        let mut obj = serde_json::Map::new();
        for (id, pkg_str) in &self.round1_packages {
            if id != exclude_id_hex {
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

    pub fn receiver_ids_json(&self) -> String {
        let arr: Vec<serde_json::Value> = self
            .receiver_identifiers
            .iter()
            .map(|s| serde_json::Value::String(s.clone()))
            .collect();
        serde_json::Value::Array(arr).to_string()
    }

    pub fn round2_received_json(&self) -> String {
        let mut obj = serde_json::Map::new();
        for (k, v) in &self.round2_received {
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

    pub fn set_round2_local_json(&mut self, json: &str) {
        self.round2_local = json_to_string_map(json);
    }

    pub fn insert_relay_packages(&mut self, sender_id_hex: String, packages_json: &str) {
        let pkgs = json_to_string_map(packages_json);
        self.round2_relay.insert(sender_id_hex, pkgs);
    }

    pub fn insert_relay_from_local(&mut self, server_id_hex: String) {
        let local = self.round2_local.clone();
        self.round2_relay.insert(server_id_hex, local);
    }

    pub fn relay_packages_for(&self, recipient_id_hex: &str) -> String {
        let mut obj = serde_json::Map::new();
        for (sender, sender_pkgs) in &self.round2_relay {
            if let Some(pkg) = sender_pkgs.get(recipient_id_hex) {
                obj.insert(sender.clone(), serde_json::Value::String(pkg.clone()));
            }
        }
        serde_json::Value::Object(obj).to_string()
    }
}

fn map_to_json_object(map: &HashMap<String, String>) -> String {
    let obj: serde_json::Map<String, serde_json::Value> = map
        .iter()
        .map(|(k, v)| (k.clone(), serde_json::Value::String(v.clone())))
        .collect();
    serde_json::Value::Object(obj).to_string()
}

fn json_to_string_map(json: &str) -> HashMap<String, String> {
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
