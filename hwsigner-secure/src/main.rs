//! Secure world boot image for RP2350 TrustZone HW Signer.
//!
//! Boots first from ROM, initializes clocks/PLLs via rp235x-hal,
//! configures SAU + ACCESSCTRL, initializes the crypto library,
//! then hands off to the Non-Secure world via BXNS.

#![no_std]
#![no_main]
#![feature(abi_cmse_nonsecure_call)]
#![feature(cmse_nonsecure_entry)]

extern crate alloc;

mod allocator;
mod handler;
pub mod nsc;
pub mod protocol;
mod rng;
mod storage;

use cortex_m::peripheral::sau::{Ctrl, Rbar, Rlar, Rnr};
use defmt::*;
use defmt_rtt as _;
use panic_probe as _;

use rp235x_hal as hal;
use hal::entry;

/// Non-Secure world entry address (start of NS flash).
const NS_FLASH_BASE: u32 = 0x1008_0000;

/// Top of NS RAM (NS MSP initial value).
const NS_RAM_TOP: u32 = 0x2006_0000;

/// External crystal frequency (Pico 2 = 12 MHz).
const XTAL_FREQ_HZ: u32 = 12_000_000;

/// PICOBIN image definition — tells boot ROM this is a Secure ARM RP2350 image.
#[unsafe(link_section = ".start_block")]
#[used]
pub static IMAGE_DEF: hal::block::ImageDef = hal::block::ImageDef::secure_exe();

#[entry]
fn main() -> ! {
    info!("Secure world booting");

    // 1. Initialize Secure heap
    allocator::init();

    // 2. Initialize RP2350 hardware via rp235x-hal
    let mut pac = hal::pac::Peripherals::take().unwrap();
    let mut watchdog = hal::Watchdog::new(pac.WATCHDOG);

    let _clocks = hal::clocks::init_clocks_and_plls(
        XTAL_FREQ_HZ,
        pac.XOSC,
        pac.CLOCKS,
        pac.PLL_SYS,
        pac.PLL_USB,
        &mut pac.RESETS,
        &mut watchdog,
    )
    .unwrap();

    info!("Clocks initialized: sys=150MHz, usb=48MHz");

    // 3. Initialize crypto library
    rng::init_trng();
    let key_material = storage::load();
    nsc::init_signer_state(key_material);
    info!("Crypto library initialized");

    // 4. Deassert NS peripherals from reset (Secure world owns RESETS)
    //    The rp235x-hal clock init only deasserts clock-related peripherals.
    //    The NS world needs IO_BANK0, PADS_BANK0, DMA, USB, etc.
    {
        let peris_to_deassert: u32 =
            (1 << 2)  | // DMA
            (1 << 5)  | // IO_BANK0
            (1 << 8)  | // PADS_BANK0
            (1 << 14) | // SPI0
            (1 << 24);  // USBCTRL
        // RESETS base = 0x40020000
        // Atomic CLR alias at +0x3000 (clears bits = deasserts reset)
        unsafe {
            core::ptr::write_volatile(0x4002_3000 as *mut u32, peris_to_deassert);
            // Wait for reset done (RESET_DONE at +0x08)
            while core::ptr::read_volatile(0x4002_0008 as *const u32) & peris_to_deassert
                != peris_to_deassert {}
        }
        info!("NS peripherals deasserted from reset");
    }

    // 5. Configure DMA internal security — allow NS access to all channels/IRQs
    unsafe { configure_dma_security() };

    // 6. Configure SAU — mark NS regions, protect Secure flash/RAM/keys
    unsafe { configure_sau() };

    // 7. Configure ACCESSCTRL — grant NS access to USB/clocks/timers, keep TRNG Secure
    unsafe { configure_accessctrl() };

    // 8. Lock ACCESSCTRL — prevent NS code from reconfiguring peripheral security.
    //    Bit 4 = lock Core0. Once set, only a full chip reset can change ACCESSCTRL.
    unsafe {
        core::ptr::write_volatile(0x4006_0000 as *mut u32, 0xACCE_0010);
    }

    // 9. Retarget NS-needed interrupts to Non-Secure via NVIC_ITNS
    unsafe { retarget_interrupts_to_ns() };

    // 10. Allow NS access to FPU coprocessor (NSACR)
    unsafe {
        let nsacr = core::ptr::read_volatile(0xE000_ED8C as *const u32);
        core::ptr::write_volatile(0xE000_ED8C as *mut u32, nsacr | (3 << 10));
    }

    // 11. Disable FPU automatic state preservation for TrustZone transitions
    unsafe {
        core::ptr::write_volatile(0xE000_EF34 as *mut u32, 0x0000_0000); // FPCCR_S
        core::ptr::write_volatile(0xE002_EF34 as *mut u32, 0x0000_0000); // FPCCR_NS
    }

    // 12. Set NS VTOR and MSP from NS vector table
    unsafe {
        core::ptr::write_volatile(0xE002_ED08 as *mut u32, NS_FLASH_BASE);
        let ns_sp = core::ptr::read_volatile(NS_FLASH_BASE as *const u32);
        cortex_m::register::msp::write_ns(ns_sp);
    }

    cortex_m::asm::dsb();
    cortex_m::asm::isb();

    info!("TrustZone configured — BLXNS to Non-Secure world");

    // 8. Read NS Reset handler and branch via BLXNS
    unsafe {
        let ns_reset = core::ptr::read_volatile((NS_FLASH_BASE + 4) as *const u32);
        // BLXNS: bit 0 must be 0 for NS target on Cortex-M33.
        // The CPU stays in Thumb mode (Cortex-M only does Thumb).
        // Bit 0 = 0 signals "branch to Non-Secure state".
        let ns_target = ns_reset & !1u32;
        core::arch::asm!(
            "blxns {entry}",
            entry = in(reg) ns_target,
            options(noreturn),
        );
    }
}

