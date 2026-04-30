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
import 'package:fixnum/fixnum.dart';

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
        '--wasm', '../cosigner/target/wasm32-wasip1/release/cosigner.wasm',
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

  test('Full E2E Regtest Flow with Policies', () async {
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

    // 6. Create Spending Policy
    Log.step(5, 'Creating Spending Policy (limit: 50,000 sats)');
    final interval = Duration(hours: 1);
    const pin = "123456";
    final limit = Int64(50000);

    await client1.createSpendingPolicy(interval, limit, pin);
    Log.ok('Spending policy created (PIN-protected).');

    // 7. Attempt Spend exceeding limit (should fail)
    Log.step(6, 'Attempting Over-Limit Spend (60,000 sats) — expect failure');
    bool failed = false;
    try {
      final dest2 = await btc.getNewAddress();
      final unsignedTx2 = await wallet.createTransaction(
          destination: dest2, amount: BigInt.from(60000), feeRate: 1);
      await wallet.signTransaction(unsignedTx2);
    } catch (e) {
      Log.warn('Expected failure caught: $e');
      failed = true;
    }
    expect(failed, isTrue, reason: "Transaction should fail without PIN");

    // 8. Spend with PIN
    Log.step(7, 'Spending with PIN (60,000 sats)');
    await waitForUtxoByTxId(wallet, tx1Id);

    final dest3 = await btc.getNewAddress();
    final unsignedTx2 = await wallet.createTransaction(
        destination: dest3, amount: BigInt.from(60000), feeRate: 1);
    final policyId = await wallet.getPolicyId(unsignedTx2);
    final hexTx2 =
        await wallet.signTransaction(unsignedTx2, policyId: policyId, pin: pin);
    final tx2Id = await wallet.broadcast(hexTx2);
    Log.ok('Broadcast · txid: $tx2Id');
    await btc.generateToAddress(1, minerAddr);

    await waitForUtxoByTxId(wallet, tx2Id);
    await wallet.sync();

    final balance = await wallet.store
        .getUtxos()
        .then((l) => l.fold(BigInt.zero, (s, u) => s + u.utxo.value).toInt());
    Log.info('Final balance: $balance sats');

    final res = await btc.getRawTransaction(tx2Id);
    expect(res['confirmations'], 1);

    // 9. Delete Spending Policy
    Log.step(8, 'Deleting Spending Policy');
    final policy = client1.activeSpendingPolicy;
    expect(policy, isNotNull, reason: "Should have an active policy to delete");
    await client1.deletePolicy(policy!.id);
    expect(client1.hasSpendingPolicy, isFalse,
        reason: "Policy should be removed after deletion");
    Log.ok('Policy deleted: ${policy.id}');

    // 10. Verify spend works without PIN after policy deletion
    Log.step(9, 'Spending without PIN after policy deletion (should succeed)');
    await waitForUtxoByTxId(wallet, tx2Id);
    await wallet.sync();
    final dest5 = await btc.getNewAddress();
    final unsignedTx4 = await wallet.createTransaction(
        destination: dest5, amount: BigInt.from(60000), feeRate: 1);
    final hexTx4 = await wallet.signTransaction(unsignedTx4);
    final tx4Id = await wallet.broadcast(hexTx4);
    Log.ok('Broadcast: $tx4Id');
    await btc.generateToAddress(1, minerAddr);
    await waitForUtxoByTxId(wallet, tx4Id);

    // 11. Restore wallet (simulate new phone)
    Log.step(10, 'Restoring Wallet via re-DKG');
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

    // 12. Sync restored wallet
    await Future.delayed(Duration(seconds: 2));
    Log.step(11, 'Syncing Restored Wallet');
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

    // 13. Sign with restored wallet
    Log.step(12, 'Signing Transaction with Restored Wallet');
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

  test('Policy: Cumulative spending within window', () async {
    // This test verifies that the policy engine correctly tracks cumulative
    // spending across multiple transactions within the same time window.
    //
    // Bug scenario: 50,000 sat policy limit
    //   - Spend 20,000 sats → under limit, goes through with normal policy
    //   - Spend 31,000 sats → cumulative 51,000 > 50,000, SHOULD require PIN
    //   - Previously the second spend also went through without PIN

    print('=== Policy Cumulative Spending Test ===');

    // 1. Setup fresh client
    print('1. MPC Setup');
    final signer = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await signer.connect();
    final client = createClient(signer, storageId: 'policy_cumulative');

    await client.doDkg();
    print('   DKG Complete');

    final wallet = MpcBitcoinWallet(client, networkName: 'regtest');
    await wallet.init();
    final address = wallet.toAddress();
    print('   Wallet Address: $address');

    // 2. Fund wallet generously
    print('2. Funding wallet');
    final minerAddr = await btc.getNewAddress();
    // Mine blocks to ensure miner has enough to send
    await btc.generateToAddress(10, minerAddr);

    final txId = await btc.sendToAddress(address, 0.5); // 50,000,000 sats
    await btc.generateToAddress(1, minerAddr);
    print('   Funded with $txId');

    // 3. Sync wallet
    print('3. Syncing wallet');
    int retries = 30;
    while (retries > 0) {
      await wallet.sync();
      final utxos = await wallet.store.getUtxos();
      if (utxos.isNotEmpty) break;
      print('   Waiting for UTXO... ($retries left)');
      retries--;
      if (retries > 0) await Future.delayed(Duration(seconds: 2));
    }
    final utxos = await wallet.store.getUtxos();
    expect(utxos.length, greaterThanOrEqualTo(1));
    final bal = utxos.fold(BigInt.zero, (s, u) => s + u.utxo.value);
    print('   Balance: $bal sats');

    // 4. Create spending policy: 50,000 sat limit, 1 hour window
    print('4. Creating spending policy (50,000 sat limit, 1h window)');
    const pin = "654321";
    await client.createSpendingPolicy(Duration(hours: 1), Int64(50000), pin);
    expect(client.hasSpendingPolicy, isTrue);
    print('   Policy created');

    // 5. First spend: 20,000 sats — under limit, should succeed without PIN
    print('5. First spend: 20,000 sats (under limit, no PIN)');
    final dest1 = await btc.getNewAddress();
    final unsigned1 = await wallet.createTransaction(
        destination: dest1, amount: BigInt.from(20000), feeRate: 1);
    final hex1 = await wallet.signTransaction(unsigned1);
    final tx1 = await wallet.broadcast(hex1);
    print('   Broadcast: $tx1');
    await btc.generateToAddress(1, minerAddr);
    await waitForUtxoByTxId(wallet, tx1);

    // 6. Second spend: 31,000 sats — cumulative 51,000 > 50,000, should FAIL without PIN
    print('6. Second spend: 31,000 sats (cumulative 51k > 50k limit, no PIN — expect failure)');
    await wallet.sync();
    bool secondSpendFailed = false;
    try {
      final dest2 = await btc.getNewAddress();
      final unsigned2 = await wallet.createTransaction(
          destination: dest2, amount: BigInt.from(31000), feeRate: 1);
      await wallet.signTransaction(unsigned2);
    } catch (e) {
      print('   Expected failure: $e');
      secondSpendFailed = true;
    }
    expect(secondSpendFailed, isTrue,
        reason: "Second spend should fail without PIN because cumulative (20k+31k=51k) exceeds 50k limit");

    // 7. Same spend with PIN — should succeed
    print('7. Second spend: 31,000 sats WITH PIN (should succeed)');
    final dest3 = await btc.getNewAddress();
    final unsigned3 = await wallet.createTransaction(
        destination: dest3, amount: BigInt.from(31000), feeRate: 1);
    final policyId = await wallet.getPolicyId(unsigned3);
    final hex3 = await wallet.signTransaction(unsigned3, policyId: policyId, pin: pin);
    final tx3 = await wallet.broadcast(hex3);
    print('   Broadcast: $tx3');
    await btc.generateToAddress(1, minerAddr);
    await waitForUtxoByTxId(wallet, tx3);

    // 8. Third spend: small amount — cumulative now ~82k, any spend should require PIN
    print('8. Third spend: 5,000 sats (cumulative ~82k > 50k, no PIN — expect failure)');
    await wallet.sync();
    bool thirdSpendFailed = false;
    try {
      final dest4 = await btc.getNewAddress();
      final unsigned4 = await wallet.createTransaction(
          destination: dest4, amount: BigInt.from(5000), feeRate: 1);
      await wallet.signTransaction(unsigned4);
    } catch (e) {
      print('   Expected failure: $e');
      thirdSpendFailed = true;
    }
    expect(thirdSpendFailed, isTrue,
        reason: "Any spend should require PIN when cumulative already exceeds limit");

    // 9. Under-limit spend after policy deletion should work
    print('9. Delete policy, then spend without PIN');
    final activePolicy = client.activeSpendingPolicy!;
    await client.deletePolicy(activePolicy.id);
    expect(client.hasSpendingPolicy, isFalse);

    final dest5 = await btc.getNewAddress();
    final unsigned5 = await wallet.createTransaction(
        destination: dest5, amount: BigInt.from(5000), feeRate: 1);
    final hex5 = await wallet.signTransaction(unsigned5);
    final tx5 = await wallet.broadcast(hex5);
    print('   Broadcast: $tx5');
    await btc.generateToAddress(1, minerAddr);

    await Future.delayed(Duration(seconds: 2));
    final res = await btc.getRawTransaction(tx5);
    expect(res['confirmations'], 1);

    print('=== Policy Cumulative Spending Test Complete ===');
  }, timeout: Timeout(Duration(minutes: 10)));
}
