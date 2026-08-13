import 'package:app_core/threshold/threshold.dart' as threshold;

class SpendingPolicy {
  final String id;

  final threshold.KeyPackage keyPackage;
  final threshold.PublicKeyPackage publicKeyPackage;

  SpendingPolicy({
    required this.id,
    required this.keyPackage,
    required this.publicKeyPackage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyPackage': keyPackage.toJson(),
      'publicKeyPackage': publicKeyPackage.toJson(),
    };
  }

  static SpendingPolicy fromJson(Map<String, dynamic> json) {
    final keyPackageJson =
        Map<String, dynamic>.from(json['keyPackage'] as Map);
    final publicKeyPackageJson =
        Map<String, dynamic>.from(json['publicKeyPackage'] as Map);
    return SpendingPolicy(
      id: json['id'],
      keyPackage: threshold.KeyPackage.fromJson(keyPackageJson),
      publicKeyPackage: threshold.PublicKeyPackage.fromJson(
          publicKeyPackageJson),
    );
  }
}
