import 'dart:typed_data';

import 'package:pointycastle/ecc/api.dart';
import 'package:threshold/core/dkg.dart'; // For KeyPackage, PublicKeyPackage, Signature
import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/share.dart';
import 'package:threshold/core/utils.dart'; // for constants, BigInt utils
import 'package:threshold/frost/errors.dart';
import 'package:threshold/frost/hasher.dart';
import 'package:threshold/frost/utils.dart';
import 'package:threshold/frost/commitment.dart';
import 'package:threshold/frost/binding.dart';

class SignatureShare {
  final BigInt s;
  SignatureShare(this.s);
}

// Sign implements [sign] from the spec.
// Returns a signature share.
SignatureShare sign(
  SigningPackage signingPackage,
  SigningNonce signingNonce,
  KeyPackage keyPackage,
) {
  if (signingPackage.commitments.length < keyPackage.minSigners) {
    throw errIncorrectNumberOfCommitments;
  }

  final commitment = signingPackage.commitments[keyPackage.identifier];
  if (commitment == null) {
    // This participant is not in the signing set
    throw errInvalidCommitment; // Using similar error
  }

  // Check if nonce matches commitment.
  // In our Dart implementation, we might not have '==' on objects easily unless overridden.
  // We check byte equivalence of points.
  if (!pointsEqual(signingNonce.commitments.binding, commitment.binding) ||
      !pointsEqual(signingNonce.commitments.hiding, commitment.hiding)) {
    throw errInvalidCommitment;
  }

  final bfl = computeBindingFactorList(signingPackage, keyPackage.verifyingKey);
  final groupCommitment = computeGroupCommitment(signingPackage, bfl);

  final lambdaI = deriveInterpolatingValue(
    keyPackage.identifier,
    signingPackage,
  );
  final challenge = computeChallenge(
    groupCommitment.elem,
    keyPackage.verifyingKey,
    signingPackage.message,
  );

  // Compute Signature Share
  // z_i = d_i + (e_i * rho_i) + lambda_i * s_i * c
  final bf = bfl.get(keyPackage.identifier);
  if (bf == null) throw errIncorrectBindingFactorPreimages; // Should not happen

  return computeSignatureShare(
    signingNonce,
    bf.scalar,
    lambdaI,
    keyPackage,
    challenge,
  );
}

BigInt computeChallenge(ECPoint R, VerifyingKey vk, Uint8List message) {
  final RBytes = serializePointCompressed(R);
  final YBytes = serializePointCompressed(vk.E);

  final builder = BytesBuilder();
  builder.add(RBytes);
  builder.add(YBytes);
  builder.add(message);

  return h2(builder.toBytes());
}

BigInt deriveInterpolatingValue(Identifier id, SigningPackage pkg) {
  final ids = sortedCommitmentIDs(pkg.commitments.keys.toList());
  return lagrangeCoeffAtZero(id, ids);
}

// Helper to compute signature share
SignatureShare computeSignatureShare(
  SigningNonce nonce,
  BigInt rhoI,
  BigInt lambdaI,
  KeyPackage keyPackage,
  BigInt challenge,
) {
  // z_i = d_i + (e_i * rho_i) + lambda_i * s_i * c
  // Note: In `signing.go`: ComputeSignatureShare seems to be missing in the file provided?
  // Wait, line 118 calls `ComputeSignatureShare`.
  // It was likely in another file or implicitly defined?
  // Ah, the view of `signing.go` line 118 calls it. But `signing.go` does not DEFINE it.
  // It must be in `share.go` or somewhere else within `threshold_signing`.
  // I need to implement what FROST spec says.

  // d_i = hiding nonce scalar
  // e_i = binding nonce scalar
  // rho_i = binding factor
  // lambda_i = lagrange coeff
  // s_i = long term secret share
  // c = challenge

  // z = d + (e * rho) + lambda * s * c  (mod q)

  final d = nonce.hiding;
  final e = nonce.binding;
  final s = keyPackage.secretShare;
  final c = challenge;

  final modulus = secp256k1Curve.n;

  final eRho = (e * rhoI) % modulus;
  final lsc = (lambdaI * s * c) % modulus;

  final z = (d + eRho + lsc) % modulus;

  return SignatureShare(z);
}

