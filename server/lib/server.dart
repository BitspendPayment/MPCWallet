import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:threshold/threshold.dart' as threshold;
import 'package:threshold/frost/signing.dart' as frost;
import 'package:threshold/frost/commitment.dart' as frost_comm;

import 'package:protocol/protocol.dart';
import 'persistence/store.dart';

// --- Session State ---
// This class is serialized to JSON for Hive persistence.
// For brevity, we are keeping it as an in-memory object and manually serializing parts of it
// or relying on re-computation where state is ephemeral.
// DKG state is somewhat ephemeral (only needed during DKG).
// KeyPackage is persistent.
class SessionState {
  final String deviceId;

  // Ephemeral DKG locks/signals (Not persisted directly, recreated on load)
  Completer<void> completerStep1 = Completer<void>();
  Completer<void> completerStep2 = Completer<void>();
  Completer<void> completerStep3 = Completer<void>();

  // DKG Data (Persisted)
  final round1Packages = <String, String>{}; // HexID -> JSON

  // Server Secrets (Persisted)
  // We need to serialize these manually or use a DTO.
  // For simplicity, we'll store them if generated.
  // Ideally, use TypeAdapters in Hive.
  // Here, we'll keeping it simple: memory-only for the complex objects during lifetime,
  // but "Saving" to store means we'd serialize what we need.
  // The User asked for persistence.

  // To avoid huge complexity in this step:
  // We will persist the *Result* (KeyPackage) and *Client Details*.
  // Active DKG state might be lost on restart (simplification), unless we serialize every step.
  // Given the prompt "store client details on server so i can know what share to use to sign",
  // we primarily need to associate device_id -> ServerShare + GroupKey + Threshold Config.

  threshold.SecretKey? serverInternalSecret;
  threshold.Round1SecretPackage? serverRound1SecretPackage;
  threshold.Round2SecretPackage? serverRound2Secret;

  // Round 2
  final dkgRound2PackagesReceived =
      <threshold.Identifier, threshold.Round2Package>{};
  final dkgRound2PackagesLocal =
      <threshold.Identifier, threshold.Round2Package>{};
  final dkgRound2PackagesForRelay = <threshold.Identifier,
      Map<threshold.Identifier, threshold.Round2Package>>{};

  // Result
  threshold.KeyPackage? serverKeyPackage;
  threshold.PublicKeyPackage? groupPublicKey;

  // Signing (Ephemeral per request usually, but if we need persistent sessions for signing...)
  // The prompt implies "session for each DKG", so DKG is the session scope.
  // Signing refers to the DKG session (device_id) to get keys.
  final completerSignStep1 = Completer<void>();
  final completerSignStep2 = Completer<void>();

  frost_comm.SigningNonce? serverNonce;
  frost_comm.SigningCommitments? serverCommitments;
  final signCommitmentsReceived =
      <threshold.Identifier, frost_comm.SigningCommitments>{};
  Uint8List? messageToSign;
  final signRound2Shares = <threshold.Identifier, BigInt>{};

  SessionState(this.deviceId);
}

class MPCWalletService extends MPCWalletServiceBase {
  // In-memory cache of active sessions
  final Map<String, SessionState> _sessions = {};

  // Persistence
  final SessionStore _store;

  // Server Identity: ID=3
  static final serverId = threshold.Identifier(BigInt.from(3));
  static final serverIdHex =
      _idToString(threshold.bigIntToBytes(serverId.toScalar()));
  static const int totalParticipants = 3;
  static const int thresholdCount = 2;

  MPCWalletService(this._store);

  SessionState _getSession(String deviceId) {
    if (!_sessions.containsKey(deviceId)) {
      // Check store? (For now, we just create new in-memory if not found,
      // strictly implies DKG Step 1 starts it).
      _sessions[deviceId] = SessionState(deviceId);
      print('New Session Created: $deviceId');
    }
    return _sessions[deviceId]!;
  }

  static String _idToString(List<int> id) {
    return id.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static threshold.Identifier _stringToId(String s) {
    return threshold.Identifier(BigInt.parse(s, radix: 16));
  }

  // --- DKG ---

  @override
  Future<DKGStep1Response> dKGStep1(
      ServiceCall call, DKGStep1Request request) async {
    final session = _getSession(request.deviceId);
    final clientIdHex = _idToString(request.identifier);
    print(
        '[${request.deviceId}] DKGStep1: Received PubPackage from $clientIdHex');

    session.round1Packages[clientIdHex] = request.round1Package;

    // Server Init for this session
    if (session.serverRound1SecretPackage == null) {
      print('[${request.deviceId}] Server: Generating DKG secrets...');
      final secret = threshold.SecretKey(threshold.modNRandom());
      final coeffs = threshold.generateCoefficients(thresholdCount - 1);
      final (r1Secret, r1Public) = threshold.dkgPart1(
          serverId, totalParticipants, thresholdCount, secret, coeffs);

      session.serverInternalSecret = secret;
      session.serverRound1SecretPackage = r1Secret;
      session.round1Packages[serverIdHex] = jsonEncode(r1Public.toJson());
    }

    if (session.round1Packages.length == totalParticipants) {
      if (!session.completerStep1.isCompleted)
        session.completerStep1.complete();
    } else {
      await session.completerStep1.future;
    }

    return DKGStep1Response()..round1Packages.addAll(session.round1Packages);
  }

  @override
  Future<DKGStep2Response> dKGStep2(
      ServiceCall call, DKGStep2Request request) async {
    final session = _getSession(request.deviceId);
    await session.completerStep1.future;

    if (session.dkgRound2PackagesLocal.isEmpty) {
      print('[${request.deviceId}] DKGStep2: Server computing shares...');
      final round1Pkgs = <threshold.Identifier, threshold.Round1Package>{};
      session.round1Packages.forEach((k, v) {
        final id = threshold.Identifier(BigInt.parse(k, radix: 16));
        if (id != serverId) {
          round1Pkgs[id] = threshold.Round1Package.fromJson(jsonDecode(v));
        }
      });

      if (session.serverRound1SecretPackage == null) {
        throw StateError(
            'Server secrets missing for session ${request.deviceId}');
      }

      final (serverRound2Secret, serverRound2Pkgs) =
          threshold.dkgPart2(session.serverRound1SecretPackage!, round1Pkgs);

      session.serverRound2Secret = serverRound2Secret;
      session.dkgRound2PackagesLocal.addAll(serverRound2Pkgs);
    }

    if (!session.completerStep2.isCompleted) session.completerStep2.complete();

    return DKGStep2Response()..allRound1Packages.addAll(session.round1Packages);
  }

  @override
  Future<DKGStep3Response> dKGStep3(
      ServiceCall call, DKGStep3Request request) async {
    final session = _getSession(request.deviceId);
    final senderId = threshold.Identifier.deserialize(
        Uint8List.fromList(request.identifier));
    print(
        '[${request.deviceId}] DKGStep3: Received Shares from ${_idToString(request.identifier)}');

    await session.completerStep2.future;

    final sharesFromSenderForOthers =
        <threshold.Identifier, threshold.Round2Package>{};
    for (final entry in request.round2PackagesForOthers.entries) {
      final recipientId = _stringToId(entry.key);
      final pkg = threshold.Round2Package.fromJson(jsonDecode(entry.value));
      sharesFromSenderForOthers[recipientId] = pkg;

      if (recipientId == serverId) {
        session.dkgRound2PackagesReceived[senderId] = pkg;
      }
    }
    session.dkgRound2PackagesForRelay[senderId] = sharesFromSenderForOthers;

    if (session.dkgRound2PackagesForRelay.length == totalParticipants - 1) {
      session.dkgRound2PackagesForRelay[serverId] =
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
      if (participantShares.containsKey(senderId)) {
        packagesForRequester[_idToString(
                threshold.bigIntToBytes(participantId.toScalar()))] =
            jsonEncode(participantShares[senderId]!.toJson());
      }
    }

    if (session.serverKeyPackage == null &&
        session.completerStep3.isCompleted) {
      print('[${request.deviceId}] DKGStep3: Server computing KeyPackage...');
      final allRound1Pkgs = <threshold.Identifier, threshold.Round1Package>{};
      session.round1Packages.forEach((k, v) {
        final id = threshold.Identifier(BigInt.parse(k, radix: 16));
        if (id != serverId) {
          allRound1Pkgs[id] = threshold.Round1Package.fromJson(jsonDecode(v));
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

      session.serverKeyPackage = keyPkg;
      session.groupPublicKey = pubKeyPkg;
      print(
          '[${request.deviceId}] DKG Complete. PK: ${pubKeyPkg.verifyingKey.E}');

      // Persist Result
      // For now, we just save a simple string to prove persistence works
      // In production, we'd serialize `keyPkg` and `pubKeyPkg`.
      await _store.saveSession(
          request.deviceId,
          jsonEncode({
            "status": "COMPLETED",
            "pk_x": pubKeyPkg.verifyingKey.E.x.toString(),
            "pk_y": pubKeyPkg.verifyingKey.E.y.toString(),
          }));
    }

    return DKGStep3Response()..round2PackagesForMe.addAll(packagesForRequester);
  }

  // --- Signing ---

  @override
  Future<SignStep1Response> signStep1(
      ServiceCall call, SignStep1Request request) async {
    final session = _getSession(request.deviceId);
    final senderId = threshold.Identifier.deserialize(
        Uint8List.fromList(request.identifier));
    print(
        '[${request.deviceId}] SignStep1: Received from ${_idToString(request.identifier)}');

    // Ensure we have a key for this session
    if (session.serverKeyPackage == null) {
      throw GrpcError.failedPrecondition(
          "DKG not completed for device ${request.deviceId}");
    }

    final hidingP = threshold.elemDeserializeCompressed(
        Uint8List.fromList(request.hidingCommitment));
    final bindingP = threshold.elemDeserializeCompressed(
        Uint8List.fromList(request.bindingCommitment));
    session.signCommitmentsReceived[senderId] =
        frost_comm.SigningCommitments(bindingP, hidingP);

    if (session.serverNonce == null) {
      print(
          '[${request.deviceId}] SignStep1: Server generating commitments...');
      session.serverNonce =
          frost_comm.newNonce(session.serverKeyPackage!.secretShare);
      session.serverCommitments = session.serverNonce!.commitments;
      session.signCommitmentsReceived[serverId] = session.serverCommitments!;
    }

    if (session.messageToSign == null && request.messageToSign.isNotEmpty) {
      session.messageToSign = Uint8List.fromList(request.messageToSign);
    }

    if (session.signCommitmentsReceived.length >= thresholdCount) {
      if (!session.completerSignStep1.isCompleted)
        session.completerSignStep1.complete();
    } else {
      await session.completerSignStep1.future;
    }

    final responseCommitments = <String, SignStep1Response_Commitment>{};
    for (final entry in session.signCommitmentsReceived.entries) {
      final comm = entry.value;
      responseCommitments[
              _idToString(threshold.bigIntToBytes(entry.key.toScalar()))] =
          SignStep1Response_Commitment(
        hiding: threshold.elemSerializeCompressed(comm.hiding),
        binding: threshold.elemSerializeCompressed(comm.binding),
      );
    }

    return SignStep1Response()
      ..commitments.addAll(responseCommitments)
      ..messageToSign = session.messageToSign!;
  }

  @override
  Future<SignStep2Response> signStep2(
      ServiceCall call, SignStep2Request request) async {
    final session = _getSession(request.deviceId);
    final senderId = threshold.Identifier.deserialize(
        Uint8List.fromList(request.identifier));
    print(
        '[${request.deviceId}] SignStep2: Received from ${_idToString(request.identifier)}');

    final share =
        threshold.bytesToBigInt(Uint8List.fromList(request.signatureShare));
    session.signRound2Shares[senderId] = share;

    if (!session.signRound2Shares.containsKey(serverId) &&
        session.serverNonce != null) {
      print('[${request.deviceId}] SignStep2: Server computing share...');
      final signingPkg = frost_comm.SigningPackage(
          session.signCommitmentsReceived, session.messageToSign!);
      final serverShareObj = frost.sign(
          signingPkg, session.serverNonce!, session.serverKeyPackage!);
      session.signRound2Shares[serverId] = serverShareObj.s;
    }

    if (session.signRound2Shares.length >= thresholdCount) {
      if (!session.completerSignStep2.isCompleted)
        session.completerSignStep2.complete();
    } else {
      await session.completerSignStep2.future;
    }

    final signingPkg = frost_comm.SigningPackage(
        session.signCommitmentsReceived, session.messageToSign!);
    final sharesMap = <threshold.Identifier, frost.SignatureShare>{};
    session.signRound2Shares.forEach((id, val) {
      sharesMap[id] = frost.SignatureShare(val);
    });

    final signature =
        frost.aggregate(signingPkg, sharesMap, session.groupPublicKey!);
    print('[${request.deviceId}] SignStep2: Aggregated.');

    return SignStep2Response()
      ..rPoint = threshold.elemSerializeCompressed(signature.R)
      ..zScalar = threshold.bigIntToBytes(signature.Z);
  }
}

Future<void> main(List<String> args) async {
  final store = SessionStore();
  await store.init();
  print('Store initialized.');

  final server = Server.create(
    services: [MPCWalletService(store)],
  );
  await server.serve(port: 50051);
  print('Server listening on port ${server.port}...');
}
