`timescale 1ns / 1ps

module SPI_Master_FSM (
    input  logic       rclk,
    input  logic       rrst_n,

    // TX FIFO Interface (FWFT)
    input  logic       tx_empty,
    input  logic [7:0] tx_rdata,
    output logic       tx_rinc,

    // RX FIFO Interface
    input  logic       rx_full,
    output logic [7:0] rx_wdata,
    output logic       rx_winc,

    // SPI Timing Controller Interface
    output logic       enable,
    input  logic       shift_en,
    input  logic       sample_en,
    input  logic       cpha,

    // External SPI Pins
    output logic       mosi,
    input  logic       miso,
    output logic       cs_n
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        TRANSFER,
        DONE
    } state_t;

    state_t state;

    logic [7:0] piso;
    logic [7:0] sipo;
    logic [3:0] edge_cnt;
    logic       first_edge;

    // MSB of PISO is continuously driven onto MOSI
    assign mosi = piso[7];

    always_ff @(posedge rclk or negedge rrst_n) begin
    
        if (!rrst_n) begin
            state     <= IDLE;
            cs_n      <= 1'b1;
            enable    <= 1'b0;
            tx_rinc   <= 1'b0;
            rx_winc   <= 1'b0;
            piso      <= 8'h00;
            sipo      <= 8'h00;
            rx_wdata  <= 8'h00;
            edge_cnt  <= 4'h0;
            first_edge <= 1'b1;
        end else begin
            // Default: FIFO controls are one-cycle pulses
            tx_rinc <= 1'b0;
            rx_winc <= 1'b0;
            case (state)

                // IDLE
                IDLE: begin
                
                    enable <= 1'b0;
                    cs_n   <= 1'b1;
                    edge_cnt   <= 4'h0;
                    first_edge <= 1'b1;
                    
                    if (!tx_empty && !rx_full) begin
                        piso <= tx_rdata;
                        tx_rinc <= 1'b1;
                        sipo <= 8'h00;
                        cs_n <= 1'b0;
                        state <= SETUP;
                    end
                    
                end

                // SETUP
                SETUP: begin
                
                    enable <= 1'b1;
                    edge_cnt   <= 4'h0;
                    first_edge <= 1'b1;
                    state <= TRANSFER;

                end

                // TRANSFER

                TRANSFER: begin

                    if (sample_en) begin
                        sipo <= {sipo[6:0], miso};
                    end

                    if (shift_en) begin

                        if (cpha == 1'b0) begin
                            piso <= {piso[6:0], 1'b0};
                        end
                        
                        else begin
                            if (!first_edge) begin
                                piso <= {piso[6:0], 1'b0};
                            end
                        end

                    end

                    if (shift_en || sample_en) begin

                        if (first_edge) begin
                            first_edge <= 1'b0;
                        end

                        if (sample_en) begin
                        
                            if (edge_cnt == 4'd7) begin
                                rx_wdata <= {sipo[6:0], miso};
                                enable <= 1'b0;
                                rx_winc <= 1'b1;
                                state <= DONE;
                            end
                            else begin
                                edge_cnt <= edge_cnt + 4'd1;
                            end
                        end
                    end
                end

                // DONE

                DONE: begin

                    cs_n   <= 1'b1;
                    enable <= 1'b0;
                    state <= IDLE;

                end

                default: begin

                    state  <= IDLE;
                    cs_n   <= 1'b1;
                    enable <= 1'b0;

                end

            endcase

        end

    end

endmodule