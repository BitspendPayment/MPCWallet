use crate::hash::tagged_hash;
use crate::point;
use k256::{ProjectivePoint, Scalar};

/// Compute taproot tweak: taggedHash("TapTweak", P_x || merkle_root).
pub fn compute_tweak(
    p: &ProjectivePoint,
    merkle_root: Option<&[u8]>,
) -> Scalar {
    let p_x = point::serialize_x_only(p);
    let mut preimage = alloc::vec::Vec::with_capacity(32 + 32);
    preimage.extend_from_slice(&p_x);
    if let Some(root) = merkle_root {
        preimage.extend_from_slice(root);
    }
    tagged_hash("TapTweak", &preimage)
}
