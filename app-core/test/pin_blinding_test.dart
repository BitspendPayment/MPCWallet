import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:app_core/pin_blinding.dart';
import 'package:app_core/threshold/threshold.dart' as threshold;

/// Headless round-trip for the FROST-share PIN/PRF blinding primitive
/// (`δ = P_full − b`, reconstruct `P_full = δ + b`). No DKG or device needed —
/// the blinding is pure scalar arithmetic over any share/identifier.
void main() {
  final id = threshold.Identifier.derive(
      Uint8List.fromList(List<int>.generate(33, (i) => (i * 7 + 1) & 0xff)));
  final share = threshold.newSecretKey();

  group('PIN-blinding', () {
    test('correct PIN reconstructs the original share', () {
      final seed = seedFromPin('123456');
      final delta = blindShare(share, id, seed);
      final recovered = reconstructShare(delta, id, seed);
      expect(recovered.scalar, equals(share.scalar));
    });

    test('delta alone does not reveal the share', () {
      final delta = blindShare(share, id, seedFromPin('123456'));
      expect(threshold.bytesToBigInt(delta), isNot(equals(share.scalar)),
          reason: 'δ must not equal the raw share');
    });

    test('a wrong PIN reconstructs a different (wrong) share', () {
      final delta = blindShare(share, id, seedFromPin('123456'));
      final wrong = reconstructShare(delta, id, seedFromPin('000000'));
      expect(wrong.scalar, isNot(equals(share.scalar)));
    });

    test('deterministic: the same seed yields the same delta', () {
      final d1 = blindShare(share, id, seedFromPin('42'));
      final d2 = blindShare(share, id, seedFromPin('42'));
      expect(d1, equals(d2));
    });

    test('a high-entropy (PRF-style) 32-byte seed round-trips too', () {
      final prfSeed =
          Uint8List.fromList(List<int>.generate(32, (i) => (i * 31 + 5) & 0xff));
      final delta = blindShare(share, id, prfSeed);
      expect(reconstructShare(delta, id, prfSeed).scalar, equals(share.scalar));
    });
  });
}
