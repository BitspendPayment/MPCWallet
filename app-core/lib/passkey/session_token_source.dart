/// Source of the Bearer session token attached to authenticated requests.
/// The COSIGNER mints these itself after a successful passkey assertion
/// (Ed25519 keypair seeded from its `WEBAUTH_TOKEN_SECRET`) and verifies them
/// at its REST boundary. A valid token authenticates the request WITHOUT the
/// share-derived Schnorr signature — which is what lets the FROST share stay
/// passkey-gated to ARK signing.
///
/// [currentToken] returns null when no token is available; the transport then
/// falls back to the legacy Schnorr auth, so the migration never half-breaks.
///
///  - Production — the passkey authenticator's cached token, re-minted via an
///    assertion when absent or expired.
///  - [StaticSessionToken] — a token the e2e harness minted with the same
///    `WEBAUTH_TOKEN_SECRET` the cosigner holds.
///  - [NoSessionToken] — always null → Schnorr auth (un-gated behavior).
abstract class SessionTokenSource {
  const SessionTokenSource();

  /// The current Bearer token, or null to fall back to Schnorr auth.
  Future<String?> currentToken();

  /// The server rejected the last token (expired early, or the cosigner's
  /// token secret rotated). Drop any cache so the next [currentToken] mints
  /// fresh instead of resending the dead token forever — essential now that
  /// tokens are long-lived. Default: nothing to drop.
  void onRejected() {}
}

/// No token — every request uses Schnorr auth (the pre-migration default).
class NoSessionToken extends SessionTokenSource {
  const NoSessionToken();

  @override
  Future<String?> currentToken() async => null;
}

/// A fixed token, for e2e / tests. The harness mints an EdDSA JWT
/// (`{sub: <group_key hex>, exp, iat, jti}`) with the cosigner's test secret.
class StaticSessionToken extends SessionTokenSource {
  final String token;

  StaticSessionToken(this.token);

  @override
  Future<String?> currentToken() async => token;
}
