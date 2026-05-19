// One end-to-end testWidgets covering the full user lifecycle:
//   onboarding (DKG) → on-chain send → Ark board → recovery (re-DKG from blob).
//
// Recovery reuses the same `InMemoryBackupStore` that onboarding wrote into,
// so the restore flow downloads main flow's blob — no second fresh DKG.

// ignore_for_file: avoid_print

import 'package:app/services/backup_store.dart';
import 'package:app/services/mpc_service.dart';
import 'package:app/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'test_helpers/bob_client.dart';
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

      final underDest = await btc.getNewAddress();
      await HomePage.tapSend(tester);
      await tester.pumpAndSettle();
      await SendPage.enterAddress(tester, underDest);
      await SendPage.enterAmount(tester, '5000');
      await SendPage.tapReview(tester);
      await pumpUntilFound(tester, find.byKey(const Key('reviewSignBtn')));
      await ReviewPage.tapSign(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('signingPinField')), findsNothing,
          reason: 'under-threshold send must not prompt for PIN');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('homeSendBtn')),
        timeout: const Duration(seconds: 90),
      );

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
        // Policy-bypass regression guard (commit bbb692b). Boarding settles
        // a boarding output into a VTXO — settling never applies a spending
        // policy. The server's SignStep1 forces selected_policy_id=None
        // whenever a settle_session/delegate_session is in flight (see
        // sign.rs). Confirm no PIN field ever pops during the next ~3s.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byKey(const Key('signingPinField')), findsNothing,
              reason:
                  'REGRESSION: boarding (500k sats, well over the 10k '
                  'policy threshold) prompted for PIN — policies must not '
                  'gate settling.');
        }
        await pumpUntilFound(
          tester,
          find.byKey(const Key('arkBoardDoneBtn')),
          timeout: const Duration(minutes: 2),
        );
        await ArkBoardPage.tapDone(tester);
        await pumpUntilFound(tester, find.byKey(const Key('arkSendBtn')));
        expect(svcBoard.arkBalance > BigInt.zero, isTrue,
            reason: 'ark balance should be non-zero after boarding');

        // Auto-delegate regression guard. MpcService.refreshVtxos() ends
        // with _delegateIfNeeded, which calls settleDelegate(storeOnly:
        // true) when vtxos are non-empty and no delegate is yet stored.
        // After boarding settles, both conditions are true → delegate
        // should be stored within seconds.
        await svcBoard.refreshVtxos();
        final delegDeadline =
            DateTime.now().add(const Duration(seconds: 30));
        while (!svcBoard.hasActiveDelegate &&
            DateTime.now().isBefore(delegDeadline)) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(svcBoard.hasActiveDelegate, isTrue,
            reason:
                'after boarding + refresh, _delegateIfNeeded must have '
                'stored a delegate intent. If false, the foreground '
                'auto-delegate path regressed.');

        // ── Ark send (App → Bob, an external ark-sample wallet) ─────
        final bob = BobClient();
        final bobArkAddress = await bob.arkAddress();
        final bobBalanceBefore = await bob.spendableSats();
        final appArkBalanceBefore = svcBoard.arkBalance;

        await ArkPage.tapSend(tester);
        await pumpUntilFound(tester, find.byKey(const Key('arkSendVtxoBtn')));
        await ArkSendPage.enterAddress(tester, bobArkAddress);
        await ArkSendPage.enterAmount(tester, '5000');
        await ArkSendPage.tapSend(tester);
        // Cumulative spending in the 24h window already exceeds the 10k
        // threshold (50k on-chain over-threshold + 500k boarding both went
        // into the spending history), so even a 5k Ark send triggers PIN.
        await pumpUntilFound(
          tester,
          find.byKey(const Key('signingPinField')),
          timeout: const Duration(seconds: 30),
        );
        await SigningPinDialog.enterAndAuthorize(tester, pin);
        await pumpUntilFound(
          tester,
          find.byKey(const Key('arkSendBtn')),
          timeout: const Duration(seconds: 90),
        );
        expect(svcBoard.arkBalance < appArkBalanceBefore, isTrue,
            reason: 'app ark balance should drop after sending to Bob');

        // Poll Bob's balance — the off-chain transfer settles in <30s.
        final bobDeadline = DateTime.now().add(const Duration(seconds: 30));
        var bobNow = await bob.spendableSats();
        while (bobNow < bobBalanceBefore + 5000 &&
            DateTime.now().isBefore(bobDeadline)) {
          await tester.pump(const Duration(seconds: 2));
          bobNow = await bob.spendableSats();
        }
        expect(bobNow, greaterThanOrEqualTo(bobBalanceBefore + 5000),
            reason: 'Bob should have received the 5000-sat VTXO');

        // ── Ark receive (Bob → App) ─────────────────────────────────
        // Send small (3000 sats) — Bob's boarding-output settle into VTXO is
        // currently flaky in ark-client-sample, so he only has the change/
        // received VTXOs. 3000 fits comfortably under that.
        final myArkAddress = svcBoard.arkAddress!;
        final appArkBalanceMid = svcBoard.arkBalance;
        await bob.sendTo(myArkAddress, 3000);
        await waitForArkBalance(
          tester,
          appArkBalanceMid + BigInt.from(2500),
          timeout: const Duration(seconds: 60),
        );

        // ── Background push handler ─────────────────────────────────
        // 1500 sats fits Bob's residual budget after the 3000-sat send
        // above; deliberately no refreshVtxos before the handler call
        // (it would fire foreground _delegateIfNeeded and steal the work).
        final preBgArkBalance = svcBoard.arkBalance;
        await bob.sendTo(myArkAddress, 1500);
        await Future<void>.delayed(const Duration(seconds: 15));

        await PushService.handleBackgroundMessageForTest(const {
          'type': 'vtxo_received',
          'user_id': '',
        });

        await svcBoard.refreshVtxos();
        final bgDeadline = DateTime.now().add(const Duration(seconds: 30));
        while (!svcBoard.hasActiveDelegate &&
            DateTime.now().isBefore(bgDeadline)) {
          await tester.pump(const Duration(seconds: 1));
          await svcBoard.refreshVtxos();
        }
        expect(svcBoard.arkBalance, greaterThanOrEqualTo(
            preBgArkBalance + BigInt.from(1000)),
            reason: 'Alice should hold Bob\'s 1500-sat VTXO (after fees)');
        expect(svcBoard.hasActiveDelegate, isTrue,
            reason:
                'after PushService.handleBackgroundMessageForTest ran, '
                'the cosigner should hold a stored delegate covering '
                'Bob\'s fresh outpoint. If false, _runBackgroundDelegate '
                'failed somewhere — Hive open in the background isolate, '
                'MpcClient.restoreState(), or the FROST sign round of '
                'settleDelegate(storeOnly:true).');
      }

      // ── Policy: delete, then a fresh 30s-window policy to prove rollover ─
      // Get back to Home (we may be on the Ark screen).
      await HomePage.tapHomeTab(tester);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));

      // Delete the 10k policy created earlier (recovery-key authorised).
      await HomePage.tapPoliciesTab(tester);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('deletePolicyBtn_0')));
      await PoliciesPage.tapDelete(tester, index: 0);
      await tester.pumpAndSettle();
      await PoliciesPage.confirmDelete(tester);
      await tester.pumpAndSettle();
      await pumpUntilFound(
          tester, find.byKey(const Key('recoveryPasswordField')));
      await RecoveryPasswordDialog.enterAndOk(tester, password);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('addPolicyBtn')),
        timeout: const Duration(seconds: 60),
      );
      await tester.pumpAndSettle();
      final delCtx = tester.element(find.byKey(const Key('addPolicyBtn')));
      final delSvc = Provider.of<MpcService>(delCtx, listen: false);
      await pumpUntilTrue(
        tester,
        () => delSvc.policies.isEmpty && delSvc.activePolicy == null,
        timeout: const Duration(seconds: 30),
        reason: 'policy should be gone after delete',
      );

      // Verify the deleted policy is not enforced: a send of any size, no PIN.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));
      await Flows.doOnChainSend(
        tester,
        destination: await btc.getNewAddress(),
        amountSats: '6000',
        expectPin: false,
        pin: pin,
      );

      // Create a 30s-window, min-threshold (~10k) policy.
      await HomePage.tapPoliciesTab(tester);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('addPolicyBtn')));
      await PoliciesPage.tapAdd(tester);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('thresholdSlider')));
      await EditPolicyPage.pickInterval(tester, '30 Sec');
      await EditPolicyPage.dragThresholdToMin(tester);
      await EditPolicyPage.tapSave(tester);
      await pumpUntilFound(
          tester, find.byKey(const Key('createPolicyPinField')));
      await EditPolicyPage.enterPinAndAuthorize(tester, pin);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('addPolicyBtn')),
        timeout: const Duration(seconds: 60),
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('homeSendBtn')));

      // Inside the 30s window: 6k alone is under threshold (no PIN), but a
      // second 6k makes the cumulative 12k > 10k → PIN. Proves aggregation.
      await Flows.doOnChainSend(
        tester,
        destination: await btc.getNewAddress(),
        amountSats: '6000',
        expectPin: false,
        pin: pin,
      );
      await Flows.doOnChainSend(
        tester,
        destination: await btc.getNewAddress(),
        amountSats: '6000',
        expectPin: true,
        pin: pin,
      );

      // Let the 30s window roll over (real wall-clock — the policy engine
      // reads SystemTime, not the test's frame clock). Cumulative resets to 0.
      await Future<void>.delayed(const Duration(seconds: 35));
      await tester.pump();
      await Flows.doOnChainSend(
        tester,
        destination: await btc.getNewAddress(),
        amountSats: '6000',
        expectPin: false, // cumulative reset → 0 + 6000 < 10000
        pin: pin,
      );
      await btc.generateToAddress(1, minerAddr);

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
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
