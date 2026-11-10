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
 * R-Tile PCIe interface adapter
 */
module pcie_rtile_if #
(
    // R-Tile AVST segment count (fixed at 4 for this adapter)
    parameter SEG_COUNT = 4,
    // R-Tile AVST segment data width
    parameter SEG_DATA_WIDTH = 256,
    // R-Tile AVST segment empty signal width
    parameter SEG_EMPTY_WIDTH = $clog2(SEG_DATA_WIDTH/32),
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
    parameter MAX_PAYLOAD_SIZE = 3'd2,
    // IO bar index
    // rx_st_bar = 6 is mapped to IO_BAR_INDEX on rx_req_tlp_bar_id
    parameter IO_BAR_INDEX = 5
)
(
    input  wire                                    clk,
    input  wire                                    rst,

    /*
     * R-Tile RX AVST interface (per-segment signal ports)
     */
    // Segment 0
    input  wire [SEG_DATA_WIDTH-1:0]               p0_rx_st0_data_i,
    input  wire [SEG_HDR_WIDTH-1:0]                p0_rx_st0_hdr_i,
    input  wire [SEG_PRFX_WIDTH-1:0]               p0_rx_st0_prefix_i,
    input  wire                                    p0_rx_st0_sop_i,
    input  wire                                    p0_rx_st0_eop_i,
    input  wire                                    p0_rx_st0_dvalid_i,
    input  wire                                    p0_rx_st0_hvalid_i,
    input  wire                                    p0_rx_st0_pvalid_i,
    input  wire [2:0]                              p0_rx_st0_bar_i,
    input  wire [SEG_EMPTY_WIDTH-1:0]              p0_rx_st0_empty_i,
    input  wire                                    p0_rx_st0_vfactive_i,
    input  wire [10:0]                             p0_rx_st0_vfnum_i,
    input  wire [2:0]                              p0_rx_st0_pfnum_i,
    // Segment 1
    input  wire [SEG_DATA_WIDTH-1:0]               p0_rx_st1_data_i,
    input  wire [SEG_HDR_WIDTH-1:0]                p0_rx_st1_hdr_i,
    input  wire [SEG_PRFX_WIDTH-1:0]               p0_rx_st1_prefix_i,
    input  wire                                    p0_rx_st1_sop_i,
    input  wire                                    p0_rx_st1_eop_i,
    input  wire                                    p0_rx_st1_dvalid_i,
    input  wire                                    p0_rx_st1_hvalid_i,
    input  wire                                    p0_rx_st1_pvalid_i,
    input  wire [2:0]                              p0_rx_st1_bar_i,
    input  wire [SEG_EMPTY_WIDTH-1:0]              p0_rx_st1_empty_i,
    input  wire                                    p0_rx_st1_vfactive_i,
    input  wire [10:0]                             p0_rx_st1_vfnum_i,
    input  wire [2:0]                              p0_rx_st1_pfnum_i,
    // Segment 2
    input  wire [SEG_DATA_WIDTH-1:0]               p0_rx_st2_data_i,
    input  wire [SEG_HDR_WIDTH-1:0]                p0_rx_st2_hdr_i,
    input  wire [SEG_PRFX_WIDTH-1:0]               p0_rx_st2_prefix_i,
    input  wire                                    p0_rx_st2_sop_i,
    input  wire                                    p0_rx_st2_eop_i,
    input  wire                                    p0_rx_st2_dvalid_i,
    input  wire                                    p0_rx_st2_hvalid_i,
    input  wire                                    p0_rx_st2_pvalid_i,
    input  wire [2:0]                              p0_rx_st2_bar_i,
    input  wire [SEG_EMPTY_WIDTH-1:0]              p0_rx_st2_empty_i,
    input  wire                                    p0_rx_st2_vfactive_i,
    input  wire [10:0]                             p0_rx_st2_vfnum_i,
    input  wire [2:0]                              p0_rx_st2_pfnum_i,
    // Segment 3
    input  wire [SEG_DATA_WIDTH-1:0]               p0_rx_st3_data_i,
    input  wire [SEG_HDR_WIDTH-1:0]                p0_rx_st3_hdr_i,
    input  wire [SEG_PRFX_WIDTH-1:0]               p0_rx_st3_prefix_i,
    input  wire                                    p0_rx_st3_sop_i,
    input  wire                                    p0_rx_st3_eop_i,
    input  wire                                    p0_rx_st3_dvalid_i,
    input  wire                                    p0_rx_st3_hvalid_i,
    input  wire                                    p0_rx_st3_pvalid_i,
    input  wire [2:0]                              p0_rx_st3_bar_i,
    input  wire [SEG_EMPTY_WIDTH-1:0]              p0_rx_st3_empty_i,
    input  wire                                    p0_rx_st3_vfactive_i,
    input  wire [10:0]                             p0_rx_st3_vfnum_i,
    input  wire [2:0]                              p0_rx_st3_pfnum_i,
    output wire                                    p0_rx_st_ready_o,

    /*
     * R-Tile TX AVST interface (per-segment signal ports)
     */
    // Segment 0
    output wire [SEG_DATA_WIDTH-1:0]               p0_tx_st0_data_o,
    output wire [SEG_HDR_WIDTH-1:0]                p0_tx_st0_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]               p0_tx_st0_prefix_o,
    output wire                                    p0_tx_st0_sop_o,
    output wire                                    p0_tx_st0_eop_o,
    output wire                                    p0_tx_st0_dvalid_o,
    output wire                                    p0_tx_st0_hvalid_o,
    output wire                                    p0_tx_st0_pvalid_o,
    // Segment 1
    output wire [SEG_DATA_WIDTH-1:0]               p0_tx_st1_data_o,
    output wire [SEG_HDR_WIDTH-1:0]                p0_tx_st1_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]               p0_tx_st1_prefix_o,
    output wire                                    p0_tx_st1_sop_o,
    output wire                                    p0_tx_st1_eop_o,
    output wire                                    p0_tx_st1_dvalid_o,
    output wire                                    p0_tx_st1_hvalid_o,
    output wire                                    p0_tx_st1_pvalid_o,
    // Segment 2
    output wire [SEG_DATA_WIDTH-1:0]               p0_tx_st2_data_o,
    output wire [SEG_HDR_WIDTH-1:0]                p0_tx_st2_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]               p0_tx_st2_prefix_o,
    output wire                                    p0_tx_st2_sop_o,
    output wire                                    p0_tx_st2_eop_o,
    output wire                                    p0_tx_st2_dvalid_o,
    output wire                                    p0_tx_st2_hvalid_o,
    output wire                                    p0_tx_st2_pvalid_o,
    // Segment 3
    output wire [SEG_DATA_WIDTH-1:0]               p0_tx_st3_data_o,
    output wire [SEG_HDR_WIDTH-1:0]                p0_tx_st3_hdr_o,
    output wire [SEG_PRFX_WIDTH-1:0]               p0_tx_st3_prefix_o,
    output wire                                    p0_tx_st3_sop_o,
    output wire                                    p0_tx_st3_eop_o,
    output wire                                    p0_tx_st3_dvalid_o,
    output wire                                    p0_tx_st3_hvalid_o,
    output wire                                    p0_tx_st3_pvalid_o,
    input  wire                                    p0_tx_st_ready_i,

    /*
     * R-Tile RX AVST credit interface
     */
    output wire [2:0]                              p0_rx_st_hcrdt_init_o,
    output wire [2:0]                              p0_rx_st_hcrdt_update_o,
    output wire [5:0]                              p0_rx_st_hcrdt_update_cnt_o,
    input  wire [2:0]                              p0_rx_st_hcrdt_init_ack_i,
    output wire [2:0]                              p0_rx_st_dcrdt_init_o,
    output wire [2:0]                              p0_rx_st_dcrdt_update_o,
    output wire [11:0]                             p0_rx_st_dcrdt_update_cnt_o,
    input  wire [2:0]                              p0_rx_st_dcrdt_init_ack_i,

    /*
     * R-Tile TX AVST credit interface
     */
    input  wire [2:0]                              p0_tx_st_hcrdt_init_i,
    input  wire [2:0]                              p0_tx_st_hcrdt_update_i,
    input  wire [5:0]                              p0_tx_st_hcrdt_update_cnt_i,
    output wire [2:0]                              p0_tx_st_hcrdt_init_ack_o,
    input  wire [2:0]                              p0_tx_st_dcrdt_init_i,
    input  wire [2:0]                              p0_tx_st_dcrdt_update_i,
    input  wire [11:0]                             p0_tx_st_dcrdt_update_cnt_i,
    output wire [2:0]                              p0_tx_st_dcrdt_init_ack_o,
    /*
     * TLP output (request to BAR)
     */
    output wire [TLP_DATA_WIDTH-1:0]               rx_req_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]               rx_req_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  rx_req_tlp_hdr,
    output wire [TLP_SEG_COUNT*3-1:0]              rx_req_tlp_bar_id,
    output wire [TLP_SEG_COUNT*8-1:0]              rx_req_tlp_func_num,
    output wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                rx_req_tlp_eop,
    input  wire                                    rx_req_tlp_ready,

    /*
     * TLP output (completion to DMA)
     */
    output wire [TLP_DATA_WIDTH-1:0]               rx_cpl_tlp_data,
    output wire [TLP_STRB_WIDTH-1:0]               rx_cpl_tlp_strb,
    output wire [TLP_SEG_COUNT*TLP_HDR_WIDTH-1:0]  rx_cpl_tlp_hdr,
    output wire [TLP_SEG_COUNT*4-1:0]              rx_cpl_tlp_error,
    output wire [TLP_SEG_COUNT-1:0]                rx_cpl_tlp_valid,
    output wire [TLP_SEG_COUNT-1:0]                rx_cpl_tlp_sop,
    output wire [TLP_SEG_COUNT-1:0]                rx_cpl_tlp_eop,
    input  wire                                    rx_cpl_tlp_ready,

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
// R-Tile RX flow control.  The receive adapter buffers TLPs in its internal
// demux FIFOs, so advertise a finite number of credits matching the FIFO
// capacity during the credit initialization phase, then return credits to the
// IP as TLPs are drained from the FIFOs.  This provides credit-based
// backpressure per the R-Tile Avalon-ST for PCIe specification.
//
// Credit accounting (per the specification):
//  - One header credit per TLP (posted, non-posted, or completion header).
//  - One data credit per 16 bytes (4 dwords).
//  - The demux FIFO holds 1024 dwords (256 data credits) per output port; the
//    request port is shared between posted and non-posted traffic while the
//    completion port carries completions only.  Header storage is 32 entries
//    per port.
localparam [5:0] RX_CRDT_PH   = 16;   // posted header credits (request port)
localparam [5:0] RX_CRDT_NPH  = 16;   // non-posted header credits (request port)
localparam [5:0] RX_CRDT_CPLH = 32;   // completion header credits (completion port)
localparam [8:0] RX_CRDT_PD   = 128;  // posted data credits (request port)
localparam [8:0] RX_CRDT_NPD  = 128;  // non-posted data credits (request port)
localparam [8:0] RX_CRDT_CPLD = 256;  // completion data credits (completion port)