/// Initialize NS world .bss (zero) and .data (copy from flash).
/// The NS world has no cortex-m-rt, so we do this from the Secure side.
///
/// Addresses are hardcoded from NS ELF build output (arm-none-eabi-objdump -h).
/// TODO: auto-generate from NS build artifacts.
unsafe fn init_ns_memory() {
    // NS .data: VMA=0x20000000, LMA=from flash, size from ELF
    // NS .bss:  VMA=after .data, size from ELF
    // These will be populated after first successful NS build.
    // For now, read the actual values from the NS ELF after building.

    // From NS ELF: arm-none-eabi-objdump -h hwsigner/target/.../hwsigner
    let ns_sbss: *mut u8 = 0x2000_0438 as *mut u8;
    let ns_bss_len: usize = 0x0002_07C4;
    let ns_sdata: *mut u8 = 0x2000_0000 as *mut u8;
    let ns_sidata: *const u8 = 0x1008_5FB4 as *const u8;
    let ns_data_len: usize = 0x38;

    // Zero .bss
    core::ptr::write_bytes(ns_sbss, 0, ns_bss_len);
    // Copy .data
    core::ptr::copy_nonoverlapping(ns_sidata, ns_sdata, ns_data_len);

    info!("NS .bss zeroed, .data copied");
}

/// Configure DMA internal security — allow NS access to all channels and IRQs.
///
/// The DMA peripheral has its own per-channel and per-IRQ security registers
/// (SECCFG_CH, SECCFG_IRQ, SECCFG_MISC) that are separate from ACCESSCTRL.
/// Without this, NS code cannot write DMA interrupt enable registers.
unsafe fn configure_dma_security() {
    const DMA_BASE: u32 = 0x5000_0000;

    // SECCFG_CH[0..15] at offset 0x480, stride 4
    // Set all channels to NS (bit 1 = S flag, clear it; bit 0 = P flag)
    for i in 0..16u32 {
        core::ptr::write_volatile((DMA_BASE + 0x480 + i * 4) as *mut u32, 0x0);
    }

    // SECCFG_IRQ[0..3] at offset 0x4C0, stride 4
    // Set all DMA IRQs to NS accessible
    for i in 0..4u32 {
        core::ptr::write_volatile((DMA_BASE + 0x4C0 + i * 4) as *mut u32, 0x0);
    }

    // SECCFG_MISC at offset 0x4D0
    // Set sniff, timer, multi-channel trigger to NS
    core::ptr::write_volatile((DMA_BASE + 0x4D0) as *mut u32, 0x0);
}

