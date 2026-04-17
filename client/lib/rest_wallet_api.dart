/// REST/JSON implementation of [WalletApi] — uses HTTP/1.1 POST requests.
///
/// Byte fields are hex-encoded strings in JSON.
/// Works with the server's axum REST API (`--rest-port`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:fixnum/fixnum.dart';
import 'package:protocol/protocol.dart';
import 'wallet_api.dart';

/// Hex encode bytes for JSON.
String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Hex decode string from JSON.
Uint8List _unhex(String? s) {
  if (s == null || s.isEmpty) return Uint8List(0);
  final bytes = <int>[];
  for (var i = 0; i < s.length; i += 2) {
    bytes.add(int.parse(s.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

/// Function type for making HTTP POST requests.
/// Used to allow different HTTP backends (plain http.Client vs enclave FFI).
typedef PostFn = Future<Map<String, dynamic>> Function(
    String path, Map<String, dynamic> body);

class RestWalletApi implements WalletApi {
  final String baseUrl;
  final http.Client? _http;
  PostFn? customPost;

  RestWalletApi(this.baseUrl, {http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        customPost = null;

  /// Create a RestWalletApi with a custom POST function (e.g. enclave FFI).
  RestWalletApi.withPostFn(this.baseUrl, PostFn postFn)
      : _http = null,
        customPost = postFn;

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    if (customPost != null) {
      return customPost!(path, body);
    }
    final resp = await _http!.post(
      Uri.parse('$baseUrl$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      final errBody = jsonDecode(resp.body);
      throw Exception(
          errBody['error'] ?? 'HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Common auth fields present on most requests.
  Map<String, dynamic> _authFields(
      List<int> userId, List<int> signature, Int64 timestampMs) {
    return {
      'user_id': _hex(userId),
      'signature': _hex(signature),
      'timestamp_ms': timestampMs.toInt(),
    };
  }

  // -------------------------------------------------------------------------
  // DKG
  // -------------------------------------------------------------------------

  @override
  Future<DKGStep1Response> dKGStep1(DKGStep1Request r) async {
    final resp = await _post('/api/dkg/step1', {
      'user_id': _hex(r.userId),
      'identifier': _hex(r.identifier),
      'round1_package': r.round1Package,
      'is_restore': r.isRestore,
    });
    return DKGStep1Response()
      ..round1Packages
          .addAll((resp['round1_packages'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v.toString())));
  }

  @override
  Future<DKGStep2Response> dKGStep2(DKGStep2Request r) async {
    final resp = await _post('/api/dkg/step2', {
      'user_id': _hex(r.userId),
      'identifier': _hex(r.identifier),
      'round1_package': r.round1Package,
    });
    return DKGStep2Response()
      ..allRound1Packages
          .addAll((resp['all_round1_packages'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v.toString())));
  }

  @override
  Future<DKGStep3Response> dKGStep3(DKGStep3Request r) async {
    final resp = await _post('/api/dkg/step3', {
      'user_id': _hex(r.userId),
      'identifier': _hex(r.identifier),
      'round2_packages_for_others':
          r.round2PackagesForOthers.map((k, v) => MapEntry(k, v)),
    });
    return DKGStep3Response()
      ..round2PackagesForMe
          .addAll((resp['round2_packages_for_me'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v.toString())));
  }

  // -------------------------------------------------------------------------
  // Signing
  // -------------------------------------------------------------------------

  @override
  Future<SignStep1Response> signStep1(SignStep1Request r) async {
    final resp = await _post('/api/sign/step1', {
      'user_id': _hex(r.userId),
      'hiding_commitment': _hex(r.hidingCommitment),
      'binding_commitment': _hex(r.bindingCommitment),
      'message_to_sign': _hex(r.messageToSign),
      'signature': _hex(r.signature),
      'full_transaction': _hex(r.fullTransaction),
      'timestamp_ms': r.timestampMs.toInt(),
      'script_path_spend': r.scriptPathSpend,
    });
    final result = SignStep1Response()
      ..messageToSign = _unhex(resp['message_to_sign'] as String?)
      ..usedKeyIndex = (resp['used_key_index'] as num?)?.toInt() ?? 0;
    final comms = resp['commitments'] as Map<String, dynamic>? ?? {};
    for (final entry in comms.entries) {
      final c = entry.value as Map<String, dynamic>;
      result.commitments[entry.key] = SignStep1Response_Commitment()
        ..hiding = _unhex(c['hiding'] as String?)
        ..binding = _unhex(c['binding'] as String?);
    }
    return result;
  }

  @override
  Future<SignStep2Response> signStep2(SignStep2Request r) async {
    final resp = await _post('/api/sign/step2', {
      'user_id': _hex(r.userId),
      'signature_share': _hex(r.signatureShare),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return SignStep2Response()
      ..rPoint = _unhex(resp['r_point'] as String?)
      ..zScalar = _unhex(resp['z_scalar'] as String?);
  }

  // -------------------------------------------------------------------------
  // Refresh
  // -------------------------------------------------------------------------

  @override
  Future<RefreshStep1Response> refreshStep1(RefreshStep1Request r) async {
    final resp = await _post('/api/refresh/step1', {
      'user_id': _hex(r.userId),
      'round1_package': r.round1Package,
      'threshold_amount': r.thresholdAmount.toInt(),
      'interval': r.interval.toInt(),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    final result = RefreshStep1Response()
      ..policyId = resp['policy_id'] as String? ?? ''
      ..startTime = Int64(resp['start_time'] as int? ?? 0);
    result.round1Packages
        .addAll((resp['round1_packages'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())));
    return result;
  }

  @override
  Future<RefreshStep2Response> refreshStep2(RefreshStep2Request r) async {
    final resp = await _post('/api/refresh/step2', {
      'user_id': _hex(r.userId),
      'round1_package': r.round1Package,
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return RefreshStep2Response()
      ..allRound1Packages
          .addAll((resp['all_round1_packages'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v.toString())));
  }

  @override
  Future<RefreshStep3Response> refreshStep3(RefreshStep3Request r) async {
    final resp = await _post('/api/refresh/step3', {
      'user_id': _hex(r.userId),
      'round2_packages_for_others':
          r.round2PackagesForOthers.map((k, v) => MapEntry(k, v)),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return RefreshStep3Response()
      ..round2PackagesForMe
          .addAll((resp['round2_packages_for_me'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v.toString())));
  }

  // -------------------------------------------------------------------------
  // Policy
  // -------------------------------------------------------------------------

  @override
  Future<CreateSpendingPolicyResponse> createSpendingPolicy(
      CreateSpendingPolicyRequest r) async {
    final resp = await _post('/api/policy/create', {
      'user_id': _hex(r.userId),
      'threshold_sats': r.thresholdSats.toInt(),
      'start_time': r.startTime.toInt(),
      'interval_seconds': r.intervalSeconds.toInt(),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return CreateSpendingPolicyResponse()
      ..policyId = resp['policy_id'] as String? ?? ''
      ..allocatedKeyIndex = (resp['allocated_key_index'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<GetPolicyIdResponse> getPolicyId(GetPolicyIdRequest r) async {
    final resp = await _post('/api/policy/get-id', {
      'user_id': _hex(r.userId),
      'tx_message': _hex(r.txMessage),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return GetPolicyIdResponse()
      ..policyId = resp['policy_id'] as String? ?? '';
  }

  @override
  Future<UpdatePolicyResponse> updatePolicy(UpdatePolicyRequest r) async {
    final resp = await _post('/api/policy/update', {
      'user_id': _hex(r.userId),
      'policy_id': r.policyId,
      'threshold_sats': r.thresholdSats.toInt(),
      'interval_seconds': r.intervalSeconds.toInt(),
      'frost_signature_r': _hex(r.frostSignatureR),
      'frost_signature_z': _hex(r.frostSignatureZ),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return UpdatePolicyResponse()
      ..success = resp['success'] as bool? ?? false;
  }

  @override
  Future<DeletePolicyResponse> deletePolicy(DeletePolicyRequest r) async {
    final resp = await _post('/api/policy/delete', {
      'user_id': _hex(r.userId),
      'policy_id': r.policyId,
      'frost_signature_r': _hex(r.frostSignatureR),
      'frost_signature_z': _hex(r.frostSignatureZ),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return DeletePolicyResponse()
      ..success = resp['success'] as bool? ?? false;
  }

  // -------------------------------------------------------------------------
  // Transactions
  // -------------------------------------------------------------------------

  @override
  Future<BroadcastTransactionResponse> broadcastTransaction(
      BroadcastTransactionRequest r) async {
    final resp = await _post('/api/tx/broadcast', {
      'user_id': _hex(r.userId),
      'tx_hex': r.txHex,
    });
    return BroadcastTransactionResponse()
      ..txId = resp['tx_id'] as String? ?? '';
  }

  @override
  Future<FetchHistoryResponse> fetchHistory(FetchHistoryRequest r) async {
    final resp = await _post('/api/tx/history', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    final result = FetchHistoryResponse();
    for (final u in (resp['utxos'] as List? ?? [])) {
      result.utxos.add(UtxoInfo()
        ..txHash = u['tx_hash'] as String? ?? ''
        ..vout = (u['vout'] as num?)?.toInt() ?? 0
        ..amount = Int64(u['amount'] as int? ?? 0));
    }
    return result;
  }

  @override
  Future<FetchRecentTransactionsResponse> fetchRecentTransactions(
      FetchRecentTransactionsRequest r) async {
    final resp = await _post('/api/tx/recent', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    final result = FetchRecentTransactionsResponse();
    for (final t in (resp['transactions'] as List? ?? [])) {
      result.transactions.add(TransactionSummary()
        ..txHash = t['tx_hash'] as String? ?? ''
        ..amountSats = Int64(t['amount_sats'] as int? ?? 0)
        ..timestamp = Int64(t['timestamp'] as int? ?? 0)
        ..isPending = t['is_pending'] as bool? ?? false);
    }
    return result;
  }

  // -------------------------------------------------------------------------
  // Ark
  // -------------------------------------------------------------------------

  @override
  Future<GetArkInfoResponse> getArkInfo(GetArkInfoRequest r) async {
    final resp = await _post('/api/ark/info', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    return GetArkInfoResponse()
      ..signerPubkey = resp['signer_pubkey'] as String? ?? ''
      ..forfeitPubkey = resp['forfeit_pubkey'] as String? ?? ''
      ..network = resp['network'] as String? ?? ''
      ..sessionDuration = Int64(resp['session_duration'] as int? ?? 0)
      ..unilateralExitDelay = Int64(resp['unilateral_exit_delay'] as int? ?? 0)
      ..boardingExitDelay = Int64(resp['boarding_exit_delay'] as int? ?? 0)
      ..vtxoMinAmount = Int64(resp['vtxo_min_amount'] as int? ?? 0)
      ..dust = Int64(resp['dust'] as int? ?? 0)
      ..checkpointTapscript = resp['checkpoint_tapscript'] as String? ?? ''
      ..forfeitAddress = resp['forfeit_address'] as String? ?? '';
  }

  @override
  Future<GetArkAddressResponse> getArkAddress(GetArkAddressRequest r) async {
    final resp = await _post('/api/ark/address', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    return GetArkAddressResponse()
      ..arkAddress = resp['ark_address'] as String? ?? '';
  }

  @override
  Future<GetBoardingAddressResponse> getBoardingAddress(
      GetBoardingAddressRequest r) async {
    final resp = await _post('/api/ark/boarding-address', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    return GetBoardingAddressResponse()
      ..boardingAddress = resp['boarding_address'] as String? ?? '';
  }

  @override
  Future<CheckBoardingBalanceResponse> checkBoardingBalance(
      CheckBoardingBalanceRequest r) async {
    final resp = await _post('/api/ark/boarding-balance', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    return CheckBoardingBalanceResponse()
      ..balance = Int64(resp['balance'] as int? ?? 0)
      ..utxoCount = (resp['utxo_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<ListVtxosResponse> listVtxos(ListVtxosRequest r) async {
    final resp = await _post('/api/ark/vtxos', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    final result = ListVtxosResponse()
      ..totalBalance = Int64(resp['total_balance'] as int? ?? 0);
    for (final v in (resp['vtxos'] as List? ?? [])) {
      result.vtxos.add(VtxoInfo()
        ..txid = v['txid'] as String? ?? ''
        ..vout = (v['vout'] as num?)?.toInt() ?? 0
        ..amount = Int64(v['amount'] as int? ?? 0)
        ..createdAt = Int64(v['created_at'] as int? ?? 0)
        ..expiresAt = Int64(v['expires_at'] as int? ?? 0)
        ..status = v['status'] as String? ?? ''
        ..isPreconfirmed = v['is_preconfirmed'] as bool? ?? false
        ..exitDelay = (v['exit_delay'] as num?)?.toInt() ?? 0);
    }
    return result;
  }

  @override
  Future<ListArkTransactionsResponse> listArkTransactions(
      ListArkTransactionsRequest r) async {
    final resp = await _post('/api/ark/transactions', {
      ..._authFields(r.userId, r.signature, r.timestampMs),
    });
    final result = ListArkTransactionsResponse();
    for (final t in (resp['transactions'] as List? ?? [])) {
      result.transactions.add(ArkTransactionSummary()
        ..txType = t['tx_type'] as String? ?? ''
        ..amountSats = Int64(t['amount_sats'] as int? ?? 0)
        ..txid = t['txid'] as String? ?? ''
        ..timestamp = Int64(t['timestamp'] as int? ?? 0));
    }
    return result;
  }

  @override
  Future<SendVtxoResponse> sendVtxo(SendVtxoRequest r) async {
    final resp = await _post('/api/ark/send', {
      'user_id': _hex(r.userId),
      'recipient_ark_address': r.recipientArkAddress,
      'amount': r.amount.toInt(),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
      'signed_messages': r.signedMessages.map((m) => _hex(m)).toList(),
    });
    final result = SendVtxoResponse()
      ..status = SendVtxoResponse_Status.valueOf(
              (resp['status'] as num?)?.toInt() ?? 0) ??
          SendVtxoResponse_Status.SIGNING_REQUIRED
      ..scriptPathSpend = resp['script_path_spend'] as bool? ?? false
      ..arkTxid = resp['ark_txid'] as String? ?? ''
      ..errorMessage = resp['error_message'] as String? ?? ''
      ..policyId = resp['policy_id'] as String? ?? '';
    for (final m in (resp['messages_to_sign'] as List? ?? [])) {
      result.messagesToSign.add(_unhex(m as String?));
    }
    return result;
  }

  @override
  Future<RedeemVtxoResponse> redeemVtxo(RedeemVtxoRequest r) async {
    final resp = await _post('/api/ark/redeem', {
      'user_id': _hex(r.userId),
      'on_chain_address': r.onChainAddress,
      'amount': r.amount.toInt(),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
    });
    return RedeemVtxoResponse()
      ..success = resp['success'] as bool? ?? false
      ..txid = resp['txid'] as String? ?? '';
  }

  @override
  Future<SettleResponse> settle(SettleRequest r) async {
    final resp = await _post('/api/ark/settle', {
      'user_id': _hex(r.userId),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
      'signed_messages': r.signedMessages.map((m) => _hex(m)).toList(),
    });
    final result = SettleResponse()
      ..status = SettleResponse_Status.valueOf(
              (resp['status'] as num?)?.toInt() ?? 0) ??
          SettleResponse_Status.SIGNING_REQUIRED
      ..scriptPathSpend = resp['script_path_spend'] as bool? ?? false
      ..commitmentTxid = resp['commitment_txid'] as String? ?? ''
      ..errorMessage = resp['error_message'] as String? ?? '';
    for (final m in (resp['messages_to_sign'] as List? ?? [])) {
      result.messagesToSign.add(_unhex(m as String?));
    }
    return result;
  }

  @override
  Future<SettleDelegateResponse> settleDelegate(
      SettleDelegateRequest r) async {
    final resp = await _post('/api/ark/settle-delegate', {
      'user_id': _hex(r.userId),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
      'signed_messages': r.signedMessages.map((m) => _hex(m)).toList(),
    });
    final result = SettleDelegateResponse()
      ..status = SettleDelegateResponse_Status.valueOf(
              (resp['status'] as num?)?.toInt() ?? 0) ??
          SettleDelegateResponse_Status.SIGNING_REQUIRED
      ..scriptPathSpend = resp['script_path_spend'] as bool? ?? false
      ..commitmentTxid = resp['commitment_txid'] as String? ?? ''
      ..errorMessage = resp['error_message'] as String? ?? '';
    for (final m in (resp['messages_to_sign'] as List? ?? [])) {
      result.messagesToSign.add(_unhex(m as String?));
    }
    return result;
  }

  @override
  Future<SubmitArkSendResponse> submitArkSend(SubmitArkSendRequest r) async {
    final resp = await _post('/api/ark/submit-send', {
      'user_id': _hex(r.userId),
      'signature': _hex(r.signature),
      'timestamp_ms': r.timestampMs.toInt(),
      'signed_ark_tx_b64': r.signedArkTxB64,
      'signed_checkpoint_txs_b64': r.signedCheckpointTxsB64,
      'spent_outpoints': r.spentOutpoints,
    });
    return SubmitArkSendResponse()
      ..arkTxid = resp['ark_txid'] as String? ?? ''
      ..changeTxid = resp['change_txid'] as String? ?? ''
      ..changeVout = (resp['change_vout'] as num?)?.toInt() ?? 0
      ..changeAmount = Int64(resp['change_amount'] as int? ?? 0);
  }

  @override
  Future<void> shutdown() async {
    _http?.close();
  }
}
