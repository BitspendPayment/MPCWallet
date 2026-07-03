/// Production Android passkey (WebAuthn) channel + PRF seed.
///
/// Orchestrates the cosigner's WebAuthn endpoints, the native Credential Manager
/// plugin ([PasskeyChannel]), and the PRF extension to produce BOTH:
///   * the 32-byte blinding seed for the FROST share ([SeedSource]) — the raw
///     PRF output, and
///   * the upstream Bearer session token ([SessionTokenSource]) — minted by the
///     cosigner's `/assert/finish`.
///
/// Wiring (done by the app, NOT here — this file only supplies the seed/token):
///   1. onboarding, AFTER DKG:      `await auth.register(userIdHex);`
///   2. then hand the seams to the client:
///        `client.setSeedSource(auth.seedSource);`
///        `client.setSessionTokenSource(auth.sessionTokenSource);`
/// Each signing operation then triggers a fresh passkey gesture (PRF eval),
/// which yields the seed and refreshes the cached token. The gating + seams
/// already exist; this just replaces the fixed/PIN seed with a real PRF seed.
///
/// ANDROID / ON-DEVICE NOTE: the exact WebAuthn options-JSON shape Credential
/// Manager expects, and the client-extension-results path for PRF, can vary by
/// Credential Manager / Play-services version. See [_optionsJsonFor] and
/// [_extractPrfResult] — both flag what may need on-device adjustment.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:app_core/passkey/seed_source.dart';
import 'package:app_core/passkey/session_token_source.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:http/http.dart' as http;

import 'passkey_channel.dart';

/// A single passkey assertion result: the minted session token + the 32-byte
/// PRF output (the blinding seed).
class _Assertion {
  final String token;
  final Uint8List prfSeed;
  const _Assertion(this.token, this.prfSeed);
}

class PasskeyAuthenticator {
  /// Cosigner base URL, e.g. `http://10.0.2.2:7074` (dev) or `https://host`
  /// (enclave) — the same base the wallet client talks to.
  final String baseUrl;
  final http.Client _http;

  /// The PRF salt: a fixed 32-byte context tag. The authenticator evaluates the
  /// credential's PRF at this salt; the result is the share-blinding seed. A
  /// constant so the SAME passkey always yields the SAME seed (deterministic
  /// reconstruction of the FROST share).
  static final Uint8List _prfSalt =
      Uint8List.fromList(sha256.convert(utf8.encode('mpcwallet-prf-v1')).bytes);

  /// Soft token lifetime, just under the cosigner's 30-day `TOKEN_TTL_SECS`
  /// (refresh a day early to avoid racing expiry). Long-lived on purpose: the
  /// token only authenticates the API boundary — spends still need a fresh
  /// passkey gesture — and every soft-expiry is a biometric prompt.
  static const Duration _tokenSoftTtl = Duration(days: 29);

  /// How long one gesture's PRF seed stays usable. An ARK operation is a burst
  /// of sequential FROST signs (intent proof, forfeits, delegate refresh…);
  /// without this, EACH sign would demand its own biometric prompt. Kept short
  /// so the seed (and thus the reconstructable share) doesn't idle in RAM.
  static const Duration _seedSoftTtl = Duration(minutes: 2);

  String? _cachedToken;
  DateTime? _tokenExpiry;

  Uint8List? _cachedSeed;
  DateTime? _seedExpiry;

  /// In-flight assertion, shared by all concurrent callers. Without this,
  /// parallel requests that each find the token missing/expired would each
  /// launch their OWN assertion — queueing a storm of biometric prompts.
  /// One gesture serves everyone: the assertion yields both the token and
  /// the PRF seed.
  Future<_Assertion>? _inflightAssertion;

  /// Called whenever a fresh token is minted, so the app can persist it —
  /// tokens outlive app restarts, and re-loading one via [initialToken] means
  /// a cold start needs no biometric prompt while the token is valid.
  final void Function(String token, DateTime expiry)? onTokenMinted;

