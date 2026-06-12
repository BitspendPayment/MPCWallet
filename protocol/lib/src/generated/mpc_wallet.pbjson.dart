//
//  Generated code. Do not modify.
//  source: mpc_wallet.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use dKGStep1RequestDescriptor instead')
const DKGStep1Request$json = {
  '1': 'DKGStep1Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
    {'1': 'is_restore', '3': 4, '4': 1, '5': 8, '10': 'isRestore'},
  ],
};

/// Descriptor for `DKGStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep1RequestDescriptor = $convert.base64Decode(
    'Cg9ES0dTdGVwMVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh4KCmlkZW50aWZpZX'
    'IYAiABKAxSCmlkZW50aWZpZXISJQoOcm91bmQxX3BhY2thZ2UYAyABKAlSDXJvdW5kMVBhY2th'
    'Z2USHQoKaXNfcmVzdG9yZRgEIAEoCFIJaXNSZXN0b3Jl');

@$core.Deprecated('Use dKGStep1ResponseDescriptor instead')
const DKGStep1Response$json = {
  '1': 'DKGStep1Response',
  '2': [
    {'1': 'round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep1Response.Round1PackagesEntry', '10': 'round1Packages'},
  ],
  '3': [DKGStep1Response_Round1PackagesEntry$json],
};

@$core.Deprecated('Use dKGStep1ResponseDescriptor instead')
const DKGStep1Response_Round1PackagesEntry$json = {
  '1': 'Round1PackagesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DKGStep1Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep1ResponseDescriptor = $convert.base64Decode(
    'ChBES0dTdGVwMVJlc3BvbnNlElkKD3JvdW5kMV9wYWNrYWdlcxgBIAMoCzIwLm1wY193YWxsZX'
    'QuREtHU3RlcDFSZXNwb25zZS5Sb3VuZDFQYWNrYWdlc0VudHJ5Ug5yb3VuZDFQYWNrYWdlcxpB'
    'ChNSb3VuZDFQYWNrYWdlc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUg'
    'V2YWx1ZToCOAE=');

@$core.Deprecated('Use dKGStep2RequestDescriptor instead')
const DKGStep2Request$json = {
  '1': 'DKGStep2Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
  ],
};

/// Descriptor for `DKGStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep2RequestDescriptor = $convert.base64Decode(
    'Cg9ES0dTdGVwMlJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh4KCmlkZW50aWZpZX'
    'IYAiABKAxSCmlkZW50aWZpZXISJQoOcm91bmQxX3BhY2thZ2UYAyABKAlSDXJvdW5kMVBhY2th'
    'Z2U=');

@$core.Deprecated('Use dKGStep2ResponseDescriptor instead')
const DKGStep2Response$json = {
  '1': 'DKGStep2Response',
  '2': [
    {'1': 'all_round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep2Response.AllRound1PackagesEntry', '10': 'allRound1Packages'},
  ],
  '3': [DKGStep2Response_AllRound1PackagesEntry$json],
};

@$core.Deprecated('Use dKGStep2ResponseDescriptor instead')
const DKGStep2Response_AllRound1PackagesEntry$json = {
  '1': 'AllRound1PackagesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DKGStep2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep2ResponseDescriptor = $convert.base64Decode(
    'ChBES0dTdGVwMlJlc3BvbnNlEmMKE2FsbF9yb3VuZDFfcGFja2FnZXMYASADKAsyMy5tcGNfd2'
    'FsbGV0LkRLR1N0ZXAyUmVzcG9uc2UuQWxsUm91bmQxUGFja2FnZXNFbnRyeVIRYWxsUm91bmQx'
    'UGFja2FnZXMaRAoWQWxsUm91bmQxUGFja2FnZXNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCg'
    'V2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use dKGStep3RequestDescriptor instead')
const DKGStep3Request$json = {
  '1': 'DKGStep3Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round2_packages_for_others', '3': 3, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep3Request.Round2PackagesForOthersEntry', '10': 'round2PackagesForOthers'},
  ],
  '3': [DKGStep3Request_Round2PackagesForOthersEntry$json],
};

@$core.Deprecated('Use dKGStep3RequestDescriptor instead')
const DKGStep3Request_Round2PackagesForOthersEntry$json = {
  '1': 'Round2PackagesForOthersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DKGStep3Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep3RequestDescriptor = $convert.base64Decode(
    'Cg9ES0dTdGVwM1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh4KCmlkZW50aWZpZX'
    'IYAiABKAxSCmlkZW50aWZpZXISdQoacm91bmQyX3BhY2thZ2VzX2Zvcl9vdGhlcnMYAyADKAsy'
    'OC5tcGNfd2FsbGV0LkRLR1N0ZXAzUmVxdWVzdC5Sb3VuZDJQYWNrYWdlc0Zvck90aGVyc0VudH'
    'J5Uhdyb3VuZDJQYWNrYWdlc0Zvck90aGVycxpKChxSb3VuZDJQYWNrYWdlc0Zvck90aGVyc0Vu'
    'dHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use dKGStep3ResponseDescriptor instead')
const DKGStep3Response$json = {
  '1': 'DKGStep3Response',
  '2': [
    {'1': 'round2_packages_for_me', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep3Response.Round2PackagesForMeEntry', '10': 'round2PackagesForMe'},
  ],
  '3': [DKGStep3Response_Round2PackagesForMeEntry$json],
};

@$core.Deprecated('Use dKGStep3ResponseDescriptor instead')
const DKGStep3Response_Round2PackagesForMeEntry$json = {
  '1': 'Round2PackagesForMeEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DKGStep3Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep3ResponseDescriptor = $convert.base64Decode(
    'ChBES0dTdGVwM1Jlc3BvbnNlEmoKFnJvdW5kMl9wYWNrYWdlc19mb3JfbWUYASADKAsyNS5tcG'
    'Nfd2FsbGV0LkRLR1N0ZXAzUmVzcG9uc2UuUm91bmQyUGFja2FnZXNGb3JNZUVudHJ5UhNyb3Vu'
    'ZDJQYWNrYWdlc0Zvck1lGkYKGFJvdW5kMlBhY2thZ2VzRm9yTWVFbnRyeRIQCgNrZXkYASABKA'
    'lSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use signStep1RequestDescriptor instead')
const SignStep1Request$json = {
  '1': 'SignStep1Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'hiding_commitment', '3': 2, '4': 1, '5': 12, '10': 'hidingCommitment'},
    {'1': 'binding_commitment', '3': 3, '4': 1, '5': 12, '10': 'bindingCommitment'},
    {'1': 'message_to_sign', '3': 4, '4': 1, '5': 12, '10': 'messageToSign'},
    {'1': 'signature', '3': 5, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'full_transaction', '3': 6, '4': 1, '5': 12, '10': 'fullTransaction'},
    {'1': 'timestamp_ms', '3': 7, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'script_path_spend', '3': 8, '4': 1, '5': 8, '10': 'scriptPathSpend'},
  ],
};

