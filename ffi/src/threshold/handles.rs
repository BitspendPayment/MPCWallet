//! Opaque handle helpers for boxing/unboxing Rust types across FFI.

use std::os::raw::c_void;

/// Box a value and return it as an opaque pointer.
pub fn box_handle<T>(val: T) -> *mut c_void {
    Box::into_raw(Box::new(val)) as *mut c_void
}

/// Borrow an opaque pointer as a reference. Returns None if null.
///
/// # Safety
/// The pointer must have been produced by `box_handle::<T>` and not yet freed.
pub unsafe fn borrow_handle<'a, T>(ptr: *mut c_void) -> Option<&'a T> {
    if ptr.is_null() {
        None
    } else {
        Some(&*(ptr as *const T))
    }
}

/// Take ownership of an opaque pointer, consuming the handle.
///
/// # Safety
/// The pointer must have been produced by `box_handle::<T>` and not yet freed.
/// After calling this, the pointer is invalid.
#[allow(dead_code)]
pub unsafe fn take_handle<T>(ptr: *mut c_void) -> Option<Box<T>> {
    if ptr.is_null() {
        None
    } else {
        Some(Box::from_raw(ptr as *mut T))
    }
}
