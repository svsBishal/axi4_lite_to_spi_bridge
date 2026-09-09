`timescale 1ns / 1ps

module Async_FIFO_FWFT #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // Write Domain
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  winc,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  wfull,

    // Read Domain
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rempty
);

    // Pointer registers

    logic [ADDR_WIDTH:0] wptr_bin;
    logic [ADDR_WIDTH:0] wptr_gray;

    logic [ADDR_WIDTH:0] rptr_bin;
    logic [ADDR_WIDTH:0] rptr_gray;

    logic [ADDR_WIDTH:0] wptr_bin_nxt;
    logic [ADDR_WIDTH:0] wptr_gray_nxt;

    logic [ADDR_WIDTH:0] rptr_bin_nxt;
    logic [ADDR_WIDTH:0] rptr_gray_nxt;


    // Synchronized pointers

    logic [ADDR_WIDTH:0] wq2_rptr;
    logic [ADDR_WIDTH:0] rq2_wptr;


    // Flag logic

    logic wfull_val;
    logic rempty_val;


    // Memory

    logic [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];


    // Memory Write
    always_ff @(posedge wclk) begin
        if (winc && !wfull) begin
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
        end
    end


    // FWFT Read
    assign rdata = mem[rptr_bin[ADDR_WIDTH-1:0]];


    // Write Pointer
    assign wptr_bin_nxt = wptr_bin + (winc & ~wfull);

    assign wptr_gray_nxt = (wptr_bin_nxt >> 1) ^ wptr_bin_nxt;

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
        end
        else begin
            wptr_bin  <= wptr_bin_nxt;
            wptr_gray <= wptr_gray_nxt;
        end
    end


    // Read Pointer
    assign rptr_bin_nxt = rptr_bin + (rinc & ~rempty);

    assign rptr_gray_nxt = (rptr_bin_nxt >> 1) ^ rptr_bin_nxt;

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
        end
        else begin
            rptr_bin  <= rptr_bin_nxt;
            rptr_gray <= rptr_gray_nxt;
        end
    end

    // CDC: Read Pointer ? Write Domai
    CDC_Synchronizer #(
        .WIDTH(ADDR_WIDTH + 1)
    ) sync_rptr_to_wclk (
        .clk   (wclk),
        .rst_n (wrst_n),
        .din   (rptr_gray),
        .dout  (wq2_rptr)
    );

    // CDC: Write Pointer ? Read Domain
    CDC_Synchronizer #(
        .WIDTH(ADDR_WIDTH + 1)
    ) sync_wptr_to_rclk (
        .clk   (rclk),
        .rst_n (rrst_n),
        .din   (wptr_gray),
        .dout  (rq2_wptr)
    );

    // EMPTY Detection
    assign rempty_val =
        (rptr_gray_nxt == rq2_wptr);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            rempty <= 1'b1;
        else
            rempty <= rempty_val;
    end

    // FULL Detection
    assign wfull_val =
        (wptr_gray_nxt ==
         {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1],
           wq2_rptr[ADDR_WIDTH-2:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            wfull <= 1'b0;
        else
            wfull <= wfull_val;
    end

endmodule