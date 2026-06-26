//! Phase T3 verification: the native-async `cosigner-guest` component answers commands
//! through its async `handle` export (no stdio/framing), with state persisting in the
//! instance across calls. Covers a Ping round-trip and a full 2-of-2 FROST sign whose
//! aggregated signature verifies under the group key — the same guarantee the earlier
//! stdio-transport `stream_sign_test` gave, now on the native-async transport.

use std::collections::BTreeMap;
use std::path::PathBuf;

use rand::rngs::OsRng;
use wasmtime::component::Component;

use cosigner_proto::{GuestCommand, GuestResponse, SignStep1Wire, SignStep2Wire};
use cosigner_runtime::auth::message::{build_auth_message, OP_SIGN_STEP1, OP_SIGN_STEP2};
use cosigner_runtime::cosigner::guest_instance::{self, GuestInstance};

use threshold::auth::AuthSigner;
use threshold::commitment::SigningPackage;
use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::nonce::{self, SigningCommitments};
use threshold::point;
use threshold::scalar::{scalar_from_bytes, scalar_to_bytes};
use threshold::signature::Signature;
use threshold::{random, signing};

fn guest_wasm_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip2/release/cosigner.wasm")
}

fn now_ms() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64
}

async fn spawn_guest() -> Option<GuestInstance> {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest component not found at {wasm:?}; build it first. Skipping.");
        return None;
    }
    let engine = guest_instance::build_engine().unwrap();
    let component = Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();
    Some(GuestInstance::spawn(&engine, &component, &linker, None).await.unwrap())
}

