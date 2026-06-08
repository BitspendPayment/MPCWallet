import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:app_core/threshold/core/dkg.dart';
import 'package:app_core/threshold/core/identifier.dart';
import 'package:app_core/threshold/core/utils.dart';
import 'package:app_core/threshold/frost/commitment.dart' as frost_comm;

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

class DkgInitResult {
  final Round1Package round1Package;
  final List<int> verifyingKeyBytes;
  final Identifier identifier;

  DkgInitResult({
    required this.round1Package,
    required this.verifyingKeyBytes,
    required this.identifier,
  });
}

class DkgFinalResult {
  final Identifier identifier;
  final String publicKeyHex;

  DkgFinalResult({
    required this.identifier,
    required this.publicKeyHex,
  });
}

class SignerInfo {
  final bool hasKeyPackage;
  final bool hasPendingNonce;
  final String? identifierHex;

  SignerInfo({
    required this.hasKeyPackage,
    required this.hasPendingNonce,
    this.identifierHex,
  });
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class HardwareSignerInterface {
  Future<void> connect();
  Future<void> disconnect();

  /// DKG round 1: generate secret on device, return Round1Package + identifier.
  Future<DkgInitResult> dkgInit(int maxSigners, int minSigners);

  /// Restore round 1: reuse stored DKG secret, generate fresh coefficients.
  /// Returns same verifying key/identifier as original DKG but different R1 package.
  Future<DkgInitResult> restoreInit(int maxSigners, int minSigners);

  /// DKG round 2: verify others' Round1Packages, compute shares.
  /// [receiverIdentifiers] are passive participants who get shares but
  /// don't contribute a secret polynomial.
  Future<Map<Identifier, Round2Package>> dkgRound2(
    Map<Identifier, Round1Package> othersRound1, {
    List<Identifier> receiverIdentifiers = const [],
  });

  /// DKG round 3: verify received shares, compute final key package on device.
  /// [receiverIdentifiers] are passive participants included in the PKP.
  Future<DkgFinalResult> dkgRound3(
    Map<Identifier, Round1Package> round1Pkgs,
    Map<Identifier, Round2Package> round2Pkgs, {
    List<Identifier> receiverIdentifiers = const [],
  });

  /// eVTXO reshare deal — round 1. Deal a fresh non-zero polynomial under the
  /// signer's EXISTING identifier. The signer keeps NO resulting share.
  Future<DkgInitResult> evtxoDealInit(int maxSigners, int minSigners);

  /// eVTXO reshare deal — round 2. Compute shares for the other parties, then
  /// discard the round-2 secret (the signer keeps no share).
  Future<Map<Identifier, Round2Package>> evtxoDealRound2(
    Map<Identifier, Round1Package> othersRound1, {
    List<Identifier> receiverIdentifiers = const [],
  });

  /// Generate a signing nonce (one-time use).
  Future<frost_comm.SigningCommitments> generateNonce();

  /// Produce a signature share for the given message.
  Future<BigInt> sign({
    required Uint8List message,
    required Map<Identifier, frost_comm.SigningCommitments> commitments,
    required bool applyTweak,
    List<int>? merkleRoot,
  });

  /// Query signer status.
  Future<SignerInfo> getInfo();
}

// ---------------------------------------------------------------------------
// TCP implementation (for E2E testing with signer-server)
// ---------------------------------------------------------------------------

class TcpHardwareSigner implements HardwareSignerInterface {
  final String host;
  final int port;
  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  final _buffer = BytesBuilder(copy: false);
  Completer<void>? _dataCompleter;

  TcpHardwareSigner({required this.host, required this.port});

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _subscription = _socket!.listen(
      (data) {
        _buffer.add(data);
        _dataCompleter?.complete();
        _dataCompleter = null;
      },
      onError: (error) {
        _dataCompleter?.completeError(error);
        _dataCompleter = null;
      },
      onDone: () {
        _dataCompleter?.completeError(
          Exception('Connection closed unexpectedly'),
        );
        _dataCompleter = null;
      },
    );
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
  }

