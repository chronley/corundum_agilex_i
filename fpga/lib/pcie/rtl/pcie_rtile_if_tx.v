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
 * R-Tile PCIe interface adapter (transmit)
 */
module pcie_rtile_if_tx #
(
    // R-Tile AVST segment count (fixed at 4 for this adapter)
    parameter SEG_COUNT = 4,
    // R-Tile AVST segment data width
    parameter SEG_DATA_WIDTH = 256,
    // R-Tile AVST segment header width
    parameter SEG_HDR_WIDTH = 128,
    // R-Tile AVST segment TLP prefix width
    parameter SEG_PRFX_WIDTH = 32,
    // TLP data width
    parameter TLP_DATA_WIDTH = SEG_COUNT*SEG_DATA_WIDTH,
    // TLP strobe width
    parameter TLP_STRB_WIDTH = TLP_DATA_WIDTH/32,
    // TLP header width
    parameter TLP_HDR_WIDTH = 128,
    // TLP segment count
    parameter TLP_SEG_COUNT = 1,
    // TX sequence number width
    parameter TX_SEQ_NUM_WIDTH = 6,
    // Maximum payload size (3-bit PCIe encoded value)
    parameter MAX_PAYLOAD_SIZE = 3'd2
)
(
    input  wire                                       clk,
    input  wire                                       rst,

    /*
     * R-Tile TX AVST interface (per-segment signal ports)
     */
    // Segment 0
    output wire [SEG_DATA_WIDTH-1:0]         p0_tx_st0_data_o,
    output wire [SEG_HDR_WIDTH-1:0]          p0_tx_st0_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]         p0_tx_st0_prefix_o,
    output wire                              p0_tx_st0_sop_o,
    output wire                              p0_tx_st0_eop_o,
    output wire                              p0_tx_st0_dvalid_o,
    output wire                              p0_tx_st0_hvalid_o,
    output wire                              p0_tx_st0_pvalid_o,
    // Segment 1
    output wire [SEG_DATA_WIDTH-1:0]         p0_tx_st1_data_o,
    output wire [SEG_HDR_WIDTH-1:0]          p0_tx_st1_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]         p0_tx_st1_prefix_o,
    output wire                              p0_tx_st1_sop_o,
    output wire                              p0_tx_st1_eop_o,
    output wire                              p0_tx_st1_dvalid_o,
    output wire                              p0_tx_st1_hvalid_o,
    output wire                              p0_tx_st1_pvalid_o,
    // Segment 2
    output wire [SEG_DATA_WIDTH-1:0]         p0_tx_st2_data_o,
    output wire [SEG_HDR_WIDTH-1:0]          p0_tx_st2_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]         p0_tx_st2_prefix_o,
    output wire                              p0_tx_st2_sop_o,
    output wire                              p0_tx_st2_eop_o,
    output wire                              p0_tx_st2_dvalid_o,
    output wire                              p0_tx_st2_hvalid_o,
    output wire                              p0_tx_st2_pvalid_o,
    // Segment 3
    output wire [SEG_DATA_WIDTH-1:0]         p0_tx_st3_data_o,
    output wire [SEG_HDR_WIDTH-1:0]          p0_tx_st3_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]         p0_tx_st3_prefix_o,
    output wire                              p0_tx_st3_sop_o,
    output wire                              p0_tx_st3_eop_o,
    output wire                              p0_tx_st3_dvalid_o,
    output wire                              p0_tx_st3_hvalid_o,
    output wire                              p0_tx_st3_pvalid_o,
    input  wire                              p0_tx_st_ready_i,

    /*
     * R-Tile TX AVST credit interface
     */
    input  wire [2:0]                        p0_tx_st_hcrdt_init_i,
    input  wire [2:0]                        p0_tx_st_hcrdt_update_i,
    input  wire [5:0]                        p0_tx_st_hcrdt_update_cnt_i,
    output wire [2:0]                        p0_tx_st_hcrdt_init_ack_o,
    input  wire [2:0]                        p0_tx_st_dcrdt_init_i,
    input  wire [2:0]                        p0_tx_st_dcrdt_update_i,
    input  wire [11:0]                       p0_tx_st_dcrdt_update_cnt_i,
    output wire [2:0]                        p0_tx_st_dcrdt_init_ack_o,

    /*
     * TLP input (read request from DMA)
     */
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]     tx_rd_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]  tx_rd_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_rd_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_rd_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_rd_req_tlp_eop,
    output wire                                       tx_rd_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA read request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]      m_axis_rd_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                       m_axis_rd_req_tx_seq_num_valid,

    /*
     * TLP input (write request from DMA)
     */
    input  wire [TLP_DATA_WIDTH-1:0]                  tx_wr_req_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                  tx_wr_req_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]     tx_wr_req_tlp_hdr,
    input  wire [TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]  tx_wr_req_tlp_seq,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_wr_req_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_wr_req_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_wr_req_tlp_eop,
    output wire                                       tx_wr_req_tlp_ready,

    /*
     * Transmit sequence number output (DMA write request)
     */
    output wire [SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0]      m_axis_wr_req_tx_seq_num,
    output wire [SEG_COUNT-1:0]                       m_axis_wr_req_tx_seq_num_valid,

    /*
     * TLP input (completion from BAR)
     */
    input  wire [TLP_DATA_WIDTH-1:0]                  tx_cpl_tlp_data,
    input  wire [TLP_STRB_WIDTH-1:0]                  tx_cpl_tlp_strb,
    input  wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]     tx_cpl_tlp_hdr,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_cpl_tlp_valid,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_cpl_tlp_sop,
    input  wire [TLP_SEG_COUNT-1:0]                   tx_cpl_tlp_eop,
    output wire                                       tx_cpl_tlp_ready,

    /*
     * TLP input (write request from MSI)
     */
    input  wire [31:0]                                tx_msi_wr_req_tlp_data,
    input  wire                                       tx_msi_wr_req_tlp_strb,
    input  wire [TLP_HDR_WIDTH-1:0]                   tx_msi_wr_req_tlp_hdr,
    input  wire                                       tx_msi_wr_req_tlp_valid,
    input  wire                                       tx_msi_wr_req_tlp_sop,
    input  wire                                       tx_msi_wr_req_tlp_eop,
    output wire                                       tx_msi_wr_req_tlp_ready
);
parameter SEG_STRB_WIDTH = SEG_DATA_WIDTH/32;

