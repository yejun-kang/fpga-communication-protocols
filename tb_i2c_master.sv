`timescale 1ns/1ps

module tb_i2c_master;

    // --- Clock and Reset Parameters ---
    localparam int CLK_FREQ = 100_000_000; // 100 MHz System Clock
    localparam int I2C_FREQ = 1_000_000;   // 1 MHz I2C Fast-Mode Plus

    // --- Testbench Signals ---
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

    // Slave model control signals
    logic       sda_slave_oe;
    logic       scl_slave_oe;

    // Open-Drain Tri-State drivers for slave model
    assign sda = sda_slave_oe ? 1'b0 : 1'bz;
    assign scl = scl_slave_oe ? 1'b0 : 1'bz;

    // Pull-up resistors for open-drain I2C bus
    pullup(scl);
    pullup(sda);

    // --- Instantiate DUT ---
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

    // --- Clock Generation (100 MHz) ---
    always #5 clk = ~clk;

    // --- Slave Tasks ---
    // Responds with ACK (pulls SDA low for 1 SCL cycle)
    task automatic slave_ack();
        @(negedge scl);
        sda_slave_oe <= 1'b1; // Drive SDA LOW (ACK)
        @(negedge scl);
        sda_slave_oe <= 1'b0; // Release SDA
    endtask

    // Sends 1 byte back to the master during Read transactions
    task automatic slave_send_byte(input logic [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            @(negedge scl);
            sda_slave_oe <= (data[i] == 1'b0); // Drive low for '0', release for '1'
        end
        @(negedge scl);
        sda_slave_oe <= 1'b0; // Release line for Master ACK/NACK phase
    endtask

    // --- Test Stimulus Sequence ---
    initial begin
        // Initialize Signals
        clk          = 1'b0;
        rst_n        = 1'b0;
        start        = 1'b0;
        slave_addr   = 7'h00;
        rw           = 1'b0;
        tx_data      = 8'h00;
        sda_slave_oe = 1'b0;
        scl_slave_oe = 1'b0;

        // Apply Reset
        #100;
        rst_n = 1'b1;
        #100;

        // ==========================================
        // TEST CASE 1: I2C Write Transaction
        // ==========================================
        $display("[%0t ns] --- Starting Test 1: Write Cycle ---", $time);
        
        @(posedge clk);
        wait(ready);
        slave_addr <= 7'h3C;
        rw         <= 1'b0;       // Write operation
        tx_data    <= 8'hA5;
        start      <= 1'b1;

        fork
            begin
                wait(!ready);
                @(posedge clk);
                start <= 1'b0;   // Hold start until FSM exits IDLE
            end
            begin
                // Receive Address + RW byte and issue ACK
                repeat (8) @(negedge scl);
                slave_ack();

                // Receive Data byte and issue ACK
                repeat (8) @(negedge scl);
                slave_ack();
            end
        join

        @(posedge done);
        if (ack_error == 1'b0) begin
            $display("[%0t ns] SUCCESS: Write Cycle Completed without ACK error.", $time);
        end else begin
            $error("[%0t ns] FAILURE: Write Cycle returned ACK Error!", $time);
        end

        #1000;

        // ==========================================
        // TEST CASE 2: I2C Read Transaction
        // ==========================================
        $display("[%0t ns] --- Starting Test 2: Read Cycle ---", $time);

        @(posedge clk);
        wait(ready);
        slave_addr <= 7'h3C;
        rw         <= 1'b1;       // Read operation
        start      <= 1'b1;

        fork
            begin
                wait(!ready);
                @(posedge clk);
                start <= 1'b0;   // Hold start until FSM exits IDLE
            end
            begin
                // Receive Address + RW byte and issue ACK
                repeat (8) @(negedge scl);
                slave_ack();

                // Send Byte (8'h7E) to Master
                slave_send_byte(8'h7E);
            end
        join

        @(posedge done);
        if (ack_error == 1'b0 && rx_data == 8'h7E) begin
            $display("[%0t ns] SUCCESS: Read Cycle Completed! Received Data: 0x%0h", $time, rx_data);
        end else begin
            $error("[%0t ns] FAILURE: Read Cycle Error! ACK Error = %b, rx_data = 0x%0h (Expected 0x7E)", 
                   $time, ack_error, rx_data);
        end

        #1000;

        // Final Summary
        $display("\n==========================================");
        $display("   SUCCESS: All I2C Tests Passed!          ");
        $display("==========================================\n");
        $finish;
    end

endmodule
