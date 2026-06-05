module rx_buffer_manager #(
    parameter DATA_WIDTH = 32
)(
    input  logic                  rst_n,
    input  logic                  clk_sys,
    input  logic [DATA_WIDTH-1:0] bus_addr,
    output logic [DATA_WIDTH-1:0] bus_rd_data,
    input  logic                  cs_rx,
    input  logic                  inc_read_index, 
    output logic [31:0]           rx_fsr,         
    input  logic                  clk_core,
    input  logic [9:0]            addr_core,      
    input  logic [DATA_WIDTH-1:0] din_core, 
    input  logic                  we_core,
    input  logic                  rx_done         
);
    logic [4:0] rd_ptr_sys, wr_ptr_core;  
    logic [4:0] wr_ptr_gray_core, wr_ptr_gray_sys_sync;
    logic [4:0] rd_ptr_gray_sys;
    logic [1:0] sys_sync [4:0];
    
    wire [9:0] ram_addr_axi;
    wire [31:0] shifted_addr = (bus_addr - 32'h1100) >> 2;
    assign ram_addr_axi = shifted_addr[9:0]; 

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr_sys      <= 5'h0;
            rd_ptr_gray_sys <= 5'h0;
        end else if (inc_read_index) begin
            rd_ptr_sys      <= rd_ptr_sys + 1'b1;
            rd_ptr_gray_sys <= (rd_ptr_sys + 1'b1) ^ ((rd_ptr_sys + 1'b1) >> 1);
        end
    end

    genvar i;
    generate
        for (i = 0; i < 5; i++) begin : sync_wr_ptr
            always_ff @(posedge clk_sys) sys_sync[i] <= {sys_sync[i][0], wr_ptr_gray_core[i]};
            assign wr_ptr_gray_sys_sync[i] = sys_sync[i][1];
        end
    endgenerate

    wire [4:0] wr_ptr_sys;
    assign wr_ptr_sys[4] = wr_ptr_gray_sys_sync[4];
    assign wr_ptr_sys[3] = wr_ptr_sys[4] ^ wr_ptr_gray_sys_sync[3];
    assign wr_ptr_sys[2] = wr_ptr_sys[3] ^ wr_ptr_gray_sys_sync[2];
    assign wr_ptr_sys[1] = wr_ptr_sys[2] ^ wr_ptr_gray_sys_sync[1];
    assign wr_ptr_sys[0] = wr_ptr_sys[1] ^ wr_ptr_gray_sys_sync[0];

    wire [5:0] fill_level;
    assign fill_level = wr_ptr_sys - rd_ptr_sys;
    assign rx_fsr = {18'b0, fill_level, 3'b0, rd_ptr_sys};

    always_ff @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr_core      <= 5'h0;
            wr_ptr_gray_core <= 5'h0;
        end else if (rx_done) begin
            wr_ptr_core      <= wr_ptr_core + 1'b1;
            wr_ptr_gray_core <= (wr_ptr_core + 1'b1) ^ ((wr_ptr_core + 1'b1) >> 1);
        end
    end

    ram_block #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(1024)) buffer_ram (
        .clk_axi(clk_sys), .we_axi(1'b0), .addr_axi(ram_addr_axi),
        .din_axi(32'h0), .dout_axi(bus_rd_data),
        .clk_core(clk_core), .we_core(we_core), .addr_core(addr_core),
        .din_core(din_core), .dout_core() 
    );
endmodule
