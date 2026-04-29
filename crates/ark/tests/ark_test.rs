extern crate alloc;

use ark::taptree::{TapLeaf, TapNode, UNSPENDABLE_KEY_X_ONLY};

/// Helper: encode bytes as hex string.
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

#[test]
fn test_multisig_script() {
    // Known test vectors — 32-byte x-only keys
    let server_pk = [0x01u8; 32];
    let owner_pk = [0x02u8; 32];

    let script = ark::multisig_script(&server_pk, &owner_pk);

    // Expected: 0x20 || server_pk(32) || OP_CHECKSIGVERIFY(0xad) || 0x20 || owner_pk(32) || OP_CHECKSIG(0xac)
    // PUSH(1) + server(32) + CHECKSIGVERIFY(1) + PUSH(1) + owner(32) + CHECKSIG(1) = 68
    assert_eq!(script.len(), 68);
    assert_eq!(script[0], 0x20); // OP_PUSHBYTES_32
    assert_eq!(&script[1..33], &server_pk);
    assert_eq!(script[33], 0xad); // OP_CHECKSIGVERIFY
    assert_eq!(script[34], 0x20); // OP_PUSHBYTES_32
    assert_eq!(&script[35..67], &owner_pk);
    assert_eq!(script[67], 0xac); // OP_CHECKSIG
}

#[test]
fn test_csv_sig_script() {
    let owner_pk = [0x02u8; 32];
    let exit_delay = 512u32; // 0x0200

    let script = ark::csv_sig_script(exit_delay, &owner_pk);

    // Expected: 0x20 || owner_pk(32) || OP_CHECKSIGVERIFY(0xad) || push(512) || OP_CSV(0xb2) || OP_DROP(0x75)
    // 512 = 0x0200 in script number encoding = [0x00, 0x02] (little-endian, 2 bytes)
    // Push: 0x02 (push 2 bytes) || 0x00 0x02
    assert_eq!(script[0], 0x20);
    assert_eq!(&script[1..33], &owner_pk);
    assert_eq!(script[33], 0xad); // OP_CHECKSIGVERIFY

    // Check CSV and DROP at the end
    let len = script.len();
    assert_eq!(script[len - 2], 0xb2); // OP_CSV
    assert_eq!(script[len - 1], 0x75); // OP_DROP
}

#[test]
fn test_csv_sig_script_small_delay() {
    let owner_pk = [0x03u8; 32];
    let exit_delay = 10u32;

    let script = ark::csv_sig_script(exit_delay, &owner_pk);

    // exit_delay = 10 should use OP_10 (0x5a)
    assert_eq!(script[0], 0x20);
    assert_eq!(&script[1..33], &owner_pk);
    assert_eq!(script[33], 0xad);
    assert_eq!(script[34], 0x5a); // OP_10 = 0x50 + 10
    assert_eq!(script[35], 0xb2); // OP_CSV
    assert_eq!(script[36], 0x75); // OP_DROP
}

#[test]
fn test_default_vtxo_tree_structure() {
    let server_pk = [0xaa; 32];
    let owner_pk = [0xbb; 32];
    let exit_delay = 1024;

    let tree = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);

    // Tree should be a branch with two leaves
    match &tree {
        TapNode::Branch(left, right) => {
            match (left.as_ref(), right.as_ref()) {
                (TapNode::Leaf(l0), TapNode::Leaf(l1)) => {
                    // Verify leaf 0 is the forfeit script
                    assert_eq!(l0.script, ark::multisig_script(&server_pk, &owner_pk));
                    // Verify leaf 1 is the exit script
                    assert_eq!(l1.script, ark::csv_sig_script(exit_delay, &owner_pk));
                }
                _ => panic!("Expected two leaf children"),
            }
        }
        _ => panic!("Expected branch node at root"),
    }
}

#[test]
fn test_tapleaf_hash_deterministic() {
    let script = vec![0x20, 0xaau8, 0xac]; // dummy script
    let leaf = TapLeaf::new(script.clone());

    let h1 = leaf.hash();
    let h2 = leaf.hash();
    assert_eq!(h1, h2, "TapLeaf hash should be deterministic");

    // Different script should produce different hash
    let other = TapLeaf::new(vec![0x20, 0xbb, 0xac]);
    assert_ne!(leaf.hash(), other.hash());
}

#[test]
fn test_merkle_proof_and_control_block() {
    let server_pk = [0x11; 32];
    let owner_pk = [0x22; 32];
    let exit_delay = 144;

    let tree = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);
    let forfeit_leaf = TapLeaf::new(ark::multisig_script(&server_pk, &owner_pk));
    let exit_leaf = TapLeaf::new(ark::csv_sig_script(exit_delay, &owner_pk));

    // Merkle proofs should exist for both leaves
    let proof0 = tree.merkle_proof(&forfeit_leaf).expect("forfeit leaf should be found");
    let proof1 = tree.merkle_proof(&exit_leaf).expect("exit leaf should be found");

    // For a 2-leaf tree at depth 1, each proof should have exactly 1 sibling
    assert_eq!(proof0.len(), 1, "forfeit proof should have 1 sibling");
    assert_eq!(proof1.len(), 1, "exit proof should have 1 sibling");

    // The sibling of forfeit is exit's hash and vice versa
    assert_eq!(proof0[0], exit_leaf.hash());
    assert_eq!(proof1[0], forfeit_leaf.hash());

    // Control blocks should be constructible
    let cb0 = ark::taptree::ControlBlock::new(
        &UNSPENDABLE_KEY_X_ONLY,
        &forfeit_leaf,
        &tree,
    )
    .expect("forfeit control block");

    let cb1 = ark::taptree::ControlBlock::new(
        &UNSPENDABLE_KEY_X_ONLY,
        &exit_leaf,
        &tree,
    )
    .expect("exit control block");

    // Control block serialization
    let cb0_bytes = cb0.serialize();
    let cb1_bytes = cb1.serialize();

    // Size: 1 (version+parity) + 32 (internal key) + 32 (1 sibling) = 65
    assert_eq!(cb0_bytes.len(), 65);
    assert_eq!(cb1_bytes.len(), 65);

    // Internal key should be UNSPENDABLE_KEY x-only
    assert_eq!(&cb0_bytes[1..33], &UNSPENDABLE_KEY_X_ONLY);
    assert_eq!(&cb1_bytes[1..33], &UNSPENDABLE_KEY_X_ONLY);

    // Leaf version should be 0xc0 (possibly | parity bit)
    assert!(cb0_bytes[0] == 0xc0 || cb0_bytes[0] == 0xc1);
    assert!(cb1_bytes[0] == 0xc0 || cb1_bytes[0] == 0xc1);
}

#[test]
fn test_vtxo_output_key_deterministic() {
    let server_pk = [0x11; 32];
    let owner_pk = [0x22; 32];
    let exit_delay = 144;

    let tree = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);
    let key1 = ark::vtxo_output_key(&tree).expect("should derive output key");
    let key2 = ark::vtxo_output_key(&tree).expect("should derive output key");

    assert_eq!(key1, key2, "Output key should be deterministic");
    assert_eq!(key1.len(), 33);
    // First byte should be 0x02 or 0x03
    assert!(key1[0] == 0x02 || key1[0] == 0x03);
}

#[test]
fn test_vtxo_script_pubkey() {
    let server_pk = [0x11; 32];
    let owner_pk = [0x22; 32];
    let exit_delay = 144;

    let tree = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);
    let spk = ark::vtxo_script_pubkey(&tree).expect("should derive script pubkey");

    assert_eq!(spk[0], 0x51); // OP_1
    assert_eq!(spk[1], 0x20); // OP_PUSHBYTES_32
    assert_eq!(spk.len(), 34);
}

