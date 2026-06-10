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
    $core.bool? isRestore,
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
    if (isRestore != null) {
      $result.isRestore = isRestore;
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
    ..aOB(4, _omitFieldNames ? '' : 'isRestore')
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

class UtxoInfo extends $pb.GeneratedMessage {
  factory UtxoInfo({
    $core.String? txHash,
    $core.int? vout,
    $fixnum.Int64? amount,
  }) {
    final $result = create();
    if (txHash != null) {
      $result.txHash = txHash;
    }
    if (vout != null) {
      $result.vout = vout;
    }
    if (amount != null) {
      $result.amount = amount;
    }
    return $result;
  }
  UtxoInfo._() : super();
  factory UtxoInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UtxoInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UtxoInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txHash')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'vout', $pb.PbFieldType.O3)
    ..aInt64(3, _omitFieldNames ? '' : 'amount')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UtxoInfo clone() => UtxoInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UtxoInfo copyWith(void Function(UtxoInfo) updates) => super.copyWith((message) => updates(message as UtxoInfo)) as UtxoInfo;

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

class RefreshStep1Request extends $pb.GeneratedMessage {
  factory RefreshStep1Request({
    $core.List<$core.int>? userId,
    $core.String? round1Package,
    $fixnum.Int64? thresholdAmount,
    $fixnum.Int64? interval,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (round1Package != null) {
      $result.round1Package = round1Package;
    }
    if (thresholdAmount != null) {
      $result.thresholdAmount = thresholdAmount;
    }
    if (interval != null) {
      $result.interval = interval;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  RefreshStep1Request._() : super();
  factory RefreshStep1Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep1Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RefreshStep1Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..aInt64(4, _omitFieldNames ? '' : 'thresholdAmount')
    ..aInt64(5, _omitFieldNames ? '' : 'interval')
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(7, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep1Request clone() => RefreshStep1Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep1Request copyWith(void Function(RefreshStep1Request) updates) => super.copyWith((message) => updates(message as RefreshStep1Request)) as RefreshStep1Request;

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
  factory RefreshStep1Response({
    $core.Map<$core.String, $core.String>? round1Packages,
    $core.String? policyId,
    $fixnum.Int64? startTime,
  }) {
    final $result = create();
    if (round1Packages != null) {
      $result.round1Packages.addAll(round1Packages);
    }
    if (policyId != null) {
      $result.policyId = policyId;
    }
    if (startTime != null) {
      $result.startTime = startTime;
    }
    return $result;
  }
  RefreshStep1Response._() : super();
  factory RefreshStep1Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep1Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RefreshStep1Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round1Packages', entryClassName: 'RefreshStep1Response.Round1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..aOS(2, _omitFieldNames ? '' : 'policyId')
    ..aInt64(3, _omitFieldNames ? '' : 'startTime')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep1Response clone() => RefreshStep1Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep1Response copyWith(void Function(RefreshStep1Response) updates) => super.copyWith((message) => updates(message as RefreshStep1Response)) as RefreshStep1Response;

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
  factory RefreshStep2Request({
    $core.List<$core.int>? userId,
    $core.String? round1Package,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (round1Package != null) {
      $result.round1Package = round1Package;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  RefreshStep2Request._() : super();
  factory RefreshStep2Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep2Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RefreshStep2Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep2Request clone() => RefreshStep2Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep2Request copyWith(void Function(RefreshStep2Request) updates) => super.copyWith((message) => updates(message as RefreshStep2Request)) as RefreshStep2Request;

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

  /// In DKG Step 2 we sent round1_package again, but strict state management
  /// might not need it if session is locked. We will mirror DKG for consistency.
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
  factory RefreshStep2Response({
    $core.Map<$core.String, $core.String>? allRound1Packages,
  }) {
    final $result = create();
    if (allRound1Packages != null) {
      $result.allRound1Packages.addAll(allRound1Packages);
    }
    return $result;
  }
  RefreshStep2Response._() : super();
  factory RefreshStep2Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep2Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RefreshStep2Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'allRound1Packages', entryClassName: 'RefreshStep2Response.AllRound1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep2Response clone() => RefreshStep2Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep2Response copyWith(void Function(RefreshStep2Response) updates) => super.copyWith((message) => updates(message as RefreshStep2Response)) as RefreshStep2Response;

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
  factory RefreshStep3Request({
    $core.List<$core.int>? userId,
    $core.Map<$core.String, $core.String>? round2PackagesForOthers,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (round2PackagesForOthers != null) {
      $result.round2PackagesForOthers.addAll(round2PackagesForOthers);
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  RefreshStep3Request._() : super();
  factory RefreshStep3Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep3Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RefreshStep3Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'round2PackagesForOthers', entryClassName: 'RefreshStep3Request.Round2PackagesForOthersEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep3Request clone() => RefreshStep3Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep3Request copyWith(void Function(RefreshStep3Request) updates) => super.copyWith((message) => updates(message as RefreshStep3Request)) as RefreshStep3Request;

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
  factory RefreshStep3Response({
    $core.Map<$core.String, $core.String>? round2PackagesForMe,
  }) {
    final $result = create();
    if (round2PackagesForMe != null) {
      $result.round2PackagesForMe.addAll(round2PackagesForMe);
    }
    return $result;
  }
  RefreshStep3Response._() : super();
  factory RefreshStep3Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RefreshStep3Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RefreshStep3Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round2PackagesForMe', entryClassName: 'RefreshStep3Response.Round2PackagesForMeEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RefreshStep3Response clone() => RefreshStep3Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RefreshStep3Response copyWith(void Function(RefreshStep3Response) updates) => super.copyWith((message) => updates(message as RefreshStep3Response)) as RefreshStep3Response;

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
  factory GetPolicyIdRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? txMessage,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (txMessage != null) {
      $result.txMessage = txMessage;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  GetPolicyIdRequest._() : super();
  factory GetPolicyIdRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetPolicyIdRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetPolicyIdRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'txMessage', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetPolicyIdRequest clone() => GetPolicyIdRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetPolicyIdRequest copyWith(void Function(GetPolicyIdRequest) updates) => super.copyWith((message) => updates(message as GetPolicyIdRequest)) as GetPolicyIdRequest;

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
  factory GetPolicyIdResponse({
    $core.String? policyId,
  }) {
    final $result = create();
    if (policyId != null) {
      $result.policyId = policyId;
    }
    return $result;
  }
  GetPolicyIdResponse._() : super();
  factory GetPolicyIdResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetPolicyIdResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetPolicyIdResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'policyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetPolicyIdResponse clone() => GetPolicyIdResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetPolicyIdResponse copyWith(void Function(GetPolicyIdResponse) updates) => super.copyWith((message) => updates(message as GetPolicyIdResponse)) as GetPolicyIdResponse;

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
  factory UpdatePolicyRequest({
    $core.List<$core.int>? userId,
    $core.String? policyId,
    $fixnum.Int64? thresholdSats,
    $fixnum.Int64? intervalSeconds,
    $core.List<$core.int>? frostSignatureR,
    $core.List<$core.int>? frostSignatureZ,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (policyId != null) {
      $result.policyId = policyId;
    }
    if (thresholdSats != null) {
      $result.thresholdSats = thresholdSats;
    }
    if (intervalSeconds != null) {
      $result.intervalSeconds = intervalSeconds;
    }
    if (frostSignatureR != null) {
      $result.frostSignatureR = frostSignatureR;
    }
    if (frostSignatureZ != null) {
      $result.frostSignatureZ = frostSignatureZ;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  UpdatePolicyRequest._() : super();
  factory UpdatePolicyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdatePolicyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdatePolicyRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'policyId')
    ..aInt64(3, _omitFieldNames ? '' : 'thresholdSats')
    ..aInt64(4, _omitFieldNames ? '' : 'intervalSeconds')
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'frostSignatureR', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'frostSignatureZ', $pb.PbFieldType.OY)
    ..aInt64(7, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdatePolicyRequest clone() => UpdatePolicyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdatePolicyRequest copyWith(void Function(UpdatePolicyRequest) updates) => super.copyWith((message) => updates(message as UpdatePolicyRequest)) as UpdatePolicyRequest;

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
  factory UpdatePolicyResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  UpdatePolicyResponse._() : super();
  factory UpdatePolicyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdatePolicyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdatePolicyResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdatePolicyResponse clone() => UpdatePolicyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdatePolicyResponse copyWith(void Function(UpdatePolicyResponse) updates) => super.copyWith((message) => updates(message as UpdatePolicyResponse)) as UpdatePolicyResponse;

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
  factory DeletePolicyRequest({
    $core.List<$core.int>? userId,
    $core.String? policyId,
    $core.List<$core.int>? frostSignatureR,
    $core.List<$core.int>? frostSignatureZ,
    $fixnum.Int64? timestampMs,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (policyId != null) {
      $result.policyId = policyId;
    }
    if (frostSignatureR != null) {
      $result.frostSignatureR = frostSignatureR;
    }
    if (frostSignatureZ != null) {
      $result.frostSignatureZ = frostSignatureZ;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  DeletePolicyRequest._() : super();
  factory DeletePolicyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeletePolicyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeletePolicyRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'policyId')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'frostSignatureR', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'frostSignatureZ', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeletePolicyRequest clone() => DeletePolicyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeletePolicyRequest copyWith(void Function(DeletePolicyRequest) updates) => super.copyWith((message) => updates(message as DeletePolicyRequest)) as DeletePolicyRequest;

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
  factory DeletePolicyResponse({
    $core.bool? success,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  DeletePolicyResponse._() : super();
  factory DeletePolicyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeletePolicyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeletePolicyResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeletePolicyResponse clone() => DeletePolicyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeletePolicyResponse copyWith(void Function(DeletePolicyResponse) updates) => super.copyWith((message) => updates(message as DeletePolicyResponse)) as DeletePolicyResponse;

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
  factory BroadcastTransactionRequest({
    $core.List<$core.int>? userId,
    $core.String? txHex,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (txHex != null) {
      $result.txHex = txHex;
    }
    return $result;
  }
  BroadcastTransactionRequest._() : super();
  factory BroadcastTransactionRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastTransactionRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastTransactionRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'txHex')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastTransactionRequest clone() => BroadcastTransactionRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastTransactionRequest copyWith(void Function(BroadcastTransactionRequest) updates) => super.copyWith((message) => updates(message as BroadcastTransactionRequest)) as BroadcastTransactionRequest;

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
  factory BroadcastTransactionResponse({
    $core.String? txId,
  }) {
    final $result = create();
    if (txId != null) {
      $result.txId = txId;
    }
    return $result;
  }
  BroadcastTransactionResponse._() : super();
  factory BroadcastTransactionResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BroadcastTransactionResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BroadcastTransactionResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BroadcastTransactionResponse clone() => BroadcastTransactionResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BroadcastTransactionResponse copyWith(void Function(BroadcastTransactionResponse) updates) => super.copyWith((message) => updates(message as BroadcastTransactionResponse)) as BroadcastTransactionResponse;

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
  factory FetchHistoryRequest({
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
  FetchHistoryRequest._() : super();
  factory FetchHistoryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchHistoryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FetchHistoryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchHistoryRequest clone() => FetchHistoryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchHistoryRequest copyWith(void Function(FetchHistoryRequest) updates) => super.copyWith((message) => updates(message as FetchHistoryRequest)) as FetchHistoryRequest;

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
  factory FetchHistoryResponse({
    $core.Iterable<UtxoInfo>? utxos,
  }) {
    final $result = create();
    if (utxos != null) {
      $result.utxos.addAll(utxos);
    }
    return $result;
  }
  FetchHistoryResponse._() : super();
  factory FetchHistoryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchHistoryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FetchHistoryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<UtxoInfo>(1, _omitFieldNames ? '' : 'utxos', $pb.PbFieldType.PM, subBuilder: UtxoInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchHistoryResponse clone() => FetchHistoryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchHistoryResponse copyWith(void Function(FetchHistoryResponse) updates) => super.copyWith((message) => updates(message as FetchHistoryResponse)) as FetchHistoryResponse;

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
  factory FetchRecentTransactionsRequest({
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
  FetchRecentTransactionsRequest._() : super();
  factory FetchRecentTransactionsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchRecentTransactionsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FetchRecentTransactionsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsRequest clone() => FetchRecentTransactionsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsRequest copyWith(void Function(FetchRecentTransactionsRequest) updates) => super.copyWith((message) => updates(message as FetchRecentTransactionsRequest)) as FetchRecentTransactionsRequest;

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
  factory FetchRecentTransactionsResponse({
    $core.Iterable<TransactionSummary>? transactions,
  }) {
    final $result = create();
    if (transactions != null) {
      $result.transactions.addAll(transactions);
    }
    return $result;
  }
  FetchRecentTransactionsResponse._() : super();
  factory FetchRecentTransactionsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FetchRecentTransactionsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FetchRecentTransactionsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..pc<TransactionSummary>(1, _omitFieldNames ? '' : 'transactions', $pb.PbFieldType.PM, subBuilder: TransactionSummary.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsResponse clone() => FetchRecentTransactionsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FetchRecentTransactionsResponse copyWith(void Function(FetchRecentTransactionsResponse) updates) => super.copyWith((message) => updates(message as FetchRecentTransactionsResponse)) as FetchRecentTransactionsResponse;

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
  factory TransactionSummary({
    $core.String? txHash,
    $fixnum.Int64? amountSats,
    $fixnum.Int64? timestamp,
    $core.bool? isPending,
  }) {
    final $result = create();
    if (txHash != null) {
      $result.txHash = txHash;
    }
    if (amountSats != null) {
      $result.amountSats = amountSats;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (isPending != null) {
      $result.isPending = isPending;
    }
    return $result;
  }
  TransactionSummary._() : super();
  factory TransactionSummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TransactionSummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TransactionSummary', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txHash')
    ..aInt64(2, _omitFieldNames ? '' : 'amountSats')
    ..aInt64(3, _omitFieldNames ? '' : 'timestamp')
    ..aOB(4, _omitFieldNames ? '' : 'isPending')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TransactionSummary clone() => TransactionSummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TransactionSummary copyWith(void Function(TransactionSummary) updates) => super.copyWith((message) => updates(message as TransactionSummary)) as TransactionSummary;

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
  factory SubscribeToHistoryRequest({
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
  SubscribeToHistoryRequest._() : super();
  factory SubscribeToHistoryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubscribeToHistoryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SubscribeToHistoryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubscribeToHistoryRequest clone() => SubscribeToHistoryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubscribeToHistoryRequest copyWith(void Function(SubscribeToHistoryRequest) updates) => super.copyWith((message) => updates(message as SubscribeToHistoryRequest)) as SubscribeToHistoryRequest;

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
  factory TransactionNotification({
    $core.String? txHash,
    $core.int? height,
    $core.Iterable<UtxoInfo>? addedUtxos,
    $core.Iterable<UtxoInfo>? spentUtxos,
  }) {
    final $result = create();
    if (txHash != null) {
      $result.txHash = txHash;
    }
    if (height != null) {
      $result.height = height;
    }
    if (addedUtxos != null) {
      $result.addedUtxos.addAll(addedUtxos);
    }
    if (spentUtxos != null) {
      $result.spentUtxos.addAll(spentUtxos);
    }
    return $result;
  }
  TransactionNotification._() : super();
  factory TransactionNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TransactionNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TransactionNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txHash')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'height', $pb.PbFieldType.O3)
    ..pc<UtxoInfo>(3, _omitFieldNames ? '' : 'addedUtxos', $pb.PbFieldType.PM, subBuilder: UtxoInfo.create)
    ..pc<UtxoInfo>(4, _omitFieldNames ? '' : 'spentUtxos', $pb.PbFieldType.PM, subBuilder: UtxoInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TransactionNotification clone() => TransactionNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TransactionNotification copyWith(void Function(TransactionNotification) updates) => super.copyWith((message) => updates(message as TransactionNotification)) as TransactionNotification;

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

  /// Using a simple notification that "something changed" or sending the full update?
  /// User said "rely on server for maintaining state and updating it with latest transactions"
  /// Sending the relevant UTXOs involved (newly created ones owned by wallet)
  @$pb.TagNumber(3)
  $core.List<UtxoInfo> get addedUtxos => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<UtxoInfo> get spentUtxos => $_getList(3);
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

class CheckBoardingBalanceRequest extends $pb.GeneratedMessage {
  factory CheckBoardingBalanceRequest({
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
  CheckBoardingBalanceRequest._() : super();
  factory CheckBoardingBalanceRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CheckBoardingBalanceRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CheckBoardingBalanceRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceRequest clone() => CheckBoardingBalanceRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceRequest copyWith(void Function(CheckBoardingBalanceRequest) updates) => super.copyWith((message) => updates(message as CheckBoardingBalanceRequest)) as CheckBoardingBalanceRequest;

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
  factory CheckBoardingBalanceResponse({
    $fixnum.Int64? balance,
    $core.int? utxoCount,
  }) {
    final $result = create();
    if (balance != null) {
      $result.balance = balance;
    }
    if (utxoCount != null) {
      $result.utxoCount = utxoCount;
    }
    return $result;
  }
  CheckBoardingBalanceResponse._() : super();
  factory CheckBoardingBalanceResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CheckBoardingBalanceResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CheckBoardingBalanceResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'balance', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'utxoCount', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceResponse clone() => CheckBoardingBalanceResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CheckBoardingBalanceResponse copyWith(void Function(CheckBoardingBalanceResponse) updates) => super.copyWith((message) => updates(message as CheckBoardingBalanceResponse)) as CheckBoardingBalanceResponse;

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
    $core.String? policyId,
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
    if (policyId != null) {
      $result.policyId = policyId;
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
    ..aOS(6, _omitFieldNames ? '' : 'policyId')
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

  /// Policy ID if a spending policy is triggered (client must provide PIN)
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

class SettleRequest extends $pb.GeneratedMessage {
  factory SettleRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
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
/// eVTXO key generation (resharing). Authenticated (the main key already exists).
/// Topology mirrors DKG: cosigner + hardware deal; the wallet sends an empty
/// round1 (passive receiver). The resulting 2-of-2 key V′ is held by
/// {wallet, cosigner} only and bound to `contract_id`.
/// ---------------------------------------------------------------------------
class EvtxoKeygenStep1Request extends $pb.GeneratedMessage {
  factory EvtxoKeygenStep1Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
    $core.List<$core.int>? contractId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.List<$core.int>? serverPk,
    $core.int? exitDelay,
    $core.List<$core.int>? contractWasm,
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
    if (contractId != null) {
      $result.contractId = contractId;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    if (serverPk != null) {
      $result.serverPk = serverPk;
    }
    if (exitDelay != null) {
      $result.exitDelay = exitDelay;
    }
    if (contractWasm != null) {
      $result.contractWasm = contractWasm;
    }
    return $result;
  }
  EvtxoKeygenStep1Request._() : super();
  factory EvtxoKeygenStep1Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoKeygenStep1Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoKeygenStep1Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'contractId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(6, _omitFieldNames ? '' : 'timestampMs')
    ..a<$core.List<$core.int>>(7, _omitFieldNames ? '' : 'serverPk', $pb.PbFieldType.OY)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'exitDelay', $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'contractWasm', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep1Request clone() => EvtxoKeygenStep1Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep1Request copyWith(void Function(EvtxoKeygenStep1Request) updates) => super.copyWith((message) => updates(message as EvtxoKeygenStep1Request)) as EvtxoKeygenStep1Request;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep1Request create() => EvtxoKeygenStep1Request._();
  EvtxoKeygenStep1Request createEmptyInstance() => create();
  static $pb.PbList<EvtxoKeygenStep1Request> createRepeated() => $pb.PbList<EvtxoKeygenStep1Request>();
  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep1Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoKeygenStep1Request>(create);
  static EvtxoKeygenStep1Request? _defaultInstance;

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
  $core.List<$core.int> get contractId => $_getN(3);
  @$pb.TagNumber(4)
  set contractId($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasContractId() => $_has(3);
  @$pb.TagNumber(4)
  void clearContractId() => clearField(4);

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

  @$pb.TagNumber(7)
  $core.List<$core.int> get serverPk => $_getN(6);
  @$pb.TagNumber(7)
  set serverPk($core.List<$core.int> v) { $_setBytes(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasServerPk() => $_has(6);
  @$pb.TagNumber(7)
  void clearServerPk() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get exitDelay => $_getIZ(7);
  @$pb.TagNumber(8)
  set exitDelay($core.int v) { $_setUnsignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasExitDelay() => $_has(7);
  @$pb.TagNumber(8)
  void clearExitDelay() => clearField(8);

  @$pb.TagNumber(9)
  $core.List<$core.int> get contractWasm => $_getN(8);
  @$pb.TagNumber(9)
  set contractWasm($core.List<$core.int> v) { $_setBytes(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasContractWasm() => $_has(8);
  @$pb.TagNumber(9)
  void clearContractWasm() => clearField(9);
}

class EvtxoKeygenStep1Response extends $pb.GeneratedMessage {
  factory EvtxoKeygenStep1Response({
    $core.Map<$core.String, $core.String>? round1Packages,
    $core.List<$core.int>? evtxoScriptPubkey,
  }) {
    final $result = create();
    if (round1Packages != null) {
      $result.round1Packages.addAll(round1Packages);
    }
    if (evtxoScriptPubkey != null) {
      $result.evtxoScriptPubkey = evtxoScriptPubkey;
    }
    return $result;
  }
  EvtxoKeygenStep1Response._() : super();
  factory EvtxoKeygenStep1Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoKeygenStep1Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoKeygenStep1Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round1Packages', entryClassName: 'EvtxoKeygenStep1Response.Round1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'evtxoScriptPubkey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep1Response clone() => EvtxoKeygenStep1Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep1Response copyWith(void Function(EvtxoKeygenStep1Response) updates) => super.copyWith((message) => updates(message as EvtxoKeygenStep1Response)) as EvtxoKeygenStep1Response;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep1Response create() => EvtxoKeygenStep1Response._();
  EvtxoKeygenStep1Response createEmptyInstance() => create();
  static $pb.PbList<EvtxoKeygenStep1Response> createRepeated() => $pb.PbList<EvtxoKeygenStep1Response>();
  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep1Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoKeygenStep1Response>(create);
  static EvtxoKeygenStep1Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get round1Packages => $_getMap(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get evtxoScriptPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set evtxoScriptPubkey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEvtxoScriptPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearEvtxoScriptPubkey() => clearField(2);
}

class EvtxoKeygenStep2Request extends $pb.GeneratedMessage {
  factory EvtxoKeygenStep2Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
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
    if (round1Package != null) {
      $result.round1Package = round1Package;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  EvtxoKeygenStep2Request._() : super();
  factory EvtxoKeygenStep2Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoKeygenStep2Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoKeygenStep2Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep2Request clone() => EvtxoKeygenStep2Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep2Request copyWith(void Function(EvtxoKeygenStep2Request) updates) => super.copyWith((message) => updates(message as EvtxoKeygenStep2Request)) as EvtxoKeygenStep2Request;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep2Request create() => EvtxoKeygenStep2Request._();
  EvtxoKeygenStep2Request createEmptyInstance() => create();
  static $pb.PbList<EvtxoKeygenStep2Request> createRepeated() => $pb.PbList<EvtxoKeygenStep2Request>();
  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep2Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoKeygenStep2Request>(create);
  static EvtxoKeygenStep2Request? _defaultInstance;

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

class EvtxoKeygenStep2Response extends $pb.GeneratedMessage {
  factory EvtxoKeygenStep2Response({
    $core.Map<$core.String, $core.String>? allRound1Packages,
  }) {
    final $result = create();
    if (allRound1Packages != null) {
      $result.allRound1Packages.addAll(allRound1Packages);
    }
    return $result;
  }
  EvtxoKeygenStep2Response._() : super();
  factory EvtxoKeygenStep2Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoKeygenStep2Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoKeygenStep2Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'allRound1Packages', entryClassName: 'EvtxoKeygenStep2Response.AllRound1PackagesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep2Response clone() => EvtxoKeygenStep2Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep2Response copyWith(void Function(EvtxoKeygenStep2Response) updates) => super.copyWith((message) => updates(message as EvtxoKeygenStep2Response)) as EvtxoKeygenStep2Response;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep2Response create() => EvtxoKeygenStep2Response._();
  EvtxoKeygenStep2Response createEmptyInstance() => create();
  static $pb.PbList<EvtxoKeygenStep2Response> createRepeated() => $pb.PbList<EvtxoKeygenStep2Response>();
  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep2Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoKeygenStep2Response>(create);
  static EvtxoKeygenStep2Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get allRound1Packages => $_getMap(0);
}

class EvtxoKeygenStep3Request extends $pb.GeneratedMessage {
  factory EvtxoKeygenStep3Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.Map<$core.String, $core.String>? round2PackagesForOthers,
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
    if (round2PackagesForOthers != null) {
      $result.round2PackagesForOthers.addAll(round2PackagesForOthers);
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (timestampMs != null) {
      $result.timestampMs = timestampMs;
    }
    return $result;
  }
  EvtxoKeygenStep3Request._() : super();
  factory EvtxoKeygenStep3Request.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoKeygenStep3Request.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoKeygenStep3Request', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'round2PackagesForOthers', entryClassName: 'EvtxoKeygenStep3Request.Round2PackagesForOthersEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep3Request clone() => EvtxoKeygenStep3Request()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep3Request copyWith(void Function(EvtxoKeygenStep3Request) updates) => super.copyWith((message) => updates(message as EvtxoKeygenStep3Request)) as EvtxoKeygenStep3Request;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep3Request create() => EvtxoKeygenStep3Request._();
  EvtxoKeygenStep3Request createEmptyInstance() => create();
  static $pb.PbList<EvtxoKeygenStep3Request> createRepeated() => $pb.PbList<EvtxoKeygenStep3Request>();
  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep3Request getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoKeygenStep3Request>(create);
  static EvtxoKeygenStep3Request? _defaultInstance;

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

class EvtxoKeygenStep3Response extends $pb.GeneratedMessage {
  factory EvtxoKeygenStep3Response({
    $core.Map<$core.String, $core.String>? round2PackagesForMe,
    $core.String? evtxoAddress,
    $core.List<$core.int>? evtxoScriptPubkey,
  }) {
    final $result = create();
    if (round2PackagesForMe != null) {
      $result.round2PackagesForMe.addAll(round2PackagesForMe);
    }
    if (evtxoAddress != null) {
      $result.evtxoAddress = evtxoAddress;
    }
    if (evtxoScriptPubkey != null) {
      $result.evtxoScriptPubkey = evtxoScriptPubkey;
    }
    return $result;
  }
  EvtxoKeygenStep3Response._() : super();
  factory EvtxoKeygenStep3Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvtxoKeygenStep3Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EvtxoKeygenStep3Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round2PackagesForMe', entryClassName: 'EvtxoKeygenStep3Response.Round2PackagesForMeEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('mpc_wallet'))
    ..aOS(2, _omitFieldNames ? '' : 'evtxoAddress')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'evtxoScriptPubkey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep3Response clone() => EvtxoKeygenStep3Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EvtxoKeygenStep3Response copyWith(void Function(EvtxoKeygenStep3Response) updates) => super.copyWith((message) => updates(message as EvtxoKeygenStep3Response)) as EvtxoKeygenStep3Response;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep3Response create() => EvtxoKeygenStep3Response._();
  EvtxoKeygenStep3Response createEmptyInstance() => create();
  static $pb.PbList<EvtxoKeygenStep3Response> createRepeated() => $pb.PbList<EvtxoKeygenStep3Response>();
  @$core.pragma('dart2js:noInline')
  static EvtxoKeygenStep3Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvtxoKeygenStep3Response>(create);
  static EvtxoKeygenStep3Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get round2PackagesForMe => $_getMap(0);

  @$pb.TagNumber(2)
  $core.String get evtxoAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set evtxoAddress($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEvtxoAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearEvtxoAddress() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get evtxoScriptPubkey => $_getN(2);
  @$pb.TagNumber(3)
  set evtxoScriptPubkey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasEvtxoScriptPubkey() => $_has(2);
  @$pb.TagNumber(3)
  void clearEvtxoScriptPubkey() => clearField(3);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
