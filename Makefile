# Makefile - iCESugar-nano PicoRV32 LED blink project
# Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)
#
# Targets:
#   make          - build everything: firmware → synth → pnr → pack
#   make flash    - program the board via openFPGALoader
#   make disasm   - disassemble firmware ELF
#   make clean    - remove build directory and firmware objects
#
# Tool prerequisites (macOS):
#   brew install yosys nextpnr icestorm
#   brew install riscv64-elf-binutils riscv64-elf-gcc
#   brew install openfpgaloader

BUILD   := build
PCF     := constraints/icesugar_nano.pcf
RTL     := rtl/top.v rtl/soc.v rtl/femtorv32_quark.v

# iCE40LP1K in CM36 (36-ball BGA) package, 12 MHz clock
DEVICE  := lp1k
PACKAGE := cm36
FREQ    := 12

.PHONY: all firmware synth pnr pack flash disasm clean

all: $(BUILD)/top.bin

# ── Firmware ─────────────────────────────────────────────────────────────────
firmware: $(BUILD)/firmware.hex

$(BUILD)/firmware.hex:
	@mkdir -p $(BUILD)
	$(MAKE) -C sw all

# ── Synthesis (Yosys) ─────────────────────────────────────────────────────────
# synth_ice40 maps the design to iCE40 primitives.
# -top top : root module name matches rtl/top.v
# -json    : output JSON netlist consumed by nextpnr
synth: $(BUILD)/top.json

$(BUILD)/top.json: $(BUILD)/firmware.hex $(RTL)
	yosys \
	    -p "synth_ice40 -top top -json $(BUILD)/top.json" \
	    -l $(BUILD)/synth.log \
	    $(RTL)
	@echo ""
	@echo "=== LUT utilisation ==="
	@grep -E "ICESTORM_LC|SB_LUT4" $(BUILD)/synth.log | tail -5 || true

# ── Place and Route (nextpnr-ice40) ───────────────────────────────────────────
# --lp1k       : iCE40LP1K device family
# --package cm36 : 36-ball BGA package on iCESugar-nano
# --freq 12    : 12 MHz timing constraint (fail if unachievable)
pnr: $(BUILD)/top.asc

$(BUILD)/top.asc: $(BUILD)/top.json $(PCF)
	nextpnr-ice40 \
	    --$(DEVICE) \
	    --package $(PACKAGE) \
	    --json $(BUILD)/top.json \
	    --pcf $(PCF) \
	    --asc $(BUILD)/top.asc \
	    --freq $(FREQ) \
	    --log $(BUILD)/pnr.log
	@echo ""
	@echo "=== Timing summary ==="
	@grep -i "max frequency\|timing" $(BUILD)/pnr.log | head -5 || true

# ── Bitstream packing (icepack) ───────────────────────────────────────────────
pack: $(BUILD)/top.bin

$(BUILD)/top.bin: $(BUILD)/top.asc
	icepack $(BUILD)/top.asc $(BUILD)/top.bin
	@echo ""
	@echo "Bitstream: $(BUILD)/top.bin ($$(wc -c < $(BUILD)/top.bin) bytes)"

# ── Flash ─────────────────────────────────────────────────────────────────────
# Primary: openFPGALoader (supports iCE40 via CMSIS-DAP / iCELink)
# Fallback: drag-and-drop — copy build/top.bin to the iCELink USB mass storage
flash: $(BUILD)/top.bin
	openFPGALoader -b ice40_generic $(BUILD)/top.bin || \
	openFPGALoader $(BUILD)/top.bin || \
	{ echo ""; \
	  echo "openFPGALoader failed. Manual fallback:"; \
	  echo "  cp $(BUILD)/top.bin /Volumes/iCELink/"; \
	}

# ── Utilities ─────────────────────────────────────────────────────────────────
disasm:
	$(MAKE) -C sw disasm

clean:
	rm -rf $(BUILD)
	$(MAKE) -C sw clean
