`timescale 1ns / 1ps

module SPI_Timing_Control (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        enable,
    input  logic        cpol,
    input  logic        cpha,
    input  logic        sclk_tick,

    output logic        sclk,
    output logic        shift_en,
    output logic        sample_en
);

    logic leading_edge;

    // SCLK Generation and Edge Tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk <= 1'b0;
            leading_edge <= 1'b1;
        end else if (!enable) begin
            // Return SCLK to its CPOL-defined idle level
            sclk <= cpol;

            // First SCLK transition after enable is the leading edge
            leading_edge <= 1'b1;
        end else if (sclk_tick) begin
            // Toggle SCLK
            sclk <= ~sclk;

            // Alternate between leading and trailing edges
            leading_edge <= ~leading_edge;
        end
    end

    // Phase Logic: Generate Shift and Sample Enables
    always_comb begin
        shift_en  = 1'b0;
        sample_en = 1'b0;

        if (sclk_tick) begin
            if (cpha == 1'b0) begin
                sample_en = leading_edge;
                shift_en  = ~leading_edge;
            end else begin
                shift_en  = leading_edge;
                sample_en = ~leading_edge;
            end

        end
    end

endmodule