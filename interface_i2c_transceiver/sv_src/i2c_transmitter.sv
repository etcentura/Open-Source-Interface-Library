module i2c_transmitter
#
(
    parameter 	CSR_WIDTH 	= 32    ,
    parameter 	DATA_WIDTH 	= 8     ,
    parameter 	ADDR_WIDTH 	= 7
)

(
    //Basic signals declaration
    input 	logic 		clk                                             ,
    input 	logic 		rst_n                                           ,

    //FIFO Buffer communication bus
    input 	logic 	                    fifo_valid                      ,
    input 	logic 	[DATA_WIDTH-1:0] 	fifo_data                       ,
    output 	logic 	                    fifo_read_request               ,

    //Inout i2c port
    output  logic                       i2c_sda_port_write              ,
    input   logic                       i2c_sda_port_read               ,
    output  logic                       i2c_scl_port                    ,
    
    //Config signals
    input 	logic 	                    csr_start_transmission          ,
    input 	logic 	                    csr_ignore_nack                 ,
    input 	logic 	                    csr_stretch_clk                 ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_stretch_clk_dur             ,
    input 	logic 	[ADDR_WIDTH-1:0] 	csr_address_of_slave            ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_tx_bytes_num                ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_fifo_read_req_timing        ,

    input 	logic 	[CSR_WIDTH-1:0] 	csr_control_clk_gen             ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_div_cnt_limit_clk_gen       ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_raise_pos_clk_gen           ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_fall_pos_clk_gen            ,

    //Status signals
    //TODO добавить драйвера для сигналов ошибок и сами сигналы ошибок
    output 	logic 	                    address_transmission_error      
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//Localparams to increase code readability
localparam BYTE_LEN = 8;

//Slow clk generator
logic 	                            clk_slow                            ;
logic 	                            clk_gen_status                      ;

//Front detector
logic 	                            clk_slow_reg                        ;
logic 	                            clk_slow_pos                        ;
logic 	                            clk_slow_neg                        ;

//FIFO
logic 	                            fifo_read_request_int               ;

//FSM
logic 	[CSR_WIDTH-1:0] 	        fsm_service_counter                 ;
logic 	[CSR_WIDTH-1:0] 	        fsm_bytes_counter                   ;
enum 	logic 	[4:0] 	            {
                                        IDLE                            ,
                                        WAIT_START                        ,
                                        SEND_ADDR_7                     ,
                                        SEND_ADDR_10_MSB                ,
                                        SEND_ADDR_10_LSB                ,
                                        SEND_DATA_BYTE                  ,
                                        STRETCH_CLK                     ,
                                        WAIT_END                        ,
                                        FATAL_ERROR_STATE
                                    } 	
                                    state, next_state, 
                                    prev_state, jump_state              ;

//Markdown of the transmission available flag
logic 	                            transmissin_ongoing                 ;

//Data to send registers
logic 	[7:0] 	                    shift_reg_address                   ;
logic 	[7:0] 	                    shift_reg_address_msb               ;
logic 	[7:0] 	                    shift_reg_address_lsb               ;
logic 	[DATA_WIDTH-1:0] 	        data_shift_reg_reserve              ;
logic 	[DATA_WIDTH-1:0] 	        data_shift_reg                      ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing clock divider section
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
    .generated_clk          (clk_slow                   ),
    
    //Input csr register
    .csr_control            (csr_control_clk_gen        ),
    .csr_div_cnt_limit      (csr_div_cnt_limit_clk_gen  ),
    .csr_raise_pos          (csr_raise_pos_clk_gen      ),
    .csr_fall_pos           (csr_fall_pos_clk_gen       ),

    //Status and errors signals
    .error_raise_fall       (clk_gen_status             )
);
//End of instancing clock divider section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of front detector section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            clk_slow_reg <= '0;
        end
    else
        begin
            clk_slow_reg <= clk_slow;
        end
end