parameter INT_TLP_SEG_COUNT = SEG_COUNT;
parameter INT_TLP_SEG_DATA_WIDTH = TLP_DATA_WIDTH / INT_TLP_SEG_COUNT;
parameter INT_TLP_SEG_STRB_WIDTH = TLP_STRB_WIDTH / INT_TLP_SEG_COUNT;

parameter SEG_SEL_WIDTH = $clog2(INT_TLP_SEG_COUNT);

parameter PORTS = 4;
parameter CL_PORTS = $clog2(PORTS);

// bus width assertions
initial begin
    if (SEG_COUNT != 4) begin
        $error("Error: SEG_COUNT must be 4 for R-Tile TX adapter (instance %m)");
        $finish;
    end

    if (SEG_HDR_WIDTH != 128) begin
        $error("Error: segment header width must be 128 (instance %m)");
        $finish;
    end

    if (SEG_PRFX_WIDTH != 32) begin
        $error("Error: segment TLP prefix width must be 32 (instance %m)");
        $finish;
    end

    if (TLP_DATA_WIDTH != SEG_COUNT*SEG_DATA_WIDTH) begin
        $error("Error: Interface widths must match (instance %m)");
        $finish;
    end

    if (TLP_HDR_WIDTH != 128) begin
        $error("Error: TLP segment header width must be 128 (instance %m)");
        $finish;
    end
