use criterion::{black_box, criterion_group, criterion_main, Criterion};
use threshold::dkg::{dkg_part1, dkg_part2, dkg_part3};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::nonce::SigningNonce;
use threshold::commitment::SigningPackage;
use threshold::signing::{sign, aggregate};
use k256::Scalar;
use rand::thread_rng;
use std::collections::BTreeMap;

fn bench_dkg(c: &mut Criterion) {
    let mut rng = thread_rng();
    let min_signers = 2;
    let max_signers = 3;
    let coefficients_template: Vec<Scalar> = (0..min_signers - 1)
        .map(|_| Scalar::generate_biased(&mut rng))
        .collect();

    // Setup for Part 2
    let (s1, p1) = dkg_part1(max_signers, min_signers, &Scalar::generate_biased(&mut rng), &coefficients_template.iter().map(|_| Scalar::generate_biased(&mut rng)).collect::<Vec<_>>(), &mut rng).unwrap();
    let (s2, p2) = dkg_part1(max_signers, min_signers, &Scalar::generate_biased(&mut rng), &coefficients_template.iter().map(|_| Scalar::generate_biased(&mut rng)).collect::<Vec<_>>(), &mut rng).unwrap();
    let (s3, p3) = dkg_part1(max_signers, min_signers, &Scalar::generate_biased(&mut rng), &coefficients_template.iter().map(|_| Scalar::generate_biased(&mut rng)).collect::<Vec<_>>(), &mut rng).unwrap();

    c.bench_function("dkg_part1", |b| {
        b.iter(|| {
            dkg_part1(
                black_box(max_signers),
                black_box(min_signers),
                black_box(&Scalar::generate_biased(&mut rng)),
                black_box(&coefficients_template.iter().map(|_| Scalar::generate_biased(&mut rng)).collect::<Vec<_>>()),
                &mut rng,
            )
            .unwrap()
        })
    });

    let mut r1_pkgs_for_s1 = BTreeMap::new();
    r1_pkgs_for_s1.insert(s2.identifier.clone(), p2.clone());
    r1_pkgs_for_s1.insert(s3.identifier.clone(), p3.clone());

    c.bench_function("dkg_part2", |b| {
        b.iter(|| {
            dkg_part2(
                black_box(&s1),
                black_box(&r1_pkgs_for_s1),
                black_box(&[]),
            )
            .unwrap()
        })
    });

    // Setup for Part 3
    let (s1_r2, _) = dkg_part2(&s1, &r1_pkgs_for_s1, &[]).unwrap();
    let (s2_r2, s2_shares) = dkg_part2(&s2, &{
        let mut m = BTreeMap::new();
        m.insert(s1.identifier.clone(), p1.clone());
        m.insert(s3.identifier.clone(), p3.clone());
        m
    }, &[]).unwrap();
    let (s3_r2, s3_shares) = dkg_part2(&s3, &{
        let mut m = BTreeMap::new();
        m.insert(s1.identifier.clone(), p1.clone());
        m.insert(s2.identifier.clone(), p2.clone());
        m
    }, &[]).unwrap();

    let mut shares_for_s1 = BTreeMap::new();
    shares_for_s1.insert(s2.identifier.clone(), s2_shares.get(&s1.identifier).unwrap().clone());
    shares_for_s1.insert(s3.identifier.clone(), s3_shares.get(&s1.identifier).unwrap().clone());

    c.bench_function("dkg_part3", |b| {
        b.iter(|| {
            dkg_part3(
                black_box(&s1),
                black_box(&s1_r2),
                black_box(&r1_pkgs_for_s1),
                black_box(&shares_for_s1),
                black_box(&[]),
            )
            .unwrap()
        })
    });
}

