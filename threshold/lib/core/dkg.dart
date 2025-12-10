import 'package:pointycastle/ecc/api.dart';
import 'package:threshold/core/commitment.dart';
import 'package:threshold/core/errors.dart';
import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/share.dart';
import 'package:threshold/core/utils.dart';
import 'package:convert/convert.dart';
import 'dart:typed_data';

class Round1Package {
  final VerifiableSecretSharingCommitment commitment;
  final Signature proofOfKnowledge;

  Round1Package(this.commitment, this.proofOfKnowledge);

  factory Round1Package.fromJson(Map<String, dynamic> json) {
    return Round1Package(
      VerifiableSecretSharingCommitment.fromJson(json['commitment']),
      Signature.fromJson(json['proofOfKnowledge']),
    );
  }

  Map<String, dynamic> toJson() => {
    'commitment': commitment.toJson(),
    'proofOfKnowledge': proofOfKnowledge.toJson(),
  };
}

class Signature {
  final ECPoint R;
  final BigInt Z;

  Signature(this.R, this.Z);

  factory Signature.fromJson(Map<String, dynamic> json) {
    final R = elemDeserializeCompressed(
      Uint8List.fromList(hex.decode(json['R'])),
    );
    final Z = bytesToBigInt(Uint8List.fromList(hex.decode(json['Z'])));
    return Signature(R, Z);
  }

  Map<String, dynamic> toJson() => {
    'R': hex.encode(elemSerializeCompressed(R)),
    'Z': hex.encode(bigIntToBytes(Z)),
  };
}

class Challenge {
  final BigInt C;
  Challenge(this.C);
}

class Round1SecretPackage {
  final Identifier identifier;
  final List<BigInt> coefficients;
  final VerifiableSecretSharingCommitment commitment;
  final int minSigners;
  final int maxSigners;

  Round1SecretPackage(
    this.identifier,
    this.coefficients,
    this.commitment,
    this.minSigners,
    this.maxSigners,
  );
}

class Round2Package {
  final SecretShare secretShare;

  Round2Package(this.secretShare);

  factory Round2Package.fromJson(Map<String, dynamic> json) {
    return Round2Package(
      bytesToBigInt(Uint8List.fromList(hex.decode(json['secretShare']))),
    );
  }

  Map<String, dynamic> toJson() => {
    'secretShare': hex.encode(bigIntToBytes(secretShare)),
  };
}

class Round2SecretPackage {
  final Identifier identifier;
  final VerifiableSecretSharingCommitment commitment;
  final BigInt secretShare;
  final int minSigners;
  final int maxSigners;

  Round2SecretPackage(
    this.identifier,
    this.commitment,
    this.secretShare,
    this.minSigners,
    this.maxSigners,
  );
}

class KeyPackage {
  final Identifier identifier;
  final SecretShare secretShare;
  final VerifyingShare verifyingShare;
  final VerifyingKey verifyingKey;
  final int minSigners;

  KeyPackage(
    this.identifier,
    this.secretShare,
    this.verifyingShare,
    this.verifyingKey,
    this.minSigners,
  );

  factory KeyPackage.fromJson(Map<String, dynamic> json) {
    return KeyPackage(
      Identifier.deserialize(
        Uint8List.fromList(hex.decode(json['identifier'])),
      ),
      bytesToBigInt(Uint8List.fromList(hex.decode(json['secretShare']))),
      elemDeserializeCompressed(
        Uint8List.fromList(hex.decode(json['verifyingShare'])),
      ),
      VerifyingKey(
        E: elemDeserializeCompressed(
          Uint8List.fromList(hex.decode(json['verifyingKey'])),
        ),
      ),
      json['minSigners'],
    );
  }

  Map<String, dynamic> toJson() => {
    'identifier': hex.encode(identifier.serialize()),
    'secretShare': hex.encode(bigIntToBytes(secretShare)),
    'verifyingShare': hex.encode(elemSerializeCompressed(verifyingShare)),
    'verifyingKey': hex.encode(elemSerializeCompressed(verifyingKey.E)),
    'minSigners': minSigners,
  };
}

