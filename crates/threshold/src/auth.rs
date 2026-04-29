//! Single-key BIP-340 Schnorr authentication.
//!
//! Provides [`AuthSigner`] for signing authentication messages and
//! [`verify_schnorr_signature`] for standalone verification.
//! This module requires the `std` feature (hwsigner does not need it).

use crate::error::Error;
use crate::hash::{compute_challenge, tagged_hash};
use crate::keys::VerifyingKey;
use crate::point;
use crate::scalar::{scalar_from_bytes, scalar_to_bytes};
use crate::signature::Signature;
use k256::{ProjectivePoint, Scalar};

/// Single-key Schnorr signer for authentication.
///
/// Uses BIP-340 compatible Schnorr signatures with a single private key
/// (not threshold). Used for authenticating gRPC requests before MPC
/// operations.
pub struct AuthSigner {
    secret: Scalar,
    public_key: ProjectivePoint,
}

impl AuthSigner {
    /// Creates an AuthSigner from 32-byte big-endian secret key bytes.
    pub fn from_secret_bytes(bytes: &[u8; 32]) -> Result<Self, Error> {
        let secret = scalar_from_bytes(bytes)?;
        let public_key = point::base_mul(&secret);
        Ok(Self { secret, public_key })
    }

    /// Returns the compressed public key (33 bytes).
    pub fn public_key_compressed(&self) -> [u8; 33] {
        point::serialize_compressed(&self.public_key)
    }

    /// Returns the x-only public key (32 bytes) for BIP-340.
    pub fn public_key_x_only(&self) -> [u8; 32] {
        point::serialize_x_only(&self.public_key)
    }

    /// Signs a message using BIP-340 Schnorr signature scheme.
    ///
    /// Uses deterministic nonce: k = taggedHash("BIP0340/nonce", d || m).
    /// Returns a 64-byte signature (32-byte R x-coordinate + 32-byte s).
    pub fn sign(&self, message: &[u8]) -> [u8; 64] {
        // Ensure public key has even Y (BIP-340 requirement)
        let mut private_key = self.secret;
        let mut _public_key = self.public_key;

        if !point::has_even_y(&self.public_key) {
            private_key = -private_key;
            _public_key = point::base_mul(&private_key);
        }

        // Deterministic nonce: k = taggedHash("BIP0340/nonce", d || m)
        let dk_bytes = scalar_to_bytes(&private_key);
        let mut nonce_input = alloc::vec::Vec::with_capacity(32 + message.len());
        nonce_input.extend_from_slice(&dk_bytes);
        nonce_input.extend_from_slice(message);
        let k = tagged_hash("BIP0340/nonce", &nonce_input);

        // R = k * G, ensure R has even Y
        let r_point = point::base_mul(&k);
        let mut k_adjusted = k;

        if !point::has_even_y(&r_point) {
            k_adjusted = -k;
        }
        let r_final = point::base_mul(&k_adjusted);

        // e = H(R || P || m)
        let vk = VerifyingKey::new(_public_key);
        let challenge = compute_challenge(&r_final, &vk, message);

        // s = k + e * d (mod n)
        let s = k_adjusted + (challenge * private_key);

        let sig = Signature::new(r_final, s);
        sig.serialize()
    }
}

/// Verifies a BIP-340 Schnorr signature against a compressed public key.
///
/// - `pk_compressed`: 33-byte compressed public key.
/// - `message`: the signed message bytes.
/// - `signature_bytes`: 64-byte signature (R_x(32) || z(32)).
///
/// Returns `true` if the signature is valid.
pub fn verify_schnorr_signature(
    pk_compressed: &[u8; 33],
    message: &[u8],
    signature_bytes: &[u8; 64],
) -> bool {
    let result = (|| -> Result<(), Error> {
        // Parse R from x-only (assume even Y)
        let mut r_compressed = [0u8; 33];
        r_compressed[0] = 0x02;
        r_compressed[1..33].copy_from_slice(&signature_bytes[..32]);
        let r = point::deserialize_compressed(&r_compressed)?;

        // Parse z scalar
        let mut z_bytes = [0u8; 32];
        z_bytes.copy_from_slice(&signature_bytes[32..64]);
        let z = scalar_from_bytes(&z_bytes)?;

        // Parse public key
        let pk = point::deserialize_compressed(pk_compressed)?;
        let vk = VerifyingKey::new(pk);

        let sig = Signature::new(r, z);
        sig.verify(&vk, message)
    })();

    result.is_ok()
}
