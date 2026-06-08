import 'dart:ffi';

import 'package:app_core/threshold/frost/commitment.dart';
import 'package:test/test.dart';

/// Guards around single-use of [SigningNonce]. The Rust `sign` FFI consumes
/// (frees) the nonce handle, so reusing a nonce must fail loudly rather than
/// pass a dangling pointer (a nonce reuse would leak the secret share).
void main() {
  group('SigningNonce reuse guard', () {
    test('handle throws after markConsumed', () {
      final nonce = SigningNonce(
        BigInt.zero,
        BigInt.zero,
        SigningCommitments('00', '00'),
        Pointer<Void>.fromAddress(0x1000), // dummy; never dereferenced here
      );

      expect(nonce.isConsumed, isFalse);
      expect(() => nonce.handle, returnsNormally);

      nonce.markConsumed();

      expect(nonce.isConsumed, isTrue);
      expect(() => nonce.handle, throwsStateError);
    });

    test('handle throws when no FFI handle is present', () {
      final nonce = SigningNonce(
        BigInt.zero,
        BigInt.zero,
        SigningCommitments('00', '00'),
      );
      expect(() => nonce.handle, throwsStateError);
    });
  });
}
