//! Guest-owned state + command handlers. The guest holds the signing keys (the host
//! never sees them) and the in-flight FROST ceremony, and answers commands from the
//! host over the stream protocol.
//!
//! Phase 2 scope: the normal raw-FROST 2-of-2 cooperative sign (`script_path_spend`,
//! no taproot tweak, no contract spend). The taproot-tweak path, contract-spend key
//! selection, and the `contract-gate` import land with the Ark/contract migration; the
//! sealed-snapshot lifecycle lands in Phase 4.

use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

use rand::rngs::OsRng;

use cosigner_proto::{
    ApplyDelegateSigsWire, ArkTxEntryWire, CommitmentWire, ContractPairingWire, GuestCommand,
    GuestResponse, SendVtxoStep1Wire, SignStep1Wire, SignStep2Wire, SnapshotState, TreeTxChunkWire,
    VtxoInputWire,
};

use ark::client::batch::{DelegateSettleSession, PersistedDelegate};
use ark::client::send::{SendSession, SendVtxoInput};
use ark::client::types::ArkInfo;

use threshold::commitment::SigningPackage;
use threshold::dkg;
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::nonce::{self, SigningCommitments, SigningNonce};
use threshold::point;
use threshold::scalar::{scalar_from_bytes, scalar_to_bytes};
use threshold::signing::{self, SignatureShare};

// Auth message format — must match the host (`auth/message.rs`) and the Dart client.
const AUTH_PREFIX: &str = "MPC_WALLET_AUTH_V1";
const OP_SIGN_STEP1: &str = "SIGN_STEP1";
const OP_SIGN_STEP2: &str = "SIGN_STEP2";
pub(crate) const OP_SEND_VTXO: &str = "SEND_VTXO";
pub(crate) const OP_SETTLE_DELEGATE: &str = "SETTLE_DELEGATE";
const MAX_TIMESTAMP_DRIFT_MS: i64 = 5 * 60 * 1000;
const THRESHOLD_COUNT: usize = 2;

/// An installed signing policy. The cosigner's own key share + the group public key,
/// plus the client's FROST identifier (the other half of the 2-of-2).
struct Policy {
    #[allow(dead_code)]
    group_key: String,
    key_package: KeyPackage,
    public_key_package: PublicKeyPackage,
    user_signing_identifier: Option<Identifier>,
    /// Set ONLY for a `{service, cosigner}` pairing actor: the guest then rebuilds + binds the
    /// cooperative-leaf sighash itself in `sign_step1` (Plan A 1C). `None` for a normal wallet.
    contract_pairing: Option<crate::conditioning::ContractPairing>,
    /// The wallet's contract registry as OPAQUE host JSON (the guest never parses it — it only
    /// stores + returns it so the seal is the single source of the public projection). Plan A
    /// Phase 2: this replaces the host `policies` sled tree. Empty string ⇒ no contracts.
    contracts_json: String,
}

/// In-flight FROST ceremony state (cleared between rounds).
#[derive(Default)]
struct Ceremony {
    message: Vec<u8>,
    commitments: BTreeMap<Identifier, SigningCommitments>,
    shares: BTreeMap<Identifier, SignatureShare>,
    /// The cosigner's single-use nonce for this round (set in step1, consumed in step2).
    nonce: Option<SigningNonce>,
    /// True ⇒ key-path (taproot) spend: sign under the BIP-341 key-path-tweaked key
    /// (`merkle_root = None`). False ⇒ raw FROST (script-path spend).
    tweaked: bool,
    /// The full transaction being signed (from step1), passed to `contract-gate` enforcement
    /// in step2 before the cosigner produces its share.
    full_transaction: Vec<u8>,
}

/// In-flight GUEST-driven boarding settle, held across the commitment-FROST pause (Plan A): the
/// boarding session + tree-signer + the boarding amount for the resulting VTXO. The event stream is
/// dropped at the pause (Step3 finalizes optimistically), so `stream` stays `None` in practice.
pub struct BoardingSettleInFlight {
    pub session: ark::client::batch::SettleSession,
    pub signer: ark::client::batch::BoardingTreeSigner,
    pub stream: Option<crate::grpc::ServerStream>,
    pub amount_sats: u64,
}

