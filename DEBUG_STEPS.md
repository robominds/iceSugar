# Debug and Bring-up Steps

Authors: Mark Castelluccio; AI-assisted (GitHub Copilot GPT-5.3-Codex)

Date: 2026-03-04

## Goal
Build, fit, and flash the iCESugar-nano SoC design; then set LED blink to fixed 2 Hz.

## Chronological Steps

1. Ran full build with `make` and identified initial blocker in `sw/Makefile` (`missing separator`).
2. Fixed firmware hex-generation recipe formatting in `sw/Makefile`.
3. Re-ran build; found missing host toolchain binaries (`riscv64-elf-*`, `yosys`, `nextpnr-ice40`, `icepack`, `openFPGALoader`).
4. Installed available dependencies via Homebrew and locally built missing FPGA tools (`icestorm`, `nextpnr-ice40`) into `.tools/local/bin`.
5. Re-ran build; fixed firmware link issue (`__umodsi3`) by adding `-lgcc`.
6. Applied RV32E reduction attempt:
   - Set PicoRV32 `ENABLE_REGS_16_31=0`.
   - Switched firmware to `-march=rv32e -mabi=ilp32e`.
   - Removed modulo in firmware loop to avoid runtime helper dependency.
7. Measured improvement but still not fitting LP1K LUT budget.
8. Replaced PicoRV32 with FemtoRV32 Quark:
   - Added `rtl/femtorv32_quark.v`.
   - Reworked `rtl/soc.v` bus glue for `mem_rbusy/mem_wbusy` protocol.
   - Updated build RTL file list.
9. Re-ran synthesis/P&R; LUT usage fit, but BRAM overflow occurred (`20/16`).
10. Reduced BRAM footprint from 8 KB to 6 KB and moved LED MMIO address above BRAM:
    - BRAM map: `0x00000000-0x000017FF`
    - LED register: `0x00001800`
    - Updated `rtl/soc.v`, `sw/main.c`, `sw/link.ld`, `sw/start.S`.
11. Rebuilt successfully (`top.json`, `top.asc`, `top.bin` generated; P&R finished normally).
12. Flashed board:
    - `openFPGALoader` path failed due to FTDI device not found on host.
    - Used manual iCELink mass-storage fallback by copying `build/top.bin` to `/Volumes/iCELink/`.
13. Changed blink behavior to fixed 2 Hz:
    - Set default `freq_reg=3000000` in `rtl/soc.v`.
    - Set firmware to write constant `3000000u` in `sw/main.c`.
14. Rebuilt and re-flashed using iCELink copy fallback.

## Final State

- Build: passing (`make` produces bitstream).
- Fit: passing for iCE40LP1K after FemtoRV32 + 6 KB BRAM adjustments.
- Flash: successful via `/Volumes/iCELink/top.bin` copy.
- Blink: fixed 2 Hz.
