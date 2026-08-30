import 'dart:typed_data';

import 'package:app_core/ark/ark_send.dart';
import 'package:app_core/client.dart';
import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:convert/convert.dart';

/// An unsigned Ark off-chain transaction, ready for policy check and signing.
class UnsignedArkTransaction {
  final int sessionHandle;
  final List<Uint8List> sighashes;
  final Uint8List arkTxBytes;
  final List<String> spentOutpoints;

  /// PSBT to pass to the cosigner as `fullTransaction` (== arkTxBytes for normal
  /// sends).
  final Uint8List gateTxBytes;

  UnsignedArkTransaction({
    required this.sessionHandle,
    required this.sighashes,
    required this.arkTxBytes,
    required this.spentOutpoints,
    Uint8List? gateTxBytes,
  }) : gateTxBytes = gateTxBytes ?? arkTxBytes;

  /// Free the native FFI session. Call if signing is skipped (e.g. user cancels).
  void dispose() => ArkSendSession.free(sessionHandle);
}

/// A signed Ark transaction ready for submission to the ASP via server proxy.
class SignedArkTransaction {
  final String signedArkTxB64;
  final List<String> signedCheckpointTxsB64;
  final List<String> spentOutpoints;

  SignedArkTransaction({
    required this.signedArkTxB64,
    required this.signedCheckpointTxsB64,
    required this.spentOutpoints,
  });
}

/// Ark wallet that mirrors [MpcBitcoinWallet]'s build → policy → sign → submit pattern.
class MpcArkWallet {
  final MpcClient client;

  MpcArkWallet(this.client);

  /// Builds an unsigned Ark off-chain send transaction via FFI.
  ///
  /// Fetches ArkInfo, VTXOs, and change address from the server,
  /// then builds the transaction client-side.
  Future<UnsignedArkTransaction> createTransaction({
    required String destination,
    required int amountSats,
  }) async {
    final ownerPk = client.groupXOnlyPubKey;
    if (ownerPk == null) {
      throw StateError('Group key not available, cannot create Ark transaction.');
    }
    print('[MpcArkWallet] ownerPk (group x-only): $ownerPk');
    print('[MpcArkWallet] userId: ${client.userId}');

    final arkInfo = await client.getArkInfo();
    final vtxosResp = await client.listVtxos();
    if (vtxosResp.vtxos.isEmpty) {
      throw Exception('No VTXOs available for sending');
    }

    final changeAddr = await client.getArkAddress();

    // Each input carries its OWN exit_delay — a boarded VTXO keeps the
    // boarding delay while received/refreshed ones use the unilateral delay,
    // so a wallet naturally spends a mixed set.
    final vtxoInputs = vtxosResp.vtxos
        .map((v) => {
              'txid': v.txid,
              'vout': v.vout,
              'amount': v.amount.toInt(),
              'exit_delay': v.exitDelay.toInt(),
            })
        .toList();

    final arkInfoMap = {
      'signer_pubkey': arkInfo.signerPubkey,
      'forfeit_pubkey': arkInfo.forfeitPubkey,
      'forfeit_address': arkInfo.forfeitAddress,
      'checkpoint_tapscript': arkInfo.checkpointTapscript,
      'network': arkInfo.network,
      'session_duration': arkInfo.sessionDuration.toInt(),
      'unilateral_exit_delay': arkInfo.unilateralExitDelay.toInt(),
      'boarding_exit_delay': arkInfo.boardingExitDelay.toInt(),
      'vtxo_min_amount': arkInfo.vtxoMinAmount.toInt(),
      'dust': arkInfo.dust.toInt(),
    };

    final session = ArkSendSession.build(
      ownerPk: ownerPk,
      vtxoInputs: vtxoInputs,
      recipientArkAddress: destination,
      amountSats: amountSats,
      changeArkAddress: changeAddr,
      // Fallback only — every input above carries its own exit_delay.
      exitDelay: arkInfo.unilateralExitDelay.toInt(),
      arkInfo: arkInfoMap,
    );

    final spentOutpoints =
        vtxosResp.vtxos.map((v) => '${v.txid}:${v.vout}').toList();

    return UnsignedArkTransaction(
      sessionHandle: session.handle,
      sighashes: session.sighashes,
      arkTxBytes: session.arkTxBytes,
      spentOutpoints: spentOutpoints,
    );
  }

  /// FROST-signs each sighash and inserts signatures into the PSBTs.
  Future<SignedArkTransaction> signTransaction(
    UnsignedArkTransaction unsigned,
  ) async {
    try {
      final sigHexes = <String>[];
      for (final sighash in unsigned.sighashes) {
        final sig = await client.sign(
          sighash,
          fullTransaction: unsigned.arkTxBytes,
          applyTweak: false,
        );

        final rBytes = threshold.elemSerializeCompressed(sig.R);
        final xOnly = rBytes.sublist(1);
        final zBytes = threshold.bigIntToBytes(sig.Z);

        final schnorrSig = Uint8List(64);
        schnorrSig.setRange(0, 32, xOnly);
        schnorrSig.setRange(32, 64, zBytes);

        sigHexes.add(hex.encode(schnorrSig));
      }

      final signed =
          ArkSendSession.insertSignatures(unsigned.sessionHandle, sigHexes);

      return SignedArkTransaction(
        signedArkTxB64: signed.signedArkTxB64,
        signedCheckpointTxsB64: signed.signedCheckpointTxsB64,
        spentOutpoints: unsigned.spentOutpoints,
      );
    } finally {
      ArkSendSession.free(unsigned.sessionHandle);
    }
  }

  /// Submits signed PSBTs to the ASP via the server proxy.
  Future<String> submit(SignedArkTransaction signed) async {
    return await client.submitArkSend(
      signedArkTxB64: signed.signedArkTxB64,
      signedCheckpointTxsB64: signed.signedCheckpointTxsB64,
      spentOutpoints: signed.spentOutpoints,
    );
  }


}
