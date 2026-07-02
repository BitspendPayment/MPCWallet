/// Source of the upstream-minted Bearer session token attached to authenticated
/// requests. The cosigner verifies it against its single `WEBAUTH_TOKEN_PUBKEY`
/// and, when valid, authenticates the request WITHOUT the share-derived Schnorr
/// signature — which is what lets the FROST share stay PIN-gated to ARK signing.
///
/// [currentToken] returns null when no token is available; the transport then
/// falls back to the legacy Schnorr auth, so the migration never half-breaks.
///
///  - Production — a token obtained from the upstream auth authority after a
///    passkey assertion (device flow; not built here).
///  - [StaticSessionToken] — a token the e2e harness minted with the test key
///    whose public half the cosigner holds via `WEBAUTH_TOKEN_PUBKEY`.
///  - [NoSessionToken] — always null → Schnorr auth (today's behavior).
abstract class SessionTokenSource {
  /// The current Bearer token, or null to fall back to Schnorr auth.
  Future<String?> currentToken();
}

/// No token — every request uses Schnorr auth (the pre-migration default).
class NoSessionToken implements SessionTokenSource {
  const NoSessionToken();

  @override
  Future<String?> currentToken() async => null;
}

/// A fixed token, for e2e / tests. The harness mints an ES256 JWT
/// (`{sub: <group_key hex>, exp, iat, jti}`) with the test private key.
class StaticSessionToken implements SessionTokenSource {
  final String token;

  StaticSessionToken(this.token);

  @override
  Future<String?> currentToken() async => token;
}
