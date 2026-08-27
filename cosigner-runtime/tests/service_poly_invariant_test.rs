//! The service-share invariant, enforced at the cosigner.
//!
//! A key-preserving refresh leaves the constant term at `V`, so at `min_signers = 2` every
//! service polynomial is a line and IS its slope. Two services minted on one slope hold two
//! points on that line and interpolate `V` — the break is demonstrated directly in
//! `crates/threshold/tests/service_poly_test.rs`. These tests cover the runtime's side: the
//! cosigner verifies the user's dealt contribution before building on it, files the pairing under
//! the verifying share taken from the package it built, and lets the wallet enumerate and revoke.
//!
//! Distinctness is not tracked anywhere and needs no id: the cosigner's half of the slope is fresh
//! `OsRng` per enrolment, so two enrolments collide only if the OS CSPRNG repeats — at which point
//! FROST nonce reuse has already broken the wallet.

mod common;

use std::collections::BTreeMap;

use cosigner_runtime::cosigner::command::CosignerCommand;
use cosigner_runtime::cosigner::registry::CosignerRegistry;
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::{dkg, point, service_poly};

const MIN_SIGNERS: usize = 2;

/// The user's half of an enrollment: deal a refresh contribution onto `{service, cosigner}`.
fn user_deals(
    kp_user: &KeyPackage,
    cosigner_id: &Identifier,
    frost_id: &Identifier,
) -> (Vec<u8>, Vec<u8>) {
    let dealt = dkg::refresh_to_ids(
        kp_user,
        &[kp_user.identifier.clone(), cosigner_id.clone()],
        &[frost_id.clone(), cosigner_id.clone()],
        MIN_SIGNERS,
        &mut rand::rngs::OsRng,
    );
    let a_at_service_point = point::serialize_compressed(&point::base_mul(&dealt[frost_id]));
    let a_at_cosigner = threshold::scalar::scalar_to_bytes(&dealt[cosigner_id]);
    (a_at_service_point.to_vec(), a_at_cosigner.to_vec())
}

/// A coarse but valid ceiling; these tests are about routing and key selection, not the policy.
fn test_policy() -> cosigner_runtime::cosigner::types::ServicePolicy {
    cosigner_runtime::cosigner::types::ServicePolicy {
        allowed_destinations: vec!["0014000102030405060708090a0b0c0d0e0f10111213".into()],
        max_sats_per_signature: 100_000,
    }
}

/// A service's identity (`service_id`). Only used to seal its half and derive its FROST
/// identifier — the signing identity is the verifying share the enrolment returns.
fn service_id_for(label: &[u8]) -> [u8; 33] {
    let secret = threshold::random::mod_n_random(&mut rand::rngs::OsRng);
    let _ = label;
    point::serialize_compressed(&point::base_mul(&secret))
}

