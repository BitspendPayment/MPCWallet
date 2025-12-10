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

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class DKGStep1Request extends $pb.GeneratedMessage {
  factory DKGStep1Request({
    $core.String? deviceId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (identifier != null) result.identifier = identifier;
    if (round1Package != null) result.round1Package = round1Package;
    return result;
  }

  DKGStep1Request._();

  factory DKGStep1Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DKGStep1Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DKGStep1Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep1Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep1Request copyWith(void Function(DKGStep1Request) updates) =>
      super.copyWith((message) => updates(message as DKGStep1Request))
          as DKGStep1Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DKGStep1Request create() => DKGStep1Request._();
  @$core.override
  DKGStep1Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DKGStep1Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DKGStep1Request>(create);
  static DKGStep1Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get round1Package => $_getSZ(2);
  @$pb.TagNumber(3)
  set round1Package($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRound1Package() => $_has(2);
  @$pb.TagNumber(3)
  void clearRound1Package() => $_clearField(3);
}

class DKGStep1Response extends $pb.GeneratedMessage {
  factory DKGStep1Response({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? round1Packages,
  }) {
    final result = create();
    if (round1Packages != null)
      result.round1Packages.addEntries(round1Packages);
    return result;
  }

  DKGStep1Response._();

  factory DKGStep1Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DKGStep1Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DKGStep1Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round1Packages',
        entryClassName: 'DKGStep1Response.Round1PackagesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep1Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep1Response copyWith(void Function(DKGStep1Response) updates) =>
      super.copyWith((message) => updates(message as DKGStep1Response))
          as DKGStep1Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DKGStep1Response create() => DKGStep1Response._();
  @$core.override
  DKGStep1Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DKGStep1Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DKGStep1Response>(create);
  static DKGStep1Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get round1Packages => $_getMap(0);
}

class DKGStep2Request extends $pb.GeneratedMessage {
  factory DKGStep2Request({
    $core.String? deviceId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (identifier != null) result.identifier = identifier;
    if (round1Package != null) result.round1Package = round1Package;
    return result;
  }

  DKGStep2Request._();

  factory DKGStep2Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DKGStep2Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DKGStep2Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep2Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep2Request copyWith(void Function(DKGStep2Request) updates) =>
      super.copyWith((message) => updates(message as DKGStep2Request))
          as DKGStep2Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DKGStep2Request create() => DKGStep2Request._();
  @$core.override
  DKGStep2Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DKGStep2Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DKGStep2Request>(create);
  static DKGStep2Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get round1Package => $_getSZ(2);
  @$pb.TagNumber(3)
  set round1Package($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRound1Package() => $_has(2);
  @$pb.TagNumber(3)
  void clearRound1Package() => $_clearField(3);
}

class DKGStep2Response extends $pb.GeneratedMessage {
  factory DKGStep2Response({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        allRound1Packages,
  }) {
    final result = create();
    if (allRound1Packages != null)
      result.allRound1Packages.addEntries(allRound1Packages);
    return result;
  }

  DKGStep2Response._();

  factory DKGStep2Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DKGStep2Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DKGStep2Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1, _omitFieldNames ? '' : 'allRound1Packages',
        entryClassName: 'DKGStep2Response.AllRound1PackagesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep2Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep2Response copyWith(void Function(DKGStep2Response) updates) =>
      super.copyWith((message) => updates(message as DKGStep2Response))
          as DKGStep2Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DKGStep2Response create() => DKGStep2Response._();
  @$core.override
  DKGStep2Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DKGStep2Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DKGStep2Response>(create);
  static DKGStep2Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get allRound1Packages => $_getMap(0);
}

class DKGStep3Request extends $pb.GeneratedMessage {
  factory DKGStep3Request({
    $core.String? deviceId,
    $core.List<$core.int>? identifier,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        round2PackagesForOthers,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (identifier != null) result.identifier = identifier;
    if (round2PackagesForOthers != null)
      result.round2PackagesForOthers.addEntries(round2PackagesForOthers);
    return result;
  }

  DKGStep3Request._();

  factory DKGStep3Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DKGStep3Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DKGStep3Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(
        3, _omitFieldNames ? '' : 'round2PackagesForOthers',
        entryClassName: 'DKGStep3Request.Round2PackagesForOthersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep3Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep3Request copyWith(void Function(DKGStep3Request) updates) =>
      super.copyWith((message) => updates(message as DKGStep3Request))
          as DKGStep3Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DKGStep3Request create() => DKGStep3Request._();
  @$core.override
  DKGStep3Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DKGStep3Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DKGStep3Request>(create);
  static DKGStep3Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get round2PackagesForOthers =>
      $_getMap(2);
}

class DKGStep3Response extends $pb.GeneratedMessage {
  factory DKGStep3Response({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        round2PackagesForMe,
  }) {
    final result = create();
    if (round2PackagesForMe != null)
      result.round2PackagesForMe.addEntries(round2PackagesForMe);
    return result;
  }

  DKGStep3Response._();

  factory DKGStep3Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DKGStep3Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DKGStep3Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1, _omitFieldNames ? '' : 'round2PackagesForMe',
        entryClassName: 'DKGStep3Response.Round2PackagesForMeEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep3Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DKGStep3Response copyWith(void Function(DKGStep3Response) updates) =>
      super.copyWith((message) => updates(message as DKGStep3Response))
          as DKGStep3Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DKGStep3Response create() => DKGStep3Response._();
  @$core.override
  DKGStep3Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DKGStep3Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DKGStep3Response>(create);
  static DKGStep3Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get round2PackagesForMe => $_getMap(0);
}

class SignStep1Request extends $pb.GeneratedMessage {
  factory SignStep1Request({
    $core.String? deviceId,
    $core.List<$core.int>? identifier,
    $core.List<$core.int>? hidingCommitment,
    $core.List<$core.int>? bindingCommitment,
    $core.List<$core.int>? messageToSign,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (identifier != null) result.identifier = identifier;
    if (hidingCommitment != null) result.hidingCommitment = hidingCommitment;
    if (bindingCommitment != null) result.bindingCommitment = bindingCommitment;
    if (messageToSign != null) result.messageToSign = messageToSign;
    return result;
  }

  SignStep1Request._();

  factory SignStep1Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignStep1Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignStep1Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'hidingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'bindingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'messageToSign', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep1Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep1Request copyWith(void Function(SignStep1Request) updates) =>
      super.copyWith((message) => updates(message as SignStep1Request))
          as SignStep1Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignStep1Request create() => SignStep1Request._();
  @$core.override
  SignStep1Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SignStep1Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignStep1Request>(create);
  static SignStep1Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get hidingCommitment => $_getN(2);
  @$pb.TagNumber(3)
  set hidingCommitment($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHidingCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearHidingCommitment() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get bindingCommitment => $_getN(3);
  @$pb.TagNumber(4)
  set bindingCommitment($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBindingCommitment() => $_has(3);
  @$pb.TagNumber(4)
  void clearBindingCommitment() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get messageToSign => $_getN(4);
  @$pb.TagNumber(5)
  set messageToSign($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMessageToSign() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageToSign() => $_clearField(5);
}

class SignStep1Response_Commitment extends $pb.GeneratedMessage {
  factory SignStep1Response_Commitment({
    $core.List<$core.int>? hiding,
    $core.List<$core.int>? binding,
  }) {
    final result = create();
    if (hiding != null) result.hiding = hiding;
    if (binding != null) result.binding = binding;
    return result;
  }

  SignStep1Response_Commitment._();

  factory SignStep1Response_Commitment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignStep1Response_Commitment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignStep1Response.Commitment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'hiding', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'binding', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep1Response_Commitment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep1Response_Commitment copyWith(
          void Function(SignStep1Response_Commitment) updates) =>
      super.copyWith(
              (message) => updates(message as SignStep1Response_Commitment))
          as SignStep1Response_Commitment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignStep1Response_Commitment create() =>
      SignStep1Response_Commitment._();
  @$core.override
  SignStep1Response_Commitment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SignStep1Response_Commitment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignStep1Response_Commitment>(create);
  static SignStep1Response_Commitment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get hiding => $_getN(0);
  @$pb.TagNumber(1)
  set hiding($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHiding() => $_has(0);
  @$pb.TagNumber(1)
  void clearHiding() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get binding => $_getN(1);
  @$pb.TagNumber(2)
  set binding($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBinding() => $_has(1);
  @$pb.TagNumber(2)
  void clearBinding() => $_clearField(2);
}

class SignStep1Response extends $pb.GeneratedMessage {
  factory SignStep1Response({
    $core.Iterable<$core.MapEntry<$core.String, SignStep1Response_Commitment>>?
        commitments,
    $core.List<$core.int>? messageToSign,
  }) {
    final result = create();
    if (commitments != null) result.commitments.addEntries(commitments);
    if (messageToSign != null) result.messageToSign = messageToSign;
    return result;
  }

  SignStep1Response._();

  factory SignStep1Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignStep1Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignStep1Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..m<$core.String, SignStep1Response_Commitment>(
        1, _omitFieldNames ? '' : 'commitments',
        entryClassName: 'SignStep1Response.CommitmentsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: SignStep1Response_Commitment.create,
        valueDefaultOrMaker: SignStep1Response_Commitment.getDefault,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messageToSign', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep1Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep1Response copyWith(void Function(SignStep1Response) updates) =>
      super.copyWith((message) => updates(message as SignStep1Response))
          as SignStep1Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignStep1Response create() => SignStep1Response._();
  @$core.override
  SignStep1Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SignStep1Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignStep1Response>(create);
  static SignStep1Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, SignStep1Response_Commitment> get commitments =>
      $_getMap(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageToSign => $_getN(1);
  @$pb.TagNumber(2)
  set messageToSign($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageToSign() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageToSign() => $_clearField(2);
}

class SignStep2Request extends $pb.GeneratedMessage {
  factory SignStep2Request({
    $core.String? deviceId,
    $core.List<$core.int>? identifier,
    $core.List<$core.int>? signatureShare,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (identifier != null) result.identifier = identifier;
    if (signatureShare != null) result.signatureShare = signatureShare;
    return result;
  }

  SignStep2Request._();

  factory SignStep2Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignStep2Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignStep2Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signatureShare', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep2Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep2Request copyWith(void Function(SignStep2Request) updates) =>
      super.copyWith((message) => updates(message as SignStep2Request))
          as SignStep2Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignStep2Request create() => SignStep2Request._();
  @$core.override
  SignStep2Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SignStep2Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignStep2Request>(create);
  static SignStep2Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signatureShare => $_getN(2);
  @$pb.TagNumber(3)
  set signatureShare($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignatureShare() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignatureShare() => $_clearField(3);
}

class SignStep2Response extends $pb.GeneratedMessage {
  factory SignStep2Response({
    $core.List<$core.int>? rPoint,
    $core.List<$core.int>? zScalar,
  }) {
    final result = create();
    if (rPoint != null) result.rPoint = rPoint;
    if (zScalar != null) result.zScalar = zScalar;
    return result;
  }

  SignStep2Response._();

  factory SignStep2Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignStep2Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignStep2Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'rPoint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'zScalar', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep2Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignStep2Response copyWith(void Function(SignStep2Response) updates) =>
      super.copyWith((message) => updates(message as SignStep2Response))
          as SignStep2Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignStep2Response create() => SignStep2Response._();
  @$core.override
  SignStep2Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SignStep2Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignStep2Response>(create);
  static SignStep2Response? _defaultInstance;

  /// Final aggregated signature
  /// (R, z)
  @$pb.TagNumber(1)
  $core.List<$core.int> get rPoint => $_getN(0);
  @$pb.TagNumber(1)
  set rPoint($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRPoint() => $_has(0);
  @$pb.TagNumber(1)
  void clearRPoint() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get zScalar => $_getN(1);
  @$pb.TagNumber(2)
  set zScalar($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasZScalar() => $_has(1);
  @$pb.TagNumber(2)
  void clearZScalar() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
