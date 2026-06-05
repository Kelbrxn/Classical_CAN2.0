/* verilator lint_off MULTITOP */
`timescale 1ns / 1ps

module can_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,
    
    // --- AXI4-Lite Interface ---
    input  logic [ADDRESS-1:0]    s_axi_araddr,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,
    input  logic                  s_axi_rready,
    output logic                  s_axi_rvalid,
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    input  logic [ADDRESS-1:0]    s_axi_awaddr,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,
    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic                  s_axi_wvalid,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    output logic                  s_axi_wready,
    input  logic                  s_axi_bready,
    output logic                  s_axi_bvalid,
    output logic [1:0]            s_axi_bresp,
    
    // --- Physical Layer ---
    output logic                  irq_out,      
    input  logic                  can_rx_pad,   
    output logic                  can_tx_pad    
);
    // Internal Native Bus (Driven by AXI Slave)
    wire [ADDRESS-1:0]    bus_addr;
    wire [DATA_WIDTH-1:0] bus_wr_data;
    wire                  bus_wr_e;
    wire                  bus_rd_e;
    wire [DATA_WIDTH-1:0] bus_rd_data;

    // AXI4-Lite Slave Wrapper Instantiation
    axi4_lite_slave #(
        .ADDRESS(ADDRESS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_axi_slave (
        .ACLK(clk), .ARESETn(rst_n),
        .ARADDR(s_axi_araddr), .ARVALID(s_axi_arvalid), .ARREADY(s_axi_arready),
        .RREADY(s_axi_rready), .RVALID(s_axi_rvalid), .RDATA(s_axi_rdata), .RRESP(s_axi_rresp),
        .AWADDR(s_axi_awaddr), .AWVALID(s_axi_awvalid), .AWREADY(s_axi_awready),
        .WDATA(s_axi_wdata), .WVALID(s_axi_wvalid), .WSTRB(s_axi_wstrb), .WREADY(s_axi_wready),
        .BREADY(s_axi_bready), .BVALID(s_axi_bvalid), .BRESP(s_axi_bresp),
        .ip_addr(bus_addr), .ip_wdata(bus_wr_data), .ip_write_en(bus_wr_e),
        .ip_read_en(bus_rd_e), .ip_rdata(bus_rd_data)
    );

    // Internal Chip Selects from Address Decoder
    wire cs_regs, cs_af_bank, cs_tx_mailbox, cs_rx_fifo;

    address_decoder u_decoder (
        .addr(bus_addr), .cs_regs(cs_regs), .cs_af_bank(cs_af_bank),
        .cs_tx_mailbox(cs_tx_mailbox), .cs_rx_fifo(cs_rx_fifo)
    );

    // Internal System Wires
    wire soft_reset, core_is_config, core_is_normal;
    wire rx_bit_clean, rx_bit_to_core, tx_bit_from_fsm;
    wire rx_bit_destuffed, tx_bit_stuffed;
    wire [31:0] btr_reg, f_btr_reg, brpr_reg, f_brpr_reg;
    wire sample_point_en, bit_done_en;
    wire [31:0] mode_reg;
    wire mode_loopback, mode_silent;
    wire tx_trigger_pulse, inc_read_index_pulse;
    wire accept_frame_wire, tx_done_wire, rx_done_wire;
    logic tx_err_pulse, rx_err_pulse; 
    wire err_passive_flag, err_bus_off_flag;
    logic arb_lost_pulse, crc_err_pulse;
    wire [7:0] tec_wire, rec_wire;
    wire crc_clear_wire, crc_enable_wire;
    wire [14:0] crc_out_wire;
    
    wire [4:0]  tx_addr_core;
    wire [31:0] tx_dout_core;
    wire        tx_ready;
    wire        we_core;
    wire [9:0]  rx_addr_core;
    wire [31:0] din_core;
    wire [31:0] rx_fsr_status;

    assign mode_loopback = mode_reg[1];
    assign mode_silent   = mode_reg[2];

    // Read Data Mux: OR together the outputs of all memory/register sub-modules
    wire [31:0] rd_data_regs, rd_data_intr, rd_data_af, rd_data_tx, rd_data_rx;
    assign bus_rd_data = rd_data_regs | rd_data_intr | rd_data_af | rd_data_tx | rd_data_rx;

    // ----------------------------------------------------------------
    // INTERNAL SUB-MODULE INSTANTIATIONS
    // ----------------------------------------------------------------

    can_bus_conditioner u_conditioner (
        .clk(clk), .rst_n(rst_n), .async_rx_pad_in(can_rx_pad), .rx_bit_clean(rx_bit_clean)
    );

    can_routing_matrix u_routing (
        .mode_loopback(mode_loopback), .mode_silent(mode_silent),
        .rx_bit_clean(rx_bit_clean), .tx_bit_from_fsm(tx_bit_stuffed),
        .tx_pad_out(can_tx_pad), .rx_bit_to_core(rx_bit_to_core)
    );

    assign rx_bit_destuffed = rx_bit_to_core; 
    assign tx_bit_from_fsm  = tx_bit_stuffed; 

    can_register_bank u_reg_bank (
        .clk(clk), .rst_n(rst_n), .
