//! Non-Secure world client for calling into the Secure world via NSC veneers.

extern "C" {
    fn nsc_init() -> i32;
    fn nsc_process(ns_in_ptr: *const u8, in_len: u32, ns_out_ptr: *mut u8, out_cap: u32) -> i32;
}

/// Initialize the Secure crypto library.
pub fn init() -> Result<(), i32> {
    let result = unsafe { nsc_init() };
    if result < 0 { Err(result) } else { Ok(()) }
}

const BUF_SIZE: usize = 4096;

/// NS-side buffers (in NS RAM — accessible from both NS and Secure)
static mut NS_IN_BUF: [u8; BUF_SIZE] = [0u8; BUF_SIZE];
static mut NS_OUT_BUF: [u8; BUF_SIZE] = [0u8; BUF_SIZE];

/// Send a JSON request to the Secure world, get JSON response back.
pub fn call_secure(request_json: &[u8]) -> Result<&'static [u8], i32> {
    if request_json.len() > BUF_SIZE {
        return Err(-2);
    }

    unsafe {
        // Copy request into NS buffer
        NS_IN_BUF[..request_json.len()].copy_from_slice(request_json);

        // Call Secure world — it reads from NS_IN_BUF, writes to NS_OUT_BUF
        let result = nsc_process(
            NS_IN_BUF.as_ptr(),
            request_json.len() as u32,
            NS_OUT_BUF.as_mut_ptr(),
            BUF_SIZE as u32,
        );

        if result < 0 {
            return Err(result);
        }

        Ok(&NS_OUT_BUF[..result as usize])
    }
}
