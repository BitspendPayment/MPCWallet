import 'dart:typed_data';
import 'package:pointycastle/ecc/api.dart';
import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/utils.dart'; // for secp256k1Curve, elemAdd, etc.

// Helper to serialize ECPoint compressed
Uint8List serializePointCompressed(ECPoint point) {
  return point.getEncoded(true);
}

// Helper to sort identifiers. Dart sort is stable.
List<Identifier> sortedCommitmentIDs(List<Identifier> ids) {
  // Identifier.compareTo uses 's.compareTo'
  final sorted = List<Identifier>.from(ids);
  sorted.sort((a, b) => a.s.compareTo(b.s));
  return sorted;
}

// VartimeMultiscalarMul
// Adapting simple iterative approach since PointyCastle doesn't have optimised MSM exposed directly easily
ECPoint vartimeMultiscalarMul(List<BigInt> scalars, List<ECPoint> elems) {
  if (scalars.length != elems.length) {
    throw Exception("scalars and elems length mismatch");
  }

  var acc = secp256k1Curve.curve.infinity!;
  for (var i = 0; i < scalars.length; i++) {
    final temp = (elems[i] * scalars[i])!;
    acc = (acc + temp)!;
  }
  return acc;
}
