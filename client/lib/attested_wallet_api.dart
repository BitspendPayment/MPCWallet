/// Attested REST transport that routes HTTP through the enclave FFI client
/// running in a background isolate (non-blocking).
///
/// Every request is verified against the enclave's attestation document (PCR0)
/// and response signatures are checked (BIP-340 Schnorr).
library;

import 'dart:convert';

import 'enclave/async_enclave.dart';
import 'enclave/native_enclave.dart' show AttestationStatus;
import 'rest_wallet_api.dart';
import 'wallet_api.dart';
import 'package:protocol/protocol.dart';

/// WalletApi implementation that uses the enclave FFI client for attested HTTP.
///
/// Delegates all serialization to [RestWalletApi] but routes HTTP through
/// [AsyncEnclaveClient] for attestation verification + response signing.
/// FFI calls run in a background isolate to avoid blocking the main thread.
class AttestedWalletApi implements WalletApi {
  final AsyncEnclaveClient _enclave;
  final RestWalletApi _inner;

  AttestedWalletApi._(this._enclave, this._inner);

  /// Create an attested wallet API.
  /// Must be called with `await` -- initializes the background isolate.
  static Future<AttestedWalletApi> create(
    String baseUrl, {
    required String expectedPcr0,
    int cacheTtlSecs = 60,
  }) async {
    final enclave = await AsyncEnclaveClient.create(
      baseUrl, expectedPcr0,
      cacheTtlSecs: cacheTtlSecs,
    );
    final inner = RestWalletApi.withPostFn(baseUrl, (path, body) async {
      // Retry once on transient errors (attestation warmup, connection reset).
      for (var attempt = 0; attempt < 2; attempt++) {
        final resp = await enclave.post(path, jsonEncode(body));
        if (resp.error != null || resp.statusCode == 0) {
          if (attempt == 0) {
            print('[AttestedWalletApi] Retrying $path (err: ${resp.error})');
            continue;
          }
          throw Exception(resp.error ?? 'Enclave request failed');
        }
        if (resp.body.isEmpty) {
          throw Exception('Empty response from enclave (HTTP ${resp.statusCode})');
        }
        if (resp.statusCode != 200) {
          try {
            final errBody = jsonDecode(resp.body);
            throw Exception(
                errBody['error'] ?? 'HTTP ${resp.statusCode}: ${resp.body}');
          } catch (e) {
            if (e is Exception) rethrow;
            throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
          }
        }
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Enclave request failed after retries');
    });
    return AttestedWalletApi._(enclave, inner);
  }

  /// Current attestation status for UI display.
  Future<AttestationStatus> getAttestationStatus() =>
      _enclave.getAttestationStatus();

  // Delegate all WalletApi methods to _inner (which uses attested POST).
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
    await _enclave.dispose();
  }
}
