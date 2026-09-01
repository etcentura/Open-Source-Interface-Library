module uart_rx_wraper
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
    output 	logic 	                        output_stream_valid         ,
    output 	logic 	[MAX_DWIDTH - 1 : 0] 	output_stream_data          ,
    input 	logic 	                        output_stream_ready         ,

    //UART interface
    input 	logic 	                        uart_rx                     ,
    output 	logic 	                        uart_rts                    ,

    //Setup inputs
    input   logic                           use_rts_on_rx               ,
    input   logic   [2 : 0]                 use_parity_rx               ,
    input   logic   [1 : 0]                 number_of_stop_bits_rx      
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of name section



//End of name section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule