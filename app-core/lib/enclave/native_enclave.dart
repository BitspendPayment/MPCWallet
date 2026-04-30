/// Dart FFI bindings for the enclave-client Rust crate.
///
/// Provides verified HTTP communication with AWS Nitro Enclaves,
/// including attestation verification and response signature checking.
library;

import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'native_library.dart';

// FFI function signatures
typedef _NewNative = Pointer<Void> Function(
    Pointer<Utf8>, Pointer<Utf8>, Uint32);
typedef _NewDart = Pointer<Void> Function(
    Pointer<Utf8>, Pointer<Utf8>, int);

typedef _PostNative = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _PostDart = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef _GetNative = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _GetDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

typedef _StatusNative = Pointer<Utf8> Function(Pointer<Void>);
typedef _StatusDart = Pointer<Utf8> Function(Pointer<Void>);

typedef _VerifyNative = Pointer<Utf8> Function(Pointer<Void>);
typedef _VerifyDart = Pointer<Utf8> Function(Pointer<Void>);

typedef _FreeClientNative = Void Function(Pointer<Void>);
typedef _FreeClientDart = void Function(Pointer<Void>);

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

/// Attestation verification status from the enclave client.
class AttestationStatus {
  final bool verified;
  final String pcr0;
  final int verifiedAtEpochSecs;
  final int ttlRemainingSecs;
  final String attestationKey;
  final String? error;

  AttestationStatus({
    required this.verified,
    required this.pcr0,
    required this.verifiedAtEpochSecs,
    required this.ttlRemainingSecs,
    required this.attestationKey,
    this.error,
  });

  factory AttestationStatus.fromJson(Map<String, dynamic> json) {
    return AttestationStatus(
      verified: json['verified'] as bool? ?? false,
      pcr0: json['pcr0'] as String? ?? '',
      verifiedAtEpochSecs: json['verified_at_epoch_secs'] as int? ?? 0,
      ttlRemainingSecs: json['ttl_remaining_secs'] as int? ?? 0,
      attestationKey: json['attestation_key'] as String? ?? '',
      error: json['error'] as String?,
    );
  }

  Duration get ttlRemaining => Duration(seconds: ttlRemainingSecs);

  DateTime? get verifiedAt => verifiedAtEpochSecs > 0
      ? DateTime.fromMillisecondsSinceEpoch(verifiedAtEpochSecs * 1000)
      : null;
}

/// Response from an attested HTTP request.
class EnclaveResponse {
  final int statusCode;
  final String body;
  final bool signatureVerified;
  final String? error;

  EnclaveResponse({
    required this.statusCode,
    required this.body,
    required this.signatureVerified,
    this.error,
  });

  factory EnclaveResponse.fromJson(Map<String, dynamic> json) {
    return EnclaveResponse(
      statusCode: json['status_code'] as int? ?? 0,
      body: json['body'] as String? ?? '',
      signatureVerified: json['signature_verified'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  bool get isOk => statusCode >= 200 && statusCode < 300 && error == null;
}

/// Verified HTTP client for AWS Nitro Enclaves via Rust FFI.
///
/// Every request verifies the enclave's attestation document (PCR0)
/// and checks the BIP-340 Schnorr response signature.
class NativeEnclaveClient {
  late final Pointer<Void> _ptr;
  late final _PostDart _post;
  late final _GetDart _get;
  late final _StatusDart _status;
  late final _VerifyDart _verify;
  late final _FreeClientDart _freeClient;
  late final _FreeStringDart _freeString;
  bool _disposed = false;

  /// Create a new enclave client.
  ///
  /// [baseUrl] - HTTPS endpoint of the enclave (e.g. "https://1.2.3.4")
  /// [expectedPcr0] - Expected PCR0 hex string (96 chars, SHA-384)
  /// [cacheTtlSecs] - Attestation cache TTL in seconds (default: 60)
  NativeEnclaveClient(String baseUrl, String expectedPcr0,
      {int cacheTtlSecs = 60}) {
    final lib = nativeLib;

    final newFn = lib.lookupFunction<_NewNative, _NewDart>('enclave_client_new');
    _post = lib.lookupFunction<_PostNative, _PostDart>('enclave_client_post');
    _get = lib.lookupFunction<_GetNative, _GetDart>('enclave_client_get');
    _status =
        lib.lookupFunction<_StatusNative, _StatusDart>('enclave_client_attestation_status');
    _verify =
        lib.lookupFunction<_VerifyNative, _VerifyDart>('enclave_client_verify');
    _freeClient =
        lib.lookupFunction<_FreeClientNative, _FreeClientDart>('enclave_client_free');
    _freeString =
        lib.lookupFunction<_FreeStringNative, _FreeStringDart>('enclave_string_free');

    final urlPtr = baseUrl.toNativeUtf8();
    final pcrPtr = expectedPcr0.toNativeUtf8();
    try {
      _ptr = newFn(urlPtr, pcrPtr, cacheTtlSecs);
      if (_ptr == nullptr) {
        throw StateError('Failed to create enclave client');
      }
    } finally {
      calloc.free(urlPtr);
      calloc.free(pcrPtr);
    }
  }

  /// Make a verified POST request.
  EnclaveResponse post(String path, String body) {
    _checkDisposed();
    final pathPtr = path.toNativeUtf8();
    final bodyPtr = body.toNativeUtf8();
    Pointer<Utf8> resultPtr;
    try {
      resultPtr = _post(_ptr, pathPtr, bodyPtr);
    } finally {
      calloc.free(pathPtr);
      calloc.free(bodyPtr);
    }
    try {
      final json = jsonDecode(resultPtr.toDartString()) as Map<String, dynamic>;
      return EnclaveResponse.fromJson(json);
    } finally {
      _freeString(resultPtr);
    }
  }

  /// Make a verified GET request.
  EnclaveResponse get(String path) {
    _checkDisposed();
    final pathPtr = path.toNativeUtf8();
    Pointer<Utf8> resultPtr;
    try {
      resultPtr = _get(_ptr, pathPtr);
    } finally {
      calloc.free(pathPtr);
    }
    try {
      final json = jsonDecode(resultPtr.toDartString()) as Map<String, dynamic>;
      return EnclaveResponse.fromJson(json);
    } finally {
      _freeString(resultPtr);
    }
  }

  /// Get the current attestation status.
  AttestationStatus get attestationStatus {
    _checkDisposed();
    final resultPtr = _status(_ptr);
    try {
      final json = jsonDecode(resultPtr.toDartString()) as Map<String, dynamic>;
      return AttestationStatus.fromJson(json);
    } finally {
      _freeString(resultPtr);
    }
  }

  /// Force re-verification of attestation and update the cache.
  AttestationStatus verify() {
    _checkDisposed();
    final resultPtr = _verify(_ptr);
    try {
      final json = jsonDecode(resultPtr.toDartString()) as Map<String, dynamic>;
      return AttestationStatus.fromJson(json);
    } finally {
      _freeString(resultPtr);
    }
  }

  /// Dispose the client and free native resources.
  void dispose() {
    if (!_disposed) {
      _freeClient(_ptr);
      _disposed = true;
    }
  }

  void _checkDisposed() {
    if (_disposed) throw StateError('EnclaveClient has been disposed');
  }
}
