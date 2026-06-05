module can_bit_timing (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] baud_reg, 
    input  logic [31:0] btr_reg,
    output logic        sample_point_en,
    output logic        bit_done_en,
    // --- NEW SYNC LOGIC PORTS ---
    input  logic        sync_restart,
    input  logic [7:0]  tseg1_modifier,
    input  logic [7:0]  tseg2_modifier,
    output logic [7:0]  current_seg_count
);
    wire [7:0] tseg1 = btr_reg[7:0];
    wire [7:0] tseg2 = btr_reg[14:8];
    
    // Apply the modifiers from the sync_logic module dynamically
    wire [7:0] dynamic_tseg1    = tseg1 + tseg1_modifier;
    wire [7:0] dynamic_total_tq = 8'd1 + dynamic_tseg1 + (tseg2 - tseg2_modifier);

    logic [7:0] brp_cnt;
    logic       tq_pulse;

    // -------------------------------------------------------------------------
    // Prescaler: Generates Time Quanta (tq_pulse)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brp_cnt  <= 8'd0;
            tq_pulse <= 1'b0;
        end else begin
            // FIX: Hard Sync MUST reset the prescaler to ensure a full TQ!
            if (sync_restart) begin
                brp_cnt  <= 8'd0;
                tq_pulse <= 1'b1; // Start a new quantum immediately
            end else if (brp_cnt >= baud_reg[7:0]) begin
                brp_cnt  <= 8'd0;
                tq_pulse <= 1'b1;
            end else begin
                brp_cnt  <= brp_cnt + 1'b1;
                tq_pulse <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Bit Timing: Generates sample_point and bit_done
    // -------------------------------------------------------------------------
    logic [7:0] tq_cnt;
    assign current_seg_count = tq_cnt; // Export current count to sync_logic

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tq_cnt          <= 8'd0;
            sample_point_en <= 1'b0;
            bit_done_en     <= 1'b0;
        end else begin
            // Default assignments
            sample_point_en <= 1'b0;
            bit_done_en     <= 1'b0;
            
            // Hard Synchronization: immediately restart the bit time
            if (sync_restart) begin
                tq_cnt <= 8'd0; 
            end 
            else if (tq_pulse) begin
                if (tq_cnt >= (dynamic_total_tq - 1'b1)) begin
                    tq_cnt      <= 8'd0;
                    bit_done_en <= 1'b1;
                end else begin
                    tq_cnt <= tq_cnt + 1'b1;
                    
                    // Sample point shifts based on the tseg1_modifier
                    if (tq_cnt == dynamic_tseg1) begin 
                        sample_point_en <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
