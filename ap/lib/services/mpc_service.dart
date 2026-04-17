import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:client/ark_wallet.dart';
import 'package:client/bitcoin.dart';
import 'package:client/client.dart';
import 'package:client/enclave/native_enclave.dart' show AttestationStatus;
import 'package:client/enclave/manifest.dart' as manifest;
import 'package:client/hardware_signer.dart';
import 'package:client/policy.dart';
import '../usb/usb_hardware_signer.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'package:protocol/protocol.dart';

class MpcService extends ChangeNotifier {
  MpcClient? _client;
  bool _isInitialized = false;
  Future<void>? _persistenceInitFuture;
  bool _dkgComplete = false;
  bool _isConnected = false;
  Box? _identityBox;
  String _network = 'regtest';

  String? _storageId;

  HardwareSignerInterface? _hardwareSigner;

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
  List<TransactionSummary> get transactions => _wallet?.transactions ?? [];
  ProtectedPolicy? get activePolicy => _client?.activeSpendingPolicy;
  List<ProtectedPolicy> get policies => _client?.spendingPolicies ?? [];

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

  Future<void> reconnectHardwareSigner() async {
    try {
      await _hardwareSigner?.disconnect();
    } catch (_) {}
    _hardwareSigner = _createSigner();
    await _hardwareSigner!.connect();
    _client?.hardwareSigner = _hardwareSigner!;
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

  /// Attestation status from the enclave client (null if not using attested transport).
  /// Caches the result so the UI doesn't flicker on widget rebuilds.
  Future<AttestationStatus?> getAttestationStatus() async {
    final status = await _client?.getAttestationStatus();
    if (status != null) _lastAttestationStatus = status;
    return _lastAttestationStatus;
  }

  /// The expected PCR0 (from manifest). Null if not yet fetched.
  String? get expectedPcr0 => _expectedPcr0;

  /// Whether attestation was expected but unavailable.
  bool _attestationUnavailable = false;
  bool get attestationUnavailable => _attestationUnavailable;

  /// Fetch PCR0 from the deployment manifest.
  Future<void> fetchManifest() async {
    if (_manifestRepo.isEmpty) return;
    try {
      final m = await manifest.fetchManifest(_manifestRepo, tag: _manifestTag);
      if (m.pcr0.length != 96 || !RegExp(r'^[a-f0-9]{96}$').hasMatch(m.pcr0)) {
        debugPrint('Warning: Invalid PCR0 format (${m.pcr0.length} chars), ignoring');
        _attestationUnavailable = true;
        return;
      }
      _expectedPcr0 = m.pcr0;
      _attestationUnavailable = false;
      debugPrint('Fetched manifest: pcr0=${m.pcr0.substring(0, 16)}...');
    } catch (e) {
      debugPrint('Warning: Could not fetch manifest: $e');
      _attestationUnavailable = true;
      // Continue without attestation -- will use plain REST.
      // UI can check attestationUnavailable to warn the user.
    }
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

      // Fetch deployment manifest for enclave PCR0 (non-blocking on failure).
      await fetchManifest();

      _dkgComplete = _identityBox!.get('dkgComplete', defaultValue: false);
      _network =
          _identityBox!.get('network', defaultValue: 'regtest') as String;
      _storageId = _identityBox!.get('storageId') as String?;
      if (_storageId == null || _storageId!.isEmpty) {
        _storageId = 'mpc_wallet_state_${_generateSessionId()}';
        await _identityBox!.put('storageId', _storageId);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint("MPC Service Error: $e");
      rethrow;
    }
  }

  /// Closes all resources. Call this when the app is shutting down.
  @override
  Future<void> dispose() async {
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

  Future<void> setHost(String host) async {
    if (_host == host && _isInitialized) return;

    debugPrint("MPC Service: Switching host to $host");
    _host = host;

    await _ensurePersistenceInitialized();
    if (_identityBox == null || !_identityBox!.isOpen) {
      _identityBox = await Hive.openBox('mpc_service_identity');
    }
    await _identityBox!.put('serverHost', host);
  }

  HardwareSignerInterface _createSigner() {
    return UsbHardwareSigner();
  }

  /// Create an MpcClient with the appropriate transport.
  /// Uses attested transport (background isolate FFI) if PCR0 is available,
  /// plain REST otherwise.
  Future<MpcClient> _createMpcClient({
    required HardwareSignerInterface hardwareSigner,
    String? storageId,
  }) async {
    if (_expectedPcr0 != null && _expectedPcr0!.isNotEmpty) {
      try {
        return await MpcClient.attested(
          _baseUrl,
          expectedPcr0: _expectedPcr0!,
          hardwareSigner: hardwareSigner,
          storageId: storageId,
        );
      } catch (e) {
        debugPrint('Attested transport failed, falling back to REST: $e');
        _attestationUnavailable = true;
        notifyListeners();
      }
    }
    return MpcClient.rest(
      _baseUrl,
      hardwareSigner: hardwareSigner,
      storageId: storageId,
    );
  }

  Future<void> doDkg() async {
    if (!_isInitialized) throw StateError("MPC Service not initialized");

    if (_dkgComplete) {
      throw StateError("DKG already completed for this user.");
    }

    final storageId = _storageId ?? 'mpc_wallet_state_default';

    // Connect hardware signer based on type
    _hardwareSigner = _createSigner();
    await _hardwareSigner!.connect();

    _client = await _createMpcClient(
      hardwareSigner: _hardwareSigner!,
      storageId: storageId,
    );
    _wallet =
        MpcBitcoinWallet(_client!, networkName: _network, storageId: storageId);
    _wallet!.onSyncComplete = _onWalletSyncComplete;

    await _wallet!.init();
    _balance = await _wallet!.getBalance();

    _dkgComplete = true;
    _isConnected = true;
    await _identityBox!.put('dkgComplete', true);

    await initArk();
    notifyListeners();
  }

  /// Restore wallet via re-DKG using the hardware signer's stored secrets.
  /// The group public key (and Bitcoin address) is preserved.
  Future<void> doRestore() async {
    if (!_isInitialized) throw StateError("MPC Service not initialized");

    final storageId = _storageId ?? 'mpc_wallet_state_default';

    debugPrint("[RESTORE] Connecting hardware signer...");
    _hardwareSigner = _createSigner();
    await _hardwareSigner!.connect();
    debugPrint("[RESTORE] Hardware signer connected.");

    _client = await _createMpcClient(
      hardwareSigner: _hardwareSigner!,
      storageId: storageId,
    );

    debugPrint("[RESTORE] Starting re-DKG...");
    // Re-DKG: derive new shares from existing secrets on HW + server
    await _client!.doRestore().timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw StateError(
              'Restore timed out. Check that the server is running and ADB reverse is set up.'),
        );
    debugPrint("[RESTORE] Re-DKG complete.");

    _wallet =
        MpcBitcoinWallet(_client!, networkName: _network, storageId: storageId);
    _wallet!.onSyncComplete = _onWalletSyncComplete;

    // init() will find restored state and skip DKG, then sync
    await _wallet!.init();
    _balance = await _wallet!.getBalance();

    _dkgComplete = true;
    _isConnected = true;
    await _identityBox!.put('dkgComplete', true);

    await initArk();
    notifyListeners();
  }

  /// Restores a previously completed session without re-running DKG.
  /// Creates gRPC channel + MpcClient + MpcBitcoinWallet, then calls
  /// wallet.init() which restores keys from Hive persistence.
  Future<void> restoreSession() async {
    if (!_isInitialized) throw StateError("MPC Service not initialized");
    if (!_dkgComplete) throw StateError("DKG not completed. Cannot restore.");

    final storageId = _storageId ?? 'mpc_wallet_state_default';

    // Reconnect hardware signer (non-fatal if device not plugged in yet)
    if (_hardwareSigner == null) {
      _hardwareSigner = _createSigner();
      try {
        await _hardwareSigner!.connect();
      } catch (e) {
        debugPrint("Hardware signer not available: $e");
      }
    }

    _client = await _createMpcClient(
      hardwareSigner: _hardwareSigner!,
      storageId: storageId,
    );
    _wallet =
        MpcBitcoinWallet(_client!, networkName: _network, storageId: storageId);
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
      if (_arkInfo != null && _arkInfo!.network.isNotEmpty) {
        _network = _arkInfo!.network;
        await _identityBox?.put('network', _network);
      }
      _arkAddress = await _client!.getArkAddress();
      _boardingAddress = await _client!.getBoardingAddress();
      _arkWallet = MpcArkWallet(_client!);
      _arkAvailable = true;
      await refreshVtxos();
    } catch (e) {
      debugPrint("Ark init failed (ASP may not be configured): $e");
      _arkWallet = null;
      _arkAvailable = false;
    }
    notifyListeners();
  }

