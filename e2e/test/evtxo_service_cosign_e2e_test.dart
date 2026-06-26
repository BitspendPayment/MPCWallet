import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/ark/ark_evtxo_spend.dart';
import 'package:app_core/client.dart';
import 'package:app_core/rest_wallet_api.dart';
import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Tier 2 — SERVICE-DRIVEN contract co-sign with the WALLET OFFLINE.
///
/// After `createEvtxoKey` refreshes `V` onto the `{service, cosigner}` pairing, the always-online
/// service drives the cosigner's normal SignStep1/SignStep2 (as the "user") against the pairing
/// actor and produces a valid `V` signature over a contract-approved eVTXO spend — no wallet share.
///
/// Crucially it also proves the CONDITIONING: the pairing co-sign is bound to spending its own
/// eVTXO. The cosigner rebuilds + signs only that eVTXO's cooperative-leaf sighash, so the service
/// is refused when it presents a spend that doesn't touch its eVTXO — closing the door on using a
/// `V` share of a contract to forge a spend of the wallet's normal funds.
///
/// Needs only: cosigner-runtime + contract-service + ffi + the oracle-gate wasm (no arkd/bitcoind).
const oracleGateWasmPath =
    '../contracts/examples/oracle-gate/target/wasm32-wasip2/release/oracle_gate.wasm';

