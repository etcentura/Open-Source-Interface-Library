`timescale 1ns/1ps

module tb_i2c_transmitter_adw_7();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters for fifo section
parameter 	CSR_WIDTH 	= 32    ;
parameter 	DATA_WIDTH 	= 8     ;
parameter 	ADDR_WIDTH 	= 7     ;

//Basic signals declaration
logic 		                clk                             ;
logic 		                rst_n                           ;
//FIFO Buffer communication bus
logic 	                    fifo_valid                      ;
logic 	[DATA_WIDTH-1:0] 	fifo_data                       ;
logic 	                    fifo_read_request               ;
//Inout i2c port
logic                       i2c_sda_port_write              ;
logic                       i2c_sda_port_read               ;
logic                       i2c_scl_port                    ;

//Config signals
logic 	                    csr_start_transmission          ;
logic 	                    csr_ignore_nack                 ;
logic 	                    csr_stretch_clk                 ;
logic 	[CSR_WIDTH-1:0] 	csr_stretch_clk_dur             ;
logic 	[ADDR_WIDTH-1:0] 	csr_address_of_slave            ;
logic 	[CSR_WIDTH-1:0] 	csr_tx_bytes_num                ;
logic 	[CSR_WIDTH-1:0] 	csr_fifo_read_req_timing        ;
logic 	[CSR_WIDTH-1:0] 	csr_control_clk_gen             ;
logic 	[CSR_WIDTH-1:0] 	csr_div_cnt_limit_clk_gen       ;
logic 	[CSR_WIDTH-1:0] 	csr_raise_pos_clk_gen           ;
logic 	[CSR_WIDTH-1:0] 	csr_fall_pos_clk_gen            ;
//Status signals
logic 	                    address_transmission_error      ;    

//TB signals
int requested_bytes_delay                                   ;
//End of declaring local singals and parameters for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing dut section
i2c_transmitter 
#
(
    .CSR_WIDTH                  (CSR_WIDTH                  ),
    .DATA_WIDTH                 (DATA_WIDTH                 ),
    .ADDR_WIDTH                 (ADDR_WIDTH                 )
)
                                i_i2c_transmitter
(
    //Basic signals declaration
    .clk                        (clk                        ),
    .rst_n                      (rst_n                      ),

    //FIFO Buffer communication bus
    .fifo_valid                 (fifo_valid                 ),
    .fifo_data                  (fifo_data                  ),
    .fifo_read_request          (fifo_read_request          ),

    //Inout i2c port
    .i2c_sda_port_write         (i2c_sda_port_write         ),
    .i2c_sda_port_read          (i2c_sda_port_read          ),
    .i2c_scl_port               (i2c_scl_port               ),
    
    //Config signals
    .csr_start_transmission     (csr_start_transmission     ),
    .csr_ignore_nack            (csr_ignore_nack            ),
    .csr_stretch_clk            (csr_stretch_clk            ),
    .csr_stretch_clk_dur        (csr_stretch_clk_dur        ),
    .csr_address_of_slave       (csr_address_of_slave       ),
    .csr_tx_bytes_num           (csr_tx_bytes_num           ),
    .csr_fifo_read_req_timing   (csr_fifo_read_req_timing   ),

    .csr_control_clk_gen        (csr_control_clk_gen        ),
    .csr_div_cnt_limit_clk_gen  (csr_div_cnt_limit_clk_gen  ),
    .csr_raise_pos_clk_gen      (csr_raise_pos_clk_gen      ),
    .csr_fall_pos_clk_gen       (csr_fall_pos_clk_gen       ),

    //Status signals
    .address_transmission_error (address_transmission_error )
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
    csr_ignore_nack = '1;
    csr_stretch_clk = '0;
    csr_stretch_clk_dur = '0;
    csr_address_of_slave = 7'h5B;
    csr_tx_bytes_num = 3;
    csr_fifo_read_req_timing = 2;

    rst_n = '1;

    i2c_sda_port_read = '0;

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
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            requested_bytes_delay <= '0;
        end
    else
        begin
            if(requested_bytes_delay != 0) begin
                if(requested_bytes_delay == csr_fifo_read_req_timing - 1)begin
                    requested_bytes_delay <= '0;
                end
            end
            else begin
                if(fifo_read_request) begin
                    requested_bytes_delay <= requested_bytes_delay + 1;
                end
            end
        end
end

always_comb
begin
    if(requested_bytes_delay == csr_fifo_read_req_timing - 1)begin
        fifo_valid = '1;
        fifo_data = $urandom_range(0, 2**DATA_WIDTH-1);
    end
    else begin
        fifo_valid = '0;
        fifo_data = '0;
    end
end
//End of serving read req singal section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
