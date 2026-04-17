/*
 * RP2350 Secure world linker script.
 *
 * Secure boot image: 0x10000000 - 0x1007FFFF (512K)
 *   Includes boot code, crypto library, NSC veneers
 * Key flash: 0x103FF000 - 0x103FFFFF (4K, SAU-protected)
 * Secure RAM: 0x20060000 - 0x2007FFFF (128K)
 *
 * NS flash starts at 0x10080000.
 */

MEMORY {
    FLASH : ORIGIN = 0x10000000, LENGTH = 512K
    RAM   : ORIGIN = 0x20060000, LENGTH = 128K
}

SECTIONS {
    .start_block : ALIGN(4) {
        __start_block_addr = .;
        KEEP(*(.start_block));
    } > FLASH
} INSERT AFTER .vector_table;

_stext = ADDR(.start_block) + SIZEOF(.start_block);

SECTIONS {
    .bi_entries : ALIGN(4) {
        __bi_entries_start = .;
        KEEP(*(.bi_entries));
        . = ALIGN(4);
        __bi_entries_end = .;
    } > FLASH
} INSERT AFTER .text;

SECTIONS {
    .end_block : ALIGN(4) {
        __end_block_addr = .;
        KEEP(*(.end_block));
    } > FLASH
} INSERT AFTER .uninit;

PROVIDE(start_to_end = __end_block_addr - __start_block_addr);
PROVIDE(end_to_start = __start_block_addr - __end_block_addr);
