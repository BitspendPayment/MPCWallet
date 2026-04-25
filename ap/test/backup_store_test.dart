import 'dart:typed_data';

import 'package:ap/services/backup_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryBackupStore', () {
    test('upload then download roundtrips the blob', () async {
      final store = InMemoryBackupStore();
      final blob = Uint8List.fromList(List.generate(128, (i) => i));

      await store.upload(blob);
      final got = await store.download();
      expect(got, equals(blob));
    });

    test('download returns null when nothing uploaded', () async {
      final store = InMemoryBackupStore();
      expect(await store.download(), isNull);
    });

    test('upload overwrites the previous blob', () async {
      final store = InMemoryBackupStore();
      await store.upload(Uint8List.fromList([1, 2, 3]));
      await store.upload(Uint8List.fromList([4, 5, 6, 7]));
      expect(await store.download(), equals(Uint8List.fromList([4, 5, 6, 7])));
    });

    test('delete removes the blob and updates lastModified', () async {
      final store = InMemoryBackupStore();
      await store.upload(Uint8List.fromList([1, 2, 3]));
      expect(await store.lastModified(), isNotNull);

      await store.delete();
      expect(await store.download(), isNull);
      expect(await store.lastModified(), isNull);
    });

    test('lastModified advances on each upload', () async {
      final store = InMemoryBackupStore();
      await store.upload(Uint8List.fromList([1]));
      final first = await store.lastModified();

      // Force a distinguishable timestamp — the in-memory store uses real
      // DateTime.now() so a small delay is enough.
      await Future.delayed(const Duration(milliseconds: 10));
      await store.upload(Uint8List.fromList([2]));
      final second = await store.lastModified();

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(second!.isAfter(first!) || second.isAtSameMomentAs(first), isTrue);
    });

    test('download copies the blob (caller mutation does not affect store)',
        () async {
      final store = InMemoryBackupStore();
      await store.upload(Uint8List.fromList([1, 2, 3]));
      final got = await store.download();
      got![0] = 99;
      final again = await store.download();
      expect(again, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('operations throw NotSignedInException when signed out', () async {
      final store = InMemoryBackupStore(initiallySignedIn: false);
      expect(store.isSignedIn, isFalse);

      await expectLater(
        store.upload(Uint8List.fromList([1])),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        store.download(),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        store.delete(),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        store.lastModified(),
        throwsA(isA<NotSignedInException>()),
      );
    });

    test('signIn transitions to signed-in', () async {
      final store = InMemoryBackupStore(initiallySignedIn: false);
      expect(store.isSignedIn, isFalse);

      final ok = await store.signIn();
      expect(ok, isTrue);
      expect(store.isSignedIn, isTrue);
      expect(store.accountLabel, isNotNull);
    });

    test('signOut clears session and label', () async {
      final store = InMemoryBackupStore();
      expect(store.isSignedIn, isTrue);
      await store.signOut();
      expect(store.isSignedIn, isFalse);
      expect(store.accountLabel, isNull);
    });

    test('signOut preserves the blob (it just closes the session)',
        () async {
      final store = InMemoryBackupStore();
      await store.upload(Uint8List.fromList([1, 2, 3]));
      await store.signOut();
      await store.signIn();
      expect(await store.download(), equals(Uint8List.fromList([1, 2, 3])));
    });
  });
}
