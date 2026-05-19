/// Dart client for `scripts/cosigner_lifecycle.py` — the host-side HTTP
/// helper that owns the cosigner-runtime subprocess.
///
/// The emulator reaches the host at 10.0.2.2:7099 (adb-reverse'd via the
/// `integration-test-lifecycle-ark` Makefile target).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CosignerLifecycle {
  CosignerLifecycle({this.baseUrl = 'http://10.0.2.2:7099'});

  final String baseUrl;
  final HttpClient _http = HttpClient();

  Future<Map<String, dynamic>> _request(
      String method, String path) async {
    final req = await _http.openUrl(method, Uri.parse('$baseUrl$path'));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      throw Exception('lifecycle $method $path: ${resp.statusCode} $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<bool> isRunning() async {
    final r = await _request('GET', '/status');
    return r['running'] as bool;
  }

  /// Start cosigner-runtime if not already running. Idempotent.
  Future<void> start() async => _request('POST', '/start');

  /// SIGTERM the cosigner. Idempotent.
  Future<void> kill() async => _request('POST', '/kill');

  /// Kill + start. Same data_dir, so sled state is preserved.
  Future<void> restart() async => _request('POST', '/restart');

  /// Poll `/status` until the cosigner is running. Useful right after
  /// `start()` or `restart()` since the subprocess takes a moment to bind
  /// its REST port.
  Future<void> waitForRunning(
      {Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await isRunning()) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw TimeoutException(
        'cosigner-lifecycle did not report running within $timeout');
  }
}
