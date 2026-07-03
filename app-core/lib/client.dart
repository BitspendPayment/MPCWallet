import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_core/policy.dart';
import 'package:app_core/auth_helper.dart';
import 'package:app_core/ark/ark_send.dart';
import 'package:grpc/src/client/channel.dart' as grpc_base;
import 'package:app_core/wallet_api.dart';
import 'package:app_core/grpc_wallet_api.dart';
import 'package:app_core/rest_wallet_api.dart';
import 'package:app_core/passkey/session_token_source.dart';
import 'package:app_core/passkey/seed_source.dart';
import 'package:app_core/pin_blinding.dart';
import 'package:app_core/attested_wallet_api.dart';
import 'package:app_core/enclave/native_enclave.dart' show AttestationStatus;
import 'package:http/http.dart' as http;
import 'package:app_core/threshold/core/dkg.dart';
import 'package:app_core/threshold/threshold.dart' as threshold;
import 'package:app_core/threshold/frost/signing.dart' as frost;
import 'package:app_core/threshold/frost/commitment.dart' as frost_comm;
import 'package:protocol/protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:convert/convert.dart';

import 'package:app_core/persistence/wallet_store.dart';
import 'package:app_core/hardware_signer.dart';

class MpcClient {
  final WalletApi _stub;
  // Store
  late final WalletStore _store;

  // User ID for this client instance (persisted or derived after DKG)
  List<int>? _userId;
  String? get userId => _userId == null ? null : hex.encode(_userId!);

  // Recovey Id
  List<int>? _recoveryId;
  List<int>? get recoveryId => _recoveryId;

  /// The FROST group x-only public key (64 hex chars).
  /// This is the owner key for Ark VTXOs — NOT the same as userId.
  String? get groupXOnlyPubKey {
    final pkp = _normalPolicy?.publicKeyPackage;
    if (pkp == null) return null;
    final compressed = threshold.elemSerializeCompressed(pkp.verifyingKey.E);
    final compressedHex = hex.encode(compressed);
    // Strip 02/03 prefix to get x-only
    return compressedHex.length == 66 ? compressedHex.substring(2) : compressedHex;
  }

  final int _maxSigners;
  final int _minSigners;

  /// REST base URL (set only for the REST transport) — used by [subscribeEvents] to open the SSE
  /// event stream, which is a raw streamed GET outside the request-reply `WalletApi`.
  String? _restBaseForEvents;

  threshold.SecretKey? _signingSecret;

  /// PIN/passkey-PRF share gating. When a [SeedSource] is configured the wallet's FROST share is
  /// stored BLINDED (δ = share − b(seed)) inside `_normalPolicy.keyPackage.secretShare`; the raw
  /// share is never persisted and is reconstructed transiently only for an ARK sign / contract
  /// op (see [_walletKeyPackage]). Reads + auth then need no share (auth rides the session token).
  SeedSource? _seedSource;

  /// Whether the stored share is blinded (a persistent property set at DKG time; loaded from state).
  /// Kept separate from [_seedSource] so persist/load/sign agree even before a seed source is wired.
  bool _shareBlinded = false;

  /// Whether the persisted share is blinded — i.e. a passkey/PIN was provisioned
  /// and a seed source must be wired before any ARK sign. Used on cold-start
  /// restore to decide whether to re-attach the passkey seed/token sources.
  bool get isShareGated => _shareBlinded;

  /// Wire the blinding seed source (passkey PRF in production; a fixed seed in tests). Set before
  /// DKG to create a gated wallet, and before signing to unlock ARK ops. Never wired ⇒ legacy
  /// un-gated behavior.
  void setSeedSource(SeedSource source) => _seedSource = source;

  /// The wallet's DKG dealer secret — the polynomial constant term that
  /// generated this wallet's share. It is a SINGLE secp256k1 key the wallet
  /// controls alone (its public point is the DKG `walletVk`), distinct from the
  /// threshold share. It is the wallet's on-chain ("utxo") signing key: on-chain
  /// receive/spend/broadcast happen wallet-alone with NO cosigner. The FROST
  /// group key stays the Ark owner key (boarding + VTXO).
  threshold.SecretKey? _onchainSecret;

  /// 32-byte on-chain secret, or null before DKG/restore.
  Uint8List? get onchainSecretBytes => _onchainSecret == null
      ? null
      : Uint8List.fromList(threshold.bigIntToBytes(_onchainSecret!.scalar));

  // Auth helper for signing requests (initialized after DKG or restore)
  ClientAuthHelper? _authHelper;

  SpendingPolicy? _normalPolicy;

  RecoveryPolicy? _recoveryPolicy;

  // Recovery-identity signer (hardware or software).
  //
  // Nullable: normal sends + Ark ops don't touch the recovery share, so a
  // session that isn't mid-DKG or mid-policy-op doesn't need one attached.
  // The MpcService layer attaches a signer only for the four operations
  // that actually need it (DKG, restore, update policy, delete policy) and
  // detaches immediately after, keeping the recovery share out of RAM the
  // rest of the time.
  HardwareSignerInterface? _hardwareSigner;
  set hardwareSigner(HardwareSignerInterface? s) => _hardwareSigner = s;
  HardwareSignerInterface? get hardwareSigner => _hardwareSigner;

  HardwareSignerInterface _requireSigner(String op) {
    final s = _hardwareSigner;
    if (s == null) {
      throw StateError(
        '$op requires a signer to be attached',
      );
    }
    return s;
  }

  /// Creates a client that manages two shares (identities).
  ///
  /// [channel] - gRPC channel to the MPC server
  /// [maxSigners] - Maximum number of signers in the threshold scheme
  /// [minSigners] - Minimum signers required (threshold)
  /// [storageId] - Unique identifier for the Hive box
  /// [encryptionCipher] - Optional cipher for encrypted storage.
  ///                      Use HiveAesCipher for AES-256 encryption.
  ///                      When null, data is stored unencrypted.
  /// [hardwareSigner] - Hardware signer for recovery identity.
  ///                    The recovery identity's secret stays on the
  ///                    hardware signer and DKG/signing is delegated.
  /// Create an MpcClient using gRPC transport (HTTP/2).
  MpcClient(
    grpc_base.ClientChannel channel, {
    int maxSigners = 2,
    int minSigners = 2,
    String? storageId,
    HiveCipher? encryptionCipher,
    HardwareSignerInterface? hardwareSigner,
  })  : _stub = GrpcWalletApi(channel),
        _maxSigners = maxSigners,
        _minSigners = minSigners,
        _hardwareSigner = hardwareSigner {
    _store = WalletStore(
      boxName: storageId ?? 'mpc_wallet_state_default',
      cipher: encryptionCipher,
    );
  }

  /// Create an MpcClient using REST transport (HTTP/1.1).
  MpcClient.rest(
    String baseUrl, {
    int maxSigners = 2,
    int minSigners = 2,
    String? storageId,
    HiveCipher? encryptionCipher,
    HardwareSignerInterface? hardwareSigner,
    http.Client? httpClient,
  })  : _stub = RestWalletApi(baseUrl, httpClient: httpClient),
        _maxSigners = maxSigners,
        _minSigners = minSigners,
        _hardwareSigner = hardwareSigner {
    _restBaseForEvents = baseUrl;
    _store = WalletStore(
      boxName: storageId ?? 'mpc_wallet_state_default',
      cipher: encryptionCipher,
    );
  }

