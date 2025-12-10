import 'dart:typed_data';

import 'package:threshold/core/identifier.dart';
import 'package:threshold/core/share.dart'; // for VerifyingKey

import 'package:threshold/frost/commitment.dart';
import 'package:threshold/frost/utils.dart';
import 'package:threshold/frost/hasher.dart';

class BindingFactor {
  final BigInt scalar;
  BindingFactor(this.scalar);
}

class BindingFactorList {
  final Map<Identifier, BindingFactor> f;
  BindingFactorList(this.f);

  BindingFactor? get(Identifier id) => f[id];
}

class BindingFactorPreimage {
  final Identifier id;
  final Uint8List preimage;
  BindingFactorPreimage(this.id, this.preimage);
}

extension SigningPackageBinding on SigningPackage {
  Uint8List encodeGroupCommitmentList() {
    final builder = BytesBuilder();
    final ids = sortedCommitmentIDs(commitments.keys.toList());

    for (final id in ids) {
      final comm = commitments[id]!;
      builder.add(id.serialize()); // Check Identifier.serialize implementation
      builder.add(serializePointCompressed(comm.hiding));
      builder.add(serializePointCompressed(comm.binding));
    }
    return builder.toBytes();
  }

  List<BindingFactorPreimage> bindingFactorPreimages(VerifyingKey vk) {
    final builder = BytesBuilder();

    final vkBytes = serializePointCompressed(vk.E);
    builder.add(vkBytes);

    final H4msg = h4(message);
    builder.add(H4msg);

    final encGC = encodeGroupCommitmentList();
    final H5enc = h5(encGC);
    builder.add(H5enc);

    final prefix = builder.toBytes();
    final ids = sortedCommitmentIDs(commitments.keys.toList());

    final out = <BindingFactorPreimage>[];
    for (final id in ids) {
      final buf = BytesBuilder();
      buf.add(prefix);
      buf.add(id.serialize());
      out.add(BindingFactorPreimage(id, buf.toBytes()));
    }
    return out;
  }
}

BindingFactorList computeBindingFactorList(SigningPackage s, VerifyingKey vk) {
  final preimages = s.bindingFactorPreimages(vk);

  final out = <Identifier, BindingFactor>{};
  for (final p in preimages) {
    out[p.id] = BindingFactor(h1(p.preimage));
  }

  return BindingFactorList(out);
}