pub struct GuestState {
    policy: Option<Policy>,
    ceremony: Ceremony,
    /// In-flight off-chain send: `(session, change_exit_delay)`. Set in SendVtxoStep1,
    /// consumed in SendVtxoStep2.
    send_session: Option<(SendSession, u32)>,
    /// A `ReadyToSettle` delegate session the guest can drive autonomously (auto-settle).
    delegate_session: Option<DelegateSettleSession>,
    /// In-flight boarding tree-signer (Plan A Phase 2): holds the secret per-node nonces between
    /// `BoardingGenNonces` and `BoardingTreeSign` while the host drives the boarding batch.
    boarding_signer: Option<ark::client::batch::BoardingTreeSigner>,
    /// In-flight GUEST-driven boarding settle: the session + tree-signer + open ASP event stream +
    /// intent id, held across the BoardingSettleStep1→2→3 commitment-FROST pause. Transient (never
    /// snapshotted — in-flight batch state must not persist).
    boarding_settle: Option<BoardingSettleInFlight>,
    /// The Ark cosigner (MuSig2) secret, hex — used by `generate_delegate` for tree signing.
    /// Installed via [`GuestCommand::InstallPolicy`]; never leaves the guest.
    ark_cosigner_secret_hex: Option<String>,
    /// The guest's owned spendable VTXO set (state-migration: the guest is becoming the
    /// source of truth; the host pushes updates via [`GuestCommand::SetVtxos`]).
    vtxos: Vec<VtxoInputWire>,
    /// The guest's owned Ark transaction history (display log; non-secret).
    history: Vec<ArkTxEntryWire>,
}

impl GuestState {
    pub fn new() -> Self {
        Self {
            policy: None,
            ceremony: Ceremony::default(),
            send_session: None,
            delegate_session: None,
            boarding_signer: None,
            boarding_settle: None,
            ark_cosigner_secret_hex: None,
            vtxos: Vec::new(),
            history: Vec::new(),
        }
    }

    /// Phase 4: serialize durable state (policy + Ark secret + VTXOs + history) into the
    /// sealed-snapshot blob. In-flight sessions are excluded (transient; MuSig2 nonces must
    /// never persist).
    pub fn to_snapshot(&self) -> Result<Vec<u8>, String> {
        let policy = self.policy.as_ref().ok_or("no policy to snapshot")?;
        let snap = SnapshotState {
            group_key: policy.group_key.clone(),
            key_package_json: policy.key_package.to_json(),
            public_key_package_json: policy.public_key_package.to_json(),
            user_signing_identifier_hex: policy
                .user_signing_identifier
                .as_ref()
                .map(|id| hex::encode(id.serialize())),
            ark_cosigner_secret_hex: self.ark_cosigner_secret_hex.clone(),
            contract_pairing: policy.contract_pairing.as_ref().map(pairing_to_wire),
            contracts_json: policy.contracts_json.clone(),
            vtxos: self.vtxos.clone(),
            history: self.history.clone(),
            // Persist a ReadyToSettle delegate (to_persisted errors for other phases → None),
            // so durable auto-settle survives reseat.
            delegate_json: self
                .delegate_session
                .as_ref()
                .and_then(|s| s.to_persisted().ok())
                .and_then(|p| serde_json::to_string(&p).ok()),
        };
        serde_json::to_vec(&snap).map_err(|e| format!("snapshot serialize: {e}"))
    }

    /// Phase 4: restore durable state from a snapshot blob (on spawn / actor reseat).
    pub fn restore_snapshot(&mut self, blob: &[u8]) -> Result<(), String> {
        let snap: SnapshotState =
            serde_json::from_slice(blob).map_err(|e| format!("snapshot deserialize: {e}"))?;
        let key_package = KeyPackage::from_json(&snap.key_package_json)
            .map_err(|e| format!("bad key package: {e}"))?;
        let public_key_package = PublicKeyPackage::from_json(&snap.public_key_package_json)
            .map_err(|e| format!("bad public key package: {e}"))?;
        let user_signing_identifier = match snap.user_signing_identifier_hex {
            Some(h) => Some(parse_identifier_hex(&h)?),
            None => None,
        };
        self.policy = Some(Policy {
            group_key: snap.group_key,
            key_package,
            public_key_package,
            user_signing_identifier,
            contract_pairing: snap.contract_pairing.map(pairing_from_wire).transpose()?,
            contracts_json: snap.contracts_json,
        });
        self.ark_cosigner_secret_hex = snap.ark_cosigner_secret_hex;
        self.vtxos = snap.vtxos;
        self.history = snap.history;
        // Restore a pending ReadyToSettle delegate (needs the cosigner secret, which
        // from_persisted re-derives the keypair from).
        self.delegate_session = match (snap.delegate_json, self.ark_cosigner_secret_hex.as_ref()) {
            (Some(dj), Some(secret)) => {
                let persisted: PersistedDelegate = serde_json::from_str(&dj)
                    .map_err(|e| format!("parse persisted delegate: {e}"))?;
                Some(DelegateSettleSession::from_persisted(&persisted, secret)?)
            }
            _ => None,
        };
        Ok(())
    }

