/// Client-side builder for spending an eVTXO's cooperative (contract-gated) leaf
/// on-chain.
///
/// Flow: [build] the spend → hand `psbt` to the cosigner via
/// `client.signWithContext(sighash, evtxoKeyPkg, evtxoPkp, psbt, applyTweak:
/// false)` (the cosigner runs the committed contract and only co-signs on
/// `allow`, selecting its V′ share) → serialize that 64-byte FROST signature →
/// [finalize] with the ASP signer key to assemble the witness → broadcast.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/bindings.dart';
import 'src/ffi_result.dart';

/// A built (unsigned) eVTXO cooperative spend.
class ArkEvtxoSpendSession {
  final int handle;

  /// The taproot script-path sighash the V′ and server legs both sign.
  final Uint8List sighash;

  /// PSBT bytes to pass as `fullTransaction` to the cosigner's sign (carries the
  /// eVTXO `witness_utxo` + the contract args in the proprietary map).
  final Uint8List psbt;

  /// 34-byte eVTXO scriptPubKey (`OP_1 <32>`).
  final Uint8List evtxoScriptPubkey;

  ArkEvtxoSpendSession._({
    required this.handle,
    required this.sighash,
    required this.psbt,
    required this.evtxoScriptPubkey,
  });

  /// Build an on-chain spend of an eVTXO's cooperative leaf via FFI.
  ///
  /// [contractId] is `sha256(component_wasm)`; [serverPk]/[evtxoPk]/[ownerPk]
  /// are 32-byte x-only keys (ASP signer / V′ / main V). [contractArgs] is the
  /// opaque caller data handed to the contract gate (e.g. an oracle token).
  static ArkEvtxoSpendSession build({
    required Uint8List contractId,
    required Uint8List serverPk,
    required Uint8List evtxoPk,
    required Uint8List ownerPk,
    required int exitDelay,
    required String inputTxid,
    required int inputVout,
    required int inputAmountSats,
    required Uint8List outputScriptPubkey,
    required int outputAmountSats,
    Uint8List? contractArgs,
  }) {
    final params = {
      'contract_id': _hexEncode(contractId),
      'server_pk': _hexEncode(serverPk),
      'evtxo_pk': _hexEncode(evtxoPk),
      'owner_pk': _hexEncode(ownerPk),
      'exit_delay': exitDelay,
      'input': {
        'txid': inputTxid,
        'vout': inputVout,
        'amount': inputAmountSats,
      },
      'output': {
        'script_pubkey': _hexEncode(outputScriptPubkey),
        'amount': outputAmountSats,
      },
      if (contractArgs != null) 'contract_args': _hexEncode(contractArgs),
    };

    final paramsPtr = jsonEncode(params).toNativeUtf8();
    try {
      final resultJson = callFfiData(arkBuildEvtxoSpendFfi(paramsPtr.cast()));
      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      return ArkEvtxoSpendSession._(
        handle: result['handle'] as int,
        sighash: Uint8List.fromList(_hexDecode(result['sighash'] as String)),
        psbt: Uint8List.fromList(_hexDecode(result['psbt'] as String)),
        evtxoScriptPubkey:
            Uint8List.fromList(_hexDecode(result['evtxo_spk'] as String)),
      );
    } finally {
      calloc.free(paramsPtr);
    }
  }

  /// Assemble the cooperative-leaf witness from the V′ FROST signature plus a
  /// server-leg signature produced from [signerSk] (the ASP signer secret key;
  /// its x-only pubkey must equal the `serverPk` the spend was built against).
  /// Returns the raw signed transaction hex, ready for `sendrawtransaction`.
  static String finalize({
    required int handle,
    required Uint8List vPrimeSig,
    required Uint8List signerSk,
  }) {
    final vPrimePtr = _hexEncode(vPrimeSig).toNativeUtf8();
    final skPtr = _hexEncode(signerSk).toNativeUtf8();
    try {
      return callFfiData(
          arkFinalizeEvtxoSpendFfi(handle, vPrimePtr.cast(), skPtr.cast()));
    } finally {
      calloc.free(vPrimePtr);
      calloc.free(skPtr);
    }
  }

  /// Free the native session resources.
  static void free(int handle) {
    arkFreeEvtxoSpendFfi(handle);
  }
}

List<int> _hexDecode(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

String _hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
