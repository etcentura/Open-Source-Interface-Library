`timescale 1ns/1ps

module tb_uart_wrapper();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters for fifo section
parameter		int     DWIDTH              =	7    ;
parameter       int     CSR_WIDTH           =   32   ;
parameter		int     FIFO_TXAWIDTH		=	5    ;
parameter		int     FIFO_RXAWIDTH		=	5    ;

//Basic signals declaration
logic 		                    clk_system                  ;
logic 		                    clk_uart                    ;
logic 		                    rst_n                       ;
//Data flow to tx fifo
logic 	                        valid_to_tx_fifo            ;
logic 	[DWIDTH - 1 : 0] 	    data_to_tx_fifo             ;
logic 	                        full_tx_fifo                ;
logic 	                        empty_tx_fifo               ;
logic 	                        rst_sync_tx_fifo_w          ;
logic 	                        rst_sync_tx_fifo_r          ;
//Data flow from rx fifo
logic 	                        read_en_to_rx_fifo          ;
logic 	                        valid_from_rx_fifo          ;
logic 	[DWIDTH - 1 : 0] 	    data_from_rx_fifo           ;
logic 	                        full_rx_fifo                ;
logic 	                        empty_rx_fifo               ;
logic 	                        rst_sync_rx_fifo_w          ;
logic 	                        rst_sync_rx_fifo_r          ;
//UART interface
logic 	                        uart_rx                     ;
logic 	                        uart_tx                     ;
logic 	                        uart_cts                    ;
logic 	                        uart_rts                    ;
//CSR registers
logic 	[CSR_WIDTH - 1 : 0] 	csr_setup_register          ;
logic 	[CSR_WIDTH - 1 : 0] 	csr_clk_divider_tx          ;
logic 	[CSR_WIDTH - 1 : 0] 	csr_clk_divider_rx          ;
//Status outputs
logic 	                        status_parity_bit_error_tx  ;
logic 	                        status_parity_bit_error_rx  ;
logic 	                        status_stop_bit_error_tx    ;

//End of declaring local singals and parameters for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing dut section
uart_wrapper 
#
(
    .DWIDTH                                 (DWIDTH                         ),   //Width of the bus for: data
    .CSR_WIDTH                              (CSR_WIDTH                      ),   //Width of the control-setup registers
    .FIFO_TXAWIDTH                          (FIFO_TXAWIDTH                  ),
    .FIFO_RXAWIDTH                          (FIFO_RXAWIDTH                  )
)
                                            i_uart_wrapper
(
    //Basic signals declaration
    .clk_system                             (clk_system                     ),
    .clk_uart                               (clk_uart                       ),
    .rst_n                                  (rst_n                          ),

    //Data flow to tx fifo
    .valid_to_tx_fifo                       (valid_to_tx_fifo               ),
    .data_to_tx_fifo                        (data_to_tx_fifo                ),
    .full_tx_fifo                           (full_tx_fifo                   ),
    .empty_tx_fifo                          (empty_tx_fifo                  ),
    .rst_sync_tx_fifo_w                     (rst_sync_tx_fifo_w             ),
    .rst_sync_tx_fifo_r                     (rst_sync_tx_fifo_r             ),

    //Data flow from rx fifo
    .read_en_to_rx_fifo                     (read_en_to_rx_fifo             ),
    .valid_from_rx_fifo                     (valid_from_rx_fifo             ),
    .data_from_rx_fifo                      (data_from_rx_fifo              ),
    .full_rx_fifo                           (full_rx_fifo                   ),
    .empty_rx_fifo                          (empty_rx_fifo                  ),
    .rst_sync_rx_fifo_w                     (rst_sync_rx_fifo_w             ),
    .rst_sync_rx_fifo_r                     (rst_sync_rx_fifo_r             ),

    //UART interface
    .uart_rx                                (uart_rx                        ),
    .uart_tx                                (uart_tx                        ),
    .uart_cts                               (uart_cts                       ),
    .uart_rts                               (uart_rts                       ),

    //CSR registers
    .csr_setup_register                     (csr_setup_register             ),
    .csr_clk_divider_tx                     (csr_clk_divider_tx             ),
    .csr_clk_divider_rx                     (csr_clk_divider_rx             ),

    //Status outputs
    .status_parity_bit_error_tx             (status_parity_bit_error_tx     ),
    .status_parity_bit_error_rx             (status_parity_bit_error_rx     ),
    .status_stop_bit_error_tx               (status_stop_bit_error_tx       )

);
//End of instancing dut section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk clock section
//Writing is faster than reading
initial
begin : clk_generation_clk_system
	clk_system = 0;
	forever #5 clk_system=~clk_system;
end

initial
begin : clk_generation_clk_uart
	clk_uart = 0;
	forever #10 clk_uart=~clk_uart;
end
//End of generatring clk clock section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of making loopback from tx to rx to check wheteher the transmission correct section
assign uart_rx = uart_tx;
//End of making loopback from tx to rx to check wheteher the transmission correct section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating main scenario section section
initial 
begin: main_scenario
    rst_n = '1;
    valid_to_tx_fifo = '0;
    data_to_tx_fifo = '0;
    read_en_to_rx_fifo = '0;
    uart_cts = '0;
    
    csr_setup_register = '0;
    csr_setup_register[0] = '1;
    csr_setup_register[3:1] = 1;    //parity is odd
    csr_setup_register[6:4] = 1;    //parity is odd
    csr_setup_register[8:7] = 0;    //1 stop bit
    csr_setup_register[9] = 0;      //don't use the cts on tx

    csr_clk_divider_tx = 97; //f_in/f_out=2n f_in = 10 MHz, f_out = 256kHz, n = 18
    csr_clk_divider_rx = 97; //f_in/f_out=2n f_in = 10 MHz, f_out = 256kHz, n = 18

    repeat(150) @(posedge clk_system);
    rst_n = '0;

    while(1) begin
        @(posedge clk_system);
        if(rst_sync_tx_fifo_w && rst_sync_tx_fifo_r && rst_sync_rx_fifo_w && rst_sync_rx_fifo_r) begin
            break;
        end
    end

    repeat(150) @(posedge clk_system);
    rst_n <= '1;
    @(posedge clk_system);

    repeat(100) @(posedge clk_system);

    valid_to_tx_fifo <= '1;
    data_to_tx_fifo <= 7'h2a;
    @(posedge clk_system);

    valid_to_tx_fifo <= '1;
    data_to_tx_fifo <= '0;
    @(posedge clk_system);

    valid_to_tx_fifo <= '1;
    data_to_tx_fifo <= 7'b1010001;
    @(posedge clk_system);

    valid_to_tx_fifo <= '1;
    data_to_tx_fifo <= 7'b1101001;
    @(posedge clk_system);

    valid_to_tx_fifo <= '1;
    data_to_tx_fifo <= '1;
    @(posedge clk_system);

    valid_to_tx_fifo <= '0;
    @(posedge clk_system);

    repeat(50000) @(posedge clk_system);

    read_en_to_rx_fifo <= '1;
    repeat(5) @(posedge clk_system);
    read_en_to_rx_fifo <= '0;
    repeat(50) @(posedge clk_system);
    $finish;
end


//End of generating main scenario section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule