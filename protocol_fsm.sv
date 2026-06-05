module protocol_fsm #(
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  soft_reset,
    input  logic                  err_passive_flag,
    output logic                  core_is_config,
    output logic                  core_is_normal,
    input  logic                  sample_point_en, 
    input  logic                  bit_done_en,     
    input  logic                  rx_bit_destuffed,
    output logic                  tx_bit_stuffed,
    input  logic                  tx_ready,
    output logic                  tx_done,
    output logic [4:0]            tx_addr_core,
    input  logic [DATA_WIDTH-1:0] tx_dout_core,
    output logic                  rx_done,
    output logic                  we_core,
    output logic [9:0]            rx_addr_core,
    output logic [DATA_WIDTH-1:0] din_core,
    output logic                  crc_clear,
    output logic                  crc_enable,
    input  logic [14:0]           crc_out
);
    typedef enum logic [1:0] {SYS_OFFLINE, SYS_ACTIVE, SYS_PASSIVE} sys_state_t;
    typedef enum logic [3:0] {
        FRAME_IDLE, FRAME_SOF, FRAME_ARB_STD, FRAME_ARB_EXT,
        FRAME_CTRL, FRAME_DATA, FRAME_CRC, FRAME_ACK, FRAME_EOF
    } frame_state_t;

    sys_state_t   sys_state;
    frame_state_t frame_state;

    logic [6:0]  bit_cnt;
    logic [31:0] tx_shift_reg;
    logic [31:0] rx_shift_reg;
    logic [14:0] tx_crc_reg;
    logic [3:0]  dlc_reg;
    logic        rtr_reg;
    
    logic [6:0] ctrl_target; 
    logic [3:0] current_dlc; 
    logic [6:0] data_target;
    logic is_tx_node, is_ext_id;
    wire  is_rx_node, is_std_id;
    
    assign is_rx_node = ~is_tx_node;
    assign is_std_id  = ~is_ext_id;

    assign core_is_config = (sys_state == SYS_OFFLINE);
    assign core_is_normal = (sys_state == SYS_ACTIVE || sys_state == SYS_PASSIVE);

    // ====================================================================
    // System State Machine 
    // ====================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sys_state <= SYS_OFFLINE;
        end else if (soft_reset) begin
            sys_state <= SYS_OFFLINE;
        end else if (err_passive_flag) begin
            sys_state <= SYS_PASSIVE; 
        end else begin
            sys_state <= SYS_ACTIVE;
        end
    end

    // ====================================================================
    // Frame State Machine
    // ====================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_state    <= FRAME_IDLE; bit_cnt <= 7'd0;
            is_tx_node     <= 1'b0; is_ext_id <= 1'b0;
            tx_bit_stuffed <= 1'b1; crc_clear <= 1'b0; crc_enable <= 1'b0;
            tx_done        <= 1'b0; rx_done <= 1'b0; we_core <= 1'b0;
            tx_addr_core   <= 5'd0; rx_addr_core <= 10'd0;
            dlc_reg        <= 4'd0; rtr_reg <= 1'b0; tx_crc_reg <= 15'd0;
            ctrl_target    <= 7'd0; current_dlc <= 4'd0; data_target <= 7'd0;
        end else begin
            crc_clear <= 1'b0; tx_done <= 1'b0; rx_done <= 1'b0; we_core <= 1'b0;

            if (sys_state == SYS_ACTIVE || sys_state == SYS_PASSIVE) begin
                case (frame_state)
                    FRAME_IDLE: begin
                        tx_bit_stuffed <= 1'b1; crc_enable <= 1'b0; 
                        if (sample_point_en && rx_bit_destuffed == 1'b0) begin
                            is_tx_node <= 1'b0; bit_cnt <= 7'd0;
                            crc_clear <= 1'b1; frame_state <= FRAME_SOF;
                        end 
                        if (bit_done_en && tx_ready && rx_bit_destuffed == 1'b1) begin
                            is_tx_node <= 1'b1; bit_cnt <= 7'd0;
                            crc_clear <= 1'b1; tx_bit_stuffed <= 1'b0; 
                            tx_addr_core <= 5'd0; frame_state <= FRAME_SOF;
                        end
                    end

                    FRAME_SOF: begin
                        crc_enable <= 1'b1; 
                        if (sample_point_en && is_rx_node && rx_bit_destuffed == 1'b1) 
                            frame_state <= FRAME_IDLE;
                        if (bit_done_en) begin
                            bit_cnt <= 7'd0;
                            if (is_tx_node) begin
                                tx_shift_reg <= tx_dout_core; tx_addr_core <= 5'd1; 
                            end
                            frame_state <= FRAME_ARB_STD;
                        end
                    end

                    FRAME_ARB_STD: begin
                        if (bit_done_en) begin
                            bit_cnt <= bit_cnt + 1'b1;
                            if (is_tx_node) begin
                                tx_bit_stuffed <= tx_shift_reg[31];
                                tx_shift_reg   <= {tx_shift_reg[30:0], 1'b0};
                            end
                            if (bit_cnt == 7'd12) begin 
                                bit_cnt <= 7'd0;
                                is_ext_id <= is_tx_node ? tx_bit_stuffed : rx_shift_reg[0];
                                if (is_tx_node ? tx_bit_stuffed : rx_shift_reg[0]) frame_state <= FRAME_ARB_EXT; 
                                else frame_state <= FRAME_CTRL; 
                            end
                        end
                        if (sample_point_en && is_rx_node) rx_shift_reg <= {rx_shift_reg[30:0], rx_bit_destuffed};
                    end

                    FRAME_ARB_EXT: begin
                        if (bit_done_en) begin
                            bit_cnt <= bit_cnt + 1'b1;
                            if (is_tx_node) begin
                                tx_bit_stuffed <= tx_shift_reg[31];
                                tx_shift_reg   <= {tx_shift_reg[30:0], 1'b0};
                            end
                            if (bit_cnt == 7'd18) begin 
                                bit_cnt <= 7'd0; rtr_reg <= is_tx_node ? tx_bit_stuffed : rx_shift_reg[0];
                                frame_state <= FRAME_CTRL; 
                            end
                        end
                        if (sample_point_en && is_rx_node) rx_shift_reg <= {rx_shift_reg[30:0], rx_bit_destuffed};
                    end

                    FRAME_CTRL: begin
                        ctrl_target = is_ext_id ? 7'd5 : 7'd4;
                        if (bit_done_en) begin
                            bit_cnt <= bit_cnt + 1'b1;
                            if (is_tx_node) begin
                                tx_bit_stuffed <= tx_shift_reg[31];
                                tx_shift_reg   <= {tx_shift_reg[30:0], 1'b0};
                            end
                            if (bit_cnt == ctrl_target) begin
                                bit_cnt <= 7'd0;
                                current_dlc = is_tx_node ? tx_shift_reg[31:28] : rx_shift_reg[3:0];
                                dlc_reg <= (current_dlc > 4'd8) ? 4'd8 : current_dlc;
                                
                                if (current_dlc == 4'd0) begin
                                    frame_state <= FRAME_CRC;  
                                    if (is_tx_node) tx_crc_reg <= crc_out; 
                                end else begin
                                    frame_state <= FRAME_DATA; 
                                    if (is_tx_node) tx_addr_core <= 5'd2;  
                                end
                            end
                        end
                        if (sample_point_en && is_rx_node) rx_shift_reg <= {rx_shift_reg[30:0], rx_bit_destuffed};
                    end

                    FRAME_DATA: begin
                        data_target = {dlc_reg, 3'd0}; 
                        if (bit_done_en) begin
                            bit_cnt <= bit_cnt + 1'b1;
                            if (is_tx_node) begin
                                tx_bit_stuffed <= tx_shift_reg[31];
                                tx_shift_reg   <= {tx_shift_reg[30:0], 1'b0};
                                if (bit_cnt[4:0] == 5'd31 && bit_cnt != (data_target - 1'b1)) begin
                                    tx_addr_core <= tx_addr_core + 1'b1;
                                    tx_shift_reg <= tx_dout_core; 
                                end
                            end 
                            if (bit_cnt == data_target - 1'b1) begin
                                bit_cnt <= 7'd0; frame_state <= FRAME_CRC;
                                if (is_tx_node) tx_crc_reg <= crc_out; 
                            end
                        end
                        if (sample_point_en && is_rx_node) begin
                            rx_shift_reg <= {rx_shift_reg[30:0], rx_bit_destuffed};
                            if (bit_cnt[4:0] == 5'd31 || bit_cnt == data_target - 1'b1) begin
                                we_core <= 1'b1; din_core <= {rx_shift_reg[30:0], rx_bit_destuffed}; 
                                rx_addr_core <= rx_addr_core + 1'b1;
                            end
                        end
                    end

                    FRAME_CRC: begin
                        crc_enable <= 1'b0; 
                        if (bit_done_en) begin
                            bit_cnt <= bit_cnt + 1'b1;
                            if (is_tx_node) begin
                                if (bit_cnt < 7'd15) begin
                                    tx_bit_stuffed <= tx_crc_reg[14];
                                    tx_crc_reg     <= {tx_crc_reg[13:0], 1'b0};
                                end else if (bit_cnt == 7'd15) tx_bit_stuffed <= 1'b1;
                            end
                            if (bit_cnt == 7'd15) begin
                                bit_cnt <= 7'd0; frame_state <= FRAME_ACK;
                            end
                        end
                        if (sample_point_en && is_rx_node && bit_cnt < 7'd15) begin
                            rx_shift_reg <= {rx_shift_reg[30:0], rx_bit_destuffed};
                            if (bit_cnt == 7'd14 && crc_out != {rx_shift_reg[13:0], rx_bit_destuffed}) 
                                frame_state <= FRAME_IDLE; 
                        end
                    end

                    FRAME_ACK: begin
                        if (bit_done_en) begin
                            bit_cnt <= bit_cnt + 1'b1;
                            if (bit_cnt == 7'd0) tx_bit_stuffed <= 1'b1; 
                            else if (bit_cnt == 7'd1) begin
                                bit_cnt <= 7'd0; frame_state <= FRAME_EOF;
                            end
                        end
                        if (sample_point_en && bit_cnt == 7'd0 && is_rx_node) tx_bit_stuffed <= 1'b0; 
                    end

                    FRAME_EOF: begin
                        if (bit_done_en) begin
                            bit_cnt <= bit_cnt + 1'b1; tx_bit_stuffed <= 1'b1; 
                            if (bit_cnt == 7'd6) begin
                                bit_cnt <= 7'd0;
                                if (is_tx_node) tx_done <= 1'b1;
                                if (is_rx_node) rx_done <= 1'b1;
                                frame_state <= FRAME_IDLE;
                            end
                        end
                    end
                    default: frame_state <= FRAME_IDLE;
                endcase
            end else frame_state <= FRAME_IDLE;
        end
    end
endmodule
