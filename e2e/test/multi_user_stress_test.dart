import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:client/client.dart';
import 'package:client/bitcoin.dart';
import 'package:client/hardware_signer.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:grpc/grpc.dart';
import 'package:hive/hive.dart';

void main() {
  late RegtestHelper btc;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mpc_multi_stress_');
    Hive.init(tempDir.path);
    btc = RegtestHelper(rpcUrl: "http://127.0.0.1:18443/wallet/default");
    
    try {
      await btc.getNewAddress();
    } catch (e) {
      throw Exception("Bitcoind not reachable. Run 'make regtest' first: $e");
    }
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('Multi-User Stress Test: Concurrent DKGs and Sequential Transactions', () async {
    final channel = ClientChannel(
      '127.0.0.1',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    // 1. Setup two hardware signers (separate connections to avoid state conflicts in signer-server)
    final signerA = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    final signerB = TcpHardwareSigner(host: '127.0.0.1', port: 9091);
    await Future.wait([signerA.connect(), signerB.connect()]);

    final clientA = MpcClient(channel, hardwareSigner: signerA, storageId: 'user_a_stress');
    final clientB = MpcClient(channel, hardwareSigner: signerB, storageId: 'user_b_stress');

    print('Starting concurrent DKGs for User A and User B...');
    await Future.wait([
      clientA.doDkg(),
      clientB.doDkg(),
    ]);
    print('DKGs Complete.');

    final walletA = MpcBitcoinWallet(clientA, isTestnet: true, storageId: 'user_a_wallet_stress');
    final walletB = MpcBitcoinWallet(clientB, isTestnet: true, storageId: 'user_b_wallet_stress');
    await Future.wait([walletA.init(), walletB.init()]);

    final addrA = walletA.toAddressCustom(hrp: 'bcrt');
    final addrB = walletB.toAddressCustom(hrp: 'bcrt');
    print('User A: $addrA, User B: $addrB');

    // Fund A
    print('Funding User A...');
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(addrA, 1.0);
    await btc.generateToAddress(1, minerAddr);

    // Sync A
    print('Syncing User A (waiting for funding)...');
    await _waitForBalance(walletA, BigInt.zero);
    print('User A Balance: ${await walletA.getBalance()}');

    // Run 5 rounds of A -> B -> A
    for (int i = 1; i <= 5; i++) {
        print('--- Transaction Round $i ---');
        
        // A -> B
        print('User A -> User B (10,000 sats)');
        final txAB = await walletA.createTransaction(destination: addrB, amount: BigInt.from(10000), feeRate: 1);
        final hexAB = await walletA.signTransaction(txAB);
        final idAB = await walletA.broadcast(hexAB);
        print('  Broadcast A->B: $idAB');
        await btc.generateToAddress(1, minerAddr);
        
        final oldBalanceB = await walletB.getBalance();
        await _waitForBalance(walletB, oldBalanceB);
        print('  User B Balance: ${await walletB.getBalance()}');

        // B -> A
        print('User B -> User A (5,000 sats)');
        final txBA = await walletB.createTransaction(destination: addrA, amount: BigInt.from(5000), feeRate: 1);
        final hexBA = await walletB.signTransaction(txBA);
        final idBA = await walletB.broadcast(hexBA);
        print('  Broadcast B->A: $idBA');
        await btc.generateToAddress(1, minerAddr);

        final oldBalanceA = await walletA.getBalance();
        await _waitForBalance(walletA, oldBalanceA);
        print('  User A Balance: ${await walletA.getBalance()}');
    }

    print('Multi-User Stress Test Complete.');
    await Future.wait([signerA.disconnect(), signerB.disconnect()]);
    await channel.terminate();
  }, timeout: Timeout(Duration(minutes: 10)));
}

Future<void> _waitForBalance(MpcBitcoinWallet wallet, BigInt currentBalance) async {
  int retries = 30;
  while (retries > 0) {
    try {
      await wallet.sync();
      final newBalance = await wallet.getBalance();
      if (newBalance != currentBalance) return;
    } catch (_) {}
    retries--;
    if (retries > 0) await Future.delayed(Duration(seconds: 2));
  }
  throw Exception("Timeout waiting for balance change. Current: $currentBalance");
}

Future<BigInt> _getBalance(MpcBitcoinWallet wallet) async {
  return await wallet.getBalance();
}
