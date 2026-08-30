//! Turning two sealed halves into a usable share — and refusing anything that does not verify.

use crate::error::{Error, Result};
use crate::identity::ServiceIdentity;
use crate::share::{ServiceShare, ShareStore};
use serde::{Deserialize, Serialize};
use threshold::keys::PublicKeyPackage;
use threshold::{ecies, point, scalar};

/// A complete pairing, assembled from the two halves the dealers pushed.
///
/// Each half is sealed to `service_id`, so it is bound to the identity that will hold the share
/// rather than to the URL it was sent to — a misconfigured or hijacked endpoint gets a blob it
/// cannot open. Nothing here is believed on the strength of who sent it; [`verify`] checks the
/// pair against the pairing package before any of it is stored.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EnrollmentBundle {
    /// The wallet's group key — the actor to address for ceremonies.
    pub pairing_group_key: String,
    /// The pairing's public key package, JSON.
    pub pairing_public_key_package_json: String,
    /// `a@service`, ECIES-sealed to `service_id` — dealt by the wallet.
    pub ecies_a_at_service: String,
    /// `b@service`, ECIES-sealed to `service_id` — dealt by the cosigner.
    pub ecies_b_at_service: String,
}

fn open(blob_hex: &str, identity: &ServiceIdentity, what: &str) -> Result<[u8; 32]> {
    let raw = hex::decode(blob_hex).map_err(|e| Error::Crypto(format!("{what} is not hex: {e}")))?;
    let blob: [u8; ecies::ECIES_BLOB_LEN] = raw
        .try_into()
        .map_err(|_| Error::Crypto(format!("{what} must be {} bytes", ecies::ECIES_BLOB_LEN)))?;
    // A wrong key yields a different shared point, hence a different MAC key, hence a tag
    // mismatch — so "sealed to the wrong service" surfaces here rather than as garbage that only
    // fails later at the sum check.
    ecies::decrypt(&blob, identity.secret())
        .map_err(|e| Error::Crypto(format!("cannot open {what}: {e:?}")))
}

/// Verify an enrolment bundle and turn it into a share.
///
/// Three checks, all of which must pass:
///
/// 1. Both halves open under the service's secret.
/// 2. The summed share matches the verifying share published in the pairing package — so the
///    share can actually sign, rather than failing at aggregation time. This is the load-bearing
///    one: the pairing package is what the cosigner will aggregate against, so agreeing with it
///    is what makes the share usable, and everything else follows from it.
/// 3. The share is not the group key itself. A CONSTANT pairing polynomial would hand the service
///    `v` outright — enough to sign alone. That takes a broken CSPRNG to produce, but it is one
///    point comparison to refuse, and the failure is total.
pub fn verify(identity: &ServiceIdentity, bundle: &EnrollmentBundle) -> Result<ServiceShare> {
    let a = open(&bundle.ecies_a_at_service, identity, "a@service")?;
    let b = open(&bundle.ecies_b_at_service, identity, "b@service")?;

    let s = scalar::scalar_from_bytes(&a)? + scalar::scalar_from_bytes(&b)?;
    if bool::from(k256::elliptic_curve::subtle::ConstantTimeEq::ct_eq(
        &s,
        &k256::Scalar::ZERO,
    )) {
        return Err(Error::Crypto("summed share is zero".into()));
    }

    let pkp = PublicKeyPackage::from_json(&bundle.pairing_public_key_package_json)?;
    let id = identity.identifier();

    let published = pkp
        .verifying_shares
        .get(id)
        .ok_or_else(|| Error::Crypto("pairing package has no share for this service".into()))?;
    if !point::points_equal(&point::base_mul(&s), published) {
        return Err(Error::Crypto(
            "the two halves do not sum to the share the pairing package publishes".into(),
        ));
    }

    if point::points_equal(published, &pkp.verifying_key.point) {
        return Err(Error::Invariant(
            "degenerate pairing: this share IS the group key, so it could sign alone — the \
             pairing polynomial is constant and the enrolment must be refused"
                .into(),
        ));
    }

    Ok(ServiceShare {
        pairing_group_key: bundle.pairing_group_key.to_ascii_lowercase(),
        // Taken from the verified share, not from the bundle: this is the identity the service
        // will present, so it must be the one it can actually prove.
        verifying_share_hex: hex::encode(point::serialize_compressed(published)),
        identifier_hex: hex::encode(id.serialize()),
        secret_share_hex: hex::encode(scalar::scalar_to_bytes(&s)),
        pairing_pkp_json: bundle.pairing_public_key_package_json.clone(),
    })
}

/// Verify a bundle and persist it. The store refuses a second share on the same polynomial.
pub fn accept(
    identity: &ServiceIdentity,
    store: &dyn ShareStore,
    bundle: &EnrollmentBundle,
) -> Result<ServiceShare> {
    let share = verify(identity, bundle)?;
    store.put(&share)?;
    Ok(share)
}