    /// The guest's owned VTXO set (read by SendVtxo/GenerateDelegate once they migrate off
    /// the wire; self-updated on send).
    pub fn vtxos(&self) -> &[VtxoInputWire] {
        &self.vtxos
    }

    pub fn set_vtxos(&mut self, vtxos: Vec<VtxoInputWire>) {
        self.vtxos = vtxos;
    }

    /// Apply a completed send to the owned VTXO set: the send spent all current VTXOs;
    /// re-add the change `(txid, vout, amount, exit_delay)` if any. Mirrors the host's
    /// post-send projection update, but now the guest is the source of truth.
    pub fn apply_send_change(&mut self, change: Option<(String, u32, u64, u32)>) {
        self.vtxos.clear();
        if let Some((txid, vout, amount_sats, exit_delay)) = change {
            self.vtxos.push(VtxoInputWire {
                txid,
                vout,
                amount_sats,
                exit_delay,
            });
        }
    }

    /// The installed Ark cosigner secret (hex), if any.
    pub fn ark_cosigner_secret_hex(&self) -> Option<&str> {
        self.ark_cosigner_secret_hex.as_deref()
    }

    pub fn take_boarding_settle(&mut self) -> Option<BoardingSettleInFlight> {
        self.boarding_settle.take()
    }

    pub fn set_boarding_settle(&mut self, b: BoardingSettleInFlight) {
        self.boarding_settle = Some(b);
    }

    /// Access the installed delegate session (the guest drives it in SettleDelegate).
    pub fn delegate_session_ref(&self) -> Option<&DelegateSettleSession> {
        self.delegate_session.as_ref()
    }

    pub fn delegate_session_mut(&mut self) -> Option<&mut DelegateSettleSession> {
        self.delegate_session.as_mut()
    }

    pub fn set_delegate_session(&mut self, session: DelegateSettleSession) {
        self.delegate_session = Some(session);
    }

    pub fn clear_delegate_session(&mut self) {
        self.delegate_session = None;
    }

    /// The wallet's group x-only pubkey (hex) — the VTXO owner key, derived from the
    /// installed policy's public key package (strip the compressed-parity byte).
    pub fn owner_pk_hex(&self) -> Result<String, String> {
        let policy = self.policy.as_ref().ok_or("no policy installed")?;
        let vk = policy.public_key_package.verifying_key.serialize(); // [u8; 33]
        Ok(hex::encode(&vk[1..]))
    }

    pub fn set_send_session(&mut self, session: SendSession, change_exit_delay: u32) {
        self.send_session = Some((session, change_exit_delay));
    }

    /// SendVtxoStep2 part 1 (sync): insert the client's FROST signatures and produce the
    /// `(signed_ark_tx_b64, unsigned_checkpoint_b64s)` to submit to the ASP.
    pub fn send_sign_and_prepare(
        &mut self,
        signatures: Vec<[u8; 64]>,
    ) -> Result<(String, Vec<String>), String> {
        let (session, _) = self.send_session.as_mut().ok_or("no send session")?;
        session.sign_with_frost(signatures)?;
        session.prepare_submit()
    }

    /// SendVtxoStep2 part 2 (sync): counter-sign the ASP-returned checkpoints.
    pub fn send_finalize_checkpoints(
        &self,
        signed_checkpoint_txs_b64: &[String],
    ) -> Result<Vec<String>, String> {
        let (session, _) = self.send_session.as_ref().ok_or("no send session")?;
        session.finalize_checkpoints(signed_checkpoint_txs_b64)
    }

    /// The change VTXO `(txid, vout, amount_sats, exit_delay)` of the in-flight send, if
    /// any. Call after submit/finalize, before `send_done`.
    pub fn send_change_vtxo(&self) -> Option<(String, u32, u64, u32)> {
        self.send_session.as_ref().and_then(|(session, change_exit_delay)| {
            session
                .change_vtxo()
                .map(|(txid, vout, amount)| (txid, vout, amount, *change_exit_delay))
        })
    }

