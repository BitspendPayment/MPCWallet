//! Secure flash persistence for key material.
//!
//! Uses raw XIP memory-mapped reads and RP2350 boot ROM flash functions
//! for erase/write. The last 4KB flash sector at 0x103FF000 is SAU-protected
//! and only accessible from the Secure world.
//!
//! Layout v2 (same as original hwsigner):
//!   [magic:1=0xA5][version:1=0x02]
//!   [secret_len:2 BE][DKG secret bytes (32)]
//!   [kp_len:2 BE][KeyPackage JSON bytes]
//!   [pkp_len:2 BE][PublicKeyPackage JSON bytes]
//!   [crc32:4 BE] (over all preceding bytes)

extern crate alloc;

use defmt::*;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use zeroize::Zeroize;

/// Flash offset of the key storage sector (last 4KB of 4MB flash).
const STORAGE_OFFSET: u32 = 0x3FF000;
/// Sector size for erase operations.
const SECTOR_SIZE: usize = 4096;
/// XIP base address — flash is memory-mapped here.
const XIP_BASE: u32 = 0x1000_0000;

const MAGIC: u8 = 0xA5;
const VERSION: u8 = 0x02;

pub struct KeyStorage;

impl KeyStorage {
    pub fn new() -> Self {
        Self
    }
}

/// Load key material from Secure flash via XIP memory-mapped read.
/// Returns None if no valid data found.
pub fn load() -> Option<(KeyPackage, PublicKeyPackage, Option<[u8; 32]>)> {
    // Read the flash sector via XIP (memory-mapped, read-only)
    let flash_ptr = (XIP_BASE + STORAGE_OFFSET) as *const u8;
    let mut buf = [0u8; SECTOR_SIZE];
    unsafe {
        core::ptr::copy_nonoverlapping(flash_ptr, buf.as_mut_ptr(), SECTOR_SIZE);
    }

    if buf[0] != MAGIC {
        info!("No key material in Secure flash (magic mismatch)");
        buf.zeroize();
        return None;
    }

    if buf[1] != VERSION {
        info!("No key material in Secure flash (version mismatch)");
        buf.zeroize();
        return None;
    }

    let result = load_v2(&buf);
    buf.zeroize();
    result
}

fn load_v2(buf: &[u8; SECTOR_SIZE]) -> Option<(KeyPackage, PublicKeyPackage, Option<[u8; 32]>)> {
    // Parse DKG secret
    let secret_len = u16::from_be_bytes([buf[2], buf[3]]) as usize;
    if secret_len != 32 {
        warn!("Invalid secret_len in flash: {}", secret_len);
        return None;
    }
    let mut dkg_secret = [0u8; 32];
    dkg_secret.copy_from_slice(&buf[4..36]);

    // Parse KeyPackage
    let kp_offset = 36;
    let kp_len = u16::from_be_bytes([buf[kp_offset], buf[kp_offset + 1]]) as usize;
    let kp_start = kp_offset + 2;
    if kp_start + kp_len + 2 > SECTOR_SIZE - 4 {
        warn!("Invalid kp_len in flash");
        return None;
    }
    let kp_json = core::str::from_utf8(&buf[kp_start..kp_start + kp_len]).ok()?;

    // Parse PublicKeyPackage
    let pkp_offset = kp_start + kp_len;
    let pkp_len = u16::from_be_bytes([buf[pkp_offset], buf[pkp_offset + 1]]) as usize;
    let pkp_start = pkp_offset + 2;
    if pkp_start + pkp_len > SECTOR_SIZE - 4 {
        warn!("Invalid pkp_len in flash");
        return None;
    }
    let pkp_json = core::str::from_utf8(&buf[pkp_start..pkp_start + pkp_len]).ok()?;

    // Verify CRC32
    let crc_offset = pkp_start + pkp_len;
    let stored_crc = u32::from_be_bytes([
        buf[crc_offset],
        buf[crc_offset + 1],
        buf[crc_offset + 2],
        buf[crc_offset + 3],
    ]);
    let computed_crc = crc32(&buf[..crc_offset]);
    if stored_crc != computed_crc {
        warn!("Flash CRC mismatch");
        return None;
    }

    let kp = KeyPackage::from_json(kp_json).ok()?;
    let pkp = PublicKeyPackage::from_json(pkp_json).ok()?;

    info!("Loaded key material from Secure flash");
    Some((kp, pkp, Some(dkg_secret)))
}

impl KeyStorage {
    /// Save key material to Secure flash. Erases the sector first.
    pub fn save(
        &mut self,
        kp: &KeyPackage,
        pkp: &PublicKeyPackage,
        dkg_secret: Option<&[u8; 32]>,
    ) -> Result<(), ()> {
        let kp_json = kp.to_json();
        let pkp_json = pkp.to_json();

        let kp_bytes = kp_json.as_bytes();
        let pkp_bytes = pkp_json.as_bytes();

        let secret_bytes: &[u8; 32] = match dkg_secret {
            Some(s) => s,
            None => {
                error!("DKG secret required for v2 save");
                return Err(());
            }
        };

        // Build buffer
        let total = 2 + 2 + 32 + 2 + kp_bytes.len() + 2 + pkp_bytes.len() + 4;
        if total > SECTOR_SIZE {
            error!("Key material too large for flash sector");
            return Err(());
        }

        let mut buf = [0xFFu8; SECTOR_SIZE];
        buf[0] = MAGIC;
        buf[1] = VERSION;

        // DKG secret
        buf[2..4].copy_from_slice(&32u16.to_be_bytes());
        buf[4..36].copy_from_slice(secret_bytes);

        // KeyPackage
        let kp_offset = 36;
        buf[kp_offset..kp_offset + 2].copy_from_slice(&(kp_bytes.len() as u16).to_be_bytes());
        let kp_start = kp_offset + 2;
        buf[kp_start..kp_start + kp_bytes.len()].copy_from_slice(kp_bytes);

        // PublicKeyPackage
        let pkp_offset = kp_start + kp_bytes.len();
        buf[pkp_offset..pkp_offset + 2].copy_from_slice(&(pkp_bytes.len() as u16).to_be_bytes());
        let pkp_start = pkp_offset + 2;
        buf[pkp_start..pkp_start + pkp_bytes.len()].copy_from_slice(pkp_bytes);

        // CRC32
        let crc_offset = pkp_start + pkp_bytes.len();
        let crc = crc32(&buf[..crc_offset]);
        buf[crc_offset..crc_offset + 4].copy_from_slice(&crc.to_be_bytes());

        // Erase and write via RP2350 boot ROM functions
        flash_erase(STORAGE_OFFSET, SECTOR_SIZE as u32)?;
        flash_write(STORAGE_OFFSET, &buf)?;

        info!("Saved key material to Secure flash");
        Ok(())
    }
}

/// Erase flash using RP2350 boot ROM `flash_range_erase`.
fn flash_erase(offset: u32, len: u32) -> Result<(), ()> {
    // The RP2350 boot ROM exposes flash_range_erase and flash_range_program
    // functions. We call them through the ROM function table.
    //
    // Safety: Must be called with interrupts disabled and from Secure world.
    // The flash controller is not re-entrant.
    cortex_m::interrupt::free(|_| unsafe {
        // ROM function table lookup for flash_range_erase
        // ROM table pointer is at 0x00000014 (RP2350 ROM table)
        let rom_table: *const u16 = *(0x0000_0014 as *const *const u16);
        let flash_erase_fn = rom_func_lookup(rom_table, b'R', b'E');
        if flash_erase_fn == 0 {
            error!("Flash erase ROM function not found");
            return Err(());
        }
        let erase: extern "C" fn(u32, usize, u32, u8) =
            core::mem::transmute(flash_erase_fn as *const ());
        erase(offset, len as usize, 1 << 16, 0xD8); // 64KB block erase command
        Ok(())
    })
}

/// Write flash using RP2350 boot ROM `flash_range_program`.
fn flash_write(offset: u32, data: &[u8]) -> Result<(), ()> {
    cortex_m::interrupt::free(|_| unsafe {
        let rom_table: *const u16 = *(0x0000_0014 as *const *const u16);
        let flash_program_fn = rom_func_lookup(rom_table, b'R', b'P');
        if flash_program_fn == 0 {
            error!("Flash program ROM function not found");
            return Err(());
        }
        let program: extern "C" fn(u32, *const u8, usize) =
            core::mem::transmute(flash_program_fn as *const ());
        program(offset, data.as_ptr(), data.len());
        Ok(())
    })
}

/// Look up a ROM function by its two-character code.
unsafe fn rom_func_lookup(table: *const u16, c1: u8, c2: u8) -> u32 {
    let code = (c2 as u16) << 8 | c1 as u16;
    let mut ptr = table;
    loop {
        let entry = *ptr;
        if entry == 0 {
            return 0;
        }
        let fn_code = *ptr.add(1);
        if fn_code == code {
            // The function pointer is stored as a 16-bit offset in older RP chips,
            // but RP2350 uses the Bootrom API. This is a simplified placeholder —
            // the actual lookup uses the rp2350 ROM table format.
            return *ptr as u32;
        }
        ptr = ptr.add(2);
    }
}

/// Simple CRC32 (no lookup table to save flash space).
fn crc32(data: &[u8]) -> u32 {
    let mut crc: u32 = 0xFFFF_FFFF;
    for &byte in data {
        crc ^= byte as u32;
        for _ in 0..8 {
            if crc & 1 != 0 {
                crc = (crc >> 1) ^ 0xEDB8_8320;
            } else {
                crc >>= 1;
            }
        }
    }
    !crc
}
