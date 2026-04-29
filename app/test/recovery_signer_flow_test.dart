import 'dart:typed_data';

import 'package:app/services/backup_store.dart';
import 'package:client/backup/backup_codec.dart';
import 'package:client/software_signer.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end style tests for the ephemeral-recovery-share flow. The real
/// DKG requires FFI + the co-signing server, so these tests simulate the
/// post-DKG blob shape directly and exercise the transport + rehydration
/// layers: export → upload → download → decrypt → use → wipe.
const int _memKib = 8;
const int _iter = 1;
const int _par = 1;

Future<Uint8List> _fakePostDkgBlob({
  required String password,
  String? secretKeyHex,
  int minSigners = 2,
  int maxSigners = 3,
  String? identifierHex,
  String? verifyingKeyHex,
}) =>
    encryptBackup({
      'secretKeyHex': secretKeyHex ?? 'aa' * 32,
      'minSigners': minSigners,
      'maxSigners': maxSigners,
      'identifierHex': identifierHex ?? 'bb' * 32,
      'verifyingKeyHex': verifyingKeyHex ?? '02${'cc' * 32}',
    }, password,
        memoryKib: _memKib, iterations: _iter, parallelism: _par);

void main() {
  group('recovery share survives the "upload → discard → restore" cycle', () {
    test('blob from device A decrypts on device B with the same password',
        () async {
      final store = InMemoryBackupStore();

      // Device A: post-DKG, uploads the encrypted blob.
      final deviceABlob = await _fakePostDkgBlob(password: 'correct-horse');
      await store.upload(deviceABlob);

      // Device A closes the app (signer wiped from RAM).

      // Device B: fresh install, signs in to the same backup store.
      final downloaded = await store.download();
      expect(downloaded, isNotNull);
      expect(downloaded, equals(deviceABlob));

      // Device B unlocks with the password.
      final signerB = await SoftwareSigner.fromEncryptedBackup(
        blob: downloaded!,
        password: 'correct-horse',
      );
      expect(signerB.hasBackupableState, isTrue);
      final info = await signerB.getInfo();
      expect(info.identifierHex, equals('bb' * 32));

      // Device B drops the signer after the op.
      await signerB.wipe();
      expect(signerB.hasBackupableState, isFalse);
    });

    test('wrong password on restore rejects without leaking state',
        () async {
      final store = InMemoryBackupStore();
      await store.upload(await _fakePostDkgBlob(password: 'correct'));

      final blob = await store.download();
      await expectLater(
        SoftwareSigner.fromEncryptedBackup(
          blob: blob!,
          password: 'wrong',
        ),
        throwsA(isA<BadPasswordException>()),
      );
      // Store remains intact — wrong password is a client-side rejection.
      expect(await store.download(), equals(blob));
    });

    test('blob tampering in transit is detected on restore', () async {
      final store = InMemoryBackupStore();
      await store.upload(await _fakePostDkgBlob(password: 'pw'));

      // Simulate a MITM flipping a bit in the ciphertext region.
      final stored = await store.download();
      stored![70] ^= 0x01;
      await store.upload(stored);

      final corrupted = await store.download();
      await expectLater(
        SoftwareSigner.fromEncryptedBackup(
          blob: corrupted!,
          password: 'pw',
        ),
        throwsA(isA<BadPasswordException>()),
      );
    });

    test('policy-op lifecycle: load → use → unload leaves no residue',
        () async {
      final store = InMemoryBackupStore();
      await store.upload(await _fakePostDkgBlob(password: 'pw'));

      // Simulate loadRecoverySigner.
      final blob = await store.download();
      final signer = await SoftwareSigner.fromEncryptedBackup(
        blob: blob!,
        password: 'pw',
      );
      expect(signer.hasBackupableState, isTrue);

      // Policy op would happen here — nothing to do in the transport-layer
      // test; the signer is ready for getInfo/generateNonce/sign.

      // Simulate unloadRecoverySigner.
      await signer.wipe();
      expect(signer.hasBackupableState, isFalse);

      // The blob on the store is untouched — policy ops don't modify it.
      expect(await store.download(), equals(blob));
    });

    test('re-upload after restore refreshes the salt/nonce even if payload '
        'unchanged', () async {
      final store = InMemoryBackupStore();

      final original = await _fakePostDkgBlob(password: 'pw');
      await store.upload(original);

      // Load, re-export (without running DKG), re-upload.
      final downloaded = await store.download();
      final signer = await SoftwareSigner.fromEncryptedBackup(
        blob: downloaded!,
        password: 'pw',
      );
      // NOTE: full state (including KeyPackage) won't be in our synthetic
      // blob, but secretKey + min/max are enough for exportEncryptedBackup.
      final refreshed = await signer.exportEncryptedBackup('pw');
      await store.upload(refreshed);
      await signer.wipe();

      final afterRefresh = await store.download();
      // New salt + nonce mean a new ciphertext even though the plaintext
      // payload is equivalent.
      expect(afterRefresh, isNot(equals(original)));

      // But it still decrypts to a valid payload with the same password.
      final signer2 = await SoftwareSigner.fromEncryptedBackup(
        blob: afterRefresh!,
        password: 'pw',
      );
      expect(signer2.hasBackupableState, isTrue);
      await signer2.wipe();
    });

    test('delete wipes the blob so future restore returns null', () async {
      final store = InMemoryBackupStore();
      await store.upload(await _fakePostDkgBlob(password: 'pw'));
      expect(await store.download(), isNotNull);

      await store.delete();
      expect(await store.download(), isNull);
    });
  });
}
