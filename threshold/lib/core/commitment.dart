
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:threshold/core/errors.dart';
import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/utils.dart';
import 'package:threshold/core/share.dart';

typedef CoefficientCommitment = ECPoint;
typedef VerifyingShare = ECPoint;

class VerifiableSecretSharingCommitment {
  final List<CoefficientCommitment> coeffs;

  VerifiableSecretSharingCommitment(this.coeffs);

  factory VerifiableSecretSharingCommitment.fromJson(dynamic jsonData) {
    List<String> hexStrings;

    if (jsonData is List) {
      hexStrings = List<String>.from(jsonData.map((item) => item.toString()));
    } else if (jsonData is Map && jsonData.containsKey('coeffs')) {
      hexStrings = List<String>.from(jsonData['coeffs'].map((item) => item.toString()));
    } else {
      throw FormatException('Invalid JSON structure for VerifiableSecretSharingCommitment');
    }

    final coeffs = hexStrings.map((h) {
      final bytes = Uint8List.fromList(hex.decode(h));
      return elemDeserializeCompressed(bytes);
    }).toList();

    return VerifiableSecretSharingCommitment(coeffs);
  }

  List<String> toJson() {
    return coeffs.map((c) {
      final compressed = elemSerializeCompressed(c);
      return hex.encode(compressed);
    }).toList();
  }

  VerifyingShare getVerifyingShare(Identifier id) {
    final x = id.toScalar();
    var itok = BigInt.one;

    VerifyingShare sum = secp256k1Curve.curve.infinity!;

    for (var k = 0; k < coeffs.length; k++) {
      final term = elemMul(coeffs[k], itok);
      sum = elemAdd(sum, term);
      itok = (itok * x) % secp256k1Curve.n;
    }
    return sum;
  }

  VerifyingKey toVerifyingKey() {
    if (coeffs.isEmpty) {
      throw InvalidCommitVectorException("Cannot create verifying key from empty commitment vector.");
    }
    return VerifyingKey(E: coeffs[0]);
  }
}

VerifiableSecretSharingCommitment sumCommitments(
    List<VerifiableSecretSharingCommitment> commitments) {
  if (commitments.isEmpty) {
    throw IncorrectNumberOfCommitmentsException("Commitment list cannot be empty.");
  }

  final l = commitments[0].coeffs.length;
  if (l == 0) {
      return VerifiableSecretSharingCommitment([]);
  }
  
  final group = List<CoefficientCommitment>.generate(l, (_) => secp256k1Curve.curve.infinity!);

  for (final c in commitments) {
    if (c.coeffs.length != l) {
      throw IncorrectNumberOfCommitmentsException(
          "Coefficient lists must have the same length.");
    }
    for (var i = 0; i < l; i++) {
      group[i] = elemAdd(group[i], c.coeffs[i]);
    }
  }
  return VerifiableSecretSharingCommitment(group);
}