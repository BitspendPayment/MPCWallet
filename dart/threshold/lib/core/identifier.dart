import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:threshold/core/errors.dart';
import 'package:threshold/core/utils.dart';


class Identifier {
  final BigInt s;

  Identifier(this.s) {
    if (s == BigInt.zero) {
      throw InvalidZeroScalarException("identifier cannot be zero");
    }
  }

  BigInt toScalar() => s;

  static Identifier derive(Uint8List msg) {
    final h = sha256.convert(msg).bytes;
    final s = bytesToBigInt(Uint8List.fromList(h)) % secp256k1Curve.n;
    return Identifier(s);
  }

  Uint8List serialize() {
    return bigIntToBytes(s);
  }

  static Identifier deserialize(Uint8List b) {
    final s = bytesToBigInt(b);
    return Identifier(s);
  }

  @override
  String toString() {
    return 'Identifier(${s.toRadixString(16)})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Identifier &&
          runtimeType == other.runtimeType &&
          s == other.s;

  @override
  int get hashCode => s.hashCode;
  
  int compareTo(Identifier other) {
    return s.compareTo(other.s);
  }
  
  bool less(Identifier other) {
    return compareTo(other) < 0;
  }
}

Identifier identifierFromUint16(int n) {
  if (n == 0) {
    throw InvalidZeroScalarException("n must be non-zero");
  }
  return Identifier(BigInt.from(n));
}
