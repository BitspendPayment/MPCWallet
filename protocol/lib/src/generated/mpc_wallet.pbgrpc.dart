//
//  Generated code. Do not modify.
//  source: mpc_wallet.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'mpc_wallet.pb.dart' as $0;

export 'mpc_wallet.pb.dart';

@$pb.GrpcServiceName('mpc_wallet.MPCWallet')
class MPCWalletClient extends $grpc.Client {
  static final _$dKGStep1 = $grpc.ClientMethod<$0.DKGStep1Request, $0.DKGStep1Response>(
      '/mpc_wallet.MPCWallet/DKGStep1',
      ($0.DKGStep1Request value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.DKGStep1Response.fromBuffer(value));
  static final _$dKGStep2 = $grpc.ClientMethod<$0.DKGStep2Request, $0.DKGStep2Response>(
      '/mpc_wallet.MPCWallet/DKGStep2',
      ($0.DKGStep2Request value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.DKGStep2Response.fromBuffer(value));
  static final _$dKGStep3 = $grpc.ClientMethod<$0.DKGStep3Request, $0.DKGStep3Response>(
      '/mpc_wallet.MPCWallet/DKGStep3',
      ($0.DKGStep3Request value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.DKGStep3Response.fromBuffer(value));
  static final _$serviceEnroll = $grpc.ClientMethod<$0.ServiceEnrollRequest, $0.ServiceEnrollResponse>(
      '/mpc_wallet.MPCWallet/ServiceEnroll',
      ($0.ServiceEnrollRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ServiceEnrollResponse.fromBuffer(value));
  static final _$serviceList = $grpc.ClientMethod<$0.ServiceListRequest, $0.ServiceListResponse>(
      '/mpc_wallet.MPCWallet/ServiceList',
      ($0.ServiceListRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ServiceListResponse.fromBuffer(value));
  static final _$serviceRevoke = $grpc.ClientMethod<$0.ServiceRevokeRequest, $0.ServiceRevokeResponse>(
      '/mpc_wallet.MPCWallet/ServiceRevoke',
      ($0.ServiceRevokeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ServiceRevokeResponse.fromBuffer(value));
  static final _$contactAdd = $grpc.ClientMethod<$0.ContactAddRequest, $0.ContactAddResponse>(
      '/mpc_wallet.MPCWallet/ContactAdd',
      ($0.ContactAddRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ContactAddResponse.fromBuffer(value));
  static final _$contactRemove = $grpc.ClientMethod<$0.ContactRemoveRequest, $0.ContactRemoveResponse>(
      '/mpc_wallet.MPCWallet/ContactRemove',
      ($0.ContactRemoveRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ContactRemoveResponse.fromBuffer(value));
  static final _$contactList = $grpc.ClientMethod<$0.ContactListRequest, $0.ContactListResponse>(
      '/mpc_wallet.MPCWallet/ContactList',
      ($0.ContactListRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ContactListResponse.fromBuffer(value));
  static final _$paymentRequestCreate = $grpc.ClientMethod<$0.PaymentRequestCreateRequest, $0.PaymentRequestCreateResponse>(
      '/mpc_wallet.MPCWallet/PaymentRequestCreate',
      ($0.PaymentRequestCreateRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PaymentRequestCreateResponse.fromBuffer(value));
  static final _$paymentRequestList = $grpc.ClientMethod<$0.PaymentRequestListRequest, $0.PaymentRequestListResponse>(
      '/mpc_wallet.MPCWallet/PaymentRequestList',
      ($0.PaymentRequestListRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PaymentRequestListResponse.fromBuffer(value));
  static final _$paymentRequestDecline = $grpc.ClientMethod<$0.PaymentRequestDeclineRequest, $0.PaymentRequestDeclineResponse>(
      '/mpc_wallet.MPCWallet/PaymentRequestDecline',
      ($0.PaymentRequestDeclineRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PaymentRequestDeclineResponse.fromBuffer(value));
  static final _$signStep1 = $grpc.ClientMethod<$0.SignStep1Request, $0.SignStep1Response>(
      '/mpc_wallet.MPCWallet/SignStep1',
      ($0.SignStep1Request value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SignStep1Response.fromBuffer(value));
  static final _$signStep2 = $grpc.ClientMethod<$0.SignStep2Request, $0.SignStep2Response>(
      '/mpc_wallet.MPCWallet/SignStep2',
      ($0.SignStep2Request value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SignStep2Response.fromBuffer(value));
  static final _$getArkInfo = $grpc.ClientMethod<$0.GetArkInfoRequest, $0.GetArkInfoResponse>(
      '/mpc_wallet.MPCWallet/GetArkInfo',
      ($0.GetArkInfoRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetArkInfoResponse.fromBuffer(value));
  static final _$getArkAddress = $grpc.ClientMethod<$0.GetArkAddressRequest, $0.GetArkAddressResponse>(
      '/mpc_wallet.MPCWallet/GetArkAddress',
      ($0.GetArkAddressRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetArkAddressResponse.fromBuffer(value));
  static final _$getBoardingAddress = $grpc.ClientMethod<$0.GetBoardingAddressRequest, $0.GetBoardingAddressResponse>(
      '/mpc_wallet.MPCWallet/GetBoardingAddress',
      ($0.GetBoardingAddressRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetBoardingAddressResponse.fromBuffer(value));
  static final _$listVtxos = $grpc.ClientMethod<$0.ListVtxosRequest, $0.ListVtxosResponse>(
      '/mpc_wallet.MPCWallet/ListVtxos',
      ($0.ListVtxosRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListVtxosResponse.fromBuffer(value));
  static final _$listArkTransactions = $grpc.ClientMethod<$0.ListArkTransactionsRequest, $0.ListArkTransactionsResponse>(
      '/mpc_wallet.MPCWallet/ListArkTransactions',
      ($0.ListArkTransactionsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListArkTransactionsResponse.fromBuffer(value));
  static final _$sendVtxo = $grpc.ClientMethod<$0.SendVtxoRequest, $0.SendVtxoResponse>(
      '/mpc_wallet.MPCWallet/SendVtxo',
      ($0.SendVtxoRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SendVtxoResponse.fromBuffer(value));
  static final _$redeemVtxo = $grpc.ClientMethod<$0.RedeemVtxoRequest, $0.RedeemVtxoResponse>(
      '/mpc_wallet.MPCWallet/RedeemVtxo',
      ($0.RedeemVtxoRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.RedeemVtxoResponse.fromBuffer(value));
  static final _$settle = $grpc.ClientMethod<$0.SettleRequest, $0.SettleResponse>(
      '/mpc_wallet.MPCWallet/Settle',
      ($0.SettleRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SettleResponse.fromBuffer(value));
  static final _$settleDelegate = $grpc.ClientMethod<$0.SettleDelegateRequest, $0.SettleDelegateResponse>(
      '/mpc_wallet.MPCWallet/SettleDelegate',
      ($0.SettleDelegateRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SettleDelegateResponse.fromBuffer(value));
  static final _$submitArkSend = $grpc.ClientMethod<$0.SubmitArkSendRequest, $0.SubmitArkSendResponse>(
      '/mpc_wallet.MPCWallet/SubmitArkSend',
      ($0.SubmitArkSendRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SubmitArkSendResponse.fromBuffer(value));
  static final _$getServerInfo = $grpc.ClientMethod<$0.GetServerInfoRequest, $0.GetServerInfoResponse>(
      '/mpc_wallet.MPCWallet/GetServerInfo',
      ($0.GetServerInfoRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetServerInfoResponse.fromBuffer(value));
  static final _$registerDeviceToken = $grpc.ClientMethod<$0.RegisterDeviceTokenRequest, $0.RegisterDeviceTokenResponse>(
      '/mpc_wallet.MPCWallet/RegisterDeviceToken',
      ($0.RegisterDeviceTokenRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.RegisterDeviceTokenResponse.fromBuffer(value));

  MPCWalletClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.DKGStep1Response> dKGStep1($0.DKGStep1Request request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$dKGStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.DKGStep2Response> dKGStep2($0.DKGStep2Request request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$dKGStep2, request, options: options);
  }

  $grpc.ResponseFuture<$0.DKGStep3Response> dKGStep3($0.DKGStep3Request request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$dKGStep3, request, options: options);
  }

  $grpc.ResponseFuture<$0.ServiceEnrollResponse> serviceEnroll($0.ServiceEnrollRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$serviceEnroll, request, options: options);
  }

  $grpc.ResponseFuture<$0.ServiceListResponse> serviceList($0.ServiceListRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$serviceList, request, options: options);
  }

  $grpc.ResponseFuture<$0.ServiceRevokeResponse> serviceRevoke($0.ServiceRevokeRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$serviceRevoke, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContactAddResponse> contactAdd($0.ContactAddRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$contactAdd, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContactRemoveResponse> contactRemove($0.ContactRemoveRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$contactRemove, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContactListResponse> contactList($0.ContactListRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$contactList, request, options: options);
  }

  $grpc.ResponseFuture<$0.PaymentRequestCreateResponse> paymentRequestCreate($0.PaymentRequestCreateRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$paymentRequestCreate, request, options: options);
  }

  $grpc.ResponseFuture<$0.PaymentRequestListResponse> paymentRequestList($0.PaymentRequestListRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$paymentRequestList, request, options: options);
  }

  $grpc.ResponseFuture<$0.PaymentRequestDeclineResponse> paymentRequestDecline($0.PaymentRequestDeclineRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$paymentRequestDecline, request, options: options);
  }

  $grpc.ResponseFuture<$0.SignStep1Response> signStep1($0.SignStep1Request request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$signStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.SignStep2Response> signStep2($0.SignStep2Request request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$signStep2, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetArkInfoResponse> getArkInfo($0.GetArkInfoRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getArkInfo, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetArkAddressResponse> getArkAddress($0.GetArkAddressRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getArkAddress, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetBoardingAddressResponse> getBoardingAddress($0.GetBoardingAddressRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getBoardingAddress, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListVtxosResponse> listVtxos($0.ListVtxosRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listVtxos, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListArkTransactionsResponse> listArkTransactions($0.ListArkTransactionsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listArkTransactions, request, options: options);
  }

  $grpc.ResponseFuture<$0.SendVtxoResponse> sendVtxo($0.SendVtxoRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$sendVtxo, request, options: options);
  }

  $grpc.ResponseFuture<$0.RedeemVtxoResponse> redeemVtxo($0.RedeemVtxoRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$redeemVtxo, request, options: options);
  }

  $grpc.ResponseFuture<$0.SettleResponse> settle($0.SettleRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$settle, request, options: options);
  }

  $grpc.ResponseFuture<$0.SettleDelegateResponse> settleDelegate($0.SettleDelegateRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$settleDelegate, request, options: options);
  }

  $grpc.ResponseFuture<$0.SubmitArkSendResponse> submitArkSend($0.SubmitArkSendRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$submitArkSend, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetServerInfoResponse> getServerInfo($0.GetServerInfoRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getServerInfo, request, options: options);
  }

  $grpc.ResponseFuture<$0.RegisterDeviceTokenResponse> registerDeviceToken($0.RegisterDeviceTokenRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$registerDeviceToken, request, options: options);
  }
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
    $addMethod($grpc.ServiceMethod<$0.ServiceEnrollRequest, $0.ServiceEnrollResponse>(
        'ServiceEnroll',
        serviceEnroll_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ServiceEnrollRequest.fromBuffer(value),
        ($0.ServiceEnrollResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ServiceListRequest, $0.ServiceListResponse>(
        'ServiceList',
        serviceList_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ServiceListRequest.fromBuffer(value),
        ($0.ServiceListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ServiceRevokeRequest, $0.ServiceRevokeResponse>(
        'ServiceRevoke',
        serviceRevoke_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ServiceRevokeRequest.fromBuffer(value),
        ($0.ServiceRevokeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ContactAddRequest, $0.ContactAddResponse>(
        'ContactAdd',
        contactAdd_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ContactAddRequest.fromBuffer(value),
        ($0.ContactAddResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ContactRemoveRequest, $0.ContactRemoveResponse>(
        'ContactRemove',
        contactRemove_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ContactRemoveRequest.fromBuffer(value),
        ($0.ContactRemoveResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ContactListRequest, $0.ContactListResponse>(
        'ContactList',
        contactList_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ContactListRequest.fromBuffer(value),
        ($0.ContactListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PaymentRequestCreateRequest, $0.PaymentRequestCreateResponse>(
        'PaymentRequestCreate',
        paymentRequestCreate_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PaymentRequestCreateRequest.fromBuffer(value),
        ($0.PaymentRequestCreateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PaymentRequestListRequest, $0.PaymentRequestListResponse>(
        'PaymentRequestList',
        paymentRequestList_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PaymentRequestListRequest.fromBuffer(value),
        ($0.PaymentRequestListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PaymentRequestDeclineRequest, $0.PaymentRequestDeclineResponse>(
        'PaymentRequestDecline',
        paymentRequestDecline_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PaymentRequestDeclineRequest.fromBuffer(value),
        ($0.PaymentRequestDeclineResponse value) => value.writeToBuffer()));
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
    $addMethod($grpc.ServiceMethod<$0.GetArkInfoRequest, $0.GetArkInfoResponse>(
        'GetArkInfo',
        getArkInfo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetArkInfoRequest.fromBuffer(value),
        ($0.GetArkInfoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetArkAddressRequest, $0.GetArkAddressResponse>(
        'GetArkAddress',
        getArkAddress_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetArkAddressRequest.fromBuffer(value),
        ($0.GetArkAddressResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetBoardingAddressRequest, $0.GetBoardingAddressResponse>(
        'GetBoardingAddress',
        getBoardingAddress_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetBoardingAddressRequest.fromBuffer(value),
        ($0.GetBoardingAddressResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListVtxosRequest, $0.ListVtxosResponse>(
        'ListVtxos',
        listVtxos_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListVtxosRequest.fromBuffer(value),
        ($0.ListVtxosResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListArkTransactionsRequest, $0.ListArkTransactionsResponse>(
        'ListArkTransactions',
        listArkTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListArkTransactionsRequest.fromBuffer(value),
        ($0.ListArkTransactionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SendVtxoRequest, $0.SendVtxoResponse>(
        'SendVtxo',
        sendVtxo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SendVtxoRequest.fromBuffer(value),
        ($0.SendVtxoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RedeemVtxoRequest, $0.RedeemVtxoResponse>(
        'RedeemVtxo',
        redeemVtxo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RedeemVtxoRequest.fromBuffer(value),
        ($0.RedeemVtxoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SettleRequest, $0.SettleResponse>(
        'Settle',
        settle_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SettleRequest.fromBuffer(value),
        ($0.SettleResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SettleDelegateRequest, $0.SettleDelegateResponse>(
        'SettleDelegate',
        settleDelegate_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SettleDelegateRequest.fromBuffer(value),
        ($0.SettleDelegateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SubmitArkSendRequest, $0.SubmitArkSendResponse>(
        'SubmitArkSend',
        submitArkSend_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SubmitArkSendRequest.fromBuffer(value),
        ($0.SubmitArkSendResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetServerInfoRequest, $0.GetServerInfoResponse>(
        'GetServerInfo',
        getServerInfo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetServerInfoRequest.fromBuffer(value),
        ($0.GetServerInfoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RegisterDeviceTokenRequest, $0.RegisterDeviceTokenResponse>(
        'RegisterDeviceToken',
        registerDeviceToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RegisterDeviceTokenRequest.fromBuffer(value),
        ($0.RegisterDeviceTokenResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.DKGStep1Response> dKGStep1_Pre($grpc.ServiceCall call, $async.Future<$0.DKGStep1Request> request) async {
    return dKGStep1(call, await request);
  }

  $async.Future<$0.DKGStep2Response> dKGStep2_Pre($grpc.ServiceCall call, $async.Future<$0.DKGStep2Request> request) async {
    return dKGStep2(call, await request);
  }

  $async.Future<$0.DKGStep3Response> dKGStep3_Pre($grpc.ServiceCall call, $async.Future<$0.DKGStep3Request> request) async {
    return dKGStep3(call, await request);
  }

  $async.Future<$0.ServiceEnrollResponse> serviceEnroll_Pre($grpc.ServiceCall call, $async.Future<$0.ServiceEnrollRequest> request) async {
    return serviceEnroll(call, await request);
  }

  $async.Future<$0.ServiceListResponse> serviceList_Pre($grpc.ServiceCall call, $async.Future<$0.ServiceListRequest> request) async {
    return serviceList(call, await request);
  }

  $async.Future<$0.ServiceRevokeResponse> serviceRevoke_Pre($grpc.ServiceCall call, $async.Future<$0.ServiceRevokeRequest> request) async {
    return serviceRevoke(call, await request);
  }

  $async.Future<$0.ContactAddResponse> contactAdd_Pre($grpc.ServiceCall call, $async.Future<$0.ContactAddRequest> request) async {
    return contactAdd(call, await request);
  }

  $async.Future<$0.ContactRemoveResponse> contactRemove_Pre($grpc.ServiceCall call, $async.Future<$0.ContactRemoveRequest> request) async {
    return contactRemove(call, await request);
  }

  $async.Future<$0.ContactListResponse> contactList_Pre($grpc.ServiceCall call, $async.Future<$0.ContactListRequest> request) async {
    return contactList(call, await request);
  }

  $async.Future<$0.PaymentRequestCreateResponse> paymentRequestCreate_Pre($grpc.ServiceCall call, $async.Future<$0.PaymentRequestCreateRequest> request) async {
    return paymentRequestCreate(call, await request);
  }

  $async.Future<$0.PaymentRequestListResponse> paymentRequestList_Pre($grpc.ServiceCall call, $async.Future<$0.PaymentRequestListRequest> request) async {
    return paymentRequestList(call, await request);
  }

  $async.Future<$0.PaymentRequestDeclineResponse> paymentRequestDecline_Pre($grpc.ServiceCall call, $async.Future<$0.PaymentRequestDeclineRequest> request) async {
    return paymentRequestDecline(call, await request);
  }

  $async.Future<$0.SignStep1Response> signStep1_Pre($grpc.ServiceCall call, $async.Future<$0.SignStep1Request> request) async {
    return signStep1(call, await request);
  }

  $async.Future<$0.SignStep2Response> signStep2_Pre($grpc.ServiceCall call, $async.Future<$0.SignStep2Request> request) async {
    return signStep2(call, await request);
  }

  $async.Future<$0.GetArkInfoResponse> getArkInfo_Pre($grpc.ServiceCall call, $async.Future<$0.GetArkInfoRequest> request) async {
    return getArkInfo(call, await request);
  }

  $async.Future<$0.GetArkAddressResponse> getArkAddress_Pre($grpc.ServiceCall call, $async.Future<$0.GetArkAddressRequest> request) async {
    return getArkAddress(call, await request);
  }

  $async.Future<$0.GetBoardingAddressResponse> getBoardingAddress_Pre($grpc.ServiceCall call, $async.Future<$0.GetBoardingAddressRequest> request) async {
    return getBoardingAddress(call, await request);
  }

  $async.Future<$0.ListVtxosResponse> listVtxos_Pre($grpc.ServiceCall call, $async.Future<$0.ListVtxosRequest> request) async {
    return listVtxos(call, await request);
  }

  $async.Future<$0.ListArkTransactionsResponse> listArkTransactions_Pre($grpc.ServiceCall call, $async.Future<$0.ListArkTransactionsRequest> request) async {
    return listArkTransactions(call, await request);
  }

  $async.Future<$0.SendVtxoResponse> sendVtxo_Pre($grpc.ServiceCall call, $async.Future<$0.SendVtxoRequest> request) async {
    return sendVtxo(call, await request);
  }

  $async.Future<$0.RedeemVtxoResponse> redeemVtxo_Pre($grpc.ServiceCall call, $async.Future<$0.RedeemVtxoRequest> request) async {
    return redeemVtxo(call, await request);
  }

  $async.Future<$0.SettleResponse> settle_Pre($grpc.ServiceCall call, $async.Future<$0.SettleRequest> request) async {
    return settle(call, await request);
  }

  $async.Future<$0.SettleDelegateResponse> settleDelegate_Pre($grpc.ServiceCall call, $async.Future<$0.SettleDelegateRequest> request) async {
    return settleDelegate(call, await request);
  }

  $async.Future<$0.SubmitArkSendResponse> submitArkSend_Pre($grpc.ServiceCall call, $async.Future<$0.SubmitArkSendRequest> request) async {
    return submitArkSend(call, await request);
  }

  $async.Future<$0.GetServerInfoResponse> getServerInfo_Pre($grpc.ServiceCall call, $async.Future<$0.GetServerInfoRequest> request) async {
    return getServerInfo(call, await request);
  }

  $async.Future<$0.RegisterDeviceTokenResponse> registerDeviceToken_Pre($grpc.ServiceCall call, $async.Future<$0.RegisterDeviceTokenRequest> request) async {
    return registerDeviceToken(call, await request);
  }

  $async.Future<$0.DKGStep1Response> dKGStep1($grpc.ServiceCall call, $0.DKGStep1Request request);
  $async.Future<$0.DKGStep2Response> dKGStep2($grpc.ServiceCall call, $0.DKGStep2Request request);
  $async.Future<$0.DKGStep3Response> dKGStep3($grpc.ServiceCall call, $0.DKGStep3Request request);
  $async.Future<$0.ServiceEnrollResponse> serviceEnroll($grpc.ServiceCall call, $0.ServiceEnrollRequest request);
  $async.Future<$0.ServiceListResponse> serviceList($grpc.ServiceCall call, $0.ServiceListRequest request);
  $async.Future<$0.ServiceRevokeResponse> serviceRevoke($grpc.ServiceCall call, $0.ServiceRevokeRequest request);
  $async.Future<$0.ContactAddResponse> contactAdd($grpc.ServiceCall call, $0.ContactAddRequest request);
  $async.Future<$0.ContactRemoveResponse> contactRemove($grpc.ServiceCall call, $0.ContactRemoveRequest request);
  $async.Future<$0.ContactListResponse> contactList($grpc.ServiceCall call, $0.ContactListRequest request);
  $async.Future<$0.PaymentRequestCreateResponse> paymentRequestCreate($grpc.ServiceCall call, $0.PaymentRequestCreateRequest request);
  $async.Future<$0.PaymentRequestListResponse> paymentRequestList($grpc.ServiceCall call, $0.PaymentRequestListRequest request);
  $async.Future<$0.PaymentRequestDeclineResponse> paymentRequestDecline($grpc.ServiceCall call, $0.PaymentRequestDeclineRequest request);
  $async.Future<$0.SignStep1Response> signStep1($grpc.ServiceCall call, $0.SignStep1Request request);
  $async.Future<$0.SignStep2Response> signStep2($grpc.ServiceCall call, $0.SignStep2Request request);
  $async.Future<$0.GetArkInfoResponse> getArkInfo($grpc.ServiceCall call, $0.GetArkInfoRequest request);
  $async.Future<$0.GetArkAddressResponse> getArkAddress($grpc.ServiceCall call, $0.GetArkAddressRequest request);
  $async.Future<$0.GetBoardingAddressResponse> getBoardingAddress($grpc.ServiceCall call, $0.GetBoardingAddressRequest request);
  $async.Future<$0.ListVtxosResponse> listVtxos($grpc.ServiceCall call, $0.ListVtxosRequest request);
  $async.Future<$0.ListArkTransactionsResponse> listArkTransactions($grpc.ServiceCall call, $0.ListArkTransactionsRequest request);
  $async.Future<$0.SendVtxoResponse> sendVtxo($grpc.ServiceCall call, $0.SendVtxoRequest request);
  $async.Future<$0.RedeemVtxoResponse> redeemVtxo($grpc.ServiceCall call, $0.RedeemVtxoRequest request);
  $async.Future<$0.SettleResponse> settle($grpc.ServiceCall call, $0.SettleRequest request);
  $async.Future<$0.SettleDelegateResponse> settleDelegate($grpc.ServiceCall call, $0.SettleDelegateRequest request);
  $async.Future<$0.SubmitArkSendResponse> submitArkSend($grpc.ServiceCall call, $0.SubmitArkSendRequest request);
  $async.Future<$0.GetServerInfoResponse> getServerInfo($grpc.ServiceCall call, $0.GetServerInfoRequest request);
  $async.Future<$0.RegisterDeviceTokenResponse> registerDeviceToken($grpc.ServiceCall call, $0.RegisterDeviceTokenRequest request);
}
