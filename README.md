# iCESugar-nano LED Blink with FemtoRV32

Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)

A minimal RISC-V SoC for the [iCESugar-nano](https://github.com/wuxx/icesugar-nano) FPGA board.
The FPGA implements a FemtoRV32 Quark soft-core that runs C firmware. The firmware writes a
memory-mapped register to set LED blink frequency; the FPGA's LED controller toggles pin B6.

## Hardware

| Item | Detail |
|------|--------|
| Board | iCESugar-nano |
| FPGA | Lattice iCE40LP1K-CM36 (1 280 LUTs, 8 KB BRAM) |
| Clock | 12 MHz from iCELink MCO (pin D1) |
| LED | Yellow, active-high on pin B6 |
| Programming | USB-C → iCELink (drag-and-drop or `openFPGALoader`) |

## Architecture

```
iCE40LP1K
┌─────────────────────────────────────────────┐
│  FemtoRV32 Quark (RV32I minimal)            │
│    executes firmware from BRAM              │
│    writes half-period to freq_reg           │
│                                             │
│  LED Blink Controller                       │
│    32-bit counter vs freq_reg               │
│    toggles LED on match → pin B6            │
│                                             │
│  Memory map:                                │
│    0x00000000–0x000017FF  BRAM (6 KB)       │
│    0x00001800             LED freq register │
└─────────────────────────────────────────────┘
```

### Blink frequency

Current firmware writes `freq_reg = 3000000`, which gives a 250 ms half-period
at 12 MHz and a 2 Hz LED blink.

## Prerequisites

Install the open-source FPGA toolchain and RISC-V cross-compiler (macOS with Homebrew):

```bash
brew install yosys nextpnr icestorm
brew install riscv64-elf-binutils riscv64-elf-gcc
brew install openfpgaloader
```

> If `icestorm` is not in Homebrew core, use the tap:
> `brew tap cloud-v/icestorm && brew install icestorm`

## Build

```bash
make        # compile firmware, synthesise, P&R, pack → build/top.bin
make flash  # program via openFPGALoader
```

Manual programming alternative — drag `build/top.bin` onto the **iCELink** USB disk that
appears when the board is connected.

## Project structure

```
iceSugar/
├── Makefile                    # top-level build orchestration
├── constraints/
│   └── icesugar_nano.pcf      # pin constraints (B6=LED, D1=CLK)
├── rtl/
│   ├── top.v                  # top-level I/O and SoC instantiation
│   ├── soc.v                  # CPU + BRAM + LED controller + memory decode
│   └── femtorv32_quark.v      # FemtoRV32 Quark CPU core
└── sw/
    ├── Makefile               # firmware build
    ├── start.S                # startup: set sp, zero BSS, call main
    ├── link.ld                # linker script: 6 KB BRAM at 0x0
    └── main.c                 # writes fixed 2 Hz blink setting
```

## LUT budget note

The iCE40LP1K has only 1 280 LUTs. This project uses FemtoRV32 Quark so the design fits
comfortably on LP1K together with BRAM and the LED peripheral.
After synthesis, check `build/synth.log` for `ICESTORM_LC` — it must be < 1 280.

If synthesis fails due to LUT overflow:
1. Keep the build on FemtoRV32 Quark (`rtl/femtorv32_quark.v`).
2. Review `build/synth.log` and `build/pnr.log` for the largest contributors.
3. Reduce BRAM footprint or simplify peripherals if needed.

## FPGA resource usage

Measured from `build/synth.log` (Yosys `synth_ice40`) on 2026-03-04:

| Resource | Used | Device total (iCE40LP1K) | Utilization |
|----------|------|---------------------------|-------------|
| `SB_LUT4` | 993 | 1280 LUT4 / logic cells | 77.6% |
| `SB_RAM40_4K` | 16 | 16 EBR blocks | 100.0% |
| Flip-flops (`SB_DFF*` total) | 231 | 1280 FF slots (one per logic cell) | 18.0% |

Notes:
1. BRAM is fully utilized by the 6 KB firmware memory implementation and packing granularity.
2. Timing and post-place-and-route utilization are reported by `nextpnr-ice40` in `build/pnr.log` when that tool is available.

## Licence

Project source files: MIT
