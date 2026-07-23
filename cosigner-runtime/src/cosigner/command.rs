//! Command enum sent from HTTP handlers to a user's actor task.
//! One variant per RPC, plus stream-fan-in variants from `vtxo_stream`.

use tokio::sync::oneshot;
use tonic::Status;

use crate::wallet_proto::*;

/// Reply channel for an actor command.
pub type Reply<T> = oneshot::Sender<Result<T, Status>>;

/// Output of an in-guest contract refresh (Plan A): the PUBLIC pairing PKP, the receiver's
/// half scalar, and the cosigner's pairing key package (relayed to seed the pairing actor;
/// never persisted host-side).
pub struct ContractRefreshOutput {
    pub pairing_public_key_package_json: String,
    pub receiver_half: Vec<u8>,
    pub my_key_package_json: String,
}

pub enum CosignerCommand {
    // --- Contract create (Plan A: refresh V inside the guest, so the host never reads V) ---
    ContractRefresh {
        receiver_id_hex: String,
        receiver_partial_point: Vec<u8>,
        wallet_id_hex: String,
        a_at_cosigner: Vec<u8>,
        min_signers: u32,
        reply: Reply<ContractRefreshOutput>,
    },
    // --- Signing ---
    // Per-user authentication runs at the REST boundary (`rest_api.rs`), not here — the actor no
    // longer re-checks the request signature/session for these per-user commands.
    SignStep1 {
        req: SignStep1Request,
        reply: Reply<SignStep1Response>,
    },
    SignStep2 {
        req: SignStep2Request,
        reply: Reply<SignStep2Response>,
    },

    // --- Ark ---
    GetArkInfo {
        req: GetArkInfoRequest,
        reply: Reply<GetArkInfoResponse>,
    },
    GetArkAddress {
        req: GetArkAddressRequest,
        reply: Reply<GetArkAddressResponse>,
    },
    GetBoardingAddress {
        req: GetBoardingAddressRequest,
        reply: Reply<GetBoardingAddressResponse>,
    },
    ListVtxos {
        req: ListVtxosRequest,
        reply: Reply<ListVtxosResponse>,
    },
    ListArkTransactions {
        req: ListArkTransactionsRequest,
        reply: Reply<ListArkTransactionsResponse>,
    },
    SendVtxo {
        req: SendVtxoRequest,
        reply: Reply<SendVtxoResponse>,
    },
    RedeemVtxo {
        req: RedeemVtxoRequest,
        reply: Reply<RedeemVtxoResponse>,
    },
    Settle {
        req: SettleRequest,
        reply: Reply<SettleResponse>,
    },
    SettleDelegate {
        req: SettleDelegateRequest,
        reply: Reply<SettleDelegateResponse>,
    },
    SubmitArkSend {
        req: SubmitArkSendRequest,
        reply: Reply<SubmitArkSendResponse>,
    },

    // --- Push registration ---
    RegisterDeviceToken {
        req: RegisterDeviceTokenRequest,
        reply: Reply<RegisterDeviceTokenResponse>,
    },

    // --- Peer-contract share inbox (receiver's own actor) ---
    EvtxoPendingShares {
        req: EvtxoPendingSharesRequest,
        reply: Reply<EvtxoPendingSharesResponse>,
    },
    EvtxoAckShare {
        req: EvtxoAckShareRequest,
        reply: Reply<EvtxoAckShareResponse>,
    },

    // --- Policy seeding (onboarding / contract create) ---
    /// Install freshly-computed policy material into the per-actor guest and seal it into
    /// the guest's snapshot, so the guest owns the keys and every later cold spawn restores
    /// them from the sealed blob (no plaintext key kept host-side). Sent by onboarding (and
    /// contract-create) right after DKG, via `registry.dispatch`.
    SeedPolicy {
        key_package_json: String,
        public_key_package_json: String,
        user_signing_identifier_hex: Option<String>,
        server_dkg_secret_hex: Option<String>,
        /// For a `{service, cosigner}` pairing actor: the eVTXO conditioning params, seeded into
        /// the guest so it rebuilds + binds the cooperative-leaf sighash itself (Plan A 1C).
        contract_pairing: Option<crate::cosigner::types::ContractPairing>,
        reply: Reply<()>,
    },

    /// Add a gate `ContractPolicy` (JSON) to the WALLET actor's sealed `contracts` projection +
    /// re-seal (Plan A: the actor is the single source — no host `policies` tree). Dispatched by
    /// `ContractManager::create_contract`.
    AddContract {
        spk_hex: String,
        contract_policy_json: String,
        reply: Reply<()>,
    },

    // --- Auto-settle ---
    /// Tick from the global 60-second task. The actor checks its stored
    /// delegate intent and submits it if `now > earliest_expires_at - margin`.
    /// Fire-and-forget — errors are logged inside the handler.
    TickAutoSettle,

    // --- Stream fan-in (no reply) ---
    /// VTXO stream notification: union of spent + new entries for a single user.
    /// `user_id_hex` is included so the actor can persist updates without
    /// having to read it from policy state.
    VtxoStreamUpdate {
        user_id_hex: String,
        spent: Vec<ark::client::proto::Vtxo>,
        spendable: Vec<ark::client::proto::Vtxo>,
        info: ark::client::types::ArkInfo,
    },
    /// Indexer subscription event for a single user.
    IndexerUpdate {
        user_id_hex: String,
        new_vtxos: Vec<ark::client::proto::Vtxo>,
        spent_vtxos: Vec<ark::client::proto::Vtxo>,
        info: ark::client::types::ArkInfo,
    },

    /// Stop the actor task. Used during idle eviction or shutdown.
    Shutdown,
}
