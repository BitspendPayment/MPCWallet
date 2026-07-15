//! Opaque handle helpers for boxing/unboxing Rust types across FFI.
//!
//! Handles box a `Box<dyn Any>` so the concrete type travels with the pointer (in
//! the vtable). This lets [`free_handle_any`] run the correct destructor regardless
//! of any caller-supplied `type_id` — a mismatched `type_id` can no longer free with
//! the wrong `Layout` and corrupt the heap — and makes [`borrow_handle`]/[`take_handle`]
//! fail with `None` on a type mismatch instead of committing type-confusion UB.
//!
//! The public API is unchanged: callers still `box_handle(val)` and
//! `borrow_handle::<T>(ptr)`; only the internal representation is type-tagged.

use std::any::Any;
use std::os::raw::c_void;

/// Box a value and return it as an opaque, type-tagged pointer.
pub fn box_handle<T: 'static>(val: T) -> *mut c_void {
    let boxed: Box<dyn Any> = Box::new(val);
    // Outer box makes the (fat) `Box<dyn Any>` addressable behind a thin pointer.
    Box::into_raw(Box::new(boxed)) as *mut c_void
}

/// Borrow an opaque pointer as `&T`. Returns `None` if null OR if the handle does
/// not actually hold a `T` (no more casting to the wrong type).
///
/// # Safety
/// The pointer must have been produced by `box_handle` and not yet freed.
pub unsafe fn borrow_handle<'a, T: 'static>(ptr: *mut c_void) -> Option<&'a T> {
    if ptr.is_null() {
        return None;
    }
    let boxed: &Box<dyn Any> = &*(ptr as *const Box<dyn Any>);
    boxed.downcast_ref::<T>()
}

/// Take ownership of an opaque pointer, consuming the handle. Returns `None` on null
/// or on a type mismatch (on mismatch the object is dropped correctly, not leaked).
///
/// # Safety
/// The pointer must have been produced by `box_handle` and not yet freed.
/// After calling this, the pointer is invalid.
#[allow(dead_code)]
pub unsafe fn take_handle<T: 'static>(ptr: *mut c_void) -> Option<Box<T>> {
    if ptr.is_null() {
        return None;
    }
    let outer: Box<Box<dyn Any>> = Box::from_raw(ptr as *mut Box<dyn Any>);
    (*outer).downcast::<T>().ok()
}

/// Free a handle produced by [`box_handle`], running the concrete destructor via the
/// `dyn Any` vtable (correct `Layout` regardless of the value's type).
///
/// # Safety
/// The pointer must have been produced by `box_handle` and not yet freed.
pub unsafe fn free_handle_any(ptr: *mut c_void) {
    if !ptr.is_null() {
        drop(Box::from_raw(ptr as *mut Box<dyn Any>));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn borrow_correct_type_then_wrong_type() {
        let p = box_handle(42u32);
        unsafe {
            assert_eq!(borrow_handle::<u32>(p), Some(&42));
            // Wrong type ⇒ None (previously this cast to the wrong type = UB).
            assert!(borrow_handle::<u64>(p).is_none());
            free_handle_any(p);
        }
    }

    #[test]
    fn null_is_none() {
        unsafe {
            assert!(borrow_handle::<u32>(std::ptr::null_mut()).is_none());
            assert!(take_handle::<u32>(std::ptr::null_mut()).is_none());
            free_handle_any(std::ptr::null_mut()); // no-op, no crash
        }
    }

    #[test]
    fn take_wrong_type_frees_and_returns_none() {
        let p = box_handle(7u8);
        unsafe {
            // Mismatch drops the value correctly (no leak, no wrong-Layout free) → None.
            assert!(take_handle::<u16>(p).is_none());
        }
    }

    #[test]
    fn take_correct_type_recovers_value() {
        let p = box_handle(String::from("secret"));
        unsafe {
            let got = take_handle::<String>(p).expect("correct type");
            assert_eq!(*got, "secret");
        }
    }
}