async fn enroll(
    registry: &std::sync::Arc<CosignerRegistry>,
    group_key: &str,
    kp_user: &KeyPackage,
    cosigner_id: &Identifier,
    service_label: &[u8],
) -> Result<String, tonic::Status> {
    let service_id = service_id_for(service_label);
    let frost_id = Identifier::derive(&service_id).unwrap();
    let (point_bytes, a_at_cosigner) = user_deals(kp_user, cosigner_id, &frost_id);
    let out = registry
        .dispatch(group_key, |reply| CosignerCommand::ServiceRefresh {
            receiver_id_hex: hex::encode(frost_id.serialize()),
            receiver_partial_point: point_bytes,
            wallet_id_hex: hex::encode(kp_user.identifier.serialize()),
            a_at_cosigner,
            min_signers: MIN_SIGNERS as u32,
            service_id: service_id.to_vec(),
            policy: test_policy(),
            reply,
        })
        .await?;
    Ok(out.pairing_public_key_package_json)
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn each_enrolment_gets_its_own_polynomial_under_the_same_group_key() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let (kps, pkp) = common::dkg_2of2();
    let (kp_user, kp_cosigner) = (&kps[0], &kps[1]);
    let group_key = hex::encode(pkp.verifying_key.serialize());
    let registry = CosignerRegistry::new(shared.clone()).unwrap();
    common::seed_policy(&registry, &group_key, kp_cosigner, kp_user, &pkp, None).await;

    let pkp_a = enroll(&registry, &group_key, kp_user, &kp_cosigner.identifier, b"svc-a")
        .await
        .expect("first enrollment");
    let pkp_b = enroll(&registry, &group_key, kp_user, &kp_cosigner.identifier, b"svc-b")
        .await
        .expect("second enrollment");

    // Distinct polynomials, observed where it matters: the shares themselves. Two enrolments on
    // one polynomial would put two services on one line and interpolate `V` — the cosigner's half
    // of the slope being fresh `OsRng` is what makes that not happen, and this pins it.
    let share_of = |json: &str| {
        let parsed = PublicKeyPackage::from_json(json).unwrap();
        let (_, vs) = parsed
            .verifying_shares
            .iter()
            .find(|(id, _)| *id != &kp_cosigner.identifier)
            .expect("the pairing has a service entry");
        point::serialize_compressed(vs)
    };
    assert_ne!(
        share_of(&pkp_a),
        share_of(&pkp_b),
        "fresh randomness must yield distinct polynomials, hence distinct shares"
    );

    // Both pairings still control the wallet's ORIGINAL key — the refresh is key-preserving.
    for json in [&pkp_a, &pkp_b] {
        let parsed = PublicKeyPackage::from_json(json).unwrap();
        assert!(point::points_equal(
            &parsed.verifying_key.point,
            &pkp.verifying_key.point
        ));
    }

    let _ = shared.persistence.delete("sealed_state", &group_key);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn a_tampered_service_point_is_rejected_before_any_share_is_minted() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let (kps, pkp) = common::dkg_2of2();
    let (kp_user, kp_cosigner) = (&kps[0], &kps[1]);
    let group_key = hex::encode(pkp.verifying_key.serialize());
    let registry = CosignerRegistry::new(shared.clone()).unwrap();
    common::seed_policy(&registry, &group_key, kp_cosigner, kp_user, &pkp, None).await;

    let service_id = service_id_for(b"svc-a");
    let frost_id = Identifier::derive(&service_id).unwrap();
    let (point_bytes, a_at_cosigner) = user_deals(kp_user, &kp_cosigner.identifier, &frost_id);

    // Nudge the one input the cosigner cannot otherwise check. Left unverified, this would let a
    // client steer the pairing package that everything downstream trusts.
    let tampered = point::point_add(
        &point::deserialize_compressed(&point_bytes.clone().try_into().unwrap()).unwrap(),
        &point::base_mul(&k256::Scalar::ONE),
    );

    let res = registry
        .dispatch(&group_key, |reply| CosignerCommand::ServiceRefresh {
            receiver_id_hex: hex::encode(frost_id.serialize()),
            receiver_partial_point: point::serialize_compressed(&tampered).to_vec(),
            wallet_id_hex: hex::encode(kp_user.identifier.serialize()),
            a_at_cosigner,
            min_signers: MIN_SIGNERS as u32,
            service_id: service_id.to_vec(),
            policy: test_policy(),
            reply,
        })
        .await;

    // `ServiceRefreshOutput` deliberately has no `Debug` (it carries a key package), so match
    // rather than `expect_err`.
    let err = match res {
        Ok(_) => panic!("a tampered contribution must be refused"),
        Err(status) => status.to_string(),
    };
    assert!(
        err.contains("inconsistent"),
        "expected the consistency check to fire, got: {err}"
    );

    let _ = shared.persistence.delete("sealed_state", &group_key);
}




/// Sanity: `refresh_to_ids` really does put the service and cosigner on one line through `V`,
/// which is what makes a single verifying share enough to identify the polynomial.
#[test]
fn a_pairing_is_one_line_through_the_group_key() {
    let (kps, pkp) = common::dkg_2of2();
    let (kp_user, kp_cosigner) = (&kps[0], &kps[1]);
    let service_id = Identifier::derive(b"svc-a").unwrap();
    let mut rng = rand::rngs::OsRng;

    let dealt = dkg::refresh_to_ids(
        kp_user,
        &[kp_user.identifier.clone(), kp_cosigner.identifier.clone()],
        &[service_id.clone(), kp_cosigner.identifier.clone()],
        MIN_SIGNERS,
        &mut rng,
    );
    let mut partial = BTreeMap::new();
    partial.insert(
        kp_user.identifier.clone(),
        threshold::scalar::scalar_to_bytes(&dealt[&kp_cosigner.identifier]),
    );
    let pairing = dkg::refresh_to_receiver(
        kp_cosigner,
        &dkg::Receiver {
            id: service_id.clone(),
            partial_verifying_share: point::serialize_compressed(&point::base_mul(
                &dealt[&service_id],
            )),
        },
        &partial,
        MIN_SIGNERS,
        &mut rng,
    )
    .unwrap();

    // The slope recovered from the SERVICE's share must also explain the COSIGNER's
    // counter-share — i.e. both really are points on one degree-1 line through `V`.
    // `VS_s = V + id_s·(m·G)`, so `m·G = id_s⁻¹·(VS_s − V)`.
    let vs_s = pairing.pairing_pkp.verifying_shares[&service_id];
    let id_inv: k256::Scalar =
        Option::from(service_id.to_scalar().invert()).expect("identifiers are non-zero");
    let m_g = point::point_mul(
        &point::point_add(&vs_s, &point::point_negate(&pairing.pairing_pkp.verifying_key.point)),
        &id_inv,
    );
    let expected = point::point_add(
        &pairing.pairing_pkp.verifying_key.point,
        &point::point_mul(&m_g, kp_cosigner.identifier.to_scalar()),
    );
    assert!(point::points_equal(
        &expected,
        &pairing.pairing_pkp.verifying_shares[&kp_cosigner.identifier]
    ));
    assert!(point::points_equal(
        &pairing.pairing_pkp.verifying_key.point,
        &pkp.verifying_key.point
    ));
}

// ---------------------------------------------------------------------------
// The ceiling on a service pairing.
// ---------------------------------------------------------------------------

/// A service pairing has no on-chain covenant bounding it, so `ServicePolicy` IS the ceiling.
/// These pin its fail-closed behaviour; the checks themselves run inside `sign_step1`.
mod service_policy {
    use bitcoin::{
        absolute::LockTime, transaction::Version, Amount, ScriptBuf, Transaction, TxOut,
    };
    use cosigner_runtime::cosigner::types::ServicePolicy;

    fn tx_paying(outs: &[(&str, u64)]) -> Vec<u8> {
        let tx = Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input: vec![],
            output: outs
                .iter()
                .map(|(spk, sats)| TxOut {
                    value: Amount::from_sat(*sats),
                    script_pubkey: ScriptBuf::from_hex(spk).unwrap(),
                })
                .collect(),
        };
        bitcoin::consensus::encode::serialize(&tx)
    }

    // Two distinct P2WPKH-shaped scripts.
    const DEST: &str = "0014000102030405060708090a0b0c0d0e0f10111213";
    const OTHER: &str = "0014ffeeddccbbaa99887766554433221100ffeeddcc";

    fn policy(max: u64) -> ServicePolicy {
        ServicePolicy {
            allowed_destinations: vec![DEST.to_string()],
            max_sats_per_signature: max,
        }
    }

    #[test]
    fn an_in_policy_spend_is_allowed() {
        let res = cosigner_runtime::cosigner::actor::enforce_service_policy_for_test(
            &policy(100_000),
            &tx_paying(&[(DEST, 50_000)]),
        );
        assert!(res.is_ok(), "{res:?}");
    }

    #[test]
    fn an_undeclared_destination_is_denied() {
        let err = cosigner_runtime::cosigner::actor::enforce_service_policy_for_test(
            &policy(100_000),
            &tx_paying(&[(OTHER, 1)]),
        )
        .unwrap_err();
        assert!(err.contains("not an allowed destination"), "{err}");
    }

    #[test]
    fn the_per_signature_cap_is_enforced() {
        let err = cosigner_runtime::cosigner::actor::enforce_service_policy_for_test(
            &policy(100_000),
            &tx_paying(&[(DEST, 100_001)]),
        )
        .unwrap_err();
        assert!(err.contains("exceeds the per-signature cap"), "{err}");
    }

    #[test]
    fn the_cap_applies_to_the_total_not_to_each_output() {
        let err = cosigner_runtime::cosigner::actor::enforce_service_policy_for_test(
            &policy(100_000),
            &tx_paying(&[(DEST, 60_000), (DEST, 60_000)]),
        )
        .unwrap_err();
        assert!(err.contains("exceeds the per-signature cap"), "{err}");
    }

    #[test]
    fn an_empty_allowlist_denies_everything() {
        let p = ServicePolicy {
            allowed_destinations: vec![],
            max_sats_per_signature: u64::MAX,
        };
        let err = cosigner_runtime::cosigner::actor::enforce_service_policy_for_test(
            &p,
            &tx_paying(&[(DEST, 1)]),
        )
        .unwrap_err();
        assert!(err.contains("no allowed destinations"), "{err}");
    }

    #[test]
    fn an_undecodable_transaction_denies_rather_than_passes() {
        let err = cosigner_runtime::cosigner::actor::enforce_service_policy_for_test(
            &policy(100_000),
            &[0xde, 0xad, 0xbe, 0xef],
        )
        .unwrap_err();
        assert!(err.contains("undecodable"), "{err}");
    }

    #[test]
    fn a_missing_transaction_denies() {
        let err = cosigner_runtime::cosigner::actor::enforce_service_policy_for_test(
            &policy(100_000),
            &[],
        )
        .unwrap_err();
        assert!(err.contains("full transaction is required"), "{err}");
    }
}

