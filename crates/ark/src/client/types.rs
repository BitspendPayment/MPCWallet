//! Ark protocol types for client-side operations.

use serde::{Deserialize, Serialize};

/// Information about the connected ASP (Ark Service Provider).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArkInfo {
    /// ASP signer x-only public key (hex).
    pub signer_pubkey: String,
    /// ASP forfeit public key (hex).
    pub forfeit_pubkey: String,
    /// ASP forfeit address (bech32m).
    pub forfeit_address: String,
    /// Checkpoint exit tapscript (hex).
    pub checkpoint_tapscript: String,
    /// Bitcoin network (e.g. "bitcoin", "testnet", "regtest").
    pub network: String,
    /// Round session duration in seconds.
    pub session_duration: i64,
    /// Unilateral exit delay in blocks.
    pub unilateral_exit_delay: i64,
    /// Boarding exit delay in blocks.
    pub boarding_exit_delay: i64,
    /// Minimum VTXO amount in sats.
    pub vtxo_min_amount: i64,
    /// Dust threshold in sats.
    pub dust: i64,
}

/// Status of a stored VTXO.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum VtxoStatus {
    /// Confirmed in a finalized batch.
    Confirmed,
    /// Pending confirmation in an upcoming batch.
    Pending,
    /// Already spent.
    Spent,
    /// Expired (batch output swept).
    Expired,
}

/// A locally tracked VTXO.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoredVtxo {
    /// Transaction ID of the VTXO outpoint.
    pub txid: String,
    /// Output index.
    pub vout: u32,
    /// Amount in satoshis.
    pub amount: u64,
    /// Script (hex-encoded).
    pub script: String,
    /// Creation timestamp.
    pub created_at: i64,
    /// Expiry timestamp.
    pub expires_at: i64,
    /// Current status.
    pub status: VtxoStatus,
    /// Whether this is a pre-confirmed (off-chain) VTXO.
    pub is_preconfirmed: bool,
    /// The Ark transaction ID that created this VTXO, if any.
    pub ark_txid: Option<String>,
}
