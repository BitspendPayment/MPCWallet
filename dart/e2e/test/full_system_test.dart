import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:client/client.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';
import 'package:threshold/threshold.dart' as threshold;

void main() {
  Process? serverProcess;

  setUpAll(() async {
    print('Starting Server Process...');
    // Assuming we are running from dart/e2e or root, we need to find the server binary path.
    // The relative path from `dart/e2e` to `dart/server/lib/server.dart` is `../server/lib/server.dart`.

    serverProcess = await Process.start(
      'dart',
      ['run', '../server/lib/server.dart'],
      mode: ProcessStartMode.detachedWithStdio,
    );

    // Pipe stdout to see server logs
    serverProcess!.stdout.transform(utf8.decoder).listen((data) {
      if (data.trim().isNotEmpty) print('[Server]: $data');
    });
    serverProcess!.stderr.transform(utf8.decoder).listen((data) {
      if (data.trim().isNotEmpty) print('[Server STDERR]: $data');
    });

    // Wait slightly for server to confirm binding (simple delay for now, or check logs)
    // In a robust system, we would poll the port or wait for a specific log line.
    await Future.delayed(Duration(seconds: 3));
  });

  tearDownAll(() {
    print('Stopping Server Process...');
    serverProcess?.kill(ProcessSignal.sigterm);
  });

  test('Concurrent Multi-Session DKG and Signing', () async {
    final channel = ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    final id1 = threshold.Identifier(BigInt.from(1));
    final id2 = threshold.Identifier(BigInt.from(2));

    // Client A (Device A)
    final clientA = MpcClient(channel, id1, id2, deviceId: "device_A_session");

    // Client B (Device B) - Same identifiers (simulating same user on diff device? or diff user. ID doesn't matter as scoped by session)
    // To be perfectly 2-of-3, we reuse IDs 1 and 2 for simplicity as they are internal to the client logic relative to server 3.
    final clientB = MpcClient(channel, id1, id2, deviceId: "device_B_session");

    print('--- STARTING CONCURRENT DKGs ---');

    // Run both concurrently
    await Future.wait([
      clientA.doDkg(),
      clientB.doDkg(),
    ]);

    print('--- CONCURRENT DOMPLETED ---');

    expect(clientA.publicKey, isNotNull);
    expect(clientB.publicKey, isNotNull);

    // They should ideally produce different keys as secrets are random
    expect(clientA.publicKey!.verifyingKey.E,
        isNot(equals(clientB.publicKey!.verifyingKey.E)));

    print('--- STARTING CONCURRENT SIGNING ---');
    final msgA = utf8.encode("Message A");
    final msgB = utf8.encode("Message B");

    final results = await Future.wait([
      clientA.sign(Uint8List.fromList(msgA)),
      clientB.sign(Uint8List.fromList(msgB)),
    ]);

    expect(results[0], isTrue);
    expect(results[1], isTrue);

    print('--- CONCURRENT SIGNING COMPLETE ---');

    await channel.shutdown();
  });
}
