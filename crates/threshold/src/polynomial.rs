use crate::identifier::Identifier;
use crate::point;
use alloc::vec::Vec;
use k256::{ProjectivePoint, Scalar};

/// Evaluate a polynomial at a given identifier using Horner's method.
/// coeffs = [a0, a1, ..., a_{t-1}] where a0 is the constant term.
pub fn evaluate_polynomial(id: &Identifier, coeffs: &[Scalar]) -> Scalar {
    if coeffs.is_empty() {
        return Scalar::ZERO;
    }
    let x = *id.to_scalar();
    let mut val = Scalar::ZERO;
    for i in (0..coeffs.len()).rev() {
        if i != coeffs.len() - 1 {
            val = val * x;
        }
        val = val + coeffs[i];
    }
    val
}

/// Generate a secret polynomial and its commitments.
///
/// Returns (coefficients, commitments) where:
/// - coefficients = [secret, coeff1, coeff2, ...]
/// - commitments = [g^secret, g^coeff1, g^coeff2, ...]
pub fn generate_secret_polynomial(
    secret: &Scalar,
    coefficients: &[Scalar],
) -> (Vec<Scalar>, Vec<ProjectivePoint>) {
    let mut coeffs = Vec::with_capacity(1 + coefficients.len());
    coeffs.push(*secret);
    coeffs.extend_from_slice(coefficients);

    let commitments: Vec<ProjectivePoint> =
        coeffs.iter().map(|c| point::base_mul(c)).collect();

    (coeffs, commitments)
}
