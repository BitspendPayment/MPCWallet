// UI verification that a stored delegate intent survives a cosigner-runtime
// restart AND that the cosigner's auto-settle tick drives it from the
// rehydrated session. Mirrors the e2e backend test "Ark: delegate intent
// survives cosigner-runtime restart + auto-settles".
//
//   1. Onboard + board + settle (foreground refresh stores a delegate)
//   2. Snapshot VTXO txid and balance, assert hasActiveDelegate=true
//   3. Restart cosigner
//   4. Assert hasActiveDelegate=true after restart (rehydrated from sled)
//   5. Wait ~90s for the cosigner tick task to drive the rehydrated intent
//   6. Assert VTXO txid changed (new settle landed), balance preserved,
//      hasActiveDelegate now false (delegate consumed on success)
//
// Lifecycle helper required — run via `make integration-test-lifecycle-ark`.
// Test env must set AUTO_SETTLE_SAFETY_MARGIN_SECS large enough that the
// tick fires immediately on any stored intent (default 1800 works with
// the docker-compose's ARKD_VTXO_TREE_EXPIRY=512).

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

  testWidgets('Delegate intent survives restart + auto-settles in UI',
      (tester) async {
    const password = 'TestPassword!2026';
    final store = InMemoryBackupStore();
    final btc = RegtestHelper();
    await btc.ensureWalletLoaded('default');
    final lifecycle = CosignerLifecycle();

    await lifecycle.start();
    await lifecycle.waitForRunning();

    // ── Onboard + board ─────────────────────────────────────────────────
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

    // Foreground refresh fires _delegateIfNeeded → stores delegate.
    await svc.refreshVtxos();
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!svc.hasActiveDelegate && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(svc.hasActiveDelegate, isTrue,
        reason: 'pre-restart: delegate must be stored after refresh');
    expect(svc.vtxos.length, equals(1));

    final originalTxid = svc.vtxos.first.txid;
    final originalBalance = svc.arkBalance;
    print('pre-restart: txid=$originalTxid balance=$originalBalance');

    // ── Restart cosigner ────────────────────────────────────────────────
    print('Restarting cosigner');
    await lifecycle.restart();
    await lifecycle.waitForRunning();
    await Future.delayed(const Duration(seconds: 2));

    // ── Verify delegate rehydrated ──────────────────────────────────────
    await svc.refreshVtxos();
    expect(svc.hasActiveDelegate, isTrue,
        reason:
            'POST-RESTART: delegate must rehydrate from sled. If false, '
            'either delegate_sessions row missing, SecretStore dkg-secret '
            'lookup failed, or DelegateSettleSession::from_persisted '
            'rejected the record (issue #31 path).');
    expect(svc.vtxos.length, equals(1),
        reason: 'VTXO must still be present immediately post-restart');
    expect(svc.vtxos.first.txid, equals(originalTxid),
        reason: 'pre/post outpoints must match before the auto-settle fires');

    // ── Wait for auto-settle tick ───────────────────────────────────────
    //
    // Cosigner ticks every 60s with the first tick skipped after boot, so
    // expect ~60-120s before the rehydrated intent gets driven. Mining
    // every 3s keeps the ASP scheduler ready to form a batch.
    print('Waiting up to 4 min for auto-settle tick to drive intent');
    final miningDeadline = DateTime.now().add(const Duration(minutes: 4));
    var newTxid = originalTxid;
    var stillActive = true;
    while (DateTime.now().isBefore(miningDeadline)) {
      try {
        await btc.generateToAddress(1, await btc.getNewAddress());
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
      await svc.refreshVtxos();
      if (svc.vtxos.isNotEmpty) {
        newTxid = svc.vtxos.first.txid;
      }
      stillActive = svc.hasActiveDelegate;
      if (newTxid != originalTxid && !stillActive) break;
    }

    expect(newTxid, isNot(equals(originalTxid)),
        reason:
            'rehydrated auto-settle must replace the original VTXO with a '
            'fresh one (different txid).');
    expect(svc.arkBalance, equals(originalBalance),
        reason: 'auto-settle must preserve balance');
    expect(stillActive, isFalse,
        reason:
            'cosigner must clear the delegate (sled + in-memory) once the '
            'settle completes.');

    print('Delegate-persistence UI test complete: $originalTxid → $newTxid');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
