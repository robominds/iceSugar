// soc.v - PicoRV32 SoC with BRAM and LED blink controller
// Authors: Mark Castelluccio; AI-assisted design (Claude claude-sonnet-4-6, Anthropic)
//
// Memory map:
//   0x00000000 - 0x00001FFF : BRAM (8 KB = 2048 x 32-bit words)
//   0x10000000              : LED frequency register (write-only)
//
// LED toggle frequency = 12 MHz / freq_reg  (half-period in clock cycles)
//   freq_reg = 6000000 → 1 Hz blink
//   freq_reg =  375000 → 16 Hz blink

`default_nettype none

module soc (
    input  wire clk,
    output reg  led
);

    // -----------------------------------------------------------------------
    // PicoRV32 memory interface signals
    // -----------------------------------------------------------------------
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata;

    // -----------------------------------------------------------------------
    // PicoRV32 CPU — minimal RV32I configuration (~800-1000 LUTs on iCE40)
    //
    // Key savings vs default:
    //   BARREL_SHIFTER=0    : ~240 LUT reduction; shift uses iterative logic
    //   ENABLE_COUNTERS=0   : removes cycle/instret CSRs
    //   CATCH_MISALIGN=0    : removes alignment fault detection
    //   CATCH_ILLINSN=0     : removes illegal instruction trap
    //   ENABLE_MUL/DIV=0    : no hardware multiply/divide
    //   ENABLE_IRQ=0        : no interrupt support needed
    //
    // STACKADDR initialises x2 (sp) at reset to top of 8 KB BRAM.
    // PROGADDR_RESET=0 starts execution at BRAM address 0 (_start).
    // -----------------------------------------------------------------------
    picorv32 #(
        .ENABLE_COUNTERS     (0),
        .ENABLE_COUNTERS64   (0),
        .ENABLE_REGS_16_31   (1),   // keep full 32-register ABI for C code
        .ENABLE_REGS_DUALPORT(0),   // slight perf hit, saves LUTs
        .TWO_STAGE_SHIFT     (1),
        .BARREL_SHIFTER      (0),   // saves ~240 LUTs; use TWO_STAGE_SHIFT instead
        .TWO_CYCLE_COMPARE   (0),
        .TWO_CYCLE_ALU       (0),
        .COMPRESSED_ISA      (0),
        .CATCH_MISALIGN      (0),
        .CATCH_ILLINSN       (0),
        .ENABLE_PCPI         (0),
        .ENABLE_MUL          (0),
        .ENABLE_FAST_MUL     (0),
        .ENABLE_DIV          (0),
        .ENABLE_IRQ          (0),
        .ENABLE_IRQ_QREGS    (0),
        .ENABLE_IRQ_TIMER    (0),
        .ENABLE_TRACE        (0),
        .STACKADDR           (32'h00002000),  // top of 8 KB BRAM
        .PROGADDR_RESET      (32'h00000000),  // reset vector at BRAM[0]
        .PROGADDR_IRQ        (32'h00000010)   // unused (IRQ disabled)
    ) u_cpu (
        .clk       (clk),
        .resetn    (1'b1),        // no external reset; CPU starts immediately
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata),
        .trap      ()             // unused
    );

    // -----------------------------------------------------------------------
    // BRAM — 2048 x 32-bit = 8 KB
    //
    // Synthesis: Yosys synth_ice40 maps this to iCE40 EBR (block RAM) cells,
    // consuming 0 logic LUTs. The $readmemh path is relative to the directory
    // where `make` is run (project root).
    //
    // BRAM read has 1-cycle registered latency (bram_rdata valid one cycle
    // after the request). mem_ready is asserted the cycle after bram_sel.
    // -----------------------------------------------------------------------
    reg [31:0] bram [0:2047];

    initial begin
        $readmemh("build/firmware.hex", bram);
    end

    // Select BRAM when address is within 0x00000000–0x00001FFF
    wire bram_sel = mem_valid && (mem_addr[31:13] == 19'h0);

    reg [31:0] bram_rdata;
    reg        bram_ready;

    always @(posedge clk) begin
        bram_ready <= 1'b0;
        if (bram_sel && !mem_ready) begin
            bram_rdata <= bram[mem_addr[12:2]];
            if (|mem_wstrb) begin
                if (mem_wstrb[0]) bram[mem_addr[12:2]][ 7: 0] <= mem_wdata[ 7: 0];
                if (mem_wstrb[1]) bram[mem_addr[12:2]][15: 8] <= mem_wdata[15: 8];
                if (mem_wstrb[2]) bram[mem_addr[12:2]][23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) bram[mem_addr[12:2]][31:24] <= mem_wdata[31:24];
            end
            bram_ready <= 1'b1;
        end
    end

    // -----------------------------------------------------------------------
    // LED blink controller
    //
    // freq_reg holds the half-period in 12 MHz clock cycles.
    // The LED toggles every freq_reg cycles, producing a square wave.
    // Default 6000000 = 0.5 s half-period = 1 Hz visible blink.
    //
    // The RISC-V firmware writes new values to 0x10000000 to change the rate.
    // -----------------------------------------------------------------------
    reg [31:0] counter;
    reg [31:0] freq_reg;

    initial begin
        counter  = 32'h0;
        freq_reg = 32'd6000000;  // default: 1 Hz
        led      = 1'b0;
    end

    wire led_sel = mem_valid && (mem_addr == 32'h10000000);

    always @(posedge clk) begin
        // Write from CPU updates freq_reg immediately
        if (led_sel && |mem_wstrb)
            freq_reg <= mem_wdata;

        // Counter drives LED toggle
        if (counter >= freq_reg) begin
            counter <= 32'h0;
            led     <= ~led;
        end else begin
            counter <= counter + 32'h1;
        end
    end

    // -----------------------------------------------------------------------
    // Memory bus arbitration — combinatorial mux of ready/rdata sources
    // -----------------------------------------------------------------------
    always @(*) begin
        mem_ready = 1'b0;
        mem_rdata = 32'h0;

        if (bram_ready) begin
            mem_ready = 1'b1;
            mem_rdata = bram_rdata;
        end else if (led_sel && |mem_wstrb) begin
            // LED register write: single-cycle acknowledgement
            mem_ready = 1'b1;
        end
    end

endmodule
