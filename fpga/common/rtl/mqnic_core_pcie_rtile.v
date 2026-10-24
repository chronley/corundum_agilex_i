


/*
 *mqnic core logic -Intel R-Tile Wrapper
 */

module mqnic_core_rtile_pcie 
#(

    //FW and board IDs
    parameter FPGA_ID = ;
    parameter FW_ID = ;
    parameter FW_VER = ;
    parameter BOARD_ID = ;
    parameter BOARD_VER = ;
    parameter BUILD_DATE = ;
    parameter GIT_HASH = ;
    parameter RELEASE_INFO = ;

    // Structural configuration

    // Clock configuration

    // PTP configuration

    // Queue manager configuration

    // TX and RX engine configuration

    // Scheduler configuration

    // Interface configuration

    // RAM configuration

    // Application block configuration

    // DMA interface configuration

    // PCIe interface configuration
    parameter SEG_COUNT = 1,
    parameter SEG_DATA_WIDTH = 256,
    parameter SEG_HDR_WIDTH = 128,
    parameter SEG_PRFX_WIDTH = 32
) (




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
);
    
endmodule