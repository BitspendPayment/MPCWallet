# Merlin Wallet

A **Recoverable Social Threshold Bitcoin wallet** powered by **FROST threshold signatures**. The full private key never exists on any single device. Two independent identities — your phone and a remote cosigning service — jointly control your funds through a 2-of-2 threshold scheme.



Each layer is doing exactly one job. WASM alone gives memory isolation but not concurrency control. The actor model alone gives concurrency control but not fault isolation. The enclave alone gives the runtime a verifiable identity but doesn't isolate users from each other. The combination is the point.

## Architecture

```
                        +-----------------------+
                        |   Cosigner Runtime    |
                        |   AWS Nitro Enclave   |
                        |   (Rust + Wasmtime)   |
                        |   Identity 2/2        |
                        +-----------+-----------+
                                    |
                              gRPC / attested HTTPS
                                    |
                        +-----------+-----------+
                        |   Android Phone       |
                        |   Flutter App         |
                        |   Identity 1/2        |
                        |   Signs in-app (FFI)  |
                        +-----------------------+
```

| Identity | Held by | Role |
|---|---|---|
| **Signing** | Phone (local, passkey-gated share) | Transaction signing |
| **Server** | Cosigner runtime in enclave | Co-signs transactions, never sees the full key |

Both parties are required to produce a valid Taproot (BIP-340) Schnorr signature. The server alone cannot move funds. The phone alone cannot move funds. You need cooperation between the two.

## The Cosigner Runtime

The remote cosigning service is built on three concentric isolation boundaries, each addressing a different class of threat:

```
┌─ AWS Nitro Enclave ──────────────────────────────────────┐  hardware-attested VM
│  PCR0 measurement · KMS keys locked to PCR0              │  client trusts: "the right binary booted"
│                                                          │
│  ┌─ cosigner-runtime (Rust)   tokio actor per user ──┐   │  concurrency isolation
│  │  per-user mailbox · serial command processing     │   │  trust: "no cross-user state mutation"
│  │                                                   │   │
│  │  ┌─ Wasmtime sandbox  one Store per user ─────┐   │   │  memory & fault isolation
│  │  │  cosigner.wasm · FROST · DKG · Schnorr     │   │   │  trust: "no leak between users"
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### Outer layer: AWS Nitro Enclave

The runtime executes inside an AWS Nitro Enclave — an isolated VM with no persistent storage, no interactive shell, no network except a vsock to the parent EC2 instance. The host's disk is invisible. The host operator can't read enclave RAM.

What the client gets in return: an **attestation document** signed by AWS, binding a `PCR0` measurement (the SHA-384 hash of the booted EIF image) to the enclave's freshly-generated TLS certificate. The client verifies `PCR0` matches a known build before trusting any response. Connecting to a different binary, or to the host itself, fails attestation — the client refuses to send DKG packets.

KMS-encrypted secrets (the FROST share's recovery material) are decrypted inside the enclave by attaching a **PCR0-locked KMS policy**: only an enclave with this exact PCR0 can call `kms:Decrypt`. A modified runtime can't load a user's secrets even if it has the same IAM role.

The enclave plumbing — supervisor, attestation server, vsock proxies — is upstream from [introspector-enclave](https://github.com/ArkLabsHQ/introspector-enclave). The cosigner-runtime is the userspace app that boots inside it.

### Middle layer: Per-user actor model

Inside the runtime, every user gets a dedicated tokio actor task:

```rust
// cosigner-runtime/src/cosigner/registry.rs
const MAILBOX_CAPACITY: usize = 256;

let (tx, rx) = mpsc::channel::<CosignerCommand>(MAILBOX_CAPACITY);
let user = self.new_user_instance()?;       // fresh Wasmtime store
let state = CosignerState::new();           // fresh in-memory state
tokio::spawn(run_actor(user, state, rx, shared, registry));
```

Properties this gives you:

- **No shared mutable state between users.** Each actor owns its `CosignerInstance` (the WASM store) and `CosignerState` (vtxos, pending DKG packets, settle session, etc.) outright. No `Arc<Mutex<...>>`, no contention, no locks inside hot paths.
- **Serial command processing per user.** The actor pulls commands one at a time from its mailbox; a DKG step finishes before the next sign-step starts. Removes a class of bugs where two parallel calls from the same user race on shared state.
- **Slow user can't starve others.** A user holding open a settle session blocks only their own mailbox. Every other user's actor keeps running on its own task.
- **Routing is constant-time.** [`CosignerRegistry`](cosigner-runtime/src/cosigner/registry.rs) is a `DashMap` from FROST verifying-share → mailbox handle. New gRPC requests just look up the handle and `send().await`. No coordinator thread.



Handlers run inside `spawn_blocking` so CPU-bound WASM work (FROST round1, DKG part3, etc.) doesn't tie up tokio worker threads. The actor itself is light — millions of idle actors fit in memory.

### Inner layer: WASM sandbox per user

Threshold cryptography (FROST, DKG, Schnorr verify, Taproot tweaking) lives entirely inside [`cosigner/`](cosigner/), a WASI Component Model crate compiled to `wasm32-wasip2`. The Rust runtime never sees raw secret shares — only opaque session handles into the WASM linear memory.

Each user actor instantiates the cosigner component into a fresh `wasmtime::Store`:

```rust
// cosigner-runtime/src/cosigner/registry.rs (new_user_instance)
let mut store = Store::new(&engine, view);
let bindings = self.linker.instantiate(&mut store, &self.component)?;
// store + bindings = one user's "CosignerInstance"
```

What this buys you:

- **Memory isolation.** A bug in `cosigner.wasm` that corrupts linear memory affects only that user's `Store`. User A's secret share cannot end up in User B's response — they live in different address spaces.
- **Fault isolation.** A panic, OOB access, or stack overflow inside WASM doesn't crash the runtime. The host catches the trap, returns an error, the actor moves on or restarts the instance.
- **Capability-based imports.** WASI gives the WASM no ambient access — no filesystem, no network, no syscalls except what the runtime explicitly imports. The cosigner crate can compute, not exfiltrate.
- **Deterministic build → PCR0.** The cosigner WASM is part of the EIF, baked into PCR0. A modified WASM means a different PCR0 means clients refuse to attest, full stop.

The runtime's job is plumbing: receive a request, validate auth, hand the request bytes to the WASM via a host call, get a response, route it back. The WASM does the math.

## Other Components

```
MPCWallet/
├── app/                  Flutter mobile app
├── app-core/             Dart client library (DKG, signing, FFI wrapper, attested transport)
├── cosigner/             WASI cosigner component (the FROST WASM)
├── cosigner-runtime/     Enclave runtime (described above)
├── crates/
│   ├── ark/              Ark protocol primitives (taproot, VTXOs, send paths)
│   ├── threshold/        FROST + DKG core (no_std, secp256k1)
│   └── enclave-client/   Attestation verification + signed-response client
├── ffi/                  Merged C-ABI shared library for Dart FFI (ark + threshold + enclave)
├── protocol/             gRPC stubs and proto definitions
├── infrastructure/       OpenTofu modules for enclave deployment (KMS, EC2, S3, SSM)
├── e2e/                  End-to-end integration tests
└── scripts/              Utilities (bitcoin.sh, arkd_init.sh, bob helpers)
```

### Flutter app ([app/](app/))

Android wallet UI built with Provider + GoRouter. Onboarding guides server connection, passkey setup, and DKG. Supports sending/receiving Bitcoin (on-chain + Ark VTXOs), spending policies, and QR codes.

### Dart client ([app-core/](app-core/))

High-level Dart API that orchestrates the full MPC protocol: drives DKG, signing, refresh, and policy operations; communicates with the cosigner runtime over **attested transport** (verifies the enclave's `PCR0` before each request); handles Taproot address derivation, UTXO tracking, and PSBT construction.

### Threshold library ([crates/threshold/](crates/threshold/))

`#![no_std]` Rust implementation of FROST over secp256k1. Includes the full 3-round DKG, Pedersen VSS, nonce commitments, signature share computation, Lagrange interpolation, Taproot key tweaking, and key refresh. Compiles for three targets: native Rust, `wasm32-wasip2` (cosigner WASM), and Dart FFI.

## Build & Run

### Prerequisites

- Dart ≥ 3.3, Flutter ≥ 3.4
- Rust (stable toolchain)
- Docker + Docker Compose

```bash
# Rust targets the runtime + cosigner need
rustup target add wasm32-wasip2                  # cosigner WASM
rustup target add aarch64-linux-android          # FFI for Android arm64
```

### Local development (regtest)

```bash
make regtest-up        # bitcoind + electrs in Docker
make bitcoin-init      # mine 150 blocks
make e2e               # runs the full E2E (build cosigner WASM + runtime + e2e harness)
```

The local cosigner runtime runs as a plain Rust binary (no enclave, no attestation) — the WASM and actor isolation still apply. Useful for fast iteration.

### Cloud deployment (signet / mutinynet / mainnet)

```bash
cd infrastructure/mutiny/tofu
tofu apply             # provisions Nitro enclave host, KMS key, S3 buckets, SSM params
```

The enclave EIF is built by the [release-eif](.github/workflows/release-eif.yml) GitHub Action and published to the repo's GitHub Releases. Tofu pulls the artifact, uploads it to S3, and the EC2 supervisor boots it. The client's `enclave verify` command confirms `PCR0` matches the published build before the wallet trusts the deployment.

### Mobile app

```bash
adb pair <ip>:<port>           # pair (wireless debugging)
adb connect <ip>:<port>
make adb-reverse               # forward server ports to phone
cd app && flutter run
```

## Testing

```bash
make threshold-test               # threshold library unit tests
make ffi-test                     # merged FFI tests
make e2e                          # full E2E (regtest + cosigner runtime + Dart e2e)
make e2e-ark                      # Ark E2E
make crypto-bench                 # cryptography benchmarks (Criterion)
make stress-test                  # multi-user E2E stress test
```

## Security model summary

- **The full private key never exists on any single device.** 2-of-2 threshold split between the phone and the cosigner.
- **The cosigner cannot unilaterally sign.** It always needs cooperation from the phone.
- **The phone's share is passkey-gated.** It is stored blinded and reconstructed transiently only for a sign, from a passkey PRF gesture.
- **The cosigner runs in a Nitro Enclave with attested boot.** Clients refuse to send DKG packets to a runtime whose `PCR0` doesn't match a known build.
- **KMS keys are locked to the enclave's `PCR0`.** A modified runtime can't decrypt user secrets even if it has the same IAM role.
- **Per-user FROST share runs in an isolated WASM sandbox** (Wasmtime) — memory and fault isolation between users.
- **Per-user actor task** — no shared mutable state, no locks, slow users can't block others.
- **All MPC requests are authenticated** with Schnorr signatures over timestamped messages (replay window enforced).

## References

- [FROST: Flexible Round-Optimized Schnorr Threshold Signatures](https://eprint.iacr.org/2020/852)
- [BIP-340: Schnorr Signatures for secp256k1](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)
- [BIP-341: Taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
- [WASI Component Model](https://component-model.bytecodealliance.org/)
- [Wasmtime](https://wasmtime.dev/)
- [AWS Nitro Enclaves](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave.html)
- [introspector-enclave](https://github.com/ArkLabsHQ/introspector-enclave) — enclave host/runtime plumbing

## License

Part of the Bitspend Payment ecosystem.
