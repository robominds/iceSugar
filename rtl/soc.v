// soc.v - FemtoRV32 Quark SoC with BRAM and LED blink controller
// Authors: Mark Castelluccio; AI-assisted design (Claude claude-sonnet-4-6, Anthropic)
//
// Memory map:
//   0x00000000 - 0x000017FF : BRAM (6 KB = 1536 x 32-bit words)
//   0x00001800              : LED frequency register
//
// LED toggle frequency = 12 MHz / freq_reg  (half-period in clock cycles)
//   freq_reg = 3000000 → 2 Hz blink
//   freq_reg =  375000 → 16 Hz blink

`default_nettype none

module soc (
    input  wire clk,
    output reg  led
);

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wmask;
    reg  [31:0] mem_rdata;
    wire        mem_rstrb;
    reg         mem_rbusy;
    reg         mem_wbusy;

    reg cpu_reset;
    initial cpu_reset = 1'b0;
    always @(posedge clk) begin
        cpu_reset <= 1'b1;
    end

    FemtoRV32 #(
        .RESET_ADDR(32'h00000000)
    ) u_cpu (
        .clk      (clk),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .reset    (cpu_reset)
    );

    // -----------------------------------------------------------------------
    // BRAM — 1536 x 32-bit = 6 KB
    //
    // Synthesis: Yosys synth_ice40 maps this to iCE40 EBR (block RAM) cells,
    // consuming 0 logic LUTs. The $readmemh path is relative to the directory
    // where `make` is run (project root).
    //
    // BRAM access is acknowledged using FemtoRV32's mem_rbusy/mem_wbusy
    // handshake. We insert one wait-state for each read/write operation.
    // -----------------------------------------------------------------------
    reg [31:0] bram [0:1535];

    initial begin
        $readmemh("build/firmware.hex", bram);
    end

    wire bram_sel = (mem_addr[31:11] == 21'h0);
    reg  [31:0] bram_rdata;
    reg         read_pending;
    reg         write_pending;
    reg         read_from_bram;
    reg         read_from_led;

    // -----------------------------------------------------------------------
    // LED blink controller
    //
    // freq_reg holds the half-period in 12 MHz clock cycles.
    // The LED toggles every freq_reg cycles, producing a square wave.
    // Default 6000000 = 0.5 s half-period = 1 Hz visible blink.
    //
    // The RISC-V firmware writes new values to 0x00002000 to change the rate.
    // -----------------------------------------------------------------------
    reg [31:0] counter;
    reg [31:0] freq_reg;

    initial begin
        counter  = 32'h0;
        freq_reg = 32'd3000000;  // default: 2 Hz
        led      = 1'b0;
        mem_rdata = 32'h0;
        mem_rbusy = 1'b0;
        mem_wbusy = 1'b0;
        bram_rdata = 32'h0;
        read_pending = 1'b0;
        write_pending = 1'b0;
        read_from_bram = 1'b0;
        read_from_led = 1'b0;
    end

    wire led_sel = (mem_addr == 32'h00001800);

    always @(posedge clk) begin
        mem_rbusy <= read_pending;
        mem_wbusy <= write_pending;

        if (read_pending) begin
            read_pending <= 1'b0;
            mem_rbusy    <= 1'b0;
            if (read_from_bram)
                mem_rdata <= bram_rdata;
            else if (read_from_led)
                mem_rdata <= freq_reg;
            else
                mem_rdata <= 32'h00000000;
        end

        if (write_pending) begin
            write_pending <= 1'b0;
            mem_wbusy     <= 1'b0;
        end

        if (mem_rstrb && !read_pending) begin
            read_pending   <= 1'b1;
            mem_rbusy      <= 1'b1;
            read_from_bram <= bram_sel;
            read_from_led  <= led_sel;
            if (bram_sel)
                bram_rdata <= bram[mem_addr[12:2]];
        end

        if (|mem_wmask && !write_pending) begin
            write_pending <= 1'b1;
            mem_wbusy     <= 1'b1;

            if (bram_sel) begin
                if (mem_wmask[0]) bram[mem_addr[12:2]][ 7: 0] <= mem_wdata[ 7: 0];
                if (mem_wmask[1]) bram[mem_addr[12:2]][15: 8] <= mem_wdata[15: 8];
                if (mem_wmask[2]) bram[mem_addr[12:2]][23:16] <= mem_wdata[23:16];
                if (mem_wmask[3]) bram[mem_addr[12:2]][31:24] <= mem_wdata[31:24];
            end else if (led_sel) begin
                if (mem_wmask[0]) freq_reg[ 7: 0] <= mem_wdata[ 7: 0];
                if (mem_wmask[1]) freq_reg[15: 8] <= mem_wdata[15: 8];
                if (mem_wmask[2]) freq_reg[23:16] <= mem_wdata[23:16];
                if (mem_wmask[3]) freq_reg[31:24] <= mem_wdata[31:24];
            end
        end

        // Counter drives LED toggle
        if (counter >= freq_reg) begin
            counter <= 32'h0;
            led     <= ~led;
        end else begin
            counter <= counter + 32'h1;
        end
    end

endmodule