    /// Delegate phase 2: auth, then insert the client's FROST signatures into the stored
    /// delegate session (→ `ReadyToSettle`). Sync (no I/O).
    fn apply_delegate_sigs(&mut self, req: ApplyDelegateSigsWire) -> Result<GuestResponse, String> {
        auth_check(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_SETTLE_DELEGATE,
        )?;
        let signatures: Vec<[u8; 64]> = req
            .signed_messages
            .iter()
            .map(|m| {
                m.as_slice()
                    .try_into()
                    .map_err(|_| "signature must be 64 bytes".to_string())
            })
            .collect::<Result<_, _>>()?;
        let session = self
            .delegate_session
            .as_mut()
            .ok_or("no delegate session")?;
        session.sign_with_frost(signatures)?;
        Ok(GuestResponse::DelegateReady)
    }

    pub fn send_done(&mut self) {
        if let Some((session, _)) = self.send_session.as_mut() {
            session.mark_done();
        }
        self.send_session = None;
    }

    /// Handle one command and produce its terminal response. (Snapshot restore becomes
    /// a command/export in Phase 4.)
    pub fn handle_command(&mut self, cmd: GuestCommand) -> GuestResponse {
        let result = match cmd {
            GuestCommand::Ping => return GuestResponse::Pong,
            GuestCommand::InstallPolicy {
                group_key,
                key_package_json,
                public_key_package_json,
                user_signing_identifier_hex,
                server_dkg_secret_hex,
                contract_pairing,
                contracts_json,
            } => self.install_policy(
                group_key,
                &key_package_json,
                &public_key_package_json,
                user_signing_identifier_hex.as_deref(),
                server_dkg_secret_hex,
                contract_pairing,
                contracts_json,
            ),
            GuestCommand::SetContracts { contracts_json } => match self.policy.as_mut() {
                Some(p) => {
                    p.contracts_json = contracts_json;
                    return GuestResponse::PolicyInstalled;
                }
                None => return GuestResponse::Error("no policy installed".into()),
            },
            GuestCommand::GetPublicPolicy => return self.public_policy(),
            GuestCommand::ContractRefresh {
                receiver_id_hex,
                receiver_partial_point,
                wallet_id_hex,
                a_at_cosigner,
                min_signers,
            } => self.contract_refresh(
                &receiver_id_hex,
                &receiver_partial_point,
                &wallet_id_hex,
                &a_at_cosigner,
                min_signers as usize,
            ),
            GuestCommand::ApplyDelegateSigs(req) => self.apply_delegate_sigs(req),
            GuestCommand::GetArkCosignerPubkey => self.get_ark_cosigner_pubkey(),
            GuestCommand::BoardingGenNonces {
                tree_tx_chunks,
                commitment_psbt_b64,
                batch_id: _,
            } => self.boarding_gen_nonces(tree_tx_chunks, &commitment_psbt_b64),
            GuestCommand::BoardingTreeSign {
                pending_nonces,
                batch_expiry,
                forfeit_pk_hex,
            } => self.boarding_tree_sign(pending_nonces, batch_expiry, &forfeit_pk_hex),
            GuestCommand::SetVtxos { vtxos } => {
                self.vtxos = vtxos;
                return GuestResponse::VtxosSet;
            }
            GuestCommand::ListVtxos => {
                return GuestResponse::Vtxos {
                    vtxos: self.vtxos.clone(),
                }
            }
            GuestCommand::SetHistory { entries } => {
                self.history = entries;
                return GuestResponse::HistoryUpdated;
            }
            GuestCommand::AppendHistory { entry } => {
                self.history.push(entry);
                return GuestResponse::HistoryUpdated;
            }
            GuestCommand::ListArkTransactions => {
                return GuestResponse::ArkTransactions {
                    entries: self.history.clone(),
                }
            }
            GuestCommand::Snapshot => {
                return match self.to_snapshot() {
                    Ok(blob) => GuestResponse::Snapshot { blob },
                    Err(e) => GuestResponse::Error(e),
                }
            }
            GuestCommand::RestoreSnapshot { blob } => {
                return match self.restore_snapshot(&blob) {
                    Ok(()) => GuestResponse::Restored,
                    Err(e) => GuestResponse::Error(e),
                }
            }
            // SendVtxo is async (it drives ASP gRPC over wasi:http) — routed in the
            // async `handle()`, never reaches this sync dispatcher.
            GuestCommand::SendVtxoStep1(_) | GuestCommand::SendVtxoStep2(_) => {
                return GuestResponse::Error(
                    "SendVtxo must be routed through the async handle(), not handle_command".into(),
                )
            }
            GuestCommand::FrostSignStep1(_)
            | GuestCommand::FrostSignStep2(_)
            | GuestCommand::SettleDelegate { .. }
            | GuestCommand::GenerateDelegate(_)
            | GuestCommand::BoardingSettleStep1 { .. }
            | GuestCommand::BoardingSettleStep2 { .. }
            | GuestCommand::BoardingSettleStep3 { .. } => {
                return GuestResponse::Error(
                    "async commands are routed through handle(), not handle_command".into(),
                )
            }
        };
        result.unwrap_or_else(GuestResponse::Error)
    }

    /// Key-preserving REFRESH of this guest's `V` onto a `{receiver, cosigner}` pairing,
    /// computed entirely in the guest so `V` never leaves it (Plan A). Returns the public
    /// pairing PKP + the receiver's half + the cosigner's pairing key package (the host relays
    /// the latter to seed the pairing actor; it is never persisted host-side).
    fn contract_refresh(
        &mut self,
        receiver_id_hex: &str,
        receiver_partial_point: &[u8],
        wallet_id_hex: &str,
        a_at_cosigner: &[u8],
        min_signers: usize,
    ) -> Result<GuestResponse, String> {
        let policy = self.policy.as_ref().ok_or("no policy installed")?;
        let receiver_id = parse_identifier_hex(receiver_id_hex)?;
        let wallet_id = parse_identifier_hex(wallet_id_hex)?;
        let partial_point: [u8; 33] = receiver_partial_point
            .try_into()
            .map_err(|_| "receiver_partial_point must be 33 bytes")?;
        let a_at_cos: [u8; 32] = a_at_cosigner
            .try_into()
            .map_err(|_| "a_at_cosigner must be 32 bytes")?;

        let mut id_partial_share = BTreeMap::new();
        id_partial_share.insert(wallet_id, a_at_cos);
        let receiver = dkg::Receiver {
            id: receiver_id,
            partial_verifying_share: partial_point,
        };
        let pairing = dkg::refresh_to_receiver(
            &policy.key_package,
            &receiver,
            &id_partial_share,
            min_signers,
            &mut OsRng,
        )
        .map_err(|e| format!("refresh_to_receiver: {e:?}"))?;
        Ok(GuestResponse::ContractRefreshed {
            pairing_public_key_package_json: pairing.pairing_pkp.to_json(),
            receiver_half: pairing.receiver_half.to_vec(),
            my_key_package_json: pairing.my_kp.to_json(),
        })
    }

    #[allow(clippy::too_many_arguments)]
    fn install_policy(
        &mut self,
        group_key: String,
        key_package_json: &str,
        public_key_package_json: &str,
        user_signing_identifier_hex: Option<&str>,
        server_dkg_secret_hex: Option<String>,
        contract_pairing: Option<ContractPairingWire>,
        contracts_json: String,
    ) -> Result<GuestResponse, String> {
        let key_package =
            KeyPackage::from_json(key_package_json).map_err(|e| format!("bad key package: {e}"))?;
        let public_key_package = PublicKeyPackage::from_json(public_key_package_json)
            .map_err(|e| format!("bad public key package: {e}"))?;
        let user_signing_identifier = match user_signing_identifier_hex {
            Some(h) => Some(parse_identifier_hex(h)?),
            None => None,
        };
        self.policy = Some(Policy {
            group_key,
            key_package,
            public_key_package,
            user_signing_identifier,
            contract_pairing: contract_pairing.map(pairing_from_wire).transpose()?,
            contracts_json,
        });
        self.ark_cosigner_secret_hex = server_dkg_secret_hex;
        Ok(GuestResponse::PolicyInstalled)
    }

    /// Return the PUBLIC policy projection the host loads into its `policy_state` after restoring a
    /// cold-spawned guest (Plan A Phase 2: replaces the host `policies` sled tree).
    fn public_policy(&self) -> GuestResponse {
        match self.policy.as_ref() {
            Some(p) => GuestResponse::PublicPolicy {
                group_key: p.group_key.clone(),
                public_key_package_json: p.public_key_package.to_json(),
                user_signing_identifier_hex: p
                    .user_signing_identifier
                    .as_ref()
                    .map(|id| hex::encode(id.serialize())),
                contract_pairing: p.contract_pairing.as_ref().map(pairing_to_wire),
                contracts_json: p.contracts_json.clone(),
            },
            None => GuestResponse::Error("no policy installed".into()),
        }
    }

    /// Return the Ark cosigner MuSig2 pubkey derived from the in-guest secret (for the host's
    /// boarding intent), without the secret leaving the guest.
    fn get_ark_cosigner_pubkey(&self) -> Result<GuestResponse, String> {
        let secret = self
            .ark_cosigner_secret_hex
            .as_deref()
            .ok_or("no Ark cosigner secret installed")?;
        let signer = ark::client::batch::BoardingTreeSigner::new(secret)?;
        Ok(GuestResponse::ArkCosignerPubkey {
            pubkey_hex: signer.cosigner_pubkey_hex(),
        })
    }

