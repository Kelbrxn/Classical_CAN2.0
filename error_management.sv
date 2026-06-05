module error_management (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tx_err_pulse,   
    input  logic       rx_err_pulse,   
    input  logic       tx_ok_pulse,    
    input  logic       rx_ok_pulse,    
    output logic       err_passive_flag, 
    output logic       err_bus_off_flag, 
    input  logic       sample_point_en,  
    input  logic       rx_bit_destuffed, 
    output logic       recovery_done,    
    output logic [7:0] tec_out,
    output logic [7:0] rec_out
);
    logic [7:0] REC; 
    logic [8:0] TEC; 
    logic [3:0] bit_cnt; 
    logic [6:0] seq_cnt; 

    always_comb begin
        err_passive_flag = (TEC >= 128) || (REC >= 128); 
        err_bus_off_flag = (TEC > 255); 
    end

    assign tec_out = (TEC > 255) ? 8'd255 : TEC[7:0]; 
    assign rec_out = REC;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            REC <= 8'd0; TEC <= 9'd0;
            bit_cnt <= 4'd0; seq_cnt <= 7'd0;
            recovery_done <= 1'b0;
        end else begin
            recovery_done <= 1'b0;
            if (err_bus_off_flag) begin
                if (sample_point_en) begin
                    if (rx_bit_destuffed == 1'b1) begin
                        if (bit_cnt == 4'd10) begin 
                            bit_cnt <= 4'd0;
                            if (seq_cnt == 7'd127) begin 
                                seq_cnt <= 7'd0; TEC <= 9'd0; REC <= 8'd0;
                                recovery_done <= 1'b1; 
                            end else seq_cnt <= seq_cnt + 1'b1;
                        end else bit_cnt <= bit_cnt + 1'b1;
                    end else bit_cnt <= 4'd0;
                end
            end else begin
                if (tx_err_pulse) TEC <= (TEC + 8 > 260) ? 9'd260 : TEC + 8;
                else if (tx_ok_pulse) TEC <= (TEC > 0) ? TEC - 1'b1 : 9'd0;

                if (rx_err_pulse) REC <= (REC < 8'd255) ? REC + 1'b1 : 8'd255;
                else if (rx_ok_pulse) REC <= (REC > 0) ? REC - 1'b1 : 8'd0;
            end
        end
    end
endmodule
