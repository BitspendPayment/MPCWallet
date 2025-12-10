import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:client/client.dart';
import 'package:client/bitcoin.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:grpc/grpc.dart';
import 'package:threshold/threshold.dart' as threshold;
import 'package:hive/hive.dart';
import 'package:blockchain_utils/blockchain_utils.dart'; // For SegwitBech32Encoder

void main() {
  Process? serverProcess; // Nullable
  late RegtestHelper btc;
  late Directory tempDir;
  bool useMock = false;

  setUpAll(() async {
    print('--- Setup ---');

    // 0. Hive Init
    tempDir = await Directory.systemTemp.createTemp('mpc_e2e_');
    Hive.init(tempDir.path);

    // 1. Docker
    print('Starting Docker...');
    // Use 'docker' executable directly to avoid path issues with 'docker-compose'
    final dRes = await Process.run(
        'docker', ['compose', 'up', '-d', 'bitcoind', 'electrs']);
    if (dRes.exitCode != 0) {
      throw Exception("Docker failed to start: ${dRes.stderr}");
    }

    // Wait for services to stabilize
    print("Waiting for Bitcoind & Electrs...");
    await Future.delayed(Duration(seconds: 15));

    // Probe
    btc = RegtestHelper();
    try {
      await btc.createWallet("default");
      // Re-init with wallet path to ensure all calls go to 'default' wallet
      btc = RegtestHelper(rpcUrl: "http://127.0.0.1:18443/wallet/default");
      await btc.getNewAddress();
      print("Docker Regtest Operational.");
    } catch (e) {
      throw Exception("Docker started but RPC unreachable: $e");
    }

    // 2. Server
    print('Starting MPC Server...');
    serverProcess = await Process.start(
      'dart',
      ['bin/server.dart'],
      workingDirectory: '../server',
      mode: ProcessStartMode.detachedWithStdio,
    );
    // Pipe stdout
    serverProcess!.stdout.transform(utf8.decoder).listen((data) {
      print('[Server]: $data');
    });
    serverProcess!.stderr.transform(utf8.decoder).listen((data) {
      print('[Server Error]: $data');
    });

    // Wait for server
    await Future.delayed(Duration(seconds: 5));
    print('--- Setup Complete ---');
  });

  tearDownAll(() {
    serverProcess?.kill();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('Full E2E Regtest Flow', () async {
    // 1. MPC Setup
    print('1. MPC Setup');
    final channel = ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    final id1 = threshold.Identifier(BigInt.from(1));
    final id2 = threshold.Identifier(BigInt.from(2));

    final randomId = DateTime.now().millisecondsSinceEpoch.toString();
    final client1 = MpcClient(channel, id1, id2, deviceId: "user_$randomId");

    await client1.doDkg();
    print('DKG Complete');

    // 2. Init Wallet
    // MPC Wallet manages its own store
    final wallet = MpcBitcoinWallet(client1, isTestnet: true);
    await wallet.init(); // Derives address and inits store

    // Use manual bcrt address for bitcoind interaction
    final address = wallet.address.toAddress(BitcoinNetwork.testnet);
    print('Wallet Address: $address');

    // 3. Mine to maturity
    print('2. Mining to maturity');
    final minerAddr = await btc.getNewAddress();
    await btc.generateToAddress(150, minerAddr);

    final balance = await btc.getBalance();
    print("Miner Wallet Balance: $balance");

    // 4. Fund Wallet 1
    print('3. Funding Wallet 1');
    String txId;
    try {
      // Regtest accepts testnet addresses usually? Or we need 'bcrt' prefix?
      // If 'tb1' fails, we might need a custom network.
      txId = await btc.sendToAddress(address, 1.0);
      print('Funded Wallet 1 with $txId');
    } catch (e) {
      print("Funding Failed: $e");
      rethrow;
    }
    await btc.generateToAddress(1, minerAddr); // Confirm

    // 5. Sync Wallet 1
    print('4. Syncing Wallet 1 via Electrum');
    // Use Real Electrum Provider
    final electrumProvider = RealElectrumProvider();
    try {
      await wallet.sync(electrumProvider);

      final utxos = await wallet.store.getUtxos();
      expect(utxos.length, greaterThanOrEqualTo(1));
      print(
          'Synced Wallet 1: ${utxos.length} UTXOs. Balance: ${utxos.fold(BigInt.zero, (s, u) => s + u.utxo.value)}');

      // --- SETUP WALLET 2 ---
      print('--- Setup Wallet 2 (Bob) ---');
      final client2 =
          MpcClient(channel, id1, id2, deviceId: "user_bob_${randomId}");
      // DKG for Bob
      await client2.doDkg();
      print('DKG Complete for Wallet 2');

      final wallet2 = MpcBitcoinWallet(client2,
          storageId: 'wallet_bob_${randomId}', isTestnet: true);
      await wallet2.init();
      final address2 = wallet2.address.toAddress(BitcoinNetwork.testnet);
      print('Wallet 2 Address: $address2');

      // 6. Send Transaction from Wallet 1 to Wallet 2
      print('5. Sending Transaction from Wallet 1 to Wallet 2');
      final dest = address2;
      final hexTx = await wallet.createTransaction(
          destination: dest,
          amount: BigInt.from(100000), // 0.001 BTC
          feeRate: 1);

      // Broadcast
      final sendTxId = await btc.sendRawTransaction(hexTx);
      print('Sent TX: $sendTxId');

      // 7. Verify
      await btc.generateToAddress(1, minerAddr);
      final txInfo = await btc.getRawTransaction(sendTxId);
      expect(txInfo['confirmations'], greaterThanOrEqualTo(1));
      print('Transaction Confirmed!');

      // 8. Sync Wallet 2 and Verify Receipt
      print('6. Syncing Wallet 2');
      // Wait a bit for Electrum to catch up?
      // electrs is usually fast but might need a moment after block generation
      await Future.delayed(Duration(seconds: 2));
      await wallet2.sync(electrumProvider);
      final utxos2 = await wallet2.store.getUtxos();
      print(
          'Synced Wallet 2: ${utxos2.length} UTXOs. Balance: ${utxos2.fold(BigInt.zero, (s, u) => s + u.utxo.value)}');

      expect(utxos2.length, 1);
      expect(utxos2[0].utxo.value, BigInt.from(100000));
      print('Wallet 2 verification successful!');
    } finally {
      electrumProvider.close();
    }

    await channel.shutdown();
  });
}

class RealElectrumProvider {
  static const int port = 50001;
  static const String host = 'localhost';

  Future<List<dynamic>> request(dynamic request) async {
    // Connect, Send, Receive, Close.
    // Optimization: Keep persistent connection if possible, but for test simple is better.
    // However, sync might expect persistent? No, underlying method just awaits request.

    // Check request type
    // dynamic request -> assuming ElectrumRequestScriptHashListUnspent
    // It has a method `scriptHash`
    // We cannot easily check type without importing bitcoin_base classes if strict
    // But we know what it is.
    final scriptHash = request.scriptHash;

    final socket = await Socket.connect(host, port);

    final payload = {
      "jsonrpc": "2.0",
      "method": "blockchain.scripthash.listunspent",
      "params": [scriptHash],
      "id": 1
    };

    socket.writeln(jsonEncode(payload));

    // Read response
    // Electrum sends newline terminated JSON
    final completer = Completer<List<dynamic>>();

    // transform(utf8.decoder) should work on Stream<List<int>> which Socket is.
    // If strict mode complains, we can cast or wrap.
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.isNotEmpty) {
        try {
          final body = jsonDecode(line);
          if (body['error'] != null) {
            completer.completeError("Electrum Error: ${body['error']}");
          } else {
            // result is list of utxos
            // [{tx_hash, tx_pos, value, height}]
            // We need to map this to what MpcBitcoinWallet expects.
            // MpcBitcoinWallet expects: u.txHash, u.txPos, u.value
            // Note: electrs returns `tx_hash`, `tx_pos`, `value`
            // BUT `FakeElectrumProvider` returned objects or maps?
            // `MpcBitcoinWallet` line 266: `u.txHash`.
            // It seems MpcBitcoinWallet expects a typed object if using a typed library!
            // Wait, check MpcBitcoinWallet import.
            // It imports `bitcoin_base`.
            // Does `provider.request` return raw JSON list or typed objects?
            // In `MpcBitcoinWallet.sync`:
            /*
                final List<dynamic> unspent = await (provider as dynamic)
                  .request(ElectrumRequestScriptHashListUnspent(scriptHash: scriptHash));
                ...
                final newUtxos = unspent.map((u) { ... u.txHash ... }).toList();
             */
            // This suggests `unspent` list contains objects with `.txHash`, not Maps.
            // If `RealElectrumProvider` returns Maps (from JSON), `u.txHash` will fail.
            // UNLESS `u` is dynamic and user uses `.property` on it?
            // Dart allows `.property` on dynamic, but Map doesn't have `txHash`.
            // `FakeElectrumProvider` returned `MockUtxo` objects.
            // So I MUST return objects that have `txHash`, `txPos`, `value`.

            final result = body['result'] as List;
            final mapped = result
                .map((r) => ElectrumUtxo(
                    txHash: r['tx_hash'],
                    txPos: r['tx_pos'],
                    value: r['value']))
                .toList();

            if (!completer.isCompleted) completer.complete(mapped);
          }
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
        socket.destroy();
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    });

    return completer.future;
  }

  void close() {}
}

class ElectrumUtxo {
  final String txHash;
  final int txPos;
  final int value;
  ElectrumUtxo(
      {required this.txHash, required this.txPos, required this.value});
}
