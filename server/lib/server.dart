import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:threshold/threshold.dart' as threshold;
import 'package:threshold/frost/signing.dart' as frost;
import 'package:threshold/frost/commitment.dart' as frost_comm;
import 'package:fixnum/fixnum.dart';
import 'package:synchronized/synchronized.dart';
import 'package:logging/logging.dart';

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart'; // for hex

import 'package:protocol/protocol.dart';
import 'persistence/store.dart';
import 'state.dart';
import 'dart:math';

import 'policy.dart';
import 'bitcoin.dart';
import 'bitcoin_service.dart';
import 'config.dart';
import 'auth_verifier.dart';

final _log = Logger('MPCWalletService');

class MPCWalletService extends MPCWalletServiceBase {
  // In-memory cache of active sessions with locks for thread safety
  final Map<String, DKGSessionState> _dkgSessions = {};
  final Map<String, SigningSessionState> _signingSessions = {};
  final Map<String, RefreshSessionState> _refreshSessions = {};
  final Map<String, PolicyState> _policies = {};
  final Map<String, UtxoState> _utxos = {};

  // Locks for synchronized access to session maps
  final Lock _dkgLock = Lock();
  final Lock _signingLock = Lock();
  final Lock _refreshLock = Lock();
  final Lock _policyLock = Lock();
  final Lock _utxoLock = Lock();

  // Persistence
  final DKGSessionStore dkgStore;
  final SigningSessionStore signingStore;
  final RefreshSessionStore refreshStore;
  final PolicyStore policyStore;
  final UtxoStore utxoStore;

  final BitcoinService bitcoinService;
  final BitcoinHistoryService historyService;

  // Authentication verifier for request signatures
  final AuthVerifier authVerifier;

  static const int totalParticipants = 3;
  static const int thresholdCount = 2;

  MPCWalletService({
    required this.dkgStore,
    required this.signingStore,
    required this.refreshStore,
    required this.policyStore,
    required this.utxoStore,
    required this.bitcoinService,
    required this.historyService,
    AuthVerifier? authVerifier,
  }) : authVerifier = authVerifier ?? AuthVerifier();

  Future<DKGSessionState> _getDKGSession(String userId) async {
    return await _dkgLock.synchronized(() async {
      if (!_dkgSessions.containsKey(userId)) {
        // Try load
        final jsonStr = await dkgStore.getSession(userId);
        if (jsonStr != null) {
          try {
            _dkgSessions[userId] =
                DKGSessionState.fromJson(jsonDecode(jsonStr));
            _log.info('[$userId] Loaded DKG session from store.');
          } catch (e) {
            _log.warning('[$userId] Error loading DKG session: $e');
          }
        }

        if (!_dkgSessions.containsKey(userId)) {
          _dkgSessions[userId] = DKGSessionState(userId);
          _log.info('[$userId] New DKG session created');
        }
      }
      return _dkgSessions[userId]!;
    });
  }

  Future<RefreshSessionState> _getRefreshSession(String userId) async {
    return await _refreshLock.synchronized(() async {
      if (!_refreshSessions.containsKey(userId)) {
        // Try load
        final jsonStr = await refreshStore.getSession(userId);
        if (jsonStr != null) {
          try {
            _refreshSessions[userId] =
                RefreshSessionState.fromJson(jsonDecode(jsonStr));
            _log.info('[$userId] Loaded Refresh session from store.');
          } catch (e) {
            _log.warning('[$userId] Error loading Refresh session: $e');
          }
        }

        if (!_refreshSessions.containsKey(userId)) {
          _refreshSessions[userId] = RefreshSessionState(userId);
          _log.info('[$userId] New Refresh session created');
        }
      }
      return _refreshSessions[userId]!;
    });
  }

  Future<SigningSessionState> _getSigningSession(String userId) async {
    return await _signingLock.synchronized(() {
      if (!_signingSessions.containsKey(userId)) {
        _signingSessions[userId] = SigningSessionState(userId);
        _log.info('[$userId] New Signing session created');
      }
      return _signingSessions[userId]!;
    });
  }

  Future<PolicyState> _getPolicyState(String userId) async {
    return await _policyLock.synchronized(() async {
      if (!_policies.containsKey(userId)) {
        // Try load
        final jsonStr = await policyStore.getPolicy(userId);
        if (jsonStr != null) {
          try {
            _policies[userId] = PolicyState.fromJson(jsonDecode(jsonStr));
            _log.info('[$userId] Loaded Policy state from store.');
          } catch (e) {
            _log.warning('[$userId] Error loading Policy state: $e');
          }
        }
        if (!_policies.containsKey(userId)) {
          throw StateError('No Policy state found for user $userId');
        }
      }
      return _policies[userId]!;
    });
  }

  Future<PolicyState> _newPolicyState(
      String userId, String recoveryId, NormalPolicy policy) async {
    return await _policyLock.synchronized(() {
      if (_policies.containsKey(userId)) {
        //remove existing
        _policies.remove(userId);
      }
      _policies[userId] = PolicyState(userId, recoveryId, policy);
      _log.info('[$userId] New Policy state created');
      return _policies[userId]!;
    });
  }

