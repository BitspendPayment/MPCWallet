use crate::binding::{compute_binding_factor_list, compute_group_commitment};
use crate::commitment::SigningPackage;
use crate::error::Error;
use crate::hash::compute_challenge;
use crate::identifier::{sorted_identifiers, Identifier};
use crate::keys::{KeyPackage, PublicKeyPackage, VerifyingKey};
use crate::lagrange::lagrange_coeff_at_zero;
use crate::nonce::SigningNonce;
use crate::point;
use crate::signature::Signature;
use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use k256::{ProjectivePoint, Scalar};

/// A participant's signature share.
#[derive(Clone, Debug)]
pub struct SignatureShare {
    pub s: Scalar,
}

/// Derive the Lagrange interpolating value for a participant in a signing package.
fn derive_interpolating_value(
    id: &Identifier,
    pkg: &SigningPackage,
) -> Scalar {
    let ids: Vec<Identifier> = pkg.commitments.keys().cloned().collect();
    let sorted = sorted_identifiers(&ids);
    lagrange_coeff_at_zero(id, &sorted)
}

/// Compute a signature share for this participant.
///
/// z_i = d + e * rho_i + lambda_i * s_i * c  (mod n)
fn compute_signature_share(
    nonce: &SigningNonce,
    rho_i: &Scalar,
    lambda_i: &Scalar,
    key_package: &KeyPackage,
    challenge: &Scalar,
    negate_nonce: bool,
) -> SignatureShare {
    let mut d = nonce.hiding;
    let mut e = nonce.binding;

    if negate_nonce {
        d = -d;
        e = -e;
    }

    let e_rho = e * rho_i;
    let lsc = *lambda_i * key_package.secret_share * challenge;
    let z = d + e_rho + lsc;

    SignatureShare { s: z }
}

/// Produce a signature share for a signing package.
pub fn sign(
    signing_package: &SigningPackage,
    signing_nonce: &SigningNonce,
    key_package: &KeyPackage,
) -> Result<SignatureShare, Error> {
    if signing_package.commitments.len() < key_package.min_signers {
        return Err(Error::IncorrectNumberOfCommitments);
    }

    let key_package = key_package.into_even_y();

    let commitment = signing_package
        .commitments
        .get(&key_package.identifier)
        .ok_or(Error::MismatchedCommitment)?;

    // Verify nonce matches commitment
    if !point::points_equal(
        &signing_nonce.commitments.binding,
        &commitment.binding,
    ) || !point::points_equal(
        &signing_nonce.commitments.hiding,
        &commitment.hiding,
    ) {
        return Err(Error::MismatchedCommitment);
    }

    let bfl =
        compute_binding_factor_list(signing_package, &key_package.verifying_key);
    let group_commitment =
        compute_group_commitment(signing_package, &bfl)?;

    // BIP-340: if R has odd Y, negate nonces
    let is_r_odd = !point::has_even_y(&group_commitment.elem);

    let lambda_i =
        derive_interpolating_value(&key_package.identifier, signing_package);

    let challenge = compute_challenge(
        &group_commitment.elem,
        &key_package.verifying_key,
        &signing_package.message,
    );

    let bf = bfl
        .get(&key_package.identifier)
        .ok_or(Error::IncorrectBindingFactorPreimages)?;

    Ok(compute_signature_share(
        signing_nonce,
        &bf.scalar,
        &lambda_i,
        &key_package,
        &challenge,
        is_r_odd,
    ))
}

/// Verify a single signature share.
pub fn verify_signature_share(
    identifier: &Identifier,
    verifying_share: &ProjectivePoint,
    signature_share: &SignatureShare,
    signing_package: &SigningPackage,
    verifying_key: &VerifyingKey,
    negate_r: bool,
) -> Result<(), Error> {
    let bfl = compute_binding_factor_list(signing_package, verifying_key);
    let group_commitment =
        compute_group_commitment(signing_package, &bfl)?;

    let challenge = compute_challenge(
        &group_commitment.elem,
        verifying_key,
        &signing_package.message,
    );

    let comm = signing_package
        .commitments
        .get(identifier)
        .ok_or(Error::UnknownIdentifier)?;
    let bf = bfl.get(identifier).ok_or(Error::UnknownIdentifier)?;

    let mut r_share = comm.to_group_commitment_share(&bf.scalar).elem;

    if negate_r {
        r_share = point::point_negate(&r_share);
    }

    let lambda_i = derive_interpolating_value(identifier, signing_package);

    // LHS: z_i * G
    let lhs = point::base_mul(&signature_share.s);

    // RHS: R_share + (challenge * lambda_i) * verifying_share
    let c_lambda = challenge * lambda_i;
    let term2 = point::point_mul(verifying_share, &c_lambda);
    let rhs = point::point_add(&r_share, &term2);

    if !point::points_equal(&lhs, &rhs) {
        return Err(Error::InvalidSignature);
    }

    Ok(())
}

/// Aggregate signature shares into a final BIP-340 signature.
pub fn aggregate(
    signing_package: &SigningPackage,
    signature_shares: &BTreeMap<Identifier, SignatureShare>,
    pubkeys: &PublicKeyPackage,
) -> Result<Signature, Error> {
    if signing_package.commitments.len() != signature_shares.len() {
        return Err(Error::UnknownIdentifier);
    }

    let pubkeys = pubkeys.into_even_y();

    // Verify all participants match
    for id in signing_package.commitments.keys() {
        if !signature_shares.contains_key(id)
            || !pubkeys.verifying_shares.contains_key(id)
        {
            return Err(Error::UnknownIdentifier);
        }
    }

    let bfl =
        compute_binding_factor_list(signing_package, &pubkeys.verifying_key);
    let group_commitment =
        compute_group_commitment(signing_package, &bfl)?;

    let is_r_odd = !point::has_even_y(&group_commitment.elem);

    // Verify each share and aggregate z
    let mut z = Scalar::ZERO;

    for (id, share) in signature_shares {
        let vs = pubkeys
            .verifying_shares
            .get(id)
            .ok_or(Error::UnknownIdentifier)?;

        verify_signature_share(
            id,
            vs,
            share,
            signing_package,
            &pubkeys.verifying_key,
            is_r_odd,
        )?;

        z += share.s;
    }

    // If R was odd, negate R for the final signature
    let effective_r = if is_r_odd {
        point::point_negate(&group_commitment.elem)
    } else {
        group_commitment.elem
    };

    let sig = Signature::new(effective_r, z);

    // Final verification: z * G == R + c * P
    let challenge = compute_challenge(
        &effective_r,
        &pubkeys.verifying_key,
        &signing_package.message,
    );

    let z_g = point::base_mul(&z);
    let c_p = point::point_mul(&pubkeys.verifying_key.point, &challenge);
    let r_plus_cp = point::point_add(&effective_r, &c_p);

    if point::points_equal(&z_g, &r_plus_cp) {
        Ok(sig.into_even_y())
    } else {
        Err(Error::InvalidSignature)
    }
}