    /// Boarding-settle tree-signing step 1 (Plan A Phase 2): build the tx graph from the host's
    /// (public) chunks, generate the secret per-node nonces with the in-guest cosigner key, and
    /// return the public nonce points. The secret nonces stay in the guest for `boarding_tree_sign`.
    fn boarding_gen_nonces(
        &mut self,
        chunks: Vec<TreeTxChunkWire>,
        commitment_psbt_b64: &str,
    ) -> Result<GuestResponse, String> {
        let secret = self
            .ark_cosigner_secret_hex
            .clone()
            .ok_or("no Ark cosigner secret installed")?;
        let mut signer = ark::client::batch::BoardingTreeSigner::new(&secret)?;
        let chunk_tuples: Vec<(String, String, Vec<(u32, String)>)> = chunks
            .into_iter()
            .map(|c| (c.txid, c.psbt_b64, c.children))
            .collect();
        let (cosigner_pk_hex, nonce_map) = signer.gen_nonces(&chunk_tuples, commitment_psbt_b64)?;
        self.boarding_signer = Some(signer);
        Ok(GuestResponse::BoardingNonces {
            cosigner_pk_hex,
            nonce_map,
        })
    }

    /// Boarding-settle tree-signing step 2: MuSig2-sign every tree tx with the in-guest cosigner
    /// key + the nonces held since step 1, then drop the session.
    fn boarding_tree_sign(
        &mut self,
        pending_nonces: Vec<(String, Vec<(String, String)>)>,
        batch_expiry: u32,
        forfeit_pk_hex: &str,
    ) -> Result<GuestResponse, String> {
        let mut signer = self
            .boarding_signer
            .take()
            .ok_or("no boarding signer (call BoardingGenNonces first)")?;
        let (cosigner_pk_hex, sig_map) =
            signer.sign(&pending_nonces, batch_expiry, forfeit_pk_hex)?;
        Ok(GuestResponse::BoardingTreeSigs {
            cosigner_pk_hex,
            sig_map,
        })
    }

    /// The full transaction stored by `sign_step1`, for the step-2 contract-gate check.
    pub fn pending_full_transaction(&self) -> Vec<u8> {
        self.ceremony.full_transaction.clone()
    }

    pub fn sign_step1(&mut self, req: SignStep1Wire) -> Result<GuestResponse, String> {
        auth_check(&req.user_id, &req.signature, req.timestamp_ms, OP_SIGN_STEP1)?;
        let policy = self.policy.as_ref().ok_or("no policy installed")?;
        let user_identifier = policy
            .user_signing_identifier
            .clone()
            .ok_or("policy has no user_signing_identifier")?;
        let server_identifier = policy.key_package.identifier.clone();

        // Key-path (taproot) spends sign under the BIP-341-tweaked key; script-path spends
        // use the raw FROST key. The client tweaks symmetrically based on `script_path_spend`.
        let tweaked = !req.script_path_spend;
        let key_package = if tweaked {
            policy.key_package.tweak(None)
        } else {
            policy.key_package.clone()
        };

        // Plan A 1C: a `{service, cosigner}` pairing actor is AUTHORITATIVE about WHAT it signs.
        // The guest rebuilds the eVTXO cooperative-leaf sighash from its OWN sealed params and binds
        // to it — single-leg (on-chain): OVERRIDE the message with leg 1; two-leg (arkd, `ark_tx`
        // present): require the requested message to be leg 1 OR leg 2. A normal actor signs the
        // requested message. (Replaces the former host-side `pairing_coop_sighash` override.)
        let message = match policy.contract_pairing.as_ref() {
            None => req.message_to_sign.clone(),
            Some(pairing) => {
                let leg1 = crate::conditioning::pairing_coop_sighash(
                    pairing,
                    &policy.public_key_package,
                    &req.full_transaction,
                )?;
                if req.ark_tx.is_empty() {
                    leg1.to_vec()
                } else {
                    let leg2 =
                        crate::conditioning::arktx_leg_sighash(&req.full_transaction, &req.ark_tx)?;
                    if req.message_to_sign == leg1 || req.message_to_sign == leg2 {
                        req.message_to_sign.clone()
                    } else {
                        return Err(
                            "pairing co-sign: message is neither leg-1 nor leg-2 of an eVTXO spend"
                                .into(),
                        );
                    }
                }
            }
        };

        // Fresh round.
        let mut ceremony = Ceremony {
            message,
            tweaked,
            full_transaction: req.full_transaction.clone(),
            ..Default::default()
        };

        let user_comm = commitments_from_bytes(&req.hiding_commitment, &req.binding_commitment)?;
        let mut rng = OsRng;
        let server_nonce = nonce::new_nonce(&mut rng, &key_package.secret_share);
        ceremony
            .commitments
            .insert(server_identifier.clone(), server_nonce.commitments.clone());
        ceremony.commitments.insert(user_identifier, user_comm);
        ceremony.nonce = Some(server_nonce);

        let commitments = ceremony
            .commitments
            .iter()
            .map(|(id, c)| CommitmentWire {
                identifier_hex: hex::encode(id.serialize()),
                hiding: point::serialize_compressed(&c.hiding).to_vec(),
                binding: point::serialize_compressed(&c.binding).to_vec(),
            })
            .collect();
        let message_to_sign = ceremony.message.clone();
        self.ceremony = ceremony;

        Ok(GuestResponse::SignStep1 {
            commitments,
            message_to_sign,
        })
    }

