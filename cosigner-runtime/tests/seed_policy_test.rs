//! Plan A foundation: `SeedPolicy` installs freshly-computed key material into the per-user
//! actor and seals it into the actor snapshot — with NO plaintext policy in persistence. Proves
//! the actor owns the keys via the seed path alone (a `sealed_state` blob appears; nothing is
//! written to a plaintext `policies` tree), which is what lets later cold spawns restore keys
//! without the host keeping a plaintext signing key.
//!
//! Integration test: needs Redis (persistence). The ASP channel is lazy and never used here.

mod common;

use std::collections::BTreeMap;

use rand::rngs::OsRng;

use cosigner_runtime::cosigner::command::CosignerCommand;
use cosigner_runtime::cosigner::registry::CosignerRegistry;

use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::random;

/// Host-side 2-of-2 DKG; even-Y-normalized outputs. Index 0 = user, 1 = cosigner.
fn dkg_2of2() -> (Vec<KeyPackage>, PublicKeyPackage) {
    let mut rng = OsRng;
    let (min, max) = (2usize, 2usize);

    let mut r1_secrets = Vec::new();
    let mut r1_packages: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
    for _ in 0..max {
        let secret = random::mod_n_random(&mut rng);
        let coefficients: Vec<_> = (0..min - 1)
            .map(|_| random::mod_n_random(&mut rng))
            .collect();
        let (secret_pkg, pub_pkg) =
            dkg::dkg_part1(max, min, &secret, &coefficients, &mut rng).expect("dkg_part1");
        r1_packages.insert(secret_pkg.identifier.clone(), pub_pkg);
        r1_secrets.push(secret_pkg);
    }

    let mut r2_secrets = Vec::new();
    let mut all_r2: Vec<BTreeMap<Identifier, Round2Package>> = Vec::new();
    for secret_pkg in &r1_secrets {
        let others: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != secret_pkg.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let (r2_secret, r2_out) = dkg::dkg_part2(secret_pkg, &others, &[]).expect("dkg_part2");
        r2_secrets.push(r2_secret);
        all_r2.push(r2_out);
    }

    let mut key_packages = Vec::new();
    let mut pkp_out: Option<PublicKeyPackage> = None;
    for (i, r2_secret) in r2_secrets.iter().enumerate() {
        let others_r1: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != r2_secret.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let mut our_r2: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
        for (j, r2_pkgs) in all_r2.iter().enumerate() {
            if j == i {
                continue;
            }
            if let Some(pkg) = r2_pkgs.get(&r2_secret.identifier) {
                our_r2.insert(r1_secrets[j].identifier.clone(), pkg.clone());
            }
        }
        let (kp, pkp) =
            dkg::dkg_part3(&r1_secrets[i], r2_secret, &others_r1, &our_r2, &[]).expect("dkg_part3");
        key_packages.push(kp.into_even_y());
        pkp_out = Some(pkp.into_even_y());
    }

    (key_packages, pkp_out.unwrap())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn seed_policy_installs_and_seals_without_plaintext() {
    let Some(shared) = common::try_shared().await else {
        return;
    };

    let (kps, pkp) = dkg_2of2();
    let kp_user = &kps[0];
    let kp_cosigner = &kps[1];
    let group_key = hex::encode(pkp.verifying_key.serialize());

    let registry = CosignerRegistry::new(shared.clone()).unwrap();

    // Seed via the actor command — note we never write the `policies` tree.
    let res: Result<(), _> = registry
        .dispatch(&group_key, |reply| CosignerCommand::SeedPolicy {
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: None,
            contract_pairing: None,
            reply,
        })
        .await;
    assert!(res.is_ok(), "SeedPolicy failed: {res:?}");

    // The actor sealed its state ⇒ a sealed_state blob exists for the group key.
    let blob = shared.persistence.get("sealed_state", &group_key).unwrap();
    assert!(blob.is_some(), "expected a sealed_state blob after SeedPolicy");

    // …and no plaintext policy was written/needed — the actor owns the keys.
    let plaintext = shared.persistence.get("policies", &group_key).unwrap();
    assert!(
        plaintext.is_none(),
        "SeedPolicy must not require a plaintext policy in the `policies` tree"
    );

    // Clean up the dev-Redis key this test wrote.
    let _ = shared.persistence.delete("sealed_state", &group_key);
}
