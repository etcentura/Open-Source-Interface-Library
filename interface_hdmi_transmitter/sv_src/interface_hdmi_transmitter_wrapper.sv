module interface_hdmi_transmitter_wrapper
#
(
    parameter       int         ITF_IDX             =   0                           ,           // Module index to be used in generation
    parameter       int         SYS_REG_WIDTH       =	32                          ,           // Width of setup registers
    parameter       bit         IS_RST_SYNC         =   1'b0                                    // Use comb or seq logic: "1" - sync rst_n, "0" - async
)

(
    //Basic signals declaration
    input		logic		                            clk_x1                      ,           //pixel clk (x1 multiplier)
    input		logic		                            clk_x10                     ,           //pixel clk (x10 multiplier) 
    input		logic		                            rst_n                       ,           //pixel clk 

    //CSR signals
    input		logic		                            csr_color_component         ,           //Select color components. 0 - RGB, 1 - YCbCr    
    input		logic       [SYS_REG_WIDTH - 1 : 0  ]   csr_cols_gen_reg            ,           // Reg for the requested number of colomns to be generated
    input		logic       [SYS_REG_WIDTH - 1 : 0  ]   csr_rows_gen_reg            ,           // Reg for the requested number of rows to be generated
    input		logic       [SYS_REG_WIDTH - 1 : 0  ]   csr_cols_del_before_reg     ,           // Reg for the requested number of colomns to be generated
    input		logic       [SYS_REG_WIDTH - 1 : 0  ]   csr_rows_del_before_reg     ,           // Reg for the requested number of rows to be generateds
    input		logic       [SYS_REG_WIDTH - 1 : 0  ]   csr_cols_del_after_reg      ,           // Reg for the requested number of colomns to be generated
    input		logic       [SYS_REG_WIDTH - 1 : 0  ]   csr_rows_del_after_reg      ,           // Reg for the requested number of rows to be generateds

    //Data streaming signals
    input		logic		                            stream_bus_vsync            ,           // Any stream bus input vsync flag
    input		logic		                            stream_bus_hsync            ,           // Any stream bus input hsync flag
    input		logic		                            stream_bus_first            ,           // Any stream bus input data beat marker - first beat
    input		logic		                            stream_bus_last             ,           // Any stream bus input data beat marker - last beat

    input		logic		[7 : 0] 	                stream_bus_data_r           ,           // Any stream bus input data - color component R
    input		logic		[7 : 0] 	                stream_bus_data_g           ,           // Any stream bus input data - color component G
    input		logic		[7 : 0] 	                stream_bus_data_b           ,           // Any stream bus input data - color component B
    input		logic		[7 : 0] 	                stream_bus_data_Y           ,           // Any stream bus input data - color component Y
    input		logic		[7 : 0] 	                stream_bus_data_Cb          ,           // Any stream bus input data - color component Cb
    input		logic		[7 : 0] 	                stream_bus_data_Cr          ,           // Any stream bus input data - color component Cr

    //Output HDMI signals
    output		logic		                            HDMI_TMDS_clk_p             ,           // Output clk TMDS (p)
    output		logic		                            HDMI_TMDS_clk_n             ,           // Output clk TMDS (p)
    output		logic		                            HDMI_TMDS_data_0_p          ,           // Output data channel 0 TMDS (p)
    output		logic		                            HDMI_TMDS_data_0_n          ,           // Output data channel 0 TMDS (n)
    output		logic		                            HDMI_TMDS_data_1_p          ,           // Output data channel 0 TMDS (p)
    output		logic		                            HDMI_TMDS_data_1_n          ,           // Output data channel 0 TMDS (n)
    output		logic		                            HDMI_TMDS_data_2_p          ,           // Output data channel 0 TMDS (p)
    output		logic		                            HDMI_TMDS_data_2_n                      // Output data channel 0 TMDS (n)
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of local signals and parameters section

//Front detector
logic		                            v_sync_posedge                  ;
logic		                            v_sync_negedge                  ;
logic		                            h_sync_posedge                  ;
logic		                            h_sync_negedge                  ;

//Counters to  mark up the line
logic		[SYS_REG_WIDTH - 1 : 0] 	counter_cols                    ;
logic		[SYS_REG_WIDTH - 1 : 0] 	counter_rows                    ;

//Registering input signals
logic		                            input_color_valid               ;
logic		[7 : 0] 	                input_component_reg     [3]     ;
logic		[1 : 0] 	                input_control_word      [3]     ;

//Registering encoded signals
logic		                            encoded_color_valid     [3]     ;
logic		[9 : 0] 	                encoded_component       [3]     ;
logic		                            encoded_color_valid_common      ;
logic		                            encoded_color_valid_reg         ;
logic		[9 : 0] 	                encoded_component_reg   [3]     ;
//End of local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of checking input parameters secntion section
initial begin
    $display("%m setup with parameter SYS_REG_WIDTH         : %d", SYS_REG_WIDTH    );
    $display("%m setup with parameter ITF_IDX               : %d", ITF_IDX          );
    $display("%m setup with parameter IS_RST_SYNC           : %d", IS_RST_SYNC      );
end 
//End of checking input parameters secntion section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of front detector section
signal_front_detector_wrapper
#
(
    .SIGNAL_WIDTH       (2                                      )              // Width of the signals to detect fronts
)
                        i_signal_front_detector_wrapper
(
    //Basic signals declaration
    .clk                (clk_x1                                 ),   // Sampling clock

    //Input signals
    .signal_in          ({stream_bus_vsync, stream_bus_hsync}   ),   // Signal in

    //Output signals
    .signal_out         (                                       ),   // Sampled signal
   .signal_posedge      ({v_sync_posedge, h_sync_posedge}       ),   // Positive fronts
   .signal_negedge      ({v_sync_negedge, h_sync_negedge}       )    // Negative fronts
);
//End of front detector section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of counters section
always_ff @(posedge clk_x1)
begin
    if(v_sync_posedge)
        begin
            counter_cols <= '1;
            counter_rows <= '0;
        end
    else
        begin
            if(counter_cols == csr_cols_del_before_reg + csr_cols_gen_reg + csr_cols_del_after_reg - 1) begin
                if (counter_rows == csr_rows_del_before_reg + csr_rows_gen_reg + csr_rows_del_after_reg - 1) begin
                    counter_cols <= '0;
                    counter_rows <= '0;
                end
                else begin
                    counter_cols <= '0;
                    counter_rows <= counter_rows + 1;
                end
            end
            else begin
                counter_cols <= counter_cols + 1;
            end
        end
end
//End of counters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching input signal section
always_ff @(posedge clk_x1)
begin
    if(v_sync_posedge)
        begin
            input_color_valid   <= '0;
            for (int i = 0; i < 3; i++) begin
                input_component_reg[i] <= '0;
            end
        end
    else
        begin
            input_color_valid   <= '0;
            if(stream_bus_hsync) begin
                input_color_valid   <= '1;

                if (!csr_color_component) begin
                    input_component_reg[0]   <= stream_bus_data_r    ;
                    input_component_reg[1]   <= stream_bus_data_g    ;
                    input_component_reg[2]   <= stream_bus_data_b    ;
                end else begin
                    input_component_reg[0]   <= stream_bus_data_Y    ;
                    input_component_reg[1]   <= stream_bus_data_Cb   ;
                    input_component_reg[2]   <= stream_bus_data_Cr   ;
                end
            end
        end
end
//End of latching input signal section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of SECTIONNAME section



//End of SECTIONNAME section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of inserting tmds encoders section

assign input_control_word[0] = {internal_vsync, internal_hsync};
assign input_control_word[1] = 2'b00;
assign input_control_word[2] = 2'b00;

generate
    genvar i;
    for (i = 0; i < 3; i++) begin : gen_tmds_encoder
        hdmi_tmds_encoder               i_hdmi_tmds_encoder
        (
            //Basic signals declaration
            .clk                        (clk                        ),  //Basic clk signal
            .rst_n                      (rst_n                      ),

            //As HDMI is based on DVI standart, it's required to implement control word
            .control_command            (input_control_word[i]      ),  //[1] - vsync, [0] - hsync
            

            //Input data
            .input_stream_valid         (input_color_valid          ),  // Input stream valid
            .input_stream_data          (input_component_reg[i]     ),  // Input stream data (non-encoded 8 bits data)

            //Output data 
            .output_stream_valid        (encoded_color_valid[i]     ),  // Output stream valid
            .output_stream_data         (encoded_component[i]       )   // Output stream data (encoded 10 bits data)
        );
    end
endgenerate

assign encoded_color_valid_common = encoded_color_valid[0] | encoded_color_valid[1] | encoded_color_valid[2];

always_ff @(posedge clk_x1)
begin
    encoded_color_valid_reg <= '0;
    if (encoded_color_valid_common) begin
        encoded_color_valid_reg <= '1;
        for (int i = 0; i < 3; i++) begin
            encoded_component_reg[i] <= encoded_component[i];
        end
    end
end
//End of inserting tmds encoders section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule