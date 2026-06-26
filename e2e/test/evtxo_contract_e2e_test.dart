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

/// End-to-end test for the off-chain WASM contract gate, on a live regtest chain.
///
/// Flow: derive an eVTXO key bound to the `oracle-gate` contract by resharing
/// (`createEvtxoKey`) — the contract wasm is handed to the cosigner at creation,
/// which validates `sha256(wasm)==contract_id` and stores it (no registry) → fund
/// the eVTXO on-chain → spend its cooperative leaf, where the cosigner runs the
/// committed contract and only co-signs (releasing its V′ share) on `allow`:
///   * allow  (within-limit output + good contract args) → tx broadcasts + confirms
///   * deny   (over-limit output)                        → cosigner refuses to sign
///   * deny   (bad contract args)                        → cosigner refuses to sign
///
/// Prereqs (mirrors `make e2e-ark`):
///   make arkd-up && make bitcoin-init && make arkd-init   # bitcoind + arkd
///   the hardware signer-server on 127.0.0.1:9090
///   the cosigner.wasm + cosigner-runtime + ffi + contracts built

/// arkd signer key from docker-compose.ark.yml (ARKD_WALLET_SIGNER_KEY). Its
/// x-only pubkey equals the ASP `signer_pubkey`, so it signs the server leg of
/// the eVTXO cooperative spend.
const arkdSignerKeyHex =
    'afcd3fa10f82a05fddc9574fdb13b3991b568e89cc39a72ba4401df8abef35f0';

const oracleGateWasmPath =
    '../contracts/examples/oracle-gate/target/wasm32-wasip2/release/oracle_gate.wasm';

/// Minimal arkd admin REST client (init/fund the ASP wallet during setup).
class ArkdAdmin {
  final String adminUrl;
  final String publicUrl;

  ArkdAdmin({
    this.adminUrl = 'http://127.0.0.1:7071',
    this.publicUrl = 'http://127.0.0.1:7070',
  });

  Future<Map<String, dynamic>> getInfo() async {
    final resp = await http.get(Uri.parse('$publicUrl/v1/info'));
    if (resp.statusCode != 200) {
      throw Exception('arkd info failed: ${resp.body}');
    }
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
    if (seedResp.statusCode != 200) {
      throw Exception('seed failed: ${seedResp.body}');
    }
    final seed = jsonDecode(seedResp.body)['seed'] as String;
    await http.post(
      Uri.parse('$adminUrl/v1/admin/wallet/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'seed': seed, 'password': 'password'}),
    );
    await Future.delayed(Duration(seconds: 1));
    await http.post(
      Uri.parse('$adminUrl/v1/admin/wallet/unlock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': 'password'}),
    );
    await Future.delayed(Duration(seconds: 1));
  }

  Future<String> getWalletAddress() async {
    final resp = await http.get(Uri.parse('$adminUrl/v1/admin/wallet/address'));
    if (resp.statusCode != 200) {
      throw Exception('wallet address failed: ${resp.body}');
    }
    return jsonDecode(resp.body)['address'] as String;
  }
}

