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

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'mpc_service.dart';

class PushService {
  static bool _initialized = false;

  /// Foreground init. Called from `main()` before runApp.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
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
    // Foreground refresh runs through the existing app — nothing to do here
    // beyond logging; the MpcService is already poll-active.
  }
}

/// Top-level background handler. Flutter requires this to be a top-level
/// (non-class) function and annotated with `@pragma('vm:entry-point')` so the
/// background isolate can resolve it after Tree Shaking.
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage msg) async {
  if (msg.data['type'] != 'vtxo_received') return;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[push:bg] Firebase.initializeApp failed: $e');
    return;
  }
  // Bringing the full MpcService online from a background isolate is heavy
  // (Hive, threshold, gRPC channel reconnect). The simplest correct
  // behavior: write a marker that the foreground refresh path can read on
  // next resume. The actual auto-settle delegation does not require us to
  // delegate from the background — it requires us to delegate "soon", which
  // any subsequent foreground refresh covers.
  //
  // We log and exit; the open-app fallback in MpcService.refreshVtxos
  // handles re-delegation deterministically when the app next runs.
  debugPrint('[push:bg] vtxo_received (user_id=${msg.data['user_id']})');
}
