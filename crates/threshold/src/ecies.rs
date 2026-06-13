//! Minimal ECIES over secp256k1 for confidentially delivering a 32-byte payload
//! (a scalar — a participant's refresh half) to a recipient identified by its
//! compressed verifying-share pubkey. Ephemeral-static ECDH → SHA-256-derived
//! keystream (a one-time pad is sufficient for a single fixed-length payload) plus
//! a SHA-256 MAC for integrity.
//!
//! Wire blob (97 bytes): `ephemeral_pubkey(33) || ciphertext(32) || tag(32)`.
//!
//! Used by the multi-user eVTXO onboarding: the author and the cosigner each encrypt
//! their refresh half to the participant's verifying share, so neither learns the
//! participant's combined share `P_i` (only the participant decrypts both and sums).

use crate::error::Error;
use crate::point;
use k256::Scalar;
use sha2::{Digest, Sha256};

pub const ECIES_BLOB_LEN: usize = 33 + 32 + 32;

fn kdf(label: &[u8], shared_compressed: &[u8; 33]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(label);
    h.update(shared_compressed);
    h.finalize().into()
}

fn mac(mac_key: &[u8; 32], ciphertext: &[u8; 32]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(mac_key);
    h.update(ciphertext);
    h.finalize().into()
}

/// Encrypt `payload` to `recipient_pubkey` (compressed) using a caller-supplied
/// `ephemeral` scalar. Production uses [`encrypt`] (fresh random ephemeral); this
/// form exists for deterministic tests.
pub fn encrypt_with_ephemeral(
    payload: &[u8; 32],
    recipient_pubkey: &[u8; 33],
    ephemeral: &Scalar,
) -> Result<[u8; ECIES_BLOB_LEN], Error> {
    let p = point::deserialize_compressed(recipient_pubkey)?;
    let e_pub = point::base_mul(ephemeral);
    let shared = point::point_mul(&p, ephemeral);
    let shared_c = point::serialize_compressed(&shared);

    let enc_key = kdf(b"ecies-enc", &shared_c);
    let mac_key = kdf(b"ecies-mac", &shared_c);

    let mut ct = [0u8; 32];
    for i in 0..32 {
        ct[i] = payload[i] ^ enc_key[i];
    }
    let tag = mac(&mac_key, &ct);

    let mut out = [0u8; ECIES_BLOB_LEN];
    out[..33].copy_from_slice(&point::serialize_compressed(&e_pub));
    out[33..65].copy_from_slice(&ct);
    out[65..].copy_from_slice(&tag);
    Ok(out)
}

/// Encrypt `payload` to `recipient_pubkey` with a fresh random ephemeral scalar.
#[cfg(feature = "std")]
pub fn encrypt(
    payload: &[u8; 32],
    recipient_pubkey: &[u8; 33],
    rng: &mut impl rand_core::RngCore,
) -> Result<[u8; ECIES_BLOB_LEN], Error> {
    let ephemeral = crate::random::mod_n_random(rng);
    encrypt_with_ephemeral(payload, recipient_pubkey, &ephemeral)
}

/// Decrypt a blob with the recipient's secret scalar, verifying the MAC.
pub fn decrypt(blob: &[u8; ECIES_BLOB_LEN], secret: &Scalar) -> Result<[u8; 32], Error> {
    let mut e_pub_b = [0u8; 33];
    e_pub_b.copy_from_slice(&blob[..33]);
    let e_pub = point::deserialize_compressed(&e_pub_b)?;
    let mut ct = [0u8; 32];
    ct.copy_from_slice(&blob[33..65]);

    let shared = point::point_mul(&e_pub, secret);
    let shared_c = point::serialize_compressed(&shared);
    let enc_key = kdf(b"ecies-enc", &shared_c);
    let mac_key = kdf(b"ecies-mac", &shared_c);

    // MAC failure ⇒ wrong key or tampered blob (reuse InvalidSignature for auth fail).
    if mac(&mac_key, &ct).as_slice() != &blob[65..] {
        return Err(Error::InvalidSignature);
    }

    let mut out = [0u8; 32];
    for i in 0..32 {
        out[i] = ct[i] ^ enc_key[i];
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scalar::scalar_from_bytes;

    fn fixed_scalar(byte: u8) -> Scalar {
        let mut b = [0u8; 32];
        b[31] = byte; // small non-zero
        scalar_from_bytes(&b).unwrap()
    }

    #[test]
    fn ecies_round_trip() {
        let secret = fixed_scalar(7);
        let pubkey = point::serialize_compressed(&point::base_mul(&secret));
        let payload = point::serialize_x_only(&point::base_mul(&fixed_scalar(99)));
        let ephemeral = fixed_scalar(42);

        let blob = encrypt_with_ephemeral(&payload, &pubkey, &ephemeral).unwrap();
        let got = decrypt(&blob, &secret).unwrap();
        assert_eq!(got, payload, "ECIES round-trip must recover the payload");

        // Wrong secret ⇒ MAC rejects.
        assert!(
            decrypt(&blob, &fixed_scalar(8)).is_err(),
            "wrong key must fail the MAC"
        );
    }
}
