module uart_tx_wrapper
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

    //UART interface
    output 	logic 	                        uart_tx                     ,
    input 	logic 	                        uart_cts                    ,

    //Setup inputs
    input   logic   [2 : 0]                 use_parity_tx               ,
    input   logic   [1 : 0]                 number_of_stop_bits_tx      ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_bits_to_send_tx         
);
endmodule