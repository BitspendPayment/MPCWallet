//! Secure world heap allocator (64KB from Secure RAM).

use embedded_alloc::LlffHeap as Heap;

#[global_allocator]
static HEAP: Heap = Heap::empty();

const HEAP_SIZE: usize = 64 * 1024;
static mut HEAP_MEM: [u8; HEAP_SIZE] = [0u8; HEAP_SIZE];

pub fn init() {
    unsafe {
        HEAP.init(HEAP_MEM.as_ptr() as usize, HEAP_SIZE);
    }
}
