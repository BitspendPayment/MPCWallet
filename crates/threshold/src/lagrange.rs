use crate::identifier::Identifier;
use k256::Scalar;

/// Compute Lagrange coefficient λ_i(0) for participant i in set S.
///
/// λ_i(0) = ∏_{j∈S, j≠i} (-j) / (i - j) mod n
pub fn lagrange_coeff_at_zero(i: &Identifier, set: &[Identifier]) -> Scalar {
    let mut num = Scalar::ONE;
    let mut den = Scalar::ONE;

    let ii = *i.to_scalar();

    for j in set {
        if j == i {
            continue;
        }

        let jj = *j.to_scalar();

        // neg_j = -j mod n
        let neg_j = -jj;
        num *= neg_j;

        // diff = i - j mod n
        let diff = ii - jj;
        den *= diff;
    }

    // num / den = num * den^(-1) mod n
    let den_inv = den.invert().expect("denominator must be non-zero");
    num * den_inv
}