end

reg [SEG_COUNT*SEG_DATA_WIDTH-1:0] tx_st_data_reg = 0, tx_st_data_next;
reg [SEG_COUNT-1:0] tx_st_sop_reg = 0, tx_st_sop_next;
reg [SEG_COUNT-1:0] tx_st_eop_reg = 0, tx_st_eop_next;
reg [SEG_COUNT-1:0] tx_st_valid_reg = 0, tx_st_valid_next;
reg [SEG_COUNT*SEG_HDR_WIDTH-1:0] tx_st_hdr_reg = 0, tx_st_hdr_next;

reg [1:0] tx_st_ready_delay_reg = 0;

wire [PORTS*TLP_DATA_WIDTH-1:0] mux_in_tlp_data;
wire [PORTS*TLP_STRB_WIDTH-1:0] mux_in_tlp_strb;
wire [PORTS*TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] mux_in_tlp_hdr;
wire [PORTS*TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0] mux_in_tlp_seq;
wire [PORTS*TLP_SEG_COUNT-1:0] mux_in_tlp_valid;
wire [PORTS*TLP_SEG_COUNT-1:0] mux_in_tlp_sop;
wire [PORTS*TLP_SEG_COUNT-1:0] mux_in_tlp_eop;
wire [PORTS-1:0] mux_in_tlp_ready;

wire [TLP_DATA_WIDTH-1:0] mux_out_tlp_data;
wire [TLP_STRB_WIDTH-1:0] mux_out_tlp_strb;
wire [INT_TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0] mux_out_tlp_hdr;
wire [INT_TLP_SEG_COUNT-1:0] mux_out_tlp_valid;
wire [INT_TLP_SEG_COUNT-1:0] mux_out_tlp_sop;
wire [INT_TLP_SEG_COUNT-1:0] mux_out_tlp_eop;
reg mux_out_tlp_ready_cmb;

wire [PORTS-1:0] mux_pause;

wire [PORTS*INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH-1:0] mux_out_sel_tlp_seq;
wire [PORTS*INT_TLP_SEG_COUNT-1:0] mux_out_sel_tlp_seq_valid;

wire [3:0] mux_tx_fc_ph;
wire [8:0] mux_tx_fc_pd;
wire [3:0] mux_tx_fc_nph;
wire [8:0] mux_tx_fc_npd;
wire [3:0] mux_tx_fc_cplh;
wire [8:0] mux_tx_fc_cpld;

wire [11:0] tx_fc_ph_av;
wire [15:0] tx_fc_pd_av;
wire [11:0] tx_fc_nph_av;
wire [15:0] tx_fc_npd_av;
wire [11:0] tx_fc_cplh_av;
wire [15:0] tx_fc_cpld_av;

wire tx_fc_ph_infinite;
wire tx_fc_pd_infinite;
wire tx_fc_nph_infinite;
wire tx_fc_npd_infinite;
wire tx_fc_cplh_infinite;
wire tx_fc_cpld_infinite;

reg [8:0] max_payload_size_fc_reg = 9'd0;
reg have_p_credit_reg = 1'b0;
reg have_np_credit_reg = 1'b0;
reg have_cpl_credit_reg = 1'b0;

// R-Tile TX flow control credit counters
pcie_rtile_fc_counter #(
    .WIDTH(12),
    .CNT_WIDTH(2)
)
fc_counter_ph (
    .clk(clk),
    .rst(rst),
    .crdt_init(p0_tx_st_hcrdt_init_i[0]),
    .crdt_update(p0_tx_st_hcrdt_update_i[0]),
    .crdt_update_cnt(p0_tx_st_hcrdt_update_cnt_i[1:0]),
    .fc_dec(mux_tx_fc_ph),
    .crdt_init_ack(p0_tx_st_hcrdt_init_ack_o[0]),
    .fc_av(tx_fc_ph_av),
    .credit_infinite(tx_fc_ph_infinite)
);