  /// Send a JSON command and receive the JSON response.
  /// Protocol: 4-byte BE length prefix + JSON payload.
  Future<Map<String, dynamic>> _sendCommand(Map<String, dynamic> cmd) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Not connected to hardware signer');
    }

    final jsonBytes = utf8.encode(jsonEncode(cmd));
    final lenBytes = ByteData(4)..setUint32(0, jsonBytes.length, Endian.big);

    socket.add(lenBytes.buffer.asUint8List());
    socket.add(jsonBytes);
    await socket.flush();

    // Read 4-byte length prefix
    final respLenBytes = await _readExact(4);
    final respLen =
        ByteData.sublistView(respLenBytes).getUint32(0, Endian.big);

    // Read JSON payload
    final respBytes = await _readExact(respLen);
    final respJson =
        jsonDecode(utf8.decode(respBytes)) as Map<String, dynamic>;

    if (respJson.containsKey('error')) {
      throw Exception('Signer error: ${respJson['error']}');
    }

    return respJson;
  }

  /// Read exactly [count] bytes from the buffered stream.
  Future<Uint8List> _readExact(int count) async {
    while (_buffer.length < count) {
      _dataCompleter = Completer<void>();
      await _dataCompleter!.future;
    }

    final allBytes = _buffer.takeBytes();
    final result = Uint8List.fromList(allBytes.sublist(0, count));

    // Put remaining bytes back into the buffer
    if (allBytes.length > count) {
      _buffer.add(allBytes.sublist(count));
    }

    return result;
  }

  @override
  Future<DkgInitResult> dkgInit(int maxSigners, int minSigners) async {
    final resp = await _sendCommand({
      'cmd': 'dkg_init',
      'max_signers': maxSigners,
      'min_signers': minSigners,
    });

    final r1PkgJson = resp['round1_package_json'] as Map<String, dynamic>;
    final round1Package = Round1Package.fromJson(r1PkgJson);

    final vkHex = resp['verifying_key_hex'] as String;
    final verifyingKeyBytes = hex.decode(vkHex);

    final idHex = resp['identifier_hex'] as String;
    final idBytes = Uint8List.fromList(hex.decode(idHex));
    final identifier = Identifier.deserialize(idBytes);

    return DkgInitResult(
      round1Package: round1Package,
      verifyingKeyBytes: verifyingKeyBytes,
      identifier: identifier,
    );
  }

  @override
  Future<DkgInitResult> restoreInit(int maxSigners, int minSigners) async {
    final resp = await _sendCommand({
      'cmd': 'restore_init',
      'max_signers': maxSigners,
      'min_signers': minSigners,
    });

    final r1PkgJson = resp['round1_package_json'] as Map<String, dynamic>;
    final round1Package = Round1Package.fromJson(r1PkgJson);

    final vkHex = resp['verifying_key_hex'] as String;
    final verifyingKeyBytes = hex.decode(vkHex);

    final idHex = resp['identifier_hex'] as String;
    final idBytes = Uint8List.fromList(hex.decode(idHex));
    final identifier = Identifier.deserialize(idBytes);

    return DkgInitResult(
      round1Package: round1Package,
      verifyingKeyBytes: verifyingKeyBytes,
      identifier: identifier,
    );
  }

  @override
  Future<Map<Identifier, Round2Package>> dkgRound2(
    Map<Identifier, Round1Package> othersRound1, {
    List<Identifier> receiverIdentifiers = const [],
  }) async {
    final r1Map = <String, dynamic>{};
    for (final entry in othersRound1.entries) {
      final idHex = hex.encode(entry.key.serialize());
      r1Map[idHex] = entry.value.toJson();
    }

    final cmd = <String, dynamic>{
      'cmd': 'dkg_round2',
      'round1_packages': r1Map,
    };
    if (receiverIdentifiers.isNotEmpty) {
      cmd['receiver_identifiers'] = receiverIdentifiers
          .map((id) => hex.encode(id.serialize()))
          .toList();
    }

    final resp = await _sendCommand(cmd);

    final r2Map = resp['round2_packages'] as Map<String, dynamic>;
    final result = <Identifier, Round2Package>{};
    for (final entry in r2Map.entries) {
      final id = Identifier.deserialize(
        Uint8List.fromList(hex.decode(entry.key)),
      );
      final pkg = Round2Package.fromJson(
        entry.value is String
            ? jsonDecode(entry.value) as Map<String, dynamic>
            : entry.value as Map<String, dynamic>,
      );
      result[id] = pkg;
    }

    return result;
  }

  @override
  Future<DkgInitResult> evtxoDealInit(int maxSigners, int minSigners) async {
    final resp = await _sendCommand({
      'cmd': 'evtxo_deal_init',
      'max_signers': maxSigners,
      'min_signers': minSigners,
    });
    final round1Package =
        Round1Package.fromJson(resp['round1_package_json'] as Map<String, dynamic>);
    final verifyingKeyBytes = hex.decode(resp['verifying_key_hex'] as String);
    final identifier = Identifier.deserialize(
      Uint8List.fromList(hex.decode(resp['identifier_hex'] as String)),
    );
    return DkgInitResult(
      round1Package: round1Package,
      verifyingKeyBytes: verifyingKeyBytes,
      identifier: identifier,
    );
  }

  @override
  Future<Map<Identifier, Round2Package>> evtxoDealRound2(
    Map<Identifier, Round1Package> othersRound1, {
    List<Identifier> receiverIdentifiers = const [],
  }) async {
    final r1Map = <String, dynamic>{};
    for (final entry in othersRound1.entries) {
      r1Map[hex.encode(entry.key.serialize())] = entry.value.toJson();
    }
    final cmd = <String, dynamic>{
      'cmd': 'evtxo_deal_round2',
      'round1_packages': r1Map,
    };
    if (receiverIdentifiers.isNotEmpty) {
      cmd['receiver_identifiers'] =
          receiverIdentifiers.map((id) => hex.encode(id.serialize())).toList();
    }
    final resp = await _sendCommand(cmd);
    final r2Map = resp['round2_packages'] as Map<String, dynamic>;
    final result = <Identifier, Round2Package>{};
    for (final entry in r2Map.entries) {
      final id = Identifier.deserialize(
        Uint8List.fromList(hex.decode(entry.key)),
      );
      final pkg = Round2Package.fromJson(
        entry.value is String
            ? jsonDecode(entry.value) as Map<String, dynamic>
            : entry.value as Map<String, dynamic>,
      );
      result[id] = pkg;
    }
    return result;
  }

  @override
  Future<DkgFinalResult> dkgRound3(
    Map<Identifier, Round1Package> round1Pkgs,
    Map<Identifier, Round2Package> round2Pkgs, {
    List<Identifier> receiverIdentifiers = const [],
  }) async {
    final r1Map = <String, dynamic>{};
    for (final entry in round1Pkgs.entries) {
      final idHex = hex.encode(entry.key.serialize());
      r1Map[idHex] = entry.value.toJson();
    }

    final r2Map = <String, dynamic>{};
    for (final entry in round2Pkgs.entries) {
      final idHex = hex.encode(entry.key.serialize());
      r2Map[idHex] = entry.value.toJson();
    }

    final cmd = <String, dynamic>{
      'cmd': 'dkg_round3',
      'round1_packages': r1Map,
      'round2_packages': r2Map,
    };
    if (receiverIdentifiers.isNotEmpty) {
      cmd['receiver_identifiers'] = receiverIdentifiers
          .map((id) => hex.encode(id.serialize()))
          .toList();
    }

    final resp = await _sendCommand(cmd);

    final idHex = resp['identifier_hex'] as String;
    final idBytes = Uint8List.fromList(hex.decode(idHex));
    final identifier = Identifier.deserialize(idBytes);

    return DkgFinalResult(
      identifier: identifier,
      publicKeyHex: resp['public_key_hex'] as String,
    );
  }

  @override
  Future<frost_comm.SigningCommitments> generateNonce() async {
    final resp = await _sendCommand({'cmd': 'generate_nonce'});

    final hidingHex = resp['hiding_hex'] as String;
    final bindingHex = resp['binding_hex'] as String;

    final hiding = elemDeserializeCompressed(
      Uint8List.fromList(hex.decode(hidingHex)),
    );
    final binding = elemDeserializeCompressed(
      Uint8List.fromList(hex.decode(bindingHex)),
    );

    return frost_comm.SigningCommitments(binding, hiding);
  }

  @override
  Future<BigInt> sign({
    required Uint8List message,
    required Map<Identifier, frost_comm.SigningCommitments> commitments,
    required bool applyTweak,
    List<int>? merkleRoot,
  }) async {
    final commMap = <String, dynamic>{};
    for (final entry in commitments.entries) {
      final idHex = hex.encode(entry.key.serialize());
      commMap[idHex] = {
        'hiding': hex.encode(elemSerializeCompressed(entry.value.hiding)),
        'binding': hex.encode(elemSerializeCompressed(entry.value.binding)),
      };
    }

    final cmd = <String, dynamic>{
      'cmd': 'sign',
      'message_hex': hex.encode(message),
      'commitments': commMap,
      'apply_tweak': applyTweak,
    };

    if (merkleRoot != null) {
      cmd['merkle_root_hex'] = hex.encode(merkleRoot);
    }

    final resp = await _sendCommand(cmd);
    final shareHex = resp['share_hex'] as String;
    return bytesToBigInt(Uint8List.fromList(hex.decode(shareHex)));
  }

  @override
  Future<SignerInfo> getInfo() async {
    final resp = await _sendCommand({'cmd': 'get_info'});
    return SignerInfo(
      hasKeyPackage: resp['has_key_package'] as bool,
      hasPendingNonce: resp['has_pending_nonce'] as bool,
      identifierHex: resp['identifier_hex'] as String?,
    );
  }
}