// ---------------------------------------------------------------------------
// The pairing map: one actor, one group key, many signers.
//
// The refresh is key-preserving, so a service shares the wallet's `V` and has no group key of its
// own. Its pairing therefore lives in the WALLET's actor, filed under the verifying share it will
// present as `user_id` — which makes routing and authorization the same lookup.
// ---------------------------------------------------------------------------

/// Enrol and return `(pairing_pkp_json, service_verifying_share_hex)`.
async fn enroll_full(
    registry: &std::sync::Arc<CosignerRegistry>,
    group_key: &str,
    kp_user: &KeyPackage,
    cosigner_id: &Identifier,
) -> (String, String) {
    let service_id = service_id_for(b"svc");
    let frost_id = Identifier::derive(&service_id).unwrap();
    let (point_bytes, a_at_cosigner) = user_deals(kp_user, cosigner_id, &frost_id);
    let out = registry
        .dispatch(group_key, move |reply| CosignerCommand::ServiceRefresh {
            receiver_id_hex: hex::encode(frost_id.serialize()),
            receiver_partial_point: point_bytes,
            wallet_id_hex: hex::encode(kp_user.identifier.serialize()),
            a_at_cosigner,
            min_signers: MIN_SIGNERS as u32,
            service_id: service_id.to_vec(),
            policy: test_policy(),
            reply,
        })
        .await
        .expect("enrolment");
    (
        out.pairing_public_key_package_json,
        out.service_verifying_share_hex,
    )
}

