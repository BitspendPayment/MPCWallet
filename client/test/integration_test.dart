import 'dart:convert';
import 'dart:typed_data';

import 'package:client/client.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';
import 'package:threshold/threshold.dart' as threshold;
import 'package:protocol/protocol.dart';

void main() {
  test('End-to-End DKG and Signing with Dual-Identity Client + Server',
      () async {
    // Client simulates Participant 1 AND Participant 2 inside one instance.
    // Server is Participant 3.
    final channel = ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    final id1 = threshold.Identifier(BigInt.from(1));
    final id2 = threshold.Identifier(BigInt.from(2));

    // Initialize client with BOTH identities
    final client = MpcClient(channel, id1, id2);

    print('--- DKG START ---');

    // Perform DKG for both identities
    await client.doDkg();

    print('--- DKG COMPLETE ---');

    // Verify both identities generated keys
    expect(client.keyPackage1, isNotNull);
    expect(client.keyPackage2, isNotNull);
    expect(client.publicKey, isNotNull);

    print('Group Public Key: ${client.publicKey!.verifyingKey.E}');

    print('--- SIGNING START ---');
    final message = utf8.encode("Hello 2-of-3 World from Dual-Identity Client");

    // Sign using the "active" identity (defaults to ID 2)
    final signature = await client.sign(Uint8List.fromList(message));

    expect(signature, isA<threshold.Signature>());
    print('--- SIGNING COMPLETE ---');

    await channel.shutdown();
  });
}
