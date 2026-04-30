import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:synchronized/synchronized.dart';

import 'package:app_core/backup/backup_codec.dart';
import 'package:app_core/hardware_signer.dart';
import 'package:app_core/threshold/core/dkg.dart';
import 'package:app_core/threshold/core/identifier.dart';
import 'package:app_core/threshold/core/utils.dart';
import 'package:app_core/threshold/frost/commitment.dart' as frost_comm;
import 'package:app_core/threshold/frost/signing.dart' as frost_sign;

/// Pure-Dart FROST signer that holds the recovery share in RAM only.
///
/// Lifetime is tied to a single operation — DKG, restore, update-policy, or
/// delete-policy. Persistence is explicitly the caller's job: export an
/// encrypted backup with [exportEncryptedBackup] after the operation
/// completes, upload it to Drive, then drop the signer reference.
/// Rehydrate with [SoftwareSigner.fromEncryptedBackup] for the next op.
///
/// No Hive box, no `connect()` file I/O. This matches the hardware signer's
/// "only plugged in when needed" model, so the recovery share isn't sitting
/// on the device at rest alongside the spending share.
///
/// SECURITY: while the signer is in memory, the secret lives in the Dart
/// heap. Dispose via [wipe] when done and drop the reference so GC can
/// collect it.
class SoftwareSigner implements HardwareSignerInterface {
  static const String _kSecretKey = 'secretKeyHex';
  static const String _kMinSigners = 'minSigners';
  static const String _kMaxSigners = 'maxSigners';
  static const String _kIdentifier = 'identifierHex';
  static const String _kVerifyingKey = 'verifyingKeyHex';
  static const String _kKeyPackage = 'keyPackage';
  static const String _kPublicKeyPackage = 'publicKeyPackage';

  final Lock _lock = Lock();

  // Persistent state — captured in the backup blob.
  SecretKey? _secretKey;
  int? _minSigners;
  int? _maxSigners;
  Identifier? _identifier;
  List<int>? _verifyingKeyBytes;
  KeyPackage? _keyPackage;
  PublicKeyPackage? _publicKeyPackage;

  // Ephemeral state — never persisted.
  Round1SecretPackage? _r1Secret;
  Round2SecretPackage? _r2Secret;
  frost_comm.SigningNonce? _pendingNonce;

  SoftwareSigner();

  /// Hydrate a signer from a decrypted backup blob. Throws
  /// [BadPasswordException] on wrong password and [FormatException] if the
  /// blob is structurally invalid.
  static Future<SoftwareSigner> fromEncryptedBackup({
    required Uint8List blob,
    required String password,
  }) async {
    final payload = await decryptBackup(blob, password);
    final signer = SoftwareSigner();

    final secretHex = payload[_kSecretKey] as String?;
    if (secretHex == null) {
      throw const FormatException('backup missing secretKeyHex');
    }
    signer._secretKey = SecretKey(BigInt.parse(secretHex, radix: 16));
    signer._minSigners = payload[_kMinSigners] as int?;
    signer._maxSigners = payload[_kMaxSigners] as int?;
    if (signer._minSigners == null || signer._maxSigners == null) {
      throw const FormatException('backup missing minSigners/maxSigners');
    }
    final idHex = payload[_kIdentifier] as String?;
    if (idHex != null) {
      signer._identifier =
          Identifier.deserialize(Uint8List.fromList(hex.decode(idHex)));
    }
    final vkHex = payload[_kVerifyingKey] as String?;
    if (vkHex != null) {
      signer._verifyingKeyBytes = hex.decode(vkHex);
    }
    final kp = payload[_kKeyPackage];
    if (kp is Map) {
      signer._keyPackage = KeyPackage.fromJson(Map<String, dynamic>.from(kp));
    }
    final pkp = payload[_kPublicKeyPackage];
    if (pkp is Map) {
      signer._publicKeyPackage =
          PublicKeyPackage.fromJson(Map<String, dynamic>.from(pkp));
    }
    return signer;
  }

