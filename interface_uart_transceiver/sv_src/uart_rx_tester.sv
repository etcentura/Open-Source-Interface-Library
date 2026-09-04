module uart_rx_tester
(
    //Basic signals declaration
    input 	logic 		            clk             ,
    input 	logic 		            rst_n           ,

    //Input button signal
    input 	logic 	                input_button    ,
    output  logic                   uart_tx         ,
    input   logic                   uart_rx         
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//Button debounce
logic 	        [31:0] 	        button_debounce_counter;
logic 	                        button_debounce_signal;

//FSM signals
enum 	logic 	[3:0] 	        {
                                    IDLE,
                                    RESETTING_FIFO,
                                    DERESETTING_FIFO,
                                    LOADING_DATA,
                                    AWAIT_DATA,
                                    READ_DATA
                                } 	
                                state, next_state;

//Load counter signals
logic 	        [7:0] 	        load_counter;
logic 	        [7:0] 	        load_counter_d;
logic 	                        load_valid;
logic 	                        load_driving;


//FIFO reset signals
logic                           rst_sync_tx_fifo_w;
logic                           rst_sync_tx_fifo_r;
logic                           rst_sync_rx_fifo_w;
logic                           rst_sync_rx_fifo_r;

logic 	        [31 : 0] 	    csr_setup_register;
logic 	        [31 : 0] 	    csr_clk_divider_tx;
logic 	        [31 : 0] 	    csr_clk_divider_rx;

//FIFO singnals
logic                           internal_fifo_reset;
logic                           empty_rx_fifo;
logic                           read_en_to_rx_fifo;

logic 	        [7:0] 	        loop_counter;
logic 	                        loop_valid;

logic                           uart_tx_int;
logic                           uart_rx_int;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of button debouncing section
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            button_debounce_counter <= '0;
            button_debounce_signal <= '0;
        end
    else
        begin
            if(!input_button)begin
                if(button_debounce_counter >= 25_000)begin //to make 500us button press
                    button_debounce_signal <= '1;
                end
                else begin
                    button_debounce_counter <= button_debounce_counter + 1;
                    button_debounce_signal <= '0;
                end
            end
            else begin
                button_debounce_counter <= '0;
                button_debounce_signal <= '0;
            end
        end
end
//End of button debouncing section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving fsm to generate test_data section
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            state <= IDLE;
        end
    else
        begin
            state <= next_state;
        end
end

always_comb
begin
    case (state)
        IDLE:
            begin
                next_state = IDLE;
                if(button_debounce_signal)begin
                    next_state = RESETTING_FIFO;
                end
            end
        RESETTING_FIFO:
            begin
                next_state = RESETTING_FIFO;
                if(rst_sync_tx_fifo_w && rst_sync_tx_fifo_r && rst_sync_rx_fifo_w && rst_sync_rx_fifo_r)begin
                    next_state = DERESETTING_FIFO;
                end
            end
        DERESETTING_FIFO:
            begin
                next_state = DERESETTING_FIFO;
                if(!rst_sync_tx_fifo_w && !rst_sync_tx_fifo_r && !rst_sync_rx_fifo_w && !rst_sync_rx_fifo_r)begin
                    next_state = LOADING_DATA;
                end
            end
        LOADING_DATA:
            begin
                next_state = LOADING_DATA;
                if(load_counter == 32 - 1)begin
                    next_state = AWAIT_DATA;
                end
            end
        AWAIT_DATA:
            begin
                next_state = AWAIT_DATA;
                if(!empty_rx_fifo)begin
                    next_state = READ_DATA;
                end
            end
        READ_DATA:
            begin
                next_state = AWAIT_DATA;
            end
        default:
            begin
                next_state = IDLE;
            end
    endcase
end
//End of driving fsm to generate test_data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of load counter driving section
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            load_counter <= '0;
            load_valid <= '0;
            load_driving <= '0;
            load_counter_d <= '0;
        end
    else
        begin
            load_counter <= '0;
            load_valid <= '0;
            load_driving <= '0;
            if(state == LOADING_DATA)begin
                load_counter <= load_counter + 1;
                if(load_counter < 32)begin
                    load_valid <= '1;
                    load_driving <= '1;
                end
                else begin
                    load_valid <= '0;
                    load_driving <= '0;
                end
            end

            load_counter_d <= load_counter;
        end
end
//End of load counter driving section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of configuring section
always_comb
begin
    csr_setup_register      ='0;
    csr_setup_register[0]   = 1;
    csr_setup_register[3:1] = 3;
    csr_setup_register[6:4] = 3;
    csr_setup_register[8:7] = 2;

    csr_clk_divider_tx = 2604;
    csr_clk_divider_rx = 2604;
end
//End of configuring section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving read enable for fifo section
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            read_en_to_rx_fifo <= '0;
        end
    else
        begin
            read_en_to_rx_fifo <= '0;
            if(state == READ_DATA)begin
                read_en_to_rx_fifo <= '1;
            end
        end
end
//End of driving read enable for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving internal fifo resetting section
always_ff @(posedge clk)
begin
    internal_fifo_reset <= '1;
    if(state == RESETTING_FIFO)begin
        internal_fifo_reset <= '0;
    end
end
//End of driving internal fifo resetting section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instanging uart tranceiver section
uart_wrapper
#
(
    .DWIDTH                         (8                                              ),   //Width of the bus for: data
    .CSR_WIDTH                      (32                                             ),   //Width of the control-setup registers
    .FIFO_TXAWIDTH		            (8                                              ),
    .FIFO_RXAWIDTH		            (8                                              )
)
                                    i_uart_wrapper
(
    //Basic signals declaration
    .clk_system                     (clk                                            ),
    .clk_uart                       (clk                                            ),
    .rst_n                          (internal_fifo_reset                            ),

    //Data flow to tx fifo
    .valid_to_tx_fifo               (load_driving ? load_valid : loop_valid         ),
    .data_to_tx_fifo                (load_driving ? load_counter_d : loop_counter   ),
    .full_tx_fifo                   (                                               ),
    .empty_tx_fifo                  (                                               ),
    .rst_sync_tx_fifo_w             (rst_sync_tx_fifo_w                             ),
    .rst_sync_tx_fifo_r             (rst_sync_tx_fifo_r                             ),

    //Data flow from rx fifo
    .read_en_to_rx_fifo             (read_en_to_rx_fifo                             ),
    .valid_from_rx_fifo             (loop_valid                                     ),
    .data_from_rx_fifo              (loop_counter                                   ),
    .full_rx_fifo                   (                                               ),
    .empty_rx_fifo                  (empty_rx_fifo                                  ),
    .rst_sync_rx_fifo_w             (rst_sync_rx_fifo_w                             ),
    .rst_sync_rx_fifo_r             (rst_sync_rx_fifo_r                             ),

    //UART interface
    .uart_rx                        (uart_rx_int                                    ),
    .uart_tx                        (uart_tx_int                                    ),
    .uart_cts                       ('0                                             ),
    .uart_rts                       (                                               ),

    //CSR registers
    .csr_setup_register             (csr_setup_register                             ),
    .csr_clk_divider_tx             (csr_clk_divider_tx                             ),
    .csr_clk_divider_rx             (csr_clk_divider_rx                             ),
    .csr_additional_delay           (100                                            ),

    //Status outputs
    .status_parity_bit_error_tx     (                                               ),
    .status_parity_bit_error_rx     (                                               ),
    .status_stop_bit_error_tx       (                                               ) 

);

//End of instanging uart tranceiver section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving uart interface section
always_ff @(posedge clk) begin
    uart_tx <= uart_tx_int;
end

always_ff @(posedge clk) begin
    uart_rx_int <= uart_rx;
end
//End of driving uart interface section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule