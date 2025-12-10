import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:threshold/threshold.dart' as threshold;
import 'package:threshold/frost/signing.dart' as frost;
import 'package:threshold/frost/commitment.dart' as frost_comm;
import 'package:protocol/protocol.dart';

class MpcClient {
  final MPCWalletClient _stub;

  // Unique Session ID for this client instance (persisted or generated)
  String _deviceId;
  String get deviceId => _deviceId;

  // Two client identities
  final threshold.Identifier _id1;
  final threshold.Identifier _id2;

  final int _maxSigners;
  final int _minSigners;

  // State for Identity 1
  threshold.SecretKey? _secret1;
  threshold.Round1SecretPackage? _r1Secret1;
  threshold.Round1Package? _r1Public1;
  threshold.Round2SecretPackage? _r2Secret1;
  threshold.KeyPackage? _keyPackage1;
  threshold.PublicKeyPackage? _publicKeyPackage1;

  // State for Identity 2
  threshold.SecretKey? _secret2;
  threshold.Round1SecretPackage? _r1Secret2;
  threshold.Round1Package? _r1Public2;
  threshold.Round2SecretPackage? _r2Secret2;
  threshold.KeyPackage? _keyPackage2;
  threshold.PublicKeyPackage? _publicKeyPackage2;

  // Bitcoin Wallet removed (Decoupled)

  /// Creates a client that manages two shares (identities).
  /// [id1] and [id2] are the identifiers for this client's two shares.
  /// [deviceId] identifies this DKG session. If null, a random one is generated.
  MpcClient(ClientChannel channel, this._id1, this._id2,
      {int maxSigners = 3, int minSigners = 2, String? deviceId})
      : _stub = MPCWalletClient(channel),
        _deviceId = deviceId ?? _generateDeviceId(),
        _maxSigners = maxSigners,
        _minSigners = minSigners;

  static String _generateDeviceId() {
    final r = Random();
    return List.generate(
        16, (index) => r.nextInt(255).toRadixString(16).padLeft(2, '0')).join();
  }

  bool get isInitialized => _keyPackage1 != null && _keyPackage2 != null;

  void restoreState(String deviceId, threshold.KeyPackage k1,
      threshold.KeyPackage k2, threshold.PublicKeyPackage pk) {
    _deviceId = deviceId;
    _keyPackage1 = k1;
    _keyPackage2 = k2;
    _publicKeyPackage1 = pk;
    _publicKeyPackage2 = pk;
  }

  // Getters for testing
  threshold.KeyPackage? get keyPackage1 => _keyPackage1;
  threshold.KeyPackage? get keyPackage2 => _keyPackage2;
  threshold.PublicKeyPackage? get publicKey => _publicKeyPackage1;

  // --- DKG ---

  Future<void> doDkg() async {
    // 1. Generate Secrets for both identities
    _secret1 = threshold.SecretKey(threshold.modNRandom());
    final coeffs1 = threshold.generateCoefficients(_minSigners - 1);
    final (r1Sec1, r1Pub1) =
        threshold.dkgPart1(_id1, _maxSigners, _minSigners, _secret1!, coeffs1);
    _r1Secret1 = r1Sec1;
    _r1Public1 = r1Pub1;

    _secret2 = threshold.SecretKey(threshold.modNRandom());
    final coeffs2 = threshold.generateCoefficients(_minSigners - 1);
    final (r1Sec2, r1Pub2) =
        threshold.dkgPart1(_id2, _maxSigners, _minSigners, _secret2!, coeffs2);
    _r1Secret2 = r1Sec2;
    _r1Public2 = r1Pub2;

    // 2. Step 1: Exchange Round 1 Packages for both
    final req1 = DKGStep1Request()
      ..deviceId = _deviceId
      ..identifier = threshold.bigIntToBytes(_id1.toScalar())
      ..round1Package = jsonEncode(_r1Public1!.toJson());

    final req2 = DKGStep1Request()
      ..deviceId = _deviceId
      ..identifier = threshold.bigIntToBytes(_id2.toScalar())
      ..round1Package = jsonEncode(_r1Public2!.toJson());

    final step1Futures =
        await Future.wait([_stub.dKGStep1(req1), _stub.dKGStep1(req2)]);

    final step1Resp = step1Futures[0];

    // 3. Step 2: Compute Shares
    // Trigger Step 2 on server for this session
    await _stub.dKGStep2(DKGStep2Request()
      ..deviceId = _deviceId
      ..identifier = threshold.bigIntToBytes(_id1.toScalar()));

    // Parse R1 packages for Identity 1
    final round1PkgsMap1 = <threshold.Identifier, threshold.Round1Package>{};
    // Parse R1 packages for Identity 2
    final round1PkgsMap2 = <threshold.Identifier, threshold.Round1Package>{};

    step1Resp.round1Packages.forEach((k, v) {
      final id = threshold.Identifier(BigInt.parse(k, radix: 16));
      final pkg = threshold.Round1Package.fromJson(jsonDecode(v));

      if (id != _id1) round1PkgsMap1[id] = pkg;
      if (id != _id2) round1PkgsMap2[id] = pkg;
    });

    // Compute shares
    final (r2Sec1, sharesFrom1) =
        threshold.dkgPart2(_r1Secret1!, round1PkgsMap1);
    _r2Secret1 = r2Sec1;

    final (r2Sec2, sharesFrom2) =
        threshold.dkgPart2(_r1Secret2!, round1PkgsMap2);
    _r2Secret2 = r2Sec2;

    // 4. Step 3: Exchange Shares
    final req3_1 = DKGStep3Request()
      ..deviceId = _deviceId
      ..identifier = threshold.bigIntToBytes(_id1.toScalar())
      ..round2PackagesForOthers.addAll(_buildSharesMap(sharesFrom1));

    final req3_2 = DKGStep3Request()
      ..deviceId = _deviceId
      ..identifier = threshold.bigIntToBytes(_id2.toScalar())
      ..round2PackagesForOthers.addAll(_buildSharesMap(sharesFrom2));

    final step3Futures =
        await Future.wait([_stub.dKGStep3(req3_1), _stub.dKGStep3(req3_2)]);

    final sharesForMe1 = _parseShares(step3Futures[0].round2PackagesForMe);
    final sharesForMe2 = _parseShares(step3Futures[1].round2PackagesForMe);

    // 5. Finalize for both
    final (keyPkg1, pubKeyPkg1) = threshold.dkgPart3(
        _r1Secret1!, _r2Secret1!, round1PkgsMap1, sharesForMe1);
    _keyPackage1 = keyPkg1;
    _publicKeyPackage1 = pubKeyPkg1;

    final (keyPkg2, pubKeyPkg2) = threshold.dkgPart3(
        _r1Secret2!, _r2Secret2!, round1PkgsMap2, sharesForMe2);
    _keyPackage2 = keyPkg2;
    _publicKeyPackage2 = pubKeyPkg2;
  }

