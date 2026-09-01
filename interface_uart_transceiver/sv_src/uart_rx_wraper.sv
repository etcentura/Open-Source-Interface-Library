module uart_rx_wraper
#
(
    parameter		int     DWIDTH      =	8                           ,       //Width of the bus for: data
    parameter       int     CSR_WIDTH   =   32                                  //Width of the control-setup registers
)

(
    //Basic signals declaration
    input 	logic 		                    clk                         ,
    input 	logic 		                    rst_n                       ,
    
    //Input data stream
    output 	logic 	                        output_stream_valid         ,
    output 	logic 	[DWIDTH - 1 : 0] 	    output_stream_data          ,

    //UART interface
    input 	logic 	                        uart_rx                     ,
    output 	logic 	                        uart_rts                    ,

    //Setup inputs
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_clk_divider_rx          ,
    input   logic   [2 : 0]                 use_parity_rx               
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//Signals to get the bits
logic 	                        is_receiving;
logic 	                        detected_receiving;
logic 	[CSR_WIDTH : 0] 	    counter_for_ticks;
logic 	[CSR_WIDTH - 1 : 0] 	counter_for_bits;
logic 	[CSR_WIDTH : 0] 	    extended_divider;

logic 	[DWIDTH : 0] 	        data_shift_register_input;

logic 	                        valid_shift_register_check;
logic 	[DWIDTH : 0] 	        data_shift_register_check;

logic 	                        calc_parity_bit;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of extending clk divider to properly capture data later section
assign extended_divider = csr_clk_divider_rx << 1;
//End of extending clk divider to properly capture data later section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of getting first bit of transaction section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            is_receiving        <= '0;
            detected_receiving  <= '0;
            counter_for_ticks   <= '0;
        end
    else
        begin
            if(!is_receiving) begin
                if(!uart_rx) begin
                    if(counter_for_ticks == extended_divider - 1)begin
                        counter_for_ticks <= 0;

                        if(detected_receiving)begin
                            is_receiving <= '1;
                        end
                    end
                    else begin
                        counter_for_ticks <= counter_for_ticks + 1;
                    end

                    if(counter_for_ticks == csr_clk_divider_rx)begin
                        detected_receiving <= '1;
                    end
                end
                else begin
                    counter_for_ticks <= 0;
                    detected_receiving <= '0;
                end
            end
            else begin
                if(counter_for_ticks == extended_divider - 1) begin
                    counter_for_ticks <= '0;
                    if(counter_for_bits == DWIDTH + 1)begin
                       is_receiving <= '0; 
                    end
                end
                else begin
                    counter_for_ticks <= counter_for_ticks + 1;
                end
            end
            
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            counter_for_bits <= '0;
        end
    else
        begin
            if(is_receiving)begin
                if(counter_for_ticks == csr_clk_divider_rx - 1) begin
                    if(counter_for_bits == DWIDTH + 1) begin
                        counter_for_bits <= '0;
                    end
                    else begin
                        counter_for_bits <= counter_for_bits + 1;
                    end
                end
            end
            else begin
                counter_for_bits <= '0;
            end
        end
end
//End of getting first bit of transaction section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving data shift register section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            data_shift_register_input <= '0;
        end
    else
        begin
            if((is_receiving) && (counter_for_ticks == csr_clk_divider_rx - 1))begin
                data_shift_register_input <= {data_shift_register_input, uart_rx};
            end
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            data_shift_register_check <= '0;
            valid_shift_register_check <= '0;
        end
    else
        begin
            valid_shift_register_check <= '0;
            if(counter_for_ticks == extended_divider - 1) begin
                if(counter_for_bits == DWIDTH + 1) begin
                    data_shift_register_check <= data_shift_register_input;
                    valid_shift_register_check <= '1;
                end
            end
        end
end
//End of driving data shift register section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of outputting received data section
always_comb
begin
    
    case (use_parity_rx)
        1:          calc_parity_bit = ~(^data_shift_register_check[DWIDTH:1]);
        2:          calc_parity_bit = ^data_shift_register_check[DWIDTH:1];
        3:          calc_parity_bit = '1;
        4:          calc_parity_bit = '0;
        default:    calc_parity_bit = '0;
    endcase
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            output_stream_valid <= '0;
            output_stream_data  <= '0;
        end
    else
        begin
            if((valid_shift_register_check) && (calc_parity_bit == data_shift_register_check[0])) begin
                output_stream_valid <= '1;
                output_stream_data  <= data_shift_register_check[DWIDTH:1];
            end
            else begin
                output_stream_valid <= '0;
            end
        end
end
//End of outputting received data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving use_rts_on_rx section
//WIP - or customizable for the requiered function
assign use_rts_on_rx = '0;
//End of driving use_rts_on_rx section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule