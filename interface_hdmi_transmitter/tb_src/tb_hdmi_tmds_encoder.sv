`timescale 1ns/1ps

module tb_hdmi_tmds_encoder();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section
//Basic signals declaration
logic		            clk                     ;   //Basic clk signal
logic		            rst_n                   ;
//Input data
logic		            input_stream_valid      ;   // Input stream valid
logic		[7 : 0] 	input_stream_data       ;   // Input stream data (non-encoded 8 bits data)
//Output data 
logic		            output_stream_valid     ;   // Output stream valid
logic       [9 : 0] 	output_stream_data      ;
//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing dut section
hdmi_tmds_encoder hdmi_tmds_encoder
(
    //Basic signals declaration
    .clk                     (clk                   ),   //Basic clk signal
    .rst_n                   (rst_n                 ),
    
    //Input data
    .input_stream_valid      (input_stream_valid    ),   // Input stream valid
    .input_stream_data       (input_stream_data     ),   // Input stream data (non-encoded 8 bits data)

    //Output data 
    .output_stream_valid     (output_stream_valid   ),   // Output stream valid
    .output_stream_data      (output_stream_data    )    // Output stream data (encoded 10 bits data)
);
//End of instancing dut section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of clk generation section

//Assuming these clks are:
initial
begin
    clk = 0;
    forever #20 clk = !clk;
end
//End of clk generation section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of task to send data section
task send_data();
    @(posedge clk);
    input_stream_valid <= '1;
    input_stream_data <= $urandom_range(0, 255);

    @(posedge clk);
    while (1) begin
        @(posedge clk);
        if(output_stream_valid) begin
            $display("Original data %b vs encoded data %b", input_stream_data, output_stream_data);
            break;
        end
    end
endtask
//End of task to send data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating main scenario section
initial begin
    input_stream_valid = '0;
    input_stream_data = '0;

    #0      rst_n =  1;
    #100  rst_n =  0;
    #100  rst_n =  1;
    @(posedge clk);

    for (int i = 0; i < 10; i++) begin
        send_data();
    end
end
//End of generating main scenario section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule