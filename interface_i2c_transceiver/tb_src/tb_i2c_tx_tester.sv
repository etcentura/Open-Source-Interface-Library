`timescale 1ns/1ps

module tb_i2c_tx_tester();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section
//Basic signals declaration
logic 		        clk                 ;
logic 		        rst_n               ;
//Test led
logic 		        led_test_busy       ;
logic 		        led_reset_required  ;
//i2c physical interface
logic               i2c_scl_line        ;
wire                i2c_sda_line        ;


//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing dut section
i2c_tx_tester                   i2c_tx_tester_i 
(
    //Basic signals declaration
    .clk                        (clk                    ),
    .rst_n                      (rst_n                  ),

    //Test led
    .led_test_busy              (led_test_busy          ),
    .led_reset_required         (led_reset_required     ),

    //i2c physical interface
    .i2c_scl_line               (i2c_scl_line           ),
    .i2c_sda_line               (i2c_sda_line           )
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
//Begin of generating main scenario section
initial begin:main
    rst_n = '1;

    force i2c_tx_tester_i.i_i2c_line_manager.i2c_transmitter_read_data = '0;
    
    #250ns rst_n = '0;
    #250ns rst_n = '1;
end
//End of generating main scenario section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule