///
//  Generated code. Do not modify.
//  source: mpc_wallet.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'mpc_wallet.pbenum.dart';

export 'mpc_wallet.pbenum.dart';

class DKGStep1Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DKGStep1Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round1Package')
    ..aOB(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'isRestore')
    ..hasRequiredFields = false
  ;

  DKGStep1Request._() : super();
  factory DKGStep1Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
    $core.bool? isRestore,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (identifier != null) {
      _result.identifier = identifier;
    }
    if (round1Package != null) {
      _result.round1Package = round1Package;
    }
    if (isRestore != null) {
      _result.isRestore = isRestore;
    }
    return _result;
  }
  factory DKGStep1Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep1Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep1Request clone() => DKGStep1Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep1Request copyWith(void Function(DKGStep1Request) updates) => super.copyWith((message) => updates(message as DKGStep1Request)) as DKGStep1Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DKGStep1Request create() => DKGStep1Request._();
  DKGStep1Request createEmptyInstance() => create();
  static $pb.PbList<DKGStep1Request> createRepeated() => $pb.PbList<DKGStep1Request>();
  @$core.pragma('dart2js:noInline')
  static DKGStep1Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DKGStep1Request>(create);
  static DKGStep1Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get round1Package => $_getSZ(2);
  @$pb.TagNumber(3)
  set round1Package($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRound1Package() => $_has(2);
  @$pb.TagNumber(3)
  void clearRound1Package() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isRestore => $_getBF(3);
  @$pb.TagNumber(4)
  set isRestore($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIsRestore() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsRestore() => clearField(4);
}

class DKGStep1Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DKGStep1Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round1Packages', entryClassName: 'DKGStep1Response.Round1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  DKGStep1Response._() : super();
  factory DKGStep1Response({
    $core.Map<$core.String, $core.String>? round1Packages,
  }) {
    final _result = create();
    if (round1Packages != null) {
      _result.round1Packages.addAll(round1Packages);
    }
    return _result;
  }
  factory DKGStep1Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep1Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep1Response clone() => DKGStep1Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep1Response copyWith(void Function(DKGStep1Response) updates) => super.copyWith((message) => updates(message as DKGStep1Response)) as DKGStep1Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DKGStep1Response create() => DKGStep1Response._();
  DKGStep1Response createEmptyInstance() => create();
  static $pb.PbList<DKGStep1Response> createRepeated() => $pb.PbList<DKGStep1Response>();
  @$core.pragma('dart2js:noInline')
  static DKGStep1Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DKGStep1Response>(create);
  static DKGStep1Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get round1Packages => $_getMap(0);
}

class DKGStep2Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DKGStep2Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round1Package')
    ..hasRequiredFields = false
  ;

  DKGStep2Request._() : super();
  factory DKGStep2Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (identifier != null) {
      _result.identifier = identifier;
    }
    if (round1Package != null) {
      _result.round1Package = round1Package;
    }
    return _result;
  }
  factory DKGStep2Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep2Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep2Request clone() => DKGStep2Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep2Request copyWith(void Function(DKGStep2Request) updates) => super.copyWith((message) => updates(message as DKGStep2Request)) as DKGStep2Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DKGStep2Request create() => DKGStep2Request._();
  DKGStep2Request createEmptyInstance() => create();
  static $pb.PbList<DKGStep2Request> createRepeated() => $pb.PbList<DKGStep2Request>();
  @$core.pragma('dart2js:noInline')
  static DKGStep2Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DKGStep2Request>(create);
  static DKGStep2Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get round1Package => $_getSZ(2);
  @$pb.TagNumber(3)
  set round1Package($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRound1Package() => $_has(2);
  @$pb.TagNumber(3)
  void clearRound1Package() => clearField(3);
}

class DKGStep2Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DKGStep2Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'allRound1Packages', entryClassName: 'DKGStep2Response.AllRound1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  DKGStep2Response._() : super();
  factory DKGStep2Response({
    $core.Map<$core.String, $core.String>? allRound1Packages,
  }) {
    final _result = create();
    if (allRound1Packages != null) {
      _result.allRound1Packages.addAll(allRound1Packages);
    }
    return _result;
  }
  factory DKGStep2Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep2Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep2Response clone() => DKGStep2Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep2Response copyWith(void Function(DKGStep2Response) updates) => super.copyWith((message) => updates(message as DKGStep2Response)) as DKGStep2Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DKGStep2Response create() => DKGStep2Response._();
  DKGStep2Response createEmptyInstance() => create();
  static $pb.PbList<DKGStep2Response> createRepeated() => $pb.PbList<DKGStep2Response>();
  @$core.pragma('dart2js:noInline')
  static DKGStep2Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DKGStep2Response>(create);
  static DKGStep2Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get allRound1Packages => $_getMap(0);
}

class DKGStep3Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DKGStep3Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'identifier', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round2PackagesForOthers', entryClassName: 'DKGStep3Request.Round2PackagesForOthersEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  DKGStep3Request._() : super();
  factory DKGStep3Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.Map<$core.String, $core.String>? round2PackagesForOthers,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (identifier != null) {
      _result.identifier = identifier;
    }
    if (round2PackagesForOthers != null) {
      _result.round2PackagesForOthers.addAll(round2PackagesForOthers);
    }
    return _result;
  }
  factory DKGStep3Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep3Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep3Request clone() => DKGStep3Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep3Request copyWith(void Function(DKGStep3Request) updates) => super.copyWith((message) => updates(message as DKGStep3Request)) as DKGStep3Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DKGStep3Request create() => DKGStep3Request._();
  DKGStep3Request createEmptyInstance() => create();
  static $pb.PbList<DKGStep3Request> createRepeated() => $pb.PbList<DKGStep3Request>();
  @$core.pragma('dart2js:noInline')
  static DKGStep3Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DKGStep3Request>(create);
  static DKGStep3Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => clearField(2);

  @$pb.TagNumber(3)
  $core.Map<$core.String, $core.String> get round2PackagesForOthers => $_getMap(2);
}

class DKGStep3Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DKGStep3Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round2PackagesForMe', entryClassName: 'DKGStep3Response.Round2PackagesForMeEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  DKGStep3Response._() : super();
  factory DKGStep3Response({
    $core.Map<$core.String, $core.String>? round2PackagesForMe,
  }) {
    final _result = create();
    if (round2PackagesForMe != null) {
      _result.round2PackagesForMe.addAll(round2PackagesForMe);
    }
    return _result;
  }
  factory DKGStep3Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep3Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep3Response clone() => DKGStep3Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep3Response copyWith(void Function(DKGStep3Response) updates) => super.copyWith((message) => updates(message as DKGStep3Response)) as DKGStep3Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DKGStep3Response create() => DKGStep3Response._();
  DKGStep3Response createEmptyInstance() => create();
  static $pb.PbList<DKGStep3Response> createRepeated() => $pb.PbList<DKGStep3Response>();
  @$core.pragma('dart2js:noInline')
  static DKGStep3Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DKGStep3Response>(create);
  static DKGStep3Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get round2PackagesForMe => $_getMap(0);
}

class SignStep1Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SignStep1Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'hidingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'bindingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'messageToSign', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'fullTransaction', $pb.PbFieldType.OY)
    ..aInt64(7, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..aOB(8, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'scriptPathSpend')
    ..hasRequiredFields = false
  ;

  SignStep1Request._() : super();
  factory SignStep1Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? hidingCommitment,
    $core.List<$core.int>? bindingCommitment,
    $core.List<$core.int>? messageToSign,
    $core.List<$core.int>? signature,
    $core.List<$core.int>? fullTransaction,
    $fixnum.Int64? timestampMs,
    $core.bool? scriptPathSpend,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (hidingCommitment != null) {
      _result.hidingCommitment = hidingCommitment;
    }
    if (bindingCommitment != null) {
      _result.bindingCommitment = bindingCommitment;
    }
    if (messageToSign != null) {
      _result.messageToSign = messageToSign;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (fullTransaction != null) {
      _result.fullTransaction = fullTransaction;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    if (scriptPathSpend != null) {
      _result.scriptPathSpend = scriptPathSpend;
    }
    return _result;
  }
  factory SignStep1Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep1Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep1Request clone() => SignStep1Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep1Request copyWith(void Function(SignStep1Request) updates) => super.copyWith((message) => updates(message as SignStep1Request)) as SignStep1Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SignStep1Request create() => SignStep1Request._();
  SignStep1Request createEmptyInstance() => create();
  static $pb.PbList<SignStep1Request> createRepeated() => $pb.PbList<SignStep1Request>();
  @$core.pragma('dart2js:noInline')
  static SignStep1Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignStep1Request>(create);
  static SignStep1Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get hidingCommitment => $_getN(1);
  @$pb.TagNumber(2)
  set hidingCommitment($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHidingCommitment() => $_has(1);
  @$pb.TagNumber(2)
  void clearHidingCommitment() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get bindingCommitment => $_getN(2);
  @$pb.TagNumber(3)
  set bindingCommitment($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasBindingCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearBindingCommitment() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get messageToSign => $_getN(3);
  @$pb.TagNumber(4)
  set messageToSign($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasMessageToSign() => $_has(3);
  @$pb.TagNumber(4)
  void clearMessageToSign() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get signature => $_getN(4);
  @$pb.TagNumber(5)
  set signature($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignature() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get fullTransaction => $_getN(5);
  @$pb.TagNumber(6)
  set fullTransaction($core.List<$core.int> v) { $_setBytes(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasFullTransaction() => $_has(5);
  @$pb.TagNumber(6)
  void clearFullTransaction() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestampMs => $_getI64(6);
  @$pb.TagNumber(7)
  set timestampMs($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTimestampMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestampMs() => clearField(7);

  @$pb.TagNumber(8)
  $core.bool get scriptPathSpend => $_getBF(7);
  @$pb.TagNumber(8)
  set scriptPathSpend($core.bool v) { $_setBool(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasScriptPathSpend() => $_has(7);
  @$pb.TagNumber(8)
  void clearScriptPathSpend() => clearField(8);
}

class SignStep1Response_Commitment extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SignStep1Response.Commitment', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'hiding', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'binding', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  SignStep1Response_Commitment._() : super();
  factory SignStep1Response_Commitment({
    $core.List<$core.int>? hiding,
    $core.List<$core.int>? binding,
  }) {
    final _result = create();
    if (hiding != null) {
      _result.hiding = hiding;
    }
    if (binding != null) {
      _result.binding = binding;
    }
    return _result;
  }
  factory SignStep1Response_Commitment.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep1Response_Commitment.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep1Response_Commitment clone() => SignStep1Response_Commitment()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep1Response_Commitment copyWith(void Function(SignStep1Response_Commitment) updates) => super.copyWith((message) => updates(message as SignStep1Response_Commitment)) as SignStep1Response_Commitment; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SignStep1Response_Commitment create() => SignStep1Response_Commitment._();
  SignStep1Response_Commitment createEmptyInstance() => create();
  static $pb.PbList<SignStep1Response_Commitment> createRepeated() => $pb.PbList<SignStep1Response_Commitment>();
  @$core.pragma('dart2js:noInline')
  static SignStep1Response_Commitment getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignStep1Response_Commitment>(create);
  static SignStep1Response_Commitment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get hiding => $_getN(0);
  @$pb.TagNumber(1)
  set hiding($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasHiding() => $_has(0);
  @$pb.TagNumber(1)
  void clearHiding() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get binding => $_getN(1);
  @$pb.TagNumber(2)
  set binding($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasBinding() => $_has(1);
  @$pb.TagNumber(2)
  void clearBinding() => clearField(2);
}

class SignStep1Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SignStep1Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, SignStep1Response_Commitment>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'commitments', entryClassName: 'SignStep1Response.CommitmentsEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: SignStep1Response_Commitment.create, packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'messageToSign', $pb.PbFieldType.OY)
    ..a<$core.int>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'usedKeyIndex', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  SignStep1Response._() : super();
  factory SignStep1Response({
    $core.Map<$core.String, SignStep1Response_Commitment>? commitments,
    $core.List<$core.int>? messageToSign,
    $core.int? usedKeyIndex,
  }) {
    final _result = create();
    if (commitments != null) {
      _result.commitments.addAll(commitments);
    }
    if (messageToSign != null) {
      _result.messageToSign = messageToSign;
    }
    if (usedKeyIndex != null) {
      _result.usedKeyIndex = usedKeyIndex;
    }
    return _result;
  }
  factory SignStep1Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep1Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep1Response clone() => SignStep1Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep1Response copyWith(void Function(SignStep1Response) updates) => super.copyWith((message) => updates(message as SignStep1Response)) as SignStep1Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SignStep1Response create() => SignStep1Response._();
  SignStep1Response createEmptyInstance() => create();
  static $pb.PbList<SignStep1Response> createRepeated() => $pb.PbList<SignStep1Response>();
  @$core.pragma('dart2js:noInline')
  static SignStep1Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignStep1Response>(create);
  static SignStep1Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, SignStep1Response_Commitment> get commitments => $_getMap(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get messageToSign => $_getN(1);
  @$pb.TagNumber(2)
  set messageToSign($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessageToSign() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageToSign() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get usedKeyIndex => $_getIZ(2);
  @$pb.TagNumber(3)
  set usedKeyIndex($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasUsedKeyIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsedKeyIndex() => clearField(3);
}

class SignStep2Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SignStep2Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signatureShare', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  SignStep2Request._() : super();
  factory SignStep2Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signatureShare,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signatureShare != null) {
      _result.signatureShare = signatureShare;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory SignStep2Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep2Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep2Request clone() => SignStep2Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep2Request copyWith(void Function(SignStep2Request) updates) => super.copyWith((message) => updates(message as SignStep2Request)) as SignStep2Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SignStep2Request create() => SignStep2Request._();
  SignStep2Request createEmptyInstance() => create();
  static $pb.PbList<SignStep2Request> createRepeated() => $pb.PbList<SignStep2Request>();
  @$core.pragma('dart2js:noInline')
  static SignStep2Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignStep2Request>(create);
  static SignStep2Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signatureShare => $_getN(1);
  @$pb.TagNumber(3)
  set signatureShare($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(3)
  $core.bool hasSignatureShare() => $_has(1);
  @$pb.TagNumber(3)
  void clearSignatureShare() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(4)
  void clearSignature() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(3);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(3);
  @$pb.TagNumber(5)
  void clearTimestampMs() => clearField(5);
}

class UtxoInfo extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'UtxoInfo', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txHash')
    ..a<$core.int>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'vout', $pb.PbFieldType.O3)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'amount')
    ..hasRequiredFields = false
  ;

  UtxoInfo._() : super();
  factory UtxoInfo({
    $core.String? txHash,
    $core.int? vout,
    $fixnum.Int64? amount,
  }) {
    final _result = create();
    if (txHash != null) {
      _result.txHash = txHash;
    }
    if (vout != null) {
      _result.vout = vout;
    }
    if (amount != null) {
      _result.amount = amount;
    }
    return _result;
  }
  factory UtxoInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UtxoInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UtxoInfo clone() => UtxoInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UtxoInfo copyWith(void Function(UtxoInfo) updates) => super.copyWith((message) => updates(message as UtxoInfo)) as UtxoInfo; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static UtxoInfo create() => UtxoInfo._();
  UtxoInfo createEmptyInstance() => create();
  static $pb.PbList<UtxoInfo> createRepeated() => $pb.PbList<UtxoInfo>();
  @$core.pragma('dart2js:noInline')
  static UtxoInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UtxoInfo>(create);
  static UtxoInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txHash => $_getSZ(0);
  @$pb.TagNumber(1)
  set txHash($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTxHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxHash() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get vout => $_getIZ(1);
  @$pb.TagNumber(2)
  set vout($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasVout() => $_has(1);
  @$pb.TagNumber(2)
  void clearVout() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => clearField(3);
}

class SignStep2Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SignStep2Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'rPoint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'zScalar', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  SignStep2Response._() : super();
  factory SignStep2Response({
    $core.List<$core.int>? rPoint,
    $core.List<$core.int>? zScalar,
  }) {
    final _result = create();
    if (rPoint != null) {
      _result.rPoint = rPoint;
    }
    if (zScalar != null) {
      _result.zScalar = zScalar;
    }
    return _result;
  }
  factory SignStep2Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep2Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep2Response clone() => SignStep2Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep2Response copyWith(void Function(SignStep2Response) updates) => super.copyWith((message) => updates(message as SignStep2Response)) as SignStep2Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SignStep2Response create() => SignStep2Response._();
  SignStep2Response createEmptyInstance() => create();
  static $pb.PbList<SignStep2Response> createRepeated() => $pb.PbList<SignStep2Response>();
  @$core.pragma('dart2js:noInline')
  static SignStep2Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignStep2Response>(create);
  static SignStep2Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get rPoint => $_getN(0);
  @$pb.TagNumber(1)
  set rPoint($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRPoint() => $_has(0);
  @$pb.TagNumber(1)
  void clearRPoint() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get zScalar => $_getN(1);
  @$pb.TagNumber(2)
  set zScalar($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasZScalar() => $_has(1);
  @$pb.TagNumber(2)
  void clearZScalar() => clearField(2);
}

class RefreshStep1Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RefreshStep1Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round1Package')
    ..aInt64(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'thresholdAmount')
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'interval')
    ..a<$core.List<$core.int>>(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(7, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  RefreshStep1Request._() : super();
  factory RefreshStep1Request({
    $core.List<$core.int>? userId,
    $core.String? round1Package,
    $fixnum.Int64? thresholdAmount,
    $fixnum.Int64? interval,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (round1Package != null) {
      _result.round1Package = round1Package;
    }
    if (thresholdAmount != null) {
      _result.thresholdAmount = thresholdAmount;
    }
    if (interval != null) {
      _result.interval = interval;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory RefreshStep1Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep1Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep1Request clone() => RefreshStep1Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep1Request copyWith(void Function(RefreshStep1Request) updates) => super.copyWith((message) => updates(message as RefreshStep1Request)) as RefreshStep1Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RefreshStep1Request create() => RefreshStep1Request._();
  RefreshStep1Request createEmptyInstance() => create();
  static $pb.PbList<RefreshStep1Request> createRepeated() => $pb.PbList<RefreshStep1Request>();
  @$core.pragma('dart2js:noInline')
  static RefreshStep1Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RefreshStep1Request>(create);
  static RefreshStep1Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(3)
  $core.String get round1Package => $_getSZ(1);
  @$pb.TagNumber(3)
  set round1Package($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(3)
  $core.bool hasRound1Package() => $_has(1);
  @$pb.TagNumber(3)
  void clearRound1Package() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get thresholdAmount => $_getI64(2);
  @$pb.TagNumber(4)
  set thresholdAmount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(4)
  $core.bool hasThresholdAmount() => $_has(2);
  @$pb.TagNumber(4)
  void clearThresholdAmount() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get interval => $_getI64(3);
  @$pb.TagNumber(5)
  set interval($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(5)
  $core.bool hasInterval() => $_has(3);
  @$pb.TagNumber(5)
  void clearInterval() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get signature => $_getN(4);
  @$pb.TagNumber(6)
  set signature($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(6)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(6)
  void clearSignature() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestampMs => $_getI64(5);
  @$pb.TagNumber(7)
  set timestampMs($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(7)
  $core.bool hasTimestampMs() => $_has(5);
  @$pb.TagNumber(7)
  void clearTimestampMs() => clearField(7);
}

class RefreshStep1Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RefreshStep1Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round1Packages', entryClassName: 'RefreshStep1Response.Round1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'policyId')
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'startTime')
    ..hasRequiredFields = false
  ;

  RefreshStep1Response._() : super();
  factory RefreshStep1Response({
    $core.Map<$core.String, $core.String>? round1Packages,
    $core.String? policyId,
    $fixnum.Int64? startTime,
  }) {
    final _result = create();
    if (round1Packages != null) {
      _result.round1Packages.addAll(round1Packages);
    }
    if (policyId != null) {
      _result.policyId = policyId;
    }
    if (startTime != null) {
      _result.startTime = startTime;
    }
    return _result;
  }
  factory RefreshStep1Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep1Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep1Response clone() => RefreshStep1Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep1Response copyWith(void Function(RefreshStep1Response) updates) => super.copyWith((message) => updates(message as RefreshStep1Response)) as RefreshStep1Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RefreshStep1Response create() => RefreshStep1Response._();
  RefreshStep1Response createEmptyInstance() => create();
  static $pb.PbList<RefreshStep1Response> createRepeated() => $pb.PbList<RefreshStep1Response>();
  @$core.pragma('dart2js:noInline')
  static RefreshStep1Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RefreshStep1Response>(create);
  static RefreshStep1Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get round1Packages => $_getMap(0);

  @$pb.TagNumber(2)
  $core.String get policyId => $_getSZ(1);
  @$pb.TagNumber(2)
  set policyId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPolicyId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPolicyId() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startTime => $_getI64(2);
  @$pb.TagNumber(3)
  set startTime($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasStartTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartTime() => clearField(3);
}

class RefreshStep2Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RefreshStep2Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round1Package')
    ..a<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  RefreshStep2Request._() : super();
  factory RefreshStep2Request({
    $core.List<$core.int>? userId,
    $core.String? round1Package,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (round1Package != null) {
      _result.round1Package = round1Package;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory RefreshStep2Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep2Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep2Request clone() => RefreshStep2Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep2Request copyWith(void Function(RefreshStep2Request) updates) => super.copyWith((message) => updates(message as RefreshStep2Request)) as RefreshStep2Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RefreshStep2Request create() => RefreshStep2Request._();
  RefreshStep2Request createEmptyInstance() => create();
  static $pb.PbList<RefreshStep2Request> createRepeated() => $pb.PbList<RefreshStep2Request>();
  @$core.pragma('dart2js:noInline')
  static RefreshStep2Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RefreshStep2Request>(create);
  static RefreshStep2Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(3)
  $core.String get round1Package => $_getSZ(1);
  @$pb.TagNumber(3)
  set round1Package($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(3)
  $core.bool hasRound1Package() => $_has(1);
  @$pb.TagNumber(3)
  void clearRound1Package() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(4)
  void clearSignature() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(3);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(3);
  @$pb.TagNumber(5)
  void clearTimestampMs() => clearField(5);
}

class RefreshStep2Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RefreshStep2Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'allRound1Packages', entryClassName: 'RefreshStep2Response.AllRound1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  RefreshStep2Response._() : super();
  factory RefreshStep2Response({
    $core.Map<$core.String, $core.String>? allRound1Packages,
  }) {
    final _result = create();
    if (allRound1Packages != null) {
      _result.allRound1Packages.addAll(allRound1Packages);
    }
    return _result;
  }
  factory RefreshStep2Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep2Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep2Response clone() => RefreshStep2Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep2Response copyWith(void Function(RefreshStep2Response) updates) => super.copyWith((message) => updates(message as RefreshStep2Response)) as RefreshStep2Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RefreshStep2Response create() => RefreshStep2Response._();
  RefreshStep2Response createEmptyInstance() => create();
  static $pb.PbList<RefreshStep2Response> createRepeated() => $pb.PbList<RefreshStep2Response>();
  @$core.pragma('dart2js:noInline')
  static RefreshStep2Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RefreshStep2Response>(create);
  static RefreshStep2Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get allRound1Packages => $_getMap(0);
}

class RefreshStep3Request extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RefreshStep3Request', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round2PackagesForOthers', entryClassName: 'RefreshStep3Request.Round2PackagesForOthersEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  RefreshStep3Request._() : super();
  factory RefreshStep3Request({
    $core.List<$core.int>? userId,
    $core.Map<$core.String, $core.String>? round2PackagesForOthers,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (round2PackagesForOthers != null) {
      _result.round2PackagesForOthers.addAll(round2PackagesForOthers);
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory RefreshStep3Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep3Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep3Request clone() => RefreshStep3Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep3Request copyWith(void Function(RefreshStep3Request) updates) => super.copyWith((message) => updates(message as RefreshStep3Request)) as RefreshStep3Request; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RefreshStep3Request create() => RefreshStep3Request._();
  RefreshStep3Request createEmptyInstance() => create();
  static $pb.PbList<RefreshStep3Request> createRepeated() => $pb.PbList<RefreshStep3Request>();
  @$core.pragma('dart2js:noInline')
  static RefreshStep3Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RefreshStep3Request>(create);
  static RefreshStep3Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(3)
  $core.Map<$core.String, $core.String> get round2PackagesForOthers => $_getMap(1);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(4)
  void clearSignature() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(3);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(3);
  @$pb.TagNumber(5)
  void clearTimestampMs() => clearField(5);
}

class RefreshStep3Response extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RefreshStep3Response', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'round2PackagesForMe', entryClassName: 'RefreshStep3Response.Round2PackagesForMeEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  RefreshStep3Response._() : super();
  factory RefreshStep3Response({
    $core.Map<$core.String, $core.String>? round2PackagesForMe,
  }) {
    final _result = create();
    if (round2PackagesForMe != null) {
      _result.round2PackagesForMe.addAll(round2PackagesForMe);
    }
    return _result;
  }
  factory RefreshStep3Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep3Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep3Response clone() => RefreshStep3Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep3Response copyWith(void Function(RefreshStep3Response) updates) => super.copyWith((message) => updates(message as RefreshStep3Response)) as RefreshStep3Response; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RefreshStep3Response create() => RefreshStep3Response._();
  RefreshStep3Response createEmptyInstance() => create();
  static $pb.PbList<RefreshStep3Response> createRepeated() => $pb.PbList<RefreshStep3Response>();
  @$core.pragma('dart2js:noInline')
  static RefreshStep3Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RefreshStep3Response>(create);
  static RefreshStep3Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get round2PackagesForMe => $_getMap(0);
}

class GetPolicyIdRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetPolicyIdRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txMessage', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  GetPolicyIdRequest._() : super();
  factory GetPolicyIdRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? txMessage,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (txMessage != null) {
      _result.txMessage = txMessage;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory GetPolicyIdRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetPolicyIdRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetPolicyIdRequest clone() => GetPolicyIdRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetPolicyIdRequest copyWith(void Function(GetPolicyIdRequest) updates) => super.copyWith((message) => updates(message as GetPolicyIdRequest)) as GetPolicyIdRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetPolicyIdRequest create() => GetPolicyIdRequest._();
  GetPolicyIdRequest createEmptyInstance() => create();
  static $pb.PbList<GetPolicyIdRequest> createRepeated() => $pb.PbList<GetPolicyIdRequest>();
  @$core.pragma('dart2js:noInline')
  static GetPolicyIdRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetPolicyIdRequest>(create);
  static GetPolicyIdRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get txMessage => $_getN(1);
  @$pb.TagNumber(2)
  set txMessage($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTxMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearTxMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(3)
  set signature($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignature() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestampMs => $_getI64(3);
  @$pb.TagNumber(4)
  set timestampMs($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTimestampMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestampMs() => clearField(4);
}

class GetPolicyIdResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetPolicyIdResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'policyId')
    ..hasRequiredFields = false
  ;

  GetPolicyIdResponse._() : super();
  factory GetPolicyIdResponse({
    $core.String? policyId,
  }) {
    final _result = create();
    if (policyId != null) {
      _result.policyId = policyId;
    }
    return _result;
  }
  factory GetPolicyIdResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetPolicyIdResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetPolicyIdResponse clone() => GetPolicyIdResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetPolicyIdResponse copyWith(void Function(GetPolicyIdResponse) updates) => super.copyWith((message) => updates(message as GetPolicyIdResponse)) as GetPolicyIdResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetPolicyIdResponse create() => GetPolicyIdResponse._();
  GetPolicyIdResponse createEmptyInstance() => create();
  static $pb.PbList<GetPolicyIdResponse> createRepeated() => $pb.PbList<GetPolicyIdResponse>();
  @$core.pragma('dart2js:noInline')
  static GetPolicyIdResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetPolicyIdResponse>(create);
  static GetPolicyIdResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get policyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set policyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPolicyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPolicyId() => clearField(1);
}

class UpdatePolicyRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'UpdatePolicyRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'policyId')
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'thresholdSats')
    ..aInt64(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'intervalSeconds')
    ..a<$core.List<$core.int>>(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'frostSignatureR', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'frostSignatureZ', $pb.PbFieldType.OY)
    ..aInt64(7, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  UpdatePolicyRequest._() : super();
  factory UpdatePolicyRequest({
    $core.List<$core.int>? userId,
    $core.String? policyId,
    $fixnum.Int64? thresholdSats,
    $fixnum.Int64? intervalSeconds,
    $core.List<$core.int>? frostSignatureR,
    $core.List<$core.int>? frostSignatureZ,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (policyId != null) {
      _result.policyId = policyId;
    }
    if (thresholdSats != null) {
      _result.thresholdSats = thresholdSats;
    }
    if (intervalSeconds != null) {
      _result.intervalSeconds = intervalSeconds;
    }
    if (frostSignatureR != null) {
      _result.frostSignatureR = frostSignatureR;
    }
    if (frostSignatureZ != null) {
      _result.frostSignatureZ = frostSignatureZ;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory UpdatePolicyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdatePolicyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdatePolicyRequest clone() => UpdatePolicyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdatePolicyRequest copyWith(void Function(UpdatePolicyRequest) updates) => super.copyWith((message) => updates(message as UpdatePolicyRequest)) as UpdatePolicyRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static UpdatePolicyRequest create() => UpdatePolicyRequest._();
  UpdatePolicyRequest createEmptyInstance() => create();
  static $pb.PbList<UpdatePolicyRequest> createRepeated() => $pb.PbList<UpdatePolicyRequest>();
  @$core.pragma('dart2js:noInline')
  static UpdatePolicyRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdatePolicyRequest>(create);
  static UpdatePolicyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get policyId => $_getSZ(1);
  @$pb.TagNumber(2)
  set policyId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPolicyId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPolicyId() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get thresholdSats => $_getI64(2);
  @$pb.TagNumber(3)
  set thresholdSats($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasThresholdSats() => $_has(2);
  @$pb.TagNumber(3)
  void clearThresholdSats() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get intervalSeconds => $_getI64(3);
  @$pb.TagNumber(4)
  set intervalSeconds($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIntervalSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearIntervalSeconds() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get frostSignatureR => $_getN(4);
  @$pb.TagNumber(5)
  set frostSignatureR($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasFrostSignatureR() => $_has(4);
  @$pb.TagNumber(5)
  void clearFrostSignatureR() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get frostSignatureZ => $_getN(5);
  @$pb.TagNumber(6)
  set frostSignatureZ($core.List<$core.int> v) { $_setBytes(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasFrostSignatureZ() => $_has(5);
  @$pb.TagNumber(6)
  void clearFrostSignatureZ() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestampMs => $_getI64(6);
  @$pb.TagNumber(7)
  set timestampMs($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasTimestampMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestampMs() => clearField(7);
}

class UpdatePolicyResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'UpdatePolicyResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'success')
    ..hasRequiredFields = false
  ;

  UpdatePolicyResponse._() : super();
  factory UpdatePolicyResponse({
    $core.bool? success,
  }) {
    final _result = create();
    if (success != null) {
      _result.success = success;
    }
    return _result;
  }
  factory UpdatePolicyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdatePolicyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdatePolicyResponse clone() => UpdatePolicyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdatePolicyResponse copyWith(void Function(UpdatePolicyResponse) updates) => super.copyWith((message) => updates(message as UpdatePolicyResponse)) as UpdatePolicyResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static UpdatePolicyResponse create() => UpdatePolicyResponse._();
  UpdatePolicyResponse createEmptyInstance() => create();
  static $pb.PbList<UpdatePolicyResponse> createRepeated() => $pb.PbList<UpdatePolicyResponse>();
  @$core.pragma('dart2js:noInline')
  static UpdatePolicyResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdatePolicyResponse>(create);
  static UpdatePolicyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

class DeletePolicyRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DeletePolicyRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'policyId')
    ..a<$core.List<$core.int>>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'frostSignatureR', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'frostSignatureZ', $pb.PbFieldType.OY)
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  DeletePolicyRequest._() : super();
  factory DeletePolicyRequest({
    $core.List<$core.int>? userId,
    $core.String? policyId,
    $core.List<$core.int>? frostSignatureR,
    $core.List<$core.int>? frostSignatureZ,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (policyId != null) {
      _result.policyId = policyId;
    }
    if (frostSignatureR != null) {
      _result.frostSignatureR = frostSignatureR;
    }
    if (frostSignatureZ != null) {
      _result.frostSignatureZ = frostSignatureZ;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory DeletePolicyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeletePolicyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeletePolicyRequest clone() => DeletePolicyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeletePolicyRequest copyWith(void Function(DeletePolicyRequest) updates) => super.copyWith((message) => updates(message as DeletePolicyRequest)) as DeletePolicyRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DeletePolicyRequest create() => DeletePolicyRequest._();
  DeletePolicyRequest createEmptyInstance() => create();
  static $pb.PbList<DeletePolicyRequest> createRepeated() => $pb.PbList<DeletePolicyRequest>();
  @$core.pragma('dart2js:noInline')
  static DeletePolicyRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeletePolicyRequest>(create);
  static DeletePolicyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get policyId => $_getSZ(1);
  @$pb.TagNumber(2)
  set policyId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPolicyId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPolicyId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get frostSignatureR => $_getN(2);
  @$pb.TagNumber(3)
  set frostSignatureR($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFrostSignatureR() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrostSignatureR() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get frostSignatureZ => $_getN(3);
  @$pb.TagNumber(4)
  set frostSignatureZ($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasFrostSignatureZ() => $_has(3);
  @$pb.TagNumber(4)
  void clearFrostSignatureZ() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestampMs() => clearField(5);
}

class DeletePolicyResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'DeletePolicyResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'success')
    ..hasRequiredFields = false
  ;

  DeletePolicyResponse._() : super();
  factory DeletePolicyResponse({
    $core.bool? success,
  }) {
    final _result = create();
    if (success != null) {
      _result.success = success;
    }
    return _result;
  }
  factory DeletePolicyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeletePolicyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeletePolicyResponse clone() => DeletePolicyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeletePolicyResponse copyWith(void Function(DeletePolicyResponse) updates) => super.copyWith((message) => updates(message as DeletePolicyResponse)) as DeletePolicyResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DeletePolicyResponse create() => DeletePolicyResponse._();
  DeletePolicyResponse createEmptyInstance() => create();
  static $pb.PbList<DeletePolicyResponse> createRepeated() => $pb.PbList<DeletePolicyResponse>();
  @$core.pragma('dart2js:noInline')
  static DeletePolicyResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeletePolicyResponse>(create);
  static DeletePolicyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);
}

class BroadcastTransactionRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'BroadcastTransactionRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txHex')
    ..hasRequiredFields = false
  ;

  BroadcastTransactionRequest._() : super();
  factory BroadcastTransactionRequest({
    $core.List<$core.int>? userId,
    $core.String? txHex,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (txHex != null) {
      _result.txHex = txHex;
    }
    return _result;
  }
  factory BroadcastTransactionRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastTransactionRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastTransactionRequest clone() => BroadcastTransactionRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastTransactionRequest copyWith(void Function(BroadcastTransactionRequest) updates) => super.copyWith((message) => updates(message as BroadcastTransactionRequest)) as BroadcastTransactionRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionRequest create() => BroadcastTransactionRequest._();
  BroadcastTransactionRequest createEmptyInstance() => create();
  static $pb.PbList<BroadcastTransactionRequest> createRepeated() => $pb.PbList<BroadcastTransactionRequest>();
  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastTransactionRequest>(create);
  static BroadcastTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get txHex => $_getSZ(1);
  @$pb.TagNumber(2)
  set txHex($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTxHex() => $_has(1);
  @$pb.TagNumber(2)
  void clearTxHex() => clearField(2);
}

class BroadcastTransactionResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'BroadcastTransactionResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txId')
    ..hasRequiredFields = false
  ;

  BroadcastTransactionResponse._() : super();
  factory BroadcastTransactionResponse({
    $core.String? txId,
  }) {
    final _result = create();
    if (txId != null) {
      _result.txId = txId;
    }
    return _result;
  }
  factory BroadcastTransactionResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastTransactionResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastTransactionResponse clone() => BroadcastTransactionResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastTransactionResponse copyWith(void Function(BroadcastTransactionResponse) updates) => super.copyWith((message) => updates(message as BroadcastTransactionResponse)) as BroadcastTransactionResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionResponse create() => BroadcastTransactionResponse._();
  BroadcastTransactionResponse createEmptyInstance() => create();
  static $pb.PbList<BroadcastTransactionResponse> createRepeated() => $pb.PbList<BroadcastTransactionResponse>();
  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BroadcastTransactionResponse>(create);
  static BroadcastTransactionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txId => $_getSZ(0);
  @$pb.TagNumber(1)
  set txId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTxId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxId() => clearField(1);
}

class FetchHistoryRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'FetchHistoryRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  FetchHistoryRequest._() : super();
  factory FetchHistoryRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory FetchHistoryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchHistoryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchHistoryRequest clone() => FetchHistoryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchHistoryRequest copyWith(void Function(FetchHistoryRequest) updates) => super.copyWith((message) => updates(message as FetchHistoryRequest)) as FetchHistoryRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static FetchHistoryRequest create() => FetchHistoryRequest._();
  FetchHistoryRequest createEmptyInstance() => create();
  static $pb.PbList<FetchHistoryRequest> createRepeated() => $pb.PbList<FetchHistoryRequest>();
  @$core.pragma('dart2js:noInline')
  static FetchHistoryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FetchHistoryRequest>(create);
  static FetchHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class FetchHistoryResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'FetchHistoryResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<UtxoInfo>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'utxos', $pb.PbFieldType.PM, subBuilder: UtxoInfo.create)
    ..hasRequiredFields = false
  ;

  FetchHistoryResponse._() : super();
  factory FetchHistoryResponse({
    $core.Iterable<UtxoInfo>? utxos,
  }) {
    final _result = create();
    if (utxos != null) {
      _result.utxos.addAll(utxos);
    }
    return _result;
  }
  factory FetchHistoryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchHistoryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchHistoryResponse clone() => FetchHistoryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchHistoryResponse copyWith(void Function(FetchHistoryResponse) updates) => super.copyWith((message) => updates(message as FetchHistoryResponse)) as FetchHistoryResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static FetchHistoryResponse create() => FetchHistoryResponse._();
  FetchHistoryResponse createEmptyInstance() => create();
  static $pb.PbList<FetchHistoryResponse> createRepeated() => $pb.PbList<FetchHistoryResponse>();
  @$core.pragma('dart2js:noInline')
  static FetchHistoryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FetchHistoryResponse>(create);
  static FetchHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<UtxoInfo> get utxos => $_getList(0);
}

class FetchRecentTransactionsRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'FetchRecentTransactionsRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  FetchRecentTransactionsRequest._() : super();
  factory FetchRecentTransactionsRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory FetchRecentTransactionsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchRecentTransactionsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsRequest clone() => FetchRecentTransactionsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsRequest copyWith(void Function(FetchRecentTransactionsRequest) updates) => super.copyWith((message) => updates(message as FetchRecentTransactionsRequest)) as FetchRecentTransactionsRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsRequest create() => FetchRecentTransactionsRequest._();
  FetchRecentTransactionsRequest createEmptyInstance() => create();
  static $pb.PbList<FetchRecentTransactionsRequest> createRepeated() => $pb.PbList<FetchRecentTransactionsRequest>();
  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FetchRecentTransactionsRequest>(create);
  static FetchRecentTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class FetchRecentTransactionsResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'FetchRecentTransactionsResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<TransactionSummary>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'transactions', $pb.PbFieldType.PM, subBuilder: TransactionSummary.create)
    ..hasRequiredFields = false
  ;

  FetchRecentTransactionsResponse._() : super();
  factory FetchRecentTransactionsResponse({
    $core.Iterable<TransactionSummary>? transactions,
  }) {
    final _result = create();
    if (transactions != null) {
      _result.transactions.addAll(transactions);
    }
    return _result;
  }
  factory FetchRecentTransactionsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchRecentTransactionsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsResponse clone() => FetchRecentTransactionsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsResponse copyWith(void Function(FetchRecentTransactionsResponse) updates) => super.copyWith((message) => updates(message as FetchRecentTransactionsResponse)) as FetchRecentTransactionsResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsResponse create() => FetchRecentTransactionsResponse._();
  FetchRecentTransactionsResponse createEmptyInstance() => create();
  static $pb.PbList<FetchRecentTransactionsResponse> createRepeated() => $pb.PbList<FetchRecentTransactionsResponse>();
  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FetchRecentTransactionsResponse>(create);
  static FetchRecentTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<TransactionSummary> get transactions => $_getList(0);
}

class TransactionSummary extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'TransactionSummary', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txHash')
    ..aInt64(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'amountSats')
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestamp')
    ..aOB(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'isPending')
    ..hasRequiredFields = false
  ;

  TransactionSummary._() : super();
  factory TransactionSummary({
    $core.String? txHash,
    $fixnum.Int64? amountSats,
    $fixnum.Int64? timestamp,
    $core.bool? isPending,
  }) {
    final _result = create();
    if (txHash != null) {
      _result.txHash = txHash;
    }
    if (amountSats != null) {
      _result.amountSats = amountSats;
    }
    if (timestamp != null) {
      _result.timestamp = timestamp;
    }
    if (isPending != null) {
      _result.isPending = isPending;
    }
    return _result;
  }
  factory TransactionSummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TransactionSummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TransactionSummary clone() => TransactionSummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TransactionSummary copyWith(void Function(TransactionSummary) updates) => super.copyWith((message) => updates(message as TransactionSummary)) as TransactionSummary; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static TransactionSummary create() => TransactionSummary._();
  TransactionSummary createEmptyInstance() => create();
  static $pb.PbList<TransactionSummary> createRepeated() => $pb.PbList<TransactionSummary>();
  @$core.pragma('dart2js:noInline')
  static TransactionSummary getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransactionSummary>(create);
  static TransactionSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txHash => $_getSZ(0);
  @$pb.TagNumber(1)
  set txHash($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTxHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxHash() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amountSats => $_getI64(1);
  @$pb.TagNumber(2)
  set amountSats($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAmountSats() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmountSats() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestamp => $_getI64(2);
  @$pb.TagNumber(3)
  set timestamp($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestamp() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isPending => $_getBF(3);
  @$pb.TagNumber(4)
  set isPending($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIsPending() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsPending() => clearField(4);
}

class SubscribeToHistoryRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SubscribeToHistoryRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  SubscribeToHistoryRequest._() : super();
  factory SubscribeToHistoryRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory SubscribeToHistoryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubscribeToHistoryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubscribeToHistoryRequest clone() => SubscribeToHistoryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubscribeToHistoryRequest copyWith(void Function(SubscribeToHistoryRequest) updates) => super.copyWith((message) => updates(message as SubscribeToHistoryRequest)) as SubscribeToHistoryRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SubscribeToHistoryRequest create() => SubscribeToHistoryRequest._();
  SubscribeToHistoryRequest createEmptyInstance() => create();
  static $pb.PbList<SubscribeToHistoryRequest> createRepeated() => $pb.PbList<SubscribeToHistoryRequest>();
  @$core.pragma('dart2js:noInline')
  static SubscribeToHistoryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubscribeToHistoryRequest>(create);
  static SubscribeToHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class TransactionNotification extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'TransactionNotification', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txHash')
    ..a<$core.int>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'height', $pb.PbFieldType.O3)
    ..pc<UtxoInfo>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'addedUtxos', $pb.PbFieldType.PM, subBuilder: UtxoInfo.create)
    ..pc<UtxoInfo>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'spentUtxos', $pb.PbFieldType.PM, subBuilder: UtxoInfo.create)
    ..hasRequiredFields = false
  ;

  TransactionNotification._() : super();
  factory TransactionNotification({
    $core.String? txHash,
    $core.int? height,
    $core.Iterable<UtxoInfo>? addedUtxos,
    $core.Iterable<UtxoInfo>? spentUtxos,
  }) {
    final _result = create();
    if (txHash != null) {
      _result.txHash = txHash;
    }
    if (height != null) {
      _result.height = height;
    }
    if (addedUtxos != null) {
      _result.addedUtxos.addAll(addedUtxos);
    }
    if (spentUtxos != null) {
      _result.spentUtxos.addAll(spentUtxos);
    }
    return _result;
  }
  factory TransactionNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TransactionNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TransactionNotification clone() => TransactionNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TransactionNotification copyWith(void Function(TransactionNotification) updates) => super.copyWith((message) => updates(message as TransactionNotification)) as TransactionNotification; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static TransactionNotification create() => TransactionNotification._();
  TransactionNotification createEmptyInstance() => create();
  static $pb.PbList<TransactionNotification> createRepeated() => $pb.PbList<TransactionNotification>();
  @$core.pragma('dart2js:noInline')
  static TransactionNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransactionNotification>(create);
  static TransactionNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txHash => $_getSZ(0);
  @$pb.TagNumber(1)
  set txHash($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTxHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxHash() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<UtxoInfo> get addedUtxos => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<UtxoInfo> get spentUtxos => $_getList(3);
}

class GetArkInfoRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetArkInfoRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  GetArkInfoRequest._() : super();
  factory GetArkInfoRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory GetArkInfoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkInfoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkInfoRequest clone() => GetArkInfoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkInfoRequest copyWith(void Function(GetArkInfoRequest) updates) => super.copyWith((message) => updates(message as GetArkInfoRequest)) as GetArkInfoRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetArkInfoRequest create() => GetArkInfoRequest._();
  GetArkInfoRequest createEmptyInstance() => create();
  static $pb.PbList<GetArkInfoRequest> createRepeated() => $pb.PbList<GetArkInfoRequest>();
  @$core.pragma('dart2js:noInline')
  static GetArkInfoRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetArkInfoRequest>(create);
  static GetArkInfoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class GetArkInfoResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetArkInfoResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signerPubkey')
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'forfeitPubkey')
    ..aOS(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'network')
    ..aInt64(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'sessionDuration')
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'unilateralExitDelay')
    ..aInt64(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'boardingExitDelay')
    ..aInt64(7, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'vtxoMinAmount')
    ..aInt64(8, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'dust')
    ..aOS(9, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'checkpointTapscript')
    ..aOS(10, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'forfeitAddress')
    ..hasRequiredFields = false
  ;

  GetArkInfoResponse._() : super();
  factory GetArkInfoResponse({
    $core.String? signerPubkey,
    $core.String? forfeitPubkey,
    $core.String? network,
    $fixnum.Int64? sessionDuration,
    $fixnum.Int64? unilateralExitDelay,
    $fixnum.Int64? boardingExitDelay,
    $fixnum.Int64? vtxoMinAmount,
    $fixnum.Int64? dust,
    $core.String? checkpointTapscript,
    $core.String? forfeitAddress,
  }) {
    final _result = create();
    if (signerPubkey != null) {
      _result.signerPubkey = signerPubkey;
    }
    if (forfeitPubkey != null) {
      _result.forfeitPubkey = forfeitPubkey;
    }
    if (network != null) {
      _result.network = network;
    }
    if (sessionDuration != null) {
      _result.sessionDuration = sessionDuration;
    }
    if (unilateralExitDelay != null) {
      _result.unilateralExitDelay = unilateralExitDelay;
    }
    if (boardingExitDelay != null) {
      _result.boardingExitDelay = boardingExitDelay;
    }
    if (vtxoMinAmount != null) {
      _result.vtxoMinAmount = vtxoMinAmount;
    }
    if (dust != null) {
      _result.dust = dust;
    }
    if (checkpointTapscript != null) {
      _result.checkpointTapscript = checkpointTapscript;
    }
    if (forfeitAddress != null) {
      _result.forfeitAddress = forfeitAddress;
    }
    return _result;
  }
  factory GetArkInfoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkInfoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkInfoResponse clone() => GetArkInfoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkInfoResponse copyWith(void Function(GetArkInfoResponse) updates) => super.copyWith((message) => updates(message as GetArkInfoResponse)) as GetArkInfoResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetArkInfoResponse create() => GetArkInfoResponse._();
  GetArkInfoResponse createEmptyInstance() => create();
  static $pb.PbList<GetArkInfoResponse> createRepeated() => $pb.PbList<GetArkInfoResponse>();
  @$core.pragma('dart2js:noInline')
  static GetArkInfoResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetArkInfoResponse>(create);
  static GetArkInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get signerPubkey => $_getSZ(0);
  @$pb.TagNumber(1)
  set signerPubkey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSignerPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignerPubkey() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get forfeitPubkey => $_getSZ(1);
  @$pb.TagNumber(2)
  set forfeitPubkey($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasForfeitPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearForfeitPubkey() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get network => $_getSZ(2);
  @$pb.TagNumber(3)
  set network($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNetwork() => $_has(2);
  @$pb.TagNumber(3)
  void clearNetwork() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sessionDuration => $_getI64(3);
  @$pb.TagNumber(4)
  set sessionDuration($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSessionDuration() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionDuration() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get unilateralExitDelay => $_getI64(4);
  @$pb.TagNumber(5)
  set unilateralExitDelay($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasUnilateralExitDelay() => $_has(4);
  @$pb.TagNumber(5)
  void clearUnilateralExitDelay() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get boardingExitDelay => $_getI64(5);
  @$pb.TagNumber(6)
  set boardingExitDelay($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasBoardingExitDelay() => $_has(5);
  @$pb.TagNumber(6)
  void clearBoardingExitDelay() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get vtxoMinAmount => $_getI64(6);
  @$pb.TagNumber(7)
  set vtxoMinAmount($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasVtxoMinAmount() => $_has(6);
  @$pb.TagNumber(7)
  void clearVtxoMinAmount() => clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get dust => $_getI64(7);
  @$pb.TagNumber(8)
  set dust($fixnum.Int64 v) { $_setInt64(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasDust() => $_has(7);
  @$pb.TagNumber(8)
  void clearDust() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get checkpointTapscript => $_getSZ(8);
  @$pb.TagNumber(9)
  set checkpointTapscript($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasCheckpointTapscript() => $_has(8);
  @$pb.TagNumber(9)
  void clearCheckpointTapscript() => clearField(9);

  @$pb.TagNumber(10)
  $core.String get forfeitAddress => $_getSZ(9);
  @$pb.TagNumber(10)
  set forfeitAddress($core.String v) { $_setString(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasForfeitAddress() => $_has(9);
  @$pb.TagNumber(10)
  void clearForfeitAddress() => clearField(10);
}

class GetArkAddressRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetArkAddressRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  GetArkAddressRequest._() : super();
  factory GetArkAddressRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory GetArkAddressRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkAddressRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkAddressRequest clone() => GetArkAddressRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkAddressRequest copyWith(void Function(GetArkAddressRequest) updates) => super.copyWith((message) => updates(message as GetArkAddressRequest)) as GetArkAddressRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetArkAddressRequest create() => GetArkAddressRequest._();
  GetArkAddressRequest createEmptyInstance() => create();
  static $pb.PbList<GetArkAddressRequest> createRepeated() => $pb.PbList<GetArkAddressRequest>();
  @$core.pragma('dart2js:noInline')
  static GetArkAddressRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetArkAddressRequest>(create);
  static GetArkAddressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class GetArkAddressResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetArkAddressResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'arkAddress')
    ..hasRequiredFields = false
  ;

  GetArkAddressResponse._() : super();
  factory GetArkAddressResponse({
    $core.String? arkAddress,
  }) {
    final _result = create();
    if (arkAddress != null) {
      _result.arkAddress = arkAddress;
    }
    return _result;
  }
  factory GetArkAddressResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkAddressResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkAddressResponse clone() => GetArkAddressResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkAddressResponse copyWith(void Function(GetArkAddressResponse) updates) => super.copyWith((message) => updates(message as GetArkAddressResponse)) as GetArkAddressResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetArkAddressResponse create() => GetArkAddressResponse._();
  GetArkAddressResponse createEmptyInstance() => create();
  static $pb.PbList<GetArkAddressResponse> createRepeated() => $pb.PbList<GetArkAddressResponse>();
  @$core.pragma('dart2js:noInline')
  static GetArkAddressResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetArkAddressResponse>(create);
  static GetArkAddressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get arkAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set arkAddress($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasArkAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearArkAddress() => clearField(1);
}

class GetBoardingAddressRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetBoardingAddressRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  GetBoardingAddressRequest._() : super();
  factory GetBoardingAddressRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory GetBoardingAddressRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBoardingAddressRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBoardingAddressRequest clone() => GetBoardingAddressRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBoardingAddressRequest copyWith(void Function(GetBoardingAddressRequest) updates) => super.copyWith((message) => updates(message as GetBoardingAddressRequest)) as GetBoardingAddressRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressRequest create() => GetBoardingAddressRequest._();
  GetBoardingAddressRequest createEmptyInstance() => create();
  static $pb.PbList<GetBoardingAddressRequest> createRepeated() => $pb.PbList<GetBoardingAddressRequest>();
  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetBoardingAddressRequest>(create);
  static GetBoardingAddressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class GetBoardingAddressResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'GetBoardingAddressResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'boardingAddress')
    ..hasRequiredFields = false
  ;

  GetBoardingAddressResponse._() : super();
  factory GetBoardingAddressResponse({
    $core.String? boardingAddress,
  }) {
    final _result = create();
    if (boardingAddress != null) {
      _result.boardingAddress = boardingAddress;
    }
    return _result;
  }
  factory GetBoardingAddressResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBoardingAddressResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBoardingAddressResponse clone() => GetBoardingAddressResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBoardingAddressResponse copyWith(void Function(GetBoardingAddressResponse) updates) => super.copyWith((message) => updates(message as GetBoardingAddressResponse)) as GetBoardingAddressResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressResponse create() => GetBoardingAddressResponse._();
  GetBoardingAddressResponse createEmptyInstance() => create();
  static $pb.PbList<GetBoardingAddressResponse> createRepeated() => $pb.PbList<GetBoardingAddressResponse>();
  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetBoardingAddressResponse>(create);
  static GetBoardingAddressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get boardingAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set boardingAddress($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBoardingAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearBoardingAddress() => clearField(1);
}

class VtxoInfo extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'VtxoInfo', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txid')
    ..a<$core.int>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'vout', $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'amount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'createdAt')
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'expiresAt')
    ..aOS(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'status')
    ..aOB(7, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'isPreconfirmed')
    ..a<$core.int>(8, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'exitDelay', $pb.PbFieldType.OU3)
    ..aOS(9, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'script')
    ..hasRequiredFields = false
  ;

  VtxoInfo._() : super();
  factory VtxoInfo({
    $core.String? txid,
    $core.int? vout,
    $fixnum.Int64? amount,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? expiresAt,
    $core.String? status,
    $core.bool? isPreconfirmed,
    $core.int? exitDelay,
    $core.String? script,
  }) {
    final _result = create();
    if (txid != null) {
      _result.txid = txid;
    }
    if (vout != null) {
      _result.vout = vout;
    }
    if (amount != null) {
      _result.amount = amount;
    }
    if (createdAt != null) {
      _result.createdAt = createdAt;
    }
    if (expiresAt != null) {
      _result.expiresAt = expiresAt;
    }
    if (status != null) {
      _result.status = status;
    }
    if (isPreconfirmed != null) {
      _result.isPreconfirmed = isPreconfirmed;
    }
    if (exitDelay != null) {
      _result.exitDelay = exitDelay;
    }
    if (script != null) {
      _result.script = script;
    }
    return _result;
  }
  factory VtxoInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory VtxoInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  VtxoInfo clone() => VtxoInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  VtxoInfo copyWith(void Function(VtxoInfo) updates) => super.copyWith((message) => updates(message as VtxoInfo)) as VtxoInfo; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static VtxoInfo create() => VtxoInfo._();
  VtxoInfo createEmptyInstance() => create();
  static $pb.PbList<VtxoInfo> createRepeated() => $pb.PbList<VtxoInfo>();
  @$core.pragma('dart2js:noInline')
  static VtxoInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<VtxoInfo>(create);
  static VtxoInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txid => $_getSZ(0);
  @$pb.TagNumber(1)
  set txid($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTxid() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxid() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get vout => $_getIZ(1);
  @$pb.TagNumber(2)
  set vout($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasVout() => $_has(1);
  @$pb.TagNumber(2)
  void clearVout() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get createdAt => $_getI64(3);
  @$pb.TagNumber(4)
  set createdAt($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCreatedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreatedAt() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get expiresAt => $_getI64(4);
  @$pb.TagNumber(5)
  set expiresAt($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasExpiresAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearExpiresAt() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get status => $_getSZ(5);
  @$pb.TagNumber(6)
  set status($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isPreconfirmed => $_getBF(6);
  @$pb.TagNumber(7)
  set isPreconfirmed($core.bool v) { $_setBool(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasIsPreconfirmed() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsPreconfirmed() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get exitDelay => $_getIZ(7);
  @$pb.TagNumber(8)
  set exitDelay($core.int v) { $_setUnsignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasExitDelay() => $_has(7);
  @$pb.TagNumber(8)
  void clearExitDelay() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get script => $_getSZ(8);
  @$pb.TagNumber(9)
  set script($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasScript() => $_has(8);
  @$pb.TagNumber(9)
  void clearScript() => clearField(9);
}

class ListVtxosRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'ListVtxosRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  ListVtxosRequest._() : super();
  factory ListVtxosRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory ListVtxosRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListVtxosRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListVtxosRequest clone() => ListVtxosRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListVtxosRequest copyWith(void Function(ListVtxosRequest) updates) => super.copyWith((message) => updates(message as ListVtxosRequest)) as ListVtxosRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static ListVtxosRequest create() => ListVtxosRequest._();
  ListVtxosRequest createEmptyInstance() => create();
  static $pb.PbList<ListVtxosRequest> createRepeated() => $pb.PbList<ListVtxosRequest>();
  @$core.pragma('dart2js:noInline')
  static ListVtxosRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListVtxosRequest>(create);
  static ListVtxosRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class ListVtxosResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'ListVtxosResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<VtxoInfo>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'vtxos', $pb.PbFieldType.PM, subBuilder: VtxoInfo.create)
    ..a<$fixnum.Int64>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'totalBalance', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  ListVtxosResponse._() : super();
  factory ListVtxosResponse({
    $core.Iterable<VtxoInfo>? vtxos,
    $fixnum.Int64? totalBalance,
  }) {
    final _result = create();
    if (vtxos != null) {
      _result.vtxos.addAll(vtxos);
    }
    if (totalBalance != null) {
      _result.totalBalance = totalBalance;
    }
    return _result;
  }
  factory ListVtxosResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListVtxosResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListVtxosResponse clone() => ListVtxosResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListVtxosResponse copyWith(void Function(ListVtxosResponse) updates) => super.copyWith((message) => updates(message as ListVtxosResponse)) as ListVtxosResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static ListVtxosResponse create() => ListVtxosResponse._();
  ListVtxosResponse createEmptyInstance() => create();
  static $pb.PbList<ListVtxosResponse> createRepeated() => $pb.PbList<ListVtxosResponse>();
  @$core.pragma('dart2js:noInline')
  static ListVtxosResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListVtxosResponse>(create);
  static ListVtxosResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<VtxoInfo> get vtxos => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalBalance => $_getI64(1);
  @$pb.TagNumber(2)
  set totalBalance($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTotalBalance() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalBalance() => clearField(2);
}

class CheckBoardingBalanceRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'CheckBoardingBalanceRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  CheckBoardingBalanceRequest._() : super();
  factory CheckBoardingBalanceRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory CheckBoardingBalanceRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CheckBoardingBalanceRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceRequest clone() => CheckBoardingBalanceRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceRequest copyWith(void Function(CheckBoardingBalanceRequest) updates) => super.copyWith((message) => updates(message as CheckBoardingBalanceRequest)) as CheckBoardingBalanceRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceRequest create() => CheckBoardingBalanceRequest._();
  CheckBoardingBalanceRequest createEmptyInstance() => create();
  static $pb.PbList<CheckBoardingBalanceRequest> createRepeated() => $pb.PbList<CheckBoardingBalanceRequest>();
  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CheckBoardingBalanceRequest>(create);
  static CheckBoardingBalanceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class CheckBoardingBalanceResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'CheckBoardingBalanceResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'balance', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'utxoCount', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  CheckBoardingBalanceResponse._() : super();
  factory CheckBoardingBalanceResponse({
    $fixnum.Int64? balance,
    $core.int? utxoCount,
  }) {
    final _result = create();
    if (balance != null) {
      _result.balance = balance;
    }
    if (utxoCount != null) {
      _result.utxoCount = utxoCount;
    }
    return _result;
  }
  factory CheckBoardingBalanceResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CheckBoardingBalanceResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceResponse clone() => CheckBoardingBalanceResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceResponse copyWith(void Function(CheckBoardingBalanceResponse) updates) => super.copyWith((message) => updates(message as CheckBoardingBalanceResponse)) as CheckBoardingBalanceResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceResponse create() => CheckBoardingBalanceResponse._();
  CheckBoardingBalanceResponse createEmptyInstance() => create();
  static $pb.PbList<CheckBoardingBalanceResponse> createRepeated() => $pb.PbList<CheckBoardingBalanceResponse>();
  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CheckBoardingBalanceResponse>(create);
  static CheckBoardingBalanceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get balance => $_getI64(0);
  @$pb.TagNumber(1)
  set balance($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBalance() => $_has(0);
  @$pb.TagNumber(1)
  void clearBalance() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get utxoCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set utxoCount($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUtxoCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearUtxoCount() => clearField(2);
}

class ArkTransactionSummary extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'ArkTransactionSummary', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txType')
    ..aInt64(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'amountSats')
    ..aOS(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txid')
    ..aInt64(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestamp')
    ..hasRequiredFields = false
  ;

  ArkTransactionSummary._() : super();
  factory ArkTransactionSummary({
    $core.String? txType,
    $fixnum.Int64? amountSats,
    $core.String? txid,
    $fixnum.Int64? timestamp,
  }) {
    final _result = create();
    if (txType != null) {
      _result.txType = txType;
    }
    if (amountSats != null) {
      _result.amountSats = amountSats;
    }
    if (txid != null) {
      _result.txid = txid;
    }
    if (timestamp != null) {
      _result.timestamp = timestamp;
    }
    return _result;
  }
  factory ArkTransactionSummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ArkTransactionSummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ArkTransactionSummary clone() => ArkTransactionSummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ArkTransactionSummary copyWith(void Function(ArkTransactionSummary) updates) => super.copyWith((message) => updates(message as ArkTransactionSummary)) as ArkTransactionSummary; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static ArkTransactionSummary create() => ArkTransactionSummary._();
  ArkTransactionSummary createEmptyInstance() => create();
  static $pb.PbList<ArkTransactionSummary> createRepeated() => $pb.PbList<ArkTransactionSummary>();
  @$core.pragma('dart2js:noInline')
  static ArkTransactionSummary getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ArkTransactionSummary>(create);
  static ArkTransactionSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txType => $_getSZ(0);
  @$pb.TagNumber(1)
  set txType($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTxType() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxType() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amountSats => $_getI64(1);
  @$pb.TagNumber(2)
  set amountSats($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAmountSats() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmountSats() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get txid => $_getSZ(2);
  @$pb.TagNumber(3)
  set txid($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTxid() => $_has(2);
  @$pb.TagNumber(3)
  void clearTxid() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestamp => $_getI64(3);
  @$pb.TagNumber(4)
  set timestamp($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTimestamp() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestamp() => clearField(4);
}

class ListArkTransactionsRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'ListArkTransactionsRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  ListArkTransactionsRequest._() : super();
  factory ListArkTransactionsRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory ListArkTransactionsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListArkTransactionsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListArkTransactionsRequest clone() => ListArkTransactionsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListArkTransactionsRequest copyWith(void Function(ListArkTransactionsRequest) updates) => super.copyWith((message) => updates(message as ListArkTransactionsRequest)) as ListArkTransactionsRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsRequest create() => ListArkTransactionsRequest._();
  ListArkTransactionsRequest createEmptyInstance() => create();
  static $pb.PbList<ListArkTransactionsRequest> createRepeated() => $pb.PbList<ListArkTransactionsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListArkTransactionsRequest>(create);
  static ListArkTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);
}

class ListArkTransactionsResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'ListArkTransactionsResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<ArkTransactionSummary>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'transactions', $pb.PbFieldType.PM, subBuilder: ArkTransactionSummary.create)
    ..hasRequiredFields = false
  ;

  ListArkTransactionsResponse._() : super();
  factory ListArkTransactionsResponse({
    $core.Iterable<ArkTransactionSummary>? transactions,
  }) {
    final _result = create();
    if (transactions != null) {
      _result.transactions.addAll(transactions);
    }
    return _result;
  }
  factory ListArkTransactionsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListArkTransactionsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListArkTransactionsResponse clone() => ListArkTransactionsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListArkTransactionsResponse copyWith(void Function(ListArkTransactionsResponse) updates) => super.copyWith((message) => updates(message as ListArkTransactionsResponse)) as ListArkTransactionsResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsResponse create() => ListArkTransactionsResponse._();
  ListArkTransactionsResponse createEmptyInstance() => create();
  static $pb.PbList<ListArkTransactionsResponse> createRepeated() => $pb.PbList<ListArkTransactionsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListArkTransactionsResponse>(create);
  static ListArkTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<ArkTransactionSummary> get transactions => $_getList(0);
}

class SendVtxoRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SendVtxoRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'recipientArkAddress')
    ..a<$fixnum.Int64>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'amount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..hasRequiredFields = false
  ;

  SendVtxoRequest._() : super();
  factory SendVtxoRequest({
    $core.List<$core.int>? userId,
    $core.String? recipientArkAddress,
    $fixnum.Int64? amount,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (recipientArkAddress != null) {
      _result.recipientArkAddress = recipientArkAddress;
    }
    if (amount != null) {
      _result.amount = amount;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    if (signedMessages != null) {
      _result.signedMessages.addAll(signedMessages);
    }
    return _result;
  }
  factory SendVtxoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SendVtxoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SendVtxoRequest clone() => SendVtxoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SendVtxoRequest copyWith(void Function(SendVtxoRequest) updates) => super.copyWith((message) => updates(message as SendVtxoRequest)) as SendVtxoRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SendVtxoRequest create() => SendVtxoRequest._();
  SendVtxoRequest createEmptyInstance() => create();
  static $pb.PbList<SendVtxoRequest> createRepeated() => $pb.PbList<SendVtxoRequest>();
  @$core.pragma('dart2js:noInline')
  static SendVtxoRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SendVtxoRequest>(create);
  static SendVtxoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get recipientArkAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set recipientArkAddress($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRecipientArkAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearRecipientArkAddress() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestampMs() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.List<$core.int>> get signedMessages => $_getList(5);
}

class SendVtxoResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SendVtxoResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..e<SendVtxoResponse_Status>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: SendVtxoResponse_Status.SIGNING_REQUIRED, valueOf: SendVtxoResponse_Status.valueOf, enumValues: SendVtxoResponse_Status.values)
    ..p<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'scriptPathSpend')
    ..aOS(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'arkTxid')
    ..aOS(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'errorMessage')
    ..aOS(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'policyId')
    ..hasRequiredFields = false
  ;

  SendVtxoResponse._() : super();
  factory SendVtxoResponse({
    SendVtxoResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? arkTxid,
    $core.String? errorMessage,
    $core.String? policyId,
  }) {
    final _result = create();
    if (status != null) {
      _result.status = status;
    }
    if (messagesToSign != null) {
      _result.messagesToSign.addAll(messagesToSign);
    }
    if (scriptPathSpend != null) {
      _result.scriptPathSpend = scriptPathSpend;
    }
    if (arkTxid != null) {
      _result.arkTxid = arkTxid;
    }
    if (errorMessage != null) {
      _result.errorMessage = errorMessage;
    }
    if (policyId != null) {
      _result.policyId = policyId;
    }
    return _result;
  }
  factory SendVtxoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SendVtxoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SendVtxoResponse clone() => SendVtxoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SendVtxoResponse copyWith(void Function(SendVtxoResponse) updates) => super.copyWith((message) => updates(message as SendVtxoResponse)) as SendVtxoResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SendVtxoResponse create() => SendVtxoResponse._();
  SendVtxoResponse createEmptyInstance() => create();
  static $pb.PbList<SendVtxoResponse> createRepeated() => $pb.PbList<SendVtxoResponse>();
  @$core.pragma('dart2js:noInline')
  static SendVtxoResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SendVtxoResponse>(create);
  static SendVtxoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SendVtxoResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(SendVtxoResponse_Status v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get messagesToSign => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get arkTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set arkTxid($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasArkTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearArkTxid() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get policyId => $_getSZ(5);
  @$pb.TagNumber(6)
  set policyId($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasPolicyId() => $_has(5);
  @$pb.TagNumber(6)
  void clearPolicyId() => clearField(6);
}

class RedeemVtxoRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RedeemVtxoRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'onChainAddress')
    ..a<$fixnum.Int64>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'amount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  RedeemVtxoRequest._() : super();
  factory RedeemVtxoRequest({
    $core.List<$core.int>? userId,
    $core.String? onChainAddress,
    $fixnum.Int64? amount,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (onChainAddress != null) {
      _result.onChainAddress = onChainAddress;
    }
    if (amount != null) {
      _result.amount = amount;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    return _result;
  }
  factory RedeemVtxoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RedeemVtxoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RedeemVtxoRequest clone() => RedeemVtxoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RedeemVtxoRequest copyWith(void Function(RedeemVtxoRequest) updates) => super.copyWith((message) => updates(message as RedeemVtxoRequest)) as RedeemVtxoRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RedeemVtxoRequest create() => RedeemVtxoRequest._();
  RedeemVtxoRequest createEmptyInstance() => create();
  static $pb.PbList<RedeemVtxoRequest> createRepeated() => $pb.PbList<RedeemVtxoRequest>();
  @$core.pragma('dart2js:noInline')
  static RedeemVtxoRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RedeemVtxoRequest>(create);
  static RedeemVtxoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get onChainAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set onChainAddress($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOnChainAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearOnChainAddress() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestampMs() => clearField(5);
}

class RedeemVtxoResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'RedeemVtxoResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'success')
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'txid')
    ..hasRequiredFields = false
  ;

  RedeemVtxoResponse._() : super();
  factory RedeemVtxoResponse({
    $core.bool? success,
    $core.String? txid,
  }) {
    final _result = create();
    if (success != null) {
      _result.success = success;
    }
    if (txid != null) {
      _result.txid = txid;
    }
    return _result;
  }
  factory RedeemVtxoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RedeemVtxoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RedeemVtxoResponse clone() => RedeemVtxoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RedeemVtxoResponse copyWith(void Function(RedeemVtxoResponse) updates) => super.copyWith((message) => updates(message as RedeemVtxoResponse)) as RedeemVtxoResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static RedeemVtxoResponse create() => RedeemVtxoResponse._();
  RedeemVtxoResponse createEmptyInstance() => create();
  static $pb.PbList<RedeemVtxoResponse> createRepeated() => $pb.PbList<RedeemVtxoResponse>();
  @$core.pragma('dart2js:noInline')
  static RedeemVtxoResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RedeemVtxoResponse>(create);
  static RedeemVtxoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get txid => $_getSZ(1);
  @$pb.TagNumber(2)
  set txid($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTxid() => $_has(1);
  @$pb.TagNumber(2)
  void clearTxid() => clearField(2);
}

class SettleRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SettleRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..hasRequiredFields = false
  ;

  SettleRequest._() : super();
  factory SettleRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    if (signedMessages != null) {
      _result.signedMessages.addAll(signedMessages);
    }
    return _result;
  }
  factory SettleRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleRequest clone() => SettleRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleRequest copyWith(void Function(SettleRequest) updates) => super.copyWith((message) => updates(message as SettleRequest)) as SettleRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SettleRequest create() => SettleRequest._();
  SettleRequest createEmptyInstance() => create();
  static $pb.PbList<SettleRequest> createRepeated() => $pb.PbList<SettleRequest>();
  @$core.pragma('dart2js:noInline')
  static SettleRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SettleRequest>(create);
  static SettleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.List<$core.int>> get signedMessages => $_getList(3);
}

class SettleResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SettleResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..e<SettleResponse_Status>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: SettleResponse_Status.SIGNING_REQUIRED, valueOf: SettleResponse_Status.valueOf, enumValues: SettleResponse_Status.values)
    ..p<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'scriptPathSpend')
    ..aOS(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'commitmentTxid')
    ..aOS(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'errorMessage')
    ..hasRequiredFields = false
  ;

  SettleResponse._() : super();
  factory SettleResponse({
    SettleResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? commitmentTxid,
    $core.String? errorMessage,
  }) {
    final _result = create();
    if (status != null) {
      _result.status = status;
    }
    if (messagesToSign != null) {
      _result.messagesToSign.addAll(messagesToSign);
    }
    if (scriptPathSpend != null) {
      _result.scriptPathSpend = scriptPathSpend;
    }
    if (commitmentTxid != null) {
      _result.commitmentTxid = commitmentTxid;
    }
    if (errorMessage != null) {
      _result.errorMessage = errorMessage;
    }
    return _result;
  }
  factory SettleResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleResponse clone() => SettleResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleResponse copyWith(void Function(SettleResponse) updates) => super.copyWith((message) => updates(message as SettleResponse)) as SettleResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SettleResponse create() => SettleResponse._();
  SettleResponse createEmptyInstance() => create();
  static $pb.PbList<SettleResponse> createRepeated() => $pb.PbList<SettleResponse>();
  @$core.pragma('dart2js:noInline')
  static SettleResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SettleResponse>(create);
  static SettleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SettleResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(SettleResponse_Status v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get messagesToSign => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get commitmentTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set commitmentTxid($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCommitmentTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommitmentTxid() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => clearField(5);
}

class SettleDelegateRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SettleDelegateRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..hasRequiredFields = false
  ;

  SettleDelegateRequest._() : super();
  factory SettleDelegateRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    if (signedMessages != null) {
      _result.signedMessages.addAll(signedMessages);
    }
    return _result;
  }
  factory SettleDelegateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleDelegateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleDelegateRequest clone() => SettleDelegateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleDelegateRequest copyWith(void Function(SettleDelegateRequest) updates) => super.copyWith((message) => updates(message as SettleDelegateRequest)) as SettleDelegateRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SettleDelegateRequest create() => SettleDelegateRequest._();
  SettleDelegateRequest createEmptyInstance() => create();
  static $pb.PbList<SettleDelegateRequest> createRepeated() => $pb.PbList<SettleDelegateRequest>();
  @$core.pragma('dart2js:noInline')
  static SettleDelegateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SettleDelegateRequest>(create);
  static SettleDelegateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.List<$core.int>> get signedMessages => $_getList(3);
}

class SettleDelegateResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SettleDelegateResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..e<SettleDelegateResponse_Status>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: SettleDelegateResponse_Status.SIGNING_REQUIRED, valueOf: SettleDelegateResponse_Status.valueOf, enumValues: SettleDelegateResponse_Status.values)
    ..p<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'scriptPathSpend')
    ..aOS(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'commitmentTxid')
    ..aOS(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'errorMessage')
    ..hasRequiredFields = false
  ;

  SettleDelegateResponse._() : super();
  factory SettleDelegateResponse({
    SettleDelegateResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? commitmentTxid,
    $core.String? errorMessage,
  }) {
    final _result = create();
    if (status != null) {
      _result.status = status;
    }
    if (messagesToSign != null) {
      _result.messagesToSign.addAll(messagesToSign);
    }
    if (scriptPathSpend != null) {
      _result.scriptPathSpend = scriptPathSpend;
    }
    if (commitmentTxid != null) {
      _result.commitmentTxid = commitmentTxid;
    }
    if (errorMessage != null) {
      _result.errorMessage = errorMessage;
    }
    return _result;
  }
  factory SettleDelegateResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleDelegateResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleDelegateResponse clone() => SettleDelegateResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleDelegateResponse copyWith(void Function(SettleDelegateResponse) updates) => super.copyWith((message) => updates(message as SettleDelegateResponse)) as SettleDelegateResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SettleDelegateResponse create() => SettleDelegateResponse._();
  SettleDelegateResponse createEmptyInstance() => create();
  static $pb.PbList<SettleDelegateResponse> createRepeated() => $pb.PbList<SettleDelegateResponse>();
  @$core.pragma('dart2js:noInline')
  static SettleDelegateResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SettleDelegateResponse>(create);
  static SettleDelegateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SettleDelegateResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(SettleDelegateResponse_Status v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get messagesToSign => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get commitmentTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set commitmentTxid($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCommitmentTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommitmentTxid() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => clearField(5);
}

class SubmitArkSendRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SubmitArkSendRequest', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'timestampMs')
    ..aOS(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signedArkTxB64')
    ..pPS(5, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'signedCheckpointTxsB64')
    ..pPS(6, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'spentOutpoints')
    ..hasRequiredFields = false
  ;

  SubmitArkSendRequest._() : super();
  factory SubmitArkSendRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.String? signedArkTxB64,
    $core.Iterable<$core.String>? signedCheckpointTxsB64,
    $core.Iterable<$core.String>? spentOutpoints,
  }) {
    final _result = create();
    if (userId != null) {
      _result.userId = userId;
    }
    if (signature != null) {
      _result.signature = signature;
    }
    if (timestampMs != null) {
      _result.timestampMs = timestampMs;
    }
    if (signedArkTxB64 != null) {
      _result.signedArkTxB64 = signedArkTxB64;
    }
    if (signedCheckpointTxsB64 != null) {
      _result.signedCheckpointTxsB64.addAll(signedCheckpointTxsB64);
    }
    if (spentOutpoints != null) {
      _result.spentOutpoints.addAll(spentOutpoints);
    }
    return _result;
  }
  factory SubmitArkSendRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubmitArkSendRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubmitArkSendRequest clone() => SubmitArkSendRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubmitArkSendRequest copyWith(void Function(SubmitArkSendRequest) updates) => super.copyWith((message) => updates(message as SubmitArkSendRequest)) as SubmitArkSendRequest; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SubmitArkSendRequest create() => SubmitArkSendRequest._();
  SubmitArkSendRequest createEmptyInstance() => create();
  static $pb.PbList<SubmitArkSendRequest> createRepeated() => $pb.PbList<SubmitArkSendRequest>();
  @$core.pragma('dart2js:noInline')
  static SubmitArkSendRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubmitArkSendRequest>(create);
  static SubmitArkSendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get signedArkTxB64 => $_getSZ(3);
  @$pb.TagNumber(4)
  set signedArkTxB64($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSignedArkTxB64() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignedArkTxB64() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.String> get signedCheckpointTxsB64 => $_getList(4);

  @$pb.TagNumber(6)
  $core.List<$core.String> get spentOutpoints => $_getList(5);
}

class SubmitArkSendResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'SubmitArkSendResponse', package: const $pb.PackageName(const $core.bool.fromEnvironment('protobuf.omit_message_names') ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'arkTxid')
    ..aOS(2, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'changeTxid')
    ..a<$core.int>(3, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'changeVout', $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(4, const $core.bool.fromEnvironment('protobuf.omit_field_names') ? '' : 'changeAmount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  SubmitArkSendResponse._() : super();
  factory SubmitArkSendResponse({
    $core.String? arkTxid,
    $core.String? changeTxid,
    $core.int? changeVout,
    $fixnum.Int64? changeAmount,
  }) {
    final _result = create();
    if (arkTxid != null) {
      _result.arkTxid = arkTxid;
    }
    if (changeTxid != null) {
      _result.changeTxid = changeTxid;
    }
    if (changeVout != null) {
      _result.changeVout = changeVout;
    }
    if (changeAmount != null) {
      _result.changeAmount = changeAmount;
    }
    return _result;
  }
  factory SubmitArkSendResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubmitArkSendResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubmitArkSendResponse clone() => SubmitArkSendResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubmitArkSendResponse copyWith(void Function(SubmitArkSendResponse) updates) => super.copyWith((message) => updates(message as SubmitArkSendResponse)) as SubmitArkSendResponse; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SubmitArkSendResponse create() => SubmitArkSendResponse._();
  SubmitArkSendResponse createEmptyInstance() => create();
  static $pb.PbList<SubmitArkSendResponse> createRepeated() => $pb.PbList<SubmitArkSendResponse>();
  @$core.pragma('dart2js:noInline')
  static SubmitArkSendResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubmitArkSendResponse>(create);
  static SubmitArkSendResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get arkTxid => $_getSZ(0);
  @$pb.TagNumber(1)
  set arkTxid($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasArkTxid() => $_has(0);
  @$pb.TagNumber(1)
  void clearArkTxid() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get changeTxid => $_getSZ(1);
  @$pb.TagNumber(2)
  set changeTxid($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasChangeTxid() => $_has(1);
  @$pb.TagNumber(2)
  void clearChangeTxid() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get changeVout => $_getIZ(2);
  @$pb.TagNumber(3)
  set changeVout($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasChangeVout() => $_has(2);
  @$pb.TagNumber(3)
  void clearChangeVout() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get changeAmount => $_getI64(3);
  @$pb.TagNumber(4)
  set changeAmount($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasChangeAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearChangeAmount() => clearField(4);
}

