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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'mpc_wallet.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'mpc_wallet.pbenum.dart';

class DKGStep1Request extends $pb.GeneratedMessage {
  factory DKGStep1Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
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
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
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
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

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
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
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
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
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
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

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
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        round2PackagesForOthers,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
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
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
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
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

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
    $core.List<$core.int>? userId,
    $core.List<$core.int>? hidingCommitment,
    $core.List<$core.int>? bindingCommitment,
    $core.List<$core.int>? messageToSign,
    $core.List<$core.int>? signature,
    $core.List<$core.int>? fullTransaction,
    $fixnum.Int64? timestampMs,
    $core.bool? scriptPathSpend,
    $core.List<$core.int>? claimedShare,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (hidingCommitment != null) result.hidingCommitment = hidingCommitment;
    if (bindingCommitment != null) result.bindingCommitment = bindingCommitment;
    if (messageToSign != null) result.messageToSign = messageToSign;
    if (signature != null) result.signature = signature;
    if (fullTransaction != null) result.fullTransaction = fullTransaction;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (scriptPathSpend != null) result.scriptPathSpend = scriptPathSpend;
    if (claimedShare != null) result.claimedShare = claimedShare;
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
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'hidingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'bindingCommitment', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'messageToSign', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'fullTransaction', $pb.PbFieldType.OY)
    ..aInt64(7, _omitFieldNames ? '' : 'timestampMs')
    ..aOB(8, _omitFieldNames ? '' : 'scriptPathSpend')
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'claimedShare', $pb.PbFieldType.OY)
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
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get hidingCommitment => $_getN(1);
  @$pb.TagNumber(2)
  set hidingCommitment($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHidingCommitment() => $_has(1);
  @$pb.TagNumber(2)
  void clearHidingCommitment() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get bindingCommitment => $_getN(2);
  @$pb.TagNumber(3)
  set bindingCommitment($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBindingCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearBindingCommitment() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get messageToSign => $_getN(3);
  @$pb.TagNumber(4)
  set messageToSign($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMessageToSign() => $_has(3);
  @$pb.TagNumber(4)
  void clearMessageToSign() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get signature => $_getN(4);
  @$pb.TagNumber(5)
  set signature($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignature() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get fullTransaction => $_getN(5);
  @$pb.TagNumber(6)
  set fullTransaction($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFullTransaction() => $_has(5);
  @$pb.TagNumber(6)
  void clearFullTransaction() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestampMs => $_getI64(6);
  @$pb.TagNumber(7)
  set timestampMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimestampMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestampMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get scriptPathSpend => $_getBF(7);
  @$pb.TagNumber(8)
  set scriptPathSpend($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasScriptPathSpend() => $_has(7);
  @$pb.TagNumber(8)
  void clearScriptPathSpend() => $_clearField(8);

  /// For a contract eVTXO spend: user_id routes to the contract actor (GroupID=V′),
  /// and claimed_share is the spending recipient's own verifying share (the cosigner
  /// authenticates it via auth_check_group + selects recipient_shares[claimed_share]).
  /// Empty for a normal wallet (claimed share = user_id).
  @$pb.TagNumber(9)
  $core.List<$core.int> get claimedShare => $_getN(8);
  @$pb.TagNumber(9)
  set claimedShare($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasClaimedShare() => $_has(8);
  @$pb.TagNumber(9)
  void clearClaimedShare() => $_clearField(9);
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
    $core.int? usedKeyIndex,
  }) {
    final result = create();
    if (commitments != null) result.commitments.addEntries(commitments);
    if (messageToSign != null) result.messageToSign = messageToSign;
    if (usedKeyIndex != null) result.usedKeyIndex = usedKeyIndex;
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
    ..aI(3, _omitFieldNames ? '' : 'usedKeyIndex')
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

  @$pb.TagNumber(3)
  $core.int get usedKeyIndex => $_getIZ(2);
  @$pb.TagNumber(3)
  set usedKeyIndex($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsedKeyIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsedKeyIndex() => $_clearField(3);
}

class SignStep2Request extends $pb.GeneratedMessage {
  factory SignStep2Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signatureShare,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.List<$core.int>? claimedShare,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signatureShare != null) result.signatureShare = signatureShare;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (claimedShare != null) result.claimedShare = claimedShare;
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
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signatureShare', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'claimedShare', $pb.PbFieldType.OY)
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
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signatureShare => $_getN(1);
  @$pb.TagNumber(3)
  set signatureShare($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(3)
  $core.bool hasSignatureShare() => $_has(1);
  @$pb.TagNumber(3)
  void clearSignatureShare() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(3);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(3);
  @$pb.TagNumber(5)
  void clearTimestampMs() => $_clearField(5);

  /// Contract eVTXO spend: the recipient's own verifying share (see SignStep1Request).
  @$pb.TagNumber(6)
  $core.List<$core.int> get claimedShare => $_getN(4);
  @$pb.TagNumber(6)
  set claimedShare($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(6)
  $core.bool hasClaimedShare() => $_has(4);
  @$pb.TagNumber(6)
  void clearClaimedShare() => $_clearField(6);
}

class UtxoInfo extends $pb.GeneratedMessage {
  factory UtxoInfo({
    $core.String? txHash,
    $core.int? vout,
    $fixnum.Int64? amount,
  }) {
    final result = create();
    if (txHash != null) result.txHash = txHash;
    if (vout != null) result.vout = vout;
    if (amount != null) result.amount = amount;
    return result;
  }

  UtxoInfo._();

  factory UtxoInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UtxoInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UtxoInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txHash')
    ..aI(2, _omitFieldNames ? '' : 'vout')
    ..aInt64(3, _omitFieldNames ? '' : 'amount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UtxoInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UtxoInfo copyWith(void Function(UtxoInfo) updates) =>
      super.copyWith((message) => updates(message as UtxoInfo)) as UtxoInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UtxoInfo create() => UtxoInfo._();
  @$core.override
  UtxoInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UtxoInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UtxoInfo>(create);
  static UtxoInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txHash => $_getSZ(0);
  @$pb.TagNumber(1)
  set txHash($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTxHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxHash() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get vout => $_getIZ(1);
  @$pb.TagNumber(2)
  set vout($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVout() => $_has(1);
  @$pb.TagNumber(2)
  void clearVout() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);
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

class BroadcastTransactionRequest extends $pb.GeneratedMessage {
  factory BroadcastTransactionRequest({
    $core.List<$core.int>? userId,
    $core.String? txHex,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (txHex != null) result.txHex = txHex;
    return result;
  }

  BroadcastTransactionRequest._();

  factory BroadcastTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BroadcastTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BroadcastTransactionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'txHex')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BroadcastTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BroadcastTransactionRequest copyWith(
          void Function(BroadcastTransactionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as BroadcastTransactionRequest))
          as BroadcastTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionRequest create() =>
      BroadcastTransactionRequest._();
  @$core.override
  BroadcastTransactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BroadcastTransactionRequest>(create);
  static BroadcastTransactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get txHex => $_getSZ(1);
  @$pb.TagNumber(2)
  set txHex($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTxHex() => $_has(1);
  @$pb.TagNumber(2)
  void clearTxHex() => $_clearField(2);
}

class BroadcastTransactionResponse extends $pb.GeneratedMessage {
  factory BroadcastTransactionResponse({
    $core.String? txId,
  }) {
    final result = create();
    if (txId != null) result.txId = txId;
    return result;
  }

  BroadcastTransactionResponse._();

  factory BroadcastTransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BroadcastTransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BroadcastTransactionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BroadcastTransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BroadcastTransactionResponse copyWith(
          void Function(BroadcastTransactionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as BroadcastTransactionResponse))
          as BroadcastTransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionResponse create() =>
      BroadcastTransactionResponse._();
  @$core.override
  BroadcastTransactionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BroadcastTransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BroadcastTransactionResponse>(create);
  static BroadcastTransactionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txId => $_getSZ(0);
  @$pb.TagNumber(1)
  set txId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTxId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxId() => $_clearField(1);
}

class FetchHistoryRequest extends $pb.GeneratedMessage {
  factory FetchHistoryRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  FetchHistoryRequest._();

  factory FetchHistoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FetchHistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchHistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchHistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchHistoryRequest copyWith(void Function(FetchHistoryRequest) updates) =>
      super.copyWith((message) => updates(message as FetchHistoryRequest))
          as FetchHistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FetchHistoryRequest create() => FetchHistoryRequest._();
  @$core.override
  FetchHistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FetchHistoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FetchHistoryRequest>(create);
  static FetchHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class FetchHistoryResponse extends $pb.GeneratedMessage {
  factory FetchHistoryResponse({
    $core.Iterable<UtxoInfo>? utxos,
  }) {
    final result = create();
    if (utxos != null) result.utxos.addAll(utxos);
    return result;
  }

  FetchHistoryResponse._();

  factory FetchHistoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FetchHistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchHistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..pPM<UtxoInfo>(1, _omitFieldNames ? '' : 'utxos',
        subBuilder: UtxoInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchHistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchHistoryResponse copyWith(void Function(FetchHistoryResponse) updates) =>
      super.copyWith((message) => updates(message as FetchHistoryResponse))
          as FetchHistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FetchHistoryResponse create() => FetchHistoryResponse._();
  @$core.override
  FetchHistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FetchHistoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FetchHistoryResponse>(create);
  static FetchHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<UtxoInfo> get utxos => $_getList(0);
}

class FetchRecentTransactionsRequest extends $pb.GeneratedMessage {
  factory FetchRecentTransactionsRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  FetchRecentTransactionsRequest._();

  factory FetchRecentTransactionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FetchRecentTransactionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchRecentTransactionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRecentTransactionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRecentTransactionsRequest copyWith(
          void Function(FetchRecentTransactionsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as FetchRecentTransactionsRequest))
          as FetchRecentTransactionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsRequest create() =>
      FetchRecentTransactionsRequest._();
  @$core.override
  FetchRecentTransactionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FetchRecentTransactionsRequest>(create);
  static FetchRecentTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class FetchRecentTransactionsResponse extends $pb.GeneratedMessage {
  factory FetchRecentTransactionsResponse({
    $core.Iterable<TransactionSummary>? transactions,
  }) {
    final result = create();
    if (transactions != null) result.transactions.addAll(transactions);
    return result;
  }

  FetchRecentTransactionsResponse._();

  factory FetchRecentTransactionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FetchRecentTransactionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchRecentTransactionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..pPM<TransactionSummary>(1, _omitFieldNames ? '' : 'transactions',
        subBuilder: TransactionSummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRecentTransactionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRecentTransactionsResponse copyWith(
          void Function(FetchRecentTransactionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as FetchRecentTransactionsResponse))
          as FetchRecentTransactionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsResponse create() =>
      FetchRecentTransactionsResponse._();
  @$core.override
  FetchRecentTransactionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FetchRecentTransactionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FetchRecentTransactionsResponse>(
          create);
  static FetchRecentTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TransactionSummary> get transactions => $_getList(0);
}

class TransactionSummary extends $pb.GeneratedMessage {
  factory TransactionSummary({
    $core.String? txHash,
    $fixnum.Int64? amountSats,
    $fixnum.Int64? timestamp,
    $core.bool? isPending,
  }) {
    final result = create();
    if (txHash != null) result.txHash = txHash;
    if (amountSats != null) result.amountSats = amountSats;
    if (timestamp != null) result.timestamp = timestamp;
    if (isPending != null) result.isPending = isPending;
    return result;
  }

  TransactionSummary._();

  factory TransactionSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransactionSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txHash')
    ..aInt64(2, _omitFieldNames ? '' : 'amountSats')
    ..aInt64(3, _omitFieldNames ? '' : 'timestamp')
    ..aOB(4, _omitFieldNames ? '' : 'isPending')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionSummary copyWith(void Function(TransactionSummary) updates) =>
      super.copyWith((message) => updates(message as TransactionSummary))
          as TransactionSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransactionSummary create() => TransactionSummary._();
  @$core.override
  TransactionSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransactionSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionSummary>(create);
  static TransactionSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txHash => $_getSZ(0);
  @$pb.TagNumber(1)
  set txHash($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTxHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxHash() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amountSats => $_getI64(1);
  @$pb.TagNumber(2)
  set amountSats($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAmountSats() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmountSats() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestamp => $_getI64(2);
  @$pb.TagNumber(3)
  set timestamp($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestamp() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isPending => $_getBF(3);
  @$pb.TagNumber(4)
  set isPending($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsPending() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsPending() => $_clearField(4);
}

class SubscribeToHistoryRequest extends $pb.GeneratedMessage {
  factory SubscribeToHistoryRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  SubscribeToHistoryRequest._();

  factory SubscribeToHistoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubscribeToHistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscribeToHistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeToHistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeToHistoryRequest copyWith(
          void Function(SubscribeToHistoryRequest) updates) =>
      super.copyWith((message) => updates(message as SubscribeToHistoryRequest))
          as SubscribeToHistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeToHistoryRequest create() => SubscribeToHistoryRequest._();
  @$core.override
  SubscribeToHistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubscribeToHistoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubscribeToHistoryRequest>(create);
  static SubscribeToHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class TransactionNotification extends $pb.GeneratedMessage {
  factory TransactionNotification({
    $core.String? txHash,
    $core.int? height,
    $core.Iterable<UtxoInfo>? addedUtxos,
    $core.Iterable<UtxoInfo>? spentUtxos,
  }) {
    final result = create();
    if (txHash != null) result.txHash = txHash;
    if (height != null) result.height = height;
    if (addedUtxos != null) result.addedUtxos.addAll(addedUtxos);
    if (spentUtxos != null) result.spentUtxos.addAll(spentUtxos);
    return result;
  }

  TransactionNotification._();

  factory TransactionNotification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransactionNotification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionNotification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txHash')
    ..aI(2, _omitFieldNames ? '' : 'height')
    ..pPM<UtxoInfo>(3, _omitFieldNames ? '' : 'addedUtxos',
        subBuilder: UtxoInfo.create)
    ..pPM<UtxoInfo>(4, _omitFieldNames ? '' : 'spentUtxos',
        subBuilder: UtxoInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionNotification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionNotification copyWith(
          void Function(TransactionNotification) updates) =>
      super.copyWith((message) => updates(message as TransactionNotification))
          as TransactionNotification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransactionNotification create() => TransactionNotification._();
  @$core.override
  TransactionNotification createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransactionNotification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionNotification>(create);
  static TransactionNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txHash => $_getSZ(0);
  @$pb.TagNumber(1)
  set txHash($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTxHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxHash() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);

  /// Using a simple notification that "something changed" or sending the full update?
  /// User said "rely on server for maintaining state and updating it with latest transactions"
  /// Sending the relevant UTXOs involved (newly created ones owned by wallet)
  @$pb.TagNumber(3)
  $pb.PbList<UtxoInfo> get addedUtxos => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<UtxoInfo> get spentUtxos => $_getList(3);
}

class GetArkInfoRequest extends $pb.GeneratedMessage {
  factory GetArkInfoRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  GetArkInfoRequest._();

  factory GetArkInfoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetArkInfoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetArkInfoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkInfoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkInfoRequest copyWith(void Function(GetArkInfoRequest) updates) =>
      super.copyWith((message) => updates(message as GetArkInfoRequest))
          as GetArkInfoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetArkInfoRequest create() => GetArkInfoRequest._();
  @$core.override
  GetArkInfoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetArkInfoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetArkInfoRequest>(create);
  static GetArkInfoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
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
    final result = create();
    if (signerPubkey != null) result.signerPubkey = signerPubkey;
    if (forfeitPubkey != null) result.forfeitPubkey = forfeitPubkey;
    if (network != null) result.network = network;
    if (sessionDuration != null) result.sessionDuration = sessionDuration;
    if (unilateralExitDelay != null)
      result.unilateralExitDelay = unilateralExitDelay;
    if (boardingExitDelay != null) result.boardingExitDelay = boardingExitDelay;
    if (vtxoMinAmount != null) result.vtxoMinAmount = vtxoMinAmount;
    if (dust != null) result.dust = dust;
    if (checkpointTapscript != null)
      result.checkpointTapscript = checkpointTapscript;
    if (forfeitAddress != null) result.forfeitAddress = forfeitAddress;
    if (autoSettleSafetyMarginSecs != null)
      result.autoSettleSafetyMarginSecs = autoSettleSafetyMarginSecs;
    return result;
  }

  GetArkInfoResponse._();

  factory GetArkInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetArkInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetArkInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
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
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkInfoResponse copyWith(void Function(GetArkInfoResponse) updates) =>
      super.copyWith((message) => updates(message as GetArkInfoResponse))
          as GetArkInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetArkInfoResponse create() => GetArkInfoResponse._();
  @$core.override
  GetArkInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetArkInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetArkInfoResponse>(create);
  static GetArkInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get signerPubkey => $_getSZ(0);
  @$pb.TagNumber(1)
  set signerPubkey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignerPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignerPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get forfeitPubkey => $_getSZ(1);
  @$pb.TagNumber(2)
  set forfeitPubkey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForfeitPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearForfeitPubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get network => $_getSZ(2);
  @$pb.TagNumber(3)
  set network($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNetwork() => $_has(2);
  @$pb.TagNumber(3)
  void clearNetwork() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sessionDuration => $_getI64(3);
  @$pb.TagNumber(4)
  set sessionDuration($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionDuration() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionDuration() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get unilateralExitDelay => $_getI64(4);
  @$pb.TagNumber(5)
  set unilateralExitDelay($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUnilateralExitDelay() => $_has(4);
  @$pb.TagNumber(5)
  void clearUnilateralExitDelay() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get boardingExitDelay => $_getI64(5);
  @$pb.TagNumber(6)
  set boardingExitDelay($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBoardingExitDelay() => $_has(5);
  @$pb.TagNumber(6)
  void clearBoardingExitDelay() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get vtxoMinAmount => $_getI64(6);
  @$pb.TagNumber(7)
  set vtxoMinAmount($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasVtxoMinAmount() => $_has(6);
  @$pb.TagNumber(7)
  void clearVtxoMinAmount() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get dust => $_getI64(7);
  @$pb.TagNumber(8)
  set dust($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDust() => $_has(7);
  @$pb.TagNumber(8)
  void clearDust() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get checkpointTapscript => $_getSZ(8);
  @$pb.TagNumber(9)
  set checkpointTapscript($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCheckpointTapscript() => $_has(8);
  @$pb.TagNumber(9)
  void clearCheckpointTapscript() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get forfeitAddress => $_getSZ(9);
  @$pb.TagNumber(10)
  set forfeitAddress($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasForfeitAddress() => $_has(9);
  @$pb.TagNumber(10)
  void clearForfeitAddress() => $_clearField(10);

  /// Seconds before a VTXO's expiry that the cosigner auto-settles a stored
  /// delegate. Lets the client show an accurate "refreshes around" time.
  @$pb.TagNumber(11)
  $fixnum.Int64 get autoSettleSafetyMarginSecs => $_getI64(10);
  @$pb.TagNumber(11)
  set autoSettleSafetyMarginSecs($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAutoSettleSafetyMarginSecs() => $_has(10);
  @$pb.TagNumber(11)
  void clearAutoSettleSafetyMarginSecs() => $_clearField(11);
}

class GetArkAddressRequest extends $pb.GeneratedMessage {
  factory GetArkAddressRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  GetArkAddressRequest._();

  factory GetArkAddressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetArkAddressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetArkAddressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkAddressRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkAddressRequest copyWith(void Function(GetArkAddressRequest) updates) =>
      super.copyWith((message) => updates(message as GetArkAddressRequest))
          as GetArkAddressRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetArkAddressRequest create() => GetArkAddressRequest._();
  @$core.override
  GetArkAddressRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetArkAddressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetArkAddressRequest>(create);
  static GetArkAddressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class GetArkAddressResponse extends $pb.GeneratedMessage {
  factory GetArkAddressResponse({
    $core.String? arkAddress,
  }) {
    final result = create();
    if (arkAddress != null) result.arkAddress = arkAddress;
    return result;
  }

  GetArkAddressResponse._();

  factory GetArkAddressResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetArkAddressResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetArkAddressResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'arkAddress')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkAddressResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetArkAddressResponse copyWith(
          void Function(GetArkAddressResponse) updates) =>
      super.copyWith((message) => updates(message as GetArkAddressResponse))
          as GetArkAddressResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetArkAddressResponse create() => GetArkAddressResponse._();
  @$core.override
  GetArkAddressResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetArkAddressResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetArkAddressResponse>(create);
  static GetArkAddressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get arkAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set arkAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasArkAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearArkAddress() => $_clearField(1);
}

class GetBoardingAddressRequest extends $pb.GeneratedMessage {
  factory GetBoardingAddressRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  GetBoardingAddressRequest._();

  factory GetBoardingAddressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetBoardingAddressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetBoardingAddressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBoardingAddressRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBoardingAddressRequest copyWith(
          void Function(GetBoardingAddressRequest) updates) =>
      super.copyWith((message) => updates(message as GetBoardingAddressRequest))
          as GetBoardingAddressRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressRequest create() => GetBoardingAddressRequest._();
  @$core.override
  GetBoardingAddressRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetBoardingAddressRequest>(create);
  static GetBoardingAddressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class GetBoardingAddressResponse extends $pb.GeneratedMessage {
  factory GetBoardingAddressResponse({
    $core.String? boardingAddress,
  }) {
    final result = create();
    if (boardingAddress != null) result.boardingAddress = boardingAddress;
    return result;
  }

  GetBoardingAddressResponse._();

  factory GetBoardingAddressResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetBoardingAddressResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetBoardingAddressResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'boardingAddress')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBoardingAddressResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBoardingAddressResponse copyWith(
          void Function(GetBoardingAddressResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetBoardingAddressResponse))
          as GetBoardingAddressResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressResponse create() => GetBoardingAddressResponse._();
  @$core.override
  GetBoardingAddressResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetBoardingAddressResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetBoardingAddressResponse>(create);
  static GetBoardingAddressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get boardingAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set boardingAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBoardingAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearBoardingAddress() => $_clearField(1);
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
    final result = create();
    if (txid != null) result.txid = txid;
    if (vout != null) result.vout = vout;
    if (amount != null) result.amount = amount;
    if (createdAt != null) result.createdAt = createdAt;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (status != null) result.status = status;
    if (isPreconfirmed != null) result.isPreconfirmed = isPreconfirmed;
    if (exitDelay != null) result.exitDelay = exitDelay;
    if (script != null) result.script = script;
    return result;
  }

  VtxoInfo._();

  factory VtxoInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory VtxoInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VtxoInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txid')
    ..aI(2, _omitFieldNames ? '' : 'vout', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'amount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(4, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(5, _omitFieldNames ? '' : 'expiresAt')
    ..aOS(6, _omitFieldNames ? '' : 'status')
    ..aOB(7, _omitFieldNames ? '' : 'isPreconfirmed')
    ..aI(8, _omitFieldNames ? '' : 'exitDelay', fieldType: $pb.PbFieldType.OU3)
    ..aOS(9, _omitFieldNames ? '' : 'script')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VtxoInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VtxoInfo copyWith(void Function(VtxoInfo) updates) =>
      super.copyWith((message) => updates(message as VtxoInfo)) as VtxoInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VtxoInfo create() => VtxoInfo._();
  @$core.override
  VtxoInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static VtxoInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<VtxoInfo>(create);
  static VtxoInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txid => $_getSZ(0);
  @$pb.TagNumber(1)
  set txid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTxid() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get vout => $_getIZ(1);
  @$pb.TagNumber(2)
  set vout($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVout() => $_has(1);
  @$pb.TagNumber(2)
  void clearVout() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get createdAt => $_getI64(3);
  @$pb.TagNumber(4)
  set createdAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreatedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreatedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get expiresAt => $_getI64(4);
  @$pb.TagNumber(5)
  set expiresAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExpiresAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearExpiresAt() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get status => $_getSZ(5);
  @$pb.TagNumber(6)
  set status($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isPreconfirmed => $_getBF(6);
  @$pb.TagNumber(7)
  set isPreconfirmed($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsPreconfirmed() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsPreconfirmed() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get exitDelay => $_getIZ(7);
  @$pb.TagNumber(8)
  set exitDelay($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExitDelay() => $_has(7);
  @$pb.TagNumber(8)
  void clearExitDelay() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get script => $_getSZ(8);
  @$pb.TagNumber(9)
  set script($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasScript() => $_has(8);
  @$pb.TagNumber(9)
  void clearScript() => $_clearField(9);
}

class ListVtxosRequest extends $pb.GeneratedMessage {
  factory ListVtxosRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  ListVtxosRequest._();

  factory ListVtxosRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListVtxosRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListVtxosRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVtxosRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVtxosRequest copyWith(void Function(ListVtxosRequest) updates) =>
      super.copyWith((message) => updates(message as ListVtxosRequest))
          as ListVtxosRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListVtxosRequest create() => ListVtxosRequest._();
  @$core.override
  ListVtxosRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListVtxosRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListVtxosRequest>(create);
  static ListVtxosRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class ListVtxosResponse extends $pb.GeneratedMessage {
  factory ListVtxosResponse({
    $core.Iterable<VtxoInfo>? vtxos,
    $fixnum.Int64? totalBalance,
    $core.bool? hasActiveDelegate,
  }) {
    final result = create();
    if (vtxos != null) result.vtxos.addAll(vtxos);
    if (totalBalance != null) result.totalBalance = totalBalance;
    if (hasActiveDelegate != null) result.hasActiveDelegate = hasActiveDelegate;
    return result;
  }

  ListVtxosResponse._();

  factory ListVtxosResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListVtxosResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListVtxosResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..pPM<VtxoInfo>(1, _omitFieldNames ? '' : 'vtxos',
        subBuilder: VtxoInfo.create)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'totalBalance', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(3, _omitFieldNames ? '' : 'hasActiveDelegate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVtxosResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVtxosResponse copyWith(void Function(ListVtxosResponse) updates) =>
      super.copyWith((message) => updates(message as ListVtxosResponse))
          as ListVtxosResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListVtxosResponse create() => ListVtxosResponse._();
  @$core.override
  ListVtxosResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListVtxosResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListVtxosResponse>(create);
  static ListVtxosResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<VtxoInfo> get vtxos => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalBalance => $_getI64(1);
  @$pb.TagNumber(2)
  set totalBalance($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalBalance() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalBalance() => $_clearField(2);

  /// True if the cosigner has a stored, signed delegate intent for this user.
  /// Clients use this to detect "VTXOs exist but no delegate" (e.g. after
  /// cosigner-runtime restart) and re-delegate.
  @$pb.TagNumber(3)
  $core.bool get hasActiveDelegate => $_getBF(2);
  @$pb.TagNumber(3)
  set hasActiveDelegate($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHasActiveDelegate() => $_has(2);
  @$pb.TagNumber(3)
  void clearHasActiveDelegate() => $_clearField(3);
}

class CheckBoardingBalanceRequest extends $pb.GeneratedMessage {
  factory CheckBoardingBalanceRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  CheckBoardingBalanceRequest._();

  factory CheckBoardingBalanceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckBoardingBalanceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckBoardingBalanceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckBoardingBalanceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckBoardingBalanceRequest copyWith(
          void Function(CheckBoardingBalanceRequest) updates) =>
      super.copyWith(
              (message) => updates(message as CheckBoardingBalanceRequest))
          as CheckBoardingBalanceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceRequest create() =>
      CheckBoardingBalanceRequest._();
  @$core.override
  CheckBoardingBalanceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckBoardingBalanceRequest>(create);
  static CheckBoardingBalanceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class CheckBoardingBalanceResponse extends $pb.GeneratedMessage {
  factory CheckBoardingBalanceResponse({
    $fixnum.Int64? balance,
    $core.int? utxoCount,
  }) {
    final result = create();
    if (balance != null) result.balance = balance;
    if (utxoCount != null) result.utxoCount = utxoCount;
    return result;
  }

  CheckBoardingBalanceResponse._();

  factory CheckBoardingBalanceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckBoardingBalanceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckBoardingBalanceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'balance', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(2, _omitFieldNames ? '' : 'utxoCount', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckBoardingBalanceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckBoardingBalanceResponse copyWith(
          void Function(CheckBoardingBalanceResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CheckBoardingBalanceResponse))
          as CheckBoardingBalanceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceResponse create() =>
      CheckBoardingBalanceResponse._();
  @$core.override
  CheckBoardingBalanceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckBoardingBalanceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckBoardingBalanceResponse>(create);
  static CheckBoardingBalanceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get balance => $_getI64(0);
  @$pb.TagNumber(1)
  set balance($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBalance() => $_has(0);
  @$pb.TagNumber(1)
  void clearBalance() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get utxoCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set utxoCount($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUtxoCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearUtxoCount() => $_clearField(2);
}

class ArkTransactionSummary extends $pb.GeneratedMessage {
  factory ArkTransactionSummary({
    $core.String? txType,
    $fixnum.Int64? amountSats,
    $core.String? txid,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (txType != null) result.txType = txType;
    if (amountSats != null) result.amountSats = amountSats;
    if (txid != null) result.txid = txid;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  ArkTransactionSummary._();

  factory ArkTransactionSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ArkTransactionSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArkTransactionSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'txType')
    ..aInt64(2, _omitFieldNames ? '' : 'amountSats')
    ..aOS(3, _omitFieldNames ? '' : 'txid')
    ..aInt64(4, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArkTransactionSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArkTransactionSummary copyWith(
          void Function(ArkTransactionSummary) updates) =>
      super.copyWith((message) => updates(message as ArkTransactionSummary))
          as ArkTransactionSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ArkTransactionSummary create() => ArkTransactionSummary._();
  @$core.override
  ArkTransactionSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ArkTransactionSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArkTransactionSummary>(create);
  static ArkTransactionSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get txType => $_getSZ(0);
  @$pb.TagNumber(1)
  set txType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTxType() => $_has(0);
  @$pb.TagNumber(1)
  void clearTxType() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amountSats => $_getI64(1);
  @$pb.TagNumber(2)
  set amountSats($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAmountSats() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmountSats() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get txid => $_getSZ(2);
  @$pb.TagNumber(3)
  set txid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTxid() => $_has(2);
  @$pb.TagNumber(3)
  void clearTxid() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestamp => $_getI64(3);
  @$pb.TagNumber(4)
  set timestamp($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTimestamp() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestamp() => $_clearField(4);
}

class ListArkTransactionsRequest extends $pb.GeneratedMessage {
  factory ListArkTransactionsRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  ListArkTransactionsRequest._();

  factory ListArkTransactionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListArkTransactionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListArkTransactionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListArkTransactionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListArkTransactionsRequest copyWith(
          void Function(ListArkTransactionsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ListArkTransactionsRequest))
          as ListArkTransactionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsRequest create() => ListArkTransactionsRequest._();
  @$core.override
  ListArkTransactionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListArkTransactionsRequest>(create);
  static ListArkTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);
}

class ListArkTransactionsResponse extends $pb.GeneratedMessage {
  factory ListArkTransactionsResponse({
    $core.Iterable<ArkTransactionSummary>? transactions,
  }) {
    final result = create();
    if (transactions != null) result.transactions.addAll(transactions);
    return result;
  }

  ListArkTransactionsResponse._();

  factory ListArkTransactionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListArkTransactionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListArkTransactionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..pPM<ArkTransactionSummary>(1, _omitFieldNames ? '' : 'transactions',
        subBuilder: ArkTransactionSummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListArkTransactionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListArkTransactionsResponse copyWith(
          void Function(ListArkTransactionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ListArkTransactionsResponse))
          as ListArkTransactionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsResponse create() =>
      ListArkTransactionsResponse._();
  @$core.override
  ListArkTransactionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListArkTransactionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListArkTransactionsResponse>(create);
  static ListArkTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ArkTransactionSummary> get transactions => $_getList(0);
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
    final result = create();
    if (userId != null) result.userId = userId;
    if (recipientArkAddress != null)
      result.recipientArkAddress = recipientArkAddress;
    if (amount != null) result.amount = amount;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (signedMessages != null) result.signedMessages.addAll(signedMessages);
    return result;
  }

  SendVtxoRequest._();

  factory SendVtxoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendVtxoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendVtxoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'recipientArkAddress')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'amount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendVtxoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendVtxoRequest copyWith(void Function(SendVtxoRequest) updates) =>
      super.copyWith((message) => updates(message as SendVtxoRequest))
          as SendVtxoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendVtxoRequest create() => SendVtxoRequest._();
  @$core.override
  SendVtxoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendVtxoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendVtxoRequest>(create);
  static SendVtxoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get recipientArkAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set recipientArkAddress($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRecipientArkAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearRecipientArkAddress() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestampMs() => $_clearField(5);

  /// FROST signatures for previously requested sighashes (phase 2)
  @$pb.TagNumber(6)
  $pb.PbList<$core.List<$core.int>> get signedMessages => $_getList(5);
}

class SendVtxoResponse extends $pb.GeneratedMessage {
  factory SendVtxoResponse({
    SendVtxoResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? arkTxid,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (messagesToSign != null) result.messagesToSign.addAll(messagesToSign);
    if (scriptPathSpend != null) result.scriptPathSpend = scriptPathSpend;
    if (arkTxid != null) result.arkTxid = arkTxid;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  SendVtxoResponse._();

  factory SendVtxoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendVtxoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendVtxoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aE<SendVtxoResponse_Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: SendVtxoResponse_Status.values)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, _omitFieldNames ? '' : 'scriptPathSpend')
    ..aOS(4, _omitFieldNames ? '' : 'arkTxid')
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendVtxoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendVtxoResponse copyWith(void Function(SendVtxoResponse) updates) =>
      super.copyWith((message) => updates(message as SendVtxoResponse))
          as SendVtxoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendVtxoResponse create() => SendVtxoResponse._();
  @$core.override
  SendVtxoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendVtxoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendVtxoResponse>(create);
  static SendVtxoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SendVtxoResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(SendVtxoResponse_Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  /// Sighashes that need FROST signing (when SIGNING_REQUIRED)
  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get messagesToSign => $_getList(1);

  /// Always true for send (script-path spend, no taproot tweak)
  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => $_clearField(3);

  /// Ark txid when SETTLED
  @$pb.TagNumber(4)
  $core.String get arkTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set arkTxid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasArkTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearArkTxid() => $_clearField(4);

  /// Error message when ERROR
  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => $_clearField(5);
}

class RedeemVtxoRequest extends $pb.GeneratedMessage {
  factory RedeemVtxoRequest({
    $core.List<$core.int>? userId,
    $core.String? onChainAddress,
    $fixnum.Int64? amount,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (onChainAddress != null) result.onChainAddress = onChainAddress;
    if (amount != null) result.amount = amount;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  RedeemVtxoRequest._();

  factory RedeemVtxoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RedeemVtxoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RedeemVtxoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'onChainAddress')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'amount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemVtxoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemVtxoRequest copyWith(void Function(RedeemVtxoRequest) updates) =>
      super.copyWith((message) => updates(message as RedeemVtxoRequest))
          as RedeemVtxoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RedeemVtxoRequest create() => RedeemVtxoRequest._();
  @$core.override
  RedeemVtxoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RedeemVtxoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RedeemVtxoRequest>(create);
  static RedeemVtxoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get onChainAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set onChainAddress($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOnChainAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearOnChainAddress() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amount => $_getI64(2);
  @$pb.TagNumber(3)
  set amount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestampMs() => $_clearField(5);
}

class RedeemVtxoResponse extends $pb.GeneratedMessage {
  factory RedeemVtxoResponse({
    $core.bool? success,
    $core.String? txid,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (txid != null) result.txid = txid;
    return result;
  }

  RedeemVtxoResponse._();

  factory RedeemVtxoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RedeemVtxoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RedeemVtxoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'txid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemVtxoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemVtxoResponse copyWith(void Function(RedeemVtxoResponse) updates) =>
      super.copyWith((message) => updates(message as RedeemVtxoResponse))
          as RedeemVtxoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RedeemVtxoResponse create() => RedeemVtxoResponse._();
  @$core.override
  RedeemVtxoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RedeemVtxoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RedeemVtxoResponse>(create);
  static RedeemVtxoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get txid => $_getSZ(1);
  @$pb.TagNumber(2)
  set txid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTxid() => $_has(1);
  @$pb.TagNumber(2)
  void clearTxid() => $_clearField(2);
}

class SettleRequest extends $pb.GeneratedMessage {
  factory SettleRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (signedMessages != null) result.signedMessages.addAll(signedMessages);
    return result;
  }

  SettleRequest._();

  factory SettleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleRequest copyWith(void Function(SettleRequest) updates) =>
      super.copyWith((message) => updates(message as SettleRequest))
          as SettleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettleRequest create() => SettleRequest._();
  @$core.override
  SettleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettleRequest>(create);
  static SettleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);

  /// FROST signatures for previously requested sighashes (phase 2+)
  @$pb.TagNumber(4)
  $pb.PbList<$core.List<$core.int>> get signedMessages => $_getList(3);
}

class SettleResponse extends $pb.GeneratedMessage {
  factory SettleResponse({
    SettleResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? commitmentTxid,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (messagesToSign != null) result.messagesToSign.addAll(messagesToSign);
    if (scriptPathSpend != null) result.scriptPathSpend = scriptPathSpend;
    if (commitmentTxid != null) result.commitmentTxid = commitmentTxid;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  SettleResponse._();

  factory SettleResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettleResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettleResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aE<SettleResponse_Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: SettleResponse_Status.values)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, _omitFieldNames ? '' : 'scriptPathSpend')
    ..aOS(4, _omitFieldNames ? '' : 'commitmentTxid')
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleResponse copyWith(void Function(SettleResponse) updates) =>
      super.copyWith((message) => updates(message as SettleResponse))
          as SettleResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettleResponse create() => SettleResponse._();
  @$core.override
  SettleResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettleResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettleResponse>(create);
  static SettleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SettleResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(SettleResponse_Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  /// Sighashes that need FROST signing (when SIGNING_REQUIRED)
  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get messagesToSign => $_getList(1);

  /// Whether these sighashes are script-path spends (no taproot tweak)
  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => $_clearField(3);

  /// Commitment txid when SETTLED
  @$pb.TagNumber(4)
  $core.String get commitmentTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set commitmentTxid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCommitmentTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommitmentTxid() => $_clearField(4);

  /// Error message when ERROR
  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => $_clearField(5);
}

class SettleDelegateRequest extends $pb.GeneratedMessage {
  factory SettleDelegateRequest({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.Iterable<$core.List<$core.int>>? signedMessages,
    $core.bool? storeOnly,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (signedMessages != null) result.signedMessages.addAll(signedMessages);
    if (storeOnly != null) result.storeOnly = storeOnly;
    return result;
  }

  SettleDelegateRequest._();

  factory SettleDelegateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettleDelegateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettleDelegateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..p<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signedMessages', $pb.PbFieldType.PY)
    ..aOB(5, _omitFieldNames ? '' : 'storeOnly')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleDelegateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleDelegateRequest copyWith(
          void Function(SettleDelegateRequest) updates) =>
      super.copyWith((message) => updates(message as SettleDelegateRequest))
          as SettleDelegateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettleDelegateRequest create() => SettleDelegateRequest._();
  @$core.override
  SettleDelegateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettleDelegateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettleDelegateRequest>(create);
  static SettleDelegateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);

  /// FROST signatures for previously requested sighashes (phase 2)
  @$pb.TagNumber(4)
  $pb.PbList<$core.List<$core.int>> get signedMessages => $_getList(3);

  /// Phase 2 only. When true, the cosigner stores the signed intent and
  /// returns DELEGATED without joining a batch. The cosigner's auto-settle
  /// tick task drives the stored intent later when the threshold is reached.
  @$pb.TagNumber(5)
  $core.bool get storeOnly => $_getBF(4);
  @$pb.TagNumber(5)
  set storeOnly($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStoreOnly() => $_has(4);
  @$pb.TagNumber(5)
  void clearStoreOnly() => $_clearField(5);
}

class SettleDelegateResponse extends $pb.GeneratedMessage {
  factory SettleDelegateResponse({
    SettleDelegateResponse_Status? status,
    $core.Iterable<$core.List<$core.int>>? messagesToSign,
    $core.bool? scriptPathSpend,
    $core.String? commitmentTxid,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (messagesToSign != null) result.messagesToSign.addAll(messagesToSign);
    if (scriptPathSpend != null) result.scriptPathSpend = scriptPathSpend;
    if (commitmentTxid != null) result.commitmentTxid = commitmentTxid;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  SettleDelegateResponse._();

  factory SettleDelegateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettleDelegateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettleDelegateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aE<SettleDelegateResponse_Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: SettleDelegateResponse_Status.values)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'messagesToSign', $pb.PbFieldType.PY)
    ..aOB(3, _omitFieldNames ? '' : 'scriptPathSpend')
    ..aOS(4, _omitFieldNames ? '' : 'commitmentTxid')
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleDelegateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettleDelegateResponse copyWith(
          void Function(SettleDelegateResponse) updates) =>
      super.copyWith((message) => updates(message as SettleDelegateResponse))
          as SettleDelegateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettleDelegateResponse create() => SettleDelegateResponse._();
  @$core.override
  SettleDelegateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettleDelegateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettleDelegateResponse>(create);
  static SettleDelegateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SettleDelegateResponse_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(SettleDelegateResponse_Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  /// Sighashes that need FROST signing (when SIGNING_REQUIRED)
  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get messagesToSign => $_getList(1);

  /// Always true for delegate (script-path spend, no taproot tweak)
  @$pb.TagNumber(3)
  $core.bool get scriptPathSpend => $_getBF(2);
  @$pb.TagNumber(3)
  set scriptPathSpend($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScriptPathSpend() => $_has(2);
  @$pb.TagNumber(3)
  void clearScriptPathSpend() => $_clearField(3);

  /// Commitment txid when SETTLED (empty for DELEGATED)
  @$pb.TagNumber(4)
  $core.String get commitmentTxid => $_getSZ(3);
  @$pb.TagNumber(4)
  set commitmentTxid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCommitmentTxid() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommitmentTxid() => $_clearField(4);

  /// Error message when ERROR
  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => $_clearField(5);
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
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (signedArkTxB64 != null) result.signedArkTxB64 = signedArkTxB64;
    if (signedCheckpointTxsB64 != null)
      result.signedCheckpointTxsB64.addAll(signedCheckpointTxsB64);
    if (spentOutpoints != null) result.spentOutpoints.addAll(spentOutpoints);
    return result;
  }

  SubmitArkSendRequest._();

  factory SubmitArkSendRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitArkSendRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitArkSendRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..aOS(4, _omitFieldNames ? '' : 'signedArkTxB64')
    ..pPS(5, _omitFieldNames ? '' : 'signedCheckpointTxsB64')
    ..pPS(6, _omitFieldNames ? '' : 'spentOutpoints')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitArkSendRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitArkSendRequest copyWith(void Function(SubmitArkSendRequest) updates) =>
      super.copyWith((message) => updates(message as SubmitArkSendRequest))
          as SubmitArkSendRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitArkSendRequest create() => SubmitArkSendRequest._();
  @$core.override
  SubmitArkSendRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubmitArkSendRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitArkSendRequest>(create);
  static SubmitArkSendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);

  /// Base64-encoded signed Ark tx PSBT (with FROST sigs on inputs)
  @$pb.TagNumber(4)
  $core.String get signedArkTxB64 => $_getSZ(3);
  @$pb.TagNumber(4)
  set signedArkTxB64($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignedArkTxB64() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignedArkTxB64() => $_clearField(4);

  /// Base64-encoded checkpoint PSBTs (with client FROST sigs)
  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get signedCheckpointTxsB64 => $_getList(4);

  /// Outpoints of spent VTXOs ("txid:vout" format)
  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get spentOutpoints => $_getList(5);
}

class SubmitArkSendResponse extends $pb.GeneratedMessage {
  factory SubmitArkSendResponse({
    $core.String? arkTxid,
    $core.String? changeTxid,
    $core.int? changeVout,
    $fixnum.Int64? changeAmount,
  }) {
    final result = create();
    if (arkTxid != null) result.arkTxid = arkTxid;
    if (changeTxid != null) result.changeTxid = changeTxid;
    if (changeVout != null) result.changeVout = changeVout;
    if (changeAmount != null) result.changeAmount = changeAmount;
    return result;
  }

  SubmitArkSendResponse._();

  factory SubmitArkSendResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitArkSendResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitArkSendResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'arkTxid')
    ..aOS(2, _omitFieldNames ? '' : 'changeTxid')
    ..aI(3, _omitFieldNames ? '' : 'changeVout', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'changeAmount', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitArkSendResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitArkSendResponse copyWith(
          void Function(SubmitArkSendResponse) updates) =>
      super.copyWith((message) => updates(message as SubmitArkSendResponse))
          as SubmitArkSendResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitArkSendResponse create() => SubmitArkSendResponse._();
  @$core.override
  SubmitArkSendResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubmitArkSendResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitArkSendResponse>(create);
  static SubmitArkSendResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get arkTxid => $_getSZ(0);
  @$pb.TagNumber(1)
  set arkTxid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasArkTxid() => $_has(0);
  @$pb.TagNumber(1)
  void clearArkTxid() => $_clearField(1);

  /// Change VTXO info (empty if no change)
  @$pb.TagNumber(2)
  $core.String get changeTxid => $_getSZ(1);
  @$pb.TagNumber(2)
  set changeTxid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChangeTxid() => $_has(1);
  @$pb.TagNumber(2)
  void clearChangeTxid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get changeVout => $_getIZ(2);
  @$pb.TagNumber(3)
  set changeVout($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChangeVout() => $_has(2);
  @$pb.TagNumber(3)
  void clearChangeVout() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get changeAmount => $_getI64(3);
  @$pb.TagNumber(4)
  set changeAmount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChangeAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearChangeAmount() => $_clearField(4);
}

class GetServerInfoRequest extends $pb.GeneratedMessage {
  factory GetServerInfoRequest() => create();

  GetServerInfoRequest._();

  factory GetServerInfoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetServerInfoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetServerInfoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetServerInfoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetServerInfoRequest copyWith(void Function(GetServerInfoRequest) updates) =>
      super.copyWith((message) => updates(message as GetServerInfoRequest))
          as GetServerInfoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetServerInfoRequest create() => GetServerInfoRequest._();
  @$core.override
  GetServerInfoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetServerInfoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetServerInfoRequest>(create);
  static GetServerInfoRequest? _defaultInstance;
}

class GetServerInfoResponse extends $pb.GeneratedMessage {
  factory GetServerInfoResponse({
    $core.String? bitcoinNetwork,
  }) {
    final result = create();
    if (bitcoinNetwork != null) result.bitcoinNetwork = bitcoinNetwork;
    return result;
  }

  GetServerInfoResponse._();

  factory GetServerInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetServerInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetServerInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'bitcoinNetwork')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetServerInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetServerInfoResponse copyWith(
          void Function(GetServerInfoResponse) updates) =>
      super.copyWith((message) => updates(message as GetServerInfoResponse))
          as GetServerInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetServerInfoResponse create() => GetServerInfoResponse._();
  @$core.override
  GetServerInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetServerInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetServerInfoResponse>(create);
  static GetServerInfoResponse? _defaultInstance;

  /// The Bitcoin network this deployment operates on. One of: "mainnet",
  /// "testnet", "signet", "mutinynet", "regtest". Source of truth for the
  /// client's address-rendering HRP.
  @$pb.TagNumber(1)
  $core.String get bitcoinNetwork => $_getSZ(0);
  @$pb.TagNumber(1)
  set bitcoinNetwork($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBitcoinNetwork() => $_has(0);
  @$pb.TagNumber(1)
  void clearBitcoinNetwork() => $_clearField(1);
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
    final result = create();
    if (userId != null) result.userId = userId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (fcmToken != null) result.fcmToken = fcmToken;
    if (platform != null) result.platform = platform;
    if (appVersion != null) result.appVersion = appVersion;
    return result;
  }

  RegisterDeviceTokenRequest._();

  factory RegisterDeviceTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterDeviceTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterDeviceTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampMs')
    ..aOS(4, _omitFieldNames ? '' : 'fcmToken')
    ..aOS(5, _omitFieldNames ? '' : 'platform')
    ..aOS(6, _omitFieldNames ? '' : 'appVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceTokenRequest copyWith(
          void Function(RegisterDeviceTokenRequest) updates) =>
      super.copyWith(
              (message) => updates(message as RegisterDeviceTokenRequest))
          as RegisterDeviceTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenRequest create() => RegisterDeviceTokenRequest._();
  @$core.override
  RegisterDeviceTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterDeviceTokenRequest>(create);
  static RegisterDeviceTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get fcmToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set fcmToken($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFcmToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearFcmToken() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get platform => $_getSZ(4);
  @$pb.TagNumber(5)
  set platform($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPlatform() => $_has(4);
  @$pb.TagNumber(5)
  void clearPlatform() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get appVersion => $_getSZ(5);
  @$pb.TagNumber(6)
  set appVersion($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAppVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearAppVersion() => $_clearField(6);
}

class RegisterDeviceTokenResponse extends $pb.GeneratedMessage {
  factory RegisterDeviceTokenResponse({
    $core.bool? ok,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  RegisterDeviceTokenResponse._();

  factory RegisterDeviceTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterDeviceTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterDeviceTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceTokenResponse copyWith(
          void Function(RegisterDeviceTokenResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RegisterDeviceTokenResponse))
          as RegisterDeviceTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenResponse create() =>
      RegisterDeviceTokenResponse._();
  @$core.override
  RegisterDeviceTokenResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterDeviceTokenResponse>(create);
  static RegisterDeviceTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

/// ---------------------------------------------------------------------------
/// Contract creation (reshare V→V′, then refresh onto the service pairing).
/// Authenticated (the user's main key already exists). The result is a 2-of-2 V′
/// with two pairings: (user + cosigner_shareA) || (service + cosigner_shareB),
/// stored as an EvtxoPolicy on the user's own policy. Steps 1-3 are the simple
/// 2-party reshare {user, cosigner}; step 4 carries the user's refresh halves for
/// the always-online service (the user sends a@service DIRECTLY to the service via
/// AssembleContractShare, so only the POINT a@service·G reaches the cosigner).
/// ---------------------------------------------------------------------------
class ContractCreateStep1Request extends $pb.GeneratedMessage {
  factory ContractCreateStep1Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.String? round1Package,
    $core.List<$core.int>? contractId,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
    $core.List<$core.int>? serverPk,
    $core.int? exitDelay,
    $core.List<$core.int>? contractWasm,
    $core.List<$core.int>? ownerPk,
    $core.List<$core.int>? serviceVk,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (identifier != null) result.identifier = identifier;
    if (round1Package != null) result.round1Package = round1Package;
    if (contractId != null) result.contractId = contractId;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    if (serverPk != null) result.serverPk = serverPk;
    if (exitDelay != null) result.exitDelay = exitDelay;
    if (contractWasm != null) result.contractWasm = contractWasm;
    if (ownerPk != null) result.ownerPk = ownerPk;
    if (serviceVk != null) result.serviceVk = serviceVk;
    return result;
  }

  ContractCreateStep1Request._();

  factory ContractCreateStep1Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep1Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep1Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'round1Package')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'contractId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(6, _omitFieldNames ? '' : 'timestampMs')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'serverPk', $pb.PbFieldType.OY)
    ..aI(8, _omitFieldNames ? '' : 'exitDelay', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'contractWasm', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        10, _omitFieldNames ? '' : 'ownerPk', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        11, _omitFieldNames ? '' : 'serviceVk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep1Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep1Request copyWith(
          void Function(ContractCreateStep1Request) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep1Request))
          as ContractCreateStep1Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep1Request create() => ContractCreateStep1Request._();
  @$core.override
  ContractCreateStep1Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep1Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep1Request>(create);
  static ContractCreateStep1Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

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

  @$pb.TagNumber(4)
  $core.List<$core.int> get contractId => $_getN(3);
  @$pb.TagNumber(4)
  set contractId($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContractId() => $_has(3);
  @$pb.TagNumber(4)
  void clearContractId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get signature => $_getN(4);
  @$pb.TagNumber(5)
  set signature($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignature() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get timestampMs => $_getI64(5);
  @$pb.TagNumber(6)
  set timestampMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTimestampMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestampMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get serverPk => $_getN(6);
  @$pb.TagNumber(7)
  set serverPk($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasServerPk() => $_has(6);
  @$pb.TagNumber(7)
  void clearServerPk() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get exitDelay => $_getIZ(7);
  @$pb.TagNumber(8)
  set exitDelay($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExitDelay() => $_has(7);
  @$pb.TagNumber(8)
  void clearExitDelay() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.List<$core.int> get contractWasm => $_getN(8);
  @$pb.TagNumber(9)
  set contractWasm($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasContractWasm() => $_has(8);
  @$pb.TagNumber(9)
  void clearContractWasm() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.List<$core.int> get ownerPk => $_getN(9);
  @$pb.TagNumber(10)
  set ownerPk($core.List<$core.int> value) => $_setBytes(9, value);
  @$pb.TagNumber(10)
  $core.bool hasOwnerPk() => $_has(9);
  @$pb.TagNumber(10)
  void clearOwnerPk() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get serviceVk => $_getN(10);
  @$pb.TagNumber(11)
  set serviceVk($core.List<$core.int> value) => $_setBytes(10, value);
  @$pb.TagNumber(11)
  $core.bool hasServiceVk() => $_has(10);
  @$pb.TagNumber(11)
  void clearServiceVk() => $_clearField(11);
}

class ContractCreateStep1Response extends $pb.GeneratedMessage {
  factory ContractCreateStep1Response({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? round1Packages,
  }) {
    final result = create();
    if (round1Packages != null)
      result.round1Packages.addEntries(round1Packages);
    return result;
  }

  ContractCreateStep1Response._();

  factory ContractCreateStep1Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep1Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep1Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'round1Packages',
        entryClassName: 'ContractCreateStep1Response.Round1PackagesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep1Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep1Response copyWith(
          void Function(ContractCreateStep1Response) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep1Response))
          as ContractCreateStep1Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep1Response create() =>
      ContractCreateStep1Response._();
  @$core.override
  ContractCreateStep1Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep1Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep1Response>(create);
  static ContractCreateStep1Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get round1Packages => $_getMap(0);
}

class ContractCreateStep2Request extends $pb.GeneratedMessage {
  factory ContractCreateStep2Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (identifier != null) result.identifier = identifier;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  ContractCreateStep2Request._();

  factory ContractCreateStep2Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep2Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep2Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep2Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep2Request copyWith(
          void Function(ContractCreateStep2Request) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep2Request))
          as ContractCreateStep2Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep2Request create() => ContractCreateStep2Request._();
  @$core.override
  ContractCreateStep2Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep2Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep2Request>(create);
  static ContractCreateStep2Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(3)
  set signature($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignature() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestampMs => $_getI64(3);
  @$pb.TagNumber(4)
  set timestampMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTimestampMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestampMs() => $_clearField(4);
}

class ContractCreateStep2Response extends $pb.GeneratedMessage {
  factory ContractCreateStep2Response({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        allRound1Packages,
  }) {
    final result = create();
    if (allRound1Packages != null)
      result.allRound1Packages.addEntries(allRound1Packages);
    return result;
  }

  ContractCreateStep2Response._();

  factory ContractCreateStep2Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep2Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep2Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1, _omitFieldNames ? '' : 'allRound1Packages',
        entryClassName: 'ContractCreateStep2Response.AllRound1PackagesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep2Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep2Response copyWith(
          void Function(ContractCreateStep2Response) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep2Response))
          as ContractCreateStep2Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep2Response create() =>
      ContractCreateStep2Response._();
  @$core.override
  ContractCreateStep2Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep2Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep2Response>(create);
  static ContractCreateStep2Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get allRound1Packages => $_getMap(0);
}

class ContractCreateStep3Request extends $pb.GeneratedMessage {
  factory ContractCreateStep3Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        round2PackagesForOthers,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (identifier != null) result.identifier = identifier;
    if (round2PackagesForOthers != null)
      result.round2PackagesForOthers.addEntries(round2PackagesForOthers);
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  ContractCreateStep3Request._();

  factory ContractCreateStep3Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep3Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep3Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(
        3, _omitFieldNames ? '' : 'round2PackagesForOthers',
        entryClassName:
            'ContractCreateStep3Request.Round2PackagesForOthersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep3Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep3Request copyWith(
          void Function(ContractCreateStep3Request) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep3Request))
          as ContractCreateStep3Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep3Request create() => ContractCreateStep3Request._();
  @$core.override
  ContractCreateStep3Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep3Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep3Request>(create);
  static ContractCreateStep3Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

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

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set timestampMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestampMs() => $_clearField(5);
}

class ContractCreateStep3Response extends $pb.GeneratedMessage {
  factory ContractCreateStep3Response({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        round2PackagesForMe,
    $core.List<$core.int>? contractScriptPubkey,
    $core.List<$core.int>? contractGroupId,
  }) {
    final result = create();
    if (round2PackagesForMe != null)
      result.round2PackagesForMe.addEntries(round2PackagesForMe);
    if (contractScriptPubkey != null)
      result.contractScriptPubkey = contractScriptPubkey;
    if (contractGroupId != null) result.contractGroupId = contractGroupId;
    return result;
  }

  ContractCreateStep3Response._();

  factory ContractCreateStep3Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep3Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep3Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1, _omitFieldNames ? '' : 'round2PackagesForMe',
        entryClassName: 'ContractCreateStep3Response.Round2PackagesForMeEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('mpc_wallet'))
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'contractScriptPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'contractGroupId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep3Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep3Response copyWith(
          void Function(ContractCreateStep3Response) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep3Response))
          as ContractCreateStep3Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep3Response create() =>
      ContractCreateStep3Response._();
  @$core.override
  ContractCreateStep3Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep3Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep3Response>(create);
  static ContractCreateStep3Response? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get round2PackagesForMe => $_getMap(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get contractScriptPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set contractScriptPubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContractScriptPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearContractScriptPubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get contractGroupId => $_getN(2);
  @$pb.TagNumber(3)
  set contractGroupId($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContractGroupId() => $_has(2);
  @$pb.TagNumber(3)
  void clearContractGroupId() => $_clearField(3);
}

/// Step 4: the user, having finalized V′ from step3, refreshes V′ onto the service
/// pairing and hands the cosigner ONLY: a@cosigner (scalar, used to form
/// cosigner_shareB) and a@service·G (point, used to form the service verifying
/// share). The scalar a@service goes DIRECTLY to the service (AssembleContractShare),
/// never to the cosigner — so the cosigner can never reconstruct V′.
class ContractCreateStep4Request extends $pb.GeneratedMessage {
  factory ContractCreateStep4Request({
    $core.List<$core.int>? userId,
    $core.List<$core.int>? identifier,
    $core.List<$core.int>? contractScriptPubkey,
    $core.List<$core.int>? aAtCosigner,
    $core.List<$core.int>? aAtServicePoint,
    $core.List<$core.int>? signature,
    $fixnum.Int64? timestampMs,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (identifier != null) result.identifier = identifier;
    if (contractScriptPubkey != null)
      result.contractScriptPubkey = contractScriptPubkey;
    if (aAtCosigner != null) result.aAtCosigner = aAtCosigner;
    if (aAtServicePoint != null) result.aAtServicePoint = aAtServicePoint;
    if (signature != null) result.signature = signature;
    if (timestampMs != null) result.timestampMs = timestampMs;
    return result;
  }

  ContractCreateStep4Request._();

  factory ContractCreateStep4Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep4Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep4Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identifier', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'contractScriptPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'aAtCosigner', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'aAtServicePoint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aInt64(7, _omitFieldNames ? '' : 'timestampMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep4Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep4Request copyWith(
          void Function(ContractCreateStep4Request) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep4Request))
          as ContractCreateStep4Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep4Request create() => ContractCreateStep4Request._();
  @$core.override
  ContractCreateStep4Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep4Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep4Request>(create);
  static ContractCreateStep4Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identifier => $_getN(1);
  @$pb.TagNumber(2)
  set identifier($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get contractScriptPubkey => $_getN(2);
  @$pb.TagNumber(3)
  set contractScriptPubkey($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContractScriptPubkey() => $_has(2);
  @$pb.TagNumber(3)
  void clearContractScriptPubkey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get aAtCosigner => $_getN(3);
  @$pb.TagNumber(4)
  set aAtCosigner($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAAtCosigner() => $_has(3);
  @$pb.TagNumber(4)
  void clearAAtCosigner() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get aAtServicePoint => $_getN(4);
  @$pb.TagNumber(5)
  set aAtServicePoint($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAAtServicePoint() => $_has(4);
  @$pb.TagNumber(5)
  void clearAAtServicePoint() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get signature => $_getN(5);
  @$pb.TagNumber(6)
  set signature($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSignature() => $_has(5);
  @$pb.TagNumber(6)
  void clearSignature() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestampMs => $_getI64(6);
  @$pb.TagNumber(7)
  set timestampMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimestampMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestampMs() => $_clearField(7);
}

class ContractCreateStep4Response extends $pb.GeneratedMessage {
  factory ContractCreateStep4Response({
    $core.bool? ok,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    return result;
  }

  ContractCreateStep4Response._();

  factory ContractCreateStep4Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractCreateStep4Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractCreateStep4Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep4Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractCreateStep4Response copyWith(
          void Function(ContractCreateStep4Response) updates) =>
      super.copyWith(
              (message) => updates(message as ContractCreateStep4Response))
          as ContractCreateStep4Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractCreateStep4Response create() =>
      ContractCreateStep4Response._();
  @$core.override
  ContractCreateStep4Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractCreateStep4Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractCreateStep4Response>(create);
  static ContractCreateStep4Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);
}

/// SERVICE-side API. Served by the external contract-signer service. Both the
/// wallet (role="user", half=a@service) and the cosigner (role="cosigner",
/// half=b@service + context) deliver their refresh halves; the service sums them
/// into its V′ secret share. `context` is set only by the cosigner.
class AssembleContractShareRequest extends $pb.GeneratedMessage {
  factory AssembleContractShareRequest({
    $core.List<$core.int>? contractGroupId,
    $core.List<$core.int>? halfScalar,
    $core.String? role,
    ContractContext? context,
  }) {
    final result = create();
    if (contractGroupId != null) result.contractGroupId = contractGroupId;
    if (halfScalar != null) result.halfScalar = halfScalar;
    if (role != null) result.role = role;
    if (context != null) result.context = context;
    return result;
  }

  AssembleContractShareRequest._();

  factory AssembleContractShareRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssembleContractShareRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssembleContractShareRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'contractGroupId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'halfScalar', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'role')
    ..aOM<ContractContext>(4, _omitFieldNames ? '' : 'context',
        subBuilder: ContractContext.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssembleContractShareRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssembleContractShareRequest copyWith(
          void Function(AssembleContractShareRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AssembleContractShareRequest))
          as AssembleContractShareRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssembleContractShareRequest create() =>
      AssembleContractShareRequest._();
  @$core.override
  AssembleContractShareRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssembleContractShareRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssembleContractShareRequest>(create);
  static AssembleContractShareRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get contractGroupId => $_getN(0);
  @$pb.TagNumber(1)
  set contractGroupId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContractGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearContractGroupId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get halfScalar => $_getN(1);
  @$pb.TagNumber(2)
  set halfScalar($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHalfScalar() => $_has(1);
  @$pb.TagNumber(2)
  void clearHalfScalar() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get role => $_getSZ(2);
  @$pb.TagNumber(3)
  set role($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => $_clearField(3);

  @$pb.TagNumber(4)
  ContractContext get context => $_getN(3);
  @$pb.TagNumber(4)
  set context(ContractContext value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasContext() => $_has(3);
  @$pb.TagNumber(4)
  void clearContext() => $_clearField(4);
  @$pb.TagNumber(4)
  ContractContext ensureContext() => $_ensure(3);
}

class ContractContext extends $pb.GeneratedMessage {
  factory ContractContext({
    $core.List<$core.int>? contractScriptPubkey,
    $core.List<$core.int>? contractId,
    $core.int? exitDelay,
    $core.List<$core.int>? ownerPk,
    $core.List<$core.int>? serverPk,
    $core.String? publicKeyPackageJson,
    $core.List<$core.int>? serviceVk,
    $core.List<$core.int>? cosignerGroupKey,
  }) {
    final result = create();
    if (contractScriptPubkey != null)
      result.contractScriptPubkey = contractScriptPubkey;
    if (contractId != null) result.contractId = contractId;
    if (exitDelay != null) result.exitDelay = exitDelay;
    if (ownerPk != null) result.ownerPk = ownerPk;
    if (serverPk != null) result.serverPk = serverPk;
    if (publicKeyPackageJson != null)
      result.publicKeyPackageJson = publicKeyPackageJson;
    if (serviceVk != null) result.serviceVk = serviceVk;
    if (cosignerGroupKey != null) result.cosignerGroupKey = cosignerGroupKey;
    return result;
  }

  ContractContext._();

  factory ContractContext.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContractContext.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContractContext',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'contractScriptPubkey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'contractId', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'exitDelay', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'ownerPk', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'serverPk', $pb.PbFieldType.OY)
    ..aOS(6, _omitFieldNames ? '' : 'publicKeyPackageJson')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'serviceVk', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'cosignerGroupKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractContext clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContractContext copyWith(void Function(ContractContext) updates) =>
      super.copyWith((message) => updates(message as ContractContext))
          as ContractContext;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContractContext create() => ContractContext._();
  @$core.override
  ContractContext createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ContractContext getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContractContext>(create);
  static ContractContext? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get contractScriptPubkey => $_getN(0);
  @$pb.TagNumber(1)
  set contractScriptPubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContractScriptPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearContractScriptPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get contractId => $_getN(1);
  @$pb.TagNumber(2)
  set contractId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContractId() => $_has(1);
  @$pb.TagNumber(2)
  void clearContractId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get exitDelay => $_getIZ(2);
  @$pb.TagNumber(3)
  set exitDelay($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExitDelay() => $_has(2);
  @$pb.TagNumber(3)
  void clearExitDelay() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get ownerPk => $_getN(3);
  @$pb.TagNumber(4)
  set ownerPk($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOwnerPk() => $_has(3);
  @$pb.TagNumber(4)
  void clearOwnerPk() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get serverPk => $_getN(4);
  @$pb.TagNumber(5)
  set serverPk($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasServerPk() => $_has(4);
  @$pb.TagNumber(5)
  void clearServerPk() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get publicKeyPackageJson => $_getSZ(5);
  @$pb.TagNumber(6)
  set publicKeyPackageJson($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPublicKeyPackageJson() => $_has(5);
  @$pb.TagNumber(6)
  void clearPublicKeyPackageJson() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get serviceVk => $_getN(6);
  @$pb.TagNumber(7)
  set serviceVk($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasServiceVk() => $_has(6);
  @$pb.TagNumber(7)
  void clearServiceVk() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get cosignerGroupKey => $_getN(7);
  @$pb.TagNumber(8)
  set cosignerGroupKey($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCosignerGroupKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearCosignerGroupKey() => $_clearField(8);
}

class AssembleContractShareResponse extends $pb.GeneratedMessage {
  factory AssembleContractShareResponse({
    $core.bool? ok,
    $core.List<$core.int>? serviceSharePoint,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    if (serviceSharePoint != null) result.serviceSharePoint = serviceSharePoint;
    return result;
  }

  AssembleContractShareResponse._();

  factory AssembleContractShareResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssembleContractShareResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssembleContractShareResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'mpc_wallet'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'serviceSharePoint', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssembleContractShareResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssembleContractShareResponse copyWith(
          void Function(AssembleContractShareResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AssembleContractShareResponse))
          as AssembleContractShareResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssembleContractShareResponse create() =>
      AssembleContractShareResponse._();
  @$core.override
  AssembleContractShareResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssembleContractShareResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssembleContractShareResponse>(create);
  static AssembleContractShareResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get serviceSharePoint => $_getN(1);
  @$pb.TagNumber(2)
  set serviceSharePoint($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasServiceSharePoint() => $_has(1);
  @$pb.TagNumber(2)
  void clearServiceSharePoint() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
