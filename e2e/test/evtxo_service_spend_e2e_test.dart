import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/ark/ark_evtxo_spend.dart';
import 'package:app_core/client.dart';
import 'package:app_core/rest_wallet_api.dart';
import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Tier 2, end-to-end: a contract eVTXO is SPENT ON-CHAIN with the WALLET OFFLINE.
///
/// The cooperative leaf needs two legs: the `V` 2-of-2 + the ASP `server_pk`. Here the `V` leg is
/// produced by the always-online `{service, cosigner}` pairing (NO wallet share), and the server
/// leg by a self-generated ASP signer key (no arkd needed — we drive the on-chain cooperative
/// spend directly). The spend is gate-approved, broadcast on regtest, and confirmed.
///
/// Needs bitcoind regtest + cosigner-runtime + contract-service + ffi + the oracle-gate wasm.
const oracleGateWasmPath =
    '../contracts/examples/oracle-gate/target/wasm32-wasip2/release/oracle_gate.wasm';

Future<Process> startCosignerRuntime(int port, Directory dataDir,
    {Map<String, String> extraEnv = const {}}) async {
  final ready = Completer<void>();
  final failed = Completer<void>();
  final env = {'BITCOIN_NETWORK': 'regtest', 'HOME': dataDir.path, ...extraEnv};
  final proc = await Process.start(
    '../cosigner-runtime/target/release/cosigner-runtime',
    ['--wasm', '../cosigner/target/wasm32-wasip2/release/cosigner.wasm', '--port', port.toString()],
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
  final failed = Completer<void>();
  final proc = await Process.start(
    '../e2e/contract-service/target/release/contract-service',
    ['--port', port.toString()],
  );
  void watch(Stream<List<int>> s) {
    s.transform(utf8.decoder).listen((d) {
      print('[Service]: $d');
      if (!ready.isCompleted && d.contains('listening on')) ready.complete();
    }, onDone: () {
      if (!ready.isCompleted && !failed.isCompleted) failed.complete();
    });
  }

  watch(proc.stdout);
  watch(proc.stderr);
  await Future.any([
    ready.future,
    failed.future.then((_) => throw Exception('contract-service failed')),
  ]).timeout(Duration(seconds: 30), onTimeout: () => throw Exception('contract-service not ready'));
  final info = await http.get(Uri.parse('http://127.0.0.1:$port/info'));
  final vkHex = jsonDecode(info.body)['service_vk'] as String;
  return (proc, Uint8List.fromList(BytesUtils.fromHexString(vkHex)));
}

void main() {
  late RegtestHelper btc;
  late Directory tempDir;
  late Directory serverTempDir;
  Process? serverProcess;
  Process? serviceProcess;
  late int serverPort;
  late int servicePort;
  late Uint8List serviceVk;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mpc_svc_spend_');
    Hive.init(tempDir.path);

    btc = RegtestHelper();
    try {
      await btc.createWallet('default');
    } catch (e) {
      if (!e.toString().contains('already loaded')) rethrow;
    }
    btc = RegtestHelper(rpcUrl: 'http://127.0.0.1:18443/wallet/default');
    final miner = await btc.getNewAddress();
    await btc.generateToAddress(101, miner);

    final svcSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    servicePort = svcSocket.port;
    await svcSocket.close();
    (serviceProcess, serviceVk) = await startContractService(servicePort);

    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_svc_spend_server_');
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

  test('service + cosigner spend an eVTXO ON-CHAIN, wallet offline (gate-approved, confirmed)',
      () async {
    // 1. Alice DKG (V).
    final alice = MpcClient.rest('http://127.0.0.1:$serverPort', storageId: 'alice');
    await alice.doDkg();

    // 2. Self-generated ASP signer key (server leg of the cooperative multisig).
    final serverSk = Uint8List(32)..[31] = 0x07; // scalar = 7
    final serverPk = Uint8List.fromList(
        BytesUtils.fromHexString(threshold.elemBaseMul(threshold.bytesToBigInt(serverSk)))
            .sublist(1)); // x-only
    const exitDelay = 86016;

    // 3. Create the eVTXO bound to oracle-gate, refreshing V onto {service, cosigner}.
    final wasmBytes = await File(oracleGateWasmPath).readAsBytes();
    final contractId = Uint8List.fromList(QuickCrypto.sha256Hash(wasmBytes));
    final serviceApi = RestWalletApi('http://127.0.0.1:$servicePort');
    final evtxo = await alice.createEvtxoKey(
        contractId, wasmBytes, serverPk, exitDelay,
        serviceVk: serviceVk, serviceApi: serviceApi);
    final vXonly = _xonlyOf(evtxo.publicKeyPackage);
    final fundingAddr = _bcrtP2trFromSpk(evtxo.scriptPubkey);
    print('1-3. eVTXO created; funding address=$fundingAddr');

    // 4. Fund the eVTXO on-chain.
    final miner = await btc.getNewAddress();
    await btc.sendToAddress(fundingAddr, 0.001); // 100k sats
    await btc.generateToAddress(1, miner);
    await Future.delayed(Duration(seconds: 2));
    final utxos = await btc.scanUtxos(fundingAddr);
    expect(utxos, isNotEmpty, reason: 'eVTXO funding UTXO not found');
    final u = utxos.first;
    final inputTxid = u['txid'] as String;
    final inputVout = u['vout'] as int;
    final inputSats = ((u['amount'] as num) * 100000000).round();
    print('4. Funded eVTXO: $inputTxid:$inputVout ($inputSats sats)');

    // 5. Build the (gate-approved) cooperative spend to a fresh address.
    final destSpk = _spkFromBcrtAddress(await btc.getNewAddress());
    final spend = ArkEvtxoSpendSession.build(
      contractId: contractId,
      serverPk: serverPk,
      evtxoPk: vXonly,
      ownerPk: vXonly,
      exitDelay: exitDelay,
      inputTxid: inputTxid,
      inputVout: inputVout,
      inputAmountSats: inputSats,
      outputScriptPubkey: destSpk,
      outputAmountSats: 90000, // ≤ 100k limit
      contractArgs: Uint8List.fromList(utf8.encode('ORACLE-OK')),
    );
    expect(spend.evtxoScriptPubkey, equals(evtxo.scriptPubkey));

    // 6. The SERVICE co-signs the V leg (no wallet share).
    final resp = await http.post(
      Uri.parse('http://127.0.0.1:$servicePort/service-sign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'evtxo_script_pubkey': BytesUtils.toHexString(evtxo.scriptPubkey),
        'full_transaction': BytesUtils.toHexString(spend.psbt),
        'cosigner_base_url': 'http://127.0.0.1:$serverPort',
      }),
    );
    final r = jsonDecode(resp.body) as Map<String, dynamic>;
    expect(r['ok'], isTrue, reason: 'service co-sign failed: ${r['error']}');
    final R = threshold.elemDeserializeCompressed(
        Uint8List.fromList(BytesUtils.fromHexString(r['r_point'] as String)));
    final z = threshold.bytesToBigInt(
        Uint8List.fromList(BytesUtils.fromHexString(r['z_scalar'] as String)));
    final vSig = _schnorr64(threshold.Signature(R, z));
    print('6. Service co-signed the V leg (wallet offline).');

    // 7. Assemble the cooperative witness (V leg + server leg) and broadcast on-chain.
    final rawTx = ArkEvtxoSpendSession.finalize(
      handle: spend.handle,
      vPrimeSig: vSig,
      signerSk: serverSk,
    );
    final spendTxid = await btc.sendRawTransaction(rawTx, maxFeeRate: 0);
    await btc.generateToAddress(1, miner);
    await Future.delayed(Duration(seconds: 2));
    print('7. Broadcast on-chain: txid=$spendTxid');

    // 8. Confirmed + the eVTXO is spent — a real spend with NO wallet key.
    final info = await btc.getRawTransaction(spendTxid);
    expect((info['confirmations'] as num?) ?? 0, greaterThanOrEqualTo(1),
        reason: 'service-driven cooperative spend should confirm on-chain');
    final prevout = await btc.getTxOut(inputTxid, inputVout);
    expect(prevout, isNull, reason: 'the eVTXO must now be spent');
    ArkEvtxoSpendSession.free(spend.handle);
    print('Service-driven ON-CHAIN spend E2E complete: eVTXO spent + confirmed, wallet offline.');
  }, timeout: Timeout(Duration(minutes: 3)));
}

Uint8List _schnorr64(threshold.Signature sig) {
  final rBytes = threshold.elemSerializeCompressed(sig.R);
  final out = Uint8List(64);
  out.setRange(0, 32, rBytes.sublist(1));
  out.setRange(32, 64, threshold.bigIntToBytes(sig.Z));
  return out;
}

Uint8List _xonlyOf(threshold.PublicKeyPackage pkp) =>
    Uint8List.fromList(threshold.elemSerializeCompressed(pkp.verifyingKey.E).sublist(1));

String _bcrtP2trFromSpk(Uint8List spk) =>
    SegwitBech32Encoder.encode('bcrt', 1, spk.sublist(2).toList());

Uint8List _spkFromBcrtAddress(String addr) {
  final decoded = SegwitBech32Decoder.decode('bcrt', addr);
  final version = decoded.item1;
  final program = decoded.item2;
  final opcode = version == 0 ? 0x00 : (0x50 + version);
  return Uint8List.fromList([opcode, program.length, ...program]);
}
