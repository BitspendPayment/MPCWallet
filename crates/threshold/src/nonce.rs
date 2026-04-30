use crate::hash::h3;
use crate::point;
use crate::scalar::scalar_to_bytes;
use k256::{ProjectivePoint, Scalar};
use rand_core::RngCore;

/// A pair of signing commitments (public nonce points).
#[derive(Clone, Debug)]
pub struct SigningCommitments {
    /// Binding commitment: binding * G
    pub binding: ProjectivePoint,
    /// Hiding commitment: hiding * G
    pub hiding: ProjectivePoint,
}

/// A signing nonce (secret scalars + public commitments).
#[derive(Clone, Debug)]
pub struct SigningNonce {
    pub hiding: Scalar,
    pub binding: Scalar,
    pub commitments: SigningCommitments,
}

/// Generate a single FROST nonce: h3(random_32 || secret_bytes).
fn generate_frost_nonce(rng: &mut impl RngCore, secret: &Scalar) -> Scalar {
    let mut random_bytes = [0u8; 32];
    rng.fill_bytes(&mut random_bytes);

    let secret_bytes = scalar_to_bytes(secret);
    let mut input = [0u8; 64];
    input[..32].copy_from_slice(&random_bytes);
    input[32..].copy_from_slice(&secret_bytes);

    h3(&input)
}

/// Generate a new signing nonce pair from a secret share.
pub fn new_nonce(rng: &mut impl RngCore, secret: &Scalar) -> SigningNonce {
    let hiding = generate_frost_nonce(rng, secret);
    let binding = generate_frost_nonce(rng, secret);

    let hiding_commitment = point::base_mul(&hiding);
    let binding_commitment = point::base_mul(&binding);

    SigningNonce {
        hiding,
        binding,
        commitments: SigningCommitments {
            binding: binding_commitment,
            hiding: hiding_commitment,
        },
    }
}
