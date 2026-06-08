//! Off-chain contract gate. Before the cosigner co-signs a spend, run any
//! contract bound to an eVTXO input and refuse to sign (no FROST share produced)
//! on a `Deny` verdict. A wasm guest cannot instantiate wasm, so this runs in
//! the native host and gates the signature — analogous to the spending-policy
//! check, just richer.
//!
//! Which contract governs an input is resolved from host storage: the
//! `evtxo_contract` tree maps an eVTXO scriptPubKey (hex) -> contract_id (hex),
//! populated when the eVTXO address is created. The eVTXO's cooperative leaf is
//! keyed by the 2-of-2 contract key V′, so the cosigner is a mandatory signer and
//! this gate runs on every cooperative spend; the contract binding is off-chain
//! (this map), not an on-chain commitment.

use tonic::Status;

use crate::contract::{crypto_host, ContractHost, Verdict};
use crate::bitcoin::tx_parser;
use crate::persistence::{KvStore, PersistenceError};
use crate::shared::SharedServices;

/// Persistence tree: eVTXO scriptPubKey (hex) -> contract_id (hex).
pub const EVTXO_CONTRACT_TREE: &str = "evtxo_contract";

/// Register the contract bound to an eVTXO output. Called when an eVTXO address
/// is created (alongside generating its V′ key) so the gate can resolve
/// `contract_id` at spend time from the input's scriptPubKey.
pub fn register_evtxo_contract(
    persistence: &dyn KvStore,
    evtxo_script_pubkey: &[u8],
    contract_id: &[u8; 32],
) -> Result<(), PersistenceError> {
    persistence.put(
        EVTXO_CONTRACT_TREE,
        &hex::encode(evtxo_script_pubkey),
        &hex::encode(contract_id),
    )
}

/// Derive an eVTXO's scriptPubKey from its keys (split-key tree: cooperative
/// leaf = `server_pk` + `evtxo_pk` = V′, exit leaf = `owner_pk` = main V) and
/// register the governing contract under it. Returns the 34-byte spk. Called
/// when an eVTXO address is created (after resharing yields V′). `*_xonly_hex`
/// are 64-char x-only hex.
pub fn register_evtxo(
    persistence: &dyn KvStore,
    server_pk_xonly_hex: &str,
    evtxo_pk_xonly_hex: &str,
    owner_pk_xonly_hex: &str,
    exit_delay: u32,
    contract_id: &[u8; 32],
) -> Result<Vec<u8>, Status> {
    let server = decode_xonly(server_pk_xonly_hex)?;
    let evtxo = decode_xonly(evtxo_pk_xonly_hex)?;
    let owner = decode_xonly(owner_pk_xonly_hex)?;
    // On-chain commitment to the contract: commit = sha256(contract_id),
    // contract_id = sha256(component_wasm). The cooperative leaf hashlocks on it.
    let mut commit = [0u8; 32];
    commit.copy_from_slice(&crypto_host::sha256(contract_id));
    let spk = ark::evtxo_script_pubkey(&commit, &server, &evtxo, &owner, exit_delay)
        .map_err(|e| Status::internal(format!("eVTXO script pubkey: {e:?}")))?;
    register_evtxo_contract(persistence, &spk, contract_id)
        .map_err(|e| Status::internal(format!("register eVTXO contract: {e}")))?;
    Ok(spk.to_vec())
}

fn decode_xonly(hex_str: &str) -> Result<[u8; 32], Status> {
    let v = hex::decode(hex_str)
        .map_err(|e| Status::invalid_argument(format!("invalid x-only hex: {e}")))?;
    if v.len() != 32 {
        return Err(Status::invalid_argument("expected 32-byte x-only key"));
    }
    let mut a = [0u8; 32];
    a.copy_from_slice(&v);
    Ok(a)
}

/// If the spend touches a registered eVTXO (matched by an input's
/// scriptPubKey), return that eVTXO's spk hex — the key into `evtxo_policies`.
/// `sign_step1` uses it to select the V′ key and mark the signing session.
pub fn detect_evtxo_spend(
    policy_state: &crate::policy::PolicyState,
    full_transaction: &[u8],
) -> Option<String> {
    let psbt = bitcoin::Psbt::deserialize(full_transaction).ok()?;
    for input in &psbt.inputs {
        if let Some(utxo) = input.witness_utxo.as_ref() {
            let spk_hex = hex::encode(utxo.script_pubkey.as_bytes());
            if policy_state.evtxo_policies.contains_key(&spk_hex) {
                return Some(spk_hex);
            }
        }
    }
    None
}

/// Run the contract gate over a spend. No-op when contracts are disabled or the
/// transaction isn't a PSBT (we need witness_utxo prevouts for introspection).
pub fn enforce_contracts(shared: &SharedServices, full_transaction: &[u8]) -> Result<(), Status> {
    let Some(host) = shared.contract_host.as_ref() else {
        return Ok(());
    };
    enforce(shared.persistence.as_ref(), host, full_transaction)
}

/// Core gate logic, decoupled from `SharedServices` for testability.
pub(crate) fn enforce(
    persistence: &dyn KvStore,
    host: &ContractHost,
    full_transaction: &[u8],
) -> Result<(), Status> {
    let Ok(psbt) = bitcoin::Psbt::deserialize(full_transaction) else {
        return Ok(()); // raw tx / not a PSBT — no prevouts to introspect
    };

    // Prevouts 1:1 with inputs (zero-value placeholder where unknown).
    let prevouts: Vec<bitcoin::TxOut> = psbt
        .inputs
        .iter()
        .map(|i| {
            i.witness_utxo.clone().unwrap_or_else(|| bitcoin::TxOut {
                value: bitcoin::Amount::from_sat(0),
                script_pubkey: bitcoin::ScriptBuf::new(),
            })
        })
        .collect();

    for (idx, input) in psbt.inputs.iter().enumerate() {
        // Detect an eVTXO by its scriptPubKey: the cosigner co-signs the
        // cooperative (V′) leaf, so any spend of a registered eVTXO that reaches
        // the cosigner runs that eVTXO's contract. (Unilateral exit on the main
        // key V doesn't involve the cosigner, so it isn't gated here.)
        let Some(utxo) = input.witness_utxo.as_ref() else {
            continue;
        };
        let spk_hex = hex::encode(utxo.script_pubkey.as_bytes());
        let contract_id = match persistence.get(EVTXO_CONTRACT_TREE, &spk_hex) {
            Ok(Some(cid_hex)) => decode_id(&cid_hex),
            _ => continue, // not a registered eVTXO — out of scope for the gate
        };
        let Some(contract_id) = contract_id else {
            return Err(Status::internal(format!(
                "corrupt contract registration for eVTXO {spk_hex}"
            )));
        };

        // Off-chain caller data for this specific input (e.g. an oracle packet),
        // carried in the input's PSBT proprietary map and stripped before broadcast.
        let contract_args = tx_parser::read_contract_args(input);
        let ctx =
            tx_parser::build_eval_context(&psbt.unsigned_tx, &prevouts, idx as u32, contract_args);
        if let Verdict::Deny(reason) = host.evaluate_by_id(&contract_id, &ctx) {
            return Err(Status::permission_denied(format!(
                "contract denied spend of input {idx}: {reason}"
            )));
        }
    }
    Ok(())
}

