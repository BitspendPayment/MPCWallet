//! BIP-341 taproot tree construction: TapLeaf, TapNode, ControlBlock.
//!
//! Implements taproot merkle tree hashing, merkle proof generation, and
//! control block serialization following BIP-341.

use alloc::vec::Vec;
use crate::hash::tagged_hash_raw;
use crate::point;
use crate::tweak::compute_tweak;
use k256::ProjectivePoint;

/// Tapscript leaf version (BIP-342).
pub const TAPSCRIPT_LEAF_VERSION: u8 = 0xc0;

/// NUMS (Nothing Up My Sleeve) unspendable internal key.
/// From BIP-341: H = lift_x(0x50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0)
/// Compressed form with 0x02 prefix (even Y).
pub const UNSPENDABLE_KEY: [u8; 33] = [
    0x02, 0x50, 0x92, 0x9b, 0x74, 0xc1, 0xa0, 0x49,
    0x54, 0xb7, 0x8b, 0x4b, 0x60, 0x35, 0xe9, 0x7a,
    0x5e, 0x07, 0x8a, 0x5a, 0x0f, 0x28, 0xec, 0x96,
    0xd5, 0x47, 0xbf, 0xee, 0x9a, 0xce, 0x80, 0x3a,
    0xc0,
];

/// X-only (32 bytes) form of the NUMS unspendable key.
pub const UNSPENDABLE_KEY_X_ONLY: [u8; 32] = [
    0x50, 0x92, 0x9b, 0x74, 0xc1, 0xa0, 0x49, 0x54,
    0xb7, 0x8b, 0x4b, 0x60, 0x35, 0xe9, 0x7a, 0x5e,
    0x07, 0x8a, 0x5a, 0x0f, 0x28, 0xec, 0x96, 0xd5,
    0x47, 0xbf, 0xee, 0x9a, 0xce, 0x80, 0x3a, 0xc0,
];

/// A taproot script leaf node.
#[derive(Clone, Debug)]
pub struct TapLeaf {
    pub script: Vec<u8>,
    pub leaf_version: u8,
}

impl TapLeaf {
    /// Create a new TapLeaf with the default tapscript leaf version (0xc0).
    pub fn new(script: Vec<u8>) -> Self {
        Self {
            script,
            leaf_version: TAPSCRIPT_LEAF_VERSION,
        }
    }

    /// Compute the leaf hash: taggedHash("TapLeaf", leaf_version || compact_size(script) || script).
    pub fn hash(&self) -> [u8; 32] {
        let mut preimage = Vec::with_capacity(1 + 5 + self.script.len());
        preimage.push(self.leaf_version);
        compact_size_encode(self.script.len(), &mut preimage);
        preimage.extend_from_slice(&self.script);
        tagged_hash_raw("TapLeaf", &preimage)
    }
}

impl PartialEq for TapLeaf {
    fn eq(&self, other: &Self) -> bool {
        self.leaf_version == other.leaf_version && self.script == other.script
    }
}
impl Eq for TapLeaf {}

/// A node in a taproot tree (either a leaf or a branch).
pub enum TapNode {
    Leaf(TapLeaf),
    Branch(alloc::boxed::Box<TapNode>, alloc::boxed::Box<TapNode>),
}

impl TapNode {
    /// Compute the hash of this node.
    /// - Leaf: taggedHash("TapLeaf", ...)
    /// - Branch: taggedHash("TapBranch", sorted(left_hash, right_hash))
    pub fn hash(&self) -> [u8; 32] {
        match self {
            TapNode::Leaf(leaf) => leaf.hash(),
            TapNode::Branch(left, right) => {
                let l = left.hash();
                let r = right.hash();
                branch_hash(&l, &r)
            }
        }
    }

    /// Alias for hash() — the merkle root of the tree rooted at this node.
    pub fn merkle_root(&self) -> [u8; 32] {
        self.hash()
    }

    /// Generate a merkle proof (list of sibling hashes) for a target leaf.
    /// Returns None if the target leaf is not in this tree.
    pub fn merkle_proof(&self, target: &TapLeaf) -> Option<Vec<[u8; 32]>> {
        match self {
            TapNode::Leaf(leaf) => {
                if leaf == target {
                    Some(Vec::new())
                } else {
                    None
                }
            }
            TapNode::Branch(left, right) => {
                if let Some(mut proof) = left.merkle_proof(target) {
                    proof.push(right.hash());
                    Some(proof)
                } else if let Some(mut proof) = right.merkle_proof(target) {
                    proof.push(left.hash());
                    Some(proof)
                } else {
                    None
                }
            }
        }
    }
}

/// Compute the tweaked output key from an internal key and a script tree.
///
/// Returns (tweaked_point, parity) where parity is 0 (even) or 1 (odd).
pub fn tweaked_output_key(
    internal_key: &ProjectivePoint,
    tree: &TapNode,
) -> (ProjectivePoint, u8) {
    let merkle_root = tree.merkle_root();
    let t = compute_tweak(internal_key, Some(&merkle_root));
    let t_g = point::base_mul(&t);
    let q = point::point_add(internal_key, &t_g);
    let parity = if point::has_even_y(&q) { 0u8 } else { 1u8 };
    (q, parity)
}

