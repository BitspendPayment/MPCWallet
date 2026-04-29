//! Random scalar generation utilities.
//!
//! Provides functions for generating random and seeded scalars.
//! Requires the `std` feature (hwsigner uses its own RNG).

use alloc::vec::Vec;
use k256::elliptic_curve::ops::Reduce;
use k256::{Scalar, U256};
use rand_core::RngCore;
use sha2::{Digest, Sha256};

/// Generate a random non-zero scalar.
pub fn mod_n_random(rng: &mut impl RngCore) -> Scalar {
    loop {
        let mut bytes = [0u8; 32];
        rng.fill_bytes(&mut bytes);
        let wide = U256::from_be_slice(&bytes);
        let s = <Scalar as Reduce<U256>>::reduce(wide);
        if !bool::from(s.is_zero()) {
            return s;
        }
    }
}

/// Generate a deterministic scalar from a seed and counter.
///
/// `result = SHA256(seed || counter_be_bytes) mod n`, rejecting zero.
pub fn mod_n_random_seeded(seed: &[u8], counter: u32) -> Scalar {
    let counter_bytes = counter.to_be_bytes();
    let mut hasher = Sha256::new();
    hasher.update(seed);
    hasher.update(counter_bytes);
    let hash = hasher.finalize();
    let wide = U256::from_be_slice(&hash);
    let s = <Scalar as Reduce<U256>>::reduce(wide);
    // If zero (astronomically unlikely), we still return it for determinism
    // matching Dart behavior which uses modNFromBytesAllowZero for seeded
    s
}

/// Generate `count` random non-zero coefficients.
pub fn generate_coefficients(count: usize, rng: &mut impl RngCore) -> Vec<Scalar> {
    (0..count).map(|_| mod_n_random(rng)).collect()
}

/// Generate `count` deterministic coefficients from a seed.
///
/// Each coefficient is `SHA256(seed || index_be) mod n`.
pub fn generate_coefficients_seeded(count: usize, seed: &[u8]) -> Vec<Scalar> {
    (0..count)
        .map(|i| mod_n_random_seeded(seed, i as u32))
        .collect()
}
