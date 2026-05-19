// UI verification that the cosigner-runtime can restart underneath a
// running Flutter app without losing per-user state (VTXOs, balance,
// boarding address). Mirrors the e2e backend test "Ark: cosigner-runtime
// restart preserves rehydrated state".
//
//   1. Onboard + board + settle into a VTXO via the UI
//   2. Snapshot ark balance + VTXO outpoints from MpcService
//   3. POST /restart to the lifecycle helper (host-side Python service)
//   4. Wait for cosigner to be running again, force refresh
//   5. Assert balance + VTXO outpoints match pre-restart
//
// Lifecycle helper required — run via `make integration-test-lifecycle-ark`.

// ignore_for_file: avoid_print

import 'package:app/services/backup_store.dart';
import 'package:app/services/mpc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'test_helpers/flows.dart';
import 'test_helpers/lifecycle_helper.dart';
import 'test_helpers/page_objects.dart';
import 'test_helpers/regtest_helper.dart';
import 'test_helpers/test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cosigner restart preserves UI state', (tester) async {
    const password = 'TestPassword!2026';
    final store = InMemoryBackupStore();
    final btc = RegtestHelper();
    await btc.ensureWalletLoaded('default');
    final lifecycle = CosignerLifecycle();

    // Make sure the cosigner is running before we start onboarding.
    await lifecycle.start();
    await lifecycle.waitForRunning();

    // ── Onboard + board + settle ────────────────────────────────────────
    await resetAppState();
    await bootApp(tester, backupStore: store);
    await Flows.completeOnboarding(tester, password: password);
    await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));

    await HomePage.tapArkTab(tester);
    await tester.pumpAndSettle();
    if (find.text('Ark Not Available').evaluate().isNotEmpty) {
      print('Ark not available — skipping');
      return;
    }

    await ArkPage.tapBoard(tester);
    await pumpUntilFound(tester, find.byKey(const Key('arkBoardNowBtn')));

    final ctx = tester.element(find.byKey(const Key('arkBoardNowBtn')));
    final svc = Provider.of<MpcService>(ctx, listen: false);
    final boardingAddress = svc.boardingAddress!;
    final minerAddr = await btc.getNewAddress();

    await btc.sendToAddress(boardingAddress, 0.005);
    await btc.generateToAddress(1, minerAddr);
    await ArkBoardPage.waitForFundsDetected(tester);
    await ArkBoardPage.tapBoardNow(tester);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('arkBoardDoneBtn')),
      timeout: const Duration(minutes: 2),
    );
    await ArkBoardPage.tapDone(tester);
    await pumpUntilFound(tester, find.byKey(const Key('arkSendBtn')));
    expect(svc.arkBalance > BigInt.zero, isTrue);

    // ── Snapshot pre-restart state ──────────────────────────────────────
    await svc.refreshVtxos();
    final preBalance = svc.arkBalance;
    final preOutpoints =
        svc.vtxos.map((v) => '${v.txid}:${v.vout}').toSet();
    print('pre-restart: balance=$preBalance vtxos=${preOutpoints.length}');
    expect(preOutpoints, isNotEmpty);

    // ── Restart cosigner ────────────────────────────────────────────────
    print('Restarting cosigner via lifecycle helper');
    await lifecycle.restart();
    await lifecycle.waitForRunning();
    // Give the cosigner an extra moment to fully bind its REST port +
    // reconnect to the ASP stream before we hit it.
    await Future.delayed(const Duration(seconds: 2));

    // ── Verify state survived ───────────────────────────────────────────
    await svc.refreshVtxos();
    final postBalance = svc.arkBalance;
    final postOutpoints =
        svc.vtxos.map((v) => '${v.txid}:${v.vout}').toSet();
    print('post-restart: balance=$postBalance vtxos=${postOutpoints.length}');

    expect(postBalance, equals(preBalance),
        reason: 'ark balance must survive cosigner restart');
    expect(postOutpoints, equals(preOutpoints),
        reason:
            'VTXO outpoints must survive cosigner restart (sled `vtxo_store` '
            'is loaded by `registry::get_or_spawn`). If this fails, the '
            'rehydration path in get_or_spawn likely regressed.');

    // Sanity: post-restart RPCs still work — getArkAddress requires the
    // policy to be loadable via ensure_policy_loaded after the fresh spawn.
    expect(svc.arkAddress, isNotEmpty);

    print('Restart-survival UI test complete');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
