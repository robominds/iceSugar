/* main.c - LED frequency cycling firmware for PicoRV32 SoC
 * Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)
 *
 * Writes half-period values (in 12 MHz clock cycles) to the memory-mapped
 * LED frequency register. The FPGA toggles the LED every freq_reg cycles,
 * producing a square wave at the chosen frequency.
 *
 * Frequency table (half-period → full blink rate):
 *   6 000 000 cycles = 500 ms half-period → 1 Hz
 *   3 000 000 cycles = 250 ms half-period → 2 Hz
 *   1 500 000 cycles = 125 ms half-period → 4 Hz
 *     750 000 cycles =  62.5 ms half-period → 8 Hz
 *     375 000 cycles =  31.25 ms half-period → 16 Hz
 *
 * The firmware cycles through all five rates with ~2 s between changes.
 */

#include <stdint.h>

/* Memory-mapped LED frequency register (write-only, in FPGA) */
#define FREQ_REG (*(volatile uint32_t *)0x10000000u)

/*
 * Busy-wait delay. At 12 MHz with ~4 CPI average for PicoRV32,
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
    static const uint32_t freqs[] = {
        6000000u,  /* 1 Hz  — very slow */
        3000000u,  /* 2 Hz  — slow      */
        1500000u,  /* 4 Hz  — medium    */
         750000u,  /* 8 Hz  — fast      */
         375000u,  /* 16 Hz — very fast */
    };

    uint32_t i = 0;

    while (1) {
        FREQ_REG = freqs[i];
        i = (i + 1u) % 5u;
        delay(2000000u);
    }

    return 0; /* unreachable */
}