localparam [2:0]
    RX_CRDT_ST_IDLE = 3'd0,
    RX_CRDT_ST_INIT = 3'd1,
    RX_CRDT_ST_UPDATE = 3'd2,
    RX_CRDT_ST_WAIT1 = 3'd3,
    RX_CRDT_ST_WAIT2 = 3'd4,
    RX_CRDT_ST_DONE = 3'd5;

reg [2:0] rx_crdt_state_reg = RX_CRDT_ST_IDLE;

// Remaining credits to advertise during the credit initialization phase.
reg [5:0] rx_crdt_ph_rem = RX_CRDT_PH;
reg [5:0] rx_crdt_nph_rem = RX_CRDT_NPH;
reg [5:0] rx_crdt_cplh_rem = RX_CRDT_CPLH;
reg [8:0] rx_crdt_pd_rem = RX_CRDT_PD;
reg [8:0] rx_crdt_npd_rem = RX_CRDT_NPD;
reg [8:0] rx_crdt_cpld_rem = RX_CRDT_CPLD;

wire rx_crdt_init_assert = (rx_crdt_state_reg == RX_CRDT_ST_INIT) ||
                           (rx_crdt_state_reg == RX_CRDT_ST_UPDATE) ||
                           (rx_crdt_state_reg == RX_CRDT_ST_WAIT1) ||
                           (rx_crdt_state_reg == RX_CRDT_ST_WAIT2);
