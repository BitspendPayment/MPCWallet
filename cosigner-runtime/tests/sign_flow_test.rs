//! Integration tests for the 2-of-2 cooperative sign driven through the real `CosignerRegistry`
//! actor flow (`SeedPolicy` → `SignStep1` → `SignStep2`), with the user/client half simulated
//! host-side. Covers both the warm path (seed + sign on one registry) and the cold-spawn path
//! (seed on one registry, sign on a fresh one so the actor restores its keys from the sealed
//! snapshot — exercising `to_snapshot`/`restore_snapshot` and the `SnapshotState` roundtrip).
//!
//! Needs Redis (persistence). The ASP channel is lazy and never used on the signing path.

mod common;

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use rand::rngs::OsRng;

use cosigner_runtime::auth::message::{build_auth_message, OP_SIGN_STEP1, OP_SIGN_STEP2};
use cosigner_runtime::cosigner::command::CosignerCommand;
use cosigner_runtime::cosigner::registry::CosignerRegistry;
use cosigner_runtime::wallet_proto::{SignStep1Request, SignStep2Request};

use threshold::auth::AuthSigner;
use threshold::commitment::SigningPackage;
use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::nonce::{self, SigningCommitments};
use threshold::point;
use threshold::random;
use threshold::scalar::{scalar_from_bytes, scalar_to_bytes};
use threshold::signature::Signature;
use threshold::signing;

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64
}

/// Host-side 2-of-2 DKG (the actor no longer does DKG); even-Y-normalized outputs.
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

/// Seed the cosigner's policy into its actor: installs the key package + group PKP and seals it.
async fn seed_policy(
    registry: &Arc<CosignerRegistry>,
    group_key: &str,
    kp_cosigner: &KeyPackage,
    kp_user: &KeyPackage,
    pkp: &PublicKeyPackage,
) {
    registry
        .dispatch(group_key, |reply| CosignerCommand::SeedPolicy {
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: None,
            contract_pairing: None,
            reply,
        })
        .await
        .expect("seed policy");
}

/// The client half of a cooperative sign against `registry`'s actor for `group_key`: drives
/// `SignStep1` → `SignStep2` and asserts the aggregated signature verifies under `pkp`.
async fn cooperative_sign_and_verify(
    registry: &Arc<CosignerRegistry>,
    group_key: &str,
    kp_user: &KeyPackage,
    pkp: &PublicKeyPackage,
) {
    // The user authenticates by signing auth messages with its FROST secret share (auth is
    // verified at the REST boundary, not in the actor — supplied here for faithfulness).
    let auth = AuthSigner::from_secret_bytes(&scalar_to_bytes(&kp_user.secret_share)).unwrap();
    let user_id = auth.public_key_compressed().to_vec();
    let user_id_hex = hex::encode(&user_id);

    let message = [0x42u8; 32];

    // --- Client: round 1 — generate the user's nonce + commitments. ---
    let mut rng = OsRng;
    let user_nonce = nonce::new_nonce(&mut rng, &kp_user.secret_share);
    let hiding = point::serialize_compressed(&user_nonce.commitments.hiding).to_vec();
    let binding = point::serialize_compressed(&user_nonce.commitments.binding).to_vec();

    let ts1 = now_ms();
    let req1 = SignStep1Request {
        user_id: user_id.clone(),
        hiding_commitment: hiding,
        binding_commitment: binding,
        message_to_sign: message.to_vec(),
        signature: auth
            .sign(&build_auth_message(OP_SIGN_STEP1, ts1, &user_id_hex))
            .to_vec(),
        full_transaction: vec![],
        timestamp_ms: ts1,
        script_path_spend: true, // raw FROST (no taproot tweak)
        ark_tx: vec![],
    };
    let resp1 = registry
        .dispatch(group_key, |reply| CosignerCommand::SignStep1 { req: req1, reply })
        .await
        .expect("sign_step1");

    // --- Client: build the signing package from the returned commitments + sign. ---
    let mut commitments: BTreeMap<Identifier, SigningCommitments> = BTreeMap::new();
    for (id_hex, c) in &resp1.commitments {
        let id_arr: [u8; 32] = hex::decode(id_hex).unwrap().try_into().unwrap();
        let id = Identifier::deserialize(&id_arr).unwrap();
        let h: [u8; 33] = c.hiding.clone().try_into().unwrap();
        let b: [u8; 33] = c.binding.clone().try_into().unwrap();
        commitments.insert(
            id,
            SigningCommitments {
                hiding: point::deserialize_compressed(&h).unwrap(),
                binding: point::deserialize_compressed(&b).unwrap(),
            },
        );
    }
    let signing_pkg = SigningPackage::new(commitments, message.to_vec());
    let user_share = signing::sign(&signing_pkg, &user_nonce, kp_user).expect("user share");

    // --- Client: round 2 — send the user's share; the cosigner signs + aggregates. ---
    let ts2 = now_ms();
    let req2 = SignStep2Request {
        user_id: user_id.clone(),
        signature_share: scalar_to_bytes(&user_share.s).to_vec(),
        signature: auth
            .sign(&build_auth_message(OP_SIGN_STEP2, ts2, &user_id_hex))
            .to_vec(),
        timestamp_ms: ts2,
    };
    let resp2 = registry
        .dispatch(group_key, |reply| CosignerCommand::SignStep2 { req: req2, reply })
        .await
        .expect("sign_step2");

    // --- Verify the aggregated signature under the group key. ---
    let r_arr: [u8; 33] = resp2.r_point.try_into().expect("R is 33 bytes");
    let z_arr: [u8; 32] = resp2.z_scalar.try_into().expect("Z is 32 bytes");
    let signature = Signature::new(
        point::deserialize_compressed(&r_arr).unwrap(),
        scalar_from_bytes(&z_arr).unwrap(),
    );
    signature
        .verify(&pkp.verifying_key, &message)
        .expect("aggregated 2-of-2 signature must verify under the group key");
}

