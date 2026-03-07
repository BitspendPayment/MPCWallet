import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:blockchain_utils/blockchain_utils.dart'
    hide hex; // For Regtest address encoding
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:client/client.dart';
import 'package:convert/convert.dart';
import 'package:client/persistence/wallet_store.dart';
import 'package:client/coin_selection.dart';
import 'package:client/fees.dart';
import 'package:client/threshold/threshold.dart' as threshold; // Access bigIntToBytes
import 'package:protocol/protocol.dart';

class UnsignedTransaction {
  final BtcTransaction btcTransaction;
  final List<List<int>> sighashes;

  UnsignedTransaction(this.btcTransaction, this.sighashes);
}

class MpcBitcoinWallet {
  final MpcClient client;
  final WalletStore store;
  final bool isTestnet;

  /// Called after a background sync completes (e.g. from a transaction
  /// notification). The caller (MpcService) can use this to update
  /// balance and notify the UI.
  Future<void> Function()? onSyncComplete;

  late P2trAddress _address;
  P2trAddress get address {
    if (client.getTweakedPublicKeyPackage(null) == null) {
      throw StateError("Wallet not initialized. Call init() first.");
    }
    return _address;
  }

  List<TransactionSummary> _transactions = [];
  List<TransactionSummary> get transactions => List.unmodifiable(_transactions);

  Future<BigInt> getBalance() async {
    final utxos = await store.getUtxos();
    return utxos.fold<BigInt>(BigInt.zero, (sum, u) => sum + u.utxo.value);
  }

  MpcBitcoinWallet(this.client,
      {this.isTestnet = false, String? storageId, bool useIdentity2 = false})
      : store = WalletStore(boxName: storageId ?? 'mpc_wallet_state_default');

  Future<void> init() async {
    await store.init();

    // 1. Try to restore Client/Wallet state from persistence
    final restored = await client.restoreState();

    if (!restored || !client.isInitialized) {
      // 2. If not found, run fresh DKG
      await initializeNewWallet();
    }

    // 3. Setup derivates and sync
    _deriveAddress();

    // Start sync and subscribe in background
    unawaited(_startBackgroundSync());
  }

  Future<void> _startBackgroundSync() async {
    try {
      await sync();
      await onSyncComplete?.call();
    } catch (e) {
      stderr.writeln('[WARN] bitcoin: initial sync error: $e');
    }
    subscribe();
  }

  /// Explicitly runs the DKG protocol.
  /// Call this when creating a fresh wallet or resetting.
  Future<void> initializeNewWallet() async {
    stderr.writeln('[INFO] bitcoin: initializing new wallet…');
    if (!client.isInitialized) {
      stderr.writeln('[INFO] bitcoin: client not initialized — running DKG…');
      await client.doDkg();
    } else {
      stderr.writeln('[INFO] bitcoin: client already initialized, skipping DKG.');
    }
  }

  void _deriveAddress() {
    final publicKeyPackage = client.getTweakedPublicKeyPackage(null);
    if (publicKeyPackage == null) {
      throw StateError("Wallet not initialized. Call init() first.");
    }
    final publicKey = publicKeyPackage.verifyingKey.E;

    // Serialize point to compressed hex
    final pointBytes = threshold.elemSerializeCompressed(publicKey);
    final pointHex = hex.encode(pointBytes);

    final ecPub = ECPublic.fromHex(pointHex);
    _address = P2trAddress.fromProgram(
        program: BytesUtils.toHexString(ecPub.toXOnly()));
  }

  /// Helper to generate address with custom HRP (e.g. 'bcrt' for Regtest)
  String toAddressCustom({required String hrp}) {
    // Generate valid Testnet address first (program is same for Testnet/Regtest)
    final addr = address.toAddress(BitcoinNetwork.testnet);
    // Decode to get version/program (Tuple<int, List<int>>)
    final decoded = SegwitBech32Decoder.decode("tb", addr);
    final version = decoded.item1;
    final program = decoded.item2;
    // Encode with custom HRP
    return SegwitBech32Encoder.encode(hrp, version, program);
  }

