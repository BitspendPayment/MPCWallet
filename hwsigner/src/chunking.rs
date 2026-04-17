//! HID report chunking protocol.
//!
//! Splits JSON messages into 64-byte HID reports and reassembles them.
//! Protocol matches the Dart-side `hid_chunking.dart` implementation.
//!
//! Report layout (64 bytes):
//!   Bytes 0-1:  Channel ID (0x01, 0x01)
//!   Byte  2:    Command tag (0x05 = MSG)
//!   Bytes 3-4:  Sequence number (big-endian u16)
//!   Bytes 5+:   Payload
//!
//! First packet (seq 0) additionally carries:
//!   Bytes 5-6:  Total message length (big-endian u16)
//!   Bytes 7-63: First 57 bytes of payload
//!
//! Continuation packets (seq >= 1):
//!   Bytes 5-63: Next 59 bytes of payload

extern crate alloc;
use alloc::vec::Vec;

const CHANNEL: [u8; 2] = [0x01, 0x01];
const CMD_MSG: u8 = 0x05;
pub const REPORT_SIZE: usize = 64;
const HEADER_SIZE: usize = 5; // 2 channel + 1 cmd + 2 seq
const FIRST_PAYLOAD: usize = REPORT_SIZE - HEADER_SIZE - 2; // 57
const CONT_PAYLOAD: usize = REPORT_SIZE - HEADER_SIZE; // 59

/// Chunk a message into 64-byte HID reports.
pub fn chunk_message(msg: &[u8]) -> Vec<[u8; REPORT_SIZE]> {
    let total_len = msg.len();
    let mut reports = Vec::new();
    let mut offset = 0usize;
    let mut seq = 0u16;

    // First report
    let mut report = [0u8; REPORT_SIZE];
    report[0..2].copy_from_slice(&CHANNEL);
    report[2] = CMD_MSG;
    report[3..5].copy_from_slice(&seq.to_be_bytes());
    report[5..7].copy_from_slice(&(total_len as u16).to_be_bytes());
    let chunk = core::cmp::min(FIRST_PAYLOAD, total_len);
    report[7..7 + chunk].copy_from_slice(&msg[..chunk]);
    offset += chunk;
    reports.push(report);
    seq += 1;

    // Continuation reports
    while offset < total_len {
        let mut report = [0u8; REPORT_SIZE];
        report[0..2].copy_from_slice(&CHANNEL);
        report[2] = CMD_MSG;
        report[3..5].copy_from_slice(&seq.to_be_bytes());
        let chunk = core::cmp::min(CONT_PAYLOAD, total_len - offset);
        report[5..5 + chunk].copy_from_slice(&msg[offset..offset + chunk]);
        offset += chunk;
        reports.push(report);
        seq += 1;
    }

    reports
}

/// State machine for reassembling incoming HID reports into a complete message.
pub struct Reassembler {
    buffer: Vec<u8>,
    expected_len: usize,
    next_seq: u16,
    active: bool,
}

impl Reassembler {
    pub fn new() -> Self {
        Self {
            buffer: Vec::new(),
            expected_len: 0,
            next_seq: 0,
            active: false,
        }
    }

    /// Reset the reassembler state.
    pub fn reset(&mut self) {
        self.buffer.clear();
        self.expected_len = 0;
        self.next_seq = 0;
        self.active = false;
    }

    /// Feed a 64-byte HID report. Returns `Some(complete_message)` when done.
    pub fn feed(&mut self, report: &[u8; REPORT_SIZE]) -> Result<Option<Vec<u8>>, &'static str> {
        // Validate channel
        if report[0] != CHANNEL[0] || report[1] != CHANNEL[1] {
            return Err("invalid channel");
        }
        if report[2] != CMD_MSG {
            return Err("invalid command tag");
        }

        let seq = u16::from_be_bytes([report[3], report[4]]);

        if seq == 0 {
            // First packet
            self.reset();
            self.expected_len = u16::from_be_bytes([report[5], report[6]]) as usize;
            self.buffer.reserve(self.expected_len);
            let chunk = core::cmp::min(FIRST_PAYLOAD, self.expected_len);
            self.buffer.extend_from_slice(&report[7..7 + chunk]);
            self.next_seq = 1;
            self.active = true;
        } else {
            if !self.active || seq != self.next_seq {
                self.reset();
                return Err("unexpected sequence number");
            }
            let remaining = self.expected_len - self.buffer.len();
            let chunk = core::cmp::min(CONT_PAYLOAD, remaining);
            self.buffer.extend_from_slice(&report[5..5 + chunk]);
            self.next_seq += 1;
        }

        if self.buffer.len() >= self.expected_len {
            self.buffer.truncate(self.expected_len);
            let msg = core::mem::take(&mut self.buffer);
            self.reset();
            Ok(Some(msg))
        } else {
            Ok(None)
        }
    }
}
