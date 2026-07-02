//
//  Generated code. Do not modify.
//  source: mpc_wallet.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'mpc_wallet.pbenum.dart';

export 'mpc_wallet.pbenum.dart';

class DKGStep1Request extends $pb.GeneratedMessage {
  factory DKGStep1Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (identifier != null) {
      $result.identifier = identifier;
    }
    if (round1Package != null) {
      $result.round1Package = round1Package;
    }
    return $result;
  }
  DKGStep1Request._() : super();
  factory DKGStep1Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep1Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DKGStep1Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep1Request clone() => DKGStep1Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep1Request copyWith(void Function(DKGStep1Request) updates) => super.copyWith((message) => updates(message as DKGStep1Request)) as DKGStep1Request;

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
}

class DKGStep1Response extends $pb.GeneratedMessage {
  factory DKGStep1Response({
    $core.Map<$core.String, $core.String>? round1Packages,
  }) {
    final $result = create();
    if (round1Packages != null) {
      $result.round1Packages.addAll(round1Packages);
    }
    return $result;
  }
  DKGStep1Response._() : super();
  factory DKGStep1Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep1Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DKGStep1Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round1Packages', entryClassName: 'DKGStep1Response.Round1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep1Response clone() => DKGStep1Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep1Response copyWith(void Function(DKGStep1Response) updates) => super.copyWith((message) => updates(message as DKGStep1Response)) as DKGStep1Response;

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
  factory DKGStep2Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (identifier != null) {
      $result.identifier = identifier;
    }
    if (round1Package != null) {
      $result.round1Package = round1Package;
    }
    return $result;
  }
  DKGStep2Request._() : super();
  factory DKGStep2Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep2Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DKGStep2Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep2Request clone() => DKGStep2Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep2Request copyWith(void Function(DKGStep2Request) updates) => super.copyWith((message) => updates(message as DKGStep2Request)) as DKGStep2Request;

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
  factory DKGStep2Response({
    $core.Map<$core.String, $core.String>? allRound1Packages,
  }) {
    final $result = create();
    if (allRound1Packages != null) {
      $result.allRound1Packages.addAll(allRound1Packages);
    }
    return $result;
  }
  DKGStep2Response._() : super();
  factory DKGStep2Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep2Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DKGStep2Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'allRound1Packages', entryClassName: 'DKGStep2Response.AllRound1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep2Response clone() => DKGStep2Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep2Response copyWith(void Function(DKGStep2Response) updates) => super.copyWith((message) => updates(message as DKGStep2Response)) as DKGStep2Response;

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
  factory DKGStep3Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.Map<$core.String, $core.String>? round2PackagesForOthers,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (identifier != null) {
      $result.identifier = identifier;
    }
    if (round2PackagesForOthers != null) {
      $result.round2PackagesForOthers.addAll(round2PackagesForOthers);
    }
    return $result;
  }
  DKGStep3Request._() : super();
  factory DKGStep3Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep3Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DKGStep3Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'round2PackagesForOthers', entryClassName: 'DKGStep3Request.Round2PackagesForOthersEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep3Request clone() => DKGStep3Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep3Request copyWith(void Function(DKGStep3Request) updates) => super.copyWith((message) => updates(message as DKGStep3Request)) as DKGStep3Request;

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
  factory DKGStep3Response({
    $core.Map<$core.String, $core.String>? round2PackagesForMe,
  }) {
    final $result = create();
    if (round2PackagesForMe != null) {
      $result.round2PackagesForMe.addAll(round2PackagesForMe);
    }
    return $result;
  }
  DKGStep3Response._() : super();
  factory DKGStep3Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DKGStep3Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DKGStep3Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round2PackagesForMe', entryClassName: 'DKGStep3Response.Round2PackagesForMeEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DKGStep3Response clone() => DKGStep3Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DKGStep3Response copyWith(void Function(DKGStep3Response) updates) => super.copyWith((message) => updates(message as DKGStep3Response)) as DKGStep3Response;

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
  factory SignStep1Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? hidingCommitment,
    $core.List<$core.int>? bindingCommitment,
    $core.List<$core.int>? messageToSign,
    $core.List<$core.int>? signature,
    $core.List<$core.int>? fullTransaction,
    $fixnum.Int64? timestampMs,
    $core.bool? scriptPathSpend,
    $core.List<$core.int>? arkTx,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (hidingCommitment != null) {
      $result.hidingCommitment = hidingCommitment;
    }
    if (bindingCommitment != null) {
      $result.bindingCommitment = bindingCommitment;
    }
    if (messageToSign != null) {
      $result.messageToSign = messageToSign;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (fullTransaction != null) {
      $result.fullTransaction = fullTransaction;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (scriptPathSpend != null) {
      $result.scriptPathSpend = scriptPathSpend;
    }
    if (arkTx != null) {
      $result.arkTx = arkTx;
    }
    return $result;
  }
  SignStep1Request._() : super();
  factory SignStep1Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep1Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SignStep1Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'hidingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'bindingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'messageToSign', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'fullTransaction', $pb.PbFieldType.OY)
    ..aInt64(7, _omitFieldNames ? '' : 'timestampMs')
    ..aOB(8, _omitFieldNames ? '' : 'scriptPathSpend')
    ..a<$core.List<$core.int>>(10, _omitFieldNames ? '' : 'arkTx', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep1Request clone() => SignStep1Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep1Request copyWith(void Function(SignStep1Request) updates) => super.copyWith((message) => updates(message as SignStep1Request)) as SignStep1Request;

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

  /// share (user or service); routing is by the URL group_key.
  /// Service-driven eVTXO spend THROUGH arkd (Tier 2): the second leg (the `ark_tx`
  /// that spends the checkpoint output). `full_transaction` carries the checkpoint
  /// PSBT (leg 1, spends the eVTXO). When set, a pairing actor's conditioning verifies
  /// `message_to_sign` is the sighash of leg 1 OR leg 2, with leg 2 chained to leg 1's
  /// checkpoint. Empty for an on-chain single-leg spend (the cosigner overrides the msg).
  @$pb.TagNumber(10)
  $core.List<$core.int> get arkTx => $_getN(8);
  @$pb.TagNumber(10)
  set arkTx($core.List<$core.int> v) { $_setBytes(8, v); }
  @$pb.TagNumber(10)
  $core.bool hasArkTx() => $_has(8);
  @$pb.TagNumber(10)
  void clearArkTx() => clearField(10);
}

class SignStep1Response_Commitment extends $pb.GeneratedMessage {
  factory SignStep1Response_Commitment({
    $core.List<$core.int>? hiding,
    $core.List<$core.int>? binding,
  }) {
    final $result = create();
    if (hiding != null) {
      $result.hiding = hiding;
    }
    if (binding != null) {
      $result.binding = binding;
    }
    return $result;
  }
  SignStep1Response_Commitment._() : super();
  factory SignStep1Response_Commitment.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep1Response_Commitment.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SignStep1Response.Commitment', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'hiding', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'binding', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep1Response_Commitment clone() => SignStep1Response_Commitment()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep1Response_Commitment copyWith(void Function(SignStep1Response_Commitment) updates) => super.copyWith((message) => updates(message as SignStep1Response_Commitment)) as SignStep1Response_Commitment;

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
  factory SignStep1Response({
    $core.Map<$core.String, SignStep1Response_Commitment>? commitments,
    $core.List<$core.int>? messageToSign,
    $core.int? usedKeyIndex,
  }) {
    final $result = create();
    if (commitments != null) {
      $result.commitments.addAll(commitments);
    }
    if (messageToSign != null) {
      $result.messageToSign = messageToSign;
    }
    if (usedKeyIndex != null) {
      $result.usedKeyIndex = usedKeyIndex;
    }
    return $result;
  }
  SignStep1Response._() : super();
  factory SignStep1Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep1Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SignStep1Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, SignStep1Response_Commitment>(1, _omitFieldNames ? '' : 'commitments', entryClassName: 'SignStep1Response.CommitmentsEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: SignStep1Response_Commitment.create, valueDefaultOrMaker: SignStep1Response_Commitment.getDefault, packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messageToSign', $pb.PbFieldType.OY)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'usedKeyIndex', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep1Response clone() => SignStep1Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep1Response copyWith(void Function(SignStep1Response) updates) => super.copyWith((message) => updates(message as SignStep1Response)) as SignStep1Response;

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
  factory SignStep2Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signatureShare,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signatureShare != null) {
      $result.signatureShare = signatureShare;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  SignStep2Request._() : super();
  factory SignStep2Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep2Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SignStep2Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'signatureShare', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep2Request clone() => SignStep2Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep2Request copyWith(void Function(SignStep2Request) updates) => super.copyWith((message) => updates(message as SignStep2Request)) as SignStep2Request;

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

class SignStep2Response extends $pb.GeneratedMessage {
  factory SignStep2Response({
    $core.List<$core.int>? rPoint,
    $core.List<$core.int>? zScalar,
  }) {
    final $result = create();
    if (rPoint != null) {
      $result.rPoint = rPoint;
    }
    if (zScalar != null) {
      $result.zScalar = zScalar;
    }
    return $result;
  }
  SignStep2Response._() : super();
  factory SignStep2Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SignStep2Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SignStep2Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'rPoint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'zScalar', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SignStep2Response clone() => SignStep2Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SignStep2Response copyWith(void Function(SignStep2Response) updates) => super.copyWith((message) => updates(message as SignStep2Response)) as SignStep2Response;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignStep2Response create() => SignStep2Response._();
  SignStep2Response createEmptyInstance() => create();
  static $pb.PbList<SignStep2Response> createRepeated() => $pb.PbList<SignStep2Response>();
  @$core.pragma('dart2js:noInline')
  static SignStep2Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SignStep2Response>(create);
  static SignStep2Response? _defaultInstance;

  /// Final aggregated signature
  /// (R, z)
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

class GetArkInfoRequest extends $pb.GeneratedMessage {
  factory GetArkInfoRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  GetArkInfoRequest._() : super();
  factory GetArkInfoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkInfoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetArkInfoRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkInfoRequest clone() => GetArkInfoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkInfoRequest copyWith(void Function(GetArkInfoRequest) updates) => super.copyWith((message) => updates(message as GetArkInfoRequest)) as GetArkInfoRequest;

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
    $fixnum.Int64? autoSettleSafetyMarginSecs,
  }) {
    final $result = create();
    if (signerPubkey != null) {
      $result.signerPubkey = signerPubkey;
    }
    if (forfeitPubkey != null) {
      $result.forfeitPubkey = forfeitPubkey;
    }
    if (network != null) {
      $result.network = network;
    }
    if (sessionDuration != null) {
      $result.sessionDuration = sessionDuration;
    }
    if (unilateralExitDelay != null) {
      $result.unilateralExitDelay = unilateralExitDelay;
    }
    if (boardingExitDelay != null) {
      $result.boardingExitDelay = boardingExitDelay;
    }
    if (vtxoMinAmount != null) {
      $result.vtxoMinAmount = vtxoMinAmount;
    }
    if (dust != null) {
      $result.dust = dust;
    }
    if (checkpointTapscript != null) {
      $result.checkpointTapscript = checkpointTapscript;
    }
    if (forfeitAddress != null) {
      $result.forfeitAddress = forfeitAddress;
    }
    if (autoSettleSafetyMarginSecs != null) {
      $result.autoSettleSafetyMarginSecs = autoSettleSafetyMarginSecs;
    }
    return $result;
  }
  GetArkInfoResponse._() : super();
  factory GetArkInfoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkInfoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetArkInfoResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'signerPubkey')
    ..aOS(2, _omitFieldNames ? '' : 'forfeitPubkey')
    ..aOS(3, _omitFieldNames ? '' : 'network')
    ..aInt64(4, _omitFieldNames ? '' : 'sessionDuration')
    ..aInt64(5, _omitFieldNames ? '' : 'unilateralExitDelay')
    ..aInt64(6, _omitFieldNames ? '' : 'boardingExitDelay')
    ..aInt64(7, _omitFieldNames ? '' : 'vtxoMinAmount')
    ..aInt64(8, _omitFieldNames ? '' : 'dust')
    ..aOS(9, _omitFieldNames ? '' : 'checkpointTapscript')
    ..aOS(10, _omitFieldNames ? '' : 'forfeitAddress')
    ..aInt64(11, _omitFieldNames ? '' : 'autoSettleSafetyMarginSecs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkInfoResponse clone() => GetArkInfoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkInfoResponse copyWith(void Function(GetArkInfoResponse) updates) => super.copyWith((message) => updates(message as GetArkInfoResponse)) as GetArkInfoResponse;

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

  /// Seconds before a VTXO's expiry that the cosigner auto-settles a stored
  /// delegate. Lets the client show an accurate "refreshes around" time.
  @$pb.TagNumber(11)
  $fixnum.Int64 get autoSettleSafetyMarginSecs => $_getI64(10);
  @$pb.TagNumber(11)
  set autoSettleSafetyMarginSecs($fixnum.Int64 v) { $_setInt64(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasAutoSettleSafetyMarginSecs() => $_has(10);
  @$pb.TagNumber(11)
  void clearAutoSettleSafetyMarginSecs() => clearField(11);
}

class GetArkAddressRequest extends $pb.GeneratedMessage {
  factory GetArkAddressRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  GetArkAddressRequest._() : super();
  factory GetArkAddressRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkAddressRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetArkAddressRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkAddressRequest clone() => GetArkAddressRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkAddressRequest copyWith(void Function(GetArkAddressRequest) updates) => super.copyWith((message) => updates(message as GetArkAddressRequest)) as GetArkAddressRequest;

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
  factory GetArkAddressResponse({
    $core.String? arkAddress,
  }) {
    final $result = create();
    if (arkAddress != null) {
      $result.arkAddress = arkAddress;
    }
    return $result;
  }
  GetArkAddressResponse._() : super();
  factory GetArkAddressResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetArkAddressResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetArkAddressResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'arkAddress')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetArkAddressResponse clone() => GetArkAddressResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetArkAddressResponse copyWith(void Function(GetArkAddressResponse) updates) => super.copyWith((message) => updates(message as GetArkAddressResponse)) as GetArkAddressResponse;

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
  factory GetBoardingAddressRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  GetBoardingAddressRequest._() : super();
  factory GetBoardingAddressRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBoardingAddressRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetBoardingAddressRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBoardingAddressRequest clone() => GetBoardingAddressRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBoardingAddressRequest copyWith(void Function(GetBoardingAddressRequest) updates) => super.copyWith((message) => updates(message as GetBoardingAddressRequest)) as GetBoardingAddressRequest;

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
  factory GetBoardingAddressResponse({
    $core.String? boardingAddress,
  }) {
    final $result = create();
    if (boardingAddress != null) {
      $result.boardingAddress = boardingAddress;
    }
    return $result;
  }
  GetBoardingAddressResponse._() : super();
  factory GetBoardingAddressResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBoardingAddressResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetBoardingAddressResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'boardingAddress')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBoardingAddressResponse clone() => GetBoardingAddressResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBoardingAddressResponse copyWith(void Function(GetBoardingAddressResponse) updates) => super.copyWith((message) => updates(message as GetBoardingAddressResponse)) as GetBoardingAddressResponse;

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
    final $result = create();
    if (txid != null) {
      $result.txid = txid;
    }
    if (vout != null) {
      $result.vout = vout;
    }
    if (amount != null) {
      $result.amount = amount;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    if (expiresAt != null) {
      $result.expiresAt = expiresAt;
    }
    if (status != null) {
      $result.status = status;
    }
    if (isPreconfirmed != null) {
      $result.isPreconfirmed = isPreconfirmed;
    }
    if (exitDelay != null) {
      $result.exitDelay = exitDelay;
    }
    if (script != null) {
      $result.script = script;
    }
    return $result;
  }
  VtxoInfo._() : super();
  factory VtxoInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory VtxoInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'VtxoInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txid')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'vout', $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'amount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(4, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(5, _omitFieldNames ? '' : 'expiresAt')
    ..aOS(6, _omitFieldNames ? '' : 'status')
    ..aOB(7, _omitFieldNames ? '' : 'isPreconfirmed')
    ..a<$core.int>(8, _omitFieldNames ? '' : 'exitDelay', $pb.PbFieldType.OU3)
    ..aOS(9, _omitFieldNames ? '' : 'script')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  VtxoInfo clone() => VtxoInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  VtxoInfo copyWith(void Function(VtxoInfo) updates) => super.copyWith((message) => updates(message as VtxoInfo)) as VtxoInfo;

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
  factory ListVtxosRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  ListVtxosRequest._() : super();
  factory ListVtxosRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListVtxosRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListVtxosRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListVtxosRequest clone() => ListVtxosRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListVtxosRequest copyWith(void Function(ListVtxosRequest) updates) => super.copyWith((message) => updates(message as ListVtxosRequest)) as ListVtxosRequest;

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
  factory ListVtxosResponse({
    $core.Iterable<VtxoInfo>? vtxos,
    $fixnum.Int64? totalBalance,
    $core.bool? hasActiveDelegate,
  }) {
    final $result = create();
    if (vtxos != null) {
      $result.vtxos.addAll(vtxos);
    }
    if (totalBalance != null) {
      $result.totalBalance = totalBalance;
    }
    if (hasActiveDelegate != null) {
      $result.hasActiveDelegate = hasActiveDelegate;
    }
    return $result;
  }
  ListVtxosResponse._() : super();
  factory ListVtxosResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListVtxosResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListVtxosResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<VtxoInfo>(1, _omitFieldNames ? '' : 'vtxos', $pb.PbFieldType.PM, subBuilder: VtxoInfo.create)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'totalBalance', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(3, _omitFieldNames ? '' : 'hasActiveDelegate')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListVtxosResponse clone() => ListVtxosResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListVtxosResponse copyWith(void Function(ListVtxosResponse) updates) => super.copyWith((message) => updates(message as ListVtxosResponse)) as ListVtxosResponse;

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

  /// True if the cosigner has a stored, signed delegate intent for this user.
  /// Clients use this to detect "VTXOs exist but no delegate" (e.g. after
  /// cosigner-runtime restart) and re-delegate.
  @$pb.TagNumber(3)
  $core.bool get hasActiveDelegate => $_getBF(2);
  @$pb.TagNumber(3)
  set hasActiveDelegate($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasHasActiveDelegate() => $_has(2);
  @$pb.TagNumber(3)
  void clearHasActiveDelegate() => clearField(3);
}

class ArkTransactionSummary extends $pb.GeneratedMessage {
  factory ArkTransactionSummary({
    $core.String? txType,
    $fixnum.Int64? amountSats,
    $core.String? txid,
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (txType != null) {
      $result.txType = txType;
    }
    if (amountSats != null) {
      $result.amountSats = amountSats;
    }
    if (txid != null) {
      $result.txid = txid;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  ArkTransactionSummary._() : super();
  factory ArkTransactionSummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ArkTransactionSummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ArkTransactionSummary', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txType')
    ..aInt64(2, _omitFieldNames ? '' : 'amountSats')
    ..aOS(3, _omitFieldNames ? '' : 'txid')
    ..aInt64(4, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ArkTransactionSummary clone() => ArkTransactionSummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ArkTransactionSummary copyWith(void Function(ArkTransactionSummary) updates) => super.copyWith((message) => updates(message as ArkTransactionSummary)) as ArkTransactionSummary;

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
  factory ListArkTransactionsRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  ListArkTransactionsRequest._() : super();
  factory ListArkTransactionsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListArkTransactionsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListArkTransactionsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListArkTransactionsRequest clone() => ListArkTransactionsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListArkTransactionsRequest copyWith(void Function(ListArkTransactionsRequest) updates) => super.copyWith((message) => updates(message as ListArkTransactionsRequest)) as ListArkTransactionsRequest;

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
  factory ListArkTransactionsResponse({
    $core.Iterable<ArkTransactionSummary>? transactions,
  }) {
    final $result = create();
    if (transactions != null) {
      $result.transactions.addAll(transactions);
    }
    return $result;
  }
  ListArkTransactionsResponse._() : super();
  factory ListArkTransactionsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListArkTransactionsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListArkTransactionsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<ArkTransactionSummary>(1, _omitFieldNames ? '' : 'transactions', $pb.PbFieldType.PM, subBuilder: ArkTransactionSummary.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListArkTransactionsResponse clone() => ListArkTransactionsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListArkTransactionsResponse copyWith(void Function(ListArkTransactionsResponse) updates) => super.copyWith((message) => updates(message as ListArkTransactionsResponse)) as ListArkTransactionsResponse;

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
  factory SendVtxoRequest({
    $core.List<$core.int>? userId,
    $core.String? recipientArkAddress,
    $fixnum.Int64? amount,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (recipientArkAddress != null) {
      $result.recipientArkAddress = recipientArkAddress;
    }
    if (amount != null) {
      $result.amount = amount;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (signedMessages != null) {
      $result.signedMessages.addAll(signedMessages);
    }
    return $result;
  }
  SendVtxoRequest._() : super();
  factory SendVtxoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SendVtxoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SendVtxoRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'recipientArkAddress')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'amount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SendVtxoRequest clone() => SendVtxoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SendVtxoRequest copyWith(void Function(SendVtxoRequest) updates) => super.copyWith((message) => updates(message as SendVtxoRequest)) as SendVtxoRequest;

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

  /// FROST signatures for previously requested sighashes (phase 2)
  @$pb.TagNumber(6)
  $core.List<$core.List<$core.int>> get signedMessages => $_getList(5);
}

class SendVtxoResponse extends $pb.GeneratedMessage {
  factory SendVtxoResponse({
    SendVtxoResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? arkTxid,
    $core.String? errorMessage,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (messagesToSign != null) {
      $result.messagesToSign.addAll(messagesToSign);
    }
    if (scriptPathSpend != null) {
      $result.scriptPathSpend = scriptPathSpend;
    }
    if (arkTxid != null) {
      $result.arkTxid = arkTxid;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    return $result;
  }
  SendVtxoResponse._() : super();
  factory SendVtxoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SendVtxoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SendVtxoResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..e<SendVtxoResponse_Status>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: SendVtxoResponse_Status.SIGNING_REQUIRED, valueOf: SendVtxoResponse_Status.valueOf, enumValues: SendVtxoResponse_Status.values)
    ..p<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, _omitFieldNames ? '' : 'scriptPathSpend')
    ..aOS(4, _omitFieldNames ? '' : 'arkTxid')
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SendVtxoResponse clone() => SendVtxoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SendVtxoResponse copyWith(void Function(SendVtxoResponse) updates) => super.copyWith((message) => updates(message as SendVtxoResponse)) as SendVtxoResponse;

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

  /// Sighashes that need FROST signing (when SIGNING_REQUIRED)
  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get messagesToSign => $_getList(1);

  /// Always true for send (script-path spend, no taproot tweak)
  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => clearField(3);

  /// Ark txid when SETTLED
  @$pb.TagNumber(4)
  $core.String get arkTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set arkTxid($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasArkTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearArkTxid() => clearField(4);

  /// Error message when ERROR
  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => clearField(5);
}

class RedeemVtxoRequest extends $pb.GeneratedMessage {
  factory RedeemVtxoRequest({
    $core.List<$core.int>? userId,
    $core.String? onChainAddress,
    $fixnum.Int64? amount,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (onChainAddress != null) {
      $result.onChainAddress = onChainAddress;
    }
    if (amount != null) {
      $result.amount = amount;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  RedeemVtxoRequest._() : super();
  factory RedeemVtxoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RedeemVtxoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RedeemVtxoRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'onChainAddress')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'amount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RedeemVtxoRequest clone() => RedeemVtxoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RedeemVtxoRequest copyWith(void Function(RedeemVtxoRequest) updates) => super.copyWith((message) => updates(message as RedeemVtxoRequest)) as RedeemVtxoRequest;

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
  factory RedeemVtxoResponse({
    $core.bool? success,
    $core.String? txid,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (txid != null) {
      $result.txid = txid;
    }
    return $result;
  }
  RedeemVtxoResponse._() : super();
  factory RedeemVtxoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RedeemVtxoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RedeemVtxoResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'txid')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RedeemVtxoResponse clone() => RedeemVtxoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RedeemVtxoResponse copyWith(void Function(RedeemVtxoResponse) updates) => super.copyWith((message) => updates(message as RedeemVtxoResponse)) as RedeemVtxoResponse;

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

class BoardingUtxo extends $pb.GeneratedMessage {
  factory BoardingUtxo({
    $core.String? txid,
    $core.int? vout,
    $fixnum.Int64? amountSats,
  }) {
    final $result = create();
    if (txid != null) {
      $result.txid = txid;
    }
    if (vout != null) {
      $result.vout = vout;
    }
    if (amountSats != null) {
      $result.amountSats = amountSats;
    }
    return $result;
  }
  BoardingUtxo._() : super();
  factory BoardingUtxo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BoardingUtxo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BoardingUtxo', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txid')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'vout', $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'amountSats', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BoardingUtxo clone() => BoardingUtxo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BoardingUtxo copyWith(void Function(BoardingUtxo) updates) => super.copyWith((message) => updates(message as BoardingUtxo)) as BoardingUtxo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BoardingUtxo create() => BoardingUtxo._();
  BoardingUtxo createEmptyInstance() => create();
  static $pb.PbList<BoardingUtxo> createRepeated() => $pb.PbList<BoardingUtxo>();
  @$core.pragma('dart2js:noInline')
  static BoardingUtxo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BoardingUtxo>(create);
  static BoardingUtxo? _defaultInstance;

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
  $fixnum.Int64 get amountSats => $_getI64(2);
  @$pb.TagNumber(3)
  set amountSats($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAmountSats() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmountSats() => clearField(3);
}

class SettleRequest extends $pb.GeneratedMessage {
  factory SettleRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
    $core.Iterable<BoardingUtxo>? boardingUtxos,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (signedMessages != null) {
      $result.signedMessages.addAll(signedMessages);
    }
    if (boardingUtxos != null) {
      $result.boardingUtxos.addAll(boardingUtxos);
    }
    return $result;
  }
  SettleRequest._() : super();
  factory SettleRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SettleRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..pc<BoardingUtxo>(5, _omitFieldNames ? '' : 'boardingUtxos', $pb.PbFieldType.PM, subBuilder: BoardingUtxo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleRequest clone() => SettleRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleRequest copyWith(void Function(SettleRequest) updates) => super.copyWith((message) => updates(message as SettleRequest)) as SettleRequest;

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

  /// FROST signatures for previously requested sighashes (phase 2+)
  @$pb.TagNumber(4)
  $core.List<$core.List<$core.int>> get signedMessages => $_getList(3);

  /// Wallet-scanned boarding UTXOs to settle. Required on the phase-1 (no-signatures)
  /// call; the cosigner no longer scans the chain. Currently the cosigner uses [0].
  @$pb.TagNumber(5)
  $core.List<BoardingUtxo> get boardingUtxos => $_getList(4);
}

class SettleResponse extends $pb.GeneratedMessage {
  factory SettleResponse({
    SettleResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? commitmentTxid,
    $core.String? errorMessage,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (messagesToSign != null) {
      $result.messagesToSign.addAll(messagesToSign);
    }
    if (scriptPathSpend != null) {
      $result.scriptPathSpend = scriptPathSpend;
    }
    if (commitmentTxid != null) {
      $result.commitmentTxid = commitmentTxid;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    return $result;
  }
  SettleResponse._() : super();
  factory SettleResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SettleResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..e<SettleResponse_Status>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: SettleResponse_Status.SIGNING_REQUIRED, valueOf: SettleResponse_Status.valueOf, enumValues: SettleResponse_Status.values)
    ..p<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, _omitFieldNames ? '' : 'scriptPathSpend')
    ..aOS(4, _omitFieldNames ? '' : 'commitmentTxid')
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleResponse clone() => SettleResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleResponse copyWith(void Function(SettleResponse) updates) => super.copyWith((message) => updates(message as SettleResponse)) as SettleResponse;

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

  /// Sighashes that need FROST signing (when SIGNING_REQUIRED)
  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get messagesToSign => $_getList(1);

  /// Whether these sighashes are script-path spends (no taproot tweak)
  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => clearField(3);

  /// Commitment txid when SETTLED
  @$pb.TagNumber(4)
  $core.String get commitmentTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set commitmentTxid($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCommitmentTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommitmentTxid() => clearField(4);

  /// Error message when ERROR
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
  factory SettleDelegateRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
    $core.bool? storeOnly,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (signedMessages != null) {
      $result.signedMessages.addAll(signedMessages);
    }
    if (storeOnly != null) {
      $result.storeOnly = storeOnly;
    }
    return $result;
  }
  SettleDelegateRequest._() : super();
  factory SettleDelegateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleDelegateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SettleDelegateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..aOB(5, _omitFieldNames ? '' : 'storeOnly')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleDelegateRequest clone() => SettleDelegateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleDelegateRequest copyWith(void Function(SettleDelegateRequest) updates) => super.copyWith((message) => updates(message as SettleDelegateRequest)) as SettleDelegateRequest;

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

  /// FROST signatures for previously requested sighashes (phase 2)
  @$pb.TagNumber(4)
  $core.List<$core.List<$core.int>> get signedMessages => $_getList(3);

  /// Phase 2 only. When true, the cosigner stores the signed intent and
  /// returns DELEGATED without joining a batch. The cosigner's auto-settle
  /// tick task drives the stored intent later when the threshold is reached.
  @$pb.TagNumber(5)
  $core.bool get storeOnly => $_getBF(4);
  @$pb.TagNumber(5)
  set storeOnly($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasStoreOnly() => $_has(4);
  @$pb.TagNumber(5)
  void clearStoreOnly() => clearField(5);
}

class SettleDelegateResponse extends $pb.GeneratedMessage {
  factory SettleDelegateResponse({
    SettleDelegateResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? commitmentTxid,
    $core.String? errorMessage,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (messagesToSign != null) {
      $result.messagesToSign.addAll(messagesToSign);
    }
    if (scriptPathSpend != null) {
      $result.scriptPathSpend = scriptPathSpend;
    }
    if (commitmentTxid != null) {
      $result.commitmentTxid = commitmentTxid;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    return $result;
  }
  SettleDelegateResponse._() : super();
  factory SettleDelegateResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SettleDelegateResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SettleDelegateResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..e<SettleDelegateResponse_Status>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: SettleDelegateResponse_Status.SIGNING_REQUIRED, valueOf: SettleDelegateResponse_Status.valueOf, enumValues: SettleDelegateResponse_Status.values)
    ..p<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, _omitFieldNames ? '' : 'scriptPathSpend')
    ..aOS(4, _omitFieldNames ? '' : 'commitmentTxid')
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SettleDelegateResponse clone() => SettleDelegateResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SettleDelegateResponse copyWith(void Function(SettleDelegateResponse) updates) => super.copyWith((message) => updates(message as SettleDelegateResponse)) as SettleDelegateResponse;

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

  /// Sighashes that need FROST signing (when SIGNING_REQUIRED)
  @$pb.TagNumber(2)
  $core.List<$core.List<$core.int>> get messagesToSign => $_getList(1);

  /// Always true for delegate (script-path spend, no taproot tweak)
  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => clearField(3);

  /// Commitment txid when SETTLED (empty for DELEGATED)
  @$pb.TagNumber(4)
  $core.String get commitmentTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set commitmentTxid($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCommitmentTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommitmentTxid() => clearField(4);

  /// Error message when ERROR
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
  factory SubmitArkSendRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.String? signedArkTxB64,
    $core.Iterable<$core.String>? signedCheckpointTxsB64,
    $core.Iterable<$core.String>? spentOutpoints,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (signedArkTxB64 != null) {
      $result.signedArkTxB64 = signedArkTxB64;
    }
    if (signedCheckpointTxsB64 != null) {
      $result.signedCheckpointTxsB64.addAll(signedCheckpointTxsB64);
    }
    if (spentOutpoints != null) {
      $result.spentOutpoints.addAll(spentOutpoints);
    }
    return $result;
  }
  SubmitArkSendRequest._() : super();
  factory SubmitArkSendRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubmitArkSendRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SubmitArkSendRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..aOS(4, _omitFieldNames ? '' : 'signedArkTxB64')
    ..pPS(5, _omitFieldNames ? '' : 'signedCheckpointTxsB64')
    ..pPS(6, _omitFieldNames ? '' : 'spentOutpoints')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubmitArkSendRequest clone() => SubmitArkSendRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubmitArkSendRequest copyWith(void Function(SubmitArkSendRequest) updates) => super.copyWith((message) => updates(message as SubmitArkSendRequest)) as SubmitArkSendRequest;

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

  /// Base64-encoded signed Ark tx PSBT (with FROST sigs on inputs)
  @$pb.TagNumber(4)
  $core.String get signedArkTxB64 => $_getSZ(3);
  @$pb.TagNumber(4)
  set signedArkTxB64($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSignedArkTxB64() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignedArkTxB64() => clearField(4);

  /// Base64-encoded checkpoint PSBTs (with client FROST sigs)
  @$pb.TagNumber(5)
  $core.List<$core.String> get signedCheckpointTxsB64 => $_getList(4);

  /// Outpoints of spent VTXOs ("txid:vout" format)
  @$pb.TagNumber(6)
  $core.List<$core.String> get spentOutpoints => $_getList(5);
}

class SubmitArkSendResponse extends $pb.GeneratedMessage {
  factory SubmitArkSendResponse({
    $core.String? arkTxid,
    $core.String? changeTxid,
    $core.int? changeVout,
    $fixnum.Int64? changeAmount,
  }) {
    final $result = create();
    if (arkTxid != null) {
      $result.arkTxid = arkTxid;
    }
    if (changeTxid != null) {
      $result.changeTxid = changeTxid;
    }
    if (changeVout != null) {
      $result.changeVout = changeVout;
    }
    if (changeAmount != null) {
      $result.changeAmount = changeAmount;
    }
    return $result;
  }
  SubmitArkSendResponse._() : super();
  factory SubmitArkSendResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubmitArkSendResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SubmitArkSendResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'arkTxid')
    ..aOS(2, _omitFieldNames ? '' : 'changeTxid')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'changeVout', $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'changeAmount', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubmitArkSendResponse clone() => SubmitArkSendResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubmitArkSendResponse copyWith(void Function(SubmitArkSendResponse) updates) => super.copyWith((message) => updates(message as SubmitArkSendResponse)) as SubmitArkSendResponse;

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

  /// Change VTXO info (empty if no change)
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

class GetServerInfoRequest extends $pb.GeneratedMessage {
  factory GetServerInfoRequest() => create();
  GetServerInfoRequest._() : super();
  factory GetServerInfoRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetServerInfoRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetServerInfoRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetServerInfoRequest clone() => GetServerInfoRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetServerInfoRequest copyWith(void Function(GetServerInfoRequest) updates) => super.copyWith((message) => updates(message as GetServerInfoRequest)) as GetServerInfoRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetServerInfoRequest create() => GetServerInfoRequest._();
  GetServerInfoRequest createEmptyInstance() => create();
  static $pb.PbList<GetServerInfoRequest> createRepeated() => $pb.PbList<GetServerInfoRequest>();
  @$core.pragma('dart2js:noInline')
  static GetServerInfoRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetServerInfoRequest>(create);
  static GetServerInfoRequest? _defaultInstance;
}

class GetServerInfoResponse extends $pb.GeneratedMessage {
  factory GetServerInfoResponse({
    $core.String? bitcoinNetwork,
  }) {
    final $result = create();
    if (bitcoinNetwork != null) {
      $result.bitcoinNetwork = bitcoinNetwork;
    }
    return $result;
  }
  GetServerInfoResponse._() : super();
  factory GetServerInfoResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetServerInfoResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetServerInfoResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'bitcoinNetwork')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetServerInfoResponse clone() => GetServerInfoResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetServerInfoResponse copyWith(void Function(GetServerInfoResponse) updates) => super.copyWith((message) => updates(message as GetServerInfoResponse)) as GetServerInfoResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetServerInfoResponse create() => GetServerInfoResponse._();
  GetServerInfoResponse createEmptyInstance() => create();
  static $pb.PbList<GetServerInfoResponse> createRepeated() => $pb.PbList<GetServerInfoResponse>();
  @$core.pragma('dart2js:noInline')
  static GetServerInfoResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetServerInfoResponse>(create);
  static GetServerInfoResponse? _defaultInstance;

  /// The Bitcoin network this deployment operates on. One of: "mainnet",
  /// "testnet", "signet", "mutinynet", "regtest". Source of truth for the
  /// client's address-rendering HRP.
  @$pb.TagNumber(1)
  $core.String get bitcoinNetwork => $_getSZ(0);
  @$pb.TagNumber(1)
  set bitcoinNetwork($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBitcoinNetwork() => $_has(0);
  @$pb.TagNumber(1)
  void clearBitcoinNetwork() => clearField(1);
}

class RegisterDeviceTokenRequest extends $pb.GeneratedMessage {
  factory RegisterDeviceTokenRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.String? fcmToken,
    $core.String? platform,
    $core.String? appVersion,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (fcmToken != null) {
      $result.fcmToken = fcmToken;
    }
    if (platform != null) {
      $result.platform = platform;
    }
    if (appVersion != null) {
      $result.appVersion = appVersion;
    }
    return $result;
  }
  RegisterDeviceTokenRequest._() : super();
  factory RegisterDeviceTokenRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RegisterDeviceTokenRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RegisterDeviceTokenRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..aOS(4, _omitFieldNames ? '' : 'fcmToken')
    ..aOS(5, _omitFieldNames ? '' : 'platform')
    ..aOS(6, _omitFieldNames ? '' : 'appVersion')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RegisterDeviceTokenRequest clone() => RegisterDeviceTokenRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RegisterDeviceTokenRequest copyWith(void Function(RegisterDeviceTokenRequest) updates) => super.copyWith((message) => updates(message as RegisterDeviceTokenRequest)) as RegisterDeviceTokenRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenRequest create() => RegisterDeviceTokenRequest._();
  RegisterDeviceTokenRequest createEmptyInstance() => create();
  static $pb.PbList<RegisterDeviceTokenRequest> createRepeated() => $pb.PbList<RegisterDeviceTokenRequest>();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RegisterDeviceTokenRequest>(create);
  static RegisterDeviceTokenRequest? _defaultInstance;

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
  $core.String get fcmToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set fcmToken($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasFcmToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearFcmToken() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get platform => $_getSZ(4);
  @$pb.TagNumber(5)
  set platform($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPlatform() => $_has(4);
  @$pb.TagNumber(5)
  void clearPlatform() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get appVersion => $_getSZ(5);
  @$pb.TagNumber(6)
  set appVersion($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasAppVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearAppVersion() => clearField(6);
}

class RegisterDeviceTokenResponse extends $pb.GeneratedMessage {
  factory RegisterDeviceTokenResponse({
    $core.bool? ok,
  }) {
    final $result = create();
    if (ok != null) {
      $result.ok = ok;
    }
    return $result;
  }
  RegisterDeviceTokenResponse._() : super();
  factory RegisterDeviceTokenResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RegisterDeviceTokenResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RegisterDeviceTokenResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RegisterDeviceTokenResponse clone() => RegisterDeviceTokenResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RegisterDeviceTokenResponse copyWith(void Function(RegisterDeviceTokenResponse) updates) => super.copyWith((message) => updates(message as RegisterDeviceTokenResponse)) as RegisterDeviceTokenResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenResponse create() => RegisterDeviceTokenResponse._();
  RegisterDeviceTokenResponse createEmptyInstance() => create();
  static $pb.PbList<RegisterDeviceTokenResponse> createRepeated() => $pb.PbList<RegisterDeviceTokenResponse>();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RegisterDeviceTokenResponse>(create);
  static RegisterDeviceTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => clearField(1);
}

/// ---------------------------------------------------------------------------
/// Contract creation (PEER model). NO reshare and NO new key: the wallet's existing
/// 2-of-2 key V is reused; the contract is enforced by the cosigner gate (WASM
/// evaluate + verifying-share allowlist). A single key-preserving REFRESH of V onto a
/// {receiver, cosigner} pairing lets the chosen RECEIVER (another user, identified by
/// its verifying key) co-sign V independently. Both halves of the receiver's share are
/// ECIES-encrypted to receiver_vk and held in the receiver's inbox: the wallet's
/// a@receiver (ecies_a_at_receiver, in this request) and the cosigner's b@receiver
/// (computed + encrypted by the cosigner). Only the POINT a@receiver·G reaches the
/// cosigner, so it never learns the receiver's full share.
/// ---------------------------------------------------------------------------
class ContractCreateRequest extends $pb.GeneratedMessage {
  factory ContractCreateRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.List<$core.int>? contractId,
    $core.List<$core.int>? contractWasm,
    $core.List<$core.int>? serverPk,
    $core.int? exitDelay,
    $core.List<$core.int>? ownerPk,
    $core.List<$core.int>? receiverVk,
    $core.List<$core.int>? aAtCosigner,
    $core.List<$core.int>? aAtReceiverPoint,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.List<$core.int>? eciesAAtReceiver,
    $core.String? templateId,
    $core.String? stubId,
    $core.List<$core.int>? configBlob,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (identifier != null) {
      $result.identifier = identifier;
    }
    if (contractId != null) {
      $result.contractId = contractId;
    }
    if (contractWasm != null) {
      $result.contractWasm = contractWasm;
    }
    if (serverPk != null) {
      $result.serverPk = serverPk;
    }
    if (exitDelay != null) {
      $result.exitDelay = exitDelay;
    }
    if (ownerPk != null) {
      $result.ownerPk = ownerPk;
    }
    if (receiverVk != null) {
      $result.receiverVk = receiverVk;
    }
    if (aAtCosigner != null) {
      $result.aAtCosigner = aAtCosigner;
    }
    if (aAtReceiverPoint != null) {
      $result.aAtReceiverPoint = aAtReceiverPoint;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (eciesAAtReceiver != null) {
      $result.eciesAAtReceiver = eciesAAtReceiver;
    }
    if (templateId != null) {
      $result.templateId = templateId;
    }
    if (stubId != null) {
      $result.stubId = stubId;
    }
    if (configBlob != null) {
      $result.configBlob = configBlob;
    }
    return $result;
  }
  ContractCreateRequest._() : super();
  factory ContractCreateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContractCreateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContractCreateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'contractId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'contractWasm', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'serverPk', $pb.PbFieldType.OY)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'exitDelay', $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(7, _omitFieldNames ? '' : 'ownerPk', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(8, _omitFieldNames ? '' : 'receiverVk', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'aAtCosigner', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(10, _omitFieldNames ? '' : 'aAtReceiverPoint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(11, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(12, _omitFieldNames ? '' : 'timestampMs')
    ..a<$core.List<$core.int>>(13, _omitFieldNames ? '' : 'eciesAAtReceiver', $pb.PbFieldType.OY)
    ..aOS(14, _omitFieldNames ? '' : 'templateId')
    ..aOS(15, _omitFieldNames ? '' : 'stubId')
    ..a<$core.List<$core.int>>(16, _omitFieldNames ? '' : 'configBlob', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContractCreateRequest clone() => ContractCreateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContractCreateRequest copyWith(void Function(ContractCreateRequest) updates) => super.copyWith((message) => updates(message as ContractCreateRequest)) as ContractCreateRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateRequest create() => ContractCreateRequest._();
  ContractCreateRequest createEmptyInstance() => create();
  static $pb.PbList<ContractCreateRequest> createRepeated() => $pb.PbList<ContractCreateRequest>();
  @$core.pragma('dart2js:noInline')
  static ContractCreateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContractCreateRequest>(create);
  static ContractCreateRequest? _defaultInstance;

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
  $core.List<$core.int> get contractId => $_getN(2);
  @$pb.TagNumber(3)
  set contractId($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasContractId() => $_has(2);
  @$pb.TagNumber(3)
  void clearContractId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get contractWasm => $_getN(3);
  @$pb.TagNumber(4)
  set contractWasm($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasContractWasm() => $_has(3);
  @$pb.TagNumber(4)
  void clearContractWasm() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get serverPk => $_getN(4);
  @$pb.TagNumber(5)
  set serverPk($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasServerPk() => $_has(4);
  @$pb.TagNumber(5)
  void clearServerPk() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get exitDelay => $_getIZ(5);
  @$pb.TagNumber(6)
  set exitDelay($core.int v) { $_setUnsignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasExitDelay() => $_has(5);
  @$pb.TagNumber(6)
  void clearExitDelay() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get ownerPk => $_getN(6);
  @$pb.TagNumber(7)
  set ownerPk($core.List<$core.int> v) { $_setBytes(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasOwnerPk() => $_has(6);
  @$pb.TagNumber(7)
  void clearOwnerPk() => clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get receiverVk => $_getN(7);
  @$pb.TagNumber(8)
  set receiverVk($core.List<$core.int> v) { $_setBytes(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasReceiverVk() => $_has(7);
  @$pb.TagNumber(8)
  void clearReceiverVk() => clearField(8);

  @$pb.TagNumber(9)
  $core.List<$core.int> get aAtCosigner => $_getN(8);
  @$pb.TagNumber(9)
  set aAtCosigner($core.List<$core.int> v) { $_setBytes(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasAAtCosigner() => $_has(8);
  @$pb.TagNumber(9)
  void clearAAtCosigner() => clearField(9);

  @$pb.TagNumber(10)
  $core.List<$core.int> get aAtReceiverPoint => $_getN(9);
  @$pb.TagNumber(10)
  set aAtReceiverPoint($core.List<$core.int> v) { $_setBytes(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasAAtReceiverPoint() => $_has(9);
  @$pb.TagNumber(10)
  void clearAAtReceiverPoint() => clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get signature => $_getN(10);
  @$pb.TagNumber(11)
  set signature($core.List<$core.int> v) { $_setBytes(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasSignature() => $_has(10);
  @$pb.TagNumber(11)
  void clearSignature() => clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get timestampMs => $_getI64(11);
  @$pb.TagNumber(12)
  set timestampMs($fixnum.Int64 v) { $_setInt64(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasTimestampMs() => $_has(11);
  @$pb.TagNumber(12)
  void clearTimestampMs() => clearField(12);

  @$pb.TagNumber(13)
  $core.List<$core.int> get eciesAAtReceiver => $_getN(12);
  @$pb.TagNumber(13)
  set eciesAAtReceiver($core.List<$core.int> v) { $_setBytes(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasEciesAAtReceiver() => $_has(12);
  @$pb.TagNumber(13)
  void clearEciesAAtReceiver() => clearField(13);

  /// Phase 2 (template + variable composition). When `template_id` is set, the cosigner composes a
  /// CONTRACT from a published TEMPLATE + the author's typed config: it fetches the template + its
  /// provider STUB (both by content id), patches `config_blob` (the encoded key-value config) into
  /// the stub, composes them into one component, and the COMPOSED sha256 becomes the bound
  /// contract_id (committing the variables). When empty, `contract_id`/`contract_wasm` above are used.
  @$pb.TagNumber(14)
  $core.String get templateId => $_getSZ(13);
  @$pb.TagNumber(14)
  set templateId($core.String v) { $_setString(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasTemplateId() => $_has(13);
  @$pb.TagNumber(14)
  void clearTemplateId() => clearField(14);

  @$pb.TagNumber(15)
  $core.String get stubId => $_getSZ(14);
  @$pb.TagNumber(15)
  set stubId($core.String v) { $_setString(14, v); }
  @$pb.TagNumber(15)
  $core.bool hasStubId() => $_has(14);
  @$pb.TagNumber(15)
  void clearStubId() => clearField(15);

  @$pb.TagNumber(16)
  $core.List<$core.int> get configBlob => $_getN(15);
  @$pb.TagNumber(16)
  set configBlob($core.List<$core.int> v) { $_setBytes(15, v); }
  @$pb.TagNumber(16)
  $core.bool hasConfigBlob() => $_has(15);
  @$pb.TagNumber(16)
  void clearConfigBlob() => clearField(16);
}

class ContractCreateResponse extends $pb.GeneratedMessage {
  factory ContractCreateResponse({
    $core.List<$core.int>? contractScriptPubkey,
    $core.List<$core.int>? contractId,
  }) {
    final $result = create();
    if (contractScriptPubkey != null) {
      $result.contractScriptPubkey = contractScriptPubkey;
    }
    if (contractId != null) {
      $result.contractId = contractId;
    }
    return $result;
  }
  ContractCreateResponse._() : super();
  factory ContractCreateResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContractCreateResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContractCreateResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'contractScriptPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'contractId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContractCreateResponse clone() => ContractCreateResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContractCreateResponse copyWith(void Function(ContractCreateResponse) updates) => super.copyWith((message) => updates(message as ContractCreateResponse)) as ContractCreateResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateResponse create() => ContractCreateResponse._();
  ContractCreateResponse createEmptyInstance() => create();
  static $pb.PbList<ContractCreateResponse> createRepeated() => $pb.PbList<ContractCreateResponse>();
  @$core.pragma('dart2js:noInline')
  static ContractCreateResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContractCreateResponse>(create);
  static ContractCreateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get contractScriptPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set contractScriptPubkey($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasContractScriptPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearContractScriptPubkey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get contractId => $_getN(1);
  @$pb.TagNumber(2)
  set contractId($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasContractId() => $_has(1);
  @$pb.TagNumber(2)
  void clearContractId() => clearField(2);
}

/// ---------------------------------------------------------------------------
/// Inbox pickup (PEER model). The receiver fetches the contract-share halves held for
/// it in its own inbox, decrypts BOTH ECIES halves with its signing secret, sums them
/// into its share P = a@receiver + b@receiver, then acks to clear. No FCM/poll loop is
/// required — the inbox is surfaced on the receiver's authenticated pull.
/// ---------------------------------------------------------------------------
class EvtxoPendingSharesRequest extends $pb.GeneratedMessage {
  factory EvtxoPendingSharesRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  EvtxoPendingSharesRequest._() : super();
  factory EvtxoPendingSharesRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoPendingSharesRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoPendingSharesRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoPendingSharesRequest clone() => EvtxoPendingSharesRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoPendingSharesRequest copyWith(void Function(EvtxoPendingSharesRequest) updates) => super.copyWith((message) => updates(message as EvtxoPendingSharesRequest)) as EvtxoPendingSharesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoPendingSharesRequest create() => EvtxoPendingSharesRequest._();
  EvtxoPendingSharesRequest createEmptyInstance() => create();
  static $pb.PbList<EvtxoPendingSharesRequest> createRepeated() => $pb.PbList<EvtxoPendingSharesRequest>();
  @$core.pragma('dart2js:noInline')
  static EvtxoPendingSharesRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoPendingSharesRequest>(create);
  static EvtxoPendingSharesRequest? _defaultInstance;

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

class EvtxoPendingSharesResponse extends $pb.GeneratedMessage {
  factory EvtxoPendingSharesResponse({
    $core.Iterable<PendingContractShare>? shares,
  }) {
    final $result = create();
    if (shares != null) {
      $result.shares.addAll(shares);
    }
    return $result;
  }
  EvtxoPendingSharesResponse._() : super();
  factory EvtxoPendingSharesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoPendingSharesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoPendingSharesResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<PendingContractShare>(1, _omitFieldNames ? '' : 'shares', $pb.PbFieldType.PM, subBuilder: PendingContractShare.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoPendingSharesResponse clone() => EvtxoPendingSharesResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoPendingSharesResponse copyWith(void Function(EvtxoPendingSharesResponse) updates) => super.copyWith((message) => updates(message as EvtxoPendingSharesResponse)) as EvtxoPendingSharesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoPendingSharesResponse create() => EvtxoPendingSharesResponse._();
  EvtxoPendingSharesResponse createEmptyInstance() => create();
  static $pb.PbList<EvtxoPendingSharesResponse> createRepeated() => $pb.PbList<EvtxoPendingSharesResponse>();
  @$core.pragma('dart2js:noInline')
  static EvtxoPendingSharesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoPendingSharesResponse>(create);
  static EvtxoPendingSharesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<PendingContractShare> get shares => $_getList(0);
}

class PendingContractShare extends $pb.GeneratedMessage {
  factory PendingContractShare({
    $core.List<$core.int>? evtxoScriptPubkey,
    $core.List<$core.int>? contractId,
    $core.List<$core.int>? eciesHalfAuthor,
    $core.List<$core.int>? eciesHalfCosigner,
    $core.String? publicKeyPackageJson,
    $core.int? exitDelay,
    $core.List<$core.int>? serverPk,
    $core.List<$core.int>? ownerPk,
  }) {
    final $result = create();
    if (evtxoScriptPubkey != null) {
      $result.evtxoScriptPubkey = evtxoScriptPubkey;
    }
    if (contractId != null) {
      $result.contractId = contractId;
    }
    if (eciesHalfAuthor != null) {
      $result.eciesHalfAuthor = eciesHalfAuthor;
    }
    if (eciesHalfCosigner != null) {
      $result.eciesHalfCosigner = eciesHalfCosigner;
    }
    if (publicKeyPackageJson != null) {
      $result.publicKeyPackageJson = publicKeyPackageJson;
    }
    if (exitDelay != null) {
      $result.exitDelay = exitDelay;
    }
    if (serverPk != null) {
      $result.serverPk = serverPk;
    }
    if (ownerPk != null) {
      $result.ownerPk = ownerPk;
    }
    return $result;
  }
  PendingContractShare._() : super();
  factory PendingContractShare.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PendingContractShare.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PendingContractShare', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'evtxoScriptPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'contractId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'eciesHalfAuthor', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'eciesHalfCosigner', $pb.PbFieldType.OY)
    ..aOS(5, _omitFieldNames ? '' : 'publicKeyPackageJson')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'exitDelay', $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(7, _omitFieldNames ? '' : 'serverPk', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(8, _omitFieldNames ? '' : 'ownerPk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PendingContractShare clone() => PendingContractShare()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PendingContractShare copyWith(void Function(PendingContractShare) updates) => super.copyWith((message) => updates(message as PendingContractShare)) as PendingContractShare;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PendingContractShare create() => PendingContractShare._();
  PendingContractShare createEmptyInstance() => create();
  static $pb.PbList<PendingContractShare> createRepeated() => $pb.PbList<PendingContractShare>();
  @$core.pragma('dart2js:noInline')
  static PendingContractShare getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PendingContractShare>(create);
  static PendingContractShare? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get evtxoScriptPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set evtxoScriptPubkey($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasEvtxoScriptPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvtxoScriptPubkey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get contractId => $_getN(1);
  @$pb.TagNumber(2)
  set contractId($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasContractId() => $_has(1);
  @$pb.TagNumber(2)
  void clearContractId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get eciesHalfAuthor => $_getN(2);
  @$pb.TagNumber(3)
  set eciesHalfAuthor($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasEciesHalfAuthor() => $_has(2);
  @$pb.TagNumber(3)
  void clearEciesHalfAuthor() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get eciesHalfCosigner => $_getN(3);
  @$pb.TagNumber(4)
  set eciesHalfCosigner($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasEciesHalfCosigner() => $_has(3);
  @$pb.TagNumber(4)
  void clearEciesHalfCosigner() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get publicKeyPackageJson => $_getSZ(4);
  @$pb.TagNumber(5)
  set publicKeyPackageJson($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPublicKeyPackageJson() => $_has(4);
  @$pb.TagNumber(5)
  void clearPublicKeyPackageJson() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get exitDelay => $_getIZ(5);
  @$pb.TagNumber(6)
  set exitDelay($core.int v) { $_setUnsignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasExitDelay() => $_has(5);
  @$pb.TagNumber(6)
  void clearExitDelay() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get serverPk => $_getN(6);
  @$pb.TagNumber(7)
  set serverPk($core.List<$core.int> v) { $_setBytes(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasServerPk() => $_has(6);
  @$pb.TagNumber(7)
  void clearServerPk() => clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get ownerPk => $_getN(7);
  @$pb.TagNumber(8)
  set ownerPk($core.List<$core.int> v) { $_setBytes(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasOwnerPk() => $_has(7);
  @$pb.TagNumber(8)
  void clearOwnerPk() => clearField(8);
}

class EvtxoAckShareRequest extends $pb.GeneratedMessage {
  factory EvtxoAckShareRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? evtxoScriptPubkey,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (evtxoScriptPubkey != null) {
      $result.evtxoScriptPubkey = evtxoScriptPubkey;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  EvtxoAckShareRequest._() : super();
  factory EvtxoAckShareRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoAckShareRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoAckShareRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'evtxoScriptPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoAckShareRequest clone() => EvtxoAckShareRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoAckShareRequest copyWith(void Function(EvtxoAckShareRequest) updates) => super.copyWith((message) => updates(message as EvtxoAckShareRequest)) as EvtxoAckShareRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoAckShareRequest create() => EvtxoAckShareRequest._();
  EvtxoAckShareRequest createEmptyInstance() => create();
  static $pb.PbList<EvtxoAckShareRequest> createRepeated() => $pb.PbList<EvtxoAckShareRequest>();
  @$core.pragma('dart2js:noInline')
  static EvtxoAckShareRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoAckShareRequest>(create);
  static EvtxoAckShareRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get evtxoScriptPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set evtxoScriptPubkey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEvtxoScriptPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearEvtxoScriptPubkey() => clearField(2);

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

class EvtxoAckShareResponse extends $pb.GeneratedMessage {
  factory EvtxoAckShareResponse({
    $core.bool? ok,
  }) {
    final $result = create();
    if (ok != null) {
      $result.ok = ok;
    }
    return $result;
  }
  EvtxoAckShareResponse._() : super();
  factory EvtxoAckShareResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoAckShareResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoAckShareResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoAckShareResponse clone() => EvtxoAckShareResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoAckShareResponse copyWith(void Function(EvtxoAckShareResponse) updates) => super.copyWith((message) => updates(message as EvtxoAckShareResponse)) as EvtxoAckShareResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoAckShareResponse create() => EvtxoAckShareResponse._();
  EvtxoAckShareResponse createEmptyInstance() => create();
  static $pb.PbList<EvtxoAckShareResponse> createRepeated() => $pb.PbList<EvtxoAckShareResponse>();
  @$core.pragma('dart2js:noInline')
  static EvtxoAckShareResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoAckShareResponse>(create);
  static EvtxoAckShareResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => clearField(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
