import 'package:app_core/bitcoin.dart';
import 'package:app_core/client.dart';
import 'package:test/test.dart';

/// The wallet keeps its own chain view, so the Electrum endpoint has to track
/// the network the cosigner reports. When it did not, `MpcBitcoinWallet`
/// defaulted to regtest loopback for every caller: against a remote deployment
/// `scanBoarding` then returned an empty list and boarding silently did
/// nothing — no error, just funds that never appeared.
void main() {
  group('defaultElectrumEndpoint', () {
    test('regtest stays on loopback', () {
      final e = defaultElectrumEndpoint('regtest');
      expect(e.host, '127.0.0.1');
      expect(e.port, 50001);
    });

    test('signet and mutinynet both resolve to the mutinynet server', () {
      // The server reports "mutinynet"; parseBitcoinNetwork folds both onto
      // BitcoinNetwork.signet, so both spellings must resolve here too.
      for (final n in ['signet', 'mutinynet']) {
        final e = defaultElectrumEndpoint(n);
        expect(e.host, 'electrum.mutinynet.com', reason: n);
        expect(e.port, 50001, reason: n);
      }
    });

    test('unconfigured networks throw rather than inheriting a default', () {
      // Scanning the wrong chain is worse than refusing to start.
      expect(() => defaultElectrumEndpoint('mainnet'), throwsArgumentError);
      expect(() => defaultElectrumEndpoint('testnet'), throwsArgumentError);
      expect(() => defaultElectrumEndpoint(''), throwsArgumentError);
    });
  });

  group('MpcBitcoinWallet electrum wiring', () {
    test('derives its endpoint from networkName', () {
      final w = MpcBitcoinWallet(_NullClient(),
          networkName: 'mutinynet', storageId: 'endpoint_test_derived');
      expect(w.electrum.host, 'electrum.mutinynet.com');
      expect(w.electrum.port, 50001);
    });

    test('explicit host and port still win', () {
      final w = MpcBitcoinWallet(_NullClient(),
          networkName: 'mutinynet',
          storageId: 'endpoint_test_override',
          electrumHost: '10.0.2.2',
          electrumPort: 60001);
      expect(w.electrum.host, '10.0.2.2');
      expect(w.electrum.port, 60001);
    });
  });
}

/// The constructor only stores the client, so a bare stand-in is enough to
/// assert the Electrum wiring without a server or a DKG.
class _NullClient implements MpcClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
