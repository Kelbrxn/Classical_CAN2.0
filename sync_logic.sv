module sync_logic (
    input  logic       clk,
    input  logic       rst_n,
    
    // Physical CAN Bus
    input  logic       rx_pin,
    
    // From Bit Timing Module
    input  logic       bit_done_en,
    input  logic [7:0] current_seg_count,
    
    // From Register Bank (Raw 32-bit registers)
    input  logic [31:0] reg_btr,         // Nominal Bit Timing (BTR)
    input  logic [31:0] reg_f_btr,       // Data Bit Timing (F_BTR)
    
    // From Protocol FSM
    input  logic       is_idle,          // 1 when bus is IDLE (allows Hard Sync)
    input  logic       is_data_phase,    // Gear shift flag
    
    // Outputs to Bit Timing Module
    output logic       sync_restart,
    output logic [7:0] tseg1_modifier,
    output logic [7:0] tseg2_modifier
);

    // --- 1. Xilinx Register Decoding ---
    logic [7:0] tseg1, tseg2, active_sjw;

    // Decode BTR based on active gear (Classical vs FD)
    always_comb begin
        if (is_data_phase) begin
            tseg1      = {2'b0, reg_f_btr[5:0]};
            tseg2      = {4'b0, reg_f_btr[11:8]};
            // Xilinx FD SJW is bits [19:16]. Add 1 for actual TQ value.
            active_sjw = {4'b0, reg_f_btr[19:16]} + 8'd1; 
        end else begin
            tseg1      = {4'b0, reg_btr[3:0]};
            tseg2      = {5'b0, reg_btr[6:4]};
            // Xilinx Classical SJW is bits [8:7]. Add 1 for actual TQ value.
            active_sjw = {6'b0, reg_btr[8:7]} + 8'd1;
        end
    end

    // --- 2. FSM State Declarations ---
    typedef enum logic [1:0] {
        IDLE       = 2'b00,
        HARD_SYNC  = 2'b01,
        LATE_EDGE  = 2'b10,
        EARLY_EDGE = 2'b11
    } state_t;

    state_t state;

    // --- 3. Internal Signals ---
    logic [2:0] rx_sync;
    logic       edge_detected;
    logic [7:0] phase_error_early;
    logic [7:0] total_bit_len;

    // --- 4. Synchronizer & Edge Detector ---
    // Triple-flop to prevent metastability and detect Recessive -> Dominant (1->0)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            rx_sync <= 3'b111;
        else 
            rx_sync <= {rx_sync[1:0], rx_pin};
    end
    assign edge_detected = (rx_sync[2] == 1'b1 && rx_sync[1] == 1'b0);

    // --- 5. Combinational Math Setup ---
    // Total bit length in counter ticks (Sync_Seg + TSEG1 + TSEG2)
    // Formula: 1 (Sync) + (tseg1 + 1) + (tseg2 + 1) = tseg1 + tseg2 + 3
    assign total_bit_len     = tseg1 + tseg2 + 8'd3;
    assign phase_error_early = total_bit_len - current_seg_count;

    // --- 6. The FSM Core ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            sync_restart   <= 1'b0;
            tseg1_modifier <= 8'd0;
            tseg2_modifier <= 8'd0;
        end else begin
            // Default pulse behavior
            sync_restart <= 1'b0;

            case (state)
                IDLE: begin
                    // Ensure modifiers are cleared while waiting for edges
                    tseg1_modifier <= 8'd0;
                    tseg2_modifier <= 8'd0;
                    
                    if (edge_detected) begin
                        if (is_idle) begin
                            state <= HARD_SYNC;
                            
                        end else if (current_seg_count > 8'd0 && current_seg_count <= (tseg1 + 8'd1)) begin
                            // LATE EDGE (Occurred in TSEG1, before or on Sample Point)
                            state <= LATE_EDGE;
                            // Stretch TSEG1 by min(phase_error, SJW)
                            tseg1_modifier <= (current_seg_count < active_sjw) ? current_seg_count : active_sjw;
                            
                        end else if (current_seg_count > (tseg1 + 8'd1)) begin
                            // EARLY EDGE (Occurred in TSEG2, after Sample Point)
                            state <= EARLY_EDGE;
                            // Shrink TSEG2 by min(phase_error, SJW)
                            tseg2_modifier <= (phase_error_early < active_sjw) ? phase_error_early : active_sjw;
                        end
                    end
                end

                HARD_SYNC: begin
                    // Pulse the reset line to the Bit Timing module
                    sync_restart <= 1'b1;
                    state        <= IDLE;
                end

                LATE_EDGE: begin
                    // STATE LOCKOUT: Hold modifier steady until end of bit
                    if (bit_done_en) begin
                        tseg1_modifier <= 8'd0;
                        state          <= IDLE;
                    end
                end

                EARLY_EDGE: begin
                    // STATE LOCKOUT: Hold modifier steady until end of bit
                    if (bit_done_en) begin
                        tseg2_modifier <= 8'd0;
                        state          <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
