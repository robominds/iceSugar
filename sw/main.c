/* main.c - LED frequency control firmware for FemtoRV32 SoC
 * Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)
 *
 * Writes a fixed half-period value (in 12 MHz clock cycles) to the
 * memory-mapped LED frequency register.
 *
 *   3 000 000 cycles = 250 ms half-period → 2 Hz blink
 */

#include <stdint.h>

/* Memory-mapped LED frequency register (write-only, in FPGA) */
#define FREQ_REG (*(volatile uint32_t *)0x00001800u)

/*
 * Busy-wait delay. At 12 MHz with a small RV32I soft-core,
 * the inner loop body takes roughly 3-4 cycles (~0.33 us per iteration).
 * n = 2 000 000 gives approximately 2 seconds of delay.
 */
static void delay(volatile uint32_t n)
{
    while (n--)
        ;
}

int main(void)
{
    while (1) {
        FREQ_REG = 3000000u;  /* 2 Hz */
        delay(2000000u);
    }

    return 0; /* unreachable */
}
