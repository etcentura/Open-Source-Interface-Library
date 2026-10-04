module i2c_tx_tester
(
    //Basic signals declaration
    input 	    logic 		        clk                 ,
    input 	    logic 		        rst_n               ,
    output 	    logic 		        rst_n_registered    ,

    //Test led
    output 	    logic 		        led_test_busy       ,
    output 	    logic 		        led_reset_required  ,

    //i2c physical interface
    output      logic               i2c_scl_line        ,
    inout       wire                i2c_sda_line        
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//i2c manager signals
logic                               i2c_bus_direction               ; //0 - to slave, 1 - from slave
logic                               i2c_sda_port_write              ;
logic                               i2c_sda_port_read               ;
logic                               i2c_scl_port                    ;

//Test signals
logic 	[31:0] 	                    test_counter                    ;
logic 	[31:0] 	                    test_timeout                    ;
logic 	                            test_valid                      ;
logic 	                            test_start                      ;
logic 	                            fifo_read_request               ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of creating tester section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            test_counter <= '0;
        end
    else
        begin
            if(test_valid)begin
                test_counter <= test_counter + 1;
            end
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            test_valid <= '0;
        end
    else
        begin
            if(fifo_read_request)begin
                test_valid <= '1;
            end
            else begin
                test_valid <= '0;
            end
        end
end

always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            test_start <= '0;
            test_timeout <= '0;
        end
    else
        begin
            if(!led_test_busy)begin
                if(test_timeout == 25000)begin
                   test_start <= '1;
                   test_timeout <= '0;
                end
                else begin
                    test_timeout <= test_timeout + 1;
                    test_start <= '0;
                end
            end
            else begin
                test_start <= '0;
                test_timeout <= '0;
            end
        end
end
//End of creating tester section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing tx part section
i2c_transmitter 
#
(
    .CSR_WIDTH                                  (32                             )
)
                                                i2c_transmitter_i
(
    //Basic signals declaration
    .clk                                        (clk                            ),
    .rst_n                                      (rst_n                          ),

    //FIFO Buffer communication bus
    .fifo_valid                                 (test_valid                     ),
    .fifo_data                                  (test_counter                   ),
    .fifo_read_request                          (fifo_read_request              ),

    //Inout i2c port
    .i2c_bus_direction                          (i2c_bus_direction              ), //0 - to slave, 1 - from slave
    .i2c_sda_port_write                         (i2c_sda_port_write             ),
    .i2c_sda_port_read                          (i2c_sda_port_read              ),
    .i2c_scl_port                               (i2c_scl_port                   ),
    
    //Config signals
    .csr_start_transmission                     (test_start                     ),
    .csr_use_max_width_addr                     ('0                             ),
    .csr_ignore_nack                            ('0                             ),
    .csr_stretch_clk_enable                     ('0                             ),
    .csr_stretch_clk_dur                        ('0                             ),
    .csr_address_of_slave                       (62                             ),
    .csr_tx_bytes_num                           (2                              ),

    .csr_control_clk_gen                        (1                              ),
    .csr_div_cnt_limit_clk_gen                  (25_000                         ),
    .csr_raise_pos_clk_gen                      (12_500                         ),
    .csr_fall_pos_clk_gen                       (24_998                         ),

    //Status signals
    .busy_status                                (led_test_busy                  ),
    .reset_required                             (led_reset_required             ),
    .address_msb_transmission_error             (                               ),
    .address_lsb_transmission_error             (                               ),
    .data_byte_transmission_error               (                               )
);
//End of instancing tx part section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing line manager and setting it to the transmitter section
i2c_line_manager                                i_i2c_line_manager

(
    //Select between tx and rx for the i2c
    .i2c_unit_selection                         ('0                             ), //0 - select transmitter, 1 - select reciever

    //Main i2c bus
    .i2c_scl_line                               (i2c_scl_line                   ),
    .i2c_sda_line                               (i2c_sda_line                   ),

    //Bus connected to the transmitter
    .i2c_transmitter_clock                      (i2c_scl_port                   ),
    .i2c_transmitter_bus_direction              (i2c_bus_direction              ),
    .i2c_transmitter_write_data                 (i2c_sda_port_write             ),
    .i2c_transmitter_read_data                  (i2c_sda_port_read              ),

    //Bus connected to the reciever
    .i2c_reciever_clock                         ('1                             ),
    .i2c_reciever_bus_direction                 ('0                             ),
    .i2c_reciever_write_data                    ('0                             ),
    .i2c_reciever_read_data                     (                               ) 
);
//End of instancing line manager and setting it to the transmitter section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving register for rst_n section
always_ff @(posedge clk)
begin
    rst_n_registered <= rst_n;
end
//End of driving register for rst_n section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule