import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_setup.dart';

Future<void> _tapKey(WidgetTester tester, String keyName) async {
  // Wait until the widget is in the tree AND actually hit-testable (i.e. not
  // behind a route-transition Offstage/AbsorbPointer overlay). pumpAndSettle
  // alone has been observed to return while the outgoing route is still
  // absorbing pointer events.
  final hit = find.byKey(Key(keyName)).hitTestable();
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (hit.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (hit.evaluate().isEmpty) {
    throw StateError('_tapKey: $keyName never became hit-testable');
  }
  await tester.tap(hit);
  await tester.pump();
}

Future<void> _enterText(
    WidgetTester tester, String keyName, String text) async {
  await tester.enterText(find.byKey(Key(keyName)), text);
  await tester.pump();
}

/// Closes the on-screen keyboard. On the small CI emulator (320x640) the IME
/// covers buttons that sit below a text field, so dismiss it before tapping.
///
/// Uses pump(), NOT pumpAndSettle(): some screens (e.g. the signing screen)
/// keep a CircularProgressIndicator running, so pumpAndSettle() would block
/// until the test times out. ~500ms is enough for the IME-hide animation and
/// the viewInsets reflow.
Future<void> _dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
}

class WelcomePage {
  static Future<void> tapCreate(WidgetTester tester) =>
      _tapKey(tester, 'welcomeCreateBtn');
  static Future<void> tapRestore(WidgetTester tester) =>
      _tapKey(tester, 'welcomeRestoreBtn');
}

class SignerSelectionPage {
  static Future<void> pickSoftware(WidgetTester tester) =>
      _tapKey(tester, 'signerSoftwareCard');
  static Future<void> pickHardware(WidgetTester tester) =>
      _tapKey(tester, 'signerHardwareCard');
  static Future<void> tapContinue(WidgetTester tester) =>
      _tapKey(tester, 'signerContinueBtn');
}

class PasswordPage {
  static Future<void> enter(WidgetTester tester, String password) async {
    await _enterText(tester, 'passwordField1', password);
    await _enterText(tester, 'passwordField2', password);
    await _tapKey(tester, 'passwordAckCheckbox');
    await tester.pumpAndSettle();
    await _dismissKeyboard(tester);
    await tester.dragUntilVisible(
      find.byKey(const Key('passwordContinueBtn')),
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, 'passwordContinueBtn');
    await tester.pumpAndSettle();
  }
}

class GoogleSignInPage {
  static Future<void> skip(WidgetTester tester) =>
      _tapKey(tester, 'googleSkipBtn');
  static Future<void> signIn(WidgetTester tester) =>
      _tapKey(tester, 'googleSignInBtn');
}

class ServerConnectPage {
  static Future<void> pickRegtest(WidgetTester tester) =>
      _tapKey(tester, 'serverPresetRegtest');
  static Future<void> pickMutiny(WidgetTester tester) =>
      _tapKey(tester, 'serverPresetMutiny');
}

class DkgProgressPage {
  static Future<void> waitForReady(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    await pumpUntilFound(
      tester,
      find.byKey(const Key('walletReadyBtn')),
      timeout: timeout,
    );
  }
}

class WalletReadyPage {
  static Future<void> tapGoToWallet(WidgetTester tester) =>
      _tapKey(tester, 'walletReadyBtn');
}

class HomePage {
  static Future<void> tapSend(WidgetTester tester) =>
      _tapKey(tester, 'homeSendBtn');
  static Future<void> tapReceive(WidgetTester tester) =>
      _tapKey(tester, 'homeReceiveBtn');
  static Future<void> tapArkTab(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Ark'),
    ));
    await tester.pump();
  }

  static Future<void> tapPoliciesTab(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Policies'),
    ));
    await tester.pump();
  }

  /// Tap the 'Home' bottom-nav item. No-op on the Home screen itself; from
  /// the Ark screen it `context.go('/')` (replacing the stack).
  static Future<void> tapHomeTab(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Home'),
    ));
    await tester.pumpAndSettle();
  }
}