wire rx_crdt_update_assert = (rx_crdt_state_reg == RX_CRDT_ST_UPDATE);

assign p0_rx_st_hcrdt_init_o = {3{rx_crdt_init_assert}};
assign p0_rx_st_dcrdt_init_o = {3{rx_crdt_init_assert}};

// Credit counts advertised each update cycle during initialization.  Each
// update may release at most 3 header credits and 15 data credits per type.
wire [1:0] rx_crdt_init_ph_cnt   = rx_crdt_ph_rem   > 3 ? 2'd3 : rx_crdt_ph_rem[1:0];
wire [1:0] rx_crdt_init_nph_cnt  = rx_crdt_nph_rem  > 3 ? 2'd3 : rx_crdt_nph_rem[1:0];
wire [1:0] rx_crdt_init_cplh_cnt = rx_crdt_cplh_rem > 3 ? 2'd3 : rx_crdt_cplh_rem[1:0];
wire [3:0] rx_crdt_init_pd_cnt   = rx_crdt_pd_rem   > 15 ? 4'd15 : rx_crdt_pd_rem[3:0];
wire [3:0] rx_crdt_init_npd_cnt  = rx_crdt_npd_rem  > 15 ? 4'd15 : rx_crdt_npd_rem[3:0];
wire [3:0] rx_crdt_init_cpld_cnt = rx_crdt_cpld_rem > 15 ? 4'd15 : rx_crdt_cpld_rem[3:0];

wire rx_crdt_init_ph_en   = rx_crdt_ph_rem   != 0;
wire rx_crdt_init_nph_en  = rx_crdt_nph_rem  != 0;
wire rx_crdt_init_cplh_en = rx_crdt_cplh_rem != 0;
wire rx_crdt_init_pd_en   = rx_crdt_pd_rem   != 0;
wire rx_crdt_init_npd_en  = rx_crdt_npd_rem  != 0;
wire rx_crdt_init_cpld_en = rx_crdt_cpld_rem != 0;

