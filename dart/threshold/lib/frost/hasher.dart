import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:threshold/core/utils.dart';

const contextString = "FROST-secp256k1-SHA256-TR-v1";

Uint8List hashToArray(List<Uint8List> input) {
  final hasher = sha256.convert(input.expand((element) => element).toList());
  return Uint8List.fromList(hasher.bytes);
}

BigInt hashToScalar(List<Uint8List> input) {
  final arr = hashToArray(input);
  return bytesToBigInt(arr) % secp256k1Curve.n;
}

BigInt h1(Uint8List input) {
  return hashToScalar([
    Uint8List.fromList(contextString.codeUnits),
    Uint8List.fromList("rho".codeUnits),
    input,
  ]);
}

BigInt h2(Uint8List input) {
  return hashToScalar([
    Uint8List.fromList(contextString.codeUnits),
    Uint8List.fromList("BIP0340/challenge".codeUnits),
    input,
  ]);
}

BigInt h3(Uint8List input) {
  return hashToScalar([
    Uint8List.fromList(contextString.codeUnits),
    Uint8List.fromList("nonce".codeUnits),
    input,
  ]);
}

Uint8List h4(Uint8List input) {
  return hashToArray([
    Uint8List.fromList(contextString.codeUnits),
    Uint8List.fromList("msg".codeUnits),
    input,
  ]);
}

Uint8List h5(Uint8List input) {
  return hashToArray([
    Uint8List.fromList(contextString.codeUnits),
    Uint8List.fromList("com".codeUnits),
    input,
  ]);
}

BigInt hDKG(Uint8List input) {
  return hashToScalar([
    Uint8List.fromList(contextString.codeUnits),
    Uint8List.fromList("dkg".codeUnits),
    input,
  ]);
}

BigInt hID(Uint8List input) {
  return hashToScalar([
    Uint8List.fromList(contextString.codeUnits),
    Uint8List.fromList("id".codeUnits),
    input,
  ]);
}
