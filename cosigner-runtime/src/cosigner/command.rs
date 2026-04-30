//! Command enum sent from HTTP handlers to a user's actor task.
//! One variant per RPC, plus stream-fan-in variants from `vtxo_stream`.

use tokio::sync::oneshot;
use tonic::Status;

use crate::wallet_proto::*;

/// Reply channel for an actor command.
pub type Reply<T> = oneshot::Sender<Result<T, Status>>;

pub enum CosignerCommand {
    // --- DKG ---
    DkgStep1 { req: DkgStep1Request, reply: Reply<DkgStep1Response> },
    DkgStep2 { req: DkgStep2Request, reply: Reply<DkgStep2Response> },
    DkgStep3 { req: DkgStep3Request, reply: Reply<DkgStep3Response> },

    // --- Signing ---
    SignStep1 { req: SignStep1Request, reply: Reply<SignStep1Response> },
    SignStep2 { req: SignStep2Request, reply: Reply<SignStep2Response> },

    // --- Refresh ---
    RefreshStep1 { req: RefreshStep1Request, reply: Reply<RefreshStep1Response> },
    RefreshStep2 { req: RefreshStep2Request, reply: Reply<RefreshStep2Response> },
    RefreshStep3 { req: RefreshStep3Request, reply: Reply<RefreshStep3Response> },

    // --- Policy ---
    CreateSpendingPolicy { req: CreateSpendingPolicyRequest, reply: Reply<CreateSpendingPolicyResponse> },
    GetPolicyId { req: GetPolicyIdRequest, reply: Reply<GetPolicyIdResponse> },
    UpdatePolicy { req: UpdatePolicyRequest, reply: Reply<UpdatePolicyResponse> },
    DeletePolicy { req: DeletePolicyRequest, reply: Reply<DeletePolicyResponse> },

    // --- Transactions ---
    BroadcastTransaction { req: BroadcastTransactionRequest, reply: Reply<BroadcastTransactionResponse> },
    FetchHistory { req: FetchHistoryRequest, reply: Reply<FetchHistoryResponse> },
    FetchRecentTransactions { req: FetchRecentTransactionsRequest, reply: Reply<FetchRecentTransactionsResponse> },

    // --- Ark ---
    GetArkInfo { req: GetArkInfoRequest, reply: Reply<GetArkInfoResponse> },
    GetArkAddress { req: GetArkAddressRequest, reply: Reply<GetArkAddressResponse> },
    GetBoardingAddress { req: GetBoardingAddressRequest, reply: Reply<GetBoardingAddressResponse> },
    CheckBoardingBalance { req: CheckBoardingBalanceRequest, reply: Reply<CheckBoardingBalanceResponse> },
    ListVtxos { req: ListVtxosRequest, reply: Reply<ListVtxosResponse> },
    ListArkTransactions { req: ListArkTransactionsRequest, reply: Reply<ListArkTransactionsResponse> },
    SendVtxo { req: SendVtxoRequest, reply: Reply<SendVtxoResponse> },
    RedeemVtxo { req: RedeemVtxoRequest, reply: Reply<RedeemVtxoResponse> },
    Settle { req: SettleRequest, reply: Reply<SettleResponse> },
    SettleDelegate { req: SettleDelegateRequest, reply: Reply<SettleDelegateResponse> },
    SubmitArkSend { req: SubmitArkSendRequest, reply: Reply<SubmitArkSendResponse> },

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
