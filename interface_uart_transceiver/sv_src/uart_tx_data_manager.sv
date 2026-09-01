module uart_tx_data_manager
#
(
    parameter		int     DWIDTH              =	8       ,   //Width of the bus for: data
    parameter       int     CSR_WIDTH           =   32          //Width of the control-setup registers
)

(
    //Basic signals declaration
    input 	logic 		            clk             ,
    input 	logic 		            rst_n           ,
    
    //Data from fifo
    input 	logic 	                fifo_valid      ,
    input 	logic 	[DWIDTH-1:0] 	fifo_data       ,
    output 	logic 	                fifo_read_req   ,
    input 	logic 	                fifo_empty      ,

    //Data to uart
    input 	logic 	                uart_ready      ,
    output 	logic 	                uart_valid      ,
    output 	logic 	[DWIDTH-1:0] 	uart_data       ,

    input 	logic 	                status_busy_tx
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//RST sync
logic 	                    rst_sync;

//FSM signals
enum 	logic 	[3:0]   {
                            IDLE, 
                            GET_DATA, 
                            SEND_DATA,
                            WAIT_TX_BUSY
                        } 	
                            state, next_state, prev_state;


//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of front detector section
logic 	status_busy_tx_reg;
logic 	status_busy_tx_pos;
logic 	status_busy_tx_neg;

always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            status_busy_tx_reg <= '0;
        end
    else
        begin
            status_busy_tx_reg <= status_busy_tx;
        end
end

assign 	status_busy_tx_pos 	= ~status_busy_tx_reg & status_busy_tx;
assign 	status_busy_tx_neg 	= status_busy_tx_reg & ~status_busy_tx;

//End of front detector section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of sync rst section
signal_synchronizer 
#
(
    .SYNCWIDTH		        (1                          ),
    .SYNCSTEPS		        (2                          )
)
                            i_signal_synchronizer
(
    //Basic signals declaration
    .clk_src                (clk                        ),
    .clk_dst                (clk                        ),

    .data_src               (rst_n                      ),
    .data_dst               (rst_sync                   )
);
//End of sync rst section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving fsm section
always_ff @(posedge clk)
begin
    if(!rst_sync)
        begin
            state <= IDLE;
            prev_state <= IDLE;
        end
    else
        begin
            state <= next_state;
            prev_state <= state;
        end
end

always_comb
begin
    case (state)
        IDLE:
            begin
                next_state = IDLE;
                if(!fifo_empty) begin
                    next_state = GET_DATA;
                end
            end
        GET_DATA:
            begin
                next_state = GET_DATA;
                if(fifo_valid) begin
                    next_state = SEND_DATA;
                end
            end
        SEND_DATA:
            begin
                next_state = SEND_DATA;
                if(uart_valid && uart_ready) begin
                    next_state = WAIT_TX_BUSY;
                end
            end
        WAIT_TX_BUSY:
            begin
                next_state = WAIT_TX_BUSY;
                if(!status_busy_tx) begin
                    next_state = IDLE;
                end
            end
        default:
            begin
                next_state = IDLE;
            end
    endcase
end
//End of driving fsm section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving data capturing section
always_ff @(posedge clk)
begin
    if(!rst_sync)
        begin
            fifo_read_req <= '0;
        end
    else
        begin
            fifo_read_req <= '0;
            if((state == GET_DATA) && (prev_state == IDLE)) begin
                fifo_read_req <= '1;
            end
        end
end
//End of driving data capturing section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of sending data to uart section
always_ff @(posedge clk)
begin
    if(!rst_sync)
        begin
            uart_valid      <= '0;
            uart_data       <= '0;
        end
    else
        begin
            if(uart_ready)begin
                uart_valid      <= '0;
            end
            else if(fifo_valid)begin
                uart_valid      <= '1;
                uart_data       <= fifo_data;
            end
        end
end
//End of sending data to uart section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule