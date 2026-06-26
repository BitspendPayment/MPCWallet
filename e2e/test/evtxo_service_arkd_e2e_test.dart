import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/ark/ark_send.dart';
import 'package:app_core/ark_wallet.dart';
import 'package:app_core/client.dart';
import 'package:app_core/rest_wallet_api.dart';
import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Tier 2, THROUGH ARKD: the always-online `{service, cosigner}` pairing spends a contract eVTXO
/// off-chain via arkd, with the WALLET OFFLINE. arkd validates + co-signs the server leg; the V
/// leg comes from the service (no wallet share). The two V-legs (checkpoint + ark_tx) are each
/// conditioned by the cosigner so the service can sign only a contract-approved spend of its own
/// eVTXO. Mirrors `evtxo_arkd_e2e_test` but routes the V-leg signing to the service.
const oracleGateWasmPath =
    '../contracts/examples/oracle-gate/target/wasm32-wasip2/release/oracle_gate.wasm';

class ArkdAdmin {
  final String adminUrl;
  final String publicUrl;
  ArkdAdmin({this.adminUrl = 'http://127.0.0.1:7071', this.publicUrl = 'http://127.0.0.1:7070'});
  Future<Map<String, dynamic>> getInfo() async {
    final resp = await http.get(Uri.parse('$publicUrl/v1/info'));
    if (resp.statusCode != 200) throw Exception('arkd info: ${resp.body}');
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
    return jsonDecode(resp.body)['address'] as String;
  }
}

Future<Process> startCosignerRuntime(int port, Directory dataDir,
    {Map<String, String> extraEnv = const {}}) async {
  final ready = Completer<void>();
  final failed = Completer<void>();
  final env = {
    'ASP_URL': 'http://127.0.0.1:7070',
    'BITCOIN_NETWORK': 'regtest',
    'AUTO_SETTLE_SAFETY_MARGIN_SECS': '3600',
    'HOME': dataDir.path,
    ...extraEnv,
  };
  final proc = await Process.start(
    '../cosigner-runtime/target/release/cosigner-runtime',
    ['--port', port.toString()],
    environment: env,
  );
  void watch(Stream<List<int>> s) {
    s.transform(utf8.decoder).listen((d) {
      print('[Server]: $d');
      if (!ready.isCompleted && d.contains('MPC Wallet Server listening on')) ready.complete();
    }, onDone: () {
      if (!ready.isCompleted && !failed.isCompleted) failed.complete();
    });
  }

  watch(proc.stdout);
  watch(proc.stderr);
  try {
    await Future.any([
      ready.future,
      failed.future.then((_) => throw Exception('MPC Server failed')),
    ]).timeout(Duration(seconds: 30), onTimeout: () => throw Exception('MPC Server not ready'));
  } catch (e) {
    proc.kill();
    rethrow;
  }
  return proc;
}

Future<(Process, Uint8List)> startContractService(int port) async {
  final ready = Completer<void>();
  final proc = await Process.start(
    '../e2e/contract-service/target/release/contract-service',
    ['--port', port.toString()],
  );
  proc.stdout.transform(utf8.decoder).listen((d) {
    print('[Service]: $d');
    if (!ready.isCompleted && d.contains('listening on')) ready.complete();
  });
  proc.stderr.transform(utf8.decoder).listen((d) => print('[Service]: $d'));
  await ready.future.timeout(Duration(seconds: 30),
      onTimeout: () => throw Exception('contract-service not ready'));
  final info = await http.get(Uri.parse('http://127.0.0.1:$port/info'));
  final vkHex = jsonDecode(info.body)['service_vk'] as String;
  return (proc, Uint8List.fromList(BytesUtils.fromHexString(vkHex)));
}

