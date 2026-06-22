//! Wire protocol between the long-lived cosigner WASM guest and the cosigner-runtime
//! host. The host drives the guest over WASI stdio: it writes [`Frame`]s to the guest's
//! stdin and reads [`Frame`]s from its stdout. A single host->guest [`GuestCommand`] may
//! cause the guest to emit several [`GuestIoRequest`] / snapshot frames before its
//! terminal [`GuestResponse`] — correlated by [`Frame::corr_id`].
//!
//! Payload bodies that would otherwise carry threshold/ark crypto types instead carry
//! already-serialized JSON / bytes, so this crate stays dependency-light and builds for
//! both the host and the `wasm32-wasip2` guest. The command/response/io enums grow one
//! variant-group per migration phase; today they cover the Phase-1 skeleton (`Ping`) and
//! the seal/unseal I/O used by the snapshot lifecycle.

use serde::{Deserialize, Serialize};

/// One framed message on the wire. Length-prefixed when serialized (see [`encode_frame`]).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Frame {
    /// Correlates a guest response (and its interleaved I/O requests) with the command
    /// that triggered it.
    pub corr_id: u64,
    pub payload: Payload,
}

/// The body of a [`Frame`]. Direction is encoded by variant, not a separate field.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Payload {
    // ---- host -> guest ----
    /// Drive a command in the guest.
    Command(GuestCommand),
    /// Answer a prior [`GuestIoRequest`] (same `corr_id`).
    IoResult(IoResult),
    /// Hand the guest its sealed state blob to restore (sent first on spawn/reseat).
    RestoreSnapshot(Vec<u8>),

    // ---- guest -> host ----
    /// Terminal result of a [`GuestCommand`].
    Response(GuestResponse),
    /// Ask the host to perform I/O (network/seal); host replies with [`Payload::IoResult`].
    IoRequest(GuestIoRequest),
    /// A sealed state blob the host must persist (opaque to the host).
    SnapshotEmit(Vec<u8>),
}

/// Host -> guest commands. Grows per migration phase.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GuestCommand {
    /// No-op liveness/round-trip check (Phase 1 skeleton).
    Ping,
    /// Install (or replace) a group's signing policy in the guest. Crypto material is
    /// carried as the same JSON the threshold lib emits (`KeyPackage`/`PublicKeyPackage`
    /// `to_json`), so this crate stays threshold-free.
    InstallPolicy {
        group_key: String,
        key_package_json: String,
        public_key_package_json: String,
        /// The user/client's FROST verifying identifier (hex). `None` ⇒ derive from user_id.
        user_signing_identifier_hex: Option<String>,
        /// The Ark cosigner secret (hex) — the MuSig2 key used for delegate-settle tree
        /// signing. Installed into the guest so the host need not hold it (enclave goal).
        /// `None` until the host is migrated to supply it.
        server_dkg_secret_hex: Option<String>,
    },
    /// FROST cooperative sign, round 1: the guest stores the client's commitments,
    /// generates its own nonce, and returns the combined commitments to sign over.
    FrostSignStep1(SignStep1Wire),
    /// FROST cooperative sign, round 2: the guest inserts the client's signature share,
    /// computes its own (gated by `contract-gate`), aggregates, and returns (R, Z).
    FrostSignStep2(SignStep2Wire),
    /// Off-chain send, phase 1: the guest builds the Ark tx (awaiting `asp-gate.get-info`)
    /// and returns the sighashes the client must FROST-sign (via the normal SignStep1/2).
    SendVtxoStep1(SendVtxoStep1Wire),
    /// Off-chain send, phase 2: the guest inserts the client's signatures, then submits +
    /// finalizes via `asp-gate`, returning the Ark txid.
    SendVtxoStep2(SendVtxoStep2Wire),
    /// Replace the guest's owned VTXO set (the host pushes it from the vtxo-stream / its
    /// projection until the stream routes directly into the guest). State-migration step:
    /// the guest becomes the source of truth for spendable VTXOs.
    SetVtxos { vtxos: Vec<VtxoInputWire> },
    /// Return the guest's current owned VTXO set.
    ListVtxos,
    /// Replace the guest's Ark transaction history (restore / initial load).
    SetHistory { entries: Vec<ArkTxEntryWire> },
    /// Append one entry to the guest's Ark transaction history (after a send/settle).
    AppendHistory { entry: ArkTxEntryWire },
    /// Return the guest's Ark transaction history.
    ListArkTransactions,
    /// Delegate phase 1: build the pre-authorized intent + forfeit PSBTs (after a gRPC
    /// `GetInfo`) and return the sighashes the client must FROST-sign. Stores the session.
    GenerateDelegate(GenerateDelegateWire),
    /// Delegate phase 2: insert the client's FROST signatures, moving the stored delegate
    /// session to `ReadyToSettle`.
    ApplyDelegateSigs(ApplyDelegateSigsWire),
    /// Drive a delegate/auto-settle batch entirely in the guest: register the pre-authorized
    /// intent, open the ASP event stream, and run the MuSig2 tree-signing + forfeit loop to
    /// completion. Requires a `ReadyToSettle` delegate session already installed in the guest.
    SettleDelegate { asp_url: String },
    /// Phase 4: serialize the guest's durable state (policy + Ark cosigner secret + VTXOs +
    /// history) into an opaque sealed blob the host stores but cannot read. In-flight sessions
    /// are deliberately excluded (MuSig2 secret nonces must never persist).
    Snapshot,
    /// Phase 4: restore durable state from a blob previously returned by `Snapshot` (on guest
    /// spawn / actor reseat).
    RestoreSnapshot { blob: Vec<u8> },
    // Phase 3 (later): Settle, SettleDelegate, SubmitArkSend, RedeemVtxo, ListVtxos,
    //                  ListArkTransactions, GetArkAddress, GetBoardingAddress,
    //                  RegisterDeviceToken, ApplyVtxoStreamUpdate, TickAutoSettle
}

