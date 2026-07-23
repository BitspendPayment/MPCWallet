# Merlin Wallet

A **2-of-2 FROST threshold Bitcoin wallet**. The full private key never exists on any single device: two independent identities — your phone and a remote cosigning service running inside an AWS Nitro Enclave — jointly control your funds. Neither can move funds alone.

The wallet spends across two value layers:

- **Ark (off-chain VTXOs).** The primary path. The FROST group key (phone + cosigner, 2-of-2) owns the VTXOs; boarding, sending, and settling go through an **Ark Service Provider (arkd)**.
- **On-chain Bitcoin.** A single key the wallet controls **alone** (the DKG dealer secret), for direct on-chain send/receive. It needs neither the cosigner nor the ASP, so it keeps working when they're unavailable — the app calls this **offline mode**.

Both parties are required to produce a valid Taproot (BIP-340) Schnorr signature on the Ark path. The server alone cannot move funds; the phone alone cannot move Ark funds.

## Architecture

```
   +-----------------------+         +-----------------------+
   |   Cosigner Runtime    |         |   Ark Service         |
   |   AWS Nitro Enclave   |         |   Provider (arkd)     |
   |   Rust · native FROST |         |   VTXO batching /     |
   |   Identity 2/2        |         |   settlement          |
   +-----------+-----------+         +-----------+-----------+
               |                                 |
        attested HTTPS                     Ark rounds
               |                                 |
   +-----------+---------------------------------+-----------+
   |   Android Phone — Flutter app — Identity 1/2            |
   |   in-app FROST signing (FFI) · passkey-gated share      |
   |   on-chain single-key path (wallet-alone / offline)     |
   +--------------------------------------------------------+
```

| Identity | Held by | Role |
|---|---|---|
| **Wallet share** | Phone (local, passkey-gated FROST share) | One half of the 2-of-2; signs in-app |
| **Cosigner share** | Cosigner runtime in the enclave | The other half; co-signs, never sees the full key |

## The Cosigner Runtime

The remote cosigning service is built on two isolation boundaries, each addressing a different class of threat.

```
┌─ AWS Nitro Enclave ──────────────────────────────────────────┐  hardware-attested VM
│  PCR0 measurement · KMS secrets PCR0-locked                  │  client trusts: "the right binary booted"
│                                                              │
│  ┌─ cosigner-runtime (Rust)   native actor per user ─────┐   │  concurrency + fault isolation
│  │  per-user mailbox · serial commands · keys in-process  │   │  trust: "no cross-user state / races"
│  │  FROST · DKG · Schnorr run natively here               │   │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### Outer layer: AWS Nitro Enclave

The runtime executes inside an AWS Nitro Enclave — an isolated VM with no persistent storage, no interactive shell, and no network except a vsock to the parent EC2 instance. The host's disk is invisible; the host operator can't read enclave RAM.

What the client gets in return: an **attestation document** signed by AWS, binding a `PCR0` measurement (the SHA-384 hash of the booted EIF image) to the enclave's attestation key. The client verifies `PCR0` matches a known build before trusting any response, and binds the enclave's response-signing key to the attestation (`appKeyHash`). Connecting to a different binary, or to the host itself, fails attestation — the client refuses to send DKG packets.

KMS-encrypted deployment secrets are decrypted inside the enclave via a **PCR0-locked KMS policy**: only an enclave measuring this exact `PCR0` can call `kms:Decrypt`. A modified runtime can't load secrets even with the same IAM role.

The enclave plumbing — supervisor, attestation server, vsock proxies — is upstream from [introspector-enclave](https://github.com/ArkLabsHQ/introspector-enclave). The cosigner-runtime is the userspace app that boots inside it.

### Inner layer: Per-user native actor

Inside the runtime, every user (keyed by FROST verifying-share / group key) gets a dedicated tokio actor task that owns its keys and state:

```rust
// cosigner-runtime/src/cosigner/registry.rs
const MAILBOX_CAPACITY: usize = 256;

let (tx, rx) = mpsc::channel::<CosignerCommand>(MAILBOX_CAPACITY);
tokio::spawn(run_cosigner(rx, shared, registry));
```

Properties this gives you:

- **No shared mutable state between users.** Each actor owns its `CosignerState` (key package, Ark secret, VTXOs, pending sessions) outright.
- **Serial command processing per user.** The actor pulls commands one at a time; a DKG step finishes before the next sign-step starts, removing a class of same-user races.
- **Fault isolation.** Handler work runs inside `spawn_blocking`; a panic on attacker input is caught (`JoinError::is_panic`), the request errors, and the actor is reseated from its snapshot rather than crashing the runtime.
- **Slow user can't starve others.** A user holding a settle session blocks only their own mailbox.
- **Constant-time routing.** [`CosignerRegistry`](cosigner-runtime/src/cosigner/registry.rs) is a `DashMap` from group key → mailbox handle; a request just looks up the handle and `send().await`. Idle actors are cheap — an idle actor is memory, not a thread.

## Other Components

```
MPCWallet/
├── app/                  Flutter mobile app (Android)
├── app-core/             Dart client library (DKG, signing, FFI wrapper, attested transport)
├── cosigner-runtime/     Enclave runtime — native per-user actors (described above)
├── crates/
│   ├── ark/              Ark protocol: boarding, VTXO send/settle, delegate/auto-settle, checkpoints
│   ├── threshold/        FROST + DKG core (no_std, secp256k1)
│   └── enclave-client/   Nitro attestation verification (COSE/X.509/PCR0) + signed-response client
├── ffi/                  Merged C-ABI shared library for Dart FFI (ark + threshold + enclave)
├── protocol/             gRPC stubs and proto definitions
├── infrastructure/       OpenTofu modules for enclave deployment (KMS, EC2, S3, SSM)
├── e2e/                  End-to-end integration tests + local signer-server
└── scripts/              Utilities (bitcoin.sh, arkd_init.sh, …)
```

### Flutter app ([app/](app/))

Android wallet UI built with Provider + GoRouter. Onboarding guides server connection, passkey setup, and DKG. Supports on-chain + Ark (VTXO) send/receive, an **offline mode** that falls back to on-chain-only when the ASP is unavailable, and passkey-gated signing.

### Dart client ([app-core/](app-core/))

High-level Dart API that orchestrates the full protocol: drives DKG, FROST signing, key refresh, Ark boarding/send/settle, and the on-chain single-key path. Talks to the cosigner over **attested transport** (verifies the enclave's `PCR0` and response signatures), and handles Taproot address derivation, UTXO/VTXO tracking, and PSBT construction.

### Threshold library ([crates/threshold/](crates/threshold/))

`#![no_std]` Rust implementation of FROST over secp256k1: the full 3-round DKG with proof-of-knowledge, Pedersen VSS, single-use nonce commitments, signature-share computation, Lagrange interpolation, Taproot key tweaking, and key refresh. Built for two targets: **native Rust** (the cosigner runtime) and **Dart FFI** (the phone, via `ffi/`).

## Build & Run

### Prerequisites

- Dart ≥ 3.3, Flutter ≥ 3.4
- Rust (stable toolchain)
- Docker + Docker Compose

```bash
rustup target add aarch64-linux-android          # FFI for Android arm64
```

### Local development (regtest)

```bash
make regtest-up        # bitcoind + electrs in Docker
make bitcoin-init      # mine blocks
make e2e               # full E2E: builds ffi + cosigner-runtime + signer-server, runs the Dart harness
make e2e-ark           # Ark E2E (regtest + arkd)
```

The local cosigner runtime runs as a plain Rust binary (no enclave, no attestation) — the per-user native-actor isolation still applies. Useful for fast iteration.

### Cloud deployment (signet / mutinynet / mainnet)

```bash
cd infrastructure/mutiny/tofu
tofu apply             # provisions Nitro enclave host, KMS key, S3 buckets, SSM params
```

The enclave EIF is built by the [release-eif](.github/workflows/release-eif.yml) GitHub Action and published to GitHub Releases. Tofu pulls the artifact, uploads it to S3, and the EC2 supervisor boots it. The [verify](.github/workflows/verify.yml) workflow confirms the published build's `PCR0` before the wallet trusts a deployment.

### Mobile app

```bash
adb pair <ip>:<port>           # pair (wireless debugging)
adb connect <ip>:<port>
make adb-reverse               # forward server ports to the phone
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

- **The full private key never exists on any single device.** The Ark owner key is a 2-of-2 FROST split between the phone and the cosigner.
- **The cosigner cannot unilaterally sign.** It always needs cooperation from the phone.
- **The phone's FROST share is passkey-gated.** It is stored blinded and reconstructed transiently, only for a sign, from a passkey PRF gesture.
- **The cosigner runs in a Nitro Enclave with attested boot.** Clients refuse to send DKG packets to a runtime whose `PCR0` doesn't match a known build, and bind its response-signing key to the attestation.
- **KMS secrets are PCR0-locked.** A modified runtime can't decrypt them even with the same IAM role.
- **FROST keys are held by an isolated per-user native actor** — no shared mutable state, serial per-user processing, panic-recovered from a sealed snapshot.
- **MPC requests are authenticated** with Schnorr signatures (or a passkey-minted session token) over timestamped messages, within a replay window.
- **The on-chain single-key path is wallet-alone.** It works without the cosigner or ASP (offline mode); it is not part of the 2-of-2.

## References

- [FROST: Flexible Round-Optimized Schnorr Threshold Signatures](https://eprint.iacr.org/2020/852)
- [BIP-340: Schnorr Signatures for secp256k1](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)
- [BIP-341: Taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
- [Ark protocol](https://arkdev.info/) — off-chain VTXOs via an Ark Service Provider
- [AWS Nitro Enclaves](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave.html)
- [introspector-enclave](https://github.com/ArkLabsHQ/introspector-enclave) — enclave host/runtime plumbing

## License

Part of the Bitspend Payment ecosystem.