// All credits advertised once each remaining count is no larger than this
// cycle's advertised count (i.e. this is the final update cycle).
wire rx_crdt_init_done = (rx_crdt_ph_rem   <= rx_crdt_init_ph_cnt) &&
                         (rx_crdt_nph_rem  <= rx_crdt_init_nph_cnt) &&
                         (rx_crdt_cplh_rem <= rx_crdt_init_cplh_cnt) &&
                         (rx_crdt_pd_rem   <= rx_crdt_init_pd_cnt) &&
                         (rx_crdt_npd_rem  <= rx_crdt_init_npd_cnt) &&
                         (rx_crdt_cpld_rem <= rx_crdt_init_cpld_cnt);

// Credit return: decode TLPs drained at the demux outputs and return their
// header and data credits to the IP.
wire [3:0] req_fc_ph, req_fc_nph, req_fc_cplh;
wire [8:0] req_fc_pd, req_fc_npd, req_fc_cpld;
wire [3:0] cpl_fc_ph, cpl_fc_nph, cpl_fc_cplh;
wire [8:0] cpl_fc_pd, cpl_fc_npd, cpl_fc_cpld;

pcie_tlp_fc_count #(
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT)
)
req_fc_count_inst (
    .clk(clk),
    .rst(rst),
    .tlp_hdr(rx_req_tlp_hdr),
    .tlp_valid(rx_req_tlp_valid),
    .tlp_sop(rx_req_tlp_sop),
    .tlp_ready(rx_req_tlp_ready),
    .out_fc_ph(req_fc_ph),
    .out_fc_pd(req_fc_pd),
    .out_fc_nph(req_fc_nph),
    .out_fc_npd(req_fc_npd),
    .out_fc_cplh(req_fc_cplh),
    .out_fc_cpld(req_fc_cpld)
);

pcie_tlp_fc_count #(
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT)
)
cpl_fc_count_inst (
    .clk(clk),
    .rst(rst),
    .tlp_hdr(rx_cpl_tlp_hdr),
    .tlp_valid(rx_cpl_tlp_valid),
    .tlp_sop(rx_cpl_tlp_sop),
    .tlp_ready(rx_cpl_tlp_ready),
    .out_fc_ph(cpl_fc_ph),
    .out_fc_pd(cpl_fc_pd),
    .out_fc_nph(cpl_fc_nph),
    .out_fc_npd(cpl_fc_npd),
    .out_fc_cplh(cpl_fc_cplh),
    .out_fc_cpld(cpl_fc_cpld)
);

// Pending credit-return accumulators.
reg [7:0] rx_ret_ph = 0;
reg [7:0] rx_ret_nph = 0;
reg [7:0] rx_ret_cplh = 0;
reg [11:0] rx_ret_pd = 0;
reg [11:0] rx_ret_npd = 0;
reg [11:0] rx_ret_cpld = 0;

// Credit-return update pulses (only after initialization completes).
wire rx_ret_ph_en   = (rx_crdt_state_reg == RX_CRDT_ST_DONE) && (rx_ret_ph != 0);
wire rx_ret_nph_en  = (rx_crdt_state_reg == RX_CRDT_ST_DONE) && (rx_ret_nph != 0);
wire rx_ret_cplh_en = (rx_crdt_state_reg == RX_CRDT_ST_DONE) && (rx_ret_cplh != 0);
wire rx_ret_pd_en   = (rx_crdt_state_reg == RX_CRDT_ST_DONE) && (rx_ret_pd != 0);
wire rx_ret_npd_en  = (rx_crdt_state_reg == RX_CRDT_ST_DONE) && (rx_ret_npd != 0);
wire rx_ret_cpld_en = (rx_crdt_state_reg == RX_CRDT_ST_DONE) && (rx_ret_cpld != 0);

wire [1:0] rx_ret_ph_cnt   = rx_ret_ph   > 3 ? 2'd3 : rx_ret_ph[1:0];
wire [1:0] rx_ret_nph_cnt  = rx_ret_nph  > 3 ? 2'd3 : rx_ret_nph[1:0];
wire [1:0] rx_ret_cplh_cnt = rx_ret_cplh > 3 ? 2'd3 : rx_ret_cplh[1:0];
wire [3:0] rx_ret_pd_cnt   = rx_ret_pd   > 15 ? 4'd15 : rx_ret_pd[3:0];
wire [3:0] rx_ret_npd_cnt  = rx_ret_npd  > 15 ? 4'd15 : rx_ret_npd[3:0];
wire [3:0] rx_ret_cpld_cnt = rx_ret_cpld > 15 ? 4'd15 : rx_ret_cpld[3:0];

