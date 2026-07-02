import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:synchronized/synchronized.dart';

import 'package:app_core/hardware_signer.dart';
import 'package:app_core/threshold/core/dkg.dart';
import 'package:app_core/threshold/core/identifier.dart';
import 'package:app_core/threshold/core/utils.dart';
import 'package:app_core/threshold/frost/commitment.dart' as frost_comm;
import 'package:app_core/threshold/frost/signing.dart' as frost_sign;

/// Pure-Dart FROST signer that holds the owner share in RAM only.
///
/// Lifetime is tied to a single operation — DKG or a signing round. No Hive
/// box, no `connect()` file I/O.
///
/// SECURITY: while the signer is in memory, the secret lives in the Dart
/// heap. Dispose via [wipe] when done and drop the reference so GC can
/// collect it.
class SoftwareSigner implements HardwareSignerInterface {
  final Lock _lock = Lock();

  // Persistent DKG-derived state.
  SecretKey? _secretKey;
  Identifier? _identifier;
  List<int>? _verifyingKeyBytes;
  KeyPackage? _keyPackage;

  // Ephemeral state — never persisted.
  Round1SecretPackage? _r1Secret;
  Round2SecretPackage? _r2Secret;
  frost_comm.SigningNonce? _pendingNonce;

  SoftwareSigner();

  @override
  Future<void> connect() async {
    // In-memory signer has nothing to connect to.
  }

  @override
  Future<void> disconnect() async {
    // Clear transient DKG/signing state; persistent fields survive.
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
      _identifier = identifier;
      _verifyingKeyBytes = vkBytes;
      _r1Secret = r1Secret;
      _keyPackage = null;

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
          'no DKG secret — run DKG before calling restoreInit',
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

      _identifier = identifier;
      _verifyingKeyBytes = vkBytes;
      _r1Secret = r1Secret;
      // A fresh re-DKG is about to run, so the old KeyPackage isn't valid
      // anymore — caller will overwrite via dkgRound3.
      _keyPackage = null;

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
  Future<DkgInitResult> evtxoDealInit(int maxSigners, int minSigners) async {
    return _lock.synchronized(() async {
      final kp = _keyPackage;
      if (kp == null) {
        throw StateError('no key package — run DKG before resharing');
      }
      final identifier = kp.identifier;
      // Deal a fresh non-zero polynomial under the EXISTING identifier.
      final (r1Secret, r1Pkg) =
          dkgResharePart1(identifier, maxSigners, minSigners);
      _r1Secret = r1Secret;
      final vk = r1Pkg.commitment.toVerifyingKey();
      final vkBytes = elemSerializeCompressed(vk.E);
      return DkgInitResult(
        round1Package: r1Pkg,
        verifyingKeyBytes: vkBytes,
        identifier: identifier,
      );
    });
  }

  @override
  Future<Map<Identifier, Round2Package>> evtxoDealRound2(
    Map<Identifier, Round1Package> othersRound1, {
    List<Identifier> receiverIdentifiers = const [],
  }) async {
    return _lock.synchronized(() async {
      final r1Secret = _r1Secret;
      if (r1Secret == null) {
        throw StateError('no reshare round1 secret — call evtxoDealInit first');
      }
      final (_, r2Out) = dkgPart2(
        r1Secret,
        othersRound1,
        receiverIdentifiers: receiverIdentifiers,
      );
      _r1Secret = null; // done dealing; the signer keeps no V′ share
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
      final (kp, _) = dkgPart3(
        r1Secret,
        r2Secret,
        round1Pkgs,
        round2Pkgs,
        receiverIdentifiers: receiverIdentifiers,
      );

      _keyPackage = kp;
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
        throw StateError('no key package — run DKG first');
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
        throw StateError('no key package — run DKG first');
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
  /// used again. Call before dropping the reference.
  Future<void> wipe() async {
    await _lock.synchronized(() async {
      _secretKey = null;
      _identifier = null;
      _verifyingKeyBytes = null;
      _keyPackage = null;
      _r1Secret = null;
      _r2Secret = null;
      _pendingNonce = null;
    });
  }
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
