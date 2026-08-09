import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/server_host.dart';

void main() {
  group('requiresAttestation', () {
    test('mainnet demands attestation', () {
      expect(requiresAttestation('mainnet.vtxos.network'), isTrue);
    });

    test('mutinynet is waived — no enclave fronts it yet', () {
      expect(requiresAttestation('mutiny.vtxos.network'), isFalse);
    });

    test('local dev addresses are waived', () {
      for (final h in ['127.0.0.1', 'localhost', '10.0.2.2', '192.168.1.42']) {
        expect(requiresAttestation(h), isFalse, reason: h);
      }
    });

    /// The whole point of spelling the rule as a waiver list. If this ever
    /// inverts to "attest only when host == mainnet", every case below silently
    /// downgrades to unattested plain REST against an arbitrary server.
    test('unknown hosts fail closed', () {
      for (final h in [
        'evil.example.com',
        'mainnet.vtxos.network.evil.com', // suffix-smuggling
        'evilmainnet.vtxos.network', // prefix-smuggling
        'MAINNET.VTXOS.NETWORK', // case variant is not the known-good host
        'mutiny.vtxos.network.evil.com',
        '',
        '10.0.2.3', // adjacent to the emulator alias, not it
        '192.168', // prefix of the local rule but not a host in it
      ]) {
        expect(requiresAttestation(h), isTrue, reason: h);
      }
    });
  });

  group('baseUrlFor', () {
    test('local hosts get plain HTTP on the REST port', () {
      expect(baseUrlFor('10.0.2.2'), 'http://10.0.2.2:7074');
      expect(baseUrlFor('127.0.0.1'), 'http://127.0.0.1:7074');
      expect(baseUrlFor('192.168.1.5'), 'http://192.168.1.5:7074');
    });

    test('remote hosts get HTTPS whether or not they are attested', () {
      expect(baseUrlFor('mainnet.vtxos.network'), 'https://mainnet.vtxos.network');
      // Waived from attestation, but still TLS — the two rules are independent.
      expect(baseUrlFor('mutiny.vtxos.network'), 'https://mutiny.vtxos.network');
    });
  });

  group('isLocalHost', () {
    test('does not treat remote deployments as local', () {
      expect(isLocalHost('mutiny.vtxos.network'), isFalse);
      expect(isLocalHost('mainnet.vtxos.network'), isFalse);
    });
  });
}