/// Host-side 2-of-2 DKG (even-Y normalized), identical to the other sign tests.
fn dkg_2of2() -> (Vec<KeyPackage>, PublicKeyPackage) {
    let mut rng = OsRng;
    let (min, max) = (2usize, 2usize);

    let mut r1_secrets = Vec::new();
    let mut r1_packages: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
    for _ in 0..max {
        let secret = random::mod_n_random(&mut rng);
        let coefficients: Vec<_> = (0..min - 1).map(|_| random::mod_n_random(&mut rng)).collect();
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
async fn ping_roundtrip() {
    let Some(mut guest) = spawn_guest().await else {
        return;
    };
    let resp = guest.command(GuestCommand::Ping).await.unwrap();
    assert!(matches!(resp, GuestResponse::Pong), "got {resp:?}");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn full_2of2_sign_via_async_handle() {
    let Some(mut guest) = spawn_guest().await else {
        return;
    };

    // 2-of-2 {user, cosigner}. Index 0 = user (client), index 1 = cosigner (guest).
    let (kps, pkp) = dkg_2of2();
    let kp_user = kps[0].clone();
    let kp_cosigner = kps[1].clone();
    let group_key = hex::encode(pkp.verifying_key.serialize());

    let auth = AuthSigner::from_secret_bytes(&scalar_to_bytes(&kp_user.secret_share)).unwrap();
    let user_id = auth.public_key_compressed().to_vec();
    let user_id_hex = hex::encode(&user_id);
    let user_identifier_hex = hex::encode(kp_user.identifier.serialize());
    let message = [0x42u8; 32];

    // Install the cosigner's policy (key material stays in the guest).
    let resp = guest
        .command(GuestCommand::InstallPolicy {
            group_key: group_key.clone(),
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(user_identifier_hex),
            server_dkg_secret_hex: None,
            contract_pairing: None,
        })
        .await
        .unwrap();
    assert!(matches!(resp, GuestResponse::PolicyInstalled), "got {resp:?}");

    // Client round 1: user nonce + commitments.
    let mut rng = OsRng;
    let user_nonce = nonce::new_nonce(&mut rng, &kp_user.secret_share);
    let ts1 = now_ms();
    let resp = guest
        .command(GuestCommand::FrostSignStep1(SignStep1Wire {
            user_id: user_id.clone(),
            hiding_commitment: point::serialize_compressed(&user_nonce.commitments.hiding).to_vec(),
            binding_commitment: point::serialize_compressed(&user_nonce.commitments.binding).to_vec(),
            message_to_sign: message.to_vec(),
            signature: auth
                .sign(&build_auth_message(OP_SIGN_STEP1, ts1, &user_id_hex))
                .to_vec(),
            full_transaction: vec![],
            timestamp_ms: ts1,
            script_path_spend: true,
            ark_tx: vec![],
        }))
        .await
        .unwrap();
    let commitments_wire = match resp {
        GuestResponse::SignStep1 { commitments, .. } => commitments,
        other => panic!("expected SignStep1, got {other:?}"),
    };

    // Client builds the signing package from the returned commitments + signs.
    let mut commitments: BTreeMap<Identifier, SigningCommitments> = BTreeMap::new();
    for c in &commitments_wire {
        let id_arr: [u8; 32] = hex::decode(&c.identifier_hex).unwrap().try_into().unwrap();
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
    let user_share = signing::sign(&signing_pkg, &user_nonce, &kp_user).expect("user share");

    // Client round 2: send the user's share; guest signs + aggregates.
    let ts2 = now_ms();
    let resp = guest
        .command(GuestCommand::FrostSignStep2(SignStep2Wire {
            user_id: user_id.clone(),
            signature_share: scalar_to_bytes(&user_share.s).to_vec(),
            signature: auth
                .sign(&build_auth_message(OP_SIGN_STEP2, ts2, &user_id_hex))
                .to_vec(),
            timestamp_ms: ts2,
        }))
        .await
        .unwrap();
    let (r_point, z_scalar) = match resp {
        GuestResponse::SignStep2 { r_point, z_scalar } => (r_point, z_scalar),
        other => panic!("expected SignStep2, got {other:?}"),
    };

    // Verify the aggregated signature under the group key.
    let r_arr: [u8; 33] = r_point.try_into().expect("R is 33 bytes");
    let z_arr: [u8; 32] = z_scalar.try_into().expect("Z is 32 bytes");
    let signature = Signature::new(
        point::deserialize_compressed(&r_arr).unwrap(),
        scalar_from_bytes(&z_arr).unwrap(),
    );
    signature
        .verify(&pkp.verifying_key, &message)
        .expect("aggregated 2-of-2 signature must verify under the group key");

    println!("full 2-of-2 sign through the native-async handle verified!");
}

/// Key-path (BIP-341 taproot) spend: `script_path_spend = false`. Both sides sign under the
/// key-path-tweaked key (`merkle_root = None`); the aggregate must verify under the TWEAKED
/// group key. This exercises the guest's tweak path — the migration of taproot key-path
/// spends off the legacy host key into the guest.
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn key_path_tweak_sign_via_guest() {
    let Some(mut guest) = spawn_guest().await else {
        return;
    };

    let (kps, pkp) = dkg_2of2();
    let kp_user = kps[0].clone();
    let kp_cosigner = kps[1].clone();
    let group_key = hex::encode(pkp.verifying_key.serialize());

    let auth = AuthSigner::from_secret_bytes(&scalar_to_bytes(&kp_user.secret_share)).unwrap();
    let user_id = auth.public_key_compressed().to_vec();
    let user_id_hex = hex::encode(&user_id);
    let user_identifier_hex = hex::encode(kp_user.identifier.serialize());
    let message = [0x42u8; 32];

    guest
        .command(GuestCommand::InstallPolicy {
            group_key: group_key.clone(),
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(user_identifier_hex),
            server_dkg_secret_hex: None,
            contract_pairing: None,
        })
        .await
        .unwrap();

    // Client tweaks its own key (key-path, merkle_root = None) — symmetric with the guest.
    let kp_user_tweaked = kp_user.tweak(None);
    let pkp_tweaked = pkp.tweak(None);

    let mut rng = OsRng;
    let user_nonce = nonce::new_nonce(&mut rng, &kp_user_tweaked.secret_share);
    let ts1 = now_ms();
    let resp = guest
        .command(GuestCommand::FrostSignStep1(SignStep1Wire {
            user_id: user_id.clone(),
            hiding_commitment: point::serialize_compressed(&user_nonce.commitments.hiding).to_vec(),
            binding_commitment: point::serialize_compressed(&user_nonce.commitments.binding).to_vec(),
            message_to_sign: message.to_vec(),
            signature: auth
                .sign(&build_auth_message(OP_SIGN_STEP1, ts1, &user_id_hex))
                .to_vec(),
            full_transaction: vec![],
            timestamp_ms: ts1,
            script_path_spend: false, // key-path → tweak
            ark_tx: vec![],
        }))
        .await
        .unwrap();
    let commitments_wire = match resp {
        GuestResponse::SignStep1 { commitments, .. } => commitments,
        other => panic!("expected SignStep1, got {other:?}"),
    };

    let mut commitments: BTreeMap<Identifier, SigningCommitments> = BTreeMap::new();
    for c in &commitments_wire {
        let id_arr: [u8; 32] = hex::decode(&c.identifier_hex).unwrap().try_into().unwrap();
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
    let user_share = signing::sign(&signing_pkg, &user_nonce, &kp_user_tweaked).expect("user share");

    let ts2 = now_ms();
    let resp = guest
        .command(GuestCommand::FrostSignStep2(SignStep2Wire {
            user_id: user_id.clone(),
            signature_share: scalar_to_bytes(&user_share.s).to_vec(),
            signature: auth
                .sign(&build_auth_message(OP_SIGN_STEP2, ts2, &user_id_hex))
                .to_vec(),
            timestamp_ms: ts2,
        }))
        .await
        .unwrap();
    let (r_point, z_scalar) = match resp {
        GuestResponse::SignStep2 { r_point, z_scalar } => (r_point, z_scalar),
        other => panic!("expected SignStep2, got {other:?}"),
    };

    let r_arr: [u8; 33] = r_point.try_into().expect("R is 33 bytes");
    let z_arr: [u8; 32] = z_scalar.try_into().expect("Z is 32 bytes");
    let signature = Signature::new(
        point::deserialize_compressed(&r_arr).unwrap(),
        scalar_from_bytes(&z_arr).unwrap(),
    );
    signature
        .verify(&pkp_tweaked.verifying_key, &message)
        .expect("key-path-tweaked 2-of-2 signature must verify under the TWEAKED group key");

    println!("key-path taproot-tweak 2-of-2 sign through the guest verified under tweaked key!");
}
