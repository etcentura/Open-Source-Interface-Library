module uart_transceiver_wrapper
#
(
    parameter		int     MAX_DWIDTH  =	8                   ,   //Width of the bus for: data
    parameter       int     CSR_WIDTH   =   32                      //Width of the control-setup registers
)

(
    //Basic signals declaration
    input 	logic 		                    clk                         ,
    input 	logic 		                    rst_n                       ,
    
    //Input data stream
    input 	logic 	                        input_stream_valid          ,
    input 	logic 	[MAX_DWIDTH - 1 : 0] 	input_stream_data           ,
    output 	logic 	                        input_stream_ready          ,

    //Output data stream
    output 	logic 	                        output_stream_valid         ,
    output 	logic 	[MAX_DWIDTH - 1 : 0] 	output_stream_data          ,
    input 	logic 	                        output_stream_ready         ,

    //UART interface
    input 	logic 	                        uart_rx                     ,
    output 	logic 	                        uart_tx                     ,
    input 	logic 	                        uart_cts                    ,
    output 	logic 	                        uart_rts                    ,

    //Setup inputs
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_setup_register          ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_clk_divider_tx          ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_bits_to_send_tx         ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_clk_divider_rx          ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_bits_to_send_rx         ,

    //Status outputs
    output 	logic 	                        status_max_bits_error_tx    ,
    output 	logic 	                        status_max_bits_error_rx    ,
    output 	logic 	                        status_parity_bit_error_tx  ,
    output 	logic 	                        status_parity_bit_error_rx  ,
    output 	logic 	                        status_stop_bit_error_tx    ,
    output 	logic 	                        status_stop_bit_error_rx    ,
);
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of notes section

/*
While setting up the parity bit it's considered that:
0 - none - no parity bit will be sent and it's position takes the stop bit
1 - odd - regular odd parity bit is used
2 - even - regular even parity bit is used
3 - mark - parity bit always equals 1
4 - space - parity bit always equals 0
>4 - prohibited value - calls status_parity_bit_error_*
*/

//Table of odd and even parity bits
/*
|-------------------|-------------------|-----------|-----------|-----------|-----------|-----------|
| 7 bits of data    | Count of ones     |                       parity bit                          |
|                   |                   |   none    |   even    |   odd     |   mark    |   space   |
|-------------------|-------------------|-----------|-----------|-----------|-----------|-----------|
|   0000000	        |       0	        |    -      |   0	    |   1       |   1       |   0       |
|   1010001	        |       3	        |    -      |   1	    |   0       |   1       |   0       |
|   1101001	        |       4	        |    -      |   0	    |   1       |   1       |   0       |
|   1111111	        |       7	        |    -      |   1	    |   0       |   1       |   0       |
|-------------------|-------------------|-----------|-----------|-----------|-----------|-----------|
*/

/*
The number of stop bits defined as
0 - 1 stop bit
1 - 1.5 stop bits
2 - 2 stop bits
3 - prohibited value - calls status_stop_bit_error_*
*/

//End of notes section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//CSR setup bits
logic 	                        use_resync_rst          ;     //csr_setup_register[0]   : 1 - use resync, 0 - use non resync
logic   [2 : 0]                 use_parity_tx           ;     //csr_setup_register[3:1] : go to notes section
logic   [2 : 0]                 use_parity_rx           ;     //csr_setup_register[6:4] : go to notes section
logic   [1 : 0]                 number_of_stop_bits_tx  ;     //csr_setup_register[8:7] : go to notes section
logic   [1 : 0]                 number_of_stop_bits_rx  ;     //csr_setup_register[10:9]: go to notes section


//RST resync
logic 	                        resync_reset_tx         ;
logic 	                        resync_reset_rx         ;
logic 	                        no_resync_reset         ;
logic 	                        internal_reset_tx       ;
logic 	                        internal_reset_rx       ;

//CLK dividing signals
logic 	[CSR_WIDTH - 1 : 0] 	clk_div_counter_tx      ;
logic 	                        clk_div_clock_tx        ;
logic 	[CSR_WIDTH - 1 : 0] 	clk_div_counter_rx      ;
logic 	                        clk_div_clock_rx        ;

//TX section
logic 	                        uart_tx_valid_resync    ;
logic 	                        uart_tx_ready_resync    ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing reset resync section
signal_synchronizer 
#
(
    .SYNCWIDTH		        (1                          ),
    .SYNCSTEPS		        (2                          )
)
                            i_signal_synchronizer_tx
(
    //Basic signals declaration
    .clk_src                (clk                        ),
    .clk_dst                (clk_div_clock_tx           ),

    .data_src               (rst_n                      ),
    .data_dst               (resync_reset_tx            )
);


signal_synchronizer 
#
(
    .SYNCWIDTH		        (1                          ),
    .SYNCSTEPS		        (2                          )
)
                            i_signal_synchronizer_rx
(
    //Basic signals declaration
    .clk_src                (clk                        ),
    .clk_dst                (clk_div_clock_rx           ),

    .data_src               (rst_n                      ),
    .data_dst               (resync_reset_rx            )
);

