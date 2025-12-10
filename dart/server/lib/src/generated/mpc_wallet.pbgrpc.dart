// This is a generated file - do not edit.
//
// Generated from mpc_wallet.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'mpc_wallet.pb.dart' as $0;

export 'mpc_wallet.pb.dart';

@$pb.GrpcServiceName('mpc_wallet.MPCWallet')
class MPCWalletClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MPCWalletClient(super.channel, {super.options, super.interceptors});

  /// DKG
  $grpc.ResponseFuture<$0.DKGStep1Response> dKGStep1(
    $0.DKGStep1Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$dKGStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.DKGStep2Response> dKGStep2(
    $0.DKGStep2Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$dKGStep2, request, options: options);
  }

  $grpc.ResponseFuture<$0.DKGStep3Response> dKGStep3(
    $0.DKGStep3Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$dKGStep3, request, options: options);
  }

  /// Signing
  $grpc.ResponseFuture<$0.SignStep1Response> signStep1(
    $0.SignStep1Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$signStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.SignStep2Response> signStep2(
    $0.SignStep2Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$signStep2, request, options: options);
  }

  // method descriptors

  static final _$dKGStep1 =
      $grpc.ClientMethod<$0.DKGStep1Request, $0.DKGStep1Response>(
          '/mpc_wallet.MPCWallet/DKGStep1',
          ($0.DKGStep1Request value) => value.writeToBuffer(),
          $0.DKGStep1Response.fromBuffer);
  static final _$dKGStep2 =
      $grpc.ClientMethod<$0.DKGStep2Request, $0.DKGStep2Response>(
          '/mpc_wallet.MPCWallet/DKGStep2',
          ($0.DKGStep2Request value) => value.writeToBuffer(),
          $0.DKGStep2Response.fromBuffer);
  static final _$dKGStep3 =
      $grpc.ClientMethod<$0.DKGStep3Request, $0.DKGStep3Response>(
          '/mpc_wallet.MPCWallet/DKGStep3',
          ($0.DKGStep3Request value) => value.writeToBuffer(),
          $0.DKGStep3Response.fromBuffer);
  static final _$signStep1 =
      $grpc.ClientMethod<$0.SignStep1Request, $0.SignStep1Response>(
          '/mpc_wallet.MPCWallet/SignStep1',
          ($0.SignStep1Request value) => value.writeToBuffer(),
          $0.SignStep1Response.fromBuffer);
  static final _$signStep2 =
      $grpc.ClientMethod<$0.SignStep2Request, $0.SignStep2Response>(
          '/mpc_wallet.MPCWallet/SignStep2',
          ($0.SignStep2Request value) => value.writeToBuffer(),
          $0.SignStep2Response.fromBuffer);
}

@$pb.GrpcServiceName('mpc_wallet.MPCWallet')
abstract class MPCWalletServiceBase extends $grpc.Service {
  $core.String get $name => 'mpc_wallet.MPCWallet';

  MPCWalletServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.DKGStep1Request, $0.DKGStep1Response>(
        'DKGStep1',
        dKGStep1_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DKGStep1Request.fromBuffer(value),
        ($0.DKGStep1Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DKGStep2Request, $0.DKGStep2Response>(
        'DKGStep2',
        dKGStep2_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DKGStep2Request.fromBuffer(value),
        ($0.DKGStep2Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DKGStep3Request, $0.DKGStep3Response>(
        'DKGStep3',
        dKGStep3_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DKGStep3Request.fromBuffer(value),
        ($0.DKGStep3Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SignStep1Request, $0.SignStep1Response>(
        'SignStep1',
        signStep1_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SignStep1Request.fromBuffer(value),
        ($0.SignStep1Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SignStep2Request, $0.SignStep2Response>(
        'SignStep2',
        signStep2_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SignStep2Request.fromBuffer(value),
        ($0.SignStep2Response value) => value.writeToBuffer()));
  }

  $async.Future<$0.DKGStep1Response> dKGStep1_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DKGStep1Request> $request) async {
    return dKGStep1($call, await $request);
  }

  $async.Future<$0.DKGStep1Response> dKGStep1(
      $grpc.ServiceCall call, $0.DKGStep1Request request);

  $async.Future<$0.DKGStep2Response> dKGStep2_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DKGStep2Request> $request) async {
    return dKGStep2($call, await $request);
  }

  $async.Future<$0.DKGStep2Response> dKGStep2(
      $grpc.ServiceCall call, $0.DKGStep2Request request);

  $async.Future<$0.DKGStep3Response> dKGStep3_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DKGStep3Request> $request) async {
    return dKGStep3($call, await $request);
  }

  $async.Future<$0.DKGStep3Response> dKGStep3(
      $grpc.ServiceCall call, $0.DKGStep3Request request);

  $async.Future<$0.SignStep1Response> signStep1_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SignStep1Request> $request) async {
    return signStep1($call, await $request);
  }

  $async.Future<$0.SignStep1Response> signStep1(
      $grpc.ServiceCall call, $0.SignStep1Request request);

  $async.Future<$0.SignStep2Response> signStep2_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SignStep2Request> $request) async {
    return signStep2($call, await $request);
  }

  $async.Future<$0.SignStep2Response> signStep2(
      $grpc.ServiceCall call, $0.SignStep2Request request);
}
