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

  /// Contract creation. Reshare V→V′ between user + cosigner (steps 1-3), then a
  /// single refresh of V′ onto the always-online SERVICE pairing (step 4), giving a
  /// 2-of-2 V′ with two signing pairings: (user + cosigner_shareA) || (service +
  /// cosigner_shareB). No ECIES, no async pickup — the service is always online.
  $grpc.ResponseFuture<$0.ContractCreateStep1Response> contractCreateStep1(
    $0.ContractCreateStep1Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$contractCreateStep1, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContractCreateStep2Response> contractCreateStep2(
    $0.ContractCreateStep2Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$contractCreateStep2, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContractCreateStep3Response> contractCreateStep3(
    $0.ContractCreateStep3Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$contractCreateStep3, request, options: options);
  }

  $grpc.ResponseFuture<$0.ContractCreateStep4Response> contractCreateStep4(
    $0.ContractCreateStep4Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$contractCreateStep4, request, options: options);
  }

  /// SERVICE-side API (served by the external contract-signer service, NOT the
  /// cosigner). Both the wallet (role=user, a@service) and the cosigner
  /// (role=cosigner, b@service + context) deliver their refresh halves; the service
  /// sums them into its V′ share. Synchronous, no encryption.
  $grpc.ResponseFuture<$0.AssembleContractShareResponse> assembleContractShare(
    $0.AssembleContractShareRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$assembleContractShare, request, options: options);
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

  /// Broadcast
  $grpc.ResponseFuture<$0.BroadcastTransactionResponse> broadcastTransaction(
    $0.BroadcastTransactionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$broadcastTransaction, request, options: options);
  }

  /// Sync / History
  $grpc.ResponseFuture<$0.FetchHistoryResponse> fetchHistory(
    $0.FetchHistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$fetchHistory, request, options: options);
  }

  $grpc.ResponseFuture<$0.FetchRecentTransactionsResponse>
      fetchRecentTransactions(
    $0.FetchRecentTransactionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$fetchRecentTransactions, request,
        options: options);
  }

  $grpc.ResponseStream<$0.TransactionNotification> subscribeToHistory(
    $0.SubscribeToHistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$subscribeToHistory, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Ark Protocol
  $grpc.ResponseFuture<$0.GetArkInfoResponse> getArkInfo(
    $0.GetArkInfoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getArkInfo, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetArkAddressResponse> getArkAddress(
    $0.GetArkAddressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getArkAddress, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetBoardingAddressResponse> getBoardingAddress(
    $0.GetBoardingAddressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getBoardingAddress, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListVtxosResponse> listVtxos(
    $0.ListVtxosRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listVtxos, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListArkTransactionsResponse> listArkTransactions(
    $0.ListArkTransactionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listArkTransactions, request, options: options);
  }

  $grpc.ResponseFuture<$0.CheckBoardingBalanceResponse> checkBoardingBalance(
    $0.CheckBoardingBalanceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$checkBoardingBalance, request, options: options);
  }

  $grpc.ResponseFuture<$0.SendVtxoResponse> sendVtxo(
    $0.SendVtxoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendVtxo, request, options: options);
  }

  $grpc.ResponseFuture<$0.RedeemVtxoResponse> redeemVtxo(
    $0.RedeemVtxoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$redeemVtxo, request, options: options);
  }

  /// Ark Settle (boarding): board on-chain UTXOs into Ark VTXOs.
  /// Stateful: call multiple times to drive the batch protocol.
  /// Phase 1: call with no signed_messages → returns SIGNING_REQUIRED + intent sighashes
  /// Phase 2: call with FROST signatures → registers intent, waits for batch
  /// Phase 3: poll → returns SIGNING_REQUIRED for commitment/forfeit, or SETTLED
  $grpc.ResponseFuture<$0.SettleResponse> settle(
    $0.SettleRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$settle, request, options: options);
  }

  /// Ark SettleDelegate: settle existing VTXOs using the delegate pattern.
  /// Only 2 rounds (vs 4 for boarding):
  /// Phase 1: call with no signed_messages → returns SIGNING_REQUIRED + all sighashes
  /// Phase 2: call with FROST signatures → server drives batch autonomously → SETTLED
  $grpc.ResponseFuture<$0.SettleDelegateResponse> settleDelegate(
    $0.SettleDelegateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$settleDelegate, request, options: options);
  }

  /// Ark SubmitArkSend: client-built off-chain send, server proxies to ASP.
  $grpc.ResponseFuture<$0.SubmitArkSendResponse> submitArkSend(
    $0.SubmitArkSendRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$submitArkSend, request, options: options);
  }

  /// Server deployment metadata. Unauthenticated — returns the cosigner-runtime's
  /// configured Bitcoin network so clients render addresses with the right HRP
  /// without having to know it themselves.
  $grpc.ResponseFuture<$0.GetServerInfoResponse> getServerInfo(
    $0.GetServerInfoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getServerInfo, request, options: options);
  }

  /// Register an FCM token so the cosigner can wake the device when a VTXO arrives.
  $grpc.ResponseFuture<$0.RegisterDeviceTokenResponse> registerDeviceToken(
    $0.RegisterDeviceTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerDeviceToken, request, options: options);
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
  static final _$contractCreateStep1 = $grpc.ClientMethod<
          $0.ContractCreateStep1Request, $0.ContractCreateStep1Response>(
      '/mpc_wallet.MPCWallet/ContractCreateStep1',
      ($0.ContractCreateStep1Request value) => value.writeToBuffer(),
      $0.ContractCreateStep1Response.fromBuffer);
  static final _$contractCreateStep2 = $grpc.ClientMethod<
          $0.ContractCreateStep2Request, $0.ContractCreateStep2Response>(
      '/mpc_wallet.MPCWallet/ContractCreateStep2',
      ($0.ContractCreateStep2Request value) => value.writeToBuffer(),
      $0.ContractCreateStep2Response.fromBuffer);
  static final _$contractCreateStep3 = $grpc.ClientMethod<
          $0.ContractCreateStep3Request, $0.ContractCreateStep3Response>(
      '/mpc_wallet.MPCWallet/ContractCreateStep3',
      ($0.ContractCreateStep3Request value) => value.writeToBuffer(),
      $0.ContractCreateStep3Response.fromBuffer);
  static final _$contractCreateStep4 = $grpc.ClientMethod<
          $0.ContractCreateStep4Request, $0.ContractCreateStep4Response>(
      '/mpc_wallet.MPCWallet/ContractCreateStep4',
      ($0.ContractCreateStep4Request value) => value.writeToBuffer(),
      $0.ContractCreateStep4Response.fromBuffer);
  static final _$assembleContractShare = $grpc.ClientMethod<
          $0.AssembleContractShareRequest, $0.AssembleContractShareResponse>(
      '/mpc_wallet.MPCWallet/AssembleContractShare',
      ($0.AssembleContractShareRequest value) => value.writeToBuffer(),
      $0.AssembleContractShareResponse.fromBuffer);
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
  static final _$broadcastTransaction = $grpc.ClientMethod<
          $0.BroadcastTransactionRequest, $0.BroadcastTransactionResponse>(
      '/mpc_wallet.MPCWallet/BroadcastTransaction',
      ($0.BroadcastTransactionRequest value) => value.writeToBuffer(),
      $0.BroadcastTransactionResponse.fromBuffer);
  static final _$fetchHistory =
      $grpc.ClientMethod<$0.FetchHistoryRequest, $0.FetchHistoryResponse>(
          '/mpc_wallet.MPCWallet/FetchHistory',
          ($0.FetchHistoryRequest value) => value.writeToBuffer(),
          $0.FetchHistoryResponse.fromBuffer);
  static final _$fetchRecentTransactions = $grpc.ClientMethod<
          $0.FetchRecentTransactionsRequest,
          $0.FetchRecentTransactionsResponse>(
      '/mpc_wallet.MPCWallet/FetchRecentTransactions',
      ($0.FetchRecentTransactionsRequest value) => value.writeToBuffer(),
      $0.FetchRecentTransactionsResponse.fromBuffer);
  static final _$subscribeToHistory = $grpc.ClientMethod<
          $0.SubscribeToHistoryRequest, $0.TransactionNotification>(
      '/mpc_wallet.MPCWallet/SubscribeToHistory',
      ($0.SubscribeToHistoryRequest value) => value.writeToBuffer(),
      $0.TransactionNotification.fromBuffer);
  static final _$getArkInfo =
      $grpc.ClientMethod<$0.GetArkInfoRequest, $0.GetArkInfoResponse>(
          '/mpc_wallet.MPCWallet/GetArkInfo',
          ($0.GetArkInfoRequest value) => value.writeToBuffer(),
          $0.GetArkInfoResponse.fromBuffer);
  static final _$getArkAddress =
      $grpc.ClientMethod<$0.GetArkAddressRequest, $0.GetArkAddressResponse>(
          '/mpc_wallet.MPCWallet/GetArkAddress',
          ($0.GetArkAddressRequest value) => value.writeToBuffer(),
          $0.GetArkAddressResponse.fromBuffer);
  static final _$getBoardingAddress = $grpc.ClientMethod<
          $0.GetBoardingAddressRequest, $0.GetBoardingAddressResponse>(
      '/mpc_wallet.MPCWallet/GetBoardingAddress',
      ($0.GetBoardingAddressRequest value) => value.writeToBuffer(),
      $0.GetBoardingAddressResponse.fromBuffer);
  static final _$listVtxos =
      $grpc.ClientMethod<$0.ListVtxosRequest, $0.ListVtxosResponse>(
          '/mpc_wallet.MPCWallet/ListVtxos',
          ($0.ListVtxosRequest value) => value.writeToBuffer(),
          $0.ListVtxosResponse.fromBuffer);
  static final _$listArkTransactions = $grpc.ClientMethod<
          $0.ListArkTransactionsRequest, $0.ListArkTransactionsResponse>(
      '/mpc_wallet.MPCWallet/ListArkTransactions',
      ($0.ListArkTransactionsRequest value) => value.writeToBuffer(),
      $0.ListArkTransactionsResponse.fromBuffer);
  static final _$checkBoardingBalance = $grpc.ClientMethod<
          $0.CheckBoardingBalanceRequest, $0.CheckBoardingBalanceResponse>(
      '/mpc_wallet.MPCWallet/CheckBoardingBalance',
      ($0.CheckBoardingBalanceRequest value) => value.writeToBuffer(),
      $0.CheckBoardingBalanceResponse.fromBuffer);
  static final _$sendVtxo =
      $grpc.ClientMethod<$0.SendVtxoRequest, $0.SendVtxoResponse>(
          '/mpc_wallet.MPCWallet/SendVtxo',
          ($0.SendVtxoRequest value) => value.writeToBuffer(),
          $0.SendVtxoResponse.fromBuffer);
  static final _$redeemVtxo =
      $grpc.ClientMethod<$0.RedeemVtxoRequest, $0.RedeemVtxoResponse>(
          '/mpc_wallet.MPCWallet/RedeemVtxo',
          ($0.RedeemVtxoRequest value) => value.writeToBuffer(),
          $0.RedeemVtxoResponse.fromBuffer);
  static final _$settle =
      $grpc.ClientMethod<$0.SettleRequest, $0.SettleResponse>(
          '/mpc_wallet.MPCWallet/Settle',
          ($0.SettleRequest value) => value.writeToBuffer(),
          $0.SettleResponse.fromBuffer);
  static final _$settleDelegate =
      $grpc.ClientMethod<$0.SettleDelegateRequest, $0.SettleDelegateResponse>(
          '/mpc_wallet.MPCWallet/SettleDelegate',
          ($0.SettleDelegateRequest value) => value.writeToBuffer(),
          $0.SettleDelegateResponse.fromBuffer);
  static final _$submitArkSend =
      $grpc.ClientMethod<$0.SubmitArkSendRequest, $0.SubmitArkSendResponse>(
          '/mpc_wallet.MPCWallet/SubmitArkSend',
          ($0.SubmitArkSendRequest value) => value.writeToBuffer(),
          $0.SubmitArkSendResponse.fromBuffer);
  static final _$getServerInfo =
      $grpc.ClientMethod<$0.GetServerInfoRequest, $0.GetServerInfoResponse>(
          '/mpc_wallet.MPCWallet/GetServerInfo',
          ($0.GetServerInfoRequest value) => value.writeToBuffer(),
          $0.GetServerInfoResponse.fromBuffer);
  static final _$registerDeviceToken = $grpc.ClientMethod<
          $0.RegisterDeviceTokenRequest, $0.RegisterDeviceTokenResponse>(
      '/mpc_wallet.MPCWallet/RegisterDeviceToken',
      ($0.RegisterDeviceTokenRequest value) => value.writeToBuffer(),
      $0.RegisterDeviceTokenResponse.fromBuffer);
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
    $addMethod($grpc.ServiceMethod<$0.ContractCreateStep1Request,
            $0.ContractCreateStep1Response>(
        'ContractCreateStep1',
        contractCreateStep1_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ContractCreateStep1Request.fromBuffer(value),
        ($0.ContractCreateStep1Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ContractCreateStep2Request,
            $0.ContractCreateStep2Response>(
        'ContractCreateStep2',
        contractCreateStep2_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ContractCreateStep2Request.fromBuffer(value),
        ($0.ContractCreateStep2Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ContractCreateStep3Request,
            $0.ContractCreateStep3Response>(
        'ContractCreateStep3',
        contractCreateStep3_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ContractCreateStep3Request.fromBuffer(value),
        ($0.ContractCreateStep3Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ContractCreateStep4Request,
            $0.ContractCreateStep4Response>(
        'ContractCreateStep4',
        contractCreateStep4_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ContractCreateStep4Request.fromBuffer(value),
        ($0.ContractCreateStep4Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AssembleContractShareRequest,
            $0.AssembleContractShareResponse>(
        'AssembleContractShare',
        assembleContractShare_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AssembleContractShareRequest.fromBuffer(value),
        ($0.AssembleContractShareResponse value) => value.writeToBuffer()));
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

  $async.Future<$0.ContractCreateStep1Response> contractCreateStep1_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ContractCreateStep1Request> $request) async {
    return contractCreateStep1($call, await $request);
  }

  $async.Future<$0.ContractCreateStep1Response> contractCreateStep1(
      $grpc.ServiceCall call, $0.ContractCreateStep1Request request);

  $async.Future<$0.ContractCreateStep2Response> contractCreateStep2_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ContractCreateStep2Request> $request) async {
    return contractCreateStep2($call, await $request);
  }

  $async.Future<$0.ContractCreateStep2Response> contractCreateStep2(
      $grpc.ServiceCall call, $0.ContractCreateStep2Request request);

  $async.Future<$0.ContractCreateStep3Response> contractCreateStep3_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ContractCreateStep3Request> $request) async {
    return contractCreateStep3($call, await $request);
  }

  $async.Future<$0.ContractCreateStep3Response> contractCreateStep3(
      $grpc.ServiceCall call, $0.ContractCreateStep3Request request);

  $async.Future<$0.ContractCreateStep4Response> contractCreateStep4_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ContractCreateStep4Request> $request) async {
    return contractCreateStep4($call, await $request);
  }

  $async.Future<$0.ContractCreateStep4Response> contractCreateStep4(
      $grpc.ServiceCall call, $0.ContractCreateStep4Request request);

  $async.Future<$0.AssembleContractShareResponse> assembleContractShare_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AssembleContractShareRequest> $request) async {
    return assembleContractShare($call, await $request);
  }

  $async.Future<$0.AssembleContractShareResponse> assembleContractShare(
      $grpc.ServiceCall call, $0.AssembleContractShareRequest request);

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

  $async.Future<$0.BroadcastTransactionResponse> broadcastTransaction_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.BroadcastTransactionRequest> $request) async {
    return broadcastTransaction($call, await $request);
  }

  $async.Future<$0.BroadcastTransactionResponse> broadcastTransaction(
      $grpc.ServiceCall call, $0.BroadcastTransactionRequest request);

  $async.Future<$0.FetchHistoryResponse> fetchHistory_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.FetchHistoryRequest> $request) async {
    return fetchHistory($call, await $request);
  }

  $async.Future<$0.FetchHistoryResponse> fetchHistory(
      $grpc.ServiceCall call, $0.FetchHistoryRequest request);

  $async.Future<$0.FetchRecentTransactionsResponse> fetchRecentTransactions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.FetchRecentTransactionsRequest> $request) async {
    return fetchRecentTransactions($call, await $request);
  }

  $async.Future<$0.FetchRecentTransactionsResponse> fetchRecentTransactions(
      $grpc.ServiceCall call, $0.FetchRecentTransactionsRequest request);

  $async.Stream<$0.TransactionNotification> subscribeToHistory_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SubscribeToHistoryRequest> $request) async* {
    yield* subscribeToHistory($call, await $request);
  }

  $async.Stream<$0.TransactionNotification> subscribeToHistory(
      $grpc.ServiceCall call, $0.SubscribeToHistoryRequest request);

  $async.Future<$0.GetArkInfoResponse> getArkInfo_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetArkInfoRequest> $request) async {
    return getArkInfo($call, await $request);
  }

  $async.Future<$0.GetArkInfoResponse> getArkInfo(
      $grpc.ServiceCall call, $0.GetArkInfoRequest request);

  $async.Future<$0.GetArkAddressResponse> getArkAddress_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetArkAddressRequest> $request) async {
    return getArkAddress($call, await $request);
  }

  $async.Future<$0.GetArkAddressResponse> getArkAddress(
      $grpc.ServiceCall call, $0.GetArkAddressRequest request);

  $async.Future<$0.GetBoardingAddressResponse> getBoardingAddress_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetBoardingAddressRequest> $request) async {
    return getBoardingAddress($call, await $request);
  }

  $async.Future<$0.GetBoardingAddressResponse> getBoardingAddress(
      $grpc.ServiceCall call, $0.GetBoardingAddressRequest request);

  $async.Future<$0.ListVtxosResponse> listVtxos_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListVtxosRequest> $request) async {
    return listVtxos($call, await $request);
  }

  $async.Future<$0.ListVtxosResponse> listVtxos(
      $grpc.ServiceCall call, $0.ListVtxosRequest request);

  $async.Future<$0.ListArkTransactionsResponse> listArkTransactions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListArkTransactionsRequest> $request) async {
    return listArkTransactions($call, await $request);
  }

  $async.Future<$0.ListArkTransactionsResponse> listArkTransactions(
      $grpc.ServiceCall call, $0.ListArkTransactionsRequest request);

  $async.Future<$0.CheckBoardingBalanceResponse> checkBoardingBalance_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CheckBoardingBalanceRequest> $request) async {
    return checkBoardingBalance($call, await $request);
  }

  $async.Future<$0.CheckBoardingBalanceResponse> checkBoardingBalance(
      $grpc.ServiceCall call, $0.CheckBoardingBalanceRequest request);

  $async.Future<$0.SendVtxoResponse> sendVtxo_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SendVtxoRequest> $request) async {
    return sendVtxo($call, await $request);
  }

  $async.Future<$0.SendVtxoResponse> sendVtxo(
      $grpc.ServiceCall call, $0.SendVtxoRequest request);

  $async.Future<$0.RedeemVtxoResponse> redeemVtxo_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RedeemVtxoRequest> $request) async {
    return redeemVtxo($call, await $request);
  }

  $async.Future<$0.RedeemVtxoResponse> redeemVtxo(
      $grpc.ServiceCall call, $0.RedeemVtxoRequest request);

  $async.Future<$0.SettleResponse> settle_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.SettleRequest> $request) async {
    return settle($call, await $request);
  }

  $async.Future<$0.SettleResponse> settle(
      $grpc.ServiceCall call, $0.SettleRequest request);

  $async.Future<$0.SettleDelegateResponse> settleDelegate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SettleDelegateRequest> $request) async {
    return settleDelegate($call, await $request);
  }

  $async.Future<$0.SettleDelegateResponse> settleDelegate(
      $grpc.ServiceCall call, $0.SettleDelegateRequest request);

  $async.Future<$0.SubmitArkSendResponse> submitArkSend_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SubmitArkSendRequest> $request) async {
    return submitArkSend($call, await $request);
  }

  $async.Future<$0.SubmitArkSendResponse> submitArkSend(
      $grpc.ServiceCall call, $0.SubmitArkSendRequest request);

  $async.Future<$0.GetServerInfoResponse> getServerInfo_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetServerInfoRequest> $request) async {
    return getServerInfo($call, await $request);
  }

  $async.Future<$0.GetServerInfoResponse> getServerInfo(
      $grpc.ServiceCall call, $0.GetServerInfoRequest request);

  $async.Future<$0.RegisterDeviceTokenResponse> registerDeviceToken_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RegisterDeviceTokenRequest> $request) async {
    return registerDeviceToken($call, await $request);
  }

  $async.Future<$0.RegisterDeviceTokenResponse> registerDeviceToken(
      $grpc.ServiceCall call, $0.RegisterDeviceTokenRequest request);
}
