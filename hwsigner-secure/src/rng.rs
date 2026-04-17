//! Hardware TRNG wrapper using raw register access.
//!
//! Uses the RP2350's true random number generator peripheral directly,
//! without the Embassy HAL or PAC. Runs in Secure world only.

use rand_core::{CryptoRng, RngCore};

// RP2350 TRNG register addresses (base: 0x400D0000)
const TRNG_BASE: u32 = 0x400D_0000;
const RNG_IMR: u32 = TRNG_BASE + 0x100;
const TRNG_CONFIG: u32 = TRNG_BASE + 0x104;
const RND_SOURCE_ENABLE: u32 = TRNG_BASE + 0x110;
const TRNG_VALID: u32 = TRNG_BASE + 0x114;
const EHR_DATA0: u32 = TRNG_BASE + 0x118;

/// Initialize the TRNG peripheral.
pub fn init_trng() {
    unsafe {
        core::ptr::write_volatile(RNG_IMR as *mut u32, 0);       // Mask interrupts (we poll)
        core::ptr::write_volatile(TRNG_CONFIG as *mut u32, 0);   // Default config
        core::ptr::write_volatile(RND_SOURCE_ENABLE as *mut u32, 1); // Enable entropy source
    }
}

/// Secure world RNG backed by the RP2350 hardware TRNG.
pub struct SecureRng;

impl RngCore for SecureRng {
    fn next_u32(&mut self) -> u32 {
        let mut buf = [0u8; 4];
        self.fill_bytes(&mut buf);
        u32::from_le_bytes(buf)
    }

    fn next_u64(&mut self) -> u64 {
        let mut buf = [0u8; 8];
        self.fill_bytes(&mut buf);
        u64::from_le_bytes(buf)
    }

    fn fill_bytes(&mut self, dest: &mut [u8]) {
        for chunk in dest.chunks_mut(24) {
            // Wait for valid random data
            unsafe {
                while core::ptr::read_volatile(TRNG_VALID as *const u32) == 0 {
                    cortex_m::asm::nop();
                }
            }

            // Read from EHR (Entropy Holding Register) data registers.
            // 6 x 32-bit registers = 192 bits (24 bytes) per sample.
            let mut ehr_data = [0u32; 6];
            for (i, word) in ehr_data.iter_mut().enumerate() {
                *word = unsafe {
                    core::ptr::read_volatile((EHR_DATA0 + i as u32 * 4) as *const u32)
                };
            }

            let mut offset = 0;
            for word in &ehr_data {
                let bytes = word.to_le_bytes();
                let remaining = chunk.len() - offset;
                let to_copy = remaining.min(4);
                chunk[offset..offset + to_copy].copy_from_slice(&bytes[..to_copy]);
                offset += to_copy;
                if offset >= chunk.len() {
                    break;
                }
            }
        }
    }

    fn try_fill_bytes(&mut self, dest: &mut [u8]) -> Result<(), rand_core::Error> {
        self.fill_bytes(dest);
        Ok(())
    }
}

impl CryptoRng for SecureRng {}