/// A spendable VTXO the guest can use as a send input. (Passed in until the guest owns
/// the vtxo set outright in a later step.)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VtxoInputWire {
    pub txid: String,
    pub vout: u32,
    pub amount_sats: u64,
    pub exit_delay: u32,
}

/// SendVtxo phase 1 — build the Ark tx and get sighashes to sign.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendVtxoStep1Wire {
    pub user_id: Vec<u8>,
    pub signature: Vec<u8>,
    pub timestamp_ms: i64,
    /// ASP gRPC endpoint (the host injects its configured ASP_URL; the guest calls it).
    pub asp_url: String,
    pub recipient_ark_address: String,
    pub amount: u64,
    // VTXOs now come from the guest's own store (set via `SetVtxos`), not the wire.
}

/// SendVtxo phase 2 — the client's FROST signatures over the phase-1 sighashes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendVtxoStep2Wire {
    pub user_id: Vec<u8>,
    pub signature: Vec<u8>,
    pub timestamp_ms: i64,
    pub asp_url: String,
    pub signed_messages: Vec<Vec<u8>>,
}

/// Phase 4: the guest's durable state, serialized into the sealed snapshot blob. Excludes
/// in-flight sessions (MuSig2 secret nonces must never persist).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnapshotState {
    pub group_key: String,
    pub key_package_json: String,
    pub public_key_package_json: String,
    pub user_signing_identifier_hex: Option<String>,
    pub ark_cosigner_secret_hex: Option<String>,
    pub vtxos: Vec<VtxoInputWire>,
    pub history: Vec<ArkTxEntryWire>,
    /// A `ReadyToSettle` delegate session serialized via ark `PersistedDelegate` (JSON), if
    /// one is pending. Lets durable auto-settle survive actor eviction. Only ever
    /// `ReadyToSettle` (never a `Settling`-phase session — MuSig2 nonces must not persist).
    pub delegate_json: Option<String>,
}

/// An Ark transaction history entry (mirrors the host `ArkTxEntry`). Display log; non-secret.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArkTxEntryWire {
    pub tx_type: String,
    pub amount_sats: i64,
    pub txid: String,
    pub timestamp: i64,
}

