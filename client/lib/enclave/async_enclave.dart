/// Async wrapper for NativeEnclaveClient that runs FFI calls in a
/// background isolate to avoid blocking the Dart main isolate.
///
/// The NativeEnclaveClient uses synchronous FFI calls (Rust block_on)
/// which freeze the main isolate on Android, killing USB callbacks and
/// UI updates. This wrapper runs all FFI in a dedicated background isolate.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'native_enclave.dart';

/// Debug-safe print that works in both Flutter and pure Dart (e2e tests).
void _log(String message) {
  developer.log(message, name: 'AsyncEnclave');
}

/// Message types for isolate communication.
sealed class _Request {}

class _PostRequest extends _Request {
  final String path;
  final String body;
  final SendPort replyPort;
  _PostRequest(this.path, this.body, this.replyPort);
}

class _GetRequest extends _Request {
  final String path;
  final SendPort replyPort;
  _GetRequest(this.path, this.replyPort);
}

class _StatusRequest extends _Request {
  final SendPort replyPort;
  _StatusRequest(this.replyPort);
}

class _VerifyRequest extends _Request {
  final SendPort replyPort;
  _VerifyRequest(this.replyPort);
}

class _DisposeRequest extends _Request {
  final SendPort replyPort;
  _DisposeRequest(this.replyPort);
}

/// Config passed to the background isolate on startup.
class _IsolateConfig {
  final String baseUrl;
  final String expectedPcr0;
  final int cacheTtlSecs;
  final SendPort mainPort;
  _IsolateConfig(
      this.baseUrl, this.expectedPcr0, this.cacheTtlSecs, this.mainPort);
}

/// Non-blocking enclave client that runs FFI calls in a background isolate.
class AsyncEnclaveClient {
  late final SendPort _isolatePort;
  late final Isolate _isolate;
  bool _disposed = false;

  AsyncEnclaveClient._();

  /// Create and initialize the async enclave client.
  /// The background isolate is spawned and the NativeEnclaveClient is
  /// created inside it.
  static Future<AsyncEnclaveClient> create(
    String baseUrl,
    String expectedPcr0, {
    int cacheTtlSecs = 60,
  }) async {
    final client = AsyncEnclaveClient._();

    final receivePort = ReceivePort();
    final config = _IsolateConfig(
      baseUrl,
      expectedPcr0,
      cacheTtlSecs,
      receivePort.sendPort,
    );

    client._isolate = await Isolate.spawn(_isolateEntry, config);

    // Wait for the background isolate to send its SendPort (or error).
    final completer = Completer<SendPort>();
    receivePort.listen((msg) {
      if (msg is SendPort && !completer.isCompleted) {
        completer.complete(msg);
      } else if (msg is String &&
          msg.startsWith('ERROR:') &&
          !completer.isCompleted) {
        completer.completeError(StateError(msg));
      }
    });
    client._isolatePort = await completer.future;
    receivePort.close();
    _log('[AsyncEnclave] Background isolate ready');

    return client;
  }