  PasskeyAuthenticator(
    this.baseUrl, {
    http.Client? httpClient,
    String? initialToken,
    DateTime? initialTokenExpiry,
    this.onTokenMinted,
  }) : _http = httpClient ?? http.Client() {
    if (initialToken != null &&
        initialTokenExpiry != null &&
        DateTime.now().isBefore(initialTokenExpiry)) {
      _cachedToken = initialToken;
      _tokenExpiry = initialTokenExpiry;
    }
  }

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  // base64url WITHOUT padding, per the WebAuthn/CTAP JSON conventions used by
  // Credential Manager for byte fields.
  static String _b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _b64uDecode(String s) {
    final pad = (4 - s.length % 4) % 4;
    return base64Url.decode(s + '=' * pad);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await _http.post(
      _u(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('passkey $path failed: ${resp.statusCode} ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// webauthn-rs serializes `CreationChallengeResponse` / `RequestChallengeResponse`
  /// as `{"publicKey": { ... }}`. Credential Manager 1.3's `requestJson` expects
  /// the INNER WebAuthn options object (the `publicKey` value) as the JSON string.
  /// We therefore unwrap `publicKey` if present, else assume the object already
  /// IS the inner options.
  ///
  /// ON-DEVICE: if Credential Manager rejects the request, try passing the full
  /// `{"publicKey": {...}}` object instead of the inner one.
  Map<String, dynamic> _optionsJsonFor(Map<String, dynamic> options) {
    final inner = options['publicKey'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return Map<String, dynamic>.from(options);
  }

  /// Register a new passkey for [userIdHex]. Enables the PRF extension so the
  /// credential can later produce the blinding seed. Idempotent from the app's
  /// side: safe to call again to (re)provision.
  Future<void> register(String userIdHex) async {
    final begin = await _post('/api/passkey/register/begin', {'user_id': userIdHex});
    final ceremonyId = begin['ceremony_id'];
    final options = _optionsJsonFor(begin['options'] as Map<String, dynamic>);

    // Enable PRF at creation. No eval here — we only need the credential to
    // support PRF; the salt is evaluated at assertion time.
    final ext = Map<String, dynamic>.from(
        (options['extensions'] as Map?)?.cast<String, dynamic>() ?? const {});
    ext['prf'] = <String, dynamic>{};
    options['extensions'] = ext;

    final respJson = await PasskeyChannel.create(jsonEncode(options));
    final credential = jsonDecode(respJson);

    await _post('/api/passkey/register/finish', {
      'ceremony_id': ceremonyId,
      'credential': credential,
    });
  }

  /// Coalesce concurrent assertion requests onto a single passkey gesture.
  Future<_Assertion> _assertSingleFlight(String userIdHex) {
    final inflight = _inflightAssertion;
    if (inflight != null) return inflight;
    final assertion = _assert(userIdHex).whenComplete(() {
      _inflightAssertion = null;
    });
    _inflightAssertion = assertion;
    return assertion;
  }

  /// Run one passkey assertion: injects the PRF eval salt, drives the native
  /// gesture, extracts the 32-byte PRF result, and finishes the ceremony to get
  /// the session token. Also refreshes the cached token.
  Future<_Assertion> _assert(String userIdHex) async {
    final begin = await _post('/api/passkey/assert/begin', {'user_id': userIdHex});
    final ceremonyId = begin['ceremony_id'];
    final options = _optionsJsonFor(begin['options'] as Map<String, dynamic>);

    // Inject PRF eval at our fixed salt: extensions.prf.eval.first = b64url(salt).
    final ext = Map<String, dynamic>.from(
        (options['extensions'] as Map?)?.cast<String, dynamic>() ?? const {});
    ext['prf'] = <String, dynamic>{
      'eval': <String, dynamic>{'first': _b64u(_prfSalt)},
    };
    options['extensions'] = ext;

    final respJson = await PasskeyChannel.get(jsonEncode(options));
    final resp = jsonDecode(respJson) as Map<String, dynamic>;

    final prfSeed = _extractPrfResult(resp);

    final finish = await _post('/api/passkey/assert/finish', {
      'ceremony_id': ceremonyId,
      'credential': resp,
    });
    final token = finish['token'] as String;

    _cachedToken = token;
    _tokenExpiry = DateTime.now().add(_tokenSoftTtl);
    _cachedSeed = prfSeed;
    _seedExpiry = DateTime.now().add(_seedSoftTtl);
    onTokenMinted?.call(token, _tokenExpiry!);

    return _Assertion(token, prfSeed);
  }

  /// Pull the PRF output from authenticationResponseJson:
  /// `clientExtensionResults.prf.results.first` (base64url) → 32 bytes.
  ///
  /// ON-DEVICE: some versions nest results differently; if this throws, log the
  /// full `resp` and adjust the path.
  Uint8List _extractPrfResult(Map<String, dynamic> resp) {
    final cer = resp['clientExtensionResults'];
    final prf = (cer is Map) ? cer['prf'] : null;
    final results = (prf is Map) ? prf['results'] : null;
    final first = (results is Map) ? results['first'] : null;
    if (first is! String) {
      throw StateError(
          'passkey PRF result missing (clientExtensionResults.prf.results.first). '
          'Ensure the authenticator supports PRF and the credential was '
          'registered with the prf extension. Got: ${jsonEncode(resp['clientExtensionResults'])}');
    }
    final seed = _b64uDecode(first);
    if (seed.length != 32) {
      throw StateError('passkey PRF result must be 32 bytes, got ${seed.length}');
    }
    return Uint8List.fromList(seed);
  }

  bool get _tokenValid =>
      _cachedToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Whether a signing op STARTED NOW would ride the cached PRF seed (no
  /// biometric prompt). Requires the seed to stay valid a while longer, not
  /// just this instant — a multi-sighash signing round takes seconds, and a
  /// seed expiring mid-operation would pop the very prompt the caller checked
  /// this getter to avoid.
  bool get hasFreshSeed =>
      _cachedSeed != null &&
      _seedExpiry != null &&
      DateTime.now()
          .add(const Duration(seconds: 30))
          .isBefore(_seedExpiry!);

  /// Production [SeedSource]: a fresh passkey gesture per call, returning the
  /// PRF-derived 32-byte blinding seed (and refreshing the cached token).
  SeedSource seedSource(String userIdHex) => _PasskeyPrfSeedSource(this, userIdHex);

  /// Production [SessionTokenSource]: the cached token, minting a fresh one via
  /// an assertion when absent or (soft-)expired.
  SessionTokenSource sessionTokenSource(String userIdHex) =>
      _PasskeySessionTokenSource(this, userIdHex);

  Future<String> _ensureToken(String userIdHex) async {
    if (_tokenValid) return _cachedToken!;
    final a = await _assertSingleFlight(userIdHex);
    return a.token;
  }
}

/// [SeedSource] backed by the passkey PRF. Each `deriveSeed()` triggers a
/// passkey gesture and returns the raw 32-byte PRF output.
class _PasskeyPrfSeedSource implements SeedSource {
  final PasskeyAuthenticator _auth;
  final String _userIdHex;
  const _PasskeyPrfSeedSource(this._auth, this._userIdHex);

  @override
  Future<Uint8List> deriveSeed() async {
    final cached = _auth._cachedSeed;
    final expiry = _auth._seedExpiry;
    if (cached != null &&
        expiry != null &&
        DateTime.now().isBefore(expiry)) {
      return cached;
    }
    _auth._cachedSeed = null;
    final a = await _auth._assertSingleFlight(_userIdHex);
    return a.prfSeed;
  }
}

/// [SessionTokenSource] returning the authenticator's cached token (refreshing
/// via an assertion when absent/expired).
class _PasskeySessionTokenSource implements SessionTokenSource {
  final PasskeyAuthenticator _auth;
  final String _userIdHex;
  const _PasskeySessionTokenSource(this._auth, this._userIdHex);

  @override
  Future<String?> currentToken() async => _auth._ensureToken(_userIdHex);

  @override
  void onRejected() {
    _auth._cachedToken = null;
    _auth._tokenExpiry = null;
  }
}
