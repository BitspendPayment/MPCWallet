import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:threshold/threshold.dart';
import 'package:test/test.dart';


import 'test_helper.dart';

class Participant {
  final Identifier identifier;
  final SecretKey secretKey;
  final List<BigInt> coefficients;

  Participant(this.identifier, this.secretKey, this.coefficients);
}

(List<KeyPackage>, PublicKeyPackage) dealerDKG(
    int min, int max, List<Participant> participants) {
  validateNumOfSigners(min, max);

  final ids = participants.map((p) => p.identifier).toList();
  if (ids.length != max) {
    throw IncorrectNumberOfIdsException("incorrect number of identifiers");
  }

  // Everyone runs part1
  final r1Secrets = <Identifier, Round1SecretPackage>{};
  final r1Pkgs = <Identifier, Round1Package>{};

  for (final participant in participants) {
    final (sec, pkg) = dkgPart1(participant.identifier, max, min,
        participant.secretKey, participant.coefficients);
    r1Secrets[participant.identifier] = sec;
    r1Pkgs[participant.identifier] = pkg;
  }

  // Everyone runs part2
  final r2Secrets = <Identifier, Round2SecretPackage>{};
  final r2Outgoing = <Identifier, Map<Identifier, Round2Package>>{};
  for (final id in ids) {
    final others = <Identifier, Round1Package>{};
    for (final j in ids) {
      if (j == id) {
        continue;
      }
      others[j] = r1Pkgs[j]!;
    }
    final (r2s, out) = dkgPart2(r1Secrets[id]!, others);
    r2Secrets[id] = r2s;
    r2Outgoing[id] = out;
  }

  // Deliver round2 messages and run part3
  final keys = <KeyPackage>[];
  PublicKeyPackage? pkp;

  for (final id in ids) {
    final r2View = <Identifier, Round2Package>{};
    final r1view = <Identifier, Round1Package>{};
    for (final j in ids) {
      if (j == id) {
        continue;
      }
      r2View[j] = r2Outgoing[j]![id]!;
      r1view[j] = r1Pkgs[j]!;
    }

    final pRound1Secret = r1Secrets[id]!;
    final pRound2Secret = r2Secrets[id]!;
    final (kp, pk) =
        dkgPart3(pRound1Secret, pRound2Secret, r1view, r2View);
    keys.add(kp);
    pkp ??= pk;
  }

  keys.sort((a, b) => a.identifier.s.compareTo(b.identifier.s));
  return (keys, pkp!);
}

void main() {
  group('DKG', () {
    test('TestDealerDkg', () {
      final minParticipants = 2;
      final maxParticipants = 3;

      final ids = defaultIdentifiers(maxParticipants);

      final participants = <Participant>[];
      for (var i = 0; i < maxParticipants; i++) {
        final secret = modNRandom();
        final coefficients = generateCoefficients(minParticipants - 1);

        participants.add(Participant(
          ids[i],
          SecretKey(secret),
          coefficients,
        ));
      }

      final (keypackage, _) =
          dealerDKG(minParticipants, maxParticipants, participants);

      final paticipantsShares = <Identifier, SecretShare>{};
      for (final p in keypackage) {
        paticipantsShares[p.identifier] = p.secretShare;
      }

      final reconstructedKey =
          reconstruct(minParticipants, paticipantsShares);

      var calculatedKeys = modNZero();
      for (final p in participants) {
        calculatedKeys = (calculatedKeys + p.secretKey.scalar) % secp256k1Curve.n;
      }

      expect(reconstructedKey.scalar, equals(calculatedKeys));
    });

    test('Test with vectors', () {
      final file = File('test/vectors_dkg.json');
      final jsonString = file.readAsStringSync();
      final jsonData = json.decode(jsonString);

      final config = jsonData['config'];
      final inputs = jsonData['inputs'];

      final minParticipants = config['MIN_PARTICIPANTS'];
      final maxParticipants = config['MAX_PARTICIPANTS'];

      final participants = <Participant>[];
      for (var i = 1; i <= maxParticipants; i++) {
        final p = inputs[i.toString()];
        participants.add(Participant(
          identifierFromUint16(p['identifier']),
          SecretKey(bytesToBigInt(Uint8List.fromList(hex.decode(p['secret_key'])))),
          [bytesToBigInt(Uint8List.fromList(hex.decode(p['coefficient'])))]
        ));
      }

      final (keypackage, pkp) = dealerDKG(minParticipants, maxParticipants, participants);
      
      final paticipantsShares = <Identifier, SecretShare>{};
      for (final p in keypackage) {
        paticipantsShares[p.identifier] = p.secretShare;
      }

       final reconstructedKey =
          reconstruct(minParticipants, paticipantsShares);

      var calculatedKeys = modNZero();
      for (final p in participants) {
        calculatedKeys = (calculatedKeys + p.secretKey.scalar) % secp256k1Curve.n;
      }
      expect(reconstructedKey.scalar, equals(calculatedKeys));

      final groupVerifyingKeyHex = hex.encode(elemSerializeCompressed(pkp.verifyingKey.E));
      expect(groupVerifyingKeyHex, equals(inputs['verifying_key']));

    });
  });
}