async fn fresh_wallet(
    shared: &std::sync::Arc<cosigner_runtime::shared::SharedServices>,
) -> (std::sync::Arc<CosignerRegistry>, String, Vec<KeyPackage>) {
    let (kps, pkp) = common::dkg_2of2();
    let group_key = hex::encode(pkp.verifying_key.serialize());
    let registry = CosignerRegistry::new(shared.clone()).unwrap();
    common::seed_policy(&registry, &group_key, &kps[1], &kps[0], &pkp, None).await;
    (registry, group_key, kps)
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn the_returned_verifying_share_is_the_one_in_the_pairing_package() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let (registry, group_key, kps) = fresh_wallet(&shared).await;

    let (pkp_json, vs_hex) = enroll_full(&registry, &group_key, &kps[0], &kps[1].identifier).await;

    // The lookup key must come from the pairing package, not from anything the caller sent —
    // otherwise a service could be filed under an identity it cannot prove it holds.
    let parsed = PublicKeyPackage::from_json(&pkp_json).unwrap();
    let matches = parsed
        .verifying_shares
        .values()
        .any(|v| hex::encode(point::serialize_compressed(v)) == vs_hex);
    assert!(matches, "{vs_hex} is not a share in the pairing package");

    let _ = shared.persistence.delete("sealed_state", &group_key);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn a_wallet_can_enumerate_and_revoke_its_services() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let (registry, group_key, kps) = fresh_wallet(&shared).await;

    let (_, vs_a) = enroll_full(&registry, &group_key, &kps[0], &kps[1].identifier).await;
    let (_, vs_b) = enroll_full(&registry, &group_key, &kps[0], &kps[1].identifier).await;
    assert_ne!(vs_a, vs_b, "each enrolment is its own polynomial and share");

    let list = |reg: std::sync::Arc<CosignerRegistry>, gk: String| async move {
        reg.dispatch(&gk, |reply| CosignerCommand::ListServicePairings { reply })
            .await
            .expect("list")
    };

    let rows = list(registry.clone(), group_key.clone()).await;
    assert_eq!(rows.len(), 2, "the map IS the index of what can sign");
    assert!(rows.iter().any(|(vs, _)| *vs == vs_a));

    // Revoking drops the cosigner's counter-share, which ends the pairing: a 2-of-2 missing a
    // half cannot sign, whatever the service still holds.
    let gk = group_key.clone();
    let vs = vs_a.clone();
    let removed = registry
        .dispatch(&gk, move |reply| CosignerCommand::RemoveServicePairing {
            verifying_share_hex: vs,
            reply,
        })
        .await
        .expect("revoke");
    assert!(removed);

    let rows = list(registry.clone(), group_key.clone()).await;
    assert_eq!(rows.len(), 1);
    assert!(rows.iter().all(|(vs, _)| *vs != vs_a));

    // Revoking twice is not an error, it is just a no-op.
    let vs = vs_a.clone();
    let again = registry
        .dispatch(&group_key, move |reply| CosignerCommand::RemoveServicePairing {
            verifying_share_hex: vs,
            reply,
        })
        .await
        .expect("second revoke");
    assert!(!again);

    let _ = shared.persistence.delete("sealed_state", &group_key);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn a_revoked_service_can_no_longer_open_a_ceremony() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let (registry, group_key, kps) = fresh_wallet(&shared).await;
    let (_, vs) = enroll_full(&registry, &group_key, &kps[0], &kps[1].identifier).await;

    // Before revocation the verifying share resolves to a signing context, so a malformed request
    // fails on its CONTENT. After revocation there is no context at all, so it fails on identity.
    let step1 = |reg: std::sync::Arc<CosignerRegistry>, gk: String, user_id: Vec<u8>| async move {
        reg.dispatch(&gk, move |reply| CosignerCommand::SignStep1 {
            req: cosigner_runtime::wallet_proto::SignStep1Request {
                user_id,
                hiding_commitment: vec![],
                binding_commitment: vec![],
                message_to_sign: vec![0u8; 32],
                signature: vec![],
                full_transaction: vec![],
                timestamp_ms: 0,
                script_path_spend: true,
            },
            reply,
        })
        .await
    };

    let vs_bytes = hex::decode(&vs).unwrap();
    let before = step1(registry.clone(), group_key.clone(), vs_bytes.clone())
        .await
        .expect_err("an empty transaction cannot satisfy the ceiling")
        .to_string();
    assert!(
        !before.contains("not authorized"),
        "an enrolled service must be recognised; got: {before}"
    );

    let vs_owned = vs.clone();
    registry
        .dispatch(&group_key, move |reply| CosignerCommand::RemoveServicePairing {
            verifying_share_hex: vs_owned,
            reply,
        })
        .await
        .expect("revoke");

    let after = step1(registry.clone(), group_key.clone(), vs_bytes)
        .await
        .expect_err("a revoked service must be refused")
        .to_string();
    assert!(
        after.contains("not authorized"),
        "expected an identity refusal, got: {after}"
    );

    let _ = shared.persistence.delete("sealed_state", &group_key);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn the_wallet_still_signs_with_its_own_share_alongside_services() {
    let Some(shared) = common::try_shared().await else {
        return;
    };
    let (registry, group_key, kps) = fresh_wallet(&shared).await;
    enroll_full(&registry, &group_key, &kps[0], &kps[1].identifier).await;

    // The wallet's own verifying share must still resolve — enrolling a service must not shadow
    // the owner. A wallet request carries no ceiling, so an empty transaction is fine.
    let wallet_vs = point::serialize_compressed(&kps[0].verifying_share).to_vec();
    let res = registry
        .dispatch(&group_key, move |reply| CosignerCommand::SignStep1 {
            req: cosigner_runtime::wallet_proto::SignStep1Request {
                user_id: wallet_vs,
                hiding_commitment: vec![2u8; 33],
                binding_commitment: vec![2u8; 33],
                message_to_sign: vec![0u8; 32],
                signature: vec![],
                full_transaction: vec![],
                timestamp_ms: 0,
                script_path_spend: true,
            },
            reply,
        })
        .await;
    // Bogus commitments fail to parse, but NOT with an authorization error.
    if let Err(e) = &res {
        assert!(!e.to_string().contains("not authorized"), "{e}");
    }

    let _ = shared.persistence.delete("sealed_state", &group_key);
}