/// Descriptor for `SignStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep1RequestDescriptor = $convert.base64Decode(
    'ChBTaWduU3RlcDFSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIrChFoaWRpbmdfY2'
    '9tbWl0bWVudBgCIAEoDFIQaGlkaW5nQ29tbWl0bWVudBItChJiaW5kaW5nX2NvbW1pdG1lbnQY'
    'AyABKAxSEWJpbmRpbmdDb21taXRtZW50EiYKD21lc3NhZ2VfdG9fc2lnbhgEIAEoDFINbWVzc2'
    'FnZVRvU2lnbhIcCglzaWduYXR1cmUYBSABKAxSCXNpZ25hdHVyZRIpChBmdWxsX3RyYW5zYWN0'
    'aW9uGAYgASgMUg9mdWxsVHJhbnNhY3Rpb24SIQoMdGltZXN0YW1wX21zGAcgASgDUgt0aW1lc3'
    'RhbXBNcxIqChFzY3JpcHRfcGF0aF9zcGVuZBgIIAEoCFIPc2NyaXB0UGF0aFNwZW5k');

@$core.Deprecated('Use signStep1ResponseDescriptor instead')
const SignStep1Response$json = {
  '1': 'SignStep1Response',
  '2': [
    {'1': 'commitments', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.SignStep1Response.CommitmentsEntry', '10': 'commitments'},
    {'1': 'message_to_sign', '3': 2, '4': 1, '5': 12, '10': 'messageToSign'},
    {'1': 'used_key_index', '3': 3, '4': 1, '5': 5, '10': 'usedKeyIndex'},
  ],
  '3': [SignStep1Response_Commitment$json, SignStep1Response_CommitmentsEntry$json],
};

@$core.Deprecated('Use signStep1ResponseDescriptor instead')
const SignStep1Response_Commitment$json = {
  '1': 'Commitment',
  '2': [
    {'1': 'hiding', '3': 1, '4': 1, '5': 12, '10': 'hiding'},
    {'1': 'binding', '3': 2, '4': 1, '5': 12, '10': 'binding'},
  ],
};

@$core.Deprecated('Use signStep1ResponseDescriptor instead')
const SignStep1Response_CommitmentsEntry$json = {
  '1': 'CommitmentsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.mpc_wallet.SignStep1Response.Commitment', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SignStep1Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep1ResponseDescriptor = $convert.base64Decode(
    'ChFTaWduU3RlcDFSZXNwb25zZRJQCgtjb21taXRtZW50cxgBIAMoCzIuLm1wY193YWxsZXQuU2'
    'lnblN0ZXAxUmVzcG9uc2UuQ29tbWl0bWVudHNFbnRyeVILY29tbWl0bWVudHMSJgoPbWVzc2Fn'
    'ZV90b19zaWduGAIgASgMUg1tZXNzYWdlVG9TaWduEiQKDnVzZWRfa2V5X2luZGV4GAMgASgFUg'
    'x1c2VkS2V5SW5kZXgaPgoKQ29tbWl0bWVudBIWCgZoaWRpbmcYASABKAxSBmhpZGluZxIYCgdi'
    'aW5kaW5nGAIgASgMUgdiaW5kaW5nGmgKEENvbW1pdG1lbnRzRW50cnkSEAoDa2V5GAEgASgJUg'
    'NrZXkSPgoFdmFsdWUYAiABKAsyKC5tcGNfd2FsbGV0LlNpZ25TdGVwMVJlc3BvbnNlLkNvbW1p'
    'dG1lbnRSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use signStep2RequestDescriptor instead')
const SignStep2Request$json = {
  '1': 'SignStep2Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature_share', '3': 3, '4': 1, '5': 12, '10': 'signatureShare'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `SignStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep2RequestDescriptor = $convert.base64Decode(
    'ChBTaWduU3RlcDJSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBInCg9zaWduYXR1cm'
    'Vfc2hhcmUYAyABKAxSDnNpZ25hdHVyZVNoYXJlEhwKCXNpZ25hdHVyZRgEIAEoDFIJc2lnbmF0'
    'dXJlEiEKDHRpbWVzdGFtcF9tcxgFIAEoA1ILdGltZXN0YW1wTXM=');

@$core.Deprecated('Use utxoInfoDescriptor instead')
const UtxoInfo$json = {
  '1': 'UtxoInfo',
  '2': [
    {'1': 'tx_hash', '3': 1, '4': 1, '5': 9, '10': 'txHash'},
    {'1': 'vout', '3': 2, '4': 1, '5': 5, '10': 'vout'},
    {'1': 'amount', '3': 3, '4': 1, '5': 3, '10': 'amount'},
  ],
};

/// Descriptor for `UtxoInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List utxoInfoDescriptor = $convert.base64Decode(
    'CghVdHhvSW5mbxIXCgd0eF9oYXNoGAEgASgJUgZ0eEhhc2gSEgoEdm91dBgCIAEoBVIEdm91dB'
    'IWCgZhbW91bnQYAyABKANSBmFtb3VudA==');

@$core.Deprecated('Use signStep2ResponseDescriptor instead')
const SignStep2Response$json = {
  '1': 'SignStep2Response',
  '2': [
    {'1': 'r_point', '3': 1, '4': 1, '5': 12, '10': 'rPoint'},
    {'1': 'z_scalar', '3': 2, '4': 1, '5': 12, '10': 'zScalar'},
  ],
};

/// Descriptor for `SignStep2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep2ResponseDescriptor = $convert.base64Decode(
    'ChFTaWduU3RlcDJSZXNwb25zZRIXCgdyX3BvaW50GAEgASgMUgZyUG9pbnQSGQoIel9zY2FsYX'
    'IYAiABKAxSB3pTY2FsYXI=');

@$core.Deprecated('Use broadcastTransactionRequestDescriptor instead')
const BroadcastTransactionRequest$json = {
  '1': 'BroadcastTransactionRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'tx_hex', '3': 2, '4': 1, '5': 9, '10': 'txHex'},
  ],
};

/// Descriptor for `BroadcastTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastTransactionRequestDescriptor = $convert.base64Decode(
    'ChtCcm9hZGNhc3RUcmFuc2FjdGlvblJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh'
    'UKBnR4X2hleBgCIAEoCVIFdHhIZXg=');

@$core.Deprecated('Use broadcastTransactionResponseDescriptor instead')
const BroadcastTransactionResponse$json = {
  '1': 'BroadcastTransactionResponse',
  '2': [
    {'1': 'tx_id', '3': 1, '4': 1, '5': 9, '10': 'txId'},
  ],
};

/// Descriptor for `BroadcastTransactionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastTransactionResponseDescriptor = $convert.base64Decode(
    'ChxCcm9hZGNhc3RUcmFuc2FjdGlvblJlc3BvbnNlEhMKBXR4X2lkGAEgASgJUgR0eElk');

