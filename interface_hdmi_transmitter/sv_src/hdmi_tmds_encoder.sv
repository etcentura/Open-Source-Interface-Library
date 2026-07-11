module hdmi_tmds_encoder
(
    //Basic signals declaration
    input		logic		            clk                     ,   //Basic clk signal
    input		logic		            rst_n                   ,
    

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
logic		                    input_stream_valid_reg  ;   // Input stream valid
logic		        [7 : 0] 	input_stream_data_reg   ;   // Input stream data (non-encoded 8 bits data)
logic		        [3 : 0] 	input_stream_data_ones  ;   // Calculaitng input number of ones in data

//First stage encoding section
logic		                    stage_1_valid_enc       ;   // Stage 1 encoded stream valid (combinational encoding signal)
logic		        [8 : 0] 	stage_1_data_enc        ;   // Stage 1 encoded stream data (combinational encoding signal)
logic		                    stage_1_valid_reg       ;   // Stage 1 encoded stream valid (registering signal)
logic		        [8 : 0] 	stage_1_data_reg        ;   // Stage 1 encoded stream data (registering signal)
logic		        [3 : 0] 	stage_1_data_ones       ;   // Calculaitng input number of ones in data

//Second stage encoding section
logic		                    stage_2_valid_enc       ;   // Stage 1 encoded stream valid (combinational encoding signal)
logic		        [9 : 0] 	stage_2_data_enc        ;   // Stage 1 encoded stream data (combinational encoding signal)
logic		                    stage_2_valid_reg       ;   // Stage 1 encoded stream valid (registering signal)
logic		        [9 : 0] 	stage_2_data_reg        ;   // Stage 1 encoded stream data (registering signal)
logic		        [3 : 0] 	stage_2_data_ones       ;   // Calculaitng input number of ones in data
logic		        [3 : 0] 	stage_2_data_zeroes     ;   // Calculaitng input number of zeroes in data

//Disparity counters
logic	signed 	    [4 : 0] 	disparity_counter       ;   // Disparity counter for the previous value beging encoded


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


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of combinational second stage of encoding section
always_comb
begin
    stage_1_data_ones = 
                        stage_1_data_reg[0] + stage_1_data_reg[1] + stage_1_data_reg[2] + stage_1_data_reg[3] + 
                        stage_1_data_reg[4] + stage_1_data_reg[5] + stage_1_data_reg[6] + stage_1_data_reg[7];

    stage_2_valid_enc       = stage_1_valid_reg;

    if((disparity_counter == 0) || (stage_1_data_ones == 4)) begin //measuring half of ones    
        stage_2_data_enc[9]     = ~stage_1_data_reg[8];
        stage_2_data_enc[8]     = stage_1_data_reg[8];
        stage_2_data_enc[7:0]   = stage_1_data_reg[8] ? stage_1_data_reg[7:0] : ~(stage_1_data_reg[7:0]);
    end
    else begin
        if(((disparity_counter > 0) && (stage_1_data_ones > 4)) || ((disparity_counter < 0) && (stage_1_data_ones < 4))) begin
            stage_2_data_enc[9]     = '1;
            stage_2_data_enc[8]     = stage_1_data_reg[8];
            stage_2_data_enc[7:0]   = ~(stage_1_data_reg[7:0]);
        end
        else begin
            stage_2_data_enc[9]     = '0;
            stage_2_data_enc[8]     = stage_1_data_reg[8];
            stage_2_data_enc[7:0]   = stage_1_data_reg[7:0];
        end
    end
end
//End of combinational second stage of encoding section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of second stage encoding section
always_ff @(posedge clk)
begin
    stage_2_valid_reg  <= '0;
    if (stage_2_valid_enc) begin
        stage_2_valid_reg   <= '1;
        stage_2_data_reg    <= stage_2_data_enc;
    end
end
//End of second stage encoding section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of calculating zeroes and ones in stage 2 encoded data section
always_comb
begin
    stage_2_data_ones = 
                        stage_1_data_reg[0] + stage_1_data_reg[1] + stage_1_data_reg[2] + stage_1_data_reg[3] + 
                        stage_1_data_reg[4] + stage_1_data_reg[5] + stage_1_data_reg[6] + stage_1_data_reg[7];

    stage_2_data_zeroes = 
                        ~stage_1_data_reg[0] + ~stage_1_data_reg[1] + ~stage_1_data_reg[2] + ~stage_1_data_reg[3] + 
                        ~stage_1_data_reg[4] + ~stage_1_data_reg[5] + ~stage_1_data_reg[6] + ~stage_1_data_reg[7];
end~
//End of calculating zeroes and ones in stage 2 encoded data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving disparity counter section
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            disparity_counter <= 0;
        end
    else
        begin
            if (stage_2_valid_enc) begin
                if((disparity_counter == 0) || (stage_1_data_ones == 4)) begin
                    if (stage_1_data_reg[8] == 0) begin
                        disparity_counter <= disparity_counter + (stage_2_data_zeroes - stage_2_data_ones);
                    end
                    else begin
                        disparity_counter <= disparity_counter + (stage_2_data_ones - stage_2_data_zeroes);
                    end
                end
                else begin
                    if(((disparity_counter > 0) && (stage_1_data_ones > 4)) || ((disparity_counter < 0) && (stage_1_data_ones < 4))) begin
                        disparity_counter <= disparity_counter + (stage_2_data_zeroes - stage_2_data_ones);
                    end
                    else begin
                        disparity_counter <= disparity_counter + (stage_2_data_ones - stage_2_data_zeroes);
                    end
                end
            end
        end
end
//End of driving disparity counter section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of assigning output value section
always_comb
begin
    output_stream_valid = stage_2_valid_reg;
    output_stream_data  = stage_2_data_reg;
end
//End of assigning output value section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule