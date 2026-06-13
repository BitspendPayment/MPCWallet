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

  threshold.SecretKey? _signingSecret;

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
        '$op requires the recovery signer to be attached '
        '(call loadRecoverySigner first)',
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
    _store = WalletStore(
      boxName: storageId ?? 'mpc_wallet_state_default',
      cipher: encryptionCipher,
    );
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

    // Restore signing secret for authentication
    if (state['signingSecret'] != null) {
      final secretHex = state['signingSecret'] as String;
      final secretBytes = Uint8List.fromList(hex.decode(secretHex));
      _signingSecret =
          threshold.SecretKey(threshold.bytesToBigInt(secretBytes));
      _authHelper =
          ClientAuthHelper.fromSigningSecret(_signingSecret!, _userId!);
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
    if (_normalPolicy != null) {
      state['spendingPolicies'] = _normalPolicy!.toJson();
    }
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

    // The wallet's DKG share is its signing + auth key.
    _signingSecret = threshold.SecretKey(walletKeyPkg.secretShare);
    _userId = threshold
        .elemSerializeCompressed(walletKeyPkg.verifyingShare)
        .toList();

    _normalPolicy = SpendingPolicy(
        id: "normal_policy_id",
        keyPackage: walletKeyPkg,
        publicKeyPackage: pubKeyPkg);

    _authHelper = ClientAuthHelper.fromSigningSecret(_signingSecret!, _userId!);

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

    // 3. Send Round1 packages to server with is_restore flag
    final hwR1Json = jsonEncode(restoreInit.round1Package.toJson());

    final reqWallet = DKGStep1Request()
      ..userId = tempUserId
      ..identifier = walletIdentifier.serialize()
      ..round1Package = '' // passive receiver
      ..isRestore = true;

    final reqHw = DKGStep1Request()
      ..userId = tempUserId
      ..identifier = hwIdentifier.serialize()
      ..round1Package = hwR1Json
      ..isRestore = true;

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

    // 11. Wallet's new secret share becomes the auth key
    _signingSecret = threshold.SecretKey(walletKeyPkg.secretShare);
    _userId = threshold
        .elemSerializeCompressed(walletKeyPkg.verifyingShare)
        .toList();
    _recoveryId = hwVerifyingKey.toList();

    // 12. Store policies
    _normalPolicy = SpendingPolicy(
        id: "normal_policy_id",
        keyPackage: walletKeyPkg,
        publicKeyPackage: pubKeyPkg);

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

    _authHelper = ClientAuthHelper.fromSigningSecret(_signingSecret!, _userId!);

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

  // --- eVTXO KEY RESHARE ---

  /// Create a contract eVTXO key `V′` via a 2-of-2 RESHARE {author, cosigner}: the
  /// author (this wallet) and the cosigner each deal a fresh non-zero Δ on top of
  /// the main key V, yielding `V′ = V + Δ_author + Δ_cosigner` (≠ V) bound to the
  /// contract. The fresh key can later be re-shared to other participants for a
  /// multi-user contract. The cosigner validates `sha256(contractWasm)==contractId`,
  /// stores the wasm, finalizes V′, derives + registers the eVTXO spk from V′ + the
  /// ASP `serverPk`/`exitDelay`. Returns the spk plus the author's V′ key package +
  /// the V′ PKP (used to spend the contract's cooperative leaf).
  Future<
      ({
        Uint8List scriptPubkey,
        threshold.KeyPackage keyPackage,
        threshold.PublicKeyPackage publicKeyPackage,
      })> createEvtxoKey(
    Uint8List contractId,
    Uint8List contractWasm,
    Uint8List serverPk,
    int exitDelay,
  ) async {
    if (!isInitialized || _userId == null) {
      throw StateError('Client not initialized (DKG not run).');
    }

    final oldKp = _normalPolicy!.keyPackage;
    final oldPkp = _normalPolicy!.publicKeyPackage;
    final authorId = oldKp.identifier;
    final ts = Int64(DateTime.now().millisecondsSinceEpoch);

    // 1. Author deals a fresh non-zero Δ_author under its EXISTING identifier.
    final (r1Secret, r1Pkg) = threshold.dkgResharePart1(authorId, 2, 2);

    // Step 1 — send the author's round1 (dealer) + the contract/ASP params. The
    // cosigner self-deals Δ_cosigner and returns both dealers' round1 packages.
    final step1Resp = await _stub.evtxoKeygenStep1(EvtxoKeygenStep1Request()
      ..userId = _userId!
      ..identifier = authorId.serialize()
      ..round1Package = jsonEncode(r1Pkg.toJson())
      ..contractId = contractId
      ..contractWasm = contractWasm
      ..serverPk = serverPk
      ..exitDelay = exitDelay
      ..signature = Uint8List(0) // eVTXO-keygen path is unauthenticated for now
      ..timestampMs = ts);

    // The cosigner's round1 package (the other dealer).
    final round1Pkgs = <threshold.Identifier, threshold.Round1Package>{};
    step1Resp.round1Packages.forEach((k, v) {
      if (v.isEmpty) return;
      final id = threshold.Identifier(BigInt.parse(k, radix: 16));
      if (id == authorId) return; // skip our own
      round1Pkgs[id] = threshold.Round1Package.fromJson(jsonDecode(v));
    });

    // Author computes its round2 share for the cosigner.
    final (r2Secret, sharesFromAuthor) =
        threshold.dkgPart2(r1Secret, round1Pkgs);

    // Step 2 — trigger the cosigner to compute its round2 share for the author.
    await _stub.evtxoKeygenStep2(EvtxoKeygenStep2Request()
      ..userId = _userId!
      ..identifier = authorId.serialize()
      ..signature = Uint8List(0)
      ..timestampMs = ts);

    // Step 3 — send the author's round2 share; the cosigner finalizes V′, registers
    // the eVTXO, and returns its round2 share for the author + the spk.
    final step3Resp = await _stub.evtxoKeygenStep3(EvtxoKeygenStep3Request()
      ..userId = _userId!
      ..identifier = authorId.serialize()
      ..round2PackagesForOthers.addAll(_buildSharesMap(sharesFromAuthor))
      ..signature = Uint8List(0)
      ..timestampMs = ts);

    // Author finalizes the reshare → its V′ key package + the V′ PKP. Final
    // shareholders = both dealers {author, cosigner}.
    final sharesForAuthor = _parseShares(step3Resp.round2PackagesForMe);
    final finalIds = <threshold.Identifier>[authorId, ...round1Pkgs.keys];
    final (evtxoKp, evtxoPkp) = threshold.dkgResharePart3(
      r2Secret,
      round1Pkgs,
      sharesForAuthor,
      oldPkp,
      oldKp,
      finalIds,
    );

    return (
      scriptPubkey: Uint8List.fromList(step3Resp.evtxoScriptPubkey),
      keyPackage: evtxoKp,
      publicKeyPackage: evtxoPkp,
    );
  }

  // --- MULTI-USER CONTRACT ONBOARDING ---

  /// Author onboards [recipientVk] to the contract eVTXO [evtxoScriptPubkey]. Computes
  /// the author's key-preserving refresh half onto the participant's identifier
  /// (`id_i = derive(recipientVk)`) and submits it to the contract cosigner, which
  /// forms the participant's counter-share `C_i` + the 2-entry V′ PKP and holds both
  /// ECIES halves for the participant to pick up. Neither side learns `P_i`.
  /// [evtxoKeyPkg]/[evtxoPkp] = the author's V′ share + V′ PKP from [createEvtxoKey].
  Future<void> onboardParticipant({
    required Uint8List evtxoScriptPubkey,
    required Uint8List recipientVk,
    required threshold.KeyPackage evtxoKeyPkg,
    required threshold.PublicKeyPackage evtxoPkp,
  }) async {
    final authorId = evtxoKeyPkg.identifier;
    // The cosigner's id is the other entry of the 2-entry V′ PKP.
    final cosignerId =
        evtxoPkp.verifyingShares.keys.firstWhere((id) => id != authorId);
    final idSet = <threshold.Identifier>[authorId, cosignerId];
    final participantId = threshold.Identifier.derive(recipientVk);
    final slope = threshold.modNRandom();

    final (aAtP, aAtC) = threshold.refreshShareToId(
        evtxoKeyPkg, idSet, participantId, cosignerId, slope);
    final aAtParticipantPoint =
        Uint8List.fromList(hex.decode(threshold.elemBaseMul(aAtP)));
    final eciesA = threshold.eciesEncrypt(threshold.bigIntToBytes(aAtP), recipientVk);
    final vPrime = threshold.elemSerializeCompressed(evtxoPkp.verifyingKey.E);

    final auth = _authHelper!.signForEvtxoOnboard();
    await _stub.evtxoOnboard(EvtxoOnboardRequest()
      ..userId = _userId!
      ..contractGroupId = vPrime
      ..evtxoScriptPubkey = evtxoScriptPubkey
      ..recipientVk = recipientVk
      ..aAtCosigner = threshold.bigIntToBytes(aAtC)
      ..aAtParticipantPoint = aAtParticipantPoint
      ..eciesAAtParticipant = eciesA
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  /// Participant fetches the contract shares held for it, decrypts BOTH ECIES halves
  /// with its own signing secret, sums them into `P_i`, and returns the spendable
  /// context per contract eVTXO (the V′ key package + PKP + the taptree parameters).
  Future<
      List<
          ({
            Uint8List scriptPubkey,
            Uint8List contractGroupId,
            Uint8List contractId,
            int exitDelay,
            Uint8List ownerPk,
            threshold.KeyPackage keyPackage,
            threshold.PublicKeyPackage publicKeyPackage,
          })>> fetchContractShares() async {
    if (_userId == null || _signingSecret == null) {
      throw StateError('Client not initialized.');
    }
    final auth = _authHelper!.signForEvtxoPending();
    final resp = await _stub.evtxoPendingShares(EvtxoPendingSharesRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);

    final participantId =
        threshold.Identifier.derive(Uint8List.fromList(_userId!));
    final secret = _signingSecret!.scalar;
    final out = <
        ({
          Uint8List scriptPubkey,
          Uint8List contractGroupId,
          Uint8List contractId,
          int exitDelay,
          Uint8List ownerPk,
          threshold.KeyPackage keyPackage,
          threshold.PublicKeyPackage publicKeyPackage,
        })>[];
    for (final s in resp.shares) {
      final aAtP = threshold.bytesToBigInt(threshold.eciesDecrypt(
          Uint8List.fromList(s.eciesHalfAuthor), secret));
      final bAtP = threshold.bytesToBigInt(threshold.eciesDecrypt(
          Uint8List.fromList(s.eciesHalfCosigner), secret));
      final pI = threshold.modNAdd(aAtP, bAtP);
      final pkp = threshold.PublicKeyPackage.fromJson(
          jsonDecode(s.publicKeyPackageJson) as Map<String, dynamic>);
      final kp = threshold.KeyPackage(
          participantId, pI, threshold.elemBaseMul(pI), pkp.verifyingKey, 2);
      out.add((
        scriptPubkey: Uint8List.fromList(s.evtxoScriptPubkey),
        contractGroupId: Uint8List.fromList(s.contractGroupId),
        contractId: Uint8List.fromList(s.contractId),
        exitDelay: s.exitDelay,
        ownerPk: Uint8List.fromList(s.ownerPk),
        keyPackage: kp,
        publicKeyPackage: pkp,
      ));
    }
    return out;
  }

  /// Clear a picked-up contract share from the participant's inbox.
  Future<void> ackContractShare(Uint8List evtxoScriptPubkey) async {
    final auth = _authHelper!.signForEvtxoAck();
    await _stub.evtxoAckShare(EvtxoAckShareRequest()
      ..userId = _userId!
      ..evtxoScriptPubkey = evtxoScriptPubkey
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  // --- SIGNING ---

  Future<threshold.Signature> sign(Uint8List message,
      {List<int>? fullTransaction, bool applyTweak = true}) async {
    final keyPackage = _normalPolicy!.keyPackage;
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
    Uint8List? contractGroupId,
  }) async {
    final nonce = frost_comm.newNonce(keyPkg.secretShare);

    if (_userId == null) {
      throw StateError("User ID is null, cannot proceed with signing.");
    }

    // For a contract eVTXO spend: route to the contract actor (GroupID = V′) but
    // authenticate as ourselves — claimed_share = our verifying share, and the auth
    // signature still binds our own user id (the cosigner verifies it via
    // auth_check_group + selects our recipient counter-share). Normal sign: route to
    // our own actor, no claimed share.
    final routeId = contractGroupId ?? _userId!;
    final claimedShare = contractGroupId != null ? _userId! : Uint8List(0);

    // 2. Step 1: Commitments
    final auth1 = _authHelper!.signForSignStep1();
    final req = SignStep1Request()
      ..userId = routeId
      ..claimedShare = claimedShare
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
    if (!applyTweak) {
      req.scriptPathSpend = true;
    }
    final signStep1Resp = await _stub.signStep1(req);

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
    final auth2 = _authHelper!.signForSignStep2();
    final signStep2Resp = await _stub.signStep2(SignStep2Request()
      ..userId = routeId
      ..claimedShare = claimedShare
      ..signatureShare = threshold.bigIntToBytes(sigShare.s)
      ..signature = auth2.signature
      ..timestampMs = auth2.timestampMs);

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
    final auth = _authHelper!.signForGetArkInfo();
    return await _stub.getArkInfo(GetArkInfoRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  Future<String> getArkAddress() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot get Ark address.");
    }
    final auth = _authHelper!.signForGetArkAddress();
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
    final auth = _authHelper!.signForGetBoardingAddress();
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
    final auth = _authHelper!.signForListVtxos();
    return await _stub.listVtxos(ListVtxosRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  Future<ListArkTransactionsResponse> listArkTransactions() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot list Ark transactions.");
    }
    final auth = _authHelper!.signForListArkTransactions();
    return await _stub.listArkTransactions(ListArkTransactionsRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
  }

  Future<CheckBoardingBalanceResponse> checkBoardingBalance() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot check boarding balance.");
    }
    final auth = _authHelper!.signForCheckBoardingBalance();
    return await _stub.checkBoardingBalance(CheckBoardingBalanceRequest()
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

      final auth = _authHelper!.signForSendVtxo();
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
    final auth = _authHelper!.signForSendVtxo();
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
    final auth = _authHelper!.signForRedeemVtxo();
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
  Future<String> settle() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot settle.");
    }

    List<List<int>> signedMessages = [];

    while (true) {
      final auth = _authHelper!.signForSettle();
      final request = SettleRequest()
        ..userId = _userId!
        ..signature = auth.signature
        ..timestampMs = auth.timestampMs;
      if (signedMessages.isNotEmpty) {
        request.signedMessages.addAll(signedMessages);
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
    final auth1 = _authHelper!.signForSettleDelegate();
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
    final auth2 = _authHelper!.signForSettleDelegate();
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
    final auth = _authHelper!.signForRegisterDeviceToken();
    final req = RegisterDeviceTokenRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs
      ..fcmToken = fcmToken
      ..platform = platform
      ..appVersion = appVersion;
    await _stub.registerDeviceToken(req);
  }

  // --- BROADCAST ---
  Future<String> broadcastTransaction(String txHex) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot broadcast transaction.");
    }

    final request = BroadcastTransactionRequest()
      ..userId = _userId!
      ..txHex = txHex;

    final response = await _stub.broadcastTransaction(request);
    return response.txId;
  }

  // --- SYNC ---
  Future<List<UtxoInfo>> fetchHistory() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot fetch history.");
    }

    final auth = _authHelper!.signForFetchHistory();
    final response = await _stub.fetchHistory(FetchHistoryRequest()
      ..userId = _userId!
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
    return response.utxos;
  }

  Stream<TransactionNotification> subscribeToHistory() {
    if (_userId == null) {
      throw StateError("User ID is null, cannot subscribe to history.");
    }

    if (_stub is GrpcWalletApi) {
      final grpc = _stub;
      final auth = _authHelper!.signForSubscribeHistory();
      return grpc.subscribeToHistory(SubscribeToHistoryRequest()
        ..userId = _userId!
        ..signature = auth.signature
        ..timestampMs = auth.timestampMs);
    }
    // REST transport: no streaming, return empty stream (caller uses polling).
    return const Stream.empty();
  }

  Future<List<TransactionSummary>> fetchRecentTransactions() async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot fetch recent transactions.");
    }

    final auth = _authHelper!.signForFetchRecentTransactions();
    final response =
        await _stub.fetchRecentTransactions(FetchRecentTransactionsRequest()
          ..userId = _userId!
          ..signature = auth.signature
          ..timestampMs = auth.timestampMs);
    return response.transactions;
  }
}
