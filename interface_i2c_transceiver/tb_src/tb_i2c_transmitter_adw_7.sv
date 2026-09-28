`timescale 1ns/1ps

module tb_i2c_transmitter_adw_7();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters for fifo section
parameter 	CSR_WIDTH 	= 32    ;

//Basic signals declaration
logic 		                        clk                             ;
logic 		                        rst_n                           ;
//FIFO Buffer communication bus
logic 	                            fifo_valid                      ;
logic 	[7:0] 	                    fifo_data                       ;
logic 	                            fifo_read_request               ;
//Inout i2c port
logic                               i2c_sda_port_write              ;
logic                               i2c_sda_port_read               ;
logic                               i2c_scl_port                    ;

//Config signals
logic 	                            csr_start_transmission          ;
logic 	                            csr_use_max_width_addr          ;
logic 	                            csr_ignore_nack                 ;
logic 	                            csr_stretch_clk_enable          ;
logic 	[CSR_WIDTH-1:0] 	        csr_stretch_clk_dur             ;
logic 	[9:0]                       csr_address_of_slave            ;
logic 	[CSR_WIDTH-1:0] 	        csr_tx_bytes_num                ;
logic 	[CSR_WIDTH-1:0] 	        csr_control_clk_gen             ;
logic 	[CSR_WIDTH-1:0] 	        csr_div_cnt_limit_clk_gen       ;
logic 	[CSR_WIDTH-1:0] 	        csr_raise_pos_clk_gen           ;
logic 	[CSR_WIDTH-1:0] 	        csr_fall_pos_clk_gen            ;
//Status signals
logic 	                            busy_status                     ;
logic 	                            reset_required                  ;
logic 	                            address_msb_transmission_error  ;
logic 	                            address_lsb_transmission_error  ;
logic 	                            data_byte_transmission_error    ;
//End of declaring local singals and parameters for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing dut section
i2c_transmitter 
#
(
    .CSR_WIDTH                          (CSR_WIDTH                          )
)
                                        i_i2c_transmitter
(
    //Basic signals declaration
    .clk                                (clk                                ),
    .rst_n                              (rst_n                              ),

    //FIFO Buffer communication bus
    .fifo_valid                         (fifo_valid                         ),
    .fifo_data                          (fifo_data                          ),
    .fifo_read_request                  (fifo_read_request                  ),

    //Inout i2c port
    .i2c_sda_port_write                 (i2c_sda_port_write                 ),
    .i2c_sda_port_read                  (i2c_sda_port_read                  ),
    .i2c_scl_port                       (i2c_scl_port                       ),
    
    //Config signals
    .csr_start_transmission             (csr_start_transmission             ),
    .csr_use_max_width_addr             (csr_use_max_width_addr             ),
    .csr_ignore_nack                    (csr_ignore_nack                    ),
    .csr_stretch_clk_enable             (csr_stretch_clk_enable             ),
    .csr_stretch_clk_dur                (csr_stretch_clk_dur                ),
    .csr_address_of_slave               (csr_address_of_slave               ),
    .csr_tx_bytes_num                   (csr_tx_bytes_num                   ),

    .csr_control_clk_gen                (csr_control_clk_gen                ),
    .csr_div_cnt_limit_clk_gen          (csr_div_cnt_limit_clk_gen          ),
    .csr_raise_pos_clk_gen              (csr_raise_pos_clk_gen              ),
    .csr_fall_pos_clk_gen               (csr_fall_pos_clk_gen               ),

    //Status signals
    .busy_status                        (busy_status                        ),
    .reset_required                     (reset_required                     ),
    .address_msb_transmission_error     (address_msb_transmission_error     ),
    .address_lsb_transmission_error     (address_lsb_transmission_error     ),
    .data_byte_transmission_error       (data_byte_transmission_error       )
);
//End of instancing dut section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk clock section
//Writing is faster than reading
initial
begin : clk_generation_clk
	clk = 0;
	forever #5 clk=~clk;
end
//End of generatring clk clock section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating main scenario section
initial begin:main
    //Generate simple 50% duty clk, no phase shift on randomly choosen slower frequency, no freeze, no half prescale
    csr_control_clk_gen ='0;
    csr_control_clk_gen[0] ='1;
    csr_control_clk_gen[1] ='0;
    csr_control_clk_gen[2] ='0;
    csr_div_cnt_limit_clk_gen = 500;
    csr_raise_pos_clk_gen = 249;
    csr_fall_pos_clk_gen = 499;

    csr_start_transmission = '0;

    // Test 1 - ignore nack, stretch clk off, 8 bytes to transmit, 2 bits after byte started to request data
    rst_n = '1;

    i2c_sda_port_read = '0;

    csr_start_transmission          =   '0;
    csr_use_max_width_addr          =   '0;
    csr_ignore_nack                 =   '0;
    csr_stretch_clk_enable          =   '0;
    csr_stretch_clk_dur             =   '0;
    csr_address_of_slave            =   '0;
    csr_address_of_slave            =   7'h5B;
    csr_tx_bytes_num                =   3;

    repeat(50) @(posedge clk);
    rst_n <= '0;
    repeat(50) @(posedge clk);
    rst_n <= '1;
    repeat(50) @(posedge clk);

    csr_start_transmission <= '1;
    
    repeat(5) @(posedge clk);
    csr_start_transmission <= '0;

    #1ms $finish();
    
end
//End of generating main scenario section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of serving read req singal section
initial begin
    while (1) begin
        @(posedge clk);
        if(fifo_read_request)begin
            fifo_valid  <= '1;
            fifo_data   <= $urandom_range(0, 255);
        end
        else begin
            fifo_valid  <= '0;
            fifo_data   <= '0;
        end
    end
end
//End of serving read req singal section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of printing sent byte section
initial begin
    while (1) begin
        @(posedge clk);
        if (fifo_valid) begin
            $display("Byte sent %h", fifo_data);
        end
    end
end
//End of printing sent byte section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
