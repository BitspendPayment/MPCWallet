import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:test/test.dart';
import 'package:app_core/ark_wallet.dart';
import 'package:app_core/client.dart';
import 'package:fixnum/fixnum.dart';
import 'package:app_core/hardware_signer.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

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

void main() {
  Process? serverProcess;
  late RegtestHelper btc;
  late ArkdAdmin arkd;
  late Directory tempDir;
  late Directory serverTempDir;
  late int serverPort;

  MpcClient createClient(HardwareSignerInterface signer, {String? storageId}) {
    return MpcClient.rest(
      'http://127.0.0.1:$serverPort',
      hardwareSigner: signer,
      storageId: storageId,
    );
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

    // 4. Start MPC Server with ASP_URL
    print('Starting MPC Server with ASP...');
    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_ark_server_');
    final serverReady = Completer<void>();
    final serverFailed = Completer<void>();
    serverProcess = await Process.start(
      '../cosigner-runtime/target/release/cosigner-runtime',
      [
        '--wasm',
        '../cosigner/target/wasm32-wasip1/release/cosigner.wasm',
        '--port',
        serverPort.toString(),
      ],
      mode: ProcessStartMode.normal,
      environment: {
        'ELECTRUM_URL': '127.0.0.1',
        'ELECTRUM_PORT': '50001',
        'BITCOIN_RPC_USER': 'admin1',
        'BITCOIN_RPC_PASSWORD': '123',
        'ASP_URL': 'http://127.0.0.1:7070',
        // Asserted by the GetServerInfo test below — set explicitly so the
        // expectation isn't dependent on the cosigner-runtime default.
        'BITCOIN_NETWORK': 'regtest',
        // Force the auto-settle threshold to be "always crossed" for any
        // realistic VTXO_TREE_EXPIRY. The tick task fires when
        // `now > expires_at - safety_margin`; with 1 hour margin and the
        // docker-compose's 512s expiry that's always true, so the next
        // 60-second tick after the intent is stored will drive the batch.
        'AUTO_SETTLE_SAFETY_MARGIN_SECS': '3600',
        'HOME': serverTempDir.path,
      },
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    serverProcess!.stdout.transform(utf8.decoder).listen((data) {
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
    serverProcess!.stderr.transform(utf8.decoder).listen((data) {
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
          throw Exception("MPC Server failed to start");
        }),
      ]).timeout(Duration(seconds: 30), onTimeout: () {
        throw Exception("MPC Server did not become ready in time");
      });
    } catch (e) {
      serverProcess?.kill();
      try {
        await serverTempDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
    print('--- Ark E2E Setup Complete ---');
  });

  tearDownAll(() async {
    serverProcess?.kill();
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
    final signer = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await signer.connect();
    final client = createClient(signer);

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
    final signer = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await signer.connect();
    final client = createClient(signer);

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
    final aliceSigner = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await aliceSigner.connect();
    final alice = createClient(aliceSigner);
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

    try {
      final commitmentTxid = await alice.settle();
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
    final bobSigner = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await bobSigner.connect();
    final bob = createClient(bobSigner);
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

    // 10. Create spending policy (limit 10k sats)
    print('10. Creating spending policy (limit 10,000 sats)');
    const pin = '123456';
    final limit = Int64(10000);
    final interval = Duration(hours: 1);
    await alice.createSpendingPolicy(interval, limit, pin);
    print('   Policy created');

    // 11. Send 20k sats WITHOUT PIN — should fail (policy triggered)
    print('11. Send 20k WITHOUT PIN (expect failure)');
    final sendAmount3 = 20000;
    bool failedWithoutPin = false;
    try {
      final unsigned3 = await aliceArkWallet.createTransaction(
        destination: bobArkAddress,
        amountSats: sendAmount3,
      );
      final signed3 = await aliceArkWallet.signTransaction(unsigned3);
      await aliceArkWallet.submit(signed3);
    } catch (e) {
      print('   Expected failure: $e');
      failedWithoutPin = true;
    }
    expect(failedWithoutPin, isTrue,
        reason: 'Should fail without PIN when policy is triggered');

    // 12. Send 20k sats WITH PIN — should succeed
    print('12. Send 20k WITH PIN');
    final unsigned4 = await aliceArkWallet.createTransaction(
      destination: bobArkAddress,
      amountSats: sendAmount3,
    );
    final policyId = await aliceArkWallet.getPolicyId(unsigned4);
    print('   policyId: $policyId');
    expect(policyId, isNotEmpty,
        reason: 'Policy should be triggered for 20k > 10k limit');
    final signed4 = await aliceArkWallet.signTransaction(
      unsigned4,
      policyId: policyId,
      pin: pin,
    );
    print('   Signed with PIN');
    final arkTxid4 = await aliceArkWallet.submit(signed4);
    print('   Send ark_txid: $arkTxid4');
    expect(arkTxid4, isNotEmpty);

    // 12b. Verify final balances
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

    // 13. Clean up — delete policy
    print('13. Deleting policy');
    final policy = alice.activeSpendingPolicy;
    expect(policy, isNotNull);
    await alice.deletePolicy(policy!.id);
    print('   Policy deleted');

    print('Full Ark E2E flow complete!');
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
    final aliceSigner = TcpHardwareSigner(host: '127.0.0.1', port: 9090);
    await aliceSigner.connect();
    final alice = createClient(aliceSigner);
    await alice.doDkg();

    print('2. Fund boarding + settle');
    final boardingAddress = await alice.getBoardingAddress();
    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress, 0.005);
    await btc.generateToAddress(1, minerAddr);
    await Future.delayed(Duration(seconds: 5));

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
      final commitment = await alice.settle();
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
}