/// Warm path: seed + sign on the same registry (the actor stays alive between commands).
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn full_2of2_sign_via_registry() {
    let Some(shared) = common::try_shared().await else {
        return;
    };

    // 2-of-2 {user, cosigner} key. Index 0 = user (client), index 1 = cosigner (server).
    let (kps, pkp) = dkg_2of2();
    let group_key = hex::encode(pkp.verifying_key.serialize());

    let registry = CosignerRegistry::new(shared.clone()).unwrap();
    seed_policy(&registry, &group_key, &kps[1], &kps[0], &pkp).await;
    cooperative_sign_and_verify(&registry, &group_key, &kps[0], &pkp).await;

    let _ = shared.persistence.delete("sealed_state", &group_key);
    println!("full 2-of-2 sign via CosignerRegistry verified!");
}

/// Cold-spawn path: seed + seal on registry A, then sign on a FRESH registry B (no in-memory
/// actor) so the actor cold-spawns and restores its key material from the sealed snapshot. This
/// exercises `restore_snapshot` + the `SnapshotState` roundtrip end-to-end.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn cold_spawn_restores_seal_and_signs() {
    let Some(shared) = common::try_shared().await else {
        return;
    };

    let (kps, pkp) = dkg_2of2();
    let group_key = hex::encode(pkp.verifying_key.serialize());

    // Seed + seal on registry A, then drop it so no live actor survives.
    let registry_a = CosignerRegistry::new(shared.clone()).unwrap();
    seed_policy(&registry_a, &group_key, &kps[1], &kps[0], &pkp).await;
    drop(registry_a);

    // Registry B has no in-memory actor: the first SignStep1 must cold-spawn it and restore its
    // policy + keys from the sealed snapshot before it can sign.
    let registry_b = CosignerRegistry::new(shared.clone()).unwrap();
    cooperative_sign_and_verify(&registry_b, &group_key, &kps[0], &pkp).await;

    let _ = shared.persistence.delete("sealed_state", &group_key);
    println!("cold-spawn restore-from-seal + 2-of-2 sign verified!");
}