class PublicKeyPackage {
  final Map<Identifier, VerifyingShare> verifyingShares;
  final VerifyingKey verifyingKey;

  PublicKeyPackage(this.verifyingShares, this.verifyingKey);

  factory PublicKeyPackage.fromJson(Map<String, dynamic> json) {
    final verifyingShares = (json['verifyingShares'] as Map<String, dynamic>)
        .map((key, value) {
          final id = Identifier.deserialize(
            Uint8List.fromList(hex.decode(key)),
          );
          final share = elemDeserializeCompressed(
            Uint8List.fromList(hex.decode(value)),
          );
          return MapEntry(id, share);
        });
    final verifyingKey = VerifyingKey(
      E: elemDeserializeCompressed(
        Uint8List.fromList(hex.decode(json['verifyingKey'])),
      ),
    );
    return PublicKeyPackage(verifyingShares, verifyingKey);
  }

  Map<String, dynamic> toJson() {
    final verifyingShares = this.verifyingShares.map(
      (key, value) => MapEntry(
        hex.encode(key.serialize()),
        hex.encode(elemSerializeCompressed(value)),
      ),
    );
    return {
      'verifyingShares': verifyingShares,
      'verifyingKey': hex.encode(elemSerializeCompressed(verifyingKey.E)),
    };
  }
}

class SecretKey {
  final BigInt scalar;
  SecretKey(this.scalar);
}

SecretShare secretShareFromCoefficients(List<BigInt> coeffs, Identifier peer) {
  return evaluatePolynomial(peer, coeffs);
}

(Round1SecretPackage, Round1Package) dkgPart1(
  Identifier identifier,
  int maxSigners,
  int minSigners,
  SecretKey secretKey,
  List<BigInt> coffiecients,
) {
  validateNumOfSigners(minSigners, maxSigners);

  final (coeffs, commitment) = generateSecretPolynomial(
    secretKey.scalar,
    maxSigners,
    minSigners,
    coffiecients,
  );

  final verifyingCommit = VerifiableSecretSharingCommitment(commitment);
  final verifyingKey = verifyingCommit.toVerifyingKey();

  final sig = computeProofOfKnowledge(identifier, coeffs, verifyingKey);

  final secretPkg = Round1SecretPackage(
    identifier,
    coeffs,
    VerifiableSecretSharingCommitment(commitment),
    minSigners,
    maxSigners,
  );
  final pubPkg = Round1Package(
    VerifiableSecretSharingCommitment(commitment),
    sig,
  );
  return (secretPkg, pubPkg);
}

(Round2SecretPackage, Map<Identifier, Round2Package>) dkgPart2(
  Round1SecretPackage secretPkg,
  Map<Identifier, Round1Package> round1Pkgs,
) {
  if (round1Pkgs.length != secretPkg.maxSigners - 1) {
    throw IncorrectNumberOfPackagesException("incorrect number of packages");
  }
  for (final p in round1Pkgs.values) {
    if (p.commitment.coeffs.length != secretPkg.minSigners) {
      throw IncorrectNumberOfCommitmentsException(
        "incorrect number of commitments",
      );
    }
  }

  final out = <Identifier, Round2Package>{};
  for (final entry in round1Pkgs.entries) {
    final senderID = entry.key;
    final pkg = entry.value;

    final verifyingKey = pkg.commitment.toVerifyingKey();
    verifyProofOfKnowledge(senderID, verifyingKey, pkg.proofOfKnowledge);

    final share = secretShareFromCoefficients(secretPkg.coefficients, senderID);
    out[senderID] = Round2Package(share);
  }

  final fii = evaluatePolynomial(secretPkg.identifier, secretPkg.coefficients);

  return (
    Round2SecretPackage(
      secretPkg.identifier,
      secretPkg.commitment,
      fii,
      secretPkg.minSigners,
      secretPkg.maxSigners,
    ),
    out,
  );
}