// Credit update outputs: advertise the initial credits during initialization,
// return drained-TLP credits during normal operation.
assign p0_rx_st_hcrdt_update_o = rx_crdt_update_assert ?
    {rx_crdt_init_cplh_en, rx_crdt_init_nph_en, rx_crdt_init_ph_en} :
    {rx_ret_cplh_en, rx_ret_nph_en, rx_ret_ph_en};
assign p0_rx_st_hcrdt_update_cnt_o = rx_crdt_update_assert ?
    {rx_crdt_init_cplh_cnt, rx_crdt_init_nph_cnt, rx_crdt_init_ph_cnt} :
    {rx_ret_cplh_cnt, rx_ret_nph_cnt, rx_ret_ph_cnt};
assign p0_rx_st_dcrdt_update_o = rx_crdt_update_assert ?
    {rx_crdt_init_cpld_en, rx_crdt_init_npd_en, rx_crdt_init_pd_en} :
    {rx_ret_cpld_en, rx_ret_npd_en, rx_ret_pd_en};
assign p0_rx_st_dcrdt_update_cnt_o = rx_crdt_update_assert ?
    {rx_crdt_init_cpld_cnt, rx_crdt_init_npd_cnt, rx_crdt_init_pd_cnt} :
    {rx_ret_cpld_cnt, rx_ret_npd_cnt, rx_ret_pd_cnt};

always @(posedge clk) begin
    if (rst) begin
        rx_crdt_state_reg <= RX_CRDT_ST_IDLE;
        rx_crdt_ph_rem <= RX_CRDT_PH;
        rx_crdt_nph_rem <= RX_CRDT_NPH;
        rx_crdt_cplh_rem <= RX_CRDT_CPLH;
        rx_crdt_pd_rem <= RX_CRDT_PD;
        rx_crdt_npd_rem <= RX_CRDT_NPD;
        rx_crdt_cpld_rem <= RX_CRDT_CPLD;
        rx_ret_ph <= 0;
        rx_ret_nph <= 0;
        rx_ret_cplh <= 0;
        rx_ret_pd <= 0;
        rx_ret_npd <= 0;
        rx_ret_cpld <= 0;
    end else begin
        case (rx_crdt_state_reg)
            RX_CRDT_ST_IDLE: begin
                rx_crdt_ph_rem <= RX_CRDT_PH;
                rx_crdt_nph_rem <= RX_CRDT_NPH;
                rx_crdt_cplh_rem <= RX_CRDT_CPLH;
                rx_crdt_pd_rem <= RX_CRDT_PD;
                rx_crdt_npd_rem <= RX_CRDT_NPD;
                rx_crdt_cpld_rem <= RX_CRDT_CPLD;
                rx_crdt_state_reg <= RX_CRDT_ST_INIT;
            end
            RX_CRDT_ST_INIT: begin
                if (&p0_rx_st_hcrdt_init_ack_i && &p0_rx_st_dcrdt_init_ack_i) begin
                    rx_crdt_state_reg <= RX_CRDT_ST_UPDATE;
                end
            end
            RX_CRDT_ST_UPDATE: begin
                rx_crdt_ph_rem <= rx_crdt_ph_rem - rx_crdt_init_ph_cnt;
                rx_crdt_nph_rem <= rx_crdt_nph_rem - rx_crdt_init_nph_cnt;
                rx_crdt_cplh_rem <= rx_crdt_cplh_rem - rx_crdt_init_cplh_cnt;
                rx_crdt_pd_rem <= rx_crdt_pd_rem - rx_crdt_init_pd_cnt;
                rx_crdt_npd_rem <= rx_crdt_npd_rem - rx_crdt_init_npd_cnt;
                rx_crdt_cpld_rem <= rx_crdt_cpld_rem - rx_crdt_init_cpld_cnt;
                if (rx_crdt_init_done) begin
                    rx_crdt_state_reg <= RX_CRDT_ST_WAIT1;
                end
            end
            RX_CRDT_ST_WAIT1: rx_crdt_state_reg <= RX_CRDT_ST_WAIT2;
            RX_CRDT_ST_WAIT2: rx_crdt_state_reg <= RX_CRDT_ST_DONE;
            default: rx_crdt_state_reg <= RX_CRDT_ST_DONE;
        endcase

        // Accumulate returned credits and drain them via update pulses.
        if (rx_crdt_state_reg == RX_CRDT_ST_DONE) begin
            rx_ret_ph <= rx_ret_ph + req_fc_ph + cpl_fc_ph - {6'b0, rx_ret_ph_en ? rx_ret_ph_cnt : 2'b0};
            rx_ret_nph <= rx_ret_nph + req_fc_nph + cpl_fc_nph - {6'b0, rx_ret_nph_en ? rx_ret_nph_cnt : 2'b0};
            rx_ret_cplh <= rx_ret_cplh + req_fc_cplh + cpl_fc_cplh - {6'b0, rx_ret_cplh_en ? rx_ret_cplh_cnt : 2'b0};
            rx_ret_pd <= rx_ret_pd + req_fc_pd + cpl_fc_pd - {8'b0, rx_ret_pd_en ? rx_ret_pd_cnt : 4'b0};
            rx_ret_npd <= rx_ret_npd + req_fc_npd + cpl_fc_npd - {8'b0, rx_ret_npd_en ? rx_ret_npd_cnt : 4'b0};
            rx_ret_cpld <= rx_ret_cpld + req_fc_cpld + cpl_fc_cpld - {8'b0, rx_ret_cpld_en ? rx_ret_cpld_cnt : 4'b0};
        end else begin
            rx_ret_ph <= 0;
            rx_ret_nph <= 0;
            rx_ret_cplh <= 0;
            rx_ret_pd <= 0;
            rx_ret_npd <= 0;
            rx_ret_cpld <= 0;
        end
    end
