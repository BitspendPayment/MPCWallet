import 'dart:async';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:protocol/protocol.dart';

import 'package:app_core/ark_wallet.dart';
import 'package:app_core/bitcoin.dart';
import 'package:app_core/client.dart';
import 'package:app_core/services_registry.dart';
import 'package:app_core/enclave/native_enclave.dart' show AttestationStatus;
import 'package:app_core/enclave/manifest.dart' as manifest;
import 'package:app_core/hardware_signer.dart';
import 'package:app_core/software_signer.dart';

import '../usb/usb_hardware_signer.dart';

/// Which backend signs for the owner share.
enum SignerKind { software, hardware }

class MpcService extends ChangeNotifier {
  MpcClient? _client;
  bool _isInitialized = false;
  Future<void>? _persistenceInitFuture;
  bool _dkgComplete = false;
  bool _isConnected = false;
  Box? _identityBox;

  String? _storageId;

  /// Persistent hardware signer when [_signerKind] == hardware. For software
  /// we don't keep a persistent reference — the signer is ephemeral, created
  /// only for the duration of an operation that needs the owner share.
  HardwareSignerInterface? _hardwareSigner;

  /// Which signer backend is in use. Persisted so cold starts know whether
  /// to reconnect USB (hardware) or create an ephemeral software signer.
  SignerKind _signerKind = SignerKind.software;
  SignerKind get signerKind => _signerKind;

  MpcService();

  /// Future that completes when init() finishes. Await this before
  /// checking dkgComplete or calling restoreSession().
  late Future<void> initFuture;

  MpcClient? get client => _client;
  bool get isInitialized => _isInitialized;
  bool get dkgComplete => _dkgComplete;
  bool get isConnected => _isConnected;

  MpcBitcoinWallet? _wallet;
  MpcBitcoinWallet? get wallet => _wallet;

  MpcArkWallet? _arkWallet;
  MpcArkWallet? get arkWallet => _arkWallet;

  BigInt _balance = BigInt.zero;
  BigInt get balance => _balance;
  List<WalletTransaction> get transactions => _wallet?.transactions ?? [];

  // --- Ark state ---
  GetArkInfoResponse? _arkInfo;
  GetArkInfoResponse? get arkInfo => _arkInfo;
  String? _arkAddress;
  String? get arkAddress => _arkAddress;
  String? _boardingAddress;
  String? get boardingAddress => _boardingAddress;
  List<VtxoInfo> _vtxos = [];
  List<VtxoInfo> get vtxos => _vtxos;
  BigInt _arkBalance = BigInt.zero;
  BigInt get arkBalance => _arkBalance;
  List<ArkTransactionSummary> _arkTransactions = [];
  List<ArkTransactionSummary> get arkTransactions => _arkTransactions;

  int _boardingBalance = 0;
  int get boardingBalance => _boardingBalance;
  int _boardingUtxoCount = 0;
  int get boardingUtxoCount => _boardingUtxoCount;
  bool _arkAvailable = false;
  bool get arkAvailable => _arkAvailable;

  void policyUpdated() {
    notifyListeners();
  }

  /// Reconnect the hardware USB signer. Only meaningful for hardware mode —
  /// the software signer is ephemeral and attached per-operation.
  Future<void> reconnectHardwareSigner() async {
    if (_signerKind != SignerKind.hardware) {
      throw StateError('reconnectHardwareSigner is only valid for hardware signer');
    }
    try {
      await _hardwareSigner?.disconnect();
    } catch (_) {}
    _hardwareSigner = UsbHardwareSigner();
    await _hardwareSigner!.connect();
    _client?.hardwareSigner = _hardwareSigner!;
  }

  /// Select the signer backend. For the software signer a fresh in-memory
  /// signer is created per-operation (DKG), so no key material sits idle.
  Future<void> setSignerKind(SignerKind kind) async {
    _signerKind = kind;
    if (_identityBox != null && _identityBox!.isOpen) {
      await _identityBox!.put('signerKind', kind.name);
    }
  }