/// Delegate phase 1 — build the pre-authorized intent + forfeit PSBTs and return sighashes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerateDelegateWire {
    pub user_id: Vec<u8>,
    pub signature: Vec<u8>,
    pub timestamp_ms: i64,
    pub asp_url: String,
    // VTXOs come from the guest's own store (SetVtxos); the settle output is a self-refresh
    // to the owner's own ark address, which the guest computes from GetInfo. Neither is on
    // the wire. Only the host-computed renewal deadline is passed in.
    /// Renewal time (Unix secs) the delegate becomes valid; `None` keeps the legacy window.
    pub intent_valid_at: Option<u64>,
}

/// Delegate phase 2 — the client's FROST signatures over the phase-1 sighashes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApplyDelegateSigsWire {
    pub user_id: Vec<u8>,
    pub signature: Vec<u8>,
    pub timestamp_ms: i64,
    pub signed_messages: Vec<Vec<u8>>,
}

/// FROST sign round-1 request (mirrors the gRPC `SignStep1Request` fields the guest needs).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignStep1Wire {
    /// The client's auth/verifying identity (compressed pubkey bytes); also the key the
    /// auth signature is checked against.
    pub user_id: Vec<u8>,
    pub hiding_commitment: Vec<u8>,
    pub binding_commitment: Vec<u8>,
    pub message_to_sign: Vec<u8>,
    /// BIP-340 auth signature over the canonical auth message for this operation.
    pub signature: Vec<u8>,
    pub full_transaction: Vec<u8>,
    pub timestamp_ms: i64,
    /// True ⇒ raw FROST (no taproot tweak).
    pub script_path_spend: bool,
}

/// FROST sign round-2 request (mirrors the gRPC `SignStep2Request`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignStep2Wire {
    pub user_id: Vec<u8>,
    pub signature_share: Vec<u8>,
    pub signature: Vec<u8>,
    pub timestamp_ms: i64,
}

/// One participant's signing commitments, keyed by FROST identifier (hex).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommitmentWire {
    pub identifier_hex: String,
    pub hiding: Vec<u8>,
    pub binding: Vec<u8>,
}

/// Guest -> host terminal responses. Grows per migration phase.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GuestResponse {
    /// Reply to [`GuestCommand::Ping`].
    Pong,
    /// Reply to [`GuestCommand::InstallPolicy`].
    PolicyInstalled,
    /// Reply to [`GuestCommand::FrostSignStep1`].
    SignStep1 {
        commitments: Vec<CommitmentWire>,
        message_to_sign: Vec<u8>,
    },
    /// Reply to [`GuestCommand::FrostSignStep2`]: the aggregated signature (R, Z).
    SignStep2 { r_point: Vec<u8>, z_scalar: Vec<u8> },
    /// Reply to [`GuestCommand::SetVtxos`] — the guest's VTXO set was replaced.
    VtxosSet,
    /// Reply to [`GuestCommand::ListVtxos`] — the guest's current owned VTXO set.
    Vtxos { vtxos: Vec<VtxoInputWire> },
    /// Reply to [`GuestCommand::SetHistory`] / [`GuestCommand::AppendHistory`].
    HistoryUpdated,
    /// Reply to [`GuestCommand::Snapshot`] — the opaque sealed state blob.
    Snapshot { blob: Vec<u8> },
    /// Reply to [`GuestCommand::RestoreSnapshot`] — durable state restored.
    Restored,
    /// Reply to [`GuestCommand::ListArkTransactions`] — the guest's transaction history.
    ArkTransactions { entries: Vec<ArkTxEntryWire> },
    /// Reply to [`GuestCommand::GenerateDelegate`] — sighashes the client must FROST-sign.
    DelegateSighashes { messages_to_sign: Vec<Vec<u8>> },
    /// Reply to [`GuestCommand::ApplyDelegateSigs`] — the delegate session is `ReadyToSettle`.
    DelegateReady,
    /// Reply to [`GuestCommand::SettleDelegate`] — the finalized batch commitment txid and
    /// the settled VTXO outpoint `(txid, vout)` if one was produced.
    SettleSubmitted {
        commitment_txid: String,
        vtxo_outpoint: Option<(String, u32)>,
    },
    /// Reply to [`GuestCommand::SendVtxoStep1`] — sighashes the client must FROST-sign.
    SendVtxoSighashes { messages_to_sign: Vec<Vec<u8>> },
    /// Reply to [`GuestCommand::SendVtxoStep2`] — the submitted Ark transaction id and the
    /// change VTXO `(txid, vout, amount_sats, exit_delay)` if the send produced one (host
    /// updates its VTXO projection from this until VTXO state migrates into the guest).
    SendVtxoSubmitted {
        ark_txid: String,
        change: Option<(String, u32, u64, u32)>,
    },
    /// The command failed; carries a human-readable reason.
    Error(String),
}

