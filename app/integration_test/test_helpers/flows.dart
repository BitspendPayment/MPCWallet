import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_objects.dart';
import 'test_setup.dart';

class Flows {
  static Future<void> completeOnboarding(
    WidgetTester tester, {
    required String password,
  }) async {
    await pumpUntilFound(
      tester,
      find.byKey(const Key('welcomeCreateBtn')),
      timeout: const Duration(seconds: 30),
    );
    await WelcomePage.tapCreate(tester);
    await tester.pumpAndSettle();
    await SignerSelectionPage.pickSoftware(tester);
    await SignerSelectionPage.tapContinue(tester);
    await tester.pumpAndSettle();
    await PasswordPage.enter(tester, password);
    await tester.pumpAndSettle();
    await GoogleSignInPage.signIn(tester);
    await tester.pumpAndSettle();
    await ServerConnectPage.pickRegtest(tester);
    // Don't pumpAndSettle here — the DKG screen has a CircularProgressIndicator
    // that never "settles" until DKG completes, so pumpAndSettle would block
    // (up to its 10-min cap). waitForReady polls via pump() instead, which is
    // unaffected by ongoing animations.
    await DkgProgressPage.waitForReady(
      tester,
      timeout: const Duration(minutes: 3),
    );
    await WalletReadyPage.tapGoToWallet(tester);
    await tester.pumpAndSettle();
  }

  /// Home → Send → Review → Sign → (maybe PIN) → back to Home.
  ///
  /// Asserts the spending-policy PIN dialog is present-or-absent according to
  /// [expectPin] — this is how the test pins down policy enforcement.
  static Future<void> doOnChainSend(
    WidgetTester tester, {
    required String destination,
    required String amountSats,
    required bool expectPin,
    String pin = '123456',
  }) async {
    await HomePage.tapSend(tester);
    await tester.pumpAndSettle();
    await SendPage.enterAddress(tester, destination);
    await SendPage.enterAmount(tester, amountSats);
    await SendPage.tapReview(tester);
    await pumpUntilFound(tester, find.byKey(const Key('reviewSignBtn')));
    await ReviewPage.tapSign(tester);
    if (expectPin) {
      await pumpUntilFound(
        tester,
        find.byKey(const Key('signingPinField')),
        timeout: const Duration(seconds: 30),
      );
      await SigningPinDialog.enterAndAuthorize(tester, pin);
    } else {
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('signingPinField')), findsNothing,
          reason: 'send of $amountSats sats must not prompt for PIN');
    }
    await pumpUntilFound(
      tester,
      find.byKey(const Key('homeSendBtn')),
      timeout: const Duration(seconds: 90),
    );
  }
}
