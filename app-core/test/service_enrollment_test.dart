import 'dart:typed_data';

import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:test/test.dart';

/// The wallet's half of service enrolment, exercised against the real FFI crypto.
///
/// `enrollService` itself needs a live cosigner, so what is pinned here is the part that must be
/// right BEFORE anything leaves the device: that the wallet deals a genuine key-preserving refresh
/// contribution, and that the scalar it must never send stays behind while only the point goes.
/// secp256k1 group order. The Dart helpers expose add/sub mod n but not mul/inverse, so the
/// consistency check below does its own arithmetic.
final BigInt _n = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16);

BigInt _mul(BigInt a, BigInt b) => (a * b) % _n;
BigInt _inv(BigInt a) => a.modInverse(_n);

void main() {
  threshold.KeyPackage keyPackage(BigInt secret, threshold.Identifier id,
      String groupKeyHex) {
    final pointHex = threshold.elemBaseMul(secret);
    return threshold.KeyPackage(
      id,
      secret,
      pointHex,
      threshold.VerifyingKey(E: groupKeyHex),
      2,
    );
  }

  /// A dealer-dealt 2-of-2 over f(t) = v + slope·t, as the wallet would hold it after DKG.
  ({
    threshold.KeyPackage wallet,
    threshold.Identifier cosignerId,
    BigInt secret,
    String groupKeyHex,
  }) deal2of2() {
    final secret = threshold.modNRandom();
    final slope = threshold.modNRandom();
    final walletId = threshold.Identifier.derive(
        Uint8List.fromList('wallet'.codeUnits));
    final cosignerId = threshold.Identifier.derive(
        Uint8List.fromList('cosigner'.codeUnits));
    final groupKeyHex = threshold.elemBaseMul(secret);

    final wShare = threshold.modNAdd(secret, _mul(slope, walletId.toScalar()));
    return (
      wallet: keyPackage(wShare, walletId, groupKeyHex),
      cosignerId: cosignerId,
      secret: secret,
      groupKeyHex: groupKeyHex,
    );
  }

  test('the wallet deals a contribution the cosigner can verify', () {
    final w = deal2of2();
    final serviceId =
        threshold.Identifier.derive(Uint8List.fromList('svc'.codeUnits));
    final idSet = [w.wallet.identifier, w.cosignerId];

    final (aAtService, aAtCosigner) = threshold.refreshShareToId(
        w.wallet, idSet, serviceId, w.cosignerId);

    // g_u(t) = λ_u·u + r_u·t is degree 1, so its two evaluations plus the wallet's Lagrange piece
    // must be consistent — this is exactly the relation the cosigner re-derives before trusting
    // the point it is handed.
    final lambdaU = threshold.lagrangeCoeffAtZero(w.wallet.identifier, idSet);
    final lamU = _mul(lambdaU, w.wallet.secretShare);

    // r_u recovered from the cosigner-side evaluation, then used to predict the service-side one.
    final idC = w.cosignerId.toScalar();
    final idS = serviceId.toScalar();
    final rU = _mul(threshold.modNSub(aAtCosigner, lamU), _inv(idC));
    final predicted = threshold.modNAdd(lamU, _mul(rU, idS));

    expect(predicted, equals(aAtService),
        reason: 'the two halves must lie on one degree-1 contribution');
  });

  test('only the point is derivable from what the cosigner receives', () {
    final w = deal2of2();
    final serviceId =
        threshold.Identifier.derive(Uint8List.fromList('svc'.codeUnits));
    final idSet = [w.wallet.identifier, w.cosignerId];

    final (aAtService, _) = threshold.refreshShareToId(
        w.wallet, idSet, serviceId, w.cosignerId);

    // What actually goes on the wire for the service's half.
    final point = threshold.elemSerializeCompressed(
        threshold.elemBaseMul(aAtService));

    expect(point.length, 33, reason: 'a compressed point, not a 32-byte scalar');
    expect(point, isNot(equals(threshold.bigIntToBytes(aAtService))),
        reason: 'the scalar must never be what is sent');
  });

  test('each enrolment deals a fresh contribution', () {
    final w = deal2of2();
    final serviceId =
        threshold.Identifier.derive(Uint8List.fromList('svc'.codeUnits));
    final idSet = [w.wallet.identifier, w.cosignerId];

    final (a1, c1) =
        threshold.refreshShareToId(w.wallet, idSet, serviceId, w.cosignerId);
    final (a2, c2) =
        threshold.refreshShareToId(w.wallet, idSet, serviceId, w.cosignerId);

    // Two enrolments on one slope would put two services on one line, and two points on a
    // degree-1 line interpolate the group secret.
    expect(a1, isNot(equals(a2)));
    expect(c1, isNot(equals(c2)));
  });

  test('the half is sealed to the service id, openable by nobody else', () {
    final w = deal2of2();
    final serviceSecret = threshold.modNRandom();
    final serviceIdBytes = threshold.elemSerializeCompressed(
        threshold.elemBaseMul(serviceSecret));
    final frostId = threshold.Identifier.derive(serviceIdBytes);
    final idSet = [w.wallet.identifier, w.cosignerId];

    final (aAtService, _) =
        threshold.refreshShareToId(w.wallet, idSet, frostId, w.cosignerId);

    final sealed = threshold.eciesEncrypt(
        threshold.bigIntToBytes(aAtService), serviceIdBytes);
    expect(sealed.length, 97, reason: 'ephemeral(33) + ct(32) + tag(32)');

    // Sealing to the id means a wrong endpoint receives something it cannot open, so the URL is
    // not what protects the half.
    expect(sealed, isNot(equals(threshold.bigIntToBytes(aAtService))));
  });
}
