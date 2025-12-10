import 'package:threshold/threshold.dart';
import 'package:convert/convert.dart';

void main() {
  // --- 1. Setup DKG Parameters ---
  const int minSigners = 2; // t
  const int maxSigners = 3; // n

  // --- 2. Initialize Participants ---
  // In a real scenario, these would be distinct entities.
  // For demonstration, we'll simulate them locally.

  final participants = <int, Participant>{};
  for (var i = 1; i <= maxSigners; i++) {
    final identifier = identifierFromUint16(i); // Unique ID for each participant
    final secretKey = newSecretKey(); // a_i0 (random secret for participant's polynomial)
    final coefficients = generateCoefficients(minSigners - 1); // a_i1, ..., a_i(t-1)
    participants[i] = Participant(identifier, secretKey, coefficients);
  }

  // --- 3. DKG Round 1: Generate Commitments and Proofs of Knowledge ---
  print('--- DKG Round 1 ---');
  final r1Secrets = <Identifier, Round1SecretPackage>{};
  final r1Pkgs = <Identifier, Round1Package>{};

  for (final entry in participants.entries) {
    final id = entry.key;
    final participant = entry.value;

    final (secretPkg, pubPkg) = dkgPart1(
      participant.identifier,
      maxSigners,
      minSigners,
      participant.secretKey,
      participant.coefficients,
    );
    r1Secrets[participant.identifier] = secretPkg;
    r1Pkgs[participant.identifier] = pubPkg;
    print('Participant $id: Generated R1 Package (Commitment & PoK)');
  }

  // --- 4. DKG Round 2: Generate Shares for Peers ---
  print('\n--- DKG Round 2 ---');
  final r2Secrets = <Identifier, Round2SecretPackage>{};
  final r2Outgoing = <Identifier, Map<Identifier, Round2Package>>{};

  for (final entry in participants.entries) {
    final id = entry.key;
    final r1Secret = r1Secrets[entry.value.identifier]!;

    // Collect all other participants' R1 packages
    final othersR1Pkgs = <Identifier, Round1Package>{};
    for (final otherEntry in participants.entries) {
      if (otherEntry.key != id) {
        othersR1Pkgs[otherEntry.value.identifier] = r1Pkgs[otherEntry.value.identifier]!;
      }
    }

    final (r2s, out) = dkgPart2(r1Secret, othersR1Pkgs);
    r2Secrets[entry.value.identifier] = r2s;
    r2Outgoing[entry.value.identifier] = out;
    print('Participant $id: Generated R2 Secret & Shares for Peers');
  }

  // --- 5. DKG Round 3: Combine Shares and Form Key Packages ---
  print('\n--- DKG Round 3 ---');
  final keyPackages = <Identifier, KeyPackage>{};
  PublicKeyPackage? publicKeyPackage; // The final combined public key package

  for (final entry in participants.entries) {
    final id = entry.key;
    final r1Secret = r1Secrets[entry.value.identifier]!;
    final r2Secret = r2Secrets[entry.value.identifier]!;

    // Collect R2 shares sent *to this participant* from others
    final inboundR2Pkgs = <Identifier, Round2Package>{};
    for (final otherEntry in participants.entries) {
      if (otherEntry.key != id) {
        inboundR2Pkgs[otherEntry.value.identifier] = r2Outgoing[otherEntry.value.identifier]![r1Secret.identifier]!;
      }
    }

    // All R1 packages (including own for verification purposes)
    final allR1Pkgs = <Identifier, Round1Package>{};
    for (final r1PkgEntry in r1Pkgs.entries) {
      allR1Pkgs[r1PkgEntry.key] = r1PkgEntry.value;
    }


    final (kp, pkp) = dkgPart3(
      r1Secret,
      r2Secret,
      allR1Pkgs, // All Round 1 packages are needed here
      inboundR2Pkgs,
    );
    keyPackages[kp.identifier] = kp;
    publicKeyPackage ??= pkp; // Store the first one, they should all be identical
    print('Participant $id: Formed Key Package');
  }

  // --- 6. Verification ---
  print('\n--- Verification ---');
  // The combined public key for the group
  final groupVerifyingKey = publicKeyPackage!.verifyingKey;
  print('Group Public Key: ${hex.encode(elemSerializeCompressed(groupVerifyingKey.E))}');

  // Sum of all individual a_i0 values (secretKey.scalar from setup)
  var expectedCombinedSecret = modNZero();
  for (final participant in participants.values) {
    expectedCombinedSecret = (expectedCombinedSecret + participant.secretKey.scalar) % secp256k1Curve.n;
  }
  print('Expected Combined Secret (sum of a_i0): ${expectedCombinedSecret.toRadixString(16)}');

  // Reconstruct the combined secret from the KeyPackages
  final sharesForReconstruction = <Identifier, SecretShare>{};
  for (final kpEntry in keyPackages.entries) {
    sharesForReconstruction[kpEntry.key] = kpEntry.value.secretShare;
  }

  final reconstructedCombinedSecret = reconstruct(minSigners, sharesForReconstruction);
  print('Reconstructed Combined Secret (f(0)): ${reconstructedCombinedSecret.scalar.toRadixString(16)}');

  if (reconstructedCombinedSecret.scalar == expectedCombinedSecret) {
    print('Verification SUCCESS: Reconstructed secret matches expected combined secret.');
  } else {
    print('Verification FAILED: Reconstructed secret DOES NOT match expected combined secret.');
  }
  print('Verifying that the sum of the a_i0 from the DKG is the first coefficient of the group commitment');
  final finalGroupCommitment = publicKeyPackage.verifyingKey;
  final expectedGroupCommitment = elemBaseMul(expectedCombinedSecret);
  if (finalGroupCommitment.E == expectedGroupCommitment) {
    print('Verification SUCCESS: Group commitment matches expected.');
  } else {
    print('Verification FAILED: Group commitment DOES NOT match expected.');
  }


}

// Helper class for Participant state in this example
class Participant {
  final Identifier identifier;
  final SecretKey secretKey;
  final List<BigInt> coefficients;

  Participant(this.identifier, this.secretKey, this.coefficients);
}
