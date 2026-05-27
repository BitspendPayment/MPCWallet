/// Dart FFI bindings for the pure-verification `enclave-client` Rust crate.
///
/// Three stateless functions — Dart owns HTTP, retries, timeouts, and the
/// attestation cache; Rust only does the crypto-heavy work (COSE_Sign1
/// over CBOR, X.509 chain validation against the AWS Nitro root CA,
/// NIST P-384 ECDSA, BIP-340 Schnorr over secp256k1).
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'native_library.dart';

// ── FFI typedefs ─────────────────────────────────────────────────────

typedef _VerifyDocNative = Pointer<Utf8> Function(
    Pointer<Uint8>, Size, Pointer<Utf8>, Pointer<Uint8>, Size);
typedef _VerifyDocDart = Pointer<Utf8> Function(
    Pointer<Uint8>, int, Pointer<Utf8>, Pointer<Uint8>, int);

typedef _VerifySigNative = Pointer<Utf8> Function(
    Pointer<Uint8>, Size, Pointer<Utf8>, Pointer<Utf8>);
typedef _VerifySigDart = Pointer<Utf8> Function(
    Pointer<Uint8>, int, Pointer<Utf8>, Pointer<Utf8>);

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

// ── Lazily-looked-up function handles ────────────────────────────────

_VerifyDocDart? _verifyDocFn;
_VerifySigDart? _verifySigFn;
_FreeStringDart? _freeStringFn;

void _ensureLoaded() {
  if (_freeStringFn != null) return;
  final lib = nativeLib;
  _verifyDocFn = lib.lookupFunction<_VerifyDocNative, _VerifyDocDart>(
      'enclave_verify_attestation_doc');
  _verifySigFn = lib.lookupFunction<_VerifySigNative, _VerifySigDart>(
      'enclave_verify_schnorr_signature');
  _freeStringFn = lib.lookupFunction<_FreeStringNative, _FreeStringDart>(
      'enclave_string_free');
}

// ── Public result types ──────────────────────────────────────────────

/// Snapshot of the current attestation cache for UI display.
///
/// Populated by [AttestedWalletApi] from its Dart-side cache after a
/// successful verify. No FFI involved — this is plain data.
class AttestationStatus {
  final bool verified;
  final String pcr0;
  final int verifiedAtEpochSecs;
  final int ttlRemainingSecs;
  final String attestationKey;
  final String? error;

  const AttestationStatus({
    required this.verified,
    required this.pcr0,
    required this.verifiedAtEpochSecs,
    required this.ttlRemainingSecs,
    required this.attestationKey,
    this.error,
  });

  /// Status when no attestation has been performed (or the cache is empty).
  factory AttestationStatus.unverified({String? error}) => AttestationStatus(
        verified: false,
        pcr0: '',
        verifiedAtEpochSecs: 0,
        ttlRemainingSecs: 0,
        attestationKey: '',
        error: error,
      );

  Duration get ttlRemaining => Duration(seconds: ttlRemainingSecs);

  DateTime? get verifiedAt => verifiedAtEpochSecs > 0
      ? DateTime.fromMillisecondsSinceEpoch(verifiedAtEpochSecs * 1000)
      : null;
}

/// Result of verifying a CBOR-encoded COSE_Sign1 attestation document.
class AttestationVerifyResult {
  final bool ok;
  final String pcr0;
  final Map<String, String> pcrs;

  /// SHA-256 hex of the enclave's attestation pubkey, parsed out of the
  /// document's UserData. Empty when the document predates the nitriding
  /// key-binding format.
  final String appKeyHash;
  final String? error;

  const AttestationVerifyResult({
    required this.ok,
    required this.pcr0,
    required this.pcrs,
    required this.appKeyHash,
    this.error,
  });

  factory AttestationVerifyResult.fromJson(Map<String, dynamic> json) {
    return AttestationVerifyResult(
      ok: json['ok'] as bool? ?? false,
      pcr0: json['pcr0'] as String? ?? '',
      pcrs: (json['pcrs'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String)),
      appKeyHash: json['app_key_hash'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

// ── Verifier entry points (stateless, synchronous, CPU-bound) ────────

class EnclaveVerifier {
  EnclaveVerifier._();

  /// Verify a COSE_Sign1 AWS Nitro attestation document.
  ///
  /// [docBytes] — raw bytes of the attestation document (already
  ///   base64-decoded by the caller, JSON envelope unwrapped).
  /// [expectedPcr0] — hex-encoded PCR0 to enforce.
  /// [nonce] — 20-byte nonce the caller used when fetching the document.
  ///
  /// Returns the verified attestation summary. Callers compare
  /// `SHA256(attestation_pubkey_bytes)` to `appKeyHash` to bind the
  /// fetched attestation pubkey to the document.
  static AttestationVerifyResult verifyAttestationDoc({
    required Uint8List docBytes,
    required String expectedPcr0,
    required Uint8List nonce,
  }) {
    _ensureLoaded();

    final docPtr = calloc<Uint8>(docBytes.length == 0 ? 1 : docBytes.length);
    final noncePtr = calloc<Uint8>(nonce.length == 0 ? 1 : nonce.length);
    final pcr0Ptr = expectedPcr0.toNativeUtf8();
    try {
      docPtr.asTypedList(docBytes.length).setAll(0, docBytes);
      noncePtr.asTypedList(nonce.length).setAll(0, nonce);

      final resultPtr = _verifyDocFn!(
          docPtr, docBytes.length, pcr0Ptr, noncePtr, nonce.length);
      try {
        final json = jsonDecode(resultPtr.toDartString())
            as Map<String, dynamic>;
        return AttestationVerifyResult.fromJson(json);
      } finally {
        _freeStringFn!(resultPtr);
      }
    } finally {
      calloc.free(docPtr);
      calloc.free(noncePtr);
      calloc.free(pcr0Ptr);
    }
  }

  /// Verify a BIP-340 Schnorr signature over `SHA256(body)` using a
  /// hex-encoded secp256k1 attestation pubkey (compressed or x-only).
  ///
  /// Returns `(ok, error?)`. Sub-millisecond — safe to call inline on
  /// the main isolate per response.
  static ({bool ok, String? error}) verifySchnorrSignature({
    required List<int> body,
    required String sigHex,
    required String pubkeyHex,
  }) {
    _ensureLoaded();

    final bodyPtr = calloc<Uint8>(body.isEmpty ? 1 : body.length);
    final sigPtr = sigHex.toNativeUtf8();
    final pkPtr = pubkeyHex.toNativeUtf8();
    try {
      bodyPtr.asTypedList(body.length).setAll(0, body);

      final resultPtr = _verifySigFn!(bodyPtr, body.length, sigPtr, pkPtr);
      try {
        final json = jsonDecode(resultPtr.toDartString())
            as Map<String, dynamic>;
        return (
          ok: json['ok'] as bool? ?? false,
          error: json['error'] as String?,
        );
      } finally {
        _freeStringFn!(resultPtr);
      }
    } finally {
      calloc.free(bodyPtr);
      calloc.free(sigPtr);
      calloc.free(pkPtr);
    }
  }
}
