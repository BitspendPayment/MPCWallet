import 'dart:async';
import 'package:hive/hive.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:synchronized/synchronized.dart';

/// Thread-safe wallet store with optional encryption support.
///
/// Stores wallet state including UTXOs and client state in Hive.
/// When encryption is enabled, all data is encrypted at rest using AES-256.
class WalletStore {
  final String boxName;
  final HiveCipher? _cipher;
  final BitcoinNetwork network;
  late Box _box;
  bool _isInitialized = false;
  final Lock _lock = Lock();

  /// Creates a WalletStore with optional encryption.
  ///
  /// [boxName] - Name of the Hive box
  /// [cipher] - Optional cipher for encrypted storage. Pass a HiveAesCipher
  ///            created from a SecureKeyProvider for encrypted storage.
  /// [network] - Bitcoin network for address encoding/decoding.
  WalletStore({
    this.boxName = 'bitcoin_wallet_state',
    HiveCipher? cipher,
    this.network = BitcoinNetwork.mainnet,
  }) : _cipher = cipher;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    await _lock.synchronized(() async {
      if (_isInitialized) return;
      // Open box with encryption if cipher is provided
      _box = await Hive.openBox(
        boxName,
        encryptionCipher: _cipher,
      );
      _isInitialized = true;
    });
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('WalletStore not initialized. Call init() first.');
    }
  }

  Future<void> saveUtxos(List<UtxoWithAddress> utxos) async {
    await _lock.synchronized(() async {
      _ensureInitialized();
      final data = utxos
          .map((u) => {
                'txHash': u.utxo.txHash,
                'vout': u.utxo.vout,
                'value': u.utxo.value.toString(),
                'address': u.ownerDetails.address
                    .toAddress(network),
                'publicKey': u.ownerDetails.publicKey,
                'scriptType': 'P2TR',
              })
          .toList();
      await _box.put('utxos', data);
    });
  }

  Future<List<UtxoWithAddress>> getUtxos() async {
    return _lock.synchronized(() async {
      _ensureInitialized();
      return _parseUtxos(_box.get('utxos'));
    });
  }

  List<UtxoWithAddress> _parseUtxos(dynamic raw) {
    if (raw == null) return [];

    final p2trType = BitcoinAddressType.values.firstWhere(
        (e) => e.toString().contains('P2TR'),
        orElse: () => BitcoinAddressType.values.last);

    final list = (raw as List).cast<Map>();
    return list.map((m) {
      final txHash = m['txHash'];
      final vout = m['vout'];
      final value = m['value'];
      final addressStr = m['address'];
      final publicKey = m['publicKey'];

      if (txHash is! String || txHash.isEmpty) {
        throw FormatException('Invalid or missing txHash in stored UTXO');
      }
      if (vout is! int) {
        throw FormatException('Invalid or missing vout in stored UTXO');
      }
      if (value is! String) {
        throw FormatException('Invalid or missing value in stored UTXO');
      }
      if (addressStr is! String || addressStr.isEmpty) {
        throw FormatException('Invalid or missing address in stored UTXO');
      }
      if (publicKey is! String || publicKey.isEmpty) {
        throw FormatException('Invalid or missing publicKey in stored UTXO');
      }

      late P2trAddress address;
      try {
        address = P2trAddress.fromAddress(
            address: addressStr, network: network);
      } catch (_) {
        // Fallback for legacy data stored with mainnet encoding
        address = P2trAddress.fromAddress(
            address: addressStr, network: BitcoinNetwork.mainnet);
      }

      final utxo = BitcoinUtxo(
        txHash: txHash,
        vout: vout,
        value: BigInt.parse(value),
        scriptType: p2trType,
      );

      final details = UtxoAddressDetails(
        publicKey: publicKey,
        address: address,
      );

      return UtxoWithAddress(utxo: utxo, ownerDetails: details);
    }).toList();
  }

  Future<void> saveClientState(Map<String, dynamic> state) async {
    await _lock.synchronized(() async {
      _ensureInitialized();
      await _box.put('client_state', state);
    });
  }

  Future<Map<String, dynamic>?> getClientState() async {
    return _lock.synchronized(() async {
      _ensureInitialized();
      final raw = _box.get('client_state');
      if (raw == null) return null;
      return _validateClientState(raw);
    });
  }

  Map<String, dynamic>? _validateClientState(dynamic raw) {
    if (raw == null) return null;

    try {
      final state = (raw as Map).cast<String, dynamic>();

      // Validate required userId field
      if (state['userId'] is! String ||
          (state['userId'] as String).isEmpty) {
        return null;
      }

      // Validate signingSecret format if present
      if (state['signingSecret'] != null) {
        final secret = state['signingSecret'];
        if (secret is! String || secret.isEmpty) {
          return null;
        }
        // Validate hex format (should be 64 hex chars for 32 bytes)
        if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(secret)) {
          return null;
        }
      }

      return state;
    } catch (e) {
      return null;
    }
  }

  /// Closes the store and releases resources.
  Future<void> close() async {
    await _lock.synchronized(() async {
      if (_isInitialized && _box.isOpen) {
        await _box.close();
        _isInitialized = false;
      }
    });
  }
}
