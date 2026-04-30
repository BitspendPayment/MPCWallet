/// Client-side Ark off-chain send builder.
///
/// Mirrors the Bitcoin on-chain pattern: build tx → compute sighashes →
/// FROST sign → submit via server proxy.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/bindings.dart';
import 'src/ffi_result.dart';

/// Result of building an Ark send transaction.
class ArkSendSession {
  final int handle;
  final List<Uint8List> sighashes;
  final Uint8List arkTxBytes;

  ArkSendSession._({
    required this.handle,
    required this.sighashes,
    required this.arkTxBytes,
  });

  /// Build an off-chain Ark send transaction via FFI.
  ///
  /// Returns a session with sighashes to FROST-sign and the serialized ark tx
  /// bytes (to pass as fullTransaction for policy evaluation).
  static ArkSendSession build({
    required String ownerPk,
    required List<Map<String, dynamic>> vtxoInputs,
    required String recipientArkAddress,
    required int amountSats,
    String? changeArkAddress,
    required int exitDelay,
    required Map<String, dynamic> arkInfo,
  }) {
    final params = {
      'owner_pk': ownerPk,
      'vtxo_inputs': vtxoInputs,
      'recipient_ark_address': recipientArkAddress,
      'amount': amountSats,
      'change_ark_address': changeArkAddress,
      'exit_delay': exitDelay,
      'ark_info': arkInfo,
    };

    final paramsJson = jsonEncode(params);
    final paramsPtr = paramsJson.toNativeUtf8();

    try {
      final resultJson = callFfiData(arkBuildSendTxFfi(paramsPtr.cast()));
      final result = jsonDecode(resultJson) as Map<String, dynamic>;

      final handle = result['handle'] as int;
      final sighashHexes = (result['sighashes'] as List).cast<String>();
      final arkTxHex = result['ark_tx_bytes'] as String;

      final sighashes = sighashHexes
          .map((hex) => Uint8List.fromList(_hexDecode(hex)))
          .toList();
      final arkTxBytes = Uint8List.fromList(_hexDecode(arkTxHex));

      return ArkSendSession._(
        handle: handle,
        sighashes: sighashes,
        arkTxBytes: arkTxBytes,
      );
    } finally {
      calloc.free(paramsPtr);
    }
  }

  /// Insert FROST signatures into the session's PSBTs.
  ///
  /// Returns base64-encoded signed PSBTs ready for server submission.
  static ArkSignedSend insertSignatures(int handle, List<String> signatureHexes) {
    final sigsJson = jsonEncode(signatureHexes);
    final sigsPtr = sigsJson.toNativeUtf8();

    try {
      final resultJson =
          callFfiData(arkInsertSendSignaturesFfi(handle, sigsPtr.cast()));
      final result = jsonDecode(resultJson) as Map<String, dynamic>;

      return ArkSignedSend(
        signedArkTxB64: result['signed_ark_tx_b64'] as String,
        signedCheckpointTxsB64:
            (result['signed_checkpoint_txs_b64'] as List).cast<String>(),
      );
    } finally {
      calloc.free(sigsPtr);
    }
  }

  /// Free the native session resources.
  static void free(int handle) {
    arkFreeSendSessionFfi(handle);
  }
}

/// Signed PSBTs ready for server submission.
class ArkSignedSend {
  final String signedArkTxB64;
  final List<String> signedCheckpointTxsB64;

  ArkSignedSend({
    required this.signedArkTxB64,
    required this.signedCheckpointTxsB64,
  });
}

List<int> _hexDecode(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

