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

  /// Home → Send → Review → Sign → back to Home.
  static Future<void> doOnChainSend(
    WidgetTester tester, {
    required String destination,
    required String amountSats,
  }) async {
    await HomePage.tapSend(tester);
    await tester.pumpAndSettle();
    await SendPage.enterAddress(tester, destination);
    await SendPage.enterAmount(tester, amountSats);
    await SendPage.tapReview(tester);
    await pumpUntilFound(tester, find.byKey(const Key('reviewSignBtn')));
    await ReviewPage.tapSign(tester);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('homeSendBtn')),
      timeout: const Duration(seconds: 90),
    );
  }
}