  /// Builds an unsigned transaction, hashes it, and returns the UnsignedTransaction object.
  /// [feeRate] is in sats/vbyte.
  Future<UnsignedTransaction> createTransaction({
    required String destination,
    required BigInt amount,
    required int feeRate,
  }) async {
    // 1. Iterative Coin Selection
    final availableUtxos = await store.getUtxos();

    // Estimates used by P2trFeeEstimator

    List<UtxoWithAddress> selected = [];
    BigInt fee = BigInt.zero;
    BigInt totalIn = BigInt.zero;

    // Attempt loop to stabilize fee
    bool sufficient = false;
    for (int i = 0; i < 5; i++) {
      // Calculate estimated fee for current input count (start with 1 if empty)
      int inputCount = selected.isEmpty ? 1 : selected.length;
      // 1 output provided + potential change output (assume 1 for estimation safety)
      int outputCount = 2;

      fee = P2trFeeEstimator.calculateFee(
          inputCount: inputCount, outputCount: outputCount, feeRate: feeRate);

      try {
        final result = CoinSelection.select(availableUtxos, amount, fee);
        selected = result.$1;
        totalIn = result.$2;

        // Check if clean match (no change needed? unlikely)
        // Re-evaluate size with ACTUAL selected count
        final newFee = P2trFeeEstimator.calculateFee(
            inputCount: selected.length,
            outputCount: outputCount,
            feeRate: feeRate);

        if (newFee <= fee) {
          // We have covered the fee.
          // Actually, if we selected enough for 'fee', and 'newFee' is <= 'fee', we are good.
          // We should use the calculated newFee for the transaction construction if we want to be precise,
          // or just pay the slightly higher 'fee' we selected for.
          // Let's settle on the new calculated fee.
          fee = newFee;
          sufficient = true;
          break;
        }
        // Otherwise, fee increased (more inputs added?), loop again with higher fee
        fee = newFee;
      } catch (e) {
        // Insufficient funds even for estimation, re-throw if last attempt
        if (i == 4) rethrow;
        // Otherwise loop might try again? No, if select fails, we are out of money.
        rethrow;
      }
    }

    if (!sufficient) {
      throw Exception("Could not stabilize fee calculation");
    }

    // 2. Build Transaction
    // Calculate Change
    final inputsValue = totalIn;
    final changeValue = inputsValue - amount - fee;

    BitcoinBaseAddress outputAddress; // Was BitcoinAddress

    // TODO (Joshua) We are only concerned about taproot address for now
    if (destination.startsWith('bcrt')) {
      // Manual decoding for custom/Regtest HRP
      final decoded = SegwitBech32Decoder.decode("bcrt", destination);
      final program = decoded.item2;
      outputAddress = P2trAddress.fromProgram(program: hex.encode(program));
    } else {
      outputAddress = P2trAddress.fromAddress(
          address: destination,
          network: isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet);
    }

    final outputs = <BitcoinOutput>[
      BitcoinOutput(
        address: outputAddress,
        value: amount,
      ),
    ];

    // Add change output if above dust threshold (approx 546 sats)
    if (changeValue > BigInt.from(546)) {
      outputs.add(BitcoinOutput(
        address: address, // Send change back to self
        value: changeValue,
      ));
    }

    final builder = BitcoinTransactionBuilder(
      outPuts: outputs,
      fee: fee,
      network: isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet,
      utxos: selected,
    );

    // 3. MPC Signing Callback (Synchronous collection of hashes)
    final List<List<int>> sighashes = [];

    final txPointer =
        await builder.buildTransaction((sighash, utxo, publicKey, index) {
      sighashes.add(sighash);
      // Return dummy signature (64 bytes hex) to satisfy builder.
      return List.filled(64, 0)
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join();
    });

    // 5. Return Unsigned Transaction
    return UnsignedTransaction(txPointer, sighashes);
  }

  /// Retrieves the Policy ID for a given UnsignedTransaction by verifying/calculating spend amounts on the server.
  Future<String> getPolicyId(UnsignedTransaction unsigned) async {
    final txPointer = unsigned.btcTransaction;
    final fullTxHex = txPointer.serialize();
    final fullTxBytes = hex.decode(fullTxHex);
    return await client.getPolicyId(Uint8List.fromList(fullTxBytes));
  }

