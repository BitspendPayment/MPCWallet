import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:test/test.dart';
import 'package:app_core/client.dart';
import 'package:app_core/bitcoin.dart';
import 'package:app_core/hardware_signer.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:e2e/logger.dart';
import 'package:hive/hive.dart';

void main() {
  Process? serverProcess;
  late RegtestHelper btc;
  late Directory tempDir;
  late Directory serverTempDir;
  late int serverPort;

  Future<void> waitForUtxoByTxId(MpcBitcoinWallet wallet, String expectedTxId,
      {int retries = 30}) async {
    while (retries > 0) {
      await wallet.sync();
      final utxos = await wallet.store.getUtxos();
      final hasExpected = utxos.any((u) => u.utxo.txHash == expectedTxId);
      if (hasExpected) return;
      Log.info("Waiting for change UTXO from ${expectedTxId.substring(0, 12)}… ($retries left)");
      retries--;
      if (retries > 0) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
    fail("Timed out waiting for change UTXO from $expectedTxId");
  }

  setUpAll(() async {
    Log.header('Setup');

    // 0. Hive Init
    tempDir = await Directory.systemTemp.createTemp('mpc_e2e_');
    Hive.init(tempDir.path);

    // 1. Docker
    Log.info('Starting Docker (Bitcoind)…');
    var dRes = await Process.run('docker', [
      'compose',
      'up',
      '-d',
      'bitcoind',
    ]);
    if (dRes.exitCode != 0)
      throw Exception("Docker Bitcoind failed: ${dRes.stderr}");

    Log.info("Waiting for Bitcoind (10s)…");
    await Future.delayed(Duration(seconds: 10));

    Log.info('Starting Docker (Electrs)…');
    dRes = await Process.run('docker', [
      'compose',
      'up',
      '-d',
      'electrs',
    ]);
    if (dRes.exitCode != 0)
      throw Exception("Docker Electrs failed: ${dRes.stderr}");

    Log.info("Waiting for Electrs (20s)…");
    await Future.delayed(Duration(seconds: 20));

    // Probe
    btc = RegtestHelper();
    try {
      try {
        await btc.createWallet("default");
      } catch (e) {
        if (!e.toString().contains("already loaded")) rethrow;
      }
      btc = RegtestHelper(rpcUrl: "http://127.0.0.1:18443/wallet/default");
      await btc.getNewAddress();
      Log.ok("Docker Regtest operational.");
    } catch (e) {
      throw Exception("Docker started but RPC unreachable: $e");
    }

    // 2. Server (Rust)
    Log.info('Starting MPC Server…');
    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_server_');
    final serverReady = Completer<void>();
    final serverFailed = Completer<void>();
    serverProcess = await Process.start(
      '../cosigner-runtime/target/release/cosigner-runtime',
      [
        '--wasm', '../cosigner/target/wasm32-wasip2/release/cosigner.wasm',
        '--port', serverPort.toString(),
      ],
      mode: ProcessStartMode.normal,
      environment: {
        'ELECTRUM_URL': '127.0.0.1',
        'ELECTRUM_PORT': '50001',
        'BITCOIN_RPC_USER': 'admin1',
        'BITCOIN_RPC_PASSWORD': '123',
        'HOME': serverTempDir.path,
      },
    );
    final stdoutBuffer = StringBuffer();
    serverProcess!.stdout.transform(utf8.decoder).listen((data) {
      stdoutBuffer.write(data);
      Log.server(data);
      if (!serverReady.isCompleted &&
          stdoutBuffer.toString().contains('MPC Wallet Server listening on')) {
        serverReady.complete();
      }
    }, onDone: () {
      if (!serverReady.isCompleted && !serverFailed.isCompleted) {
        serverFailed.complete();
      }
    });
    // Server uses tracing which outputs to stderr
    final stderrBuffer = StringBuffer();
    serverProcess!.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
      Log.server(data);
      if (!serverReady.isCompleted &&
          stderrBuffer.toString().contains('MPC Wallet Server listening on')) {
        serverReady.complete();
      }
    }, onDone: () {
      if (!serverReady.isCompleted && !serverFailed.isCompleted) {
        serverFailed.complete();
      }
    });

    try {
      await Future.any([
        serverReady.future,
        serverFailed.future.then((_) {
          throw Exception("MPC Server failed to start");
        }),
      ]).timeout(Duration(seconds: 15), onTimeout: () {
        throw Exception("MPC Server did not become ready in time");
      });
    } catch (e) {
      serverProcess?.kill();
      try {
        await serverTempDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
    Log.ok('Setup complete.');
    Log.separator();
  });

  tearDownAll(() async {
    serverProcess?.kill();
    try {
      await serverTempDir.delete(recursive: true);
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  MpcClient createClient(HardwareSignerInterface signer, {String? storageId}) {
    return MpcClient.rest(
      'http://127.0.0.1:$serverPort',
      hardwareSigner: signer,
      storageId: storageId,
    );
  }

  test('Full E2E Regtest Flow', () async {
    // 1. MPC Setup
    Log.step(1, 'MPC Setup');
    final signer = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await signer.connect();
    final client1 = createClient(signer);

    await client1.doDkg();
    Log.ok('DKG complete.');

    // 2. Init Wallet
    final wallet = MpcBitcoinWallet(client1, networkName: 'regtest');
    await wallet.init();

    final address = wallet.toAddress();
    Log.info('Wallet address: $address');

    // 3. Fund Wallet
    Log.step(2, 'Funding Wallet');
    final minerAddr = await btc.getNewAddress();
    await btc.generateToAddress(101, minerAddr);

    final txId = await btc.sendToAddress(address, 1.0);
    Log.ok('Funded wallet · txid: $txId');
    await btc.generateToAddress(1, minerAddr);

    // 4. Sync Wallet
    Log.step(3, 'Syncing Wallet');
    try {
      int retries = 30;
      while (retries > 0) {
        try {
          await wallet.sync();
          final utxos = await wallet.store.getUtxos();
          if (utxos.isNotEmpty) break;
          Log.warn("Synced 0 UTXOs from server — retrying… ($retries left)");
        } catch (e) {
          Log.warn("Sync error: $e — retrying…");
        }
        retries--;
        if (retries > 0) await Future.delayed(Duration(seconds: 2));
      }
      final utxos = await wallet.store.getUtxos();

      if (utxos.isEmpty) {
        // Debug: Check Bitcoind direct view
        try {
          final scan = await btc.scanUtxos(address);
          Log.debug("Bitcoind scanUtxos for $address: $scan");
        } catch (e) {
          Log.debug("scanUtxos failed: $e");
        }

        // Dump logs
        final logs = await Process.run('docker', ['logs', 'mpc_electrs']);
        Log.warn("Electrs logs:\n${logs.stdout}\n${logs.stderr}");
      }

      expect(utxos.length, greaterThanOrEqualTo(1));
      final balance = utxos.fold(BigInt.zero, (s, u) => s + u.utxo.value);
      Log.ok('Synced ${utxos.length} UTXO(s) · balance: $balance sats');
    } catch (e) {
      fail("Failed to sync wallet: $e");
    }

    // 5. Initial Spend (Normal)
    Log.step(4, 'Normal Spend (10,000 sats)');
    final dest1 = await btc.getNewAddress();
    final unsignedTx1 = await wallet.createTransaction(
        destination: dest1, amount: BigInt.from(10000), feeRate: 1);
    final hexTx1 = await wallet.signTransaction(unsignedTx1);
    final tx1Id = await wallet.broadcast(hexTx1);
    Log.ok('Broadcast · txid: $tx1Id');
    await btc.generateToAddress(1, minerAddr);
    await waitForUtxoByTxId(wallet, tx1Id);
    await wallet.sync();

    final balance = await wallet.store
        .getUtxos()
        .then((l) => l.fold(BigInt.zero, (s, u) => s + u.utxo.value).toInt());
    Log.info('Balance after spend: $balance sats');

    final res = await btc.getRawTransaction(tx1Id);
    expect(res['confirmations'], 1);

    // 6. Restore wallet (simulate new phone)
    Log.step(5, 'Restoring Wallet via re-DKG');
    final originalAddress = address;
    final client2 = createClient(signer, storageId: 'restore_e2e');
    await client2.doRestore();
    Log.ok('Restore complete.');

    final wallet2 = MpcBitcoinWallet(client2, networkName: 'regtest');
    await wallet2.init();
    final restoredAddress = wallet2.toAddress();
    Log.info('Restored address: $restoredAddress');
    expect(restoredAddress, equals(originalAddress),
        reason: "Restored wallet must have the same Bitcoin address");

    // 7. Sync restored wallet
    await Future.delayed(Duration(seconds: 2));
    Log.step(6, 'Syncing Restored Wallet');
    int syncRetries = 30;
    while (syncRetries > 0) {
      try {
        await wallet2.sync();
      } catch (e) {
        Log.warn('Sync error (retrying): $e');
        syncRetries--;
        if (syncRetries > 0) await Future.delayed(Duration(seconds: 2));
        continue;
      }
      final utxos = await wallet2.store.getUtxos();
      if (utxos.isNotEmpty) break;
      Log.info('Waiting for UTXO… ($syncRetries left)');
      syncRetries--;
      if (syncRetries > 0) await Future.delayed(Duration(seconds: 2));
    }
    final restoredUtxos = await wallet2.store.getUtxos();
    expect(restoredUtxos.length, greaterThanOrEqualTo(1),
        reason: "Restored wallet should see existing UTXOs");
    final restoredBalance =
        restoredUtxos.fold(BigInt.zero, (s, u) => s + u.utxo.value);
    Log.ok('Restored balance: $restoredBalance sats');

    // 8. Sign with restored wallet
    Log.step(7, 'Signing Transaction with Restored Wallet');
    final dest4 = await btc.getNewAddress();
    final unsignedTx3 = await wallet2.createTransaction(
        destination: dest4, amount: BigInt.from(10000), feeRate: 1);
    final hexTx3 = await wallet2.signTransaction(unsignedTx3);
    final tx3Id = await wallet2.broadcast(hexTx3);
    Log.ok('Broadcast · txid: $tx3Id');
    await btc.generateToAddress(1, minerAddr);

    await Future.delayed(Duration(seconds: 2));
    final res2 = await btc.getRawTransaction(tx3Id);
    expect(res2['confirmations'], 1,
        reason: "Post-restore transaction should be confirmed");

    Log.separator();
    Log.ok('All tests passed.');
  }, timeout: Timeout(Duration(minutes: 10)));
}