(KeyPackage, PublicKeyPackage) dkgPart3(
  Round1SecretPackage r1Secret,
  Round2SecretPackage r2Secret,
  Map<Identifier, Round1Package> round1Pkgs,
  Map<Identifier, Round2Package> round2Pkgs,
) {
  if (round1Pkgs.length != r2Secret.maxSigners - 1) {
    throw IncorrectNumberOfPackagesException("incorrect number of packages");
  }
  if (round1Pkgs.length != round2Pkgs.length) {
    throw IncorrectNumberOfPackagesException("incorrect number of packages");
  }
  for (final id in round1Pkgs.keys) {
    if (!round2Pkgs.containsKey(id)) {
      throw IncorrectPackageException("incorrect package mapping");
    }
  }

  var si = modNZero();

  for (final entry in round2Pkgs.entries) {
    final senderID = entry.key;
    final pkg2 = entry.value;

    final r1 = round1Pkgs[senderID]!;
    final temp = ThresholdShare(
      r2Secret.identifier,
      pkg2.secretShare,
      elemBaseMul(pkg2.secretShare),
      r1.commitment,
    );
    temp.verify();
    si = (si + pkg2.secretShare);
  }

  si = (si + r2Secret.secretShare);
  final secretShare = si;

  final verifyingShare = elemBaseMul(secretShare);

  final commitMap = <Identifier, VerifiableSecretSharingCommitment>{};
  for (final entry in round1Pkgs.entries) {
    commitMap[entry.key] = entry.value.commitment;
  }
  commitMap[r2Secret.identifier] = r2Secret.commitment;

  final publicKeyPackage = pkpFromDkgCommitments(commitMap);

  final keyPackage = KeyPackage(
    r2Secret.identifier,
    secretShare,
    verifyingShare,
    publicKeyPackage.verifyingKey,
    r2Secret.minSigners,
  );

  return (keyPackage, publicKeyPackage);
}

PublicKeyPackage pkpFromDkgCommitments(
  Map<Identifier, VerifiableSecretSharingCommitment> commits,
) {
  final ids = commits.keys.toList();
  final list = commits.values.toList();

  final group = sumCommitments(list);
  ids.sort((a, b) => a.s.compareTo(b.s));
  return pkpFromCommitment(ids, group);
}

PublicKeyPackage pkpFromCommitment(
  List<Identifier> ids,
  VerifiableSecretSharingCommitment commit,
) {
  final vmap = <Identifier, VerifyingShare>{};
  for (final id in ids) {
    vmap[id] = commit.getVerifyingShare(id);
  }
  final vk = commit.toVerifyingKey();
  return PublicKeyPackage(vmap, vk);
}

(Round1SecretPackage, Round1Package) dkgRefreshPart1(
  Identifier identifier,
  int maxSigners,
  int minSigners,
) {
  validateNumOfSigners(minSigners, maxSigners);

  final refreshingKey = modNZero();
  final coeffOnly = generateCoefficients(minSigners - 1);

  final (coeffs, commitment) = generateSecretPolynomial(
    refreshingKey,
    maxSigners,
    minSigners,
    coeffOnly,
  );

  if (commitment.isEmpty) {
    throw InvalidCommitVectorException("invalid commit vector");
  }
  final trimmed = commitment.sublist(1);
  final trimCommit = VerifiableSecretSharingCommitment(trimmed);

  final verifyingKey = trimCommit.toVerifyingKey();

  final sig = computeProofOfKnowledge(identifier, coeffs, verifyingKey);

  final sec = Round1SecretPackage(
    identifier,
    coeffs,
    trimCommit,
    minSigners,
    maxSigners,
  );
  final pub = Round1Package(trimCommit, sig);
  return (sec, pub);
}

(Round2SecretPackage, Map<Identifier, Round2Package>) dkgRefreshPart2(
  Round1SecretPackage secretPkg,
  Map<Identifier, Round1Package> round1Pkgs,
) {
  if (round1Pkgs.length != secretPkg.maxSigners - 1) {
    throw IncorrectNumberOfPackagesException("incorrect number of packages");
  }

  final elemIdentity = secp256k1Curve.curve.infinity!;
  final identity = elemIdentity;

  final myCoeffs = <ECPoint>[identity, ...secretPkg.commitment.coeffs];
  secretPkg = Round1SecretPackage(
    secretPkg.identifier,
    secretPkg.coefficients,
    VerifiableSecretSharingCommitment(myCoeffs),
    secretPkg.minSigners,
    secretPkg.maxSigners,
  );

  final out = <Identifier, Round2Package>{};

  for (final entry in round1Pkgs.entries) {
    final senderID = entry.key;
    final r1 = entry.value;

    final peerCoeffs = <ECPoint>[identity, ...r1.commitment.coeffs];

    if (peerCoeffs.length != secretPkg.minSigners) {
      throw IncorrectNumberOfCommitmentsException(
        "incorrect number of commitments",
      );
    }

    final share = secretShareFromCoefficients(secretPkg.coefficients, senderID);
    out[senderID] = Round2Package(share);
  }

  final fii = evaluatePolynomial(secretPkg.identifier, secretPkg.coefficients);

  return (
    Round2SecretPackage(
      secretPkg.identifier,
      secretPkg.commitment,
      fii,
      secretPkg.minSigners,
      secretPkg.maxSigners,
    ),
    out,
  );
}

(KeyPackage, PublicKeyPackage) dkgRefreshPart3(
  Round2SecretPackage r2Secret,
  Map<Identifier, Round1Package> round1Pkgs,
  Map<Identifier, Round2Package> round2Pkgs,
  PublicKeyPackage oldPKP,
  KeyPackage oldKP,
) {
  final newR1 = <Identifier, Round1Package>{};
  final elemIdentity = secp256k1Curve.curve.infinity!;
  final identity = elemIdentity;

  for (final entry in round1Pkgs.entries) {
    final senderID = entry.key;
    final r1 = entry.value;
    final coeffs = <ECPoint>[identity, ...r1.commitment.coeffs];
    newR1[senderID] = Round1Package(
      VerifiableSecretSharingCommitment(coeffs),
      r1.proofOfKnowledge,
    );
  }

  if (newR1.length != r2Secret.maxSigners - 1) {
    throw IncorrectNumberOfPackagesException("incorrect number of packages");
  }
  if (newR1.length != round2Pkgs.length) {
    throw IncorrectNumberOfPackagesException("incorrect number of packages");
  }
  for (final id in newR1.keys) {
    if (!round2Pkgs.containsKey(id)) {
      throw IncorrectPackageException("incorrect package mapping");
    }
  }

  var si = modNZero();

  for (final entry in round2Pkgs.entries) {
    final senderID = entry.key;
    final r2 = entry.value;

    final r1 = newR1[senderID]!;
    final temp = ThresholdShare(
      r2Secret.identifier,
      r2.secretShare,
      elemBaseMul(r2.secretShare),
      r1.commitment,
    );
    temp.verify();
    si = (si + r2.secretShare);
  }

  si = (si + r2Secret.secretShare);

  final oldShare = oldKP.secretShare;
  si = (si + oldShare);

  final newSecretShare = si;
  final newVerifying = elemBaseMul(newSecretShare);

  final commitMap = <Identifier, VerifiableSecretSharingCommitment>{};
  for (final entry in newR1.entries) {
    commitMap[entry.key] = entry.value.commitment;
  }
  commitMap[r2Secret.identifier] = r2Secret.commitment;

  final zeroPKP = pkpFromDkgCommitments(commitMap);

  final newVS = <Identifier, VerifyingShare>{};
  for (final entry in zeroPKP.verifyingShares.entries) {
    final id = entry.key;
    final vsNew = entry.value;
    final vsOld = oldPKP.verifyingShares[id];
    if (vsOld == null) {
      throw UnknownIdentifierException("unknown identifier");
    }
    final sum = elemAdd(vsNew, vsOld);
    newVS[id] = sum;
  }

  final pub = PublicKeyPackage(newVS, oldPKP.verifyingKey);

  final kp = KeyPackage(
    r2Secret.identifier,
    newSecretShare,
    newVerifying,
    pub.verifyingKey,
    r2Secret.minSigners,
  );

  return (kp, pub);
}
