// Shared test helpers: each integration binary compiles this module and uses only part of it.
#![allow(dead_code)]

//! Shared setup for the integration tests. Builds `SharedServices` against the local dev stack.
//!
//! Redis is required (persistence backend); the ASP channel is created lazily, so a reachable
//! arkd is NOT needed for paths that never issue an ASP RPC (FROST signing, policy seal, DKG
//! onboarding bookkeeping). `try_shared` returns `None` — with a skip notice — only when Redis
//! is unreachable, so these tests skip cleanly when run off-stack.

use std::collections::BTreeMap;
use std::sync::Arc;

use rand::rngs::OsRng;

use cosigner_runtime::auth::session::SessionAuthority;
use cosigner_runtime::cosigner::command::CosignerCommand;
use cosigner_runtime::cosigner::registry::CosignerRegistry;
use cosigner_runtime::resp_store::RespStore;
use cosigner_runtime::shared::SharedServices;

use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::random;

pub async fn try_shared() -> Option<Arc<SharedServices>> {
    // Default matches the dev stack in `docker-compose.ark.yml` (`--requirepass testpass`; the
    // username is ignored — connect as the `default` user). Override with `REDIS_URL`.
    let redis_url = std::env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://:testpass@127.0.0.1:6379".to_string());
    let asp_url = std::env::var("ASP_URL").unwrap_or_else(|_| "http://127.0.0.1:7070".to_string());

    let store = match RespStore::connect(&redis_url).await {
        Ok(s) => Arc::new(s),
        Err(e) => {
            eprintln!("skip: Redis unreachable at {redis_url}: {e:?}");
            return None;
        }
    };
    let asp = match ark::client::AspClient::connect_lazy(&asp_url) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("skip: invalid ASP url {asp_url}: {e:?}");
            return None;
        }
    };
    Some(Arc::new(SharedServices::new(
        store,
        asp,
        None, // fcm
        1800, // auto_settle_safety_margin_secs
        1800, // actor_idle_threshold_secs
        Arc::new(SessionAuthority::from_secret_hex("")),
    )))
}

/// Host-side 2-of-2 DKG; even-Y-normalized outputs. Index 0 = user/client, 1 = cosigner/server.
/// The actor no longer performs DKG, so tests mint the key material themselves.
pub fn dkg_2of2() -> (Vec<KeyPackage>, PublicKeyPackage) {
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

/// Seed a wallet's policy into its actor: installs the cosigner key package + group PKP, supplies
/// the Ark cosigner secret, and seals it.
pub async fn seed_policy(
    registry: &Arc<CosignerRegistry>,
    group_key: &str,
    kp_cosigner: &KeyPackage,
    kp_user: &KeyPackage,
    pkp: &PublicKeyPackage,
    ark_cosigner_secret_hex: Option<String>,
) {
    registry
        .dispatch(group_key, |reply| CosignerCommand::SeedPolicy {
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: ark_cosigner_secret_hex,
            contract_pairing: None,
            reply,
        })
        .await
        .expect("seed policy");
}
