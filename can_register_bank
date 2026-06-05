module can_register_bank (
    input  logic clk,
    input  logic rst_n,
    input  logic        cs_regs,
    input  logic        bus_wr_e,
    input  logic [7:0]  bus_addr,     
    input  logic [31:0] bus_wr_data,
    output logic [31:0] bus_rd_data,
    input  logic        core_is_config,
    input  logic        core_is_normal,
    input  logic        tx_busy,        
    input  logic [31:0] rx_fsr,         
    output logic        soft_reset,     
    output logic [31:0] out_mode,     
    output logic [31:0] out_baud,     
    output logic [31:0] out_btr,
    output logic [31:0] out_f_baud,
    output logic [31:0] out_f_btr,    
    output logic        tx_trigger,     
    output logic        inc_read_index  
);
    localparam XCAN_SRR_OFFSET          = 8'h00; 
    localparam XCAN_MSR_OFFSET          = 8'h04; 
    localparam XCAN_BRPR_OFFSET         = 8'h08; 
    localparam XCAN_BTR_OFFSET          = 8'h0C; 
    localparam XCAN_SR_OFFSET           = 8'h18; 
    localparam XCAN_F_BRPR_OFFSET       = 8'h88; 
    localparam XCAN_F_BTR_OFFSET        = 8'h8C; 
    localparam XCAN_TRR_OFFSET          = 8'h90; 
    localparam XCAN_FSR_OFFSET          = 8'hE8; 
    localparam XCAN_ECC_CFG_OFFSET      = 8'hC8; 
    localparam XCAN_TXTLFIFO_ECC_OFFSET = 8'hCC; 
    localparam XCAN_TXOLFIFO_ECC_OFFSET = 8'hD0; 
    localparam XCAN_RXFIFO_ECC_OFFSET   = 8'hD4; 

    

    logic [31:0] srr_reg, msr_reg, brpr_reg, btr_reg, f_brpr_reg, f_btr_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            srr_reg        <= 32'h00000001; 
            msr_reg        <= 32'h0;
            brpr_reg       <= 32'h0; 
            btr_reg        <= 32'h0;
            f_brpr_reg     <= 32'h0;
            f_btr_reg      <= 32'h0;
            tx_trigger     <= 1'b0;
            inc_read_index <= 1'b0;
        end else begin
            tx_trigger     <= 1'b0; 
            inc_read_index <= 1'b0;
            if (cs_regs & bus_wr_e) begin
                case (bus_addr)
                    XCAN_SRR_OFFSET:    srr_reg        <= bus_wr_data; 
                    XCAN_MSR_OFFSET:    msr_reg        <= bus_wr_data;
                    XCAN_BRPR_OFFSET:   brpr_reg       <= bus_wr_data;
                    XCAN_BTR_OFFSET:    btr_reg        <= bus_wr_data;
                    XCAN_F_BRPR_OFFSET: f_brpr_reg     <= bus_wr_data;
                    XCAN_F_BTR_OFFSET:  f_btr_reg      <= bus_wr_data;
                    XCAN_TRR_OFFSET:    tx_trigger     <= bus_wr_data[0]; 
                    XCAN_FSR_OFFSET:    inc_read_index <= bus_wr_data[7]; 
                    default: ;
                endcase
            end
        end
    end

    wire [31:0] status_reg_wires = {28'd0, core_is_normal, 1'b0, msr_reg[1], core_is_config};

    always_comb begin
        bus_rd_data = 32'h0;
        if (cs_regs) begin
            case (bus_addr)
                XCAN_SRR_OFFSET:    bus_rd_data = srr_reg;
                XCAN_MSR_OFFSET:    bus_rd_data = msr_reg;
                XCAN_BRPR_OFFSET:   bus_rd_data = brpr_reg;
                XCAN_BTR_OFFSET:    bus_rd_data = btr_reg;
                XCAN_SR_OFFSET:     bus_rd_data = status_reg_wires; 
                XCAN_F_BRPR_OFFSET: bus_rd_data = f_brpr_reg;
                XCAN_F_BTR_OFFSET:  bus_rd_data = f_btr_reg;
                XCAN_TRR_OFFSET:    bus_rd_data = {31'h0, tx_busy}; 
                XCAN_FSR_OFFSET:    bus_rd_data = rx_fsr;           
                XCAN_ECC_CFG_OFFSET, XCAN_TXTLFIFO_ECC_OFFSET, 
                XCAN_TXOLFIFO_ECC_OFFSET, XCAN_RXFIFO_ECC_OFFSET: bus_rd_data = 32'h0;
                default: bus_rd_data = 32'hDEADBEEF;
            endcase
        end
    end

    assign soft_reset = srr_reg[0]; 
    assign out_mode   = msr_reg;
    assign out_baud   = brpr_reg;
    assign out_btr    = btr_reg;
    assign out_f_baud = f_brpr_reg;
    assign out_f_btr  = f_btr_reg;
endmodule