#[test]
fn test_forfeit_and_exit_spend_info() {
    let server_pk = [0xaa; 32];
    let owner_pk = [0xbb; 32];
    let exit_delay = 512;

    let (forfeit_script, forfeit_cb) =
        ark::forfeit_spend_info(&server_pk, &owner_pk, exit_delay)
            .expect("forfeit spend info");

    let (exit_script, exit_cb) =
        ark::exit_spend_info(&server_pk, &owner_pk, exit_delay)
            .expect("exit spend info");

    // Scripts should match the expected format
    assert_eq!(forfeit_script, ark::multisig_script(&server_pk, &owner_pk));
    assert_eq!(exit_script, ark::csv_sig_script(exit_delay, &owner_pk));

    // Both control blocks should have the same parity since they share the same output key
    assert_eq!(
        forfeit_cb.leaf_version_and_parity & 1,
        exit_cb.leaf_version_and_parity & 1,
        "Both leaves share the same output key parity"
    );
}

#[test]
fn test_leaf_not_in_tree() {
    let server_pk = [0x11; 32];
    let owner_pk = [0x22; 32];
    let exit_delay = 144;

    let tree = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);

    // A random leaf that's NOT in the tree
    let fake_leaf = TapLeaf::new(vec![0xde, 0xad, 0xbe, 0xef]);
    assert!(tree.merkle_proof(&fake_leaf).is_none());
}

#[test]
fn test_calculate_leaf_depths() {
    use ark::taptree::calculate_leaf_depths;

    assert_eq!(calculate_leaf_depths(0), Vec::<usize>::new());
    assert_eq!(calculate_leaf_depths(1), vec![0]);
    assert_eq!(calculate_leaf_depths(2), vec![1, 1]);

    // 3 leaves: two at depth 2, one at depth 1
    let d3 = calculate_leaf_depths(3);
    assert_eq!(d3.len(), 3);
    // Should contain depths 1 and 2
    assert!(d3.contains(&1));
    assert!(d3.contains(&2));

    // 4 leaves: all at depth 2
    assert_eq!(calculate_leaf_depths(4), vec![2, 2, 2, 2]);
}

#[test]
fn test_branch_hash_sorted() {
    // BIP-341 requires branch hash children to be sorted lexicographically.
    // Creating the same tree with swapped children should produce the same root hash.
    let leaf_a = TapLeaf::new(vec![0x01]);
    let leaf_b = TapLeaf::new(vec![0x02]);

    let tree_ab = TapNode::Branch(
        Box::new(TapNode::Leaf(leaf_a.clone())),
        Box::new(TapNode::Leaf(leaf_b.clone())),
    );
    let tree_ba = TapNode::Branch(
        Box::new(TapNode::Leaf(leaf_b)),
        Box::new(TapNode::Leaf(leaf_a)),
    );

    assert_eq!(
        tree_ab.merkle_root(),
        tree_ba.merkle_root(),
        "Branch hash should be order-independent (sorted internally)"
    );
}

#[test]
fn test_single_leaf_tree() {
    let leaf = TapLeaf::new(vec![0xca, 0xfe]);
    let tree = TapNode::Leaf(leaf.clone());

    // Merkle root of a single leaf is just the leaf hash
    assert_eq!(tree.merkle_root(), leaf.hash());

    // Proof for the single leaf is empty
    let proof = tree.merkle_proof(&leaf).unwrap();
    assert!(proof.is_empty());
}

#[test]
fn test_hex_output_consistency() {
    // Verify that script pubkey hex is stable
    let server_pk = [0x11; 32];
    let owner_pk = [0x22; 32];
    let exit_delay = 144;

    let tree1 = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);
    let tree2 = ark::default_vtxo_tree(&server_pk, &owner_pk, exit_delay);

    let spk1 = ark::vtxo_script_pubkey(&tree1).unwrap();
    let spk2 = ark::vtxo_script_pubkey(&tree2).unwrap();
    assert_eq!(hex(&spk1), hex(&spk2));
}
