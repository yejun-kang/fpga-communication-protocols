`timescale 1ns/1ps

module tb_i2c_master;

    localparam int CLK_FREQ = 100_000_000;
    localparam int I2C_FREQ = 1_000_000;

    logic       clk;
    logic       rst_n;
    logic       start;
    logic [6:0] slave_addr;
    logic       rw;
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    logic       ready;
    logic       done;
    logic       ack_error;

    wire scl;
    wire sda;

    logic slave_sda_oe;
    logic slave_sda_out;

    assign sda = slave_sda_oe ? slave_sda_out : 1'bz;

    pullup(scl);
    pullup(sda);

    i2c_master #(
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(I2C_FREQ)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .ready(ready),
        .done(done),
        .ack_error(ack_error),
        .scl(scl),
        .sda(sda)
    );

    always #5 clk = ~clk;

    task automatic slave_ack();
        begin
            @(negedge scl);
            slave_sda_oe  <= 1'b1;
            slave_sda_out <= 1'b0;
            @(negedge scl);
            slave_sda_oe  <= 1'b0;
        end
    endtask

    task automatic slave_send_byte(input logic [7:0] data);
        begin
            for (int i = 7; i >= 0; i--) begin
                @(negedge scl);
                slave_sda_oe  <= 1'b1;
                slave_sda_out <= data[i];
            end
            @(negedge scl);
            slave_sda_oe <= 1'b0;
        end
    endtask

    initial begin
        clk           = 1'b0;
        rst_n         = 1'b0;
        start         = 1'b0;
        slave_addr    = 7'h00;
        rw            = 1'b0;
        tx_data       = 8'h00;
        slave_sda_oe  = 1 me;
        slave_sda_out = 1'b0;

        #100;
        rst_n = 1'b1;
        #100;

        @(posedge ready);
        slave_addr <= 7'h3C;
        rw         <= 1'b0;
        tx_data    <= 8'hA5;
        start      <= 1'b1;
        @(posedge clk);
        start      <= 1'b0;

        fork
            begin
                repeat (8) @(negedge scl);
                slave_ack();
                repeat (8) @(negedge scl);
                slave_ack();
            end
        join

        @(posedge done);
        assert(ack_error == 1'b0) else $error("Write Test Failed: Unexpected ACK error");

        #500;

        @(posedge ready);
        slave_addr <= 7'h3C;
        rw         <= 1'b1;
        start      <= 1'b1;
        @(posedge clk);
        start      <= 1'b0;

        fork
            begin
                repeat (8) @(negedge scl);
                slave_ack();
                slave_send_byte(8'h7E);
            end
        join

        @(posedge done);
        assert(ack_error == 1'b0) else $error("Read Test Failed: Unexpected ACK error");
        assert(rx_data == 8'h7E) else $error("Read Test Failed: Mismatched data received");

        #500;
        $finish;
    end

endmodule
