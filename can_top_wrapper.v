`timescale 1ns / 1ps

module can_top_wrapper #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // --- AXI4-Lite Interface ---
    input  wire [ADDRESS-1:0]    s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,
    input  wire                  s_axi_rready,
    output wire                  s_axi_rvalid,
    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    input  wire [ADDRESS-1:0]    s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire                  s_axi_wvalid,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    output wire                  s_axi_wready,
    input  wire                  s_axi_bready,
    output wire                  s_axi_bvalid,
    output wire [1:0]            s_axi_bresp,
    
    // --- Physical Layer ---
    output wire                  irq_out,      
    input  wire                  can_rx_pad,   
    output wire                  can_tx_pad    
);

    // Instantiate your SystemVerilog Core inside the Verilog Wrapper
    can_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRESS(ADDRESS)
    ) u_can_top (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rready(s_axi_rready),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wready(s_axi_wready),
        .s_axi_bready(s_axi_bready),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bresp(s_axi_bresp),
        .irq_out(irq_out),
        .can_rx_pad(can_rx_pad),
        .can_tx_pad(can_tx_pad)
    );

endmodule
