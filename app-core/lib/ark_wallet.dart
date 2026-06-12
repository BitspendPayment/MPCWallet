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
  /// sends; the checkpoint PSBT for an eVTXO spend, so the gate fires + V′ is used).
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
    // Use per-VTXO exit_delay (boarding vs refreshed VTXOs have different delays).
    // All VTXOs in a send should be the same type; use the first one's delay.
    final exitDelay = vtxosResp.vtxos.first.exitDelay;
    print('[MpcArkWallet] exitDelay: $exitDelay (per-VTXO, vs unilateral=${arkInfo.unilateralExitDelay})');

    final vtxoInputs = vtxosResp.vtxos
        .map((v) {
          print('[MpcArkWallet] VTXO from server: ${v.txid}:${v.vout} amount=${v.amount} exit_delay=${v.exitDelay}');
          return {
              'txid': v.txid,
              'vout': v.vout,
              'amount': v.amount.toInt(),
            };
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
      exitDelay: exitDelay,
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

  /// Build an off-chain send that spends a contract **eVTXO** input through arkd:
  /// the cooperative (`ConditionMultisigClosure`) leaf, signed by V′ (gated by the
  /// cosigner) + co-signed by arkd's `server_pk`. The eVTXO must already be an
  /// arkd-tracked VTXO (mint it first with a normal send to its Ark address).
  /// `contractId` = sha256(wasm); `evtxoPk` = V′ x-only; `exitDelay` must match
  /// the value the eVTXO was created with.
  Future<UnsignedArkTransaction> createEvtxoSpend({
    required String destination,
    required int amountSats,
    required String inputTxid,
    required int inputVout,
    required int inputAmountSats,
    required Uint8List contractId,
    required Uint8List evtxoPk,
    required int exitDelay,
    Uint8List? contractArgs,
  }) async {
    final ownerPk = client.groupXOnlyPubKey;
    if (ownerPk == null) {
      throw StateError('Group key not available, cannot spend eVTXO.');
    }
    final arkInfo = await client.getArkInfo();
    var serverPkHex = arkInfo.signerPubkey;
    if (serverPkHex.length == 66) serverPkHex = serverPkHex.substring(2);

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

    final vtxoInputs = [
      {
        'txid': inputTxid,
        'vout': inputVout,
        'amount': inputAmountSats,
        'evtxo': {
          'contract_id': hex.encode(contractId),
          'server_pk': serverPkHex,
          'evtxo_pk': hex.encode(evtxoPk),
          'owner_pk': ownerPk,
          'exit_delay': exitDelay,
          if (contractArgs != null) 'contract_args': hex.encode(contractArgs),
        },
      }
    ];

    final session = ArkSendSession.build(
      ownerPk: ownerPk,
      vtxoInputs: vtxoInputs,
      recipientArkAddress: destination,
      amountSats: amountSats,
      changeArkAddress: await client.getArkAddress(),
      exitDelay: exitDelay,
      arkInfo: arkInfoMap,
    );

    return UnsignedArkTransaction(
      sessionHandle: session.handle,
      sighashes: session.sighashes,
      arkTxBytes: session.arkTxBytes,
      gateTxBytes: session.gateTxBytes,
      spentOutpoints: ['$inputTxid:$inputVout'],
    );
  }

  /// Sign an eVTXO spend with the V′ key package (NOT the main key) so the
  /// cosigner uses V′ and the contract gate runs. Passes the checkpoint PSBT
  /// (`gateTxBytes`) as `fullTransaction` so the gate detects the eVTXO. Throws
  /// if the contract denies (the cosigner withholds its V′ share).
  Future<SignedArkTransaction> signEvtxoSpend(
    UnsignedArkTransaction unsigned, {
    required threshold.KeyPackage evtxoKeyPkg,
    required threshold.PublicKeyPackage evtxoPkp,
  }) async {
    try {
      final sigHexes = <String>[];
      for (final sighash in unsigned.sighashes) {
        final sig = await client.signWithContext(
          sighash,
          evtxoKeyPkg,
          evtxoPkp,
          unsigned.gateTxBytes,
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
}
