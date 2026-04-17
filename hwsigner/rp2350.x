/*
* RP2350 Non-Secure world memory layout.
*
* This provides memory.x for cortex-m-rt (vector table + interrupt dispatch).
* The Secure world initializes .bss/.data and calls main() via BXNS.
* cortex-m-rt's Reset handler is NOT used (Secure boots first).
*
* Flash:
*   Secure (0x10000000, 512K): hwsigner-secure
*   NS     (0x10080000, 3584K): this image
*   Keys   (0x103FF000, 4K): SAU-protected
*
* RAM:
*   NS     (0x20000000, 384K): this image
*   Secure (0x20060000, 128K): SAU-protected
*/

MEMORY {
    FLASH : ORIGIN = 0x10080000, LENGTH = 3584K
    RAM   : ORIGIN = 0x20000000, LENGTH = 384K
}
