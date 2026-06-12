import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/ark/ark_send.dart';
import 'package:app_core/ark_wallet.dart';
import 'package:app_core/client.dart';
import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:e2e/mock_fcm_server.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Full e2e: a contract eVTXO minted and spent THROUGH arkd — the ASP genuinely
/// co-signs the cooperative (`ConditionMultisigClosure`) leaf; no forged key.
///
/// 1. Alice DKG (V); Bob DKG (recipient). Build the `oracle-gate` contract.
/// 2. `createEvtxoKey` → V′ + eVTXO spk; derive its Ark address.
/// 3. Alice boards + settles → a normal Ark VTXO.
/// 4. Alice sends to the eVTXO Ark address → arkd MINTS a VTXO at it (now tracked).
/// 5. Alice spends the eVTXO via arkd:
///    - allow (within limit + good arg): V′ FROST leg (gate allows) + arkd co-signs
///      the server leg → ark_txid returned, Bob credited.
///    - over-limit / bad-arg: the cosigner withholds the V′ share → throws at sign.
///
/// Prereqs (mirrors `make e2e-ark`): bitcoind + arkd + signer-server(9090) +
/// cosigner.wasm/cosigner-runtime/ffi/contracts built. The contract is handed to
/// the cosigner at eVTXO creation (no registry).

const oracleGateWasmPath =
    '../contracts/examples/oracle-gate/target/wasm32-wasip2/release/oracle_gate.wasm';

