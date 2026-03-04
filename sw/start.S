/* start.S - Minimal RISC-V startup for PicoRV32 SoC
 * Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)
 *
 * PicoRV32 hardware initialises x2 (sp) to STACKADDR (0x2000) at reset,
 * but we set it here explicitly for simulator compatibility.
 */

.section .text.start
.global _start
.type   _start, @function

_start:
    /* Set stack pointer to top of 8 KB BRAM */
    li   sp, 0x2000

    /* Zero the .bss section */
    la   a0, _bss_start
    la   a1, _bss_end
.Lbss_loop:
    beq  a0, a1, .Lbss_done
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    .Lbss_loop
.Lbss_done:

    /* Call main — should never return */
    call main

    /* Halt if main returns */
.Lhalt:
    j    .Lhalt

.size _start, . - _start
