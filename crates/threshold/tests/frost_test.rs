extern crate alloc;

use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use k256::Scalar;
use rand::rngs::OsRng;
use threshold::commitment::SigningPackage;
use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage, VerifyingKey};
use threshold::lagrange::lagrange_coeff_at_zero;
use threshold::nonce::new_nonce;
use threshold::point;
use threshold::scalar::{scalar_from_bytes, scalar_to_bytes};
use threshold::signing::{aggregate, sign};
use threshold::vss::VssCommitment;

// --- Dealer DKG simulation (test-only) ---

/// Evaluate a polynomial at a given identifier using Horner's method.
/// coeffs = [a0, a1, ..., a_{t-1}] where a0 is the constant term.
fn evaluate_polynomial(id: &Identifier, coeffs: &[Scalar]) -> Scalar {
    let x = *id.to_scalar();
    let mut val = Scalar::ZERO;
    for i in (0..coeffs.len()).rev() {
        if i != coeffs.len() - 1 {
            val = val * x;
        }
        val = val + coeffs[i];
    }
    val
}

/// Simulate a dealer DKG for testing: generates key packages for `max_signers`
/// participants with a `min_signers` threshold.
fn run_dealer_dkg(
    min_signers: usize,
    max_signers: usize,
) -> (Vec<KeyPackage>, PublicKeyPackage) {
    let mut rng = OsRng;

    // Each participant generates a random polynomial of degree (min_signers - 1)
    let ids: Vec<Identifier> = (1..=max_signers as u16)
        .map(|i| Identifier::from_u16(i).unwrap())
        .collect();

    let mut all_coefficients: Vec<Vec<Scalar>> = Vec::new();

    for _ in 0..max_signers {
        let mut coeffs = Vec::with_capacity(min_signers);
        for _ in 0..min_signers {
            // Generate random non-zero scalar
            let s = loop {
                let nonce = new_nonce(&mut rng, &Scalar::ONE);
                let s = nonce.hiding; // Use nonce scalar as random
                if !bool::from(s.is_zero()) {
                    break s;
                }
            };
            coeffs.push(s);
        }
        all_coefficients.push(coeffs);
    }

    // Compute combined secret shares for each participant:
    // s_i = sum_j f_j(i) for all j
    let mut key_packages = Vec::new();
    let mut verifying_shares = BTreeMap::new();

    // Group public key = sum of all a0 values
    let mut group_secret = Scalar::ZERO;
    for coeffs in &all_coefficients {
        group_secret = group_secret + coeffs[0];
    }
    let group_pk = point::base_mul(&group_secret);
    let verifying_key = VerifyingKey::new(group_pk);

    for id in ids.iter() {
        let mut secret_share = Scalar::ZERO;
        for coeffs in &all_coefficients {
            secret_share = secret_share + evaluate_polynomial(id, coeffs);
        }

        let verifying_share = point::base_mul(&secret_share);
        verifying_shares.insert(id.clone(), verifying_share);

        key_packages.push(KeyPackage {
            identifier: id.clone(),
            secret_share,
            verifying_share,
            verifying_key: verifying_key.clone(),
            min_signers,
        });
    }

    let pubkeys = PublicKeyPackage {
        verifying_shares,
        verifying_key,
    };

    (key_packages, pubkeys)
}

// --- Tests ---

#[test]
fn test_scalar_round_trip() {
    let mut rng = OsRng;
    let nonce = new_nonce(&mut rng, &Scalar::ONE);
    let s = nonce.hiding;

    let bytes = scalar_to_bytes(&s);
    let recovered = scalar_from_bytes(&bytes).unwrap();
    assert_eq!(scalar_to_bytes(&s), scalar_to_bytes(&recovered));
}

#[test]
fn test_point_round_trip() {
    let mut rng = OsRng;
    let nonce = new_nonce(&mut rng, &Scalar::ONE);
    let p = point::base_mul(&nonce.hiding);

    let compressed = point::serialize_compressed(&p);
    let recovered = point::deserialize_compressed(&compressed).unwrap();
    assert!(point::points_equal(&p, &recovered));
}

#[test]
fn test_identifier_ordering() {
    let id1 = Identifier::from_u16(1).unwrap();
    let id2 = Identifier::from_u16(2).unwrap();
    let id3 = Identifier::from_u16(3).unwrap();

    assert!(id1 < id2);
    assert!(id2 < id3);
    assert!(id1 != id2);
}

#[test]
fn test_identifier_derive() {
    let id = Identifier::derive(b"test-participant").unwrap();
    let bytes = id.serialize();
    let recovered = Identifier::deserialize(&bytes).unwrap();
    assert_eq!(id, recovered);
}

#[test]
fn test_lagrange_reconstruction() {
    // Create a polynomial f(x) = a0 + a1*x with known constant term
    let a0 = Scalar::from(42u64);
    let a1 = Scalar::from(7u64);

    let id1 = Identifier::from_u16(1).unwrap();
    let id2 = Identifier::from_u16(2).unwrap();
    let id3 = Identifier::from_u16(3).unwrap();

    let coeffs = vec![a0, a1];

    // Evaluate at each point
    let y1 = evaluate_polynomial(&id1, &coeffs); // f(1) = 42 + 7 = 49
    let y2 = evaluate_polynomial(&id2, &coeffs); // f(2) = 42 + 14 = 56
    let y3 = evaluate_polynomial(&id3, &coeffs); // f(3) = 42 + 21 = 63

    // Reconstruct f(0) = a0 using Lagrange on any 2 points
    let set12 = vec![id1.clone(), id2.clone()];
    let l1 = lagrange_coeff_at_zero(&id1, &set12);
    let l2 = lagrange_coeff_at_zero(&id2, &set12);
    let reconstructed_12 = l1 * y1 + l2 * y2;
    assert_eq!(scalar_to_bytes(&reconstructed_12), scalar_to_bytes(&a0));

    // Also with a different pair
    let set23 = vec![id2.clone(), id3.clone()];
    let l2b = lagrange_coeff_at_zero(&id2, &set23);
    let l3b = lagrange_coeff_at_zero(&id3, &set23);
    let reconstructed_23 = l2b * y2 + l3b * y3;
    assert_eq!(scalar_to_bytes(&reconstructed_23), scalar_to_bytes(&a0));
}

