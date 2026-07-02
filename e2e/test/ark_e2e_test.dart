import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:app_core/ark_wallet.dart';
import 'package:app_core/client.dart';
import 'package:app_core/passkey/seed_source.dart';
import 'package:app_core/passkey/session_token_source.dart';
import 'package:cryptography/cryptography.dart';
import 'package:e2e/boarding_poll.dart';
import 'package:e2e/mock_fcm_server.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

/// 32-byte seed for the cosigner's Ed25519 session-token keypair (env `WEBAUTH_TOKEN_SECRET`).
/// The gated test mints Bearer tokens with the same seed so `SessionAuthority::verify` accepts them.
final List<int> webauthTokenSecret = List<int>.generate(32, (i) => i + 1);
final String webauthTokenSecretHex =
    webauthTokenSecret.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Mint a session token in the cosigner's compact-EdDSA-JWT shape: `b64u(header).b64u(payload).
/// b64u(Ed25519_sig over "header.payload")`. The cosigner verifies the signature over the received
/// bytes (it doesn't re-serialize), so no JSON canonicalization is required — only a matching key.
Future<String> mintSessionToken(String subHex, List<int> seed) async {
  final algo = Ed25519();
  final keyPair = await algo.newKeyPairFromSeed(seed);
  String b64u(List<int> b) => base64Url.encode(b).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = b64u(utf8.encode('{"alg":"EdDSA","typ":"JWT"}'));
  final payload = b64u(utf8.encode(jsonEncode({
    'sub': subHex,
    'exp': now + 900,
    'iat': now,
    'jti': 'e2e-gated',
  })));
  final signingInput = '$header.$payload';
  final sig = await algo.sign(utf8.encode(signingInput), keyPair: keyPair);
  return '$signingInput.${b64u(sig.bytes)}';
}

/// Helper to call the arkd admin REST API.
class ArkdAdmin {
  final String adminUrl;
  final String publicUrl;

  ArkdAdmin({
    this.adminUrl = 'http://127.0.0.1:7071',
    this.publicUrl = 'http://127.0.0.1:7070',
  });

  Future<Map<String, dynamic>> getInfo() async {
    final resp = await http.get(Uri.parse('$publicUrl/v1/info'));
    if (resp.statusCode != 200)
      throw Exception('arkd info failed: ${resp.body}');
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
    // Get seed
    final seedResp =
        await http.get(Uri.parse('$adminUrl/v1/admin/wallet/seed'));
    if (seedResp.statusCode != 200)
      throw Exception('seed failed: ${seedResp.body}');
    final seed = jsonDecode(seedResp.body)['seed'] as String;

    // Create wallet
    await http.post(
      Uri.parse('$adminUrl/v1/admin/wallet/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'seed': seed, 'password': 'password'}),
    );

    await Future.delayed(Duration(seconds: 1));

    // Unlock wallet
    await http.post(
      Uri.parse('$adminUrl/v1/admin/wallet/unlock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': 'password'}),
    );

    await Future.delayed(Duration(seconds: 1));
  }

  Future<String> getWalletAddress() async {
    final resp = await http.get(Uri.parse('$adminUrl/v1/admin/wallet/address'));
    if (resp.statusCode != 200)
      throw Exception('wallet address failed: ${resp.body}');
    return jsonDecode(resp.body)['address'] as String;
  }
}

/// Spawn the cosigner-runtime binary against the shared regtest fixtures.
/// Same `serverTempDir` across calls reuses the same sled `data_dir`, so
/// killing + restarting exercises persistence rehydration paths.
/// `extraEnv` lets the caller layer additional env vars on top (used by
/// setUpAll to point FCM at the local `MockFcmServer`). Returns the spawned
/// Process; throws if it doesn't report "listening on" within 30s or exits
/// before becoming ready.
Future<Process> startCosignerRuntime(
  int port,
  Directory dataDir, {
  Map<String, String> extraEnv = const {},
}) async {
  final serverReady = Completer<void>();
  final serverFailed = Completer<void>();
  final env = {
    'BITCOIN_RPC_USER': 'admin1',
    'BITCOIN_RPC_PASSWORD': '123',
    'ASP_URL': 'http://127.0.0.1:7070',
    // Boarding watcher: poll the local electrs esplora; sweep fast for tests.
    'ESPLORA_URL': 'http://127.0.0.1:30000',
    'BOARDING_WATCH_INTERVAL_SECS': '3',
    // Asserted by the GetServerInfo test — set explicitly so the
    // expectation isn't dependent on the cosigner-runtime default.
    'BITCOIN_NETWORK': 'regtest',
    // Force the auto-settle threshold to be "always crossed" for any
    // realistic VTXO_TREE_EXPIRY. The tick task fires when
    // `now > expires_at - safety_margin`; with 1 hour margin and the
    // docker-compose's 512s expiry that's always true, so the next
    // 60-second tick after the intent is stored will drive the batch.
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
    mode: ProcessStartMode.normal,
    environment: env,
  );
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  proc.stdout.transform(utf8.decoder).listen((data) {
    stdoutBuffer.write(data);
    print('[Server]: $data');
    if (!serverReady.isCompleted &&
        stdoutBuffer.toString().contains('MPC Wallet Server listening on')) {
      serverReady.complete();
    }
  }, onDone: () {
    if (!serverReady.isCompleted && !serverFailed.isCompleted) {
      serverFailed.complete();
    }
  });
  proc.stderr.transform(utf8.decoder).listen((data) {
    stderrBuffer.write(data);
    print('[Server]: $data');
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
        throw Exception('MPC Server failed to start');
      }),
    ]).timeout(Duration(seconds: 30), onTimeout: () {
      throw Exception('MPC Server did not become ready in time');
    });
  } catch (e) {
    proc.kill();
    rethrow;
  }
  return proc;
}

