`timescale 1ns/1ps

module tb_uart_tester();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters for fifo section
logic 		            clk             ;
logic 		            rst_n           ;
logic 	                input_button    ;
logic                   uart_tx         ;
logic                   uart_rx         ;
//End of declaring local singals and parameters for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing dut section
uart_rx_tester          i_uart_rx_tester 
(
    //Basic signals declaration
    .clk                (clk            ),
    .rst_n              (rst_n          ),

    //Input button signal
    .input_button       (input_button   ),
    .uart_tx            (uart_tx        ),
    .uart_rx            (uart_rx        )
);

//End of instancing dut section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk clock section
//Writing is faster than reading
initial
begin : clk_generation_clk
	clk = 0;
	forever #10 clk=~clk;
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
    input_button = '1;
    
    @(posedge clk);
    rst_n <= '0;

    repeat(50) @(posedge clk);

    rst_n <= '1;

    repeat(50) @(posedge clk);

    input_button <= '0;
end


//End of generating main scenario section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
