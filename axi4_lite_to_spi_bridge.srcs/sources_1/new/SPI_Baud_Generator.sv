`timescale 1ns / 1ps

module SPI_Baud_Generator (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [15:0] baud_div,

    output logic        sclk_tick
);

    logic [15:0] baud_counter;

    // Baud Rate Prescaler (Down-Counter)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 16'h0000;
        end else if (!enable) begin
            // Hold counter at division ratio when idle
            baud_counter <= baud_div;
        end else if (baud_counter == 16'h0000) begin
            // Reload counter when terminal count is reached
            baud_counter <= baud_div;
        end else begin
            baud_counter <= baud_counter - 16'h0001;
        end
    end

    // One-rclk-cycle pulse indicating an SCLK transition
    assign sclk_tick = enable && (baud_counter == 16'h0000);

endmodule