class PoliciesPage {
  static Future<void> tapAdd(WidgetTester tester) =>
      _tapKey(tester, 'addPolicyBtn');
  static Future<void> tapDelete(WidgetTester tester, {int index = 0}) =>
      _tapKey(tester, 'deletePolicyBtn_$index');
  static Future<void> confirmDelete(WidgetTester tester) =>
      _tapKey(tester, 'confirmDeletePolicyBtn');
}

class RecoveryPasswordDialog {
  static Future<void> enterAndOk(WidgetTester tester, String password) async {
    await _enterText(tester, 'recoveryPasswordField', password);
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'recoveryPasswordOkBtn');
  }
}

class EditPolicyPage {
  static Future<void> dragThresholdToMin(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('thresholdSlider')),
      const Offset(-1000, 0),
    );
    await tester.pump();
  }

  /// Pick an interval segment by its visible label, e.g. '30 Sec' or 'Daily'.
  static Future<void> pickInterval(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byKey(const Key('policyIntervalSelector')),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  static Future<void> tapSave(WidgetTester tester) =>
      _tapKey(tester, 'createPolicyBtn');

  static Future<void> enterPinAndAuthorize(
    WidgetTester tester,
    String pin,
  ) async {
    await _enterText(tester, 'createPolicyPinField', pin);
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'createPolicyAuthorizeBtn');
  }
}

class SigningPinDialog {
  static Future<void> enterAndAuthorize(
    WidgetTester tester,
    String pin,
  ) async {
    await _enterText(tester, 'signingPinField', pin);
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'signingAuthorizeBtn');
  }
}

class SendPage {
  static Future<void> enterAddress(WidgetTester tester, String address) =>
      _enterText(tester, 'sendAddressField', address);
  static Future<void> enterAmount(WidgetTester tester, String sats) =>
      _enterText(tester, 'sendAmountField', sats);
  static Future<void> tapReview(WidgetTester tester) async {
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'sendReviewBtn');
  }
}

class ReviewPage {
  static Future<void> tapSign(WidgetTester tester) =>
      _tapKey(tester, 'reviewSignBtn');
}

class ArkPage {
  static Future<void> tapSend(WidgetTester tester) =>
      _tapKey(tester, 'arkSendBtn');
  static Future<void> tapReceive(WidgetTester tester) =>
      _tapKey(tester, 'arkReceiveBtn');
  static Future<void> tapBoard(WidgetTester tester) =>
      _tapKey(tester, 'arkBoardBtn');
}

class ArkBoardPage {
  static Future<void> tapBoardNow(WidgetTester tester) =>
      _tapKey(tester, 'arkBoardNowBtn');
  static Future<void> tapDone(WidgetTester tester) =>
      _tapKey(tester, 'arkBoardDoneBtn');
  static Future<void> waitForFundsDetected(
    WidgetTester tester, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await pumpUntilFound(
      tester,
      find.text('Board Now'),
      timeout: timeout,
    );
  }

  /// Fill the PIN that pops up when an active policy gates boarding.
  static Future<void> enterBoardingPinAndAuthorize(
    WidgetTester tester,
    String pin,
  ) async {
    await _enterText(tester, 'boardingPinField', pin);
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'boardingAuthorizeBtn');
  }
}

class ArkSendPage {
  static Future<void> enterAddress(WidgetTester tester, String address) =>
      _enterText(tester, 'arkSendAddressField', address);
  static Future<void> enterAmount(WidgetTester tester, String sats) =>
      _enterText(tester, 'arkSendAmountField', sats);
  static Future<void> tapSend(WidgetTester tester) async {
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'arkSendVtxoBtn');
  }
}

class RestorePage {
  static Future<void> enterPassword(WidgetTester tester, String password) =>
      _enterText(tester, 'restorePasswordField', password);
  static Future<void> tapContinue(WidgetTester tester) async {
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'restoreContinueBtn');
  }
}
