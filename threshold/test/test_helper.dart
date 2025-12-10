import 'package:threshold/threshold.dart';




List<Identifier> defaultIdentifiers(int maxSigners) {
  final out = <Identifier>[];
  for (var i = 1; i <= maxSigners; i++) {
    out.add(identifierFromUint16(i));
  }
  return out;
}
