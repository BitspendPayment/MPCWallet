use crate::error::Error;
use k256::elliptic_curve::ops::Reduce;
use k256::{Scalar, U256};

/// Decode a 32-byte big-endian scalar, rejecting zero.
pub fn scalar_from_bytes(b: &[u8; 32]) -> Result<Scalar, Error> {
    let s = scalar_from_bytes_allow_zero(b)?;
    if s.is_zero().into() {
        return Err(Error::InvalidZeroScalar);
    }
    Ok(s)
}

/// Decode a 32-byte big-endian scalar, reducing mod n. Zero is allowed.
pub fn scalar_from_bytes_allow_zero(b: &[u8; 32]) -> Result<Scalar, Error> {
    let wide = U256::from_be_slice(b);
    Ok(<Scalar as Reduce<U256>>::reduce(wide))
}

/// Encode a scalar to 32-byte big-endian.
pub fn scalar_to_bytes(s: &Scalar) -> [u8; 32] {
    let bytes = s.to_bytes();
    // k256::Scalar::to_bytes() returns big-endian GenericArray<u8, U32>
    let mut out = [0u8; 32];
    out.copy_from_slice(&bytes);
    out
}

/// Negate a scalar: n - s mod n.
pub fn scalar_negate(s: &Scalar) -> Scalar {
    -s
}
