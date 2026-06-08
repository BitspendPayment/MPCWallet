//! Host-native implementation of the contract `crypto` WIT interface. Contracts
//! import these so they never need WASI (filesystem/network) to hash or verify a
//! signature. Backed by the already-vendored `bitcoin::hashes` and
//! `bitcoin::secp256k1` — no extra dependency. Swappable for a WASM crypto
//! component later behind the same WIT without touching any contract.

use bitcoin::hashes::{Hash, HashEngine};
use bitcoin::secp256k1::{schnorr::Signature, Message, Secp256k1, XOnlyPublicKey};

pub fn sha256(data: &[u8]) -> Vec<u8> {
    bitcoin::hashes::sha256::Hash::hash(data).to_byte_array().to_vec()
}

pub fn hash256(data: &[u8]) -> Vec<u8> {
    bitcoin::hashes::sha256d::Hash::hash(data).to_byte_array().to_vec()
}

pub fn ripemd160(data: &[u8]) -> Vec<u8> {
    bitcoin::hashes::ripemd160::Hash::hash(data).to_byte_array().to_vec()
}

pub fn hash160(data: &[u8]) -> Vec<u8> {
    bitcoin::hashes::hash160::Hash::hash(data).to_byte_array().to_vec()
}

/// BIP-340 tagged hash: SHA256(SHA256(tag) || SHA256(tag) || msg).
pub fn tagged_hash(tag: &str, msg: &[u8]) -> Vec<u8> {
    let t = bitcoin::hashes::sha256::Hash::hash(tag.as_bytes());
    let mut e = bitcoin::hashes::sha256::Hash::engine();
    e.input(t.as_byte_array());
    e.input(t.as_byte_array());
    e.input(msg);
    bitcoin::hashes::sha256::Hash::from_engine(e).to_byte_array().to_vec()
}

/// BIP-340 Schnorr verify. `msg` must be the 32-byte sighash. Returns false on
/// any malformed input rather than trapping, so a contract gets a defined result.
pub fn schnorr_verify(pubkey: &[u8], msg: &[u8], sig: &[u8]) -> bool {
    let Ok(pk) = XOnlyPublicKey::from_slice(pubkey) else { return false };
    let Ok(signature) = Signature::from_slice(sig) else { return false };
    let Ok(message) = Message::from_digest_slice(msg) else { return false };
    Secp256k1::verification_only()
        .verify_schnorr(&signature, &message, &pk)
        .is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sha256_known_vector() {
        // SHA256("abc")
        assert_eq!(
            hex::encode(sha256(b"abc")),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn hash256_is_double_sha() {
        assert_eq!(hash256(b"abc"), sha256(&sha256(b"abc")));
    }

    #[test]
    fn hash160_is_ripemd_of_sha() {
        assert_eq!(hash160(b"abc"), ripemd160(&sha256(b"abc")));
    }

    #[test]
    fn tagged_hash_is_deterministic_and_tag_separated() {
        let h = tagged_hash("TapLeaf", b"hello");
        assert_eq!(h.len(), 32);
        assert_eq!(h, tagged_hash("TapLeaf", b"hello"));
        assert_ne!(h, tagged_hash("TapBranch", b"hello"));
    }

    #[test]
    fn schnorr_rejects_garbage() {
        assert!(!schnorr_verify(&[0u8; 32], &[0u8; 32], &[0u8; 64]));
        assert!(!schnorr_verify(b"short", b"short", b"short"));
    }
}
