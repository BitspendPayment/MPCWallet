//! Enrolment is where a service decides whether to believe a share. Everything here is about
//! what it refuses.

use std::collections::BTreeMap;

use service_sdk::enrollment::{self, EnrollmentBundle};
use service_sdk::share::{FileShareStore, ShareStore};
use service_sdk::{Error, ServiceIdentity};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage, VerifyingKey};
use threshold::{dkg, ecies, point, scalar};

const MIN_SIGNERS: usize = 2;

fn rand_scalar() -> k256::Scalar {
    threshold::random::mod_n_random(&mut rand::rngs::OsRng)
}

struct Wallet {
    wallet_id: Identifier,
    cosigner_id: Identifier,
    wallet_kp: KeyPackage,
    cosigner_kp: KeyPackage,
}

/// A dealer-dealt 2-of-2 wallet.
fn deal_wallet() -> Wallet {
    let secret = rand_scalar();
    let slope = rand_scalar();
    let wallet_id = Identifier::from_u16(1).unwrap();
    let cosigner_id = Identifier::from_u16(2).unwrap();
    let vk = VerifyingKey::new(point::base_mul(&secret));

    let eval = |id: &Identifier| secret + slope * *id.to_scalar();
    let mk = |id: &Identifier| {
        let s = eval(id);
        KeyPackage {
            identifier: id.clone(),
            secret_share: s,
            verifying_share: point::base_mul(&s),
            verifying_key: vk.clone(),
            min_signers: MIN_SIGNERS,
        }
    };
    Wallet {
        wallet_id: wallet_id.clone(),
        cosigner_id: cosigner_id.clone(),
        wallet_kp: mk(&wallet_id),
        cosigner_kp: mk(&cosigner_id),
    }
}

/// Run the real wallet + cosigner enrolment and produce the bundle the wallet would relay.
fn enroll_bundle(w: &Wallet, identity: &ServiceIdentity) -> EnrollmentBundle {
    let mut rng = rand::rngs::OsRng;
    let service_id = identity.identifier().clone();

    let dealt = dkg::refresh_to_ids(
        &w.wallet_kp,
        &[w.wallet_id.clone(), w.cosigner_id.clone()],
        &[service_id.clone(), w.cosigner_id.clone()],
        MIN_SIGNERS,
        &mut rng,
    );
    let a_at_service = dealt[&service_id];

    let mut partial = BTreeMap::new();
    partial.insert(
        w.wallet_id.clone(),
        scalar::scalar_to_bytes(&dealt[&w.cosigner_id]),
    );
    let pairing = dkg::refresh_to_receiver(
        &w.cosigner_kp,
        &dkg::Receiver {
            id: service_id.clone(),
            partial_verifying_share: point::serialize_compressed(&point::base_mul(&a_at_service)),
        },
        &partial,
        MIN_SIGNERS,
        &mut rng,
    )
    .unwrap();

    let seal = |v: [u8; 32]| {
        hex::encode(ecies::encrypt(&v, identity.id(), &mut rand::rngs::OsRng).unwrap())
    };

    EnrollmentBundle {
        // The pairing shares the wallet's group key; a stand-in is fine here since these tests
        // never dial a cosigner.
        pairing_group_key: "wallet-group-key".into(),
        pairing_public_key_package_json: pairing.pairing_pkp.to_json(),
        ecies_a_at_service: seal(scalar::scalar_to_bytes(&a_at_service)),
        ecies_b_at_service: seal(pairing.receiver_half),
    }
}

// ---------------------------------------------------------------------------

#[test]
fn a_well_formed_bundle_yields_a_usable_share() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let bundle = enroll_bundle(&w, &identity);

    let share = enrollment::verify(&identity, &bundle).expect("bundle must verify");

    // The rebuilt key package really does hold the share the pairing publishes.
    let kp = share.key_package().unwrap();
    let pkp = share.pairing_pkp().unwrap();
    assert!(point::points_equal(
        &kp.verifying_share,
        &pkp.verifying_shares[identity.identifier()]
    ));
    assert_eq!(kp.min_signers, MIN_SIGNERS);
}


