import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:client/client.dart';
import 'package:client/bitcoin.dart';
import 'package:client/hardware_signer.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:e2e/logger.dart';
import 'package:grpc/grpc.dart';
import 'package:hive/hive.dart';

/// E2E test for hardware signer integration.
///
/// Prerequisites: `make regtest` must be running (bitcoind, electrs,
/// signer-server on 9090, MPC server on 50051).
void main() {
  late RegtestHelper btc;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mpc_hw_e2e_');
    Hive.init(tempDir.path);

    btc = RegtestHelper(rpcUrl: "http://127.0.0.1:18443/wallet/default");

    try {
      await btc.getNewAddress();
      Log.ok("Bitcoind reachable.");
    } catch (e) {
      throw Exception("Bitcoind not reachable. Run 'make regtest' first: $e");
    }
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('Hardware signer DKG + normal transaction (no signer needed)', () async {
    // 1. Connect to signer-server
    Log.step(1, 'Connecting to hardware signer (127.0.0.1:9090)');
    final signer = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await signer.connect();
    Log.ok('Connected.');

    // Verify signer has no key yet
    final infoBefore = await signer.getInfo();
    Log.info('Signer hasKeyPackage: ${infoBefore.hasKeyPackage}');
    expect(infoBefore.hasKeyPackage, isFalse);

    // 2. MPC Setup with hardware signer
    Log.step(2, 'Running DKG with hardware signer');
    final channel = ClientChannel(
      '127.0.0.1',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    final client = MpcClient(channel, hardwareSigner: signer);

    await client.doDkg();
    Log.ok('DKG complete.');

    // Verify signer now has a key package
    final infoAfter = await signer.getInfo();
    Log.info('Signer hasKeyPackage: ${infoAfter.hasKeyPackage}');
    expect(infoAfter.hasKeyPackage, isTrue);

    // 3. Init Wallet
    Log.step(3, 'Initializing wallet');
    final wallet = MpcBitcoinWallet(client, isTestnet: true);
    await wallet.init();

    final address = wallet.toAddressCustom(hrp: 'bcrt');
    Log.info('Wallet address: $address');
    expect(address, isNotNull);
    expect(address, startsWith('bcrt1'));

    // 4. Fund Wallet
    Log.step(4, 'Funding wallet (1 BTC)');
    final minerAddr = await btc.getNewAddress();

    final txId = await btc.sendToAddress(address, 1.0);
    Log.ok('Funded · txid: $txId');
    await btc.generateToAddress(1, minerAddr);

    // 5. Sync and verify balance
    Log.step(5, 'Syncing wallet');
    int retries = 30;
    while (retries > 0) {
      try {
        await wallet.sync();
        final utxos = await wallet.store.getUtxos();
        if (utxos.isNotEmpty) break;
        Log.warn("Synced 0 UTXOs — retrying… ($retries left)");
      } catch (e) {
        Log.warn("Sync error: $e — retrying…");
      }
      retries--;
      if (retries > 0) await Future.delayed(Duration(seconds: 2));
    }

    final utxos = await wallet.store.getUtxos();
    expect(utxos.length, greaterThanOrEqualTo(1));
    final balance = utxos.fold(BigInt.zero, (s, u) => s + u.utxo.value);
    Log.ok('Balance: $balance sats (${utxos.length} UTXO(s))');

    // 6. Normal spend
    Log.step(6, 'Normal spend (10,000 sats) — no hardware signer involved');
    final dest = await btc.getNewAddress();
    final unsignedTx = await wallet.createTransaction(
        destination: dest, amount: BigInt.from(10000), feeRate: 1);
    final hexTx = await wallet.signTransaction(unsignedTx);
    final spendTxId = await wallet.broadcast(hexTx);
    Log.ok('Broadcast · txid: $spendTxId');
    await btc.generateToAddress(1, minerAddr);

    // Verify transaction confirmed
    await Future.delayed(Duration(seconds: 2));
    final txInfo = await btc.getRawTransaction(spendTxId);
    expect(txInfo['confirmations'], greaterThanOrEqualTo(1));
    Log.ok('Confirmed with ${txInfo['confirmations']} confirmation(s).');

    // Cleanup
    Log.info('Cleaning up…');
    try {
      await signer.disconnect().timeout(Duration(seconds: 5));
    } catch (e) {
      Log.warn('Signer disconnect: $e');
    }
    try {
      await channel.terminate();
    } catch (e) {
      Log.warn('Channel terminate: $e');
    }

    Log.separator();
    Log.ok('Hardware signer E2E test passed.');
  }, timeout: Timeout(Duration(minutes: 5)));
}
