# Hardware Signer — TrustZone Architecture

The hardware signer is the recovery identity (2/3) in the VTXOS threshold scheme. It runs on an RP2350 (Cortex-M33) and uses **ARM TrustZone** to provide hardware-enforced isolation between the crypto engine and the USB attack surface.

```
┌──────────────────────────────────────────────────────────┐
│  SECURE WORLD (hwsigner-secure/)                         │
│  Flash: 0x10000000 — 512K                                │
│  RAM:   0x20060000 — 128K                                │
│                                                          │
│  • Boots from ROM (rp235x-hal)                           │
│  • Initializes clocks, PLLs                              │
│  • Configures SAU, ACCESSCTRL, DMA SECCFG, NVIC_ITNS    │
│  • FROST threshold signing, DKG, nonce generation        │
│  • TRNG hardware random number generator                 │
│  • Key storage in Secure flash (0x103FF000)              │
│  • BLXNS → hands off to Non-Secure world                 │
│                                                          │
│  NSC entry points (SG veneers):                          │
│    nsc_init()    — init crypto library                   │
│    nsc_process() — handle JSON crypto request/response   │
└────────────────────────┬─────────────────────────────────┘
                         │ SG veneers (Secure Gateway)
┌────────────────────────┴─────────────────────────────────┐
│  NON-SECURE WORLD (hwsigner/)                            │
│  Flash: 0x10080000 — 3584K                               │
│  RAM:   0x20000000 — 384K                                │
│                                                          │
│  • Embassy async runtime + USB HID                       │
│  • JSON protocol over 64-byte HID reports                │
│  • Forwards crypto requests to Secure via nsc_process()  │
│  • CANNOT access: Secure flash, Secure RAM, TRNG, keys   │
└──────────────────────────────────────────────────────────┘
```

## Security Boundaries (SAU Regions)

| Region | Address Range | Attribute | Purpose |
|--------|--------------|-----------|---------|
| 0 | `0x10080000 - 0x103FEFFF` | NS | Non-Secure firmware flash |
| 1 | `0x20000000 - 0x2005FFFF` | NS | Non-Secure RAM |
| 2 | `0x1002AB00 - 0x1002ABFF` | NSC | SG veneers (crypto entry points) |
| 3 | `0x40000000 - 0x50FFFFFF` | NS | Peripherals + USB DPRAM |
| 4 | `0xD0000000 - 0xD0020FFF` | NS | SIO |
| 5 | `0x00000000 - 0x00007DFF` | NS | Boot ROM |
| 7 | *(boot ROM)* | NSC | Boot ROM SG gateway |
| — | Everything else | **Secure** | Crypto library, key flash, crypto RAM |

## Boot Sequence

1. **Boot ROM** verifies Secure world signature against OTP key hash
2. **Secure world** initializes clocks (XOSC 12MHz, PLL_SYS 150MHz, PLL_USB 48MHz)
3. Deasserts NS peripherals from reset (IO_BANK0, PADS_BANK0, DMA, USB)
4. Configures DMA internal security (SECCFG channels + IRQs)
5. Configures SAU (6 regions) + ACCESSCTRL (with write password `0xACCE00FF`)
6. Locks ACCESSCTRL (Core0 lock — NS code cannot reconfigure)
7. Retargets interrupts to NS (TIMER0, DMA, USB, IO_BANK0 via NVIC_ITNS)
8. Configures FPU for TrustZone (NSACR, FPCCR)
9. Initializes crypto library (TRNG, loads keys from Secure flash)
10. Sets NS VTOR + MSP from NS vector table
11. **BLXNS** → transitions CPU to Non-Secure state
12. **NS world** runs cortex-m-rt Reset handler → `embassy_rp::init_ns()` → Embassy executor → USB HID

## Embassy Fork (`crates/embassy-rp-fork/`)

A minimal fork of `embassy-rp` 0.9.0 that adds TrustZone Non-Secure support:

- **`init_ns(NsClockConfig)`** — initializes Embassy without touching clocks/PLLs/resets (Secure world already configured them). Populates the internal `CLOCKS` static with known frequencies and enables timer/DMA/GPIO interrupts.
- **`trustzone-ns` feature** — disables `pre_init` which writes to Secure-only registers (SIO spinlock, PSM, ACTLR) that would fault from NS state.

## NSC Protocol

The Non-Secure world communicates with the Secure crypto library through two NSC (Non-Secure Callable) functions exposed via SG (Secure Gateway) veneers:

```
nsc_init() -> i32
    Initialize crypto library (TRNG, load keys, signer state).
    Returns 0 on success.

nsc_process(ns_in_ptr, in_len, ns_out_ptr, out_cap) -> i32
    Process a JSON crypto request.
    Secure world copies data from NS buffers, processes, copies response back.
    Returns response length (>0) or error code (<0).
```

The NS world keeps its own buffers in NS RAM and passes pointers to the Secure world. The Secure world copies data internally, processes the request, zeros the input buffer (may contain DKG secrets), and copies the response to the NS output buffer.

## USB HID Protocol

Messages between the phone and hardware signer are split into 64-byte HID reports:

```
First report:  [channel:2][cmd:1][seq:2][total_len:2][payload:57B]
Continuation:  [channel:2][cmd:1][seq:2][payload:59B]
```

Channel `0x0101`, command `0x05` (MSG). Sequence numbers are big-endian `u16`. Last packet zero-padded. Strictly request-response.

### Commands

| Command | Description |
|---------|-------------|
| `dkg_init` | Initialize DKG round 1 |
| `dkg_round2` | Process round 1 packages, generate round 2 output |
| `dkg_round3` | Finalize with round 2 packages, derive key material |
| `generate_nonce` | Create ephemeral nonce pair for signing |
| `sign` | Generate signature share |
| `get_info` | Query key material status |

## Build, Sign, and Flash

The firmware is signed with **ECDSA secp256k1 + SHA-256**. The RP2350's boot ROM verifies the signature against a public key hash burned into OTP before executing. Unsigned or tampered firmware will not boot.

### First-time setup (generate signing key)

```bash
mkdir -p keys
openssl ecparam -name secp256k1 -genkey -noout -out keys/ec_private_key.pem
openssl ec -in keys/ec_private_key.pem -pubout -out keys/ec_public_key.pem
```

**Back up `keys/ec_private_key.pem` securely.** If Secure Boot is enabled and you lose this key, the device is permanently bricked.

### Build, sign, and flash

```bash
make hw-flash         # Builds both worlds, signs Secure, flashes via debug probe
```

This runs:
1. `hw-build-secure` — builds Secure world with `cargo +nightly` (generates `target/veneers.o`)
2. `hw-build-ns` — clean-builds NS world (links `veneers.o` for NSC symbols)
3. `hw-sign` — signs Secure ELF with `picotool seal --sign --hash`
4. Flashes both images via `probe-rs download`
5. Resets the device

### Smoke test

```bash
make hw-test                    # Quick: just get_info
make hw-test ARGS="--full-dkg"  # Full: DKG + signing with signer-server
```

Requires Python `hidapi` and the udev rule:

```bash
sudo cp scripts/99-hwsigner.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Secure Boot Provisioning (irreversible — read carefully)

All OTP writes are **permanent**. There is no undo. If you lose `keys/ec_private_key.pem` after enabling Secure Boot, the device is **bricked forever**.

Put the device in BOOTSEL mode (hold BOOTSEL + plug in USB) for all OTP commands.

### Step 1: Prepare OTP config (remove enforcement)

`make hw-sign` generates `keys/otp.json` which includes `"crit1": {"secure_boot_enable": 1}`. Remove that section so we enroll the key without enabling enforcement:

```bash
jq 'del(.crit1)' keys/otp.json > keys/otp_enroll_only.json
```

### Step 2: Enroll signing key hash in OTP

```bash
# Burns SHA-256 hash of your public key into BOOTKEY0 (OTP rows 0x0080-0x008F).
# These 16 rows can NEVER be changed.
picotool otp load keys/otp_enroll_only.json
```

### Step 3: Verify enrollment

```bash
picotool otp get BOOT_FLAGS1     # KEY_VALID should be 1
picotool otp get BOOTKEY0_0      # Should show non-zero hash value
picotool otp get CRIT1           # SECURE_BOOT_ENABLE should still be 0
```

### Step 4: Invalidate unused key slots

```bash
# The RP2350 has 4 key slots (BOOTKEY0-3). We only use slot 0.
# Invalidating slots 1-3 prevents an attacker from enrolling their own key
# in an empty slot and signing malicious firmware.
# KEY_INVALID bits 8-11 = 0x0E, combined with existing KEY_VALID bit 0 = 0x01.
picotool otp set BOOT_FLAGS1 0x0e01
```

### Step 5: Enable Secure Boot enforcement

```bash
# WARNING: This is IRREVERSIBLE.
# After this:
#   - Only firmware signed with your private key will boot
#   - RISC-V cores are permanently disabled (ARM-only)
#   - Unsigned firmware is rejected by the boot ROM
#   - Losing ec_private_key.pem = bricked device
picotool otp set CRIT1 0x01
```

### Step 6: Verify Secure Boot works

```bash
# Reboot device (unplug + replug, or probe-rs reset)
# Flash SIGNED firmware — should boot:
make hw-flash && make hw-test

# Flash UNSIGNED firmware — should be REJECTED by boot ROM:
probe-rs download --chip RP2350 hwsigner-secure/hwsigner-secure.elf
probe-rs reset --chip RP2350
# Device will not enumerate on USB — boot ROM rejected unsigned image
```

### Optional future hardening

```bash
# Disable all debug access (SWD probe will no longer work)
picotool otp set CRIT1 0x05    # SECURE_BOOT_ENABLE + DEBUG_DISABLE

# Enable glitch detection (hardware defense against fault injection)
picotool otp set CRIT1 0x11    # SECURE_BOOT_ENABLE + GLITCH_DETECTOR_ENABLE
```

## References

- [ARMv8-M TrustZone](https://developer.arm.com/Architectures/TrustZone)
- [RP2350 Datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf)
- [Embassy: Async embedded framework for Rust](https://embassy.dev/)
