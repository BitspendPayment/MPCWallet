//! Runtime glue for `#![no_std]` Bitcoin WASM contracts. A contract must import
//! ONLY `crypto` (no WASI) so the host's strict linker can sandbox it; that
//! means no std, which in turn means the contract must provide its own global
//! allocator, panic handler, and Canonical-ABI `cabi_realloc` (on wasm32-wasip2
//! `cabi_realloc` would otherwise come from std).
//!
//! A contract installs all three with one line at its crate root:
//!
//! ```ignore
//! #![no_std]
//! extern crate alloc;
//! contract_sdk::runtime!();
//! wit_bindgen::generate!({ world: "contract", path: "wit" });
//! ```
//!
//! The allocator is `talc`'s dynamic WASM allocator: it grows linear memory on
//! demand (no static arena) and supports real free. A runaway contract is still
//! bounded by the host's per-contract memory cap — growth fails, the allocation
//! errors, and the host treats the resulting trap as a deny (fail-closed).
#![no_std]

extern crate alloc;

use core::alloc::Layout;

/// Re-exported so the `runtime!` macro can name the allocator type from within
/// the contract crate.
#[doc(hidden)]
pub use talc;

/// Implementation of the Canonical ABI realloc, on top of the global allocator.
/// Exposed via the `runtime!` macro (which gives it the `cabi_realloc` export
/// name in the contract crate).
#[doc(hidden)]
pub unsafe fn cabi_realloc_impl(
    old_ptr: *mut u8,
    old_len: usize,
    align: usize,
    new_len: usize,
) -> *mut u8 {
    if new_len == 0 {
        return align as *mut u8;
    }
    let new_layout = Layout::from_size_align_unchecked(new_len, align);
    if old_len == 0 {
        return alloc::alloc::alloc(new_layout);
    }
    let old_layout = Layout::from_size_align_unchecked(old_len, align);
    alloc::alloc::realloc(old_ptr, old_layout, new_len)
}

/// Install the contract runtime: a dynamic global allocator (talc, grows WASM
/// memory on demand), a trapping panic handler, and the exported `cabi_realloc`.
/// Invoke once at the contract crate root. The items are emitted *here* (in the
/// contract crate) because `#[global_allocator]`/`#[panic_handler]`/the
/// `cabi_realloc` export must live in the final artifact.
#[macro_export]
macro_rules! runtime {
    () => {
        #[global_allocator]
        static __CONTRACT_ALLOC: $crate::talc::wasm::WasmDynamicTalc =
            $crate::talc::wasm::new_wasm_dynamic_allocator();

        #[panic_handler]
        fn __contract_panic(_: &core::panic::PanicInfo) -> ! {
            core::arch::wasm32::unreachable()
        }

        #[no_mangle]
        pub unsafe extern "C" fn cabi_realloc(
            old_ptr: *mut u8,
            old_len: usize,
            align: usize,
            new_len: usize,
        ) -> *mut u8 {
            $crate::cabi_realloc_impl(old_ptr, old_len, align, new_len)
        }
    };
}
