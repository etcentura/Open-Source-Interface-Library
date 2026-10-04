module i2c_transmitter
#
(
    parameter 	CSR_WIDTH 	        = 32
)

(
    //Basic signals declaration
    input 	logic 		                        clk                             ,
    input 	logic 		                        rst_n                           ,

    //FIFO Buffer communication bus
    input 	logic 	                            fifo_valid                      ,
    input 	logic 	[7:0] 	                    fifo_data                       ,
    output 	logic 	                            fifo_read_request               ,

    //Inout i2c port
    output  logic                               i2c_bus_direction               , //0 - to slave, 1 - from slave
    output  logic                               i2c_sda_port_write              ,
    input   logic                               i2c_sda_port_read               ,
    output  logic                               i2c_scl_port                    ,
    
    //Config signals
    input 	logic 	                            csr_start_transmission          ,
    input 	logic 	                            csr_use_max_width_addr          ,
    input 	logic 	                            csr_ignore_nack                 ,
    input 	logic 	                            csr_stretch_clk_enable          ,
    input 	logic 	[CSR_WIDTH-1:0] 	        csr_stretch_clk_dur             ,
    input 	logic 	[9:0]                       csr_address_of_slave            ,
    input 	logic 	[CSR_WIDTH-1:0] 	        csr_tx_bytes_num                ,

    input 	logic 	[CSR_WIDTH-1:0] 	        csr_control_clk_gen             ,
    input 	logic 	[CSR_WIDTH-1:0] 	        csr_div_cnt_limit_clk_gen       ,
    input 	logic 	[CSR_WIDTH-1:0] 	        csr_raise_pos_clk_gen           ,
    input 	logic 	[CSR_WIDTH-1:0] 	        csr_fall_pos_clk_gen            ,

    //Status signals
    output 	logic 	                            busy_status                     ,
    output 	logic 	                            reset_required                  ,
    output 	logic 	                            address_msb_transmission_error  ,
    output 	logic 	                            address_lsb_transmission_error  ,
    output 	logic 	                            data_byte_transmission_error
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//Setup registers
logic 	                                        csr_use_max_width_addr_reg      ;
logic 	                                        csr_ignore_nack_reg             ;
logic 	                                        csr_stretch_clk_enable_reg      ;
logic 	[CSR_WIDTH-1:0] 	                    csr_stretch_clk_dur_reg         ;
logic 	[9:0] 	                                csr_address_of_slave_reg        ;
logic 	[CSR_WIDTH-1:0] 	                    csr_tx_bytes_num_reg            ;

//FSM signals
enum 	logic 	[3:0] 	                    {
                                                IDLE                            ,
                                                SYNC_BY_SCL_NEG                 ,
                                                SYNC_BY_SCL_POS                 ,
                                                SEND_ADDR_MSB                   ,
                                                SEND_ADDR_LSB                   ,
                                                SEND_DATA_BYTE                  ,
                                                STRETCH_CLK                     ,
                                                DESYNC_BY_SCL_NEG               ,
                                                DESYNC_BY_SCL_POS               ,
                                                ERROR_STATE                     
                                            } 	
                                                state, 
                                                next_state, 
                                                prev_state,
                                                jump_state                      ;

//Clock driving register
logic 	                                        clk_divider_generated_clk       ;
logic 	                                        clk_divider_generated_err       ;

//Clock sync registers
logic 	                                        clk_divider_generated_clk_reg   ;
logic 	                                        clk_divider_generated_clk_pos   ;
logic 	                                        clk_divider_generated_clk_neg   ;

//Address driving register
logic 	[7:0]                                   address_to_send_msb             ;
logic 	[7:0]                                   address_to_send_lsb             ;

//Data driving register
logic 	[7:0] 	                                byte_to_send_show               ;
logic 	[7:0] 	                                byte_to_send_shadow             ;

//Counters section
logic 	[CSR_WIDTH-1:0] 	                    cnt_bits_sent                   ;
logic 	[CSR_WIDTH-1:0] 	                    cnt_bytes_sent                  ;
logic 	[CSR_WIDTH-1:0] 	                    cnt_stretch_clk_dur             ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving setup registers section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            csr_use_max_width_addr_reg              <= '0                               ;
            csr_ignore_nack_reg                     <= '0                               ;
            csr_stretch_clk_enable_reg              <= '0                               ;
            csr_stretch_clk_dur_reg                 <= '0                               ;
            csr_address_of_slave_reg                <= '0                               ;
            csr_tx_bytes_num_reg                    <= '0                               ;
        end
    else 
        begin
            if ((state == IDLE) && (csr_start_transmission)) begin
                csr_use_max_width_addr_reg          <= csr_use_max_width_addr           ;
                csr_ignore_nack_reg                 <= csr_ignore_nack                  ;
                csr_stretch_clk_enable_reg          <= csr_stretch_clk_enable           ;
                csr_stretch_clk_dur_reg             <= csr_stretch_clk_dur              ;
                csr_address_of_slave_reg            <= csr_address_of_slave             ;
                csr_tx_bytes_num_reg                <= csr_tx_bytes_num                 ;
            end
        end
end
//End of driving setup registers section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of clk divider instancing section
clk_divider_wrapper
#
(
    .CSR_WIDTH              (CSR_WIDTH                  )
)
                            i_clk_divider_wrapper
(
    //Basic signals declaration
    .clk                    (clk                        ),
    .rst_n                  (rst_n                      ),

    //Generated clk signal
    .generated_clk          (clk_divider_generated_clk  ),
    
    //Input csr register
    .csr_control            (csr_control_clk_gen        ),
    .csr_div_cnt_limit      (csr_div_cnt_limit_clk_gen  ),
    .csr_raise_pos          (csr_raise_pos_clk_gen      ),
    .csr_fall_pos           (csr_fall_pos_clk_gen       ),

    //Status and errors signals
    .error_raise_fall       (clk_divider_generated_err  )
);
//End of clk divider instancing section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of front detector to sync by scl signal section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            clk_divider_generated_clk_reg <= '0;
        end
    else
        begin
            clk_divider_generated_clk_reg <= clk_divider_generated_clk;
        end
end

assign 	clk_divider_generated_clk_pos 	= ~clk_divider_generated_clk_reg & clk_divider_generated_clk;
assign 	clk_divider_generated_clk_neg 	= clk_divider_generated_clk_reg & ~clk_divider_generated_clk;
//End of front detector to sync by scl signal section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of fsm driving section section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            state <= IDLE;
            prev_state <= IDLE;
        end
    else
        begin
            state <= next_state;
            prev_state <= state;
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            jump_state <= IDLE;
        end
    else
        begin
            case (state)
                SEND_ADDR_MSB:
                    begin
                        if(csr_stretch_clk_enable_reg)begin
                            if(csr_use_max_width_addr_reg) begin
                                jump_state <= SEND_ADDR_LSB;
                            end
                            else begin
                                jump_state <= SEND_DATA_BYTE;
                            end
                        end
                    end
                SEND_ADDR_LSB:
                    begin
                        if(csr_stretch_clk_enable_reg)begin
                            jump_state <= SEND_DATA_BYTE;
                        end
                    end
                SEND_DATA_BYTE:
                    begin
                        if(csr_stretch_clk_enable_reg)begin
                            jump_state <= SEND_DATA_BYTE;
                        end
                    end
            endcase
        end
end


always_comb
begin
    case (state)
        IDLE:
            begin
                next_state = IDLE;
                if (csr_start_transmission) begin
                    next_state = SYNC_BY_SCL_POS;
                end
            end
        SYNC_BY_SCL_POS:
            begin
                next_state = SYNC_BY_SCL_POS;
                if(clk_divider_generated_clk_pos) begin
                    next_state = SYNC_BY_SCL_NEG;
                end
            end
        SYNC_BY_SCL_NEG:
            begin
                next_state = SYNC_BY_SCL_NEG;
                if(clk_divider_generated_clk_neg) begin
                    next_state = SEND_ADDR_MSB;
                end
            end
        SEND_ADDR_MSB:
            begin
                next_state = SEND_ADDR_MSB;
                if((clk_divider_generated_clk_neg) && (cnt_bits_sent == 8))begin
                    if(csr_ignore_nack_reg)begin
                        if(csr_stretch_clk_enable_reg)begin
                            next_state = STRETCH_CLK;
                        end
                        else begin
                            if(csr_use_max_width_addr_reg)begin
                                next_state = SEND_ADDR_LSB;
                            end
                            else begin
                                next_state = SEND_DATA_BYTE;
                            end
                        end
                    end
                    else begin
                        if(i2c_sda_port_read == '1) begin
                            next_state = ERROR_STATE;
                        end
                        else begin
                            if(csr_stretch_clk_enable_reg)begin
                                next_state = STRETCH_CLK;
                            end
                            else begin
                                if(csr_use_max_width_addr_reg)begin
                                    next_state = SEND_ADDR_LSB;
                                end
                                else begin
                                    next_state = SEND_DATA_BYTE;
                                end
                            end
                        end
                    end
                end
            end
        SEND_ADDR_LSB:
            begin
                next_state = SEND_ADDR_LSB;
                if((clk_divider_generated_clk_neg) && (cnt_bits_sent == 8))begin
                    if(csr_ignore_nack_reg)begin
                        if(csr_stretch_clk_enable_reg)begin
                            next_state = STRETCH_CLK;
                        end
                        else begin
                            next_state = SEND_DATA_BYTE;
                        end
                    end
                    else begin
                        if(i2c_sda_port_read == '1) begin
                            next_state = ERROR_STATE;
                        end
                        else begin
                            if(csr_stretch_clk_enable_reg)begin
                                next_state = STRETCH_CLK;
                            end
                            else begin
                                next_state = SEND_DATA_BYTE;
                            end
                        end
                    end
                end
            end
        SEND_DATA_BYTE:
            begin
                next_state = SEND_DATA_BYTE;
                if((clk_divider_generated_clk_neg) && (cnt_bits_sent == 8))begin
                    if(cnt_bytes_sent == csr_tx_bytes_num_reg - 1)begin
                        next_state = DESYNC_BY_SCL_POS;
                    end
                    else begin
                        if(csr_ignore_nack_reg)begin
                            if(csr_stretch_clk_enable_reg)begin
                                next_state = STRETCH_CLK;
                            end
                            else begin
                                next_state = SEND_DATA_BYTE;
                            end
                        end
                        else begin
                            if(i2c_sda_port_read == '1) begin
                                next_state = ERROR_STATE;
                            end
                            else begin
                                if(csr_stretch_clk_enable_reg)begin
                                    next_state = STRETCH_CLK;
                                end
                                else begin
                                    next_state = SEND_DATA_BYTE;
                                end
                            end
                        end
                    end
                end
            end
        STRETCH_CLK:
            begin
                next_state = STRETCH_CLK;  
                if((clk_divider_generated_clk_neg) && (cnt_stretch_clk_dur == csr_stretch_clk_dur_reg - 1))begin
                    next_state = jump_state; 
                end
            end
        DESYNC_BY_SCL_POS:
            begin
                next_state = DESYNC_BY_SCL_POS;
                if(clk_divider_generated_clk_pos)begin
                    next_state = DESYNC_BY_SCL_NEG;
                end
            end
        DESYNC_BY_SCL_NEG:
            begin
                next_state = DESYNC_BY_SCL_NEG;
                if(clk_divider_generated_clk_neg)begin
                    next_state = IDLE;
                end
            end
        ERROR_STATE:
            begin
                next_state = ERROR_STATE;
            end
        default:
            begin
                next_state = IDLE;
            end
    endcase
end
//End of fsm driving section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating read req for fifo section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            fifo_read_request <= '0;
        end
    else
        begin
            if(clk_divider_generated_clk_neg) begin
                if(csr_use_max_width_addr_reg)begin
                    if((state == SEND_ADDR_LSB) && (cnt_bits_sent == 1)) begin
                        fifo_read_request <= '1;
                    end
                    else if((state == SEND_DATA_BYTE) && (cnt_bits_sent == 1) && (cnt_bytes_sent != csr_tx_bytes_num_reg - 1))begin
                        fifo_read_request <= '1;
                    end
                end
                else begin
                    if((state == SEND_ADDR_MSB) && (cnt_bits_sent == 1)) begin
                        fifo_read_request <= '1;
                    end
                    else if((state == SEND_DATA_BYTE) && (cnt_bits_sent == 1) && (cnt_bytes_sent != csr_tx_bytes_num_reg - 1))begin
                        fifo_read_request <= '1;
                    end
                end
            end
            else begin
                fifo_read_request <= '0;
            end
            
        end
end
//End of generating read req for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving address setup section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            address_to_send_msb     <= '0;
            address_to_send_lsb     <= '0;
        end
    else
        begin
            if(state == SYNC_BY_SCL_NEG) begin
                if (csr_use_max_width_addr_reg) begin
                    address_to_send_msb     <= {5'b11110, csr_address_of_slave_reg[9:8], 1'b0};
                    address_to_send_lsb     <= csr_address_of_slave_reg[7:0];
                end
                else begin
                    address_to_send_msb     <= {csr_address_of_slave_reg[6:0], 1'b0};
                end
            end
            else if(state == SEND_ADDR_MSB)begin
                if(clk_divider_generated_clk_neg)begin
                    address_to_send_msb <= {address_to_send_msb, 1'b0};
                end
            end
            else if(state == SEND_ADDR_LSB)begin
                if(clk_divider_generated_clk_neg)begin
                    address_to_send_lsb <= {address_to_send_lsb, 1'b0};
                end
            end
        end
end
//End of driving address setup section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of data register driving section
//Show register
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            byte_to_send_show <= '0;
        end
    else
        begin
            if(clk_divider_generated_clk_neg)begin
                if(cnt_bits_sent == 8)begin
                    byte_to_send_show <= byte_to_send_shadow;
                end
                else if(state == SEND_DATA_BYTE)begin
                    byte_to_send_show <= {byte_to_send_show, 1'b0};
                end
                
            end
        end
end

//Shadow register
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            byte_to_send_shadow <= '0;
        end
    else
        begin
            if(fifo_valid)begin
                byte_to_send_shadow <= fifo_data;
            end
        end
end
//End of data register driving section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of counters section
//Bits in transmission coutner
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            cnt_bits_sent <= '0;
        end
    else
        begin
            if((state == SEND_ADDR_MSB) || (state == SEND_ADDR_LSB) || (state == SEND_DATA_BYTE)) begin
                if(clk_divider_generated_clk_neg)begin
                    if(cnt_bits_sent == 8) begin
                        cnt_bits_sent <= '0;
                    end
                    else begin
                        cnt_bits_sent <= cnt_bits_sent + 1;
                    end
                end
            end
            else begin
                cnt_bits_sent <= '0;
            end
        end
end

//Bytes in transmission coutner
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            cnt_bytes_sent <= '0;
        end
    else
        begin
            if(state == SEND_DATA_BYTE) begin
                if(clk_divider_generated_clk_neg)begin
                    if(cnt_bits_sent == 8) begin
                        if(cnt_bytes_sent == csr_tx_bytes_num_reg - 1)begin
                            cnt_bytes_sent <= '0;
                        end
                        else begin
                            cnt_bytes_sent <= cnt_bytes_sent + 1;
                        end
                    end
                end
            end
        end
end

//Clk stretch edges counter in transmission coutner
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            cnt_stretch_clk_dur <= '0;
        end
    else
        begin
            if (state == STRETCH_CLK) begin
                if(clk_divider_generated_clk_neg) begin
                    if (cnt_stretch_clk_dur == csr_stretch_clk_dur_reg - 1) begin
                        cnt_stretch_clk_dur <= '0;
                    end
                    else begin
                        cnt_stretch_clk_dur <= cnt_stretch_clk_dur + 1;
                    end
                end
            end
            else begin
                cnt_stretch_clk_dur <= '0;
            end
        end
end
//End of counters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving output lines section
always_comb
begin
    case (state)
        SYNC_BY_SCL_NEG:    i2c_sda_port_write  = '0;
        SEND_ADDR_MSB:      i2c_sda_port_write  = address_to_send_msb[7];
        SEND_ADDR_LSB:      i2c_sda_port_write  = address_to_send_lsb[7];
        SEND_DATA_BYTE:     i2c_sda_port_write  = byte_to_send_show[7];
        DESYNC_BY_SCL_POS:  i2c_sda_port_write  = '0;
        DESYNC_BY_SCL_NEG:  i2c_sda_port_write  = '0;
        default:            i2c_sda_port_write  = '1;
    endcase
end

always_comb
begin
    case (state)
        SYNC_BY_SCL_NEG:    i2c_scl_port  = '1;
        SEND_ADDR_MSB:      i2c_scl_port  = clk_divider_generated_clk_reg;
        SEND_ADDR_LSB:      i2c_scl_port  = clk_divider_generated_clk_reg;
        SEND_DATA_BYTE:     i2c_scl_port  = clk_divider_generated_clk_reg;
        DESYNC_BY_SCL_POS:  i2c_scl_port  = clk_divider_generated_clk_reg;
        DESYNC_BY_SCL_NEG:  i2c_scl_port  = '1;
        STRETCH_CLK:        i2c_scl_port  = '0;
        default:            i2c_scl_port  = '1;
    endcase
end
//End of driving output lines section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving i2c port direction section
always_comb
begin
    case (state)
        SEND_ADDR_MSB:      i2c_bus_direction = (cnt_bits_sent == 8) ? '1 : '0;
        SEND_ADDR_LSB:      i2c_bus_direction = (cnt_bits_sent == 8) ? '1 : '0;
        SEND_DATA_BYTE:     i2c_bus_direction = (cnt_bits_sent == 8) ? '1 : '0;
        default:            i2c_bus_direction = '0;
    endcase
end
//End of driving i2c port direction section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving status and error flags section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            busy_status <= '0;
        end
    else
        begin
            if(state == IDLE)   busy_status <= '0;
            else                busy_status <= '1;
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            reset_required <= '0;
        end
    else
        begin
            if(state == ERROR_STATE)    reset_required <= '1;
            else                        reset_required <= '0;
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            address_msb_transmission_error  <= '0;
            address_lsb_transmission_error  <= '0;
            data_byte_transmission_error    <= '0;
        end
    else
        begin
            if((state == SEND_ADDR_MSB) && (!csr_ignore_nack_reg) && (clk_divider_generated_clk_neg) && (cnt_bits_sent == 8) && (i2c_sda_port_read == '1)) begin
                address_msb_transmission_error  <= '1;
            end
            else begin
                address_msb_transmission_error  <= '0;
            end

            if((state == SEND_ADDR_LSB) && (!csr_ignore_nack_reg) && (clk_divider_generated_clk_neg) && (cnt_bits_sent == 8) && (i2c_sda_port_read == '1)) begin
                address_lsb_transmission_error  <= '1;
            end
            else begin
                address_lsb_transmission_error  <= '0;
            end

            if((state == SEND_DATA_BYTE) && (!csr_ignore_nack_reg) && (clk_divider_generated_clk_neg) && (cnt_bits_sent == 8) && (i2c_sda_port_read == '1)) begin
                data_byte_transmission_error    <= '1;
            end
            else begin
                data_byte_transmission_error    <= '0;
            end
        end
end
//End of driving status and error flags section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule 