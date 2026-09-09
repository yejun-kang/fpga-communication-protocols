`timescale 1ns/1ps

module i2c_master #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int I2C_FREQ = 1_000_000
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [6:0] slave_addr,
    input  logic       rw,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       ready,
    output logic       done,
    output logic       ack_error,
    inout  wire        scl,
    inout  wire        sda
);

    localparam int OVERSAMPLE_FACTOR = 4;
    localparam int CLK_DIVIDER       = CLK_FREQ / (I2C_FREQ * OVERSAMPLE_FACTOR);

    logic [$clog2(CLK_DIVIDER > 1 ? CLK_DIVIDER : 2)-1:0] clk_cnt;
    logic                                                  scl_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt  <= '0;
            scl_tick <= 1'b0;
        end else if (clk_cnt >= CLK_DIVIDER - 1) begin
            clk_cnt  <= '0;
            scl_tick <= 1'b1;
        end else begin
            clk_cnt  <= clk_cnt + 1'b1;
            scl_tick <= 1'b0;
        end
    end

    typedef enum logic [3:0] {
        ST_IDLE      = 4'b0000,
        ST_START     = 4'b0001,
        ST_ADDR      = 4'b0010,
        ST_ADDR_ACK  = 4'b0011,
        ST_WRITE     = 4'b0100,
        ST_WRITE_ACK = 4'b0101,
        ST_READ      = 4'b0110,
        ST_READ_ACK  = 4'b0111,
        ST_STOP      = 4'b1000
    } state_e;

    state_e state;

    logic scl_oe;
    logic sda_oe;

    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;
    logic [1:0] sub_state;

    assign scl = scl_oe ? 1'b0 : 1'bz;
    assign sda = sda_oe ? 1'b0 : 1'bz;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            scl_oe    <= 1'b0;
            sda_oe    <= 1'b0;
            ready     <= 1'b1;
            done      <= 1'b0;
            ack_error <= 1'b0;
            rx_data   <= '0;
            shift_reg <= '0;
            bit_cnt   <= '0;
            sub_state <= '0;
        end else begin
            done <= 1'b0;

            if (scl_tick) begin
                sub_state <= sub_state + 1'b1;

                case (state)
                    ST_IDLE: begin
                        ready     <= 1'b1;
                        scl_oe    <= 1'b0;
                        sda_oe    <= 1'b0;
                        sub_state <= '0;

                        if (start) begin
                            ready     <= 1'b0;
                            ack_error <= 1'b0;
                            shift_reg <= {slave_addr, rw};
                            bit_cnt   <= 3'd7;
                            state     <= ST_START;
                        end
                    end

                    ST_START: begin
                        case (sub_state)
                            2'b00: begin sda_oe <= 1'b1; scl_oe <= 1'b0; end
                            2'b01: begin sda_oe <= 1'b1; scl_oe <= 1'b0; end
                            2'b10: begin sda_oe <= 1'b1; scl_oe <= 1'b1; end
                            2'b11: begin
                                sda_oe    <= (shift_reg[bit_cnt] == 1'b0);
                                state     <= ST_ADDR;
                                sub_state <= '0;
                            end
                        endcase
                    end

                    ST_ADDR: begin
                        case (sub_state)
                            2'b00: scl_oe <= 1'b1;
                            2'b01: scl_oe <= 1'b0;
                            2'b10: scl_oe <= 1'b0;
                            2'b11: begin
                                scl_oe <= 1'b1;
                                if (bit_cnt == 0) begin
                                    sda_oe <= 1'b0;
                                    state  <= ST_ADDR_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt - 1'b1;
                                    sda_oe  <= (shift_reg[bit_cnt - 1'b1] == 1'b0);
                                end
                            end
                        endcase
                    end

                    ST_ADDR_ACK: begin
                        case (sub_state)
                            2'b00: scl_oe <= 1'b1;
                            2'b01: begin
                                scl_oe <= 1'b0;
                                if (sda == 1'b1) begin
                                    ack_error <= 1'b1;
                                end
                            end
                            2'b10: scl_oe <= 1'b0;
                            2'b11: begin
                                scl_oe  <= 1'b1;
                                bit_cnt <= 3'd7;
                                if (ack_error || sda == 1'b1) begin
                                    state <= ST_STOP;
                                end else if (rw == 1'b0) begin
                                    shift_reg <= tx_data;
                                    sda_oe    <= (tx_data[7] == 1'b0);
                                    state     <= ST_WRITE;
                                end else begin
                                    sda_oe <= 1'b0;
                                    state  <= ST_READ;
                                end
                            end
                        endcase
                    end

                    ST_WRITE: begin
                        case (sub_state)
                            2'b00: scl_oe <= 1'b1;
                            2'b01: scl_oe <= 1'b0;
                            2 me: scl_oe <= 1'b0;
                            2'b10: scl_oe <= 1'b0;
                            2'b11: begin
                                scl_oe <= 1'b1;
                                if (bit_cnt == 0) begin
                                    sda_oe <= 1'b0;
                                    state  <= ST_WRITE_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt - 1'b1;
                                    sda_oe  <= (shift_reg[bit_cnt - 1'b1] == 1'b0);
                                end
                            end
                        endcase
                    end

                    ST_WRITE_ACK: begin
                        case (sub_state)
                            2'b00: scl_oe <= 1'b1;
                            2'b01: begin
                                scl_oe <= 1'b0;
                                if (sda == 1'b1) begin
                                    ack_error <= 1'b1;
                                end
                            end
                            2'b10: scl_oe <= 1'b0;
                            2'b11: begin
                                scl_oe <= 1'b1;
                                state  <= ST_STOP;
                            end
                        endcase
                    end

                    ST_READ: begin
                        case (sub_state)
                            2'b00: scl_oe <= 1'b1;
                            2'b01: begin
                                scl_oe <= 1'b0;
                                shift_reg[bit_cnt] <= sda;
                            end
                            2'b10: scl_oe <= 1'b0;
                            2'b11: begin
                                scl_oe <= 1'b1;
                                if (bit_cnt == 0) begin
                                    rx_data <= {shift_reg[7:1], sda};
                                    sda_oe  <= 1'b1;
                                    state   <= ST_READ_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt - 1'b1;
                                end
                            end
                        endcase
                    end

                    ST_READ_ACK: begin
                        case (sub_state)
                            2'b00: scl_oe <= 1'b1;
                            2'b01: scl_oe <= 1 me: scl_oe <= 1'b0;
                            2'b01: scl_oe <= 1'b0;
                            2'b10: scl_oe <= 1'b0;
                            2'b11: begin
                                scl_oe <= 1'b1;
                                sda_oe <= 1'b0;
                                state  <= ST_STOP;
                            end
                        endcase
                    end

                    ST_STOP: begin
                        case (sub_state)
                            2'b00: begin sda_oe <= 1'b1; scl_oe <= 1'b1; end
                            2'b01: begin sda_oe <= 1'b1; scl_oe <= 1'b0; end
                            2'b10: begin sda_oe <= 1'b0; scl_oe <= 1'b0; end
                            2'b11: begin
                                done  <= 1'b1;
                                ready <= 1'b1;
                                state <= ST_IDLE;
                            end
                        endcase
                    end

                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