end

pcie_rtile_if_rx #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_EMPTY_WIDTH(SEG_EMPTY_WIDTH),
    .SEG_HDR_WIDTH(SEG_HDR_WIDTH),
    .SEG_PRFX_WIDTH(SEG_PRFX_WIDTH),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .IO_BAR_INDEX(IO_BAR_INDEX)
)
pcie_rtile_if_rx_inst (
    .clk(clk),
    .rst(rst),

    .p0_rx_st0_data_i(p0_rx_st0_data_i),
    .p0_rx_st0_hdr_i(p0_rx_st0_hdr_i),
    .p0_rx_st0_prefix_i(p0_rx_st0_prefix_i),
    .p0_rx_st0_sop_i(p0_rx_st0_sop_i),
    .p0_rx_st0_eop_i(p0_rx_st0_eop_i),
    .p0_rx_st0_dvalid_i(p0_rx_st0_dvalid_i),
    .p0_rx_st0_hvalid_i(p0_rx_st0_hvalid_i),
    .p0_rx_st0_pvalid_i(p0_rx_st0_pvalid_i),
    .p0_rx_st0_bar_i(p0_rx_st0_bar_i),
    .p0_rx_st0_empty_i(p0_rx_st0_empty_i),
    .p0_rx_st0_vfactive_i(p0_rx_st0_vfactive_i),
    .p0_rx_st0_vfnum_i(p0_rx_st0_vfnum_i),
    .p0_rx_st0_pfnum_i(p0_rx_st0_pfnum_i),

    .p0_rx_st1_data_i(p0_rx_st1_data_i),
    .p0_rx_st1_hdr_i(p0_rx_st1_hdr_i),
    .p0_rx_st1_prefix_i(p0_rx_st1_prefix_i),
    .p0_rx_st1_sop_i(p0_rx_st1_sop_i),
    .p0_rx_st1_eop_i(p0_rx_st1_eop_i),
    .p0_rx_st1_dvalid_i(p0_rx_st1_dvalid_i),
    .p0_rx_st1_hvalid_i(p0_rx_st1_hvalid_i),
    .p0_rx_st1_pvalid_i(p0_rx_st1_pvalid_i),
    .p0_rx_st1_bar_i(p0_rx_st1_bar_i),
    .p0_rx_st1_empty_i(p0_rx_st1_empty_i),
    .p0_rx_st1_vfactive_i(p0_rx_st1_vfactive_i),
    .p0_rx_st1_vfnum_i(p0_rx_st1_vfnum_i),
    .p0_rx_st1_pfnum_i(p0_rx_st1_pfnum_i),

    .p0_rx_st2_data_i(p0_rx_st2_data_i),
    .p0_rx_st2_hdr_i(p0_rx_st2_hdr_i),
    .p0_rx_st2_prefix_i(p0_rx_st2_prefix_i),
    .p0_rx_st2_sop_i(p0_rx_st2_sop_i),
    .p0_rx_st2_eop_i(p0_rx_st2_eop_i),
    .p0_rx_st2_dvalid_i(p0_rx_st2_dvalid_i),
    .p0_rx_st2_hvalid_i(p0_rx_st2_hvalid_i),
    .p0_rx_st2_pvalid_i(p0_rx_st2_pvalid_i),
    .p0_rx_st2_bar_i(p0_rx_st2_bar_i),
    .p0_rx_st2_empty_i(p0_rx_st2_empty_i),
    .p0_rx_st2_vfactive_i(p0_rx_st2_vfactive_i),
    .p0_rx_st2_vfnum_i(p0_rx_st2_vfnum_i),
    .p0_rx_st2_pfnum_i(p0_rx_st2_pfnum_i),

    .p0_rx_st3_data_i(p0_rx_st3_data_i),
    .p0_rx_st3_hdr_i(p0_rx_st3_hdr_i),
    .p0_rx_st3_prefix_i(p0_rx_st3_prefix_i),
    .p0_rx_st3_sop_i(p0_rx_st3_sop_i),
    .p0_rx_st3_eop_i(p0_rx_st3_eop_i),
    .p0_rx_st3_dvalid_i(p0_rx_st3_dvalid_i),
    .p0_rx_st3_hvalid_i(p0_rx_st3_hvalid_i),
    .p0_rx_st3_pvalid_i(p0_rx_st3_pvalid_i),
    .p0_rx_st3_bar_i(p0_rx_st3_bar_i),
    .p0_rx_st3_empty_i(p0_rx_st3_empty_i),
    .p0_rx_st3_vfactive_i(p0_rx_st3_vfactive_i),
    .p0_rx_st3_vfnum_i(p0_rx_st3_vfnum_i),
    .p0_rx_st3_pfnum_i(p0_rx_st3_pfnum_i),
    .p0_rx_st_ready_o(p0_rx_st_ready_o),

    .rx_req_tlp_data(rx_req_tlp_data),
    .rx_req_tlp_strb(rx_req_tlp_strb),
    .rx_req_tlp_hdr(rx_req_tlp_hdr),
    .rx_req_tlp_bar_id(rx_req_tlp_bar_id),
    .rx_req_tlp_func_num(rx_req_tlp_func_num),
    .rx_req_tlp_valid(rx_req_tlp_valid),
    .rx_req_tlp_sop(rx_req_tlp_sop),
    .rx_req_tlp_eop(rx_req_tlp_eop),
    .rx_req_tlp_ready(rx_req_tlp_ready),

    .rx_cpl_tlp_data(rx_cpl_tlp_data),
    .rx_cpl_tlp_strb(rx_cpl_tlp_strb),
    .rx_cpl_tlp_hdr(rx_cpl_tlp_hdr),
    .rx_cpl_tlp_error(rx_cpl_tlp_error),
    .rx_cpl_tlp_valid(rx_cpl_tlp_valid),
    .rx_cpl_tlp_sop(rx_cpl_tlp_sop),
    .rx_cpl_tlp_eop(rx_cpl_tlp_eop),
    .rx_cpl_tlp_ready(rx_cpl_tlp_ready)
);
pcie_rtile_if_tx #(
    .SEG_COUNT(SEG_COUNT),
    .SEG_DATA_WIDTH(SEG_DATA_WIDTH),
    .SEG_HDR_WIDTH(SEG_HDR_WIDTH),
    .SEG_PRFX_WIDTH(SEG_PRFX_WIDTH),
    .TLP_DATA_WIDTH(TLP_DATA_WIDTH),
    .TLP_STRB_WIDTH(TLP_STRB_WIDTH),
    .TLP_HDR_WIDTH(TLP_HDR_WIDTH),
    .TLP_SEG_COUNT(TLP_SEG_COUNT),
    .TX_SEQ_NUM_WIDTH(TX_SEQ_NUM_WIDTH),
    .MAX_PAYLOAD_SIZE(MAX_PAYLOAD_SIZE)
)
pcie_rtile_if_tx_inst (
    .clk(clk),
    .rst(rst),

    .p0_tx_st0_data_o(p0_tx_st0_data_o),
    .p0_tx_st0_hdr_o(p0_tx_st0_hdr_o),
    .p0_tx_st0_prefix_o(p0_tx_st0_prefix_o),
    .p0_tx_st0_sop_o(p0_tx_st0_sop_o),
    .p0_tx_st0_eop_o(p0_tx_st0_eop_o),
    .p0_tx_st0_dvalid_o(p0_tx_st0_dvalid_o),
    .p0_tx_st0_hvalid_o(p0_tx_st0_hvalid_o),
    .p0_tx_st0_pvalid_o(p0_tx_st0_pvalid_o),

    .p0_tx_st1_data_o(p0_tx_st1_data_o),
    .p0_tx_st1_hdr_o(p0_tx_st1_hdr_o),
    .p0_tx_st1_prefix_o(p0_tx_st1_prefix_o),
    .p0_tx_st1_sop_o(p0_tx_st1_sop_o),
    .p0_tx_st1_eop_o(p0_tx_st1_eop_o),
    .p0_tx_st1_dvalid_o(p0_tx_st1_dvalid_o),
    .p0_tx_st1_hvalid_o(p0_tx_st1_hvalid_o),
    .p0_tx_st1_pvalid_o(p0_tx_st1_pvalid_o),

    .p0_tx_st2_data_o(p0_tx_st2_data_o),
    .p0_tx_st2_hdr_o(p0_tx_st2_hdr_o),
    .p0_tx_st2_prefix_o(p0_tx_st2_prefix_o),
    .p0_tx_st2_sop_o(p0_tx_st2_sop_o),
    .p0_tx_st2_eop_o(p0_tx_st2_eop_o),
    .p0_tx_st2_dvalid_o(p0_tx_st2_dvalid_o),
    .p0_tx_st2_hvalid_o(p0_tx_st2_hvalid_o),
    .p0_tx_st2_pvalid_o(p0_tx_st2_pvalid_o),

    .p0_tx_st3_data_o(p0_tx_st3_data_o),
    .p0_tx_st3_hdr_o(p0_tx_st3_hdr_o),
    .p0_tx_st3_prefix_o(p0_tx_st3_prefix_o),
    .p0_tx_st3_sop_o(p0_tx_st3_sop_o),
    .p0_tx_st3_eop_o(p0_tx_st3_eop_o),
    .p0_tx_st3_dvalid_o(p0_tx_st3_dvalid_o),
    .p0_tx_st3_hvalid_o(p0_tx_st3_hvalid_o),
    .p0_tx_st3_pvalid_o(p0_tx_st3_pvalid_o),
    .p0_tx_st_ready_i(p0_tx_st_ready_i),

    .p0_tx_st_hcrdt_init_i(p0_tx_st_hcrdt_init_i),
    .p0_tx_st_hcrdt_update_i(p0_tx_st_hcrdt_update_i),
    .p0_tx_st_hcrdt_update_cnt_i(p0_tx_st_hcrdt_update_cnt_i),
    .p0_tx_st_hcrdt_init_ack_o(p0_tx_st_hcrdt_init_ack_o),
    .p0_tx_st_dcrdt_init_i(p0_tx_st_dcrdt_init_i),
    .p0_tx_st_dcrdt_update_i(p0_tx_st_dcrdt_update_i),
    .p0_tx_st_dcrdt_update_cnt_i(p0_tx_st_dcrdt_update_cnt_i),
    .p0_tx_st_dcrdt_init_ack_o(p0_tx_st_dcrdt_init_ack_o),

    .tx_rd_req_tlp_hdr(tx_rd_req_tlp_hdr),
    .tx_rd_req_tlp_seq(tx_rd_req_tlp_seq),
    .tx_rd_req_tlp_valid(tx_rd_req_tlp_valid),
    .tx_rd_req_tlp_sop(tx_rd_req_tlp_sop),
    .tx_rd_req_tlp_eop(tx_rd_req_tlp_eop),
    .tx_rd_req_tlp_ready(tx_rd_req_tlp_ready),

    .m_axis_rd_req_tx_seq_num(m_axis_rd_req_tx_seq_num),
    .m_axis_rd_req_tx_seq_num_valid(m_axis_rd_req_tx_seq_num_valid),

    .tx_wr_req_tlp_data(tx_wr_req_tlp_data),
    .tx_wr_req_tlp_strb(tx_wr_req_tlp_strb),
    .tx_wr_req_tlp_hdr(tx_wr_req_tlp_hdr),
    .tx_wr_req_tlp_seq(tx_wr_req_tlp_seq),
    .tx_wr_req_tlp_valid(tx_wr_req_tlp_valid),
    .tx_wr_req_tlp_sop(tx_wr_req_tlp_sop),
    .tx_wr_req_tlp_eop(tx_wr_req_tlp_eop),
    .tx_wr_req_tlp_ready(tx_wr_req_tlp_ready),

    .m_axis_wr_req_tx_seq_num(m_axis_wr_req_tx_seq_num),
    .m_axis_wr_req_tx_seq_num_valid(m_axis_wr_req_tx_seq_num_valid),

    .tx_cpl_tlp_data(tx_cpl_tlp_data),
    .tx_cpl_tlp_strb(tx_cpl_tlp_strb),
    .tx_cpl_tlp_hdr(tx_cpl_tlp_hdr),
    .tx_cpl_tlp_valid(tx_cpl_tlp_valid),
    .tx_cpl_tlp_sop(tx_cpl_tlp_sop),
    .tx_cpl_tlp_eop(tx_cpl_tlp_eop),
    .tx_cpl_tlp_ready(tx_cpl_tlp_ready),

    .tx_msi_wr_req_tlp_data(tx_msi_wr_req_tlp_data),
    .tx_msi_wr_req_tlp_strb(tx_msi_wr_req_tlp_strb),
    .tx_msi_wr_req_tlp_hdr(tx_msi_wr_req_tlp_hdr),
    .tx_msi_wr_req_tlp_valid(tx_msi_wr_req_tlp_valid),
    .tx_msi_wr_req_tlp_sop(tx_msi_wr_req_tlp_sop),
    .tx_msi_wr_req_tlp_eop(tx_msi_wr_req_tlp_eop),
    .tx_msi_wr_req_tlp_ready(tx_msi_wr_req_tlp_ready)
);

endmodule

`resetall

