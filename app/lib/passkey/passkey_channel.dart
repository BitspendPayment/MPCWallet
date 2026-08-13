import 'package:flutter/services.dart';

/// Thin Dart wrapper over the Android `PasskeyPlugin` (Jetpack Credential
/// Manager). Both methods take a WebAuthn options JSON string and return the
/// corresponding response JSON string produced by the authenticator.
///
/// Android-only: on other platforms `invokeMethod` throws a
/// [MissingPluginException]; callers gate on `Platform.isAndroid`.
class PasskeyChannel {
  static const _ch = MethodChannel('com.mpcwallet.ap/passkey');

  /// WebAuthn registration (create a passkey). Returns registrationResponseJson.
  static Future<String> create(String requestJson) async =>
      (await _ch.invokeMethod<String>('create', {'requestJson': requestJson}))!;

  /// WebAuthn assertion (use a passkey). Returns authenticationResponseJson.
  static Future<String> get(String requestJson) async =>
      (await _ch.invokeMethod<String>('get', {'requestJson': requestJson}))!;
}