Future<Process> startCosignerRuntime(int port, Directory dataDir,
    {Map<String, String> extraEnv = const {}}) async {
  final ready = Completer<void>();
  final failed = Completer<void>();
  final env = {
    'BITCOIN_NETWORK': 'regtest',
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
      if (!ready.isCompleted && data.contains('MPC Wallet Server listening on')) ready.complete();
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
    s.transform(utf8.decoder).listen((data) {
      print('[Service]: $data');
      if (!ready.isCompleted && data.contains('listening on')) ready.complete();
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

Uint8List _xonlyOf(threshold.PublicKeyPackage pkp) =>
    Uint8List.fromList(threshold.elemSerializeCompressed(pkp.verifyingKey.E).sublist(1));

void main() {
  late Directory tempDir;
  late Directory serverTempDir;
  Process? serverProcess;
  Process? serviceProcess;
  late int serverPort;
  late int servicePort;
  late Uint8List serviceVk;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mpc_svc_cosign_');
    Hive.init(tempDir.path);

    final svcSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    servicePort = svcSocket.port;
    await svcSocket.close();
    (serviceProcess, serviceVk) = await startContractService(servicePort);

    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_svc_cosign_server_');
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

  test('service co-signs an eVTXO spend under V with NO wallet; refuses non-associated spends',
      () async {
    // 1. Alice DKG (V) + create a contract eVTXO bound to oracle-gate, refreshing V onto the
    //    {service, cosigner} pairing (the service receives + assembles its share).
    final alice = MpcClient.rest('http://127.0.0.1:$serverPort', storageId: 'alice');
    await alice.doDkg();
    final serverPk = Uint8List(32)..fillRange(0, 32, 0x02); // dummy ASP x-only (no broadcast)
    const exitDelay = 86016;
    final wasmBytes = await File(oracleGateWasmPath).readAsBytes();
    final contractId = Uint8List.fromList(QuickCrypto.sha256Hash(wasmBytes));
    final serviceApi = RestWalletApi('http://127.0.0.1:$servicePort');
    final evtxo = await alice.createEvtxoKey(
        contractId, wasmBytes, serverPk, exitDelay,
        serviceVk: serviceVk, serviceApi: serviceApi);
    final vXonly = _xonlyOf(evtxo.publicKeyPackage); // V = the cooperative-leaf key
    print('1. eVTXO created; spk=${BytesUtils.toHexString(evtxo.scriptPubkey)}');

    final cosignerBase = 'http://127.0.0.1:$serverPort';
    final dummyTxid = '00' * 32;
    final outSpk = Uint8List.fromList([0x51, 0x20, ...List.filled(32, 0x03)]);

    Future<Map<String, dynamic>> serviceSign(Uint8List spk, Uint8List psbt) async {
      final resp = await http.post(
        Uri.parse('http://127.0.0.1:$servicePort/service-sign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'evtxo_script_pubkey': BytesUtils.toHexString(spk),
          'full_transaction': BytesUtils.toHexString(psbt),
          'cosigner_base_url': cosignerBase,
        }),
      );
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    // 2. Build an unsigned spend of THIS eVTXO (within the 100k limit + good oracle token).
    final spend = ArkEvtxoSpendSession.build(
      contractId: contractId,
      serverPk: serverPk,
      evtxoPk: vXonly,
      ownerPk: vXonly, // exit-leaf owner defaulted to V x-only at create
      exitDelay: exitDelay,
      inputTxid: dummyTxid,
      inputVout: 0,
      inputAmountSats: 90000,
      outputScriptPubkey: outSpk,
      outputAmountSats: 50000,
      contractArgs: Uint8List.fromList(utf8.encode('ORACLE-OK')),
    );
    expect(BytesUtils.toHexString(spend.evtxoScriptPubkey),
        equals(BytesUtils.toHexString(evtxo.scriptPubkey)),
        reason: 'rebuilt eVTXO spk must match the registered one');

    // 3. SERVICE co-signs — no wallet share involved.
    final ok = await serviceSign(evtxo.scriptPubkey, spend.psbt);
    expect(ok['ok'], isTrue, reason: 'service+cosigner must co-sign: ${ok['error']}');
    // The cosigner is authoritative about the message: it must equal the spend's coop sighash.
    expect(ok['sighash'], equals(BytesUtils.toHexString(spend.sighash)),
        reason: 'cosigner must sign the cooperative-leaf sighash of THIS eVTXO spend');
    // The (R, z) signature must verify under V (BIP-340) for that sighash. `verify` returns the
    // (even-Y) Signature on success and THROWS on an invalid signature, so reaching past it = valid.
    final R = threshold.elemDeserializeCompressed(
        Uint8List.fromList(BytesUtils.fromHexString(ok['r_point'] as String)));
    final z = threshold.bytesToBigInt(
        Uint8List.fromList(BytesUtils.fromHexString(ok['z_scalar'] as String)));
    threshold.Signature(R, z).verify(evtxo.publicKeyPackage.verifyingKey, spend.sighash);
    print('3. ALLOW: service co-signed under V, signature verifies. No wallet.');

    // 4. CONDITIONING: a spend that does NOT touch this eVTXO (different key ⇒ different input spk)
    //    must be REFUSED — the service can't get a V signature on anything but its own eVTXO.
    final foreign = ArkEvtxoSpendSession.build(
      contractId: contractId,
      serverPk: serverPk,
      evtxoPk: serverPk, // different cooperative key ⇒ different (foreign) eVTXO spk
      ownerPk: vXonly,
      exitDelay: exitDelay,
      inputTxid: dummyTxid,
      inputVout: 0,
      inputAmountSats: 90000,
      outputScriptPubkey: outSpk,
      outputAmountSats: 50000,
      contractArgs: Uint8List.fromList(utf8.encode('ORACLE-OK')),
    );
    expect(BytesUtils.toHexString(foreign.evtxoScriptPubkey),
        isNot(equals(BytesUtils.toHexString(evtxo.scriptPubkey))));
    final denied = await serviceSign(evtxo.scriptPubkey, foreign.psbt);
    expect(denied['ok'], isFalse,
        reason: 'pairing must refuse to co-sign a spend of a different output');
    print('4. DENY non-associated: ${denied['error']}');

    // 5. The contract GATE still applies to associated spends: over the 100k limit ⇒ refused.
    final overLimit = ArkEvtxoSpendSession.build(
      contractId: contractId,
      serverPk: serverPk,
      evtxoPk: vXonly,
      ownerPk: vXonly,
      exitDelay: exitDelay,
      inputTxid: dummyTxid,
      inputVout: 0,
      inputAmountSats: 300000,
      outputScriptPubkey: outSpk,
      outputAmountSats: 300000,
      contractArgs: Uint8List.fromList(utf8.encode('ORACLE-OK')),
    );
    final gated = await serviceSign(evtxo.scriptPubkey, overLimit.psbt);
    expect(gated['ok'], isFalse, reason: 'gate must deny an over-limit spend');
    print('5. DENY over-limit (gate): ${gated['error']}');

    print('Service-driven co-sign E2E complete: allow + verify under V, deny non-associated, deny over-limit.');
  }, timeout: Timeout(Duration(minutes: 3)));
}