@$core.Deprecated('Use fetchHistoryRequestDescriptor instead')
const FetchHistoryRequest$json = {
  '1': 'FetchHistoryRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `FetchHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchHistoryRequestDescriptor = $convert.base64Decode(
    'ChNGZXRjaEhpc3RvcnlSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYX'
    'R1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1z');

@$core.Deprecated('Use fetchHistoryResponseDescriptor instead')
const FetchHistoryResponse$json = {
  '1': 'FetchHistoryResponse',
  '2': [
    {'1': 'utxos', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.UtxoInfo', '10': 'utxos'},
  ],
};

/// Descriptor for `FetchHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchHistoryResponseDescriptor = $convert.base64Decode(
    'ChRGZXRjaEhpc3RvcnlSZXNwb25zZRIqCgV1dHhvcxgBIAMoCzIULm1wY193YWxsZXQuVXR4b0'
    'luZm9SBXV0eG9z');

@$core.Deprecated('Use fetchRecentTransactionsRequestDescriptor instead')
const FetchRecentTransactionsRequest$json = {
  '1': 'FetchRecentTransactionsRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `FetchRecentTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchRecentTransactionsRequestDescriptor = $convert.base64Decode(
    'Ch5GZXRjaFJlY2VudFRyYW5zYWN0aW9uc1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlck'
    'lkEhwKCXNpZ25hdHVyZRgCIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgDIAEoA1IL'
    'dGltZXN0YW1wTXM=');

@$core.Deprecated('Use fetchRecentTransactionsResponseDescriptor instead')
const FetchRecentTransactionsResponse$json = {
  '1': 'FetchRecentTransactionsResponse',
  '2': [
    {'1': 'transactions', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.TransactionSummary', '10': 'transactions'},
  ],
};

/// Descriptor for `FetchRecentTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchRecentTransactionsResponseDescriptor = $convert.base64Decode(
    'Ch9GZXRjaFJlY2VudFRyYW5zYWN0aW9uc1Jlc3BvbnNlEkIKDHRyYW5zYWN0aW9ucxgBIAMoCz'
    'IeLm1wY193YWxsZXQuVHJhbnNhY3Rpb25TdW1tYXJ5Ugx0cmFuc2FjdGlvbnM=');

@$core.Deprecated('Use transactionSummaryDescriptor instead')
const TransactionSummary$json = {
  '1': 'TransactionSummary',
  '2': [
    {'1': 'tx_hash', '3': 1, '4': 1, '5': 9, '10': 'txHash'},
    {'1': 'amount_sats', '3': 2, '4': 1, '5': 3, '10': 'amountSats'},
    {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'is_pending', '3': 4, '4': 1, '5': 8, '10': 'isPending'},
  ],
};

/// Descriptor for `TransactionSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionSummaryDescriptor = $convert.base64Decode(
    'ChJUcmFuc2FjdGlvblN1bW1hcnkSFwoHdHhfaGFzaBgBIAEoCVIGdHhIYXNoEh8KC2Ftb3VudF'
    '9zYXRzGAIgASgDUgphbW91bnRTYXRzEhwKCXRpbWVzdGFtcBgDIAEoA1IJdGltZXN0YW1wEh0K'
    'CmlzX3BlbmRpbmcYBCABKAhSCWlzUGVuZGluZw==');

@$core.Deprecated('Use subscribeToHistoryRequestDescriptor instead')
const SubscribeToHistoryRequest$json = {
  '1': 'SubscribeToHistoryRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `SubscribeToHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeToHistoryRequestDescriptor = $convert.base64Decode(
    'ChlTdWJzY3JpYmVUb0hpc3RvcnlSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCg'
    'lzaWduYXR1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVz'
    'dGFtcE1z');

@$core.Deprecated('Use transactionNotificationDescriptor instead')
const TransactionNotification$json = {
  '1': 'TransactionNotification',
  '2': [
    {'1': 'tx_hash', '3': 1, '4': 1, '5': 9, '10': 'txHash'},
    {'1': 'height', '3': 2, '4': 1, '5': 5, '10': 'height'},
    {'1': 'added_utxos', '3': 3, '4': 3, '5': 11, '6': '.mpc_wallet.UtxoInfo', '10': 'addedUtxos'},
    {'1': 'spent_utxos', '3': 4, '4': 3, '5': 11, '6': '.mpc_wallet.UtxoInfo', '10': 'spentUtxos'},
  ],
};

/// Descriptor for `TransactionNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionNotificationDescriptor = $convert.base64Decode(
    'ChdUcmFuc2FjdGlvbk5vdGlmaWNhdGlvbhIXCgd0eF9oYXNoGAEgASgJUgZ0eEhhc2gSFgoGaG'
    'VpZ2h0GAIgASgFUgZoZWlnaHQSNQoLYWRkZWRfdXR4b3MYAyADKAsyFC5tcGNfd2FsbGV0LlV0'
    'eG9JbmZvUgphZGRlZFV0eG9zEjUKC3NwZW50X3V0eG9zGAQgAygLMhQubXBjX3dhbGxldC5VdH'
    'hvSW5mb1IKc3BlbnRVdHhvcw==');

@$core.Deprecated('Use getArkInfoRequestDescriptor instead')
const GetArkInfoRequest$json = {
  '1': 'GetArkInfoRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `GetArkInfoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkInfoRequestDescriptor = $convert.base64Decode(
    'ChFHZXRBcmtJbmZvUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHAoJc2lnbmF0dX'
    'JlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1lc3RhbXBNcw==');

@$core.Deprecated('Use getArkInfoResponseDescriptor instead')
const GetArkInfoResponse$json = {
  '1': 'GetArkInfoResponse',
  '2': [
    {'1': 'signer_pubkey', '3': 1, '4': 1, '5': 9, '10': 'signerPubkey'},
    {'1': 'forfeit_pubkey', '3': 2, '4': 1, '5': 9, '10': 'forfeitPubkey'},
    {'1': 'network', '3': 3, '4': 1, '5': 9, '10': 'network'},
    {'1': 'session_duration', '3': 4, '4': 1, '5': 3, '10': 'sessionDuration'},
    {'1': 'unilateral_exit_delay', '3': 5, '4': 1, '5': 3, '10': 'unilateralExitDelay'},
    {'1': 'boarding_exit_delay', '3': 6, '4': 1, '5': 3, '10': 'boardingExitDelay'},
    {'1': 'vtxo_min_amount', '3': 7, '4': 1, '5': 3, '10': 'vtxoMinAmount'},
    {'1': 'dust', '3': 8, '4': 1, '5': 3, '10': 'dust'},
    {'1': 'checkpoint_tapscript', '3': 9, '4': 1, '5': 9, '10': 'checkpointTapscript'},
    {'1': 'forfeit_address', '3': 10, '4': 1, '5': 9, '10': 'forfeitAddress'},
    {'1': 'auto_settle_safety_margin_secs', '3': 11, '4': 1, '5': 3, '10': 'autoSettleSafetyMarginSecs'},
  ],
};

