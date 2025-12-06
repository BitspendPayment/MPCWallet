import 'package:threshold/threshold.dart';
import 'package:test/test.dart';

import 'test_helper.dart';

void main() {
  group('Utils', () {
    test('TestLagrangeCoeffAtZero_ReconstructsConstantTerm', () {
      final S = defaultIdentifiers(3);

      final a0 = BigInt.from(12345);
      final a1 = BigInt.from(6789);
      final a2 = BigInt.from(42);
      final coeffs = [a0, a1, a2];

      final shares = <Identifier, BigInt>{};
      for (final id in S) {
        final yi = evaluatePolynomial(id, coeffs);
        shares[id] = yi;
      }

      var recon = modNZero();
      for (final sh in shares.entries) {
        final lambda = lagrangeCoeffAtZero(sh.key, S);
        final term = (sh.value * lambda) % secp256k1Curve.n;
        recon = (recon + term) % secp256k1Curve.n;
      }

      expect(recon, equals(a0));
    });

    test('TestLagrangeCoeffAtZero_PermutationInvariant', () {
      final id1 = identifierFromUint16(1);
      final id2 = identifierFromUint16(2);
      final id4 = identifierFromUint16(4);
      final id7 = identifierFromUint16(7);

      final S1 = [id1, id2, id4, id7];
      final S2 = [id7, id4, id2, id1];

      for (final id in S1) {
        final l1 = lagrangeCoeffAtZero(id, S1);
        final l2 = lagrangeCoeffAtZero(id, S2);
        expect(l1, equals(l2));
      }
    });

    test('TestEvaluatePolynomial_EmptyCoeffs', () {
      final id = identifierFromUint16(123);
      final got = evaluatePolynomial(id, []);
      expect(got, equals(modNZero()));
    });

    test('TestEvaluatePolynomial_AgainstNaivePowerSum', () {
      final ids = [
        identifierFromUint16(1),
        identifierFromUint16(2),
        identifierFromUint16(4),
        identifierFromUint16(7),
        identifierFromUint16(8),
      ];

      for (var degree = 1; degree <= 5; degree++) {
        final coeffs = List<BigInt>.generate(degree + 1, (_) => modNRandom());
        for (final id in ids) {
          final got = evaluatePolynomial(id, coeffs);
          final want = naiveEvaluatePolynomial(id, coeffs);
          expect(got, equals(want));
        }
      }
    });

    test('TestEvaluatePolynomial_Constant', () {
      final id = identifierFromUint16(123);
      final c0 = modNRandom();

      final got = evaluatePolynomial(id, [c0]);
      expect(got, equals(c0));
    });


  });
}

BigInt naiveEvaluatePolynomial(Identifier id, List<BigInt> coeffs) {
  if (coeffs.isEmpty) {
    return modNZero();
  }
  final x = id.toScalar();
  var pow = modNOne();
  var sum = modNZero();
  for (var k = 0; k < coeffs.length; k++) {
    final term = (coeffs[k] * pow) % secp256k1Curve.n;
    sum = (sum + term) % secp256k1Curve.n;
    pow = (pow * x) % secp256k1Curve.n;
  }
  return sum;
}
