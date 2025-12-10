class FrostException implements Exception {
  final String message;
  FrostException(this.message);
  @override
  String toString() => "FrostException: $message";
}

final errIdentityCommitment = FrostException("identity commitment");
final errUnknownIdentifier = FrostException("unknown identifier");
final errIncorrectNumberOfCommitments = FrostException(
  "incorrect number of commitments",
);
final errInvalidCommitment = FrostException("invalid commitment");
final errIncorrectBindingFactorPreimages = FrostException(
  "incorrect binding factor preimages",
);
final errorWrongSignature = FrostException("wrong signature");
final errorInvalidSignature = FrostException("invalid signature");
