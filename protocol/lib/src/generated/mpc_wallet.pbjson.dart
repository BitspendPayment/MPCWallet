///
//  Generated code. Do not modify.
//  source: mpc_wallet.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,deprecated_member_use_from_same_package,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

import 'dart:core' as $core;
import 'dart:convert' as $convert;
import 'dart:typed_data' as $typed_data;
@$core.Deprecated('Use dKGStep1RequestDescriptor instead')
const DKGStep1Request$json = const {
  '1': 'DKGStep1Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    const {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
    const {'1': 'is_restore', '3': 4, '4': 1, '5': 8, '10': 'isRestore'},
  ],
};

/// Descriptor for `DKGStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep1RequestDescriptor = $convert.base64Decode('Cg9ES0dTdGVwMVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh4KCmlkZW50aWZpZXIYAiABKAxSCmlkZW50aWZpZXISJQoOcm91bmQxX3BhY2thZ2UYAyABKAlSDXJvdW5kMVBhY2thZ2USHQoKaXNfcmVzdG9yZRgEIAEoCFIJaXNSZXN0b3Jl');
@$core.Deprecated('Use dKGStep1ResponseDescriptor instead')
const DKGStep1Response$json = const {
  '1': 'DKGStep1Response',
  '2': const [
    const {'1': 'round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep1Response.Round1PackagesEntry', '10': 'round1Packages'},
  ],
  '3': const [DKGStep1Response_Round1PackagesEntry$json],
};

@$core.Deprecated('Use dKGStep1ResponseDescriptor instead')
const DKGStep1Response_Round1PackagesEntry$json = const {
  '1': 'Round1PackagesEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `DKGStep1Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep1ResponseDescriptor = $convert.base64Decode('ChBES0dTdGVwMVJlc3BvbnNlElkKD3JvdW5kMV9wYWNrYWdlcxgBIAMoCzIwLm1wY193YWxsZXQuREtHU3RlcDFSZXNwb25zZS5Sb3VuZDFQYWNrYWdlc0VudHJ5Ug5yb3VuZDFQYWNrYWdlcxpBChNSb3VuZDFQYWNrYWdlc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');
@$core.Deprecated('Use dKGStep2RequestDescriptor instead')
const DKGStep2Request$json = const {
  '1': 'DKGStep2Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    const {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
  ],
};

/// Descriptor for `DKGStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep2RequestDescriptor = $convert.base64Decode('Cg9ES0dTdGVwMlJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh4KCmlkZW50aWZpZXIYAiABKAxSCmlkZW50aWZpZXISJQoOcm91bmQxX3BhY2thZ2UYAyABKAlSDXJvdW5kMVBhY2thZ2U=');
@$core.Deprecated('Use dKGStep2ResponseDescriptor instead')
const DKGStep2Response$json = const {
  '1': 'DKGStep2Response',
  '2': const [
    const {'1': 'all_round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep2Response.AllRound1PackagesEntry', '10': 'allRound1Packages'},
  ],
  '3': const [DKGStep2Response_AllRound1PackagesEntry$json],
};

@$core.Deprecated('Use dKGStep2ResponseDescriptor instead')
const DKGStep2Response_AllRound1PackagesEntry$json = const {
  '1': 'AllRound1PackagesEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `DKGStep2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep2ResponseDescriptor = $convert.base64Decode('ChBES0dTdGVwMlJlc3BvbnNlEmMKE2FsbF9yb3VuZDFfcGFja2FnZXMYASADKAsyMy5tcGNfd2FsbGV0LkRLR1N0ZXAyUmVzcG9uc2UuQWxsUm91bmQxUGFja2FnZXNFbnRyeVIRYWxsUm91bmQxUGFja2FnZXMaRAoWQWxsUm91bmQxUGFja2FnZXNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');
@$core.Deprecated('Use dKGStep3RequestDescriptor instead')
const DKGStep3Request$json = const {
  '1': 'DKGStep3Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    const {'1': 'round2_packages_for_others', '3': 3, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep3Request.Round2PackagesForOthersEntry', '10': 'round2PackagesForOthers'},
  ],
  '3': const [DKGStep3Request_Round2PackagesForOthersEntry$json],
};

@$core.Deprecated('Use dKGStep3RequestDescriptor instead')
const DKGStep3Request_Round2PackagesForOthersEntry$json = const {
  '1': 'Round2PackagesForOthersEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `DKGStep3Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep3RequestDescriptor = $convert.base64Decode('Cg9ES0dTdGVwM1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh4KCmlkZW50aWZpZXIYAiABKAxSCmlkZW50aWZpZXISdQoacm91bmQyX3BhY2thZ2VzX2Zvcl9vdGhlcnMYAyADKAsyOC5tcGNfd2FsbGV0LkRLR1N0ZXAzUmVxdWVzdC5Sb3VuZDJQYWNrYWdlc0Zvck90aGVyc0VudHJ5Uhdyb3VuZDJQYWNrYWdlc0Zvck90aGVycxpKChxSb3VuZDJQYWNrYWdlc0Zvck90aGVyc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');
@$core.Deprecated('Use dKGStep3ResponseDescriptor instead')
const DKGStep3Response$json = const {
  '1': 'DKGStep3Response',
  '2': const [
    const {'1': 'round2_packages_for_me', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.DKGStep3Response.Round2PackagesForMeEntry', '10': 'round2PackagesForMe'},
  ],
  '3': const [DKGStep3Response_Round2PackagesForMeEntry$json],
};

@$core.Deprecated('Use dKGStep3ResponseDescriptor instead')
const DKGStep3Response_Round2PackagesForMeEntry$json = const {
  '1': 'Round2PackagesForMeEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `DKGStep3Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep3ResponseDescriptor = $convert.base64Decode('ChBES0dTdGVwM1Jlc3BvbnNlEmoKFnJvdW5kMl9wYWNrYWdlc19mb3JfbWUYASADKAsyNS5tcGNfd2FsbGV0LkRLR1N0ZXAzUmVzcG9uc2UuUm91bmQyUGFja2FnZXNGb3JNZUVudHJ5UhNyb3VuZDJQYWNrYWdlc0Zvck1lGkYKGFJvdW5kMlBhY2thZ2VzRm9yTWVFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');
@$core.Deprecated('Use signStep1RequestDescriptor instead')
const SignStep1Request$json = const {
  '1': 'SignStep1Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'hiding_commitment', '3': 2, '4': 1, '5': 12, '10': 'hidingCommitment'},
    const {'1': 'binding_commitment', '3': 3, '4': 1, '5': 12, '10': 'bindingCommitment'},
    const {'1': 'message_to_sign', '3': 4, '4': 1, '5': 12, '10': 'messageToSign'},
    const {'1': 'signature', '3': 5, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'full_transaction', '3': 6, '4': 1, '5': 12, '10': 'fullTransaction'},
    const {'1': 'timestamp_ms', '3': 7, '4': 1, '5': 3, '10': 'timestampMs'},
    const {'1': 'script_path_spend', '3': 8, '4': 1, '5': 8, '10': 'scriptPathSpend'},
  ],
};

/// Descriptor for `SignStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep1RequestDescriptor = $convert.base64Decode('ChBTaWduU3RlcDFSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIrChFoaWRpbmdfY29tbWl0bWVudBgCIAEoDFIQaGlkaW5nQ29tbWl0bWVudBItChJiaW5kaW5nX2NvbW1pdG1lbnQYAyABKAxSEWJpbmRpbmdDb21taXRtZW50EiYKD21lc3NhZ2VfdG9fc2lnbhgEIAEoDFINbWVzc2FnZVRvU2lnbhIcCglzaWduYXR1cmUYBSABKAxSCXNpZ25hdHVyZRIpChBmdWxsX3RyYW5zYWN0aW9uGAYgASgMUg9mdWxsVHJhbnNhY3Rpb24SIQoMdGltZXN0YW1wX21zGAcgASgDUgt0aW1lc3RhbXBNcxIqChFzY3JpcHRfcGF0aF9zcGVuZBgIIAEoCFIPc2NyaXB0UGF0aFNwZW5k');
@$core.Deprecated('Use signStep1ResponseDescriptor instead')
const SignStep1Response$json = const {
  '1': 'SignStep1Response',
  '2': const [
    const {'1': 'commitments', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.SignStep1Response.CommitmentsEntry', '10': 'commitments'},
    const {'1': 'message_to_sign', '3': 2, '4': 1, '5': 12, '10': 'messageToSign'},
    const {'1': 'used_key_index', '3': 3, '4': 1, '5': 5, '10': 'usedKeyIndex'},
  ],
  '3': const [SignStep1Response_Commitment$json, SignStep1Response_CommitmentsEntry$json],
};

@$core.Deprecated('Use signStep1ResponseDescriptor instead')
const SignStep1Response_Commitment$json = const {
  '1': 'Commitment',
  '2': const [
    const {'1': 'hiding', '3': 1, '4': 1, '5': 12, '10': 'hiding'},
    const {'1': 'binding', '3': 2, '4': 1, '5': 12, '10': 'binding'},
  ],
};

@$core.Deprecated('Use signStep1ResponseDescriptor instead')
const SignStep1Response_CommitmentsEntry$json = const {
  '1': 'CommitmentsEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.mpc_wallet.SignStep1Response.Commitment', '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `SignStep1Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep1ResponseDescriptor = $convert.base64Decode('ChFTaWduU3RlcDFSZXNwb25zZRJQCgtjb21taXRtZW50cxgBIAMoCzIuLm1wY193YWxsZXQuU2lnblN0ZXAxUmVzcG9uc2UuQ29tbWl0bWVudHNFbnRyeVILY29tbWl0bWVudHMSJgoPbWVzc2FnZV90b19zaWduGAIgASgMUg1tZXNzYWdlVG9TaWduEiQKDnVzZWRfa2V5X2luZGV4GAMgASgFUgx1c2VkS2V5SW5kZXgaPgoKQ29tbWl0bWVudBIWCgZoaWRpbmcYASABKAxSBmhpZGluZxIYCgdiaW5kaW5nGAIgASgMUgdiaW5kaW5nGmgKEENvbW1pdG1lbnRzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSPgoFdmFsdWUYAiABKAsyKC5tcGNfd2FsbGV0LlNpZ25TdGVwMVJlc3BvbnNlLkNvbW1pdG1lbnRSBXZhbHVlOgI4AQ==');
@$core.Deprecated('Use signStep2RequestDescriptor instead')
const SignStep2Request$json = const {
  '1': 'SignStep2Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature_share', '3': 3, '4': 1, '5': 12, '10': 'signatureShare'},
    const {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `SignStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep2RequestDescriptor = $convert.base64Decode('ChBTaWduU3RlcDJSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBInCg9zaWduYXR1cmVfc2hhcmUYAyABKAxSDnNpZ25hdHVyZVNoYXJlEhwKCXNpZ25hdHVyZRgEIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgFIAEoA1ILdGltZXN0YW1wTXM=');
@$core.Deprecated('Use utxoInfoDescriptor instead')
const UtxoInfo$json = const {
  '1': 'UtxoInfo',
  '2': const [
    const {'1': 'tx_hash', '3': 1, '4': 1, '5': 9, '10': 'txHash'},
    const {'1': 'vout', '3': 2, '4': 1, '5': 5, '10': 'vout'},
    const {'1': 'amount', '3': 3, '4': 1, '5': 3, '10': 'amount'},
  ],
};

/// Descriptor for `UtxoInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List utxoInfoDescriptor = $convert.base64Decode('CghVdHhvSW5mbxIXCgd0eF9oYXNoGAEgASgJUgZ0eEhhc2gSEgoEdm91dBgCIAEoBVIEdm91dBIWCgZhbW91bnQYAyABKANSBmFtb3VudA==');
@$core.Deprecated('Use signStep2ResponseDescriptor instead')
const SignStep2Response$json = const {
  '1': 'SignStep2Response',
  '2': const [
    const {'1': 'r_point', '3': 1, '4': 1, '5': 12, '10': 'rPoint'},
    const {'1': 'z_scalar', '3': 2, '4': 1, '5': 12, '10': 'zScalar'},
  ],
};

/// Descriptor for `SignStep2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep2ResponseDescriptor = $convert.base64Decode('ChFTaWduU3RlcDJSZXNwb25zZRIXCgdyX3BvaW50GAEgASgMUgZyUG9pbnQSGQoIel9zY2FsYXIYAiABKAxSB3pTY2FsYXI=');
@$core.Deprecated('Use refreshStep1RequestDescriptor instead')
const RefreshStep1Request$json = const {
  '1': 'RefreshStep1Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
    const {'1': 'threshold_amount', '3': 4, '4': 1, '5': 3, '10': 'thresholdAmount'},
    const {'1': 'interval', '3': 5, '4': 1, '5': 3, '10': 'interval'},
    const {'1': 'signature', '3': 6, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 7, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `RefreshStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStep1RequestDescriptor = $convert.base64Decode('ChNSZWZyZXNoU3RlcDFSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIlCg5yb3VuZDFfcGFja2FnZRgDIAEoCVINcm91bmQxUGFja2FnZRIpChB0aHJlc2hvbGRfYW1vdW50GAQgASgDUg90aHJlc2hvbGRBbW91bnQSGgoIaW50ZXJ2YWwYBSABKANSCGludGVydmFsEhwKCXNpZ25hdHVyZRgGIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgHIAEoA1ILdGltZXN0YW1wTXM=');
@$core.Deprecated('Use refreshStep1ResponseDescriptor instead')
const RefreshStep1Response$json = const {
  '1': 'RefreshStep1Response',
  '2': const [
    const {'1': 'round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.RefreshStep1Response.Round1PackagesEntry', '10': 'round1Packages'},
    const {'1': 'policy_id', '3': 2, '4': 1, '5': 9, '10': 'policyId'},
    const {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
  ],
  '3': const [RefreshStep1Response_Round1PackagesEntry$json],
};

@$core.Deprecated('Use refreshStep1ResponseDescriptor instead')
const RefreshStep1Response_Round1PackagesEntry$json = const {
  '1': 'Round1PackagesEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `RefreshStep1Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStep1ResponseDescriptor = $convert.base64Decode('ChRSZWZyZXNoU3RlcDFSZXNwb25zZRJdCg9yb3VuZDFfcGFja2FnZXMYASADKAsyNC5tcGNfd2FsbGV0LlJlZnJlc2hTdGVwMVJlc3BvbnNlLlJvdW5kMVBhY2thZ2VzRW50cnlSDnJvdW5kMVBhY2thZ2VzEhsKCXBvbGljeV9pZBgCIAEoCVIIcG9saWN5SWQSHQoKc3RhcnRfdGltZRgDIAEoA1IJc3RhcnRUaW1lGkEKE1JvdW5kMVBhY2thZ2VzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');
@$core.Deprecated('Use refreshStep2RequestDescriptor instead')
const RefreshStep2Request$json = const {
  '1': 'RefreshStep2Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
    const {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `RefreshStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStep2RequestDescriptor = $convert.base64Decode('ChNSZWZyZXNoU3RlcDJSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIlCg5yb3VuZDFfcGFja2FnZRgDIAEoCVINcm91bmQxUGFja2FnZRIcCglzaWduYXR1cmUYBCABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYBSABKANSC3RpbWVzdGFtcE1z');
@$core.Deprecated('Use refreshStep2ResponseDescriptor instead')
const RefreshStep2Response$json = const {
  '1': 'RefreshStep2Response',
  '2': const [
    const {'1': 'all_round1_packages', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.RefreshStep2Response.AllRound1PackagesEntry', '10': 'allRound1Packages'},
  ],
  '3': const [RefreshStep2Response_AllRound1PackagesEntry$json],
};

@$core.Deprecated('Use refreshStep2ResponseDescriptor instead')
const RefreshStep2Response_AllRound1PackagesEntry$json = const {
  '1': 'AllRound1PackagesEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `RefreshStep2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStep2ResponseDescriptor = $convert.base64Decode('ChRSZWZyZXNoU3RlcDJSZXNwb25zZRJnChNhbGxfcm91bmQxX3BhY2thZ2VzGAEgAygLMjcubXBjX3dhbGxldC5SZWZyZXNoU3RlcDJSZXNwb25zZS5BbGxSb3VuZDFQYWNrYWdlc0VudHJ5UhFhbGxSb3VuZDFQYWNrYWdlcxpEChZBbGxSb3VuZDFQYWNrYWdlc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');
@$core.Deprecated('Use refreshStep3RequestDescriptor instead')
const RefreshStep3Request$json = const {
  '1': 'RefreshStep3Request',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'round2_packages_for_others', '3': 3, '4': 3, '5': 11, '6': '.mpc_wallet.RefreshStep3Request.Round2PackagesForOthersEntry', '10': 'round2PackagesForOthers'},
    const {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
  '3': const [RefreshStep3Request_Round2PackagesForOthersEntry$json],
};

@$core.Deprecated('Use refreshStep3RequestDescriptor instead')
const RefreshStep3Request_Round2PackagesForOthersEntry$json = const {
  '1': 'Round2PackagesForOthersEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `RefreshStep3Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStep3RequestDescriptor = $convert.base64Decode('ChNSZWZyZXNoU3RlcDNSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBJ5Chpyb3VuZDJfcGFja2FnZXNfZm9yX290aGVycxgDIAMoCzI8Lm1wY193YWxsZXQuUmVmcmVzaFN0ZXAzUmVxdWVzdC5Sb3VuZDJQYWNrYWdlc0Zvck90aGVyc0VudHJ5Uhdyb3VuZDJQYWNrYWdlc0Zvck90aGVycxIcCglzaWduYXR1cmUYBCABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYBSABKANSC3RpbWVzdGFtcE1zGkoKHFJvdW5kMlBhY2thZ2VzRm9yT3RoZXJzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');
@$core.Deprecated('Use refreshStep3ResponseDescriptor instead')
const RefreshStep3Response$json = const {
  '1': 'RefreshStep3Response',
  '2': const [
    const {'1': 'round2_packages_for_me', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.RefreshStep3Response.Round2PackagesForMeEntry', '10': 'round2PackagesForMe'},
  ],
  '3': const [RefreshStep3Response_Round2PackagesForMeEntry$json],
};

@$core.Deprecated('Use refreshStep3ResponseDescriptor instead')
const RefreshStep3Response_Round2PackagesForMeEntry$json = const {
  '1': 'Round2PackagesForMeEntry',
  '2': const [
    const {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    const {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': const {'7': true},
};

/// Descriptor for `RefreshStep3Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshStep3ResponseDescriptor = $convert.base64Decode('ChRSZWZyZXNoU3RlcDNSZXNwb25zZRJuChZyb3VuZDJfcGFja2FnZXNfZm9yX21lGAEgAygLMjkubXBjX3dhbGxldC5SZWZyZXNoU3RlcDNSZXNwb25zZS5Sb3VuZDJQYWNrYWdlc0Zvck1lRW50cnlSE3JvdW5kMlBhY2thZ2VzRm9yTWUaRgoYUm91bmQyUGFja2FnZXNGb3JNZUVudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');
@$core.Deprecated('Use createSpendingPolicyRequestDescriptor instead')
const CreateSpendingPolicyRequest$json = const {
  '1': 'CreateSpendingPolicyRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'threshold_sats', '3': 2, '4': 1, '5': 3, '10': 'thresholdSats'},
    const {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
    const {'1': 'interval_seconds', '3': 4, '4': 1, '5': 3, '10': 'intervalSeconds'},
    const {'1': 'signature', '3': 5, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 6, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `CreateSpendingPolicyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSpendingPolicyRequestDescriptor = $convert.base64Decode('ChtDcmVhdGVTcGVuZGluZ1BvbGljeVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEiUKDnRocmVzaG9sZF9zYXRzGAIgASgDUg10aHJlc2hvbGRTYXRzEh0KCnN0YXJ0X3RpbWUYAyABKANSCXN0YXJ0VGltZRIpChBpbnRlcnZhbF9zZWNvbmRzGAQgASgDUg9pbnRlcnZhbFNlY29uZHMSHAoJc2lnbmF0dXJlGAUgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAYgASgDUgt0aW1lc3RhbXBNcw==');
@$core.Deprecated('Use createSpendingPolicyResponseDescriptor instead')
const CreateSpendingPolicyResponse$json = const {
  '1': 'CreateSpendingPolicyResponse',
  '2': const [
    const {'1': 'policy_id', '3': 1, '4': 1, '5': 9, '10': 'policyId'},
    const {'1': 'allocated_key_index', '3': 2, '4': 1, '5': 5, '10': 'allocatedKeyIndex'},
  ],
};

/// Descriptor for `CreateSpendingPolicyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSpendingPolicyResponseDescriptor = $convert.base64Decode('ChxDcmVhdGVTcGVuZGluZ1BvbGljeVJlc3BvbnNlEhsKCXBvbGljeV9pZBgBIAEoCVIIcG9saWN5SWQSLgoTYWxsb2NhdGVkX2tleV9pbmRleBgCIAEoBVIRYWxsb2NhdGVkS2V5SW5kZXg=');
@$core.Deprecated('Use getPolicyIdRequestDescriptor instead')
const GetPolicyIdRequest$json = const {
  '1': 'GetPolicyIdRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'tx_message', '3': 2, '4': 1, '5': 12, '10': 'txMessage'},
    const {'1': 'signature', '3': 3, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 4, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `GetPolicyIdRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPolicyIdRequestDescriptor = $convert.base64Decode('ChJHZXRQb2xpY3lJZFJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEh0KCnR4X21lc3NhZ2UYAiABKAxSCXR4TWVzc2FnZRIcCglzaWduYXR1cmUYAyABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYBCABKANSC3RpbWVzdGFtcE1z');
@$core.Deprecated('Use getPolicyIdResponseDescriptor instead')
const GetPolicyIdResponse$json = const {
  '1': 'GetPolicyIdResponse',
  '2': const [
    const {'1': 'policy_id', '3': 1, '4': 1, '5': 9, '10': 'policyId'},
  ],
};

/// Descriptor for `GetPolicyIdResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPolicyIdResponseDescriptor = $convert.base64Decode('ChNHZXRQb2xpY3lJZFJlc3BvbnNlEhsKCXBvbGljeV9pZBgBIAEoCVIIcG9saWN5SWQ=');
@$core.Deprecated('Use updatePolicyRequestDescriptor instead')
const UpdatePolicyRequest$json = const {
  '1': 'UpdatePolicyRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'policy_id', '3': 2, '4': 1, '5': 9, '10': 'policyId'},
    const {'1': 'threshold_sats', '3': 3, '4': 1, '5': 3, '10': 'thresholdSats'},
    const {'1': 'interval_seconds', '3': 4, '4': 1, '5': 3, '10': 'intervalSeconds'},
    const {'1': 'frost_signature_r', '3': 5, '4': 1, '5': 12, '10': 'frostSignatureR'},
    const {'1': 'frost_signature_z', '3': 6, '4': 1, '5': 12, '10': 'frostSignatureZ'},
    const {'1': 'timestamp_ms', '3': 7, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `UpdatePolicyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePolicyRequestDescriptor = $convert.base64Decode('ChNVcGRhdGVQb2xpY3lSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIbCglwb2xpY3lfaWQYAiABKAlSCHBvbGljeUlkEiUKDnRocmVzaG9sZF9zYXRzGAMgASgDUg10aHJlc2hvbGRTYXRzEikKEGludGVydmFsX3NlY29uZHMYBCABKANSD2ludGVydmFsU2Vjb25kcxIqChFmcm9zdF9zaWduYXR1cmVfchgFIAEoDFIPZnJvc3RTaWduYXR1cmVSEioKEWZyb3N0X3NpZ25hdHVyZV96GAYgASgMUg9mcm9zdFNpZ25hdHVyZVoSIQoMdGltZXN0YW1wX21zGAcgASgDUgt0aW1lc3RhbXBNcw==');
@$core.Deprecated('Use updatePolicyResponseDescriptor instead')
const UpdatePolicyResponse$json = const {
  '1': 'UpdatePolicyResponse',
  '2': const [
    const {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `UpdatePolicyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePolicyResponseDescriptor = $convert.base64Decode('ChRVcGRhdGVQb2xpY3lSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNz');
@$core.Deprecated('Use deletePolicyRequestDescriptor instead')
const DeletePolicyRequest$json = const {
  '1': 'DeletePolicyRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'policy_id', '3': 2, '4': 1, '5': 9, '10': 'policyId'},
    const {'1': 'frost_signature_r', '3': 3, '4': 1, '5': 12, '10': 'frostSignatureR'},
    const {'1': 'frost_signature_z', '3': 4, '4': 1, '5': 12, '10': 'frostSignatureZ'},
    const {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `DeletePolicyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePolicyRequestDescriptor = $convert.base64Decode('ChNEZWxldGVQb2xpY3lSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIbCglwb2xpY3lfaWQYAiABKAlSCHBvbGljeUlkEioKEWZyb3N0X3NpZ25hdHVyZV9yGAMgASgMUg9mcm9zdFNpZ25hdHVyZVISKgoRZnJvc3Rfc2lnbmF0dXJlX3oYBCABKAxSD2Zyb3N0U2lnbmF0dXJlWhIhCgx0aW1lc3RhbXBfbXMYBSABKANSC3RpbWVzdGFtcE1z');
@$core.Deprecated('Use deletePolicyResponseDescriptor instead')
const DeletePolicyResponse$json = const {
  '1': 'DeletePolicyResponse',
  '2': const [
    const {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `DeletePolicyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePolicyResponseDescriptor = $convert.base64Decode('ChREZWxldGVQb2xpY3lSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNz');
@$core.Deprecated('Use broadcastTransactionRequestDescriptor instead')
const BroadcastTransactionRequest$json = const {
  '1': 'BroadcastTransactionRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'tx_hex', '3': 2, '4': 1, '5': 9, '10': 'txHex'},
  ],
};

/// Descriptor for `BroadcastTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastTransactionRequestDescriptor = $convert.base64Decode('ChtCcm9hZGNhc3RUcmFuc2FjdGlvblJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEhUKBnR4X2hleBgCIAEoCVIFdHhIZXg=');
@$core.Deprecated('Use broadcastTransactionResponseDescriptor instead')
const BroadcastTransactionResponse$json = const {
  '1': 'BroadcastTransactionResponse',
  '2': const [
    const {'1': 'tx_id', '3': 1, '4': 1, '5': 9, '10': 'txId'},
  ],
};

/// Descriptor for `BroadcastTransactionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastTransactionResponseDescriptor = $convert.base64Decode('ChxCcm9hZGNhc3RUcmFuc2FjdGlvblJlc3BvbnNlEhMKBXR4X2lkGAEgASgJUgR0eElk');
@$core.Deprecated('Use fetchHistoryRequestDescriptor instead')
const FetchHistoryRequest$json = const {
  '1': 'FetchHistoryRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `FetchHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchHistoryRequestDescriptor = $convert.base64Decode('ChNGZXRjaEhpc3RvcnlSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYXR1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1z');
@$core.Deprecated('Use fetchHistoryResponseDescriptor instead')
const FetchHistoryResponse$json = const {
  '1': 'FetchHistoryResponse',
  '2': const [
    const {'1': 'utxos', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.UtxoInfo', '10': 'utxos'},
  ],
};

/// Descriptor for `FetchHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchHistoryResponseDescriptor = $convert.base64Decode('ChRGZXRjaEhpc3RvcnlSZXNwb25zZRIqCgV1dHhvcxgBIAMoCzIULm1wY193YWxsZXQuVXR4b0luZm9SBXV0eG9z');
@$core.Deprecated('Use fetchRecentTransactionsRequestDescriptor instead')
const FetchRecentTransactionsRequest$json = const {
  '1': 'FetchRecentTransactionsRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `FetchRecentTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchRecentTransactionsRequestDescriptor = $convert.base64Decode('Ch5GZXRjaFJlY2VudFRyYW5zYWN0aW9uc1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEhwKCXNpZ25hdHVyZRgCIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgDIAEoA1ILdGltZXN0YW1wTXM=');
@$core.Deprecated('Use fetchRecentTransactionsResponseDescriptor instead')
const FetchRecentTransactionsResponse$json = const {
  '1': 'FetchRecentTransactionsResponse',
  '2': const [
    const {'1': 'transactions', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.TransactionSummary', '10': 'transactions'},
  ],
};

/// Descriptor for `FetchRecentTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchRecentTransactionsResponseDescriptor = $convert.base64Decode('Ch9GZXRjaFJlY2VudFRyYW5zYWN0aW9uc1Jlc3BvbnNlEkIKDHRyYW5zYWN0aW9ucxgBIAMoCzIeLm1wY193YWxsZXQuVHJhbnNhY3Rpb25TdW1tYXJ5Ugx0cmFuc2FjdGlvbnM=');
@$core.Deprecated('Use transactionSummaryDescriptor instead')
const TransactionSummary$json = const {
  '1': 'TransactionSummary',
  '2': const [
    const {'1': 'tx_hash', '3': 1, '4': 1, '5': 9, '10': 'txHash'},
    const {'1': 'amount_sats', '3': 2, '4': 1, '5': 3, '10': 'amountSats'},
    const {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
    const {'1': 'is_pending', '3': 4, '4': 1, '5': 8, '10': 'isPending'},
  ],
};

/// Descriptor for `TransactionSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionSummaryDescriptor = $convert.base64Decode('ChJUcmFuc2FjdGlvblN1bW1hcnkSFwoHdHhfaGFzaBgBIAEoCVIGdHhIYXNoEh8KC2Ftb3VudF9zYXRzGAIgASgDUgphbW91bnRTYXRzEhwKCXRpbWVzdGFtcBgDIAEoA1IJdGltZXN0YW1wEh0KCmlzX3BlbmRpbmcYBCABKAhSCWlzUGVuZGluZw==');
@$core.Deprecated('Use subscribeToHistoryRequestDescriptor instead')
const SubscribeToHistoryRequest$json = const {
  '1': 'SubscribeToHistoryRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `SubscribeToHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeToHistoryRequestDescriptor = $convert.base64Decode('ChlTdWJzY3JpYmVUb0hpc3RvcnlSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYXR1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1z');
@$core.Deprecated('Use transactionNotificationDescriptor instead')
const TransactionNotification$json = const {
  '1': 'TransactionNotification',
  '2': const [
    const {'1': 'tx_hash', '3': 1, '4': 1, '5': 9, '10': 'txHash'},
    const {'1': 'height', '3': 2, '4': 1, '5': 5, '10': 'height'},
    const {'1': 'added_utxos', '3': 3, '4': 3, '5': 11, '6': '.mpc_wallet.UtxoInfo', '10': 'addedUtxos'},
    const {'1': 'spent_utxos', '3': 4, '4': 3, '5': 11, '6': '.mpc_wallet.UtxoInfo', '10': 'spentUtxos'},
  ],
};

/// Descriptor for `TransactionNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionNotificationDescriptor = $convert.base64Decode('ChdUcmFuc2FjdGlvbk5vdGlmaWNhdGlvbhIXCgd0eF9oYXNoGAEgASgJUgZ0eEhhc2gSFgoGaGVpZ2h0GAIgASgFUgZoZWlnaHQSNQoLYWRkZWRfdXR4b3MYAyADKAsyFC5tcGNfd2FsbGV0LlV0eG9JbmZvUgphZGRlZFV0eG9zEjUKC3NwZW50X3V0eG9zGAQgAygLMhQubXBjX3dhbGxldC5VdHhvSW5mb1IKc3BlbnRVdHhvcw==');
@$core.Deprecated('Use getArkInfoRequestDescriptor instead')
const GetArkInfoRequest$json = const {
  '1': 'GetArkInfoRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `GetArkInfoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkInfoRequestDescriptor = $convert.base64Decode('ChFHZXRBcmtJbmZvUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHAoJc2lnbmF0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1lc3RhbXBNcw==');
@$core.Deprecated('Use getArkInfoResponseDescriptor instead')
const GetArkInfoResponse$json = const {
  '1': 'GetArkInfoResponse',
  '2': const [
    const {'1': 'signer_pubkey', '3': 1, '4': 1, '5': 9, '10': 'signerPubkey'},
    const {'1': 'forfeit_pubkey', '3': 2, '4': 1, '5': 9, '10': 'forfeitPubkey'},
    const {'1': 'network', '3': 3, '4': 1, '5': 9, '10': 'network'},
    const {'1': 'session_duration', '3': 4, '4': 1, '5': 3, '10': 'sessionDuration'},
    const {'1': 'unilateral_exit_delay', '3': 5, '4': 1, '5': 3, '10': 'unilateralExitDelay'},
    const {'1': 'boarding_exit_delay', '3': 6, '4': 1, '5': 3, '10': 'boardingExitDelay'},
    const {'1': 'vtxo_min_amount', '3': 7, '4': 1, '5': 3, '10': 'vtxoMinAmount'},
    const {'1': 'dust', '3': 8, '4': 1, '5': 3, '10': 'dust'},
    const {'1': 'checkpoint_tapscript', '3': 9, '4': 1, '5': 9, '10': 'checkpointTapscript'},
    const {'1': 'forfeit_address', '3': 10, '4': 1, '5': 9, '10': 'forfeitAddress'},
  ],
};

/// Descriptor for `GetArkInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkInfoResponseDescriptor = $convert.base64Decode('ChJHZXRBcmtJbmZvUmVzcG9uc2USIwoNc2lnbmVyX3B1YmtleRgBIAEoCVIMc2lnbmVyUHVia2V5EiUKDmZvcmZlaXRfcHVia2V5GAIgASgJUg1mb3JmZWl0UHVia2V5EhgKB25ldHdvcmsYAyABKAlSB25ldHdvcmsSKQoQc2Vzc2lvbl9kdXJhdGlvbhgEIAEoA1IPc2Vzc2lvbkR1cmF0aW9uEjIKFXVuaWxhdGVyYWxfZXhpdF9kZWxheRgFIAEoA1ITdW5pbGF0ZXJhbEV4aXREZWxheRIuChNib2FyZGluZ19leGl0X2RlbGF5GAYgASgDUhFib2FyZGluZ0V4aXREZWxheRImCg92dHhvX21pbl9hbW91bnQYByABKANSDXZ0eG9NaW5BbW91bnQSEgoEZHVzdBgIIAEoA1IEZHVzdBIxChRjaGVja3BvaW50X3RhcHNjcmlwdBgJIAEoCVITY2hlY2twb2ludFRhcHNjcmlwdBInCg9mb3JmZWl0X2FkZHJlc3MYCiABKAlSDmZvcmZlaXRBZGRyZXNz');
@$core.Deprecated('Use getArkAddressRequestDescriptor instead')
const GetArkAddressRequest$json = const {
  '1': 'GetArkAddressRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `GetArkAddressRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkAddressRequestDescriptor = $convert.base64Decode('ChRHZXRBcmtBZGRyZXNzUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHAoJc2lnbmF0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1lc3RhbXBNcw==');
@$core.Deprecated('Use getArkAddressResponseDescriptor instead')
const GetArkAddressResponse$json = const {
  '1': 'GetArkAddressResponse',
  '2': const [
    const {'1': 'ark_address', '3': 1, '4': 1, '5': 9, '10': 'arkAddress'},
  ],
};

/// Descriptor for `GetArkAddressResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getArkAddressResponseDescriptor = $convert.base64Decode('ChVHZXRBcmtBZGRyZXNzUmVzcG9uc2USHwoLYXJrX2FkZHJlc3MYASABKAlSCmFya0FkZHJlc3M=');
@$core.Deprecated('Use getBoardingAddressRequestDescriptor instead')
const GetBoardingAddressRequest$json = const {
  '1': 'GetBoardingAddressRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `GetBoardingAddressRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBoardingAddressRequestDescriptor = $convert.base64Decode('ChlHZXRCb2FyZGluZ0FkZHJlc3NSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYXR1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1z');
@$core.Deprecated('Use getBoardingAddressResponseDescriptor instead')
const GetBoardingAddressResponse$json = const {
  '1': 'GetBoardingAddressResponse',
  '2': const [
    const {'1': 'boarding_address', '3': 1, '4': 1, '5': 9, '10': 'boardingAddress'},
  ],
};

/// Descriptor for `GetBoardingAddressResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBoardingAddressResponseDescriptor = $convert.base64Decode('ChpHZXRCb2FyZGluZ0FkZHJlc3NSZXNwb25zZRIpChBib2FyZGluZ19hZGRyZXNzGAEgASgJUg9ib2FyZGluZ0FkZHJlc3M=');
@$core.Deprecated('Use vtxoInfoDescriptor instead')
const VtxoInfo$json = const {
  '1': 'VtxoInfo',
  '2': const [
    const {'1': 'txid', '3': 1, '4': 1, '5': 9, '10': 'txid'},
    const {'1': 'vout', '3': 2, '4': 1, '5': 13, '10': 'vout'},
    const {'1': 'amount', '3': 3, '4': 1, '5': 4, '10': 'amount'},
    const {'1': 'created_at', '3': 4, '4': 1, '5': 3, '10': 'createdAt'},
    const {'1': 'expires_at', '3': 5, '4': 1, '5': 3, '10': 'expiresAt'},
    const {'1': 'status', '3': 6, '4': 1, '5': 9, '10': 'status'},
    const {'1': 'is_preconfirmed', '3': 7, '4': 1, '5': 8, '10': 'isPreconfirmed'},
    const {'1': 'exit_delay', '3': 8, '4': 1, '5': 13, '10': 'exitDelay'},
    const {'1': 'script', '3': 9, '4': 1, '5': 9, '10': 'script'},
  ],
};

/// Descriptor for `VtxoInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vtxoInfoDescriptor = $convert.base64Decode('CghWdHhvSW5mbxISCgR0eGlkGAEgASgJUgR0eGlkEhIKBHZvdXQYAiABKA1SBHZvdXQSFgoGYW1vdW50GAMgASgEUgZhbW91bnQSHQoKY3JlYXRlZF9hdBgEIAEoA1IJY3JlYXRlZEF0Eh0KCmV4cGlyZXNfYXQYBSABKANSCWV4cGlyZXNBdBIWCgZzdGF0dXMYBiABKAlSBnN0YXR1cxInCg9pc19wcmVjb25maXJtZWQYByABKAhSDmlzUHJlY29uZmlybWVkEh0KCmV4aXRfZGVsYXkYCCABKA1SCWV4aXREZWxheRIWCgZzY3JpcHQYCSABKAlSBnNjcmlwdA==');
@$core.Deprecated('Use listVtxosRequestDescriptor instead')
const ListVtxosRequest$json = const {
  '1': 'ListVtxosRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `ListVtxosRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listVtxosRequestDescriptor = $convert.base64Decode('ChBMaXN0VnR4b3NSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYXR1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1z');
@$core.Deprecated('Use listVtxosResponseDescriptor instead')
const ListVtxosResponse$json = const {
  '1': 'ListVtxosResponse',
  '2': const [
    const {'1': 'vtxos', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.VtxoInfo', '10': 'vtxos'},
    const {'1': 'total_balance', '3': 2, '4': 1, '5': 4, '10': 'totalBalance'},
  ],
};

/// Descriptor for `ListVtxosResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listVtxosResponseDescriptor = $convert.base64Decode('ChFMaXN0VnR4b3NSZXNwb25zZRIqCgV2dHhvcxgBIAMoCzIULm1wY193YWxsZXQuVnR4b0luZm9SBXZ0eG9zEiMKDXRvdGFsX2JhbGFuY2UYAiABKARSDHRvdGFsQmFsYW5jZQ==');
@$core.Deprecated('Use checkBoardingBalanceRequestDescriptor instead')
const CheckBoardingBalanceRequest$json = const {
  '1': 'CheckBoardingBalanceRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `CheckBoardingBalanceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkBoardingBalanceRequestDescriptor = $convert.base64Decode('ChtDaGVja0JvYXJkaW5nQmFsYW5jZVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEhwKCXNpZ25hdHVyZRgCIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgDIAEoA1ILdGltZXN0YW1wTXM=');
@$core.Deprecated('Use checkBoardingBalanceResponseDescriptor instead')
const CheckBoardingBalanceResponse$json = const {
  '1': 'CheckBoardingBalanceResponse',
  '2': const [
    const {'1': 'balance', '3': 1, '4': 1, '5': 4, '10': 'balance'},
    const {'1': 'utxo_count', '3': 2, '4': 1, '5': 13, '10': 'utxoCount'},
  ],
};

/// Descriptor for `CheckBoardingBalanceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkBoardingBalanceResponseDescriptor = $convert.base64Decode('ChxDaGVja0JvYXJkaW5nQmFsYW5jZVJlc3BvbnNlEhgKB2JhbGFuY2UYASABKARSB2JhbGFuY2USHQoKdXR4b19jb3VudBgCIAEoDVIJdXR4b0NvdW50');
@$core.Deprecated('Use arkTransactionSummaryDescriptor instead')
const ArkTransactionSummary$json = const {
  '1': 'ArkTransactionSummary',
  '2': const [
    const {'1': 'tx_type', '3': 1, '4': 1, '5': 9, '10': 'txType'},
    const {'1': 'amount_sats', '3': 2, '4': 1, '5': 3, '10': 'amountSats'},
    const {'1': 'txid', '3': 3, '4': 1, '5': 9, '10': 'txid'},
    const {'1': 'timestamp', '3': 4, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `ArkTransactionSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arkTransactionSummaryDescriptor = $convert.base64Decode('ChVBcmtUcmFuc2FjdGlvblN1bW1hcnkSFwoHdHhfdHlwZRgBIAEoCVIGdHhUeXBlEh8KC2Ftb3VudF9zYXRzGAIgASgDUgphbW91bnRTYXRzEhIKBHR4aWQYAyABKAlSBHR4aWQSHAoJdGltZXN0YW1wGAQgASgDUgl0aW1lc3RhbXA=');
@$core.Deprecated('Use listArkTransactionsRequestDescriptor instead')
const ListArkTransactionsRequest$json = const {
  '1': 'ListArkTransactionsRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `ListArkTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listArkTransactionsRequestDescriptor = $convert.base64Decode('ChpMaXN0QXJrVHJhbnNhY3Rpb25zUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHAoJc2lnbmF0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1lc3RhbXBNcw==');
@$core.Deprecated('Use listArkTransactionsResponseDescriptor instead')
const ListArkTransactionsResponse$json = const {
  '1': 'ListArkTransactionsResponse',
  '2': const [
    const {'1': 'transactions', '3': 1, '4': 3, '5': 11, '6': '.mpc_wallet.ArkTransactionSummary', '10': 'transactions'},
  ],
};

/// Descriptor for `ListArkTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listArkTransactionsResponseDescriptor = $convert.base64Decode('ChtMaXN0QXJrVHJhbnNhY3Rpb25zUmVzcG9uc2USRQoMdHJhbnNhY3Rpb25zGAEgAygLMiEubXBjX3dhbGxldC5BcmtUcmFuc2FjdGlvblN1bW1hcnlSDHRyYW5zYWN0aW9ucw==');
@$core.Deprecated('Use sendVtxoRequestDescriptor instead')
const SendVtxoRequest$json = const {
  '1': 'SendVtxoRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'recipient_ark_address', '3': 2, '4': 1, '5': 9, '10': 'recipientArkAddress'},
    const {'1': 'amount', '3': 3, '4': 1, '5': 4, '10': 'amount'},
    const {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
    const {'1': 'signed_messages', '3': 6, '4': 3, '5': 12, '10': 'signedMessages'},
  ],
};

/// Descriptor for `SendVtxoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendVtxoRequestDescriptor = $convert.base64Decode('Cg9TZW5kVnR4b1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEjIKFXJlY2lwaWVudF9hcmtfYWRkcmVzcxgCIAEoCVITcmVjaXBpZW50QXJrQWRkcmVzcxIWCgZhbW91bnQYAyABKARSBmFtb3VudBIcCglzaWduYXR1cmUYBCABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYBSABKANSC3RpbWVzdGFtcE1zEicKD3NpZ25lZF9tZXNzYWdlcxgGIAMoDFIOc2lnbmVkTWVzc2FnZXM=');
@$core.Deprecated('Use sendVtxoResponseDescriptor instead')
const SendVtxoResponse$json = const {
  '1': 'SendVtxoResponse',
  '2': const [
    const {'1': 'status', '3': 1, '4': 1, '5': 14, '6': '.mpc_wallet.SendVtxoResponse.Status', '10': 'status'},
    const {'1': 'messages_to_sign', '3': 2, '4': 3, '5': 12, '10': 'messagesToSign'},
    const {'1': 'script_path_spend', '3': 3, '4': 1, '5': 8, '10': 'scriptPathSpend'},
    const {'1': 'ark_txid', '3': 4, '4': 1, '5': 9, '10': 'arkTxid'},
    const {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
    const {'1': 'policy_id', '3': 6, '4': 1, '5': 9, '10': 'policyId'},
  ],
  '4': const [SendVtxoResponse_Status$json],
};

@$core.Deprecated('Use sendVtxoResponseDescriptor instead')
const SendVtxoResponse_Status$json = const {
  '1': 'Status',
  '2': const [
    const {'1': 'SIGNING_REQUIRED', '2': 0},
    const {'1': 'SETTLED', '2': 1},
    const {'1': 'ERROR', '2': 2},
  ],
};

/// Descriptor for `SendVtxoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendVtxoResponseDescriptor = $convert.base64Decode('ChBTZW5kVnR4b1Jlc3BvbnNlEjsKBnN0YXR1cxgBIAEoDjIjLm1wY193YWxsZXQuU2VuZFZ0eG9SZXNwb25zZS5TdGF0dXNSBnN0YXR1cxIoChBtZXNzYWdlc190b19zaWduGAIgAygMUg5tZXNzYWdlc1RvU2lnbhIqChFzY3JpcHRfcGF0aF9zcGVuZBgDIAEoCFIPc2NyaXB0UGF0aFNwZW5kEhkKCGFya190eGlkGAQgASgJUgdhcmtUeGlkEiMKDWVycm9yX21lc3NhZ2UYBSABKAlSDGVycm9yTWVzc2FnZRIbCglwb2xpY3lfaWQYBiABKAlSCHBvbGljeUlkIjYKBlN0YXR1cxIUChBTSUdOSU5HX1JFUVVJUkVEEAASCwoHU0VUVExFRBABEgkKBUVSUk9SEAI=');
@$core.Deprecated('Use redeemVtxoRequestDescriptor instead')
const RedeemVtxoRequest$json = const {
  '1': 'RedeemVtxoRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'on_chain_address', '3': 2, '4': 1, '5': 9, '10': 'onChainAddress'},
    const {'1': 'amount', '3': 3, '4': 1, '5': 4, '10': 'amount'},
    const {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 5, '4': 1, '5': 3, '10': 'timestampMs'},
  ],
};

/// Descriptor for `RedeemVtxoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redeemVtxoRequestDescriptor = $convert.base64Decode('ChFSZWRlZW1WdHhvUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSKAoQb25fY2hhaW5fYWRkcmVzcxgCIAEoCVIOb25DaGFpbkFkZHJlc3MSFgoGYW1vdW50GAMgASgEUgZhbW91bnQSHAoJc2lnbmF0dXJlGAQgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAUgASgDUgt0aW1lc3RhbXBNcw==');
@$core.Deprecated('Use redeemVtxoResponseDescriptor instead')
const RedeemVtxoResponse$json = const {
  '1': 'RedeemVtxoResponse',
  '2': const [
    const {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    const {'1': 'txid', '3': 2, '4': 1, '5': 9, '10': 'txid'},
  ],
};

/// Descriptor for `RedeemVtxoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redeemVtxoResponseDescriptor = $convert.base64Decode('ChJSZWRlZW1WdHhvUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxISCgR0eGlkGAIgASgJUgR0eGlk');
@$core.Deprecated('Use settleRequestDescriptor instead')
const SettleRequest$json = const {
  '1': 'SettleRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
    const {'1': 'signed_messages', '3': 4, '4': 3, '5': 12, '10': 'signedMessages'},
  ],
};

/// Descriptor for `SettleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleRequestDescriptor = $convert.base64Decode('Cg1TZXR0bGVSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAxSBnVzZXJJZBIcCglzaWduYXR1cmUYAiABKAxSCXNpZ25hdHVyZRIhCgx0aW1lc3RhbXBfbXMYAyABKANSC3RpbWVzdGFtcE1zEicKD3NpZ25lZF9tZXNzYWdlcxgEIAMoDFIOc2lnbmVkTWVzc2FnZXM=');
@$core.Deprecated('Use settleResponseDescriptor instead')
const SettleResponse$json = const {
  '1': 'SettleResponse',
  '2': const [
    const {'1': 'status', '3': 1, '4': 1, '5': 14, '6': '.mpc_wallet.SettleResponse.Status', '10': 'status'},
    const {'1': 'messages_to_sign', '3': 2, '4': 3, '5': 12, '10': 'messagesToSign'},
    const {'1': 'script_path_spend', '3': 3, '4': 1, '5': 8, '10': 'scriptPathSpend'},
    const {'1': 'commitment_txid', '3': 4, '4': 1, '5': 9, '10': 'commitmentTxid'},
    const {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
  '4': const [SettleResponse_Status$json],
};

@$core.Deprecated('Use settleResponseDescriptor instead')
const SettleResponse_Status$json = const {
  '1': 'Status',
  '2': const [
    const {'1': 'SIGNING_REQUIRED', '2': 0},
    const {'1': 'WAITING_FOR_BATCH', '2': 1},
    const {'1': 'SETTLED', '2': 2},
    const {'1': 'ERROR', '2': 3},
  ],
};

/// Descriptor for `SettleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleResponseDescriptor = $convert.base64Decode('Cg5TZXR0bGVSZXNwb25zZRI5CgZzdGF0dXMYASABKA4yIS5tcGNfd2FsbGV0LlNldHRsZVJlc3BvbnNlLlN0YXR1c1IGc3RhdHVzEigKEG1lc3NhZ2VzX3RvX3NpZ24YAiADKAxSDm1lc3NhZ2VzVG9TaWduEioKEXNjcmlwdF9wYXRoX3NwZW5kGAMgASgIUg9zY3JpcHRQYXRoU3BlbmQSJwoPY29tbWl0bWVudF90eGlkGAQgASgJUg5jb21taXRtZW50VHhpZBIjCg1lcnJvcl9tZXNzYWdlGAUgASgJUgxlcnJvck1lc3NhZ2UiTQoGU3RhdHVzEhQKEFNJR05JTkdfUkVRVUlSRUQQABIVChFXQUlUSU5HX0ZPUl9CQVRDSBABEgsKB1NFVFRMRUQQAhIJCgVFUlJPUhAD');
@$core.Deprecated('Use settleDelegateRequestDescriptor instead')
const SettleDelegateRequest$json = const {
  '1': 'SettleDelegateRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
    const {'1': 'signed_messages', '3': 4, '4': 3, '5': 12, '10': 'signedMessages'},
  ],
};

/// Descriptor for `SettleDelegateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleDelegateRequestDescriptor = $convert.base64Decode('ChVTZXR0bGVEZWxlZ2F0ZVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoDFIGdXNlcklkEhwKCXNpZ25hdHVyZRgCIAEoDFIJc2lnbmF0dXJlEiEKDHRpbWVzdGFtcF9tcxgDIAEoA1ILdGltZXN0YW1wTXMSJwoPc2lnbmVkX21lc3NhZ2VzGAQgAygMUg5zaWduZWRNZXNzYWdlcw==');
@$core.Deprecated('Use settleDelegateResponseDescriptor instead')
const SettleDelegateResponse$json = const {
  '1': 'SettleDelegateResponse',
  '2': const [
    const {'1': 'status', '3': 1, '4': 1, '5': 14, '6': '.mpc_wallet.SettleDelegateResponse.Status', '10': 'status'},
    const {'1': 'messages_to_sign', '3': 2, '4': 3, '5': 12, '10': 'messagesToSign'},
    const {'1': 'script_path_spend', '3': 3, '4': 1, '5': 8, '10': 'scriptPathSpend'},
    const {'1': 'commitment_txid', '3': 4, '4': 1, '5': 9, '10': 'commitmentTxid'},
    const {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
  '4': const [SettleDelegateResponse_Status$json],
};

@$core.Deprecated('Use settleDelegateResponseDescriptor instead')
const SettleDelegateResponse_Status$json = const {
  '1': 'Status',
  '2': const [
    const {'1': 'SIGNING_REQUIRED', '2': 0},
    const {'1': 'SETTLED', '2': 1},
    const {'1': 'ERROR', '2': 2},
  ],
};

/// Descriptor for `SettleDelegateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settleDelegateResponseDescriptor = $convert.base64Decode('ChZTZXR0bGVEZWxlZ2F0ZVJlc3BvbnNlEkEKBnN0YXR1cxgBIAEoDjIpLm1wY193YWxsZXQuU2V0dGxlRGVsZWdhdGVSZXNwb25zZS5TdGF0dXNSBnN0YXR1cxIoChBtZXNzYWdlc190b19zaWduGAIgAygMUg5tZXNzYWdlc1RvU2lnbhIqChFzY3JpcHRfcGF0aF9zcGVuZBgDIAEoCFIPc2NyaXB0UGF0aFNwZW5kEicKD2NvbW1pdG1lbnRfdHhpZBgEIAEoCVIOY29tbWl0bWVudFR4aWQSIwoNZXJyb3JfbWVzc2FnZRgFIAEoCVIMZXJyb3JNZXNzYWdlIjYKBlN0YXR1cxIUChBTSUdOSU5HX1JFUVVJUkVEEAASCwoHU0VUVExFRBABEgkKBUVSUk9SEAI=');
@$core.Deprecated('Use submitArkSendRequestDescriptor instead')
const SubmitArkSendRequest$json = const {
  '1': 'SubmitArkSendRequest',
  '2': const [
    const {'1': 'user_id', '3': 1, '4': 1, '5': 12, '10': 'userId'},
    const {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
    const {'1': 'timestamp_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampMs'},
    const {'1': 'signed_ark_tx_b64', '3': 4, '4': 1, '5': 9, '10': 'signedArkTxB64'},
    const {'1': 'signed_checkpoint_txs_b64', '3': 5, '4': 3, '5': 9, '10': 'signedCheckpointTxsB64'},
    const {'1': 'spent_outpoints', '3': 6, '4': 3, '5': 9, '10': 'spentOutpoints'},
  ],
};

/// Descriptor for `SubmitArkSendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitArkSendRequestDescriptor = $convert.base64Decode('ChRTdWJtaXRBcmtTZW5kUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgMUgZ1c2VySWQSHAoJc2lnbmF0dXJlGAIgASgMUglzaWduYXR1cmUSIQoMdGltZXN0YW1wX21zGAMgASgDUgt0aW1lc3RhbXBNcxIpChFzaWduZWRfYXJrX3R4X2I2NBgEIAEoCVIOc2lnbmVkQXJrVHhCNjQSOQoZc2lnbmVkX2NoZWNrcG9pbnRfdHhzX2I2NBgFIAMoCVIWc2lnbmVkQ2hlY2twb2ludFR4c0I2NBInCg9zcGVudF9vdXRwb2ludHMYBiADKAlSDnNwZW50T3V0cG9pbnRz');
@$core.Deprecated('Use submitArkSendResponseDescriptor instead')
const SubmitArkSendResponse$json = const {
  '1': 'SubmitArkSendResponse',
  '2': const [
    const {'1': 'ark_txid', '3': 1, '4': 1, '5': 9, '10': 'arkTxid'},
    const {'1': 'change_txid', '3': 2, '4': 1, '5': 9, '10': 'changeTxid'},
    const {'1': 'change_vout', '3': 3, '4': 1, '5': 13, '10': 'changeVout'},
    const {'1': 'change_amount', '3': 4, '4': 1, '5': 4, '10': 'changeAmount'},
  ],
};

/// Descriptor for `SubmitArkSendResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitArkSendResponseDescriptor = $convert.base64Decode('ChVTdWJtaXRBcmtTZW5kUmVzcG9uc2USGQoIYXJrX3R4aWQYASABKAlSB2Fya1R4aWQSHwoLY2hhbmdlX3R4aWQYAiABKAlSCmNoYW5nZVR4aWQSHwoLY2hhbmdlX3ZvdXQYAyABKA1SCmNoYW5nZVZvdXQSIwoNY2hhbmdlX2Ftb3VudBgEIAEoBFIMY2hhbmdlQW1vdW50');