/// Descriptor for `GetArkInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkInfoResponseDescriptor = $convert.base64Decode(
    'ChJHZXRBcmtJbmZvUmVzcG9uc2USIwoNc2lnbmVyX3B1YmtleRgBIAEoCVIMc2lnbmVyUHVia2'
    'V5EiUKDmZvcmZlaXRfcHVia2V5GAIgASgJUg1mb3JmZWl0UHVia2V5EhgKB25ldHdvcmsYAyAB'
    'KAlSB25ldHdvcmsSKQoQc2Vzc2lvbl9kdXJhdGlvbhgEIAEoA1IPc2Vzc2lvbkR1cmF0aW9uEj'
    'IKFXVuaWxhdGVyYWxfZXhpdF9kZWxheRgFIAEoA1ITdW5pbGF0ZXJhbEV4aXREZWxheRIuChNi'
    'b2FyZGluZ19leGl0X2RlbGF5GAYgASgDUhFib2FyZGluZ0V4aXREZWxheRImCg92dHhvX21pbl'
    '9hbW91bnQYByABKANSDXZ0eG9NaW5BbW91bnQSEgoEZHVzdBgIIAEoA1IEZHVzdBIxChRjaGVj'
    'a3BvaW50X3RhcHNjcmlwdBgJIAEoCVITY2hlY2twb2ludFRhcHNjcmlwdBInCg9mb3JmZWl0X2'
    'FkZHJlc3MYCiABKAlSDmZvcmZlaXRBZGRyZXNzEkIKHmF1dG9fc2V0dGxlX3NhZmV0eV9tYXJn'
    'aW5fc2VjcxgLIAEoA1IaYXV0b1NldHRsZVNhZmV0eU1hcmdpblNlY3M=');

@$core.Deprecated('Use getArkAddressRequestDescriptor instead')
const GetArkAddressRequest$json = {
  '1': 'GetArkAddressRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `GetArkAddressRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkAddressRequestDescriptor = $convert.base64Decode(
    'ChRHZXRBcmtBZGRyZXNzUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHAoJc2lnbm'
    'F0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1lc3RhbXBN'
    'cw==');

@$core.Deprecated('Use getArkAddressResponseDescriptor instead')
const GetArkAddressResponse$json = {
  '1': 'GetArkAddressResponse',
  '2': [
    {'1': 'ark_address', '3': 1, '4': 1, '5': 9, '10': 'arkAddress'},
  ],
};

/// Descriptor for `GetArkAddressResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkAddressResponseDescriptor = $convert.base64Decode(
    'ChVHZXRBcmtBZGRyZXNzUmVzcG9uc2USHwoLYXJrX2FkZHJlc3MYASABKAlSCmFya0FkZHJlc3'
    'M=');

@$core.Deprecated('Use getBoardingAddressRequestDescriptor instead')
const GetBoardingAddressRequest$json = {
  '1': 'GetBoardingAddressRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `GetBoardingAddressRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBoardingAddressRequestDescriptor = $convert.base64Decode(
    'ChlHZXRCb2FyZGluZ0FkZHJlc3NSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCg'
    'lzaWduYXR1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVz'
    'dGFtcE1z');

@$core.Deprecated('Use getBoardingAddressResponseDescriptor instead')
const GetBoardingAddressResponse$json = {
  '1': 'GetBoardingAddressResponse',
  '2': [
    {'1': 'boarding_address', '3': 1, '4': 1, '5': 9, '10': 'boardingAddress'},
  ],
};

/// Descriptor for `GetBoardingAddressResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBoardingAddressResponseDescriptor = $convert.base64Decode(
    'ChpHZXRCb2FyZGluZ0FkZHJlc3NSZXNwb25zZRIpChBib2FyZGluZ19hZGRyZXNzGAEgASgJUg'
    '9ib2FyZGluZ0FkZHJlc3M=');

@$core.Deprecated('Use vtxoInfoDescriptor instead')
const VtxoInfo$json = {
  '1': 'VtxoInfo',
  '2': [
    {'1': 'txid', '3': 1, '4': 1, '5': 9, '10': 'txid'},
    {'1': 'vout', '3': 2, '4': 1, '5': 13, '10': 'vout'},
    {'1': 'amount', '3': 3, '4': 1, '5': 4, '10': 'amount'},
    {'1': 'created_at', '3': 4, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'expires_at', '3': 5, '4': 1, '5': 3, '10': 'expiresAt'},
    {'1': 'status', '3': 6, '4': 1, '5': 9, '10': 'status'},
    {'1': 'is_preconfirmed', '3': 7, '4': 1, '5': 8, '10': 'isPreconfirmed'},
    {'1': 'exit_delay', '3': 8, '4': 1, '5': 13, '10': 'exitDelay'},
    {'1': 'script', '3': 9, '4': 1, '5': 9, '10': 'script'},
  ],
};

/// Descriptor for `VtxoInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vtxoInfoDescriptor = $convert.base64Decode(
    'CghWdHhvSW5mbxISCgR0eGlkGAEgASgJUgR0eGlkEhIKBHZvdXQYAiABKA1SBHZvdXQSFgoGYW'
    '1vdW50GAMgASgEUgZhbW91bnQSHQoKY3JlYXRlZF9hdBgEIAEoA1IJY3JlYXRlZEF0Eh0KCmV4'
    'cGlyZXNfYXQYBSABKANSCWV4cGlyZXNBdBIWCgZzdGF0dXMYBiABKAlSBnN0YXR1cxInCg9pc1'
    '9wcmVjb25maXJtZWQYByABKAhSDmlzUHJlY29uZmlybWVkEh0KCmV4aXRfZGVsYXkYCCABKA1S'
    'CWV4aXREZWxheRIWCgZzY3JpcHQYCSABKAlSBnNjcmlwdA==');

@$core.Deprecated('Use listVtxosRequestDescriptor instead')
const ListVtxosRequest$json = {
  '1': 'ListVtxosRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `ListVtxosRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listVtxosRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0VnR4b3NSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYXR1cm'
    'UYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1z');

@$core.Deprecated('Use listVtxosResponseDescriptor instead')
const ListVtxosResponse$json = {
  '1': 'ListVtxosResponse',
  '2': [
    {'1': 'vtxos', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.VtxoInfo', '10': 'vtxos'},
    {'1': 'total_balance', '3': 2, '4': 1, '5': 4, '10': 'totalBalance'},
    {'1': 'has_active_delegate', '3': 3, '4': 1, '5': 8, '10': 'hasActiveDelegate'},
  ],
};

/// Descriptor for `ListVtxosResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listVtxosResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0VnR4b3NSZXNwb25zZRIqCgV2dHhvcxgBIAMoCzIULm1wY193YWxsZXQuVnR4b0luZm'
    '9SBXZ0eG9zEiMKDXRvdGFsX2JhbGFuY2UYAiABKARSDHRvdGFsQmFsYW5jZRIuChNoYXNfYWN0'
    'aXZlX2RlbGVnYXRlGAMgASgIUhFoYXNBY3RpdmVEZWxlZ2F0ZQ==');

@$core.Deprecated('Use checkBoardingBalanceRequestDescriptor instead')
const CheckBoardingBalanceRequest$json = {
  '1': 'CheckBoardingBalanceRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `CheckBoardingBalanceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkBoardingBalanceRequestDescriptor = $convert.base64Decode(
    'ChtDaGVja0JvYXJkaW5nQmFsYW5jZVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh'
    'wKCXNpZ25hdHVyZRgCIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgDIAEoA1ILdGlt'
    'ZXN0YW1wTXM=');

@$core.Deprecated('Use checkBoardingBalanceResponseDescriptor instead')
const CheckBoardingBalanceResponse$json = {
  '1': 'CheckBoardingBalanceResponse',
  '2': [
    {'1': 'balance', '3': 1, '4': 1, '5': 4, '10': 'balance'},
    {'1': 'utxo_count', '3': 2, '4': 1, '5': 13, '10': 'utxoCount'},
  ],
};

/// Descriptor for `CheckBoardingBalanceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkBoardingBalanceResponseDescriptor = $convert.base64Decode(
    'ChxDaGVja0JvYXJkaW5nQmFsYW5jZVJlc3BvbnNlEhgKB2JhbGFuY2UYASABKARSB2JhbGFuY2'
    'USHQoKdXR4b19jb3VudBgCIAEoDVIJdXR4b0NvdW50');

@$core.Deprecated('Use arkTransactionSummaryDescriptor instead')
const ArkTransactionSummary$json = {
  '1': 'ArkTransactionSummary',
  '2': [
    {'1': 'tx_type', '3': 1, '4': 1, '5': 9, '10': 'txType'},
    {'1': 'amount_sats', '3': 2, '4': 1, '5': 3, '10': 'amountSats'},
    {'1': 'txid', '3': 3, '4': 1, '5': 9, '10': 'txid'},
    {'1': 'timestamp', '3': 4, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `ArkTransactionSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arkTransactionSummaryDescriptor = $convert.base64Decode(
    'ChVBcmtUcmFuc2FjdGlvblN1bW1hcnkSFwoHdHhfdHlwZRgBIAEoCVIGdHhUeXBlEh8KC2Ftb3'
    'VudF9zYXRzGAIgASgDUgphbW91bnRTYXRzEhIKBHR4aWQYAyABKAlSBHR4aWQSHAoJdGltZXN0'
    'YW1wGAQgASgDUgl0aW1lc3RhbXA=');

@$core.Deprecated('Use listArkTransactionsRequestDescriptor instead')
const ListArkTransactionsRequest$json = {
  '1': 'ListArkTransactionsRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `ListArkTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listArkTransactionsRequestDescriptor = $convert.base64Decode(
    'ChpMaXN0QXJrVHJhbnNhY3Rpb25zUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHA'
    'oJc2lnbmF0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1l'
    'c3RhbXBNcw==');

@$core.Deprecated('Use listArkTransactionsResponseDescriptor instead')
const ListArkTransactionsResponse$json = {
  '1': 'ListArkTransactionsResponse',
  '2': [
    {'1': 'transactions', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.ArkTransactionSummary', '10': 'transactions'},
  ],
};

/// Descriptor for `ListArkTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listArkTransactionsResponseDescriptor = $convert.base64Decode(
    'ChtMaXN0QXJrVHJhbnNhY3Rpb25zUmVzcG9uc2USRQoMdHJhbnNhY3Rpb25zGAEgAygLMiEubX'
    'BjX3dhbGxldC5BcmtUcmFuc2FjdGlvblN1bW1hcnlSDHRyYW5zYWN0aW9ucw==');

@$core.Deprecated('Use sendVtxoRequestDescriptor instead')
const SendVtxoRequest$json = {
  '1': 'SendVtxoRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'recipient_ark_address', '3': 2, '4': 1, '5': 9, '10': 'recipientArkAddress'},
    {'1': 'amount', '3': 3, '4': 1, '5': 4, '10': 'amount'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'signed_messages', '3': 6, '4': 3, '5': 12, '10': 'signedMessages'},
  ],
};

/// Descriptor for `SendVtxoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendVtxoRequestDescriptor = $convert.base64Decode(
    'Cg9TZW5kVnR4b1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEjIKFXJlY2lwaWVudF'
    '9hcmtfYWRkcmVzcxgCIAEoCVITcmVjaXBpZW50QXJrQWRkcmVzcxIWCgZhbW91bnQYAyABKARS'
    'BmFtb3VudBIcCglzaWduYXR1cmUYBCABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYBS'
    'ABKANSC3RpbWVzdGFtcE1zEicKD3NpZ25lZF9tZXNzYWdlcxgGIAMoDFIOc2lnbmVkTWVzc2Fn'
    'ZXM=');

@$core.Deprecated('Use sendVtxoResponseDescriptor instead')
const SendVtxoResponse$json = {
  '1': 'SendVtxoResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 14, '6': '.mpc_wallet.SendVtxoResponse.Status', '10': 'status'},
    {'1': 'messages_to_sign', '3': 2, '4': 3, '5': 12, '10': 'messagesToSign'},
    {'1': 'script_path_spend', '3': 3, '4': 1, '5': 8, '10': 'scriptPathSpend'},
    {'1': 'ark_txid', '3': 4, '4': 1, '5': 9, '10': 'arkTxid'},
    {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
  '4': [SendVtxoResponse_Status$json],
};

@$core.Deprecated('Use sendVtxoResponseDescriptor instead')
const SendVtxoResponse_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'SIGNING_REQUIRED', '2': 0},
    {'1': 'SETTLED', '2': 1},
    {'1': 'ERROR', '2': 2},
  ],
};

/// Descriptor for `SendVtxoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendVtxoResponseDescriptor = $convert.base64Decode(
    'ChBTZW5kVnR4b1Jlc3BvbnNlEjsKBnN0YXR1cxgBIAEoDjIjLm1wY193YWxsZXQuU2VuZFZ0eG'
    '9SZXNwb25zZS5TdGF0dXNSBnN0YXR1cxIoChBtZXNzYWdlc190b19zaWduGAIgAygMUg5tZXNz'
    'YWdlc1RvU2lnbhIqChFzY3JpcHRfcGF0aF9zcGVuZBgDIAEoCFIPc2NyaXB0UGF0aFNwZW5kEh'
    'kKCGFya190eGlkGAQgASgJUgdhcmtUeGlkEiMKDWVycm9yX21lc3NhZ2UYBSABKAlSDGVycm9y'
    'TWVzc2FnZSI2CgZTdGF0dXMSFAoQU0lHTklOR19SRVFVSVJFRBAAEgsKB1NFVFRMRUQQARIJCg'
    'VFUlJPUhAC');

@$core.Deprecated('Use redeemVtxoRequestDescriptor instead')
const RedeemVtxoRequest$json = {
  '1': 'RedeemVtxoRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'on_chain_address', '3': 2, '4': 1, '5': 9, '10': 'onChainAddress'},
    {'1': 'amount', '3': 3, '4': 1, '5': 4, '10': 'amount'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `RedeemVtxoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redeemVtxoRequestDescriptor = $convert.base64Decode(
    'ChFSZWRlZW1WdHhvUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSKAoQb25fY2hhaW'
    '5fYWRkcmVzcxgCIAEoCVIOb25DaGFpbkFkZHJlc3MSFgoGYW1vdW50GAMgASgEUgZhbW91bnQS'
    'HAoJc2lnbmF0dXJlGAQgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAUgASgDUgt0aW'
    '1lc3RhbXBNcw==');

@$core.Deprecated('Use redeemVtxoResponseDescriptor instead')
const RedeemVtxoResponse$json = {
  '1': 'RedeemVtxoResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'txid', '3': 2, '4': 1, '5': 9, '10': 'txid'},
  ],
};

/// Descriptor for `RedeemVtxoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redeemVtxoResponseDescriptor = $convert.base64Decode(
    'ChJSZWRlZW1WdHhvUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxISCgR0eGlkGA'
    'IgASgJUgR0eGlk');

@$core.Deprecated('Use settleRequestDescriptor instead')
const SettleRequest$json = {
  '1': 'SettleRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'signed_messages', '3': 4, '4': 3, '5': 12, '10': 'signedMessages'},
  ],
};

/// Descriptor for `SettleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleRequestDescriptor = $convert.base64Decode(
    'Cg1TZXR0bGVSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYXR1cmUYAi'
    'ABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1zEicKD3Np'
    'Z25lZF9tZXNzYWdlcxgEIAMoDFIOc2lnbmVkTWVzc2FnZXM=');

@$core.Deprecated('Use settleResponseDescriptor instead')
const SettleResponse$json = {
  '1': 'SettleResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 14, '6': '.mpc_wallet.SettleResponse.Status', '10': 'status'},
    {'1': 'messages_to_sign', '3': 2, '4': 3, '5': 12, '10': 'messagesToSign'},
    {'1': 'script_path_spend', '3': 3, '4': 1, '5': 8, '10': 'scriptPathSpend'},
    {'1': 'commitment_txid', '3': 4, '4': 1, '5': 9, '10': 'commitmentTxid'},
    {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
  '4': [SettleResponse_Status$json],
};

@$core.Deprecated('Use settleResponseDescriptor instead')
const SettleResponse_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'SIGNING_REQUIRED', '2': 0},
    {'1': 'WAITING_FOR_BATCH', '2': 1},
    {'1': 'SETTLED', '2': 2},
    {'1': 'ERROR', '2': 3},
  ],
};

/// Descriptor for `SettleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleResponseDescriptor = $convert.base64Decode(
    'Cg5TZXR0bGVSZXNwb25zZRI5CgZzdGF0dXMYASABKA4yIS5tcGNfd2FsbGV0LlNldHRsZVJlc3'
    'BvbnNlLlN0YXR1c1IGc3RhdHVzEigKEG1lc3NhZ2VzX3RvX3NpZ24YAiADKAxSDm1lc3NhZ2Vz'
    'VG9TaWduEioKEXNjcmlwdF9wYXRoX3NwZW5kGAMgASgIUg9zY3JpcHRQYXRoU3BlbmQSJwoPY2'
    '9tbWl0bWVudF90eGlkGAQgASgJUg5jb21taXRtZW50VHhpZBIjCg1lcnJvcl9tZXNzYWdlGAUg'
    'ASgJUgxlcnJvck1lc3NhZ2UiTQoGU3RhdHVzEhQKEFNJR05JTkdfUkVRVUlSRUQQABIVChFXQU'
    'lUSU5HX0ZPUl9CQVRDSBABEgsKB1NFVFRMRUQQAhIJCgVFUlJPUhAD');

@$core.Deprecated('Use settleDelegateRequestDescriptor instead')
const SettleDelegateRequest$json = {
  '1': 'SettleDelegateRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'signed_messages', '3': 4, '4': 3, '5': 12, '10': 'signedMessages'},
    {'1': 'store_only', '3': 5, '4': 1, '5': 8, '10': 'storeOnly'},
  ],
};

/// Descriptor for `SettleDelegateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleDelegateRequestDescriptor = $convert.base64Decode(
    'ChVTZXR0bGVEZWxlZ2F0ZVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEhwKCXNpZ2'
    '5hdHVyZRgCIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgDIAEoA1ILdGltZXN0YW1w'
    'TXMSJwoPc2lnbmVkX21lc3NhZ2VzGAQgAygMUg5zaWduZWRNZXNzYWdlcxIdCgpzdG9yZV9vbm'
    'x5GAUgASgIUglzdG9yZU9ubHk=');

@$core.Deprecated('Use settleDelegateResponseDescriptor instead')
const SettleDelegateResponse$json = {
  '1': 'SettleDelegateResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 14, '6': '.mpc_wallet.SettleDelegateResponse.Status', '10': 'status'},
    {'1': 'messages_to_sign', '3': 2, '4': 3, '5': 12, '10': 'messagesToSign'},
    {'1': 'script_path_spend', '3': 3, '4': 1, '5': 8, '10': 'scriptPathSpend'},
    {'1': 'commitment_txid', '3': 4, '4': 1, '5': 9, '10': 'commitmentTxid'},
    {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
  '4': [SettleDelegateResponse_Status$json],
};

@$core.Deprecated('Use settleDelegateResponseDescriptor instead')
const SettleDelegateResponse_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'SIGNING_REQUIRED', '2': 0},
    {'1': 'SETTLED', '2': 1},
    {'1': 'ERROR', '2': 2},
    {'1': 'DELEGATED', '2': 3},
  ],
};

/// Descriptor for `SettleDelegateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleDelegateResponseDescriptor = $convert.base64Decode(
    'ChZTZXR0bGVEZWxlZ2F0ZVJlc3BvbnNlEkEKBnN0YXR1cxgBIAEoDjIpLm1wY193YWxsZXQuU2'
    'V0dGxlRGVsZWdhdGVSZXNwb25zZS5TdGF0dXNSBnN0YXR1cxIoChBtZXNzYWdlc190b19zaWdu'
    'GAIgAygMUg5tZXNzYWdlc1RvU2lnbhIqChFzY3JpcHRfcGF0aF9zcGVuZBgDIAEoCFIPc2NyaX'
    'B0UGF0aFNwZW5kEicKD2NvbW1pdG1lbnRfdHhpZBgEIAEoCVIOY29tbWl0bWVudFR4aWQSIwoN'
    'ZXJyb3JfbWVzc2FnZRgFIAEoCVIMZXJyb3JNZXNzYWdlIkUKBlN0YXR1cxIUChBTSUdOSU5HX1'
    'JFUVVJUkVEEAASCwoHU0VUVExFRBABEgkKBUVSUk9SEAISDQoJREVMRUdBVEVEEAM=');

@$core.Deprecated('Use submitArkSendRequestDescriptor instead')
const SubmitArkSendRequest$json = {
  '1': 'SubmitArkSendRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'signed_ark_tx_b64', '3': 4, '4': 1, '5': 9, '10': 'signedArkTxB64'},
    {'1': 'signed_checkpoint_txs_b64', '3': 5, '4': 3, '5': 9, '10': 'signedCheckpointTxsB64'},
    {'1': 'spent_outpoints', '3': 6, '4': 3, '5': 9, '10': 'spentOutpoints'},
  ],
};

/// Descriptor for `SubmitArkSendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitArkSendRequestDescriptor = $convert.base64Decode(
    'ChRTdWJtaXRBcmtTZW5kUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHAoJc2lnbm'
    'F0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1lc3RhbXBN'
    'cxIpChFzaWduZWRfYXJrX3R4X2I2NBgEIAEoCVIOc2lnbmVkQXJrVHhCNjQSOQoZc2lnbmVkX2'
    'NoZWNrcG9pbnRfdHhzX2I2NBgFIAMoCVIWc2lnbmVkQ2hlY2twb2ludFR4c0I2NBInCg9zcGVu'
    'dF9vdXRwb2ludHMYBiADKAlSDnNwZW50T3V0cG9pbnRz');

@$core.Deprecated('Use submitArkSendResponseDescriptor instead')
const SubmitArkSendResponse$json = {
  '1': 'SubmitArkSendResponse',
  '2': [
    {'1': 'ark_txid', '3': 1, '4': 1, '5': 9, '10': 'arkTxid'},
    {'1': 'change_txid', '3': 2, '4': 1, '5': 9, '10': 'changeTxid'},
    {'1': 'change_vout', '3': 3, '4': 1, '5': 13, '10': 'changeVout'},
    {'1': 'change_amount', '3': 4, '4': 1, '5': 4, '10': 'changeAmount'},
  ],
};

/// Descriptor for `SubmitArkSendResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitArkSendResponseDescriptor = $convert.base64Decode(
    'ChVTdWJtaXRBcmtTZW5kUmVzcG9uc2USGQoIYXJrX3R4aWQYASABKAlSB2Fya1R4aWQSHwoLY2'
    'hhbmdlX3R4aWQYAiABKAlSCmNoYW5nZVR4aWQSHwoLY2hhbmdlX3ZvdXQYAyABKA1SCmNoYW5n'
    'ZVZvdXQSIwoNY2hhbmdlX2Ftb3VudBgEIAEoBFIMY2hhbmdlQW1vdW50');

@$core.Deprecated('Use getServerInfoRequestDescriptor instead')
const GetServerInfoRequest$json = {
  '1': 'GetServerInfoRequest',
};

/// Descriptor for `GetServerInfoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getServerInfoRequestDescriptor = $convert.base64Decode(
    'ChRHZXRTZXJ2ZXJJbmZvUmVxdWVzdA==');

@$core.Deprecated('Use getServerInfoResponseDescriptor instead')
const GetServerInfoResponse$json = {
  '1': 'GetServerInfoResponse',
  '2': [
    {'1': 'bitcoin_network', '3': 1, '4': 1, '5': 9, '10': 'bitcoinNetwork'},
  ],
};

/// Descriptor for `GetServerInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getServerInfoResponseDescriptor = $convert.base64Decode(
    'ChVHZXRTZXJ2ZXJJbmZvUmVzcG9uc2USJwoPYml0Y29pbl9uZXR3b3JrGAEgASgJUg5iaXRjb2'
    'luTmV0d29yaw==');

@$core.Deprecated('Use registerDeviceTokenRequestDescriptor instead')
const RegisterDeviceTokenRequest$json = {
  '1': 'RegisterDeviceTokenRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'fcm_token', '3': 4, '4': 1, '5': 9, '10': 'fcmToken'},
    {'1': 'platform', '3': 5, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'app_version', '3': 6, '4': 1, '5': 9, '10': 'appVersion'},
  ],
};

/// Descriptor for `RegisterDeviceTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceTokenRequestDescriptor = $convert.base64Decode(
    'ChpSZWdpc3RlckRldmljZVRva2VuUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHA'
    'oJc2lnbmF0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1l'
    'c3RhbXBNcxIbCglmY21fdG9rZW4YBCABKAlSCGZjbVRva2VuEhoKCHBsYXRmb3JtGAUgASgJUg'
    'hwbGF0Zm9ybRIfCgthcHBfdmVyc2lvbhgGIAEoCVIKYXBwVmVyc2lvbg==');

@$core.Deprecated('Use registerDeviceTokenResponseDescriptor instead')
const RegisterDeviceTokenResponse$json = {
  '1': 'RegisterDeviceTokenResponse',
  '2': [
    {'1': 'ok', '3': 1, '4': 1, '5': 8, '10': 'ok'},
  ],
};

/// Descriptor for `RegisterDeviceTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceTokenResponseDescriptor = $convert.base64Decode(
    'ChtSZWdpc3RlckRldmljZVRva2VuUmVzcG9uc2USDgoCb2sYASABKAhSAm9r');

@$core.Deprecated('Use evtxoKeygenStep1RequestDescriptor instead')
const EvtxoKeygenStep1Request$json = {
  '1': 'EvtxoKeygenStep1Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
    {'1': 'contract_id', '3': 4, '4': 1, '5': 12, '10': 'contractId'},
    {'1': 'signature', '3': 5, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 6, '4': 1, '5': 3, '10': 'timestampMs'},
    {'1': 'server_pk', '3': 7, '4': 1, '5': 12, '10': 'serverPk'},
    {'1': 'exit_delay', '3': 8, '4': 1, '5': 13, '10': 'exitDelay'},
    {'1': 'contract_wasm', '3': 9, '4': 1, '5': 12, '10': 'contractWasm'},
  ],
};

/// Descriptor for `EvtxoKeygenStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List evtxoKeygenStep1RequestDescriptor = $convert.base64Decode(
    'ChdFdnR4b0tleWdlblN0ZXAxUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHgoKaW'
    'RlbnRpZmllchgCIAEoDFIKaWRlbnRpZmllchIlCg5yb3VuZDFfcGFja2FnZRgDIAEoCVINcm91'
    'bmQxUGFja2FnZRIfCgtjb250cmFjdF9pZBgEIAEoDFIKY29udHJhY3RJZBIcCglzaWduYXR1cm'
    'UYBSABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYBiABKANSC3RpbWVzdGFtcE1zEhsK'
    'CXNlcnZlcl9waxgHIAEoDFIIc2VydmVyUGsSHQoKZXhpdF9kZWxheRgIIAEoDVIJZXhpdERlbG'
    'F5EiMKDWNvbnRyYWN0X3dhc20YCSABKAxSDGNvbnRyYWN0V2FzbQ==');

@$core.Deprecated('Use evtxoKeygenStep1ResponseDescriptor instead')
const EvtxoKeygenStep1Response$json = {
  '1': 'EvtxoKeygenStep1Response',
  '2': [
    {'1': 'round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.EvtxoKeygenStep1Response.Round1PackagesEntry', '10': 'round1Packages'},
    {'1': 'evtxo_script_pubkey', '3': 2, '4': 1, '5': 12, '10': 'evtxoScriptPubkey'},
  ],
  '3': [EvtxoKeygenStep1Response_Round1PackagesEntry$json],
};

@$core.Deprecated('Use evtxoKeygenStep1ResponseDescriptor instead')
const EvtxoKeygenStep1Response_Round1PackagesEntry$json = {
  '1': 'Round1PackagesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `EvtxoKeygenStep1Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List evtxoKeygenStep1ResponseDescriptor = $convert.base64Decode(
    'ChhFdnR4b0tleWdlblN0ZXAxUmVzcG9uc2USYQoPcm91bmQxX3BhY2thZ2VzGAEgAygLMjgubX'
    'BjX3dhbGxldC5FdnR4b0tleWdlblN0ZXAxUmVzcG9uc2UuUm91bmQxUGFja2FnZXNFbnRyeVIO'
    'cm91bmQxUGFja2FnZXMSLgoTZXZ0eG9fc2NyaXB0X3B1YmtleRgCIAEoDFIRZXZ0eG9TY3JpcH'
    'RQdWJrZXkaQQoTUm91bmQxUGFja2FnZXNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1'
    'ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use evtxoKeygenStep2RequestDescriptor instead')
const EvtxoKeygenStep2Request$json = {
  '1': 'EvtxoKeygenStep2Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `EvtxoKeygenStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List evtxoKeygenStep2RequestDescriptor = $convert.base64Decode(
    'ChdFdnR4b0tleWdlblN0ZXAyUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHgoKaW'
    'RlbnRpZmllchgCIAEoDFIKaWRlbnRpZmllchIlCg5yb3VuZDFfcGFja2FnZRgDIAEoCVINcm91'
    'bmQxUGFja2FnZRIcCglzaWduYXR1cmUYBCABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbX'
    'MYBSABKANSC3RpbWVzdGFtcE1z');

@$core.Deprecated('Use evtxoKeygenStep2ResponseDescriptor instead')
const EvtxoKeygenStep2Response$json = {
  '1': 'EvtxoKeygenStep2Response',
  '2': [
    {'1': 'all_round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.EvtxoKeygenStep2Response.AllRound1PackagesEntry', '10': 'allRound1Packages'},
  ],
  '3': [EvtxoKeygenStep2Response_AllRound1PackagesEntry$json],
};

@$core.Deprecated('Use evtxoKeygenStep2ResponseDescriptor instead')
const EvtxoKeygenStep2Response_AllRound1PackagesEntry$json = {
  '1': 'AllRound1PackagesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `EvtxoKeygenStep2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List evtxoKeygenStep2ResponseDescriptor = $convert.base64Decode(
    'ChhFdnR4b0tleWdlblN0ZXAyUmVzcG9uc2USawoTYWxsX3JvdW5kMV9wYWNrYWdlcxgBIAMoCz'
    'I7Lm1wY193YWxsZXQuRXZ0eG9LZXlnZW5TdGVwMlJlc3BvbnNlLkFsbFJvdW5kMVBhY2thZ2Vz'
    'RW50cnlSEWFsbFJvdW5kMVBhY2thZ2VzGkQKFkFsbFJvdW5kMVBhY2thZ2VzRW50cnkSEAoDa2'
    'V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use evtxoKeygenStep3RequestDescriptor instead')
const EvtxoKeygenStep3Request$json = {
  '1': 'EvtxoKeygenStep3Request',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round2_packages_for_others', '3': 3, '4': 3, '5': 11, '6': '.mpc_wallet.EvtxoKeygenStep3Request.Round2PackagesForOthersEntry', '10': 'round2PackagesForOthers'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
  '3': [EvtxoKeygenStep3Request_Round2PackagesForOthersEntry$json],
};

@$core.Deprecated('Use evtxoKeygenStep3RequestDescriptor instead')
const EvtxoKeygenStep3Request_Round2PackagesForOthersEntry$json = {
  '1': 'Round2PackagesForOthersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `EvtxoKeygenStep3Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List evtxoKeygenStep3RequestDescriptor = $convert.base64Decode(
    'ChdFdnR4b0tleWdlblN0ZXAzUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHgoKaW'
    'RlbnRpZmllchgCIAEoDFIKaWRlbnRpZmllchJ9Chpyb3VuZDJfcGFja2FnZXNfZm9yX290aGVy'
    'cxgDIAMoCzJALm1wY193YWxsZXQuRXZ0eG9LZXlnZW5TdGVwM1JlcXVlc3QuUm91bmQyUGFja2'
    'FnZXNGb3JPdGhlcnNFbnRyeVIXcm91bmQyUGFja2FnZXNGb3JPdGhlcnMSHAoJc2lnbmF0dXJl'
    'GAQgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAUgASgDUgt0aW1lc3RhbXBNcxpKCh'
    'xSb3VuZDJQYWNrYWdlc0Zvck90aGVyc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVl'
    'GAIgASgJUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use evtxoKeygenStep3ResponseDescriptor instead')
const EvtxoKeygenStep3Response$json = {
  '1': 'EvtxoKeygenStep3Response',
  '2': [
    {'1': 'round2_packages_for_me', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.EvtxoKeygenStep3Response.Round2PackagesForMeEntry', '10': 'round2PackagesForMe'},
    {'1': 'evtxo_address', '3': 2, '4': 1, '5': 9, '10': 'evtxoAddress'},
    {'1': 'evtxo_script_pubkey', '3': 3, '4': 1, '5': 12, '10': 'evtxoScriptPubkey'},
  ],
  '3': [EvtxoKeygenStep3Response_Round2PackagesForMeEntry$json],
};

@$core.Deprecated('Use evtxoKeygenStep3ResponseDescriptor instead')
const EvtxoKeygenStep3Response_Round2PackagesForMeEntry$json = {
  '1': 'Round2PackagesForMeEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `EvtxoKeygenStep3Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List evtxoKeygenStep3ResponseDescriptor = $convert.base64Decode(
    'ChhFdnR4b0tleWdlblN0ZXAzUmVzcG9uc2UScgoWcm91bmQyX3BhY2thZ2VzX2Zvcl9tZRgBIA'
    'MoCzI9Lm1wY193YWxsZXQuRXZ0eG9LZXlnZW5TdGVwM1Jlc3BvbnNlLlJvdW5kMlBhY2thZ2Vz'
    'Rm9yTWVFbnRyeVITcm91bmQyUGFja2FnZXNGb3JNZRIjCg1ldnR4b19hZGRyZXNzGAIgASgJUg'
    'xldnR4b0FkZHJlc3MSLgoTZXZ0eG9fc2NyaXB0X3B1YmtleRgDIAEoDFIRZXZ0eG9TY3JpcHRQ'
    'dWJrZXkaRgoYUm91bmQyUGFja2FnZXNGb3JNZUVudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBX'
    'ZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

