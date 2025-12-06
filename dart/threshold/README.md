# threshold_core

A Dart library for implementing threshold cryptography, specifically focusing on Distributed Key Generation (DKG) protocols based on secp256k1 elliptic curves. This library is a port of the Go `threshold_core` package.

## Features

- **Distributed Key Generation (DKG):** Implements a robust DKG protocol allowing multiple participants to jointly generate a shared secret without any single party learning the full secret.
- **Verifiable Secret Sharing (VSS):** Utilizes Pedersen's VSS to ensure the integrity and correctness of shared secrets.
- **Secp256k1 Support:** Built upon the secp256k1 elliptic curve, commonly used in blockchain and cryptocurrency applications.
- **Key Reconstruction:** Provides functionality to reconstruct the combined secret from a threshold of individual key shares.
- **Key Refresh:** Supports refreshing existing key shares to enhance security without changing the master public key.

## Getting started

To use this package, add `threshold_core` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  threshold_core: ^1.0.0
```

Then, run `dart pub get` to fetch the package.

## Usage

The core functionality revolves around the DKG process. Here's a quick example of how to perform a DKG setup:

```dart
import 'package:threshold/threshold.dart';
import 'package:convert/convert.dart';

void main() {
  // --- DKG Setup ---
  const int minSigners = 2; // t (threshold)
  const int maxSigners = 3; // n (total participants)

  // Initialize participants
  final participants = <int, Participant>{};
  for (var i = 1; i <= maxSigners; i++) {
    final identifier = identifierFromUint16(i); 
    final secretKey = newSecretKey(); // a_i0 (random secret)
    final coefficients = generateCoefficients(minSigners - 1); // a_i1, ..., a_i(t-1)
    participants[i] = Participant(identifier, secretKey, coefficients);
  }

  // Run DKG (simplified for example)
  final (keyPackages, publicKeyPackage) = dealerDKG(minSigners, maxSigners, participants.values.toList());

  // Verify and reconstruct
  var expectedCombinedSecret = modNZero();
  for (final p in participants.values) {
    expectedCombinedSecret = (expectedCombinedSecret + p.secretKey.scalar) % secp256k1Curve.n;
  }

  final sharesForReconstruction = <Identifier, SecretShare>{};
  for (final kpEntry in keyPackages) {
    sharesForReconstruction[kpEntry.identifier] = kpEntry.secretShare;
  }

  final reconstructedCombinedSecret = reconstruct(minSigners, sharesForReconstruction);

  if (reconstructedCombinedSecret.scalar == expectedCombinedSecret) {
    print('DKG Successful: Reconstructed secret matches expected.');
  } else {
    print('DKG Failed: Reconstructed secret DOES NOT match expected.');
  }
  print('Group Public Key: ${hex.encode(elemSerializeCompressed(publicKeyPackage.verifyingKey.E))}');
}

// Helper class for Participant state (defined in example/dkg_example.dart)
class Participant {
  final Identifier identifier;
  final SecretKey secretKey;
  final List<BigInt> coefficients;

  Participant(this.identifier, this.secretKey, this.coefficients);
}
```

For a more comprehensive example, refer to `example/dkg_example.dart`.

## Additional information

This library is a direct port of the Go `github.com/BitspendPayment/MPCWallet/threshold_core` package. While efforts have been made to ensure functional parity, subtle differences in cryptographic library implementations (e.g., `pointycastle` in Dart versus `decred/dcrd/dcrec/secp256k1/v4` in Go) might lead to discrepancies when comparing outputs against Go-generated test vectors.

Contributions, bug reports, and feature requests are welcome! Please open an issue on the GitHub repository.
