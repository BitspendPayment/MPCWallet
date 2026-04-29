use crate::error::Error;
use crate::hash::compute_challenge;
use crate::keys::VerifyingKey;
use crate::point;
use crate::scalar::scalar_to_bytes;
use k256::{ProjectivePoint, Scalar};

/// A BIP-340 Schnorr signature (R, z).
#[derive(Clone, Debug)]
pub struct Signature {
    pub r: ProjectivePoint,
    pub z: Scalar,
}

impl Signature {
    pub fn new(r: ProjectivePoint, z: Scalar) -> Self {
        Self { r, z }
    }

    pub fn has_even_y(&self) -> bool {
        point::has_even_y(&self.r)
    }

    /// Normalize R to have even Y (BIP-340).
    pub fn into_even_y(&self) -> Self {
        if !self.has_even_y() {
            Self {
                r: point::point_negate(&self.r),
                z: self.z,
            }
        } else {
            self.clone()
        }
    }

    /// Serialize to 64-byte BIP-340 format: R_x(32) || z(32).
    pub fn serialize(&self) -> [u8; 64] {
        let r_x = point::serialize_x_only(&self.r);
        let z_bytes = scalar_to_bytes(&self.z);

        let mut out = [0u8; 64];
        out[..32].copy_from_slice(&r_x);
        out[32..].copy_from_slice(&z_bytes);
        out
    }

    /// Verify this signature against a public key and message.
    /// Returns Ok(()) on success, Err on failure.
    pub fn verify(
        &self,
        pk: &VerifyingKey,
        message: &[u8],
    ) -> Result<(), Error> {
        let pk_even = pk.into_even_y();
        let sig_even = self.into_even_y();

        let challenge =
            compute_challenge(&sig_even.r, &pk_even, message);

        // Check: z * G == R + e * P
        let z_g = point::base_mul(&sig_even.z);
        let e_p = point::point_mul(&pk_even.point, &challenge);
        let r_plus_ep = point::point_add(&sig_even.r, &e_p);

        if point::points_equal(&z_g, &r_plus_ep) {
            Ok(())
        } else {
            Err(Error::InvalidSignature)
        }
    }
}
