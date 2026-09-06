//TODO finish the CAN error frame and overload frame complete
//TODO bitstuffer
//TODO error handler
//TODO crc
//TODO complete receiver
//TODO complete wrapper
module can_transmitter_unit
#
(
    parameter 	CSR_WIDTH 	= 32
)

(
    //Basic signals declaration
    input 	logic 		                    clk                     ,
    input 	logic 		                    rst_n                   ,
    
    //Serial data output
    inout 	wire 	                        can_serial_wire         , //0 is the dominant bit, 1 is the recessive one

    //CSR registers and control signals
    input 	logic 	                        start_transmission      ,
    input 	logic 	                        frame_type_to_send      , //0 - data frame, 1 - remote frame
    input 	logic 	                        use_extended_profile    ,
    input 	logic   [10:0]                  identifier_standart     ,
    input 	logic   [17:0]                  identifier_standart     ,
    input 	logic   [CSR_WIDTH - 1 : 0]     number_of_bytes_to_tx   ,
    input   logic                           error_detected_ext      ,

    //TX status
    output 	logic 	                        status_is_busy
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of delcaring local signals and parameters section

//Local parameters for better code usage
localparam  STANDART_ID_LEN                 = 11;
localparam  EXTENDED_ID_LEN                 = 18;
localparam  STANDART_CONTROL_FIELD_LEN      = 5;
localparam  EXTENDED_CONTROL_FIELD_LEN      = 6;
localparam  BYTE_LEN_IN_BITS                = 8;
localparam  CRC_FIELD_LEN                   = 16;
localparam  ACK_FIELD_LEN                   = 2;
localparam  END_OF_FRAME_LEN                = 7;
localparam  INTERMISSION_TIME_LEN           = 3;
localparam  SUSPEND_TIME_LEN                = 8;

localparam  ERROR_FLAG_LEN                = 8;
localparam  ERROR_FLAG_LEN                = 8;


//Front detector signals
logic 	                        start_transmission_reg      ;
logic 	                        start_transmission_pos      ;
logic 	                        start_transmission_neg      ;

//Input signals latch
logic 	[1:0]                   frame_type_to_send_r        ;
logic 	                        use_extended_profile_r      ;
logic   [10:0]                  identifier_standart_r       ;
logic   [17:0]                  identifier_standart_r       ;
logic   [CSR_WIDTH - 1 : 0]     number_of_bytes_to_tx_r     ;

//Error detection signals
logic                           error_detected_int          ;

//FSM signals
logic 	[7:0] 	                fsm_service_counter         ;
logic 	[CSR_WIDTH - 1 : 0]     fsm_bytes_counter           ;
enum 	logic 	[7:0] 	    {
                                    IDLE                    ,
                                    SEND_SOF                ,
                                    SEND_ID_11              ,
                                    SEND_SSR                ,
                                    SEND_RTR                ,
                                    SEND_IDE                ,
                                    SEND_ID_18              ,
                                    SEND_CONTROL_FIELD      ,
                                    SEND_DATA_FIELD         ,
                                    SEND_CRC_FIELD          ,
                                    SEND_ACK_FIELD          ,
                                    SEND_END_OF_FRAME       ,
                                    SEND_INTERFRAME_SPACE   ,

                                    SEND_ERROR_FRAME        ,   //Error handler state (works like the interrupt)

                                    SEND_OVERLOAD_FRAME     
                                } 	
                                state, next_state;

//Enums to make code more readable
enum    logic                   {
                                    IN                      ,
                                    OUT
                                } 
                                inout_direction             ;

enum    logic                   {
                                    DATA_FRAME              ,
                                    REMOTE_FRAME            
                                } 
                                requested_frame_type        ;


//End of delcaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of misc assigns section
assign requested_frame_type = frame_type_to_send_r;
//End of misc assigns section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of front detector to get start of the transmission and latch input parameters section
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            start_transmission_reg <= '0;
        end
    else
        begin
            start_transmission_reg <= start_transmission;
        end
end

assign 	start_transmission_pos 	= ~start_transmission_reg & start_transmission;
assign 	start_transmission_neg 	= start_transmission_reg & ~start_transmission;
//End of front detector to get start of the transmission and latch input parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching input parameters section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            frame_type_to_send_r        <= '0;
            use_extended_profile_r      <= '0;
            identifier_standart_r       <= '0;
            identifier_standart_r       <= '0;
            number_of_bytes_to_tx_r     <= '0;
        end
    else
        begin
            if(start_transmission_pos)begin
                frame_type_to_send_r        <= frame_type_to_send_r     ;
                use_extended_profile_r      <= use_extended_profile     ;
                identifier_standart_r       <= identifier_standart      ;
                identifier_standart_r       <= identifier_standart      ;
                number_of_bytes_to_tx_r     <= number_of_bytes_to_tx    ;
            end
        end
end
//End of latching input parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving fsm section section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            state <= IDLE;
        end
    else
        begin
            if(error_detected_int || error_detected_ext)begin
                state <= SEND_ERROR_FRAME;
            end
            else begin
                state <= next_state;
            end
        end
end

always_comb
begin
    case (state)
        IDLE:
            begin
                next_state = IDLE;
                if(start_transmission_pos)begin
                    next_state = SEND_SOF;
                end
            end
        SEND_SOF:
            begin
                next_state = SEND_ID_11;
            end
        SEND_ID_11:
            begin
                next_state = SEND_ID_11;
                if(fsm_service_counter == STANDART_ID_LEN - 1)begin
                    if(use_extended_profile_r)begin
                        next_state = SEND_SSR;
                    end
                    else begin
                        next_state = SEND_RTR;
                    end
                end
            end
        SEND_SSR:
            begin
                next_state = SEND_IDE;
            end
        SEND_RTR:
            begin
                if(use_extended_profile_r)begin
                    next_state = SEND_CONTROL_FIELD;
                end
                else begin
                    next_state = SEND_IDE;
                end
            end
        SEND_IDE:
            begin
                if(use_extended_profile_r)begin
                    next_state = SEND_ID_18;
                end
                else begin
                    next_state = SEND_CONTROL_FIELD;
                end
            end
        SEND_ID_18:
            begin
                next_state = SEND_ID_18;
                if(fsm_service_counter == EXTENDED_ID_LEN - 1)begin
                    next_state = SEND_RTR;
                end
            end
        SEND_CONTROL_FIELD:
            begin
                if(use_extended_profile_r)begin
                    if(fsm_service_counter == EXTENDED_CONTROL_FIELD_LEN - 1)begin
                        if(requested_frame_type == REMOTE_FRAME)begin
                           next_state = SEND_CRC_FIELD; 
                        end
                        else begin
                            next_state = SEND_DATA_FIELD;
                        end
                    end
                    else begin
                        if(requested_frame_type == REMOTE_FRAME)begin
                           next_state = SEND_CRC_FIELD; 
                        end
                        else begin
                            next_state = SEND_DATA_FIELD;
                        end
                    end
                end
                else begin
                    if(fsm_service_counter == STANDART_CONTROL_FIELD_LEN - 1)begin
                        next_state = SEND_DATA_FIELD;
                    end
                    else begin
                        next_state = SEND_CONTROL_FIELD;
                    end
                end
            end
        SEND_DATA_FIELD:
            begin
                next_state = SEND_DATA_FIELD;
                if((fsm_bytes_counter == number_of_bytes_to_tx_r - 1) && (fsm_service_counter == BYTE_LEN_IN_BITS - 1))begin
                    next_state = SEND_CRC_FIELD;
                end
            end
        SEND_CRC_FIELD:
            begin
                next_state = SEND_CRC_FIELD;
                if(fsm_service_counter == CRC_FIELD_LEN - 1)begin
                    next_state = SEND_ACK_FIELD;
                end
            end
        SEND_ACK_FIELD:
            begin
                next_state = SEND_ACK_FIELD;
                if(fsm_service_counter == ACK_FIELD_LEN - 1)begin
                    next_state = SEND_END_OF_FRAME;
                end
            end
        SEND_END_OF_FRAME:
            begin
                next_state = SEND_END_OF_FRAME;
                if(fsm_service_counter == END_OF_FRAME_LEN - 1)begin
                    next_state = SEND_INTERFRAME_SPACE;
                end
            end
        SEND_INTERFRAME_SPACE:
            begin
                next_state = SEND_INTERFRAME_SPACE;
                if(fsm_service_counter == SEND_INTERFRAME_SPACE - 1)begin
                    next_state = IDLE;
                end
            end


        SEND_ERROR_FRAME:
            begin
                next_state = SEND_ERROR_FRAME;
                if()begin
                    
                end
            end
        default:
            begin
                next_state = IDLE;
            end
    endcase
end

always_ff @(posedge clk)
begin
    case (state)
        SEND_ID_11: begin
            if(fsm_service_counter == STANDART_ID_LEN - 1) fsm_service_counter <= '0;
            else fsm_service_counter <= fsm_service_counter + 1;
        end
        SEND_ID_18: begin
            if(fsm_service_counter == EXTENDED_ID_LEN - 1) fsm_service_counter <= '0;
            else fsm_service_counter <= fsm_service_counter + 1;
        end
        SEND_CONTROL_FIELD: begin
            if(use_extended_profile_r)begin
                if(fsm_service_counter == EXTENDED_CONTROL_FIELD_LEN - 1) fsm_service_counter <= '0;
                else fsm_service_counter <= fsm_service_counter + 1;
            end
            else begin
                if(fsm_service_counter == STANDART_CONTROL_FIELD_LEN - 1) fsm_service_counter <= '0;
                else fsm_service_counter <= fsm_service_counter + 1;
            end
        end
        SEND_DATA_FIELD: begin
            if(fsm_service_counter == BYTE_LEN_IN_BITS - 1) fsm_service_counter <= '0;
            else fsm_service_counter <= fsm_service_counter + 1;
        end
        SEND_CRC_FIELD: begin
            if(fsm_service_counter == CRC_FIELD_LEN - 1) fsm_service_counter <= '0;
            else fsm_service_counter <= fsm_service_counter + 1;
        end
        SEND_ACK_FIELD: begin
            if(fsm_service_counter == ACK_FIELD_LEN - 1) fsm_service_counter <= '0;
            else fsm_service_counter <= fsm_service_counter + 1;
        end
        SEND_END_OF_FRAME: begin
            if(fsm_service_counter == END_OF_FRAME_LEN - 1) fsm_service_counter <= '0;
            else fsm_service_counter <= fsm_service_counter + 1;
        end
        SEND_INTERFRAME_SPACE:
        begin
            if(fsm_service_counter == SEND_INTERFRAME_SPACE - 1) fsm_service_counter <= '0;
            else fsm_service_counter <= fsm_service_counter + 1;
        end
        default: begin
            fsm_service_counter <= '0;
        end
    endcase
end
//End of driving fsm section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving bytes sent counter section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            fsm_bytes_counter <= '0;
        end
    else
        begin
            fsm_bytes_counter <= '0;
            if(state == SEND_DATA_FIELD)begin
                if(fsm_service_counter == BYTE_LEN_IN_BITS - 1)begin
                    fsm_bytes_counter <= fsm_bytes_counter + 1;
                end
            end
        end
end
//End of driving bytes sent counter section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving status bits section
always_comb
begin
    status_is_busy = state == IDLE ? '1 : '0;
end
//End of driving status bits section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving inout can wire section
assign can_serial_wire = (inout_direction == OUT) ? can_output_bitstuffed : 1'bz; 
//End of driving inout can wire section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
