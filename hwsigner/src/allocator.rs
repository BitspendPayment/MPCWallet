use embedded_alloc::LlffHeap as Heap;

#[global_allocator]
static HEAP: Heap = Heap::empty();

/// Initialize the heap allocator. Call once at startup.
/// Reserves 128KB of the 520KB SRAM for heap.
pub fn init() {
    const HEAP_SIZE: usize = 128 * 1024;
    static mut HEAP_MEM: [u8; HEAP_SIZE] = [0; HEAP_SIZE];
    unsafe { HEAP.init(HEAP_MEM.as_ptr() as usize, HEAP_SIZE) }
}
