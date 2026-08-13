/// Classification of the co-signing server host: how to reach it, and whether
/// it must prove it is running inside a Nitro enclave before we talk to it.
///
/// Shared by [MpcService] (foreground) and the FCM background isolate in
/// `push_service.dart`, which previously carried its own copy of the URL rule.
library;

/// Dev/loopback addresses. The runtime is a bare process on a workstation
/// here — plain HTTP on the REST port, and no enclave to attest.
///
/// `10.0.2.2` is the Android emulator's alias for the host machine;
/// `127.0.0.1` is how a physical phone reaches it over `adb reverse`.
bool isLocalHost(String host) =>
    host == '127.0.0.1' ||
    host == 'localhost' ||
    host == '10.0.2.2' ||
    host.startsWith('192.168.');

/// Remote deployments that are deliberately NOT enclave-backed, and so cannot
/// produce an attestation document.
///
/// This is a WAIVER list, not an opt-in list — [requiresAttestation] demands
/// attestation for every host that is not named here or covered by
/// [isLocalHost], so an unrecognised host fails CLOSED.
///
/// The inverse spelling ("attest only when host == the production hostname")
/// would fail OPEN: `serverHost` is persisted in Hive and rewritten by
/// `MpcService.setHost`, so any other value — a typo, a stale box, a tampered
/// one — would silently downgrade to unattested plain REST against a server of
/// someone else's choosing. Adding a host here is a deliberate, reviewable act.
const Set<String> _unattestedRemoteHosts = {
  // mutinynet (signet). The cosigner runs directly on the EC2 host with its
  // SQLite KV on an EBS volume; there is no enclave in front of it yet, so
  // there is no PCR0 to verify and no `/enclave/attestation` endpoint to call.
  // Signet coins only. When the enclave fronts this deployment, delete this
  // entry — that is the whole change needed to switch attestation back on.
  'mutiny.vtxos.network',
};

/// Whether [host] must present a verified Nitro attestation (matching PCR0,
/// with the response-signing key bound to the attested image) before the app
/// will exchange any wallet traffic with it.
///
/// True for every remote host except the explicitly waived ones above — in
/// particular TRUE for `mainnet.vtxos.network`, and true for any host nobody
/// has classified yet.
bool requiresAttestation(String host) =>
    !isLocalHost(host) && !_unattestedRemoteHosts.contains(host);

/// `http://host:7074` for local dev, `https://host` for anything remote.
///
/// Independent of [requiresAttestation]: a waived remote host is still reached
/// over TLS, it just isn't additionally bound to an enclave measurement.
String baseUrlFor(String host) {
  // 7074 is the server binary's default REST port; the Makefile mirrors it.
  const port = 7074;
  return isLocalHost(host) ? 'http://$host:$port' : 'https://$host';
}
