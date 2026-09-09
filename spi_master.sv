`timescale 1ns / 1ps

module spi_master #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int SPI_SCLK  = 10_000_000
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        start,
    input  logic [1:0]  mode,
    input  logic [15:0] byte_count,
    output logic        busy,
    output logic        done,

    input  logic [7:0]  tx_data,
    output logic        tx_ready,
    output logic [7:0]  rx_data,
    output logic        rx_valid,

    output logic        sclk,
    output logic        cs_n,
    output logic        mosi,
    input  logic        miso
);

    logic cpol, cpha;
    assign cpol = mode[1];
    assign cpha = mode[0];

    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        SETUP_CS  = 3'b001,
        TRANSFER  = 3'b010,
        NEXT_BYTE = 3'b011,
        HOLD_CS   = 3'b100,
        DONE_ST   = 3'b101
    } state_t;

    state_t state;

    localparam int CLK_DIV   = CLK_FREQ / (2 * SPI_SCLK);
    localparam int DIV_WIDTH = $clog2(CLK_DIV);

    logic [DIV_WIDTH-1:0] clk_cnt;
    logic                 sclk_tick;
    logic                 sclk_reg;
    logic [4:0]           edge_cnt;

    logic [15:0] bytes_rem;
    logic [7:0]  tx_shift;
    logic [7:0]  rx_shift;
    logic        cs_n_reg;
    logic        mosi_reg;

    assign sclk = sclk_reg;
    assign cs_n = cs_n_reg;
    assign mosi = mosi_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt   <= '0;
            sclk_tick <= 1'b0;
        end else if (state == SETUP_CS || state == TRANSFER || state == NEXT_BYTE || state == HOLD_CS) begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt   <= '0;
                sclk_tick <= 1'b1;
            end else begin
                clk_cnt   <= clk_cnt + 1'b1;
                sclk_tick <= 1'b0;
            end
        end else begin
            clk_cnt   <= '0;
            sclk_tick <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            sclk_reg  <= 1'b0;
            cs_n_reg  <= 1'b1;
            mosi_reg  <= 1'b0;
            busy      <= 1'b0;
            done      <= 1'b0;
            tx_ready  <= 1'b0;
            rx_valid  <= 1'b0;
            rx_data   <= 8'h00;
            edge_cnt  <= '0;
            bytes_rem <= '0;
            tx_shift  <= 8'h00;
            rx_shift  <= 8'h00;
        end else begin
            done     <= 1'b0;
            rx_valid <= 1'b0;
            tx_ready <= 1'b0;

            case (state)
                IDLE: begin
                    cs_n_reg <= 1'b1;
                    busy     <= 1'b0;
                    mosi_reg <= 1'b0;
                    sclk_reg <= cpol;
                    if (start && (byte_count > 0)) begin
                        busy      <= 1'b1;
                        bytes_rem <= byte_count;
                        tx_shift  <= tx_data;
                        state     <= SETUP_CS;
                    end
                end

                SETUP_CS: begin
                    cs_n_reg <= 1'b0;
                    sclk_reg <= cpol;
                    edge_cnt <= '0;
                    if (cpha == 1'b0) begin
                        mosi_reg <= tx_shift[7];
                    end
                    if (sclk_tick) begin
                        tx_ready <= 1'b1;
                        state    <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (sclk_tick) begin
                        sclk_reg <= ~sclk_reg;
                        edge_cnt <= edge_cnt + 1'b1;

                        if (cpha == 1'b0) begin
                            if (edge_cnt[0] == 1'b1 && edge_cnt < 5'd15) begin
                                mosi_reg <= tx_shift[7 - ((edge_cnt + 1) >> 1)];
                            end
                            if (edge_cnt[0] == 1'b0) begin
                                rx_shift <= {rx_shift[6:0], miso};
                                if (edge_cnt == 5'd14) begin
                                    rx_data  <= {rx_shift[6:0], miso};
                                    rx_valid <= 1'b1;
                                end
                            end
                        end else begin
                            if (edge_cnt == 5'd0) begin
                                mosi_reg <= tx_shift[7];
                            end else if (edge_cnt[0] == 1'b0 && edge_cnt < 5'd14) begin
                                mosi_reg <= tx_shift[7 - (edge_cnt >> 1)];
                            end
                            if (edge_cnt[0] == 1'b1) begin
                                rx_shift <= {rx_shift[6:0], miso};
                                if (edge_cnt == 5'd15) begin
                                    rx_data  <= {rx_shift[6:0], miso};
                                    rx_valid <= 1'b1;
                                end
                            end
                        end

                        if (edge_cnt == 5'd15) begin
                            if (bytes_rem == 16'd1) begin
                                state <= HOLD_CS;
                            end else begin
                                bytes_rem <= bytes_rem - 1'b1;
                                tx_shift  <= tx_data;
                                tx_ready  <= 1'b1;
                                state     <= NEXT_BYTE;
                            end
                        end
                    end
                end

                NEXT_BYTE: begin
                    sclk_reg <= cpol;
                    edge_cnt <= '0;
                    if (cpha == 1'b0) begin
                        mosi_reg <= tx_shift[7];
                    end
                    if (sclk_tick) begin
                        state <= TRANSFER;
                    end
                end

                HOLD_CS: begin
                    sclk_reg <= cpol;
                    mosi_reg <= 1'b0;
                    if (sclk_tick) begin
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    cs_n_reg <= 1'b1;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