class ArkdAdmin {
  final String adminUrl;
  final String publicUrl;
  ArkdAdmin({
    this.adminUrl = 'http://127.0.0.1:7071',
    this.publicUrl = 'http://127.0.0.1:7070',
  });
  Future<Map<String, dynamic>> getInfo() async {
    final resp = await http.get(Uri.parse('$publicUrl/v1/info'));
    if (resp.statusCode != 200) throw Exception('arkd info failed: ${resp.body}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<bool> isReady() async {
    try {
      await getInfo();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> initWallet() async {
    final seedResp = await http.get(Uri.parse('$adminUrl/v1/admin/wallet/seed'));
    if (seedResp.statusCode != 200) throw Exception('seed failed: ${seedResp.body}');
    final seed = jsonDecode(seedResp.body)['seed'] as String;
    await http.post(Uri.parse('$adminUrl/v1/admin/wallet/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'seed': seed, 'password': 'password'}));
    await Future.delayed(Duration(seconds: 1));
    await http.post(Uri.parse('$adminUrl/v1/admin/wallet/unlock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': 'password'}));
    await Future.delayed(Duration(seconds: 1));
  }

  Future<String> getWalletAddress() async {
    final resp = await http.get(Uri.parse('$adminUrl/v1/admin/wallet/address'));
    if (resp.statusCode != 200) throw Exception('wallet address failed: ${resp.body}');
    return jsonDecode(resp.body)['address'] as String;
  }
}

Future<Process> startCosignerRuntime(
  int port,
  Directory dataDir, {
  Map<String, String> extraEnv = const {},
}) async {
  final serverReady = Completer<void>();
  final serverFailed = Completer<void>();
  final env = {
    'ELECTRUM_URL': '127.0.0.1',
    'ELECTRUM_PORT': '50001',
    'BITCOIN_RPC_USER': 'admin1',
    'BITCOIN_RPC_PASSWORD': '123',
    'ASP_URL': 'http://127.0.0.1:7070',
    'BITCOIN_NETWORK': 'regtest',
    'AUTO_SETTLE_SAFETY_MARGIN_SECS': '3600',
    'HOME': dataDir.path,
    ...extraEnv,
  };
  final proc = await Process.start(
    '../cosigner-runtime/target/release/cosigner-runtime',
    ['--wasm', '../cosigner/target/wasm32-wasip2/release/cosigner.wasm', '--port', port.toString()],
    environment: env,
  );
  void watch(Stream<List<int>> s) {
    s.transform(utf8.decoder).listen((data) {
      print('[Server]: $data');
      if (!serverReady.isCompleted && data.contains('MPC Wallet Server listening on')) {
        serverReady.complete();
      }
    }, onDone: () {
      if (!serverReady.isCompleted && !serverFailed.isCompleted) serverFailed.complete();
    });
  }

  watch(proc.stdout);
  watch(proc.stderr);
  try {
    await Future.any([
      serverReady.future,
      serverFailed.future.then((_) => throw Exception('MPC Server failed')),
    ]).timeout(Duration(seconds: 30),
        onTimeout: () => throw Exception('MPC Server not ready in time'));
  } catch (e) {
    proc.kill();
    rethrow;
  }
  return proc;
}

void main() {
  late RegtestHelper btc;
  late ArkdAdmin arkd;
  late Directory tempDir;
  late Directory serverTempDir;
  late MockFcmServer mockFcm;
  Process? serverProcess;
  late int serverPort;

  setUpAll(() async {
    print('--- eVTXO-through-arkd E2E Setup ---');
    tempDir = await Directory.systemTemp.createTemp('mpc_evtxo_arkd_');
    Hive.init(tempDir.path);

    btc = RegtestHelper();
    try {
      await btc.createWallet('default');
    } catch (e) {
      if (!e.toString().contains('already loaded')) rethrow;
    }
    btc = RegtestHelper(rpcUrl: 'http://127.0.0.1:18443/wallet/default');
    await btc.getNewAddress();

    arkd = ArkdAdmin();
    bool ready = false;
    for (int i = 0; i < 10; i++) {
      if (await arkd.isReady()) {
        ready = true;
        break;
      }
      await Future.delayed(Duration(seconds: 3));
    }
    if (!ready) {
      await arkd.initWallet();
      await Future.delayed(Duration(seconds: 2));
    }
    try {
      final aspAddr = await arkd.getWalletAddress();
      final minerAddr = await btc.getNewAddress();
      await btc.generateToAddress(101, minerAddr);
      await btc.sendToAddress(aspAddr, 10.0);
      await btc.generateToAddress(1, minerAddr);
      await Future.delayed(Duration(seconds: 5));
    } catch (e) {
      print('  Warning: could not fund ASP: $e');
    }

    mockFcm = MockFcmServer();
    await mockFcm.start();
    const fcmTestProjectId = 'mpc-wallet-e2e-test';
    final keyPem = await File('../e2e/fixtures/fcm_test_key.pem').readAsString();
    final fcmServiceAccountJson = jsonEncode({
      'type': 'service_account',
      'project_id': fcmTestProjectId,
      'private_key_id': 'e2e-mock',
      'private_key': keyPem,
      'client_email': 'fcm-e2e@$fcmTestProjectId.iam.gserviceaccount.com',
      'token_uri': mockFcm.tokenUri,
    });

    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_evtxo_arkd_server_');
    serverProcess = await startCosignerRuntime(serverPort, serverTempDir, extraEnv: {
      'FCM_SERVICE_ACCOUNT_JSON': fcmServiceAccountJson,
      'FCM_BASE_URL': mockFcm.baseUrl,
    });
    print('--- Setup Complete (port $serverPort) ---');
  });

  tearDownAll(() async {
    serverProcess?.kill();
    try {
      await mockFcm.stop();
    } catch (_) {}
    try {
      await serverTempDir.delete(recursive: true);
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Settle Alice's boarding UTXO into a VTXO, mining blocks to trigger batches.
  Future<void> settleWithMining(MpcClient client) async {
    bool settling = true;
    final timer = Timer.periodic(Duration(seconds: 3), (t) async {
      if (!settling) {
        t.cancel();
        return;
      }
      try {
        final a = await btc.getNewAddress();
        await btc.generateToAddress(1, a);
      } catch (_) {}
    });
    try {
      await client.settle();
    } finally {
      settling = false;
      timer.cancel();
    }
  }

  test('eVTXO through arkd: mint via send, arkd co-signs cooperative spend, deny over-limit/bad-arg',
      () async {
    // 1. Alice + Bob real 2-of-2 DKG (no signer; distinct local stores).
    final alice =
        MpcClient.rest('http://127.0.0.1:$serverPort', storageId: 'alice');
    await alice.doDkg();
    final bob = MpcClient.rest('http://127.0.0.1:$serverPort', storageId: 'bob');
    await bob.doDkg();
    final bobArk = await bob.getArkAddress();
    print('1. DKG done. alice=${alice.userId?.substring(0, 12)}, bob=${bob.userId?.substring(0, 12)}');

    // 2. eVTXO key bound to the oracle-gate contract.
    final arkInfo = await alice.getArkInfo();
    var serverPkHex = arkInfo.signerPubkey;
    if (serverPkHex.length == 66) serverPkHex = serverPkHex.substring(2);
    final serverPk = Uint8List.fromList(BytesUtils.fromHexString(serverPkHex));
    final exitDelay = arkInfo.unilateralExitDelay.toInt();
    final wasmBytes = await File(oracleGateWasmPath).readAsBytes();
    final contractId = Uint8List.fromList(QuickCrypto.sha256Hash(wasmBytes));
    final evtxo = await alice.createEvtxoKey(contractId, wasmBytes, serverPk, exitDelay);
    // qEvtxo = the eVTXO's taproot OUTPUT key (the address). vPrime = V′, the raw
    // 2-of-2 key INSIDE the cooperative multisig leaf — these are different.
    final qEvtxo = Uint8List.fromList(evtxo.scriptPubkey.sublist(2));
    final vPrimeXonly = _xonlyOf(evtxo.publicKeyPackage);

    // V′ MUST differ from V: createEvtxoKey runs a real 2-of-2 reshare
    // (V′ = V + Δ_author + Δ_cosigner), not the old one-shot V′ == V register.
    final vXonly = _xonlyOf(alice.getPublicKeyPackage()!);
    expect(BytesUtils.toHexString(vPrimeXonly),
        isNot(equals(BytesUtils.toHexString(vXonly))),
        reason: 'V′ must differ from V — createEvtxoKey must run a real reshare');
    print('   V  x-only: ${BytesUtils.toHexString(vXonly)}');
    print('   V′ x-only: ${BytesUtils.toHexString(vPrimeXonly)}');

    final evtxoArkAddr =
        arkEvtxoArkAddress(serverPk: serverPk, qEvtxo: qEvtxo, network: arkInfo.network);
    print('2. eVTXO key created; ark address=$evtxoArkAddr');

    // 3. Board + settle Alice → a normal VTXO.
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.01); // 1,000,000 sats
    await btc.generateToAddress(1, minerAddr);
    await Future.delayed(Duration(seconds: 5));
    await settleWithMining(alice);
    final afterSettle = await alice.listVtxos();
    expect(afterSettle.vtxos, isNotEmpty, reason: 'Alice should hold a VTXO after settle');
    print('3. Settled. Alice balance=${afterSettle.totalBalance}');

    // 4. Mint the eVTXO: send to its Ark address → arkd tracks a VTXO at Q_evtxo.
    // The contract gate runs on the CHECKPOINT PSBT, whose single output forwards
    // the FULL eVTXO value into the Ark layer — so the oracle-gate limit (100k)
    // effectively caps the eVTXO denomination. Mint two eVTXOs at the same address:
    // a 90k one (under the limit → allow) and a 300k one (over the limit → deny).
    final wallet = MpcArkWallet(alice);
    Future<String> mint(int sats) async {
      final u = await wallet.createTransaction(destination: evtxoArkAddr, amountSats: sats);
      final s = await wallet.signTransaction(u);
      final txid = await wallet.submit(s);
      expect(txid, isNotEmpty, reason: 'mint send should return an ark_txid');
      await Future.delayed(Duration(seconds: 2));
      return txid; // recipient (eVTXO) is output 0; change is output 1
    }

    final mint90 = await mint(90000);
    final mint300 = await mint(300000);
    print('4. Minted eVTXOs: $mint90:0 (90k), $mint300:0 (300k)');

    Future<UnsignedArkTransaction> buildSpend(
            String txid, int inAmt, String args) =>
        wallet.createEvtxoSpend(
          destination: bobArk,
          amountSats: 50000,
          inputTxid: txid,
          inputVout: 0,
          inputAmountSats: inAmt,
          contractId: contractId,
          evtxoPk: vPrimeXonly,
          exitDelay: exitDelay,
          contractArgs: Uint8List.fromList(utf8.encode(args)),
        );

    // 5a. DENY (over-limit): the 300k eVTXO exceeds the 100k limit. The gate fires
    // at sign time (before submit), so the input needn't be unspent.
    await _expectDenied(
        () async => wallet.signEvtxoSpend(await buildSpend(mint300, 300000, 'ORACLE-OK'),
            evtxoKeyPkg: evtxo.keyPackage, evtxoPkp: evtxo.publicKeyPackage),
        'over-limit');
    print('5a. DENY over-limit: cosigner refused (gate)');

    // 5b. DENY (bad arg): wrong oracle token on the 90k eVTXO.
    await _expectDenied(
        () async => wallet.signEvtxoSpend(await buildSpend(mint90, 90000, 'WRONG-TOKEN'),
            evtxoKeyPkg: evtxo.keyPackage, evtxoPkp: evtxo.publicKeyPackage),
        'bad-arg');
    print('5b. DENY bad-arg: cosigner refused (gate)');

    // 5c. ALLOW — 90k eVTXO (≤ limit) + good arg: arkd co-signs the cooperative spend.
    final allowSigned = await wallet.signEvtxoSpend(
        await buildSpend(mint90, 90000, 'ORACLE-OK'),
        evtxoKeyPkg: evtxo.keyPackage,
        evtxoPkp: evtxo.publicKeyPackage);
    final spendArkTxid = await wallet.submit(allowSigned);
    expect(spendArkTxid, isNotEmpty,
        reason: 'arkd must co-sign + finalize the eVTXO cooperative spend');
    print('5c. ALLOW: arkd co-signed eVTXO spend, ark_txid=$spendArkTxid');

    // Bob credited by the eVTXO spend (proves the off-chain transfer landed).
    int bobBalance = 0;
    for (int i = 0; i < 10; i++) {
      bobBalance = (await bob.listVtxos()).totalBalance.toInt();
      if (bobBalance >= 50000) break;
      await Future.delayed(Duration(seconds: 1));
    }
    expect(bobBalance, equals(50000), reason: 'Bob should receive 50000 sats from the eVTXO spend');

    print('eVTXO-through-arkd E2E complete: arkd co-signed the allow; over-limit + bad-arg refused.');
  }, timeout: Timeout(Duration(minutes: 8)));
}

/// x-only (32-byte) public key from a FROST group public key package (V′).
Uint8List _xonlyOf(threshold.PublicKeyPackage pkp) {
  final compressed = threshold.elemSerializeCompressed(pkp.verifyingKey.E);
  return Uint8List.fromList(compressed.sublist(1));
}

Future<void> _expectDenied(Future<void> Function() op, String because) async {
  try {
    await op();
    fail('cosigner should have refused ($because)');
  } catch (e) {
    print('   denied as expected ($because): $e');
    expect(e.toString().toLowerCase(), contains('deni'),
        reason: 'expected a contract permission-denied error, got: $e');
  }
}
