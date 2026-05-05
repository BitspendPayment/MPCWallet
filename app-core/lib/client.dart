import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_core/policy.dart';
import 'package:app_core/auth_helper.dart';
import 'package:app_core/ark/ark_send.dart';
import 'package:grpc/grpc.dart';
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
import 'package:crypto/crypto.dart';
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
  Map<String, ProtectedPolicy> _protectedPolicies;

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
    int maxSigners = 3,
    int minSigners = 2,
    String? storageId,
    HiveCipher? encryptionCipher,
    HardwareSignerInterface? hardwareSigner,
  })  : _stub = GrpcWalletApi(channel),
        _maxSigners = maxSigners,
        _minSigners = minSigners,
        _hardwareSigner = hardwareSigner,
        _protectedPolicies = {} {
    _store = WalletStore(
      boxName: storageId ?? 'mpc_wallet_state_default',
      cipher: encryptionCipher,
    );
  }

  /// Create an MpcClient using REST transport (HTTP/1.1).
  MpcClient.rest(
    String baseUrl, {
    int maxSigners = 3,
    int minSigners = 2,
    String? storageId,
    HiveCipher? encryptionCipher,
    HardwareSignerInterface? hardwareSigner,
    http.Client? httpClient,
  })  : _stub = RestWalletApi(baseUrl, httpClient: httpClient),
        _maxSigners = maxSigners,
        _minSigners = minSigners,
        _hardwareSigner = hardwareSigner,
        _protectedPolicies = {} {
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
    int maxSigners = 3,
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
        _hardwareSigner = hardwareSigner,
        _protectedPolicies = {} {
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

  bool get isInitialized => _normalPolicy != null && _recoveryPolicy != null;

  bool get hasSpendingPolicy => _protectedPolicies.isNotEmpty;

  ProtectedPolicy? get activeSpendingPolicy =>
      _protectedPolicies.isNotEmpty ? _protectedPolicies.values.last : null;

  List<ProtectedPolicy> get spendingPolicies =>
      _protectedPolicies.values.toList();

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

    if (state['protectedPolicies'] != null) {
      final pp = Map<String, dynamic>.from(state['protectedPolicies'] as Map);
      pp.forEach((k, v) {
        _protectedPolicies[k] =
            ProtectedPolicy.fromJson(Map<String, dynamic>.from(v as Map));
      });
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
    if (_protectedPolicies.isNotEmpty) {
      state['protectedPolicies'] =
          _protectedPolicies.map((k, v) => MapEntry(k, v.toJson()));
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
    final signer = _requireSigner('doDkg');

    // 0. Quick connectivity test
    print('[DKG] Step 0: Testing signer connectivity (getInfo)...');
    try {
      final info = await signer.getInfo();
      print('[DKG] Step 0: Signer responded: hasKeyPackage=${info.hasKeyPackage}');
    } catch (e) {
      print('[DKG] Step 0: Signer getInfo FAILED: $e');
    }

    // 1. Hardware signer generates secret (dealer)
    print('[DKG] Step 1: Calling signer.dkgInit...');
    final dkgInit = await signer.dkgInit(_maxSigners, _minSigners);
    print('[DKG] Step 1: signer.dkgInit complete');
    final hwVerifyingKey = dkgInit.verifyingKeyBytes;
    final hwIdentifier = dkgInit.identifier;

    // 2. Derive wallet identifier deterministically from HW signer's VK
    final walletIdInput = Uint8List.fromList(
      [...'wallet:'.codeUnits, ...hwVerifyingKey],
    );
    final walletIdentifier = threshold.Identifier.derive(walletIdInput);

    // Use HW VK as temporary session key during DKG
    final tempUserId = Uint8List.fromList(hwVerifyingKey);

    // 3. Send Round1 packages to server:
    //    - Wallet: empty round1 = passive receiver
    //    - HW signer: actual round1 = dealer
    final hwR1Json = jsonEncode(dkgInit.round1Package.toJson());

    final reqWallet = DKGStep1Request()
      ..userId = tempUserId
      ..identifier = walletIdentifier.serialize()
      ..round1Package = ''; // passive receiver

    final reqHw = DKGStep1Request()
      ..userId = tempUserId
      ..identifier = hwIdentifier.serialize()
      ..round1Package = hwR1Json;

    print('[DKG] Step 1: Sending DKGStep1 to server...');
    final step1Futures = await Future.wait(
        [_stub.dKGStep1(reqWallet), _stub.dKGStep1(reqHw)]);
    final step1Resp = step1Futures[0];
    print('[DKG] Step 1: Server responded with ${step1Resp.round1Packages.length} packages');

    // 4. Trigger Step 2 on server (server computes round2)
    print('[DKG] Step 2: Calling DKGStep2...');
    await _stub.dKGStep2(DKGStep2Request()..userId = tempUserId);
    print('[DKG] Step 2: Server responded');

    // 5. Parse dealer R1 packages (for HW signer and wallet)
    final dealerR1ForHw = <threshold.Identifier, threshold.Round1Package>{};
    final dealerR1ForWallet = <threshold.Identifier, threshold.Round1Package>{};

    step1Resp.round1Packages.forEach((k, v) {
      if (v.isEmpty) return; // skip passive receiver entries
      final id = threshold.Identifier(BigInt.parse(k, radix: 16));
      final pkg = threshold.Round1Package.fromJson(jsonDecode(v));
      // HW signer needs all other dealers' R1 (= server's)
      if (id != hwIdentifier) dealerR1ForHw[id] = pkg;
      // Wallet needs all dealers' R1 (= HW signer + server)
      dealerR1ForWallet[id] = pkg;
    });

    // 6. HW signer computes shares for server + wallet
    print('[DKG] Step 3: Calling signer.dkgRound2 (${dealerR1ForHw.length} packages)...');
    final sharesFromHw = await signer.dkgRound2(
      dealerR1ForHw,
      receiverIdentifiers: [walletIdentifier],
    );
    print('[DKG] Step 3: signer.dkgRound2 complete');

    // 7. Send Round2 packages to server
    //    - HW signer: actual shares for others
    //    - Wallet: empty (passive receiver)
    final reqStep3Hw = DKGStep3Request()
      ..userId = tempUserId
      ..identifier = threshold.bigIntToBytes(hwIdentifier.toScalar())
      ..round2PackagesForOthers.addAll(_buildSharesMap(sharesFromHw));

    final reqStep3Wallet = DKGStep3Request()
      ..userId = tempUserId
      ..identifier = threshold.bigIntToBytes(walletIdentifier.toScalar());
    // wallet sends no round2 packages (passive receiver)

    print('[DKG] Step 3: Sending DKGStep3 to server...');
    final step3Futures = await Future.wait(
        [_stub.dKGStep3(reqStep3Wallet), _stub.dKGStep3(reqStep3Hw)]);
    print('[DKG] Step 3: Server responded');

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

    // 10. HW signer finalizes (stores key internally)
    final dkgResult = await signer.dkgRound3(
      dealerR1ForHw,
      sharesForHw,
      receiverIdentifiers: [walletIdentifier],
    );

    // 11. Wallet's DKG secret share becomes the auth key
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

    // Recovery policy: secret share stays on hardware signer (store zero locally)
    final recoveryVerifyingShare =
        pubKeyPkg.verifyingShares[dkgResult.identifier];
    if (recoveryVerifyingShare == null) {
      throw StateError("Recovery identifier not found in public key package");
    }

    final recoveryKeyPkg = threshold.KeyPackage(
      dkgResult.identifier,
      BigInt.zero, // secret stays on hardware signer
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

    // Clear protected policies (verifying shares changed, old keys invalid)
    _protectedPolicies.clear();

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

  // --- REFRESH ---

  Future<void> createSpendingPolicy(
      Duration interval, Int64 thresholdAmount, String pin) async {
    if (!isInitialized) {
      throw StateError("Client not initialized (DKG not run).");
    }

    final seed = sha256.convert(utf8.encode(pin)).bytes;

    // Part 1: Generate Refresh Secrets
    // We use 2-party refresh (Client + Server) for Policy Creation.
    final refreshTotalParties = 2;
    final refreshThreshold = 2; // 2-of-2

    if (_userId == null) {
      throw StateError("Signing secret is null, cannot proceed with refresh.");
    }

    final signingIdentifier = _normalPolicy!.keyPackage.identifier;

    final (r1Sec1, r1Pub1) = threshold.dkgRefreshPart1(
        signingIdentifier, refreshTotalParties, refreshThreshold,
        seed: seed);

    if (_userId == null) {
      throw StateError("User ID is null, cannot proceed with refresh.");
    }

    // Step 1: Exchange
    final auth1 = _authHelper!.signForRefreshStep1();
    final req1 = RefreshStep1Request()
      ..userId = _userId!
      ..round1Package = jsonEncode(r1Pub1.toJson())
      ..interval = Int64(interval.inSeconds)
      ..thresholdAmount = thresholdAmount
      ..signature = auth1.signature
      ..timestampMs = auth1.timestampMs;

    final step1Resp = await _stub.refreshStep1(req1);

    // Step 2: Shares
    final auth2 = _authHelper!.signForRefreshStep2();
    final req2_1 = RefreshStep2Request()
      ..userId = _userId!
      ..signature = auth2.signature
      ..timestampMs = auth2.timestampMs;

    await _stub.refreshStep2(req2_1);

    // Parse R1 packages (includes server's)
    final round1PkgsMap1 = <threshold.Identifier, threshold.Round1Package>{};

    step1Resp.round1Packages.forEach((k, v) {
      final id_temp = threshold.Identifier(BigInt.parse(k, radix: 16));
      final pkg = threshold.Round1Package.fromJson(jsonDecode(v));
      if (id_temp != signingIdentifier) round1PkgsMap1[id_temp] = pkg;
    });

    // Compute shares
    final (r2Sec1, sharesFrom1) =
        threshold.dkgRefreshPart2(r1Sec1, round1PkgsMap1);

    // Step 3: Finalize
    final auth3 = _authHelper!.signForRefreshStep3();
    final req3_1 = RefreshStep3Request()
      ..userId = _userId!
      ..round2PackagesForOthers.addAll(_buildSharesMap(sharesFrom1))
      ..signature = auth3.signature
      ..timestampMs = auth3.timestampMs;

    final step3Resp1 = await _stub.refreshStep3(req3_1);

    final sharesForMe1 = _parseShares(step3Resp1.round2PackagesForMe);

    final normalKeyPackage1 = _normalPolicy!.keyPackage;
    final normalPubPackage = _normalPolicy!.publicKeyPackage;

    final (keyPkg1, pubKeyPkg1) = threshold.dkgRefreshPart3(r2Sec1,
        round1PkgsMap1, sharesForMe1, normalPubPackage, normalKeyPackage1);

    // Compute protected key for Identity 1
    // myUpdate is evaluatePolynomial(myId, coeffs)
    final myUpdate =
        threshold.evaluatePolynomial(signingIdentifier, r1Sec1.coefficients);
    final newSecret = keyPkg1.secretShare;

    var diff = (newSecret - myUpdate);

    final protectedKeyPkg = threshold.KeyPackage(
      keyPkg1.identifier,
      diff, // Cleared
      keyPkg1.verifyingShare,
      keyPkg1.verifyingKey,
      keyPkg1.minSigners,
    );

    _protectedPolicies[step1Resp.policyId] = ProtectedPolicy(
      id: step1Resp.policyId,
      keyPackage: protectedKeyPkg,
      publicKeyPackage: pubKeyPkg1,
      startTime:
          DateTime.fromMillisecondsSinceEpoch(step1Resp.startTime.toInt()),
      interval: interval,
      thresholdSats: thresholdAmount.toInt(),
    );
    await _saveState();
  }

  // --- SIGNING ---
  Future<String> getPolicyId(Uint8List message) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot get Policy ID.");
    }

    final auth = _authHelper!.signForGetPolicyId();
    final response = await _stub.getPolicyId(GetPolicyIdRequest()
      ..userId = _userId!
      ..txMessage = message
      ..signature = auth.signature
      ..timestampMs = auth.timestampMs);
    return response.policyId;
  }

  Future<threshold.Signature> sign(Uint8List message,
      {String? pin,
      String? policyId,
      List<int>? fullTransaction,
      bool applyTweak = true}) async {
    var keyPackage = _normalPolicy!.keyPackage;
    var groupPubKey = _normalPolicy!.publicKeyPackage;

    if (_userId == null) {
      throw StateError("User ID is null, cannot proceed with signing.");
    }

    final signingIdentifier = _normalPolicy!.keyPackage.identifier;

    if (policyId != null &&
        _protectedPolicies.containsKey(policyId) &&
        pin != null) {
      final protectedPolicy = _protectedPolicies[policyId];

      final minSigners = 2; // Matched with createSpendingPolicy

      final seed = sha256.convert(utf8.encode(pin)).bytes;

      // Re-run part 1 logic to reliably recover the polynomial
      final (r1Sec, _) = threshold.dkgRefreshPart1(
          signingIdentifier, minSigners, minSigners,
          seed: seed);

      final myUpdate =
          threshold.evaluatePolynomial(signingIdentifier, r1Sec.coefficients);

      final partialShare = protectedPolicy!.keyPackage.secretShare;
      final correctedShare = (partialShare + myUpdate);

      keyPackage = threshold.KeyPackage(
        protectedPolicy.keyPackage.identifier,
        correctedShare,
        protectedPolicy.keyPackage.verifyingShare,
        protectedPolicy.keyPackage.verifyingKey,
        protectedPolicy.keyPackage.minSigners,
      );

      groupPubKey = protectedPolicy.publicKeyPackage;
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
  }) async {
    final nonce = frost_comm.newNonce(keyPkg.secretShare);

    if (_userId == null) {
      throw StateError("User ID is null, cannot proceed with signing.");
    }

    // 2. Step 1: Commitments
    final auth1 = _authHelper!.signForSignStep1();
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
      ..userId = _userId!
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

  // --- RECOVERY SIGNING (Client-only 2-of-3 FROST) ---

  /// Produces a FROST threshold signature using both client key packages
  /// (signing + recovery identity) without server participation.
  /// No taproot tweak is applied — this is for auth, not Bitcoin transactions.
  ///
  /// When a hardware signer is configured, the recovery identity's nonce
  /// generation and signing are delegated to the hardware device.
  /// FROST sign with both keys: signing identity (local) + recovery identity
  /// (hardware signer). No taproot tweak — used for auth, not Bitcoin txs.
  Future<threshold.Signature> _frostSignWithBothKeys(Uint8List message) async {
    if (!isInitialized) {
      throw StateError("Client not initialized (DKG not run).");
    }

    final signer = _requireSigner('_frostSignWithBothKeys');
    final keyPkg1 = _normalPolicy!.keyPackage;
    final recoveryId = _recoveryPolicy!.keyPackage.identifier;
    final groupPubKey = _normalPolicy!.publicKeyPackage;

    // 1. Hardware signer generates nonce for recovery identity
    final recoveryCommitments = await signer.generateNonce();

    // 2. Generate signing identity nonce locally
    final nonce1 = frost_comm.newNonce(keyPkg1.secretShare);

    // 3. Build commitments map with both identities
    final commitmentsMap = <threshold.Identifier, frost_comm.SigningCommitments>{
      keyPkg1.identifier: nonce1.commitments,
      recoveryId: recoveryCommitments,
    };

    // 4. Create signing package
    final signingPkg = frost_comm.SigningPackage(commitmentsMap, message);

    // 5. Hardware signer produces recovery share (no taproot tweak)
    final recoveryShareScalar = await signer.sign(
      message: message,
      commitments: commitmentsMap,
      applyTweak: false,
    );

    // 6. Compute signing identity share locally
    final share1 = frost.sign(signingPkg, nonce1, keyPkg1);

    // 7. Aggregate both shares
    final sharesMap = <threshold.Identifier, frost.SignatureShare>{
      keyPkg1.identifier: share1,
      recoveryId: frost.SignatureShare(recoveryShareScalar),
    };

    return frost.aggregate(signingPkg, sharesMap, groupPubKey);
  }

  // --- POLICY MANAGEMENT ---

  Future<void> updatePolicy(String policyId,
      {int? thresholdSats, int? intervalSeconds}) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot update policy.");
    }
    if (!_protectedPolicies.containsKey(policyId)) {
      throw StateError("Policy $policyId not found.");
    }

    final existing = _protectedPolicies[policyId]!;
    final newThreshold = thresholdSats ?? existing.thresholdSats;
    final newInterval = intervalSeconds ?? existing.interval.inSeconds;
    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    final message = threshold.RecoveryAuthMessage.buildUpdatePolicyMessage(
      policyId: policyId,
      thresholdSats: newThreshold,
      intervalSeconds: newInterval,
      timestampMs: timestampMs,
      userIdHex: hex.encode(_userId!),
    );

    final signature = await _frostSignWithBothKeys(message);

    await _stub.updatePolicy(UpdatePolicyRequest()
      ..userId = _userId!
      ..policyId = policyId
      ..thresholdSats = Int64(newThreshold)
      ..intervalSeconds = Int64(newInterval)
      ..frostSignatureR = signature.serialize().sublist(0, 32)
      ..frostSignatureZ = signature.serialize().sublist(32, 64)
      ..timestampMs = Int64(timestampMs));

    // Update local state
    _protectedPolicies[policyId] = ProtectedPolicy(
      id: policyId,
      keyPackage: existing.keyPackage,
      publicKeyPackage: existing.publicKeyPackage,
      startTime: existing.startTime,
      interval: Duration(seconds: newInterval),
      thresholdSats: newThreshold,
    );
    await _saveState();
  }

  Future<void> deletePolicy(String policyId) async {
    if (_userId == null) {
      throw StateError("User ID is null, cannot delete policy.");
    }
    if (!_protectedPolicies.containsKey(policyId)) {
      throw StateError("Policy $policyId not found.");
    }

    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    final message = threshold.RecoveryAuthMessage.buildDeletePolicyMessage(
      policyId: policyId,
      timestampMs: timestampMs,
      userIdHex: hex.encode(_userId!),
    );

    final signature = await _frostSignWithBothKeys(message);

    await _stub.deletePolicy(DeletePolicyRequest()
      ..userId = _userId!
      ..policyId = policyId
      ..frostSignatureR = signature.serialize().sublist(0, 32)
      ..frostSignatureZ = signature.serialize().sublist(32, 64)
      ..timestampMs = Int64(timestampMs));

    // Update local state
    _protectedPolicies.remove(policyId);
    await _saveState();
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
  Future<String> sendVtxo(String recipientArkAddress, int amountSats,
      {String? policyId, String? pin}) async {
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
      // 6. FROST sign each sighash via sign() which handles client-side policy
      //    key correction. Pass real PSBT bytes as fullTransaction so the server
      //    independently evaluates the same net spend for policy selection.
      final sigHexes = <String>[];
      for (final sighash in session.sighashes) {
        final sig = await sign(
          sighash,
          policyId: policyId,
          pin: pin,
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

          // FROST sign - script path means no taproot tweak
          final sig = await signWithContext(
            sighashBytes,
            _normalPolicy!.keyPackage,
            _normalPolicy!.publicKeyPackage,
            null,
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
  /// Only 2 rounds vs 4 for boarding:
  /// Phase 1: get all sighashes (intent proof + forfeit PSBTs)
  /// Phase 2: send FROST signatures, server drives batch autonomously
  Future<String> settleDelegate() async {
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
      final sig = await signWithContext(
        sighashBytes,
        _normalPolicy!.keyPackage,
        _normalPolicy!.publicKeyPackage,
        null,
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

    // Phase 2: send signatures, server settles autonomously
    final auth2 = _authHelper!.signForSettleDelegate();
    final req2 = SettleDelegateRequest()
      ..userId = _userId!
      ..signature = auth2.signature
      ..timestampMs = auth2.timestampMs;
    req2.signedMessages.addAll(signedMessages);

    final resp2 = await _stub.settleDelegate(req2);

    if (resp2.status == SettleDelegateResponse_Status.ERROR) {
      throw Exception('SettleDelegate error: ${resp2.errorMessage}');
    }
    if (resp2.status != SettleDelegateResponse_Status.SETTLED) {
      throw Exception('Expected SETTLED, got ${resp2.status}');
    }

    return resp2.commitmentTxid;
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
      final grpc = _stub as GrpcWalletApi;
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
