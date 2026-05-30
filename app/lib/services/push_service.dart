/// FCM push handling.
///
/// Initializes Firebase, registers the device token with the cosigner, and
/// keeps the token registration in sync with FCM rotations. Wakes
/// [MpcService] from a background message so the app re-delegates after a
/// receive even when the user hasn't opened it.
///
/// Safe to call on platforms or builds without Firebase config: any
/// initialization error is logged and the rest of the app continues without
/// push (auto-settle still fires for users who open the app).
library;

import 'dart:io' show Platform;

import 'package:app_core/client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../firebase_options.dart';
import 'mpc_service.dart';

class PushService {
  static bool _initialized = false;

  /// The live, logged-in service. Set by [registerCurrentToken] so the
  /// foreground push handler can drive a re-delegate while the app is open.
  static MpcService? _svc;

  /// Foreground init. Called from `main()` before runApp.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('[push] Firebase.initializeApp failed: $e — push disabled');
      return;
    }
    try {
      // iOS requires permission; Android <13 grants by default.
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _initialized = true;
    } catch (e) {
      debugPrint('[push] permission/handler setup failed: $e');
    }
  }

  /// Register the current FCM token with the cosigner. Call after login,
  /// once `MpcService` has a client. Idempotent.
  static Future<void> registerCurrentToken(MpcService svc) async {
    _svc = svc;
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await svc.registerDeviceToken(
        fcmToken: token,
        platform: Platform.isAndroid ? 'android' : 'ios',
      );
      // Re-register on rotation. We don't store the StreamSubscription —
      // it lives for the process lifetime, same as the MpcService it talks to.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        svc.registerDeviceToken(
          fcmToken: newToken,
          platform: Platform.isAndroid ? 'android' : 'ios',
        );
      });
    } catch (e) {
      debugPrint('[push] registerCurrentToken failed: $e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    debugPrint('[push] foreground: ${msg.data}');
    if (msg.data['type'] != 'vtxo_received') return;
    // App is open: nothing wakes a background isolate, so drive the refresh
    // here. refreshVtxos() runs _delegateIfNeeded() -> settleDelegate, the same
    // re-delegate the background handler performs.
    final svc = _svc;
    if (svc == null) {
      debugPrint('[push] foreground vtxo_received but no live service yet');
      return;
    }
    try {
      await svc.refreshVtxos();
      debugPrint('[push] foreground re-delegate via refreshVtxos ok');
    } catch (e) {
      debugPrint('[push] foreground refreshVtxos failed: $e');
    }
  }

  /// Run the same code path `_handleBackgroundMessage` runs for a
  /// `vtxo_received` payload, but synchronously from the calling isolate.
  /// Integration tests use this because Flutter test bindings can't deliver
  /// real OS push events — but the test still wants to prove the handler's
  /// work (load Hive, restore client, store delegate) actually runs.
  @visibleForTesting
  static Future<void> handleBackgroundMessageForTest(
      Map<String, String> data) async {
    if (data['type'] != 'vtxo_received') return;
    await _runBackgroundDelegate();
  }
}

/// Build the server base URL with the same rules `MpcService._baseUrl` uses.
/// Local hosts get http://host:7074; remote (enclave) hosts get https://host.
String _baseUrlFor(String host) {
  const port = 7074;
  final isLocal = host == '127.0.0.1' ||
      host == 'localhost' ||
      host == '10.0.2.2' ||
      host.startsWith('192.168.');
  return isLocal ? 'http://$host:$port' : 'https://$host';
}

/// Construct a fresh REST client, restore identity from Hive, run
/// `settleDelegate(storeOnly: true)`. Used by both the real background
/// handler and the test-only entry point.
///
/// No hardware signer needed — FROST signing here uses the wallet's own
/// share (`_normalPolicy.keyPackage`), which `restoreState()` rehydrates
/// from Hive.
Future<void> _runBackgroundDelegate({Duration? timeout}) async {
  final dir = await getApplicationDocumentsDirectory();
  // Must match the main app's Hive root. MpcService.init() initialises
  // persistence at '<docs>/mpc_client' (via MpcClient.initPersistence), so the
  // identity box and wallet state live there. A bare Hive.init(dir.path) opens
  // an empty box in the wrong directory — identity + wallet state come back
  // missing and the delegate silently no-ops.
  await MpcClient.initPersistence(path: '${dir.path}/mpc_client');
  final identityBox = await Hive.openBox('mpc_service_identity');
  final host = identityBox.get('serverHost') as String?;
  final storageId = identityBox.get('storageId') as String?;
  if (host == null || storageId == null) {
    debugPrint('[push:bg] missing serverHost or storageId in Hive');
    return;
  }
  final client = MpcClient.rest(
    _baseUrlFor(host),
    hardwareSigner: null,
    storageId: storageId,
  );
  try {
    final restored = await client.restoreState();
    if (!restored) {
      debugPrint('[push:bg] restoreState returned false (no wallet)');
      return;
    }
    final future = client.settleDelegate(storeOnly: true);
    await (timeout != null ? future.timeout(timeout) : future);
    debugPrint('[push:bg] settleDelegate(storeOnly:true) ok');
  } finally {
    // No explicit dispose on MpcClient; falls out of scope.
  }
}

/// Top-level background handler. Flutter requires this to be a top-level
/// (non-class) function and annotated with `@pragma('vm:entry-point')` so the
/// background isolate can resolve it after Tree Shaking.
///
/// FROST signing happens with the wallet's own share — no hardware signer
/// reachability required.
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage msg) async {
  if (msg.data['type'] != 'vtxo_received') return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[push:bg] Firebase.initializeApp failed: $e');
    return;
  }
  try {
    await _runBackgroundDelegate(timeout: const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[push:bg] settleDelegate failed: $e — foreground will catch up');
  }
}