assign 	clk_slow_pos 	= ~clk_slow_reg & clk_slow;
assign 	clk_slow_neg 	= clk_slow_reg & ~clk_slow;
//End of front detector section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of front detector for fiof read req section
logic 	fifo_read_request_reg;
logic 	fifo_read_request_pos;
logic 	fifo_read_request_neg;

always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            fifo_read_request_reg <= '0;
        end
    else
        begin
            fifo_read_request_reg <= fifo_read_request_int;
        end
end

assign fifo_read_request_pos 	= ~fifo_read_request_reg & fifo_read_request_int;
assign fifo_read_request_neg 	= fifo_read_request_reg & ~fifo_read_request_int;
assign fifo_read_request        = fifo_read_request_pos;
//End of front detector for fiof read req section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of fsm driving section
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

always_comb
begin
    case (state)
        IDLE:
            begin
                next_state = IDLE;
                if(csr_start_transmission)begin
                    next_state = WAIT_START;
                end
            end
        WAIT_START:
            begin
                next_state = WAIT_START;
                if(clk_slow_pos)begin
                    if(ADDR_WIDTH == 7) begin
                        next_state = SEND_ADDR_7;
                    end
                    else if(ADDR_WIDTH == 10) begin
                        next_state = SEND_ADDR_10_MSB;
                    end
                    else begin
                        next_state = FATAL_ERROR_STATE;
                    end
                end
            end
        SEND_ADDR_7:
            begin
                next_state = SEND_ADDR_7;
                if((fsm_service_counter == BYTE_LEN) && (clk_slow_neg))begin
                    if(csr_ignore_nack)begin
                        if(csr_stretch_clk) begin
                            next_state = STRETCH_CLK;
                        end
                        else begin
                            next_state = SEND_DATA_BYTE;
                        end
                    end
                    else begin
                        if(i2c_sda_port_read == 1'b0)begin
                            if(csr_stretch_clk) begin
                                next_state = STRETCH_CLK;
                            end
                            else begin
                                next_state = SEND_DATA_BYTE;
                            end
                        end
                        else begin
                            next_state = FATAL_ERROR_STATE;
                        end
                    end
                end
            end
        SEND_ADDR_10_MSB:
            begin
                if((fsm_service_counter == BYTE_LEN) && (clk_slow_neg))begin
                    if(csr_ignore_nack)begin
                        if(csr_stretch_clk) begin
                            next_state = STRETCH_CLK;
                        end
                        else begin
                            next_state = SEND_ADDR_10_LSB;
                        end
                    end
                    else begin
                        if(i2c_sda_port_read == 1'b0)begin
                            if(csr_stretch_clk) begin
                                next_state = STRETCH_CLK;
                            end
                            else begin
                                next_state = SEND_ADDR_10_LSB;
                            end
                        end
                        else begin
                            next_state = FATAL_ERROR_STATE;
                        end
                    end
                end
            end
        SEND_ADDR_10_LSB:
            begin
                if((fsm_service_counter == BYTE_LEN) && (clk_slow_neg))begin
                    if(csr_ignore_nack)begin
                        if(csr_stretch_clk) begin
                            next_state = STRETCH_CLK;
                        end
                        else begin
                            next_state = SEND_DATA_BYTE;
                        end
                    end
                    else begin
                        if(i2c_sda_port_read == 1'b0)begin
                            if(csr_stretch_clk) begin
                                next_state = STRETCH_CLK;
                            end
                            else begin
                                next_state = SEND_DATA_BYTE;
                            end
                        end
                        else begin
                            next_state = FATAL_ERROR_STATE;
                        end
                    end
                end
            end
        SEND_DATA_BYTE:
            begin
                next_state = SEND_DATA_BYTE;
                if((fsm_service_counter == DATA_WIDTH) && (clk_slow_pos))begin
                    if(csr_ignore_nack)begin
                        if(fsm_bytes_counter == csr_tx_bytes_num)begin
                            next_state = WAIT_END;
                        end
                        else begin
                            if(csr_stretch_clk) begin
                                next_state = STRETCH_CLK;
                            end
                            else begin
                                next_state = SEND_DATA_BYTE;
                            end
                        end
                    end
                    else begin
                        if(i2c_sda_port_read == 1'b0)begin
                            if(fsm_bytes_counter == csr_tx_bytes_num)begin
                                next_state = WAIT_END;
                            end
                            else begin
                                if(csr_stretch_clk) begin
                                    next_state = STRETCH_CLK;
                                end
                                else begin
                                    next_state = SEND_DATA_BYTE;
                                end
                            end
                        end
                        else begin
                            next_state = FATAL_ERROR_STATE;
                        end
                    end
                end
            end
        WAIT_END:
            begin
                next_state = WAIT_END;
                if(clk_slow_neg) begin
                    next_state = IDLE;
                end
            end
        STRETCH_CLK:
            begin
                next_state = STRETCH_CLK;
                if ((fsm_service_counter == csr_stretch_clk_dur - 1) && (clk_slow_neg)) begin
                    next_state = jump_state;
                end
            end
        FATAL_ERROR_STATE:
            begin
                next_state = FATAL_ERROR_STATE;
            end
        default:
            begin
                next_state = IDLE;
            end
    endcase
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            jump_state <= IDLE;
        end
    else
        begin
            if(state == SEND_ADDR_7) begin
                if((fsm_service_counter == BYTE_LEN) && (clk_slow_pos) && (csr_stretch_clk)) begin
                    jump_state <= SEND_DATA_BYTE;
                end
            end
            else if(state == SEND_ADDR_10_MSB) begin
                if((fsm_service_counter == BYTE_LEN) && (clk_slow_pos) && (csr_stretch_clk)) begin
                    jump_state <= SEND_ADDR_10_LSB;
                end
            end
            else if(state == SEND_ADDR_10_LSB) begin
                if((fsm_service_counter == BYTE_LEN) && (clk_slow_pos) && (csr_stretch_clk)) begin
                    jump_state <= SEND_DATA_BYTE;
                end
            end
            else if(state == SEND_DATA_BYTE) begin
                if((fsm_service_counter == DATA_WIDTH) && (clk_slow_pos) && (csr_stretch_clk)) begin
                    jump_state <= SEND_DATA_BYTE;
                end
            end
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            fsm_service_counter <= '0;
        end
    else
        begin
            case (state)
                SEND_ADDR_7, SEND_ADDR_10_MSB, SEND_ADDR_10_LSB:
                    begin
                        if(clk_slow_pos)begin
                            if(fsm_service_counter == ADDR_WIDTH + 1)begin
                                fsm_service_counter <= '0;  
                            end
                            else begin
                                fsm_service_counter <= fsm_service_counter + 1;  
                            end
                        end
                    end
                SEND_DATA_BYTE:
                    begin
                        if(clk_slow_pos)begin
                            if(fsm_service_counter == DATA_WIDTH)begin
                                fsm_service_counter <= '0;  
                            end
                            else begin
                                fsm_service_counter <= fsm_service_counter + 1;  
                            end
                        end
                    end
                STRETCH_CLK:
                    begin
                        if(clk_slow_neg)begin
                            if(fsm_service_counter == csr_stretch_clk_dur - 1)begin
                                fsm_service_counter <= '0;  
                            end
                            else begin
                                fsm_service_counter <= fsm_service_counter + 1;  
                            end
                        end
                    end
                default:
                    begin
                        fsm_service_counter <= '0;
                    end
            endcase
        end
end
//End of fsm driving section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving address section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            shift_reg_address       <= '0;
            shift_reg_address_msb   <= '0;
            shift_reg_address_lsb   <= '0;
        end
    else
        begin
            if(state == IDLE)begin
                if(ADDR_WIDTH == 7)begin
                    shift_reg_address   <= {csr_address_of_slave, 1'b0};
                end
                else if(ADDR_WIDTH == 10)begin
                    shift_reg_address_msb   <= {5'b11110, csr_address_of_slave[9:8], 1'b0};
                    shift_reg_address_lsb   <= {csr_address_of_slave[7:0]};
                end
            end
            else if((state == SEND_ADDR_7) && (clk_slow_neg) && (transmissin_ongoing))begin
                shift_reg_address       <= {shift_reg_address, 1'b0};
            end
            else if((state == SEND_ADDR_10_MSB) && (clk_slow_neg) && (transmissin_ongoing))begin
                shift_reg_address_msb   <= {shift_reg_address_msb, 1'b0};
            end
            else if((state == SEND_ADDR_10_LSB) && (clk_slow_neg) && (transmissin_ongoing))begin
                shift_reg_address_lsb   <= {shift_reg_address_lsb, 1'b0};
            end
        end
end
//End of driving address section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving data register section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            data_shift_reg_reserve <= '0;
        end
    else
        begin
            if(fifo_valid)begin
                data_shift_reg_reserve <= fifo_data;    
            end
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            data_shift_reg <= '0;
        end
    else
        begin
            if(state == SEND_DATA_BYTE)begin
                if((fsm_service_counter == DATA_WIDTH) && (clk_slow_neg))begin
                    data_shift_reg <= data_shift_reg_reserve;
                end
                else if (clk_slow_neg)begin
                    data_shift_reg <= {data_shift_reg, 1'b0};
                end
            end
            else if ((state == SEND_ADDR_7) || (state == SEND_ADDR_10_LSB)) begin
                if((fsm_service_counter == BYTE_LEN) && (clk_slow_neg))begin
                    data_shift_reg <= data_shift_reg_reserve;
                end
                else if (clk_slow_neg)begin
                    data_shift_reg <= {data_shift_reg, 1'b0};
                end
            end
        end
end
//End of driving data register section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of fifo read req driving section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            fifo_read_request_int <= '0;
        end
    else
        begin
            if((state == SEND_ADDR_7) || (state == SEND_ADDR_10_LSB) || (state == SEND_DATA_BYTE) && (clk_slow_pos)) begin
                if(fsm_service_counter == csr_fifo_read_req_timing - 1)begin
                    fifo_read_request_int <= '1;
                end
                else begin
                    fifo_read_request_int <= '0;
                end
            end
        end
end
//End of fifo read req driving section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving byte counter section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            fsm_bytes_counter <= '0;
        end
    else
        begin
            if(state == IDLE)begin
                fsm_bytes_counter <= '0;
            end
            else if(state == SEND_DATA_BYTE)begin
                if((fsm_service_counter == DATA_WIDTH) && (clk_slow_pos))begin
                    fsm_bytes_counter <= fsm_bytes_counter + 1;
                end
            end
        end
end
//End of driving byte counter section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving output data arbitrage section
always_comb
begin
    case (state)
        WAIT_START: begin
            i2c_sda_port_write = '0;
        end
        SEND_ADDR_7: begin
            i2c_sda_port_write = transmissin_ongoing ? shift_reg_address[7] : '0;
        end
        SEND_ADDR_10_MSB: begin
            i2c_sda_port_write = transmissin_ongoing ? shift_reg_address_msb[7] : '0;
        end
        SEND_ADDR_10_LSB: begin
            i2c_sda_port_write = transmissin_ongoing ? shift_reg_address_lsb[7] : '0;
        end
        SEND_DATA_BYTE: begin
            i2c_sda_port_write = data_shift_reg[DATA_WIDTH-1];
        end
        WAIT_END: begin
            i2c_sda_port_write = '0;
        end
        default:
            begin
                i2c_sda_port_write = '1;
            end
    endcase
end
//End of driving output data arbitrage section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving scl line section
always_comb
begin
    i2c_scl_port = clk_slow;
    if((state == IDLE) || (state == WAIT_START) || (state == WAIT_END))begin
        i2c_scl_port = '1;
    end
end
//End of driving scl line section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving transmission ongoing flag section

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            transmissin_ongoing <= '0;
        end
    else
        begin
            if((state == SEND_ADDR_7) || (state == SEND_ADDR_10_MSB)) begin
                if(clk_slow_neg)begin
                    transmissin_ongoing <= '1;
                end
            end
        end
end
//End of driving transmission ongoing flag section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule