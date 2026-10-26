
// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * R-Tile PCIe interface adapter (receive)
 */
module pcie_rtile_if_rx #
(
    // R-Tile AVST segment count
    parameter SEG_COUNT = 1,
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
    // IO bar index
    // rx_st_bar_range = 6 is mapped to IO_BAR_INDEX on rx_req_tlp_bar_id
    parameter IO_BAR_INDEX = 5
    
)
(
    input  wire                                    clk,
    input  wire                                    rst,

    /*
     * R-tile RX AVST interface
     */
    // Segment 0
    input wire [SEG_DATA_WIDTH-1:0]          p0_rx_st0_data_i,
    input wire [SEG_HDR_WIDTH-1:0]           p0_rx_st0_hdr_i,
    input wire [SEG_PRFX_WIDTH-1:0]          p0_rx_st0_prefix_i,
    input wire                               p0_rx_st0_sop_i,
    input wire                               p0_rx_st0_eop_i,
    input wire                               p0_rx_st0_dvalid_i,
    input wire                               p0_rx_st0_hvalid_i,
    input wire                               p0_rx_st0_pvalid_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st0_bar_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st0_empty_i, // Width is different from ptile
    input wire                               p0_rx_st0_vfactive_i,
    input wire [SEG_COUNT*11-1:0]            p0_rx_st0_vfnum_i,
    input wire [SRG_COUNT*3-1:0]             p0_rx_st0_pfnum_i,
    // Segment 1
    input wire [SEG_DATA_WIDTH-1:0]          p0_rx_st1_data_i,
    input wire [SEG_HDR_WIDTH-1:0]           p0_rx_st1_hdr_i,
    input wire [SEG_PRFX_WIDTH-1:0]          p0_rx_st1_prefix_i,
    input wire                               p0_rx_st1_sop_i,
    input wire                               p0_rx_st1_eop_i,
    input wire                               p0_rx_st1_dvalid_i,
    input wire                               p0_rx_st1_hvalid_i,
    input wire                               p0_rx_st1_pvalid_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st1_bar_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st1_empty_i, // Width is different from ptile
    input wire                               p0_rx_st1_vfactive_i,
    input wire [SEG_COUNT*11-1:0]            p0_rx_st1_vfnum_i,
    input wire [SRG_COUNT*3-1:0]             p0_rx_st1_pfnum_i,
    // Segment 2
    input wire [SEG_DATA_WIDTH-1:0]          p0_rx_st2_data_i,
    input wire [SEG_HDR_WIDTH-1:0]           p0_rx_st2_hdr_i,
    input wire [SEG_PRFX_WIDTH-1:0]          p0_rx_st2_prefix_i,
    input wire                               p0_rx_st2_sop_i,
    input wire                               p0_rx_st2_eop_i,
    input wire                               p0_rx_st2_dvalid_i,
    input wire                               p0_rx_st2_hvalid_i,
    input wire                               p0_rx_st2_pvalid_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st2_bar_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st2_empty_i, // Width is different from ptile
    input wire                               p0_rx_st2_vfactive_i,
    input wire [SEG_COUNT*11-1:0]            p0_rx_st2_vfnum_i,
    input wire [SRG_COUNT*3-1:0]             p0_rx_st2_pfnum_i,
    // Segment 3
    input wire [SEG_DATA_WIDTH-1:0]          p0_rx_st3_data_i,
    input wire [SEG_HDR_WIDTH-1:0]           p0_rx_st3_hdr_i,
    input wire [SEG_PRFX_WIDTH-1:0]          p0_rx_st3_prefix_i,
    input wire                               p0_rx_st3_sop_i,
    input wire                               p0_rx_st3_eop_i,
    input wire                               p0_rx_st3_dvalid_i,
    input wire                               p0_rx_st3_hvalid_i,
    input wire                               p0_rx_st3_pvalid_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st3_bar_i,
    input wire [SEG_COUNT*3-1:0]             p0_rx_st3_empty_i, // Width is different from ptile
    input wire                               p0_rx_st3_vfactive_i,
    input wire [SEG_COUNT*11-1:0]            p0_rx_st3_vfnum_i,
    input wire [SRG_COUNT*3-1:0]             p0_rx_st3_pfnum_i,
    output wire                              p0_rx_st_ready_o,
    /*
     * R-tile TX AVST interface
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
    input wire                               p0_tx_st_ready_i,

     /*
     * R-tile AVST RX Credit Interface
     */   
    output wire [2:0]                       p0_rx_st_hcrdt_init_o,       
	output wire [2:0]                       p0_rx_st_hcrdt_update_o,     
	output wire [5:0]                   	p0_rx_st_hcrdt_update_cnt_o, 
    input  wire [2:0] 	                    p0_rx_st_hcrdt_init_ack_i,   
	output wire [2:0] 	                    p0_rx_st_dcrdt_init_o,       
	output wire [2:0]                       p0_rx_st_dcrdt_update_o,     
	output wire [11:0]                      p0_rx_st_dcrdt_update_cnt_o, 
	input  wire [2:0]                       p0_rx_st_dcrdt_init_ack_i,   

     /*
     * R-tile AVST TX Credit Interface
     */ 
    input  wire [2:0]                       p0_tx_st_hcrdt_init_i,       
	input  wire [2:0]                       p0_tx_st_hcrdt_update_i,     
	input  wire [5:0]                   	p0_tx_st_hcrdt_update_cnt_i, 
    output wire [2:0] 	                    p0_tx_st_hcrdt_init_ack_o,   
	input  wire [2:0] 	                    p0_tx_st_dcrdt_init_i,       
	input  wire [2:0]                       p0_tx_st_dcrdt_update_i,     
	input  wire [11:0]                      p0_tx_st_dcrdt_update_cnt_i, 
    output wire [2:0]                       p0_tx_st_dcrdt_init_ack_o, 

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















endmodule

`resetall