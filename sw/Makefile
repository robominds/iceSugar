# sw/Makefile - Firmware build for PicoRV32 on iCESugar-nano
# Authors: Mark Castelluccio; AI-assisted (Claude claude-sonnet-4-6, Anthropic)
#
# Toolchain: riscv64-elf-gcc from "brew install riscv64-elf-gcc"
# Override prefix: make RISCV_PREFIX=riscv32-unknown-elf-

RISCV_PREFIX ?= riscv64-elf-
CC      := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump
SIZE    := $(RISCV_PREFIX)size

ARCH    := -march=rv32i -mabi=ilp32
CFLAGS  := $(ARCH) -O2 -Wall -Wextra -ffreestanding -nostdlib -fno-builtin
LDFLAGS := $(ARCH) -nostdlib -Wl,-T,link.ld -Wl,--no-relax

SRCS    := start.S main.c
ELF     := firmware.elf
BIN     := firmware.bin
HEX     := ../build/firmware.hex

.PHONY: all clean disasm

all: $(HEX)

# Step 1: Link ELF
$(ELF): $(SRCS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)

# Step 2: Flat binary from ELF
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

# Step 3: Convert flat binary to $readmemh-compatible word-per-line hex.
# Using binary → Python is more reliable than objcopy -O verilog whose
# @address format varies by binutils version.
$(HEX): $(BIN)
	@mkdir -p ../build
	python3 -c "
import sys
data = open('$(BIN)', 'rb').read()
# Pad to 4-byte boundary
data += b'\x00' * ((4 - len(data) % 4) % 4)
for i in range(0, len(data), 4):
    word = int.from_bytes(data[i:i+4], 'little')
    print(f'{word:08x}')
" > $@
	@echo "Firmware hex written to $(HEX)"
	$(SIZE) $(ELF)

disasm: $(ELF)
	$(OBJDUMP) -d -M no-aliases $<

clean:
	rm -f $(ELF) $(BIN)