  /// Signs an unsigned transaction using the MPC client.
  /// If [pin] is provided, it attempts to resolve the Policy ID from the server
  /// (unless [policyId] is explicitly provided) and sign using the protected policy flow.
  Future<String> signTransaction(UnsignedTransaction unsigned,
      {String? pin, String? policyId}) async {
    final txPointer = unsigned.btcTransaction;
    final sighashes = unsigned.sighashes;

    if (sighashes.length != txPointer.inputs.length) {
      throw StateError("Sighash count mismatch");
    }

    String? resolvedPolicyId = policyId;
    List<int>? fullTxBytes;

    final fullTxHex = txPointer.serialize();
    fullTxBytes = hex.decode(fullTxHex);

    // 4. Sign Asynchronously
    final witnesses = <TxWitnessInput>[];

    for (int i = 0; i < txPointer.inputs.length; i++) {
      final sighash = sighashes[i];
      final sighashUint8 = Uint8List.fromList(sighash);

      final signature = await client.sign(
        sighashUint8,
        pin: pin,
        policyId: resolvedPolicyId,
        fullTransaction: fullTxBytes,
      );

      final sigBytes = signature.serialize();

      final sigHex =
          sigBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

      // Create Witness Input
      // Assuming TxWitnessInput only needs the stack since BtcTransaction correlates by index
      witnesses.add(TxWitnessInput(
        stack: [sigHex],
      ));
    }

    // 5. Reconstruct Transaction
    final signedTx = BtcTransaction(
      inputs: txPointer.inputs,
      outputs: txPointer.outputs,
      witnesses: witnesses,
      version: txPointer.version,
    );

    return signedTx.serialize();
  }

  /// Syncs the wallet's UTXOs and History using the server.
  Future<void> sync() async {
    // 1. Fetch from Server
    final utxoInfos = await client.fetchHistory();
    try {
      _transactions = await client.fetchRecentTransactions();
    } catch (e) {
      stderr.writeln('[WARN] bitcoin: error fetching recent transactions: $e');
    }

    // 2. Convert to UtxoWithAddress
    // Find P2TR type robustly
    final p2trType = BitcoinAddressType.values.firstWhere(
        (e) => e
            .toString()
            .toLowerCase()
            .contains('tr'), // matches p2tr or taproot
        orElse: () => BitcoinAddressType.values.last);

    // TODO() : WARNING: This is critical, it helps avoid retweaking of Public Key
    final publicKeyPackage = client.getPublicKeyPackage();
    if (publicKeyPackage == null) {
      throw StateError("Wallet not initialized. Call init() first.");
    }
    final publicKey = publicKeyPackage.verifyingKey.E;
    final ownerDetails = UtxoAddressDetails(
        publicKey: hex.encode(threshold.elemSerializeCompressed(publicKey)),
        address: address);

    final newUtxos = utxoInfos.map((u) {
      return UtxoWithAddress(
        utxo: BitcoinUtxo(
          txHash: u.txHash,
          vout: u.vout,
          value: BigInt.parse(u.amount.toString()),
          scriptType: p2trType,
        ),
        ownerDetails: ownerDetails,
      );
    }).toList();

    // 3. Save to Store
    final deduped = <String, UtxoWithAddress>{};
    for (final utxo in newUtxos) {
      deduped['${utxo.utxo.txHash}:${utxo.utxo.vout}'] = utxo;
    }
    final uniqueUtxos = deduped.values.toList();
    await store.saveUtxos(uniqueUtxos);
  }

  void subscribe() {
    client.subscribeToHistory().listen((notification) {
      sync().then((_) async {
        await onSyncComplete?.call();
      }).catchError((e) {
        stderr.writeln('[WARN] bitcoin: notification sync error: $e');
      });
    }, onError: (e) {
      stderr.writeln('[WARN] bitcoin: history subscription error: $e');
    });
  }

  /// Broadcasts a signed transaction hex to the network via the MPC Server.
  Future<String> broadcast(String txHex) async {
    return await client.broadcastTransaction(txHex);
  }
}
