import 'dart:async';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:synchronized/synchronized.dart';

import 'backup_store.dart';

/// Google Drive–backed [BackupStore].
///
/// Uses `appDataFolder` — a hidden per-app folder the user can't see in the
/// Drive UI; only this app's OAuth client can read/write. Single file named
/// `wallet.mpcbackup`.
///
/// All operations serialize on an internal [Lock] so concurrent uploads
/// can't interleave.
class BackupService implements BackupStore {
  static const String _fileName = 'wallet.mpcbackup';
  static const String _appDataFolder = 'appDataFolder';

  final GoogleSignIn _googleSignIn;
  final Lock _lock = Lock();

  GoogleSignInAccount? _account;
  drive.DriveApi? _driveApi;

  BackupService({GoogleSignIn? signIn})
      : _googleSignIn = signIn ??
            GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);

  GoogleSignInAccount? get account => _account;

  @override
  bool get isSignedIn => _account != null && _driveApi != null;

  @override
  String? get accountLabel => _account?.email;

  @override
  Future<bool> signIn() async {
    return _lock.synchronized(() async {
      try {
        _account = await _googleSignIn.signIn();
        if (_account == null) return false; // user cancelled
        await _attachDriveApi();
        return true;
      } catch (e) {
        debugPrint('BackupService.signIn failed: $e');
        _account = null;
        _driveApi = null;
        // Surface the real error so the UI can display it. Common causes:
        //   * "sign_in_failed, ApiException: 10" — OAuth client misconfigured
        //     in Google Cloud Console (wrong package name / SHA-1)
        //   * "sign_in_failed, ApiException: 12500" — Google Play Services
        //     missing or out of date (common on stripped emulators)
        //   * "PlatformException(network_error...)" — no internet
        //   * "Drive API has not been used in project ..." — enable Drive
        //     API in Cloud Console
        throw BackupAuthException(e.toString());
      }
    });
  }

  @override
  Future<bool> signInSilently() async {
    return _lock.synchronized(() async {
      try {
        _account = await _googleSignIn.signInSilently();
        if (_account == null) return false;
        await _attachDriveApi();
        return true;
      } catch (e) {
        debugPrint('BackupService.signInSilently failed: $e');
        _account = null;
        _driveApi = null;
        return false;
      }
    });
  }

  @override
  Future<void> signOut() async {
    await _lock.synchronized(() async {
      try {
        await _googleSignIn.signOut();
      } finally {
        _account = null;
        _driveApi = null;
      }
    });
  }

  @override
  Future<void> upload(Uint8List blob) async {
    await _lock.synchronized(() async {
      final api = _requireDrive();
      final existingId = await _findBlobFileId(api);
      final media = drive.Media(Stream.value(blob), blob.length);
      if (existingId != null) {
        await api.files.update(
          drive.File(),
          existingId,
          uploadMedia: media,
        );
      } else {
        await api.files.create(
          drive.File()
            ..name = _fileName
            ..parents = [_appDataFolder],
          uploadMedia: media,
        );
      }
    });
  }

  @override
  Future<Uint8List?> download() async {
    return _lock.synchronized(() async {
      final api = _requireDrive();
      final fileId = await _findBlobFileId(api);
      if (fileId == null) return null;

      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final builder = BytesBuilder(copy: false);
      await for (final chunk in media.stream) {
        builder.add(chunk);
      }
      return builder.toBytes();
    });
  }

  @override
  Future<void> delete() async {
    await _lock.synchronized(() async {
      final api = _requireDrive();
      final fileId = await _findBlobFileId(api);
      if (fileId == null) return;
      await api.files.delete(fileId);
    });
  }

  @override
  Future<DateTime?> lastModified() async {
    return _lock.synchronized(() async {
      final api = _requireDrive();
      final list = await api.files.list(
        spaces: _appDataFolder,
        q: "name = '$_fileName'",
        $fields: 'files(id, modifiedTime)',
      );
      final files = list.files;
      if (files == null || files.isEmpty) return null;
      return files.first.modifiedTime;
    });
  }

  Future<void> _attachDriveApi() async {
    final acct = _account;
    if (acct == null) {
      _driveApi = null;
      return;
    }
    final authClient = await _googleSignIn.authenticatedClient();
    if (authClient == null) {
      _driveApi = null;
      throw StateError('failed to build authenticated Drive client');
    }
    _driveApi = drive.DriveApi(authClient);
  }

  drive.DriveApi _requireDrive() {
    final api = _driveApi;
    if (api == null) throw NotSignedInException();
    return api;
  }

  Future<String?> _findBlobFileId(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: _appDataFolder,
      q: "name = '$_fileName'",
      $fields: 'files(id, modifiedTime)',
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }
}
