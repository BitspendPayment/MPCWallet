import 'dart:typed_data';

import 'package:client/backup/backup_codec.dart';
import 'package:test/test.dart';

/// Use low-cost Argon2 params throughout so tests stay fast.
const int _memKib = 8;
const int _iter = 1;
const int _par = 1;

Future<Uint8List> _encryptFast(Map<String, dynamic> pt, String pw) =>
    encryptBackup(pt, pw,
        memoryKib: _memKib, iterations: _iter, parallelism: _par);

void main() {
  group('backup codec', () {
    test('roundtrip', () async {
      final plaintext = {
        'secretKeyHex':
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
        'minSigners': 2,
        'maxSigners': 3,
      };
      final blob = await _encryptFast(plaintext, 'correct horse battery');

      // Header starts with magic "MPCB"
      expect(blob[0], 0x4D);
      expect(blob[1], 0x50);
      expect(blob[2], 0x43);
      expect(blob[3], 0x42);
      expect(blob[4], 0x01); // version

      final decrypted = await decryptBackup(blob, 'correct horse battery');
      expect(decrypted, equals(plaintext));
    });

    test('wrong password is rejected', () async {
      final blob = await _encryptFast({'x': 1}, 'right');
      await expectLater(
        decryptBackup(blob, 'wrong'),
        throwsA(isA<BadPasswordException>()),
      );
    });

    test('tampered ciphertext is rejected', () async {
      final blob = await _encryptFast({'x': 1}, 'pw');
      // Flip a bit inside the ciphertext region (after 60-byte header).
      blob[70] ^= 0x01;
      await expectLater(
        decryptBackup(blob, 'pw'),
        throwsA(isA<BadPasswordException>()),
      );
    });

    test('tampered header is rejected', () async {
      final blob = await _encryptFast({'x': 1}, 'pw');
      // Flip a bit in the salt (part of the AAD).
      blob[25] ^= 0x80;
      await expectLater(
        decryptBackup(blob, 'pw'),
        throwsA(isA<BadPasswordException>()),
      );
    });

    test('bad magic is rejected', () async {
      final blob = await _encryptFast({'x': 1}, 'pw');
      blob[0] = 0x00;
      await expectLater(
        decryptBackup(blob, 'pw'),
        throwsA(isA<MalformedBlobException>()),
      );
    });

    test('unsupported version is rejected', () async {
      final blob = await _encryptFast({'x': 1}, 'pw');
      blob[4] = 0x02; // claim version 2
      await expectLater(
        decryptBackup(blob, 'pw'),
        throwsA(isA<UnsupportedVersionException>()),
      );
    });

    test('blobs with same password use fresh salt+nonce', () async {
      final a = await _encryptFast({'k': 'v'}, 'pw');
      final b = await _encryptFast({'k': 'v'}, 'pw');
      // Same plaintext + same password must never produce identical output
      // (salt and nonce are randomised each call).
      expect(a, isNot(equals(b)));
    });
  });
}
