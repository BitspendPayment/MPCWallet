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
    await ServerConnectPage.useDefault(tester);
    await tester.pumpAndSettle();
    await DkgProgressPage.waitForReady(tester);
    await WalletReadyPage.tapGoToWallet(tester);
    await tester.pumpAndSettle();
  }
}