  /// Wire the upstream Bearer session-token source onto the transport
  /// (auth-off-the-share migration). No-op for transports that can't carry HTTP
  /// headers (attested FFI), which stay on Schnorr until that path is extended.
  void setSessionTokenSource(SessionTokenSource source) {
    final stub = _stub;
    if (stub is RestWalletApi) {
      stub.sessionTokens = source;
    }
  }

  /// Create an MpcClient using attested REST transport (enclave FFI).
  /// Verifies enclave attestation (PCR0) and response signatures (BIP-340).
  /// FFI runs in a background isolate -- non-blocking.
  static Future<MpcClient> attested(
    String baseUrl, {
    required String expectedPcr0,
    int maxSigners = 2,
    int minSigners = 2,
    String? storageId,
    HiveCipher? encryptionCipher,
    HardwareSignerInterface? hardwareSigner,
    int cacheTtlSecs = 60,
  }) async {
    final api = await AttestedWalletApi.create(baseUrl,
        expectedPcr0: expectedPcr0, cacheTtlSecs: cacheTtlSecs);
    final client = MpcClient._internal(
      stub: api,
      maxSigners: maxSigners,
      minSigners: minSigners,
      hardwareSigner: hardwareSigner,
      storageId: storageId,
      encryptionCipher: encryptionCipher,
    );
    return client;
  }

  /// Internal constructor used by the async `attested()` factory.
  MpcClient._internal({
    required WalletApi stub,
    required int maxSigners,
    required int minSigners,
    HardwareSignerInterface? hardwareSigner,
    String? storageId,
    HiveCipher? encryptionCipher,
  })  : _stub = stub,
        _maxSigners = maxSigners,
        _minSigners = minSigners,
        _hardwareSigner = hardwareSigner {
    _store = WalletStore(
      boxName: storageId ?? 'mpc_wallet_state_default',
      cipher: encryptionCipher,
    );
  }

  /// Get the attestation status (only available with `MpcClient.attested()`).
  /// Returns a Future since the FFI runs in a background isolate.
  Future<AttestationStatus?> getAttestationStatus() async {
    final stub = _stub;
    if (stub is AttestedWalletApi) {
      return stub.getAttestationStatus();
    }
    return null;
  }

