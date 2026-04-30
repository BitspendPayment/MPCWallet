use crate::identifier::Identifier;
use crate::nonce::SigningCommitments;
use crate::point;
use alloc::collections::BTreeMap;
use alloc::vec::Vec;
use k256::ProjectivePoint;

/// A participant's contribution to the group commitment.
#[derive(Clone, Debug)]
pub struct GroupCommitmentShare {
    pub elem: ProjectivePoint,
}

/// The aggregated group commitment point R.
#[derive(Clone, Debug)]
pub struct GroupCommitment {
    pub elem: ProjectivePoint,
}

/// A signing package: commitments from all participants + message.
#[derive(Clone, Debug)]
pub struct SigningPackage {
    pub commitments: BTreeMap<Identifier, SigningCommitments>,
    pub message: Vec<u8>,
}

impl SigningPackage {
    pub fn new(
        commitments: BTreeMap<Identifier, SigningCommitments>,
        message: Vec<u8>,
    ) -> Self {
        Self {
            commitments,
            message,
        }
    }
}

impl SigningCommitments {
    /// Compute this participant's group commitment share: hiding + binding_scalar * binding.
    pub fn to_group_commitment_share(
        &self,
        binding_scalar: &k256::Scalar,
    ) -> GroupCommitmentShare {
        let b_h = point::point_mul(&self.binding, binding_scalar);
        let sum = point::point_add(&self.hiding, &b_h);
        GroupCommitmentShare { elem: sum }
    }
}