/// Configure SAU regions.
///
/// NS regions: main firmware flash/RAM, peripherals, SIO, boot ROM.
/// Everything else (crypto library, key flash, crypto RAM) stays Secure.
unsafe fn configure_sau() {
    let sau = &*cortex_m::peripheral::SAU::PTR;

    // Region 0: NS firmware flash (0x10080000 - 0x103FEFFF) → NS
    sau.rnr.write(Rnr(0));
    sau.rbar.write(Rbar(0x1008_0000));
    sau.rlar.write(Rlar(0x103F_EFE0 | 1));

    // Region 1: NS firmware RAM (0x20000000 - 0x2005FFFF) → NS
    sau.rnr.write(Rnr(1));
    sau.rbar.write(Rbar(0x2000_0000));
    sau.rlar.write(Rlar(0x2005_FFE0 | 1));

    // Region 2: SG veneers — crypto NSC entry points
    // Covers the .gnu.sgstubs section in Secure flash.
    // Wide range (0x1002A000-0x1002FFFF) to tolerate veneer address shifts
    // when the Secure binary is rebuilt.
    sau.rnr.write(Rnr(2));
    sau.rbar.write(Rbar(0x1002_A000));
    sau.rlar.write(Rlar(0x1002_FFE0 | 3)); // Enable + NSC

    // Region 3: Peripherals + USB DPRAM (0x40000000 - 0x50FFFFFF) → NS
    sau.rnr.write(Rnr(3));
    sau.rbar.write(Rbar(0x4000_0000));
    sau.rlar.write(Rlar(0x50FF_FFE0 | 1));

    // Region 4: SIO (0xD0000000 - 0xD0020FFF) → NS
    sau.rnr.write(Rnr(4));
    sau.rbar.write(Rbar(0xD000_0000));
    sau.rlar.write(Rlar(0xD002_0FE0 | 1));

    // Region 5: Boot ROM (0x00000000 - 0x00007DFF) → NS
    // Embassy calls ROM functions for clock queries.
    // ROM NSC gateway (region 7 at 0x7E00+) preserved from boot ROM.
    sau.rnr.write(Rnr(5));
    sau.rbar.write(Rbar(0x0000_0000));
    sau.rlar.write(Rlar(0x0000_7DE0 | 1));

    // NOT listed → Secure by default:
    //   Secure flash    (0x10000000 - 0x1007FFFF) — boot image + crypto
    //   Key flash       (0x103FF000 - 0x103FFFFF) — key storage
    //   Secure RAM      (0x20060000 - 0x2007FFFF) — crypto state + heap

    // Enable SAU
    let ctrl = sau.ctrl.read();
    sau.ctrl.write(Ctrl(ctrl.0 | 1));
}

/// Configure ACCESSCTRL — grant NS access to USB/clocks/timers, keep TRNG Secure.
unsafe fn configure_accessctrl() {
    #[inline(always)]
    unsafe fn grant_ns(offset: u32) {
        // ACCESSCTRL registers require password 0xACCE0000 in the upper 16 bits
        // Lower 8 bits are the access control value
        // 0xFF = all masters, all security levels (S + NS + DMA + debug)
        core::ptr::write_volatile(
            (0x4006_0000 + offset) as *mut u32,
            0xACCE_00FF,
        );
    }

    grant_ns(0x0C0); // CLOCKS
    grant_ns(0x0C4); // XOSC
    grant_ns(0x0C8); // ROSC
    grant_ns(0x0CC); // PLL_SYS
    grant_ns(0x0D0); // PLL_USB
    grant_ns(0x064); // RESETS
    grant_ns(0x048); // USBCTRL
    grant_ns(0x044); // DMA
    grant_ns(0x068); // IO_BANK0
    grant_ns(0x06C); // IO_BANK1
    grant_ns(0x070); // PADS_BANK0
    grant_ns(0x098); // TIMER0
    grant_ns(0x09C); // TIMER1
    grant_ns(0x0D4); // TICKS
    grant_ns(0x0D8); // WATCHDOG
    grant_ns(0x060); // SYSINFO
    grant_ns(0x078); // BUSCTRL
    grant_ns(0x0BC); // SYSCFG
    grant_ns(0x0AC); // TBMAN
    grant_ns(0x0B0); // POWMAN

    // Keep Secure: TRNG (0x0B4), OTP (0x0A8), SHA256 (0x0B8), XIP_CTRL/QMI
}

/// Retarget TIMER0_IRQ_0 and USBCTRL_IRQ to Non-Secure.
unsafe fn retarget_interrupts_to_ns() {
    const NVIC_ITNS0: *mut u32 = 0xE000_E380 as *mut u32;
    const NVIC_ICER0: *mut u32 = 0xE000_E180 as *mut u32;
    const NVIC_ICPR0: *mut u32 = 0xE000_E280 as *mut u32;
    const NVIC_ISER0: *mut u32 = 0xE000_E100 as *mut u32;

    // TIMER0_IRQ_0 = bit 0, USBCTRL_IRQ = bit 14
    // DMA_IRQ_0 = bit 10, IO_IRQ_BANK0 = bit 21
    let irq_bits: u32 = (1 << 0) | (1 << 10) | (1 << 14) | (1 << 21);

    core::ptr::write_volatile(NVIC_ICER0, irq_bits);
    core::ptr::write_volatile(NVIC_ICPR0, irq_bits);

    let itns = core::ptr::read_volatile(NVIC_ITNS0);
    core::ptr::write_volatile(NVIC_ITNS0, itns | irq_bits);

    core::ptr::write_volatile(NVIC_ISER0, irq_bits);
}

/// Program metadata for picotool.
#[unsafe(link_section = ".bi_entries")]
#[used]
pub static PICOTOOL_ENTRIES: [hal::binary_info::EntryAddr; 3] = [
    hal::binary_info::rp_cargo_bin_name!(),
    hal::binary_info::rp_cargo_version!(),
    hal::binary_info::rp_program_description!(c"HW Signer Secure World"),
];
