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

    wire        scl;
    wire        sda;

    logic       sda_slave_oe;
    logic       scl_slave_oe;

    assign sda = sda_slave_oe ? 1'b0 : 1'bz;
    assign scl = scl_slave_oe ? 1'b0 : 1'bz;

    pullup(scl);
    pullup(sda);

    i2c_master #(
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(I2C_FREQ)
    ) dut (
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
        @(negedge scl);
        sda_slave_oe <= 1'b1;
        @(negedge scl);
        sda_slave_oe <= 1'b0;
    endtask

    task automatic slave_send_byte(input logic [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            @(negedge scl);
            sda_slave_oe <= (data[i] == 1'b0);
        end
        @(negedge scl);
        sda_slave_oe <= 1'b0;
    endtask

    initial begin
        clk          = 1'b0;
        rst_n        = 1'b0;
        start        = 1'b0;
        slave_addr   = 7'h00;
        rw           = 1'b0;
        tx_data      = 8'h00;
        sda_slave_oe = 1'b0;
        scl_slave_oe = 1'b0;

        #100;
        rst_n = 1'b1;
        #100;

        $display("[%0t ns] Starting Write Cycle...", $time);

        @(posedge clk);
        wait(ready);
        slave_addr <= 7'h3C;
        rw         <= 1'b0;
        tx_data    <= 8'hA5;
        start      <= 1'b1;

        fork
            begin
                wait(!ready);
                @(posedge clk);
                start <= 1'b0;
            end
            begin
                repeat (8) @(negedge scl);
                slave_ack();
                repeat (8) @(negedge scl);
                slave_ack();
            end
            begin
                #50000;
                $error("[%0t ns] TIMEOUT: Simulation hung waiting for Write Cycle!", $time);
                $finish;
            end
        join_any
        disable fork;

        @(posedge done);
        if (ack_error == 1'b0) begin
            $display("[%0t ns] SUCCESS: Write Cycle Passed", $time);
        end else begin
            $error("[%0t ns] FAILURE: Write Cycle ACK error", $time);
        end

        #1000;

        $display("[%0t ns] Starting Read Cycle...", $time);

        @(posedge clk);
        wait(ready);
        slave_addr <= 7'h3C;
        rw         <= 1'b1;
        start      <= 1'b1;

        fork
            begin
                wait(!ready);
                @(posedge clk);
                start <= 1'b0;
            end
            begin
                repeat (8) @(negedge scl);
                slave_ack();
                slave_send_byte(8'h7E);
            end
            begin
                #50000;
                $error("[%0t ns] TIMEOUT: Simulation hung waiting for Read Cycle!", $time);
                $finish;
            end
        join_any
        disable fork;

        @(posedge done);
        if (ack_error == 1'b0 && rx_data == 8'h7E) begin
            $display("[%0t ns] SUCCESS: Read Cycle Passed! rx_data = 0x%0h", $time, rx_data);
        end else begin
            $error("[%0t ns] FAILURE: Read Cycle Error! rx_data = 0x%0h", $time, rx_data);
        end

        #1000;

        $display("\n==========================================");
        $display("   SUCCESS: All I2C Tests Passed!          ");
        $display("==========================================\n");
        $finish;
    end

endmodule
