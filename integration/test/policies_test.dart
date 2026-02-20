import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:grpc/grpc.dart';
import 'package:threshold/threshold.dart' as threshold;
import 'package:client/client.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:fixnum/fixnum.dart';
import 'package:hive/hive.dart';

import 'package:server/server.dart';
import 'package:server/bitcoin.dart';
import 'package:server/bitcoin_service.dart';
import 'package:server/persistence/store.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Runs DKG, derives P2TR address, builds and broadcasts a funding tx.
/// Returns (client, p2trAddress, utxoTxId).
Future<(MpcClient, P2trAddress, String)> setupDkgAndFund(
    ClientChannel channel, int fundingSats) async {
  final client = MpcClient(channel, minSigners: 2, maxSigners: 3);
  await client.doDkg();

  final pubKeyPkg = client.getTweakedPublicKeyPackage(null)!;
  final point = pubKeyPkg.verifyingKey.E;
  final pointBytes = threshold.elemSerializeCompressed(point);
  final ecPub = ECPublic.fromHex(BytesUtils.toHexString(pointBytes));
  final p2tr = P2trAddress.fromProgram(
      program: BytesUtils.toHexString(ecPub.toXOnly()));

  // Build funding tx
  final output = TxOutput(
      amount: BigInt.from(fundingSats),
      scriptPubKey: p2tr.toScriptPubKey());
  final input = TxInput(
    txId: "00" * 32,
    txIndex: 0,
    scriptSig: Script(script: []),
  );
  final fundingTx = BtcTransaction(inputs: [input], outputs: [output]);
  await client.broadcastTransaction(fundingTx.serialize());

  // Mock bitcoind always returns this txid
  const utxoTxId =
      "0000000000000000000000000000000000000000000000000000000000000001";

  return (client, p2tr, utxoTxId);
}

/// Builds a spend transaction. Returns (fullTxBytes, dummySighash).
(List<int>, Uint8List) buildSpendTx({
  required String utxoTxId,
  required int inputAmount,
  required int spendAmount,
  required P2trAddress changeAddress,
  int msgByte = 1,
}) {
  final spendInput = TxInput(
    txId: utxoTxId,
    txIndex: 0,
    scriptSig: Script(script: []),
  );
  final destOutput = TxOutput(
      amount: BigInt.from(spendAmount),
      scriptPubKey:
          P2trAddress.fromProgram(program: "00" * 32).toScriptPubKey());

  final changeValue = inputAmount - spendAmount;
  final outputs = <TxOutput>[destOutput];
  if (changeValue > 0) {
    outputs.add(TxOutput(
        amount: BigInt.from(changeValue),
        scriptPubKey: changeAddress.toScriptPubKey()));
  }

  final tx = BtcTransaction(inputs: [spendInput], outputs: outputs);
  final fullTxBytes = BytesUtils.fromHexString(tx.serialize());
  final sighash = Uint8List.fromList(List.filled(32, msgByte));
  return (fullTxBytes, sighash);
}

