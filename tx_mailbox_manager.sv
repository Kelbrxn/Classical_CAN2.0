module tx_mailbox_manager #(
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk_sys,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] bus_addr,
    input  logic                  bus_we,
    input  logic [DATA_WIDTH-1:0] bus_wr_data,
    output logic [DATA_WIDTH-1:0] bus_rd_data, 
    input  logic                  cs_tx,
    input  logic                  tx_trigger, 
    output logic                  tx_busy,    
    input  logic                  clk_core,
    output logic                  tx_ready,   
    input  logic                  tx_done,    
    input  logic [4:0]            addr_core,  
    output logic [DATA_WIDTH-1:0] dout_core
);
    wire [4:0]             ram_addr_axi;
    wire [DATA_WIDTH-1:0]  dout_axi;
    logic tx_toggle_sys, sync_trigger_delay, core_trigger_pulse;
    logic [1:0] sync_trigger_core;
    logic tx_done_toggle_core, sync_done_delay, sys_done_pulse;
    logic [1:0] sync_done_sys;

    assign ram_addr_axi = bus_addr[6:2]; 
    assign bus_rd_data  = dout_axi; 

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            tx_busy       <= 1'b0;
            tx_toggle_sys <= 1'b0;
        end else begin
            if (sys_done_pulse) tx_busy <= 1'b0; 
            if (tx_trigger && !tx_busy) begin
                tx_busy       <= 1'b1;         
                tx_toggle_sys <= ~tx_toggle_sys; 
            end
        end
    end

    always_ff @(posedge clk_sys) begin
        sync_done_sys   <= {sync_done_sys[0], tx_done_toggle_core};
        sync_done_delay <= sync_done_sys[1];
    end
    assign sys_done_pulse = sync_done_sys[1] ^ sync_done_delay;

    always_ff @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            tx_done_toggle_core <= 1'b0;
            tx_ready            <= 1'b0;
        end else begin
            sync_trigger_core  <= {sync_trigger_core[0], tx_toggle_sys};
            sync_trigger_delay <= sync_trigger_core[1];
            core_trigger_pulse = sync_trigger_core[1] ^ sync_trigger_delay;

            if (core_trigger_pulse) tx_ready <= 1'b1; 
            else if (tx_done) begin
                tx_ready            <= 1'b0;
                tx_done_toggle_core <= ~tx_done_toggle_core; 
            end
        end
    end

    ram_block #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(32)) mailbox_ram (
        .clk_axi(clk_sys), .we_axi(bus_we && cs_tx && !tx_busy), 
        .addr_axi(ram_addr_axi), .din_axi(bus_wr_data), .dout_axi(dout_axi),
        .clk_core(clk_core), .we_core(1'b0), .addr_core(addr_core),
        .din_core(32'h0), .dout_core(dout_core)
    );
endmodule