fn decode_id(hex_str: &str) -> Option<[u8; 32]> {
    let v = hex::decode(hex_str).ok()?;
    (v.len() == 32).then(|| {
        let mut id = [0u8; 32];
        id.copy_from_slice(&v);
        id
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::contract::InMemoryRegistry;
    use crate::persistence::PersistenceError;
    use std::collections::HashMap;
    use std::sync::Mutex;

    // Minimal in-memory KvStore for gate tests.
    #[derive(Default)]
    struct MemStore(Mutex<HashMap<String, String>>);
    impl KvStore for MemStore {
        fn get(&self, tree: &str, key: &str) -> Result<Option<String>, PersistenceError> {
            Ok(self.0.lock().unwrap().get(&format!("{tree}/{key}")).cloned())
        }
        fn put(&self, tree: &str, key: &str, value: &str) -> Result<(), PersistenceError> {
            self.0
                .lock()
                .unwrap()
                .insert(format!("{tree}/{key}"), value.to_string());
            Ok(())
        }
        fn delete(&self, tree: &str, key: &str) -> Result<(), PersistenceError> {
            self.0.lock().unwrap().remove(&format!("{tree}/{key}"));
            Ok(())
        }
        fn get_all(&self, _tree: &str) -> Result<HashMap<String, String>, PersistenceError> {
            Ok(HashMap::new())
        }
        fn clear(&self, _tree: &str) -> Result<(), PersistenceError> {
            Ok(())
        }
    }

    fn example_wasm() -> Vec<u8> {
        let p = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("contracts/examples/spending-limit/target/wasm32-wasip2/release/spending_limit.wasm");
        std::fs::read(&p).unwrap_or_else(|_| {
            panic!("build the contract first: (cd contracts/examples/spending-limit && cargo build --release)")
        })
    }

    /// A real eVTXO scriptPubKey (commit + cooperative=V′, exit=V).
    fn evtxo_spk() -> bitcoin::ScriptBuf {
        let spk =
            ark::evtxo_script_pubkey(&[0x44; 32], &[0x11; 32], &[0x22; 32], &[0x33; 32], 144).unwrap();
        bitcoin::ScriptBuf::from_bytes(spk.to_vec())
    }

    /// Build a PSBT spending `spk` (as the input's prevout) with one output of
    /// `out_value` sats. Detection is by scriptPubKey, so no tap leaves needed.
    fn psbt_spending(spk: &bitcoin::ScriptBuf, out_value: u64) -> Vec<u8> {
        use bitcoin::hashes::Hash as _;
        let unsigned = bitcoin::Transaction {
            version: bitcoin::transaction::Version::TWO,
            lock_time: bitcoin::absolute::LockTime::ZERO,
            input: vec![bitcoin::TxIn {
                previous_output: bitcoin::OutPoint {
                    txid: bitcoin::Txid::from_byte_array([1u8; 32]),
                    vout: 0,
                },
                script_sig: bitcoin::ScriptBuf::new(),
                sequence: bitcoin::Sequence::ENABLE_RBF_NO_LOCKTIME,
                witness: bitcoin::Witness::new(),
            }],
            output: vec![bitcoin::TxOut {
                value: bitcoin::Amount::from_sat(out_value),
                script_pubkey: bitcoin::ScriptBuf::new(),
            }],
        };
        let mut psbt = bitcoin::Psbt::from_unsigned_tx(unsigned).unwrap();
        psbt.inputs[0].witness_utxo = Some(bitcoin::TxOut {
            value: bitcoin::Amount::from_sat(1_000_000),
            script_pubkey: spk.clone(),
        });
        psbt.serialize()
    }

    fn host_with_example() -> (ContractHost, [u8; 32]) {
        let mut reg = InMemoryRegistry::new();
        let id = reg.insert(example_wasm());
        (ContractHost::new(Box::new(reg)).unwrap(), id)
    }

    fn oracle_gate_wasm() -> Vec<u8> {
        let p = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("contracts/examples/oracle-gate/target/wasm32-wasip2/release/oracle_gate.wasm");
        std::fs::read(&p).unwrap_or_else(|_| {
            panic!("build the contract first: (cd contracts/examples/oracle-gate && cargo build --release)")
        })
    }

    fn host_with_oracle() -> (ContractHost, [u8; 32]) {
        let mut reg = InMemoryRegistry::new();
        let id = reg.insert(oracle_gate_wasm());
        (ContractHost::new(Box::new(reg)).unwrap(), id)
    }

    /// Like `psbt_spending`, but attaches `args` to the input's PSBT proprietary
    /// map under the `EVTXO/0x01` key the gate reads as `ctx.contract_args`.
    fn psbt_spending_with_args(spk: &bitcoin::ScriptBuf, out_value: u64, args: &[u8]) -> Vec<u8> {
        let bytes = psbt_spending(spk, out_value);
        let mut psbt = bitcoin::Psbt::deserialize(&bytes).unwrap();
        psbt.inputs[0].proprietary.insert(
            bitcoin::psbt::raw::ProprietaryKey {
                prefix: tx_parser::CONTRACT_ARGS_PREFIX.to_vec(),
                subtype: tx_parser::CONTRACT_ARGS_SUBTYPE,
                key: vec![],
            },
            args.to_vec(),
        );
        psbt.serialize()
    }

    #[test]
    fn gate_allows_under_and_denies_over() {
        let (host, id) = host_with_example();
        let store = MemStore::default();
        let spk = evtxo_spk();
        register_evtxo_contract(&store, spk.as_bytes(), &id).unwrap();

        // Under the 100_000-sat limit → allowed.
        assert!(enforce(&store, &host, &psbt_spending(&spk, 50_000)).is_ok());

        // Over the limit → permission denied.
        assert_eq!(
            enforce(&store, &host, &psbt_spending(&spk, 200_000))
                .unwrap_err()
                .code(),
            tonic::Code::PermissionDenied
        );
    }

    #[test]
    fn gate_noop_for_unregistered_spk() {
        // A spend whose scriptPubKey isn't a registered eVTXO is never gated,
        // even over-limit (it's a normal VTXO the cosigner signs as today).
        let (host, _id) = host_with_example();
        let store = MemStore::default(); // nothing registered
        assert!(enforce(&store, &host, &psbt_spending(&evtxo_spk(), 200_000)).is_ok());
    }

    #[test]
    fn gate_reads_contract_args_from_psbt_proprietary() {
        // oracle-gate allows only when args == b"ORACLE-OK" AND total ≤ limit.
        let (host, id) = host_with_oracle();
        let store = MemStore::default();
        let spk = evtxo_spk();
        register_evtxo_contract(&store, spk.as_bytes(), &id).unwrap();

        // Good arg + within limit → allowed.
        assert!(
            enforce(&store, &host, &psbt_spending_with_args(&spk, 50_000, b"ORACLE-OK")).is_ok()
        );

        // Good arg + over limit → denied on the amount check.
        assert_eq!(
            enforce(&store, &host, &psbt_spending_with_args(&spk, 200_000, b"ORACLE-OK"))
                .unwrap_err()
                .code(),
            tonic::Code::PermissionDenied
        );

        // Bad arg + within limit → denied on the arg check.
        assert_eq!(
            enforce(&store, &host, &psbt_spending_with_args(&spk, 50_000, b"WRONG"))
                .unwrap_err()
                .code(),
            tonic::Code::PermissionDenied
        );

        // Missing arg (no proprietary key) + within limit → denied on the arg check.
        assert_eq!(
            enforce(&store, &host, &psbt_spending(&spk, 50_000))
                .unwrap_err()
                .code(),
            tonic::Code::PermissionDenied
        );
    }

    #[test]
    fn register_evtxo_derives_spk_and_gates() {
        let (host, id) = host_with_example();
        let store = MemStore::default();
        // x-only hex for server_pk, V′ (evtxo), V (owner).
        let spk = register_evtxo(&store, &"11".repeat(32), &"22".repeat(32), &"33".repeat(32), 144, &id)
            .unwrap();

        // Matches the ark derivation (commit = sha256(contract_id)).
        let mut commit = [0u8; 32];
        commit.copy_from_slice(&crypto_host::sha256(&id));
        let expected =
            ark::evtxo_script_pubkey(&commit, &[0x11; 32], &[0x22; 32], &[0x33; 32], 144).unwrap();
        assert_eq!(spk, expected.to_vec());

        // The gate now fires on a spend of that registered spk.
        let spk_buf = bitcoin::ScriptBuf::from_bytes(spk);
        assert!(enforce(&store, &host, &psbt_spending(&spk_buf, 50_000)).is_ok());
        assert_eq!(
            enforce(&store, &host, &psbt_spending(&spk_buf, 200_000))
                .unwrap_err()
                .code(),
            tonic::Code::PermissionDenied
        );
    }
}
