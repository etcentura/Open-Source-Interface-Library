module uart_tx_wrapper
#
(
    parameter		int     DWIDTH  =	8                               ,   //Width of the bus for: data
    parameter       int     CSR_WIDTH   =   32                              //Width of the control-setup registers
)

(
    //Basic signals declaration
    input 	logic 		                    clk                         ,
    input 	logic 		                    rst_n                       ,
    
    //Input data stream
    input 	logic 	                        input_stream_valid          ,
    input 	logic 	[DWIDTH - 1 : 0] 	    input_stream_data           ,
    output 	logic 	                        input_stream_ready          ,

    //UART interface
    output 	logic 	                        uart_tx                     ,
    input 	logic 	                        uart_cts                    ,

    //Setup inputs
    input 	logic 	                        use_cts_on_tx               ,
    input   logic   [2 : 0]                 use_parity_tx               ,
    input   logic   [1 : 0]                 number_of_stop_bits_tx      ,

    //Status flag for manager
    output 	logic 	                        status_busy                        
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters section

//CTS resync
logic           cts_resync;

//FSM section
enum 	logic 	[7:0] 	                {
                                            IDLE, 
                                            GET_DATA, 
                                            SEND_DATA
                                        } 	
                                        state, next_state;

//Data processing section
logic 	        [DWIDTH - 1 : 0]        data_shift_register;
logic 	                                data_parity_bit;
logic 	        [CSR_WIDTH - 1 : 0] 	send_counter;
logic 	        [CSR_WIDTH - 1 : 0] 	number_of_stops;

//End of declaring local singals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of CTS resync section
signal_synchronizer 
#
(
    .SYNCWIDTH		        (1                          ),
    .SYNCSTEPS		        (2                          )
)
                            i_signal_synchronizer_tx_ready
(
    //Basic signals declaration
    .clk_src                (clk                        ),
    .clk_dst                (clk                        ),

    .data_src               (uart_cts                   ),
    .data_dst               (cts_resync                 )
);
//End of CTS resync section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of getting number of stop bits section
always_comb
begin
    case (number_of_stop_bits_tx)
        0, 1:       number_of_stops = 1;
        2:          number_of_stops = 2;
        default:    number_of_stops = 1;
    endcase
end
//End of getting number of stop bits section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of fsm to control the flow section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            state <= IDLE;
        end
    else
        begin
            state <= next_state;
        end
end

always_comb
begin
    case (state)
        IDLE:
            begin
                next_state = IDLE;
                if(input_stream_valid)begin
                    next_state = GET_DATA;
                end
            end
        GET_DATA:
            begin
                next_state = GET_DATA;
                if(use_cts_on_tx) begin
                    if(!cts_resync)begin
                        next_state = SEND_DATA;
                    end
                end
                else begin
                    next_state = SEND_DATA;
                end
            end
        SEND_DATA:
            begin
                next_state = SEND_DATA;
                if(send_counter >= 1 + DWIDTH + number_of_stops)begin
                    next_state = IDLE;
                end
            end
        default:
            begin
                next_state = IDLE;
            end
    endcase
end
//End of fsm to control the flow section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving ready signal for the master section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            input_stream_ready <= '0;
        end
    else
        begin
            if(state == GET_DATA)begin
                if(use_cts_on_tx)begin
                    if(!cts_resync)begin
                        input_stream_ready <= '1;
                    end
                    else begin
                        input_stream_ready <= '0;
                    end
                end
                else begin
                    input_stream_ready <= '1;
                end
            end
            else begin
                input_stream_ready <= '0;
            end
        end
end
//End of driving ready signal for the master section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving data bus section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            data_shift_register <= '1;
        end
    else
        begin
            if(state == GET_DATA)begin
                data_shift_register <= input_stream_data;
            end
            else if(state == SEND_DATA)begin
                if(send_counter >= 1)begin
                    data_shift_register <= {1'b1, data_shift_register[DWIDTH-1:1]};
                end
            end
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            data_parity_bit <= '0;
        end
    else
        begin
            if(state == GET_DATA)begin
                case (use_parity_tx)
                    1:          data_parity_bit <= ~(^input_stream_data);
                    2:          data_parity_bit <= ^input_stream_data;
                    3:          data_parity_bit <= '1;
                    4:          data_parity_bit <= '0;
                    default:    data_parity_bit <= '0;
                endcase
            end
        end
end
//End of driving data bus section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving send counter section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            send_counter <= '0;
        end
    else
        begin
            if(state == SEND_DATA) begin
                send_counter <= send_counter + 1;
            end
            else begin
                send_counter <= '0;
            end
        end
end
//End of driving send counter section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving output data section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            uart_tx <= '1;
        end
    else
        begin
            if(state == SEND_DATA)begin
                if(send_counter == 0) begin
                    uart_tx <= '0;
                end
                else if((send_counter >= 1) && (send_counter <= DWIDTH)) begin
                    uart_tx <= data_shift_register[0];
                end
                else if(send_counter == DWIDTH + 1) begin
                    uart_tx <= data_parity_bit;
                end
                else begin
                    uart_tx <= '1;
                end
            end
            else begin
                uart_tx <= '1;
            end
        end
end
//End of driving output data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of busy status driving section
always_ff @(posedge clk)
begin
    if(state == IDLE) begin
        status_busy <= '0;
    end
    else begin
        status_busy <= '1;
    end
end
//End of busy status driving section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule