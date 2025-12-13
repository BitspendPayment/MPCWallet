import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:threshold/threshold.dart';
// We need to import FROST/core internals that might not be exported by main lib if we want to test low level
// But we exported everything in threshold.dart so we should be good.

// Replicate Go test logic
void main() {
  group('FROST End-to-End', () {
    test('Sign and Aggregate', () {
      const minSigners = 2;
      const maxSigners = 3;

      // 1. DKG (Setup)
      // We use the existing DKG implementation to generate keys
      final participants = <Identifier>[
        Identifier(BigInt.from(1)),
        Identifier(BigInt.from(2)),
        Identifier(BigInt.from(3)),
      ];

      // Helper to run full DKG locally (simulated)
      final (keyPackages, pkp) = runDealerDKG(
        minSigners,
        maxSigners,
        participants,
      );

      // 2. Signing Setup
      final message = Uint8List.fromList(
        "threshold frost end-to-end signature".codeUnits,
      );

      final signingCommitments = <Identifier, SigningCommitments>{};
      final nonces = <Identifier, SigningNonce>{};

      // Participants 1 and 2 sign (minSigners = 2)
      final signers = participants.sublist(0, minSigners);

      for (final id in signers) {
        // Find key package for this ID
        final kp = keyPackages.firstWhere((k) => k.identifier == id);

        // Generate Nonce
        // We just pass secret share as BigInt
        final nonce = newNonce(kp.secretShare);
        nonces[id] = nonce;
        signingCommitments[id] = nonce.commitments;
      }

      final signingPackage = SigningPackage(signingCommitments, message);

      // 3. Sign
      final signatureShares = <Identifier, SignatureShare>{};

      for (final id in signers) {
        final kp = keyPackages.firstWhere((k) => k.identifier == id);
        final nonce = nonces[id]!;

        final share = sign(signingPackage, nonce, kp);
        signatureShares[id] = share;
      }

      final signature = aggregate(signingPackage, signatureShares, pkp);
      final isTrue = signature.verify(pkp.verifyingKey, message);

      expect(isTrue, true, reason: "Signature verification failed");
    });
  });
}

// Helper to simulate DKG
(List<KeyPackage>, PublicKeyPackage) runDealerDKG(
  int min,
  int max,
  List<Identifier> ids,
) {
  // We just run DKG steps locally in loop

  // 1. Round 1
  final round1Secrets = <Identifier, Round1SecretPackage>{};
  final round1Publics = <Identifier, Round1Package>{};

  for (final id in ids) {
    final secret = SecretKey(modNRandom());
    final coeffs = generateCoefficients(min - 1);
    final (sec, pub) = dkgPart1(id, max, min, secret, coeffs);
    round1Secrets[id] = sec;
    round1Publics[id] = pub;
  }

  // 2. Round 2
  final round2Secrets = <Identifier, Round2SecretPackage>{};
  final round2Out = <Identifier, Map<Identifier, Round2Package>>{};

  for (final id in ids) {
    final others = <Identifier, Round1Package>{};
    for (final otherId in ids) {
      if (otherId != id) others[otherId] = round1Publics[otherId]!;
    }
    final (sec, out) = dkgPart2(round1Secrets[id]!, others);
    round2Secrets[id] = sec;
    round2Out[id] = out;
  }

  // 3. Round 3
  final keyPackages = <KeyPackage>[];
  PublicKeyPackage? pkp;

  for (final id in ids) {
    final r2Inbound = <Identifier, Round2Package>{};
    final r1View = <Identifier, Round1Package>{};

    for (final otherId in ids) {
      if (otherId != id) {
        r2Inbound[otherId] = round2Out[otherId]![id]!;
        r1View[otherId] = round1Publics[otherId]!;
      }
    }

    final (kp, pub) = dkgPart3(
      round1Secrets[id]!,
      round2Secrets[id]!,
      r1View,
      r2Inbound,
    );
    keyPackages.add(kp);
    pkp = pub;
  }

  return (keyPackages, pkp!);
}

bool pointsEqual(ECPoint a, ECPoint b) {
  if (a.isInfinity && b.isInfinity) return true;
  if (a.isInfinity || b.isInfinity) return false;
  return a.x!.toBigInteger() == b.x!.toBigInteger() &&
      a.y!.toBigInteger() == b.y!.toBigInteger();
}