void main() {
  late RegtestHelper btc;
  late ArkdAdmin arkd;
  late Directory tempDir;
  late Directory serverTempDir;
  Process? serverProcess;
  Process? serviceProcess;
  late int serverPort;
  late int servicePort;
  late Uint8List serviceVk;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mpc_svc_arkd_');
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

    final svcSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    servicePort = svcSocket.port;
    await svcSocket.close();
    (serviceProcess, serviceVk) = await startContractService(servicePort);

    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_svc_arkd_server_');
    serverProcess = await startCosignerRuntime(serverPort, serverTempDir,
        extraEnv: {'SERVICE_URL': 'http://127.0.0.1:$servicePort'});
    print('--- Setup complete (server $serverPort, service $servicePort) ---');
  });

  tearDownAll(() async {
    serverProcess?.kill();
    serviceProcess?.kill();
    try {
      await serverTempDir.delete(recursive: true);
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> settleWithMining(MpcClient client) async {
    bool settling = true;
    final timer = Timer.periodic(Duration(seconds: 3), (t) async {
      if (!settling) {
        t.cancel();
        return;
      }
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
    });
    try {
      await client.settle();
    } finally {
      settling = false;
      timer.cancel();
    }
  }

  test('service + cosigner spend a contract eVTXO THROUGH arkd, wallet offline', () async {
    // 1. Alice (spender) + Bob (recipient) DKG.
    final alice = MpcClient.rest('http://127.0.0.1:$serverPort', storageId: 'alice');
    await alice.doDkg();
    final bob = MpcClient.rest('http://127.0.0.1:$serverPort', storageId: 'bob');
    await bob.doDkg();
    final bobArk = await bob.getArkAddress();

    // 2. eVTXO bound to oracle-gate; V refreshed onto {service, cosigner}.
    final arkInfo = await alice.getArkInfo();
    var serverPkHex = arkInfo.signerPubkey;
    if (serverPkHex.length == 66) serverPkHex = serverPkHex.substring(2);
    final serverPk = Uint8List.fromList(BytesUtils.fromHexString(serverPkHex));
    final exitDelay = arkInfo.unilateralExitDelay.toInt();
    final wasmBytes = await File(oracleGateWasmPath).readAsBytes();
    final contractId = Uint8List.fromList(QuickCrypto.sha256Hash(wasmBytes));
    final serviceApi = RestWalletApi('http://127.0.0.1:$servicePort');
    final evtxo = await alice.createEvtxoKey(
        contractId, wasmBytes, serverPk, exitDelay,
        serviceVk: serviceVk, serviceApi: serviceApi);
    final qEvtxo = Uint8List.fromList(evtxo.scriptPubkey.sublist(2));
    final vXonly = _xonlyOf(evtxo.publicKeyPackage);
    final evtxoArkAddr =
        arkEvtxoArkAddress(serverPk: serverPk, qEvtxo: qEvtxo, network: arkInfo.network);
    print('2. eVTXO created; ark address=$evtxoArkAddr');

    // 3. Board + settle Alice, then mint a 90k eVTXO (≤ the 100k oracle-gate limit).
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.01);
    await btc.generateToAddress(1, minerAddr);
    await Future.delayed(Duration(seconds: 5));
    await settleWithMining(alice);

    final wallet = MpcArkWallet(alice);
    final u = await wallet.createTransaction(destination: evtxoArkAddr, amountSats: 90000);
    final mintTxid = await wallet.submit(await wallet.signTransaction(u));
    await Future.delayed(Duration(seconds: 2));
    print('3. Minted eVTXO $mintTxid:0 (90k)');

    // 4. Build the (gate-approved) spend to Bob — the unsigned tx is public (no secret).
    final unsigned = await wallet.createEvtxoSpend(
      destination: bobArk,
      amountSats: 50000,
      inputTxid: mintTxid,
      inputVout: 0,
      inputAmountSats: 90000,
      contractId: contractId,
      evtxoPk: vXonly,
      exitDelay: exitDelay,
      contractArgs: Uint8List.fromList(utf8.encode('ORACLE-OK')),
    );

    // 5. Route EACH V-leg (checkpoint + ark_tx) to the SERVICE — no wallet share. The cosigner
    //    verifies each sighash is a leg of THIS eVTXO's arkd spend before co-signing.
    final sigHexes = <String>[];
    for (final sighash in unsigned.sighashes) {
      final resp = await http.post(
        Uri.parse('http://127.0.0.1:$servicePort/service-sign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'evtxo_script_pubkey': BytesUtils.toHexString(evtxo.scriptPubkey),
          'full_transaction': BytesUtils.toHexString(unsigned.gateTxBytes),
          'message': BytesUtils.toHexString(sighash),
          'ark_tx': BytesUtils.toHexString(unsigned.arkTxBytes),
          'cosigner_base_url': 'http://127.0.0.1:$serverPort',
        }),
      );
      final r = jsonDecode(resp.body) as Map<String, dynamic>;
      expect(r['ok'], isTrue, reason: 'service co-sign failed: ${r['error']}');
      final R = threshold.elemDeserializeCompressed(
          Uint8List.fromList(BytesUtils.fromHexString(r['r_point'] as String)));
      final z = threshold.bytesToBigInt(
          Uint8List.fromList(BytesUtils.fromHexString(r['z_scalar'] as String)));
      sigHexes.add(BytesUtils.toHexString(_schnorr64(threshold.Signature(R, z))));
    }
    print('4-5. Service co-signed ${sigHexes.length} V-leg(s), wallet offline.');

    // 6. Assemble + submit THROUGH arkd (arkd validates + co-signs the server leg).
    final assembled = ArkSendSession.insertSignatures(unsigned.sessionHandle, sigHexes);
    final spendTxid = await wallet.submit(SignedArkTransaction(
      signedArkTxB64: assembled.signedArkTxB64,
      signedCheckpointTxsB64: assembled.signedCheckpointTxsB64,
      spentOutpoints: unsigned.spentOutpoints,
    ));
    expect(spendTxid, isNotEmpty, reason: 'arkd must co-sign + finalize the eVTXO spend');
    print('6. Spent through arkd: ark_txid=$spendTxid');

    // 7. Bob credited — a real off-chain transfer, no wallet key involved.
    int bobBalance = 0;
    for (int i = 0; i < 12; i++) {
      bobBalance = (await bob.listVtxos()).totalBalance.toInt();
      if (bobBalance >= 50000) break;
      await Future.delayed(Duration(seconds: 1));
    }
    expect(bobBalance, equals(50000), reason: 'Bob must receive 50000 from the service-driven spend');
    print('Service-through-arkd E2E complete: Bob credited 50000, wallet offline.');
  }, timeout: Timeout(Duration(minutes: 12)));
}

Uint8List _xonlyOf(threshold.PublicKeyPackage pkp) =>
    Uint8List.fromList(threshold.elemSerializeCompressed(pkp.verifyingKey.E).sublist(1));

Uint8List _schnorr64(threshold.Signature sig) {
  final out = Uint8List(64);
  out.setRange(0, 32, threshold.elemSerializeCompressed(sig.R).sublist(1));
  out.setRange(32, 64, threshold.bigIntToBytes(sig.Z));
  return out;
}
