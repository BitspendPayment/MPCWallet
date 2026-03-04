# Merlin Wallet

A **self-custodial Bitcoin wallet** powered by **FROST threshold signatures** and a **Raspberry Pi Pico 2 hardware signer**. No single device ever holds the full private key.

Three independent identities — your phone, a hardware signer, and a coordination server — jointly control your funds through a 2-of-3 threshold scheme. Transactions require cooperation between any two parties, eliminating single points of failure while keeping the user in control.

## Architecture

```
                        +-----------------------+
                        |   Coordination Server |
                        |   (Rust, gRPC)        |
                        |   Identity 3/3        |
                        +-----------+-----------+
                                    |
                              gRPC (50051)
                                    |
              +---------------------+---------------------+
              |                                           |
+-------------+--------------+             +--------------+-------------+
|   Android Phone            |   USB OTG   |   Pico 2 Hardware Signer  |
|   Flutter App              +-------------+   Embassy firmware         |
|   Identity 1/3             |   HID 64B   |   Identity 2/3            |
|   Signing + wallet logic   |   reports   |   Recovery key in flash   |
+----------------------------+             +----------------------------+
```

| Identity | Held by | Purpose |
|----------|---------|---------|
| **Signing** | Phone (local) | Day-to-day transaction signing |
| **Recovery** | Pico 2 (USB HID) | Policy changes, recovery operations |
| **Server** | Coordination server | Co-signs transactions, never learns the full key |

Any 2-of-3 can produce a valid Taproot (BIP-340) signature. The server alone cannot move funds.

## Components

```
MPCWallet/
+-- ap/                 Flutter mobile app (Merlin Wallet)
+-- client/             Dart client library (DKG, signing, UTXO management, FFI wrapper)
+-- threshold/          FROST & DKG cryptography (Rust, no_std, secp256k1)
+-- threshold-ffi/      C-ABI shared library wrapping threshold for Dart FFI
+-- server/             Rust gRPC coordination server (Wasmtime + cosigner WASM)
+-- cosigner/           WASM cosigner component (server-side threshold crypto)
+-- pico-signer/        Raspberry Pi Pico 2 firmware (Embassy + USB HID)
+-- protocol/           gRPC stubs and proto definitions
+-- e2e/                End-to-end integration tests (includes signer-server)
+-- scripts/            Utilities (bitcoin.sh, test_pico.py, udev rules)
+-- docker-compose.yml  Bitcoin regtest environment (bitcoind + electrs)
+-- Makefile            Build, flash, and run targets
```

### Flutter App (`ap/`)

Android wallet UI built with Provider state management and GoRouter navigation. Onboarding flow guides the user through server connection, hardware signer pairing, and DKG key generation. Supports sending/receiving Bitcoin, spending policies, and QR codes.

### Client Library (`client/`)

High-level Dart API that orchestrates the full MPC protocol. Manages two local identities (signing + recovery), communicates with the coordination server over gRPC, drives the hardware signer over USB HID, and handles Taproot address derivation, UTXO tracking, coin selection, and PSBT construction. Includes the Dart FFI wrapper for the threshold crypto library.

### Threshold Library (`threshold/`)

`#![no_std]` Rust implementation of FROST (Flexible Round-Optimized Schnorr Threshold Signatures) over secp256k1 using the `k256` crate. Includes the full 3-round DKG protocol, Pedersen VSS, nonce commitment generation, signature share computation, Lagrange interpolation, Taproot key tweaking, and key refresh. Compiles for four targets: native (tests & server), `wasm32-wasip1` (cosigner), `thumbv8m.main-none-eabihf` (Pico 2), and Dart FFI (`libthreshold_ffi.so`).

### Threshold FFI (`threshold-ffi/`)

C-ABI shared library that wraps the threshold crate for consumption by Dart via `dart:ffi`. Exposes handle-based functions for DKG, nonce generation, signing, and key refresh. The Dart FFI bindings live inside `client/lib/threshold/`.

### Coordination Server (`server/`)

Rust gRPC server that participates as the third identity in DKG and signing. Each user gets an isolated WASI sandbox — the server uses Wasmtime to instantiate a per-user cosigner WASM component that holds the server's key share and performs threshold crypto operations. Routes packages between participants, aggregates signature shares, enforces spending policies, and interfaces with Bitcoin Core (RPC) and Electrs (UTXO indexing).

