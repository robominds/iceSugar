# iCESugar-nano LED Blink with PicoRV32

Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)

A minimal RISC-V SoC for the [iCESugar-nano](https://github.com/wuxx/icesugar-nano) FPGA board.
The FPGA implements a PicoRV32 soft-core that runs C firmware. The firmware cycles through five
LED blink frequencies by writing to a memory-mapped register; the FPGA's LED controller toggles
pin B6 at the requested rate.

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
│  PicoRV32 (RV32I minimal, ~800-1000 LUTs)   │
│    executes firmware from BRAM              │
│    writes half-period to freq_reg           │
│                                             │
│  LED Blink Controller                       │
│    32-bit counter vs freq_reg               │
│    toggles LED on match → pin B6            │
│                                             │
│  Memory map:                                │
│    0x00000000–0x00001FFF  BRAM (8 KB)       │
│    0x10000000             LED freq register │
└─────────────────────────────────────────────┘
```

### Blink frequencies

The firmware cycles through these rates (~2 s between each change):

| freq_reg value | Half-period | Rate |
|----------------|-------------|------|
| 6 000 000 | 500 ms | 1 Hz |
| 3 000 000 | 250 ms | 2 Hz |
| 1 500 000 | 125 ms | 4 Hz |
| 750 000 | 62.5 ms | 8 Hz |
| 375 000 | 31.25 ms | 16 Hz |

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
│   ├── picorv32.v             # PicoRV32 RISC-V core (ISC licence, YosysHQ)
│   └── soc.v                  # CPU + BRAM + LED controller + memory decode
└── sw/
    ├── Makefile               # firmware build
    ├── start.S                # startup: set sp, zero BSS, call main
    ├── link.ld                # linker script: 8 KB BRAM at 0x0
    └── main.c                 # frequency cycling loop
```

## LUT budget note

The iCE40LP1K has only 1 280 LUTs. PicoRV32 is configured with non-essential features
disabled (no barrel shifter, no counters, no MUL/DIV, no IRQ) to stay within budget.
After synthesis, check `build/synth.log` for the `ICESTORM_LC` count — it must be < 1 280.

If synthesis fails due to LUT overflow:
1. Disable registers 16–31: add `.ENABLE_REGS_16_31(0)` in `rtl/soc.v` and
   recompile firmware with `-march=rv32e -mabi=ilp32e`.
2. Switch to FemtoRV32 Quark (proven to fit iCE40LP1K IceStick in ~980 LUTs).

## Licence

Project source files: MIT
`rtl/picorv32.v`: ISC licence — Copyright (C) 2015 Claire Xenia Wolf
