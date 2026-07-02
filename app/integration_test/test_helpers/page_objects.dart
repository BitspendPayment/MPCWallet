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
}

class PinPage {
  static Future<void> enter(WidgetTester tester, String pin) async {
    await _enterText(tester, 'pinField1', pin);
    await _enterText(tester, 'pinField2', pin);
    await tester.pumpAndSettle();
    await _dismissKeyboard(tester);
    await _tapKey(tester, 'pinContinueBtn');
    await tester.pumpAndSettle();
  }
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
