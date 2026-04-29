use crate::commitment::{GroupCommitment, SigningPackage};
use crate::error::Error;
use crate::hash::{h1, h4, h5};
use crate::identifier::{sorted_identifiers, Identifier};
use crate::keys::VerifyingKey;
use crate::nonce::SigningCommitments;
use crate::point;
use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use k256::{ProjectivePoint, Scalar};

/// A binding factor for a participant.
#[derive(Clone, Debug)]
pub struct BindingFactor {
    pub scalar: Scalar,
}

/// Map of identifier → binding factor.
pub struct BindingFactorList {
    pub factors: BTreeMap<Identifier, BindingFactor>,
}

impl BindingFactorList {
    pub fn get(&self, id: &Identifier) -> Option<&BindingFactor> {
        self.factors.get(id)
    }
}

/// Encode group commitment list: for each participant (sorted by id),
/// emit id(32) || hiding_compressed(33) || binding_compressed(33).
fn encode_group_commitment_list(
    commitments: &BTreeMap<Identifier, SigningCommitments>,
) -> Vec<u8> {
    let ids: Vec<Identifier> = commitments.keys().cloned().collect();
    let sorted = sorted_identifiers(&ids);

    let mut buf = Vec::with_capacity(sorted.len() * (32 + 33 + 33));
    for id in &sorted {
        let comm = &commitments[id];
        buf.extend_from_slice(&id.serialize());
        buf.extend_from_slice(&point::serialize_compressed(&comm.hiding));
        buf.extend_from_slice(&point::serialize_compressed(&comm.binding));
    }
    buf
}

/// Compute binding factors for all participants.
pub fn compute_binding_factor_list(
    signing_package: &SigningPackage,
    vk: &VerifyingKey,
) -> BindingFactorList {
    // Build shared prefix: vk(33) || h4(msg)(32) || h5(encoded)(32)
    let vk_bytes = point::serialize_compressed(&vk.point);
    let h4_msg = h4(&signing_package.message);
    let enc_gc = encode_group_commitment_list(&signing_package.commitments);
    let h5_enc = h5(&enc_gc);

    let mut prefix = Vec::with_capacity(33 + 32 + 32);
    prefix.extend_from_slice(&vk_bytes);
    prefix.extend_from_slice(&h4_msg);
    prefix.extend_from_slice(&h5_enc);

    // Compute per-participant binding factors
    let ids: Vec<Identifier> =
        signing_package.commitments.keys().cloned().collect();
    let sorted = sorted_identifiers(&ids);

    let mut factors = BTreeMap::new();
    for id in &sorted {
        let mut preimage = Vec::with_capacity(prefix.len() + 32);
        preimage.extend_from_slice(&prefix);
        preimage.extend_from_slice(&id.serialize());
        factors.insert(
            id.clone(),
            BindingFactor {
                scalar: h1(&preimage),
            },
        );
    }

    BindingFactorList { factors }
}

/// Compute the aggregated group commitment R from commitments and binding factors.
pub fn compute_group_commitment(
    signing_package: &SigningPackage,
    bfl: &BindingFactorList,
) -> Result<GroupCommitment, Error> {
    let mut group_commitment = ProjectivePoint::IDENTITY;

    for (id, comm) in &signing_package.commitments {
        if point::is_identity(&comm.binding)
            || point::is_identity(&comm.hiding)
        {
            return Err(Error::IdentityCommitment);
        }

        let bf = bfl.get(id).ok_or(Error::UnknownIdentifier)?;

        // Accumulate hiding commitments
        group_commitment = point::point_add(&group_commitment, &comm.hiding);

        // Accumulate binding: rho_i * B_i
        let rho_b =
            point::point_mul(&comm.binding, &bf.scalar);
        group_commitment = point::point_add(&group_commitment, &rho_b);
    }

    Ok(GroupCommitment {
        elem: group_commitment,
    })
}
