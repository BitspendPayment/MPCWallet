# Cosigner rearchitecture — handoff / resume point

Status as of 2026-06-22. Branch `v3`. Everything below is **uncommitted** (staged / working-tree)
unless you commit it. Deep implementation notes live in the agent memory file
`~/.claude/projects/-home-joshua-MerlinWallet/memory/ark-crate-wasm-split-recipe.md`
(the recipes + exact edit sets + gotchas). This file is the short, ordered to-do.

## Goal
Enclave-grade key isolation: the WASM **guest** owns all signing keys + per-user state; the
host only does I/O + stores an opaque sealed snapshot. (Full plan:
`~/.claude/plans/i-want-do-a-witty-tiger.md`.)

## Build / verify commands
- Guest (the only WASM component): `cd cosigner && cargo +stable build --target wasm32-wasip2 --release`
  → produces `cosigner/target/wasm32-wasip2/release/cosigner.wasm` (~3 min clean).
- Host: `cd cosigner-runtime && cargo +stable build` (and `--bin cosigner-runtime`).
- Guest test suites (need the guest .wasm built first): `cargo +stable test --test guest_async_test
  --test guest_delegate_test --test guest_sendvtxo_test --test guest_vtxo_test
  --test registry_guest_test --test sign_flow_test --test seed_policy_test`
- Pre-existing failures NOT caused by this work: `onboarding_test` has 2 eviction-timing fails;
  `contract_engine_test` 3 fails are a MISSING fixture (`contracts/examples/spending-limit/target/
  wasm32-wasip2/release/spending_limit.wasm` not built in this env), not a regression.

## DONE + verified green
- All signing in the guest: FROST script-path + BIP-341 key-path tweak + contract spends
  (guest calls the async `contract-gate` enforce before producing its share).
- `cosigner-guest` folded into `cosigner` (one crate, one `cosigner.wasm`); legacy in-WASM
  component deleted; pure-public-crypto ops (pubkey tweak, schnorr verify) moved host-side to the
  `threshold` crate.
- `CosignerInstance` merged into `CosignerState` (one actor Arc; dispatch sig is
  `(state, shared, req)` — no `_user` params).
- **Plan A mechanism**: `SeedPolicy` actor command (onboarding seeds keys into the guest + seals);
  onboarding wired (`OnboardingManager::with_registry`, best-effort seed after step3); cold-spawn
  **restore-first** (skip plaintext `InstallPolicy` when the sealed snapshot restores).
- **Contract refresh-not-reshare — COSIGNER SIDE**: proto 4 `ContractCreateStep*` → 1
  `ContractCreate`; `ContractPolicy` drops `V′` material + adds `wallet_vk` allowlist; single
  stateless `contract_create` refreshes the normal `V` onto `{service,cosigner}`; eVTXO coop leaf
  scripted with `V`; rest route `POST /u/{group_key}/contract/create`. Builds zero-warning.
- **Module cleanup**: deleted `contract/session.rs` (now-inert); `ContractManager` is stateless
  (no sessions/eviction); the shared `ceremony` module moved into `onboarding/ceremony.rs`
  (onboarding is its only user now). Binary builds zero-warning; onboarding/sign/seed suites green.

## REMAINING TODO (ordered)

1. **Contract CLIENT side (Dart) — needs your build env; Dart can't be built/tested here.**
   `app-core/lib/client.dart` `createEvtxoKey`: DROP the reshare rounds (`dkgResharePart1`,
   `dkgPart2`, `dkgResharePart3` + the 3 `ContractCreateStep` POSTs). Instead: compute refresh
   slices from the **normal `V`** key package via `refreshShareToId` (yields `a@service`,
   `a@cosigner`, `a@service·G`), make ONE `POST /u/{group_key}/contract/create` with
   `{identifier, contract_id, contract_wasm, server_pk, exit_delay, owner_pk, service_vk,
   a_at_cosigner, a_at_service_point, signature, timestamp_ms}`, then send `a@service` to the
   service (`AssembleContractShare`, role=user). `ffi` is unchanged (refresh FFI already exists).

2. **E2E verify** contract create + spend on regtest (wallet-driven and service-driven), with the
   external service. This is the runtime check the in-repo tests can't do here.

3. **Service-driven contract spend through the guest (deferred):** the guest holds only the
   `{wallet,cosigner}` `V` pairing, so it can't yet co-sign a *service*-driven contract spend. The
   MVP keeps the service `V` counter-share host-side in `ContractPolicy.shares`. To make the
   service path enclave-pure, install that counter-share into the guest (a `SeedPolicy`-like path).

4. **Plan A final — remove the plaintext key store** (now unblocked once onboarding + contracts
   both seed into the guest): stop persisting the secret `key_package_json` in the `policies` tree
   (keep only a non-secret public projection for routing/address); remove the SecretStore
   `dkg-secret.*` host reads; then grep/CI-audit that NO steady-state host module reads a plaintext
   key (no `KeyPackage`/`dkg_secret` imports outside onboarding DKG).

5. **Cleanup (mostly done):** `ContractSession`/`session.rs` + the contract eviction loop are
   removed and `ceremony` is now `onboarding/ceremony.rs`. Only cosmetic remains:
   `ContractContext`/`AssembleContractShare` proto comments still say `V′`.

## Env-gated / can't verify here
- Guest **contract-DENY** test (gate actually refuses a bad contract spend) — needs the
  `spending_limit.wasm` fixture built.
- **MuSig2** tree-signing runtime verification — needs a live regtest `arkd`.
- **Re-vendor** + restore `cosigner-runtime/.cargo/config.toml` (currently `*.vendor-bak` so builds
  hit the network).
- 2 pre-existing `onboarding_test` eviction-timing failures — investigate (not a regression).

## Separate track (deployment, makes the security property REAL)
Phase 6: run the guest as a separate attested process + `Seal`/`Unseal` via the supervisor
`/v1/secrets` AEAD (an `EnclaveStore` already exists). In-process wasmtime can't hide guest memory
from the host that owns the `Store` — so today it's enclave-*ready*, not enclave-*enforced*.
