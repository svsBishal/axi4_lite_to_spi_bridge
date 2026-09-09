`timescale 1ns / 1ps

module AXI_SPI_Bridge_Top (
    // AXI System Clock Domain
    input  logic        aclk,
    input  logic        aresetn,

    // AXI4-Lite Slave Channels
    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,

    // SPI Peripheral Clock Domain
    input  logic        rclk,
    input  logic        rrst_n,

    // External SPI Pins
    output logic        mosi,
    input  logic        miso,
    output logic        sclk,
    output logic        cs_n
);

    // =========================================================================
    // Internal Interconnect Wires
    // =========================================================================

    logic [31:0] spi_ctrl;      // output of AXI4_Lite_Slave_Interface module, input to SPI_Baud_Generator, SPI_Timing_Control, SPI_Master_FSM modules
    logic [31:0] spi_stat;      // output of top module assign block, input to AXI4_Lite_Slave_Interface module
    
    logic        tx_fifo_we;    // output of AXI4_Lite_Slave_Interface module, input to Async_FIFO_FWFT (TX) module
    logic [7:0]  tx_fifo_wdata; // output of AXI4_Lite_Slave_Interface module, input to Async_FIFO_FWFT (TX) module
    logic        tx_fifo_rinc;  // output of SPI_Master_FSM module, input to Async_FIFO_FWFT (TX) module
    logic [7:0]  tx_fifo_rdata; // output of Async_FIFO_FWFT (TX) module, input to SPI_Master_FSM module
    logic        tx_fifo_full;  // output of Async_FIFO_FWFT (TX) module, input to top module assign block
    logic        tx_fifo_empty; // output of Async_FIFO_FWFT (TX) module, input to SPI_Master_FSM module

    logic        rx_fifo_winc;  // output of SPI_Master_FSM module, input to Async_FIFO_FWFT (RX) module
    logic [7:0]  rx_fifo_wdata; // output of SPI_Master_FSM module, input to Async_FIFO_FWFT (RX) module
    logic        rx_fifo_re;    // output of AXI4_Lite_Slave_Interface module, input to Async_FIFO_FWFT (RX) module
    logic [7:0]  rx_fifo_rdata; // output of Async_FIFO_FWFT (RX) module, input to AXI4_Lite_Slave_Interface module
    logic        rx_fifo_full;  // output of Async_FIFO_FWFT (RX) module, input to SPI_Master_FSM module
    logic        rx_fifo_empty; // output of Async_FIFO_FWFT (RX) module, input to top module assign block

    logic        spi_enable;    // output of SPI_Master_FSM module, input to SPI_Baud_Generator, SPI_Timing_Control modules
    logic        sclk_tick;     // output of SPI_Baud_Generator module, input to SPI_Timing_Control module
    logic        shift_en;      // output of SPI_Timing_Control module, input to SPI_Master_FSM module
    logic        sample_en;     // output of SPI_Timing_Control module, input to SPI_Master_FSM module


    // =========================================================================
    // Status Register Mapping
    // =========================================================================
    // Bit 0: TX FIFO Full
    // Bit 1: RX FIFO Empty
    // Bit 2: SPI Busy (Active when Chip Select is LOW)
    assign spi_stat = {29'h0, ~cs_n, rx_fifo_empty, tx_fifo_full};

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    AXI4_Lite_Slave_Interface axi_slave_inst (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .awaddr        (awaddr),
        .awvalid       (awvalid),
        .awready       (awready),
        .wdata         (wdata),
        .wstrb         (wstrb),
        .wvalid        (wvalid),
        .wready        (wready),
        .bresp         (bresp),
        .bvalid        (bvalid),
        .bready        (bready),
        .araddr        (araddr),
        .arvalid       (arvalid),
        .arready       (arready),
        .rdata         (rdata),
        .rresp         (rresp),
        .rvalid        (rvalid),
        .rready        (rready),
        .tx_fifo_we    (tx_fifo_we),
        .tx_fifo_wdata (tx_fifo_wdata),
        .rx_fifo_re    (rx_fifo_re),
        .rx_fifo_rdata (rx_fifo_rdata),
        .spi_ctrl      (spi_ctrl),
        .spi_stat      (spi_stat)
    );

    // TX FIFO: AXI Write Domain (aclk) to SPI Read Domain (rclk)
    Async_FIFO_FWFT #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) tx_fifo_inst (
        .wclk   (aclk),
        .wrst_n (aresetn),
        .winc   (tx_fifo_we),
        .wdata  (tx_fifo_wdata),
        .wfull  (tx_fifo_full),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (tx_fifo_rinc),
        .rdata  (tx_fifo_rdata),
        .rempty (tx_fifo_empty)
    );

    // RX FIFO: SPI Write Domain (rclk) to AXI Read Domain (aclk)
    Async_FIFO_FWFT #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) rx_fifo_inst (
        .wclk   (rclk),
        .wrst_n (rrst_n),
        .winc   (rx_fifo_winc),
        .wdata  (rx_fifo_wdata),
        .wfull  (rx_fifo_full),
        .rclk   (aclk),
        .rrst_n (aresetn),
        .rinc   (rx_fifo_re),
        .rdata  (rx_fifo_rdata),
        .rempty (rx_fifo_empty)
    );

    SPI_Baud_Generator baud_gen_inst (
        .clk       (rclk),
        .rst_n     (rrst_n),
        .enable    (spi_enable),
        .baud_div  (spi_ctrl[31:16]),
        .sclk_tick (sclk_tick)
    );

    SPI_Timing_Control timing_ctrl_inst (
        .clk       (rclk),
        .rst_n     (rrst_n),
        .enable    (spi_enable),
        .cpol      (spi_ctrl[1]),
        .cpha      (spi_ctrl[0]),
        .sclk_tick (sclk_tick),
        .sclk      (sclk),
        .shift_en  (shift_en),
        .sample_en (sample_en)
    );

    SPI_Master_FSM spi_fsm_inst (
        .rclk      (rclk),
        .rrst_n    (rrst_n),
        .tx_empty  (tx_fifo_empty),
        .tx_rdata  (tx_fifo_rdata),
        .tx_rinc   (tx_fifo_rinc),
        .rx_full   (rx_fifo_full),
        .rx_wdata  (rx_fifo_wdata),
        .rx_winc   (rx_fifo_winc),
        .enable    (spi_enable),
        .shift_en  (shift_en),
        .sample_en (sample_en),
        .cpha      (spi_ctrl[0]),
        .mosi      (mosi),
        .miso      (miso),
        .cs_n      (cs_n)
    );

endmodule