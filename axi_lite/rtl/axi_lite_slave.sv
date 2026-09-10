`timescale 1ns/1ps

module axi_lite_slave #(
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 4
)(
    input  logic                          s_axi_aclk,
    input  logic                          s_axi_aresetn,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                          s_axi_awvalid,
    output logic                          s_axi_awready,

    input  logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                          s_axi_wvalid,
    output logic                          s_axi_wready,

    output logic [1:0]                    s_axi_bresp,
    output logic                          s_axi_bvalid,
    input  logic                          s_axi_bready,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                          s_axi_arvalid,
    output logic                          s_axi_arready,

    output logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                    s_axi_rresp,
    output logic                          s_axi_rvalid,
    input  logic                          s_axi_rready,

    output logic                          ctrl_start_tx,
    input  logic                          status_tx_busy,
    input  logic                          status_rx_valid,
    output logic [7:0]                    tx_data,
    input  logic [7:0]                    rx_data
);

    localparam logic [1:0] ADDR_CTRL   = 2'b00;
    localparam logic [1:0] ADDR_STATUS = 2'b01;
    localparam logic [1:0] ADDR_DATA   = 2'b10;

    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic                          axi_awready;
    logic                          axi_wready;
    logic [1:0]                    axi_bresp;
    logic                          axi_bvalid;
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    logic                          axi_arready;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    logic [1:0]                    axi_rresp;
    logic                          axi_rvalid;

    logic [C_S_AXI_DATA_WIDTH-1:0] reg_ctrl;
    logic [C_S_AXI_DATA_WIDTH-1:0] reg_status;
    logic [C_S_AXI_DATA_WIDTH-1:0] reg_data;

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp;
    assign s_axi_bvalid  = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata   = axi_rdata;
    assign s_axi_rresp   = axi_rresp;
    assign s_axi_rvalid  = axi_rvalid;

    assign ctrl_start_tx = reg_ctrl[0];
    assign tx_data       = reg_data[7:0];

    always_comb begin
        reg_status = '0;
        reg_status[0] = status_tx_busy;
        reg_status[1] = status_rx_valid;
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            axi_awready <= 1'b0;
            axi_awaddr  <= '0;
        end else begin
            if (!axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                axi_awready <= 1'b1;
                axi_awaddr  <= s_axi_awaddr;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            axi_wready <= 1'b0;
        end else begin
            if (!axi_wready && s_axi_wvalid && s_axi_awvalid) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            reg_ctrl <= '0;
            reg_data <= '0;
        end else begin
            if (reg_ctrl[0]) begin
                reg_ctrl[0] <= 1'b0;
            end

            if (axi_awready && s_axi_awvalid && axi_wready && s_axi_wvalid) begin
                case (axi_awaddr[3:2])
                    ADDR_CTRL: begin
                        for (int byte_index = 0; byte_index < (C_S_AXI_DATA_WIDTH/8); byte_index++) begin
                            if (s_axi_wstrb[byte_index]) begin
                                reg_ctrl[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                            end
                        end
                    end
                    ADDR_DATA: begin
                        for (int byte_index = 0; byte_index < (C_S_AXI_DATA_WIDTH/8); byte_index++) begin
                            if (s_axi_wstrb[byte_index]) begin
                                reg_data[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                            end
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (axi_awready && s_axi_awvalid && axi_wready && s_axi_wvalid && !axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00;
            end else if (s_axi_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            axi_arready <= 1'b0;
            axi_araddr  <= '0;
        end else begin
            if (!axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
                axi_araddr  <= s_axi_araddr;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
            axi_rdata  <= '0;
        end else begin
            if (axi_arready && s_axi_arvalid && !axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00;
                case (axi_araddr[3:2])
                    ADDR_CTRL:   axi_rdata <= reg_ctrl;
                    ADDR_STATUS: axi_rdata <= reg_status;
                    ADDR_DATA:   axi_rdata <= {24'h000000, rx_data};
                    default:     axi_rdata <= '0;
                endcase
            end else if (s_axi_rready && axi_rvalid) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