/// Guest -> host I/O requests: the guest holds the keys/state and asks the host (which
/// owns the network + the sealing key) to perform side effects. Grows per phase.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GuestIoRequest {
    /// Seal a plaintext state blob (AEAD under a key the host/enclave holds).
    Seal { plaintext: Vec<u8> },
    /// Unseal a previously sealed blob.
    Unseal { blob: Vec<u8> },
    // Phase 3 (Ark/network): AspGetInfo, AspSubmitTx, AspFinalizeTx, AspDrive,
    //                        ElectrumListUnspent, SetScriptOwner
}

/// Host -> guest answers to a [`GuestIoRequest`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum IoResult {
    Sealed(Vec<u8>),
    Unsealed(Vec<u8>),
    Error(String),
}

// ---------------------------------------------------------------------------
// Framing: u32 little-endian length prefix + serde_json body.
// (serde_json for now — debuggable + reuses the existing JSON adapters; can switch to
// a compact codec later without changing the enums.)
// ---------------------------------------------------------------------------

/// Serialize a frame as `len(u32 LE) || json(body)`.
pub fn encode_frame(frame: &Frame) -> Vec<u8> {
    let body = serde_json::to_vec(frame).expect("frame is serializable");
    let mut out = Vec::with_capacity(4 + body.len());
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

/// Try to decode one frame from the front of `buf`. Returns `(frame, bytes_consumed)`,
/// or `None` if `buf` doesn't yet hold a complete frame (caller should read more bytes).
pub fn try_decode_frame(buf: &[u8]) -> Result<Option<(Frame, usize)>, String> {
    if buf.len() < 4 {
        return Ok(None);
    }
    let len = u32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]]) as usize;
    let total = 4 + len;
    if buf.len() < total {
        return Ok(None);
    }
    let frame: Frame =
        serde_json::from_slice(&buf[4..total]).map_err(|e| format!("bad frame: {e}"))?;
    Ok(Some((frame, total)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ping_roundtrip() {
        let frame = Frame {
            corr_id: 7,
            payload: Payload::Command(GuestCommand::Ping),
        };
        let bytes = encode_frame(&frame);
        let (decoded, consumed) = try_decode_frame(&bytes).unwrap().unwrap();
        assert_eq!(consumed, bytes.len());
        assert_eq!(decoded.corr_id, 7);
        assert!(matches!(
            decoded.payload,
            Payload::Command(GuestCommand::Ping)
        ));
    }

    #[test]
    fn partial_frame_returns_none() {
        let bytes = encode_frame(&Frame {
            corr_id: 1,
            payload: Payload::Response(GuestResponse::Pong),
        });
        // One byte short of complete.
        assert!(try_decode_frame(&bytes[..bytes.len() - 1]).unwrap().is_none());
        // Fewer than the 4-byte length prefix.
        assert!(try_decode_frame(&bytes[..2]).unwrap().is_none());
    }

    #[test]
    fn two_frames_back_to_back() {
        let mut buf = encode_frame(&Frame {
            corr_id: 1,
            payload: Payload::IoRequest(GuestIoRequest::Seal { plaintext: vec![1, 2, 3] }),
        });
        buf.extend(encode_frame(&Frame {
            corr_id: 1,
            payload: Payload::IoResult(IoResult::Sealed(vec![9])),
        }));
        let (f1, n1) = try_decode_frame(&buf).unwrap().unwrap();
        assert!(matches!(f1.payload, Payload::IoRequest(_)));
        let (f2, _n2) = try_decode_frame(&buf[n1..]).unwrap().unwrap();
        assert!(matches!(f2.payload, Payload::IoResult(_)));
    }
}
