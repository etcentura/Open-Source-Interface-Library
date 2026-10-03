module i2c_tranceiver
#
(
    parameter 	    int     CSR_WIDTH 	= 32,
    parameter		int     FIFO_TX_AWIDTH		=	8                   ,
    parameter		int     FIFO_TX_FIFO_STYLE  =	0                   ,   //0 - SCFIFO, 1 - DCFIFO
    parameter       int     FIFO_TX_SYNC_RSTN   =   0                   ,   //0 - async reset, 1 - synced to both write and read separately

    parameter		int     FIFO_RX_AWIDTH		=	8                   ,
    parameter		int     FIFO_RX_FIFO_STYLE  =	0                   ,   //0 - SCFIFO, 1 - DCFIFO
    parameter       int     FIFO_RX_SYNC_RSTN   =   0                       //0 - async reset, 1 - synced to both write and read separately
)

(   
    //Basic signals declaration
    input 	    logic 		                        clk_system                                  ,
    input 	    logic 		                        clk_i2c                                     ,
    input 	    logic 		                        rst_n                                       ,
    
    //Fifo tx signals
    input		logic		                        fifo_tx_enable_write                        ,
    input		logic   [7 : 0] 	                fifo_tx_data_write                          ,
    output		logic                               fifo_tx_flag_full                           ,
    output		logic                               fifo_tx_flag_empty                          ,
    output      logic 	                            fifo_tx_rst_n_synched_write                 ,
    output      logic 	                            fifo_tx_rst_n_synched_read                  ,

    //Fifo rx signals
    input		logic		                        fifo_rx_enable_read                         ,
    output		logic   [7 : 0] 	                fifo_rx_data_read                           ,
    output		logic		                        fifo_rx_flag_full                           ,
    output		logic		                        fifo_rx_flag_empty                          ,
    output		logic		                        fifo_rx_valid_read                          ,
    output      logic 	                            fifo_rx_rst_n_synched_write                 ,
    output      logic 	                            fifo_rx_rst_n_synched_read                  ,

    //CSR bits and regeisters
    //Manager bits
    input 	    logic 	                            i2c_unit_selection                          , //0 - select transmitter, 1 - select reciever

    //Tx part bits
    input 	    logic 	                            tx_csr_start_transmission                   ,
    input 	    logic 	                            tx_csr_use_max_width_addr                   ,
    input 	    logic 	                            tx_csr_ignore_nack                          ,
    input 	    logic 	                            tx_csr_stretch_clk_enable                   ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        tx_csr_stretch_clk_dur                      ,
    input 	    logic 	[9:0]                       tx_csr_address_of_slave                     ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        tx_csr_tx_bytes_num                         ,

    input 	    logic 	[CSR_WIDTH-1:0] 	        tx_csr_control_clk_gen                      ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        tx_csr_div_cnt_limit_clk_gen                ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        tx_csr_raise_pos_clk_gen                    ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        tx_csr_fall_pos_clk_gen                     ,

    output 	    logic 	                            tx_busy_status                              ,
    output 	    logic 	                            tx_reset_required                           ,
    output 	    logic 	                            tx_address_msb_transmission_error           ,
    output 	    logic 	                            tx_address_lsb_transmission_error           ,
    output 	    logic 	                            tx_data_byte_transmission_error             ,

    //Rx part bits
    input 	    logic 	                            rx_csr_start_transmission                   ,
    input 	    logic 	                            rx_csr_use_max_width_addr                   ,
    input 	    logic 	                            rx_csr_use_register_addr_msb                ,
    input 	    logic 	                            rx_csr_use_register_addr_lsb                ,
    input 	    logic 	[7:0]                       rx_csr_register_addr_msb                    ,
    input 	    logic 	[7:0]                       rx_csr_register_addr_lsb                    ,
    input 	    logic 	                            rx_csr_ignore_nack                          ,
    input 	    logic 	                            rx_csr_stretch_clk_enable                   ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        rx_csr_stretch_clk_dur                      ,
    input 	    logic 	[9:0]                       rx_csr_address_of_slave                     ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        rx_csr_rx_bytes_num                         ,

    input 	    logic 	[CSR_WIDTH-1:0] 	        rx_csr_control_clk_gen                      ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        rx_csr_div_cnt_limit_clk_gen                ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        rx_csr_raise_pos_clk_gen                    ,
    input 	    logic 	[CSR_WIDTH-1:0] 	        rx_csr_fall_pos_clk_gen                     ,

    output 	    logic 	                            rx_busy_status                              ,
    output 	    logic 	                            rx_reset_required                           ,
    output 	    logic 	                            rx_address_msb_transmission_error           ,
    output 	    logic 	                            rx_address_lsb_transmission_error           ,
    output 	    logic 	                            rx_address_reg_msb_transmission_error       ,
    output 	    logic 	                            rx_address_reg_lsb_transmission_error       , 


    //i2c physical interface
    output      logic                               i2c_scl_line                                ,
    inout       wire                                i2c_sda_line                    
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and local parameters section

//Inout i2c port
logic                                           tx_i2c_bus_direction            ; //0 - to slave, 1 - from slave
logic                                           tx_i2c_sda_port_write           ;
logic                                           tx_i2c_sda_port_read            ;
logic                                           tx_i2c_scl_port                 ;

logic                                           rx_i2c_bus_direction            ; //0 - to slave, 1 - from slave
logic                                           rx_i2c_sda_port_write           ;
logic                                           rx_i2c_sda_port_read            ;
logic                                           rx_i2c_scl_port                 ;

//FIFO related signals
logic		                                    fifo_int_tx_enable_read         ;
logic		[7 : 0] 	                        fifo_int_tx_data_read           ;
logic		                                    fifo_int_tx_valid_read          ;

logic		[7 : 0] 	                        fifo_int_rx_data_write          ;
logic		                                    fifo_int_rx_valid_write         ;

//End of declaring local signals and local parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing tx fifo buffer section
fifo_buffer_wrapper 
#
(
    .DWIDTH		                                (8	                                    ),
    .AWIDTH		                                (FIFO_TX_AWIDTH	                        ),
    .FIFO_STYLE                                 (FIFO_TX_FIFO_STYLE                     ),  //0 - SCFIFO, 1 - DCFIFO
    .SYNC_RSTN                                  (FIFO_TX_SYNC_RSTN                      )   //0 - async reset, 1 - synced to both write and read separately
)
                                                fifo_buffer_wrapper_tx
(
    //RST signlal
    .rst_n                                      (rst_n                                  ),

    //Write side signals declaration
    .clk_write                                  (clk_system                             ),
    .enable_write                               (fifo_tx_enable_write                   ),
    .data_write                                 (fifo_tx_data_write                     ),
    .flag_full                                  (fifo_tx_flag_full                      ),
    .rst_n_synched_write                        (fifo_tx_rst_n_synched_write            ),

    
    //Read side signals declaration
    .clk_read                                   (clk_i2c                                ),
    .enable_read                                (fifo_int_tx_enable_read                ),
    .data_read                                  (fifo_int_tx_data_read                  ),
    .flag_empty                                 (fifo_tx_flag_empty                     ),
    .valid_read                                 (fifo_int_tx_valid_read                 ),
    .rst_n_synched_read                         (fifo_tx_rst_n_synched_read             )  
);
//End of instancing tx fifo buffer section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of isntancing rx fifo buffer section
fifo_buffer_wrapper 
#
(
    .DWIDTH                                     (8                                      ),
    .AWIDTH		                                (FIFO_RX_AWIDTH		                    ),
    .FIFO_STYLE                                 (FIFO_RX_FIFO_STYLE                     ),  //0 - SCFIFO, 1 - DCFIFO
    .SYNC_RSTN                                  (FIFO_RX_SYNC_RSTN                      )   //0 - async reset, 1 - synced to both write and read separately
)
                                                fifo_buffer_wrapper_rx
(
    //RST signlal
    .rst_n                                      (rst_n                                  ),

    //Write side signals declaration
    .clk_write                                  (clk_i2c                                ),
    .enable_write                               (fifo_int_rx_valid_write                ),
    .data_write                                 (fifo_int_rx_data_write                 ),
    .flag_full                                  (fifo_rx_flag_full                      ),
    .rst_n_synched_write                        (fifo_rx_rst_n_synched_write            ),

    
    //Read side signals declaration
    .clk_read                                   (clk_system                             ),
    .enable_read                                (fifo_rx_enable_read                    ),
    .data_read                                  (fifo_rx_data_read                      ),
    .flag_empty                                 (fifo_rx_flag_empty                     ),
    .valid_read                                 (fifo_rx_valid_read                     ),
    .rst_n_synched_read                         (fifo_rx_rst_n_synched_read             )
);
//End of isntancing rx fifo buffer section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing tx partition section
i2c_transmitter
#
(
    .CSR_WIDTH                                  (CSR_WIDTH                              )
)
                                                i2c_transmitter_i
(
    //Basic signals declaration
    .clk                                        (clk_i2c                                ),
    .rst_n                                      (rst_n                                  ),

    //FIFO Buffer communication bus
    .fifo_valid                                 (fifo_int_tx_valid_read                 ),
    .fifo_data                                  (fifo_int_tx_data_read                  ),
    .fifo_read_request                          (fifo_int_tx_enable_read                ),

    //Inout i2c port
    .i2c_bus_direction                          (tx_i2c_bus_direction                   ), //0 - to slave, 1 - from slave
    .i2c_sda_port_write                         (tx_i2c_sda_port_write                  ),
    .i2c_sda_port_read                          (tx_i2c_sda_port_read                   ),
    .i2c_scl_port                               (tx_i2c_scl_port                        ),
    
    //Config signals
    .csr_start_transmission                     (tx_csr_start_transmission              ),
    .csr_use_max_width_addr                     (tx_csr_use_max_width_addr              ),
    .csr_ignore_nack                            (tx_csr_ignore_nack                     ),
    .csr_stretch_clk_enable                     (tx_csr_stretch_clk_enable              ),
    .csr_stretch_clk_dur                        (tx_csr_stretch_clk_dur                 ),
    .csr_address_of_slave                       (tx_csr_address_of_slave                ),
    .csr_tx_bytes_num                           (tx_csr_tx_bytes_num                    ),

    .csr_control_clk_gen                        (tx_csr_control_clk_gen                 ),
    .csr_div_cnt_limit_clk_gen                  (tx_csr_div_cnt_limit_clk_gen           ),
    .csr_raise_pos_clk_gen                      (tx_csr_raise_pos_clk_gen               ),
    .csr_fall_pos_clk_gen                       (tx_csr_fall_pos_clk_gen                ),

    //Status signals
    .busy_status                                (tx_busy_status                         ),
    .reset_required                             (tx_reset_required                      ),
    .address_msb_transmission_error             (tx_address_msb_transmission_error      ),
    .address_lsb_transmission_error             (tx_address_lsb_transmission_error      ),
    .data_byte_transmission_error               (tx_data_byte_transmission_error        )
);
//End of instancing tx partition section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing rx partition section
i2c_receiver 
#
(
    .CSR_WIDTH                                  (CSR_WIDTH                              )
)
                                                i2c_receiver_i
(
    //Basic signals declaration
    .clk                                        (clk_i2c                                ),
    .rst_n                                      (rst_n                                  ),

    //FIFO Buffer communication bus
    .fifo_valid                                 (fifo_int_rx_valid_write                ),
    .fifo_data                                  (fifo_int_rx_data_write                 ),

    //Inout i2c port
    .i2c_bus_direction                          (rx_i2c_bus_direction                   ), //0 - to slave, 1 - from slave
    .i2c_sda_port_write                         (rx_i2c_sda_port_write                  ),
    .i2c_sda_port_read                          (rx_i2c_sda_port_read                   ),
    .i2c_scl_port                               (rx_i2c_scl_port                        ),
    
    //Config signals
    .csr_start_transmission                     (rx_csr_start_transmission              ),
    .csr_use_max_width_addr                     (rx_csr_use_max_width_addr              ),
    .csr_use_register_addr_msb                  (rx_csr_use_register_addr_msb           ),
    .csr_use_register_addr_lsb                  (rx_csr_use_register_addr_lsb           ),
    .csr_register_addr_msb                      (rx_csr_register_addr_msb               ),
    .csr_register_addr_lsb                      (rx_csr_register_addr_lsb               ),
    .csr_ignore_nack                            (rx_csr_ignore_nack                     ),
    .csr_stretch_clk_enable                     (rx_csr_stretch_clk_enable              ),
    .csr_stretch_clk_dur                        (rx_csr_stretch_clk_dur                 ),
    .csr_address_of_slave                       (rx_csr_address_of_slave                ),
    .csr_rx_bytes_num                           (rx_csr_rx_bytes_num                    ),

   .csr_control_clk_gen                         (rx_csr_control_clk_gen                 ),
   .csr_div_cnt_limit_clk_gen                   (rx_csr_div_cnt_limit_clk_gen           ),
   .csr_raise_pos_clk_gen                       (rx_csr_raise_pos_clk_gen               ),
   .csr_fall_pos_clk_gen                        (rx_csr_fall_pos_clk_gen                ),

    //Status signals
    .busy_status                                (rx_busy_status                         ),
    .reset_required                             (rx_reset_required                      ),
    .address_msb_transmission_error             (rx_address_msb_transmission_error      ),
    .address_lsb_transmission_error             (rx_address_lsb_transmission_error      ),
    .address_reg_msb_transmission_error         (rx_address_reg_msb_transmission_error  ),
    .address_reg_lsb_transmission_error         (rx_address_reg_lsb_transmission_error  )
);
//End of instancing rx partition section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing line manager section
i2c_line_manager                                i2c_line_manager_i
(
    //Select between tx and rx for the i2c
    .i2c_unit_selection                         (i2c_unit_selection                     ), //0 - select transmitter, 1 - select reciever

    //Main i2c bus
    .i2c_scl_line                               (i2c_scl_line                           ),
    .i2c_sda_line                               (i2c_sda_line                           ),

    //Bus connected to the transmitter
    .i2c_transmitter_clock                      (tx_i2c_scl_port                        ),
    .i2c_transmitter_bus_direction              (tx_i2c_bus_direction                   ),
    .i2c_transmitter_write_data                 (tx_i2c_sda_port_write                  ),
    .i2c_transmitter_read_data                  (tx_i2c_sda_port_read                   ),

    //Bus connected to the reciever
    .i2c_reciever_clock                         (rx_i2c_scl_port                        ),
    .i2c_reciever_bus_direction                 (rx_i2c_bus_direction                   ),
    .i2c_reciever_write_data                    (rx_i2c_sda_port_write                  ),
    .i2c_reciever_read_data                     (rx_i2c_sda_port_read                   ) 
);
//End of instancing line manager section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule