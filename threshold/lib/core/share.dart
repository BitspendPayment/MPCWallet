import 'dart:typed_data';
import 'package:pointycastle/ecc/api.dart';
import 'package:threshold/core/commitment.dart';
import 'package:threshold/core/errors.dart';
import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/utils.dart';
import 'package:threshold/core/dkg.dart';

typedef SecretShare = BigInt;

class VerifyingKey {
  final ECPoint E;
  VerifyingKey({required this.E});

  bool verify(Uint8List message, Signature signature) {
    final left = elemBaseMul(signature.Z);

    final s = bytesToBigInt(message) % secp256k1Curve.n;
    final temp = elemMul(E, s);

    final right = elemAdd(signature.R, temp);

    return left == right;
  }
}

class ThresholdShare {
  final Identifier identifier;
  final SecretShare secretShare;
  final VerifyingShare verifyingShare;
  final VerifiableSecretSharingCommitment commitment;

  ThresholdShare(
    this.identifier,
    this.secretShare,
    this.verifyingShare,
    this.commitment,
  );

  (VerifyingShare, VerifyingKey) verify() {
    final left = elemBaseMul(secretShare);
    final right = commitment.getVerifyingShare(identifier);

    if (left != right) {
      throw InvalidSecretShareException("invalid secret share");
    }

    final groupVK = commitment.toVerifyingKey();
    return (right, groupVK);
  }
}

SecretKey reconstruct(
    int minParticipants, Map<Identifier, SecretShare> participants) {
  if (participants.isEmpty) {
    throw IncorrectNumberOfSharesException("incorrect number of shares");
  }
  if (participants.length < minParticipants) {
    throw IncorrectNumberOfSharesException("incorrect number of shares");
  }

  final ids = participants.keys.toList();
  var secret = modNZero();

  for (final entry in participants.entries) {
    final i = entry.key;
    final k = entry.value;

    final l = lagrangeCoeffAtZero(i, ids);
    final part = (l * k) % secp256k1Curve.n;
    secret = (secret + part) % secp256k1Curve.n;
  }

  return SecretKey(secret);
}
