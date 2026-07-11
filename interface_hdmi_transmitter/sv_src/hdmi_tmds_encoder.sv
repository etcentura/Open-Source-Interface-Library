module hdmi_tmds_encoder
(
    //Basic signals declaration
    input		logic		            clk                     ,   //Basic clk signal

    //Input data
    input		logic		            input_stream_valid      ,   // Input stream valid
    input		logic		[7 : 0] 	input_stream_data       ,   // Input stream data (non-encoded 8 bits data)

    //Output data 
    output		logic		            output_stream_valid     ,   // Output stream valid
    output		logic		[9 : 0] 	output_stream_data          // Output stream data (encoded 10 bits data)
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of local signals and parameters section

//Registering input signals
logic		            input_stream_valid_reg  ;   // Input stream valid
logic		[7 : 0] 	input_stream_data_reg   ;   // Input stream data (non-encoded 8 bits data)
logic		[3 : 0] 	input_stream_data_ones  ;   // Calculaitng input number of ones in data

//First stage encoding section
logic		            stage_1_valid_enc       ;   // Stage 1 encoded stream valid (combinational encoding signal)
logic		[8 : 0] 	stage_1_data_enc        ;   // Stage 1 encoded stream data (combinational encoding signal)
logic		            stage_1_valid_reg       ;   // Stage 1 encoded stream valid (registering signal)
logic		[8 : 0] 	stage_1_data_reg        ;   // Stage 1 encoded stream data (registering signal)

//Disparity counters
logic		[3 : 0] 	disparity_prev          ;   // Disparity counter for the previous value beging encoded
logic		[3 : 0] 	disparity_counter       ;   // Disparity counter for the current value being encoded
//End of local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching input data section
always_ff @(posedge clk)
begin
    input_stream_valid_reg <= '0;
    if(input_stream_valid)
        begin
            input_stream_valid_reg <= '1;
            input_stream_data_reg <= input_stream_data;
            input_stream_data_ones <= 
                                        input_stream_data[0] + input_stream_data[1] + input_stream_data[2] + input_stream_data[3] + 
                                        input_stream_data[4] + input_stream_data[5] + input_stream_data[6] + input_stream_data[7];
        end
end
//End of latching input data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of combinational first stage encoding section
always_comb
begin
    stage_1_valid_enc = input_stream_valid_reg;
    if((input_stream_data_ones > 4) || ((input_stream_data_ones == 4) && (input_stream_data_reg[0] == 0))) begin
        stage_1_data_enc[0] = input_stream_data_reg[0];
        stage_1_data_enc[1] = ~(stage_1_data_enc[0] ^ input_stream_data_reg[1]);
        stage_1_data_enc[2] = ~(stage_1_data_enc[1] ^ input_stream_data_reg[2]);
        stage_1_data_enc[3] = ~(stage_1_data_enc[2] ^ input_stream_data_reg[3]);
        stage_1_data_enc[4] = ~(stage_1_data_enc[3] ^ input_stream_data_reg[4]);
        stage_1_data_enc[5] = ~(stage_1_data_enc[4] ^ input_stream_data_reg[5]);
        stage_1_data_enc[6] = ~(stage_1_data_enc[5] ^ input_stream_data_reg[6]);
        stage_1_data_enc[7] = ~(stage_1_data_enc[6] ^ input_stream_data_reg[7]);
        stage_1_data_enc[8] = 0;
    end
    else begin
        stage_1_data_enc[0] = input_stream_data_reg[0];
        stage_1_data_enc[1] = (stage_1_data_enc[0] ^ input_stream_data_reg[1]);
        stage_1_data_enc[2] = (stage_1_data_enc[1] ^ input_stream_data_reg[2]);
        stage_1_data_enc[3] = (stage_1_data_enc[2] ^ input_stream_data_reg[3]);
        stage_1_data_enc[4] = (stage_1_data_enc[3] ^ input_stream_data_reg[4]);
        stage_1_data_enc[5] = (stage_1_data_enc[4] ^ input_stream_data_reg[5]);
        stage_1_data_enc[6] = (stage_1_data_enc[5] ^ input_stream_data_reg[6]);
        stage_1_data_enc[7] = (stage_1_data_enc[6] ^ input_stream_data_reg[7]);
        stage_1_data_enc[8] = 1;
    end
end
//End of combinational first stage encoding section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of first stage encoding section
always_ff @(posedge clk)
begin
    stage_1_valid_reg  <= '0;
    if (stage_1_valid_enc) begin
        stage_1_valid_reg   <= '1;
        stage_1_data_reg    <= stage_1_data_enc;
    end
end
//End of first stage encoding section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule