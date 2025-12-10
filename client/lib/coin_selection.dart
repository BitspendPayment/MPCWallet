import 'package:bitcoin_base/bitcoin_base.dart';

class CoinSelection {
  /// Simple accumulation algorithm: Select UTXOs until amount + fee is covered.
  /// Returns a list of selected UTXOs and the total value selected.
  /// Throws Exception if insufficient funds.
  static (List<UtxoWithAddress>, BigInt) select(List<UtxoWithAddress> available,
      BigInt targetAmount, BigInt estimatedFee) {
    // Sort by value descending (optimization to reduce inputs)
    // or ascending to clear dust. Let's do descending for now.
    final sorted = List<UtxoWithAddress>.from(available);
    sorted.sort((a, b) => b.utxo.value.compareTo(a.utxo.value));

    BigInt total = BigInt.zero;
    final selected = <UtxoWithAddress>[];

    for (final u in sorted) {
      selected.add(u);
      total += u.utxo.value;
      if (total >= targetAmount + estimatedFee) {
        return (selected, total);
      }
    }

    if (total < targetAmount + estimatedFee) {
      throw Exception(
          "Insufficient funds. Available: $total, Required: ${targetAmount + estimatedFee}");
    }

    return (selected, total);
  }
}
