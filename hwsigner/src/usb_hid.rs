//! USB HID configuration for vendor-defined 64-byte reports.

/// HID Report Descriptor: Vendor-defined usage page (0xFF00), 64-byte I/O.
pub const REPORT_DESCRIPTOR: &[u8] = &[
    0x06, 0x00, 0xFF, // Usage Page (Vendor Defined 0xFF00)
    0x09, 0x01,       // Usage (Vendor Usage 1)
    0xA1, 0x01,       // Collection (Application)
    //   Input report (device -> host)
    0x09, 0x01,       //   Usage (Vendor Usage 1)
    0x15, 0x00,       //   Logical Minimum (0)
    0x26, 0xFF, 0x00, //   Logical Maximum (255)
    0x75, 0x08,       //   Report Size (8 bits)
    0x95, 0x40,       //   Report Count (64)
    0x81, 0x02,       //   Input (Data, Variable, Absolute)
    //   Output report (host -> device)
    0x09, 0x02,       //   Usage (Vendor Usage 2)
    0x15, 0x00,       //   Logical Minimum (0)
    0x26, 0xFF, 0x00, //   Logical Maximum (255)
    0x75, 0x08,       //   Report Size (8 bits)
    0x95, 0x40,       //   Report Count (64)
    0x91, 0x02,       //   Output (Data, Variable, Absolute)
    0xC0,             // End Collection
];

/// Community VID from pid.codes (open-source USB IDs).
pub const VID: u16 = 0x1209;
/// Product ID (allocate from pid.codes for production).
pub const PID: u16 = 0x0001;
