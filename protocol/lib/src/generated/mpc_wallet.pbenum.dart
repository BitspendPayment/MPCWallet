///
//  Generated code. Do not modify.
//  source: mpc_wallet.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

// ignore_for_file: UNDEFINED_SHOWN_NAME
import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;

class SendVtxoResponse_Status extends $pb.ProtobufEnum {
  static const SendVtxoResponse_Status SIGNING_REQUIRED = SendVtxoResponse_Status._(0, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'SIGNING_REQUIRED');
  static const SendVtxoResponse_Status SETTLED = SendVtxoResponse_Status._(1, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'SETTLED');
  static const SendVtxoResponse_Status ERROR = SendVtxoResponse_Status._(2, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'ERROR');

  static const $core.List<SendVtxoResponse_Status> values = <SendVtxoResponse_Status> [
    SIGNING_REQUIRED,
    SETTLED,
    ERROR,
  ];

  static final $core.Map<$core.int, SendVtxoResponse_Status> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SendVtxoResponse_Status? valueOf($core.int value) => _byValue[value];

  const SendVtxoResponse_Status._($core.int v, $core.String n) : super(v, n);
}

class SettleResponse_Status extends $pb.ProtobufEnum {
  static const SettleResponse_Status SIGNING_REQUIRED = SettleResponse_Status._(0, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'SIGNING_REQUIRED');
  static const SettleResponse_Status WAITING_FOR_BATCH = SettleResponse_Status._(1, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'WAITING_FOR_BATCH');
  static const SettleResponse_Status SETTLED = SettleResponse_Status._(2, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'SETTLED');
  static const SettleResponse_Status ERROR = SettleResponse_Status._(3, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'ERROR');

  static const $core.List<SettleResponse_Status> values = <SettleResponse_Status> [
    SIGNING_REQUIRED,
    WAITING_FOR_BATCH,
    SETTLED,
    ERROR,
  ];

  static final $core.Map<$core.int, SettleResponse_Status> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SettleResponse_Status? valueOf($core.int value) => _byValue[value];

  const SettleResponse_Status._($core.int v, $core.String n) : super(v, n);
}

class SettleDelegateResponse_Status extends $pb.ProtobufEnum {
  static const SettleDelegateResponse_Status SIGNING_REQUIRED = SettleDelegateResponse_Status._(0, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'SIGNING_REQUIRED');
  static const SettleDelegateResponse_Status SETTLED = SettleDelegateResponse_Status._(1, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'SETTLED');
  static const SettleDelegateResponse_Status ERROR = SettleDelegateResponse_Status._(2, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'ERROR');
  static const SettleDelegateResponse_Status DELEGATED = SettleDelegateResponse_Status._(3, const $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'DELEGATED');

  static const $core.List<SettleDelegateResponse_Status> values = <SettleDelegateResponse_Status> [
    SIGNING_REQUIRED,
    SETTLED,
    ERROR,
    DELEGATED,
  ];

  static final $core.Map<$core.int, SettleDelegateResponse_Status> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SettleDelegateResponse_Status? valueOf($core.int value) => _byValue[value];

  const SettleDelegateResponse_Status._($core.int v, $core.String n) : super(v, n);
}

