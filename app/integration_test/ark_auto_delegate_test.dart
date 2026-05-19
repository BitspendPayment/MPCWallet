// UI verification of the foreground auto-delegate path.
//
// Mirrors the e2e backend test "Ark: auto-settle drives stored delegate
// intent without client" but proves the work fires through the Flutter app:
//
//   1. Onboard (DKG)
//   2. Board + settle into a VTXO
//   3. Refresh — this triggers _delegateIfNeeded which calls
//      settleDelegate(storeOnly: true) because vtxos exist and no
//      delegate is yet stored.
//   4. Assert MpcService.hasActiveDelegate flips to true.
//
// No cosigner restart involved — the lifecycle helper isn't used here.
// This guards the foreground path; the persistence + cold-spawn tests
// guard the rehydration path.

// ignore_for_file: avoid_print

import 'package:app/services/backup_store.dart';
import 'package:app/services/mpc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'test_helpers/flows.dart';
import 'test_helpers/page_objects.dart';
import 'test_helpers/regtest_helper.dart';
import 'test_helpers/test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Auto-delegate fires on foreground refresh after boarding settle',
      (tester) async {
    const password = 'TestPassword!2026';
    final store = InMemoryBackupStore();
    final btc = RegtestHelper();
    await btc.ensureWalletLoaded('default');

    // ── Onboarding ──────────────────────────────────────────────────────
    await resetAppState();
    await bootApp(tester, backupStore: store);
    await Flows.completeOnboarding(tester, password: password);
    await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));

    // ── Ark boarding ────────────────────────────────────────────────────
    await HomePage.tapArkTab(tester);
    await tester.pumpAndSettle();
    final arkAvailable = find.text('Ark Not Available').evaluate().isEmpty;
    if (!arkAvailable) {
      print('Ark not available — skipping (ASP not configured)');
      return;
    }

    await ArkPage.tapBoard(tester);
    await pumpUntilFound(tester, find.byKey(const Key('arkBoardNowBtn')));

    final ctx = tester.element(find.byKey(const Key('arkBoardNowBtn')));
    final svc = Provider.of<MpcService>(ctx, listen: false);
    final boardingAddress = svc.boardingAddress;
    expect(boardingAddress, isNotNull);

    final minerAddr = await btc.getNewAddress();
    await btc.sendToAddress(boardingAddress!, 0.005);
    await btc.generateToAddress(1, minerAddr);

    await ArkBoardPage.waitForFundsDetected(tester);
    await ArkBoardPage.tapBoardNow(tester);

    // No spending policy in this test → no PIN prompt → board lands
    // directly on the done screen. Allow up to 2 min for the ASP batch.
    await pumpUntilFound(
      tester,
      find.byKey(const Key('arkBoardDoneBtn')),
      timeout: const Duration(minutes: 2),
    );
    await ArkBoardPage.tapDone(tester);
    await pumpUntilFound(tester, find.byKey(const Key('arkSendBtn')));
    expect(svc.arkBalance > BigInt.zero, isTrue,
        reason: 'ark balance should be non-zero after boarding');

    // ── Verify auto-delegate fired ──────────────────────────────────────
    //
    // The MpcService's refreshVtxos triggers _delegateIfNeeded at the end,
    // which checks (a) vtxos non-empty and (b) !_serverHasActiveDelegate.
    // After boarding settles, both conditions are true, so a re-delegate
    // call should fire. Poll until hasActiveDelegate flips true.
    //
    // Force one explicit refresh so we don't depend on whatever polling
    // cadence the screen is using.
    await svc.refreshVtxos();

    var deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!svc.hasActiveDelegate && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(svc.hasActiveDelegate, isTrue,
        reason:
            'After boarding + refresh, MpcService should have stored a '
            'delegate intent via _delegateIfNeeded. If false, either '
            '_delegateIfNeeded did not fire (check the guard conditions) '
            'or the cosigner refused to store the intent.');

    print('Auto-delegate UI test complete');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
