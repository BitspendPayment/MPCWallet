//! The native, in-process per-user cosigner actor — holds the signing keys, the FROST
//! ceremony, the Ark sessions, and its own ASP connection. Driven by the `run_cosigner` task.
//! The only WASM left is the untrusted contract (run by the native `ContractHost`).
//! (Merged from the former core/{mod,flows,conditioning}.rs.)




use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use rand::rngs::OsRng;
use zeroize::Zeroizing;

use crate::cosigner::wire::{
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

use crate::shared::SharedServices;

// Auth message format — must match the host (`auth/message.rs`) and the Dart client.
const AUTH_PREFIX: &str = "MPC_WALLET_AUTH_V1";
const OP_SIGN_STEP1: &str = "SIGN_STEP1";
const OP_SIGN_STEP2: &str = "SIGN_STEP2";
pub(crate) const OP_SEND_VTXO: &str = "SEND_VTXO";
pub(crate) const OP_SETTLE_DELEGATE: &str = "SETTLE_DELEGATE";
const MAX_TIMESTAMP_DRIFT_MS: i64 = 5 * 60 * 1000;
const THRESHOLD_COUNT: usize = 2;

/// An installed signing policy. The cosigner's own key share + the group public key, plus the
/// client's FROST identifier (the other half of the 2-of-2).
struct Policy {
    group_key: String,
    key_package: KeyPackage,
    public_key_package: PublicKeyPackage,
    user_signing_identifier: Option<Identifier>,
    /// Set ONLY for a `{service, cosigner}` pairing actor: the core then rebuilds + binds the
    /// cooperative-leaf sighash itself in `sign_step1` (Plan A 1C). `None` for a normal wallet.
    contract_pairing: Option< ContractPairing>,
    /// The wallet's contract registry as JSON (kept so the sealed snapshot is the single source of
    /// the public projection). Empty string ⇒ no contracts.
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
    /// The full transaction being signed (from step1), passed to the contract gate in step2
    /// before the cosigner produces its share.
    full_transaction: Vec<u8>,
}

pub struct CosignerActor {
    policy: Option<Policy>,
    ceremony: Ceremony,
    /// In-flight off-chain send: `(session, change_exit_delay)`.
    send_session: Option<(SendSession, u32)>,
    /// A `ReadyToSettle` delegate session the core can drive autonomously (auto-settle).
    delegate_session: Option<DelegateSettleSession>,
    /// In-flight boarding tree-signer: holds the secret per-node nonces between `BoardingGenNonces`
    /// and `BoardingTreeSign`.
    boarding_signer: Option<ark::client::batch::BoardingTreeSigner>,
    /// In-flight GUEST-style boarding settle, held across the commitment-FROST pause (the client
    /// must FROST-sign the commitment sighashes between step 2 and step 3). Native: no held stream
    /// (step 3 finalizes optimistically). Transient — never snapshotted.
    boarding_settle: Option<BoardingSettleInFlight>,
    /// The Ark cosigner (MuSig2) secret, hex — zeroized on drop. Used for tree signing.
    ark_cosigner_secret_hex: Option<Zeroizing<String>>,
    /// The owned spendable VTXO set.
    vtxos: Vec<VtxoInputWire>,
    /// The owned Ark transaction history (display log; non-secret).
    history: Vec<ArkTxEntryWire>,
    /// Global services (contract gate + ASP url). Held so `command()` is a drop-in for the old
    /// `GuestInstance::command` — no per-call-site `shared` threading.
    shared: Arc<SharedServices>,
    /// This actor's OWN ASP connection (lazily connected, reused across commands). Per-actor — like
    /// the guest's per-instance h2 connection — so one actor's long settle never serializes another's
    /// ASP access (important multi-tenant: the single shared `AspClient` lock would bottleneck).
    asp: Option<ark::client::AspClient>,
}

/// In-flight boarding settle, held across the commitment-FROST pause (the client FROST-signs the
/// commitment sighashes between step 2 and step 3). Unlike the guest, native tonic CAN hold the
/// event stream across the pause, so step 3 drives to BatchFinalized — ensuring the new VTXO is
/// settled + ASP-indexed before returning (an immediate send must find it).
pub struct BoardingSettleInFlight {
    pub session: ark::client::batch::SettleSession,
    pub signer: ark::client::batch::BoardingTreeSigner,
    pub amount_sats: u64,
    pub stream: Option<tonic::Streaming<ark::client::proto::GetEventStreamResponse>>,
}

impl CosignerActor {
    pub fn new(shared: Arc<SharedServices>) -> Self {
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
            shared,
            asp: None,
        }
    }

    /// Serialize durable state (policy + Ark secret + VTXOs + history) into the sealed-snapshot blob.
    /// In-flight sessions are excluded (transient; MuSig2 nonces must never persist).
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
            ark_cosigner_secret_hex: self.ark_secret().map(|s| s.to_string()),
            contract_pairing: policy.contract_pairing.as_ref().map(pairing_to_wire),
            contracts_json: policy.contracts_json.clone(),
            vtxos: self.vtxos.clone(),
            history: self.history.clone(),
            // Persist a ReadyToSettle delegate (to_persisted errors for other phases → None).
            delegate_json: self
                .delegate_session
                .as_ref()
                .and_then(|s| s.to_persisted().ok())
                .and_then(|p| serde_json::to_string(&p).ok()),
        };
        serde_json::to_vec(&snap).map_err(|e| format!("snapshot serialize: {e}"))
    }

    /// Restore durable state from a snapshot blob (on actor spawn / reseat).
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
        self.ark_cosigner_secret_hex = snap.ark_cosigner_secret_hex.map(Zeroizing::new);
        self.vtxos = snap.vtxos;
        self.history = snap.history;
        // Restore a pending ReadyToSettle delegate (needs the cosigner secret to re-derive its kp).
        self.delegate_session = match (snap.delegate_json, self.ark_secret()) {
            (Some(dj), Some(secret)) => {
                let persisted: PersistedDelegate = serde_json::from_str(&dj)
                    .map_err(|e| format!("parse persisted delegate: {e}"))?;
                Some(DelegateSettleSession::from_persisted(&persisted, secret)?)
            }
            _ => None,
        };
        Ok(())
    }

    /// The MuSig2 secret (hex), if installed.
    pub(crate) fn ark_secret(&self) -> Option<&str> {
        self.ark_cosigner_secret_hex.as_ref().map(|z| z.as_str())
    }

    pub fn ark_cosigner_secret_hex(&self) -> Option<&str> {
        self.ark_secret()
    }

    /// The owned VTXO set.
    pub fn vtxos(&self) -> &[VtxoInputWire] {
        &self.vtxos
    }

    pub fn set_vtxos(&mut self, vtxos: Vec<VtxoInputWire>) {
        self.vtxos = vtxos;
    }

    /// Apply a completed send to the owned VTXO set: the send spent all current VTXOs; re-add the
    /// change `(txid, vout, amount, exit_delay)` if any.
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

    /// The wallet's group x-only pubkey (hex) — the VTXO owner key, from the installed policy's PKP.
    pub fn owner_pk_hex(&self) -> Result<String, String> {
        let policy = self.policy.as_ref().ok_or("no policy installed")?;
        let vk = policy.public_key_package.verifying_key.serialize(); // [u8; 33]
        Ok(hex::encode(&vk[1..]))
    }

    // --- delegate-session accessors (the async settle/auto-settle flow drives these) ---
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

    // --- send-session accessors (the async send flow drives these) ---
    pub fn set_send_session(&mut self, session: SendSession, change_exit_delay: u32) {
        self.send_session = Some((session, change_exit_delay));
    }

    /// SendVtxoStep2 part 1: insert the client's FROST signatures and produce the
    /// `(signed_ark_tx_b64, unsigned_checkpoint_b64s)` to submit to the ASP.
    pub fn send_sign_and_prepare(
        &mut self,
        signatures: Vec<[u8; 64]>,
    ) -> Result<(String, Vec<String>), String> {
        let (session, _) = self.send_session.as_mut().ok_or("no send session")?;
        session.sign_with_frost(signatures)?;
        session.prepare_submit()
    }

    /// SendVtxoStep2 part 2: counter-sign the ASP-returned checkpoints.
    pub fn send_finalize_checkpoints(
        &self,
        signed_checkpoint_txs_b64: &[String],
    ) -> Result<Vec<String>, String> {
        let (session, _) = self.send_session.as_ref().ok_or("no send session")?;
        session.finalize_checkpoints(signed_checkpoint_txs_b64)
    }

    /// The change VTXO `(txid, vout, amount_sats, exit_delay)` of the in-flight send, if any.
    pub fn send_change_vtxo(&self) -> Option<(String, u32, u64, u32)> {
        self.send_session.as_ref().and_then(|(session, change_exit_delay)| {
            session
                .change_vtxo()
                .map(|(txid, vout, amount)| (txid, vout, amount, *change_exit_delay))
        })
    }

    pub fn send_done(&mut self) {
        if let Some((session, _)) = self.send_session.as_mut() {
            session.mark_done();
        }
        self.send_session = None;
    }

    /// Delegate phase 2: auth, then insert the client's FROST signatures into the stored delegate
    /// session (→ `ReadyToSettle`). Sync (no I/O).
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
        let session = self.delegate_session.as_mut().ok_or("no delegate session")?;
        session.sign_with_frost(signatures)?;
        Ok(GuestResponse::DelegateReady)
    }

    /// Handle one SYNC command, in-process. Async commands (SendVtxo, GenerateDelegate,
    /// SettleDelegate, BoardingSettle{2,3}) are routed by `command()` to the async flows instead.
    pub fn handle(&mut self, cmd: GuestCommand) -> GuestResponse {
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
            GuestCommand::FrostSignStep1(req) => self.sign_step1(req),
            GuestCommand::FrostSignStep2(req) => {
                // Plan A: enforce the bound contract (native `ContractHost`) over the full tx BEFORE
                // producing the cosigner's share — on Deny we refuse. No-op for non-contract spends.
                let full_tx = self.pending_full_transaction();
                if let Err(e) =
                    crate::cosigner::handlers::contract_gate::enforce_contracts(&self.shared, &full_tx)
                {
                    return GuestResponse::Error(format!("contract gate denied: {}", e.message()));
                }
                self.sign_step2(req)
            }
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
            // Boarding settle step 1 is sync (build the session from the public scan + ASP info).
            GuestCommand::BoardingSettleStep1 {
                owner_pk_hex,
                signer_pubkey,
                forfeit_pubkey,
                boarding_address,
                boarding_txid,
                boarding_vout,
                boarding_amount_sats,
                exit_delay,
                network,
            } => self.boarding_settle_step1(
                &owner_pk_hex,
                &signer_pubkey,
                &forfeit_pubkey,
                &boarding_address,
                &boarding_txid,
                boarding_vout,
                boarding_amount_sats,
                exit_delay,
                &network,
            ),
            // Async flows are driven by the actor's async methods, never this dispatcher.
            GuestCommand::SendVtxoStep1(_)
            | GuestCommand::SendVtxoStep2(_)
            | GuestCommand::GenerateDelegate(_)
            | GuestCommand::SettleDelegate { .. }
            | GuestCommand::BoardingSettleStep2 { .. }
            | GuestCommand::BoardingSettleStep3 { .. } => {
                return GuestResponse::Error(
                    "async command must be driven by the actor's async path, not handle()".into(),
                )
            }
        };
        result.unwrap_or_else(GuestResponse::Error)
    }

    /// Key-preserving REFRESH of this core's `V` onto a `{receiver, cosigner}` pairing, computed
    /// in-process so `V` never leaves it (Plan A). Returns the public pairing PKP + the receiver's
    /// half + the cosigner's pairing key package (the host relays the latter to seed the pairing
    /// actor; it is never persisted host-side).
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
        self.ark_cosigner_secret_hex = server_dkg_secret_hex.map(Zeroizing::new);
        Ok(GuestResponse::PolicyInstalled)
    }

    /// Return the PUBLIC policy projection the host loads into its `policy_state`.
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

    /// Return the Ark cosigner MuSig2 pubkey derived from the in-core secret (for the boarding
    /// intent), without the secret leaving the core.
    fn get_ark_cosigner_pubkey(&self) -> Result<GuestResponse, String> {
        let secret = self.ark_secret().ok_or("no Ark cosigner secret installed")?;
        let signer = ark::client::batch::BoardingTreeSigner::new(secret)?;
        Ok(GuestResponse::ArkCosignerPubkey {
            pubkey_hex: signer.cosigner_pubkey_hex(),
        })
    }

    /// Boarding-settle tree-signing step 1: build the tx graph from the (public) chunks, generate the
    /// secret per-node nonces with the in-core cosigner key, and return the public nonce points.
    fn boarding_gen_nonces(
        &mut self,
        chunks: Vec<TreeTxChunkWire>,
        commitment_psbt_b64: &str,
    ) -> Result<GuestResponse, String> {
        let secret = self
            .ark_secret()
            .ok_or("no Ark cosigner secret installed")?
            .to_string();
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

    /// Boarding-settle tree-signing step 2: MuSig2-sign every tree tx with the in-core cosigner key +
    /// the nonces held since step 1, then drop the session.
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
        let (cosigner_pk_hex, sig_map) = signer.sign(&pending_nonces, batch_expiry, forfeit_pk_hex)?;
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

        // Key-path (taproot) spends sign under the BIP-341-tweaked key; script-path spends use the
        // raw FROST key. The client tweaks symmetrically based on `script_path_spend`.
        let tweaked = !req.script_path_spend;
        let key_package = if tweaked {
            policy.key_package.tweak(None)
        } else {
            policy.key_package.clone()
        };

        // Plan A 1C: a `{service, cosigner}` pairing actor is AUTHORITATIVE about WHAT it signs. The
        // core rebuilds the eVTXO cooperative-leaf sighash from its OWN sealed params and binds to it
        // — single-leg (on-chain): OVERRIDE the message with leg 1; two-leg (arkd, `ark_tx` present):
        // require the requested message to be leg 1 OR leg 2. A normal actor signs the requested msg.
        let message = match policy.contract_pairing.as_ref() {
            None => req.message_to_sign.clone(),
            Some(pairing) => {
                let leg1 =  pairing_coop_sighash(
                    pairing,
                    &policy.public_key_package,
                    &req.full_transaction,
                )?;
                if req.ark_tx.is_empty() {
                    leg1.to_vec()
                } else {
                    let leg2 =  arktx_leg_sighash(&req.full_transaction, &req.ark_tx)?;
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

/// BIP-340 auth check: timestamp drift + signature over the canonical auth message, verified
/// against the claimed `user_id` (which is also the pubkey).
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

fn pairing_from_wire(w: ContractPairingWire) -> Result< ContractPairing, String> {
    Ok( ContractPairing {
        evtxo_spk_hex: w.evtxo_spk_hex,
        contract_id: arr32(&w.contract_id, "contract_id")?,
        server_pk: arr32(&w.server_pk, "server_pk")?,
        owner_pk: arr32(&w.owner_pk, "owner_pk")?,
        exit_delay: w.exit_delay,
    })
}

fn pairing_to_wire(p: & ContractPairing) -> ContractPairingWire {
    ContractPairingWire {
        evtxo_spk_hex: p.evtxo_spk_hex.clone(),
        contract_id: p.contract_id.to_vec(),
        server_pk: p.server_pk.to_vec(),
        owner_pk: p.owner_pk.to_vec(),
        exit_delay: p.exit_delay,
    }
}

/// Build the off-chain send transactions (SendVtxoStep1): derive change address, run
/// `SendSession::build`, and return `(session, change_exit_delay, sighashes)`. Pure ark signing math
/// (no I/O); `info` comes from a prior gRPC `GetInfo`.
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
        return Err(format!("insufficient balance: have {total}, need {}", req.amount));
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

use ark::client::batch::{DelegateOutput, DelegateVtxoInput, SettleAction};
use ark::client::proto::get_event_stream_response::Event;
use ark::client::AspClient;

use crate::cosigner::wire::{GenerateDelegateWire, SendVtxoStep2Wire};


fn sigs_from_wire(wire: &[Vec<u8>]) -> Result<Vec<[u8; 64]>, String> {
    wire.iter()
        .map(|v| {
            <[u8; 64]>::try_from(v.as_slice())
                .map_err(|_| "signature must be 64 bytes".to_string())
        })
        .collect()
}

impl CosignerActor {
    /// Drop-in replacement for the old `GuestInstance::command`: dispatch one command in-process.
    /// Sync commands go to `handle`; the Ark flows lock the shared `AspClient` and drive natively.
    /// Infallible at the transport layer (always `Ok`) — callers' `Err` arms are dead but harmless.
    pub async fn command(&mut self, cmd: crate::cosigner::wire::GuestCommand) -> anyhow::Result<GuestResponse> {
        use crate::cosigner::wire::GuestCommand as C;
        // The Ark flows borrow this actor's OWN ASP connection: take it out (disjoint from `self`),
        // run the flow, put it back. No shared lock → no cross-actor serialization.
        let resp = match cmd {
            C::SendVtxoStep1(req) => match self.take_asp().await {
                Ok(mut asp) => {
                    let r = self.send_vtxo_step1(req, &mut asp).await;
                    self.asp = Some(asp);
                    r
                }
                Err(e) => e,
            },
            C::SendVtxoStep2(req) => match self.take_asp().await {
                Ok(mut asp) => {
                    let r = self.send_vtxo_step2(req, &mut asp).await;
                    self.asp = Some(asp);
                    r
                }
                Err(e) => e,
            },
            C::GenerateDelegate(req) => match self.take_asp().await {
                Ok(mut asp) => {
                    let r = self.generate_delegate(req, &mut asp).await;
                    self.asp = Some(asp);
                    r
                }
                Err(e) => e,
            },
            C::SettleDelegate { .. } => match self.take_asp().await {
                Ok(mut asp) => {
                    let r = self.settle_delegate(&mut asp).await;
                    self.asp = Some(asp);
                    r
                }
                Err(e) => e,
            },
            C::BoardingSettleStep2 { intent_signatures, .. } => match self.take_asp().await {
                Ok(mut asp) => {
                    let r = self.boarding_settle_step2(intent_signatures, &mut asp).await;
                    self.asp = Some(asp);
                    r
                }
                Err(e) => e,
            },
            C::BoardingSettleStep3 { commitment_signatures, .. } => match self.take_asp().await {
                Ok(mut asp) => {
                    let r = self.boarding_settle_step3(commitment_signatures, &mut asp).await;
                    self.asp = Some(asp);
                    r
                }
                Err(e) => e,
            },
            other => self.handle(other),
        };
        Ok(resp)
    }

    /// Take this actor's ASP connection (connecting lazily on first use). The caller puts it back
    /// after the flow so it's reused across commands.
    async fn take_asp(&mut self) -> Result<AspClient, GuestResponse> {
        if let Some(a) = self.asp.take() {
            return Ok(a);
        }
        let url = self
            .shared
            .asp_url
            .clone()
            .ok_or_else(|| GuestResponse::Error("ASP not configured (set ASP_URL)".into()))?;
        AspClient::connect(&url)
            .await
            .map_err(|e| GuestResponse::Error(format!("ASP connect: {e}")))
    }

    /// Boarding settle step 1 (sync): build the boarding session + tree-signer from the host's
    /// (public) scan + ASP info, hold it in flight, and return the intent-proof sighashes to sign.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn boarding_settle_step1(
        &mut self,
        owner_pk_hex: &str,
        signer_pubkey: &str,
        forfeit_pubkey: &str,
        boarding_address: &str,
        boarding_txid: &str,
        boarding_vout: u32,
        boarding_amount_sats: u64,
        exit_delay: u32,
        network: &str,
    ) -> Result<GuestResponse, String> {
        let secret = self
            .ark_cosigner_secret_hex()
            .ok_or("no Ark cosigner secret installed")?
            .to_string();
        let signer = ark::client::batch::BoardingTreeSigner::new(&secret)?;
        let cosigner_pk_hex = signer.cosigner_pubkey_hex();
        let (session, sighashes) = ark::client::batch::SettleSession::new_boarding(
            owner_pk_hex,
            signer_pubkey,
            forfeit_pubkey,
            boarding_address,
            boarding_txid,
            boarding_vout,
            boarding_amount_sats,
            exit_delay,
            network,
            &cosigner_pk_hex,
        )
        .map_err(|e| format!("new_boarding: {e}"))?;
        self.boarding_settle = Some(BoardingSettleInFlight {
            session,
            signer,
            amount_sats: boarding_amount_sats,
            stream: None,
        });
        Ok(GuestResponse::BoardingSettleSighashes {
            messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
        })
    }

    /// Delegate phase 1: build the pre-authorized intent + forfeit PSBTs (after `GetInfo`) and return
    /// the sighashes the client must FROST-sign. The Ark cosigner secret never leaves the core.
    pub(crate) async fn generate_delegate(
        &mut self,
        req: GenerateDelegateWire,
        asp: &mut AspClient,
    ) -> GuestResponse {
        if let Err(e) = auth_check(
            &req.user_id,
            &req.signature,
            req.timestamp_ms,
            OP_SETTLE_DELEGATE,
        ) {
            return GuestResponse::Error(e);
        }
        let (owner_pk_hex, cosigner_secret_hex, vtxos) = {
            let owner = match self.owner_pk_hex() {
                Ok(o) => o,
                Err(e) => return GuestResponse::Error(e),
            };
            let secret = match self.ark_cosigner_secret_hex() {
                Some(s) => s.to_string(),
                None => return GuestResponse::Error("no Ark cosigner secret installed".into()),
            };
            (owner, secret, self.vtxos().to_vec())
        };

        let info = match asp.get_info().await {
            Ok(i) => i,
            Err(e) => return GuestResponse::Error(format!("GetInfo: {e}")),
        };

        if vtxos.is_empty() {
            return GuestResponse::Error("no VTXOs to settle".into());
        }
        let vtxo_inputs: Vec<DelegateVtxoInput> = vtxos
            .iter()
            .map(|v| DelegateVtxoInput {
                txid: v.txid.clone(),
                vout: v.vout,
                amount_sats: v.amount_sats,
                is_swept: false,
            })
            .collect();

        let input_exit_delay = vtxos[0].exit_delay;
        if vtxos.iter().any(|v| v.exit_delay != input_exit_delay) {
            return GuestResponse::Error("cannot settle VTXOs with mixed exit_delays".into());
        }

        let network = match ark::client::parse_network(&info.network) {
            Ok(n) => n,
            Err(e) => return GuestResponse::Error(e),
        };
        let total: u64 = vtxos.iter().map(|v| v.amount_sats).sum();
        let owner_ark_address = match ark::client::ark_address(
            &owner_pk_hex,
            &info.signer_pubkey,
            info.unilateral_exit_delay as u32,
            network,
        ) {
            Ok(a) => a,
            Err(e) => return GuestResponse::Error(format!("ark_address: {e}")),
        };
        let outputs = vec![DelegateOutput {
            ark_address: owner_ark_address,
            amount_sats: total,
        }];

        match DelegateSettleSession::generate_delegate(
            &owner_pk_hex,
            &info.signer_pubkey,
            &info.forfeit_pubkey,
            &cosigner_secret_hex,
            &vtxo_inputs,
            &outputs,
            &info.forfeit_address,
            info.dust as u64,
            input_exit_delay,
            &info.network,
            req.intent_valid_at,
        ) {
            Ok((session, sighashes)) => {
                self.set_delegate_session(session);
                GuestResponse::DelegateSighashes {
                    messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                }
            }
            Err(e) => GuestResponse::Error(format!("generate_delegate: {e}")),
        }
    }

    /// Drive a delegate/auto-settle batch: register the pre-authorized intent, open the ASP event
    /// stream, and run the MuSig2 tree-signing + forfeit loop to completion. Requires an installed
    /// `ReadyToSettle` delegate session. Each arm runs a sync (secret-using) session step then an
    /// `asp.*().await` — `self` and `asp` are disjoint, no held cross-await borrow.
    pub(crate) async fn settle_delegate(&mut self, asp: &mut AspClient) -> GuestResponse {
        let (proof, message, topics) = match self
            .delegate_session_ref()
            .ok_or_else(|| "no delegate session installed".to_string())
            .and_then(|s| s.register_payload())
        {
            Ok(v) => v,
            Err(e) => return GuestResponse::Error(e),
        };

        let intent_id = match asp.register_intent(proof, message).await {
            Ok(id) => id,
            Err(e) => return GuestResponse::Error(format!("RegisterIntent: {e}")),
        };
        let mut stream = match asp.get_event_stream(topics).await {
            Ok(s) => s,
            Err(e) => return GuestResponse::Error(format!("GetEventStream: {e}")),
        };

        loop {
            let resp = match stream.message().await {
                Ok(Some(r)) => r,
                Ok(None) => return GuestResponse::Error("event stream ended unexpectedly".into()),
                Err(e) => return GuestResponse::Error(format!("event stream: {e}")),
            };
            let Some(event) = resp.event else { continue };
            match event {
                Event::BatchStarted(e) => {
                    if let Err(e) = self.delegate_session_mut().ok_or_else(|| "no delegate session".to_string()).and_then(|s| s.on_batch_started(e)) {
                        return GuestResponse::Error(e);
                    }
                    if let Err(e) = asp.confirm_registration(intent_id.clone()).await {
                        return GuestResponse::Error(format!("ConfirmRegistration: {e}"));
                    }
                }
                Event::TreeTx(e) => {
                    if let Err(e) = self.delegate_session_mut().ok_or_else(|| "no delegate session".to_string()).and_then(|s| s.on_tree_tx(e)) {
                        return GuestResponse::Error(e);
                    }
                }
                Event::TreeSigningStarted(e) => {
                    let (batch_id, pubkey, tree_nonces) =
                        match self.delegate_session_mut().ok_or_else(|| "no delegate session".to_string()).and_then(|s| s.on_tree_signing_started(e)) {
                            Ok(v) => v,
                            Err(e) => return GuestResponse::Error(e),
                        };
                    if let Err(e) = asp.submit_tree_nonces(&batch_id, pubkey, tree_nonces).await {
                        return GuestResponse::Error(format!("SubmitTreeNonces: {e}"));
                    }
                }
                Event::TreeNonces(e) => {
                    let maybe = match self.delegate_session_mut().ok_or_else(|| "no delegate session".to_string()).and_then(|s| s.on_tree_nonces(e)) {
                        Ok(v) => v,
                        Err(e) => return GuestResponse::Error(e),
                    };
                    if let Some((batch_id, pubkey, tree_signatures)) = maybe {
                        if let Err(e) =
                            asp.submit_tree_signatures(&batch_id, pubkey, tree_signatures).await
                        {
                            return GuestResponse::Error(format!("SubmitTreeSignatures: {e}"));
                        }
                    }
                }
                Event::BatchFinalization(e) => {
                    let maybe = match self.delegate_session_mut().ok_or_else(|| "no delegate session".to_string()).and_then(|s| s.on_batch_finalization(e)) {
                        Ok(v) => v,
                        Err(e) => return GuestResponse::Error(e),
                    };
                    if let Some(signed_forfeit_txs) = maybe {
                        if let Err(e) = asp
                            .submit_signed_forfeit_txs(signed_forfeit_txs, String::new())
                            .await
                        {
                            return GuestResponse::Error(format!("SubmitSignedForfeitTxs: {e}"));
                        }
                    }
                }
                Event::BatchFinalized(e) => {
                    let finalized = self.delegate_session_mut().map(|s| s.on_batch_finalized(e));
                    self.clear_delegate_session();
                    return match finalized {
                        Some((commitment_txid, vtxo_outpoint)) => GuestResponse::SettleSubmitted {
                            commitment_txid,
                            vtxo_outpoint,
                        },
                        None => GuestResponse::Error("no delegate session at finalize".into()),
                    };
                }
                Event::BatchFailed(e) => {
                    return GuestResponse::Error(format!("batch failed: {}", e.reason))
                }
                _ => {}
            }
        }
    }

    /// Boarding settle step 2: insert the intent FROST sigs, RegisterIntent + open the event stream,
    /// drive the batch (tree-signing in-core) to BatchFinalization, and return the commitment
    /// sighashes (the pause — the client FROST-signs them, then calls step 3). The stream is dropped
    /// at the pause; step 3 finalizes optimistically.
    pub(crate) async fn boarding_settle_step2(
        &mut self,
        intent_sigs_wire: Vec<Vec<u8>>,
        asp: &mut AspClient,
    ) -> GuestResponse {
        let intent_sigs = match sigs_from_wire(&intent_sigs_wire) {
            Ok(s) => s,
            Err(e) => return GuestResponse::Error(e),
        };
        let inflight = match self.boarding_settle.as_mut() {
            Some(b) => b,
            None => return GuestResponse::Error("no boarding settle in flight".into()),
        };
        if let Err(e) = inflight.session.insert_intent_signatures(intent_sigs) {
            return GuestResponse::Error(e);
        }
        let (proof, message, topics) = match inflight.session.register_payload() {
            Ok(v) => v,
            Err(e) => return GuestResponse::Error(e),
        };
        let intent_id = match asp.register_intent(proof, message).await {
            Ok(id) => id,
            Err(e) => return GuestResponse::Error(format!("RegisterIntent: {e}")),
        };
        let mut stream = match asp.get_event_stream(topics).await {
            Ok(s) => s,
            Err(e) => return GuestResponse::Error(format!("GetEventStream: {e}")),
        };

        // Drive to BatchFinalization, returning the commitment sighashes (the pause).
        loop {
            let resp = match stream.message().await {
                Ok(Some(r)) => r,
                Ok(None) => return GuestResponse::Error("event stream ended unexpectedly".into()),
                Err(e) => return GuestResponse::Error(format!("event stream: {e}")),
            };
            let Some(event) = resp.event else { continue };
            let inflight = self.boarding_settle.as_mut().unwrap();
            match event {
                Event::BatchStarted(e) => {
                    if let Err(e) = inflight.session.on_batch_started(e) {
                        return GuestResponse::Error(e);
                    }
                    if let Err(e) = asp.confirm_registration(intent_id.clone()).await {
                        return GuestResponse::Error(format!("ConfirmRegistration: {e}"));
                    }
                }
                Event::TreeTx(e) => {
                    if let Err(e) = inflight.session.handle_tree_tx(e) {
                        return GuestResponse::Error(e);
                    }
                }
                Event::TreeSigningStarted(e) => {
                    match inflight.session.on_tree_signing_started(e) {
                        Ok(SettleAction::NeedTreeNonces {
                            tree_tx_chunks,
                            commitment_psbt_b64,
                        }) => {
                            let (pubkey, nonce_map) =
                                match inflight.signer.gen_nonces(&tree_tx_chunks, &commitment_psbt_b64) {
                                    Ok(v) => v,
                                    Err(e) => return GuestResponse::Error(e),
                                };
                            let batch_id = inflight.session.batch_id();
                            if let Err(e) = asp
                                .submit_tree_nonces(&batch_id, pubkey, nonce_map.into_iter().collect())
                                .await
                            {
                                return GuestResponse::Error(format!("SubmitTreeNonces: {e}"));
                            }
                        }
                        Ok(_) => {}
                        Err(e) => return GuestResponse::Error(e),
                    }
                }
                Event::TreeNonces(e) => {
                    match inflight.session.on_tree_nonces(e) {
                        Ok(Some(SettleAction::NeedTreeSign {
                            pending_nonces,
                            batch_expiry,
                            forfeit_pk_hex,
                        })) => {
                            let (pubkey, sig_map) =
                                match inflight.signer.sign(&pending_nonces, batch_expiry, &forfeit_pk_hex) {
                                    Ok(v) => v,
                                    Err(e) => return GuestResponse::Error(e),
                                };
                            let batch_id = inflight.session.batch_id();
                            if let Err(e) = asp
                                .submit_tree_signatures(&batch_id, pubkey, sig_map.into_iter().collect())
                                .await
                            {
                                return GuestResponse::Error(format!("SubmitTreeSignatures: {e}"));
                            }
                        }
                        Ok(_) => {}
                        Err(e) => return GuestResponse::Error(e),
                    }
                }
                Event::BatchFinalization(e) => {
                    return match inflight.session.handle_batch_finalization(e) {
                        Ok(sighashes) => {
                            // Hold the open stream across the pause; step 3 drives it to BatchFinalized.
                            inflight.stream = Some(stream);
                            GuestResponse::BoardingSettleSighashes {
                                messages_to_sign: sighashes.iter().map(|s| s.to_vec()).collect(),
                            }
                        }
                        Err(e) => GuestResponse::Error(e),
                    };
                }
                Event::BatchFinalized(_) => {
                    return GuestResponse::Error("batch finalized before commitment signing".into())
                }
                Event::BatchFailed(e) => {
                    return GuestResponse::Error(format!("batch failed: {}", e.reason))
                }
                _ => {}
            }
        }
    }

    /// Boarding settle step 3: insert the commitment FROST sigs, submit the signed commitment, and
    /// finalize optimistically — returning the new VTXO.
    pub(crate) async fn boarding_settle_step3(
        &mut self,
        commitment_sigs_wire: Vec<Vec<u8>>,
        asp: &mut AspClient,
    ) -> GuestResponse {
        let commitment_sigs = match sigs_from_wire(&commitment_sigs_wire) {
            Ok(s) => s,
            Err(e) => return GuestResponse::Error(e),
        };
        let mut inflight = match self.boarding_settle.take() {
            Some(b) => b,
            None => return GuestResponse::Error("no boarding settle in flight".into()),
        };
        let signed_commitment_b64 = match inflight.session.insert_commitment_signatures(commitment_sigs)
        {
            Ok(v) => v,
            Err(e) => return GuestResponse::Error(e),
        };
        if let Err(e) = asp
            .submit_signed_forfeit_txs(vec![], signed_commitment_b64)
            .await
        {
            return GuestResponse::Error(format!("SubmitSignedForfeitTxs: {e}"));
        }
        // Drive the held event stream to BatchFinalized so the new VTXO is settled + ASP-indexed
        // before we return — an immediate send must find it (the optimistic txid is already correct;
        // this just waits for the batch to commit).
        if let Some(mut stream) = inflight.stream.take() {
            loop {
                match stream.message().await {
                    Ok(Some(resp)) => match resp.event {
                        Some(Event::BatchFinalized(_)) => break,
                        Some(Event::BatchFailed(e)) => {
                            return GuestResponse::Error(format!("batch failed: {}", e.reason))
                        }
                        _ => continue,
                    },
                    Ok(None) => break,
                    Err(e) => return GuestResponse::Error(format!("event stream: {e}")),
                }
            }
        }
        let (commitment_txid, vtxo) = match inflight.session.finalize_optimistic() {
            Ok(v) => v,
            Err(e) => return GuestResponse::Error(e),
        };
        let (vtxo_txid, vtxo_vout) = vtxo.unwrap_or_else(|| (commitment_txid.clone(), 0));
        GuestResponse::BoardingSettleSubmitted {
            commitment_txid,
            vtxo_txid,
            vtxo_vout,
            amount_sats: inflight.amount_sats,
        }
    }

    /// SendVtxo phase 1: build the off-chain send tx (after `GetInfo`) and return the sighashes the
    /// client must FROST-sign.
    pub(crate) async fn send_vtxo_step1(
        &mut self,
        req: SendVtxoStep1Wire,
        asp: &mut AspClient,
    ) -> GuestResponse {
        if let Err(e) = auth_check(&req.user_id, &req.signature, req.timestamp_ms, OP_SEND_VTXO) {
            return GuestResponse::Error(e);
        }
        let (owner_pk_hex, vtxos) = match self.owner_pk_hex() {
            Ok(owner) => (owner, self.vtxos().to_vec()),
            Err(e) => return GuestResponse::Error(e),
        };
        let info = match asp.get_info().await {
            Ok(i) => i,
            Err(e) => return GuestResponse::Error(format!("GetInfo: {e}")),
        };
        match build_send(&owner_pk_hex, &vtxos, &req, &info) {
            Ok((session, change_exit_delay, sighashes)) => {
                self.set_send_session(session, change_exit_delay);
                GuestResponse::SendVtxoSighashes {
                    messages_to_sign: sighashes,
                }
            }
            Err(e) => GuestResponse::Error(format!("build send: {e}")),
        }
    }

    /// SendVtxo phase 2: insert the client's signatures, then submit + finalize via the ASP.
    pub(crate) async fn send_vtxo_step2(
        &mut self,
        req: SendVtxoStep2Wire,
        asp: &mut AspClient,
    ) -> GuestResponse {
        if let Err(e) = auth_check(&req.user_id, &req.signature, req.timestamp_ms, OP_SEND_VTXO) {
            return GuestResponse::Error(e);
        }
        let signatures = match sigs_from_wire(&req.signed_messages) {
            Ok(s) => s,
            Err(e) => return GuestResponse::Error(e),
        };

        let (ark_b64, checkpoints) = match self.send_sign_and_prepare(signatures) {
            Ok(x) => x,
            Err(e) => return GuestResponse::Error(format!("prepare submit: {e}")),
        };

        let submit = match asp.submit_tx(ark_b64, checkpoints).await {
            Ok(r) => r,
            Err(e) => return GuestResponse::Error(format!("SubmitTx: {e}")),
        };

        let final_checkpoints = match self.send_finalize_checkpoints(&submit.signed_checkpoint_txs) {
            Ok(c) => c,
            Err(e) => return GuestResponse::Error(format!("finalize checkpoints: {e}")),
        };

        if let Err(e) = asp
            .finalize_tx(submit.ark_txid.clone(), final_checkpoints)
            .await
        {
            return GuestResponse::Error(format!("FinalizeTx: {e}"));
        }

        let change = {
            let change = self.send_change_vtxo();
            self.send_done();
            self.apply_send_change(change.clone());
            change
        };
        GuestResponse::SendVtxoSubmitted {
            ark_txid: submit.ark_txid,
            change,
        }
    }
}

use bitcoin::hashes::Hash;
use bitcoin::sighash::{Prevouts, SighashCache};
use bitcoin::taproot::LeafVersion;
use bitcoin::{TapLeafHash, TapSighashType};
use sha2::{Digest, Sha256};

/// Binds a pairing actor to the single eVTXO it may co-sign. All params needed to rebuild the
/// cooperative-leaf script (and thus the script-path sighash), carried in via `install_policy` and
/// sealed in the snapshot.
#[derive(Clone, Debug)]
pub struct ContractPairing {
    pub evtxo_spk_hex: String,
    pub contract_id: [u8; 32],
    pub server_pk: [u8; 32],
    pub owner_pk: [u8; 32],
    pub exit_delay: u32,
}

/// LEG 1: the cooperative-leaf script-path sighash of the input that spends this actor's eVTXO.
/// The leaf is rebuilt from the cosigner's own registration params (NOT the client PSBT scripts),
/// so the only thing this can ever produce a signature over is a spend of its own eVTXO. `pkp` is
/// the pairing PKP (its group key is `V`, the cooperative key). Errs if the spend doesn't touch it.
pub fn pairing_coop_sighash(
    pairing: &ContractPairing,
    pkp: &PublicKeyPackage,
    full_transaction: &[u8],
) -> Result<[u8; 32], String> {
    let psbt =
        bitcoin::Psbt::deserialize(full_transaction).map_err(|e| format!("not a PSBT: {e}"))?;

    let prevouts: Vec<bitcoin::TxOut> = psbt
        .inputs
        .iter()
        .map(|i| {
            i.witness_utxo.clone().unwrap_or_else(|| bitcoin::TxOut {
                value: bitcoin::Amount::from_sat(0),
                script_pubkey: bitcoin::ScriptBuf::new(),
            })
        })
        .collect();
    let input_idx = prevouts
        .iter()
        .position(|p| hex::encode(p.script_pubkey.as_bytes()) == pairing.evtxo_spk_hex)
        .ok_or("service pairing may only co-sign a spend of its own eVTXO")?;

    let commit: [u8; 32] = Sha256::digest(pairing.contract_id).into();
    let evtxo_pk = threshold::point::serialize_x_only(&pkp.verifying_key.point);
    let (coop_script, _cb) = ark::evtxo_cooperative_spend_info(
        &commit,
        &pairing.server_pk,
        &evtxo_pk,
        &pairing.owner_pk,
        pairing.exit_delay,
    )
    .ok_or("evtxo_cooperative_spend_info failed")?;
    let coop_script_buf = bitcoin::ScriptBuf::from_bytes(coop_script);

    let leaf_hash = TapLeafHash::from_script(&coop_script_buf, LeafVersion::TapScript);
    let sighash = SighashCache::new(&psbt.unsigned_tx)
        .taproot_script_spend_signature_hash(
            input_idx,
            &Prevouts::All(&prevouts),
            leaf_hash,
            TapSighashType::Default,
        )
        .map_err(|e| format!("coop sighash: {e}"))?;
    Ok(sighash.to_byte_array())
}

/// LEG 2 (service spend THROUGH arkd): the script-path sighash of the `ark_tx` input that spends an
/// OUTPUT of the verified `checkpoint_tx`. We don't re-derive ark-core's protocol; we CHAIN leg 2
/// to leg 1 — the `ark_tx` input's prevout must be an output of the same checkpoint leg 1 verified
/// spends the eVTXO. That binds the bundle to the eVTXO. The checkpoint output is `V`+server and
/// arkd validates the ark_tx independently, so taking the leaf from the PSBT is safe.
pub fn arktx_leg_sighash(checkpoint_tx: &[u8], ark_tx: &[u8]) -> Result<[u8; 32], String> {
    let cp = bitcoin::Psbt::deserialize(checkpoint_tx)
        .map_err(|e| format!("checkpoint not a PSBT: {e}"))?;
    let at = bitcoin::Psbt::deserialize(ark_tx).map_err(|e| format!("ark_tx not a PSBT: {e}"))?;
    let cp_txid = cp.unsigned_tx.compute_txid();

    let prevouts: Vec<bitcoin::TxOut> = at
        .inputs
        .iter()
        .map(|i| {
            i.witness_utxo
                .clone()
                .ok_or_else(|| "ark_tx input missing witness_utxo".to_string())
        })
        .collect::<Result<_, _>>()?;

    let idx = at
        .unsigned_tx
        .input
        .iter()
        .enumerate()
        .find_map(|(i, txin)| {
            if txin.previous_output.txid != cp_txid {
                return None;
            }
            let cp_out = cp.unsigned_tx.output.get(txin.previous_output.vout as usize)?;
            (prevouts.get(i)?.script_pubkey == cp_out.script_pubkey).then_some(i)
        })
        .ok_or("ark_tx does not spend the verified checkpoint's output")?;

    let input = &at.inputs[idx];
    let leaf_hash = input
        .tap_script_sigs
        .keys()
        .next()
        .map(|(_, lh)| *lh)
        .or_else(|| {
            input
                .tap_scripts
                .values()
                .next()
                .map(|(script, ver)| TapLeafHash::from_script(script, *ver))
        })
        .ok_or("ark_tx input has no tap leaf")?;

    let sighash = SighashCache::new(&at.unsigned_tx)
        .taproot_script_spend_signature_hash(
            idx,
            &Prevouts::All(&prevouts),
            leaf_hash,
            TapSighashType::Default,
        )
        .map_err(|e| format!("ark_tx sighash: {e}"))?;
    Ok(sighash.to_byte_array())
}
