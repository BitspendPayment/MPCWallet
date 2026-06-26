import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/client.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

/// Plan A 1B gate: after the plaintext FROST key is removed from `policies`, the cosigner's
/// signing share lives ONLY in the guest's sealed snapshot. This proves restore-from-seal works:
/// DKG → KILL + respawn the runtime on the same data dir → sign again. The cold-spawned actor must
/// reconstruct its share purely from the seal (the persisted key is blank, so a broken restore
/// can't be masked by a plaintext fallback — the sign would simply fail).
Future<Process> startRuntime(int port, Directory dataDir) async {
  final ready = Completer<void>();
  final failed = Completer<void>();
  final env = {'BITCOIN_NETWORK': 'regtest', 'HOME': dataDir.path};
  final proc = await Process.start(
    '../cosigner-runtime/target/release/cosigner-runtime',
    ['--port', port.toString()],
    environment: env,
  );
  void watch(Stream<List<int>> s) {
    s.transform(utf8.decoder).listen((data) {
      print('[Server]: $data');
      if (!ready.isCompleted && data.contains('MPC Wallet Server listening on')) ready.complete();
    }, onDone: () {
      if (!ready.isCompleted && !failed.isCompleted) failed.complete();
    });
  }

  watch(proc.stdout);
  watch(proc.stderr);
  await Future.any([
    ready.future,
    failed.future.then((_) => throw Exception('runtime failed to start')),
  ]).timeout(Duration(seconds: 30), onTimeout: () => throw Exception('runtime not ready'));
  return proc;
}

void main() {
  late Directory tempDir;
  late Directory serverTempDir;
  Process? proc;
  late int port;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mpc_restore_');
    Hive.init(tempDir.path);
    serverTempDir = await Directory.systemTemp.createTemp('mpc_restore_server_');
    final sock = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = sock.port;
    await sock.close();
    proc = await startRuntime(port, serverTempDir);
  });

  tearDownAll(() async {
    proc?.kill();
    try {
      await serverTempDir.delete(recursive: true);
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('cosigner signs from the sealed snapshot after a runtime restart (no plaintext key)',
      () async {
    final alice = MpcClient.rest('http://127.0.0.1:$port', storageId: 'alice');
    await alice.doDkg();
    print('1. DKG complete: ${alice.userId?.substring(0, 12)}');

    // Baseline: sign once while the actor is warm (verifies the happy path + that the guest sealed).
    final msg1 = Uint8List.fromList(List.generate(32, (i) => i + 1));
    await alice.sign(msg1, applyTweak: false); // throws on an invalid aggregate
    print('2. Warm sign OK');

    // RESTART the runtime on the SAME data dir — every actor is now cold; the sled DB still holds
    // the sealed snapshot + the PUBLIC policy projection (the FROST key field is blank).
    proc?.kill();
    await Future.delayed(Duration(seconds: 2));
    proc = await startRuntime(port, serverTempDir);
    print('3. Runtime restarted (cold actors)');

    // Cold sign: the cosigner actor must restore its V share purely from the seal. With the
    // persisted key blank, this only succeeds if restore_guest_snapshot actually works.
    final msg2 = Uint8List.fromList(List.generate(32, (i) => 0xA0 + i));
    await alice.sign(msg2, applyTweak: false);
    print('4. COLD sign OK — cosigner restored its share from the seal alone.');

    print('Restore-from-seal E2E complete: signing works after restart with no plaintext key.');
  }, timeout: Timeout(Duration(minutes: 3)));
}
