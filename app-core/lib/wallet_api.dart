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

  // Signing
  Future<SignStep1Response> signStep1(SignStep1Request request);
  Future<SignStep2Response> signStep2(SignStep2Request request);

  // Refresh
  Future<RefreshStep1Response> refreshStep1(RefreshStep1Request request);
  Future<RefreshStep2Response> refreshStep2(RefreshStep2Request request);
  Future<RefreshStep3Response> refreshStep3(RefreshStep3Request request);

  // Policy
  Future<CreateSpendingPolicyResponse> createSpendingPolicy(
      CreateSpendingPolicyRequest request);
  Future<GetPolicyIdResponse> getPolicyId(GetPolicyIdRequest request);
  Future<UpdatePolicyResponse> updatePolicy(UpdatePolicyRequest request);
  Future<DeletePolicyResponse> deletePolicy(DeletePolicyRequest request);

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

  /// Shutdown the underlying connection.
  Future<void> shutdown();
}
