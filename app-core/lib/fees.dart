class P2trFeeEstimator {
  // P2TR (Taproot) Transaction Size Constants (vBytes)
  // Overhead: Version (4) + Marker (1) + Flag (1) + Locktime (4) = 10.
  // Plus variant count overhead ~1. Total ~11.
  static const int overhead = 11;

  // Input Size (Key Path Spend):
  // Outpoint (36) + Sequence (4) = 40 (Non-witness)
  // Witness: Signature (64) + SIGHASH_TYPE (1) = 65 (Witness)
  // Total Weight = (40 * 4) + 65 = 160 + 65 = 225 weight units
  // vBytes = ceil(225 / 4) = 57 (approx).
  // Using 58 as a safe conservative estimate.
  static const int inputVBytes = 58;

  // Output Size (P2TR):
  // Value (8) + VarInt(1) + Script(32) + VarInt(1)?? No.
  // ScriptPubKey is 34 bytes (1 byte version + 1 byte length + 32 bytes pubkey).
  // Total: 8 + 1 (length of script) + 34 = 43 bytes.
  static const int outputVBytes = 43;

  /// Input Size (Script Path Spend):
  /// Base (Non-witness): Outpoint(36) + Sequence(4) = 40 bytes (160 WU)
  /// Witness:
  /// - Script size: VarInt + Script
  /// - Control Block: VarInt + ControlBlock (typically 33)
  /// - Witness Stack: Item Count (VarInt) + [Item Length (VarInt) + Item]...
  static int estimateScriptPathVBytes({
    required int scriptSize,
    required int controlBlockSize,
    required int stackItemCount,
    required int totalStackSize, // Sum of sizes of items on stack
  }) {
    // Weight Units Calculation:
    // Base: 40 bytes * 4 = 160 WU
    int wu = 160;

    // Witness Data:
    // 1. Script
    wu += _varIntSize(scriptSize) + scriptSize;
    // 2. Control Block
    wu += _varIntSize(controlBlockSize) + controlBlockSize;
    // 3. Stack
    // Stack items count (approx 1 byte for reasonable counts)
    wu += _varIntSize(stackItemCount);
    // Stack items total size (each item has a length prefix, assume 1 byte len for now per item)
    wu += totalStackSize + stackItemCount;

    // Conversion to vBytes: ceil(WU / 4)
    return (wu / 4).ceil();
  }

  static int _varIntSize(int val) {
    if (val < 0xfd) return 1;
    if (val <= 0xffff) return 3;
    if (val <= 0xffffffff) return 5;
    return 9;
  }

  /// Calculates the estimated vByte size of a P2TR transaction.
  static int estimateVBytes(
      {required int inputCount, required int outputCount}) {
    return overhead + (inputCount * inputVBytes) + (outputCount * outputVBytes);
  }

  /// Calculates the required fee in satoshis.
  static BigInt calculateFee({
    required int inputCount,
    required int outputCount,
    required int feeRate,
  }) {
    final vBytes =
        estimateVBytes(inputCount: inputCount, outputCount: outputCount);
    return BigInt.from(vBytes * feeRate);
  }
}
