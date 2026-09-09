`timescale 1ns / 1ps

module AXI4_Lite_Slave_Interface (
    input  logic        aclk,
    input  logic        aresetn,

    // AXI4-Lite Write Channels
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

    // AXI4-Lite Read Channels
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,

    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,

    // Hardware Bridge Interfaces
    output logic        tx_fifo_we,
    output logic [7:0]  tx_fifo_wdata,

    output logic        rx_fifo_re,
    input  logic [7:0]  rx_fifo_rdata,

    output logic [31:0] spi_ctrl,
    input  logic [31:0] spi_stat
);

    // FSM State Declarations

    typedef enum logic {
        AW_IDLE,
        AW_WAIT_RESP
    } aw_state_t;

    typedef enum logic {
        W_IDLE,
        W_WAIT_RESP
    } w_state_t;

    typedef enum logic {
        B_IDLE,
        B_ACTIVE
    } b_state_t;

    typedef enum logic {
        AR_IDLE,
        AR_WAIT_RESP
    } ar_state_t;

    typedef enum logic {
        R_IDLE,
        R_ACTIVE
    } r_state_t;

    aw_state_t aw_state;
    w_state_t  w_state;
    b_state_t  b_state;
    ar_state_t ar_state;
    r_state_t  r_state;

   
    // Internal Registers
   
    logic [31:0] awaddr_reg;
    logic [31:0] wdata_reg;
    logic [3:0]  wstrb_reg;
    logic [31:0] araddr_reg;

   
    // Write Address Channel (AW)

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_state   <= AW_IDLE;
            awready    <= 1'b1;
            awaddr_reg <= 32'h0;
        end
        else begin
            case (aw_state)

                AW_IDLE: begin
                    awready <= 1'b1;

                    if (awvalid && awready) begin
                        awaddr_reg <= awaddr;
                        awready    <= 1'b0;
                        aw_state   <= AW_WAIT_RESP;
                    end
                end

                AW_WAIT_RESP: begin
                    awready <= 1'b0;

                    if (bvalid && bready) begin
                        awready  <= 1'b1;
                        aw_state <= AW_IDLE;
                    end
                end

                default: begin
                    awready  <= 1'b1;
                    aw_state <= AW_IDLE;
                end

            endcase
        end
    end

  
    // Write Data Channel (W)

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state   <= W_IDLE;
            wready    <= 1'b1;
            wdata_reg <= 32'h0;
            wstrb_reg <= 4'h0;
        end
        else begin
            case (w_state)

                W_IDLE: begin
                    wready <= 1'b1;

                    if (wvalid && wready) begin
                        wdata_reg <= wdata;
                        wstrb_reg <= wstrb;
                        wready    <= 1'b0;
                        w_state   <= W_WAIT_RESP;
                    end
                end

                W_WAIT_RESP: begin
                    wready <= 1'b0;

                    if (bvalid && bready) begin
                        wready  <= 1'b1;
                        w_state <= W_IDLE;
                    end
                end

                default: begin
                    wready  <= 1'b1;
                    w_state <= W_IDLE;
                end

            endcase
        end
    end

   
    // Write Response Channel (B) and Write Execution

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            b_state       <= B_IDLE;
            bvalid        <= 1'b0;
            bresp         <= 2'b00;
            spi_ctrl      <= 32'h0;
            tx_fifo_we    <= 1'b0;
            tx_fifo_wdata <= 8'h0;
        end
        else begin

            // Default: TX FIFO write enable is a one-cycle pulse
            tx_fifo_we <= 1'b0;

            case (b_state)

                B_IDLE: begin
                    bvalid <= 1'b0;

                    // Both AW and W transactions have been received
                    if ((aw_state == AW_WAIT_RESP) &&
                        (w_state  == W_WAIT_RESP)) begin

                        bvalid  <= 1'b1;
                        bresp   <= 2'b00;       // OKAY
                        b_state <= B_ACTIVE;

                        case (awaddr_reg[7:0])

                            // SPI Control Register
                            8'h00: begin

                                if (wstrb_reg[0])
                                    spi_ctrl[7:0] <= wdata_reg[7:0];

                                if (wstrb_reg[1])
                                    spi_ctrl[15:8] <= wdata_reg[15:8];

                                if (wstrb_reg[2])
                                    spi_ctrl[23:16] <= wdata_reg[23:16];

                                if (wstrb_reg[3])
                                    spi_ctrl[31:24] <= wdata_reg[31:24];

                            end

                            // TX FIFO
                            8'h08: begin

                                if (wstrb_reg[0]) begin
                                    tx_fifo_wdata <= wdata_reg[7:0];
                                    tx_fifo_we    <= 1'b1;
                                end
                                else begin
                                    bresp <= 2'b10; // SLVERR
                                end

                            end


                            // Invalid Address
                            default: begin
                                bresp <= 2'b10;     // SLVERR
                            end

                        endcase
                    end
                end

                B_ACTIVE: begin

                    if (bvalid && bready) begin
                        bvalid  <= 1'b0;
                        b_state <= B_IDLE;
                    end

                end

                default: begin
                    bvalid  <= 1'b0;
                    b_state <= B_IDLE;
                end

            endcase
        end
    end

 
    // Read Address Channel (AR)
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ar_state   <= AR_IDLE;
            arready    <= 1'b1;
            araddr_reg <= 32'h0;
        end
        else begin
            case (ar_state)

                AR_IDLE: begin
                    arready <= 1'b1;

                    if (arvalid && arready) begin
                        araddr_reg <= araddr;
                        arready    <= 1'b0;
                        ar_state   <= AR_WAIT_RESP;
                    end
                end

                AR_WAIT_RESP: begin
                    arready <= 1'b0;

                    if (rvalid && rready) begin
                        arready  <= 1'b1;
                        ar_state <= AR_IDLE;
                    end
                end

                default: begin
                    arready  <= 1'b1;
                    ar_state <= AR_IDLE;
                end

            endcase
        end
    end


    // Read Data Channel (R) and Read Execution

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state <= R_IDLE;
            rvalid  <= 1'b0;
            rresp   <= 2'b00;
            rdata   <= 32'h0;
        end
        else begin

            case (r_state)

                R_IDLE: begin
                    rvalid <= 1'b0;

                    // Address has been accepted
                    if (ar_state == AR_WAIT_RESP) begin

                        rvalid  <= 1'b1;
                        rresp   <= 2'b00;       // OKAY
                        r_state <= R_ACTIVE;

                        case (araddr_reg[7:0])


                            // SPI Control Register
                            8'h00: begin
                                rdata <= spi_ctrl;
                            end


                            // SPI Status Register
                            8'h04: begin
                                rdata <= spi_stat;
                            end


                            // RX FIFO
                            // Assumes FWFT / show-ahead FIFO
                            8'h0C: begin
                                rdata <= {24'h0, rx_fifo_rdata};
                            end

                            // Invalid Address
                            default: begin
                                rdata <= 32'h0;
                                rresp <= 2'b10;     // SLVERR
                            end

                        endcase
                    end
                end

                R_ACTIVE: begin

                    if (rvalid && rready) begin
                        rvalid  <= 1'b0;
                        r_state <= R_IDLE;
                    end

                end

                default: begin
                    rvalid  <= 1'b0;
                    r_state <= R_IDLE;
                end

            endcase
        end
    end

    // RX FIFO Read Enable

    always_comb begin

        rx_fifo_re = 1'b0;

        if ((r_state == R_ACTIVE) &&
            rvalid &&
            rready &&
            (araddr_reg[7:0] == 8'h0C)) begin

            rx_fifo_re = 1'b1;

        end

    end

endmodule