// Aggregate
// Returns Signature (R, z)
Signature aggregate(
  SigningPackage signingPackage,
  Map<Identifier, SignatureShare> signatureShares,
  PublicKeyPackage pubkeys,
) {
  // 1. Check identifiers
  if (signingPackage.commitments.length != signatureShares.length) {
    throw errUnknownIdentifier;
  }
  for (final id in signingPackage.commitments.keys) {
    if (!signatureShares.containsKey(id) ||
        !pubkeys.verifyingShares.containsKey(id)) {
      throw errUnknownIdentifier;
    }
  }

  final bfl = computeBindingFactorList(signingPackage, pubkeys.verifyingKey);
  final groupCommitment = computeGroupCommitment(signingPackage, bfl);

  // Aggregate z = sum(z_i)
  var z = BigInt.zero;
  final modulus = secp256k1Curve.n;

  for (final share in signatureShares.values) {
    z = (z + share.s) % modulus;
  }

  final sig = Signature(groupCommitment.elem, z);

  // Verify final signature
  final challenge = computeChallenge(
    groupCommitment.elem,
    pubkeys.verifyingKey,
    signingPackage.message,
  );

  // Verify: z * G == R + c * Y
  final zG = (secp256k1Curve.G * z)!;

  final cY = (pubkeys.verifyingKey.E * challenge)!;
  final R_plus_cY = (groupCommitment.elem + cY)!;

  if (pointsEqual(zG, R_plus_cY)) {
    return sig;
  }

  // Cheater detection would go here (verifySignatureShare)
  throw errorInvalidSignature;
}

// Verify Signature Share
void verifySignatureShare(
  Identifier identifier,
  ECPoint verifyingShare,
  SignatureShare signatureShare,
  SigningPackage signingPackage,
  VerifyingKey verifyingKey,
) {
  // Binding factors and group commitment
  final bfl = computeBindingFactorList(signingPackage, verifyingKey);
  final groupCommitment = computeGroupCommitment(signingPackage, bfl);

  final challenge = computeChallenge(
    groupCommitment.elem,
    verifyingKey,
    signingPackage.message,
  );

  // Verify:
  // z_i * G == R_i + c * lambda_i * Y_i
  // Where R_i = D_i + rho_i * E_i (Wait, check commitment definition)
  // commitment.go: toGroupCommitmentShare: sum = Hiding + bindingScalar * Binding
  // So R_i = H_i + rho_i * B_i

  final comm = signingPackage.commitments[identifier];
  if (comm == null) throw errUnknownIdentifier;

  final bf = bfl.get(identifier);
  if (bf == null) throw errUnknownIdentifier;

  final R_share = comm.toGroupCommitmentShare(bf.scalar).elem; // H + rho*B

  final lambdaI = deriveInterpolatingValue(identifier, signingPackage);

  // LHS: z_i * G
  final LHS = (secp256k1Curve.G * signatureShare.s)!;

  // RHS: R_share + c * lambda_i * Y_i
  final c_lambda = (challenge * lambdaI) % secp256k1Curve.n;
  final term2 = (verifyingShare * c_lambda)!;

  final RHS = (R_share + term2)!;

  if (!pointsEqual(LHS, RHS)) {
    throw errorInvalidSignature;
  }
}

bool pointsEqual(ECPoint a, ECPoint b) {
  if (a.isInfinity && b.isInfinity) return true;
  if (a.isInfinity || b.isInfinity) return false;
  return a.x!.toBigInteger() == b.x!.toBigInteger() &&
      a.y!.toBigInteger() == b.y!.toBigInteger();
}
