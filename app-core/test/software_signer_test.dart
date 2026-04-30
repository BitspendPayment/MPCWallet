import 'dart:typed_data';

import 'package:app_core/backup/backup_codec.dart';
import 'package:app_core/software_signer.dart';
import 'package:test/test.dart';

/// Tests the in-memory [SoftwareSigner] — no Hive, no FFI-heavy DKG.
/// Full DKG roundtrips live in the e2e test suite.
///
/// Uses low-cost Argon2 params throughout so tests stay fast.
const int _memKib = 8;
const int _iter = 1;
const int _par = 1;

Future<Uint8List> _blob(Map<String, dynamic> payload, String pw) =>
    encryptBackup(payload, pw,
        memoryKib: _memKib, iterations: _iter, parallelism: _par);

void main() {
  group('SoftwareSigner in-memory lifecycle', () {
    test('fromEncryptedBackup rehydrates fields and wipe() clears them',
        () async {
      final idHex =
          '0000000000000000000000000000000000000000000000000000000000000001';
      final payload = {
        'secretKeyHex':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'minSigners': 2,
        'maxSigners': 3,
        'identifierHex': idHex,
        'verifyingKeyHex': '02${'11' * 32}',
      };
      final blob = await _blob(payload, 'pw');

      final signer =
          await SoftwareSigner.fromEncryptedBackup(blob: blob, password: 'pw');
      expect(signer.hasBackupableState, isTrue);

      final info = await signer.getInfo();
      expect(info.hasKeyPackage, isFalse);
      expect(info.hasPendingNonce, isFalse);
      expect(info.identifierHex, equals(idHex));

      await signer.wipe();
      expect(signer.hasBackupableState, isFalse);
      final info2 = await signer.getInfo();
      expect(info2.hasKeyPackage, isFalse);
      expect(info2.identifierHex, isNull);
    });

    test('fromEncryptedBackup with wrong password throws BadPasswordException',
        () async {
      final blob = await _blob({
        'secretKeyHex': '11' * 32,
        'minSigners': 2,
        'maxSigners': 3,
      }, 'right');
      await expectLater(
        SoftwareSigner.fromEncryptedBackup(blob: blob, password: 'wrong'),
        throwsA(isA<BadPasswordException>()),
      );
    });

    test('fromEncryptedBackup rejects blob missing required fields',
        () async {
      final blob = await _blob({'secretKeyHex': '22' * 32}, 'pw');
      await expectLater(
        SoftwareSigner.fromEncryptedBackup(blob: blob, password: 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('exportEncryptedBackup throws when no DKG state exists', () async {
      final signer = SoftwareSigner();
      await expectLater(
        signer.exportEncryptedBackup('pw'),
        throwsA(isA<StateError>()),
      );
    });

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

  group('SoftwareSigner blob round-trip', () {
    test('payload survives encrypt → decrypt with full field set', () async {
      final payload = {
        'secretKeyHex': 'bb' * 32,
        'minSigners': 2,
        'maxSigners': 3,
        // Non-zero identifier (Identifier rejects zero scalars).
        'identifierHex':
            '0000000000000000000000000000000000000000000000000000000000000007',
        'verifyingKeyHex': '02${'dd' * 32}',
      };
      final blob = await _blob(payload, 'pw');
      final decrypted = await decryptBackup(blob, 'pw');
      expect(decrypted, equals(payload));
    });
  });
}
