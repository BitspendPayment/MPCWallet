import 'dart:typed_data';

import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:test/test.dart';

/// The refresh slope must be unreachable to callers and fresh on every call.
///
/// A key-preserving refresh keeps the constant term at the group secret, so the
/// polynomial is a line and IS its slope. Two recipients minted on one slope hold two
/// points on that line and interpolate the group secret outright. `refreshShareToId`
/// therefore draws the slope inside the FFI from the OS CSPRNG — this test pins that
/// behaviour across the ABI (SECURITY_FINDINGS TH-6).
void main() {
  threshold.KeyPackage makeKeyPackage() {
    final secret = threshold.modNRandom();
    final id =
        threshold.Identifier.derive(Uint8List.fromList('wallet'.codeUnits));
    final pointHex = threshold.elemBaseMul(secret); // compressed point hex
    return threshold.KeyPackage(
      id,
      secret,
      pointHex,
      threshold.VerifyingKey(E: pointHex),
      2,
    );
  }

  test('identical inputs yield a different polynomial every call', () {
    final kp = makeKeyPackage();
    final cosignerId =
        threshold.Identifier.derive(Uint8List.fromList('cosigner'.codeUnits));
    final receiverId =
        threshold.Identifier.derive(Uint8List.fromList('service-a'.codeUnits));
    final idSet = [kp.identifier, cosignerId];

    final (a1, c1) =
        threshold.refreshShareToId(kp, idSet, receiverId, cosignerId);
    final (a2, c2) =
        threshold.refreshShareToId(kp, idSet, receiverId, cosignerId);

    expect(a1, isNot(equals(a2)),
        reason: 'a repeated slope would put two services on one line');
    expect(c1, isNot(equals(c2)));
  });
}