void main() {
  Process? serverProcess;
  late RegtestHelper btc;
  late ArkdAdmin arkd;
  late Directory tempDir;
  late Directory serverTempDir;
  late int serverPort;
  late MockFcmServer mockFcm;
  late String fcmTestProjectId;
  late Map<String, String> cosignerExtraEnv;

  // Real 2-of-2 {wallet, cosigner}: no signer. Distinct storageId per wallet.
  MpcClient createClient({String? storageId}) {
    return MpcClient.rest('http://127.0.0.1:$serverPort', storageId: storageId);
  }

  setUpAll(() async {
    print('--- Ark E2E Setup ---');

    // 0. Hive Init
    tempDir = await Directory.systemTemp.createTemp('mpc_ark_e2e_');
    Hive.init(tempDir.path);

    // 1. Docker: bitcoind + electrs + arkd should already be running
    // (via `make arkd-up && make bitcoin-init && make arkd-init`)
    print('Checking Docker services...');

    btc = RegtestHelper();
    try {
      try {
        await btc.createWallet("default");
      } catch (e) {
        if (!e.toString().contains("already loaded")) rethrow;
      }
      btc = RegtestHelper(rpcUrl: "http://127.0.0.1:18443/wallet/default");
      await btc.getNewAddress();
      print("  Bitcoind: OK");
    } catch (e) {
      throw Exception(
          "Bitcoind not reachable. Run: make arkd-up && make bitcoin-init\nError: $e");
    }

    // 2. Check arkd
    arkd = ArkdAdmin();
    print('Checking arkd...');
    bool arkdReady = false;
    for (int i = 0; i < 10; i++) {
      if (await arkd.isReady()) {
        arkdReady = true;
        break;
      }
      print('  Waiting for arkd... (${i + 1}/10)');
      await Future.delayed(Duration(seconds: 3));
    }

    if (!arkdReady) {
      // Try to initialize arkd wallet
      print('  arkd not ready, attempting wallet init...');
      try {
        await arkd.initWallet();
        await Future.delayed(Duration(seconds: 2));
        final info = await arkd.getInfo();
        print('  arkd initialized: $info');
      } catch (e) {
        throw Exception(
            "arkd not reachable. Run: make arkd-up && make arkd-init\nError: $e");
      }
    }

    final info = await arkd.getInfo();
    print(
        '  arkd info: pubkey=${(info['pubkey'] as String?)?.substring(0, 16)}...');

    // 3. Fund ASP wallet if needed
    try {
      final aspAddr = await arkd.getWalletAddress();
      print('  Funding ASP wallet at $aspAddr');
      final minerAddr = await btc.getNewAddress();
      // Ensure enough blocks for spending
      await btc.generateToAddress(101, minerAddr);
      await btc.sendToAddress(aspAddr, 10.0);
      await btc.generateToAddress(1, minerAddr);
      print('  ASP funded with 10 BTC');
      await Future.delayed(Duration(seconds: 5));
    } catch (e) {
      print('  Warning: Could not fund ASP: $e');
    }

    // 4. Mock Firebase Cloud Messaging
    //
    // Stand up a local HTTP server that impersonates both endpoints the
    // cosigner-runtime hits during a push: the OAuth2 token endpoint and
    // the `messages:send` endpoint. The cosigner signs an OAuth JWT with
    // the fixture private key — the mock doesn't verify the signature,
    // since real Firebase isn't in the loop.
    //
    // Pushes only fire when a user has registered a device token AND a
    // new VTXO arrives. Existing tests don't register tokens, so the
    // mock sits idle for them. The dedicated FCM test below is the only
    // consumer.
    print('Starting MockFcmServer...');
    mockFcm = MockFcmServer();
    await mockFcm.start();
    print('  MockFcmServer listening on ${mockFcm.baseUrl}');

    fcmTestProjectId = 'mpc-wallet-e2e-test';
    final keyPemPath = '../e2e/fixtures/fcm_test_key.pem';
    final keyPem = await File(keyPemPath).readAsString();
    final fcmServiceAccountJson = jsonEncode({
      'type': 'service_account',
      'project_id': fcmTestProjectId,
      'private_key_id': 'e2e-mock',
      'private_key': keyPem,
      'client_email': 'fcm-e2e@$fcmTestProjectId.iam.gserviceaccount.com',
      // Both `aud` claim in the JWT and the POST destination are derived
      // from this — see fcm_client.rs::mint_token.
      'token_uri': mockFcm.tokenUri,
    });
    cosignerExtraEnv = {
      'FCM_SERVICE_ACCOUNT_JSON': fcmServiceAccountJson,
      'FCM_BASE_URL': mockFcm.baseUrl,
      // Enable session-token auth so the gated-wallet test can present a minted
      // Bearer token. Harmless for the other tests: verify_auth falls back to
      // Schnorr when no token is presented.
      'WEBAUTH_TOKEN_SECRET': webauthTokenSecretHex,
    };

    // 5. Start MPC Server with ASP_URL
    print('Starting MPC Server with ASP...');
    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_ark_server_');
    serverProcess = await startCosignerRuntime(
      serverPort,
      serverTempDir,
      extraEnv: cosignerExtraEnv,
    );
    print('--- Ark E2E Setup Complete ---');
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

  // Server is the source of truth for `bitcoin_network`; the client fetches
  // it via this RPC at the moment a wallet is constructed (see
  // `MpcService.restoreSession` / `doDkg` / `doRestore`). Verifies the wire
  // shape: unauthenticated, no DKG required, returns whatever the runtime
  // was started with.
  test('GetServerInfo returns the configured bitcoin_network', () async {
    final client = createClient();

    final info = await client.getServerInfo();
    print('   bitcoin_network=${info.bitcoinNetwork}');
    expect(info.bitcoinNetwork, equals('regtest'),
        reason:
            'Server should echo back BITCOIN_NETWORK env var (set to "regtest" '
            'in the test harness). If this fails, either the env wiring or the '
            'GetServerInfo handler is broken.');
  }, timeout: Timeout(Duration(minutes: 1)));

  test('Ark: DKG + GetArkInfo + GetArkAddress + GetBoardingAddress', () async {
    // 1. DKG Setup
    print('1. DKG Setup');
    final client = createClient();

    await client.doDkg();
    print('   DKG Complete. userId=${client.userId?.substring(0, 16)}...');

    // 2. GetArkInfo
    print('2. GetArkInfo');
    final arkInfo = await client.getArkInfo();
    print('   network=${arkInfo.network}');
    print('   signerPubkey=${arkInfo.signerPubkey.substring(0, 16)}...');
    print('   sessionDuration=${arkInfo.sessionDuration}');
    print('   unilateralExitDelay=${arkInfo.unilateralExitDelay}');
    print('   boardingExitDelay=${arkInfo.boardingExitDelay}');

    expect(arkInfo.signerPubkey, isNotEmpty);
    expect(arkInfo.network, isNotEmpty);
    expect(arkInfo.unilateralExitDelay, greaterThan(0));

    // 3. GetArkAddress
    print('3. GetArkAddress');
    final arkAddress = await client.getArkAddress();
    print('   Ark Address: $arkAddress');
    expect(arkAddress, isNotEmpty);
    // Ark addresses start with "ark1" on mainnet or "tark1" on testnet/regtest
    expect(
      arkAddress.startsWith('ark1') || arkAddress.startsWith('tark1'),
      isTrue,
      reason: "Ark address should start with ark1 or tark1, got: $arkAddress",
    );

    // 4. GetBoardingAddress
    print('4. GetBoardingAddress');
    final boardingAddress = await client.getBoardingAddress();
    print('   Boarding Address: $boardingAddress');
    expect(boardingAddress, isNotEmpty);
    // Boarding address is a P2TR address (bcrt1p... on regtest, tb1p... on signet/testnet)
    expect(
        boardingAddress.startsWith('bcrt1p') ||
            boardingAddress.startsWith('tb1p'),
        isTrue,
        reason: "Boarding address should be P2TR, got: $boardingAddress");

    // 5. ListVtxos (should be empty for new wallet)
    print('5. ListVtxos');
    final vtxosResp = await client.listVtxos();
    print(
        '   VTXOs: ${vtxosResp.vtxos.length}, balance: ${vtxosResp.totalBalance}');
    expect(vtxosResp.vtxos, isEmpty);
    expect(vtxosResp.totalBalance.toInt(), equals(0));

    // 6. Verify addresses are deterministic
    print('6. Verifying address determinism');
    final arkAddress2 = await client.getArkAddress();
    final boardingAddress2 = await client.getBoardingAddress();
    expect(arkAddress2, equals(arkAddress));
    expect(boardingAddress2, equals(boardingAddress));
    print('   Addresses are deterministic');

    print('Ark E2E Test Complete!');
  }, timeout: Timeout(Duration(minutes: 5)));

  // Balance and VTXO assertions below caught two production bugs:
  // 1. get_boarding_address() not registering scripts → VTXOs invisible after settle
  // 2. exit_delay stored as 0 → VTXO reconstruction used wrong taproot tree → VTXO_NOT_FOUND on send
  // Without these, the test only verified txid non-empty, which passed even with broken VTXOs.
  test('Ark: Full flow - fund boarding, settle, send Alice→Bob', () async {
    // 1. Alice DKG
    print('1. Alice DKG');
    final alice = createClient(storageId: "alice");
    await alice.doDkg();
    print('   Alice userId=${alice.userId?.substring(0, 16)}...');

    // 2. Get Alice's boarding address
    print('2. Get boarding address');
    final boardingAddress = await alice.getBoardingAddress();
    print('   Boarding: $boardingAddress');

    // 3. Fund boarding address with 0.01 BTC (1,000,000 sats)
    print('3. Fund boarding address');
    final minerAddr = await btc.getNewAddress();
    final fundTxid = await btc.sendToAddress(boardingAddress, 0.01);
    print('   Fund txid: $fundTxid');
    // Confirm the funding tx
    await btc.generateToAddress(1, minerAddr);
    print('   Funding confirmed');

    // Wait for electrum/nbxplorer to index the new block
    await Future.delayed(Duration(seconds: 5));

    // Verify UTXO exists at boarding address
    final utxos = await btc.scanUtxos(boardingAddress);
    print('   UTXOs at boarding address: ${utxos.length}');
    expect(utxos, isNotEmpty, reason: 'Should have UTXO at boarding address');
    print('   UTXO amount: ${utxos[0]['amount']} BTC');

    // 4. Settle (board on-chain UTXO into Ark VTXO)
    print('4. Settle (board)');
    // We need to mine blocks to trigger ASP batches (ARKD_SCHEDULER_TYPE=block).
    bool settling = true;
    int blocksMined = 0;
    final miningTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!settling) {
        timer.cancel();
        return;
      }
      try {
        final addr = await btc.getNewAddress();
        await btc.generateToAddress(1, addr);
        blocksMined++;
        print('   Mined block #$blocksMined for batch trigger');
      } catch (e) {
        print('   Mining error (non-fatal): $e');
      }
    });

    final boardingUtxos = await pollBoardingUtxos(boardingAddress, 1);
    expect(boardingUtxos, isNotEmpty);
    try {
      final commitmentTxid = await alice.settle(boardingUtxos: boardingUtxos);
      settling = false;
      miningTimer.cancel();
      print('   Settled! commitment_txid=$commitmentTxid');
      expect(commitmentTxid, isNotEmpty);
    } catch (e) {
      settling = false;
      miningTimer.cancel();
      rethrow;
    }

    // 5. Verify Alice has a VTXO with correct balance and exit_delay
    print('5. List VTXOs');
    final vtxosResp = await alice.listVtxos();
    final aliceBalanceAfterSettle = vtxosResp.totalBalance.toInt();
    print(
        '   VTXOs: ${vtxosResp.vtxos.length}, balance: $aliceBalanceAfterSettle');
    expect(vtxosResp.vtxos.length, equals(1),
        reason: 'Alice should have exactly 1 VTXO after settle');
    expect(aliceBalanceAfterSettle, greaterThan(900000),
        reason: 'Alice should have ~1M sats (0.01 BTC minus fees)');
    expect(vtxosResp.vtxos.first.exitDelay, greaterThan(0),
        reason:
            'exit_delay must not be 0 — would produce wrong taproot tree on spend');
    // expires_at lands asynchronously: the boarding settle handler pushes
    // the VTXO without it (the ASP doesn't return it from the settle call),
    // and the vtxo_stream subscription backfills it when the matching
    // event arrives. Poll for it.
    int expiresAt = vtxosResp.vtxos.first.expiresAt.toInt();
    for (int i = 0; i < 20 && expiresAt == 0; i++) {
      await Future.delayed(Duration(seconds: 1));
      final r = await alice.listVtxos();
      if (r.vtxos.isNotEmpty) {
        expiresAt = r.vtxos.first.expiresAt.toInt();
      }
    }
    expect(expiresAt, greaterThan(0),
        reason:
            'expires_at must be populated end-to-end so auto-settle can decide when to fire');
    final aliceScript = vtxosResp.vtxos.first.script;
    expect(aliceScript, isNotEmpty, reason: 'VTXO script must be populated');
    print('   Alice script: ${aliceScript.substring(0, 16)}...');

    // 5b. Store-only delegate: signed intent stored on the cosigner without
    // joining a batch. listVtxos should report the delegate as active and
    // VTXOs unchanged.
    print('5b. settleDelegate(storeOnly: true)');
    final delegatedTxid = await alice.settleDelegate(storeOnly: true);
    expect(delegatedTxid, isEmpty,
        reason: 'DELEGATED status returns no commitment_txid');
    final afterDelegate = await alice.listVtxos();
    expect(afterDelegate.hasActiveDelegate, isTrue,
        reason: 'cosigner should report delegate as active');
    expect(afterDelegate.vtxos.length, equals(1),
        reason: 'store-only must not consume VTXOs');
    expect(afterDelegate.totalBalance.toInt(), equals(aliceBalanceAfterSettle),
        reason: 'store-only must not change balance');

    // 6. Bob DKG
    print('6. Bob DKG');
    final bob = createClient(storageId: "bob");
    await bob.doDkg();
    print('   Bob userId=${bob.userId?.substring(0, 16)}...');

    // 7. Get Bob's Ark address
    print('7. Bob Ark address');
    final bobArkAddress = await bob.getArkAddress();
    print('   Bob Ark: $bobArkAddress');

    // 8. Alice sends VTXO to Bob via MpcArkWallet
    print('8. Alice sends to Bob');
    final sendAmount = 100000; // 100k sats
    final aliceArkWallet = MpcArkWallet(alice);
    final unsigned = await aliceArkWallet.createTransaction(
      destination: bobArkAddress,
      amountSats: sendAmount,
    );
    print('   Built tx: ${unsigned.sighashes.length} sighashes');
    final signed = await aliceArkWallet.signTransaction(unsigned);
    print('   Signed tx');
    final arkTxid = await aliceArkWallet.submit(signed);
    print('   Send ark_txid: $arkTxid');
    expect(arkTxid, isNotEmpty);

    // 8b. Verify balances after first send.
    // Wait for Bob's indexer subscription to deliver the received VTXO.
    final aliceAfterSend1 = await alice.listVtxos();
    print(
        '   Alice: ${aliceAfterSend1.vtxos.length} VTXOs, balance=${aliceAfterSend1.totalBalance}');
    expect(
        aliceAfterSend1.totalBalance.toInt(), lessThan(aliceBalanceAfterSettle),
        reason: 'Alice balance should decrease after send');
    // The off-chain send consumed VTXOs covered by Alice's stored delegate,
    // so the cosigner must have invalidated it. Without invalidation the
    // auto-settle tick task would later submit signatures referencing
    // already-spent VTXOs.
    expect(aliceAfterSend1.hasActiveDelegate, isFalse,
        reason:
            'sending should invalidate any stored delegate covering the spent VTXOs');
    // Verify all Alice VTXOs have a non-empty script.
    // Note: boarding VTXOs use boarding_exit_delay, change VTXOs use
    // unilateral_exit_delay — so scripts may differ. Both must be non-empty.
    for (final vtxo in aliceAfterSend1.vtxos) {
      expect(vtxo.script, isNotEmpty,
          reason: 'Every VTXO must have a non-empty scriptPubKey');
    }

    // Poll Bob's balance — subscription event may take a moment to arrive.
    int bobBalance1 = 0;
    for (int i = 0; i < 10; i++) {
      final resp = await bob.listVtxos();
      bobBalance1 = resp.totalBalance.toInt();
      if (bobBalance1 > 0) break;
      print('   Waiting for Bob VTXO... (${i + 1}/10)');
      await Future.delayed(Duration(seconds: 1));
    }
    print('   Bob: balance=$bobBalance1');
    expect(bobBalance1, equals(sendAmount),
        reason: 'Bob should have received exactly $sendAmount sats');

    // 8c. Verify the receive shows up in Bob's transaction history.
    // Regression guard for the `vtxo_stream::apply_stream_update` gate that
    // previously dropped "receive" entries when any session was in flight.
    // Without this assertion the bug was invisible — listVtxos worked fine
    // even while listArkTransactions silently lost the row.
    final bobHistoryAfterSend1 = await bob.listArkTransactions();
    final receivesAfter1 = bobHistoryAfterSend1.transactions
        .where((e) => e.txType == 'receive')
        .toList();
    print(
        '   Bob history: ${bobHistoryAfterSend1.transactions.length} entries, '
        'receives: ${receivesAfter1.length}');
    expect(receivesAfter1, hasLength(1),
        reason: 'Bob should have exactly 1 receive entry after first send');
    expect(receivesAfter1.first.amountSats.toInt(), equals(sendAmount),
        reason: 'Receive amount should match sent amount');

    // 9. Alice sends again to Bob (uses change VTXO from first send)
    print('9. Alice sends to Bob again');
    final sendAmount2 = 50000; // 50k sats
    final unsigned2 = await aliceArkWallet.createTransaction(
      destination: bobArkAddress,
      amountSats: sendAmount2,
    );
    print('   Built tx: ${unsigned2.sighashes.length} sighashes');
    final signed2 = await aliceArkWallet.signTransaction(unsigned2);
    print('   Signed tx');
    final arkTxid2 = await aliceArkWallet.submit(signed2);
    print('   Send ark_txid: $arkTxid2');
    expect(arkTxid2, isNotEmpty);

    // 9b. Verify balances after second send
    final aliceAfterSend2 = await alice.listVtxos();
    print(
        '   Alice: ${aliceAfterSend2.vtxos.length} VTXOs, balance=${aliceAfterSend2.totalBalance}');
    expect(aliceAfterSend2.totalBalance.toInt(),
        lessThan(aliceAfterSend1.totalBalance.toInt()),
        reason: 'Alice balance should decrease after second send');
    int bobBalance2 = 0;
    for (int i = 0; i < 10; i++) {
      final resp = await bob.listVtxos();
      bobBalance2 = resp.totalBalance.toInt();
      if (bobBalance2 >= sendAmount + sendAmount2) break;
      await Future.delayed(Duration(seconds: 1));
    }
    print('   Bob: balance=$bobBalance2');
    expect(bobBalance2, equals(sendAmount + sendAmount2),
        reason: 'Bob should have ${sendAmount + sendAmount2} sats total');

    // 9c. Bob's history should now have two distinct receive entries — one
    // per send. Verifies receives don't merge or get dropped on the second
    // event when the first VTXO is being spent.
    final bobHistoryAfterSend2 = await bob.listArkTransactions();
    final receivesAfter2 = bobHistoryAfterSend2.transactions
        .where((e) => e.txType == 'receive')
        .toList();
    print('   Bob history: ${receivesAfter2.length} receives');
    expect(receivesAfter2, hasLength(2),
        reason: 'Bob should have 2 receive entries after second send');
    final totalReceived = receivesAfter2.fold<int>(
        0, (sum, e) => sum + e.amountSats.toInt());
    expect(totalReceived, equals(sendAmount + sendAmount2),
        reason: 'Sum of receive amounts should match total sent');

    // 10. Third send (20k sats) — exercises spending down the change VTXO
    print('10. Alice sends 20k to Bob');
    final sendAmount3 = 20000;
    final unsigned4 = await aliceArkWallet.createTransaction(
      destination: bobArkAddress,
      amountSats: sendAmount3,
    );
    final signed4 = await aliceArkWallet.signTransaction(unsigned4);
    final arkTxid4 = await aliceArkWallet.submit(signed4);
    print('   Send ark_txid: $arkTxid4');
    expect(arkTxid4, isNotEmpty);

    // 10b. Verify final balances
    final aliceFinal = await alice.listVtxos();
    final totalSent = sendAmount + sendAmount2 + sendAmount3;
    print(
        '   Alice final: ${aliceFinal.vtxos.length} VTXOs, balance=${aliceFinal.totalBalance}');
    expect(aliceFinal.totalBalance.toInt(),
        equals(aliceBalanceAfterSettle - totalSent),
        reason:
            'Alice should have original balance minus $totalSent sats sent');
    int bobFinalBalance = 0;
    for (int i = 0; i < 10; i++) {
      final resp = await bob.listVtxos();
      bobFinalBalance = resp.totalBalance.toInt();
      if (bobFinalBalance >= totalSent) break;
      await Future.delayed(Duration(seconds: 1));
    }
    print('   Bob final: balance=$bobFinalBalance');
    expect(bobFinalBalance, equals(totalSent),
        reason: 'Bob should have received $totalSent sats total');

    print('Full Ark E2E flow complete!');
  }, timeout: Timeout(Duration(minutes: 10)));

  // Phase 5 — gated wallet. The FROST share is PIN/PRF-blinded (δ); auth rides a minted session
  // token; the raw share is reconstructed transiently ONLY to FROST-sign an ARK op. Proves the
  // whole "PIN only for ARK" design headlessly (FixedSeedSource stands in for the passkey PRF):
  //  - reads authenticate token-only, with NO seed reconstructed;
  //  - a right-seed settle FROST-signs validly (reconstruction integrates end-to-end);
  //  - a WRONG seed cannot sign — the cosigner rejects the bad signature share.
  test('Ark gated: PIN/PRF-blinded share — token auth + reconstructed FROST sign',
      () async {
    final seed =
        Uint8List.fromList(List<int>.generate(32, (i) => (i * 7 + 3) & 0xff));
    final wrongSeed =
        Uint8List.fromList(List<int>.generate(32, (i) => (i * 7 + 4) & 0xff));

    // 1. Gated DKG: the seed is wired BEFORE DKG, so the share is stored blinded and no Schnorr
    //    auth helper is built. DKG itself is unauthenticated, so no token is needed yet.
    print('1. Gated DKG');
    final alice = createClient(storageId: "gated_alice");
    alice.setSeedSource(FixedSeedSource(seed));
    await alice.doDkg();
    expect(alice.userId, isNotNull);
    print('   userId=${alice.userId!.substring(0, 16)}...');

    // 2. Mint an upstream-style session token bound to this user (sub = group key) and wire it.
    //    Every authenticated RPC now rides the Bearer token; the share is never used for auth.
    final token = await mintSessionToken(alice.userId!, webauthTokenSecret);
    alice.setSessionTokenSource(StaticSessionToken(token));

    // 3. Reads work token-only — no seed reconstructed. Proves auth is off the share.
    print('2. Reads via token (no seed)');
    final arkInfo = await alice.getArkInfo();
    expect(arkInfo.signerPubkey, isNotEmpty);
    final boardingAddress = await alice.getBoardingAddress();
    expect(boardingAddress, isNotEmpty);

    // 4. Fund + settle — the first FROST sign. The share is reconstructed from δ + the seed
    //    transiently; a valid commitment proves the gating integrates end-to-end.
    print('3. Fund + settle (gated FROST sign)');
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.01);
    await btc.generateToAddress(1, minerAddr);
    await Future.delayed(Duration(seconds: 5));

    bool settling = true;
    final miningTimer = Timer.periodic(Duration(seconds: 3), (t) async {
      if (!settling) {
        t.cancel();
        return;
      }
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
    });
    final boardingUtxos = await pollBoardingUtxos(boardingAddress, 1);
    expect(boardingUtxos, isNotEmpty);
    String commitmentTxid;
    try {
      commitmentTxid = await alice.settle(boardingUtxos: boardingUtxos);
    } finally {
      settling = false;
      miningTimer.cancel();
    }
    expect(commitmentTxid, isNotEmpty,
        reason: 'gated settle must FROST-sign validly with the reconstructed share');
    final vtxos = await alice.listVtxos();
    expect(vtxos.vtxos.length, equals(1),
        reason: 'a VTXO ⇒ the gated signature was accepted on-chain');
    print('   Settled — reconstructed share signed validly');

    // 5. WRONG seed ⇒ reconstruction yields the wrong share ⇒ the cosigner rejects the FROST
    //    signature share. The gate holds: a wrong PIN/PRF cannot spend.
    print('4. Wrong seed must fail to sign');
    alice.setSeedSource(FixedSeedSource(wrongSeed));
    final aliceArk = MpcArkWallet(alice);
    final selfAddr = await alice.getArkAddress();
    final unsigned = await aliceArk.createTransaction(
      destination: selfAddr,
      amountSats: 1000,
    );
    await expectLater(
      aliceArk.signTransaction(unsigned),
      throwsA(anything),
      reason: 'a wrong PIN/PRF seed must not produce a valid FROST signature',
    );
    print('   Wrong seed correctly rejected — gate holds');
  }, timeout: Timeout(Duration(minutes: 10)));

  // Auto-settle round-trip: register a delegate intent with store_only=true,
  // then verify the cosigner's tick task drives it to completion on its own.
  //
  // Requires `ARKD_VTXO_TREE_EXPIRY` short enough for the tick to cross the
  // threshold before the test times out (the docker-compose has it at 60s).
  // The cosigner's `AUTO_SETTLE_SAFETY_MARGIN_SECS` defaults to 1800, which
  // means any intent fires on the next tick — no need to override in tests.
  test('Ark: auto-settle drives stored delegate intent without client', () async {
    print('1. Alice DKG');
    final alice = createClient(storageId: "alice");
    await alice.doDkg();

    print('2. Fund boarding + settle');
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.005);
    await btc.generateToAddress(1, minerAddr);

    // The wallet polls the boarding address via electrum (bitcoind sees the
    // deposit immediately; electrs needs a few seconds to index) and supplies
    // the UTXO to settle().
    final boardingUtxos = await pollBoardingUtxos(boardingAddress, 500000);
    expect(boardingUtxos, isNotEmpty,
        reason: 'Electrum should index the boarding UTXO within 30s');

    bool stillMining = true;
    final miningTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!stillMining) {
        timer.cancel();
        return;
      }
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
    });
    try {
      final commitment = await alice.settle(boardingUtxos: boardingUtxos);
      expect(commitment, isNotEmpty);
      print('   Settled commitment=$commitment');
    } finally {
      // Keep mining through the rest of the test — the cosigner's auto-settle
      // submission still needs the ASP scheduler firing batches.
    }

    print('3. Snapshot original VTXO (poll until expires_at populates)');
    String originalTxid = '';
    int originalBalance = 0;
    int expiresAt = 0;
    for (int i = 0; i < 20; i++) {
      final r = await alice.listVtxos();
      if (r.vtxos.isNotEmpty) {
        originalTxid = r.vtxos.first.txid;
        originalBalance = r.totalBalance.toInt();
        expiresAt = r.vtxos.first.expiresAt.toInt();
      }
      if (expiresAt > 0) break;
      await Future.delayed(Duration(seconds: 1));
    }
    expect(expiresAt, greaterThan(0),
        reason:
            'expires_at must be populated by the vtxo_stream backfill before the tick can act');
    print('   txid=$originalTxid balance=$originalBalance expires_at=$expiresAt');

    print('4. settleDelegate(storeOnly: true) — store signed intent');
    final delegated = await alice.settleDelegate(storeOnly: true);
    expect(delegated, isEmpty, reason: 'DELEGATED returns no commitment_txid');
    final afterDelegate = await alice.listVtxos();
    expect(afterDelegate.hasActiveDelegate, isTrue);
    expect(afterDelegate.vtxos.first.txid, equals(originalTxid),
        reason: 'storing the intent must NOT consume the VTXO');

    print(
        '5. Wait up to 2 minutes for the cosigner tick task to drive the intent');
    // Setup forces AUTO_SETTLE_SAFETY_MARGIN_SECS=3600, so the tick threshold
    // is "always crossed" regardless of VTXO_TREE_EXPIRY. Tick interval is
    // 60s with the first tick skipped on boot, so worst-case ~60s before
    // submission + ASP batch latency. Mining keeps the scheduler moving.
    String? newTxid;
    int newBalance = 0;
    bool stillActive = true;
    final deadline = DateTime.now().add(Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: 5));
      try {
        final resp = await alice.listVtxos();
        stillActive = resp.hasActiveDelegate;
        if (resp.vtxos.isNotEmpty) {
          newTxid = resp.vtxos.first.txid;
          newBalance = resp.totalBalance.toInt();
        }
        // Auto-settle complete: VTXO refreshed (txid changed) AND delegate
        // cleared (the handler clears it after a successful settle).
        if (newTxid != null && newTxid != originalTxid && !stillActive) {
          break;
        }
      } catch (e) {
        print('   listVtxos error (will retry): $e');
      }
    }
    stillMining = false;
    miningTimer.cancel();

    expect(newTxid, isNotNull,
        reason: 'auto-settle did not produce any VTXO update before timeout');
    expect(newTxid, isNot(equals(originalTxid)),
        reason:
            'auto-settle must replace the original VTXO with a fresh one');
    expect(newBalance, equals(originalBalance),
        reason: 'auto-settle must preserve the balance');
    expect(stillActive, isFalse,
        reason: 'cosigner must clear the delegate after a successful settle');
    print(
        '6. Auto-settle complete: new txid=$newTxid (was $originalTxid), balance preserved');
  }, timeout: Timeout(Duration(minutes: 4)));

  // Cosigner-runtime restart: kill the process, restart against the same
  // data_dir, and prove that persisted state survives. Specifically:
  //   * VTXOs reload (`load_user_vtxos`) before the vtxo_stream catches up
  //   * Ark transaction history reloads (`load_user_ark_history`) — the
  //     previously-gone-on-restart entries we just wired up
  //   * Per-user RPCs (getArkAddress) work again after rehydration
  test('Ark: cosigner-runtime restart preserves rehydrated state', () async {
    print('1. Alice DKG');
    final alice = createClient(storageId: "alice");
    await alice.doDkg();

    print('2. Fund boarding + settle');
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.003);
    await btc.generateToAddress(1, minerAddr);

    final boardingUtxos = await pollBoardingUtxos(boardingAddress, 300000);
    expect(boardingUtxos, isNotEmpty,
        reason: 'Electrum should index the boarding UTXO within 30s');

    bool stillMining = true;
    final miningTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!stillMining) {
        timer.cancel();
        return;
      }
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
    });
    final commitment = await alice.settle(boardingUtxos: boardingUtxos);
    expect(commitment, isNotEmpty);
    stillMining = false;
    miningTimer.cancel();

    print('3. Capture pre-restart state');
    final preVtxos = await alice.listVtxos();
    final preTxs = await alice.listArkTransactions();
    expect(preVtxos.vtxos, isNotEmpty,
        reason: 'pre-restart should have at least one VTXO');
    expect(preTxs.transactions, isNotEmpty,
        reason: 'pre-restart should have at least the boarding settle entry');
    final preVtxoOutpoints =
        preVtxos.vtxos.map((v) => '${v.txid}:${v.vout}').toSet();
    final preTxTxids = preTxs.transactions.map((t) => t.txid).toSet();
    print(
        '   pre-restart: ${preVtxos.vtxos.length} VTXOs, ${preTxs.transactions.length} history entries');

    print('4. Kill cosigner-runtime');
    final oldProcess = serverProcess!;
    serverProcess = null;
    oldProcess.kill(ProcessSignal.sigterm);
    // Wait for actual exit so the sled lock releases before we restart.
    await oldProcess.exitCode;
    print('   cosigner-runtime exited; sled lock should be released');

    print('5. Restart cosigner-runtime against the same data_dir');
    serverProcess = await startCosignerRuntime(
      serverPort,
      serverTempDir,
      extraEnv: cosignerExtraEnv,
    );

    print('6. Recapture post-restart state');
    // First listVtxos call spawns a fresh actor; `get_or_spawn` rehydrates
    // vtxos / ark_tx_history / device_tokens from sled. The vtxo_stream
    // subscription will also reconnect and reconcile, but the rehydration
    // load means the first listVtxos call already returns valid state.
    final postVtxos = await alice.listVtxos();
    final postTxs = await alice.listArkTransactions();

    print(
        '   post-restart: ${postVtxos.vtxos.length} VTXOs, ${postTxs.transactions.length} history entries');

    final postVtxoOutpoints =
        postVtxos.vtxos.map((v) => '${v.txid}:${v.vout}').toSet();
    final postTxTxids = postTxs.transactions.map((t) => t.txid).toSet();

    expect(postVtxoOutpoints, equals(preVtxoOutpoints),
        reason:
            'VTXOs should be rehydrated from vtxo_store after restart (pre-restart set must match post-restart set)');
    expect(postTxTxids, equals(preTxTxids),
        reason:
            'ark_tx_history should be rehydrated from sled after restart — without the new load_user_ark_history path this set would be empty');

    print('7. Sanity: post-restart per-user RPCs work');
    final addr = await alice.getArkAddress();
    expect(addr, isNotEmpty,
        reason:
            'getArkAddress should succeed once the user actor is rehydrated post-restart');

    print('Restart-survival test complete!');
  }, timeout: Timeout(Duration(minutes: 4)));

  // FCM push delivery: the cosigner-runtime is configured (via setUpAll) to
  // direct all FCM traffic at `MockFcmServer`. This test:
  //   1. Registers a fake device token for the recipient (Bob)
  //   2. Triggers a receive (Alice → Bob via off-chain send)
  //   3. Asserts the mock recorded a `messages:send` POST with the right
  //      bearer token, project id, target token, and data payload shape
  //
  // Pre-conditions covered:
  //   * OAuth round-trip happens (cosigner sets Authorization: Bearer <mock>)
  //   * payload is data-only with `type=vtxo_received`
  //   * Android `priority: HIGH` + APNS background headers present
  //   * `user_id` field in data matches the recipient
  test('FCM push fires on VTXO receive with correct payload shape', () async {
    // Use a port for Bob's signer that isn't already taken by other tests in
    // this suite (9090 is the universal one most tests use; we use it too
    // here since each test does its own DKG and there's no signer-state
    // overlap between tests).
    print('1. Alice + Bob DKG');
    final alice = createClient(storageId: "alice");
    await alice.doDkg();

    final bob = createClient(storageId: "bob");
    await bob.doDkg();

    // Snapshot mock sends BEFORE registering — prior tests may have left
    // residue (they shouldn't, but be defensive).
    mockFcm.clearSends();

    print('2. Register fake FCM token for Bob');
    const fakeBobToken = 'fake-fcm-token-for-bob-e2e';
    await bob.registerDeviceToken(
      fcmToken: fakeBobToken,
      platform: 'android',
      appVersion: '1.0.0-e2e',
    );

    print('3. Fund Alice + settle into VTXO');
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.003);
    await btc.generateToAddress(1, minerAddr);

    final boardingUtxos = await pollBoardingUtxos(boardingAddress, 300000);
    expect(boardingUtxos, isNotEmpty);

    bool stillMining = true;
    final miningTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!stillMining) {
        timer.cancel();
        return;
      }
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
    });

    final commitment = await alice.settle(boardingUtxos: boardingUtxos);
    expect(commitment, isNotEmpty);

    print('4. Alice sends to Bob (triggers receive on Bob → push fires)');
    final bobArkAddress = await bob.getArkAddress();
    final aliceArkWallet = MpcArkWallet(alice);
    final unsigned = await aliceArkWallet.createTransaction(
      destination: bobArkAddress,
      amountSats: 100000,
    );
    final signed = await aliceArkWallet.signTransaction(unsigned);
    final arkTxid = await aliceArkWallet.submit(signed);
    expect(arkTxid, isNotEmpty);
    print('   send ark_txid=$arkTxid');

    // 5. Wait for the mock to record the push. The cosigner's stream
    // fan-out runs after the vtxo_stream event arrives at Bob's actor,
    // which is async w.r.t. the send completing.
    print('5. Wait for FCM mock to record the push');
    final push = await mockFcm.waitForFirstSend(timeout: Duration(seconds: 15));
    stillMining = false;
    miningTimer.cancel();

    expect(push, isNotNull,
        reason:
            'FCM mock should have received a messages:send call within 15s of Bob receiving a VTXO');
    final p = push!;

    // 6. Assert the OAuth happened — the bearer token must be the mock's
    // canonical access token, NOT the raw JWT assertion.
    expect(p.bearerToken, equals(MockFcmServer.mockAccessToken),
        reason:
            'Cosigner must complete the OAuth round-trip and use the access_token from the mock token endpoint');

    // 7. The path's project_id must match what we configured the cosigner
    // with — proves the URL template uses sa.project_id.
    expect(p.projectId, equals(fcmTestProjectId),
        reason:
            'POST path must be /v1/projects/${fcmTestProjectId}/messages:send');

    // 8. The push must target Bob's registered token.
    expect(p.targetToken, equals(fakeBobToken),
        reason:
            'cosigner should push to the FCM token Bob registered, not Alice or some default');

    // 9. Payload shape — must be data-only, type=vtxo_received, with Bob's
    // user_id (no notification body for silent background wake).
    final data = p.data;
    expect(data, isNotNull, reason: 'message.data must be present');
    expect(data!['type'], equals('vtxo_received'),
        reason: 'data.type identifies what woke the app');
    expect(data['user_id'], isNotEmpty,
        reason: 'data.user_id lets the app scope its refresh to the right user');

    // 10. Android + APNS routing headers — these are what make the device
    // wake silently in the background.
    final message = p.body['message'] as Map<String, dynamic>;
    expect(message['notification'], isNull,
        reason:
            'must be data-only — a `notification` field would force a visible banner and could change OS routing');
    expect((message['android'] as Map?)?['priority'], equals('HIGH'),
        reason: 'Android needs HIGH priority to wake from idle');
    final apns = message['apns'] as Map<String, dynamic>?;
    expect(apns, isNotNull);
    expect((apns!['headers'] as Map?)?['apns-priority'], equals('5'),
        reason: 'APNS requires <=5 for content-available silent pushes');
    expect((apns['headers'] as Map?)?['apns-push-type'], equals('background'),
        reason: 'apns-push-type=background is required by iOS 13+');
    expect(
        ((apns['payload'] as Map?)?['aps'] as Map?)?['content-available'],
        equals(1),
        reason: 'content-available=1 is the iOS background-wake flag');

    print('FCM push test complete!');
  }, timeout: Timeout(Duration(minutes: 4)));

  // Boarding watcher: the cosigner has no chain view for the WALLET's money,
  // but it runs a thin read-only esplora watcher over each user's boarding
  // address. On a new confirmed deposit it pushes a user-visible "tap to
  // board" notification — the device boards on tap. This test funds a boarding
  // address WITHOUT the client polling, and asserts the cosigner autonomously
  // pushes a `boarding_deposit` notification with the deposit's outpoint.
  test('Ark: boarding watcher pushes tap-to-board on a confirmed deposit',
      () async {
    print('1. DKG + register device token');
    final alice = createClient(storageId: 'boardwatch');
    await alice.doDkg();
    // getBoardingAddress records the address in the cosigner's boarding_watches.
    final boardingAddress = await alice.getBoardingAddress();
    const fakeToken = 'fake-fcm-token-boardwatch';
    await alice.registerDeviceToken(
      fcmToken: fakeToken,
      platform: 'android',
      appVersion: '1.0.0-e2e',
    );

    mockFcm.clearSends();

    print('2. Fund + confirm the boarding deposit (client does NOT poll)');
    await btc.sendToAddress(boardingAddress, 0.004);
    await btc.generateToAddress(1, await btc.getNewAddress());

    print('3. Wait for the watcher to detect + push (3s sweep + index lag)');
    final push = await mockFcm.waitForFirstSend(timeout: Duration(seconds: 40));
    expect(push, isNotNull,
        reason: 'cosigner boarding watcher should push within the sweep window');
    final p = push!;
    expect(p.targetToken, equals(fakeToken));

    final data = p.data;
    expect(data, isNotNull);
    expect(data!['type'], equals('boarding_deposit'));
    expect(data['txid'], isNotEmpty);
    expect(int.parse(data['amount_sats']!), equals(400000));

    // Visible notification (tap-to-board), unlike the silent vtxo_received push.
    final message = p.body['message'] as Map<String, dynamic>;
    expect(message['notification'], isNotNull,
        reason: 'boarding push is a user-visible notification to tap');

    print('Boarding watcher push test complete!');
  }, timeout: Timeout(Duration(minutes: 3)));

  // Delegate persistence across cosigner restart (Phase 2, issue #31).
  //
  // Verifies the full round-trip:
  //   1. Alice stores a signed delegate intent via settleDelegate(storeOnly).
  //   2. Cosigner-runtime is killed + restarted against the same data_dir.
  //   3. listVtxos confirms `has_active_delegate=true` — rehydration ran
  //      `DelegateSettleSession::from_persisted` with the dkg_secret pulled
  //      from `SecretStore`, NOT from the persisted record.
  //   4. The auto-settle tick fires on the rehydrated session and drives
  //      it through a batch, producing a new VTXO with the same balance.
  //
  // The key correctness claim: the cosigner secret was never written to
  // the sled `delegate_sessions` tree. The rehydration path reattaches
  // it from `SecretStore` (`dkg-secret.<canonical>`), which already
  // existed in sled from the original DKG.
  test('Ark: delegate intent survives cosigner-runtime restart + auto-settles',
      () async {
    print('1. Alice DKG');
    final alice = createClient(storageId: "alice");
    await alice.doDkg();

    print('2. Fund boarding + settle');
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.003);
    await btc.generateToAddress(1, minerAddr);

    final boardingUtxos = await pollBoardingUtxos(boardingAddress, 300000);
    expect(boardingUtxos, isNotEmpty);

    bool stillMining = true;
    final miningTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!stillMining) {
        timer.cancel();
        return;
      }
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
    });
    final commitment = await alice.settle(boardingUtxos: boardingUtxos);
    expect(commitment, isNotEmpty);

    print('3. Wait for expires_at backfill');
    int originalExpiresAt = 0;
    String originalTxid = '';
    int originalBalance = 0;
    for (int i = 0; i < 20; i++) {
      final r = await alice.listVtxos();
      if (r.vtxos.isNotEmpty) {
        originalExpiresAt = r.vtxos.first.expiresAt.toInt();
        originalTxid = r.vtxos.first.txid;
        originalBalance = r.totalBalance.toInt();
      }
      if (originalExpiresAt > 0) break;
      await Future.delayed(Duration(seconds: 1));
    }
    expect(originalExpiresAt, greaterThan(0));

    print('4. settleDelegate(storeOnly: true) — persist signed intent to sled');
    final delegatedTxid = await alice.settleDelegate(storeOnly: true);
    expect(delegatedTxid, isEmpty);
    final beforeRestart = await alice.listVtxos();
    expect(beforeRestart.hasActiveDelegate, isTrue,
        reason: 'pre-restart: cosigner should report delegate as active');

    print('5. Kill cosigner-runtime');
    final oldProcess = serverProcess!;
    serverProcess = null;
    oldProcess.kill(ProcessSignal.sigterm);
    await oldProcess.exitCode;
    print('   cosigner-runtime exited; sled lock should be released');

    print('6. Restart against same data_dir — must rehydrate delegate');
    serverProcess = await startCosignerRuntime(
      serverPort,
      serverTempDir,
      extraEnv: cosignerExtraEnv,
    );

    print('7. listVtxos confirms delegate rehydrated from sled');
    final afterRestart = await alice.listVtxos();
    expect(afterRestart.hasActiveDelegate, isTrue,
        reason:
            'POST-RESTART: cosigner must rehydrate the signed delegate intent from sled. '
            'If false, either (a) delegate_sessions sled row missing, '
            '(b) SecretStore dkg-secret lookup failed, or '
            '(c) DelegateSettleSession::from_persisted rejected the record.');
    expect(afterRestart.vtxos.length, equals(1),
        reason: 'pre-restart VTXO must still be present post-restart');
    expect(afterRestart.vtxos.first.txid, equals(originalTxid),
        reason: 'rehydrated VTXO outpoint must match pre-restart');

    print(
        '8. Wait up to 4 minutes for tick to drive the rehydrated intent through a batch');
    String? newTxid;
    int newBalance = 0;
    bool stillActive = true;
    final deadline = DateTime.now().add(Duration(minutes: 4));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: 5));
      try {
        final resp = await alice.listVtxos();
        stillActive = resp.hasActiveDelegate;
        if (resp.vtxos.isNotEmpty) {
          newTxid = resp.vtxos.first.txid;
          newBalance = resp.totalBalance.toInt();
        }
        if (newTxid != null && newTxid != originalTxid && !stillActive) {
          break;
        }
      } catch (e) {
        print('   listVtxos error (will retry): $e');
      }
    }
    stillMining = false;
    miningTimer.cancel();

    expect(newTxid, isNotNull,
        reason: 'rehydrated auto-settle did not produce a VTXO update');
    expect(newTxid, isNot(equals(originalTxid)),
        reason:
            'rehydrated auto-settle must replace the original VTXO with a fresh one');
    expect(newBalance, equals(originalBalance),
        reason: 'rehydrated auto-settle must preserve the balance');
    expect(stillActive, isFalse,
        reason:
            'cosigner must clear the rehydrated delegate (sled + in-memory) after settle completes');

    print(
        '9. Delegate-persistence + rehydrated auto-settle complete: txid=$originalTxid → $newTxid');
  }, timeout: Timeout(Duration(minutes: 7)));

  // Cold-spawn auto-settle: prove the tick task itself spawns the actor
  // from sled, not by reading the in-memory DashMap.
  //
  // The previous test ('delegate intent survives cosigner-runtime restart')
  // calls `listVtxos` immediately after restart, which warms Alice's actor.
  // The tick would find her in the DashMap and fire — even if the sled-
  // iteration code were broken. This test instead waits for the tick to
  // happen WITHOUT any prior RPC against Alice. The first `listVtxos`
  // happens AFTER the wait; if it shows the new VTXO, the only thing
  // that could have driven the settle is the tick task spawning Alice
  // cold via the sled `delegate_sessions` iteration.
  //
  // Failure mode this guards against: a regression that switches the
  // tick back to `snapshot_handles()` (in-memory only). With that change,
  // a restarted Alice whose client hasn't reopened the app would still
  // have her delegate intent in sled but the tick would never find her
  // and her VTXO would eventually expire.
  test(
      'Ark: auto-settle tick cold-spawns user from sled after restart, no prior RPC',
      () async {
    print('1. Alice DKG');
    final alice = createClient(storageId: "alice");
    await alice.doDkg();

    print('2. Fund boarding + settle');
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.003);
    await btc.generateToAddress(1, minerAddr);

    final boardingUtxos = await pollBoardingUtxos(boardingAddress, 300000);
    expect(boardingUtxos, isNotEmpty);

    bool stillMining = true;
    final miningTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!stillMining) {
        timer.cancel();
        return;
      }
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
    });
    final commitment = await alice.settle(boardingUtxos: boardingUtxos);
    expect(commitment, isNotEmpty);

    print('3. Wait for expires_at backfill, then store delegate intent');
    int expiresAt = 0;
    String originalTxid = '';
    int originalBalance = 0;
    for (int i = 0; i < 20; i++) {
      final r = await alice.listVtxos();
      if (r.vtxos.isNotEmpty) {
        expiresAt = r.vtxos.first.expiresAt.toInt();
        originalTxid = r.vtxos.first.txid;
        originalBalance = r.totalBalance.toInt();
      }
      if (expiresAt > 0) break;
      await Future.delayed(Duration(seconds: 1));
    }
    expect(expiresAt, greaterThan(0));

    await alice.settleDelegate(storeOnly: true);
    final pre = await alice.listVtxos();
    expect(pre.hasActiveDelegate, isTrue);

    print('4. Kill cosigner-runtime');
    final oldProcess = serverProcess!;
    serverProcess = null;
    oldProcess.kill(ProcessSignal.sigterm);
    await oldProcess.exitCode;

    print('5. Restart cosigner-runtime');
    serverProcess = await startCosignerRuntime(
      serverPort,
      serverTempDir,
      extraEnv: cosignerExtraEnv,
    );

    // Critical: the next ~3 minutes must pass with NO RPC against Alice.
    // The only legitimate way her actor can spawn is via the sled-iterating
    // tick task we're testing. We keep mining so the ASP scheduler can
    // form batches once the cosigner-driven settle starts.
    //
    // Timing: the tick task skips its immediate fire, then ticks every
    // 60s, so the first tick lands ~60s after restart. If the sled
    // iteration finds Alice, it cold-spawns her and sends TickAutoSettle.
    // The handler then drives the batch (10-30s with active mining).
    // Total expected wall-clock: ~90-120s. We wait up to 3 minutes for
    // slack.
    print('6. Wait 3 minutes for cold-spawn tick to drive the settle');
    print('   (NOT calling any RPC against Alice during this window)');
    await Future.delayed(Duration(minutes: 3));

    print('7. First post-restart RPC against Alice — assert tick did the work');
    final post = await alice.listVtxos();
    stillMining = false;
    miningTimer.cancel();

    expect(post.vtxos, isNotEmpty,
        reason: 'Alice should still have a VTXO after the tick drove the settle');
    expect(post.vtxos.first.txid, isNot(equals(originalTxid)),
        reason:
            'COLD-SPAWN PROOF: if the tick task only iterated the in-memory '
            'DashMap, Alice would never have been spawned (no prior RPC), '
            'her delegate would never have fired, and the VTXO txid would '
            'still match the pre-restart original.');
    expect(post.totalBalance.toInt(), equals(originalBalance),
        reason: 'cold-spawn auto-settle must preserve balance');
    expect(post.hasActiveDelegate, isFalse,
        reason:
            'cold-spawn auto-settle must clear the delegate (sled + in-memory) on success');

    print(
        '8. Cold-spawn auto-settle proven: ${originalTxid.substring(0, 12)}…');
    print('   → ${post.vtxos.first.txid.substring(0, 12)}…');
  }, timeout: Timeout(Duration(minutes: 6)));
}
