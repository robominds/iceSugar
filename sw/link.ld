/* link.ld - Linker script for FemtoRV32 SoC on iCESugar-nano
 * Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)
 *
 * Single 6 KB BRAM region starting at 0x0 holds code, data, BSS, and stack.
 * The stack grows downward from 0x1800 (top of BRAM).
 * Peripheral registers (e.g. LED at 0x00001800) are accessed directly
 * as volatile pointers in C; they are not part of any memory region here.
 */

ENTRY(_start)

MEMORY
{
    bram (rwx) : ORIGIN = 0x00000000, LENGTH = 6K
}

SECTIONS
{
    .text : {
        *(.text.start)    /* _start must be at address 0 (reset vector) */
        *(.text*)
        *(.rodata*)
    } > bram

    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > bram

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > bram

    /* Stack top */
    _stack_top = ORIGIN(bram) + LENGTH(bram);

    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