#[test]
fn test_even_y_normalization() {
    let mut rng = OsRng;
    // Generate a random point
    let nonce = new_nonce(&mut rng, &Scalar::ONE);
    let p = point::base_mul(&nonce.hiding);

    let vk = VerifyingKey::new(p);
    let vk_even = vk.into_even_y();

    // After normalization, Y must be even
    assert!(vk_even.has_even_y());

    // Double normalization is idempotent
    let vk_even2 = vk_even.into_even_y();
    assert!(point::points_equal(&vk_even.point, &vk_even2.point));
}

#[test]
fn test_frost_sign_and_aggregate_2_of_3() {
    let min_signers = 2;
    let max_signers = 3;

    // 1. Dealer DKG
    let (key_packages, pubkeys) = run_dealer_dkg(min_signers, max_signers);

    // 2. Signing setup: participants 1 and 2 sign
    let signers: Vec<&KeyPackage> = key_packages.iter().take(min_signers).collect();
    let message = b"threshold frost end-to-end signature";

    let mut rng = OsRng;
    let mut nonces = BTreeMap::new();
    let mut commitments = BTreeMap::new();

    for kp in &signers {
        let nonce = new_nonce(&mut rng, &kp.secret_share);
        commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
        nonces.insert(kp.identifier.clone(), nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    // 3. Each signer produces a share
    let mut signature_shares = BTreeMap::new();
    for kp in &signers {
        let nonce = nonces.get(&kp.identifier).unwrap();
        let share = sign(&signing_package, nonce, kp).unwrap();
        signature_shares.insert(kp.identifier.clone(), share);
    }

    // 4. Aggregate
    let signature = aggregate(&signing_package, &signature_shares, &pubkeys).unwrap();

    // 5. Verify
    signature
        .verify(&pubkeys.verifying_key, message)
        .expect("Signature verification failed");
}

#[test]
fn test_frost_sign_and_aggregate_3_of_5() {
    let min_signers = 3;
    let max_signers = 5;

    let (key_packages, pubkeys) = run_dealer_dkg(min_signers, max_signers);

    let message = b"3-of-5 threshold test";

    // Pick participants 2, 3, 5 (non-contiguous)
    let signers: Vec<&KeyPackage> = vec![&key_packages[1], &key_packages[2], &key_packages[4]];

    let mut rng = OsRng;
    let mut nonces = BTreeMap::new();
    let mut commitments = BTreeMap::new();

    for kp in &signers {
        let nonce = new_nonce(&mut rng, &kp.secret_share);
        commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
        nonces.insert(kp.identifier.clone(), nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let mut signature_shares = BTreeMap::new();
    for kp in &signers {
        let nonce = nonces.get(&kp.identifier).unwrap();
        let share = sign(&signing_package, nonce, kp).unwrap();
        signature_shares.insert(kp.identifier.clone(), share);
    }

    let signature = aggregate(&signing_package, &signature_shares, &pubkeys).unwrap();

    signature
        .verify(&pubkeys.verifying_key, message)
        .expect("3-of-5 signature verification failed");
}

#[test]
fn test_frost_different_signer_subsets_produce_valid_signatures() {
    let min_signers = 2;
    let max_signers = 3;

    let (key_packages, pubkeys) = run_dealer_dkg(min_signers, max_signers);
    let message = b"different subsets";

    // Sign with participants {1,2} and then {2,3} and then {1,3}
    let subsets: Vec<Vec<usize>> = vec![vec![0, 1], vec![1, 2], vec![0, 2]];

    for subset in &subsets {
        let signers: Vec<&KeyPackage> =
            subset.iter().map(|&i| &key_packages[i]).collect();

        let mut rng = OsRng;
        let mut nonces = BTreeMap::new();
        let mut commitments = BTreeMap::new();

        for kp in &signers {
            let nonce = new_nonce(&mut rng, &kp.secret_share);
            commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
            nonces.insert(kp.identifier.clone(), nonce);
        }

        let signing_package =
            SigningPackage::new(commitments, message.to_vec());

        let mut signature_shares = BTreeMap::new();
        for kp in &signers {
            let nonce = nonces.get(&kp.identifier).unwrap();
            let share = sign(&signing_package, nonce, kp).unwrap();
            signature_shares.insert(kp.identifier.clone(), share);
        }

        let signature =
            aggregate(&signing_package, &signature_shares, &pubkeys).unwrap();
        signature
            .verify(&pubkeys.verifying_key, message)
            .expect("Subset signature verification failed");
    }
}

#[test]
fn test_signature_serialization_64_bytes() {
    let (key_packages, pubkeys) = run_dealer_dkg(2, 3);
    let message = b"serialization test";

    let signers: Vec<&KeyPackage> = key_packages.iter().take(2).collect();

    let mut rng = OsRng;
    let mut nonces = BTreeMap::new();
    let mut commitments = BTreeMap::new();

    for kp in &signers {
        let nonce = new_nonce(&mut rng, &kp.secret_share);
        commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
        nonces.insert(kp.identifier.clone(), nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let mut signature_shares = BTreeMap::new();
    for kp in &signers {
        let nonce = nonces.get(&kp.identifier).unwrap();
        let share = sign(&signing_package, nonce, kp).unwrap();
        signature_shares.insert(kp.identifier.clone(), share);
    }

    let signature = aggregate(&signing_package, &signature_shares, &pubkeys).unwrap();
    let serialized = signature.serialize();

    // BIP-340: 64 bytes = R_x(32) || z(32)
    assert_eq!(serialized.len(), 64);

    // R should have even Y after serialization
    let sig_even = signature.into_even_y();
    assert!(sig_even.has_even_y());
}

#[test]
fn test_key_package_json_round_trip() {
    let (key_packages, _) = run_dealer_dkg(2, 3);
    let kp = &key_packages[0];

    let json = kp.to_json();
    let recovered = KeyPackage::from_json(&json).unwrap();

    assert_eq!(kp.identifier, recovered.identifier);
    assert_eq!(
        scalar_to_bytes(&kp.secret_share),
        scalar_to_bytes(&recovered.secret_share)
    );
    assert!(point::points_equal(
        &kp.verifying_share,
        &recovered.verifying_share
    ));
    assert!(point::points_equal(
        &kp.verifying_key.point,
        &recovered.verifying_key.point
    ));
    assert_eq!(kp.min_signers, recovered.min_signers);
}

#[test]
fn test_taproot_tweaked_signing() {
    let (key_packages, pubkeys) = run_dealer_dkg(2, 3);
    let merkle_root = [0u8; 32]; // Empty merkle root

    // Tweak key packages and public key package
    let tweaked_kps: Vec<KeyPackage> = key_packages
        .iter()
        .map(|kp| kp.tweak(Some(&merkle_root)))
        .collect();
    let tweaked_pubkeys = pubkeys.tweak(Some(&merkle_root));

    let message = b"taproot tweaked signature";
    let signers: Vec<&KeyPackage> = tweaked_kps.iter().take(2).collect();

    let mut rng = OsRng;
    let mut nonces = BTreeMap::new();
    let mut commitments = BTreeMap::new();

    for kp in &signers {
        let nonce = new_nonce(&mut rng, &kp.secret_share);
        commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
        nonces.insert(kp.identifier.clone(), nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let mut signature_shares = BTreeMap::new();
    for kp in &signers {
        let nonce = nonces.get(&kp.identifier).unwrap();
        let share = sign(&signing_package, nonce, kp).unwrap();
        signature_shares.insert(kp.identifier.clone(), share);
    }

    let signature =
        aggregate(&signing_package, &signature_shares, &tweaked_pubkeys).unwrap();
    signature
        .verify(&tweaked_pubkeys.verifying_key, message)
        .expect("Taproot tweaked signature verification failed");
}

#[test]
fn test_insufficient_signers_rejected() {
    let (key_packages, _) = run_dealer_dkg(2, 3);

    // Only 1 signer for a 2-of-3 scheme
    let kp = &key_packages[0];
    let message = b"insufficient signers";

    let mut rng = OsRng;
    let nonce = new_nonce(&mut rng, &kp.secret_share);
    let mut commitments = BTreeMap::new();
    commitments.insert(kp.identifier.clone(), nonce.commitments.clone());

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let result = sign(&signing_package, &nonce, kp);
    assert!(result.is_err(), "Should reject insufficient signers");
}

// ---------------------------------------------------------------------------
// DKG tests
// ---------------------------------------------------------------------------

/// Helper: generate a random non-zero scalar using the nonce mechanism.
fn random_scalar(rng: &mut impl rand::RngCore) -> Scalar {
    loop {
        let nonce = new_nonce(rng, &Scalar::ONE);
        let s = nonce.hiding;
        if !bool::from(s.is_zero()) {
            return s;
        }
    }
}

/// Run a full 3-round DKG among `max_signers` participants with `min_signers` threshold.
/// Returns (Vec<KeyPackage>, PublicKeyPackage).
fn run_full_dkg(
    min_signers: usize,
    max_signers: usize,
) -> (Vec<KeyPackage>, PublicKeyPackage) {
    let mut rng = OsRng;

    // --- Round 1: each participant generates secret + coefficients, runs dkg_part1 ---
    let mut r1_secrets = Vec::new();
    let mut r1_packages: BTreeMap<Identifier, Round1Package> = BTreeMap::new();

    for _ in 0..max_signers {
        let secret = random_scalar(&mut rng);
        let mut coefficients = Vec::with_capacity(min_signers - 1);
        for _ in 0..(min_signers - 1) {
            coefficients.push(random_scalar(&mut rng));
        }

        let (secret_pkg, pub_pkg) =
            dkg::dkg_part1(max_signers, min_signers, &secret, &coefficients, &mut rng)
                .expect("dkg_part1 failed");

        r1_packages.insert(secret_pkg.identifier.clone(), pub_pkg);
        r1_secrets.push(secret_pkg);
    }

    // --- Round 2: each participant verifies others' round 1 and computes shares ---
    let mut r2_secrets = Vec::new();
    let mut all_r2_packages: Vec<BTreeMap<Identifier, Round2Package>> = Vec::new();

    for secret_pkg in &r1_secrets {
        // Collect round 1 packages from everyone else
        let others: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != secret_pkg.identifier)
            .map(|(id, pkg)| (id.clone(), pkg.clone()))
            .collect();

        let (r2_secret, r2_out) =
            dkg::dkg_part2(secret_pkg, &others, &[]).expect("dkg_part2 failed");

        r2_secrets.push(r2_secret);
        all_r2_packages.push(r2_out);
    }

    // --- Round 3: each participant computes final key package ---
    let mut key_packages = Vec::new();
    let mut final_pubkeys: Option<PublicKeyPackage> = None;

    for (i, r2_secret) in r2_secrets.iter().enumerate() {
        // Collect round 1 packages from others
        let others_r1: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != r2_secret.identifier)
            .map(|(id, pkg)| (id.clone(), pkg.clone()))
            .collect();

        // Collect round 2 packages addressed to us from all other participants
        let mut our_r2: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
        for (j, r2_pkgs) in all_r2_packages.iter().enumerate() {
            if j == i {
                continue;
            }
            // Participant j sent us a share
            if let Some(pkg) = r2_pkgs.get(&r2_secret.identifier) {
                our_r2.insert(r1_secrets[j].identifier.clone(), pkg.clone());
            }
        }

        let (kp, pkp) =
            dkg::dkg_part3(&r1_secrets[i], r2_secret, &others_r1, &our_r2, &[])
                .expect("dkg_part3 failed");

        key_packages.push(kp);

        if let Some(ref existing) = final_pubkeys {
            // All participants should derive the same group public key
            assert!(
                point::points_equal(
                    &existing.verifying_key.point,
                    &pkp.verifying_key.point
                ),
                "Group public key mismatch between participants"
            );
        }
        final_pubkeys = Some(pkp);
    }

    (key_packages, final_pubkeys.unwrap())
}

#[test]
fn test_dkg_3_party_full_flow() {
    let (key_packages, pubkeys) = run_full_dkg(2, 3);

    assert_eq!(key_packages.len(), 3);
    assert_eq!(pubkeys.verifying_shares.len(), 3);

    // Verify each participant's verifying share matches their secret share * G
    for kp in &key_packages {
        let expected = point::base_mul(&kp.secret_share);
        assert!(
            point::points_equal(&kp.verifying_share, &expected),
            "Verifying share mismatch for participant"
        );
    }

    // Verify group key has even Y (normalized by dkg_part3)
    assert!(pubkeys.verifying_key.has_even_y());
}

#[test]
fn test_dkg_then_sign_2_of_3() {
    let (key_packages, pubkeys) = run_full_dkg(2, 3);
    let message = b"DKG + FROST signing end-to-end";

    // Sign with participants 0 and 1
    let signers: Vec<&KeyPackage> = key_packages.iter().take(2).collect();

    let mut rng = OsRng;
    let mut nonces = BTreeMap::new();
    let mut commitments = BTreeMap::new();

    for kp in &signers {
        let nonce = new_nonce(&mut rng, &kp.secret_share);
        commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
        nonces.insert(kp.identifier.clone(), nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let mut signature_shares = BTreeMap::new();
    for kp in &signers {
        let nonce = nonces.get(&kp.identifier).unwrap();
        let share = sign(&signing_package, nonce, kp).unwrap();
        signature_shares.insert(kp.identifier.clone(), share);
    }

    let signature = aggregate(&signing_package, &signature_shares, &pubkeys).unwrap();

    signature
        .verify(&pubkeys.verifying_key, message)
        .expect("DKG + signing: signature verification failed");
}

#[test]
fn test_dkg_then_sign_different_subsets() {
    let (key_packages, pubkeys) = run_full_dkg(2, 3);
    let message = b"different subsets after DKG";

    let subsets: Vec<Vec<usize>> = vec![vec![0, 1], vec![1, 2], vec![0, 2]];

    for subset in &subsets {
        let signers: Vec<&KeyPackage> =
            subset.iter().map(|&i| &key_packages[i]).collect();

        let mut rng = OsRng;
        let mut nonces = BTreeMap::new();
        let mut commitments = BTreeMap::new();

        for kp in &signers {
            let nonce = new_nonce(&mut rng, &kp.secret_share);
            commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
            nonces.insert(kp.identifier.clone(), nonce);
        }

        let signing_package = SigningPackage::new(commitments, message.to_vec());

        let mut signature_shares = BTreeMap::new();
        for kp in &signers {
            let nonce = nonces.get(&kp.identifier).unwrap();
            let share = sign(&signing_package, nonce, kp).unwrap();
            signature_shares.insert(kp.identifier.clone(), share);
        }

        let signature =
            aggregate(&signing_package, &signature_shares, &pubkeys).unwrap();
        signature
            .verify(&pubkeys.verifying_key, message)
            .expect("DKG subset signature verification failed");
    }
}

#[test]
fn test_dkg_then_taproot_tweaked_signing() {
    let (key_packages, pubkeys) = run_full_dkg(2, 3);
    let merkle_root = [0u8; 32];

    let tweaked_kps: Vec<KeyPackage> = key_packages
        .iter()
        .map(|kp| kp.tweak(Some(&merkle_root)))
        .collect();
    let tweaked_pubkeys = pubkeys.tweak(Some(&merkle_root));

    let message = b"DKG + taproot tweaked signature";
    let signers: Vec<&KeyPackage> = tweaked_kps.iter().take(2).collect();

    let mut rng = OsRng;
    let mut nonces = BTreeMap::new();
    let mut commitments = BTreeMap::new();

    for kp in &signers {
        let nonce = new_nonce(&mut rng, &kp.secret_share);
        commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
        nonces.insert(kp.identifier.clone(), nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let mut signature_shares = BTreeMap::new();
    for kp in &signers {
        let nonce = nonces.get(&kp.identifier).unwrap();
        let share = sign(&signing_package, nonce, kp).unwrap();
        signature_shares.insert(kp.identifier.clone(), share);
    }

    let signature =
        aggregate(&signing_package, &signature_shares, &tweaked_pubkeys).unwrap();
    signature
        .verify(&tweaked_pubkeys.verifying_key, message)
        .expect("DKG + taproot tweaked signature verification failed");
}

#[test]
fn test_dkg_5_party_3_of_5() {
    let (key_packages, pubkeys) = run_full_dkg(3, 5);

    assert_eq!(key_packages.len(), 5);
    assert_eq!(pubkeys.verifying_shares.len(), 5);

    // Sign with 3 out of 5
    let message = b"3-of-5 DKG test";
    let signers: Vec<&KeyPackage> = vec![&key_packages[0], &key_packages[2], &key_packages[4]];

    let mut rng = OsRng;
    let mut nonces = BTreeMap::new();
    let mut commitments = BTreeMap::new();

    for kp in &signers {
        let nonce = new_nonce(&mut rng, &kp.secret_share);
        commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
        nonces.insert(kp.identifier.clone(), nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let mut signature_shares = BTreeMap::new();
    for kp in &signers {
        let nonce = nonces.get(&kp.identifier).unwrap();
        let share = sign(&signing_package, nonce, kp).unwrap();
        signature_shares.insert(kp.identifier.clone(), share);
    }

    let signature = aggregate(&signing_package, &signature_shares, &pubkeys).unwrap();
    signature
        .verify(&pubkeys.verifying_key, message)
        .expect("3-of-5 DKG signature verification failed");
}

#[test]
fn test_dkg_proof_of_knowledge_verification() {
    let mut rng = OsRng;

    let secret = random_scalar(&mut rng);
    let coeff = random_scalar(&mut rng);

    let (secret_pkg, pub_pkg) =
        dkg::dkg_part1(3, 2, &secret, &[coeff], &mut rng)
            .expect("dkg_part1 failed");

    // Verify proof of knowledge succeeds
    let vk = pub_pkg.commitment.to_verifying_key();
    dkg::verify_proof_of_knowledge(
        &secret_pkg.identifier,
        &vk,
        &pub_pkg.proof_of_knowledge,
    )
    .expect("Proof of knowledge should verify");
}

#[test]
fn test_dkg_proof_of_knowledge_rejects_wrong_key() {
    let mut rng = OsRng;

    let secret1 = random_scalar(&mut rng);
    let coeff1 = random_scalar(&mut rng);
    let secret2 = random_scalar(&mut rng);
    let coeff2 = random_scalar(&mut rng);

    let (secret_pkg1, pub_pkg1) =
        dkg::dkg_part1(3, 2, &secret1, &[coeff1], &mut rng).unwrap();
    let (_secret_pkg2, pub_pkg2) =
        dkg::dkg_part1(3, 2, &secret2, &[coeff2], &mut rng).unwrap();

    // Try verifying pkg1's proof with pkg2's verifying key — should fail
    let wrong_vk = pub_pkg2.commitment.to_verifying_key();
    let result = dkg::verify_proof_of_knowledge(
        &secret_pkg1.identifier,
        &wrong_vk,
        &pub_pkg1.proof_of_knowledge,
    );
    assert!(result.is_err(), "Proof should fail with wrong verifying key");
}

#[test]
fn test_vss_commitment_verifying_share() {
    let mut rng = OsRng;

    let secret = random_scalar(&mut rng);
    let coeff = random_scalar(&mut rng);
    let coefficients = vec![secret, coeff];

    // Build VssCommitment from g^coeff_i
    let commitment_points: Vec<k256::ProjectivePoint> =
        coefficients.iter().map(|c| point::base_mul(c)).collect();
    let vss = VssCommitment {
        coeffs: commitment_points,
    };

    // For any identifier, verifying_share should equal polynomial_eval * G
    let id = Identifier::from_u16(5).unwrap();
    let vs = vss.get_verifying_share(&id);

    let x = *id.to_scalar();
    let expected_scalar = secret + coeff * x;
    let expected_point = point::base_mul(&expected_scalar);

    assert!(
        point::points_equal(&vs, &expected_point),
        "VSS verifying share should match polynomial evaluation * G"
    );
}

#[test]
fn test_vss_sum_commitments() {
    let mut rng = OsRng;

    // Two commitments, each with 2 coefficients (threshold=2)
    let a0 = random_scalar(&mut rng);
    let a1 = random_scalar(&mut rng);
    let b0 = random_scalar(&mut rng);
    let b1 = random_scalar(&mut rng);

    let vss_a = VssCommitment {
        coeffs: vec![point::base_mul(&a0), point::base_mul(&a1)],
    };
    let vss_b = VssCommitment {
        coeffs: vec![point::base_mul(&b0), point::base_mul(&b1)],
    };

    let summed = threshold::vss::sum_commitments(&[vss_a, vss_b]).unwrap();

    // summed.coeffs[0] should be (a0+b0)*G
    let expected_0 = point::base_mul(&(a0 + b0));
    let expected_1 = point::base_mul(&(a1 + b1));

    assert!(point::points_equal(&summed.coeffs[0], &expected_0));
    assert!(point::points_equal(&summed.coeffs[1], &expected_1));
}

#[test]
fn test_dkg_round1_package_json_round_trip() {
    let mut rng = OsRng;

    let secret = random_scalar(&mut rng);
    let coeff = random_scalar(&mut rng);

    let (_secret_pkg, pub_pkg) =
        dkg::dkg_part1(3, 2, &secret, &[coeff], &mut rng).unwrap();

    let json = pub_pkg.to_json();
    let recovered = Round1Package::from_json(&json).unwrap();

    // Check commitment coefficients
    assert_eq!(
        pub_pkg.commitment.coeffs.len(),
        recovered.commitment.coeffs.len()
    );
    for (a, b) in pub_pkg
        .commitment
        .coeffs
        .iter()
        .zip(recovered.commitment.coeffs.iter())
    {
        assert!(point::points_equal(a, b));
    }

    // Check proof of knowledge
    assert!(point::points_equal(
        &pub_pkg.proof_of_knowledge.r,
        &recovered.proof_of_knowledge.r
    ));
    assert_eq!(
        scalar_to_bytes(&pub_pkg.proof_of_knowledge.z),
        scalar_to_bytes(&recovered.proof_of_knowledge.z)
    );

    // Check verifying key
    assert!(point::points_equal(
        &pub_pkg.verifying_key.point,
        &recovered.verifying_key.point
    ));
}

#[test]
fn test_dkg_round2_package_json_round_trip() {
    let share = Scalar::from(12345u64);
    let pkg = Round2Package {
        secret_share: share,
    };

    let json = pkg.to_json();
    let recovered = Round2Package::from_json(&json).unwrap();

    assert_eq!(
        scalar_to_bytes(&pkg.secret_share),
        scalar_to_bytes(&recovered.secret_share)
    );
}

// ---------------------------------------------------------------------------
// Key Refresh tests
// ---------------------------------------------------------------------------

#[test]
fn test_key_refresh_preserves_group_key() {
    let mut rng = OsRng;

    // Run full DKG for 3-of-3
    let (key_packages, pubkeys) = run_full_dkg(2, 3);

    let original_group_key = pubkeys.verifying_key.serialize();

    // All 3 participants do refresh
    let ids: Vec<Identifier> = key_packages.iter().map(|kp| kp.identifier.clone()).collect();

    // Round 1: each participant generates refresh polynomial
    let mut r1_secrets = Vec::new();
    let mut r1_packages: BTreeMap<Identifier, dkg::Round1Package> = BTreeMap::new();

    for kp in &key_packages {
        let coefficients: Vec<Scalar> = (0..1).map(|_| random_scalar(&mut rng)).collect(); // min_signers-1 = 1
        let (secret_pkg, pub_pkg) =
            dkg::dkg_refresh_part1(&kp.identifier, 3, 2, &coefficients, &mut rng)
                .expect("refresh part1 failed");

        r1_packages.insert(kp.identifier.clone(), pub_pkg);
        r1_secrets.push(secret_pkg);
    }

    // Round 2: each participant computes refresh shares
    let mut r2_secrets = Vec::new();
    let mut all_r2_packages: Vec<BTreeMap<Identifier, Round2Package>> = Vec::new();

    for (i, secret_pkg) in r1_secrets.iter().enumerate() {
        let others: BTreeMap<Identifier, dkg::Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != ids[i])
            .map(|(id, pkg)| (id.clone(), pkg.clone()))
            .collect();

        let (r2_secret, r2_out) =
            dkg::dkg_refresh_part2(secret_pkg, &others).expect("refresh part2 failed");

        r2_secrets.push(r2_secret);
        all_r2_packages.push(r2_out);
    }

    // Round 3: each participant combines refresh delta with old key
    let mut new_key_packages = Vec::new();
    let mut new_pubkeys: Option<PublicKeyPackage> = None;

    for (i, r2_secret) in r2_secrets.iter().enumerate() {
        let others_r1: BTreeMap<Identifier, dkg::Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != ids[i])
            .map(|(id, pkg)| (id.clone(), pkg.clone()))
            .collect();

        let mut our_r2: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
        for (j, r2_pkgs) in all_r2_packages.iter().enumerate() {
            if j == i {
                continue;
            }
            if let Some(pkg) = r2_pkgs.get(&ids[i]) {
                our_r2.insert(ids[j].clone(), pkg.clone());
            }
        }

        let (new_kp, new_pkp) = dkg::dkg_refresh_part3(
            r2_secret,
            &others_r1,
            &our_r2,
            &pubkeys,
            &key_packages[i],
        )
        .expect("refresh part3 failed");

        new_key_packages.push(new_kp);

        if let Some(ref existing) = new_pubkeys {
            assert!(
                point::points_equal(
                    &existing.verifying_key.point,
                    &new_pkp.verifying_key.point
                ),
                "Group public key mismatch after refresh"
            );
        }
        new_pubkeys = Some(new_pkp);
    }

    let new_pubkeys = new_pubkeys.unwrap();

    // Group key must be preserved
    assert_eq!(
        original_group_key,
        new_pubkeys.verifying_key.serialize(),
        "Group key changed after refresh — this should never happen"
    );

    // Verify signing still works with refreshed keys
    let message = b"test message after refresh";
    let signers = vec![0, 1]; // 2-of-3

    let mut nonces = Vec::new();
    let mut commitments: BTreeMap<Identifier, threshold::nonce::SigningCommitments> =
        BTreeMap::new();

    for &idx in &signers {
        let nonce = new_nonce(&mut rng, &new_key_packages[idx].secret_share);
        commitments.insert(
            new_key_packages[idx].identifier.clone(),
            nonce.commitments.clone(),
        );
        nonces.push(nonce);
    }

    let signing_package = SigningPackage::new(commitments, message.to_vec());

    let mut shares: BTreeMap<Identifier, threshold::signing::SignatureShare> = BTreeMap::new();
    for (i, &idx) in signers.iter().enumerate() {
        let share = sign(&signing_package, &nonces[i], &new_key_packages[idx])
            .expect("signing failed");
        shares.insert(new_key_packages[idx].identifier.clone(), share);
    }

    let signature = aggregate(&signing_package, &shares, &new_pubkeys)
        .expect("aggregation failed");

    signature
        .verify(&new_pubkeys.verifying_key, message)
        .expect("signature verification failed after refresh");
}

// ---------------------------------------------------------------------------
// Auth tests
// ---------------------------------------------------------------------------

#[cfg(feature = "std")]
mod auth_tests {
    use threshold::auth::{AuthSigner, verify_schnorr_signature};
    use threshold::scalar::scalar_to_bytes;
    use threshold::nonce::new_nonce;
    use k256::Scalar;
    use rand::rngs::OsRng;

    #[test]
    fn test_auth_signer_sign_verify() {
        let mut rng = OsRng;
        let nonce = new_nonce(&mut rng, &Scalar::ONE);
        let secret_bytes = scalar_to_bytes(&nonce.hiding);

        let signer = AuthSigner::from_secret_bytes(&secret_bytes)
            .expect("AuthSigner creation failed");

        let message = b"test auth message";
        let signature = signer.sign(message);

        assert_eq!(signature.len(), 64);

        let pk = signer.public_key_compressed();
        assert!(
            verify_schnorr_signature(&pk, message, &signature),
            "Signature verification failed"
        );
    }

    #[test]
    fn test_auth_signer_wrong_message_fails() {
        let mut rng = OsRng;
        let nonce = new_nonce(&mut rng, &Scalar::ONE);
        let secret_bytes = scalar_to_bytes(&nonce.hiding);

        let signer = AuthSigner::from_secret_bytes(&secret_bytes).unwrap();

        let signature = signer.sign(b"correct message");
        let pk = signer.public_key_compressed();

        assert!(
            !verify_schnorr_signature(&pk, b"wrong message", &signature),
            "Signature should not verify with wrong message"
        );
    }

    #[test]
    fn test_auth_signer_wrong_key_fails() {
        let mut rng = OsRng;
        let nonce1 = new_nonce(&mut rng, &Scalar::ONE);
        let nonce2 = new_nonce(&mut rng, &Scalar::ONE);

        let signer1 = AuthSigner::from_secret_bytes(&scalar_to_bytes(&nonce1.hiding)).unwrap();
        let signer2 = AuthSigner::from_secret_bytes(&scalar_to_bytes(&nonce2.hiding)).unwrap();

        let message = b"test message";
        let signature = signer1.sign(message);
        let wrong_pk = signer2.public_key_compressed();

        assert!(
            !verify_schnorr_signature(&wrong_pk, message, &signature),
            "Signature should not verify with wrong key"
        );
    }

    #[test]
    fn test_auth_signer_deterministic() {
        let mut rng = OsRng;
        let nonce = new_nonce(&mut rng, &Scalar::ONE);
        let secret_bytes = scalar_to_bytes(&nonce.hiding);

        let signer = AuthSigner::from_secret_bytes(&secret_bytes).unwrap();

        let message = b"deterministic test";
        let sig1 = signer.sign(message);
        let sig2 = signer.sign(message);

        assert_eq!(sig1, sig2, "Deterministic nonce should produce identical signatures");
    }
}

// ---------------------------------------------------------------------------
// Random utility tests
// ---------------------------------------------------------------------------

#[cfg(feature = "std")]
mod random_tests {
    use threshold::random::{mod_n_random, mod_n_random_seeded, generate_coefficients, generate_coefficients_seeded};
    use threshold::scalar::scalar_to_bytes;
    use rand::rngs::OsRng;

    #[test]
    fn test_mod_n_random_non_zero() {
        let mut rng = OsRng;
        for _ in 0..100 {
            let s = mod_n_random(&mut rng);
            assert!(!bool::from(s.is_zero()));
        }
    }

    #[test]
    fn test_mod_n_random_seeded_deterministic() {
        let seed = b"test seed";
        let s1 = mod_n_random_seeded(seed, 0);
        let s2 = mod_n_random_seeded(seed, 0);
        assert_eq!(scalar_to_bytes(&s1), scalar_to_bytes(&s2));

        // Different counter should give different result
        let s3 = mod_n_random_seeded(seed, 1);
        assert_ne!(scalar_to_bytes(&s1), scalar_to_bytes(&s3));
    }

    #[test]
    fn test_generate_coefficients_count() {
        let mut rng = OsRng;
        let coeffs = generate_coefficients(5, &mut rng);
        assert_eq!(coeffs.len(), 5);
    }

    #[test]
    fn test_generate_coefficients_seeded_deterministic() {
        let seed = b"coeff seed";
        let c1 = generate_coefficients_seeded(3, seed);
        let c2 = generate_coefficients_seeded(3, seed);

        assert_eq!(c1.len(), 3);
        for i in 0..3 {
            assert_eq!(scalar_to_bytes(&c1[i]), scalar_to_bytes(&c2[i]));
        }
    }
}

// ---------------------------------------------------------------------------
// Restore (re-DKG) tests
// ---------------------------------------------------------------------------

/// Simulate the wallet restore flow: two dealers (HW signer + server) reuse
/// their original DKG secrets with fresh random coefficients. A passive
/// receiver (wallet) gets a new secret share via `dkg_part3_receive`.
/// The group public key must be preserved, and signing must work after restore.
#[test]
fn test_restore_via_redkg_preserves_group_key_and_signing() {
    let mut rng = OsRng;
    let min_signers = 2;
    let max_signers = 3;

    // ---------------------------------------------------------------
    // Phase 1: Initial DKG (HW signer + server as dealers, wallet as
    // passive receiver)
    // ---------------------------------------------------------------

    // HW signer: random secret + coefficients
    let hw_secret = random_scalar(&mut rng);
    let hw_coeffs: Vec<Scalar> = (0..min_signers - 1)
        .map(|_| random_scalar(&mut rng))
        .collect();
    let (hw_r1_secret, hw_r1_pub) =
        dkg::dkg_part1(max_signers, min_signers, &hw_secret, &hw_coeffs, &mut rng)
            .expect("hw dkg_part1");
    let hw_id = hw_r1_secret.identifier.clone();

    // Server: random secret + coefficients
    let srv_secret = random_scalar(&mut rng);
    let srv_coeffs: Vec<Scalar> = (0..min_signers - 1)
        .map(|_| random_scalar(&mut rng))
        .collect();
    let (srv_r1_secret, srv_r1_pub) =
        dkg::dkg_part1(max_signers, min_signers, &srv_secret, &srv_coeffs, &mut rng)
            .expect("srv dkg_part1");
    let srv_id = srv_r1_secret.identifier.clone();

    // Wallet: passive receiver (deterministic identifier derived from HW VK)
    let wallet_id = Identifier::derive(&hw_r1_pub.verifying_key.serialize())
        .expect("wallet id derive");

    // Round 2: HW signer
    let hw_others_r1: BTreeMap<Identifier, Round1Package> =
        [(srv_id.clone(), srv_r1_pub.clone())].into();
    let (hw_r2_secret, hw_r2_out) =
        dkg::dkg_part2(&hw_r1_secret, &hw_others_r1, &[wallet_id.clone()])
            .expect("hw dkg_part2");

    // Round 2: Server
    let srv_others_r1: BTreeMap<Identifier, Round1Package> =
        [(hw_id.clone(), hw_r1_pub.clone())].into();
    let (srv_r2_secret, srv_r2_out) =
        dkg::dkg_part2(&srv_r1_secret, &srv_others_r1, &[wallet_id.clone()])
            .expect("srv dkg_part2");

    // Round 3: HW signer finalizes
    let hw_r2_for_me: BTreeMap<Identifier, Round2Package> =
        [(srv_id.clone(), srv_r2_out.get(&hw_id).unwrap().clone())].into();
    let (_hw_kp, _) = dkg::dkg_part3(
        &hw_r1_secret,
        &hw_r2_secret,
        &[(srv_id.clone(), srv_r1_pub.clone())].into(),
        &hw_r2_for_me,
        &[wallet_id.clone()],
    )
    .expect("hw dkg_part3");

    // Round 3: Server finalizes
    let srv_r2_for_me: BTreeMap<Identifier, Round2Package> =
        [(hw_id.clone(), hw_r2_out.get(&srv_id).unwrap().clone())].into();
    let (srv_kp, _) = dkg::dkg_part3(
        &srv_r1_secret,
        &srv_r2_secret,
        &[(hw_id.clone(), hw_r1_pub.clone())].into(),
        &srv_r2_for_me,
        &[wallet_id.clone()],
    )
    .expect("srv dkg_part3");

    // Round 3: Wallet finalizes as passive receiver
    let dealer_r1_for_wallet: BTreeMap<Identifier, Round1Package> = [
        (hw_id.clone(), hw_r1_pub.clone()),
        (srv_id.clone(), srv_r1_pub.clone()),
    ]
    .into();
    let shares_for_wallet: BTreeMap<Identifier, Round2Package> = [
        (hw_id.clone(), hw_r2_out.get(&wallet_id).unwrap().clone()),
        (srv_id.clone(), srv_r2_out.get(&wallet_id).unwrap().clone()),
    ]
    .into();
    let all_ids = vec![hw_id.clone(), srv_id.clone(), wallet_id.clone()];
    let (wallet_kp, pubkeys) = dkg::dkg_part3_receive(
        &wallet_id,
        &dealer_r1_for_wallet,
        &shares_for_wallet,
        min_signers,
        max_signers,
        &all_ids,
    )
    .expect("wallet dkg_part3_receive");

    let original_group_key = pubkeys.verifying_key.serialize();

    // Verify signing works: wallet + server (2-of-3)
    let message = b"pre-restore signing test";
    {
        let signers = [&wallet_kp, &srv_kp];
        let mut nonces = BTreeMap::new();
        let mut commitments = BTreeMap::new();
        for kp in &signers {
            let nonce = new_nonce(&mut rng, &kp.secret_share);
            commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
            nonces.insert(kp.identifier.clone(), nonce);
        }
        let signing_package = SigningPackage::new(commitments, message.to_vec());
        let mut shares = BTreeMap::new();
        for kp in &signers {
            let nonce = nonces.get(&kp.identifier).unwrap();
            let share = sign(&signing_package, nonce, kp).unwrap();
            shares.insert(kp.identifier.clone(), share);
        }
        let sig = aggregate(&signing_package, &shares, &pubkeys).unwrap();
        sig.verify(&pubkeys.verifying_key, message)
            .expect("pre-restore signature failed");
    }

    // ---------------------------------------------------------------
    // Phase 2: Restore (re-DKG). HW signer + server reuse their
    // original secrets with fresh coefficients. Wallet is passive.
    // ---------------------------------------------------------------

    // HW signer: same secret, fresh coefficients
    let hw_restore_coeffs: Vec<Scalar> = (0..min_signers - 1)
        .map(|_| random_scalar(&mut rng))
        .collect();
    let (hw2_r1_secret, hw2_r1_pub) =
        dkg::dkg_part1(max_signers, min_signers, &hw_secret, &hw_restore_coeffs, &mut rng)
            .expect("hw restore dkg_part1");
    let hw2_id = hw2_r1_secret.identifier.clone();

    // Server: same secret, fresh coefficients
    let srv_restore_coeffs: Vec<Scalar> = (0..min_signers - 1)
        .map(|_| random_scalar(&mut rng))
        .collect();
    let (srv2_r1_secret, srv2_r1_pub) =
        dkg::dkg_part1(max_signers, min_signers, &srv_secret, &srv_restore_coeffs, &mut rng)
            .expect("srv restore dkg_part1");
    let srv2_id = srv2_r1_secret.identifier.clone();

    // Wallet: new passive receiver ID derived from HW's (unchanged) VK
    let wallet2_id = Identifier::derive(&hw2_r1_pub.verifying_key.serialize())
        .expect("wallet2 id derive");

    // The identifiers should be the same since secrets are the same
    assert_eq!(hw_id, hw2_id, "HW identifier should be stable across restores");
    assert_eq!(srv_id, srv2_id, "Server identifier should be stable across restores");
    assert_eq!(wallet_id, wallet2_id, "Wallet identifier should be stable across restores");

    // Round 2
    let hw2_others_r1: BTreeMap<Identifier, Round1Package> =
        [(srv2_id.clone(), srv2_r1_pub.clone())].into();
    let (hw2_r2_secret, hw2_r2_out) =
        dkg::dkg_part2(&hw2_r1_secret, &hw2_others_r1, &[wallet2_id.clone()])
            .expect("hw restore dkg_part2");

    let srv2_others_r1: BTreeMap<Identifier, Round1Package> =
        [(hw2_id.clone(), hw2_r1_pub.clone())].into();
    let (srv2_r2_secret, srv2_r2_out) =
        dkg::dkg_part2(&srv2_r1_secret, &srv2_others_r1, &[wallet2_id.clone()])
            .expect("srv restore dkg_part2");

    // Round 3: dealers finalize
    let hw2_r2_for_me: BTreeMap<Identifier, Round2Package> =
        [(srv2_id.clone(), srv2_r2_out.get(&hw2_id).unwrap().clone())].into();
    let (_hw2_kp, _) = dkg::dkg_part3(
        &hw2_r1_secret,
        &hw2_r2_secret,
        &[(srv2_id.clone(), srv2_r1_pub.clone())].into(),
        &hw2_r2_for_me,
        &[wallet2_id.clone()],
    )
    .expect("hw restore dkg_part3");

    let srv2_r2_for_me: BTreeMap<Identifier, Round2Package> =
        [(hw2_id.clone(), hw2_r2_out.get(&srv2_id).unwrap().clone())].into();
    let (srv2_kp, _) = dkg::dkg_part3(
        &srv2_r1_secret,
        &srv2_r2_secret,
        &[(hw2_id.clone(), hw2_r1_pub.clone())].into(),
        &srv2_r2_for_me,
        &[wallet2_id.clone()],
    )
    .expect("srv restore dkg_part3");

    // Round 3: wallet as passive receiver
    let dealer_r1_for_wallet2: BTreeMap<Identifier, Round1Package> = [
        (hw2_id.clone(), hw2_r1_pub.clone()),
        (srv2_id.clone(), srv2_r1_pub.clone()),
    ]
    .into();
    let shares_for_wallet2: BTreeMap<Identifier, Round2Package> = [
        (hw2_id.clone(), hw2_r2_out.get(&wallet2_id).unwrap().clone()),
        (srv2_id.clone(), srv2_r2_out.get(&wallet2_id).unwrap().clone()),
    ]
    .into();
    let all_ids2 = vec![hw2_id.clone(), srv2_id.clone(), wallet2_id.clone()];
    let (wallet2_kp, pubkeys2) = dkg::dkg_part3_receive(
        &wallet2_id,
        &dealer_r1_for_wallet2,
        &shares_for_wallet2,
        min_signers,
        max_signers,
        &all_ids2,
    )
    .expect("wallet restore dkg_part3_receive");

    // ---------------------------------------------------------------
    // Assertions
    // ---------------------------------------------------------------

    // Group public key MUST be preserved
    assert_eq!(
        original_group_key,
        pubkeys2.verifying_key.serialize(),
        "Group key must be preserved after restore"
    );

    // Secret shares should be DIFFERENT (fresh coefficients -> new polynomial)
    assert_ne!(
        scalar_to_bytes(&wallet_kp.secret_share),
        scalar_to_bytes(&wallet2_kp.secret_share),
        "Wallet secret share should change after restore"
    );

    // Signing with restored keys: wallet + server
    let message2 = b"post-restore signing test";
    {
        let signers = [&wallet2_kp, &srv2_kp];
        let mut nonces = BTreeMap::new();
        let mut commitments = BTreeMap::new();
        for kp in &signers {
            let nonce = new_nonce(&mut rng, &kp.secret_share);
            commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
            nonces.insert(kp.identifier.clone(), nonce);
        }
        let signing_package = SigningPackage::new(commitments, message2.to_vec());
        let mut shares = BTreeMap::new();
        for kp in &signers {
            let nonce = nonces.get(&kp.identifier).unwrap();
            let share = sign(&signing_package, nonce, kp).unwrap();
            shares.insert(kp.identifier.clone(), share);
        }
        let sig = aggregate(&signing_package, &shares, &pubkeys2).unwrap();
        sig.verify(&pubkeys2.verifying_key, message2)
            .expect("post-restore signature verification failed");
    }

    // Also verify HW + server can sign (different subset)
    let message3 = b"post-restore hw+server signing";
    {
        let signers = [&_hw2_kp, &srv2_kp];
        let mut nonces = BTreeMap::new();
        let mut commitments = BTreeMap::new();
        for kp in &signers {
            let nonce = new_nonce(&mut rng, &kp.secret_share);
            commitments.insert(kp.identifier.clone(), nonce.commitments.clone());
            nonces.insert(kp.identifier.clone(), nonce);
        }
        let signing_package = SigningPackage::new(commitments, message3.to_vec());
        let mut shares = BTreeMap::new();
        for kp in &signers {
            let nonce = nonces.get(&kp.identifier).unwrap();
            let share = sign(&signing_package, nonce, kp).unwrap();
            shares.insert(kp.identifier.clone(), share);
        }
        let sig = aggregate(&signing_package, &shares, &pubkeys2).unwrap();
        sig.verify(&pubkeys2.verifying_key, message3)
            .expect("post-restore hw+server signature failed");
    }
}