  /// Encrypt the full signer state with [password]. The returned blob is
  /// suitable for upload to Drive. Throws if DKG hasn't run yet (no secret).
  Future<Uint8List> exportEncryptedBackup(String password) async {
    return _lock.synchronized(() async {
      final sk = _secretKey;
      if (sk == null || _minSigners == null || _maxSigners == null) {
        throw StateError('no signer state to back up — run DKG first');
      }
      return encryptBackup({
        _kSecretKey: _bigIntToHex64(sk.scalar),
        _kMinSigners: _minSigners,
        _kMaxSigners: _maxSigners,
        if (_identifier != null)
          _kIdentifier: hex.encode(_identifier!.serialize()),
        if (_verifyingKeyBytes != null)
          _kVerifyingKey: hex.encode(_verifyingKeyBytes!),
        if (_keyPackage != null) _kKeyPackage: _keyPackage!.toJson(),
        if (_publicKeyPackage != null)
          _kPublicKeyPackage: _publicKeyPackage!.toJson(),
      }, password);
    });
  }

  /// Whether [exportEncryptedBackup] can be called (DKG has produced state).
  bool get hasBackupableState => _secretKey != null;

  @override
  Future<void> connect() async {
    // In-memory signer has nothing to connect to.
  }

  @override
  Future<void> disconnect() async {
    // Clear transient DKG/signing state; persistent fields survive so the
    // caller can still call exportEncryptedBackup afterwards.
    _r1Secret = null;
    _r2Secret = null;
    _pendingNonce = null;
  }

  @override
  Future<DkgInitResult> dkgInit(int maxSigners, int minSigners) async {
    return _lock.synchronized(() async {
      validateNumOfSigners(minSigners, maxSigners);
      final secret = newSecretKey();
      final coefficients =
          List<BigInt>.generate(minSigners - 1, (_) => modNRandom());
      final (r1Secret, r1Pkg) =
          dkgPart1(maxSigners, minSigners, secret, coefficients);

      final vk = r1Pkg.commitment.toVerifyingKey();
      final vkBytes = elemSerializeCompressed(vk.E);
      final identifier = Identifier.derive(vkBytes);

      _secretKey = secret;
      _minSigners = minSigners;
      _maxSigners = maxSigners;
      _identifier = identifier;
      _verifyingKeyBytes = vkBytes;
      _r1Secret = r1Secret;
      _keyPackage = null;
      _publicKeyPackage = null;

      return DkgInitResult(
        round1Package: r1Pkg,
        verifyingKeyBytes: vkBytes,
        identifier: identifier,
      );
    });
  }

  @override
  Future<DkgInitResult> restoreInit(int maxSigners, int minSigners) async {
    return _lock.synchronized(() async {
      validateNumOfSigners(minSigners, maxSigners);
      final secret = _secretKey;
      if (secret == null) {
        throw StateError(
          'no DKG secret — load from backup before calling restoreInit',
        );
      }
      final coefficients =
          List<BigInt>.generate(minSigners - 1, (_) => modNRandom());
      final (r1Secret, r1Pkg) =
          dkgPart1(maxSigners, minSigners, secret, coefficients);

      final vk = r1Pkg.commitment.toVerifyingKey();
      final vkBytes = elemSerializeCompressed(vk.E);
      final identifier = Identifier.derive(vkBytes);

      // Defensive: restoring with the same secret must yield the same
      // participant identity. Any mismatch means the secret is corrupted.
      if (_verifyingKeyBytes != null) {
        if (!_listEquals(vkBytes, _verifyingKeyBytes!)) {
          throw StateError(
            'restoreInit produced different verifying key — secret is corrupted',
          );
        }
      }

      _minSigners = minSigners;
      _maxSigners = maxSigners;
      _identifier = identifier;
      _verifyingKeyBytes = vkBytes;
      _r1Secret = r1Secret;
      // A fresh re-DKG is about to run, so the old KeyPackage / PKP aren't
      // valid anymore — caller will overwrite via dkgRound3.
      _keyPackage = null;
      _publicKeyPackage = null;

      return DkgInitResult(
        round1Package: r1Pkg,
        verifyingKeyBytes: vkBytes,
        identifier: identifier,
      );
    });
  }

  @override
  Future<Map<Identifier, Round2Package>> dkgRound2(
    Map<Identifier, Round1Package> othersRound1, {
    List<Identifier> receiverIdentifiers = const [],
  }) async {
    return _lock.synchronized(() async {
      final r1Secret = _r1Secret;
      if (r1Secret == null) {
        throw StateError(
          'no round 1 secret package — call dkgInit/restoreInit first',
        );
      }
      final (r2Secret, r2Out) = dkgPart2(
        r1Secret,
        othersRound1,
        receiverIdentifiers: receiverIdentifiers,
      );
      _r2Secret = r2Secret;
      return r2Out;
    });
  }

  @override
  Future<DkgFinalResult> dkgRound3(
    Map<Identifier, Round1Package> round1Pkgs,
    Map<Identifier, Round2Package> round2Pkgs, {
    List<Identifier> receiverIdentifiers = const [],
  }) async {
    return _lock.synchronized(() async {
      final r1Secret = _r1Secret;
      final r2Secret = _r2Secret;
      if (r1Secret == null) {
        throw StateError('no round 1 secret package');
      }
      if (r2Secret == null) {
        throw StateError('no round 2 secret package — call dkgRound2 first');
      }
      final (kp, pkp) = dkgPart3(
        r1Secret,
        r2Secret,
        round1Pkgs,
        round2Pkgs,
        receiverIdentifiers: receiverIdentifiers,
      );

      _keyPackage = kp;
      _publicKeyPackage = pkp;
      _identifier = kp.identifier;
      // DKG state can be released now.
      _r1Secret = null;
      _r2Secret = null;

      return DkgFinalResult(
        identifier: kp.identifier,
        publicKeyHex: kp.verifyingKey.E,
      );
    });
  }

  @override
  Future<frost_comm.SigningCommitments> generateNonce() async {
    return _lock.synchronized(() async {
      final kp = _keyPackage;
      if (kp == null) {
        throw StateError('no key package — load from backup or run DKG first');
      }
      final nonce = frost_comm.newNonce(kp.secretShare);
      _pendingNonce = nonce;
      return nonce.commitments;
    });
  }

  @override
  Future<BigInt> sign({
    required Uint8List message,
    required Map<Identifier, frost_comm.SigningCommitments> commitments,
    required bool applyTweak,
    List<int>? merkleRoot,
  }) async {
    return _lock.synchronized(() async {
      final kp = _keyPackage;
      if (kp == null) {
        throw StateError('no key package — load from backup or run DKG first');
      }
      final nonce = _pendingNonce;
      if (nonce == null) {
        throw StateError('no pending nonce — call generateNonce first');
      }
      // One-shot.
      _pendingNonce = null;

      final finalKp = applyTweak ? kp.tweak(merkleRoot) : kp;

      final signingPackage = frost_comm.SigningPackage(commitments, message);
      final share = frost_sign.sign(signingPackage, nonce, finalKp);
      return share.s;
    });
  }

  @override
  Future<SignerInfo> getInfo() async {
    return _lock.synchronized(() async {
      return SignerInfo(
        hasKeyPackage: _keyPackage != null,
        hasPendingNonce: _pendingNonce != null,
        identifierHex: _identifier != null
            ? hex.encode(_identifier!.serialize())
            : null,
      );
    });
  }

  /// Drop all in-memory state. After this, the signer cannot be used unless
  /// rehydrated from a backup. Call before dropping the reference.
  Future<void> wipe() async {
    await _lock.synchronized(() async {
      _secretKey = null;
      _minSigners = null;
      _maxSigners = null;
      _identifier = null;
      _verifyingKeyBytes = null;
      _keyPackage = null;
      _publicKeyPackage = null;
      _r1Secret = null;
      _r2Secret = null;
      _pendingNonce = null;
    });
  }
}

String _bigIntToHex64(BigInt v) {
  var h = v.toRadixString(16);
  while (h.length < 64) {
    h = '0$h';
  }
  return h;
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