/// Signs with PIN: gets policyId, then signs.
Future<threshold.Signature> signWithPin(
    MpcClient client, Uint8List msg, List<int> fullTx, String pin) async {
  final policyId =
      await client.getPolicyId(Uint8List.fromList(fullTx));
  return await client.sign(msg,
      fullTransaction: fullTx, pin: pin, policyId: policyId);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Server server;
  late ClientChannel channel;
  late HttpServer mockBitcoind;
  Directory? tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync("policies_test_");
    Hive.init(tempDir!.path);

    // Mock Bitcoind
    mockBitcoind = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    mockBitcoind.listen((request) async {
      final content = await utf8.decoder.bind(request).join();
      final json = jsonDecode(content);
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          "result": json['method'] == 'sendrawtransaction'
              ? "0000000000000000000000000000000000000000000000000000000000000001"
              : null,
          "error": null,
          "id": json['id']
        }))
        ..close();
    });

    final dkgStore = DKGSessionStore();
    final policyStore = PolicyStore();
    final refreshStore = RefreshSessionStore();
    final signingStore = SigningSessionStore();
    final utxoStore = UtxoStore();
    await dkgStore.init();
    await policyStore.init();
    await refreshStore.init();
    await signingStore.init();
    await utxoStore.init();

    final service = MPCWalletService(
        dkgStore: dkgStore,
        signingStore: signingStore,
        refreshStore: refreshStore,
        policyStore: policyStore,
        utxoStore: utxoStore,
        bitcoinService: BitcoinService(utxoStore,
            rpcUrl: "http://localhost:${mockBitcoind.port}",
            rpcUser: "admin1",
            rpcPassword: "123"),
        historyService: BitcoinHistoryService());

    server = Server.create(services: [service]);
    await server.serve(port: 0);
    channel = ClientChannel(
      'localhost',
      port: server.port!,
      options:
          const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
  });

  tearDown(() async {
    await channel.shutdown();
    await server.shutdown();
    await mockBitcoind.close();
    await Hive.close();
    if (tempDir != null && tempDir!.existsSync()) {
      tempDir!.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // Group 1: Boundary Amount Tests
  // -------------------------------------------------------------------------
  group('Boundary Amounts', () {
    test('Spend exactly at threshold passes without PIN', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend exactly 1000 sats — server uses > (not >=), so this should pass
      final (fullTx, msg) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 1000,
          changeAddress: p2tr,
          msgByte: 1);

      final sig = await client.sign(msg, fullTransaction: fullTx);
      expect(sig, isNotNull);
    });

    test('Spend 1 sat over threshold triggers policy', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend 1001 sats — 1001 > 1000, should trigger
      final (fullTx, msg) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 1001,
          changeAddress: p2tr,
          msgByte: 1);

      // Normal sign should fail
      try {
        await client.sign(msg, fullTransaction: fullTx);
        fail("Should have thrown");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Retry with PIN should succeed
      final sig = await signWithPin(client, msg, fullTx, "123456");
      expect(sig, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Group 2: Time Window Reset
  // -------------------------------------------------------------------------
  group('Time Window', () {
    test('Spending resets after time window elapses', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      // 2-second interval, 500 sats threshold
      await client.createSpendingPolicy(
          const Duration(seconds: 2), Int64(500), "123456");

      // Spend 400 sats — under threshold, should pass
      final (fullTx1, msg1) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 400,
          changeAddress: p2tr,
          msgByte: 1);
      final sig1 = await client.sign(msg1, fullTransaction: fullTx1);
      expect(sig1, isNotNull);

      // Spend 200 sats — cumulative 600 > 500, should fail
      final (fullTx2, msg2) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 200,
          changeAddress: p2tr,
          msgByte: 2);
      try {
        await client.sign(msg2, fullTransaction: fullTx2);
        fail("Should have thrown — cumulative 600 > 500");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Wait for window to elapse
      await Future.delayed(const Duration(seconds: 3));

      // New window — spend 200 sats should pass (cumulative resets to 200)
      final (fullTx3, msg3) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 200,
          changeAddress: p2tr,
          msgByte: 3);
      final sig3 = await client.sign(msg3, fullTransaction: fullTx3);
      expect(sig3, isNotNull);
    }, timeout: Timeout(Duration(seconds: 30)));
  });

  // -------------------------------------------------------------------------
  // Group 3: Multiple Policies
  // -------------------------------------------------------------------------
  group('Multiple Policies', () {
    test('Stricter policy triggers when violated', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      // Policy A: loose (2000 sats threshold)
      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(2000), "123456");

      // Policy B: strict (500 sats threshold)
      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(500), "654321");

      // Spend 600 sats — exceeds B (500) but not A (2000)
      final (fullTx, msg) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 600,
          changeAddress: p2tr,
          msgByte: 1);

      // Should fail — a policy is triggered
      try {
        await client.sign(msg, fullTransaction: fullTx);
        fail("Should have thrown — exceeds policy B threshold");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Retry with correct PIN for the triggered policy
      final policyId =
          await client.getPolicyId(Uint8List.fromList(fullTx));
      expect(policyId, isNotEmpty);

      // Sign with the correct PIN for the triggered policy
      // Policy B used PIN "654321"
      final sig = await client.sign(msg,
          fullTransaction: fullTx, pin: "654321", policyId: policyId);
      expect(sig, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Group 4: Wrong PIN
  // -------------------------------------------------------------------------
  group('Wrong PIN', () {
    test('Wrong PIN causes invalid signature', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend 1500 sats — exceeds threshold
      final (fullTx, msg) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 1500,
          changeAddress: p2tr,
          msgByte: 1);

      // Normal sign fails (expected)
      try {
        await client.sign(msg, fullTransaction: fullTx);
        fail("Should have thrown");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Wrong PIN should also fail
      final policyId =
          await client.getPolicyId(Uint8List.fromList(fullTx));
      try {
        await client.sign(msg,
            fullTransaction: fullTx, pin: "999999", policyId: policyId);
        fail("Should have thrown — wrong PIN");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Correct PIN succeeds
      final sig = await client.sign(msg,
          fullTransaction: fullTx, pin: "123456", policyId: policyId);
      expect(sig, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Group 5: Cumulative Spending
  // -------------------------------------------------------------------------
  group('Cumulative Spending', () {
    test('Multiple small spends within threshold all succeed', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend 200, 300, 400 — cumulative 200, 500, 900 — all under 1000
      for (var i = 0; i < 3; i++) {
        final amounts = [200, 300, 400];
        final (fullTx, msg) = buildSpendTx(
            utxoTxId: utxoTxId,
            inputAmount: 10000,
            spendAmount: amounts[i],
            changeAddress: p2tr,
            msgByte: i + 1);
        final sig = await client.sign(msg, fullTransaction: fullTx);
        expect(sig, isNotNull, reason: 'Spend ${amounts[i]} should succeed');
      }
    });

    test('Cumulative small spends exceeding threshold triggers policy',
        () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend 500 sats — under threshold
      final (fullTx1, msg1) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 500,
          changeAddress: p2tr,
          msgByte: 1);
      final sig1 = await client.sign(msg1, fullTransaction: fullTx1);
      expect(sig1, isNotNull);

      // Spend 600 sats — cumulative 1100 > 1000, should fail
      final (fullTx2, msg2) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 600,
          changeAddress: p2tr,
          msgByte: 2);
      try {
        await client.sign(msg2, fullTransaction: fullTx2);
        fail("Should have thrown — cumulative 1100 > 1000");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Retry with PIN
      final sig2 = await signWithPin(client, msg2, fullTx2, "123456");
      expect(sig2, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Group 6: Policy Creation Ordering
  // -------------------------------------------------------------------------
  group('Policy Creation Ordering', () {
    test('Policy created before any spending works', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      // Create policy FIRST — no prior spending
      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend 500 sats — fresh window, 500 <= 1000
      final (fullTx, msg) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 500,
          changeAddress: p2tr,
          msgByte: 1);
      final sig = await client.sign(msg, fullTransaction: fullTx);
      expect(sig, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Group 7: Large Single Transaction
  // -------------------------------------------------------------------------
  group('Large Single Transaction', () {
    test('Single transaction exceeding threshold triggers policy immediately',
        () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend 5000 sats in first tx — 5000 > 1000
      final (fullTx, msg) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 5000,
          changeAddress: p2tr,
          msgByte: 1);

      try {
        await client.sign(msg, fullTransaction: fullTx);
        fail("Should have thrown — 5000 > 1000");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Retry with PIN
      final sig = await signWithPin(client, msg, fullTx, "123456");
      expect(sig, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Group 8: PIN-Authorized Spending History
  // -------------------------------------------------------------------------
  group('PIN-Authorized Spending History', () {
    test('PIN-authorized spend is recorded in spending history', () async {
      final (client, p2tr, utxoTxId) =
          await setupDkgAndFund(channel, 10000);

      await client.createSpendingPolicy(
          const Duration(seconds: 60), Int64(1000), "123456");

      // Spend 1500 sats — exceeds threshold, sign with PIN
      final (fullTx1, msg1) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 1500,
          changeAddress: p2tr,
          msgByte: 1);

      // First attempt without PIN fails
      try {
        await client.sign(msg1, fullTransaction: fullTx1);
        fail("Should have thrown");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }

      // Sign with PIN — succeeds, 1500 sats should be recorded in history
      final sig1 = await signWithPin(client, msg1, fullTx1, "123456");
      expect(sig1, isNotNull);

      // Now spend just 200 sats — cumulative = 1500 + 200 = 1700 > 1000
      // This proves the PIN-authorized spend was recorded in history
      final (fullTx2, msg2) = buildSpendTx(
          utxoTxId: utxoTxId,
          inputAmount: 10000,
          spendAmount: 200,
          changeAddress: p2tr,
          msgByte: 2);

      try {
        await client.sign(msg2, fullTransaction: fullTx2);
        fail("Should have thrown — cumulative 1700 > 1000");
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('invalid signature'));
      }
    });
  });
}
