module crc15_lfsr (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,   
    input  logic        enable,  
    input  logic        data_in, 
    output logic [14:0] crc_out  
);
    logic [14:0] crc_reg;
    wire         feedback;
    assign feedback = data_in ^ crc_reg[14];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) crc_reg <= 15'h0000;
        else if (clear) crc_reg <= 15'h0000;
        else if (enable) begin      
            crc_reg[0]  <= feedback;
            crc_reg[1]  <= crc_reg[0];
            crc_reg[2]  <= crc_reg[1];
            crc_reg[3]  <= crc_reg[2]  ^ feedback; 
            crc_reg[4]  <= crc_reg[3]  ^ feedback; 
            crc_reg[5]  <= crc_reg[4];
            crc_reg[6]  <= crc_reg[5];
            crc_reg[7]  <= crc_reg[6]  ^ feedback; 
            crc_reg[8]  <= crc_reg[7]  ^ feedback; 
            crc_reg[9]  <= crc_reg[8];
            crc_reg[10] <= crc_reg[9]  ^ feedback; 
            crc_reg[11] <= crc_reg[10];
            crc_reg[12] <= crc_reg[11];
            crc_reg[13] <= crc_reg[12];
            crc_reg[14] <= crc_reg[13] ^ feedback; 
        end
    end
    assign crc_out = crc_reg;
endmodule
