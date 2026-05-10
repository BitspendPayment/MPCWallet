// One end-to-end testWidgets covering the full user lifecycle:
//   onboarding (DKG) → on-chain send → Ark board → recovery (re-DKG from blob).
//
// Recovery reuses the same `InMemoryBackupStore` that onboarding wrote into,
// so the restore flow downloads main flow's blob — no second fresh DKG.

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

  testWidgets(
    'full flow: onboarding → send → ark → recovery',
    (tester) async {
      const password = 'TestPassword!2026';
      final store = InMemoryBackupStore();
      final btc = RegtestHelper();
      await btc.ensureWalletLoaded('default');

      // ── Onboarding ───────────────────────────────────────────────────────
      await resetAppState();
      await bootApp(tester, backupStore: store);
      await Flows.completeOnboarding(tester, password: password);
      await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));
      expect(find.byKey(const Key('homeSendBtn')), findsOneWidget);

      final ctxOnboard = tester.element(find.byKey(const Key('homeSendBtn')));
      final originalAddress =
          Provider.of<MpcService>(ctxOnboard, listen: false).receiveAddress;
      expect(originalAddress, isNotNull);
      expect(await store.download(), isNotNull,
          reason: 'DKG should have uploaded an encrypted backup');

      // ── On-chain send ────────────────────────────────────────────────────
      await HomePage.tapReceive(tester);
      await pumpUntilFound(tester, find.byType(SelectableText));
      final receiveAddress =
          tester.widget<SelectableText>(find.byType(SelectableText)).data!;

      await btc.sendToAddress(receiveAddress, 0.01);
      final minerAddr = await btc.getNewAddress();
      await btc.generateToAddress(1, minerAddr);

      await tester.pageBack();
      await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));

      await waitForBalance(tester, BigInt.from(1000000));

      final destination = await btc.getNewAddress();
      await HomePage.tapSend(tester);
      await tester.pumpAndSettle();
      await SendPage.enterAddress(tester, destination);
      await SendPage.enterAmount(tester, '50000');
      await SendPage.tapReview(tester);
      await pumpUntilFound(tester, find.byKey(const Key('reviewSignBtn')));
      await ReviewPage.tapSign(tester);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('homeSendBtn')),
        timeout: const Duration(seconds: 90),
      );

      // ── Spending policy: create + verify enforcement ────────────────────
      const pin = '123456';

      await HomePage.tapPoliciesTab(tester);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('addPolicyBtn')));
      await PoliciesPage.tapAdd(tester);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('thresholdSlider')));
      await EditPolicyPage.dragThresholdToMin(tester);
      await EditPolicyPage.tapSave(tester);
      await pumpUntilFound(
          tester, find.byKey(const Key('createPolicyPinField')));
      await EditPolicyPage.enterPinAndAuthorize(tester, pin);

      // Edit screen pops back to /policies on success.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('addPolicyBtn')),
        timeout: const Duration(seconds: 60),
      );
      await tester.pumpAndSettle();
      final policiesCtx = tester.element(find.byKey(const Key('addPolicyBtn')));
      final policiesSvc =
          Provider.of<MpcService>(policiesCtx, listen: false);
      expect(policiesSvc.policies.length, greaterThanOrEqualTo(1),
          reason: 'one policy should exist after creation');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));

      // Under-threshold send (5000 sats < 10k threshold) — no PIN dialog.
      final underDest = await btc.getNewAddress();
      await HomePage.tapSend(tester);
      await tester.pumpAndSettle();
      await SendPage.enterAddress(tester, underDest);
      await SendPage.enterAmount(tester, '5000');
      await SendPage.tapReview(tester);
      await pumpUntilFound(tester, find.byKey(const Key('reviewSignBtn')));
      await ReviewPage.tapSign(tester);
      // Give signing a moment; assert PIN dialog never rendered.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('signingPinField')), findsNothing,
          reason: 'under-threshold send must not prompt for PIN');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('homeSendBtn')),
        timeout: const Duration(seconds: 90),
      );

      // Over-threshold send (50000 sats > 10k threshold) — PIN dialog expected.
      final overDest = await btc.getNewAddress();
      await HomePage.tapSend(tester);
      await tester.pumpAndSettle();
      await SendPage.enterAddress(tester, overDest);
      await SendPage.enterAmount(tester, '50000');
      await SendPage.tapReview(tester);
      await pumpUntilFound(tester, find.byKey(const Key('reviewSignBtn')));
      await ReviewPage.tapSign(tester);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('signingPinField')),
        timeout: const Duration(seconds: 30),
      );
      await SigningPinDialog.enterAndAuthorize(tester, pin);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('homeSendBtn')),
        timeout: const Duration(seconds: 90),
      );

      // ── Ark boarding (skipped when ASP not configured) ──────────────────
      await HomePage.tapArkTab(tester);
      await tester.pumpAndSettle();
      final arkAvailable = find.text('Ark Not Available').evaluate().isEmpty;
      if (!arkAvailable) {
        print('Ark not available — skipping ark sub-flow');
      } else {
        await ArkPage.tapBoard(tester);
        await pumpUntilFound(tester, find.byKey(const Key('arkBoardNowBtn')));

        final ctxBoard = tester.element(find.byKey(const Key('arkBoardNowBtn')));
        final svcBoard = Provider.of<MpcService>(ctxBoard, listen: false);
        final boardingAddress = svcBoard.boardingAddress;
        expect(boardingAddress, isNotNull,
            reason: 'boardingAddress should be populated by the ark wallet');

        await btc.sendToAddress(boardingAddress!, 0.005);
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
        expect(svcBoard.arkBalance > BigInt.zero, isTrue,
            reason: 'ark balance should be non-zero after boarding');
      }

      // ── Recovery: wipe, re-restore from the blob `store` already holds ──
      await tearDownTree(tester);
      await resetAppState();
      await bootApp(tester, backupStore: store);

      await pumpUntilFound(tester, find.byKey(const Key('welcomeRestoreBtn')));
      await WelcomePage.tapRestore(tester);
      await tester.pumpAndSettle();
      await SignerSelectionPage.pickSoftware(tester);
      await SignerSelectionPage.tapContinue(tester);
      await tester.pumpAndSettle();
      await GoogleSignInPage.signIn(tester);
      await tester.pumpAndSettle();

      await pumpUntilFound(tester, find.byKey(const Key('restoreContinueBtn')));
      await RestorePage.enterPassword(tester, password);
      await RestorePage.tapContinue(tester);

      await pumpUntilFound(tester, find.byKey(const Key('serverConnectBtn')));
      await ServerConnectPage.useDefault(tester);
      await tester.pumpAndSettle();
      await DkgProgressPage.waitForReady(tester,
          timeout: const Duration(minutes: 2));
      await WalletReadyPage.tapGoToWallet(tester);

      await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));
      final ctxPost = tester.element(find.byKey(const Key('homeSendBtn')));
      final svcPost = Provider.of<MpcService>(ctxPost, listen: false);
      expect(svcPost.dkgComplete, isTrue);
      expect(svcPost.receiveAddress, equals(originalAddress),
          reason: 'restored wallet should derive the same group verifying key');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
