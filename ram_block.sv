module ram_block #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 256
)(
    input  logic                     clk_axi,
    input  logic                     we_axi,
    input  logic [$clog2(DEPTH)-1:0] addr_axi,
    input  logic [DATA_WIDTH-1:0]    din_axi,
    output logic [DATA_WIDTH-1:0]    dout_axi,

    input  logic                     clk_core,
    input  logic                     we_core,
    input  logic [$clog2(DEPTH)-1:0] addr_core,
    input  logic [DATA_WIDTH-1:0]    din_core,
    output logic [DATA_WIDTH-1:0]    dout_core
);
    logic [DATA_WIDTH-1:0] ram [DEPTH-1:0];

    always_ff @(posedge clk_axi) begin
        if (we_axi) ram[addr_axi] <= din_axi;
        dout_axi <= ram[addr_axi]; 
    end

    always_ff @(posedge clk_core) begin
        if (we_core) ram[addr_core] <= din_core;
        dout_core <= ram[addr_core];
    end
endmodule
