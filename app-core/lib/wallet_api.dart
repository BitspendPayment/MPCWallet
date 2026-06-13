/// Abstract interface for the MPC Wallet server API.
///
/// Implemented by [GrpcWalletApi] (gRPC/HTTP2) and [RestWalletApi] (REST/HTTP1.1).
/// This decouples the client business logic from the transport protocol.
library;

import 'package:protocol/protocol.dart';

abstract class WalletApi {
  // DKG
  Future<DKGStep1Response> dKGStep1(DKGStep1Request request);
  Future<DKGStep2Response> dKGStep2(DKGStep2Request request);
  Future<DKGStep3Response> dKGStep3(DKGStep3Request request);

  // eVTXO key generation (resharing)
  Future<EvtxoKeygenStep1Response> evtxoKeygenStep1(EvtxoKeygenStep1Request request);
  Future<EvtxoKeygenStep2Response> evtxoKeygenStep2(EvtxoKeygenStep2Request request);
  Future<EvtxoKeygenStep3Response> evtxoKeygenStep3(EvtxoKeygenStep3Request request);

  // Multi-user contract onboarding
  Future<EvtxoOnboardResponse> evtxoOnboard(EvtxoOnboardRequest request);
  Future<EvtxoPendingSharesResponse> evtxoPendingShares(EvtxoPendingSharesRequest request);
  Future<EvtxoAckShareResponse> evtxoAckShare(EvtxoAckShareRequest request);

  // Signing
  Future<SignStep1Response> signStep1(SignStep1Request request);
  Future<SignStep2Response> signStep2(SignStep2Request request);

  // Transactions
  Future<BroadcastTransactionResponse> broadcastTransaction(
      BroadcastTransactionRequest request);
  Future<FetchHistoryResponse> fetchHistory(FetchHistoryRequest request);
  Future<FetchRecentTransactionsResponse> fetchRecentTransactions(
      FetchRecentTransactionsRequest request);

  // Ark
  Future<GetArkInfoResponse> getArkInfo(GetArkInfoRequest request);
  Future<GetArkAddressResponse> getArkAddress(GetArkAddressRequest request);
  Future<GetBoardingAddressResponse> getBoardingAddress(
      GetBoardingAddressRequest request);
  Future<CheckBoardingBalanceResponse> checkBoardingBalance(
      CheckBoardingBalanceRequest request);
  Future<ListVtxosResponse> listVtxos(ListVtxosRequest request);
  Future<ListArkTransactionsResponse> listArkTransactions(
      ListArkTransactionsRequest request);
  Future<SendVtxoResponse> sendVtxo(SendVtxoRequest request);
  Future<RedeemVtxoResponse> redeemVtxo(RedeemVtxoRequest request);
  Future<SettleResponse> settle(SettleRequest request);
  Future<SettleDelegateResponse> settleDelegate(
      SettleDelegateRequest request);
  Future<SubmitArkSendResponse> submitArkSend(SubmitArkSendRequest request);

  // Deployment metadata. Unauthenticated.
  Future<GetServerInfoResponse> getServerInfo(GetServerInfoRequest request);

  // Push notifications
  Future<RegisterDeviceTokenResponse> registerDeviceToken(
      RegisterDeviceTokenRequest request);

  /// Shutdown the underlying connection.
  Future<void> shutdown();
}