/// Spawn the cosigner-runtime against the regtest fixtures. The contract gate
/// resolves contracts from the cosigner's own storage (populated at eVTXO
/// creation), so no registry env is needed.
Future<Process> startCosignerRuntime(int port, Directory dataDir,
    {Map<String, String> extraEnv = const {}}) async {
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
    [
      '--port',
      port.toString(),
    ],
    environment: env,
  );
  void watch(Stream<List<int>> s) {
    s.transform(utf8.decoder).listen((data) {
      print('[Server]: $data');
      if (!serverReady.isCompleted &&
          data.contains('MPC Wallet Server listening on')) {
        serverReady.complete();
      }
    }, onDone: () {
      if (!serverReady.isCompleted && !serverFailed.isCompleted) {
        serverFailed.complete();
      }
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

/// Start the dummy always-online contract-signer service and return (process, vk).
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
  try {
    await Future.any([
      ready.future,
      failed.future.then((_) => throw Exception('contract-service failed')),
    ]).timeout(Duration(seconds: 30),
        onTimeout: () => throw Exception('contract-service not ready in time'));
  } catch (e) {
    proc.kill();
    rethrow;
  }
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
    print('--- eVTXO Contract E2E Setup ---');
    tempDir = await Directory.systemTemp.createTemp('mpc_evtxo_e2e_');
    Hive.init(tempDir.path);

    // 1. bitcoind
    btc = RegtestHelper();
    try {
      await btc.createWallet('default');
    } catch (e) {
      if (!e.toString().contains('already loaded')) rethrow;
    }
    btc = RegtestHelper(rpcUrl: 'http://127.0.0.1:18443/wallet/default');
    await btc.getNewAddress();
    print('  Bitcoind: OK');

    // 2. arkd
    arkd = ArkdAdmin();
    bool arkdReady = false;
    for (int i = 0; i < 10; i++) {
      if (await arkd.isReady()) {
        arkdReady = true;
        break;
      }
      await Future.delayed(Duration(seconds: 3));
    }
    if (!arkdReady) {
      await arkd.initWallet();
      await Future.delayed(Duration(seconds: 2));
    }
    // Fund the ASP wallet so it can serve VTXOs.
    try {
      final aspAddr = await arkd.getWalletAddress();
      final minerAddr = await btc.getNewAddress();
      await btc.generateToAddress(101, minerAddr);
      await btc.sendToAddress(aspAddr, 10.0);
      await btc.generateToAddress(1, minerAddr);
      await Future.delayed(Duration(seconds: 5));
      print('  arkd: funded');
    } catch (e) {
      print('  Warning: could not fund ASP: $e');
    }

    // 4. contract-signer service (the cosigner needs SERVICE_URL at boot).
    final svcSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    servicePort = svcSocket.port;
    await svcSocket.close();
    (serviceProcess, serviceVk) = await startContractService(servicePort);

    // 5. cosigner-runtime (contract gate enabled)
    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_evtxo_server_');
    serverProcess = await startCosignerRuntime(serverPort, serverTempDir,
        extraEnv: {'SERVICE_URL': 'http://127.0.0.1:$servicePort'});
    print('--- Setup Complete (port $serverPort, service $servicePort) ---');
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

  test('eVTXO contract gate: fund, deny over-limit, deny bad-arg, allow + confirm',
      () async {
    // Real 2-of-2 {wallet, cosigner}: no signer.
    final client = MpcClient.rest('http://127.0.0.1:$serverPort');

    // 1. DKG → main key V (2-of-2).
    await client.doDkg();
    print('1. DKG complete: userId=${client.userId?.substring(0, 16)}...');

    // 2. ASP info: server_pk (x-only) + exit delay.
    final arkInfo = await client.getArkInfo();
    var serverPkHex = arkInfo.signerPubkey;
    if (serverPkHex.length == 66) serverPkHex = serverPkHex.substring(2);
    final serverPk = Uint8List.fromList(BytesUtils.fromHexString(serverPkHex));
    final exitDelay = arkInfo.unilateralExitDelay.toInt();
    final ownerPk =
        Uint8List.fromList(BytesUtils.fromHexString(client.groupXOnlyPubKey!));
    print('2. ArkInfo: serverPk=${serverPkHex.substring(0, 16)}..., '
        'exitDelay=$exitDelay');

    // 3. The contract bytes are the source of truth: contract_id = sha256(wasm).
    //    No registry to publish to — the wasm is handed to the cosigner at creation.
    final wasmBytes = await File(oracleGateWasmPath).readAsBytes();
    final contractId = Uint8List.fromList(QuickCrypto.sha256Hash(wasmBytes));
    print('3. contract_id=${BytesUtils.toHexString(contractId).substring(0, 16)}...');

    // 4. Create the contract eVTXO (single ContractCreate; coop leaf = V). The
    //    cosigner validates sha256(wasm)==contract_id, refreshes V onto the
    //    {service, cosigner} pairing (cosigner → b@service via SERVICE_URL, wallet →
    //    a@service via serviceApi), and registers the spk.
    final serviceApi = RestWalletApi('http://127.0.0.1:$servicePort');
    final evtxo = await client.createEvtxoKey(
        contractId, wasmBytes, serverPk, exitDelay,
        serviceVk: serviceVk, serviceApi: serviceApi);
    final vPrimeXonly = _xonlyOf(evtxo.publicKeyPackage);
    final fundingAddr = _bcrtP2trFromSpk(evtxo.scriptPubkey);
    print('4. eVTXO key created; funding address=$fundingAddr');

    // 5. Fund the eVTXO on-chain (300k sats; above the 100k contract limit so the
    //    over-limit case has a real input to build against).
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(fundingAddr, 0.003);
    await btc.generateToAddress(1, minerAddr);
    await Future.delayed(Duration(seconds: 3));
    final utxos = await btc.scanUtxos(fundingAddr);
    expect(utxos, isNotEmpty, reason: 'eVTXO funding UTXO not found');
    final u = utxos.first;
    final inputTxid = u['txid'] as String;
    final inputVout = u['vout'] as int;
    final inputSats = ((u['amount'] as num) * 100000000).round();
    print('5. Funded eVTXO: $inputTxid:$inputVout ($inputSats sats)');

    // Destination output for the spend: a fresh regtest p2tr.
    final destSpk = _spkFromBcrtAddress(await btc.getNewAddress());

    ArkEvtxoSpendSession buildSpend(int outSats, String args) {
      return ArkEvtxoSpendSession.build(
        contractId: contractId,
        serverPk: serverPk,
        evtxoPk: vPrimeXonly,
        ownerPk: ownerPk,
        exitDelay: exitDelay,
        inputTxid: inputTxid,
        inputVout: inputVout,
        inputAmountSats: inputSats,
        outputScriptPubkey: destSpk,
        outputAmountSats: outSats,
        contractArgs: Uint8List.fromList(utf8.encode(args)),
      );
    }

    Future<void> expectDenied(
        ArkEvtxoSpendSession s, String because) async {
      try {
        await client.signWithContext(
            s.sighash, evtxo.keyPackage, evtxo.publicKeyPackage, s.psbt,
            applyTweak: false);
        fail('cosigner should have refused ($because)');
      } catch (e) {
        // The gate returns permission_denied; the runtime surfaces the reason.
        print('   denied as expected ($because): $e');
        expect(e.toString().toLowerCase(), contains('deni'),
            reason: 'expected a contract permission-denied error, got: $e');
      } finally {
        ArkEvtxoSpendSession.free(s.handle);
      }
    }

    // 6. DENY — over the 100k limit (good arg, 150k output).
    print('6. Deny over-limit');
    await expectDenied(buildSpend(150000, 'ORACLE-OK'), 'over-limit');

    // 7. DENY — bad contract args (within limit, wrong token).
    print('7. Deny bad-arg');
    await expectDenied(buildSpend(90000, 'WRONG-TOKEN'), 'bad-arg');

    // 8. ALLOW — within limit + good arg: cosigner co-signs; broadcast + confirm.
    print('8. Allow + broadcast');
    final allow = buildSpend(90000, 'ORACLE-OK');
    expect(allow.evtxoScriptPubkey, equals(evtxo.scriptPubkey),
        reason: 'FFI-derived eVTXO spk must match the reshared key registration');

    final sig = await client.signWithContext(
        allow.sighash, evtxo.keyPackage, evtxo.publicKeyPackage, allow.psbt,
        applyTweak: false);
    final vPrimeSig = _schnorr64(sig);

    final rawTx = ArkEvtxoSpendSession.finalize(
      handle: allow.handle,
      vPrimeSig: vPrimeSig,
      signerSk: Uint8List.fromList(BytesUtils.fromHexString(arkdSignerKeyHex)),
    );
    final spendTxid = await btc.sendRawTransaction(rawTx, maxFeeRate: 0);
    print('   broadcast txid=$spendTxid');
    await btc.generateToAddress(1, minerAddr);
    await Future.delayed(Duration(seconds: 2));

    // Confirmed: the spend tx has a confirmation and the eVTXO is now spent.
    final spendInfo = await btc.getRawTransaction(spendTxid);
    expect((spendInfo['confirmations'] as num?) ?? 0, greaterThanOrEqualTo(1),
        reason: 'cooperative spend should be confirmed on-chain');
    final prevout = await btc.getTxOut(inputTxid, inputVout);
    expect(prevout, isNull, reason: 'eVTXO prevout should be spent');
    ArkEvtxoSpendSession.free(allow.handle);
    print('eVTXO contract E2E complete: allow confirmed, both deny cases refused.');
  }, timeout: Timeout(Duration(minutes: 5)));
}

/// 64-byte BIP-340 signature `R.x(32) || z(32)` from a FROST `Signature(R, z)`.
Uint8List _schnorr64(threshold.Signature sig) {
  final rBytes = threshold.elemSerializeCompressed(sig.R);
  final out = Uint8List(64);
  out.setRange(0, 32, rBytes.sublist(1)); // x-only R (drop 02/03 prefix)
  out.setRange(32, 64, threshold.bigIntToBytes(sig.Z));
  return out;
}

/// x-only (32-byte) public key from a FROST group public key package.
Uint8List _xonlyOf(threshold.PublicKeyPackage pkp) {
  final compressed = threshold.elemSerializeCompressed(pkp.verifyingKey.E);
  return Uint8List.fromList(compressed.sublist(1));
}

/// Regtest bech32m (`bcrt1p...`) address from a 34-byte taproot spk (`OP_1 <32>`).
String _bcrtP2trFromSpk(Uint8List spk) {
  return SegwitBech32Encoder.encode('bcrt', 1, spk.sublist(2).toList());
}

/// Decode a `bcrt1...` address back into its scriptPubKey bytes.
Uint8List _spkFromBcrtAddress(String addr) {
  final decoded = SegwitBech32Decoder.decode('bcrt', addr);
  final version = decoded.item1;
  final program = decoded.item2;
  final opcode = version == 0 ? 0x00 : (0x50 + version); // OP_0 / OP_1..OP_16
  return Uint8List.fromList([opcode, program.length, ...program]);
}
