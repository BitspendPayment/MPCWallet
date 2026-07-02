import 'dart:typed_data';

import 'package:app_core/software_signer.dart';
import 'package:test/test.dart';

/// Tests the in-memory [SoftwareSigner] — no Hive, no FFI-heavy DKG.
/// Full DKG roundtrips live in the e2e test suite.
void main() {
  group('SoftwareSigner in-memory lifecycle', () {
    test('sign() throws when no key package is loaded', () async {
      final signer = SoftwareSigner();
      await expectLater(
        signer.sign(
          message: Uint8List.fromList([1, 2, 3]),
          commitments: const {},
          applyTweak: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('generateNonce() throws when no key package is loaded', () async {
      final signer = SoftwareSigner();
      await expectLater(
        signer.generateNonce(),
        throwsA(isA<StateError>()),
      );
    });

    test('restoreInit() throws when no secret is loaded', () async {
      final signer = SoftwareSigner();
      await expectLater(
        signer.restoreInit(3, 2),
        throwsA(isA<StateError>()),
      );
    });
  });
}
