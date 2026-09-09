`timescale 1ns/1ps

module tb_axi_lite_slave;

    localparam int C_S_AXI_DATA_WIDTH = 32;
    localparam int C_S_AXI_ADDR_WIDTH = 4;

    logic                          s_axi_aclk;
    logic                          s_axi_aresetn;

    logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic                          s_axi_awvalid;
    logic                          s_axi_awready;

    logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    logic                          s_axi_wvalid;
    logic                          s_axi_wready;

    logic [1:0]                    s_axi_bresp;
    logic                          s_axi_bvalid;
    logic                          s_axi_bready;

    logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic                          s_axi_arvalid;
    logic                          s_axi_arready;

    logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]                    s_axi_rresp;
    logic                          s_axi_rvalid;
    logic                          s_axi_rready;

    logic                          ctrl_start_tx;
    logic                          status_tx_busy;
    logic                          status_rx_valid;
    logic [7:0]                    tx_data;
    logic [7:0]                    rx_data;
    logic                          tx_pin;

    axi_lite_slave #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_axi_slave (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .ctrl_start_tx(ctrl_start_tx),
        .status_tx_busy(status_tx_busy),
        .status_rx_valid(status_rx_valid),
        .tx_data(tx_data),
        .rx_data(rx_data)
    );

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(10_000_000)
    ) u_uart_tx (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .tx_start(ctrl_start_tx),
        .tx_data(tx_data),
        .tx_busy(status_tx_busy),
        .tx_pin(tx_pin)
    );

    always #5 s_axi_aclk = ~s_axi_aclk;

    task automatic axi_write(input logic [3:0] addr, input logic [31:0] data);
        begin
            @(posedge s_axi_aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'b1111;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            fork
                begin
                    wait (s_axi_awready);
                    @(posedge s_axi_aclk);
                    s_axi_awvalid <= 1'b0;
                end
                begin
                    wait (s_axi_wready);
                    @(posedge s_axi_aclk);
                    s_axi_wvalid <= 1'b0;
                end
            join

            wait (s_axi_bvalid);
            @(posedge s_axi_aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task automatic axi_read(input logic [3:0] addr, output logic [31:0] data);
        begin
            @(posedge s_axi_aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            wait (s_axi_arready);
            @(posedge s_axi_aclk);
            s_axi_arvalid <= 1'b0;

            wait (s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge s_axi_aclk);
            s_axi_rready <= 1'b0;
        end
    endtask

    initial begin
        logic [31:0] read_val;

        s_axi_aclk      = 1'b0;
        s_axi_aresetn   = 1'b0;
        s_axi_awaddr    = '0;
        s_axi_awvalid   = 1'b0;
        s_axi_wdata     = '0;
        s_axi_wstrb     = '0;
        s_axi_wvalid    = 1'b0;
        s_axi_bready    = 1'b0;
        s_axi_araddr    = '0;
        s_axi_arvalid   = 1'b0;
        s_axi_rready    = 1'b0;
        status_rx_valid = 1'b0;
        rx_data         = 8'h00;

        #20;
        s_axi_aresetn = 1'b1;
        #20;

        axi_write(4'h8, 32'h0000_00A5);
        axi_write(4'h0, 32'h0000_0001);

        do begin
            axi_read(4'h4, read_val);
        end while (read_val[0] == 1'b0);

        $display("[%0t ns] SUCCESS: UART transmission started, BUSY set", $time);

        do begin
            axi_read(4'h4, read_val);
        end while (read_val[0] == 1'b1);

        $display("[%0t ns] SUCCESS: UART transmission complete, BUSY cleared", $time);

        #100;
        $finish;
    end

endmodule
