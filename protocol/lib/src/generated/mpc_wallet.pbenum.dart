// This is a generated file - do not edit.
//
// Generated from mpc_wallet.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SendVtxoResponse_Status extends $pb.ProtobufEnum {
  static const SendVtxoResponse_Status SIGNING_REQUIRED =
      SendVtxoResponse_Status._(0, _omitEnumNames ? '' : 'SIGNING_REQUIRED');
  static const SendVtxoResponse_Status SETTLED =
      SendVtxoResponse_Status._(1, _omitEnumNames ? '' : 'SETTLED');
  static const SendVtxoResponse_Status ERROR =
      SendVtxoResponse_Status._(2, _omitEnumNames ? '' : 'ERROR');

  static const $core.List<SendVtxoResponse_Status> values =
      <SendVtxoResponse_Status>[
    SIGNING_REQUIRED,
    SETTLED,
    ERROR,
  ];

  static final $core.List<SendVtxoResponse_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SendVtxoResponse_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SendVtxoResponse_Status._(super.value, super.name);
}

class SettleResponse_Status extends $pb.ProtobufEnum {
  static const SettleResponse_Status SIGNING_REQUIRED =
      SettleResponse_Status._(0, _omitEnumNames ? '' : 'SIGNING_REQUIRED');
  static const SettleResponse_Status WAITING_FOR_BATCH =
      SettleResponse_Status._(1, _omitEnumNames ? '' : 'WAITING_FOR_BATCH');
  static const SettleResponse_Status SETTLED =
      SettleResponse_Status._(2, _omitEnumNames ? '' : 'SETTLED');
  static const SettleResponse_Status ERROR =
      SettleResponse_Status._(3, _omitEnumNames ? '' : 'ERROR');

  static const $core.List<SettleResponse_Status> values =
      <SettleResponse_Status>[
    SIGNING_REQUIRED,
    WAITING_FOR_BATCH,
    SETTLED,
    ERROR,
  ];

  static final $core.List<SettleResponse_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SettleResponse_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SettleResponse_Status._(super.value, super.name);
}

class SettleDelegateResponse_Status extends $pb.ProtobufEnum {
  static const SettleDelegateResponse_Status SIGNING_REQUIRED =
      SettleDelegateResponse_Status._(
          0, _omitEnumNames ? '' : 'SIGNING_REQUIRED');
  static const SettleDelegateResponse_Status SETTLED =
      SettleDelegateResponse_Status._(1, _omitEnumNames ? '' : 'SETTLED');
  static const SettleDelegateResponse_Status ERROR =
      SettleDelegateResponse_Status._(2, _omitEnumNames ? '' : 'ERROR');

  /// store_only path: signed intent stored, batch not joined yet.
  static const SettleDelegateResponse_Status DELEGATED =
      SettleDelegateResponse_Status._(3, _omitEnumNames ? '' : 'DELEGATED');

  static const $core.List<SettleDelegateResponse_Status> values =
      <SettleDelegateResponse_Status>[
    SIGNING_REQUIRED,
    SETTLED,
    ERROR,
    DELEGATED,
  ];

  static final $core.List<SettleDelegateResponse_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SettleDelegateResponse_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SettleDelegateResponse_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
