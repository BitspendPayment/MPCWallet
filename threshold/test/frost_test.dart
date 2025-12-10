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

      // 4. Aggregate
      final signature = aggregate(signingPackage, signatureShares, pkp);

      // 5. Verify
      final challenge = computeChallenge(
        signature.R,
        pkp.verifyingKey,
        message,
      );

      // Check: z * G == R + c * P
      final zG = (secp256k1Curve.G * signature.Z)!;
      final cP = (pkp.verifyingKey.E * challenge)!;
      final RHS = (signature.R + cP)!;

      expect(
        pointsEqual(zG, RHS),
        isTrue,
        reason: "Signature verification failed",
      );

      // Also verify using standard Verify method on VerifyingKey if available or re-implement check
      // In `share.dart`, VerifyingKey.verify(message, signature)
      // But `share.dart` `verify` uses Schnorr where hash includes R || P || m
      // Our `computeChallenge` uses R || P || m
      // so it should match

      // Note: `share.dart` definition of `Signature` might differ from `frost/signing.dart` `Signature`.
      // `dkg.dart` defines `Signature` (R, Z).
      // `frost/signing.dart` imports `dkg.dart`.
      // So they use the same `Signature` class.

      // But `share.dart` VerifyingKey.verify logic:
      // final s = bytesToBigInt(message) % secp256k1Curve.n;
      // final temp = elemMul(E, s);
      // ...
      // It treats message as scalar directly? That looks like ECDSA-ish or naive Schnorr without hashing message?
      // Wait, `share.dart` :
      // final s = bytesToBigInt(message) % ...
      // It does NOT hash message ??
      // Actually `share.dart` seems to implement a simplified check or expects hashed message as input.
      // BUT `frost` `computeChallenge` implements `H2(R, P, m)`.
      // So `share.dart` `verify` is likely incompatible with correct Schnorr/FROST verification if it doesn't do the same hashing.
      // The manual check I did above (zG == R + cP) IS valid.

      // Let's rely on manual check for this test.
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
