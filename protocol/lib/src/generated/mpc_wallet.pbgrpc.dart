///
//  Generated code. Do not modify.
//  source: mpc_wallet.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

import 'dart:async' as $async;

import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'mpc_wallet.pb.dart' as $0;
export 'mpc_wallet.pb.dart';

class MPCWalletClient extends $grpc.Client {
  static final _$dKGStep1 =
      $grpc.ClientMethod<$0.DKGStep1Request, $0.DKGStep1Response>(
          '/mpc_wallet.MPCWallet/DKGStep1',
          ($0.DKGStep1Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.DKGStep1Response.fromBuffer(value));
  static final _$dKGStep2 =
      $grpc.ClientMethod<$0.DKGStep2Request, $0.DKGStep2Response>(
          '/mpc_wallet.MPCWallet/DKGStep2',
          ($0.DKGStep2Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.DKGStep2Response.fromBuffer(value));
  static final _$dKGStep3 =
      $grpc.ClientMethod<$0.DKGStep3Request, $0.DKGStep3Response>(
          '/mpc_wallet.MPCWallet/DKGStep3',
          ($0.DKGStep3Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.DKGStep3Response.fromBuffer(value));
  static final _$signStep1 =
      $grpc.ClientMethod<$0.SignStep1Request, $0.SignStep1Response>(
          '/mpc_wallet.MPCWallet/SignStep1',
          ($0.SignStep1Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.SignStep1Response.fromBuffer(value));
  static final _$signStep2 =
      $grpc.ClientMethod<$0.SignStep2Request, $0.SignStep2Response>(
          '/mpc_wallet.MPCWallet/SignStep2',
          ($0.SignStep2Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.SignStep2Response.fromBuffer(value));
  static final _$refreshStep1 =
      $grpc.ClientMethod<$0.RefreshStep1Request, $0.RefreshStep1Response>(
          '/mpc_wallet.MPCWallet/RefreshStep1',
          ($0.RefreshStep1Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.RefreshStep1Response.fromBuffer(value));
  static final _$refreshStep2 =
      $grpc.ClientMethod<$0.RefreshStep2Request, $0.RefreshStep2Response>(
          '/mpc_wallet.MPCWallet/RefreshStep2',
          ($0.RefreshStep2Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.RefreshStep2Response.fromBuffer(value));
  static final _$refreshStep3 =
      $grpc.ClientMethod<$0.RefreshStep3Request, $0.RefreshStep3Response>(
          '/mpc_wallet.MPCWallet/RefreshStep3',
          ($0.RefreshStep3Request value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.RefreshStep3Response.fromBuffer(value));
  static final _$getPolicyId =
      $grpc.ClientMethod<$0.GetPolicyIdRequest, $0.GetPolicyIdResponse>(
          '/mpc_wallet.MPCWallet/GetPolicyId',
          ($0.GetPolicyIdRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.GetPolicyIdResponse.fromBuffer(value));
  static final _$updatePolicy =
      $grpc.ClientMethod<$0.UpdatePolicyRequest, $0.UpdatePolicyResponse>(
          '/mpc_wallet.MPCWallet/UpdatePolicy',
          ($0.UpdatePolicyRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.UpdatePolicyResponse.fromBuffer(value));
  static final _$deletePolicy =
      $grpc.ClientMethod<$0.DeletePolicyRequest, $0.DeletePolicyResponse>(
          '/mpc_wallet.MPCWallet/DeletePolicy',
          ($0.DeletePolicyRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.DeletePolicyResponse.fromBuffer(value));
  static final _$broadcastTransaction = $grpc.ClientMethod<
          $0.BroadcastTransactionRequest, $0.BroadcastTransactionResponse>(
      '/mpc_wallet.MPCWallet/BroadcastTransaction',
      ($0.BroadcastTransactionRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.BroadcastTransactionResponse.fromBuffer(value));
  static final _$fetchHistory =
      $grpc.ClientMethod<$0.FetchHistoryRequest, $0.FetchHistoryResponse>(
          '/mpc_wallet.MPCWallet/FetchHistory',
          ($0.FetchHistoryRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.FetchHistoryResponse.fromBuffer(value));
  static final _$fetchRecentTransactions = $grpc.ClientMethod<
          $0.FetchRecentTransactionsRequest,
          $0.FetchRecentTransactionsResponse>(
      '/mpc_wallet.MPCWallet/FetchRecentTransactions',
      ($0.FetchRecentTransactionsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.FetchRecentTransactionsResponse.fromBuffer(value));
  static final _$subscribeToHistory = $grpc.ClientMethod<
          $0.SubscribeToHistoryRequest, $0.TransactionNotification>(
      '/mpc_wallet.MPCWallet/SubscribeToHistory',
      ($0.SubscribeToHistoryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.TransactionNotification.fromBuffer(value));
  static final _$getArkInfo =
      $grpc.ClientMethod<$0.GetArkInfoRequest, $0.GetArkInfoResponse>(
          '/mpc_wallet.MPCWallet/GetArkInfo',
          ($0.GetArkInfoRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.GetArkInfoResponse.fromBuffer(value));
  static final _$getArkAddress =
      $grpc.ClientMethod<$0.GetArkAddressRequest, $0.GetArkAddressResponse>(
          '/mpc_wallet.MPCWallet/GetArkAddress',
          ($0.GetArkAddressRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.GetArkAddressResponse.fromBuffer(value));
  static final _$getBoardingAddress = $grpc.ClientMethod<
          $0.GetBoardingAddressRequest, $0.GetBoardingAddressResponse>(
      '/mpc_wallet.MPCWallet/GetBoardingAddress',
      ($0.GetBoardingAddressRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.GetBoardingAddressResponse.fromBuffer(value));
  static final _$listVtxos =
      $grpc.ClientMethod<$0.ListVtxosRequest, $0.ListVtxosResponse>(
          '/mpc_wallet.MPCWallet/ListVtxos',
          ($0.ListVtxosRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.ListVtxosResponse.fromBuffer(value));
  static final _$listArkTransactions = $grpc.ClientMethod<
          $0.ListArkTransactionsRequest, $0.ListArkTransactionsResponse>(
      '/mpc_wallet.MPCWallet/ListArkTransactions',
      ($0.ListArkTransactionsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.ListArkTransactionsResponse.fromBuffer(value));
  static final _$checkBoardingBalance = $grpc.ClientMethod<
          $0.CheckBoardingBalanceRequest, $0.CheckBoardingBalanceResponse>(
      '/mpc_wallet.MPCWallet/CheckBoardingBalance',
      ($0.CheckBoardingBalanceRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.CheckBoardingBalanceResponse.fromBuffer(value));
  static final _$sendVtxo =
      $grpc.ClientMethod<$0.SendVtxoRequest, $0.SendVtxoResponse>(
          '/mpc_wallet.MPCWallet/SendVtxo',
          ($0.SendVtxoRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.SendVtxoResponse.fromBuffer(value));
  static final _$redeemVtxo =
      $grpc.ClientMethod<$0.RedeemVtxoRequest, $0.RedeemVtxoResponse>(
          '/mpc_wallet.MPCWallet/RedeemVtxo',
          ($0.RedeemVtxoRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.RedeemVtxoResponse.fromBuffer(value));
  static final _$settle =
      $grpc.ClientMethod<$0.SettleRequest, $0.SettleResponse>(
          '/mpc_wallet.MPCWallet/Settle',
          ($0.SettleRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) => $0.SettleResponse.fromBuffer(value));
  static final _$settleDelegate =
      $grpc.ClientMethod<$0.SettleDelegateRequest, $0.SettleDelegateResponse>(
          '/mpc_wallet.MPCWallet/SettleDelegate',
          ($0.SettleDelegateRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.SettleDelegateResponse.fromBuffer(value));
  static final _$submitArkSend =
      $grpc.ClientMethod<$0.SubmitArkSendRequest, $0.SubmitArkSendResponse>(
          '/mpc_wallet.MPCWallet/SubmitArkSend',
          ($0.SubmitArkSendRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.SubmitArkSendResponse.fromBuffer(value));
  static final _$getServerInfo =
      $grpc.ClientMethod<$0.GetServerInfoRequest, $0.GetServerInfoResponse>(
          '/mpc_wallet.MPCWallet/GetServerInfo',
          ($0.GetServerInfoRequest value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.GetServerInfoResponse.fromBuffer(value));
  static final _$registerDeviceToken = $grpc.ClientMethod<
          $0.RegisterDeviceTokenRequest, $0.RegisterDeviceTokenResponse>(
      '/mpc_wallet.MPCWallet/RegisterDeviceToken',
      ($0.RegisterDeviceTokenRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.RegisterDeviceTokenResponse.fromBuffer(value));

  MPCWalletClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseFuture<$0.DKGStep1Response> dKGStep1($0.DKGStep1Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$dKGStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.DKGStep2Response> dKGStep2($0.DKGStep2Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$dKGStep2, request, options: options);
  }

  $grpc.ResponseFuture<$0.DKGStep3Response> dKGStep3($0.DKGStep3Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$dKGStep3, request, options: options);
  }

  $grpc.ResponseFuture<$0.SignStep1Response> signStep1(
      $0.SignStep1Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$signStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.SignStep2Response> signStep2(
      $0.SignStep2Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$signStep2, request, options: options);
  }

  $grpc.ResponseFuture<$0.RefreshStep1Response> refreshStep1(
      $0.RefreshStep1Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$refreshStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.RefreshStep2Response> refreshStep2(
      $0.RefreshStep2Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$refreshStep2, request, options: options);
  }

  $grpc.ResponseFuture<$0.RefreshStep3Response> refreshStep3(
      $0.RefreshStep3Request request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$refreshStep3, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPolicyIdResponse> getPolicyId(
      $0.GetPolicyIdRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getPolicyId, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdatePolicyResponse> updatePolicy(
      $0.UpdatePolicyRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updatePolicy, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeletePolicyResponse> deletePolicy(
      $0.DeletePolicyRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deletePolicy, request, options: options);
  }

  $grpc.ResponseFuture<$0.BroadcastTransactionResponse> broadcastTransaction(
      $0.BroadcastTransactionRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$broadcastTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$0.FetchHistoryResponse> fetchHistory(
      $0.FetchHistoryRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$fetchHistory, request, options: options);
  }

  $grpc.ResponseFuture<$0.FetchRecentTransactionsResponse>
      fetchRecentTransactions($0.FetchRecentTransactionsRequest request,
          {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$fetchRecentTransactions, request,
        options: options);
  }

  $grpc.ResponseStream<$0.TransactionNotification> subscribeToHistory(
      $0.SubscribeToHistoryRequest request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(
        _$subscribeToHistory, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.GetArkInfoResponse> getArkInfo(
      $0.GetArkInfoRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getArkInfo, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetArkAddressResponse> getArkAddress(
      $0.GetArkAddressRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getArkAddress, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetBoardingAddressResponse> getBoardingAddress(
      $0.GetBoardingAddressRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getBoardingAddress, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListVtxosResponse> listVtxos(
      $0.ListVtxosRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listVtxos, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListArkTransactionsResponse> listArkTransactions(
      $0.ListArkTransactionsRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listArkTransactions, request, options: options);
  }

  $grpc.ResponseFuture<$0.CheckBoardingBalanceResponse> checkBoardingBalance(
      $0.CheckBoardingBalanceRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$checkBoardingBalance, request, options: options);
  }

  $grpc.ResponseFuture<$0.SendVtxoResponse> sendVtxo($0.SendVtxoRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$sendVtxo, request, options: options);
  }

  $grpc.ResponseFuture<$0.RedeemVtxoResponse> redeemVtxo(
      $0.RedeemVtxoRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$redeemVtxo, request, options: options);
  }

  $grpc.ResponseFuture<$0.SettleResponse> settle($0.SettleRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$settle, request, options: options);
  }

  $grpc.ResponseFuture<$0.SettleDelegateResponse> settleDelegate(
      $0.SettleDelegateRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$settleDelegate, request, options: options);
  }

  $grpc.ResponseFuture<$0.SubmitArkSendResponse> submitArkSend(
      $0.SubmitArkSendRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$submitArkSend, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetServerInfoResponse> getServerInfo(
      $0.GetServerInfoRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getServerInfo, request, options: options);
  }

  $grpc.ResponseFuture<$0.RegisterDeviceTokenResponse> registerDeviceToken(
      $0.RegisterDeviceTokenRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$registerDeviceToken, request, options: options);
  }
}

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
    $addMethod(
        $grpc.ServiceMethod<$0.RefreshStep1Request, $0.RefreshStep1Response>(
            'RefreshStep1',
            refreshStep1_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RefreshStep1Request.fromBuffer(value),
            ($0.RefreshStep1Response value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RefreshStep2Request, $0.RefreshStep2Response>(
            'RefreshStep2',
            refreshStep2_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RefreshStep2Request.fromBuffer(value),
            ($0.RefreshStep2Response value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RefreshStep3Request, $0.RefreshStep3Response>(
            'RefreshStep3',
            refreshStep3_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RefreshStep3Request.fromBuffer(value),
            ($0.RefreshStep3Response value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetPolicyIdRequest, $0.GetPolicyIdResponse>(
            'GetPolicyId',
            getPolicyId_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetPolicyIdRequest.fromBuffer(value),
            ($0.GetPolicyIdResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdatePolicyRequest, $0.UpdatePolicyResponse>(
            'UpdatePolicy',
            updatePolicy_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdatePolicyRequest.fromBuffer(value),
            ($0.UpdatePolicyResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeletePolicyRequest, $0.DeletePolicyResponse>(
            'DeletePolicy',
            deletePolicy_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeletePolicyRequest.fromBuffer(value),
            ($0.DeletePolicyResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BroadcastTransactionRequest,
            $0.BroadcastTransactionResponse>(
        'BroadcastTransaction',
        broadcastTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.BroadcastTransactionRequest.fromBuffer(value),
        ($0.BroadcastTransactionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.FetchHistoryRequest, $0.FetchHistoryResponse>(
            'FetchHistory',
            fetchHistory_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.FetchHistoryRequest.fromBuffer(value),
            ($0.FetchHistoryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.FetchRecentTransactionsRequest,
            $0.FetchRecentTransactionsResponse>(
        'FetchRecentTransactions',
        fetchRecentTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.FetchRecentTransactionsRequest.fromBuffer(value),
        ($0.FetchRecentTransactionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SubscribeToHistoryRequest,
            $0.TransactionNotification>(
        'SubscribeToHistory',
        subscribeToHistory_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.SubscribeToHistoryRequest.fromBuffer(value),
        ($0.TransactionNotification value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetArkInfoRequest, $0.GetArkInfoResponse>(
        'GetArkInfo',
        getArkInfo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetArkInfoRequest.fromBuffer(value),
        ($0.GetArkInfoResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetArkAddressRequest, $0.GetArkAddressResponse>(
            'GetArkAddress',
            getArkAddress_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetArkAddressRequest.fromBuffer(value),
            ($0.GetArkAddressResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetBoardingAddressRequest,
            $0.GetBoardingAddressResponse>(
        'GetBoardingAddress',
        getBoardingAddress_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetBoardingAddressRequest.fromBuffer(value),
        ($0.GetBoardingAddressResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListVtxosRequest, $0.ListVtxosResponse>(
        'ListVtxos',
        listVtxos_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListVtxosRequest.fromBuffer(value),
        ($0.ListVtxosResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListArkTransactionsRequest,
            $0.ListArkTransactionsResponse>(
        'ListArkTransactions',
        listArkTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListArkTransactionsRequest.fromBuffer(value),
        ($0.ListArkTransactionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CheckBoardingBalanceRequest,
            $0.CheckBoardingBalanceResponse>(
        'CheckBoardingBalance',
        checkBoardingBalance_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CheckBoardingBalanceRequest.fromBuffer(value),
        ($0.CheckBoardingBalanceResponse value) => value.writeToBuffer()));
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
    $addMethod($grpc.ServiceMethod<$0.SettleDelegateRequest,
            $0.SettleDelegateResponse>(
        'SettleDelegate',
        settleDelegate_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SettleDelegateRequest.fromBuffer(value),
        ($0.SettleDelegateResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SubmitArkSendRequest, $0.SubmitArkSendResponse>(
            'SubmitArkSend',
            submitArkSend_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SubmitArkSendRequest.fromBuffer(value),
            ($0.SubmitArkSendResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetServerInfoRequest, $0.GetServerInfoResponse>(
            'GetServerInfo',
            getServerInfo_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetServerInfoRequest.fromBuffer(value),
            ($0.GetServerInfoResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RegisterDeviceTokenRequest,
            $0.RegisterDeviceTokenResponse>(
        'RegisterDeviceToken',
        registerDeviceToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RegisterDeviceTokenRequest.fromBuffer(value),
        ($0.RegisterDeviceTokenResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.DKGStep1Response> dKGStep1_Pre(
      $grpc.ServiceCall call, $async.Future<$0.DKGStep1Request> request) async {
    return dKGStep1(call, await request);
  }

  $async.Future<$0.DKGStep2Response> dKGStep2_Pre(
      $grpc.ServiceCall call, $async.Future<$0.DKGStep2Request> request) async {
    return dKGStep2(call, await request);
  }

  $async.Future<$0.DKGStep3Response> dKGStep3_Pre(
      $grpc.ServiceCall call, $async.Future<$0.DKGStep3Request> request) async {
    return dKGStep3(call, await request);
  }

  $async.Future<$0.SignStep1Response> signStep1_Pre($grpc.ServiceCall call,
      $async.Future<$0.SignStep1Request> request) async {
    return signStep1(call, await request);
  }

  $async.Future<$0.SignStep2Response> signStep2_Pre($grpc.ServiceCall call,
      $async.Future<$0.SignStep2Request> request) async {
    return signStep2(call, await request);
  }

  $async.Future<$0.RefreshStep1Response> refreshStep1_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.RefreshStep1Request> request) async {
    return refreshStep1(call, await request);
  }

  $async.Future<$0.RefreshStep2Response> refreshStep2_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.RefreshStep2Request> request) async {
    return refreshStep2(call, await request);
  }

  $async.Future<$0.RefreshStep3Response> refreshStep3_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.RefreshStep3Request> request) async {
    return refreshStep3(call, await request);
  }

  $async.Future<$0.GetPolicyIdResponse> getPolicyId_Pre($grpc.ServiceCall call,
      $async.Future<$0.GetPolicyIdRequest> request) async {
    return getPolicyId(call, await request);
  }

  $async.Future<$0.UpdatePolicyResponse> updatePolicy_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.UpdatePolicyRequest> request) async {
    return updatePolicy(call, await request);
  }

  $async.Future<$0.DeletePolicyResponse> deletePolicy_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.DeletePolicyRequest> request) async {
    return deletePolicy(call, await request);
  }

  $async.Future<$0.BroadcastTransactionResponse> broadcastTransaction_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.BroadcastTransactionRequest> request) async {
    return broadcastTransaction(call, await request);
  }

  $async.Future<$0.FetchHistoryResponse> fetchHistory_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.FetchHistoryRequest> request) async {
    return fetchHistory(call, await request);
  }

  $async.Future<$0.FetchRecentTransactionsResponse> fetchRecentTransactions_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.FetchRecentTransactionsRequest> request) async {
    return fetchRecentTransactions(call, await request);
  }

  $async.Stream<$0.TransactionNotification> subscribeToHistory_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.SubscribeToHistoryRequest> request) async* {
    yield* subscribeToHistory(call, await request);
  }

  $async.Future<$0.GetArkInfoResponse> getArkInfo_Pre($grpc.ServiceCall call,
      $async.Future<$0.GetArkInfoRequest> request) async {
    return getArkInfo(call, await request);
  }

  $async.Future<$0.GetArkAddressResponse> getArkAddress_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.GetArkAddressRequest> request) async {
    return getArkAddress(call, await request);
  }

  $async.Future<$0.GetBoardingAddressResponse> getBoardingAddress_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.GetBoardingAddressRequest> request) async {
    return getBoardingAddress(call, await request);
  }

  $async.Future<$0.ListVtxosResponse> listVtxos_Pre($grpc.ServiceCall call,
      $async.Future<$0.ListVtxosRequest> request) async {
    return listVtxos(call, await request);
  }

  $async.Future<$0.ListArkTransactionsResponse> listArkTransactions_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.ListArkTransactionsRequest> request) async {
    return listArkTransactions(call, await request);
  }

  $async.Future<$0.CheckBoardingBalanceResponse> checkBoardingBalance_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.CheckBoardingBalanceRequest> request) async {
    return checkBoardingBalance(call, await request);
  }

  $async.Future<$0.SendVtxoResponse> sendVtxo_Pre(
      $grpc.ServiceCall call, $async.Future<$0.SendVtxoRequest> request) async {
    return sendVtxo(call, await request);
  }

  $async.Future<$0.RedeemVtxoResponse> redeemVtxo_Pre($grpc.ServiceCall call,
      $async.Future<$0.RedeemVtxoRequest> request) async {
    return redeemVtxo(call, await request);
  }

  $async.Future<$0.SettleResponse> settle_Pre(
      $grpc.ServiceCall call, $async.Future<$0.SettleRequest> request) async {
    return settle(call, await request);
  }

  $async.Future<$0.SettleDelegateResponse> settleDelegate_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.SettleDelegateRequest> request) async {
    return settleDelegate(call, await request);
  }

  $async.Future<$0.SubmitArkSendResponse> submitArkSend_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.SubmitArkSendRequest> request) async {
    return submitArkSend(call, await request);
  }

  $async.Future<$0.GetServerInfoResponse> getServerInfo_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.GetServerInfoRequest> request) async {
    return getServerInfo(call, await request);
  }

  $async.Future<$0.RegisterDeviceTokenResponse> registerDeviceToken_Pre(
      $grpc.ServiceCall call,
      $async.Future<$0.RegisterDeviceTokenRequest> request) async {
    return registerDeviceToken(call, await request);
  }

  $async.Future<$0.DKGStep1Response> dKGStep1(
      $grpc.ServiceCall call, $0.DKGStep1Request request);
  $async.Future<$0.DKGStep2Response> dKGStep2(
      $grpc.ServiceCall call, $0.DKGStep2Request request);
  $async.Future<$0.DKGStep3Response> dKGStep3(
      $grpc.ServiceCall call, $0.DKGStep3Request request);
  $async.Future<$0.SignStep1Response> signStep1(
      $grpc.ServiceCall call, $0.SignStep1Request request);
  $async.Future<$0.SignStep2Response> signStep2(
      $grpc.ServiceCall call, $0.SignStep2Request request);
  $async.Future<$0.RefreshStep1Response> refreshStep1(
      $grpc.ServiceCall call, $0.RefreshStep1Request request);
  $async.Future<$0.RefreshStep2Response> refreshStep2(
      $grpc.ServiceCall call, $0.RefreshStep2Request request);
  $async.Future<$0.RefreshStep3Response> refreshStep3(
      $grpc.ServiceCall call, $0.RefreshStep3Request request);
  $async.Future<$0.GetPolicyIdResponse> getPolicyId(
      $grpc.ServiceCall call, $0.GetPolicyIdRequest request);
  $async.Future<$0.UpdatePolicyResponse> updatePolicy(
      $grpc.ServiceCall call, $0.UpdatePolicyRequest request);
  $async.Future<$0.DeletePolicyResponse> deletePolicy(
      $grpc.ServiceCall call, $0.DeletePolicyRequest request);
  $async.Future<$0.BroadcastTransactionResponse> broadcastTransaction(
      $grpc.ServiceCall call, $0.BroadcastTransactionRequest request);
  $async.Future<$0.FetchHistoryResponse> fetchHistory(
      $grpc.ServiceCall call, $0.FetchHistoryRequest request);
  $async.Future<$0.FetchRecentTransactionsResponse> fetchRecentTransactions(
      $grpc.ServiceCall call, $0.FetchRecentTransactionsRequest request);
  $async.Stream<$0.TransactionNotification> subscribeToHistory(
      $grpc.ServiceCall call, $0.SubscribeToHistoryRequest request);
  $async.Future<$0.GetArkInfoResponse> getArkInfo(
      $grpc.ServiceCall call, $0.GetArkInfoRequest request);
  $async.Future<$0.GetArkAddressResponse> getArkAddress(
      $grpc.ServiceCall call, $0.GetArkAddressRequest request);
  $async.Future<$0.GetBoardingAddressResponse> getBoardingAddress(
      $grpc.ServiceCall call, $0.GetBoardingAddressRequest request);
  $async.Future<$0.ListVtxosResponse> listVtxos(
      $grpc.ServiceCall call, $0.ListVtxosRequest request);
  $async.Future<$0.ListArkTransactionsResponse> listArkTransactions(
      $grpc.ServiceCall call, $0.ListArkTransactionsRequest request);
  $async.Future<$0.CheckBoardingBalanceResponse> checkBoardingBalance(
      $grpc.ServiceCall call, $0.CheckBoardingBalanceRequest request);
  $async.Future<$0.SendVtxoResponse> sendVtxo(
      $grpc.ServiceCall call, $0.SendVtxoRequest request);
  $async.Future<$0.RedeemVtxoResponse> redeemVtxo(
      $grpc.ServiceCall call, $0.RedeemVtxoRequest request);
  $async.Future<$0.SettleResponse> settle(
      $grpc.ServiceCall call, $0.SettleRequest request);
  $async.Future<$0.SettleDelegateResponse> settleDelegate(
      $grpc.ServiceCall call, $0.SettleDelegateRequest request);
  $async.Future<$0.SubmitArkSendResponse> submitArkSend(
      $grpc.ServiceCall call, $0.SubmitArkSendRequest request);
  $async.Future<$0.GetServerInfoResponse> getServerInfo(
      $grpc.ServiceCall call, $0.GetServerInfoRequest request);
  $async.Future<$0.RegisterDeviceTokenResponse> registerDeviceToken(
      $grpc.ServiceCall call, $0.RegisterDeviceTokenRequest request);
}
