module uart_wrapper
#
(
    parameter		int     DWIDTH              =	8       ,   //Width of the bus for: data
    parameter       int     CSR_WIDTH           =   32      ,   //Width of the control-setup registers
    parameter		int     FIFO_TXAWIDTH		=	8       ,
    parameter		int     FIFO_RXAWIDTH		=	8       
)

(
    //Basic signals declaration
    input 	logic 		                    clk_system                  ,
    input 	logic 		                    clk_uart                    ,
    input 	logic 		                    rst_n                       ,

    //Data flow to tx fifo
    input 	logic 	                        valid_to_tx_fifo            ,
    input 	logic 	[DWIDTH - 1 : 0] 	    data_to_tx_fifo             ,
    output 	logic 	                        full_tx_fifo                ,
    output 	logic 	                        empty_tx_fifo               ,
    output 	logic 	                        rst_sync_tx_fifo_w          ,
    output 	logic 	                        rst_sync_tx_fifo_r          ,

    //Data flow from rx fifo
    input 	logic 	                        read_en_to_rx_fifo          ,
    output 	logic 	                        valid_from_rx_fifo          ,
    output 	logic 	[DWIDTH - 1 : 0] 	    data_from_rx_fifo           ,
    output 	logic 	                        full_rx_fifo                ,
    output 	logic 	                        empty_rx_fifo               ,
    output 	logic 	                        rst_sync_rx_fifo_w          ,
    output 	logic 	                        rst_sync_rx_fifo_r          ,

    //UART interface
    input 	logic 	                        uart_rx                     ,
    output 	logic 	                        uart_tx                     ,
    input 	logic 	                        uart_cts                    ,
    output 	logic 	                        uart_rts                    ,

    //CSR registers
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_setup_register          ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_clk_divider_tx          ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	csr_clk_divider_rx          ,

    //Status outputs
    output 	logic 	                        status_parity_bit_error_tx  ,
    output 	logic 	                        status_parity_bit_error_rx  ,
    output 	logic 	                        status_stop_bit_error_tx    

);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters section

//Data from uart
logic 	                    valid_from_uart         ;
logic 	[DWIDTH - 1 : 0] 	data_from_uart          ;

//Data manager unit
logic 	                    manage_fifo_valid       ;
logic 	[DWIDTH-1:0] 	    manage_fifo_data        ;
logic 	                    manage_fifo_read_req    ;

logic 	                    manage_uart_valid       ;
logic 	                    manage_uart_ready       ;
logic 	[DWIDTH-1:0] 	    manage_uart_data        ;

//End of declaring local singals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing tx fifo buffer section
fifo_buffer_wrapper 
#
(
    .DWIDTH                                 (DWIDTH                         ),
    .AWIDTH                                 (FIFO_TXAWIDTH                  ),
    .FIFO_STYLE                             (1                              ),  //0 - SCFIFO, 1 - DCFIFO
    .SYNC_RSTN                              (1                              )   //0 - async reset, 1 - synced to both write and read separately
)
                                            i_fifo_buffer_wrapper_tx
(
    //RST signlal
    .rst_n                                  (rst_n                          ),

    //Write side signals declaration
    .clk_write                              (clk_system                     ),
    .enable_write                           (valid_to_tx_fifo               ),
    .data_write                             (data_to_tx_fifo                ),
    .flag_full                              (full_tx_fifo                   ),
    .rst_n_synched_write                    (rst_sync_tx_fifo_w             ),

    
    //Read side signals declaration
    .clk_read                               (clk_uart                       ),
    .enable_read                            (manage_fifo_read_req           ),
    .data_read                              (manage_fifo_data               ),
    .flag_empty                             (empty_tx_fifo                  ),
    .valid_read                             (manage_fifo_valid              ),
    .rst_n_synched_read                     (rst_sync_tx_fifo_r             )  
);
//End of instancing tx fifo buffer section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing rx fifo buffer section
fifo_buffer_wrapper
#
(
    .DWIDTH                                 (DWIDTH                         ),
    .AWIDTH                                 (FIFO_RXAWIDTH                  ),
    .FIFO_STYLE                             (1                              ),  //0 - SCFIFO, 1 - DCFIFO
    .SYNC_RSTN                              (1                              )   //0 - async reset, 1 - synced to both write and read separately
)
                                            i_fifo_buffer_wrapper_rx
(
    //RST signlal
    .rst_n                                  (rst_n                          ),

    //Write side signals declaration
    .clk_write                              (clk_uart                       ),
    .enable_write                           (valid_from_uart                ),
    .data_write                             (data_from_uart                 ),
    .flag_full                              (full_rx_fifo                   ),
    .rst_n_synched_write                    (rst_sync_rx_fifo_w             ),

    
    //Read side signals declaration
    .clk_read                               (clk_system                     ),
    .enable_read                            (read_en_to_rx_fifo             ),
    .data_read                              (data_from_rx_fifo              ),
    .flag_empty                             (empty_rx_fifo                  ),
    .valid_read                             (valid_from_rx_fifo             ),
    .rst_n_synched_read                     (rst_sync_rx_fifo_r             )  
);
//End of instancing rx fifo buffer section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing uart tx and rx wrapper section
uart_transceiver_wrapper 
#
(
    .DWIDTH                                 (DWIDTH                         ),  //Width of the bus for: data
    .CSR_WIDTH                              (CSR_WIDTH                      )   //Width of the control-setup registers
)
                                            uart_transceiver_wrapper
(
    //Basic signals declaration
    .clk                                    (clk_uart                       ),
    .rst_n                                  (rst_n                          ),
    
    //Input data stream
    .input_stream_valid                     (manage_uart_valid              ),
    .input_stream_data                      (manage_uart_data               ),
    .input_stream_ready                     (manage_uart_ready              ),

    //Output data stream
    .output_stream_valid                    (valid_from_uart                ),
    .output_stream_data                     (data_from_uart                 ),

    //UART interface
    .uart_rx                                (uart_rx                        ),
    .uart_tx                                (uart_tx                        ),
    .uart_cts                               (uart_cts                       ),
    .uart_rts                               (uart_rts                       ),

    //Setup inputs
    .csr_setup_register                     (csr_setup_register             ),
    .csr_clk_divider_tx                     (csr_clk_divider_tx             ),
    .csr_clk_divider_rx                     (csr_clk_divider_rx             ),

    //Status outputs
    .status_parity_bit_error_tx             (status_parity_bit_error_tx     ),
    .status_parity_bit_error_rx             (status_parity_bit_error_rx     ),
    .status_stop_bit_error_tx               (status_stop_bit_error_tx       ) 
);
//End of instancing uart tx and rx wrapper section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing tx data fifo manager section
uart_tx_data_manager 
#
(
    .DWIDTH                                 (DWIDTH                         ),  //Width of the bus for: data
    .CSR_WIDTH                              (CSR_WIDTH                      )   //Width of the control-setup registers
)
                                            i_uart_tx_data_manager
(
    //Basic signals declaration
    .clk                                    (clk_uart                       ),
    .rst_n                                  (rst_n                          ),
    
    //Data from fifo
    .fifo_valid                             (manage_fifo_valid              ),
    .fifo_data                              (manage_fifo_data               ),
    .fifo_read_req                          (manage_fifo_read_req           ),

    //Data to uart
    .uart_ready                             (manage_uart_ready              ),
    .uart_valid                             (manage_uart_valid              ),
    .uart_data                              (manage_uart_data               ) 
);

//End of instancing tx data fifo manager section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule