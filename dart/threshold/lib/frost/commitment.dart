import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/ecc/api.dart';
import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/share.dart'; // for SecretShare
import 'package:threshold/core/utils.dart';
import 'package:threshold/frost/errors.dart';
import 'package:threshold/frost/hasher.dart';
import 'package:threshold/frost/utils.dart';
import 'package:threshold/frost/binding.dart';

class SigningNonce {
  final BigInt hiding;
  final BigInt binding;
  final SigningCommitments commitments;

  SigningNonce(this.hiding, this.binding, this.commitments);
}

class SigningCommitments {
  final ECPoint binding;
  final ECPoint hiding;

  SigningCommitments(this.binding, this.hiding);
}

class GroupCommitmentShare {
  final ECPoint elem;
  GroupCommitmentShare(this.elem);
}

class GroupCommitment {
  final ECPoint elem;
  GroupCommitment(this.elem);
}

// Generates a new nonce pair and returns the SigningNonce struct
SigningNonce newNonce(SecretShare secret) {
  final hiding = generateFrostNonce(secret);
  final binding = generateFrostNonce(secret);

  final hidingCommitment = (secp256k1Curve.G * hiding)!;
  final bindingCommitment = (secp256k1Curve.G * binding)!;

  final commitments = SigningCommitments(bindingCommitment, hidingCommitment);

  return SigningNonce(hiding, binding, commitments);
}

BigInt generateFrostNonce(SecretShare secret) {
  final rand = Random.secure();
  final rb = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    rb[i] = rand.nextInt(256);
  }

  // secret is BigInt (typedef SecretShare = BigInt)
  final secretBytes = bigIntToBytes(secret);
  final concatenatedBytes = Uint8List.fromList(rb + secretBytes);

  return h3(concatenatedBytes);
}

extension SigningCommitmentsExt on SigningCommitments {
  GroupCommitmentShare toGroupCommitmentShare(BigInt bindingScalar) {
    // sum = B_i + b_i * H_i (NOTE: Go code logic: sum = Hiding + bindingScalar * Binding)
    // Wait, looking at Go code:
    // secp256k1.ScalarMultNonConst(&bindingScalar, &s.Binding, &bH)
    // secp256k1.AddNonConst(&s.Hiding, &bH, &sum)
    // So it is Hiding + scalar * Binding

    final bH = (binding * bindingScalar)!;
    final sum = (hiding + bH)!;
    return GroupCommitmentShare(sum);
  }
}

class SigningPackage {
  final Map<Identifier, SigningCommitments> commitments;
  final Uint8List message;

  SigningPackage(this.commitments, this.message);

  SigningCommitments? signingCommitment(Identifier id) {
    return commitments[id];
  }
}

// computeGroupCommitment
GroupCommitment computeGroupCommitment(
  SigningPackage s,
  BindingFactorList bfl,
) {
  var groupCommitment = secp256k1Curve.curve.infinity!;

  final bindingScalars = <BigInt>[];
  final bindingElements = <ECPoint>[];

  for (final entry in s.commitments.entries) {
    final id = entry.key;
    final comm = entry.value;
    final bind = comm.binding;
    final hide = comm.hiding;

    if (bind.isInfinity || hide.isInfinity) {
      throw errIdentityCommitment;
    }

    // lookup binding factor
    final bf = bfl.get(id);
    if (bf == null) {
      throw errUnknownIdentifier;
    }

    bindingElements.add(bind);
    bindingScalars.add(bf.scalar);

    // sum hiding commitments
    groupCommitment = (groupCommitment + hide)!;
  }

  // accumulated binding
  final acc = vartimeMultiscalarMul(bindingScalars, bindingElements);
  groupCommitment = (groupCommitment + acc)!;

  return GroupCommitment(groupCommitment);
}