/// Compute the tweaked output key from an x-only internal key and script tree.
/// Returns the compressed (33-byte) tweaked key.
pub fn tweaked_output_key_from_x_only(
    internal_key_x_only: &[u8; 32],
    tree: &TapNode,
) -> Result<[u8; 33], crate::error::Error> {
    // Construct compressed key with 0x02 prefix (even Y)
    let mut compressed = [0u8; 33];
    compressed[0] = 0x02;
    compressed[1..].copy_from_slice(internal_key_x_only);
    let p = point::deserialize_compressed(&compressed)?;
    let (q, _) = tweaked_output_key(&p, tree);
    Ok(point::serialize_compressed(&q))
}

/// Control block for BIP-341 script-path spending.
pub struct ControlBlock {
    /// leaf_version | output_key_parity (single byte).
    pub leaf_version_and_parity: u8,
    /// X-only internal public key (32 bytes).
    pub internal_key: [u8; 32],
    /// Merkle path — sibling hashes from leaf to root.
    pub merkle_path: Vec<[u8; 32]>,
}

impl ControlBlock {
    /// Build a control block for a target leaf in the given tree.
    ///
    /// - `internal_key`: x-only internal pubkey (32 bytes)
    /// - `leaf`: the leaf being spent
    /// - `tree`: the full script tree
    ///
    /// Returns None if the leaf is not found in the tree.
    pub fn new(
        internal_key: &[u8; 32],
        leaf: &TapLeaf,
        tree: &TapNode,
    ) -> Option<Self> {
        let proof = tree.merkle_proof(leaf)?;

        // Compute the tweaked output key to determine parity
        let mut compressed = [0u8; 33];
        compressed[0] = 0x02;
        compressed[1..].copy_from_slice(internal_key);
        let p = point::deserialize_compressed(&compressed).ok()?;
        let (_, parity) = tweaked_output_key(&p, tree);

        Some(ControlBlock {
            leaf_version_and_parity: leaf.leaf_version | parity,
            internal_key: *internal_key,
            merkle_path: proof,
        })
    }

    /// Serialize the control block to bytes.
    /// Format: [leaf_version_and_parity (1)] [internal_key (32)] [merkle_path (32*n)]
    pub fn serialize(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(1 + 32 + self.merkle_path.len() * 32);
        out.push(self.leaf_version_and_parity);
        out.extend_from_slice(&self.internal_key);
        for hash in &self.merkle_path {
            out.extend_from_slice(hash);
        }
        out
    }
}

/// Calculate balanced leaf depths for n scripts.
/// Matches ark-core's `calculate_leaf_depths`.
pub fn calculate_leaf_depths(n: usize) -> Vec<usize> {
    if n == 0 {
        return Vec::new();
    }
    if n == 1 {
        return alloc::vec![0];
    }

    let mut depths = Vec::with_capacity(n);
    let depth = log2_ceil(n);
    let full = 1usize << depth;
    let overflow = n - (full / 2);
    let shallow = n - overflow;

    // First `shallow` leaves are at depth-1, remaining at depth
    // Actually, for a balanced tree: bottom level has `overflow` leaves at depth,
    // and (full/2 - overflow) are at depth-1 ... but the ark-core implementation
    // is simpler: all leaves at the same depth for powers of 2, otherwise
    // fill bottom level first.
    //
    // Matching ark-core exactly:
    // n=2 -> [1, 1]
    // n=3 -> [2, 2, 1]  (two at depth 2, one at depth 1)
    // n=4 -> [2, 2, 2, 2]
    let _ = shallow; // suppress unused

    // Use the standard approach: build a tree and measure depths
    fn assign_depths(remaining: usize, depth: usize, result: &mut Vec<usize>) {
        if remaining == 0 {
            return;
        }
        if remaining == 1 {
            result.push(depth);
            return;
        }
        let left = (remaining + 1) / 2;
        let right = remaining - left;
        assign_depths(left, depth + 1, result);
        assign_depths(right, depth + 1, result);
    }

    assign_depths(n, 0, &mut depths);
    depths
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Bitcoin-style compact size encoding.
fn compact_size_encode(n: usize, out: &mut Vec<u8>) {
    if n < 0xfd {
        out.push(n as u8);
    } else if n <= 0xffff {
        out.push(0xfd);
        out.extend_from_slice(&(n as u16).to_le_bytes());
    } else if n <= 0xffff_ffff {
        out.push(0xfe);
        out.extend_from_slice(&(n as u32).to_le_bytes());
    } else {
        out.push(0xff);
        out.extend_from_slice(&(n as u64).to_le_bytes());
    }
}

/// Compute taggedHash("TapBranch", sorted(a, b)).
fn branch_hash(a: &[u8; 32], b: &[u8; 32]) -> [u8; 32] {
    let (first, second) = if a[..] <= b[..] { (a, b) } else { (b, a) };
    let mut preimage = [0u8; 64];
    preimage[..32].copy_from_slice(first);
    preimage[32..].copy_from_slice(second);
    tagged_hash_raw("TapBranch", &preimage)
}

/// Ceiling of log2(n).
fn log2_ceil(n: usize) -> usize {
    if n <= 1 {
        return 0;
    }
    let mut v = n - 1;
    let mut r = 0;
    while v > 0 {
        v >>= 1;
        r += 1;
    }
    r
}