  Future<void> refreshVtxos() async {
    if (_client == null) return;
    try {
      final resp = await _client!.listVtxos();
      _vtxos = resp.vtxos;
      _arkBalance = BigInt.from(resp.totalBalance.toInt());
    } catch (e) {
      debugPrint("Refresh VTXOs failed: $e");
    }
    await refreshArkTransactions();
    notifyListeners();
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
    if (_client == null) return;
    try {
      final resp = await _client!.checkBoardingBalance();
      _boardingBalance = resp.balance.toInt();
      _boardingUtxoCount = resp.utxoCount;
    } catch (e) {
      debugPrint("Refresh boarding balance failed: $e");
    }
    notifyListeners();
  }

  Future<String> boardFunds() async {
    if (_client == null) throw StateError("Client not initialized");
    final txid = await _client!.settle();
    await refreshVtxos();
    return txid;
  }

  Future<String> sendArk(String recipientArkAddress, int amountSats,
      {String? policyId, String? pin}) async {
    if (_client == null) throw StateError("Client not initialized");
    final arkTxid = await _client!.sendVtxo(recipientArkAddress, amountSats,
        policyId: policyId, pin: pin);
    await refreshVtxos();
    return arkTxid;
  }

  Future<String> settleDelegate() async {
    if (_client == null) throw StateError("Client not initialized");
    final txid = await _client!.settleDelegate();
    await refreshVtxos();
    return txid;
  }

  String _generateSessionId() {
    final r = Random.secure();
    return List.generate(
        16, (index) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