    pub fn sign_step2(&mut self, req: SignStep2Wire) -> Result<GuestResponse, String> {
        auth_check(&req.user_id, &req.signature, req.timestamp_ms, OP_SIGN_STEP2)?;
        let policy = self.policy.as_ref().ok_or("no policy installed")?;
        let user_identifier = policy
            .user_signing_identifier
            .clone()
            .ok_or("policy has no user_signing_identifier")?;
        let server_identifier = policy.key_package.identifier.clone();

        // Match the tweak chosen in step1 (key-path spends sign under the tweaked key).
        let key_package = if self.ceremony.tweaked {
            policy.key_package.tweak(None)
        } else {
            policy.key_package.clone()
        };
        let public_key_package = if self.ceremony.tweaked {
            policy.public_key_package.tweak(None)
        } else {
            policy.public_key_package.clone()
        };

        // Insert the client's signature share.
        let user_s_bytes: [u8; 32] = req
            .signature_share
            .as_slice()
            .try_into()
            .map_err(|_| "signature_share must be 32 bytes")?;
        let user_s = scalar_from_bytes(&user_s_bytes).map_err(|e| format!("bad share scalar: {e}"))?;
        self.ceremony
            .shares
            .insert(user_identifier, SignatureShare { s: user_s });

        // Compute the cosigner's share once (consumes the single-use nonce).
        // NOTE: the `contract-gate` enforcement call belongs here; it is deferred to the
        // Ark/contract migration (the host gate is a no-op for normal spends today).
        if !self.ceremony.shares.contains_key(&server_identifier) {
            let nonce = self
                .ceremony
                .nonce
                .take()
                .ok_or("no signing nonce; call FrostSignStep1 first")?;
            let package =
                SigningPackage::new(self.ceremony.commitments.clone(), self.ceremony.message.clone());
            let share = signing::sign(&package, &nonce, &key_package)
                .map_err(|e| format!("frost sign: {e}"))?;
            self.ceremony.shares.insert(server_identifier, share);
        }

        if self.ceremony.shares.len() < THRESHOLD_COUNT {
            return Err("share count below threshold".into());
        }

        // Aggregate.
        let package =
            SigningPackage::new(self.ceremony.commitments.clone(), self.ceremony.message.clone());
        let signature = signing::aggregate(&package, &self.ceremony.shares, &public_key_package)
            .map_err(|e| format!("frost aggregate: {e}"))?;
        let r_point = point::serialize_compressed(&signature.r).to_vec();
        let z_scalar = scalar_to_bytes(&signature.z).to_vec();

        self.ceremony = Ceremony::default();
        Ok(GuestResponse::SignStep2 { r_point, z_scalar })
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// BIP-340 auth check: timestamp drift + signature over the canonical auth message,
/// verified against the claimed `user_id` (which is also the pubkey).
pub(crate) fn auth_check(
    user_id: &[u8],
    signature: &[u8],
    timestamp_ms: i64,
    operation: &str,
) -> Result<(), String> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| format!("clock error: {e}"))?
        .as_millis() as i64;
    if (now - timestamp_ms).abs() > MAX_TIMESTAMP_DRIFT_MS {
        return Err("request timestamp outside acceptable range".into());
    }
    let user_id_hex = hex::encode(user_id);
    let message = build_auth_message(operation, timestamp_ms, &user_id_hex);
    let pk: [u8; 33] = user_id.try_into().map_err(|_| "user_id must be 33 bytes")?;
    let sig: [u8; 64] = signature.try_into().map_err(|_| "signature must be 64 bytes")?;
    if !threshold::auth::verify_schnorr_signature(&pk, &message, &sig) {
        return Err("invalid authentication signature".into());
    }
    Ok(())
}