### Cosigner (`cosigner/`)

WASI P2 Component Model guest that encapsulates all threshold cryptography on the server side. Compiled to `wasm32-wasip1` and loaded by the server into per-user Wasmtime instances. Exposes DKG, nonce generation, signing, and key refresh operations through a WIT interface. Shares no memory between users.

### Pico Signer Firmware (`pico-signer/`)

Embassy-based async firmware for the RP2350 (Raspberry Pi Pico 2). Communicates over vendor-defined USB HID (64-byte reports) using a chunking protocol for JSON messages up to 8KB. Persists key material to the last 4KB flash sector after DKG. Handles all six commands: `dkg_init`, `dkg_round2`, `dkg_round3`, `generate_nonce`, `sign`, `get_info`.

### Signer Server (`e2e/signer-server/`)

Standalone Rust TCP server that implements the same JSON command protocol as the Pico firmware. Used in E2E and integration tests to simulate the hardware signer without physical hardware.

## Protocol

### Distributed Key Generation (3 rounds)

All three identities participate. Each generates a random polynomial, exchanges commitments (Round 1), distributes secret shares (Round 2), and verifies shares against commitments to derive their `KeyPackage` and the shared `PublicKeyPackage` (Round 3). No party ever sees the full private key.

### FROST Signing (2 rounds)

Any two identities can co-sign. Each generates an ephemeral nonce pair and exchanges commitments (Round 1). Each computes a signature share using their secret share, Lagrange coefficients, and the challenge hash (Round 2). The server aggregates shares into a final BIP-340 Schnorr signature `(R, z)`.

### Spending Policies

Key refresh creates additional key shares with time-windowed spending limits. Transactions below the threshold use the policy key (phone + server, no hardware signer needed). Policy updates and deletion require a recovery signature from the Pico.

### USB HID Chunking

Messages between the phone and Pico are split into 64-byte HID reports:

```
First report:  [channel:2][cmd:1][seq:2][total_len:2][payload:57B]
Continuation:  [channel:2][cmd:1][seq:2][payload:59B]
```

Channel `0x0101`, command `0x05` (MSG). Sequence numbers are big-endian `u16`. Last packet zero-padded. Strictly request-response.

## Prerequisites

- **Dart** >= 3.3
- **Flutter** >= 3.4 (Android SDK configured)
- **Rust** (stable toolchain)
- **Docker** & Docker Compose
- **protoc** with Dart plugin (only if regenerating gRPC stubs)
- **Android device** with USB OTG support (for hardware signer testing)

```bash
# Install Rust targets
rustup target add wasm32-wasip1                  # Cosigner WASM component
rustup target add thumbv8m.main-none-eabihf      # Pico 2 firmware

# Install cargo-component for building WASI components
cargo install cargo-component

# Install probe-rs for Pico flashing (optional, UF2 also supported)
cargo install probe-rs-tools
```

## Quick Start

### 1. Start the regtest environment

```bash
make regtest-up       # Docker: bitcoind + electrs
make bitcoin-init     # Mine 150 blocks
```

### 2. Run the coordination server

```bash
make server-run           # Builds cosigner WASM + server, runs on :50051
```

### 3a. Emulator testing (no hardware)

In a second terminal:

```bash
cd ap && flutter run   # Launch on emulator
```

### 3b. Physical device + Pico hardware signer

Flash the Pico (hold BOOTSEL, plug in USB, release):

```bash
make pico-flash       # Build firmware, convert to UF2, copy to RP2350 drive
```

Connect your Android phone via ADB (wireless debugging recommended to free the USB port for the Pico):

```bash
adb pair <ip>:<pairing-port>     # Pair once
adb connect <ip>:<connect-port>  # Connect
make adb-reverse                  # Forward ports 50051 + 50001 to PC
```

In a second terminal:

```bash
cd ap && flutter run   # Select "Hardware Signer (USB)" in onboarding
```

Connect the Pico to the phone via USB OTG adapter. The app will auto-discover it.

### 4. Smoke test the Pico (no phone needed)

```bash
# Quick: just get_info
make pico-test

# Full: 2-of-2 DKG + sign with signer-server as second participant
make pico-test ARGS="--full-dkg"
```

Requires the Python `hidapi` package (`pip install hidapi`) and the udev rule:

```bash
sudo cp scripts/99-pico-signer.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Testing

```bash
# Threshold library unit tests (Rust)
cd threshold && cargo test --features std

# Threshold FFI tests
cd threshold-ffi && cargo test

# End-to-end (builds all deps, starts Docker automatically)
make e2e-test

# Pico firmware over USB HID
make pico-test ARGS="--full-dkg"

## Performance & Stress Testing

The project includes benchmarks for the core cryptography and E2E load tests to ensure stability under concurrent usage.

### 1. Cryptography Benchmarks
Run [Criterion](https://github.com/bheisler/criterion.rs) benchmarks for the Rust `threshold` library:
```bash
make crypto-bench
```
This measures the latency of DKG rounds, signature share generation, and share aggregation.

### 2. Multi-User Stress Test
Simulate multiple users performing concurrent DKGs and sequential transaction rounds in a Regtest environment:
```bash
make stress-test
```
This target:
1. Stops any running servers.
2. Starts a fresh Bitcoin Regtest environment.
3. Launches the hardware signer simulator (`signer-server`).
4. Launches the MPC Wallet Server.
5. Runs the Dart E2E stress test suite (`multi_user_stress_test.dart`).
6. Cleans up by stopping the servers.
```

## Makefile Reference

| Target | Description |
|--------|-------------|
| `regtest-up` | Start bitcoind + electrs via Docker Compose |
| `regtest-down` | Stop Docker containers and kill server processes |
| `server-build` | Build the Rust gRPC server |
| `server-run` | Build cosigner WASM + server and run on :50051 |
| `server-stop` | Stop the Rust gRPC server |
| `cosigner-build` | Build WASM cosigner component (`wasm32-wasip1`) |
| `bitcoin-init` | Mine 150 regtest blocks |
| `signer-build` | Build the TCP signer-server in `e2e/signer-server/` |
| `signer-run` | Build and run signer-server on port 9090 (for e2e tests) |
| `e2e-test` | Run full E2E test (builds all deps, requires Docker) |
| `threshold-ffi-build` | Build threshold FFI shared library (`libthreshold_ffi.so`) |
| `threshold-test` | Run threshold Rust unit tests |
| `threshold-ffi-test` | Run threshold-ffi tests |
| `pico-build` | Build Pico 2 firmware |
| `pico-flash` | Build, convert to UF2, and copy to RP2350 drive |
| `pico-test` | Test Pico over USB HID (`ARGS="--full-dkg"` for full test) |
| `adb-reverse` | Forward ports 50051 + 50001 from phone to PC |
| `regtest` | Full dev stack: Docker + init + signer + server |
| `regtest-hardware` | Hardware dev stack: Docker + init + ADB + server |
| `proto` | Regenerate Dart gRPC stubs from `.proto` files |
| `crypto-bench` | Run Rust cryptography benchmarks (Criterion) |
| `stress-test` | Run multi-user E2E stress test (DKG + transactions) |

## Security Model

- The **full private key never exists** on any single device.
- The **hardware signer's secret share** never leaves the Pico's flash memory.
- The **server cannot unilaterally sign** — it always needs cooperation from the phone or Pico.
- The server is designed to run inside a **Trusted Execution Environment (TEE)**, ensuring the server operator cannot access key shares in memory.
- Each user's server-side key share runs in an **isolated WASM sandbox** (Wasmtime) with no shared memory between users.
- Signing requests are **authenticated** with Schnorr signatures over timestamped messages to prevent replay attacks.
- Policy changes (update/delete spending limits) require a **recovery signature** from the hardware signer.
- The Pico uses the RP2350's **hardware TRNG** for all randomness.

## References

- [FROST: Flexible Round-Optimized Schnorr Threshold Signatures](https://eprint.iacr.org/2020/852)
- [BIP-340: Schnorr Signatures for secp256k1](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)
- [BIP-341: Taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
- [Pedersen's Verifiable Secret Sharing](https://link.springer.com/chapter/10.1007/3-540-46766-1_9)
- [WASI Component Model](https://component-model.bytecodealliance.org/)
- [Embassy: Async embedded framework for Rust](https://embassy.dev/)

## License

This project is part of the Bitspend Payment ecosystem.
