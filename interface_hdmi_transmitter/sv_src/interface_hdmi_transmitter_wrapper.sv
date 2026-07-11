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
    input		logic		[SYS_REG_WIDTH - 1 : 0  ] 	csr_requested_total_width   ,           // Requested total number of cols
    input		logic		[SYS_REG_WIDTH - 1 : 0  ] 	csr_requested_total_height  ,           // Requested total number of rows
    input		logic		[SYS_REG_WIDTH - 1 : 0  ] 	csr_requested_active_width  ,           // Requested active number of cols
    input		logic		[SYS_REG_WIDTH - 1 : 0  ] 	csr_requested_active_height ,           // Requested active number of rows
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
logic		            v_sync_posedge          ;
logic		            v_sync_negedge          ;
logic		            h_sync_posedge          ;
logic		            h_sync_negedge          ;

//Registering input signals
logic		            input_color_valid       ;
logic		[7 : 0] 	input_component_0_r     ;
logic		[7 : 0] 	input_component_1_r     ;
logic		[7 : 0] 	input_component_2_r     ;

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
    .ignal_out          (                                       ),   // Sampled signal
   .signal_posedge      ({v_sync_posedge, h_sync_posedge}       ),   // Positive fronts
   .signal_negedge      ({v_sync_negedge, h_sync_negedge}       )    // Negative fronts
);
//End of front detector section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching input signal section
always_ff @(posedge clk)
begin
    if(v_sync_posedge)
        begin
            input_color_valid   <= '0;
            input_component_0_r   <= '0;
            input_component_1_r   <= '0;
            input_component_2_r   <= '0;
        end
    else
        begin
            input_color_valid   <= '0;
            if(stream_bus_hsync) begin
                input_color_valid   <= '1;

                if (!csr_color_component) begin
                    input_component_0_r   <= stream_bus_data_r    ;
                    input_component_1_r   <= stream_bus_data_g    ;
                    input_component_2_r   <= stream_bus_data_b    ;
                end else begin
                    input_component_0_r   <= stream_bus_data_Y    ;
                    input_component_1_r   <= stream_bus_data_Cb   ;
                    input_component_2_r   <= stream_bus_data_Cr   ;
                end
            end
        end
end
//End of latching input signal section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule