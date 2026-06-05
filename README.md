# Merlin Wallet

A **Recoverable Social Threshold Bitcoin wallet** powered by **FROST threshold signatures**. The full private key never exists on any single device. Three independent identities — your phone, a hardware signer, and a remote cosigning service — jointly control your funds through a 2-of-3 threshold scheme.



Each layer is doing exactly one job. WASM alone gives memory isolation but not concurrency control. The actor model alone gives concurrency control but not fault isolation. The enclave alone gives the runtime a verifiable identity but doesn't isolate users from each other. The combination is the point.

## Architecture

```
                        +-----------------------+
                        |   Cosigner Runtime    |
                        |   AWS Nitro Enclave   |
                        |   (Rust + Wasmtime)   |
                        |   Identity 3/3        |
                        +-----------+-----------+
                                    |
                              gRPC / attested HTTPS
                                    |
              +---------------------+---------------------+
              |                                           |
+-------------+--------------+             +--------------+-------------+
|   Android Phone            |   USB OTG   |   HW Signer (RP2350)       |
|   Flutter App              +-------------+   TrustZone firmware       |
|   Identity 1/3             |   HID 64B   |   Identity 2/3             |
|   Day-to-day signing       |   reports   |   Recovery / policy ops    |
+----------------------------+             +----------------------------+
```

| Identity | Held by | Role |
|---|---|---|
| **Signing** | Phone (local) | Day-to-day transaction signing |
| **Recovery** | HW signer (USB HID) | Policy changes, restoration |
| **Server** | Cosigner runtime in enclave | Co-signs transactions, never sees the full key |

Any 2-of-3 produces a valid Taproot (BIP-340) Schnorr signature. The server alone cannot move funds. The phone alone cannot move funds. You need cooperation between any two parties.

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

## The Hardware Signer

The recovery identity (2/3) lives on an RP2350 microcontroller. Lives in [`hwsigner-secure/`](hwsigner-secure/) (Secure world) and [`hwsigner/`](hwsigner/) (Non-Secure world).

Two reasons it exists:

1. **The phone is single-purpose hardware running general-purpose software.** A compromised app or OS could exfiltrate the signing share. The hardware signer keeps a separate share on a physically separate device, so a compromise of the phone alone is recoverable.
2. **Policy changes need a stronger guarantee than day-to-day signing.** Spending limits, refresh, and recovery operations require a recovery signature from the hardware signer. The phone alone cannot raise its own spending limit.

### TrustZone isolation

The RP2350 (Cortex-M33) supports ARM TrustZone. The chip splits flash, RAM, and peripherals into Secure and Non-Secure regions, with hardware enforcement of which side can access which.

```
┌─ SECURE WORLD  (hwsigner-secure/) ──────────────────────┐
│  Flash 0x10000000 — 512K  ·  RAM 0x20060000 — 128K      │
│                                                          │
│  • FROST share, signing logic, DKG, nonces               │
│  • TRNG (Secure-only peripheral)                         │
│  • Key storage in Secure flash (0x103FF000)              │
│                                                          │
│  Exposes two NSC (Non-Secure Callable) entry points:     │
│    nsc_init()    — initialize crypto library             │
│    nsc_process() — handle JSON crypto request/response   │
└────────────────────────┬─────────────────────────────────┘
                         │ SG veneers (Secure Gateway)
┌────────────────────────┴─────────────────────────────────┐
│  NON-SECURE WORLD  (hwsigner/) ─────────────────────────┐│
│  Flash 0x10080000 — 3584K  ·  RAM 0x20000000 — 384K     ││
│                                                          ││
│  • Embassy async runtime + USB HID                       ││
│  • JSON protocol over 64-byte HID reports                ││
│  • Forwards crypto requests to Secure via nsc_process()  ││
│  • CANNOT access: Secure flash, Secure RAM, TRNG, keys   ││
└──────────────────────────────────────────────────────────┘│
                                                            │
SAU enforces address-region attributes; ACCESSCTRL          │
locks peripheral security after configuration.              │
```

What this gives you: even if the USB stack is compromised — a malicious peer on the bus, a buffer overflow in the HID parser — the attacker is in the Non-Secure world. They can issue crypto requests through the NSC veneers, but **cannot read the FROST share, cannot read the TRNG output, cannot pivot into Secure flash**. The Secure world copies request bytes from NS RAM, processes them in Secure RAM, zeroes the input buffer, and copies the response back. The attack surface from NS to Secure is exactly two function entry points.

### Boot, signing, and provisioning

Firmware is signed with **ECDSA secp256k1 + SHA-256**. The RP2350 boot ROM verifies each signature against a public key hash burned into OTP before executing the image — unsigned or tampered firmware does not boot. Once OTP is provisioned with `SECURE_BOOT_ENABLE`, the operation is irreversible: only firmware signed with the matching private key will ever boot on that chip.

Build, sign, and flash:

```bash
make hw-build         # builds Secure + NS worlds
make hw-sign          # signs Secure world via picotool seal
make hw-flash         # builds, signs, flashes via probe-rs
make hw-test          # smoke test over USB HID
```

The full boot sequence (12 stages from boot ROM through `BLXNS` to Embassy), SAU region table, NSC protocol, USB HID framing, and the irreversible OTP provisioning procedure are in [docs/HW_SIGNER.md](docs/HW_SIGNER.md).

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
│   ├── enclave-client/   Attestation verification + signed-response client
│   └── embassy-rp-fork/  Forked embassy-rp with TrustZone NS support
├── ffi/                  Merged C-ABI shared library for Dart FFI (ark + threshold + enclave)
├── hwsigner/             RP2350 Non-Secure firmware (Embassy, USB HID)
├── hwsigner-secure/      RP2350 Secure firmware (TrustZone, key storage, TRNG)
├── protocol/             gRPC stubs and proto definitions
├── infrastructure/       OpenTofu modules for enclave deployment (KMS, EC2, S3, SSM)
├── e2e/                  End-to-end integration tests
└── scripts/              Utilities (bitcoin.sh, test_hwsigner.py, udev rules)
```

### Flutter app ([app/](app/))

Android wallet UI built with Provider + GoRouter. Onboarding guides server connection, hardware signer pairing, network selection, and DKG. Supports sending/receiving Bitcoin (on-chain + Ark VTXOs), spending policies, and QR codes.

### Dart client ([app-core/](app-core/))

High-level Dart API that orchestrates the full MPC protocol: drives DKG, signing, refresh, and policy operations; communicates with the cosigner runtime over **attested transport** (verifies the enclave's `PCR0` before each request); drives the hardware signer over USB HID; handles Taproot address derivation, UTXO tracking, and PSBT construction.

### Threshold library ([crates/threshold/](crates/threshold/))

`#![no_std]` Rust implementation of FROST over secp256k1. Includes the full 3-round DKG, Pedersen VSS, nonce commitments, signature share computation, Lagrange interpolation, Taproot key tweaking, and key refresh. Compiles for four targets: native Rust, `wasm32-wasip2` (cosigner WASM), `thumbv8m.main-none-eabihf` (HW signer Secure world), and Dart FFI.

## Build & Run

### Prerequisites

- Dart ≥ 3.3, Flutter ≥ 3.4
- Rust (stable + nightly toolchains)
- Docker + Docker Compose
- ARM GNU toolchain (`arm-none-eabi-ld`) — only if building HW signer firmware
- picotool, probe-rs — only if flashing HW signer
- Android device with USB OTG (for HW signer testing)

```bash
# Rust targets the runtime + cosigner need
rustup target add wasm32-wasip2                  # cosigner WASM
rustup target add aarch64-linux-android          # FFI for Android arm64
rustup target add thumbv8m.main-none-eabihf      # HW signer (only if needed)
rustup toolchain install nightly                  # TrustZone CMSE features (HW signer only)

cargo install probe-rs-tools    # only for HW signer flashing
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

### HW signer

If you want the recovery identity on real hardware:

```bash
make hw-build && make hw-flash    # builds Secure + NS, signs Secure, flashes via debug probe
make hw-test                       # smoke test over USB HID
```

For OTP provisioning (Secure Boot enforcement, key invalidation, glitch detection): see [HW_SIGNER.md](docs/HW_SIGNER.md). All OTP writes are permanent.

### Mobile app

```bash
adb pair <ip>:<port>           # pair (wireless debugging)
adb connect <ip>:<port>
make adb-reverse               # forward server ports to phone
cd app && flutter run          # pick "Hardware Signer (USB)" or "Software Signer" in onboarding
```

## Testing

```bash
make threshold-test               # threshold library unit tests
make ffi-test                     # merged FFI tests
make e2e                          # full E2E (regtest + cosigner runtime + Dart e2e)
make e2e-ark                      # Ark E2E
make hw-test ARGS="--full-dkg"    # HW signer firmware over USB HID
make crypto-bench                 # cryptography benchmarks (Criterion)
make stress-test                  # multi-user E2E stress test
```

## Security model summary

- **The full private key never exists on any single device.** 2-of-3 threshold; loss of any one share is recoverable.
- **The cosigner cannot unilaterally sign.** It always needs cooperation from the phone or hardware signer.
- **The cosigner runs in a Nitro Enclave with attested boot.** Clients refuse to send DKG packets to a runtime whose `PCR0` doesn't match a known build.
- **KMS keys are locked to the enclave's `PCR0`.** A modified runtime can't decrypt user secrets even if it has the same IAM role.
- **Per-user FROST share runs in an isolated WASM sandbox** (Wasmtime) — memory and fault isolation between users.
- **Per-user actor task** — no shared mutable state, no locks, slow users can't block others.
- **The hardware signer's share is in TrustZone Secure flash** — inaccessible from the USB attack surface via SAU hardware enforcement.
- **All MPC requests are authenticated** with Schnorr signatures over timestamped messages (replay window enforced).
- **Policy changes require a recovery signature** from the hardware signer.

## References

- [FROST: Flexible Round-Optimized Schnorr Threshold Signatures](https://eprint.iacr.org/2020/852)
- [BIP-340: Schnorr Signatures for secp256k1](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)
- [BIP-341: Taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
- [WASI Component Model](https://component-model.bytecodealliance.org/)
- [Wasmtime](https://wasmtime.dev/)
- [AWS Nitro Enclaves](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave.html)
- [introspector-enclave](https://github.com/ArkLabsHQ/introspector-enclave) — enclave host/runtime plumbing
- [ARMv8-M TrustZone](https://developer.arm.com/Architectures/TrustZone)
- [RP2350 Datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf)

## License

Part of the Bitspend Payment ecosystem.
