//! Command enum sent from HTTP handlers to a user's actor task.
//! One variant per RPC, plus stream-fan-in variants from `vtxo_stream`.

use tokio::sync::oneshot;
use tonic::Status;

use crate::wallet_proto::*;

/// Reply channel for an actor command.
pub type Reply<T> = oneshot::Sender<Result<T, Status>>;

pub enum CosignerCommand {
    // --- Signing ---
    SignStep1 {
        req: SignStep1Request,
        reply: Reply<SignStep1Response>,
    },
    SignStep2 {
        req: SignStep2Request,
        reply: Reply<SignStep2Response>,
    },

    // --- Transactions ---
    BroadcastTransaction {
        req: BroadcastTransactionRequest,
        reply: Reply<BroadcastTransactionResponse>,
    },
    FetchHistory {
        req: FetchHistoryRequest,
        reply: Reply<FetchHistoryResponse>,
    },
    FetchRecentTransactions {
        req: FetchRecentTransactionsRequest,
        reply: Reply<FetchRecentTransactionsResponse>,
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
    CheckBoardingBalance {
        req: CheckBoardingBalanceRequest,
        reply: Reply<CheckBoardingBalanceResponse>,
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