  String? get receiveAddress {
    if (_wallet == null) return null;
    return _wallet!.toAddress();
  }

  Future<void> refreshHistory() async {
    if (_wallet != null) {
      try {
        await _wallet!.sync();
        _balance = await _wallet!.getBalance();
        _isConnected = true;
      } catch (e) {
        debugPrint("Refresh failed: $e");
        _isConnected = false;
      }
      notifyListeners();
    }
  }

  // Hardcoded for now, could be configurable
  String _host = '10.0.2.2'; // Default, will be overwritten by persistence
  // 7074 is the server binary's default REST port and what the enclave
  // production deployment listens on. The Makefile mirrors this for dev.
  static const int _port = 7074;

  /// GitHub repo for fetching deployment manifest (PCR0).
  /// Set to empty to disable attestation (uses plain REST).
  static const String _manifestRepo = 'BitspendPayment/MPCWallet';
  static const String _manifestTag = 'eif-latest';

  /// Cached PCR0 from the deployment manifest.
  String? _expectedPcr0;

  /// Base URL for the server.
  /// Uses HTTPS (port 443) for remote hosts (enclave).
  /// Uses HTTP (port 7074) for local addresses (dev).
  String get _baseUrl {
    final isLocal = _host == '127.0.0.1' ||
        _host == 'localhost' ||
        _host == '10.0.2.2' ||
        _host.startsWith('192.168.');
    return isLocal ? 'http://$_host:$_port' : 'https://$_host';
  }

  /// Cached attestation status for immediate UI access.
  AttestationStatus? _lastAttestationStatus;

  /// Attestation status from the enclave client (null for local dev).
  Future<AttestationStatus?> getAttestationStatus() async {
    final status = await _client?.getAttestationStatus();
    if (status != null) _lastAttestationStatus = status;
    return _lastAttestationStatus;
  }

  /// The expected PCR0 (from manifest). Null if not yet fetched.
  String? get expectedPcr0 => _expectedPcr0;

  /// Fetch PCR0 from the deployment manifest.
  /// Throws if the manifest cannot be fetched or PCR0 is invalid —
  /// attestation is mandatory for non-local connections.
  Future<void> fetchManifest() async {
    if (_manifestRepo.isEmpty) return;
    final m = await manifest.fetchManifest(_manifestRepo, tag: _manifestTag);
    if (m.pcr0.length != 96 || !RegExp(r'^[a-f0-9]{96}$').hasMatch(m.pcr0)) {
      throw StateError('Invalid PCR0 from manifest: ${m.pcr0.length} chars');
    }
    _expectedPcr0 = m.pcr0;
    debugPrint('Fetched manifest: pcr0=${m.pcr0.substring(0, 16)}...');
  }

  Future<void> _ensurePersistenceInitialized() async {
    _persistenceInitFuture ??= () async {
      final appDir = await getApplicationDocumentsDirectory();
      final persistencePath = '${appDir.path}/mpc_client';
      await MpcClient.initPersistence(path: persistencePath);
    }();
    await _persistenceInitFuture;
  }

  Future<void> init() async {
    try {
      // 1. Initialize Hive for MpcClient (and us)
      await _ensurePersistenceInitialized();

      // 2. Open our own box for identity persistence
      _identityBox = await Hive.openBox('mpc_service_identity');

      _host = _identityBox!.get('serverHost', defaultValue: '10.0.2.2');
      debugPrint("MPC Service: Using host: $_host");

      // Fetch deployment manifest for enclave PCR0.
      // For remote hosts this is mandatory — failure will propagate.
      // For local dev, manifest fetch failure is non-fatal.
      try {
        await fetchManifest();
      } catch (e) {
        if (_requiresAttestation) rethrow;
        debugPrint('Manifest fetch skipped for local dev: $e');
      }

      _dkgComplete = _identityBox!.get('dkgComplete', defaultValue: false);
      _storageId = _identityBox!.get('storageId') as String?;
      if (_storageId == null || _storageId!.isEmpty) {
        _storageId = 'mpc_wallet_state_${_generateSessionId()}';
        await _identityBox!.put('storageId', _storageId);
      }

      // Migrate from the old client-side network selection: the wallet
      // network now comes from the server via `getServerInfo()`, so any
      // persisted 'network' key from prior versions is dead weight.
      // No-op if the key isn't present.
      await _identityBox!.delete('network');

      // Restore signer kind. Default to software (hardware signer is opt-in
      // for users who own the device).
      final kindStr =
          _identityBox!.get('signerKind', defaultValue: SignerKind.software.name)
              as String;
      _signerKind = SignerKind.values.firstWhere(
        (k) => k.name == kindStr,
        orElse: () => SignerKind.software,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint("MPC Service Error: $e");
      rethrow;
    }
  }

  /// Closes all resources. Call this when the app is shutting down.
  @override
  Future<void> dispose() async {
    _vtxoPollTimer?.cancel();
    try {
      await _hardwareSigner?.disconnect();
      _hardwareSigner = null;
    } catch (e) {
      debugPrint("MPC Service: Error disconnecting hardware signer: $e");
    }
    try {
      await _identityBox?.close();
      _identityBox = null;
    } catch (e) {
      debugPrint("MPC Service: Error closing identity box: $e");
    }
    super.dispose();
  }

  /// Fetch deployment metadata from the cosigner-runtime with bounded
  /// retry. Address rendering depends on `bitcoinNetwork`, so we refuse
  /// to proceed without a non-empty value — silently defaulting was the
  /// regression that the empty-string check guards against.
  Future<GetServerInfoResponse> _fetchServerInfoWithRetry() async {
    Object? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final info = await _client!.getServerInfo();
        if (info.bitcoinNetwork.isEmpty) {
          throw StateError(
              "Server returned empty bitcoin_network; refusing to construct "
              "wallet without a known HRP source");
        }
        return info;
      } catch (e) {
        lastError = e;
        debugPrint(
            "getServerInfo attempt $attempt/3 failed: $e; "
            "${attempt < 3 ? 'retrying in ${attempt}s' : 'giving up'}");
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
    throw StateError(
        "Cosigner unreachable: getServerInfo failed after 3 attempts. "
        "Last error: $lastError. Check that the server is running and "
        "reachable at $_host.");
  }

  /// Set the server endpoint. The Bitcoin network is no longer carried in
  /// app state — it's fetched from the server via `getServerInfo()` at the
  /// moment the wallet is constructed (see `restoreSession`/`doDkg`).
  Future<void> setHost(String host) async {
    if (_host == host && _isInitialized) return;

    debugPrint("MPC Service: Switching host to $host");
    _host = host;

    // Remote hosts require attestation. If we switched in from a local host
    // where manifest fetch was skipped or silently failed, refresh now so the
    // failure surfaces here (with network context) instead of later as a
    // confusing "no PCR0 available" error inside _createMpcClient.
    if (_requiresAttestation && (_expectedPcr0 == null || _expectedPcr0!.isEmpty)) {
      await fetchManifest();
    }

    await _ensurePersistenceInitialized();
    if (_identityBox == null || !_identityBox!.isOpen) {
      _identityBox = await Hive.openBox('mpc_service_identity');
    }
    await _identityBox!.put('serverHost', host);
  }

  /// For hardware mode: return a live USB signer. For software mode we never
  /// return a signer directly — the software signer is created per-operation.
  Future<HardwareSignerInterface> _createHardwareSignerOrThrow() async {
    if (_signerKind != SignerKind.hardware) {
      throw StateError(
        '_createHardwareSignerOrThrow called for software signer',
      );
    }
    return UsbHardwareSigner();
  }

  /// Whether the current host requires attestation.
  bool get _requiresAttestation {
    return !(_host == '127.0.0.1' ||
        _host == 'localhost' ||
        _host == '10.0.2.2' ||
        _host.startsWith('192.168.'));
  }

  /// Create an MpcClient with the appropriate transport.
  /// Local hosts use plain REST. Remote hosts MUST use attested transport —
  /// if attestation fails, the error propagates (no silent fallback).
  Future<MpcClient> _createMpcClient({
    HardwareSignerInterface? hardwareSigner,
    String? storageId,
  }) async {
    if (_requiresAttestation) {
      if (_expectedPcr0 == null || _expectedPcr0!.isEmpty) {
        throw StateError(
            'Attestation required for remote host $_host but no PCR0 available. '
            'Check network connection and retry.');
      }
      return MpcClient.attested(
        _baseUrl,
        expectedPcr0: _expectedPcr0!,
        hardwareSigner: hardwareSigner,
        storageId: storageId,
      );
    }
    return MpcClient.rest(
      _baseUrl,
      hardwareSigner: hardwareSigner,
      storageId: storageId,
    );
  }

  /// Run initial DKG. For software mode a fresh in-memory signer is created
  /// for this call, DKG runs, and the signer is wiped afterwards so the share
  /// doesn't linger in RAM. [pin] is collected at onboarding and threaded
  /// through for a later phase that will gate the share; it is not yet used.
  /// There is no cloud backup — the share lives only on this device.
  Future<void> doDkg({String? pin}) async {
    if (!_isInitialized) throw StateError("MPC Service not initialized");

    if (_dkgComplete) {
      throw StateError("DKG already completed for this user.");
    }

    final storageId = _storageId ?? 'mpc_wallet_state_default';

    HardwareSignerInterface signer;
    SoftwareSigner? softwareSigner;
    if (_signerKind == SignerKind.hardware) {
      signer = await _createHardwareSignerOrThrow();
      _hardwareSigner = signer;
    } else {
      softwareSigner = SoftwareSigner();
      signer = softwareSigner;
    }
    await signer.connect();

    try {
      _client = await _createMpcClient(
        hardwareSigner: signer,
        storageId: storageId,
      );
      final serverInfo = await _fetchServerInfoWithRetry();
      _wallet = MpcBitcoinWallet(_client!,
          networkName: serverInfo.bitcoinNetwork, storageId: storageId);
      _wallet!.onSyncComplete = _onWalletSyncComplete;

      await _wallet!.init();
      _balance = await _wallet!.getBalance();

      _dkgComplete = true;
      _isConnected = true;
      await _identityBox!.put('dkgComplete', true);

      await initArk();
      notifyListeners();
    } finally {
      // Drop the software signer so the share doesn't sit in RAM after DKG.
      if (softwareSigner != null) {
        await softwareSigner.wipe();
        _client?.hardwareSigner = null;
      }
    }
  }

  /// Restores a previously completed session without re-running DKG.
  /// Creates gRPC channel + MpcClient + MpcBitcoinWallet, then calls
  /// wallet.init() which restores keys from Hive persistence.
  ///
  /// No software signer is attached here — normal sends / Ark ops don't
  /// need it.
  Future<void> restoreSession() async {
    if (!_isInitialized) throw StateError("MPC Service not initialized");
    if (!_dkgComplete) throw StateError("DKG not completed. Cannot restore.");

    final storageId = _storageId ?? 'mpc_wallet_state_default';

    // Hardware signer stays persistent (USB is stateful). Software signer is
    // deliberately not connected here.
    if (_signerKind == SignerKind.hardware && _hardwareSigner == null) {
      _hardwareSigner = await _createHardwareSignerOrThrow();
      try {
        await _hardwareSigner!.connect();
      } catch (e) {
        debugPrint("Hardware signer not available: $e");
      }
    }

    _client = await _createMpcClient(
      hardwareSigner: _hardwareSigner, // null for software mode — that's fine
      storageId: storageId,
    );
    final serverInfo = await _fetchServerInfoWithRetry();
    _wallet = MpcBitcoinWallet(_client!,
        networkName: serverInfo.bitcoinNetwork, storageId: storageId);
    _wallet!.onSyncComplete = _onWalletSyncComplete;

    await _wallet!.init();
    _balance = await _wallet!.getBalance();
    _isConnected = true;

    await initArk();
    notifyListeners();
  }

  /// Reconnects to the server by tearing down the existing channel
  /// and restoring the session fresh.
  Future<void> reconnect() async {
    if (!_dkgComplete) return;

    _isConnected = false;
    notifyListeners();

    try {
      // REST client cleanup handled by MpcClient
    } catch (_) {}
    try {
      await _hardwareSigner?.disconnect();
    } catch (_) {}
    _client = null;
    _wallet = null;
    _hardwareSigner = null;

    try {
      await restoreSession();
    } catch (e) {
      debugPrint("Reconnect failed: $e");
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Called by MpcBitcoinWallet when a background sync completes
  /// (e.g. after a transaction notification from the server).
  Future<void> _onWalletSyncComplete() async {
    try {
      _balance = await _wallet!.getBalance();
      _isConnected = true;
    } catch (e) {
      debugPrint("Post-sync balance update failed: $e");
    }
    notifyListeners();
  }

  // --- Ark methods ---

  Future<void> initArk() async {
    if (_client == null) return;
    try {
      _arkInfo = await _client!.getArkInfo();
      _arkAddress = await _client!.getArkAddress();
      _boardingAddress = await _client!.getBoardingAddress();
      _arkWallet = MpcArkWallet(_client!);
      _arkAvailable = true;
      await refreshVtxos();
      _startVtxoPolling();
    } catch (e) {
      debugPrint("Ark init failed (ASP may not be configured): $e");
      _arkWallet = null;
      _arkAvailable = false;
      _vtxoPollTimer?.cancel();
    }
    notifyListeners();
  }

  /// Outpoints (`txid:vout`) seen on the previous refresh. Used to detect
  /// "new VTXO arrived" so the auto-settle re-delegation can fire even when
  /// the push notification path didn't deliver (denied perms, force-quit, etc).
  final Set<String> _previousVtxoOutpoints = <String>{};
  bool _serverHasActiveDelegate = false;
  bool _delegateInFlight = false;

  /// Periodic VTXO poll. Off-chain receives don't trigger the on-chain electrs
  /// sync, so without this, received VTXOs only show up on a manual refresh.
  /// Runs while Ark is active; the OS pauses it when the app is backgrounded.
  Timer? _vtxoPollTimer;
  bool _vtxoPollInFlight = false;
  static const Duration _vtxoPollInterval = Duration(seconds: 10);

  /// Whether the cosigner currently holds a signed delegate intent for this
  /// user. Refreshed on every `refreshVtxos()` from `ListVtxosResponse.
  /// has_active_delegate`. Used by integration tests to verify the auto-
  /// delegate flow fired.
  bool get hasActiveDelegate => _serverHasActiveDelegate;

  Future<void> refreshVtxos() async {
    if (_client == null) return;
    try {
      final resp = await _client!.listVtxos();
      _vtxos = resp.vtxos;
      _arkBalance = BigInt.from(resp.totalBalance.toInt());
      _serverHasActiveDelegate = resp.hasActiveDelegate;
    } catch (e) {
      debugPrint("Refresh VTXOs failed: $e");
    }
    await refreshArkTransactions();
    notifyListeners();
    unawaited(_delegateIfNeeded());
  }

  /// Re-delegate when either:
  /// - A new VTXO appeared since the last refresh that wasn't created by us
  ///   (i.e. an external receive), OR
  /// - VTXOs exist but the server reports no active delegate (cosigner
  ///   restart, or first refresh after login).
  ///
  /// Self-originated change (txid matches a recent send/board/settle) is
  /// skipped since the corresponding handler already invalidated the delegate
  /// on the server side and a fresh re-delegate covers the new change VTXO.
  Future<void> _delegateIfNeeded() async {
    if (_client == null || _delegateInFlight || _vtxos.isEmpty) return;

    final current = _vtxos.map((v) => '${v.txid}:${v.vout}').toSet();
    final newOutpoints = current.difference(_previousVtxoOutpoints);
    _previousVtxoOutpoints
      ..clear()
      ..addAll(current);

    final selfTxids =
        _arkTransactions.map((t) => t.txid).where((s) => s.isNotEmpty).toSet();
    final external =
        newOutpoints.where((op) => !selfTxids.contains(op.split(':').first));

    final needsDelegate = external.isNotEmpty || !_serverHasActiveDelegate;
    if (!needsDelegate) return;

    _delegateInFlight = true;
    try {
      await _client!.settleDelegate(storeOnly: true);
      _serverHasActiveDelegate = true;
      notifyListeners();
    } catch (e) {
      debugPrint("[auto-settle] re-delegate failed: $e");
    } finally {
      _delegateInFlight = false;
    }
  }

  /// Start polling VTXOs so off-chain receives appear without a manual refresh.
  /// Idempotent; skips a tick if a refresh is already in flight.
  void _startVtxoPolling() {
    _vtxoPollTimer?.cancel();
    _vtxoPollTimer = Timer.periodic(_vtxoPollInterval, (_) async {
      if (_client == null || !_arkAvailable || _vtxoPollInFlight) return;
      _vtxoPollInFlight = true;
      try {
        await refreshVtxos();
      } finally {
        _vtxoPollInFlight = false;
      }
    });
  }

  Future<void> refreshArkTransactions() async {
    if (_client == null) return;
    try {
      final resp = await _client!.listArkTransactions();
      _arkTransactions = resp.transactions;
    } catch (e) {
      debugPrint("Refresh Ark transactions failed: $e");
    }
  }

  Future<void> refreshBoardingBalance() async {
    if (_client == null || _wallet == null) return;
    try {
      // The wallet (the only chain-viewer) scans its boarding address directly.
      final boardingAddress = await _client!.getBoardingAddress();
      final utxos = await _wallet!.scanBoarding(boardingAddress);
      _boardingBalance = utxos.fold<int>(0, (s, u) => s + u.amountSats.toInt());
      _boardingUtxoCount = utxos.length;
    } catch (e) {
      debugPrint("Refresh boarding balance failed: $e");
    }
    notifyListeners();
  }

  Future<String> boardFunds() async {
    if (_client == null || _wallet == null) {
      throw StateError("Client not initialized");
    }
    // Scan the boarding deposit on-chain and hand it to the cosigner's settle.
    final boardingAddress = await _client!.getBoardingAddress();
    final utxos = await _wallet!.scanBoarding(boardingAddress);
    final txid = await _client!.settle(boardingUtxos: utxos);
    await refreshVtxos();
    return txid;
  }

  Future<String> sendArk(String recipientArkAddress, int amountSats) async {
    if (_client == null) throw StateError("Client not initialized");
    final arkTxid = await _client!.sendVtxo(recipientArkAddress, amountSats);
    await refreshVtxos();
    return arkTxid;
  }

  // --- Contracts (the Services tab, PEER model) -----------------------------
  // Browse the cosigner's template directory (CosignerID -> [template, VerifyingShare]),
  // then create a contract WITH a chosen author as the receiver. No service URLs.

  final ContractDirectory _directory = ContractDirectory();

  List<DirectoryContract> _contracts = [];
  List<DirectoryContract> get contracts => List.unmodifiable(_contracts);

  /// Browse all published contract templates from the cosigner directory.
  Future<void> fetchContracts() async {
    _contracts = await _directory.listContracts(_baseUrl);
    notifyListeners();
  }

  /// Create a contract eVTXO bound to [contract], WITH its author as the receiver: the
  /// cosigner refreshes our V onto {author, cosigner} and relays the author's two share
  /// halves into the author's inbox. Returns the registered eVTXO scriptPubKey hex.
  Future<String> createContractWith(DirectoryContract contract) async {
    if (_client == null) throw StateError("Client not initialized");
    final wasm = await _directory.fetchWasm(_baseUrl, contract.contractIdHex);
    final arkInfo = await _client!.getArkInfo();
    var serverPkHex = arkInfo.signerPubkey;
    if (serverPkHex.length == 66) serverPkHex = serverPkHex.substring(2);
    final serverPk = Uint8List.fromList(hex.decode(serverPkHex));
    final result = await _client!.createEvtxoKey(
      contract.contractId,
      wasm,
      serverPk,
      arkInfo.unilateralExitDelay.toInt(),
      receiverVk: contract.authorVk,
    );
    notifyListeners();
    return hex.encode(result.scriptPubkey);
  }

  /// Phase 2: create a contract FROM a template, supplying the author's TYPED config (collected
  /// from the template's published schema). The cosigner composes the template + a provider
  /// synthesized from [config] into one contract whose composed sha256 is bound to the eVTXO.
  Future<String> createContractFromTemplate(
    DirectoryContract contract,
    List<(String, ConfigValue)> config,
  ) async {
    if (_client == null) throw StateError("Client not initialized");
    final arkInfo = await _client!.getArkInfo();
    var serverPkHex = arkInfo.signerPubkey;
    if (serverPkHex.length == 66) serverPkHex = serverPkHex.substring(2);
    final serverPk = Uint8List.fromList(hex.decode(serverPkHex));
    final result = await _client!.createEvtxoFromTemplate(
      templateId: contract.contractIdHex,
      stubId: contract.stubId,
      configBlob: encodeContractConfig(config),
      serverPk: serverPk,
      exitDelay: arkInfo.unilateralExitDelay.toInt(),
      receiverVk: contract.authorVk,
    );
    notifyListeners();
    return hex.encode(result.scriptPubkey);
  }

  /// Publish a contract template under this wallet's CosignerID so others can discover it
  /// and create a contract WITH this wallet as the receiver. [contractId] must be
  /// sha256([wasm]).
  Future<void> publishTemplate({
    required Uint8List contractId,
    required Uint8List wasm,
    String name = '',
    String description = '',
  }) async {
    if (_client == null || _client!.userId == null) {
      throw StateError("Client not initialized");
    }
    await _directory.registerTemplate(
      cosignerBase: _baseUrl,
      authorVkHex: _client!.userId!,
      contractIdHex: hex.encode(contractId),
      wasm: wasm,
      name: name,
      description: description,
    );
    await fetchContracts();
  }

  /// Receiver side: pick up any contract shares waiting in this wallet's inbox, assemble
  /// each into a spendable pairing share, and ack them. Returns the number picked up.
  Future<int> pickUpContractShares() async {
    if (_client == null) throw StateError("Client not initialized");
    final shares = await _client!.fetchContractShares();
    for (final s in shares) {
      await _client!.ackContractShare(s.scriptPubkey);
    }
    notifyListeners();
    return shares.length;
  }

  Future<String> settleDelegate() async {
    if (_client == null) throw StateError("Client not initialized");
    final txid = await _client!.settleDelegate();
    await refreshVtxos();
    return txid;
  }

  /// Register a push notification token. Best-effort — failures are logged.
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String appVersion = '',
  }) async {
    if (_client == null) return;
    try {
      await _client!.registerDeviceToken(
        fcmToken: fcmToken,
        platform: platform,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint("registerDeviceToken failed: $e");
    }
  }

  String _generateSessionId() {
    final r = Random.secure();
    return List.generate(
        16, (index) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
