/*

Copyright (c) 2022 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * R-Tile PCIe flow control credit counter
 *
 * Tracks the number of available credits for a single credit type using the
 * R-Tile Avalon-ST credit init/update handshake.  During the init phase the
 * sink advertises its buffer size (one or more update cycles); after init the
 * counter is incremented on every update pulse and decremented by fc_dec.
 */
module pcie_rtile_fc_counter #
(
    // Accumulator width
    parameter WIDTH = 12,
    // Credit update count field width (2 for header, 4 for data)
    parameter CNT_WIDTH = 2
)
(
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  crdt_init,
    input  wire                  crdt_update,
    input  wire [CNT_WIDTH-1:0]  crdt_update_cnt,
    input  wire [WIDTH-1:0]      fc_dec,

    output wire                  crdt_init_ack,
    output wire [WIDTH-1:0]      fc_av,
    output wire                  credit_infinite
);

wire [WIDTH-1:0] fc_inc = crdt_update ? {{WIDTH-CNT_WIDTH{1'b0}}, crdt_update_cnt} : {WIDTH{1'b0}};

reg [WIDTH-1:0] fc_cap_reg = 0;
reg [WIDTH-1:0] fc_av_reg = 0;
reg credit_infinite_reg = 1'b0;

assign fc_av = fc_av_reg;
assign credit_infinite = credit_infinite_reg;
assign crdt_init_ack = crdt_init;

always @(posedge clk) begin
    if (rst) begin
        fc_cap_reg <= 0;
        fc_av_reg <= 0;
        credit_infinite_reg <= 1'b0;
    end else if (crdt_init) begin
        // Initialization phase: accumulate the advertised buffer size.
        if (crdt_update) begin
            if (crdt_update_cnt == 0) begin
                // A zero count during init advertises infinite credits.
                credit_infinite_reg <= 1'b1;
                fc_cap_reg <= 0;
                fc_av_reg <= 0;
            end else begin
                fc_cap_reg <= fc_cap_reg + crdt_update_cnt;
                fc_av_reg <= fc_av_reg + crdt_update_cnt;
            end
        end
    end else begin
        // Normal operation: increment on update, decrement on transmit.
        if (credit_infinite_reg) begin
            fc_av_reg <= 0;
        end else if ($signed({1'b0, fc_av_reg}) - $signed({1'b0, fc_dec}) + $signed({1'b0, fc_inc}) < 0) begin
            fc_av_reg <= 0;
        end else if ($signed({1'b0, fc_av_reg}) + $signed({1'b0, fc_inc}) > fc_cap_reg) begin
            fc_av_reg <= fc_cap_reg;
        end else begin
            fc_av_reg <= fc_av_reg - fc_dec + fc_inc;
        end
    end
end

endmodule

`resetall
