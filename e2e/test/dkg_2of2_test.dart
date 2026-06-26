import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/client.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

/// Verifies the real 2-of-2 {wallet, cosigner} DKG: the wallet (a dealer, no
/// hardware signer) and the cosigner derive a matching shared key, proven by a
/// FROST sign round-trip (a valid signature is impossible unless both shares lie
/// on the same 2-of-2 polynomial).
Future<Process> startRuntime(int port, Directory dataDir) async {
  final ready = Completer<void>();
  final failed = Completer<void>();
  final proc = await Process.start(
    '../cosigner-runtime/target/release/cosigner-runtime',
    [
      '--wasm',
      '../cosigner/target/wasm32-wasip2/release/cosigner.wasm',
      '--port',
      '$port',
    ],
    environment: {
      'ELECTRUM_URL': '127.0.0.1',
      'ELECTRUM_PORT': '50001',
      'BITCOIN_RPC_USER': 'admin1',
      'BITCOIN_RPC_PASSWORD': '123',
      'ASP_URL': 'http://127.0.0.1:7070',
      'BITCOIN_NETWORK': 'regtest',
      'AUTO_SETTLE_SAFETY_MARGIN_SECS': '3600',
      'HOME': dataDir.path,
    },
  );
  void watch(Stream<List<int>> s) {
    s.transform(utf8.decoder).listen((d) {
      print('[Server]: $d');
      if (!ready.isCompleted && d.contains('MPC Wallet Server listening on')) {
        ready.complete();
      }
    }, onDone: () {
      if (!ready.isCompleted && !failed.isCompleted) failed.complete();
    });
  }

  watch(proc.stdout);
  watch(proc.stderr);
  await Future.any([
    ready.future,
    failed.future.then((_) => throw Exception('server failed to start')),
  ]).timeout(Duration(seconds: 30),
      onTimeout: () => throw Exception('server not ready in time'));
  return proc;
}

void main() {
  late Directory tmp;
  late Directory serverTmp;
  Process? proc;
  late int port;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('dkg2of2_');
    Hive.init(tmp.path);
    final sock = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = sock.port;
    await sock.close();
    serverTmp = await Directory.systemTemp.createTemp('dkg2of2_srv_');
    proc = await startRuntime(port, serverTmp);
  });

  tearDownAll(() async {
    proc?.kill();
    try {
      await serverTmp.delete(recursive: true);
    } catch (_) {}
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('real 2-of-2 DKG + sign round-trip', () async {
    // No signer: the wallet is a dealer in a 2-of-2 with the cosigner.
    final client = MpcClient.rest('http://127.0.0.1:$port');
    await client.doDkg();

    expect(client.isInitialized, isTrue,
        reason: '2-of-2 DKG should initialize the wallet');
    final gpk = client.groupXOnlyPubKey;
    print('   group x-only pubkey: $gpk');
    expect(gpk, isNotNull);
    expect(gpk!.length, equals(64), reason: '32-byte x-only key (hex)');

    // Decisive: a FROST sign with the cosigner. signWithContext verifies the
    // aggregate against the group key and throws on mismatch, so a non-throwing
    // sign proves wallet + cosigner shares are consistent.
    final msg = Uint8List.fromList(List.generate(32, (i) => (i * 7) & 0xff));
    final sig = await client.sign(msg);
    expect(sig, isNotNull, reason: '2-of-2 FROST signature should verify');
    print('   2-of-2 DKG + sign round-trip OK');

    // NOTE: the former Part C (contract eVTXO key creation) moved to the new
    // single-shot ContractCreate model (refresh V onto an always-online {service,
    // cosigner} pairing) and is covered by evtxo_contract_e2e_test /
    // evtxo_arkd_e2e_test, which drive the dummy contract-service.
  }, timeout: Timeout(Duration(minutes: 2)));
}