#[test]
fn halves_that_do_not_sum_to_the_published_share_are_refused() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let mut bundle = enroll_bundle(&w, &identity);

    // Swap one half for a different scalar sealed to the same service.
    bundle.ecies_a_at_service = hex::encode(
        ecies::encrypt(
            &scalar::scalar_to_bytes(&rand_scalar()),
            identity.id(),
            &mut rand::rngs::OsRng,
        )
        .unwrap(),
    );

    match enrollment::verify(&identity, &bundle) {
        Err(Error::Crypto(m)) => assert!(m.contains("do not sum"), "{m}"),
        other => panic!("expected a crypto refusal, got {other:?}"),
    }
}

#[test]
fn a_half_sealed_to_someone_else_is_refused() {
    let identity = ServiceIdentity::generate().unwrap();
    let other = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let mut bundle = enroll_bundle(&w, &identity);

    bundle.ecies_b_at_service = hex::encode(
        ecies::encrypt(
            &scalar::scalar_to_bytes(&rand_scalar()),
            other.id(),
            &mut rand::rngs::OsRng,
        )
        .unwrap(),
    );

    assert!(matches!(
        enrollment::verify(&identity, &bundle),
        Err(Error::Crypto(_))
    ));
}

#[test]
fn a_pairing_without_a_share_for_this_service_is_refused() {
    let identity = ServiceIdentity::generate().unwrap();
    let stranger = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    // Enrol the OTHER service, then hand the bundle to this one.
    let bundle = enroll_bundle(&w, &stranger);

    assert!(matches!(
        enrollment::verify(&identity, &bundle),
        Err(Error::Crypto(_))
    ));
}

// ---------------------------------------------------------------------------
// The store's half of the invariant.
// ---------------------------------------------------------------------------

fn tmp_store(name: &str) -> (FileShareStore, std::path::PathBuf) {
    let mut p = std::env::temp_dir();
    let suffix = hex::encode(scalar::scalar_to_bytes(&rand_scalar()));
    p.push(format!("service-sdk-{name}-{}.json", &suffix[..16]));
    (FileShareStore::new(&p), p)
}

#[test]
fn the_store_refuses_two_secrets_under_one_verifying_share() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let bundle = enroll_bundle(&w, &identity);
    let (store, path) = tmp_store("dup");

    let share = enrollment::accept(&identity, &store, &bundle).unwrap();

    // Re-accepting the identical share is a no-op (an enrolment retry must not fail).
    enrollment::accept(&identity, &store, &bundle).expect("idempotent re-enrolment");

    // A DIFFERENT share claiming the same polynomial is the case that reconstructs the group key.
    let mut impostor = share.clone();
    impostor.secret_share_hex = hex::encode(scalar::scalar_to_bytes(&rand_scalar()));
    match store.put(&impostor) {
        Err(Error::Store(m)) => assert!(m.contains("cannot have two secrets"), "{m}"),
        other => panic!("expected a store refusal, got {other:?}"),
    }

    assert_eq!(store.list().unwrap().len(), 1);
    let _ = std::fs::remove_file(path);
}

#[test]
fn the_store_holds_shares_on_distinct_polynomials_side_by_side() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let (store, path) = tmp_store("multi");

    let a = enrollment::accept(&identity, &store, &enroll_bundle(&w, &identity)).unwrap();
    let b = enrollment::accept(&identity, &store, &enroll_bundle(&w, &identity)).unwrap();

    assert_ne!(
        a.verifying_share_hex, b.verifying_share_hex,
        "each enrolment is its own polynomial, so its own share"
    );
    assert_eq!(store.list().unwrap().len(), 2);
    assert!(store.get(&a.verifying_share_hex).unwrap().is_some());

    let _ = std::fs::remove_file(path);
}

#[test]
fn a_persisted_share_survives_a_reopen() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let bundle = enroll_bundle(&w, &identity);
    let (store, path) = tmp_store("reopen");

    let share = enrollment::accept(&identity, &store, &bundle).unwrap();
    drop(store);

    let reopened = FileShareStore::new(&path);
    let got = reopened.get(&share.verifying_share_hex).unwrap().expect("share persisted");
    assert_eq!(got.secret_share_hex, share.secret_share_hex);

    let _ = std::fs::remove_file(path);
}

