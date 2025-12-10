import 'package:hive/hive.dart';
import 'package:bitcoin_base/bitcoin_base.dart';

class WalletStore {
  static const String _boxName = 'bitcoin_wallet_state';
  late Box _box;

  Future<void> init() async {
    // Determine path? For now just use default or in-memory if not specified.
    // Client usually runs in context where Hive.init is called.
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveUtxos(List<UtxoWithAddress> utxos) async {
    final data = utxos
        .map((u) => {
              'txHash': u.utxo.txHash,
              'vout': u.utxo.vout,
              'value': u.utxo.value.toString(),
              'address': u.ownerDetails.address
                  .toAddress(BitcoinNetwork.mainnet), // Store address string
              'publicKey': u.ownerDetails.publicKey, // Store public key string
              'scriptType': 'P2TR', // Hardcoded for now as we focus on Taproot
            })
        .toList();
    await _box.put('utxos', data);
  }

  Future<List<UtxoWithAddress>> getUtxos() async {
    final raw = _box.get('utxos');
    if (raw == null) return [];

    // Runtime lookup for script type
    final p2trType = BitcoinAddressType.values.firstWhere(
        (e) =>
            e.toString().contains('P2TR'), // Matches 'SegwitAddressType.P2TR'
        orElse: () => BitcoinAddressType.values.last // Fallback
        );

    final list = (raw as List).cast<Map>();
    return list.map((m) {
      final address = P2trAddress.fromAddress(
          address: m['address'],
          network: BitcoinNetwork.mainnet // Assume mainnet for now
          );

      final utxo = BitcoinUtxo(
        txHash: m['txHash'],
        vout: m['vout'],
        value: BigInt.parse(m['value']),
        scriptType: p2trType,
      );

      final details = UtxoAddressDetails(
        publicKey: m['publicKey'],
        address: address,
      );

      return UtxoWithAddress(utxo: utxo, ownerDetails: details);
    }).toList();
  }

  Future<void> saveClientState({
    required String deviceId,
    required Map<String, dynamic> keyPackage1,
    required Map<String, dynamic> keyPackage2,
    required Map<String, dynamic> publicKeyPackage,
  }) async {
    final state = {
      'deviceId': deviceId,
      'keyPackage1': keyPackage1,
      'keyPackage2': keyPackage2,
      'publicKeyPackage': publicKeyPackage,
    };
    await _box.put('client_state', state);
  }

  Future<Map<String, dynamic>?> getClientState() async {
    final raw = _box.get('client_state');
    if (raw == null) return null;
    return (raw as Map).cast<String, dynamic>();
  }
}
