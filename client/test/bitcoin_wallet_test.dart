import 'package:client/client.dart';
import 'package:client/bitcoin.dart';
import 'package:test/test.dart';
import 'package:grpc/grpc.dart';
import 'package:threshold/threshold.dart' as threshold;

// Mock or integration test?
// Since we don't have a running server here easily without e2e,
// we will just verify that the class exists and constructor logic works (throws if no key).

void main() {
  test('MpcBitcoinWallet requires DKG to be done', () {
    final channel = ClientChannel('localhost',
        port: 1234,
        options:
            const ChannelOptions(credentials: ChannelCredentials.insecure()));
    final client = MpcClient(channel, threshold.Identifier(BigInt.one),
        threshold.Identifier(BigInt.two));
    // No DKG done

    expect(() => MpcBitcoinWallet(client), throwsStateError);

    channel.shutdown();
  });
}
