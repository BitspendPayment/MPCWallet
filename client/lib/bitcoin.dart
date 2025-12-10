import 'dart:typed_data';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:client/client.dart';
import 'package:convert/convert.dart';
import 'package:client/persistence/wallet_store.dart';
import 'package:client/coin_selection.dart';
import 'package:client/fees.dart';

import 'package:threshold/threshold.dart' as threshold; // Access bigIntToBytes

class MpcBitcoinWallet {
  final MpcClient client;
  final bool isTestnet;
  final WalletStore store = WalletStore();

  late P2trAddress _address;
  P2trAddress get address {
    if (client.publicKey == null) {
      throw StateError("Wallet not initialized. Call init() first.");
    }
    return _address;
  }

  MpcBitcoinWallet(this.client, {this.isTestnet = false});

  Future<void> init() async {
    await store.init();

    // Check if we have saved client state
    final clientState = await store.getClientState();
    if (clientState != null) {
      await _restoreState(clientState);
    } else {
      await initializeNewWallet();
    }

    _deriveAddress();
  }

  /// Explicitly runs the DKG protocol and saves the resulting shares.
  /// Call this when creating a fresh wallet or resetting.
  Future<void> initializeNewWallet() async {
    print("No saved state found. Checking client initialization...");
    if (!client.isInitialized) {
      print("Client not initialized. Running DKG...");
      await client.doDkg();
    } else {
      print("Client already initialized. Skipping DKG.");
    }

    print("Saving MPC Client state...");
    await store.saveClientState(
      deviceId: client.deviceId,
      keyPackage1: client.keyPackage1!.toJson(),
      keyPackage2: client.keyPackage2!.toJson(),
      publicKeyPackage: client.publicKey!.toJson(),
    );
  }

  Future<void> _restoreState(Map<dynamic, dynamic> clientState) async {
    print("Restoring MPC Client state...");
    client.restoreState(
      clientState['deviceId'],
      threshold.KeyPackage.fromJson(
          Map<String, dynamic>.from(clientState['keyPackage1'])),
      threshold.KeyPackage.fromJson(
          Map<String, dynamic>.from(clientState['keyPackage2'])),
      threshold.PublicKeyPackage.fromJson(
          Map<String, dynamic>.from(clientState['publicKeyPackage'])),
    );
  }

  void _deriveAddress() {
    final publicKey = client.publicKey;
    if (publicKey == null) return; // Should not happen after init

    // 1. Extract Public Key Point
    final point = publicKey.verifyingKey.E;

    // 2. Serialize to x-only bytes (32 bytes) for Taproot
    final xBigInt = point.x!.toBigInteger();
    // Manual padding to 32 bytes
    final xBytesRaw = threshold.bigIntToBytes(xBigInt!);
    final xBytes = Uint8List(32);
    final offset = 32 - xBytesRaw.length;
    xBytes.setRange(offset, 32, xBytesRaw);

    // 3. Derive P2TR address
    final programHex =
        xBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    _address = P2trAddress.fromProgram(program: programHex);

    print(
        "Wallet Address: ${_address.toAddress(isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet)}");
  }

  /// Builds a transaction, hashes it, and returns the sighash to be signed by MPC.
  /// [feeRate] is in sats/vbyte.
  Future<String> createTransaction({
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

    final outputs = <BitcoinOutput>[
      BitcoinOutput(
        address: P2trAddress.fromAddress(
            address: destination,
            network:
                isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet),
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

    // 4. Sign Asynchronously
    final witnesses = <TxWitnessInput>[];
    if (sighashes.length != txPointer.inputs.length) {
      throw StateError("Sighash count mismatch");
    }

    for (int i = 0; i < txPointer.inputs.length; i++) {
      final sighash = sighashes[i];
      final sighashUint8 = Uint8List.fromList(sighash);

      final signature = await client.sign(sighashUint8);

      // Convert (R, Z) to Schnorr (R || s) 64 bytes
      final rBigInt = signature.R.x!.toBigInteger()!;
      final zBigInt = signature.Z;

      final rBytesRaw = threshold.bigIntToBytes(rBigInt);
      final sBytesRaw = threshold.bigIntToBytes(zBigInt);

      final rBytes = Uint8List(32);
      final sBytes = Uint8List(32);

      rBytes.setRange(32 - rBytesRaw.length, 32, rBytesRaw);
      sBytes.setRange(32 - sBytesRaw.length, 32, sBytesRaw);

      final sigBytes = Uint8List.fromList([...rBytes, ...sBytes]);
      final sigHex =
          sigBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

      // Create Witness Input
      // Assuming TxWitnessInput only needs the stack since BtcTransaction correlates by index
      witnesses.add(TxWitnessInput(
        stack: [sigHex],
      ));
    }

    // 5. Reconstruct Transaction
    // Use BtcTransaction constructor directly to include witnesses
    final signedTx = BtcTransaction(
      inputs: txPointer.inputs,
      outputs: txPointer.outputs,
      witnesses: witnesses,
      version: txPointer.version,
    );

    return signedTx.serialize();
  }

  /// Syncs the wallet's UTXOs using the provided Electrum [provider].
  /// [provider] should be an ElectrumProvider. Typed dynamic to bypass missing interface.
  Future<void> sync(dynamic provider) async {
    // 1. Get Script Hash for P2TR address
    final scriptHash = address.pubKeyHash();

    // 2. Fetch Unspent Outputs
    // Ensure we await the request.
    final List<dynamic> unspent = await (provider as dynamic)
        .request(ElectrumRequestScriptHashListUnspent(scriptHash: scriptHash));

    // 3. Convert to UtxoWithAddress
    // Find P2TR type robustly
    final p2trType = BitcoinAddressType.values.firstWhere(
        (e) => e
            .toString()
            .toLowerCase()
            .contains('tr'), // matches p2tr or taproot
        orElse: () => BitcoinAddressType.values.last);

    final newUtxos = unspent.map((u) {
      // u is expected to differ based on library version, usually has tx_hash, tx_pos, value (sats)
      // Inspecting user snippet implies direct access or Map.
      // If it's a Map: u['tx_hash'], u['tx_pos']...
      // If it's a strongly typed object: u.txHash
      // Let's assume typed object as per typical Dart libs.

      return UtxoWithAddress(
        utxo: BitcoinUtxo(
          txHash: u.txHash,
          vout: u.txPos,
          value: BigInt.from(u.value),
          scriptType: p2trType,
        ),
        ownerDetails: UtxoAddressDetails(
          // Serialize verifying key to hex
          publicKey: hex.encode(threshold
              .elemSerializeCompressed(client.publicKey!.verifyingKey.E)),
          address: address,
        ),
      );
    }).toList();

    // 4. Save to Store
    await store.saveUtxos(newUtxos);
    print("Synced ${newUtxos.length} UTXOs.");
  }
}
