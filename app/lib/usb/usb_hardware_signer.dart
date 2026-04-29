/// USB hardware signer implementation using HID transport.
///
/// Implements [HardwareSignerInterface] by communicating with a Pico 2
/// signer device over USB HID. Uses the same JSON command protocol as
/// [TcpHardwareSigner] but over chunked HID reports instead of TCP.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:client/hardware_signer.dart';
import 'package:client/threshold/core/dkg.dart';
import 'package:client/threshold/core/identifier.dart';
import 'package:client/threshold/core/utils.dart';
import 'package:client/threshold/frost/commitment.dart' as frost_comm;

import 'usb_hid_transport.dart';

class UsbHardwareSigner implements HardwareSignerInterface {
  final UsbHidTransport _transport = UsbHidTransport();

  @override
  Future<void> connect() async {
    final devices = await _transport.enumerate();
    if (devices.isEmpty) {
      throw StateError('No HW Signer device found. '
          'Connect the device via USB OTG and try again.');
    }
    await _transport.open();
  }

  @override
  Future<void> disconnect() async {
    if (_transport.isConnected) {
      await _transport.close();
    }
  }

  @override
  Future<DkgInitResult> dkgInit(int maxSigners, int minSigners) async {
    final resp = await _transport.sendCommand({
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
    final resp = await _transport.sendCommand({
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

    final resp = await _transport.sendCommand(cmd);

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

    final resp = await _transport.sendCommand(cmd);

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
    final resp = await _transport.sendCommand({'cmd': 'generate_nonce'});

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

    final resp = await _transport.sendCommand(cmd);
    final shareHex = resp['share_hex'] as String;
    return bytesToBigInt(Uint8List.fromList(hex.decode(shareHex)));
  }

  @override
  Future<SignerInfo> getInfo() async {
    final resp = await _transport.sendCommand({'cmd': 'get_info'});
    return SignerInfo(
      hasKeyPackage: resp['has_key_package'] as bool,
      hasPendingNonce: resp['has_pending_nonce'] as bool,
      identifierHex: resp['identifier_hex'] as String?,
    );
  }
}
