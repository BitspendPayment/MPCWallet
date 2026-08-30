//! Delivery: two dealers push independently, and the service assembles when both land.

use std::collections::BTreeMap;

use service_sdk::intake::{EnrollmentHalf, EnrollmentInbox, HalfRole, Intake};
use service_sdk::share::{FileShareStore, ShareStore};
use service_sdk::{Error, ServiceIdentity};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, VerifyingKey};
use threshold::{dkg, ecies, point, scalar};

const MIN_SIGNERS: usize = 2;

fn rand_scalar() -> k256::Scalar {
    threshold::random::mod_n_random(&mut rand::rngs::OsRng)
}

struct Enrolment {
    group_key: String,
    verifying_share: String,
    pkp_json: String,
    ecies_a: String,
    ecies_b: String,
}

/// Run a real refresh and produce what each dealer would push.
fn deal(identity: &ServiceIdentity) -> Enrolment {
    let mut rng = rand::rngs::OsRng;
    let secret = rand_scalar();
    let slope = rand_scalar();
    let wallet_id = Identifier::from_u16(1).unwrap();
    let cosigner_id = Identifier::from_u16(2).unwrap();
    let vk = VerifyingKey::new(point::base_mul(&secret));
    let mk = |id: &Identifier| {
        let s = secret + slope * *id.to_scalar();
        KeyPackage {
            identifier: id.clone(),
            secret_share: s,
            verifying_share: point::base_mul(&s),
            verifying_key: vk.clone(),
            min_signers: MIN_SIGNERS,
        }
    };
    let (kp_user, kp_cosigner) = (mk(&wallet_id), mk(&cosigner_id));
    let service_id = identity.identifier().clone();

    let dealt = dkg::refresh_to_ids(
        &kp_user,
        &[wallet_id.clone(), cosigner_id.clone()],
        &[service_id.clone(), cosigner_id.clone()],
        MIN_SIGNERS,
        &mut rng,
    );
    let a_at_service = dealt[&service_id];
    let mut partial = BTreeMap::new();
    partial.insert(wallet_id, scalar::scalar_to_bytes(&dealt[&cosigner_id]));
    let pairing = dkg::refresh_to_receiver(
        &kp_cosigner,
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
    let vs = pairing.pairing_pkp.verifying_shares[&service_id];

    Enrolment {
        group_key: hex::encode(vk.serialize()),
        verifying_share: hex::encode(point::serialize_compressed(&vs)),
        pkp_json: pairing.pairing_pkp.to_json(),
        ecies_a: seal(scalar::scalar_to_bytes(&a_at_service)),
        ecies_b: seal(pairing.receiver_half),
    }
}

fn half(e: &Enrolment, role: HalfRole) -> EnrollmentHalf {
    EnrollmentHalf {
        role,
        pairing_group_key: e.group_key.clone(),
        service_verifying_share: e.verifying_share.clone(),
        pairing_public_key_package_json: e.pkp_json.clone(),
        ecies_half: match role {
            HalfRole::User => e.ecies_a.clone(),
            HalfRole::Cosigner => e.ecies_b.clone(),
        },
    }
}

fn tmp_store(name: &str) -> (FileShareStore, std::path::PathBuf) {
    let mut p = std::env::temp_dir();
    let suffix = hex::encode(scalar::scalar_to_bytes(&rand_scalar()));
    p.push(format!("service-sdk-intake-{name}-{}.json", &suffix[..16]));
    (FileShareStore::new(&p), p)
}

// ---------------------------------------------------------------------------

#[test]
fn either_dealer_may_arrive_first() {
    for first in [HalfRole::User, HalfRole::Cosigner] {
        let identity = ServiceIdentity::generate().unwrap();
        let e = deal(&identity);
        let (store, path) = tmp_store("order");
        let inbox = EnrollmentInbox::new([e.group_key.clone()]);

        let second = match first {
            HalfRole::User => HalfRole::Cosigner,
            HalfRole::Cosigner => HalfRole::User,
        };

        let r1 = inbox.accept(&identity, &store, &half(&e, first)).unwrap();
        assert!(
            matches!(r1, Intake::AwaitingOther(r) if r == second),
            "first half must stage, got {r1:?}"
        );
        assert_eq!(inbox.pending_count(), 1);

        let r2 = inbox.accept(&identity, &store, &half(&e, second)).unwrap();
        let share = r2.share().expect("the pair completes the enrolment");
        assert_eq!(share.verifying_share_hex, e.verifying_share);
        assert_eq!(inbox.pending_count(), 0, "a completed pairing is not left staged");
        assert!(store.get(&e.verifying_share).unwrap().is_some());

        let _ = std::fs::remove_file(path);
    }
}

#[test]
fn a_redelivered_half_does_not_re_enrol() {
    let identity = ServiceIdentity::generate().unwrap();
    let e = deal(&identity);
    let (store, path) = tmp_store("redeliver");
    let inbox = EnrollmentInbox::new([e.group_key.clone()]);

    inbox.accept(&identity, &store, &half(&e, HalfRole::User)).unwrap();
    assert!(inbox
        .accept(&identity, &store, &half(&e, HalfRole::Cosigner))
        .unwrap()
        .is_enrolled());

    // Dealers retry; that must be a no-op rather than a second enrolment or an error.
    for role in [HalfRole::User, HalfRole::Cosigner] {
        let again = inbox.accept(&identity, &store, &half(&e, role)).unwrap();
        assert!(matches!(again, Intake::AlreadyEnrolled), "got {again:?}");
    }
    assert_eq!(store.list().unwrap().len(), 1);

    let _ = std::fs::remove_file(path);
}

#[test]
fn a_wallet_outside_the_allowlist_is_refused() {
    let identity = ServiceIdentity::generate().unwrap();
    let e = deal(&identity);
    let (store, path) = tmp_store("allowlist");

    // This is the load-bearing check on this endpoint: without it a stranger could push a
    // self-consistent pairing for a key of their choosing and the service would hold a share of it.
    let inbox = EnrollmentInbox::new(["some-other-wallet".to_string()]);
    match inbox.accept(&identity, &store, &half(&e, HalfRole::User)) {
        Err(Error::Config(m)) => assert!(m.contains("allowlist"), "{m}"),
        other => panic!("expected an allowlist refusal, got {other:?}"),
    }

    let _ = std::fs::remove_file(path);
}

#[test]
fn an_empty_allowlist_accepts_nothing() {
    let identity = ServiceIdentity::generate().unwrap();
    let e = deal(&identity);
    let (store, path) = tmp_store("empty");
    let inbox = EnrollmentInbox::new([]);
    assert!(inbox.accept(&identity, &store, &half(&e, HalfRole::User)).is_err());
    let _ = std::fs::remove_file(path);
}

#[test]
fn dealers_disagreeing_about_the_pairing_package_are_both_refused() {
    let identity = ServiceIdentity::generate().unwrap();
    let e = deal(&identity);
    let other = deal(&identity); // a different pairing entirely
    let (store, path) = tmp_store("disagree");
    let inbox = EnrollmentInbox::new([e.group_key.clone(), other.group_key.clone()]);

    inbox.accept(&identity, &store, &half(&e, HalfRole::User)).unwrap();

    // Same correlation key, different package. There is no way to tell which dealer is lying, so
    // neither half survives.
    let mut poisoned = half(&other, HalfRole::Cosigner);
    poisoned.service_verifying_share = e.verifying_share.clone();
    poisoned.pairing_group_key = e.group_key.clone();
    match inbox.accept(&identity, &store, &poisoned) {
        Err(Error::Crypto(m)) => assert!(m.contains("not this service's share"), "{m}"),
        Err(Error::Invariant(m)) => assert!(m.contains("different pairing packages"), "{m}"),
        other => panic!("expected a refusal, got {other:?}"),
    }

    let _ = std::fs::remove_file(path);
}

#[test]
fn a_half_naming_someone_elses_verifying_share_is_refused() {
    let identity = ServiceIdentity::generate().unwrap();
    let e = deal(&identity);
    let (store, path) = tmp_store("wrongshare");
    let inbox = EnrollmentInbox::new([e.group_key.clone()]);

    let mut wrong = half(&e, HalfRole::User);
    wrong.service_verifying_share = "02".to_string() + &"11".repeat(32);
    match inbox.accept(&identity, &store, &wrong) {
        Err(Error::Crypto(m)) => assert!(m.contains("not this service's share"), "{m}"),
        other => panic!("expected a refusal, got {other:?}"),
    }

    let _ = std::fs::remove_file(path);
}

/// A forged half fails on the arithmetic, not on who sent it — which is why this endpoint does not
/// need sender authentication to be correct.
#[test]
fn a_forged_half_dies_on_the_sum_check() {
    let identity = ServiceIdentity::generate().unwrap();
    let e = deal(&identity);
    let (store, path) = tmp_store("forged");
    let inbox = EnrollmentInbox::new([e.group_key.clone()]);

    let mut forged = half(&e, HalfRole::User);
    forged.ecies_half = hex::encode(
        ecies::encrypt(
            &scalar::scalar_to_bytes(&rand_scalar()),
            identity.id(),
            &mut rand::rngs::OsRng,
        )
        .unwrap(),
    );

    inbox.accept(&identity, &store, &forged).unwrap();
    match inbox.accept(&identity, &store, &half(&e, HalfRole::Cosigner)) {
        Err(Error::Crypto(m)) => assert!(m.contains("do not sum"), "{m}"),
        other => panic!("expected the sum check to fire, got {other:?}"),
    }
    assert!(store.list().unwrap().is_empty());

    let _ = std::fs::remove_file(path);
}

#[test]
fn two_services_enrol_independently_without_interfering() {
    let identity = ServiceIdentity::generate().unwrap();
    let a = deal(&identity);
    let b = deal(&identity);
    let (store, path) = tmp_store("two");
    let inbox = EnrollmentInbox::new([a.group_key.clone(), b.group_key.clone()]);

    // Interleaved delivery — the staging key keeps them apart.
    inbox.accept(&identity, &store, &half(&a, HalfRole::User)).unwrap();
    inbox.accept(&identity, &store, &half(&b, HalfRole::Cosigner)).unwrap();
    assert_eq!(inbox.pending_count(), 2);

    assert!(inbox.accept(&identity, &store, &half(&b, HalfRole::User)).unwrap().is_enrolled());
    assert!(inbox.accept(&identity, &store, &half(&a, HalfRole::Cosigner)).unwrap().is_enrolled());

    assert_eq!(store.list().unwrap().len(), 2);
    assert_eq!(inbox.pending_count(), 0);

    let _ = std::fs::remove_file(path);
}
