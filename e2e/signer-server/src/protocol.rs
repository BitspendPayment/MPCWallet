use serde::{Deserialize, Serialize};
use std::collections::HashMap;

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

#[derive(Deserialize, Debug)]
#[serde(tag = "cmd")]
pub enum Request {
    #[serde(rename = "dkg_init")]
    DkgInit {
        max_signers: usize,
        min_signers: usize,
    },

    #[serde(rename = "restore_init")]
    RestoreInit {
        max_signers: usize,
        min_signers: usize,
    },

    #[serde(rename = "dkg_round2")]
    DkgRound2 {
        /// Keyed by identifier hex, value is Round1Package JSON
        round1_packages: HashMap<String, serde_json::Value>,
        #[serde(default)]
        receiver_identifiers: Vec<String>,
    },

    #[serde(rename = "dkg_round3")]
    DkgRound3 {
        round1_packages: HashMap<String, serde_json::Value>,
        round2_packages: HashMap<String, serde_json::Value>,
        #[serde(default)]
        receiver_identifiers: Vec<String>,
    },

    // eVTXO reshare: the signer deals a fresh non-zero polynomial under its
    // EXISTING identifier but keeps NO resulting share (it's excluded from V′).
    #[serde(rename = "evtxo_deal_init")]
    EvtxoDealInit {
        max_signers: usize,
        min_signers: usize,
    },

    #[serde(rename = "evtxo_deal_round2")]
    EvtxoDealRound2 {
        round1_packages: HashMap<String, serde_json::Value>,
        #[serde(default)]
        receiver_identifiers: Vec<String>,
    },

    #[serde(rename = "generate_nonce")]
    GenerateNonce,

    #[serde(rename = "sign")]
    Sign {
        message_hex: String,
        /// Keyed by identifier hex, value is {"binding":"hex","hiding":"hex"}
        commitments: HashMap<String, serde_json::Value>,
        #[serde(default)]
        apply_tweak: bool,
        #[serde(default)]
        merkle_root_hex: Option<String>,
    },

    #[serde(rename = "get_info")]
    GetInfo,
}

// ---------------------------------------------------------------------------
// Responses
// ---------------------------------------------------------------------------

#[derive(Serialize, Debug)]
#[serde(untagged)]
pub enum Response {
    DkgInit {
        round1_package_json: serde_json::Value,
        verifying_key_hex: String,
        identifier_hex: String,
    },

    DkgRound2 {
        round2_packages: HashMap<String, serde_json::Value>,
    },

    DkgRound3 {
        ok: bool,
        identifier_hex: String,
        public_key_hex: String,
    },

    GenerateNonce {
        hiding_hex: String,
        binding_hex: String,
    },

    Sign {
        share_hex: String,
    },

    Info {
        has_key_package: bool,
        has_pending_nonce: bool,
        identifier_hex: Option<String>,
    },

    Error {
        error: String,
    },
}
