/// Abstract interface for the MPC Wallet server API.
///
/// Implemented by [GrpcWalletApi] (gRPC/HTTP2) and [RestWalletApi] (REST/HTTP1.1).
/// This decouples the client business logic from the transport protocol.
library;

import 'package:protocol/protocol.dart';

abstract class WalletApi {
  // DKG
  Future<DKGStep1Response> dKGStep1(DKGStep1Request request);
  Future<DKGStep2Response> dKGStep2(DKGStep2Request request);
  Future<DKGStep3Response> dKGStep3(DKGStep3Request request);

  // Contract eVTXO creation (PEER model): a single key-preserving refresh of V onto
  // {receiver, cosigner}. The receiver later picks up its two ECIES half-shares from
  // its inbox (evtxoPendingShares) and acks them (evtxoAckShare).
  Future<ContractCreateResponse> contractCreate(ContractCreateRequest request);
  Future<EvtxoPendingSharesResponse> evtxoPendingShares(
      EvtxoPendingSharesRequest request);
  Future<EvtxoAckShareResponse> evtxoAckShare(EvtxoAckShareRequest request);

  // Signing
  // [routeGroupKeyHex] overrides the actor the request is routed to (the URL group_key),
  // while `request.userId` stays the signer's auth identity. Used by a contract RECEIVER to
  // route a spend to the eVTXO's `{receiver, cosigner}` pairing actor (keyed by the spk) while
  // authenticating as itself. Null ⇒ route by `request.userId` (the normal case).
  Future<SignStep1Response> signStep1(SignStep1Request request,
      {String? routeGroupKeyHex});
  Future<SignStep2Response> signStep2(SignStep2Request request,
      {String? routeGroupKeyHex});

  // Ark
  Future<GetArkInfoResponse> getArkInfo(GetArkInfoRequest request);
  Future<GetArkAddressResponse> getArkAddress(GetArkAddressRequest request);
  Future<GetBoardingAddressResponse> getBoardingAddress(
      GetBoardingAddressRequest request);
  Future<ListVtxosResponse> listVtxos(ListVtxosRequest request);
  Future<ListArkTransactionsResponse> listArkTransactions(
      ListArkTransactionsRequest request);
  Future<SendVtxoResponse> sendVtxo(SendVtxoRequest request);
  Future<RedeemVtxoResponse> redeemVtxo(RedeemVtxoRequest request);
  Future<SettleResponse> settle(SettleRequest request);
  Future<SettleDelegateResponse> settleDelegate(
      SettleDelegateRequest request);
  Future<SubmitArkSendResponse> submitArkSend(SubmitArkSendRequest request);

  // Deployment metadata. Unauthenticated.
  Future<GetServerInfoResponse> getServerInfo(GetServerInfoRequest request);

  // Push notifications
  Future<RegisterDeviceTokenResponse> registerDeviceToken(
      RegisterDeviceTokenRequest request);

  /// Shutdown the underlying connection.
  Future<void> shutdown();
}