  /// Initializes persistence for the client.
  ///
  /// [path] is the directory where client state will be stored.
  /// If [path] is null, defaults to `$HOME/.mpc_wallet/client`.
  ///
  /// This must be called before creating MpcClient instances.
  static Future<void> initPersistence({String? path}) async {
    String storePath;
    if (path != null) {
      storePath = path;
    } else {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      storePath = p.join(home, '.mpc_wallet', 'client');
    }

    final dir = Directory(storePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    Hive.init(storePath);
  }

  // Real 2-of-2: a completed DKG yields the normal policy; there is no recovery policy.
  bool get isInitialized => _normalPolicy != null;

  /// Restores client state from persistence.
  /// [debugState] can be provided to inject state for testing (bypassing store).
  /// Returns true if state was found and restored.
  Future<bool> restoreState({Map<String, dynamic>? debugState}) async {
    // Ensure persistence is initialized (via initPersistence or just ensure path)
    // WalletStore relies on Hive.init being called previously.
    // If not called, assume default? We rely on user calling initPersistence.
    await _store.init();

    Map<String, dynamic>? state;
    if (debugState != null) {
      state = debugState;
    } else {
      state = await _store.getClientState();
    }

    if (state == null) return false;

    final storedUserId = state['userId'];
    if (storedUserId is! String || storedUserId.isEmpty) {
      return false;
    }
    _userId = hex.decode(storedUserId);

    // Restore signing secret for authentication. Absent for a gated wallet (share stored blinded);
    // then `_authHelper` stays null and auth rides the session token.
    if (state['signingSecret'] != null) {
      final secretHex = state['signingSecret'] as String;
      final secretBytes = Uint8List.fromList(hex.decode(secretHex));
      _signingSecret =
          threshold.SecretKey(threshold.bytesToBigInt(secretBytes));
      _authHelper =
          ClientAuthHelper.fromSigningSecret(_signingSecret!, _userId!);
    }
    // Gated wallet: `_normalPolicy.keyPackage.secretShare` holds δ; reconstruct at sign time.
    _shareBlinded = state['shareBlinded'] == true;

    // Restore the single-key on-chain secret (the DKG dealer secret).
    if (state['onchainSecret'] != null) {
      final secretBytes =
          Uint8List.fromList(hex.decode(state['onchainSecret'] as String));
      _onchainSecret =
          threshold.SecretKey(threshold.bytesToBigInt(secretBytes));
    }

    if (state['spendingPolicies'] != null) {
      _normalPolicy = SpendingPolicy.fromJson(
          Map<String, dynamic>.from(state['spendingPolicies']));
    }

    if (state['recoveryPolicy'] != null) {
      _recoveryPolicy = RecoveryPolicy.fromJson(
          Map<String, dynamic>.from(state['recoveryPolicy']));
    }

    return true;
  }

  Future<void> _saveState() async {
    final state = <String, dynamic>{
      'userId': hex.encode(_userId!),
    };
    if (_signingSecret != null) {
      state['signingSecret'] =
          hex.encode(threshold.bigIntToBytes(_signingSecret!.scalar));
    }
    if (_onchainSecret != null) {
      state['onchainSecret'] =
          hex.encode(threshold.bigIntToBytes(_onchainSecret!.scalar));
    }
    if (_normalPolicy != null) {
      // When gating is on, `_normalPolicy.keyPackage.secretShare` already holds δ (the raw share is
      // never persisted); `shareBlinded` tells restore to reconstruct at sign time, not load time.
      state['spendingPolicies'] = _normalPolicy!.toJson();
    }
    state['shareBlinded'] = _shareBlinded;
    if (_recoveryPolicy != null) {
      state['recoveryPolicy'] = _recoveryPolicy!.toJson();
    }
    await _store.saveClientState(state);
  }

  // Getters for testing
  threshold.KeyPackage? get keyPackage1 => _normalPolicy?.keyPackage;
  threshold.KeyPackage? get keyPackage2 => _recoveryPolicy?.keyPackage;
  threshold.PublicKeyPackage? get publicKey => _normalPolicy?.publicKeyPackage;

  // --- SERVER METADATA ---

  /// Fetch the server's deployment metadata (Bitcoin network).
  /// Unauthenticated; safe to call before DKG completes.
  Future<GetServerInfoResponse> getServerInfo() async {
    return _stub.getServerInfo(GetServerInfoRequest());
  }

  // --- DKG ---

  /// DKG: only the hardware signer and server contribute secrets (dealers).
  /// The wallet is a passive receiver — it gets a valid signing share
  /// without contributing key material. Group key = s_hw + s_server.
  Future<void> doDkg() async {
    await _store.init();

    // Real 2-of-2 {wallet, cosigner}: the wallet is a dealer (its own secret) and
    // the cosigner is the other dealer. Both hold a share; both are mandatory to
    // sign. No hardware signer, no recovery share.
    final secret = threshold.newSecretKey();
    // This dealer secret is also the wallet's single-key on-chain ("utxo") key.
    _onchainSecret = secret;
    final coefficients =
        List<BigInt>.generate(_minSigners - 1, (_) => threshold.modNRandom());
    final (r1Secret, r1Pkg) =
        threshold.dkgPart1(_maxSigners, _minSigners, secret, coefficients);

    final walletVkBytes =
        threshold.elemSerializeCompressed(r1Pkg.commitment.toVerifyingKey().E);
    final walletIdentifier = threshold.Identifier.derive(walletVkBytes);
    // Temporary session label during DKG (endpoints are unauthenticated until the
    // group key exists). The canonical user_id is the verifying share, set below.
    final tempUserId = Uint8List.fromList(walletVkBytes);

    // Step 1 — wallet sends its round1 (dealer). The server self-inits as the
    // second dealer and completes the round once both are registered.
    final step1Resp = await _stub.dKGStep1(DKGStep1Request()
      ..userId = tempUserId
      ..identifier = walletIdentifier.serialize()
      ..round1Package = jsonEncode(r1Pkg.toJson()));

    // Step 2 — server computes its round2 share for the wallet.
    await _stub.dKGStep2(DKGStep2Request()..userId = tempUserId);

    // The server's round1 package (the other dealer).
    final round1Pkgs = <threshold.Identifier, threshold.Round1Package>{};
    step1Resp.round1Packages.forEach((k, v) {
      if (v.isEmpty) return;
      final id = threshold.Identifier(BigInt.parse(k, radix: 16));
      if (id == walletIdentifier) return; // skip our own
      round1Pkgs[id] = threshold.Round1Package.fromJson(jsonDecode(v));
    });

    // Wallet computes its round2 share for the server.
    final (r2Secret, sharesFromWallet) =
        threshold.dkgPart2(r1Secret, round1Pkgs);

    // Step 3 — wallet sends its round2 share; server finalizes.
    final step3Resp = await _stub.dKGStep3(DKGStep3Request()
      ..userId = tempUserId
      ..identifier = threshold.bigIntToBytes(walletIdentifier.toScalar())
      ..round2PackagesForOthers.addAll(_buildSharesMap(sharesFromWallet)));

    // Wallet finalizes (full participant) → its key package + the group PKP.
    final sharesForWallet = _parseShares(step3Resp.round2PackagesForMe);
    final (walletKeyPkg, pubKeyPkg) =
        threshold.dkgPart3(r1Secret, r2Secret, round1Pkgs, sharesForWallet);

    // The wallet's DKG share becomes `_normalPolicy` (blinded under the seed when gating is on).
    await _finalizeWalletShare(walletKeyPkg, pubKeyPkg);

    await _saveState();
  }

  /// Restore: re-derive the wallet's signing share using the same DKG secrets
  /// stored on the hardware signer and server. The group public key stays the
  /// same so the Bitcoin address (and funds) are preserved.
  Future<void> doRestore() async {
    await _store.init();
    final signer = _requireSigner('doRestore');

    // 1. Hardware signer reuses stored DKG secret (same VK, same identifier)
    final restoreInit = await signer.restoreInit(_maxSigners, _minSigners);
    final hwVerifyingKey = restoreInit.verifyingKeyBytes;
    final hwIdentifier = restoreInit.identifier;

    // 2. Derive wallet identifier (deterministic — same as original DKG)
    final walletIdInput = Uint8List.fromList(
      [...'wallet:'.codeUnits, ...hwVerifyingKey],
    );
    final walletIdentifier = threshold.Identifier.derive(walletIdInput);

    // Use HW VK as temporary session key during restore
    final tempUserId = Uint8List.fromList(hwVerifyingKey);

    // 3. Send Round1 packages to server.
    final hwR1Json = jsonEncode(restoreInit.round1Package.toJson());

    final reqWallet = DKGStep1Request()
      ..userId = tempUserId
      ..identifier = walletIdentifier.serialize()
      ..round1Package = ''; // passive receiver

    final reqHw = DKGStep1Request()
      ..userId = tempUserId
      ..identifier = hwIdentifier.serialize()
      ..round1Package = hwR1Json;

    final step1Futures = await Future.wait(
        [_stub.dKGStep1(reqWallet), _stub.dKGStep1(reqHw)]);
    final step1Resp = step1Futures[0];

    // 4. Trigger Step 2 on server (server computes round2)
    await _stub.dKGStep2(DKGStep2Request()..userId = tempUserId);

    // 5. Parse dealer R1 packages (for HW signer and wallet)
    final dealerR1ForHw = <threshold.Identifier, threshold.Round1Package>{};
    final dealerR1ForWallet = <threshold.Identifier, threshold.Round1Package>{};

    step1Resp.round1Packages.forEach((k, v) {
      if (v.isEmpty) return;
      final id = threshold.Identifier(BigInt.parse(k, radix: 16));
      final pkg = threshold.Round1Package.fromJson(jsonDecode(v));
      if (id != hwIdentifier) dealerR1ForHw[id] = pkg;
      dealerR1ForWallet[id] = pkg;
    });

    // 6. HW signer computes shares for server + wallet
    final sharesFromHw = await signer.dkgRound2(
      dealerR1ForHw,
      receiverIdentifiers: [walletIdentifier],
    );

    // 7. Send Round2 packages to server
    final reqStep3Hw = DKGStep3Request()
      ..userId = tempUserId
      ..identifier = threshold.bigIntToBytes(hwIdentifier.toScalar())
      ..round2PackagesForOthers.addAll(_buildSharesMap(sharesFromHw));

    final reqStep3Wallet = DKGStep3Request()
      ..userId = tempUserId
      ..identifier = threshold.bigIntToBytes(walletIdentifier.toScalar());

    final step3Futures = await Future.wait(
        [_stub.dKGStep3(reqStep3Wallet), _stub.dKGStep3(reqStep3Hw)]);

    // 8. Wallet receives shares from dealers (HW signer + server)
    final sharesForWallet = _parseShares(step3Futures[0].round2PackagesForMe);
    final sharesForHw = _parseShares(step3Futures[1].round2PackagesForMe);

    // 9. Wallet finalizes as passive receiver
    final allParticipantIds = <threshold.Identifier>[
      ...dealerR1ForWallet.keys,
      walletIdentifier,
    ];
    final (walletKeyPkg, pubKeyPkg) = threshold.dkgPart3Receive(
      walletIdentifier,
      dealerR1ForWallet,
      sharesForWallet,
      _minSigners,
      _maxSigners,
      allParticipantIds,
    );

    // 10. HW signer finalizes (stores updated key internally)
    final dkgResult = await signer.dkgRound3(
      dealerR1ForHw,
      sharesForHw,
      receiverIdentifiers: [walletIdentifier],
    );

    // 11. `_finalizeWalletShare` (below) sets the wallet share + `_userId` + auth state.
    _recoveryId = hwVerifyingKey.toList();


    _onchainSecret ??= threshold.newSecretKey();

    // 12. Store policies (blinds the share under the seed when gating is on).
    await _finalizeWalletShare(walletKeyPkg, pubKeyPkg);

    final recoveryVerifyingShare =
        pubKeyPkg.verifyingShares[dkgResult.identifier];
    if (recoveryVerifyingShare == null) {
      throw StateError("Recovery identifier not found in public key package");
    }

    final recoveryKeyPkg = threshold.KeyPackage(
      dkgResult.identifier,
      BigInt.zero,
      recoveryVerifyingShare,
      pubKeyPkg.verifyingKey,
      _minSigners,
    );

    _recoveryPolicy = RecoveryPolicy(
        id: "recovery_policy_id",
        keyPackage: recoveryKeyPkg,
        publicKeyPackage: pubKeyPkg);

    await _saveState();
  }

  // Note: PublicKey is the unifying key for all identities
  PublicKeyPackage? getTweakedPublicKeyPackage(List<int>? merkle_root) {
    final publicKeyPackage = _normalPolicy?.publicKeyPackage;
    return publicKeyPackage?.tweak(merkle_root);
  }

  PublicKeyPackage? getPublicKeyPackage() {
    return _normalPolicy?.publicKeyPackage;
  }

  // --- CONTRACT eVTXO CREATION ---

  /// Create a contract eVTXO bound to [contractId] WITH a peer [receiverVk]. The
  /// cooperative leaf reuses the wallet's EXISTING key `V` (no new key): a single
  /// key-preserving REFRESH places a co-signing share of `V` onto a `{receiver, cosigner}`
  /// pairing so the chosen receiver (another user) can co-sign independently, while the
  /// cosigner GATES every spend by [contractWasm]. The wallet computes its refresh slices
  /// locally from `V` and sends `a@cosigner` (scalar) + `a@receiver·G` (point) +
  /// `ECIES(a@receiver)` (to receiver_vk) to the cosigner; the cosigner adds its own
  /// `b@receiver`, ECIES-encrypts it too, and drops BOTH halves into the receiver's inbox.
  /// Only the POINT `a@receiver·G` reaches the cosigner in the clear, so it never learns
  /// the receiver's full share. The cosigner validates `sha256(contractWasm)==contractId`,
  /// stores the wasm, and registers the eVTXO spk (coop leaf = `V`).
  ///
  /// [receiverVk] is the peer receiver's verifying key (33 bytes). [ownerPk] is the
  /// unilateral-exit-leaf x-only key; defaults to the wallet's own `V` x-only.
  ///
  /// Returns the registered eVTXO scriptPubKey plus the wallet's `V` key package + PKP,
  /// which the author uses to spend the contract's cooperative leaf via its normal pairing.
  Future<
      ({
        Uint8List scriptPubkey,
        threshold.KeyPackage keyPackage,
        threshold.PublicKeyPackage publicKeyPackage,
      })> createEvtxoKey(
    Uint8List contractId,
    Uint8List contractWasm,
    Uint8List serverPk,
    int exitDelay, {
    required Uint8List receiverVk,
    Uint8List? ownerPk,
  }) async {
    if (!isInitialized || _userId == null) {
      throw StateError('Client not initialized (DKG not run).');
    }

    final vKp = await _walletKeyPackage();
    final vPkp = _normalPolicy!.publicKeyPackage;
    final walletId = vKp.identifier;
    final cosignerId =
        vPkp.verifyingShares.keys.firstWhere((id) => id != walletId);
    final receiverId = threshold.Identifier.derive(receiverVk);
    final ts = Int64(DateTime.now().millisecondsSinceEpoch);

    // Exit-leaf owner defaults to the wallet's own V x-only (drop the parity byte).
    final vCompressed = threshold.elemSerializeCompressed(vPkp.verifyingKey.E);
    final ownerXonly = ownerPk ?? Uint8List.fromList(vCompressed.sublist(1));

    // Key-preserving refresh of V onto {receiver, cosigner}: a@cosigner (scalar) +
    // a@receiver·G (point) go to the cosigner; a@receiver is ECIES-sealed to the receiver.
    final idSet = <threshold.Identifier>[walletId, cosignerId];
    final slope = threshold.modNRandom();
    final (aAtReceiver, aAtCosigner) =
        threshold.refreshShareToId(vKp, idSet, receiverId, cosignerId, slope);
    final aAtReceiverPoint =
        threshold.elemSerializeCompressed(threshold.elemBaseMul(aAtReceiver));
    final eciesAAtReceiver =
        threshold.eciesEncrypt(threshold.bigIntToBytes(aAtReceiver), receiverVk);

    final resp = await _stub.contractCreate(ContractCreateRequest()
      ..userId = _userId!
      ..identifier = walletId.serialize()
      ..contractId = contractId
      ..contractWasm = contractWasm
      ..serverPk = serverPk
      ..exitDelay = exitDelay
      ..ownerPk = ownerXonly
      ..receiverVk = receiverVk
      ..aAtCosigner = threshold.bigIntToBytes(aAtCosigner)
      ..aAtReceiverPoint = aAtReceiverPoint
      ..signature = Uint8List(0) // contract-create path is unauthenticated for now
      ..timestampMs = ts
      ..eciesAAtReceiver = eciesAAtReceiver);

    return (
      scriptPubkey: Uint8List.fromList(resp.contractScriptPubkey),
      keyPackage: vKp,
      publicKeyPackage: vPkp,
    );
  }

  /// Phase 2: create a contract eVTXO from a published TEMPLATE + the author's typed config. The
  /// cosigner composes the template + a provider synthesized from [configBlob] (the encoded
  /// key-value config) into one contract whose composed sha256 becomes the bound contract_id, then
  /// runs the same peer flow as [createEvtxoKey] (refresh V onto {receiver, cosigner} + relay).
  /// Returns the eVTXO spk, the COMPOSED contract id, and the wallet's V key package + PKP.
  Future<
      ({
        Uint8List scriptPubkey,
        Uint8List contractId,
        threshold.KeyPackage keyPackage,
        threshold.PublicKeyPackage publicKeyPackage,
      })> createEvtxoFromTemplate({
    required String templateId,
    required String stubId,
    required Uint8List configBlob,
    required Uint8List serverPk,
    int exitDelay = 0,
    required Uint8List receiverVk,
    Uint8List? ownerPk,
  }) async {
    if (!isInitialized || _userId == null) {
      throw StateError('Client not initialized (DKG not run).');
    }
    final vKp = await _walletKeyPackage();
    final vPkp = _normalPolicy!.publicKeyPackage;
    final walletId = vKp.identifier;
    final cosignerId =
        vPkp.verifyingShares.keys.firstWhere((id) => id != walletId);
    final receiverId = threshold.Identifier.derive(receiverVk);
    final ts = Int64(DateTime.now().millisecondsSinceEpoch);

    final vCompressed = threshold.elemSerializeCompressed(vPkp.verifyingKey.E);
    final ownerXonly = ownerPk ?? Uint8List.fromList(vCompressed.sublist(1));

    final idSet = <threshold.Identifier>[walletId, cosignerId];
    final slope = threshold.modNRandom();
    final (aAtReceiver, aAtCosigner) =
        threshold.refreshShareToId(vKp, idSet, receiverId, cosignerId, slope);
    final aAtReceiverPoint =
        threshold.elemSerializeCompressed(threshold.elemBaseMul(aAtReceiver));
    final eciesAAtReceiver =
        threshold.eciesEncrypt(threshold.bigIntToBytes(aAtReceiver), receiverVk);

    final resp = await _stub.contractCreate(ContractCreateRequest()
      ..userId = _userId!
      ..identifier = walletId.serialize()
      ..templateId = templateId
      ..stubId = stubId
      ..configBlob = configBlob
      ..serverPk = serverPk
      ..exitDelay = exitDelay
      ..ownerPk = ownerXonly
      ..receiverVk = receiverVk
      ..aAtCosigner = threshold.bigIntToBytes(aAtCosigner)
      ..aAtReceiverPoint = aAtReceiverPoint
      ..signature = Uint8List(0)
      ..timestampMs = ts
      ..eciesAAtReceiver = eciesAAtReceiver);

    return (
      scriptPubkey: Uint8List.fromList(resp.contractScriptPubkey),
      contractId: Uint8List.fromList(resp.contractId),
      keyPackage: vKp,
      publicKeyPackage: vPkp,
    );
  }

  /// Receiver side: fetch the contract shares held for this wallet in its inbox, decrypt
  /// BOTH ECIES halves with the signing secret, sum them into the receiver's share
  /// `P = a@receiver + b@receiver`, and return the spendable context per contract eVTXO
  /// (the `{receiver, cosigner}` pairing key package + PKP + taptree parameters).
  Future<
      List<
          ({
            Uint8List scriptPubkey,
            Uint8List contractId,
            int exitDelay,
            Uint8List serverPk,
            Uint8List ownerPk,
            threshold.KeyPackage keyPackage,
            threshold.PublicKeyPackage publicKeyPackage,
          })>> fetchContractShares() async {
    // `_normalPolicy` (not `_signingSecret`) — a gated wallet has no raw `_signingSecret`; the
    // share (blinded) lives in the policy and is reconstructed by `_walletKeyPackage()` below.
    if (_userId == null || _normalPolicy == null) {
      throw StateError('Client not initialized.');
    }
    final auth = _authSig((h) => h.signForEvtxoPending());
    final resp = await _stub.evtxoPendingShares(EvtxoPendingSharesRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);

    final receiverId = threshold.Identifier.derive(Uint8List.fromList(_userId!));
    // Reconstruct the wallet share (P_full) to ECIES-decrypt the inbox; gated ⇒ needs the seed.
    final secret = (await _walletKeyPackage()).secretShare;
    final out = <
        ({
          Uint8List scriptPubkey,
          Uint8List contractId,
          int exitDelay,
          Uint8List serverPk,
          Uint8List ownerPk,
          threshold.KeyPackage keyPackage,
          threshold.PublicKeyPackage publicKeyPackage,
        })>[];
    for (final s in resp.shares) {
      final aAtR = threshold.bytesToBigInt(threshold.eciesDecrypt(
          Uint8List.fromList(s.eciesHalfAuthor), secret));
      final bAtR = threshold.bytesToBigInt(threshold.eciesDecrypt(
          Uint8List.fromList(s.eciesHalfCosigner), secret));
      final pI = threshold.modNAdd(aAtR, bAtR);
      final pkp = threshold.PublicKeyPackage.fromJson(
          jsonDecode(s.publicKeyPackageJson) as Map<String, dynamic>);
      final kp = threshold.KeyPackage(
          receiverId, pI, threshold.elemBaseMul(pI), pkp.verifyingKey, 2);
      out.add((
        scriptPubkey: Uint8List.fromList(s.evtxoScriptPubkey),
        contractId: Uint8List.fromList(s.contractId),
        exitDelay: s.exitDelay,
        serverPk: Uint8List.fromList(s.serverPk),
        ownerPk: Uint8List.fromList(s.ownerPk),
        keyPackage: kp,
        publicKeyPackage: pkp,
      ));
    }
    return out;
  }

  /// Receiver side: clear a picked-up contract share from the inbox.
  Future<void> ackContractShare(Uint8List evtxoScriptPubkey) async {
    final auth = _authSig((h) => h.signForEvtxoAck());
    await _stub.evtxoAckShare(EvtxoAckShareRequest()
      ..userId = _userId!
      ..evtxoScriptPubkey = evtxoScriptPubkey
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  /// Subscribe (Phase 3) to this wallet's cosigner event stream over HTTP (SSE). For a BACKEND
  /// user that holds the connection open and reacts to events — chiefly `contract_share` (a
  /// contract share landed in our inbox). Best-effort live nudges; the inbox (`fetchContractShares`)
  /// is the durable record, so drain it on connect to catch up. REST transport only.
  Stream<({String type, Map<String, dynamic> data})> subscribeEvents() async* {
    if (_userId == null) throw StateError('Client not initialized.');
    final base = _restBaseForEvents;
    if (base == null) {
      throw StateError('Event stream is only available on the REST transport.');
    }
    final auth = _authSig((h) => h.signForEventsSubscribe());
    final uri = Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/api/u/'
        '${hex.encode(_userId!)}/events'
        '?signature=${hex.encode(auth.signature)}&timestamp_ms=${auth.timestampMs.toInt()}');
    final req = http.Request('GET', uri)..headers['accept'] = 'text/event-stream';
    final resp = await http.Client().send(req);
    if (resp.statusCode != 200) {
      throw Exception('events subscribe: HTTP ${resp.statusCode}');
    }
    String? ev;
    await for (final line
        in resp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        ev = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final raw = line.substring(5).trim();
        final data = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
        yield (type: ev ?? (data['type'] as String? ?? 'message'), data: data);
        ev = null;
      }
      // blank lines separate events; keep-alive comment lines (':') are ignored.
    }
  }


  /// Auth signature for a request. With share gating on, `_authHelper` is null and the cosigner
  /// authenticates the Bearer session token at the REST boundary, so we send an empty Schnorr
  /// signature. Un-gated, this is the usual share-derived signature.
  AuthSignature _authSig(AuthSignature Function(ClientAuthHelper) sign) {
    final h = _authHelper;
    if (h != null) return sign(h);
    return AuthSignature(
        Uint8List(0), Int64(DateTime.now().millisecondsSinceEpoch));
  }

  /// The wallet's key package carrying the REAL share for a single op. Gated: reconstruct
  /// `P_full = δ + b(seed)` from `_seedSource` (throws if no seed is wired — an ARK sign needs the
  /// PIN/passkey). Un-gated: the stored key package already holds the real share. The reconstructed
  /// share lives only for the caller's scope (best-effort wipe = it goes out of scope after use).
  Future<threshold.KeyPackage> _walletKeyPackage() async {
    final kp = _normalPolicy!.keyPackage;
    if (!_shareBlinded) return kp;
    final src = _seedSource;
    if (src == null) {
      throw StateError(
          'signing requires the wallet seed (PIN/passkey) — none configured');
    }
    final seed = await src.deriveSeed();
    final pFull = reconstructShare(
            threshold.bigIntToBytes(kp.secretShare), kp.identifier, seed)
        .scalar;
    return threshold.KeyPackage(kp.identifier, pFull, kp.verifyingShare,
        kp.verifyingKey, kp.minSigners);
  }

  /// Finalize the wallet's freshly-DKG'd share into `_normalPolicy` + auth state. When a
  /// [SeedSource] is configured, store the share BLINDED (δ) — the raw share is never persisted and
  /// never lingers in memory; it's reconstructed transiently at sign time. Auth then rides the
  /// session token (no share-derived helper). Un-gated: keep the raw share + the Schnorr helper.
  Future<void> _finalizeWalletShare(threshold.KeyPackage walletKeyPkg,
      threshold.PublicKeyPackage pubKeyPkg) async {
    _userId =
        threshold.elemSerializeCompressed(walletKeyPkg.verifyingShare).toList();
    final src = _seedSource;
    if (src != null) {
      final seed = await src.deriveSeed();
      final delta = threshold.bytesToBigInt(blindShare(
          threshold.SecretKey(walletKeyPkg.secretShare),
          walletKeyPkg.identifier,
          seed));
      final blindedKp = threshold.KeyPackage(walletKeyPkg.identifier, delta,
          walletKeyPkg.verifyingShare, walletKeyPkg.verifyingKey,
          walletKeyPkg.minSigners);
      _normalPolicy = SpendingPolicy(
          id: "normal_policy_id",
          keyPackage: blindedKp,
          publicKeyPackage: pubKeyPkg);
      _shareBlinded = true;
      _signingSecret = null;
      _authHelper = null;
    } else {
      _signingSecret = threshold.SecretKey(walletKeyPkg.secretShare);
      _normalPolicy = SpendingPolicy(
          id: "normal_policy_id",
          keyPackage: walletKeyPkg,
          publicKeyPackage: pubKeyPkg);
      _authHelper =
          ClientAuthHelper.fromSigningSecret(_signingSecret!, _userId!);
    }
  }

  /// Gate an already-DKG'd (raw) share retroactively: blind it to δ under [seed], persist δ, and drop
  /// the raw share + Schnorr auth helper. Used when the seed only exists after DKG — a passkey's PRF
  /// needs the post-DKG user id to register/assert. No-op if already gated.
  Future<void> gateShare(Uint8List seed) async {
    if (_shareBlinded) return;
    final kp = _normalPolicy?.keyPackage;
    if (kp == null) throw StateError('no wallet share to gate');
    final delta = threshold.bytesToBigInt(
        blindShare(threshold.SecretKey(kp.secretShare), kp.identifier, seed));
    _normalPolicy = SpendingPolicy(
        id: "normal_policy_id",
        keyPackage: threshold.KeyPackage(kp.identifier, delta, kp.verifyingShare,
            kp.verifyingKey, kp.minSigners),
        publicKeyPackage: _normalPolicy!.publicKeyPackage);
    _shareBlinded = true;
    _signingSecret = null;
    _authHelper = null;
    await _saveState();
    // Hive appends; without compaction the pre-gating state (raw share +
    // signingSecret) would remain readable in the box file.
    await _store.compact();
  }

  // --- SIGNING ---

  Future<threshold.Signature> sign(Uint8List message,
      {List<int>? fullTransaction, bool applyTweak = true}) async {
    final keyPackage = await _walletKeyPackage();
    final groupPubKey = _normalPolicy!.publicKeyPackage;

    if (_userId == null) {
      throw StateError("User ID is null, cannot proceed with signing.");
    }

    return signWithContext(
      message,
      keyPackage,
      groupPubKey,
      fullTransaction,
      applyTweak: applyTweak,
    );
  }

  Future<threshold.Signature> signWithContext(
    Uint8List message,
    threshold.KeyPackage keyPkg,
    threshold.PublicKeyPackage groupPubKey,
    List<int>? fullTransaction, {
    bool applyTweak = true,
    String? routeGroupKeyHex,
    List<int>? arkTx,
  }) async {
    final nonce = frost_comm.newNonce(keyPkg.secretShare);

    if (_userId == null) {
      throw StateError("User ID is null, cannot proceed with signing.");
    }

    // `user_id` is our own verifying share (auth identity); routing is by the actor URL.
    // Contract spends reuse our normal V actor, so there's no separate routing key.
    // 2. Step 1: Commitments
    final auth1 = _authSig((h) => h.signForSignStep1());
    final req = SignStep1Request()
      ..userId = _userId!
      ..hidingCommitment =
          threshold.elemSerializeCompressed(nonce.commitments.hiding)
      ..bindingCommitment =
          threshold.elemSerializeCompressed(nonce.commitments.binding)
      ..messageToSign = message
      ..signature = auth1.signature
      ..timestampMs = auth1.timestampMs;

    if (fullTransaction != null) {
      req.fullTransaction = fullTransaction;
    }
    // For a contract RECEIVER spending via the {receiver, cosigner} pairing actor, the
    // cosigner is authoritative about the message: with `ark_tx` present it takes the two-leg
    // path and signs the requested leg (else it overrides to leg 1, breaking the aggregate).
    if (arkTx != null) {
      req.arkTx = arkTx;
    }
    if (!applyTweak) {
      req.scriptPathSpend = true;
    }
    final signStep1Resp =
        await _stub.signStep1(req, routeGroupKeyHex: routeGroupKeyHex);

    // Parse Commitments
    final commitmentsMap =
        <threshold.Identifier, frost_comm.SigningCommitments>{};
    signStep1Resp.commitments.forEach((k, v) {
      final id = threshold.Identifier(BigInt.parse(k, radix: 16));
      final hiding =
          threshold.elemDeserializeCompressed(Uint8List.fromList(v.hiding));
      final binding =
          threshold.elemDeserializeCompressed(Uint8List.fromList(v.binding));
      commitmentsMap[id] = frost_comm.SigningCommitments(binding, hiding);
    });

    // 3. Step 2: Sign
    final signingPkg = frost_comm.SigningPackage(commitmentsMap, message);

    // Apply Taproot tweak for key-path spending; skip for script-path spending.
    threshold.PublicKeyPackage pubPackage;
    if (applyTweak) {
      keyPkg = keyPkg.tweak(null);
      pubPackage = groupPubKey.tweak(null);
    } else {
      pubPackage = groupPubKey;
    }

    final sigShare = frost.sign(signingPkg, nonce, keyPkg);

    // 4. Send Share & Get Result
    final auth2 = _authSig((h) => h.signForSignStep2());
    final signStep2Resp = await _stub.signStep2(
        SignStep2Request()
          ..userId = _userId!
          ..signatureShare = threshold.bigIntToBytes(sigShare.s)
          ..signature = auth2.signature
          ..timestampMs = auth2.timestampMs,
        routeGroupKeyHex: routeGroupKeyHex);

    // 5. Verify
    final R = threshold
        .elemDeserializeCompressed(Uint8List.fromList(signStep2Resp.rPoint));
    final z =
        threshold.bytesToBigInt(Uint8List.fromList(signStep2Resp.zScalar));

    final signature = threshold.Signature(R, z);

    return signature.verify(pubPackage.verifyingKey, message);
  }


  // Helpers
  Map<String, String> _buildSharesMap(
      Map<threshold.Identifier, threshold.Round2Package> shares) {
    final m = <String, String>{};
    shares.forEach((id, pkg) {
      m[threshold
          .bigIntToBytes(id.toScalar())
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()] = jsonEncode(pkg.toJson());
    });
    return m;
  }

  Map<threshold.Identifier, threshold.Round2Package> _parseShares(
      Map<String, String> raw) {
    final m = <threshold.Identifier, threshold.Round2Package>{};
    raw.forEach((k, v) {
      m[threshold.Identifier(BigInt.parse(k, radix: 16))] =
          threshold.Round2Package.fromJson(jsonDecode(v));
    });
    return m;
  }

  // --- ARK ---

  Future<GetArkInfoResponse> getArkInfo() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot get Ark info.");
    }
    final auth = _authSig((h) => h.signForGetArkInfo());
    return await _stub.getArkInfo(GetArkInfoRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  Future<String> getArkAddress() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot get Ark address.");
    }
    final auth = _authSig((h) => h.signForGetArkAddress());
    final response = await _stub.getArkAddress(GetArkAddressRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
    return response.arkAddress;
  }

