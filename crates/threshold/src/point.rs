use crate::error::Error;
use k256::elliptic_curve::group::Group;
use k256::elliptic_curve::sec1::{FromEncodedPoint, ToEncodedPoint};
use k256::{AffinePoint, EncodedPoint, ProjectivePoint, Scalar};

/// Multiply generator G by scalar k: k * G.
pub fn base_mul(k: &Scalar) -> ProjectivePoint {
    ProjectivePoint::GENERATOR * k
}

/// Multiply point P by scalar k: k * P.
pub fn point_mul(p: &ProjectivePoint, k: &Scalar) -> ProjectivePoint {
    p * k
}

/// Add two points: a + b.
pub fn point_add(a: &ProjectivePoint, b: &ProjectivePoint) -> ProjectivePoint {
    a + b
}

/// Negate a point: -P.
pub fn point_negate(p: &ProjectivePoint) -> ProjectivePoint {
    -p
}

/// Serialize a point to 33-byte compressed form.
pub fn serialize_compressed(p: &ProjectivePoint) -> [u8; 33] {
    let affine = AffinePoint::from(*p);
    let encoded = affine.to_encoded_point(true);
    let bytes = encoded.as_bytes();
    let mut out = [0u8; 33];
    out.copy_from_slice(bytes);
    out
}

/// Extract x-only coordinate (32 bytes) from a point.
pub fn serialize_x_only(p: &ProjectivePoint) -> [u8; 32] {
    let compressed = serialize_compressed(p);
    let mut out = [0u8; 32];
    out.copy_from_slice(&compressed[1..33]);
    out
}

/// Deserialize a 33-byte compressed point.
pub fn deserialize_compressed(b: &[u8; 33]) -> Result<ProjectivePoint, Error> {
    let encoded =
        EncodedPoint::from_bytes(b).map_err(|_| Error::InvalidPoint)?;
    let affine = AffinePoint::from_encoded_point(&encoded);
    if affine.is_some().into() {
        Ok(ProjectivePoint::from(affine.unwrap()))
    } else {
        Err(Error::InvalidPoint)
    }
}

/// Check if a point has even Y coordinate.
pub fn has_even_y(p: &ProjectivePoint) -> bool {
    let affine = AffinePoint::from(*p);
    let encoded = affine.to_encoded_point(false); // uncompressed
    let y_bytes = encoded.y().expect("point at infinity");
    // Even if last byte is even
    (y_bytes[31] & 1) == 0
}

/// Check if a point is the identity (point at infinity).
pub fn is_identity(p: &ProjectivePoint) -> bool {
    bool::from(p.is_identity())
}

/// Check if two points are equal.
pub fn points_equal(a: &ProjectivePoint, b: &ProjectivePoint) -> bool {
    let aa = AffinePoint::from(*a);
    let ab = AffinePoint::from(*b);
    aa == ab
}