#[test]
fn the_share_debug_impl_does_not_leak_the_secret() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let share = enrollment::verify(&identity, &enroll_bundle(&w, &identity)).unwrap();

    let rendered = format!("{share:?}");
    assert!(rendered.contains("<redacted>"), "{rendered}");
    assert!(!rendered.contains(&share.secret_share_hex), "{rendered}");
}

/// Sanity that the SDK and the threshold crate agree on how a pairing is put together: the pairing
/// still controls the wallet's original key, which is what makes a service transparent on-chain.
#[test]
fn the_assembled_share_still_reconstructs_the_wallet_key() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let bundle = enroll_bundle(&w, &identity);
    let share = enrollment::verify(&identity, &bundle).unwrap();

    let pkp: PublicKeyPackage = share.pairing_pkp().unwrap();
    assert!(point::points_equal(
        &pkp.verifying_key.point,
        &w.wallet_kp.verifying_key.point,
    ));
}

/// The share's on-wire identity is its verifying share, and it can prove it by signing with the
/// secret share — no separate signing key. Same convention the wallet uses for its own half.
#[test]
fn a_share_authenticates_as_its_verifying_share() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let share = enrollment::verify(&identity, &enroll_bundle(&w, &identity)).unwrap();

    let signer = share.auth_signer().unwrap();
    assert_eq!(
        hex::encode(signer.public_key_compressed()),
        share.verifying_share_hex,
        "the auth key must be the secret behind the advertised verifying share"
    );

    // And that share really is the one the pairing publishes for this service.
    let pkp = share.pairing_pkp().unwrap();
    let published = pkp.verifying_shares[identity.identifier()];
    assert_eq!(
        hex::encode(point::serialize_compressed(&published)),
        share.verifying_share_hex
    );

    // The enrolment key is NOT the signing identity — conflating them was the bug.
    assert_ne!(share.verifying_share_hex, identity.id_hex());
}

/// A signature made with the share verifies under the advertised verifying share.
#[test]
fn the_auth_signature_verifies_under_the_advertised_share() {
    let identity = ServiceIdentity::generate().unwrap();
    let w = deal_wallet();
    let share = enrollment::verify(&identity, &enroll_bundle(&w, &identity)).unwrap();

    let signer = share.auth_signer().unwrap();
    let msg = b"MPC_WALLET_AUTH_V1:SIGN_STEP1:0:test";
    let sig = signer.sign(msg);

    let pk = signer.public_key_compressed();
    assert!(
        threshold::auth::verify_schnorr_signature(&pk, msg, &sig),
        "the cosigner must be able to verify this against the share it has on file"
    );
}

/// A CONSTANT pairing polynomial hands the service `v` itself — enough to sign alone, without the
/// cosigner. It takes a broken CSPRNG to produce (the user cannot force a cancellation of a slope
/// half it has not seen), but the failure is total, so enrolment refuses it outright.
#[test]
fn a_share_equal_to_the_group_key_is_refused() {
    let identity = ServiceIdentity::generate().unwrap();
    let secret = rand_scalar();
    let vk = VerifyingKey::new(point::base_mul(&secret));
    let service_id = identity.identifier().clone();

    // f(t) = v, so every point on it — the service's included — is the group secret.
    let mut shares = BTreeMap::new();
    shares.insert(service_id, vk.point);
    shares.insert(Identifier::from_u16(2).unwrap(), vk.point);
    let pkp = PublicKeyPackage {
        verifying_shares: shares,
        verifying_key: vk,
    };

    // Split `v` into two halves so the sum check passes and only the degeneracy check can fire.
    let half = rand_scalar();
    let other = secret - half;
    let seal = |v: k256::Scalar| {
        hex::encode(
            ecies::encrypt(
                &scalar::scalar_to_bytes(&v),
                identity.id(),
                &mut rand::rngs::OsRng,
            )
            .unwrap(),
        )
    };

    let bundle = EnrollmentBundle {
        pairing_group_key: "wallet-group-key".into(),
        pairing_public_key_package_json: pkp.to_json(),
        ecies_a_at_service: seal(half),
        ecies_b_at_service: seal(other),
    };

    match enrollment::verify(&identity, &bundle) {
        Err(Error::Invariant(m)) => assert!(m.contains("could sign alone"), "{m}"),
        other => panic!("a share equal to the group key must be refused, got {other:?}"),
    }
}