  Future<String> getBoardingAddress() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot get boarding address.");
    }
    final auth = _authSig((h) => h.signForGetBoardingAddress());
    final response = await _stub.getBoardingAddress(GetBoardingAddressRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
    return response.boardingAddress;
  }

  Future<ListVtxosResponse> listVtxos() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot list VTXOs.");
    }
    final auth = _authSig((h) => h.signForListVtxos());
    return await _stub.listVtxos(ListVtxosRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  Future<ListArkTransactionsResponse> listArkTransactions() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot list Ark transactions.");
    }
    final auth = _authSig((h) => h.signForListArkTransactions());
    return await _stub.listArkTransactions(ListArkTransactionsRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  /// Send VTXOs off-chain to a recipient Ark address.
  ///
  /// 2-round flow:
  /// Phase 1: get sighashes (ark tx + checkpoint tx inputs)
  /// Phase 2: send FROST signatures, server submits to ASP + finalizes
  Future<String> sendVtxo(String recipientArkAddress, int amountSats) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot send VTXO.");
    }

    // 1. Get ArkInfo (includes checkpoint_tapscript, forfeit_address)
    final arkInfo = await getArkInfo();

    // 2. Get VTXOs from server
    final vtxosResp = await listVtxos();
    if (vtxosResp.vtxos.isEmpty) {
      throw Exception('No VTXOs available for sending');
    }

    // 3. Get change address (our own Ark address)
    final changeAddr = await getArkAddress();

    // 4. Get owner x-only pubkey (strip 02/03 prefix from userId)
    final userIdHex = hex.encode(_userId!);
    final ownerPk = userIdHex.length == 66 ? userIdHex.substring(2) : userIdHex;

    // Use exit_delay from first VTXO (all should be same type)
    // VTXOs from server don't carry exit_delay, so use unilateral_exit_delay
    final exitDelay = arkInfo.unilateralExitDelay.toInt();

    // 5. Build Ark send transaction via FFI (client-side)
    final vtxoInputs = vtxosResp.vtxos.map((v) => {
      'txid': v.txid,
      'vout': v.vout,
      'amount': v.amount.toInt(),
    }).toList();

    final arkInfoMap = {
      'signer_pubkey': arkInfo.signerPubkey,
      'forfeit_pubkey': arkInfo.forfeitPubkey,
      'forfeit_address': arkInfo.forfeitAddress,
      'checkpoint_tapscript': arkInfo.checkpointTapscript,
      'network': arkInfo.network,
      'session_duration': arkInfo.sessionDuration.toInt(),
      'unilateral_exit_delay': arkInfo.unilateralExitDelay.toInt(),
      'boarding_exit_delay': arkInfo.boardingExitDelay.toInt(),
      'vtxo_min_amount': arkInfo.vtxoMinAmount.toInt(),
      'dust': arkInfo.dust.toInt(),
    };

    final session = ArkSendSession.build(
      ownerPk: ownerPk,
      vtxoInputs: vtxoInputs,
      recipientArkAddress: recipientArkAddress,
      amountSats: amountSats,
      changeArkAddress: changeAddr,
      exitDelay: exitDelay,
      arkInfo: arkInfoMap,
    );

    try {
      // 6. FROST sign each sighash. Pass real PSBT bytes as fullTransaction so
      //    the server independently evaluates the same net spend.
      final sigHexes = <String>[];
      for (final sighash in session.sighashes) {
        final sig = await sign(
          sighash,
          fullTransaction: session.arkTxBytes,
          applyTweak: false, // script-path spend
        );

        final rBytes = threshold.elemSerializeCompressed(sig.R);
        final xOnly = rBytes.sublist(1);
        final zBytes = threshold.bigIntToBytes(sig.Z);

        final schnorrSig = Uint8List(64);
        schnorrSig.setRange(0, 32, xOnly);
        schnorrSig.setRange(32, 64, zBytes);

        sigHexes.add(hex.encode(schnorrSig));
      }

      // 7. Insert signatures into PSBTs via FFI
      final signed = ArkSendSession.insertSignatures(session.handle, sigHexes);

      // 8. Submit via server proxy (server forwards to ASP + counter-signs)
      final spentOutpoints = vtxosResp.vtxos.map((v) => '${v.txid}:${v.vout}').toList();

      final auth = _authSig((h) => h.signForSendVtxo());
      final resp = await _stub.submitArkSend(SubmitArkSendRequest()
        ..userId = _userId!
        ..signature = auth.signature
        ..timestampMs = auth.timestampMs
        ..signedArkTxB64 = signed.signedArkTxB64
        ..signedCheckpointTxsB64.addAll(signed.signedCheckpointTxsB64)
        ..spentOutpoints.addAll(spentOutpoints));

      return resp.arkTxid;
    } finally {
      ArkSendSession.free(session.handle);
    }
  }

  /// Submits signed Ark PSBTs to the ASP via the server proxy.
  Future<String> submitArkSend({
    required String signedArkTxB64,
    required List<String> signedCheckpointTxsB64,
    required List<String> spentOutpoints,
  }) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot submit Ark send.");
    }
    final auth = _authSig((h) => h.signForSendVtxo());
    final resp = await _stub.submitArkSend(SubmitArkSendRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs
      ..signedArkTxB64 = signedArkTxB64
      ..signedCheckpointTxsB64.addAll(signedCheckpointTxsB64)
      ..spentOutpoints.addAll(spentOutpoints));
    return resp.arkTxid;
  }

  Future<RedeemVtxoResponse> redeemVtxo(String onChainAddress, int amountSats) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot redeem VTXO.");
    }
    final auth = _authSig((h) => h.signForRedeemVtxo());
    return await _stub.redeemVtxo(RedeemVtxoRequest()
      ..userId = _userId!
      ..onChainAddress = onChainAddress
      ..amount = Int64(amountSats)
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  /// Settle on-chain boarding UTXOs into Ark VTXOs.
  /// Returns the commitment txid when settled.
  ///
  /// Spending policies do NOT gate settling — they gate fund egress (sends
  /// and redeems), not "promote my boarding UTXO into a VTXO." Server-side
  /// `SignStep1` forces the normal key package whenever an active settle
  /// or delegate session is in flight, so no PIN is required.
  /// [boardingUtxos] are the wallet-scanned on-chain boarding outputs to settle
  /// — the cosigner no longer scans the chain. They are sent on the phase-1
  /// (no-signatures) request.
  Future<String> settle({List<BoardingUtxo> boardingUtxos = const []}) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot settle.");
    }

    List<List<int>> signedMessages = [];

    while (true) {
      final auth = _authSig((h) => h.signForSettle());
      final request = SettleRequest()
        ..userId = _userId!
        ..signature = auth.signature
        ..timestampMs = auth.timestampMs;
      if (signedMessages.isNotEmpty) {
        request.signedMessages.addAll(signedMessages);
      } else {
        // Phase 1: supply the boarding UTXOs the wallet found on-chain.
        request.boardingUtxos.addAll(boardingUtxos);
      }

      final response = await _stub.settle(request);
      final status = response.status;

      if (status == SettleResponse_Status.SETTLED) {
        return response.commitmentTxid;
      }

      if (status == SettleResponse_Status.ERROR) {
        throw Exception('Settle error: ${response.errorMessage}');
      }

      if (status == SettleResponse_Status.SIGNING_REQUIRED) {
        signedMessages = [];
        final scriptPath = response.scriptPathSpend;

        for (final sighash in response.messagesToSign) {
          final sighashBytes = Uint8List.fromList(sighash);

          // Settling always signs with the normal policy KP.
          final sig = await sign(
            sighashBytes,
            applyTweak: !scriptPath,
          );

          // Convert threshold.Signature to 64-byte BIP-340 Schnorr sig
          // R: compressed point (33 bytes) -> x-only (32 bytes, drop prefix)
          final rBytes = threshold.elemSerializeCompressed(sig.R);
          final xOnly = rBytes.sublist(1);
          // Z: scalar -> 32 bytes big-endian
          final zBytes = threshold.bigIntToBytes(sig.Z);

          final schnorrSig = Uint8List(64);
          schnorrSig.setRange(0, 32, xOnly);
          schnorrSig.setRange(32, 64, zBytes);

          signedMessages.add(schnorrSig.toList());
        }
        // Loop back to call Settle again with signatures
        continue;
      }

      if (status == SettleResponse_Status.WAITING_FOR_BATCH) {
        // Server is still processing, wait and retry
        await Future.delayed(Duration(seconds: 2));
        signedMessages = []; // No signatures to send when polling
        continue;
      }
    }
  }

  /// Settle existing VTXOs using the delegate pattern.
  ///
  /// Two rounds. Phase 1 fetches sighashes; phase 2 sends FROST signatures.
  /// When [storeOnly] is true, the cosigner stores the signed intent and
  /// drives the batch later when the auto-settle threshold is met (returns
  /// DELEGATED, commitment txid is empty). When false, the cosigner joins
  /// the next batch immediately (returns SETTLED with the commitment txid).
  ///
  /// Like [settle], no PIN/policy is required. Settling is a re-packaging of
  /// the user's own funds, not egress; server-side `SignStep1` forces the
  /// normal key package while a delegate session is active.
  Future<String> settleDelegate({bool storeOnly = false}) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot settleDelegate.");
    }

    // Phase 1: request sighashes
    final auth1 = _authSig((h) => h.signForSettleDelegate());
    final req1 = SettleDelegateRequest()
      ..userId = _userId!
      ..signature = auth1.signature
      ..timestampMs = auth1.timestampMs;

    final resp1 = await _stub.settleDelegate(req1);

    if (resp1.status == SettleDelegateResponse_Status.ERROR) {
      throw Exception('SettleDelegate error: ${resp1.errorMessage}');
    }
    if (resp1.status != SettleDelegateResponse_Status.SIGNING_REQUIRED) {
      throw Exception('Expected SIGNING_REQUIRED, got ${resp1.status}');
    }

    // FROST sign all sighashes
    List<List<int>> signedMessages = [];
    final scriptPath = resp1.scriptPathSpend;

    for (final sighash in resp1.messagesToSign) {
      final sighashBytes = Uint8List.fromList(sighash);
      // Always sign with normal policy KP — see class docstring above.
      final sig = await sign(
        sighashBytes,
        applyTweak: !scriptPath,
      );

      final rBytes = threshold.elemSerializeCompressed(sig.R);
      final xOnly = rBytes.sublist(1);
      final zBytes = threshold.bigIntToBytes(sig.Z);

      final schnorrSig = Uint8List(64);
      schnorrSig.setRange(0, 32, xOnly);
      schnorrSig.setRange(32, 64, zBytes);

      signedMessages.add(schnorrSig.toList());
    }

    // Phase 2: send signatures. When storeOnly, the server holds the intent
    // and the auto-settle tick task drives it later.
    final auth2 = _authSig((h) => h.signForSettleDelegate());
    final req2 = SettleDelegateRequest()
      ..userId = _userId!
      ..signature = auth2.signature
      ..timestampMs = auth2.timestampMs
      ..storeOnly = storeOnly;
    req2.signedMessages.addAll(signedMessages);

    final resp2 = await _stub.settleDelegate(req2);

    if (resp2.status == SettleDelegateResponse_Status.ERROR) {
      throw Exception('SettleDelegate error: ${resp2.errorMessage}');
    }
    final isDelegatedOk = storeOnly
        ? resp2.status == SettleDelegateResponse_Status.DELEGATED
        : resp2.status == SettleDelegateResponse_Status.SETTLED;
    if (!isDelegatedOk) {
      throw Exception(
          'Expected ${storeOnly ? "DELEGATED" : "SETTLED"}, got ${resp2.status}');
    }

    return resp2.commitmentTxid; // empty when DELEGATED
  }

  /// Register an FCM token so the cosigner can wake the device on receive.
  /// Idempotent — safe to call on every login and token rotation.
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String appVersion = '',
  }) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot registerDeviceToken.");
    }
    final auth = _authSig((h) => h.signForRegisterDeviceToken());
    final req = RegisterDeviceTokenRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs
      ..fcmToken = fcmToken
      ..platform = platform
      ..appVersion = appVersion;
    await _stub.registerDeviceToken(req);
  }

}
