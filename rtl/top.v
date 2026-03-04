// top.v - iCESugar-nano LED blink top level
// Authors: Mark Castelluccio; AI-assisted design (Claude claude-sonnet-4-6, Anthropic)
// Board: iCESugar-nano, iCE40LP1K-CM36
// Clock: 12 MHz from iCELink MCO on pin D1
// LED:   Yellow LED on pin B6 (active high)

`default_nettype none
`timescale 1ns/1ps

module top (
    input  wire clk,  // 12 MHz from iCELink on D1
    output wire led   // Yellow LED on B6
);

    soc u_soc (
        .clk (clk),
        .led (led)
    );

endmodule
