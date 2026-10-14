module spi_master_unit
#
(
    parameter 	    int     CSR_WIDTH 	            =   32                  ,
    parameter 	    int     CHIP_SELECT_SLAVES      =   32                  ,

    parameter 	    int     FIFO_TX_MAX_WORD_LEN    =   32                  ,
    parameter 	    int     FIFO_TX_AWIDTH          =   32                  ,
    parameter		int     FIFO_TX_FIFO_STYLE      =	0                   ,   //0 - SCFIFO, 1 - DCFIFO
    parameter       int     FIFO_TX_SYNC_RSTN       =   0                   ,   //0 - async reset, 1 - synced to both write and read separately


    parameter 	    int     FIFO_RX_MAX_WORD_LEN    =   32                  ,
    parameter 	    int     FIFO_RX_AWIDTH          =   32                  ,
    parameter		int     FIFO_RX_FIFO_STYLE      =	0                   ,   //0 - SCFIFO, 1 - DCFIFO
    parameter       int     FIFO_RX_SYNC_RSTN       =   0                       //0 - async reset, 1 - synced to both write and read separately

)

(
    //Basic signals declaration
    input 	    logic 		                            clk                                         ,
    input 	    logic 		                            rst_n                                       ,

    //SPI interface signals
    output 	    logic 	                                spi_clk                                     ,
    output 	    logic 	                                spi_data_out                                ,
    input 	    logic 	                                spi_data_input                              ,
    output 	    logic   [CHIP_SELECT_SLAVES - 1 : 0]    spi_chip_select                             ,

    //Fifo tx signals
    input		logic		                            fifo_tx_enable_write                        ,
    input		logic   [FIFO_TX_MAX_WORD_LEN - 1 : 0]  fifo_tx_data_write                          ,
    output		logic                                   fifo_tx_flag_full                           ,
    output		logic                                   fifo_tx_flag_empty                          ,
    output      logic 	                                fifo_tx_rst_n_synched_write                 ,
    output      logic 	                                fifo_tx_rst_n_synched_read                  ,

    //Fifo rx signals
    input		logic		                            fifo_rx_enable_read                         ,
    output		logic   [FIFO_RX_MAX_WORD_LEN - 1 : 0]  fifo_rx_data_read                           ,
    output		logic		                            fifo_rx_flag_full                           ,
    output		logic		                            fifo_rx_flag_empty                          ,
    output		logic		                            fifo_rx_valid_read                          ,
    output      logic 	                                fifo_rx_rst_n_synched_write                 ,
    output      logic 	                                fifo_rx_rst_n_synched_read                  ,

    //CSR bits and registers

    //Setup for clk divider
    input 	    logic 	[CSR_WIDTH-1:0] 	            csr_control_clk_gen                         ,
    input 	    logic 	[CSR_WIDTH-1:0] 	            csr_div_cnt_limit_clk_gen                   ,
    input 	    logic 	[CSR_WIDTH-1:0] 	            csr_raise_pos_clk_gen                       ,
    input 	    logic 	[CSR_WIDTH-1:0] 	            csr_fall_pos_clk_gen                        ,

    //Setup for spi transmission
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of decalring local signals and parameters section

//Clock divider signals
logic 	                                        clk_divider_generated_clk       ;
logic 	                                        clk_divider_generated_err       ;

//Fron detector for the generated clk
logic 	                                        clk_divider_generated_clk_reg   ;
logic 	                                        clk_divider_generated_clk_pos   ;
logic 	                                        clk_divider_generated_clk_neg   ;

//End of decalring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving setup registers section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            
        end
    else 
        begin
            if ((state == IDLE) && (csr_start_transmission)) begin
                
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
//Begin of declaring generated clk front detector section
always_ff @(posedge clk or negedge rst_n)
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
//End of declaring generated clk front detector section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing fsm controller section
//TODO
//End of instancing fsm controller section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring tx fifo section
fifo_buffer_wrapper 
#
(
    .DWIDTH		                                (FIFO_TX_MAX_WORD_LEN                   ),
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
    .clk_read                                   (clk_divider_generated_clk              ),
    .enable_read                                (                                       ),
    .data_read                                  (                                       ),
    .flag_empty                                 (fifo_tx_flag_empty                     ),
    .valid_read                                 (                                       ),
    .rst_n_synched_read                         (fifo_tx_rst_n_synched_read             )  
);
//End of declaring tx fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring rx fifo section
fifo_buffer_wrapper 
#
(
    .DWIDTH                                     (FIFO_RX_MAX_WORD_LEN                   ),
    .AWIDTH		                                (FIFO_RX_AWIDTH		                    ),
    .FIFO_STYLE                                 (FIFO_RX_FIFO_STYLE                     ),  //0 - SCFIFO, 1 - DCFIFO
    .SYNC_RSTN                                  (FIFO_RX_SYNC_RSTN                      )   //0 - async reset, 1 - synced to both write and read separately
)
                                                fifo_buffer_wrapper_rx
(
    //RST signlal
    .rst_n                                      (rst_n                                  ),

    //Write side signals declaration
    .clk_write                                  (clk_divider_generated_clk              ),
    .enable_write                               (                                       ),
    .data_write                                 (                                       ),
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
//End of declaring rx fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring section



//End of declaring section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule