// This is a generated file - do not edit.
//
// Generated from mpc_wallet.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use dKGStep1RequestDescriptor instead')
const DKGStep1Request$json = {
  '1': 'DKGStep1Request',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
  ],
};

/// Descriptor for `DKGStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep1RequestDescriptor = $convert.base64Decode(
    'Cg9ES0dTdGVwMVJlcXVlc3QSGwoJZGV2aWNlX2lkGAEgASgJUghkZXZpY2VJZBIeCgppZGVudG'
    'lmaWVyGAIgASgMUgppZGVudGlmaWVyEiUKDnJvdW5kMV9wYWNrYWdlGAMgASgJUg1yb3VuZDFQ'
    'YWNrYWdl');

@$core.Deprecated('Use dKGStep1ResponseDescriptor instead')
const DKGStep1Response$json = {
  '1': 'DKGStep1Response',
  '2': [
    {
      '1': 'round1_packages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mpc_wallet.DKGStep1Response.Round1PackagesEntry',
      '10': 'round1Packages'
    },
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
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'round1_package', '3': 3, '4': 1, '5': 9, '10': 'round1Package'},
  ],
};

/// Descriptor for `DKGStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dKGStep2RequestDescriptor = $convert.base64Decode(
    'Cg9ES0dTdGVwMlJlcXVlc3QSGwoJZGV2aWNlX2lkGAEgASgJUghkZXZpY2VJZBIeCgppZGVudG'
    'lmaWVyGAIgASgMUgppZGVudGlmaWVyEiUKDnJvdW5kMV9wYWNrYWdlGAMgASgJUg1yb3VuZDFQ'
    'YWNrYWdl');

@$core.Deprecated('Use dKGStep2ResponseDescriptor instead')
const DKGStep2Response$json = {
  '1': 'DKGStep2Response',
  '2': [
    {
      '1': 'all_round1_packages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mpc_wallet.DKGStep2Response.AllRound1PackagesEntry',
      '10': 'allRound1Packages'
    },
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
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {
      '1': 'round2_packages_for_others',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.mpc_wallet.DKGStep3Request.Round2PackagesForOthersEntry',
      '10': 'round2PackagesForOthers'
    },
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
    'Cg9ES0dTdGVwM1JlcXVlc3QSGwoJZGV2aWNlX2lkGAEgASgJUghkZXZpY2VJZBIeCgppZGVudG'
    'lmaWVyGAIgASgMUgppZGVudGlmaWVyEnUKGnJvdW5kMl9wYWNrYWdlc19mb3Jfb3RoZXJzGAMg'
    'AygLMjgubXBjX3dhbGxldC5ES0dTdGVwM1JlcXVlc3QuUm91bmQyUGFja2FnZXNGb3JPdGhlcn'
    'NFbnRyeVIXcm91bmQyUGFja2FnZXNGb3JPdGhlcnMaSgocUm91bmQyUGFja2FnZXNGb3JPdGhl'
    'cnNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use dKGStep3ResponseDescriptor instead')
const DKGStep3Response$json = {
  '1': 'DKGStep3Response',
  '2': [
    {
      '1': 'round2_packages_for_me',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mpc_wallet.DKGStep3Response.Round2PackagesForMeEntry',
      '10': 'round2PackagesForMe'
    },
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
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {
      '1': 'hiding_commitment',
      '3': 3,
      '4': 1,
      '5': 12,
      '10': 'hidingCommitment'
    },
    {
      '1': 'binding_commitment',
      '3': 4,
      '4': 1,
      '5': 12,
      '10': 'bindingCommitment'
    },
    {'1': 'message_to_sign', '3': 5, '4': 1, '5': 12, '10': 'messageToSign'},
  ],
};

/// Descriptor for `SignStep1Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep1RequestDescriptor = $convert.base64Decode(
    'ChBTaWduU3RlcDFSZXF1ZXN0EhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQSHgoKaWRlbn'
    'RpZmllchgCIAEoDFIKaWRlbnRpZmllchIrChFoaWRpbmdfY29tbWl0bWVudBgDIAEoDFIQaGlk'
    'aW5nQ29tbWl0bWVudBItChJiaW5kaW5nX2NvbW1pdG1lbnQYBCABKAxSEWJpbmRpbmdDb21taX'
    'RtZW50EiYKD21lc3NhZ2VfdG9fc2lnbhgFIAEoDFINbWVzc2FnZVRvU2lnbg==');

@$core.Deprecated('Use signStep1ResponseDescriptor instead')
const SignStep1Response$json = {
  '1': 'SignStep1Response',
  '2': [
    {
      '1': 'commitments',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.mpc_wallet.SignStep1Response.CommitmentsEntry',
      '10': 'commitments'
    },
    {'1': 'message_to_sign', '3': 2, '4': 1, '5': 12, '10': 'messageToSign'},
  ],
  '3': [
    SignStep1Response_Commitment$json,
    SignStep1Response_CommitmentsEntry$json
  ],
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
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.mpc_wallet.SignStep1Response.Commitment',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `SignStep1Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep1ResponseDescriptor = $convert.base64Decode(
    'ChFTaWduU3RlcDFSZXNwb25zZRJQCgtjb21taXRtZW50cxgBIAMoCzIuLm1wY193YWxsZXQuU2'
    'lnblN0ZXAxUmVzcG9uc2UuQ29tbWl0bWVudHNFbnRyeVILY29tbWl0bWVudHMSJgoPbWVzc2Fn'
    'ZV90b19zaWduGAIgASgMUg1tZXNzYWdlVG9TaWduGj4KCkNvbW1pdG1lbnQSFgoGaGlkaW5nGA'
    'EgASgMUgZoaWRpbmcSGAoHYmluZGluZxgCIAEoDFIHYmluZGluZxpoChBDb21taXRtZW50c0Vu'
    'dHJ5EhAKA2tleRgBIAEoCVIDa2V5Ej4KBXZhbHVlGAIgASgLMigubXBjX3dhbGxldC5TaWduU3'
    'RlcDFSZXNwb25zZS5Db21taXRtZW50UgV2YWx1ZToCOAE=');

@$core.Deprecated('Use signStep2RequestDescriptor instead')
const SignStep2Request$json = {
  '1': 'SignStep2Request',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'identifier', '3': 2, '4': 1, '5': 12, '10': 'identifier'},
    {'1': 'signature_share', '3': 3, '4': 1, '5': 12, '10': 'signatureShare'},
  ],
};

/// Descriptor for `SignStep2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signStep2RequestDescriptor = $convert.base64Decode(
    'ChBTaWduU3RlcDJSZXF1ZXN0EhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQSHgoKaWRlbn'
    'RpZmllchgCIAEoDFIKaWRlbnRpZmllchInCg9zaWduYXR1cmVfc2hhcmUYAyABKAxSDnNpZ25h'
    'dHVyZVNoYXJl');

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
