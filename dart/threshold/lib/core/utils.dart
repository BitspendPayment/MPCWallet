import 'dart:typed_data';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/ecc/api.dart';

import 'package:threshold/core/dkg.dart';
import 'package:threshold/core/errors.dart';
import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/share.dart';

final secp256k1Curve = ECDomainParameters('secp256k1');

BigInt bytesToBigInt(Uint8List bytes) {
  var result = BigInt.from(0);
  for (var i = 0; i < bytes.length; i++) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

Uint8List bigIntToBytes(BigInt number) {
  var hex = number.toRadixString(16);
  if (hex.length % 2 != 0) {
    hex = '0' + hex;
  }
  // zero pad to 32 bytes
  while (hex.length < 64) {
    hex = '0' + hex;
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    final byteString = hex.substring(i * 2, i * 2 + 2);
    bytes[i] = int.parse(byteString, radix: 16);
  }
  return bytes;
}


BigInt modNFromBytesBE(Uint8List b) {
  final s = bytesToBigInt(b) % secp256k1Curve.n;
  if (s == BigInt.zero) {
    throw InvalidZeroScalarException("invalid zero scalar");
  }
  return s;
}

BigInt modNZero() {
  return BigInt.zero;
}

BigInt modNOne() {
  return BigInt.one;
}

Uint8List elemSerializeCompressed(ECPoint e) {
  return e.getEncoded(true);
}

ECPoint elemDeserializeCompressed(Uint8List b) {
  return secp256k1Curve.curve.decodePoint(b)!;
}

ECPoint elemBaseMul(BigInt k) {
  return (secp256k1Curve.G * k)!;
}

ECPoint elemAdd(ECPoint a, ECPoint b) {
  return (a + b)!;
}

ECPoint elemMul(ECPoint a, BigInt k) {
  return (a * k)!;
}

// λ_i(0) = ∏_{j∈S, j≠i} (-j)/(i-j)  over the field (mod n)
BigInt lagrangeCoeffAtZero(Identifier i, List<Identifier> set) {
  var num = modNOne();
  var den = modNOne();

  for (final j in set) {
    if (j == i) {
      continue;
    }

    final jj = j.toScalar();
    final ii = i.toScalar();

    final negj = (secp256k1Curve.n - jj) % secp256k1Curve.n;
    num = (num * negj) % secp256k1Curve.n;

    final diff = (ii - jj + secp256k1Curve.n) % secp256k1Curve.n;
    den = (den * diff) % secp256k1Curve.n;
  }

  final denInv = den.modInverse(secp256k1Curve.n);
  return (num * denInv) % secp256k1Curve.n;
}

BigInt evaluatePolynomial(Identifier id, List<BigInt> coeffs) {
  if (coeffs.isEmpty) {
    return modNZero();
  }
  final x = id.toScalar();
  var val = modNZero();
  for (var i = coeffs.length - 1; i >= 0; i--) {
    if (i != coeffs.length - 1) {
      val = (val * x) % secp256k1Curve.n;
    }
    val = (val + coeffs[i]) % secp256k1Curve.n;
  }
  return val;
}

BigInt modNRandom() {
  final random = Random.secure();
  BigInt s;
  do {
    final bytes = Uint8List.fromList(
        List<int>.generate(32, (i) => random.nextInt(256)));
    s = bytesToBigInt(bytes) % secp256k1Curve.n;
  } while (s == BigInt.zero);
  return s;
}

List<BigInt> generateCoefficients(int size) {
  return List<BigInt>.generate(size, (i) => modNRandom());
}

(BigInt, ECPoint) generateNonce() {
  final k = modNRandom();
  final R = elemBaseMul(k);
  return (k, R);
}

(List<BigInt>, List<ECPoint>) generateSecretPolynomial(
    BigInt secret, int maxSigners, int minSigners, List<BigInt> coeffOnly) {
  validateNumOfSigners(minSigners, maxSigners);
  if (coeffOnly.length != minSigners - 1) {
    throw InvalidCoefficientsException("invalid coefficients");
  }

  final coeffs = <BigInt>[secret, ...coeffOnly];
  final commit = coeffs.map((c) => elemBaseMul(c)).toList();
  return (coeffs, commit);
}

Challenge dkgChallenge(
    Identifier identifier, VerifyingKey verifyingKey, ECPoint R) {
  final pre = BytesBuilder();
  pre.add(identifier.serialize());
  pre.add(elemSerializeCompressed(verifyingKey.E));
  pre.add(elemSerializeCompressed(R));

  final sum = sha256.convert(pre.toBytes()).bytes;
  return Challenge(bytesToBigInt(Uint8List.fromList(sum)) % secp256k1Curve.n);
}

Signature computeProofOfKnowledge(Identifier identifier,
    List<BigInt> coefficients, VerifyingKey verifyingKey) {
  final (k, R) = generateNonce();
  final chal = dkgChallenge(identifier, verifyingKey, R);
  if (coefficients.isEmpty) {
    throw InvalidCoefficientsException("invalid coefficients");
  }
  final a0 = coefficients[0];
  final zc = (a0 * chal.C) % secp256k1Curve.n;
  final z = (zc + k) % secp256k1Curve.n;
  return Signature(R, z);
}

void verifyProofOfKnowledge(
    Identifier identifier, VerifyingKey verifyingKey, Signature sig) {
  final chal = dkgChallenge(identifier, verifyingKey, sig.R);
  final gmu = elemBaseMul(sig.Z);
  final cneg = (secp256k1Curve.n - chal.C) % secp256k1Curve.n;
  final phiNeg = elemMul(verifyingKey.E, cneg);
  final right = elemAdd(gmu, phiNeg);

  if (sig.R != right) {
    throw InvalidSecretShareException("invalid proof of knowledge");
  }
}

void validateNumOfSigners(int minSigners, int maxSigners) {
  if (minSigners < 2) {
    throw InvalidMinSignersException("min_signers must be >= 2");
  }
  if (maxSigners < 2) {
    throw InvalidMaxSignersException("max_signers must be >= 2");
  }
  if (minSigners > maxSigners) {
    throw InvalidMinSignersException("min_signers cannot be greater than max_signers");
  }
}

SecretKey newSecretKey() {
  return SecretKey(modNRandom());
}

BigInt modNFromBytesAllowZero(Uint8List b) {
  return bytesToBigInt(b) % secp256k1Curve.n;
}