assign use_resync_rst = csr_setup_register[0];
assign no_resync_reset = rst_n;
assign internal_reset_tx = use_resync_rst ? resync_reset_tx : no_resync_reset;
assign internal_reset_rx = use_resync_rst ? resync_reset_rx : no_resync_reset;

//End of instancing reset resync section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of clk divider section
always_ff @(posedge clk or negedge internal_reset)
begin
    if(!internal_reset)
        begin
            clk_div_counter_tx <= '0;
            clk_div_clock_tx <= '0;

            clk_div_counter_rx <= '0;
            clk_div_clock_rx <= '0;
        end
    else
        begin
            //TX clock
            if(clk_div_counter_tx == csr_clk_divider_tx - 1)begin
                clk_div_counter_tx <= '0;
                clk_div_clock_tx <= ~clk_div_clock_tx;
            end
            else begin
                clk_div_counter_tx <= clk_div_counter_tx + 1;
            end


            //RX clock
            if(clk_div_counter_rx == csr_clk_divider_tx - 1)begin
                clk_div_counter_rx <= '0;
                clk_div_clock_rx <= ~clk_div_clock_rx;
            end
            else begin
                clk_div_counter_rx <= clk_div_counter_rx + 1;
            end
        end
end
//End of clk divider section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring uart tx section section

signal_synchronizer 
#
(
    .SYNCWIDTH		        (1                          ),
    .SYNCSTEPS		        (2                          )
)
                            i_signal_synchronizer_tx_valid
(
    //Basic signals declaration
    .clk_src                (clk                        ),
    .clk_dst                (clk_div_clock_tx           ),

    .data_src               (input_stream_valid         ),
    .data_dst               (uart_tx_valid_resync       )
);

signal_synchronizer 
#
(
    .SYNCWIDTH		        (1                          ),
    .SYNCSTEPS		        (2                          )
)
                            i_signal_synchronizer_tx_ready
(
    //Basic signals declaration
    .clk_src                (clk_div_clock_rx           ),
    .clk_dst                (clk                        ),

    .data_src               (uart_tx_ready_resync       ),
    .data_dst               (input_stream_ready         )
);

uart_transceiver_wrapper 
#
(
    .MAX_DWIDTH             (MAX_DWIDTH                 ),      //Width of the bus for: data
    .CSR_WIDTH              (CSR_WIDTH                  )       //Width of the control-setup registers
)
                            i_uart_transceiver_wrapper
(
    //Basic signals declaration
    .clk                    (clk_div_clock_tx           ),
    .rst_n                  (internal_reset_tx          ),
    
    //Input data stream
    .input_stream_valid     (uart_tx_valid_resync       ),
    .input_stream_data      (input_stream_data          ),
    .input_stream_ready     (uart_tx_ready_resync       ),

    //UART interface
    .uart_tx                (uart_tx                    ),
    .uart_cts               (uart_cts                   ),

    //Setup inputs
    .use_parity_tx          (use_parity_tx              ),
    .number_of_stop_bits_tx (number_of_stop_bits_tx     ),
    .csr_bits_to_send_tx    (csr_bits_to_send_tx        )
);

//End of declaring uart tx section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring uart rx section section
uart_rx_wraper 
#
(
    .MAX_DWIDTH             (MAX_DWIDTH                 ),      //Width of the bus for: data
    .CSR_WIDTH              (CSR_WIDTH                  )       //Width of the control-setup registers
)
                            i_uart_rx_wraper
(
    //Basic signals declaration
    .clk                    (clk_div_clock_tx           ),
    .rst_n                  (internal_reset_rx          ),
    
    //Input data stream
    .output_stream_valid    ()   ,
    .output_stream_data     ()   ,
    .output_stream_ready    ()   ,

    //UART interface
    .uart_rx                (uart_rx                    ),
    .uart_rts               (uart_rts                   ),

    //Setup inputs
    .use_parity_rx          (use_parity_rx              ),
    .number_of_stop_bits_rx (number_of_stop_bits_rx     ),
    .csr_bits_to_send_rx    (csr_bits_to_send_rx        )
);
//End of declaring uart rx section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving status errors section
always_comb
begin
    status_max_bits_error_tx = '0;
    if(csr_bits_to_send_tx > MAX_DWIDTH) begin
        status_max_bits_error_tx = '1;
    end

    status_max_bits_error_rx = '0;
    if(csr_bits_to_send_rx > MAX_DWIDTH) begin
        status_max_bits_error_rx = '1;
    end

    status_parity_bit_error_tx = '0;
    if(use_parity_tx > 4)begin
        status_parity_bit_error_tx = '1;
    end
    
    status_parity_bit_error_rx = '0;
    if(use_parity_rx > 4)begin
        status_parity_bit_error_rx = '1;
    end

    status_stop_bit_error_tx = '0;
    if(number_of_stop_bits_tx)begin
        status_stop_bit_error_tx = '1;
    end

    status_stop_bit_error_rx = '0;
    if(number_of_stop_bits_rx)begin
        status_stop_bit_error_rx = '1;
    end
end
//End of driving status errors section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule