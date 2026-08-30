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
/// Service enrolment
/// ---------------------------------------------------------------------------
class ServiceEnrollRequest extends $pb.GeneratedMessage {
  factory ServiceEnrollRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.List<$core.int>? serviceId,
    $core.List<$core.int>? aAtCosigner,
    $core.List<$core.int>? aAtServicePoint,
    $core.Iterable<$core.String>? allowedDestinations,
    $fixnum.Int64? maxSatsPerSignature,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (identifier != null) {
      $result.identifier = identifier;
    }
    if (serviceId != null) {
      $result.serviceId = serviceId;
    }
    if (aAtCosigner != null) {
      $result.aAtCosigner = aAtCosigner;
    }
    if (aAtServicePoint != null) {
      $result.aAtServicePoint = aAtServicePoint;
    }
    if (allowedDestinations != null) {
      $result.allowedDestinations.addAll(allowedDestinations);
    }
    if (maxSatsPerSignature != null) {
      $result.maxSatsPerSignature = maxSatsPerSignature;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  ServiceEnrollRequest._() : super();
  factory ServiceEnrollRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ServiceEnrollRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ServiceEnrollRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'serviceId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'aAtCosigner', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'aAtServicePoint', $pb.PbFieldType.OY)
    ..pPS(6, _omitFieldNames ? '' : 'allowedDestinations')
    ..a<$fixnum.Int64>(7, _omitFieldNames ? '' : 'maxSatsPerSignature', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(8, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(9, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ServiceEnrollRequest clone() => ServiceEnrollRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ServiceEnrollRequest copyWith(void Function(ServiceEnrollRequest) updates) => super.copyWith((message) => updates(message as ServiceEnrollRequest)) as ServiceEnrollRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServiceEnrollRequest create() => ServiceEnrollRequest._();
  ServiceEnrollRequest createEmptyInstance() => create();
  static $pb.PbList<ServiceEnrollRequest> createRepeated() => $pb.PbList<ServiceEnrollRequest>();
  @$core.pragma('dart2js:noInline')
  static ServiceEnrollRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServiceEnrollRequest>(create);
  static ServiceEnrollRequest? _defaultInstance;

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

  /// The service's identity: a 33-byte compressed secp256k1 key. Names the service, is the ECIES
  /// target for its half, and derives its FROST identifier. It never signs — the service's signing
  /// credential is the verifying share this call returns.
  @$pb.TagNumber(3)
  $core.List<$core.int> get serviceId => $_getN(2);
  @$pb.TagNumber(3)
  set serviceId($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasServiceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearServiceId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get aAtCosigner => $_getN(3);
  @$pb.TagNumber(4)
  set aAtCosigner($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAAtCosigner() => $_has(3);
  @$pb.TagNumber(4)
  void clearAAtCosigner() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get aAtServicePoint => $_getN(4);
  @$pb.TagNumber(5)
  set aAtServicePoint($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasAAtServicePoint() => $_has(4);
  @$pb.TagNumber(5)
  void clearAAtServicePoint() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.String> get allowedDestinations => $_getList(5);

  @$pb.TagNumber(7)
  $fixnum.Int64 get maxSatsPerSignature => $_getI64(6);
  @$pb.TagNumber(7)
  set maxSatsPerSignature($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasMaxSatsPerSignature() => $_has(6);
  @$pb.TagNumber(7)
  void clearMaxSatsPerSignature() => clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get signature => $_getN(7);
  @$pb.TagNumber(8)
  set signature($core.List<$core.int> v) { $_setBytes(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasSignature() => $_has(7);
  @$pb.TagNumber(8)
  void clearSignature() => clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get timestampMs => $_getI64(8);
  @$pb.TagNumber(9)
  set timestampMs($fixnum.Int64 v) { $_setInt64(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasTimestampMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearTimestampMs() => clearField(9);
}

class ServiceEnrollResponse extends $pb.GeneratedMessage {
  factory ServiceEnrollResponse({
    $core.String? pairingGroupKey,
    $core.String? serviceVerifyingShare,
    $core.String? pairingPublicKeyPackageJson,
    $core.bool? cosignerHalfDelivered,
  }) {
    final $result = create();
    if (pairingGroupKey != null) {
      $result.pairingGroupKey = pairingGroupKey;
    }
    if (serviceVerifyingShare != null) {
      $result.serviceVerifyingShare = serviceVerifyingShare;
    }
    if (pairingPublicKeyPackageJson != null) {
      $result.pairingPublicKeyPackageJson = pairingPublicKeyPackageJson;
    }
    if (cosignerHalfDelivered != null) {
      $result.cosignerHalfDelivered = cosignerHalfDelivered;
    }
    return $result;
  }
  ServiceEnrollResponse._() : super();
  factory ServiceEnrollResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ServiceEnrollResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ServiceEnrollResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pairingGroupKey')
    ..aOS(2, _omitFieldNames ? '' : 'serviceVerifyingShare')
    ..aOS(3, _omitFieldNames ? '' : 'pairingPublicKeyPackageJson')
    ..aOB(4, _omitFieldNames ? '' : 'cosignerHalfDelivered')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ServiceEnrollResponse clone() => ServiceEnrollResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ServiceEnrollResponse copyWith(void Function(ServiceEnrollResponse) updates) => super.copyWith((message) => updates(message as ServiceEnrollResponse)) as ServiceEnrollResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServiceEnrollResponse create() => ServiceEnrollResponse._();
  ServiceEnrollResponse createEmptyInstance() => create();
  static $pb.PbList<ServiceEnrollResponse> createRepeated() => $pb.PbList<ServiceEnrollResponse>();
  @$core.pragma('dart2js:noInline')
  static ServiceEnrollResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServiceEnrollResponse>(create);
  static ServiceEnrollResponse? _defaultInstance;

  /// The wallet's own group key: the pairing shares `V`, so the service addresses the wallet's
  /// actor and is told apart by its verifying share.
  @$pb.TagNumber(1)
  $core.String get pairingGroupKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairingGroupKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPairingGroupKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairingGroupKey() => clearField(1);

  /// The service's verifying share — its `user_id` when signing, and the key its pairing is filed
  /// under. The wallet needs it to address the half it must still push.
  @$pb.TagNumber(2)
  $core.String get serviceVerifyingShare => $_getSZ(1);
  @$pb.TagNumber(2)
  set serviceVerifyingShare($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasServiceVerifyingShare() => $_has(1);
  @$pb.TagNumber(2)
  void clearServiceVerifyingShare() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get pairingPublicKeyPackageJson => $_getSZ(2);
  @$pb.TagNumber(3)
  set pairingPublicKeyPackageJson($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPairingPublicKeyPackageJson() => $_has(2);
  @$pb.TagNumber(3)
  void clearPairingPublicKeyPackageJson() => clearField(3);

  /// Whether the cosigner reached the service with its own half. False means the pairing exists but
  /// the service cannot assemble a share until that half is re-pushed.
  @$pb.TagNumber(4)
  $core.bool get cosignerHalfDelivered => $_getBF(3);
  @$pb.TagNumber(4)
  set cosignerHalfDelivered($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCosignerHalfDelivered() => $_has(3);
  @$pb.TagNumber(4)
  void clearCosignerHalfDelivered() => clearField(4);
}

class ServiceListRequest extends $pb.GeneratedMessage {
  factory ServiceListRequest({
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
  ServiceListRequest._() : super();
  factory ServiceListRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ServiceListRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ServiceListRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ServiceListRequest clone() => ServiceListRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ServiceListRequest copyWith(void Function(ServiceListRequest) updates) => super.copyWith((message) => updates(message as ServiceListRequest)) as ServiceListRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServiceListRequest create() => ServiceListRequest._();
  ServiceListRequest createEmptyInstance() => create();
  static $pb.PbList<ServiceListRequest> createRepeated() => $pb.PbList<ServiceListRequest>();
  @$core.pragma('dart2js:noInline')
  static ServiceListRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServiceListRequest>(create);
  static ServiceListRequest? _defaultInstance;

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

class ServiceListResponse extends $pb.GeneratedMessage {
  factory ServiceListResponse({
    $core.Iterable<EnrolledService>? services,
  }) {
    final $result = create();
    if (services != null) {
      $result.services.addAll(services);
    }
    return $result;
  }
  ServiceListResponse._() : super();
  factory ServiceListResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ServiceListResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ServiceListResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<EnrolledService>(1, _omitFieldNames ? '' : 'services', $pb.PbFieldType.PM, subBuilder: EnrolledService.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ServiceListResponse clone() => ServiceListResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ServiceListResponse copyWith(void Function(ServiceListResponse) updates) => super.copyWith((message) => updates(message as ServiceListResponse)) as ServiceListResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServiceListResponse create() => ServiceListResponse._();
  ServiceListResponse createEmptyInstance() => create();
  static $pb.PbList<ServiceListResponse> createRepeated() => $pb.PbList<ServiceListResponse>();
  @$core.pragma('dart2js:noInline')
  static ServiceListResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServiceListResponse>(create);
  static ServiceListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<EnrolledService> get services => $_getList(0);
}

class EnrolledService extends $pb.GeneratedMessage {
  factory EnrolledService({
    $core.String? verifyingShare,
    $core.String? serviceId,
  }) {
    final $result = create();
    if (verifyingShare != null) {
      $result.verifyingShare = verifyingShare;
    }
    if (serviceId != null) {
      $result.serviceId = serviceId;
    }
    return $result;
  }
  EnrolledService._() : super();
  factory EnrolledService.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EnrolledService.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EnrolledService', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'verifyingShare')
    ..aOS(2, _omitFieldNames ? '' : 'serviceId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EnrolledService clone() => EnrolledService()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EnrolledService copyWith(void Function(EnrolledService) updates) => super.copyWith((message) => updates(message as EnrolledService)) as EnrolledService;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnrolledService create() => EnrolledService._();
  EnrolledService createEmptyInstance() => create();
  static $pb.PbList<EnrolledService> createRepeated() => $pb.PbList<EnrolledService>();
  @$core.pragma('dart2js:noInline')
  static EnrolledService getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EnrolledService>(create);
  static EnrolledService? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get verifyingShare => $_getSZ(0);
  @$pb.TagNumber(1)
  set verifyingShare($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasVerifyingShare() => $_has(0);
  @$pb.TagNumber(1)
  void clearVerifyingShare() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get serviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set serviceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasServiceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearServiceId() => clearField(2);
}

class ServiceRevokeRequest extends $pb.GeneratedMessage {
  factory ServiceRevokeRequest({
    $core.List<$core.int>? userId,
    $core.String? verifyingShare,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (verifyingShare != null) {
      $result.verifyingShare = verifyingShare;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  ServiceRevokeRequest._() : super();
  factory ServiceRevokeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ServiceRevokeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ServiceRevokeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'verifyingShare')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ServiceRevokeRequest clone() => ServiceRevokeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ServiceRevokeRequest copyWith(void Function(ServiceRevokeRequest) updates) => super.copyWith((message) => updates(message as ServiceRevokeRequest)) as ServiceRevokeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServiceRevokeRequest create() => ServiceRevokeRequest._();
  ServiceRevokeRequest createEmptyInstance() => create();
  static $pb.PbList<ServiceRevokeRequest> createRepeated() => $pb.PbList<ServiceRevokeRequest>();
  @$core.pragma('dart2js:noInline')
  static ServiceRevokeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServiceRevokeRequest>(create);
  static ServiceRevokeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get verifyingShare => $_getSZ(1);
  @$pb.TagNumber(2)
  set verifyingShare($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasVerifyingShare() => $_has(1);
  @$pb.TagNumber(2)
  void clearVerifyingShare() => clearField(2);

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

class ServiceRevokeResponse extends $pb.GeneratedMessage {
  factory ServiceRevokeResponse({
    $core.bool? revoked,
  }) {
    final $result = create();
    if (revoked != null) {
      $result.revoked = revoked;
    }
    return $result;
  }
  ServiceRevokeResponse._() : super();
  factory ServiceRevokeResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ServiceRevokeResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ServiceRevokeResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'revoked')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ServiceRevokeResponse clone() => ServiceRevokeResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ServiceRevokeResponse copyWith(void Function(ServiceRevokeResponse) updates) => super.copyWith((message) => updates(message as ServiceRevokeResponse)) as ServiceRevokeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServiceRevokeResponse create() => ServiceRevokeResponse._();
  ServiceRevokeResponse createEmptyInstance() => create();
  static $pb.PbList<ServiceRevokeResponse> createRepeated() => $pb.PbList<ServiceRevokeResponse>();
  @$core.pragma('dart2js:noInline')
  static ServiceRevokeResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServiceRevokeResponse>(create);
  static ServiceRevokeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get revoked => $_getBF(0);
  @$pb.TagNumber(1)
  set revoked($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRevoked() => $_has(0);
  @$pb.TagNumber(1)
  void clearRevoked() => clearField(1);
}

/// A party this wallet has authorized to send it payment requests. One-way: the owner decides who
/// may bill it; the contact needs no consent and is not notified.
class Contact extends $pb.GeneratedMessage {
  factory Contact({
    $core.List<$core.int>? verifyingKey,
    $core.String? label,
    $fixnum.Int64? addedAt,
  }) {
    final $result = create();
    if (verifyingKey != null) {
      $result.verifyingKey = verifyingKey;
    }
    if (label != null) {
      $result.label = label;
    }
    if (addedAt != null) {
      $result.addedAt = addedAt;
    }
    return $result;
  }
  Contact._() : super();
  factory Contact.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Contact.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Contact', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'verifyingKey', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aInt64(3, _omitFieldNames ? '' : 'addedAt')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Contact clone() => Contact()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Contact copyWith(void Function(Contact) updates) => super.copyWith((message) => updates(message as Contact)) as Contact;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Contact create() => Contact._();
  Contact createEmptyInstance() => create();
  static $pb.PbList<Contact> createRepeated() => $pb.PbList<Contact>();
  @$core.pragma('dart2js:noInline')
  static Contact getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Contact>(create);
  static Contact? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get verifyingKey => $_getN(0);
  @$pb.TagNumber(1)
  set verifyingKey($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasVerifyingKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearVerifyingKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get addedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set addedAt($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAddedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearAddedAt() => clearField(3);
}

class ContactAddRequest extends $pb.GeneratedMessage {
  factory ContactAddRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? contactVerifyingKey,
    $core.String? label,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (contactVerifyingKey != null) {
      $result.contactVerifyingKey = contactVerifyingKey;
    }
    if (label != null) {
      $result.label = label;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  ContactAddRequest._() : super();
  factory ContactAddRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContactAddRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContactAddRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'contactVerifyingKey', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'label')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContactAddRequest clone() => ContactAddRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContactAddRequest copyWith(void Function(ContactAddRequest) updates) => super.copyWith((message) => updates(message as ContactAddRequest)) as ContactAddRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContactAddRequest create() => ContactAddRequest._();
  ContactAddRequest createEmptyInstance() => create();
  static $pb.PbList<ContactAddRequest> createRepeated() => $pb.PbList<ContactAddRequest>();
  @$core.pragma('dart2js:noInline')
  static ContactAddRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContactAddRequest>(create);
  static ContactAddRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get contactVerifyingKey => $_getN(1);
  @$pb.TagNumber(2)
  set contactVerifyingKey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasContactVerifyingKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearContactVerifyingKey() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get label => $_getSZ(2);
  @$pb.TagNumber(3)
  set label($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasLabel() => $_has(2);
  @$pb.TagNumber(3)
  void clearLabel() => clearField(3);

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

class ContactAddResponse extends $pb.GeneratedMessage {
  factory ContactAddResponse({
    $core.bool? ok,
  }) {
    final $result = create();
    if (ok != null) {
      $result.ok = ok;
    }
    return $result;
  }
  ContactAddResponse._() : super();
  factory ContactAddResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContactAddResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContactAddResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContactAddResponse clone() => ContactAddResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContactAddResponse copyWith(void Function(ContactAddResponse) updates) => super.copyWith((message) => updates(message as ContactAddResponse)) as ContactAddResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContactAddResponse create() => ContactAddResponse._();
  ContactAddResponse createEmptyInstance() => create();
  static $pb.PbList<ContactAddResponse> createRepeated() => $pb.PbList<ContactAddResponse>();
  @$core.pragma('dart2js:noInline')
  static ContactAddResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContactAddResponse>(create);
  static ContactAddResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => clearField(1);
}

class ContactRemoveRequest extends $pb.GeneratedMessage {
  factory ContactRemoveRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? contactVerifyingKey,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (contactVerifyingKey != null) {
      $result.contactVerifyingKey = contactVerifyingKey;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  ContactRemoveRequest._() : super();
  factory ContactRemoveRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContactRemoveRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContactRemoveRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'contactVerifyingKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContactRemoveRequest clone() => ContactRemoveRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContactRemoveRequest copyWith(void Function(ContactRemoveRequest) updates) => super.copyWith((message) => updates(message as ContactRemoveRequest)) as ContactRemoveRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContactRemoveRequest create() => ContactRemoveRequest._();
  ContactRemoveRequest createEmptyInstance() => create();
  static $pb.PbList<ContactRemoveRequest> createRepeated() => $pb.PbList<ContactRemoveRequest>();
  @$core.pragma('dart2js:noInline')
  static ContactRemoveRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContactRemoveRequest>(create);
  static ContactRemoveRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get contactVerifyingKey => $_getN(1);
  @$pb.TagNumber(2)
  set contactVerifyingKey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasContactVerifyingKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearContactVerifyingKey() => clearField(2);

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

class ContactRemoveResponse extends $pb.GeneratedMessage {
  factory ContactRemoveResponse({
    $core.bool? ok,
  }) {
    final $result = create();
    if (ok != null) {
      $result.ok = ok;
    }
    return $result;
  }
  ContactRemoveResponse._() : super();
  factory ContactRemoveResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContactRemoveResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContactRemoveResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContactRemoveResponse clone() => ContactRemoveResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContactRemoveResponse copyWith(void Function(ContactRemoveResponse) updates) => super.copyWith((message) => updates(message as ContactRemoveResponse)) as ContactRemoveResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContactRemoveResponse create() => ContactRemoveResponse._();
  ContactRemoveResponse createEmptyInstance() => create();
  static $pb.PbList<ContactRemoveResponse> createRepeated() => $pb.PbList<ContactRemoveResponse>();
  @$core.pragma('dart2js:noInline')
  static ContactRemoveResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContactRemoveResponse>(create);
  static ContactRemoveResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => clearField(1);
}

class ContactListRequest extends $pb.GeneratedMessage {
  factory ContactListRequest({
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
  ContactListRequest._() : super();
  factory ContactListRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContactListRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContactListRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContactListRequest clone() => ContactListRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContactListRequest copyWith(void Function(ContactListRequest) updates) => super.copyWith((message) => updates(message as ContactListRequest)) as ContactListRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContactListRequest create() => ContactListRequest._();
  ContactListRequest createEmptyInstance() => create();
  static $pb.PbList<ContactListRequest> createRepeated() => $pb.PbList<ContactListRequest>();
  @$core.pragma('dart2js:noInline')
  static ContactListRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContactListRequest>(create);
  static ContactListRequest? _defaultInstance;

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

class ContactListResponse extends $pb.GeneratedMessage {
  factory ContactListResponse({
    $core.Iterable<Contact>? contacts,
  }) {
    final $result = create();
    if (contacts != null) {
      $result.contacts.addAll(contacts);
    }
    return $result;
  }
  ContactListResponse._() : super();
  factory ContactListResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContactListResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContactListResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<Contact>(1, _omitFieldNames ? '' : 'contacts', $pb.PbFieldType.PM, subBuilder: Contact.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContactListResponse clone() => ContactListResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContactListResponse copyWith(void Function(ContactListResponse) updates) => super.copyWith((message) => updates(message as ContactListResponse)) as ContactListResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContactListResponse create() => ContactListResponse._();
  ContactListResponse createEmptyInstance() => create();
  static $pb.PbList<ContactListResponse> createRepeated() => $pb.PbList<ContactListResponse>();
  @$core.pragma('dart2js:noInline')
  static ContactListResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContactListResponse>(create);
  static ContactListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Contact> get contacts => $_getList(0);
}

/// A request-to-pay held for the payer. NOT a pre-signed transaction: FROST is 2-round interactive
/// and Ark checkpoints need an ASP counter-signature, so no payment can be fully signed ahead of the
/// payer's approval. This records WHO asked, HOW MUCH, TO WHICH ADDRESS and UNTIL WHEN; the payer
/// reviews it and either signs the payment or declines.
class PaymentIntent extends $pb.GeneratedMessage {
  factory PaymentIntent({
    $core.String? id,
    $core.List<$core.int>? fromVerifyingKey,
    $core.String? toArkAddress,
    $fixnum.Int64? amountSats,
    $core.String? memo,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? expiresAt,
    $core.String? status,
    $core.String? arkTxid,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (fromVerifyingKey != null) {
      $result.fromVerifyingKey = fromVerifyingKey;
    }
    if (toArkAddress != null) {
      $result.toArkAddress = toArkAddress;
    }
    if (amountSats != null) {
      $result.amountSats = amountSats;
    }
    if (memo != null) {
      $result.memo = memo;
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
    if (arkTxid != null) {
      $result.arkTxid = arkTxid;
    }
    return $result;
  }
  PaymentIntent._() : super();
  factory PaymentIntent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PaymentIntent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PaymentIntent', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'fromVerifyingKey', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'toArkAddress')
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'amountSats', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(5, _omitFieldNames ? '' : 'memo')
    ..aInt64(6, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(7, _omitFieldNames ? '' : 'expiresAt')
    ..aOS(8, _omitFieldNames ? '' : 'status')
    ..aOS(9, _omitFieldNames ? '' : 'arkTxid')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PaymentIntent clone() => PaymentIntent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PaymentIntent copyWith(void Function(PaymentIntent) updates) => super.copyWith((message) => updates(message as PaymentIntent)) as PaymentIntent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentIntent create() => PaymentIntent._();
  PaymentIntent createEmptyInstance() => create();
  static $pb.PbList<PaymentIntent> createRepeated() => $pb.PbList<PaymentIntent>();
  @$core.pragma('dart2js:noInline')
  static PaymentIntent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaymentIntent>(create);
  static PaymentIntent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get fromVerifyingKey => $_getN(1);
  @$pb.TagNumber(2)
  set fromVerifyingKey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFromVerifyingKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromVerifyingKey() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get toArkAddress => $_getSZ(2);
  @$pb.TagNumber(3)
  set toArkAddress($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasToArkAddress() => $_has(2);
  @$pb.TagNumber(3)
  void clearToArkAddress() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get amountSats => $_getI64(3);
  @$pb.TagNumber(4)
  set amountSats($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAmountSats() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmountSats() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get memo => $_getSZ(4);
  @$pb.TagNumber(5)
  set memo($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMemo() => $_has(4);
  @$pb.TagNumber(5)
  void clearMemo() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdAt => $_getI64(5);
  @$pb.TagNumber(6)
  set createdAt($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get expiresAt => $_getI64(6);
  @$pb.TagNumber(7)
  set expiresAt($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasExpiresAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpiresAt() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get status => $_getSZ(7);
  @$pb.TagNumber(8)
  set status($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get arkTxid => $_getSZ(8);
  @$pb.TagNumber(9)
  set arkTxid($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasArkTxid() => $_has(8);
  @$pb.TagNumber(9)
  void clearArkTxid() => clearField(9);
}

/// Sent by the REQUESTER but routed to the PAYER's actor: `user_id` is the requester (who signs),
/// while the URL/actor id is the payer. The payer's allowlist is the only authorization.
class PaymentRequestCreateRequest extends $pb.GeneratedMessage {
  factory PaymentRequestCreateRequest({
    $core.List<$core.int>? userId,
    $fixnum.Int64? amountSats,
    $core.String? memo,
    $fixnum.Int64? expiresInSecs,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (amountSats != null) {
      $result.amountSats = amountSats;
    }
    if (memo != null) {
      $result.memo = memo;
    }
    if (expiresInSecs != null) {
      $result.expiresInSecs = expiresInSecs;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  PaymentRequestCreateRequest._() : super();
  factory PaymentRequestCreateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PaymentRequestCreateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PaymentRequestCreateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'amountSats', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'memo')
    ..aInt64(4, _omitFieldNames ? '' : 'expiresInSecs')
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(6, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PaymentRequestCreateRequest clone() => PaymentRequestCreateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PaymentRequestCreateRequest copyWith(void Function(PaymentRequestCreateRequest) updates) => super.copyWith((message) => updates(message as PaymentRequestCreateRequest)) as PaymentRequestCreateRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRequestCreateRequest create() => PaymentRequestCreateRequest._();
  PaymentRequestCreateRequest createEmptyInstance() => create();
  static $pb.PbList<PaymentRequestCreateRequest> createRepeated() => $pb.PbList<PaymentRequestCreateRequest>();
  @$core.pragma('dart2js:noInline')
  static PaymentRequestCreateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaymentRequestCreateRequest>(create);
  static PaymentRequestCreateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amountSats => $_getI64(1);
  @$pb.TagNumber(2)
  set amountSats($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAmountSats() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmountSats() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get memo => $_getSZ(2);
  @$pb.TagNumber(3)
  set memo($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMemo() => $_has(2);
  @$pb.TagNumber(3)
  void clearMemo() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get expiresInSecs => $_getI64(3);
  @$pb.TagNumber(4)
  set expiresInSecs($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasExpiresInSecs() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresInSecs() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get signature => $_getN(4);
  @$pb.TagNumber(5)
  set signature($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignature() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get timestampMs => $_getI64(5);
  @$pb.TagNumber(6)
  set timestampMs($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTimestampMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestampMs() => clearField(6);
}

class PaymentRequestCreateResponse extends $pb.GeneratedMessage {
  factory PaymentRequestCreateResponse({
    PaymentIntent? intent,
  }) {
    final $result = create();
    if (intent != null) {
      $result.intent = intent;
    }
    return $result;
  }
  PaymentRequestCreateResponse._() : super();
  factory PaymentRequestCreateResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PaymentRequestCreateResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PaymentRequestCreateResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOM<PaymentIntent>(1, _omitFieldNames ? '' : 'intent', subBuilder: PaymentIntent.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PaymentRequestCreateResponse clone() => PaymentRequestCreateResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PaymentRequestCreateResponse copyWith(void Function(PaymentRequestCreateResponse) updates) => super.copyWith((message) => updates(message as PaymentRequestCreateResponse)) as PaymentRequestCreateResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRequestCreateResponse create() => PaymentRequestCreateResponse._();
  PaymentRequestCreateResponse createEmptyInstance() => create();
  static $pb.PbList<PaymentRequestCreateResponse> createRepeated() => $pb.PbList<PaymentRequestCreateResponse>();
  @$core.pragma('dart2js:noInline')
  static PaymentRequestCreateResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaymentRequestCreateResponse>(create);
  static PaymentRequestCreateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PaymentIntent get intent => $_getN(0);
  @$pb.TagNumber(1)
  set intent(PaymentIntent v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasIntent() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntent() => clearField(1);
  @$pb.TagNumber(1)
  PaymentIntent ensureIntent() => $_ensure(0);
}

class PaymentRequestListRequest extends $pb.GeneratedMessage {
  factory PaymentRequestListRequest({
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
  PaymentRequestListRequest._() : super();
  factory PaymentRequestListRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PaymentRequestListRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PaymentRequestListRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PaymentRequestListRequest clone() => PaymentRequestListRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PaymentRequestListRequest copyWith(void Function(PaymentRequestListRequest) updates) => super.copyWith((message) => updates(message as PaymentRequestListRequest)) as PaymentRequestListRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRequestListRequest create() => PaymentRequestListRequest._();
  PaymentRequestListRequest createEmptyInstance() => create();
  static $pb.PbList<PaymentRequestListRequest> createRepeated() => $pb.PbList<PaymentRequestListRequest>();
  @$core.pragma('dart2js:noInline')
  static PaymentRequestListRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaymentRequestListRequest>(create);
  static PaymentRequestListRequest? _defaultInstance;

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

class PaymentRequestListResponse extends $pb.GeneratedMessage {
  factory PaymentRequestListResponse({
    $core.Iterable<PaymentIntent>? intents,
  }) {
    final $result = create();
    if (intents != null) {
      $result.intents.addAll(intents);
    }
    return $result;
  }
  PaymentRequestListResponse._() : super();
  factory PaymentRequestListResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PaymentRequestListResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PaymentRequestListResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<PaymentIntent>(1, _omitFieldNames ? '' : 'intents', $pb.PbFieldType.PM, subBuilder: PaymentIntent.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PaymentRequestListResponse clone() => PaymentRequestListResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PaymentRequestListResponse copyWith(void Function(PaymentRequestListResponse) updates) => super.copyWith((message) => updates(message as PaymentRequestListResponse)) as PaymentRequestListResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRequestListResponse create() => PaymentRequestListResponse._();
  PaymentRequestListResponse createEmptyInstance() => create();
  static $pb.PbList<PaymentRequestListResponse> createRepeated() => $pb.PbList<PaymentRequestListResponse>();
  @$core.pragma('dart2js:noInline')
  static PaymentRequestListResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaymentRequestListResponse>(create);
  static PaymentRequestListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<PaymentIntent> get intents => $_getList(0);
}

class PaymentRequestDeclineRequest extends $pb.GeneratedMessage {
  factory PaymentRequestDeclineRequest({
    $core.List<$core.int>? userId,
    $core.String? id,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (id != null) {
      $result.id = id;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  PaymentRequestDeclineRequest._() : super();
  factory PaymentRequestDeclineRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PaymentRequestDeclineRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PaymentRequestDeclineRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PaymentRequestDeclineRequest clone() => PaymentRequestDeclineRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PaymentRequestDeclineRequest copyWith(void Function(PaymentRequestDeclineRequest) updates) => super.copyWith((message) => updates(message as PaymentRequestDeclineRequest)) as PaymentRequestDeclineRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRequestDeclineRequest create() => PaymentRequestDeclineRequest._();
  PaymentRequestDeclineRequest createEmptyInstance() => create();
  static $pb.PbList<PaymentRequestDeclineRequest> createRepeated() => $pb.PbList<PaymentRequestDeclineRequest>();
  @$core.pragma('dart2js:noInline')
  static PaymentRequestDeclineRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaymentRequestDeclineRequest>(create);
  static PaymentRequestDeclineRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => clearField(2);

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

class PaymentRequestDeclineResponse extends $pb.GeneratedMessage {
  factory PaymentRequestDeclineResponse({
    $core.bool? ok,
  }) {
    final $result = create();
    if (ok != null) {
      $result.ok = ok;
    }
    return $result;
  }
  PaymentRequestDeclineResponse._() : super();
  factory PaymentRequestDeclineResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PaymentRequestDeclineResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PaymentRequestDeclineResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PaymentRequestDeclineResponse clone() => PaymentRequestDeclineResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PaymentRequestDeclineResponse copyWith(void Function(PaymentRequestDeclineResponse) updates) => super.copyWith((message) => updates(message as PaymentRequestDeclineResponse)) as PaymentRequestDeclineResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRequestDeclineResponse create() => PaymentRequestDeclineResponse._();
  PaymentRequestDeclineResponse createEmptyInstance() => create();
  static $pb.PbList<PaymentRequestDeclineResponse> createRepeated() => $pb.PbList<PaymentRequestDeclineResponse>();
  @$core.pragma('dart2js:noInline')
  static PaymentRequestDeclineResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaymentRequestDeclineResponse>(create);
  static PaymentRequestDeclineResponse? _defaultInstance;

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
