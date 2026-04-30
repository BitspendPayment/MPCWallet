import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Authentication message builder for MPC Wallet requests.
///
/// Uses a static message prefix with operation type and timestamp
/// to create a deterministic message for Schnorr signature authentication.
/// This design prevents replay attacks through timestamp validation.
class AuthMessage {
  /// Protocol version prefix for domain separation
  static const String protocolVersion = 'MPC_WALLET_AUTH_V1';

  /// Maximum allowed timestamp drift in milliseconds (5 minutes)
  static const int maxTimestampDriftMs = 5 * 60 * 1000;

  /// Operation types for different RPC calls
  static const String opSignStep1 = 'SIGN_STEP1';
  static const String opSignStep2 = 'SIGN_STEP2';
  static const String opRefreshStep1 = 'REFRESH_STEP1';
  static const String opRefreshStep2 = 'REFRESH_STEP2';
  static const String opRefreshStep3 = 'REFRESH_STEP3';
  static const String opCreatePolicy = 'CREATE_POLICY';
  static const String opGetPolicyId = 'GET_POLICY_ID';
  static const String opFetchHistory = 'FETCH_HISTORY';
  static const String opFetchRecentTxs = 'FETCH_RECENT_TXS';
  static const String opSubscribeHistory = 'SUBSCRIBE_HISTORY';
  static const String opUpdatePolicy = 'UPDATE_POLICY';
  static const String opDeletePolicy = 'DELETE_POLICY';
  static const String opGetArkInfo = 'GET_ARK_INFO';
  static const String opGetArkAddress = 'GET_ARK_ADDRESS';
  static const String opGetBoardingAddress = 'GET_BOARDING_ADDRESS';
  static const String opListVtxos = 'LIST_VTXOS';
  static const String opSendVtxo = 'SEND_VTXO';
  static const String opRedeemVtxo = 'REDEEM_VTXO';
  static const String opSettle = 'SETTLE';
  static const String opSettleDelegate = 'SETTLE_DELEGATE';
  static const String opListArkTxs = 'LIST_ARK_TXS';
  static const String opCheckBoardingBalance = 'CHECK_BOARDING_BALANCE';

  final String operation;
  final int timestampMs;
  final String userIdHex;

  AuthMessage({
    required this.operation,
    required this.timestampMs,
    required this.userIdHex,
  });

  /// Creates an auth message for the current time
  factory AuthMessage.now({
    required String operation,
    required String userIdHex,
  }) {
    return AuthMessage(
      operation: operation,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      userIdHex: userIdHex,
    );
  }

  /// Builds the canonical message string for signing
  /// Format: MPC_WALLET_AUTH_V1:<operation>:<timestamp_ms>:<user_id_hex>
  String get canonicalMessage {
    return '$protocolVersion:$operation:$timestampMs:$userIdHex';
  }

  /// Returns the message bytes to be signed (SHA256 hash of canonical message)
  /// Using a hash ensures consistent 32-byte message length for BIP-340
  Uint8List get messageBytes {
    final canonical = canonicalMessage;
    final hash = sha256.convert(utf8.encode(canonical));
    return Uint8List.fromList(hash.bytes);
  }

  /// Validates that the timestamp is within acceptable drift range
  bool isTimestampValid({int? serverTimeMs}) {
    final now = serverTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    final diff = (now - timestampMs).abs();
    return diff <= maxTimestampDriftMs;
  }

  /// Parses an auth message from its components
  factory AuthMessage.parse({
    required String operation,
    required int timestampMs,
    required String userIdHex,
  }) {
    return AuthMessage(
      operation: operation,
      timestampMs: timestampMs,
      userIdHex: userIdHex,
    );
  }

  @override
  String toString() => canonicalMessage;
}

/// Exception thrown when authentication fails
class AuthenticationException implements Exception {
  final String message;
  final String? code;

  AuthenticationException(this.message, {this.code});

  @override
  String toString() => 'AuthenticationException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Exception thrown when timestamp validation fails
class TimestampValidationException extends AuthenticationException {
  TimestampValidationException(String message) : super(message, code: 'TIMESTAMP_INVALID');
}

/// Exception thrown when signature verification fails
class SignatureVerificationException extends AuthenticationException {
  SignatureVerificationException(String message) : super(message, code: 'SIGNATURE_INVALID');
}

/// Message builder for recovery-authenticated operations (FROST-signed).
///
/// These messages are signed using client-only 2-of-3 FROST threshold
/// signing (both signing + recovery key packages), proving control
/// of both keys. The server verifies using the group public key.
class RecoveryAuthMessage {
  static const String protocolVersion = 'MPC_WALLET_RECOVERY_V1';

  static Uint8List buildUpdatePolicyMessage({
    required String policyId,
    required int thresholdSats,
    required int intervalSeconds,
    required int timestampMs,
    required String userIdHex,
  }) {
    final canonical =
        '$protocolVersion:UPDATE_POLICY:$policyId:$thresholdSats:$intervalSeconds:$timestampMs:$userIdHex';
    return Uint8List.fromList(sha256.convert(utf8.encode(canonical)).bytes);
  }

  static Uint8List buildDeletePolicyMessage({
    required String policyId,
    required int timestampMs,
    required String userIdHex,
  }) {
    final canonical =
        '$protocolVersion:DELETE_POLICY:$policyId:$timestampMs:$userIdHex';
    return Uint8List.fromList(sha256.convert(utf8.encode(canonical)).bytes);
  }
}