fn build_auth_message(operation: &str, timestamp_ms: i64, user_id_hex: &str) -> Vec<u8> {
    use sha2::{Digest, Sha256};
    let msg = format!("{AUTH_PREFIX}:{operation}:{timestamp_ms}:{user_id_hex}");
    Sha256::digest(msg.as_bytes()).to_vec()
}

fn parse_identifier_hex(h: &str) -> Result<Identifier, String> {
    let bytes = hex::decode(h).map_err(|e| format!("bad identifier hex: {e}"))?;
    let arr: [u8; 32] = bytes
        .as_slice()
        .try_into()
        .map_err(|_| "identifier must be 32 bytes")?;
    Identifier::deserialize(&arr).map_err(|e| format!("bad identifier: {e}"))
}

fn arr32(v: &[u8], what: &str) -> Result<[u8; 32], String> {
    v.try_into().map_err(|_| format!("{what} must be 32 bytes"))
}

fn pairing_from_wire(w: ContractPairingWire) -> Result<crate::conditioning::ContractPairing, String> {
    Ok(crate::conditioning::ContractPairing {
        evtxo_spk_hex: w.evtxo_spk_hex,
        contract_id: arr32(&w.contract_id, "contract_id")?,
        server_pk: arr32(&w.server_pk, "server_pk")?,
        owner_pk: arr32(&w.owner_pk, "owner_pk")?,
        exit_delay: w.exit_delay,
    })
}

fn pairing_to_wire(p: &crate::conditioning::ContractPairing) -> ContractPairingWire {
    ContractPairingWire {
        evtxo_spk_hex: p.evtxo_spk_hex.clone(),
        contract_id: p.contract_id.to_vec(),
        server_pk: p.server_pk.to_vec(),
        owner_pk: p.owner_pk.to_vec(),
        exit_delay: p.exit_delay,
    }
}

/// Build the off-chain send transactions (SendVtxoStep1): derive change address, run
/// `SendSession::build`, and return `(session, change_exit_delay, sighashes)`. Pure ark
/// signing-feature math (no I/O); `info` comes from a prior gRPC `GetInfo`.
pub(crate) fn build_send(
    owner_pk_hex: &str,
    vtxos: &[VtxoInputWire],
    req: &SendVtxoStep1Wire,
    info: &ArkInfo,
) -> Result<(SendSession, u32, Vec<Vec<u8>>), String> {
    if vtxos.is_empty() {
        return Err("no VTXOs to send".into());
    }
    let vtxo_inputs: Vec<SendVtxoInput> = vtxos
        .iter()
        .map(|v| SendVtxoInput {
            txid: v.txid.clone(),
            vout: v.vout,
            amount_sats: v.amount_sats,
        })
        .collect();

    let total: u64 = vtxos.iter().map(|v| v.amount_sats).sum();
    if total < req.amount {
        return Err(format!(
            "insufficient balance: have {total}, need {}",
            req.amount
        ));
    }

    let exit_delay = vtxos
        .first()
        .map(|v| v.exit_delay)
        .unwrap_or(info.unilateral_exit_delay as u32);
    let network = ark::client::parse_network(&info.network)?;
    let change_exit_delay = info.unilateral_exit_delay as u32;
    let change_addr = if total > req.amount {
        Some(ark::client::ark_address(
            owner_pk_hex,
            &info.signer_pubkey,
            change_exit_delay,
            network,
        )?)
    } else {
        None
    };

    let (session, sighashes) = SendSession::build(
        owner_pk_hex,
        &vtxo_inputs,
        &req.recipient_ark_address,
        req.amount,
        change_addr.as_deref(),
        exit_delay,
        info,
    )?;
    Ok((
        session,
        change_exit_delay,
        sighashes.iter().map(|s| s.to_vec()).collect(),
    ))
}

fn commitments_from_bytes(hiding: &[u8], binding: &[u8]) -> Result<SigningCommitments, String> {
    let h: [u8; 33] = hiding.try_into().map_err(|_| "hiding must be 33 bytes")?;
    let b: [u8; 33] = binding.try_into().map_err(|_| "binding must be 33 bytes")?;
    Ok(SigningCommitments {
        hiding: point::deserialize_compressed(&h).map_err(|e| format!("bad hiding point: {e}"))?,
        binding: point::deserialize_compressed(&b).map_err(|e| format!("bad binding point: {e}"))?,
    })
}
