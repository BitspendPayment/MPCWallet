import 'dart:async';
import 'dart:typed_data';

/// Transport-level interface for the encrypted recovery-share blob.
///
/// Real implementation: [BackupService] (Google Drive `appDataFolder`).
/// Test implementation: [InMemoryBackupStore] (local map, no network).
///
/// All operations are async and may throw on network/auth failures. None
/// take a password — encryption happens at the [backup_codec] layer below.
abstract class BackupStore {
  /// Whether an authenticated session currently exists.
  bool get isSignedIn;

  /// Email (or similar short identifier) of the signed-in account.
  /// `null` when not signed in.
  String? get accountLabel;

  /// Prompt the user to authenticate. Returns true on success, false on
  /// cancel. Throws [BackupAuthException] on configuration / platform
  /// errors so the UI can show what went wrong.
  Future<bool> signIn();

  /// Try to resume a prior silent session without prompting.
  Future<bool> signInSilently();

  /// End the authenticated session.
  Future<void> signOut();

  /// Upload [blob], overwriting any existing backup.
  Future<void> upload(Uint8List blob);

  /// Download the backup. Returns null if none exists.
  Future<Uint8List?> download();

  /// Delete the backup. No-op if none exists.
  Future<void> delete();

  /// `modifiedTime` of the current backup, or null.
  Future<DateTime?> lastModified();
}

/// Thrown by operations that require auth when none is active.
class NotSignedInException implements Exception {
  @override
  String toString() => 'NotSignedInException: not signed in to backup store';
}

/// Thrown when Google Sign-In itself fails (misconfigured OAuth, missing
/// Play Services, network error, etc.). The [message] is the underlying
/// platform error, intended to be shown to the user verbatim so they (or
/// the developer) can diagnose the cause.
class BackupAuthException implements Exception {
  final String message;
  BackupAuthException(this.message);
  @override
  String toString() => 'BackupAuthException: $message';
}

/// In-memory [BackupStore] for tests. Simulates a single-blob Drive folder.
class InMemoryBackupStore implements BackupStore {
  Uint8List? _blob;
  DateTime? _modifiedTime;
  bool _signedIn;
  String? _accountLabel;

  /// [initiallySignedIn] mirrors a test user who has already authenticated.
  InMemoryBackupStore({
    bool initiallySignedIn = true,
    String accountLabel = 'test@example.com',
  })  : _signedIn = initiallySignedIn,
        _accountLabel = initiallySignedIn ? accountLabel : null;

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get accountLabel => _accountLabel;

  @override
  Future<bool> signIn() async {
    _signedIn = true;
    _accountLabel ??= 'test@example.com';
    return true;
  }

  @override
  Future<bool> signInSilently() async => _signedIn;

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _accountLabel = null;
  }

  @override
  Future<void> upload(Uint8List blob) async {
    if (!_signedIn) throw NotSignedInException();
    _blob = Uint8List.fromList(blob);
    _modifiedTime = DateTime.now();
  }

  @override
  Future<Uint8List?> download() async {
    if (!_signedIn) throw NotSignedInException();
    final b = _blob;
    return b == null ? null : Uint8List.fromList(b);
  }

  @override
  Future<void> delete() async {
    if (!_signedIn) throw NotSignedInException();
    _blob = null;
    _modifiedTime = null;
  }

  @override
  Future<DateTime?> lastModified() async {
    if (!_signedIn) throw NotSignedInException();
    return _modifiedTime;
  }
}
