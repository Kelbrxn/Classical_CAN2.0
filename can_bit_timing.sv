module can_bit_timing (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] baud_reg, 
    input  logic [31:0] btr_reg,  
    output logic        sample_point_en,
    output logic        bit_done_en
);
    wire [7:0] tseg1 = btr_reg[7:0];
    wire [7:0] tseg2 = btr_reg[14:8];
    wire [7:0] total_tq = 8'd1 + tseg1 + tseg2; 

    logic [7:0] brp_cnt;
    logic       tq_pulse;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brp_cnt  <= 8'd0;
            tq_pulse <= 1'b0;
        end else begin
            if (brp_cnt >= baud_reg[7:0]) begin
                brp_cnt  <= 8'd0;
                tq_pulse <= 1'b1;
            end else begin
                brp_cnt  <= brp_cnt + 1'b1;
                tq_pulse <= 1'b0;
            end
        end
    end

    logic [7:0] tq_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tq_cnt          <= 8'd0;
            sample_point_en <= 1'b0;
            bit_done_en     <= 1'b0;
        end else begin
            sample_point_en <= 1'b0;
            bit_done_en     <= 1'b0;
            
            if (tq_pulse) begin
                if (tq_cnt >= (total_tq - 1'b1)) begin
                    tq_cnt      <= 8'd0;
                    bit_done_en <= 1'b1;
                end else begin
                    tq_cnt <= tq_cnt + 1'b1;
                    if (tq_cnt == tseg1) begin 
                        sample_point_en <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
