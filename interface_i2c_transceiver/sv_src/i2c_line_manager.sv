module i2c_line_manager

(
    //Select between tx and rx for the i2c
    input 	    logic 	    i2c_unit_selection              , //0 - select transmitter, 1 - select reciever

    //Main i2c bus
    output      logic       i2c_scl_line                    ,
    inout       wire        i2c_sda_line                    ,

    //Bus connected to the transmitter
    input 	    logic 	    i2c_transmitter_clock           ,
    input 	    logic 	    i2c_transmitter_bus_direction   ,
    input 	    logic 	    i2c_transmitter_write_data      ,
    output 	    logic 	    i2c_transmitter_read_data       ,

    //Bus connected to the reciever
    input 	    logic 	    i2c_reciever_clock              ,
    input 	    logic 	    i2c_reciever_bus_direction      ,
    input 	    logic 	    i2c_reciever_write_data         ,
    output 	    logic 	    i2c_reciever_read_data          
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//Muxed signals
logic 	                i2c_muxed_clock             ;
logic 	                i2c_muxed_bus_direction     ;
logic 	                i2c_muxed_write_data        ;
logic 	                i2c_muxed_read_data         ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of muxing clock section
assign i2c_muxed_clock = (i2c_unit_selection) ? i2c_transmitter_clock : i2c_reciever_clock;
//End of muxing clock section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of muxing bus direction section section
assign i2c_muxed_bus_direction = (i2c_unit_selection) ? i2c_transmitter_bus_direction : i2c_reciever_bus_direction;
//End of muxing bus direction section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of muxing write data section
assign i2c_muxed_write_data = (i2c_unit_selection) ? i2c_transmitter_write_data : i2c_reciever_write_data;
//End of muxing write data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of muxing read data section
always_comb
begin
    if(i2c_unit_selection) begin
        i2c_transmitter_read_data = i2c_muxed_read_data;
        i2c_reciever_read_data = '1; //1 because even if something goes wrong this value will be recognized as nack
    end
    else begin
        i2c_transmitter_read_data = '1;
        i2c_reciever_read_data = i2c_muxed_read_data; //1 because even if something goes wrong this value will be recognized as nack
    end
end
//End of muxing read data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of managing i2c physical interface section
assign i2c_scl_line = i2c_muxed_clock;
assign i2c_sda_line = (i2c_muxed_bus_direction) ? 1'bz : i2c_muxed_write_data;
assign i2c_muxed_read_data = i2c_sda_line;
//End of managing i2c physical interface section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule