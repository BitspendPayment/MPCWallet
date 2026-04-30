/// Raw dart:ffi bindings to libark_ffi.
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'ffi_result.dart';
import 'native_library.dart';

// ---------------------------------------------------------------------------
// Ark protocol bindings
// ---------------------------------------------------------------------------

typedef _ArkVtxoSpkNative = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>, Uint32);
typedef _ArkVtxoSpkDart = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>, int);
final arkDefaultVtxoScriptPubkeyFfi = nativeLib
    .lookupFunction<_ArkVtxoSpkNative, _ArkVtxoSpkDart>(
        'ark_default_vtxo_script_pubkey');

typedef _ArkForfeitNative = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>, Uint32);
typedef _ArkForfeitDart = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>, int);
final arkForfeitSpendInfoFfi = nativeLib
    .lookupFunction<_ArkForfeitNative, _ArkForfeitDart>(
        'ark_forfeit_spend_info');

typedef _ArkExitNative = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>, Uint32);
typedef _ArkExitDart = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>, int);
final arkExitSpendInfoFfi = nativeLib
    .lookupFunction<_ArkExitNative, _ArkExitDart>(
        'ark_exit_spend_info');

typedef _ArkMultisigNative = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef _ArkMultisigDart = Pointer<FfiResult> Function(
    Pointer<Utf8>, Pointer<Utf8>);
final arkMultisigScriptFfi = nativeLib
    .lookupFunction<_ArkMultisigNative, _ArkMultisigDart>(
        'ark_multisig_script');

typedef _ArkCsvNative = Pointer<FfiResult> Function(Uint32, Pointer<Utf8>);
typedef _ArkCsvDart = Pointer<FfiResult> Function(int, Pointer<Utf8>);
final arkCsvSigScriptFfi = nativeLib
    .lookupFunction<_ArkCsvNative, _ArkCsvDart>('ark_csv_sig_script');

typedef _ArkTapleafHashNative = Pointer<FfiResult> Function(Pointer<Utf8>);
typedef _ArkTapleafHashDart = Pointer<FfiResult> Function(Pointer<Utf8>);
final arkTapleafHashFfi = nativeLib
    .lookupFunction<_ArkTapleafHashNative, _ArkTapleafHashDart>(
        'ark_tapleaf_hash');

// ---------------------------------------------------------------------------
// Ark Send bindings
// ---------------------------------------------------------------------------

typedef _ArkBuildSendTxNative = Pointer<FfiResult> Function(Pointer<Utf8>);
typedef _ArkBuildSendTxDart = Pointer<FfiResult> Function(Pointer<Utf8>);
final arkBuildSendTxFfi = nativeLib
    .lookupFunction<_ArkBuildSendTxNative, _ArkBuildSendTxDart>(
        'ark_build_send_tx');

typedef _ArkInsertSendSigsNative = Pointer<FfiResult> Function(
    Uint64, Pointer<Utf8>);
typedef _ArkInsertSendSigsDart = Pointer<FfiResult> Function(
    int, Pointer<Utf8>);
final arkInsertSendSignaturesFfi = nativeLib
    .lookupFunction<_ArkInsertSendSigsNative, _ArkInsertSendSigsDart>(
        'ark_insert_send_signatures');

typedef _ArkGetChangeVtxoNative = Pointer<FfiResult> Function(Uint64);
typedef _ArkGetChangeVtxoDart = Pointer<FfiResult> Function(int);
final arkGetChangeVtxoFfi = nativeLib
    .lookupFunction<_ArkGetChangeVtxoNative, _ArkGetChangeVtxoDart>(
        'ark_get_change_vtxo');

typedef _ArkFreeSendSessionNative = Void Function(Uint64);
typedef _ArkFreeSendSessionDart = void Function(int);
final arkFreeSendSessionFfi = nativeLib
    .lookupFunction<_ArkFreeSendSessionNative, _ArkFreeSendSessionDart>(
        'ark_free_send_session');
