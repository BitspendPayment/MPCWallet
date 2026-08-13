import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

import 'package:app_core/threshold/threshold.dart' as threshold;

/// Client-side PIN / passkey-PRF blinding of a FROST secret share.
///
/// The wallet's share `P_full` is never persisted in the clear; instead we store
/// `δ = P_full − b`, where `b = f(id)` and `f` is a ZERO-secret refresh polynomial
/// whose coefficients are derived from `seed` (`dkgRefreshPart1(id, 2, 2, seed:)`).
/// Reconstruct with `P_full = δ + b` — only the correct `seed` yields the real share,
/// and the cosigner's own share is untouched (purely client-side gating).
///
/// The seed is OPAQUE bytes so the source is pluggable:
///  - PIN — [seedFromPin] = `sha256(pin)`. Low-entropy: a UX lock only, offline
///    brute-forceable (the device holds `δ` + the public verifying share).
///  - passkey PRF — the 32-byte `prfResults.first`. High-entropy: real security.

/// Derive the blinding seed from a user PIN.
///
/// WARNING: a PIN is low-entropy — this is a UX lock, not cryptographic protection.
/// Swap the seed for the passkey PRF output (32 bytes) for real security.
Uint8List seedFromPin(String pin) =>
    Uint8List.fromList(sha256.convert(utf8.encode(pin)).bytes);

/// The blinding scalar `b = evaluatePolynomial(id, coeffs(seed))`. Deterministic in `seed`
/// (the refresh coefficients are seeded), so blind/reconstruct with the same seed cancel.
BigInt _blindingScalar(threshold.Identifier id, Uint8List seed) {
  final (secretPkg, _) = threshold.dkgRefreshPart1(id, 2, 2, seed: seed.toList());
  return threshold.evaluatePolynomial(id, secretPkg.coefficients);
}

/// Blind [share] under [seed]: returns `δ = share.scalar − b` (32 bytes), safe to persist.
Uint8List blindShare(
    threshold.SecretKey share, threshold.Identifier id, Uint8List seed) {
  final b = _blindingScalar(id, seed);
  return threshold.bigIntToBytes(threshold.modNSub(share.scalar, b));
}

/// Reconstruct `P_full = δ + b` from [delta] + [seed]. A wrong seed yields a wrong
/// scalar (a FROST sign with it fails aggregation) — never the real share.
threshold.SecretKey reconstructShare(
    Uint8List delta, threshold.Identifier id, Uint8List seed) {
  final b = _blindingScalar(id, seed);
  final deltaScalar = threshold.bytesToBigInt(delta);
  return threshold.SecretKey(threshold.modNAdd(deltaScalar, b));
}
