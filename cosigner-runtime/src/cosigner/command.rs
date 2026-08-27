//! Command enum sent from HTTP handlers to a user's actor task.
//! One variant per RPC, plus stream-fan-in variants from `vtxo_stream`.

use tokio::sync::oneshot;
use tonic::Status;

use crate::wallet_proto::*;

/// Reply channel for an actor command.
pub type Reply<T> = oneshot::Sender<Result<T, Status>>;

/// Output of an in-actor service refresh: the PUBLIC pairing PKP, the receiver's half scalar,
/// and the cosigner's pairing key package (relayed to seed the pairing actor; never persisted
/// host-side).
pub struct ServiceRefreshOutput {
    pub pairing_public_key_package_json: String,
    pub receiver_half: Vec<u8>,
    /// The service's verifying share hex — the `user_id` it presents when signing, and the key
    /// its pairing is filed under in the wallet actor.
    pub service_verifying_share_hex: String,
}

pub enum CosignerCommand {
    // --- Service enrolment: refresh V onto a `{service, cosigner}` pairing inside the actor,
    // so the host never reads V ---
    ServiceRefresh {
        receiver_id_hex: String,
        receiver_partial_point: Vec<u8>,
        wallet_id_hex: String,
        a_at_cosigner: Vec<u8>,
        min_signers: u32,
        service_id: Vec<u8>,

        policy: crate::cosigner::types::ServicePolicy,
        reply: Reply<ServiceRefreshOutput>,
    },
   
    ListServicePairings {
        reply: Reply<Vec<(String, String)>>,
    },
    
    RemoveServicePairing {
        verifying_share_hex: String,
        reply: Reply<bool>,
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

    // --- Request-to-pay ---
    /// Authorize / revoke / list the parties allowed to bill this wallet. Signed by the owner.
    ContactAdd {
        req: ContactAddRequest,
        reply: Reply<ContactAddResponse>,
    },
    ContactRemove {
        req: ContactRemoveRequest,
        reply: Reply<ContactRemoveResponse>,
    },
    ContactList {
        req: ContactListRequest,
        reply: Reply<ContactListResponse>,
    },
    /// Sent by the REQUESTER, routed to the PAYER's actor. `req.user_id` is the requester; the
    /// payer is whichever actor this lands on. The payer's allowlist is the only authorization,
    /// so the handler MUST check it before touching state.
    PaymentRequestCreate {
        req: PaymentRequestCreateRequest,
        reply: Reply<PaymentRequestCreateResponse>,
    },
    /// The payer's own inbox.
    PaymentRequestList {
        req: PaymentRequestListRequest,
        reply: Reply<PaymentRequestListResponse>,
    },
    PaymentRequestDecline {
        req: PaymentRequestDeclineRequest,
        reply: Reply<PaymentRequestDeclineResponse>,
    },

    // --- Policy seeding (onboarding / service enrolment) ---
    /// Install freshly-computed policy material into the actor and seal it into the actor's
    /// snapshot, so the actor owns the keys and every later cold spawn restores them from the
    /// sealed blob (no plaintext key kept host-side). Sent by onboarding right after DKG, and by
    /// service enrolment right after the refresh, via `registry.dispatch`.
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
