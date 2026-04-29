use crate::point;
use k256::elliptic_curve::ops::Reduce;
use k256::{ProjectivePoint, Scalar, U256};
use sha2::{Digest, Sha256};

use crate::keys::VerifyingKey;

const CONTEXT_STRING: &[u8] = b"FROST-secp256k1-SHA256-TR-v1";

/// SHA256(concat(inputs)) interpreted as big-endian mod n.
fn hash_to_scalar(inputs: &[&[u8]]) -> Scalar {
    let mut hasher = Sha256::new();
    for input in inputs {
        hasher.update(input);
    }
    let hash = hasher.finalize();
    let wide = U256::from_be_slice(&hash);
    <Scalar as Reduce<U256>>::reduce(wide)
}

/// SHA256(concat(inputs)) as raw bytes.
fn hash_to_array(inputs: &[&[u8]]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    for input in inputs {
        hasher.update(input);
    }
    let hash = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(&hash);
    out
}

/// FROST h1: binding factor hash.
/// h1(input) = hashToScalar(contextString || "rho" || input)
pub fn h1(input: &[u8]) -> Scalar {
    hash_to_scalar(&[CONTEXT_STRING, b"rho", input])
}

/// FROST h3: nonce derivation hash.
/// h3(input) = hashToScalar(contextString || "nonce" || input)
pub fn h3(input: &[u8]) -> Scalar {
    hash_to_scalar(&[CONTEXT_STRING, b"nonce", input])
}

/// FROST h4: message hash (returns raw bytes, not scalar).
/// h4(input) = SHA256(contextString || "msg" || input)
pub fn h4(input: &[u8]) -> [u8; 32] {
    hash_to_array(&[CONTEXT_STRING, b"msg", input])
}

/// FROST h5: commitment hash (returns raw bytes, not scalar).
/// h5(input) = SHA256(contextString || "com" || input)
pub fn h5(input: &[u8]) -> [u8; 32] {
    hash_to_array(&[CONTEXT_STRING, b"com", input])
}

/// BIP-340 tagged hash returning raw bytes (NOT reduced mod n).
/// Used for TapLeaf/TapBranch hashes where the result is a hash, not a scalar.
pub fn tagged_hash_raw(tag: &str, msg: &[u8]) -> [u8; 32] {
    let tag_hash = Sha256::digest(tag.as_bytes());
    let mut hasher = Sha256::new();
    hasher.update(&tag_hash);
    hasher.update(&tag_hash);
    hasher.update(msg);
    let hash = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(&hash);
    out
}

/// BIP-340 tagged hash: SHA256(SHA256(tag) || SHA256(tag) || msg) mod n.
pub fn tagged_hash(tag: &str, msg: &[u8]) -> Scalar {
    let tag_hash = Sha256::digest(tag.as_bytes());
    let mut hasher = Sha256::new();
    hasher.update(&tag_hash);
    hasher.update(&tag_hash);
    hasher.update(msg);
    let hash = hasher.finalize();
    let wide = U256::from_be_slice(&hash);
    <Scalar as Reduce<U256>>::reduce(wide)
}

/// BIP-340 challenge: e = taggedHash("BIP0340/challenge", R_x || P_x || message).
pub fn compute_challenge(
    r: &ProjectivePoint,
    vk: &VerifyingKey,
    message: &[u8],
) -> Scalar {
    let r_x = point::serialize_x_only(r);
    let p_x = point::serialize_x_only(&vk.point);

    let mut preimage = alloc::vec::Vec::with_capacity(64 + message.len());
    preimage.extend_from_slice(&r_x);
    preimage.extend_from_slice(&p_x);
    preimage.extend_from_slice(message);

    tagged_hash("BIP0340/challenge", &preimage)
}