  /// Background isolate entry point.
  static void _isolateEntry(_IsolateConfig config) {
    NativeEnclaveClient client;
    try {
      client = NativeEnclaveClient(
        config.baseUrl,
        config.expectedPcr0,
        cacheTtlSecs: config.cacheTtlSecs,
      );
    } catch (e) {
      _log(
          '[AsyncEnclave] Failed to create NativeEnclaveClient in isolate: $e');
      // Send error back -- the main isolate will get a null SendPort
      config.mainPort.send('ERROR: $e');
      return;
    }
    _log('[AsyncEnclave] NativeEnclaveClient created in background isolate');

    final receivePort = ReceivePort();
    config.mainPort.send(receivePort.sendPort);

    receivePort.listen((msg) {
      if (msg is _PostRequest) {
        try {
          _log('[AsyncEnclave] POST ${msg.path}...');
          final resp = client.post(msg.path, msg.body);
          _log(
              '[AsyncEnclave] POST ${msg.path} -> ${resp.statusCode} (${resp.body.length} bytes, sig=${resp.signatureVerified})');
          msg.replyPort.send(jsonEncode({
            'status_code': resp.statusCode,
            'body': resp.body,
            'signature_verified': resp.signatureVerified,
          }));
        } catch (e) {
          _log('[AsyncEnclave] POST ${msg.path} ERROR: $e');
          msg.replyPort.send(jsonEncode({'error': e.toString()}));
        }
      } else if (msg is _GetRequest) {
        try {
          final resp = client.get(msg.path);
          msg.replyPort.send(jsonEncode({
            'status_code': resp.statusCode,
            'body': resp.body,
            'signature_verified': resp.signatureVerified,
          }));
        } catch (e) {
          msg.replyPort.send(jsonEncode({'error': e.toString()}));
        }
      } else if (msg is _StatusRequest) {
        try {
          final status = client.attestationStatus;
          _log('[AsyncEnclave] Status: verified=${status.verified}, pcr0=${status.pcr0.length}, ttl=${status.ttlRemainingSecs}, epoch=${status.verifiedAtEpochSecs}');
          msg.replyPort.send(jsonEncode({
            'verified': status.verified,
            'pcr0': status.pcr0,
            'verified_at_epoch_secs': status.verifiedAtEpochSecs,
            'ttl_remaining_secs': status.ttlRemainingSecs,
            'attestation_key': status.attestationKey,
          }));
        } catch (e) {
          msg.replyPort.send(jsonEncode({
            'verified': false,
            'error': e.toString(),
          }));
        }
      } else if (msg is _VerifyRequest) {
        try {
          final status = client.verify();
          msg.replyPort.send(jsonEncode({
            'verified': status.verified,
            'pcr0': status.pcr0,
            'verified_at_epoch_secs': status.verifiedAtEpochSecs,
            'ttl_remaining_secs': status.ttlRemainingSecs,
            'attestation_key': status.attestationKey,
          }));
        } catch (e) {
          msg.replyPort.send(jsonEncode({
            'verified': false,
            'error': e.toString(),
          }));
        }
      } else if (msg is _DisposeRequest) {
        client.dispose();
        msg.replyPort.send('done');
        receivePort.close();
      }
    });
  }

  /// Make a verified POST request (non-blocking).
  Future<EnclaveResponse> post(String path, String body) async {
    _checkDisposed();
    final replyPort = ReceivePort();
    _isolatePort.send(_PostRequest(path, body, replyPort.sendPort));
    final result = await replyPort.first as String;
    replyPort.close();
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json.containsKey('error') && !json.containsKey('status_code')) {
      throw Exception(json['error']);
    }
    return EnclaveResponse.fromJson(json);
  }

  /// Make a verified GET request (non-blocking).
  Future<EnclaveResponse> get(String path) async {
    _checkDisposed();
    final replyPort = ReceivePort();
    _isolatePort.send(_GetRequest(path, replyPort.sendPort));
    final result = await replyPort.first as String;
    replyPort.close();
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json.containsKey('error') && !json.containsKey('status_code')) {
      throw Exception(json['error']);
    }
    return EnclaveResponse.fromJson(json);
  }

  /// Get attestation status (non-blocking).
  Future<AttestationStatus> getAttestationStatus() async {
    _checkDisposed();
    final replyPort = ReceivePort();
    _isolatePort.send(_StatusRequest(replyPort.sendPort));
    final result = await replyPort.first as String;
    replyPort.close();
    return AttestationStatus.fromJson(
        jsonDecode(result) as Map<String, dynamic>);
  }

  /// Force attestation verification and return the result.
  /// Throws if verification fails (PCR0 mismatch, enclave unreachable, etc.).
  Future<AttestationStatus> verify() async {
    _checkDisposed();
    final replyPort = ReceivePort();
    _isolatePort.send(_VerifyRequest(replyPort.sendPort));
    final result = await replyPort.first as String;
    replyPort.close();
    final status = AttestationStatus.fromJson(
        jsonDecode(result) as Map<String, dynamic>);
    if (!status.verified) {
      throw StateError(
          'Attestation verification failed: ${status.error ?? "PCR0 mismatch or enclave unreachable"}');
    }
    return status;
  }

  /// Dispose the client and kill the background isolate.
  Future<void> dispose() async {
    if (!_disposed) {
      _disposed = true;
      final replyPort = ReceivePort();
      _isolatePort.send(_DisposeRequest(replyPort.sendPort));
      await replyPort.first;
      replyPort.close();
      _isolate.kill();
    }
  }

  void _checkDisposed() {
    if (_disposed) throw StateError('AsyncEnclaveClient has been disposed');
  }
}
