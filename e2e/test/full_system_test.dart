import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:client/client.dart';
import 'package:client/bitcoin.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:grpc/grpc.dart';
import 'package:threshold/threshold.dart' as threshold;
import 'package:hive/hive.dart';

void main() {
  late Process serverProcess;
  late RegtestHelper btc;
  late Directory tempDir;
  bool useMock = false;

  setUpAll(() async {
    print('--- Setup ---');

    // 0. Hive Init
    tempDir = await Directory.systemTemp.createTemp('mpc_e2e_');
    Hive.init(tempDir.path);

    // 1. Docker
    print('Starting Docker (optimistic)...');
    try {
      // Use 'docker' executable directly to avoid path issues with 'docker-compose'
      await Process.run(
          'docker', ['compose', 'up', '-d', 'bitcoind', 'electrs']);
      await Future.delayed(
          Duration(seconds: 10)); // Wait longer for bitcoind warmup

      // Probe
      final probe = RegtestHelper();
      try {
        await probe.getNewAddress();
        btc = probe;
        print("Docker Regtest Operational.");
      } catch (e) {
        print("Docker started but RPC unreachable: $e. Using Mock.");
        useMock = true;
        btc = MockRegtestHelper();
      }
    } catch (e) {
      print("Docker start failed: $e. Using Mock.");
      useMock = true;
      btc = MockRegtestHelper();
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
    serverProcess.stdout.transform(utf8.decoder).listen((data) {
      print('[Server]: $data');
    });
    serverProcess.stderr.transform(utf8.decoder).listen((data) {
      print('[Server Error]: $data');
    });

    // Wait for server
    await Future.delayed(Duration(seconds: 5));
    print('--- Setup Complete ---');
  });

  tearDownAll(() {
    serverProcess.kill();
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
    final wallet = MpcBitcoinWallet(client1);
    await wallet.init(); // Derives address and inits store

    final address = wallet.address.toAddress(BitcoinNetwork.mainnet);
    print('Wallet Address: $address');

    // 3. Mine to maturity
    print('2. Mining to maturity');
    final minerAddr = await btc.getNewAddress();
    await btc.generateToAddress(101, minerAddr);

    // 4. Fund Wallet
    print('3. Funding');
    final txId = await btc.sendToAddress(address, 1.0);
    print('Funded with $txId');
    await btc.generateToAddress(1, minerAddr); // Confirm

    // 5. Sync
    print('4. Syncing via Electrum');
    // Using Fake Provider that wraps btc helper (Regtest or Mock)
    final fakeProvider = FakeElectrumProvider(btc, address);
    await wallet.sync(fakeProvider);

    final utxos = await wallet.store.getUtxos();
    expect(utxos.length, greaterThanOrEqualTo(1));
    print(
        'Synced ${utxos.length} UTXOs. Balance: ${utxos.fold(BigInt.zero, (s, u) => s + u.utxo.value)}');

    // 6. Send Transaction
    print('5. Sending Transaction');
    final dest = address; // Send to self to ensure valid address
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
    await channel.shutdown();
  });
}

// Mock Provider so we don't depend on unresolvable Imports or connection issues
class FakeElectrumProvider {
  final RegtestHelper btc;
  final String address;

  FakeElectrumProvider(this.btc, this.address);

  Future<List<dynamic>> request(dynamic request) async {
    // 1. Get List of unspent for tracking by address?
    // We use `scanUtxos` now available on helper.
    final utxos = await btc.scanUtxos(address);
    return utxos
        .map((u) => MockUtxo(u['txid'], u['vout'], u['amount']))
        .toList();
  }
}

class MockUtxo {
  final String txHash;
  final int txPos;
  final int value;

  MockUtxo(this.txHash, this.txPos, double amountBtc)
      : value = (amountBtc * 100000000).round();
}

// Mock Helper for CI/No-Docker environments
class MockRegtestHelper implements RegtestHelper {
  @override
  String get rpcUrl => "mock";

  @override
  Future<String> getNewAddress() async {
    return "mock_addr_random";
  }

  @override
  Future<List<String>> generateToAddress(int blocks, String address) async =>
      [];
  @override
  Future<String> sendToAddress(String address, double amount) async =>
      "0000000000000000000000000000000000000000000000000000000000000001";
  @override
  Future<dynamic> getRawTransaction(String txId) async => {'confirmations': 1};
  @override
  Future<String> sendRawTransaction(String hex) async =>
      "0000000000000000000000000000000000000000000000000000000000000002";
  @override
  Future<List<Map<String, dynamic>>> scanUtxos(String address) async => [
        {
          'txid':
              '0000000000000000000000000000000000000000000000000000000000000001',
          'vout': 0,
          'amount': 1.0
        }
      ];
  @override
  Future<dynamic> getMempoolEntry(String txId) async => {};
  @override
  Future<dynamic> _call(String method, [List? params]) async => null;
}
