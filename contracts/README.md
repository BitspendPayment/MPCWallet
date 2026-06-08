# Bitcoin programmability via off-chain WASM contracts

Funds locked in an **eVTXO** (executable VTXO) are governed by a user-supplied
**WASM smart contract**. When the cosigner is asked to co-sign a spend of an
eVTXO's contract leaf, it runs the committed contract — giving it the full
transaction for introspection — and **only releases its FROST signature share if
the contract returns `allow`**. Contracts run with **no WASI**: their only window
on the world is the transaction structure plus a host-provided `crypto`
interface.

A WASM guest cannot instantiate WASM, so the **native host** (`cosigner-runtime`,
embedding wasmtime) runs the contract and gates the signature — the same shape as
the existing spending-policy check. Programmability is therefore an *off-chain
covenant enforced by the threshold signer*, bound on-chain by a hashlock leaf to
the contract's code hash.

## Pieces (all built & tested)

| Piece | Where |
|---|---|
| Shared contract ABI (`evaluate(eval-context) -> verdict`, `import crypto`) | [`cosigner-runtime/wit/contract.wit`](../cosigner-runtime/wit/contract.wit) |
| Sandbox engine (no-WASI linker, fuel/memory limits, fail-closed) | `cosigner-runtime/src/contract/engine.rs` |
| Host-native `crypto` (sha2/secp256k1) | `cosigner-runtime/src/contract/crypto_host.rs` |
| Registry (in-memory / local-dir / **Warg** content-fetch) + compiled cache | `cosigner-runtime/src/contract/registry.rs` |
| On-chain leaf `OP_SHA256 <commit> OP_EQUALVERIFY <evtxo_pk> OP_CHECKSIG` | `crates/ark/src/lib.rs` (`contract_script`, `evtxo_tree`, `contract_spend_info`) |
| Leaf detection + the signing gate (fail-closed) | `cosigner-runtime/src/bitcoin/tx_parser.rs`, `cosigner-runtime/src/cosigner/handlers/contract_gate.rs` |
| no_std contract SDK (allocator/panic/cabi_realloc via `runtime!()`) | `contracts/contract-sdk` |
| Example contract | `contracts/examples/spending-limit` |

## Authoring a contract

```rust
#![no_std]
extern crate alloc;
contract_sdk::runtime!();                                   // allocator + panic + cabi_realloc
wit_bindgen::generate!({ world: "contract", path: "wit" });

struct Component;
impl Guest for Component {
    fn evaluate(ctx: EvalContext) -> Verdict { /* introspect ctx.tx; allow/deny */ }
}
export!(Component);
```

Build the component (its sha256 digest **is** the `contract_id`):

```bash
make contracts-build      # or: cd contracts/examples/spending-limit && cargo build --release
```

## Identity & commitment

- `contract_id = sha256(component_wasm)` — revealed in the spend witness, and the
  key the registry resolves.
- `commit = sha256(contract_id)` — committed in the on-chain tapleaf.
- The gate re-checks `sha256(registered_contract_id) == commit` from the PSBT's
  tap leaf, so a registered contract can't be swapped for the on-chain one.

## Registry configuration

- Default: local dir — `<data_dir>/contracts/<hex(contract_id)>.wasm`.
- Warg: set `CONTRACT_REGISTRY_URL=https://<registry>`; the runtime fetches
  `GET <url>/content/sha256:<hex>` and re-verifies the hash.

## The one remaining integration seam

The gate is **fail-closed**: a contract-leaf spend with no registration is
denied. So an eVTXO must be registered when its address is created. The host-side
write already exists:

```rust
contract_gate::register_evtxo_contract(persistence, &evtxo_script_pubkey, &contract_id)?;
```

To go live, expose eVTXO address creation to clients (a REST route, mirroring the
existing per-user handlers): derive the address with
`ark::evtxo_script_pubkey(commit, server_evtxo_pk, owner_pk, exit_delay)` and call
`register_evtxo_contract`. That is the only piece not yet wired end-to-end.

## Regtest e2e plan (needs Docker / bitcoind / arkd)

Extends `e2e/test/`:

1. `make contracts-build` and publish `spending-limit.wasm` to the registry
   (local dir or Warg) under its sha256.
2. Create an eVTXO bound to that contract; register `spk -> contract_id`.
3. Fund the eVTXO on regtest.
4. **Within-limit spend** (output ≤ 100_000 sats): cosigner co-signs, tx
   confirms.
5. **Over-limit spend** (> 100_000 sats): `sign_step1` returns
   `permission_denied`; no signature share is produced.
6. (Hardening) a contract-leaf spend with the registration removed → denied
   (fail-closed), and a mismatched registration → denied.

Steps 4–6 are covered at the unit level today in `contract_gate::tests` (real
`TaprootBuilder` PSBTs); the regtest run exercises the same paths against a live
chain.