pcie_rtile_fc_counter #(
    .WIDTH(12),
    .CNT_WIDTH(2)
)
fc_counter_nph (
    .clk(clk),
    .rst(rst),
    .crdt_init(p0_tx_st_hcrdt_init_i[1]),
    .crdt_update(p0_tx_st_hcrdt_update_i[1]),
    .crdt_update_cnt(p0_tx_st_hcrdt_update_cnt_i[3:2]),
    .fc_dec(mux_tx_fc_nph),
    .crdt_init_ack(p0_tx_st_hcrdt_init_ack_o[1]),
    .fc_av(tx_fc_nph_av),
    .credit_infinite(tx_fc_nph_infinite)
);

pcie_rtile_fc_counter #(
    .WIDTH(12),
    .CNT_WIDTH(2)
)
fc_counter_cplh (
    .clk(clk),
    .rst(rst),
    .crdt_init(p0_tx_st_hcrdt_init_i[2]),
    .crdt_update(p0_tx_st_hcrdt_update_i[2]),
    .crdt_update_cnt(p0_tx_st_hcrdt_update_cnt_i[5:4]),
    .fc_dec(mux_tx_fc_cplh),
    .crdt_init_ack(p0_tx_st_hcrdt_init_ack_o[2]),
    .fc_av(tx_fc_cplh_av),
    .credit_infinite(tx_fc_cplh_infinite)
);

pcie_rtile_fc_counter #(
    .WIDTH(16),
    .CNT_WIDTH(4)
)
fc_counter_pd (
    .clk(clk),
    .rst(rst),
    .crdt_init(p0_tx_st_dcrdt_init_i[0]),
    .crdt_update(p0_tx_st_dcrdt_update_i[0]),
    .crdt_update_cnt(p0_tx_st_dcrdt_update_cnt_i[3:0]),
    .fc_dec(mux_tx_fc_pd),
    .crdt_init_ack(p0_tx_st_dcrdt_init_ack_o[0]),
    .fc_av(tx_fc_pd_av),
    .credit_infinite(tx_fc_pd_infinite)
);

pcie_rtile_fc_counter #(
    .WIDTH(16),
    .CNT_WIDTH(4)
)
fc_counter_npd (
    .clk(clk),
    .rst(rst),
    .crdt_init(p0_tx_st_dcrdt_init_i[1]),
    .crdt_update(p0_tx_st_dcrdt_update_i[1]),
    .crdt_update_cnt(p0_tx_st_dcrdt_update_cnt_i[7:4]),
    .fc_dec(mux_tx_fc_npd),
    .crdt_init_ack(p0_tx_st_dcrdt_init_ack_o[1]),
    .fc_av(tx_fc_npd_av),
    .credit_infinite(tx_fc_npd_infinite)
);

pcie_rtile_fc_counter #(
    .WIDTH(16),
    .CNT_WIDTH(4)
)
fc_counter_cpld (
    .clk(clk),
    .rst(rst),
    .crdt_init(p0_tx_st_dcrdt_init_i[2]),
    .crdt_update(p0_tx_st_dcrdt_update_i[2]),
    .crdt_update_cnt(p0_tx_st_dcrdt_update_cnt_i[11:8]),
    .fc_dec(mux_tx_fc_cpld),
    .crdt_init_ack(p0_tx_st_dcrdt_init_ack_o[2]),
    .fc_av(tx_fc_cpld_av),
    .credit_infinite(tx_fc_cpld_infinite)
);
assign mux_in_tlp_data[TLP_DATA_WIDTH*0 +: TLP_DATA_WIDTH] = tx_msi_wr_req_tlp_data;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*0 +: TLP_STRB_WIDTH] = tx_msi_wr_req_tlp_strb;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*0 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_msi_wr_req_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*0 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = 0;
assign mux_in_tlp_valid[TLP_SEG_COUNT*0 +: TLP_SEG_COUNT] = tx_msi_wr_req_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*0 +: TLP_SEG_COUNT] = tx_msi_wr_req_tlp_sop;
assign mux_in_tlp_eop[TLP_SEG_COUNT*0 +: TLP_SEG_COUNT] = tx_msi_wr_req_tlp_eop;
assign tx_msi_wr_req_tlp_ready = mux_in_tlp_ready[0 +: 1];

