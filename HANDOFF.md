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

1. **Contract CLIENT side (Dart) — DONE 2026-06-25 (analyze-clean; not runtime-verified).**
   `make proto` regenerated (single `ContractCreate`/`AssembleContractShare`; the stale
   `ContractCreateStep1..4` + `EvtxoKeygen*`/`EvtxoOnboard*` messages are gone; `$_clearField`
   count 0 → correct protoc_plugin). `app-core/lib/client.dart` `createEvtxoKey` rewritten to the
   single-shot flow: compute refresh slices from the **normal `V`** kp via `refreshShareToId`
   (`a@service`, `a@cosigner`, `a@service·G`), ONE `POST /u/{group_key}/contract/create`, then
   deliver `a@service` to the service via `assembleContractShare(role="user")` (gated behind an
   optional `serviceApi` param — the external service doesn't exist yet, so it's skipped when
   null). New required arg `serviceVk` + optional `ownerPk` (defaults to wallet `V` x-only). It
   now returns the wallet's `V` kp/PKP (coop leaf reuses `V`), so spends use the normal key.
   - Removed the dead V′ multi-user path: `onboardParticipant`/`fetchContractShares`/
     `ackContractShare` (client) + their auth helpers/op-constants + the 6 dead RPC methods across
     `wallet_api.dart` / `grpc_` / `rest_` / `attested_`. REST impls added for the 2 new RPCs.
   - Drive-by: `make proto` also surfaced the already-removed `is_restore` (proto `reserved 4`);
     dropped the stale `..isRestore` setters in `client.dart`/`rest_wallet_api.dart`.
   - E2E tests reconciled to compile + **skipped** with a reason (need the external service):
     `evtxo_contract_e2e_test`, `evtxo_arkd_e2e_test` (multi-user Phase 5 deleted; V′≠V flipped to
     ==V); `dkg_2of2_test` Part C (contract reshare) removed, DKG+sign kept green.
   - `dart analyze` clean: `app-core/lib`, `protocol/lib` (after `pub get`), `e2e/test`.

2. **E2E verify** contract create + spend on regtest. **Dummy service built 2026-06-25** — the
   always-online contract-signer is now a real (Tier-1) component:
   - New crate `e2e/contract-service` (axum): `GET /info` publishes `service_vk` (fixed test
     keypair); `POST /assemble-contract-share` receives both refresh halves keyed by the
     scriptPubKey, sums `s_service = a@service + b@service`, and verifies `s_service·G` against the
     contract PKP's `service_id` share. Tier-1 = assemble+verify+ack (enough for `ContractCreate`
     to succeed + wallet-driven spend); Tier-2 (service FROST co-sign) is still TODO #3.
   - **Wire format unified to hex**: `manager.rs::deliver_to_service` now sends hex JSON (was
     prost-serde int-arrays); the wallet's `assembleContractShare` + the service all speak the same
     hex schema `{contract_group_id, half_scalar, role, context?}`.
   - **e2e wired + un-skipped**: `evtxo_contract_e2e_test` + `evtxo_arkd_e2e_test` spawn the service,
     pass `SERVICE_URL` to the cosigner, fetch `service_vk` from `/info`, and hand `createEvtxoKey`
     a `serviceApi` (RestWalletApi at the service) so the wallet delivers `a@service` directly.
   - Makefile: `service-build`/`service-run`/`service-stop`; `service-build` added to
     `e2e-evtxo`/`e2e-evtxo-arkd` deps.
   - **`make e2e-evtxo` GREEN end-to-end on regtest 2026-06-25** ("All tests passed!"): full path
     verified — DKG → `ContractCreate` (refresh V onto {service,cosigner}) → both halves reached the
     service, summed, **PKP cross-check passed** → eVTXO registered → cosigner guest gated the spends
     (deny over-limit, deny bad-arg `oracle token mismatch`, allow + broadcast confirmed).
   - **Two real blockers found + fixed along the way:**
     a. **Missing FFI export** — the handoff's "refresh FFI already exists" was WRONG. `app-core`'s
        `refreshShareToId` binding looks up `threshold_refresh_share_to_id`, which the FFI crate
        never exported (only `dkg_refresh_part1/2/3`). Added it in `ffi/src/threshold/ffi_dkg.rs`
        (wraps `refresh_to_ids` math with the caller-supplied slope; min_signers=2). Rebuild ffi.
     b. **wasm32-wasip2 C toolchain** — `cosigner.wasm` was stale (Jun 13, pre-`90f60cdb`, exported
        no `handle`) and rebuilding failed: system clang targeting wasm32-wasip2 has no sysroot, so
        its `stdint.h` falls through to `/usr/include` and dies on `bits/libc-header-start.h` while
        compiling secp256k1-sys. Fix: fetch the **wasi-sdk-24 sysroot** (LLVM-18, matches system
        clang-18) and build with `CC_wasm32_wasip2=clang CFLAGS_wasm32_wasip2=--sysroot=<sysroot>`.
        Wired into the Makefile: new `wasi-sysroot` target (guarded curl to
        `$(HOME)/.local/wasi/wasi-sysroot-24.0`) is now a dep of `cosigner-build`.

3. **Service-driven contract co-sign (Tier 2) — DONE + e2e-verified 2026-06-25**
   (`make e2e-evtxo-cosign` GREEN: "All tests passed!"). The always-online service co-signs an
   eVTXO spend under `V` with the **wallet offline**, and is **conditioned on spending its own
   eVTXO** (can't forge a `V` spend of the wallet's normal funds). Design:
   - `ContractCreate` now also seeds a **`{service, cosigner}` pairing ACTOR** — a separate guest
     actor keyed by the eVTXO **spk**, holding the cosigner's pairing counter-share + the `V` PKP
     (`PolicyState.contract_pairing` marks it). Reuses the EXISTING `SignStep1/SignStep2` path, so
     no FROST is duplicated and the share lives in the guest (enclave-pure, not host-side).
   - **Conditioning (the security crux):** for a pairing actor, `route_sign_step1` rebuilds the
     cooperative-leaf sighash from the cosigner's own params (`ark::evtxo_cooperative_spend_info`)
     and OVERRIDES `message_to_sign` with it — the cosigner is authoritative about WHAT it signs,
     and rejects any spend that doesn't touch the associated spk. The contract gate still runs.
   - `contract-service` now has `/service-sign`: it stashes `s_service` at assemble and drives the
     cosigner's `SignStep1/SignStep2` as the "user" (auth as `service_vk` via `AuthSigner`), then
     returns the aggregated `V` signature.
   - Test [evtxo_service_cosign_e2e_test.dart](e2e/test/evtxo_service_cosign_e2e_test.dart): allow +
     verify under `V` (no wallet), deny non-associated spend, deny over-limit (gate). Needs only
     runtime + service + ffi (no arkd/bitcoind). `make e2e-evtxo-cosign`.
   - **ON-CHAIN spend — DONE + e2e-verified 2026-06-25** (`make e2e-evtxo-service-spend` GREEN): a
     real eVTXO is SPENT ON-CHAIN on regtest with the wallet offline — `{service, cosigner}` produce
     the `V` leg, a self-generated ASP key the server leg (no arkd), `ArkEvtxoSpendSession.finalize`
     assembles the cooperative witness, broadcast + confirmed.
     [evtxo_service_spend_e2e_test.dart](e2e/test/evtxo_service_spend_e2e_test.dart).
   - **THROUGH ARKD — DONE + e2e-verified 2026-06-25** (`make e2e-evtxo-service-arkd` GREEN): the
     service + cosigner spend a contract eVTXO OFF-CHAIN via arkd, wallet offline; arkd validates +
     co-signs the server leg, Bob (recipient) credited. The arkd spend has TWO V-legs (the
     `checkpoint_tx` that spends the eVTXO, and the `ark_tx` that spends the checkpoint output), so
     the conditioning grew to a two-leg VERIFY: leg 1 = `pairing_coop_sighash` (checkpoint→eVTXO);
     leg 2 = `arktx_leg_sighash` (ark_tx input must spend an OUTPUT of leg-1's verified checkpoint);
     `message_to_sign` must equal one of them. New proto field `SignStep1Request.ark_tx` carries
     leg 2 (host-only; the guest never sees it). The test routes each of `createEvtxoSpend`'s
     sighashes to `/service-sign` (verify mode: pass `message` + `ark_tx`), then
     `insertSignatures` + `submit`. [evtxo_service_arkd_e2e_test.dart](e2e/test/evtxo_service_arkd_e2e_test.dart).

4. **Plan A — remove the plaintext key store. IN PROGRESS 2026-06-25.** Goal: NO steady-state host
   module reads a plaintext key. The audit found **TWO secrets + THREE steady-state host readers**:
   - `key_package_json` (the cosigner's FROST share): read by guest-install (first run) + **the
     ContractCreate refresh** (`contract/handler.rs` `KeyPackage::from_json(...normal_policy...)`).
   - `dkg-secret.*` (the server's MuSig2 delegate key): read by **Ark settle/send** (`ark_send.rs`
     via `get_user_ark_keys`) + delegate rehydration (`registry.rs`).
   Good news for Phase 2: the guest ALREADY holds `dkg_secret` (via `InstallPolicy`) and already has
   `SendVtxoStep1/2`, `GenerateDelegate/ApplyDelegateSigs/SettleDelegate` + seals them — so Phase 2 is
   "route the remaining LEGACY host ark paths to the guest commands that already exist + delete the
   host secret reads," not "build Ark in the guest."

   **PHASE 1A (the host stops READING the FROST share) — DONE + e2e-verified 2026-06-25**
   (`make e2e-evtxo-cosign` + `e2e-evtxo` both GREEN):
   - `GuestCommand::ContractRefresh` — the guest refreshes its own `V` onto the
     `{receiver, cosigner}` pairing internally (`cosigner/src/state.rs::contract_refresh`).
   - `CosignerCommand::ContractRefresh` + `registry.rs::route_contract_refresh`;
     `ContractManager::new` now takes the registry and `create_contract` dispatches it (computing the
     ids from the req — never loading `V`). `handler::contract_create` takes the refresh OUTPUT and is
     SECRET-FREE: deleted the `V` `KeyPackage::from_json`, the host `refresh_to_receiver`, and the
     secret `CosignerShare`. `ContractPolicy` is now a PUBLIC allowlist (`authorized_service_vks`).
     The pairing key reaches the pairing actor as an OPAQUE `my_key_package_json` string (the GUEST
     parses it on install, never the host). Deleted dead `resolve_signing_key`/`share_for`.
   - **AUDIT PASS:** `grep KeyPackage::from_json cosigner-runtime/src` → 0 hits (only
     `PublicKeyPackage::from_json` remains). The host never parses/uses a plaintext FROST share.

   **PHASE 1B (stop PERSISTING the FROST share) — DONE + e2e-verified 2026-06-25.** The plaintext
   FROST `key_package_json` is no longer at rest in `policies`; the cosigner's share lives ONLY in
   the guest's sealed snapshot. (Durability is unchanged — the seal already lives in the same sled.)
   - **Inc1:** pairing actor EAGER-SEALED at create (`manager::create_contract` dispatches `SeedPolicy`
     to the spk actor); `route_seed_policy` carries forward the persisted `contract_pairing` marker.
   - **Wallet:** onboarding now SEEDS the guest from the in-memory DKG key (`OnboardingSession::seed_material`
     → `manager::seed_guest_mandatory`) and is **MANDATORY** (seal fails ⇒ onboarding fails — no
     plaintext fallback). `policies` gets only the PUBLIC projection (`key_package_json = ""`).
   - **Pairing:** `handler::contract_create` persists `key_package_json = ""` (the real key is the
     eager-sealed `my_kp`).
   - **GATE PASSED — `restore_from_seal_e2e_test`:** spawn runtime → DKG → **kill + respawn on the
     same data dir** → sign. The cold actor restores its `V` share PURELY from the seal; with the
     persisted key blank, a broken restore can't be masked (the sign would fail). Plus
     `e2e-evtxo-cosign` + `e2e-evtxo` still GREEN. (Cold-spawn with a missing seal already fails
     cleanly — the guest's `KeyPackage::from_json("")` errors — so no plaintext key is ever installed.)
   - **Optional polish (not done):** a clearer host-side guard ("no sealed snapshot; actor not seeded")
     instead of relying on the guest's blank-install error.

   **PHASE 1C (guest as SINGLE source of truth) — DONE + e2e-verified 2026-06-26.** The conditioning
   now lives ENTIRELY in the guest (`cosigner/src/conditioning.rs`): `pairing_coop_sighash` (leg 1) +
   `arktx_leg_sighash` (leg 2), ported with `String` errors. The guest pulls `bitcoin = "0.32"` as a
   direct dep (already transitive via `ark`) and rebuilds the cooperative-leaf script-path sighash from
   its OWN sealed params. Flow: `ContractPairing` rides `CosignerCommand::SeedPolicy` → `GuestCommand::
   InstallPolicy.contract_pairing` (proto `ContractPairingWire`) → guest `Policy.contract_pairing` →
   `SnapshotState.contract_pairing` (sealed) + restore. `ark_tx` was added to `SignStep1Wire`; `route_
   sign_step1` forwards `req.ark_tx`. The guest's `sign_step1`: pairing actor + no `ark_tx` ⇒ OVERRIDE
   the message with leg 1; pairing + `ark_tx` ⇒ require the message to equal leg 1 OR leg 2; normal
   actor ⇒ sign the requested message. The host-side `pairing_coop_sighash`/`arktx_leg_sighash` +
   the `route_sign_step1` override block are DELETED.
   - **Pairing persist DROPPED:** `handler::contract_create` persists NOTHING for the pairing actor
     (no `policies` write). `route_sign_step1` is now restore-ONLY: it uses `state.cosigner_id` as the
     group key and OPTIONAL host material (only the normal wallet has a projection — the `InstallPolicy`
     fallback for the pre-seal edge). A pairing actor has no material and MUST restore from its seal
     (eager-sealed at create); no seal + no material ⇒ `failed_precondition` (Plan A 1B: restore-only,
     no plaintext fallback).
   - **VERIFIED:** `evtxo_service_cosign` (single-leg ALLOW + DENY-non-associated now from the GUEST +
     gate DENY-over-limit), `evtxo_service_arkd` (two-leg: "service co-signed 2 V-leg(s)", Bob credited,
     wallet offline), plus host Rust tests (`sign_flow`/`seed_policy`/`registry_guest`) — all GREEN.

   **PHASE 2 (MuSig2 delegate / `dkg-secret`) — IN PROGRESS.**
   - **Boarding settle FULLY GUEST-DRIVEN — DONE + e2e-verified 2026-06-26** (`evtxo_arkd` GREEN with the
     ORIGINAL `ARKD_SESSION_DURATION=10`: "3. Settled. Alice balance=1000000" → eVTXO mint + arkd co-sign).
     The GUEST now owns the ASP event stream + MuSig2 tree-signing + BOTH FROST rounds; the host only scans
     the boarding UTXO (public chain) and relays the two client FROST rounds. This supersedes the earlier
     host-drives-the-stream design — the full in-guest drive WAS achievable.
     - **Root-cause win (the thing that was "blocked"):** the blocker was NOT the wstd reactor. The guest
       drives the stream + unary calls fine (the `drive()` poll-pump from the delegate work handles unary
       while a stream is active). The real bug: holding an OPEN `wasi:io` stream resource in `GuestState`
       across the `block_on` teardown at the commitment-FROST pause STALLS the guest call from completing,
       so the host never delivered Step2's response and the client hung. Fix: **drop the stream at the
       pause** and have Step3 finalize OPTIMISTICALLY (`SettleSession::finalize_optimistic` — commitment
       txid = commitment-PSBT txid, VTXO = first tree leaf; no stream read needed past the pause).
     - `crates/ark` `batch.rs`: `SettleSession` got guest-driveable step methods made `pub`
       (`insert_intent_signatures`, `register_payload`, `on_batch_started`, `on_tree_signing_started`,
       `on_tree_nonces`, `handle_tree_tx`, `handle_batch_finalization`, `insert_commitment_signatures`,
       `batch_id`, `finalize_optimistic`). `BoardingTreeSigner` (standalone, `signing`-usable) unchanged.
     - proto: `GuestCommand::{BoardingSettleStep1, BoardingSettleStep2, BoardingSettleStep3}` + responses
       `{BoardingSettleSighashes, BoardingSettleSubmitted}`. (The host-drive `GetArkCosignerPubkey/
       BoardingGenNonces/BoardingTreeSign` commands still exist but are now unused by the live path.)
     - guest (`cosigner/src/lib.rs`): `boarding_settle_step1` (sync: build session, return intent sighashes),
       `boarding_settle_step2` (async: insert intent sigs → RegisterIntent → open stream → `drive_boarding`
       to BatchFinalization → return commitment sighashes, DROP stream), `boarding_settle_step3` (async:
       insert commitment sigs → SubmitSignedForfeitTxs → `finalize_optimistic`). `BoardingSettleInFlight`
       in `state.rs` holds the session + signer + boarding amount across the pause.
     - host (`registry.rs`): `route_settle_boarding` is now a THIN RELAY — Phase 1 scans the boarding UTXO +
       dispatches Step1; Phase 2 dispatches Step2; Phase 3 dispatches Step3 + records the VTXO. Progress is
       a 3-state marker `CosignerState.guest_boarding = (step, amount_sats, exit_delay)`. The host no longer
       touches the ASP for the settle drive (only for `GetInfo`).
   - **dkg-secret host persistence REMOVED — DONE + e2e-verified 2026-06-26** (`evtxo_arkd` GREEN
     after each step). The host no longer writes or reads a plaintext `dkg-secret`:
     - Deleted the DEAD legacy `settle_delegate`/`send_vtxo`/`redeem_vtxo` (guest-routed; `ark_send:788`
       never ran) + `get_user_ark_keys`. The no-ASP dispatch arms now error.
     - `persist_policy` (`store.rs`) no longer writes `dkg-secret.<key>` to the SecretStore; `try_load_policy`
       (`helpers.rs`) no longer reads it — `server_dkg_secret_hex` stays `None` host-side. The guest holds
       the SOLE copy in its sealed snapshot (seeded via `SeedPolicy` at onboarding, restored on spawn).
     - The only remaining `get_secret("dkg-secret.*")` is the delegate REHYDRATION (`registry:169`); it now
       returns `None` (nothing written) and drops the row — no plaintext read. (Left in place; the whole
       legacy host-delegate subsystem is dead — see the gap below — and removing it is a separate cleanup.)
   - **AUTO-SETTLE-AFTER-RESTART — FIXED + e2e-verified 2026-06-26** (`ark_e2e` "survives cosigner-runtime
     restart" GREEN; "auto-settle drives stored delegate intent" GREEN; `evtxo_arkd` GREEN). Two parts:
     - **Guest-path restart durability:** `route_settle_delegate` store_only writes a SECRET-FREE marker to a
       new `guest_delegate_thresholds` sled tree (`helpers::save/load/delete_guest_delegate_threshold`); the
       spawn rehydration in `registry.rs` restores `guest_delegate_threshold` from it (replacing the dead
       dkg-secret rehydration); the `main.rs` auto-settle tick scans that tree to re-spawn+tick actors;
       `has_active_delegate` = `guest_delegate_threshold.is_some() || state.delegate_session.is_some()`.
     - **The guest-internal delegate settle was HANGING** on its unary gRPC calls (`ConfirmRegistration` /
       `SubmitTree*`) while the event stream was active — a wstd/wasi-http reactor bug: the host h2 hook's
       response future resolves host-side but doesn't wake the guest reactor. Fixed with a `drive(fut)`
       poll-pump (poll + `wstd::task::sleep` yield-to-host + re-poll) wrapping the UNARY calls in
       `cosigner/src/grpc.rs` (NOT the stream's `body.frame()` — DATA frames wake fine). Now the guest drives
       the WHOLE delegate settle itself (stream + all unary). See memory `guest_grpc_reactor_pump`.
     - (The flushed-`eprintln` "fix" during debugging was a red herring — stderr wasi calls accidentally
       pumped the reactor. The `drive()` helper is the real fix.)

5. **Cleanup (done):** `ContractSession`/`session.rs` + the contract eviction loop are removed and
   `ceremony` is now `onboarding/ceremony.rs`. The stale `AssembleContractShare` `contract_group_id`
   `// V′` proto comment is fixed (now "correlation key = scriptPubKey") in both proto copies.

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
