//! Contract TEMPLATE + variable composition (Phase 2).
//!
//! A contract becomes `template + variable input`: a TEMPLATE component imports `author:config/vars`
//! (typed config getters) and exports `evaluate`; an author supplies TYPED config values. The
//! cosigner SYNTHESIZES a generic provider component by patching a key-value blob into a pre-compiled
//! fixture's data slot (no compiler), then COMPOSES the patched provider into the template — wiring
//! the provider's `author:config/vars` export into the template's import. The result imports only
//! `bitcoin:contract/crypto` and exports `evaluate`: a self-contained contract whose `sha256` (the
//! bound `contract_id`) commits the author's variables.

use std::io::Write;
use std::path::PathBuf;

use wasm_compose::composer::ComponentComposer;
use wasm_compose::config::Config;

/// The 8-byte marker a provider stub stamps at the start of its config slot.
const MAGIC: &[u8] = b"CFGSLOT!";
/// Max KV-blob a stub's slot can hold (must match the SDK provider stub's `SLOT_CAP`).
const SLOT_CAP: usize = 4096;

/// A typed config value the author sets for a template variable.
///
/// NOTE: in production the cosigner never builds these — the CLIENT collects the typed values from
/// the template's schema, encodes them (Dart `encodeContractConfig`, same KV format as below), and
/// sends the ready `config_blob` that `synthesize_provider` patches. `ConfigValue` / `encode_kv` /
/// `compose_with_config` are a Rust mirror of that format, exercised only by the tests below.
#[cfg(test)]
#[derive(Debug, Clone)]
pub enum ConfigValue {
    Bytes(Vec<u8>),
    U64(u64),
    Str(String),
}

/// Encode `[n: u16 LE]` then n × `[key_len: u8][key][type: u8][val_len: u16 LE][val]`
/// (type: 0 = bytes, 1 = u64 LE, 2 = string) — the KV blob the generic provider decodes.
#[cfg(test)]
pub fn encode_kv(entries: &[(String, ConfigValue)]) -> Result<Vec<u8>, String> {
    let mut out = Vec::new();
    let n: u16 = entries
        .len()
        .try_into()
        .map_err(|_| "too many config entries".to_string())?;
    out.extend_from_slice(&n.to_le_bytes());
    for (key, val) in entries {
        let kb = key.as_bytes();
        if kb.len() > u8::MAX as usize {
            return Err(format!("config key `{key}` too long"));
        }
        out.push(kb.len() as u8);
        out.extend_from_slice(kb);
        let (ty, vb): (u8, Vec<u8>) = match val {
            ConfigValue::Bytes(b) => (0, b.clone()),
            ConfigValue::U64(u) => (1, u.to_le_bytes().to_vec()),
            ConfigValue::Str(s) => (2, s.as_bytes().to_vec()),
        };
        let vlen: u16 = vb
            .len()
            .try_into()
            .map_err(|_| format!("config value for `{key}` too long"))?;
        out.push(ty);
        out.extend_from_slice(&vlen.to_le_bytes());
        out.extend_from_slice(&vb);
    }
    Ok(out)
}

/// Synthesize a concrete provider component by patching `kv_blob` into a provider STUB's slot.
/// The stub is the template's published, schema-matching provider (it exports the template's typed
/// config interface, reading each value from this patchable slot).
pub fn synthesize_provider(stub: &[u8], kv_blob: &[u8]) -> Result<Vec<u8>, String> {
    if kv_blob.len() > SLOT_CAP {
        return Err(format!(
            "config blob {} bytes exceeds provider capacity {SLOT_CAP}",
            kv_blob.len()
        ));
    }
    let mut bytes = stub.to_vec();
    let pos = bytes
        .windows(MAGIC.len())
        .position(|w| w == MAGIC)
        .ok_or("config slot marker not found in provider stub")?;
    let slot = pos + MAGIC.len();
    let len = kv_blob.len() as u16;
    bytes[slot..slot + 2].copy_from_slice(&len.to_le_bytes());
    bytes[slot + 2..slot + 2 + kv_blob.len()].copy_from_slice(kv_blob);
    Ok(bytes)
}

/// Compose `template` (imports `author:config/vars` + `crypto`) with `provider` (exports
/// `author:config/vars`) into one component importing only `crypto` and exporting `evaluate`.
pub fn compose(template: &[u8], provider: &[u8]) -> Result<Vec<u8>, String> {
    let dir = tempfile::tempdir().map_err(|e| format!("tempdir: {e}"))?;
    let template_path = dir.path().join("template.wasm");
    let provider_path = dir.path().join("provider.wasm");
    write_file(&template_path, template)?;
    write_file(&provider_path, provider)?;

    // `definitions` are components whose EXPORTS satisfy the root's imports; wasm-compose wires the
    // provider's `author:config/vars` export into the template's import and leaves `crypto` imported.
    let config = Config {
        dir: dir.path().to_path_buf(),
        definitions: vec![PathBuf::from("provider.wasm")],
        ..Default::default()
    };
    ComponentComposer::new(&template_path, &config)
        .compose()
        .map_err(|e| format!("compose: {e:#}"))
}

/// One-shot: patch typed config into the template's provider `stub` + compose it into `template`.
/// Test-only convenience (production patches a client-encoded `config_blob` directly).
#[cfg(test)]
pub fn compose_with_config(
    template: &[u8],
    stub: &[u8],
    entries: &[(String, ConfigValue)],
) -> Result<Vec<u8>, String> {
    let blob = encode_kv(entries)?;
    let provider = synthesize_provider(stub, &blob)?;
    compose(template, &provider)
}

fn write_file(path: &std::path::Path, bytes: &[u8]) -> Result<(), String> {
    let mut f = std::fs::File::create(path).map_err(|e| format!("create {path:?}: {e}"))?;
    f.write_all(bytes)
        .map_err(|e| format!("write {path:?}: {e}"))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::contract::{ContractEngine, EvalContext, Transaction, Txout, Verdict};

    const TEMPLATE: &[u8] = include_bytes!("../../../contracts/fixtures/oracle_gate_template.wasm");
    const STUB: &[u8] = include_bytes!("../../../contracts/fixtures/config_provider.wasm");

    fn ctx(args: &[u8], total: u64) -> EvalContext {
        EvalContext {
            tx: Transaction {
                version: 2,
                lock_time: 0,
                inputs: vec![],
                outputs: vec![Txout {
                    value: total,
                    script_pubkey: vec![],
                }],
            },
            prevouts: vec![],
            input_index: 0,
            contract_args: args.to_vec(),
        }
    }

    fn composed() -> Vec<u8> {
        compose_with_config(
            TEMPLATE,
            STUB,
            &[
                (
                    "oracle-token".into(),
                    ConfigValue::Bytes(b"ORACLE-OK".to_vec()),
                ),
                ("max-sats".into(), ConfigValue::U64(50_000)),
            ],
        )
        .expect("compose")
    }

    #[test]
    fn composed_imports_only_crypto() {
        let wasm = composed();
        let engine = ContractEngine::new().unwrap();
        // The strict validator rejects anything not under `bitcoin:contract/` — so a passing
        // composed component proves the `author:config` import was satisfied internally.
        engine
            .validate(&wasm)
            .expect("composed must import only crypto");
    }

    #[test]
    fn baked_config_drives_evaluate() {
        let wasm = composed();
        let engine = ContractEngine::new().unwrap();
        let component = engine.compile(&wasm).unwrap();

        // good token, under the per-instance 50k limit -> Allow
        assert!(matches!(
            engine.evaluate(&component, &ctx(b"ORACLE-OK", 40_000)),
            Verdict::Allow
        ));
        // good token, OVER the per-instance 50k limit (but under the old hardcoded 100k) -> Deny
        assert!(matches!(
            engine.evaluate(&component, &ctx(b"ORACLE-OK", 60_000)),
            Verdict::Deny(_)
        ));
        // wrong token -> Deny
        assert!(matches!(
            engine.evaluate(&component, &ctx(b"WRONG", 40_000)),
            Verdict::Deny(_)
        ));
    }
}