  // --- SIGNING ---

  Future<threshold.Signature> sign(Uint8List message,
      {bool useIdentity2 = true}) async {
    final myId = useIdentity2 ? _id2 : _id1;
    final myKeyPkg = useIdentity2 ? _keyPackage2 : _keyPackage1;
    final groupPubKey = _publicKeyPackage1;

    if (myKeyPkg == null || groupPubKey == null) {
      throw StateError("DKG not completed.");
    }

    // 1. Generate Nonce
    final nonce = frost_comm.newNonce(myKeyPkg.secretShare);

    // 2. Step 1: Commitments
    final signStep1Resp = await _stub.signStep1(SignStep1Request()
      ..deviceId = _deviceId
      ..identifier = threshold.bigIntToBytes(myId.toScalar())
      ..hidingCommitment =
          threshold.elemSerializeCompressed(nonce.commitments.hiding)
      ..bindingCommitment =
          threshold.elemSerializeCompressed(nonce.commitments.binding)
      ..messageToSign = message);

    // Parse Commitments
    final commitmentsMap =
        <threshold.Identifier, frost_comm.SigningCommitments>{};
    signStep1Resp.commitments.forEach((k, v) {
      final id = threshold.Identifier(BigInt.parse(k, radix: 16));
      final hiding =
          threshold.elemDeserializeCompressed(Uint8List.fromList(v.hiding));
      final binding =
          threshold.elemDeserializeCompressed(Uint8List.fromList(v.binding));
      commitmentsMap[id] = frost_comm.SigningCommitments(binding, hiding);
    });

    // 3. Step 2: Sign
    final signingPkg = frost_comm.SigningPackage(commitmentsMap, message);
    final sigShare = frost.sign(signingPkg, nonce, myKeyPkg);

    // 4. Send Share & Get Result
    final signStep2Resp = await _stub.signStep2(SignStep2Request()
      ..deviceId = _deviceId
      ..identifier = threshold.bigIntToBytes(myId.toScalar())
      ..signatureShare = threshold.bigIntToBytes(sigShare.s));

    // 5. Verify
    final R = threshold
        .elemDeserializeCompressed(Uint8List.fromList(signStep2Resp.rPoint));
    final z =
        threshold.bytesToBigInt(Uint8List.fromList(signStep2Resp.zScalar));

    final challenge =
        frost.computeChallenge(R, groupPubKey.verifyingKey, message);
    final zG = (threshold.secp256k1Curve.G * z)!;
    final cY = (groupPubKey.verifyingKey.E * challenge)!;
    final R_plus_cY = (R + cY)!;

    final isValid = threshold.pointsEqual(zG, R_plus_cY);
    if (!isValid) throw Exception("Invalid signature produced by MPC group");

    return threshold.Signature(R, z);
  }

  // Helpers
  Map<String, String> _buildSharesMap(
      Map<threshold.Identifier, threshold.Round2Package> shares) {
    final m = <String, String>{};
    shares.forEach((id, pkg) {
      m[threshold
          .bigIntToBytes(id.toScalar())
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()] = jsonEncode(pkg.toJson());
    });
    return m;
  }

  Map<threshold.Identifier, threshold.Round2Package> _parseShares(
      Map<String, String> raw) {
    final m = <threshold.Identifier, threshold.Round2Package>{};
    raw.forEach((k, v) {
      m[threshold.Identifier(BigInt.parse(k, radix: 16))] =
          threshold.Round2Package.fromJson(jsonDecode(v));
    });
    return m;
  }
}
