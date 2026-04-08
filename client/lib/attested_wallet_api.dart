/// Attested REST transport that routes HTTP through the enclave FFI client.
///
/// Every request is verified against the enclave's attestation document (PCR0)
/// and response signatures are checked (BIP-340 Schnorr).
library;

import 'dart:convert';

import 'enclave/native_enclave.dart';
import 'rest_wallet_api.dart';
import 'wallet_api.dart';
import 'package:protocol/protocol.dart';

/// WalletApi implementation that uses the enclave FFI client for attested HTTP.
///
/// Delegates all serialization to [RestWalletApi] but routes HTTP through
/// [NativeEnclaveClient] for attestation verification + response signing.
class AttestedWalletApi implements WalletApi {
  final NativeEnclaveClient _enclave;
  final RestWalletApi _inner;

  AttestedWalletApi(String baseUrl,
      {required String expectedPcr0, int cacheTtlSecs = 60})
      : _enclave = NativeEnclaveClient(baseUrl, expectedPcr0,
            cacheTtlSecs: cacheTtlSecs),
        _inner = RestWalletApi.withPostFn(baseUrl, _placeholder) {
    // Replace the placeholder with the real enclave-backed POST function.
    _inner.customPost = _attestedPost;
  }

  /// Current attestation status for UI display.
  AttestationStatus get attestationStatus => _enclave.attestationStatus;

  Future<Map<String, dynamic>> _attestedPost(
      String path, Map<String, dynamic> body) async {
    final resp = _enclave.post(path, jsonEncode(body));
    if (resp.error != null) {
      throw Exception(resp.error);
    }
    if (resp.statusCode != 200) {
      final errBody = jsonDecode(resp.body);
      throw Exception(errBody['error'] ?? 'HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _placeholder(
          String path, Map<String, dynamic> body) =>
      throw StateError('not initialized');

  // Delegate all WalletApi methods to _inner (which uses our attested POST).
  @override
  Future<DKGStep1Response> dKGStep1(DKGStep1Request r) => _inner.dKGStep1(r);
  @override
  Future<DKGStep2Response> dKGStep2(DKGStep2Request r) => _inner.dKGStep2(r);
  @override
  Future<DKGStep3Response> dKGStep3(DKGStep3Request r) => _inner.dKGStep3(r);
  @override
  Future<SignStep1Response> signStep1(SignStep1Request r) => _inner.signStep1(r);
  @override
  Future<SignStep2Response> signStep2(SignStep2Request r) => _inner.signStep2(r);
  @override
  Future<RefreshStep1Response> refreshStep1(RefreshStep1Request r) => _inner.refreshStep1(r);
  @override
  Future<RefreshStep2Response> refreshStep2(RefreshStep2Request r) => _inner.refreshStep2(r);
  @override
  Future<RefreshStep3Response> refreshStep3(RefreshStep3Request r) => _inner.refreshStep3(r);
  @override
  Future<CreateSpendingPolicyResponse> createSpendingPolicy(CreateSpendingPolicyRequest r) => _inner.createSpendingPolicy(r);
  @override
  Future<GetPolicyIdResponse> getPolicyId(GetPolicyIdRequest r) => _inner.getPolicyId(r);
  @override
  Future<UpdatePolicyResponse> updatePolicy(UpdatePolicyRequest r) => _inner.updatePolicy(r);
  @override
  Future<DeletePolicyResponse> deletePolicy(DeletePolicyRequest r) => _inner.deletePolicy(r);
  @override
  Future<BroadcastTransactionResponse> broadcastTransaction(BroadcastTransactionRequest r) => _inner.broadcastTransaction(r);
  @override
  Future<FetchHistoryResponse> fetchHistory(FetchHistoryRequest r) => _inner.fetchHistory(r);
  @override
  Future<FetchRecentTransactionsResponse> fetchRecentTransactions(FetchRecentTransactionsRequest r) => _inner.fetchRecentTransactions(r);
  @override
  Future<GetArkInfoResponse> getArkInfo(GetArkInfoRequest r) => _inner.getArkInfo(r);
  @override
  Future<GetArkAddressResponse> getArkAddress(GetArkAddressRequest r) => _inner.getArkAddress(r);
  @override
  Future<GetBoardingAddressResponse> getBoardingAddress(GetBoardingAddressRequest r) => _inner.getBoardingAddress(r);
  @override
  Future<CheckBoardingBalanceResponse> checkBoardingBalance(CheckBoardingBalanceRequest r) => _inner.checkBoardingBalance(r);
  @override
  Future<ListVtxosResponse> listVtxos(ListVtxosRequest r) => _inner.listVtxos(r);
  @override
  Future<ListArkTransactionsResponse> listArkTransactions(ListArkTransactionsRequest r) => _inner.listArkTransactions(r);
  @override
  Future<SendVtxoResponse> sendVtxo(SendVtxoRequest r) => _inner.sendVtxo(r);
  @override
  Future<RedeemVtxoResponse> redeemVtxo(RedeemVtxoRequest r) => _inner.redeemVtxo(r);
  @override
  Future<SettleResponse> settle(SettleRequest r) => _inner.settle(r);
  @override
  Future<SettleDelegateResponse> settleDelegate(SettleDelegateRequest r) => _inner.settleDelegate(r);
  @override
  Future<SubmitArkSendResponse> submitArkSend(SubmitArkSendRequest r) => _inner.submitArkSend(r);

  @override
  Future<void> shutdown() async {
    _enclave.dispose();
  }
}