fn bench_signing(c: &mut Criterion) {
    let mut rng = thread_rng();
    let min_signers = 2;
    let max_signers = 3;
    let coefficients_template: Vec<Scalar> = (0..min_signers - 1).map(|_| Scalar::generate_biased(&mut rng)).collect();
    
    let (s1, p1) = dkg_part1(max_signers, min_signers, &Scalar::generate_biased(&mut rng), &coefficients_template.iter().map(|_| Scalar::generate_biased(&mut rng)).collect::<Vec<_>>(), &mut rng).unwrap();
    let (s2, p2) = dkg_part1(max_signers, min_signers, &Scalar::generate_biased(&mut rng), &coefficients_template.iter().map(|_| Scalar::generate_biased(&mut rng)).collect::<Vec<_>>(), &mut rng).unwrap();
    let (s3, p3) = dkg_part1(max_signers, min_signers, &Scalar::generate_biased(&mut rng), &coefficients_template.iter().map(|_| Scalar::generate_biased(&mut rng)).collect::<Vec<_>>(), &mut rng).unwrap();

    let mut r1_pkgs_for_s1 = BTreeMap::new();
    r1_pkgs_for_s1.insert(s2.identifier.clone(), p2.clone());
    r1_pkgs_for_s1.insert(s3.identifier.clone(), p3.clone());
    let (s1_r2, _) = dkg_part2(&s1, &r1_pkgs_for_s1, &[]).unwrap();

    let mut r1_pkgs_for_s2 = BTreeMap::new();
    r1_pkgs_for_s2.insert(s1.identifier.clone(), p1.clone());
    r1_pkgs_for_s2.insert(s3.identifier.clone(), p3.clone());
    let (s2_r2, s2_shares) = dkg_part2(&s2, &r1_pkgs_for_s2, &[]).unwrap();

    let mut r1_pkgs_for_s3 = BTreeMap::new();
    r1_pkgs_for_s3.insert(s1.identifier.clone(), p1.clone());
    r1_pkgs_for_s3.insert(s2.identifier.clone(), p2.clone());
    let (s3_r2, s3_shares) = dkg_part2(&s3, &r1_pkgs_for_s3, &[]).unwrap();

    let mut shares_for_s1 = BTreeMap::new();
    shares_for_s1.insert(s2.identifier.clone(), s2_shares.get(&s1.identifier).unwrap().clone());
    shares_for_s1.insert(s3.identifier.clone(), s3_shares.get(&s1.identifier).unwrap().clone());

    let (kp1, pkp) = dkg_part3(&s1, &s1_r2, &r1_pkgs_for_s1, &shares_for_s1, &[]).unwrap();

    // Nonce generation
    let n1 = threshold::nonce::new_nonce(&mut rng, &kp1.secret_share);
    let n2 = threshold::nonce::new_nonce(&mut rng, &kp1.secret_share); // Simplified
    
    let message = b"hello world";
    let mut commitments = BTreeMap::new();
    commitments.insert(s1.identifier.clone(), n1.commitments.clone());
    commitments.insert(s2.identifier.clone(), n2.commitments.clone());
    
    let pkg = SigningPackage {
        message: message.to_vec(),
        commitments,
    };

    c.bench_function("sign_share", |b| {
        b.iter(|| {
            sign(
                black_box(&pkg),
                black_box(&n1),
                black_box(&kp1),
            )
            .unwrap()
        })
    });

    // Setup for aggregate (need real shares from multiple participants)
    // We need kp2 for user 2
    let mut r1_pkgs_for_s2 = BTreeMap::new();
    r1_pkgs_for_s2.insert(s1.identifier.clone(), p1.clone());
    r1_pkgs_for_s2.insert(s3.identifier.clone(), p3.clone());
    let (s2_r2, _) = dkg_part2(&s2, &r1_pkgs_for_s2, &[]).unwrap();
    
    // We need shares from s1 and s3 for s2
    let (_, s1_shares) = dkg_part2(&s1, &r1_pkgs_for_s1, &[]).unwrap();
    let (_, s3_shares_for_s2) = dkg_part2(&s3, &{
        let mut m = BTreeMap::new();
        m.insert(s1.identifier.clone(), p1.clone());
        m.insert(s2.identifier.clone(), p2.clone());
        m
    }, &[]).unwrap();

    let mut shares_for_s2 = BTreeMap::new();
    shares_for_s2.insert(s1.identifier.clone(), s1_shares.get(&s2.identifier).unwrap().clone());
    shares_for_s2.insert(s3.identifier.clone(), s3_shares_for_s2.get(&s2.identifier).unwrap().clone());

    let (kp2, _) = dkg_part3(&s2, &s2_r2, &r1_pkgs_for_s2, &shares_for_s2, &[]).unwrap();

    let share1 = sign(&pkg, &n1, &kp1).unwrap();
    let share2 = sign(&pkg, &n2, &kp2).unwrap();

    let mut shares = BTreeMap::new();
    shares.insert(s1.identifier.clone(), share1);
    shares.insert(s2.identifier.clone(), share2);

    c.bench_function("aggregate", |b| {
        b.iter(|| {
            aggregate(
                black_box(&pkg),
                black_box(&shares),
                black_box(&pkp),
            )
            .unwrap()
        })
    });
}

criterion_group!(benches, bench_dkg, bench_signing);
criterion_main!(benches);
