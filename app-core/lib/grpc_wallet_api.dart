/// gRPC implementation of [WalletApi] — wraps the generated [MPCWalletClient] stub.
library;

import 'package:grpc/grpc.dart';
import 'package:grpc/src/client/channel.dart' as grpc_base;
import 'package:protocol/protocol.dart';
import 'wallet_api.dart';

class GrpcWalletApi implements WalletApi {
  final MPCWalletClient _stub;
  final grpc_base.ClientChannel _channel;

  GrpcWalletApi(grpc_base.ClientChannel channel)
      : _channel = channel,
        _stub = MPCWalletClient(channel);

  @override
  Future<DKGStep1Response> dKGStep1(DKGStep1Request r) => _stub.dKGStep1(r);
  @override
  Future<DKGStep2Response> dKGStep2(DKGStep2Request r) => _stub.dKGStep2(r);
  @override
  Future<DKGStep3Response> dKGStep3(DKGStep3Request r) => _stub.dKGStep3(r);

  @override
  Future<SignStep1Response> signStep1(SignStep1Request r) => _stub.signStep1(r);
  @override
  Future<SignStep2Response> signStep2(SignStep2Request r) => _stub.signStep2(r);

  @override
  Future<RefreshStep1Response> refreshStep1(RefreshStep1Request r) =>
      _stub.refreshStep1(r);
  @override
  Future<RefreshStep2Response> refreshStep2(RefreshStep2Request r) =>
      _stub.refreshStep2(r);
  @override
  Future<RefreshStep3Response> refreshStep3(RefreshStep3Request r) =>
      _stub.refreshStep3(r);

  @override
  Future<CreateSpendingPolicyResponse> createSpendingPolicy(
          CreateSpendingPolicyRequest r) =>
      _stub.createSpendingPolicy(r);
  @override
  Future<GetPolicyIdResponse> getPolicyId(GetPolicyIdRequest r) =>
      _stub.getPolicyId(r);
  @override
  Future<UpdatePolicyResponse> updatePolicy(UpdatePolicyRequest r) =>
      _stub.updatePolicy(r);
  @override
  Future<DeletePolicyResponse> deletePolicy(DeletePolicyRequest r) =>
      _stub.deletePolicy(r);

  @override
  Future<BroadcastTransactionResponse> broadcastTransaction(
          BroadcastTransactionRequest r) =>
      _stub.broadcastTransaction(r);
  @override
  Future<FetchHistoryResponse> fetchHistory(FetchHistoryRequest r) =>
      _stub.fetchHistory(r);
  @override
  Future<FetchRecentTransactionsResponse> fetchRecentTransactions(
          FetchRecentTransactionsRequest r) =>
      _stub.fetchRecentTransactions(r);

  @override
  Future<GetArkInfoResponse> getArkInfo(GetArkInfoRequest r) =>
      _stub.getArkInfo(r);
  @override
  Future<GetArkAddressResponse> getArkAddress(GetArkAddressRequest r) =>
      _stub.getArkAddress(r);
  @override
  Future<GetBoardingAddressResponse> getBoardingAddress(
          GetBoardingAddressRequest r) =>
      _stub.getBoardingAddress(r);
  @override
  Future<CheckBoardingBalanceResponse> checkBoardingBalance(
          CheckBoardingBalanceRequest r) =>
      _stub.checkBoardingBalance(r);
  @override
  Future<ListVtxosResponse> listVtxos(ListVtxosRequest r) =>
      _stub.listVtxos(r);
  @override
  Future<ListArkTransactionsResponse> listArkTransactions(
          ListArkTransactionsRequest r) =>
      _stub.listArkTransactions(r);
  @override
  Future<SendVtxoResponse> sendVtxo(SendVtxoRequest r) => _stub.sendVtxo(r);
  @override
  Future<RedeemVtxoResponse> redeemVtxo(RedeemVtxoRequest r) =>
      _stub.redeemVtxo(r);
  @override
  Future<SettleResponse> settle(SettleRequest r) => _stub.settle(r);
  @override
  Future<SettleDelegateResponse> settleDelegate(SettleDelegateRequest r) =>
      _stub.settleDelegate(r);
  @override
  Future<SubmitArkSendResponse> submitArkSend(SubmitArkSendRequest r) =>
      _stub.submitArkSend(r);

  /// Server streaming RPC (gRPC only, not part of WalletApi interface).
  Stream<TransactionNotification> subscribeToHistory(
          SubscribeToHistoryRequest r) =>
      _stub.subscribeToHistory(r);

  @override
  Future<void> shutdown() => _channel.shutdown();
}