  Future<UtxoState> _getUtxoState(String userId) async {
    return await _utxoLock.synchronized(() async {
      if (!_utxos.containsKey(userId)) {
        final newState = UtxoState(userId);

        // Load from persistence
        final existingJson = await utxoStore.getUtxo(userId);
        if (existingJson != null) {
          try {
            final List<dynamic> list = jsonDecode(existingJson);
            final loadedUtxos = list.map((item) {
              final amount = BigInt.parse(item['amount'].toString());
              final txid = item['tx_hash'] as String;
              final vout = item['vout'] as int;
              return Utxo(amount, txid, vout);
            }).toList();
            newState.addUtxoList(loadedUtxos);
            _log.info(
                '[$userId] Loaded ${loadedUtxos.length} UTXOs from store.');
          } catch (e) {
            _log.warning('[$userId] Error loading UTXOs: $e');
          }
        }

        _utxos[userId] = newState;
      }
      return _utxos[userId]!;
    });
  }

  static String _idToString(threshold.Identifier id) {
    final idList = threshold.bigIntToBytes(id.toScalar());
    return idList.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static threshold.Identifier _stringToId(String s) {
    return threshold.Identifier(BigInt.parse(s, radix: 16));
  }

  static Map<String, String> _stringKeyedPackageMap(
      Map<threshold.Identifier, String> input) {
    return {
      for (final entry in input.entries) _idToString(entry.key): entry.value,
    };
  }

  static String _userIdFromVerifyingKey(threshold.VerifyingKey verifyingKey) {
    final bytes = threshold.elemSerializeCompressed(verifyingKey.E);
    return hex.encode(bytes);
  }

  // --- DKG ---
  @override
  Future<DKGStep1Response> dKGStep1(
      ServiceCall call, DKGStep1Request request) async {
    final userId = request.userId;

    final userIdHex = hex.encode(userId);

    final session = await _getDKGSession(userIdHex);
    try {
      final identifier = threshold.Identifier.deserialize(
          Uint8List.fromList(request.identifier));
      _log.info(
          '[$userIdHex] DKGStep1: Received PubPackage from ${hex.encode(userId)}');

      session.round1Packages[identifier] = request.round1Package;

      // Server Init for this session
      if (session.serverRound1SecretPackage == null) {
        _log.info('[$userIdHex] Server: Generating DKG secrets...');
        final secret = threshold.SecretKey(threshold.modNRandom());
        final coeffs = threshold.generateCoefficients(thresholdCount - 1);
        final (r1Secret, r1Public) = threshold.dkgPart1(
            totalParticipants, thresholdCount, secret, coeffs);

        final serverId =
            threshold.elemSerializeCompressed(r1Public.verifyingKey.E);

        session.serverInternalSecret = secret;
        session.serverRound1SecretPackage = r1Secret;
        session.serverId = serverId;

        final serverIdentifier = threshold.Identifier.derive(session.serverId!);
        session.round1Packages[serverIdentifier] =
            jsonEncode(r1Public.toJson());
      }

      if (session.round1Packages.length == totalParticipants) {
        if (!session.completerStep1.isCompleted)
          session.completerStep1.complete();
      } else {
        await session.completerStep1.future;
      }

      return DKGStep1Response()
        ..round1Packages.addAll(_stringKeyedPackageMap(session.round1Packages));
    } catch (e) {
      _log.severe('[$userIdHex] DKGStep1 Error: $e');
      session.reset();
      rethrow;
    }
  }

  @override
  Future<DKGStep2Response> dKGStep2(
      ServiceCall call, DKGStep2Request request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    final session = await _getDKGSession(userIdHex);
    try {
      await session.completerStep1.future;

      if (session.serverId == null) {
        throw StateError('Server ID not initialized for session $userIdHex');
      }

      if (session.dkgRound2PackagesLocal.isEmpty) {
        _log.info('[$userIdHex] DKGStep2: Server computing shares...');
        final round1Pkgs = <threshold.Identifier, threshold.Round1Package>{};
        session.round1Packages.forEach((k, v) {
          final serverIdenfier = threshold.Identifier.derive(session.serverId!);

          if (k != serverIdenfier) {
            round1Pkgs[k] = threshold.Round1Package.fromJson(jsonDecode(v));
          }
        });

        if (session.serverRound1SecretPackage == null) {
          throw StateError('Server secrets missing for session $userIdHex');
        }

        final (serverRound2Secret, serverRound2Pkgs) =
            threshold.dkgPart2(session.serverRound1SecretPackage!, round1Pkgs);

        session.serverRound2Secret = serverRound2Secret;
        session.dkgRound2PackagesLocal.addAll(serverRound2Pkgs);
      }

      if (!session.completerStep2.isCompleted)
        session.completerStep2.complete();

      return DKGStep2Response()
        ..allRound1Packages
            .addAll(_stringKeyedPackageMap(session.round1Packages));
    } catch (e) {
      _log.severe('[$userIdHex] DKGStep2 Error: $e');
      session.reset();
      rethrow;
    }
  }

  @override
  Future<DKGStep3Response> dKGStep3(
      ServiceCall call, DKGStep3Request request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    _log.info('[$userIdHex] DKGStep3: Received Shares from ${userIdHex}');

    final session = await _getDKGSession(userIdHex);
    try {
      if (session.serverId == null) {
        throw StateError('Server ID not initialized for session $userIdHex');
      }

      final identifier = threshold.Identifier.deserialize(
          Uint8List.fromList(request.identifier));

      final serverIdentifier = threshold.Identifier.derive(session.serverId!);

      await session.completerStep2.future;

      final sharesFromSenderForOthers =
          <threshold.Identifier, threshold.Round2Package>{};
      for (final entry in request.round2PackagesForOthers.entries) {
        final recipientId = _stringToId(entry.key);
        final pkg = threshold.Round2Package.fromJson(jsonDecode(entry.value));
        sharesFromSenderForOthers[recipientId] = pkg;

        if (recipientId == serverIdentifier) {
          session.dkgRound2PackagesReceived[identifier] = pkg;
        }
      }
      session.dkgRound2PackagesForRelay[identifier] = sharesFromSenderForOthers;

      if (session.dkgRound2PackagesForRelay.length == totalParticipants - 1) {
        session.dkgRound2PackagesForRelay[serverIdentifier] =
            session.dkgRound2PackagesLocal;
        if (!session.completerStep3.isCompleted)
          session.completerStep3.complete();
      } else {
        await session.completerStep3.future;
      }

      final packagesForRequester = <String, String>{};
      for (final participantId in session.dkgRound2PackagesForRelay.keys) {
        final participantShares =
            session.dkgRound2PackagesForRelay[participantId]!;
        if (participantShares.containsKey(identifier)) {
          packagesForRequester[_idToString(participantId)] =
              jsonEncode(participantShares[identifier]!.toJson());
        }
      }

      if (session.completerStep3.isCompleted) {
        _log.info('[$userIdHex] DKGStep3: Server computing KeyPackage...');

        final userSigningIdentifier =
            threshold.Identifier.derive(Uint8List.fromList(userId));

        Uint8List? userRecoveryIdentifier;

        final allRound1Pkgs = <threshold.Identifier, threshold.Round1Package>{};
        session.round1Packages.forEach((k, v) {
          final decodedPkg = threshold.Round1Package.fromJson(jsonDecode(v));
          if (k != serverIdentifier) {
            allRound1Pkgs[k] = decodedPkg;

            if (k != userSigningIdentifier && userRecoveryIdentifier == null) {
              userRecoveryIdentifier =
                  threshold.elemSerializeCompressed(decodedPkg.verifyingKey.E);
            }
          }
        });

        final allReceivedSharesPoints =
            <threshold.Identifier, threshold.Round2Package>{};
        allReceivedSharesPoints.addAll(session.dkgRound2PackagesReceived);

        final (keyPkg, pubKeyPkg) = threshold.dkgPart3(
            session.serverRound1SecretPackage!,
            session.serverRound2Secret!,
            allRound1Pkgs,
            allReceivedSharesPoints);

        final normalPolicy = NormalPolicy(
          id: "normal policies",
          keyPackage: keyPkg,
          publicKeyPackage: pubKeyPkg,
        );

        // fresh policy state
        final userRecoveryIdHex = hex.encode(userRecoveryIdentifier!);
        final policyState =
            await _newPolicyState(userIdHex, userRecoveryIdHex, normalPolicy);
        _policies[userIdHex] = policyState;

        _log.info('[$userId] DKG Complete. PK: ${pubKeyPkg.verifyingKey.E}');

        // Persistence
        try {
          await policyStore.savePolicy(
              userIdHex, jsonEncode(policyState.toJson()));
          await dkgStore.saveSession(userIdHex, jsonEncode(session.toJson()));
          _log.info('[$userId] Saved DKG completion state.');
        } catch (e) {
          _log.severe('[$userId] Error saving DKG complete state: $e');
        }
      }

      return DKGStep3Response()
        ..round2PackagesForMe.addAll(packagesForRequester);
    } catch (e) {
      _log.severe('[$userIdHex] DKGStep3 Error: $e');
      session.reset();
      rethrow;
    }
  }

  // --- Signing ---

  // Helper to decode tx and calculate spent amount
  Future<BigInt> _calculateSpentAmount(Uint8List fullTxBytes,
      threshold.PublicKeyPackage groupKey, String userId) async {
    if (fullTxBytes.isEmpty) return BigInt.zero;

    try {
      final tx = BtcTransaction.deserialize(fullTxBytes);

      BigInt totalIn = BigInt.zero;
      final utxoState = await _getUtxoState(userId);
      final clientUtxos = utxoState.utxos;
      for (final input in tx.inputs) {
        for (final y in clientUtxos) {
          if (y.txid == input.txId && y.vout == input.txIndex) {
            totalIn += y.amount;
          }
        }
      }
      BigInt changeValue = BigInt.zero;

      final tweakedPk = groupKey.tweak(null);
      final point = tweakedPk.verifyingKey.E;
      final pointBytes = threshold.elemSerializeCompressed(point);
      // P2TR script is: 5120 <32-byte-x-only-pubkey>
      // Use bitcoin_base to generate address/program to be safe
      final ecPub = ECPublic.fromHex(BytesUtils.toHexString(pointBytes));
      final p2tr = P2trAddress.fromProgram(
          program: BytesUtils.toHexString(ecPub.toXOnly()));
      final groupScript = p2tr.toScriptPubKey().toHex();
      for (final out in tx.outputs) {
        final outScript = out.scriptPubKey.toHex();
        if (groupScript == outScript) {
          changeValue += out.amount;
        }
      }

      final spent = totalIn - changeValue;
      // Note: This 'spent' includes Fee + Destination Amount.
      // Policy usually applies to "Amount leaving the wallet".
      // So this is correct.
      return spent;
    } catch (e) {
      _log.warning("Error decoding transaction: $e");
      // Fallback/Fail safe
      return BigInt.zero;
    }
  }

  Future<ProtectedPolicy?> _getPolicy(
    List<int> txMessage,
    threshold.PublicKeyPackage groupKey,
    String userId,
  ) async {
    final policies = await _getPolicyState(userId);
    final spent = await _calculateSpentAmount(
        Uint8List.fromList(txMessage), groupKey, userId);

    // Check cumulative spending for active policies
    final now = DateTime.now();

    // Iterate policies
    for (final p in policies.protectedPolicies.values) {
      // Calculate policy window
      // Window Start = startTime + (N * interval) such that Window Start <= now
      final diff = now.difference(p.startTime);
      if (diff.isNegative) continue; // Not started yet

      final intervalsPassed = diff.inSeconds ~/ p.interval.inSeconds;
      final currentWindowStart = p.startTime.add(p.interval * intervalsPassed);

      // Sum historical spending in this window
      BigInt cumulativeSpent = BigInt.zero;
      for (final entry in policies.spendingHistory) {
        if (entry.timestamp.isAfter(currentWindowStart) ||
            entry.timestamp.isAtSameMomentAs(currentWindowStart)) {
          cumulativeSpent += entry.amount;
        }
      }

      // Add current spending
      final totalSpent = cumulativeSpent + spent;

      if (totalSpent > p.thresholdSats) {
        return p;
      }
    }
    return null;
  }

  @override
  Future<SignStep1Response> signStep1(
      ServiceCall call, SignStep1Request request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifySignStep1(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    final session = await _getSigningSession(userIdHex);
    try {
      final policyState = await _getPolicyState(userIdHex);
      _log.info('[$userId] SignStep1: Received from ${userIdHex}');

      final userIdentifier =
          threshold.Identifier.derive(Uint8List.fromList(userId));
      var serverKeyPackage = policyState.normalPolicy.keyPackage;

      final policy = await _getPolicy(
        request.fullTransaction,
        policyState.normalPolicy.publicKeyPackage,
        userIdHex,
      );

      if (policy != null) {
        serverKeyPackage = policy.keyPackage;
        session.currentPolicyId = policy.id;
        _log.info(
            '[$userId] SignStep1: Switched to Protected Policy: ${policy.id}');
      } else {
        _log.info('[$userId] SignStep1: Using Normal Policy (Default)');
      }

      // ---------------------------

      final hidingP = threshold.elemDeserializeCompressed(
          Uint8List.fromList(request.hidingCommitment));
      final bindingP = threshold.elemDeserializeCompressed(
          Uint8List.fromList(request.bindingCommitment));
      session.userCommitments =
          frost_comm.SigningCommitments(bindingP, hidingP);

      if (session.serverNonce == null) {
        _log.info('[$userId] SignStep1: Server generating commitments...');
        session.serverNonce = frost_comm.newNonce(serverKeyPackage.secretShare);
        session.serverCommitments = session.serverNonce!.commitments;
      }

      if (session.messageToSign == null && request.messageToSign.isNotEmpty) {
        session.messageToSign = Uint8List.fromList(request.messageToSign);
      }

      // Calculate spent amount for history tracking
      final spent = await _calculateSpentAmount(
          Uint8List.fromList(request.fullTransaction),
          policyState.normalPolicy.publicKeyPackage,
          userIdHex);
      session.pendingAmount = spent;

      if (session.userCommitments != null &&
          session.serverCommitments != null) {
        if (!session.completerSignStep1.isCompleted)
          session.completerSignStep1.complete();
      } else {
        await session.completerSignStep1.future;
      }

      final serverIdentifier = serverKeyPackage.identifier;
      final responseCommitments = <String, SignStep1Response_Commitment>{};
      final signCommitmentList = [
        (serverIdentifier, session.serverCommitments!),
        (userIdentifier, session.userCommitments!)
      ];

      session.signCommitmentList = {};

      for (final (id, comm) in signCommitmentList) {
        responseCommitments[_idToString(id)] = SignStep1Response_Commitment(
          hiding: threshold.elemSerializeCompressed(comm.hiding),
          binding: threshold.elemSerializeCompressed(comm.binding),
        );

        session.signCommitmentList[id] = comm;
      }

      return SignStep1Response()
        ..commitments.addAll(responseCommitments)
        ..messageToSign = session.messageToSign!;
    } catch (e) {
      _log.severe('[$userId] SignStep1 Error: $e');
      session.reset();
      rethrow;
    }
  }

  @override
  Future<SignStep2Response> signStep2(
      ServiceCall call, SignStep2Request request) async {
    final userId = request.userId;

    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifySignStep2(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    _log.info('[$userId] SignStep2: Received from ${userIdHex}');

    final session = await _getSigningSession(userIdHex);
    try {
      final policyState = await _getPolicyState(userIdHex);

      final userIdentifier =
          threshold.Identifier.derive(Uint8List.fromList(userId));

      var serverKeyPackage = policyState.normalPolicy.keyPackage;
      var serverPubPackage = policyState.normalPolicy.publicKeyPackage;

      if (session.currentPolicyId != null) {
        serverKeyPackage =
            policyState.protectedPolicies[session.currentPolicyId!]!.keyPackage;
        serverPubPackage = policyState
            .protectedPolicies[session.currentPolicyId!]!.publicKeyPackage;
      }

      final share =
          threshold.bytesToBigInt(Uint8List.fromList(request.signatureShare));
      session.signRound2Shares[userIdentifier] = share;

      final serverIdentifier = serverKeyPackage.identifier;

      if (!session.signRound2Shares.containsKey(serverIdentifier) &&
          session.serverNonce != null) {
        _log.info('[$userId] SignStep2: Server computing share...');
        final signingPkg = frost_comm.SigningPackage(
            session.signCommitmentList, session.messageToSign!);

        // Explicitly apply Taproot tweak (Key Path Spending)
        serverKeyPackage = serverKeyPackage.tweak(null);

        final serverShareObj =
            frost.sign(signingPkg, session.serverNonce!, serverKeyPackage);
        session.signRound2Shares[serverIdentifier] = serverShareObj.s;
      }

      if (session.signRound2Shares.length >= thresholdCount) {
        if (!session.completerSignStep2.isCompleted)
          session.completerSignStep2.complete();
      } else {
        await session.completerSignStep2.future;
      }

      final signingPkg = frost_comm.SigningPackage(
          session.signCommitmentList, session.messageToSign!);
      final sharesMap = <threshold.Identifier, frost.SignatureShare>{};
      session.signRound2Shares.forEach((id, val) {
        sharesMap[id] = frost.SignatureShare(val);
      });

      // CRITICAL: Tweak public package before aggregation
      // This must happen every time, not just when server signs,
      // because we reload the untweaked package from state at the top of this function
      serverPubPackage = serverPubPackage.tweak(null);

      final signature =
          frost.aggregate(signingPkg, sharesMap, serverPubPackage);
      _log.info('[$userId] SignStep2: Aggregated.');

      // Commit Pending Amount to History
      if (session.pendingAmount != null &&
          session.pendingAmount! > BigInt.zero) {
        policyState.spendingHistory
            .add(SpendingEntry(DateTime.now(), session.pendingAmount!));
        _log.info(
            '[$userId] Policy Update: Added spending of ${session.pendingAmount} sats. Total History: ${policyState.spendingHistory.length}');

        // Persist Policy State (spending history update)
        try {
          await policyStore.savePolicy(
              hex.encode(userId), jsonEncode(policyState.toJson()));
        } catch (e) {
          _log.severe('[$userId] Error saving policy spending history: $e');
        }
      }

      final response = SignStep2Response()
        ..rPoint = threshold.elemSerializeCompressed(signature.R)
        ..zScalar = threshold.bigIntToBytes(signature.Z);

      // Reset session after successful signing so next sign gets fresh nonces
      session.reset();

      return response;
    } catch (e) {
      _log.severe('[$userId] SignStep2 Error: $e');
      session.reset();
      rethrow;
    }
  }

  // --- Refresh ---

  @override
  Future<RefreshStep1Response> refreshStep1(
      ServiceCall call, RefreshStep1Request request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifyRefreshStep1(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    _log.info('[$userId] RefreshStep1: Received PubPackage from $userIdHex');

    final session = await _getRefreshSession(userIdHex);

    final userIdentifier =
        threshold.Identifier.derive(Uint8List.fromList(userId));

    try {
      final policyState = await _getPolicyState(userIdHex);

      // Auto-Reset if previous session finished
      if (session.completerRefreshStep3.isCompleted) {
        _log.info(
            '[$userId] RefreshStep1: Resetting previous refresh session...');
        session.reset();
        // Since reset() clears everything including refreshCreationTime, we need to re-initialize below
      }

      session.refreshRound1Packages[userIdentifier] = request.round1Package;

      // Server Init for this refresh session
      if (session.serverRefreshRound1Secret == null) {
        _log.info('[$userId] Server: Generating Refresh secrets...');

        final serverIdentifier = policyState.normalPolicy.keyPackage.identifier;
        final serverId = threshold.elemSerializeCompressed(
            policyState.normalPolicy.publicKeyPackage.verifyingKey.E);

        session.serverId = serverId;
        session.serverIdentifier = serverIdentifier;

        final (r1Secret, r1Public) = threshold.dkgRefreshPart1(
          serverIdentifier,
          2,
          thresholdCount,
        );

        if (session.refreshCreationTime == null) {
          session.refreshCreationTime = DateTime.now();
          session.refreshId = randomBase64(32);
          session.refreshThresholdAmount = request.thresholdAmount;
          session.refreshInterval = request.interval.toInt();
        }

        session.serverRefreshRound1Secret = r1Secret;
        session.refreshRound1Packages[serverIdentifier] =
            jsonEncode(r1Public.toJson());
      }

      if (session.refreshRound1Packages.length == 2) {
        if (!session.completerRefreshStep1.isCompleted)
          session.completerRefreshStep1.complete();
      } else {
        await session.completerRefreshStep1.future;
      }

      return RefreshStep1Response()
        ..round1Packages
            .addAll(_stringKeyedPackageMap(session.refreshRound1Packages))
        ..startTime = Int64(session.refreshCreationTime!.millisecondsSinceEpoch)
        ..policyId = session.refreshId!;
    } catch (e) {
      _log.severe('[$userId] RefreshStep1 Error: $e');
      session.reset();
      rethrow;
    }
  }

  @override
  Future<RefreshStep2Response> refreshStep2(
      ServiceCall call, RefreshStep2Request request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifyRefreshStep2(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    final session = await _getRefreshSession(userIdHex);

    if (session.serverIdentifier == null) {
      throw StateError('Server identifier not initialized for session $userIdHex');
    }

    final serverIdentifier = session.serverIdentifier!;
    try {
      await session.completerRefreshStep1.future;

      if (session.refreshRound2PackagesLocal.isEmpty) {
        _log.info('[$userId] RefreshStep2: Server computing shares...');
        final round1Pkgs = <threshold.Identifier, threshold.Round1Package>{};
        session.refreshRound1Packages.forEach((k, v) {
          if (k != serverIdentifier) {
            round1Pkgs[k] = threshold.Round1Package.fromJson(jsonDecode(v));
          }
        });

        final (serverRound2Secret, serverRound2Pkgs) = threshold
            .dkgRefreshPart2(session.serverRefreshRound1Secret!, round1Pkgs);

        session.serverRefreshRound2Secret = serverRound2Secret;
        session.refreshRound2PackagesLocal.addAll(serverRound2Pkgs);
      }

      if (!session.completerRefreshStep2.isCompleted)
        session.completerRefreshStep2.complete();

      return RefreshStep2Response()
        ..allRound1Packages
            .addAll(_stringKeyedPackageMap(session.refreshRound1Packages));
    } catch (e) {
      _log.severe('[$userId] RefreshStep2 Error: $e');
      session.reset();
      rethrow;
    }
  }

  @override
  Future<RefreshStep3Response> refreshStep3(
      ServiceCall call, RefreshStep3Request request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifyRefreshStep3(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    _log.info('[$userId] RefreshStep3: Received Shares from ${userIdHex}');

    final session = await _getRefreshSession(userIdHex);

    if (session.serverIdentifier == null) {
      throw StateError('Server identifier not initialized for session $userIdHex');
    }
    final serverIdentifier = session.serverIdentifier!;

    try {
      final policyState = await _getPolicyState(userIdHex);

      final userIdentifier =
          threshold.Identifier.derive(Uint8List.fromList(userId));

      await session.completerRefreshStep2.future;

      final sharesFromSenderForOthers =
          <threshold.Identifier, threshold.Round2Package>{};
      for (final entry in request.round2PackagesForOthers.entries) {
        final recipientId = _stringToId(entry.key);
        final pkg = threshold.Round2Package.fromJson(jsonDecode(entry.value));
        sharesFromSenderForOthers[recipientId] = pkg;

        if (recipientId == serverIdentifier) {
          session.refreshRound2PackagesReceived[userIdentifier] = pkg;
        }
      }
      session.refreshRound2PackagesForRelay[userIdentifier] =
          sharesFromSenderForOthers;

      // Determine N based on session state
      int n = 2;

      if (session.refreshRound2PackagesForRelay.length == n - 1) {
        session.refreshRound2PackagesForRelay[serverIdentifier] =
            session.refreshRound2PackagesLocal;
        if (!session.completerRefreshStep3.isCompleted)
          session.completerRefreshStep3.complete();
      } else {
        await session.completerRefreshStep3.future;
      }

      final packagesForRequester = <String, String>{};
      for (final participantId in session.refreshRound2PackagesForRelay.keys) {
        final participantShares =
            session.refreshRound2PackagesForRelay[participantId]!;
        if (participantShares.containsKey(userIdentifier)) {
          packagesForRequester[_idToString(participantId)] =
              jsonEncode(participantShares[userIdentifier]!.toJson());
        }
      }

      if (session.completerRefreshStep3.isCompleted) {
        if (session.serverRefreshRound2Secret != null) {
          _log.info('[$userId] RefreshStep3: Server computing New Key...');

          final allRound1Pkgs =
              <threshold.Identifier, threshold.Round1Package>{};
          session.refreshRound1Packages.forEach((k, v) {
            if (k != serverIdentifier) {
              allRound1Pkgs[k] =
                  threshold.Round1Package.fromJson(jsonDecode(v));
            }
          });

          final allReceivedSharesPoints =
              <threshold.Identifier, threshold.Round2Package>{};
          allReceivedSharesPoints.addAll(session.refreshRound2PackagesReceived);

          final normalKey = policyState.normalPolicy.keyPackage;
          final normalPub = policyState.normalPolicy.publicKeyPackage;

          final (keyPkg, pubKeyPkg) = threshold.dkgRefreshPart3(
              session.serverRefreshRound2Secret!,
              allRound1Pkgs,
              allReceivedSharesPoints,
              normalPub,
              normalKey);

          final newPolicy = ProtectedPolicy(
            id: session.refreshId!,
            thresholdSats: BigInt.from(session.refreshThresholdAmount!.toInt()),
            startTime: session.refreshCreationTime!,
            interval: Duration(seconds: session.refreshInterval!),
            keyPackage: keyPkg,
            publicKeyPackage: pubKeyPkg,
          );

          policyState.protectedPolicies[newPolicy.id] = newPolicy;

          // Persist New Policy and Refresh Session
          try {
            await policyStore.savePolicy(
                userIdHex, jsonEncode(policyState.toJson()));
            await refreshStore.saveSession(
                userIdHex, jsonEncode(session.toJson()));
          } catch (e) {
            _log.severe('[$userId] Error saving Refreshed Policy: $e');
          }

          // Prevent re-computation
          session.serverRefreshRound2Secret = null;

          // Verify invariant - REJECT if group key changed (security critical)
          if (normalPub.verifyingKey.E.getEncoded(true).toString() !=
              pubKeyPkg.verifyingKey.E.getEncoded(true).toString()) {
            _log.severe(
                '[$userId] CRITICAL: Group key changed during refresh! This indicates a protocol failure or attack.');
            throw GrpcError.internal(
                'Protocol violation: Group key changed during refresh');
          }

          if (!session.completerRefreshStep3.isCompleted)
            session.completerRefreshStep3.complete();
        }
      }

      // Wait for completion if we weren't the trigger
      await session.completerRefreshStep3.future;

      return RefreshStep3Response()
        ..round2PackagesForMe.addAll(packagesForRequester);
    } catch (e) {
      _log.severe('[$userId] RefreshStep3 Error: $e');
      session.reset();
      rethrow;
    }
  }

  @override
  Future<GetPolicyIdResponse> getPolicyId(
      ServiceCall call, GetPolicyIdRequest request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifyGetPolicyId(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    final policyState = await _getPolicyState(userIdHex);

    // request.txMessage is already List<int> (bytes)
    final policy = await _getPolicy(
      request.txMessage,
      policyState.normalPolicy.publicKeyPackage,
      userIdHex,
    );

    return GetPolicyIdResponse()..policyId = policy?.id ?? "";
  }

  @override
  Future<CreateSpendingPolicyResponse> createSpendingPolicy(
      ServiceCall call, CreateSpendingPolicyRequest request) async {
    throw GrpcError.unimplemented("Use Refresh flow to create policies");
  }

  @override
  Future<BroadcastTransactionResponse> broadcastTransaction(
      ServiceCall call, BroadcastTransactionRequest request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    _log.info(
        '[$userId] Broadcasting Tx: ${request.txHex.substring(0, 20)}...');

    final policyState = await _getPolicyState(userIdHex);
    final (txId, _) = await bitcoinService.broadcastTransaction(
        userIdHex, request.txHex, policyState);

    return BroadcastTransactionResponse()..txId = txId;
  }

  @override
  Future<FetchHistoryResponse> fetchHistory(
      ServiceCall call, FetchHistoryRequest request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifyFetchHistory(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    final policyState = await _getPolicyState(userIdHex);

    // Fetch from BitcoinHistoryService
    final utxos = await historyService.getUtxos(userIdHex, policyState);

    return FetchHistoryResponse()..utxos.addAll(utxos);
  }

  @override
  Future<FetchRecentTransactionsResponse> fetchRecentTransactions(
      ServiceCall call, FetchRecentTransactionsRequest request) async {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifyFetchRecentTransactions(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    final policyState = await _getPolicyState(userIdHex);
    try {
      final txs =
          await historyService.getRecentTransactions(userIdHex, policyState);

      _log.info('[$userId] FetchRecentTransactionsResponse: ${txs.length} txs');
      return FetchRecentTransactionsResponse()..transactions.addAll(txs);
    } catch (e) {
      _log.severe('[$userId] fetchRecentTransactions Error: $e');
      rethrow;
    }
  }

  @override
  Stream<TransactionNotification> subscribeToHistory(
      ServiceCall call, SubscribeToHistoryRequest request) async* {
    final userId = request.userId;
    final userIdHex = hex.encode(userId);

    // Verify authentication signature
    authVerifier.verifySubscribeHistory(
      userId: Uint8List.fromList(userId),
      signature: Uint8List.fromList(request.signature),
      timestampMs: request.timestampMs.toInt(),
    );

    final policyState = await _getPolicyState(userIdHex);
    yield* historyService.subscribe(userIdHex, policyState);
  }
} // End of MPCWalletService

Future<void> main(List<String> args) async {
  Server? server;
  BitcoinHistoryService? historyService;
  var shuttingDown = false;

  Future<void> shutdown(
      {int exitCode = 0, Object? error, StackTrace? stack}) async {
    if (shuttingDown) return;
    shuttingDown = true;

    if (error != null) {
      stderr.writeln('Unhandled exception: $error');
      if (stack != null) {
        stderr.writeln(stack);
      }
    } else {
      print('Shutting down...');
    }

    // Close services first to terminate active streams (prevents gRPC shutdown hang)
    try {
      if (historyService != null) {
        await historyService!.close().timeout(const Duration(seconds: 2),
            onTimeout: () {
          print("History service close timed out.");
        });
      }
    } catch (e) {
      stderr.writeln('Error closing history service: $e');
    }

    try {
      // Shutdown gRPC server
      if (server != null) {
        await server!.shutdown().timeout(const Duration(seconds: 2),
            onTimeout: () {
          print("Server shutdown timed out.");
        });
      }
    } catch (e) {
      stderr.writeln('Error shutting down server: $e');
    }

    try {
      await Hive.close().timeout(const Duration(seconds: 2), onTimeout: () {
        print("Hive close timed out.");
        return [];
      });
    } catch (e) {
      stderr.writeln('Error closing Hive: $e');
    }

    exit(exitCode);
  }

  void handleSignal(ProcessSignal signal) {
    stderr.writeln('Received $signal, shutting down.');
    shutdown(exitCode: 0);
  }

  for (final signal in [
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ]) {
    try {
      signal.watch().listen(handleSignal);
    } catch (e) {
      stderr.writeln('Signal $signal not supported: $e');
    }
  }

  await runZonedGuarded(() async {
    final config = ServerConfig.fromEnvironment();
    config.validate();

    // Setup logging
    Logger.root.level = config.loggerLevel;
    Logger.root.onRecord.listen((record) {
      final time = record.time.toIso8601String();
      print(
          '$time [${record.level.name}] ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        print('Stack: ${record.stackTrace}');
      }
    });

    // Persistence Init
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final serverStorePath = p.join(home, '.mpc_wallet', 'server');
    final dir = Directory(serverStorePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    Hive.init(serverStorePath);
    _log.info('Persistence Path: $serverStorePath');

    final dkgStore = DKGSessionStore();
    final policyStore = PolicyStore();
    final refreshStore = RefreshSessionStore();
    final signingStore = SigningSessionStore();
    final utxoStore = UtxoStore();

    await dkgStore.init();
    await policyStore.init();
    await refreshStore.init();
    await signingStore.init();
    await utxoStore.init();
    _log.info('Store initialized.');

    // Bitcoin Services Init
    final bitcoinService = BitcoinService(
      utxoStore,
      rpcUrl: config.bitcoinRpcUrl,
      rpcUser: config.bitcoinRpcUser,
      rpcPassword: config.bitcoinRpcPassword,
    );

    _log.info(
        "Connecting to Electrum at ${config.electrumUrl}:${config.electrumPort}");

    historyService = BitcoinHistoryService(
        electrumUrl: config.electrumUrl,
        electrumPort: config.electrumPort); // Electrum/History
    await historyService!.init();

    server = Server.create(
      services: [
        MPCWalletService(
            dkgStore: dkgStore,
            signingStore: signingStore,
            refreshStore: refreshStore,
            policyStore: policyStore,
            utxoStore: utxoStore,
            bitcoinService: bitcoinService,
            historyService: historyService!)
      ],
    );

    final ServerCredentials? serverCredentials = config.tlsEnabled
        ? ServerTlsCredentials(
            certificate: File(config.tlsCertPath!).readAsBytesSync(),
            privateKey: File(config.tlsKeyPath!).readAsBytesSync(),
          )
        : null;

    await server!.serve(port: config.port, security: serverCredentials);
    _log.info('Server listening on port ${server!.port}...');
  }, (error, stack) async {
    await shutdown(exitCode: 1, error: error, stack: stack);
  });
}

String randomBase64(int bytes) {
  final rand = Random.secure();
  final values = List<int>.generate(bytes, (_) => rand.nextInt(256));
  return base64UrlEncode(values);
}