assign mux_pause[0] = !have_p_credit_reg;

assign mux_in_tlp_data[TLP_DATA_WIDTH*1 +: TLP_DATA_WIDTH] = tx_cpl_tlp_data;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*1 +: TLP_STRB_WIDTH] = tx_cpl_tlp_strb;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*1 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_cpl_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*1 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = 0;
assign mux_in_tlp_valid[TLP_SEG_COUNT*1 +: TLP_SEG_COUNT] = tx_cpl_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*1 +: TLP_SEG_COUNT] = tx_cpl_tlp_sop;
assign mux_in_tlp_eop[TLP_SEG_COUNT*1 +: TLP_SEG_COUNT] = tx_cpl_tlp_eop;
assign tx_cpl_tlp_ready = mux_in_tlp_ready[1 +: 1];

assign mux_pause[1] = !have_cpl_credit_reg;

assign mux_in_tlp_data[TLP_DATA_WIDTH*2 +: TLP_DATA_WIDTH] = 0;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*2 +: TLP_STRB_WIDTH] = 0;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*2 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_rd_req_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*2 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = tx_rd_req_tlp_seq;
assign mux_in_tlp_valid[TLP_SEG_COUNT*2 +: TLP_SEG_COUNT] = tx_rd_req_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*2 +: TLP_SEG_COUNT] = {TLP_SEG_COUNT{1'b1}};
assign mux_in_tlp_eop[TLP_SEG_COUNT*2 +: TLP_SEG_COUNT] = {TLP_SEG_COUNT{1'b1}};
assign tx_rd_req_tlp_ready = mux_in_tlp_ready[2 +: 1];

assign mux_pause[2] = !have_np_credit_reg;

assign mux_in_tlp_data[TLP_DATA_WIDTH*3 +: TLP_DATA_WIDTH] = tx_wr_req_tlp_data;
assign mux_in_tlp_strb[TLP_STRB_WIDTH*3 +: TLP_STRB_WIDTH] = tx_wr_req_tlp_strb;
assign mux_in_tlp_hdr[TLP_SEG_COUNT*TLP_HDR_WIDTH*3 +: TLP_SEG_COUNT*TLP_HDR_WIDTH] = tx_wr_req_tlp_hdr;
assign mux_in_tlp_seq[TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*3 +: TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH] = tx_wr_req_tlp_seq;
assign mux_in_tlp_valid[TLP_SEG_COUNT*3 +: TLP_SEG_COUNT] = tx_wr_req_tlp_valid;
assign mux_in_tlp_sop[TLP_SEG_COUNT*3 +: TLP_SEG_COUNT] = tx_wr_req_tlp_sop;
assign mux_in_tlp_eop[TLP_SEG_COUNT*3 +: TLP_SEG_COUNT] = tx_wr_req_tlp_eop;
assign tx_wr_req_tlp_ready = mux_in_tlp_ready[3 +: 1];

assign mux_pause[3] = !have_p_credit_reg;

assign m_axis_rd_req_tx_seq_num = mux_out_sel_tlp_seq[INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*2 +: INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH];
assign m_axis_rd_req_tx_seq_num_valid = mux_out_sel_tlp_seq_valid[INT_TLP_SEG_COUNT*2 +: INT_TLP_SEG_COUNT];
assign m_axis_wr_req_tx_seq_num = mux_out_sel_tlp_seq[INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH*3 +: INT_TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH];
assign m_axis_wr_req_tx_seq_num_valid = mux_out_sel_tlp_seq_valid[INT_TLP_SEG_COUNT*3 +: INT_TLP_SEG_COUNT];

// Unpack the internal segment bus to the R-Tile per-segment TX signal ports.
assign p0_tx_st0_data_o = tx_st_data_reg[SEG_DATA_WIDTH*0 +: SEG_DATA_WIDTH];
assign p0_tx_st1_data_o = tx_st_data_reg[SEG_DATA_WIDTH*1 +: SEG_DATA_WIDTH];
assign p0_tx_st2_data_o = tx_st_data_reg[SEG_DATA_WIDTH*2 +: SEG_DATA_WIDTH];
assign p0_tx_st3_data_o = tx_st_data_reg[SEG_DATA_WIDTH*3 +: SEG_DATA_WIDTH];

assign p0_tx_st0_hdr_o = tx_st_hdr_reg[SEG_HDR_WIDTH*0 +: SEG_HDR_WIDTH];
assign p0_tx_st1_hdr_o = tx_st_hdr_reg[SEG_HDR_WIDTH*1 +: SEG_HDR_WIDTH];
assign p0_tx_st2_hdr_o = tx_st_hdr_reg[SEG_HDR_WIDTH*2 +: SEG_HDR_WIDTH];
assign p0_tx_st3_hdr_o = tx_st_hdr_reg[SEG_HDR_WIDTH*3 +: SEG_HDR_WIDTH];

assign p0_tx_st0_prefix_o = {SEG_PRFX_WIDTH{1'b0}};
assign p0_tx_st1_prefix_o = {SEG_PRFX_WIDTH{1'b0}};
assign p0_tx_st2_prefix_o = {SEG_PRFX_WIDTH{1'b0}};
assign p0_tx_st3_prefix_o = {SEG_PRFX_WIDTH{1'b0}};

assign p0_tx_st0_sop_o = tx_st_sop_reg[0];
assign p0_tx_st1_sop_o = tx_st_sop_reg[1];
assign p0_tx_st2_sop_o = tx_st_sop_reg[2];
assign p0_tx_st3_sop_o = tx_st_sop_reg[3];

assign p0_tx_st0_eop_o = tx_st_eop_reg[0];
assign p0_tx_st1_eop_o = tx_st_eop_reg[1];
assign p0_tx_st2_eop_o = tx_st_eop_reg[2];
assign p0_tx_st3_eop_o = tx_st_eop_reg[3];

assign p0_tx_st0_dvalid_o = tx_st_valid_reg[0];
assign p0_tx_st1_dvalid_o = tx_st_valid_reg[1];
assign p0_tx_st2_dvalid_o = tx_st_valid_reg[2];
assign p0_tx_st3_dvalid_o = tx_st_valid_reg[3];

// Header is valid on the SOP segment; no TLP prefix is ever transmitted.
assign p0_tx_st0_hvalid_o = tx_st_sop_reg[0];
assign p0_tx_st1_hvalid_o = tx_st_sop_reg[1];
assign p0_tx_st2_hvalid_o = tx_st_sop_reg[2];
assign p0_tx_st3_hvalid_o = tx_st_sop_reg[3];

assign p0_tx_st0_pvalid_o = 1'b0;
assign p0_tx_st1_pvalid_o = 1'b0;
assign p0_tx_st2_pvalid_o = 1'b0;
assign p0_tx_st3_pvalid_o = 1'b0;
pcie_tlp_fifo_mux #(
    .PORTS(PORTS),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .IN_TLP_SEG_COUNT(TLP_SEG_COUNT),
    .OUT_TLP_SEG_COUNT(INT_TLP_SEG_COUNT),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(1),
    .FIFO_DEPTH((1024/4)*2)
)
pcie_tlp_fifo_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * TLP input
     */
    .in_tlp_data(mux_in_tlp_data),
    .in_tlp_strb(mux_in_tlp_strb),
    .in_tlp_hdr(mux_in_tlp_hdr),
    .in_tlp_seq(mux_in_tlp_seq),
    .in_tlp_bar_id(0),
    .in_tlp_func_num(0),
    .in_tlp_error(0),
    .in_tlp_valid(mux_in_tlp_valid),
    .in_tlp_sop(mux_in_tlp_sop),
    .in_tlp_eop(mux_in_tlp_eop),
    .in_tlp_ready(mux_in_tlp_ready),

    /*
     * TLP output
     */
    .out_tlp_data(mux_out_tlp_data),
    .out_tlp_strb(mux_out_tlp_strb),
    .out_tlp_hdr(mux_out_tlp_hdr),
    .out_tlp_seq(),
    .out_tlp_bar_id(),
    .out_tlp_func_num(),
    .out_tlp_error(),
    .out_tlp_valid(mux_out_tlp_valid),
    .out_tlp_sop(mux_out_tlp_sop),
    .out_tlp_eop(mux_out_tlp_eop),
    .out_tlp_ready(mux_out_tlp_ready_cmb),

    /*
     * Flow control count output
     */
    .out_fc_ph(mux_tx_fc_ph),
    .out_fc_pd(mux_tx_fc_pd),
    .out_fc_nph(mux_tx_fc_nph),
    .out_fc_npd(mux_tx_fc_npd),
    .out_fc_cplh(mux_tx_fc_cplh),
    .out_fc_cpld(mux_tx_fc_cpld),

    /*
     * Control
     */
    .pause(mux_pause),

    /*
     * Status
     */
    .sel_tlp_seq(mux_out_sel_tlp_seq),
    .sel_tlp_seq_valid(mux_out_sel_tlp_seq_valid),
    .fifo_half_full(),
    .fifo_watermark()
);

always @* begin
    mux_out_tlp_ready_cmb = 1'b0;

    tx_st_data_next = 0;
    tx_st_sop_next = 0;
    tx_st_eop_next = 0;
    tx_st_valid_next = 0;
    tx_st_hdr_next = 0;

    if (tx_st_ready_delay_reg[1]) begin
        mux_out_tlp_ready_cmb = 1'b1;

        tx_st_data_next = mux_out_tlp_data;
        tx_st_valid_next = mux_out_tlp_valid;
        tx_st_sop_next = mux_out_tlp_sop;
        tx_st_eop_next = mux_out_tlp_eop;
        tx_st_hdr_next = mux_out_tlp_hdr;
    end
end

always @(posedge clk) begin
    tx_st_data_reg <= tx_st_data_next;
    tx_st_sop_reg <= tx_st_sop_next;
    tx_st_eop_reg <= tx_st_eop_next;
    tx_st_valid_reg <= tx_st_valid_next;
    tx_st_hdr_reg <= tx_st_hdr_next;

    tx_st_ready_delay_reg <= {tx_st_ready_delay_reg, p0_tx_st_ready_i};

    max_payload_size_fc_reg <= 9'd8 << (MAX_PAYLOAD_SIZE > 5 ? 5 : MAX_PAYLOAD_SIZE);
    have_p_credit_reg <= (tx_fc_ph_infinite || tx_fc_ph_av > 4) && (tx_fc_pd_infinite || tx_fc_pd_av > (max_payload_size_fc_reg << 1));
    have_np_credit_reg <= tx_fc_nph_infinite || tx_fc_nph_av > 4;
    have_cpl_credit_reg <= (tx_fc_cplh_infinite || tx_fc_cplh_av > 4) && (tx_fc_cpld_infinite || tx_fc_cpld_av > (max_payload_size_fc_reg << 1));

    if (rst) begin
        tx_st_valid_reg <= 0;
        tx_st_ready_delay_reg <= 0;
    end
end

endmodule

`resetall

