module axi4_lite_slave #(
    parameter ADDRESS = 32,
    parameter DATA_WIDTH = 32
) (
    // Global signals
    input  logic ACLK,
    input  logic ARESETn,

    // AXI4-Lite Interface (Signals names kept from your original)
    input  logic [ADDRESS-1:0]    ARADDR,
    input  logic                  ARVALID,
    output logic                  ARREADY,
    input  logic                  RREADY,
    output logic                  RVALID,
    output logic [DATA_WIDTH-1:0] RDATA,
    output logic [1:0]            RRESP,
    input  logic [ADDRESS-1:0]    AWADDR,
    input  logic                  AWVALID,
    output logic                  AWREADY,
    input  logic [DATA_WIDTH-1:0] WDATA,
    input  logic                  WVALID,
    input  logic [DATA_WIDTH/8-1:0] WSTRB,
    output logic                  WREADY,
    input  logic                  BREADY,
    output logic                  BVALID,
    output logic [1:0]            BRESP,

    // --- NEW: INTERFACE TO INTERNAL IP ---
    // These signals go to your address_decoder.sv
    output logic [ADDRESS-1:0]    ip_addr,
    output logic [DATA_WIDTH-1:0] ip_wdata,
    output logic                  ip_write_en,
    output logic                  ip_read_en,
    input  logic [DATA_WIDTH-1:0] ip_rdata      // Data coming back from Core/FIFO
);

    typedef enum logic [2:0] {IDLE, WRITE_CHANNEL, WRESP_CHANNEL, READ_DATA_CHANNEL, READ_ADDR_CHANNEL} state_t;
    state_t state, next_state;

    // --- HANDSHAKE LOGIC ---
    assign AWREADY = (state == WRITE_CHANNEL);
    assign WREADY  = (state == WRITE_CHANNEL);
    assign ARREADY = (state == READ_ADDR_CHANNEL);

    // --- IP CORE INTERFACE ROUTING ---
    // We capture the address from whichever channel is active
    assign ip_addr     = (state == WRITE_CHANNEL) ? AWADDR : ARADDR;
    assign ip_wdata    = WDATA;
    
    // Enable pulses for the internal register bank
    assign ip_write_en = (state == WRITE_CHANNEL && AWVALID && WVALID);
    assign ip_read_en  = (state == READ_ADDR_CHANNEL && ARVALID);

    // Read Data Path: Directly wire the Core's output to the AXI bus
    assign RDATA  = ip_rdata; 
    assign RVALID = (state == READ_DATA_CHANNEL);
    assign RRESP  = 2'b00; // OKAY

    // Write Response Path
    assign BVALID = (state == WRESP_CHANNEL);
    assign BRESP  = 2'b00; // OKAY

    // --- STATE MACHINE ---
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) state <= IDLE;
        else          state <= next_state;
    end

    always_comb begin
        next_state = state; 
        case (state)
            IDLE: begin
                if (AWVALID)      next_state = WRITE_CHANNEL;
                else if (ARVALID) next_state = READ_ADDR_CHANNEL;
            end

            // Xilinx Driver often sends AWADDR and WDATA simultaneously
            WRITE_CHANNEL: begin
                if (AWVALID && WVALID) next_state = WRESP_CHANNEL;
            end

            WRESP_CHANNEL: begin
                if (BREADY) next_state = IDLE;
            end

            READ_ADDR_CHANNEL: begin
                if (ARVALID) next_state = READ_DATA_CHANNEL;
            end

            READ_DATA_CHANNEL: begin
                if (RREADY)  next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
endmodule
