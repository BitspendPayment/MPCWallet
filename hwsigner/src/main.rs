//! Non-Secure world firmware for RP2350 TrustZone HW Signer.
//!
//! The Secure world boots first (rp235x-hal), initializes clocks/PLLs,
//! configures SAU/ACCESSCTRL, initializes the crypto library, then
//! BLXNS to this NS world's Reset handler.
//!
//! cortex-m-rt provides the vector table and .bss/.data init.
//! embassy_rp::init_ns() skips clock setup (already done by Secure world).

#![no_std]
#![no_main]

extern crate alloc;

mod allocator;
mod chunking;
mod nsc_client;
mod usb_hid;

use defmt::*;
use defmt_rtt as _;
use panic_probe as _;

use embassy_executor::Spawner;
use embassy_rp::bind_interrupts;
use embassy_rp::peripherals::USB;
use embassy_rp::usb::InterruptHandler;
use embassy_rp::NsClockConfig;
use embassy_usb::class::hid::{HidReaderWriter, State as HidState};
use embassy_usb::Builder;

bind_interrupts!(struct Irqs {
    USBCTRL_IRQ => InterruptHandler<USB>;
});

#[cortex_m_rt::entry]
fn main() -> ! {
    // DEBUG BISECT: uncomment one line at a time to find crash point
    // CHECKPOINT 1: NS main reached
    // loop { cortex_m::asm::nop(); }

    // 1. Initialize NS heap
    allocator::init();

    // CHECKPOINT 2: allocator done
    // loop { cortex_m::asm::nop(); }

    // 2. Initialize Embassy (clocks already configured by Secure world)
    let p = unsafe {
        embassy_rp::init_ns(NsClockConfig::rp2350_default())
    };

    info!("NS world running — Embassy initialized via init_ns()");

    // 3. Create and run Embassy executor
    let mut executor = embassy_executor::Executor::new();
    let executor = unsafe {
        core::mem::transmute::<&mut embassy_executor::Executor, &'static mut embassy_executor::Executor>(&mut executor)
    };
    executor.run(|spawner| {
        spawner.must_spawn(run_usb(spawner, p));
    })
}

/// Main USB HID task.
#[embassy_executor::task]
async fn run_usb(_spawner: Spawner, p: embassy_rp::Peripherals) {
    let driver = embassy_rp::usb::Driver::new(p.USB, Irqs);

    let mut config = embassy_usb::Config::new(usb_hid::VID, usb_hid::PID);
    config.manufacturer = Some("MPCWallet");
    config.product = Some("HW Signer");
    config.serial_number = Some("001");
    config.max_power = 100;
    config.max_packet_size_0 = 64;

    let mut config_descriptor = [0; 256];
    let mut bos_descriptor = [0; 256];
    let mut control_buf = [0; 64];
    let mut hid_state = HidState::new();

    let mut builder = Builder::new(
        driver,
        config,
        &mut config_descriptor,
        &mut bos_descriptor,
        &mut [],
        &mut control_buf,
    );

    let hid_config = embassy_usb::class::hid::Config {
        report_descriptor: usb_hid::REPORT_DESCRIPTOR,
        request_handler: None,
        poll_ms: 5,
        max_packet_size: 64,
    };
    let hid = HidReaderWriter::<_, 64, 64>::new(&mut builder, &mut hid_state, hid_config);

    let mut usb = builder.build();
    let (reader, writer) = hid.split();

    let usb_fut = usb.run();
    let hid_fut = run_hid_loop(reader, writer);

    info!("HW Signer ready — USB HID active, crypto via Secure NSC");
    embassy_futures::join::join(usb_fut, hid_fut).await;
}

/// HID request-response loop.
async fn run_hid_loop<'d, D: embassy_usb::driver::Driver<'d>>(
    mut reader: embassy_usb::class::hid::HidReader<'d, D, 64>,
    mut writer: embassy_usb::class::hid::HidWriter<'d, D, 64>,
) {
    let mut reassembler = chunking::Reassembler::new();
    let mut report_buf = [0u8; 64];

    loop {
        match reader.read(&mut report_buf).await {
            Ok(_) => {
                let report: &[u8; 64] = &report_buf;

                match reassembler.feed(report) {
                    Ok(Some(message)) => {
                        let response_bytes = match nsc_client::call_secure(&message) {
                            Ok(resp) => resp,
                            Err(code) => {
                                warn!("NSC call failed: {}", code);
                                b"{\"error\":\"secure world error\"}"
                            }
                        };

                        let reports = chunking::chunk_message(response_bytes);
                        for report in &reports {
                            if let Err(e) = writer.write(report).await {
                                error!("HID write error: {:?}", e);
                                break;
                            }
                        }
                    }
                    Ok(None) => {}
                    Err(e) => {
                        warn!("Reassembly error: {}", e);
                        reassembler.reset();
                        let err_json = br#"{"error":"protocol framing error"}"#;
                        let reports = chunking::chunk_message(err_json);
                        for report in &reports {
                            let _ = writer.write(report).await;
                        }
                    }
                }
            }
            Err(e) => {
                error!("HID read error: {:?}", e);
                embassy_time::Timer::after_millis(100).await;
            }
        }
    }
}
