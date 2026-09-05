module can_time_manager
#
(
    parameter 	CSR_WIDTH 	= 32
)

(
    //Basic signals declaration
    input 	logic 		                        clk                             ,
    input 	logic 		                        rst_n                           ,
    
    //Prescaler coefficient value
    input 	logic 	[CSR_WIDTH - 1 : 0] 	    csr_prescaler_value             , //m value (see "Some information about time quantum")
    input 	logic 	[CSR_WIDTH - 1 : 0] 	    csr_duration_sync_seg           ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	    csr_duration_prop_seg           ,   
    input 	logic 	[CSR_WIDTH - 1 : 0] 	    csr_duration_phase_1_seg        ,
    input 	logic 	[CSR_WIDTH - 1 : 0] 	    csr_duration_phase_2_seg        ,

    //Prescaler output clock
    output 	logic 	                            prescaler_out_clk               
);
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of notes section

/*
The formula to make divided clk is f_in/f_out = 2n, where n is the value of prescaler
CAN bus can handle the set of the different bit frequencies such as:
1   Mbits/s - 25-40 meters
500 Kbits/s - 100   meters
250 Kbits/s - 250   meters
125 Kbits/s - 500   meters
50  Kbits/s - 1000  meters
20  Kbtis/s - 2500  meters
9   Kbits/s - 5000  meters
considering the length of the transmission line as the main tradeoff.
However there is also the value of the minimal bit width defined by the dominant bit timeout protection.
The minimum possible time before the protection starts is about 1.2 ms should be considered while setup.
This time means 11 bits possible be transmitted, therefore minimum bit time is 11/1.2ms = 108 us.
*/

/*
Some information about time quantum:
Time quantum (TQ) is a fixed unit of time derivered from oscillator period
minimum time quantum (MTQ) is the smallest period of the CAN controller
The dependence among them is
TIME QUANTUM = m * MINIMUM TIME QUANTUM where m is the value of prescaler

In other words
TQ is the atomic time unit inside the nominal bit time
MTQ is just a period of the smallest period in the CAN controller (let's say it's just the freq of clk)
m is the prescaler value (PV) that is about the division of the smallest clk to get the bit time
TQ = m * MTQ => 50ns = 4 * 12.5 ns

|<---------------------------------------bit processing time (bpt)----------------------------->|
|   sync seg  | prop seg    |    phase seg 1    |  phase buffer seg 2                           |
|   1 tq      |  1,2...8 TQ |   1,2..8 TQ       |   maxof(INFO PROCESSING TIME and phase seg 1) |
                                                ^ info processing time = <= 2*TQ
Total number of tq in bpt is from 8 to 25 bits

Nevertheless this CAN controller allows you to set different values as you wish
*/

//End of notes section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters section

//Total bit time calculated as the sum of parameters
logic 	[CSR_WIDTH - 1 : 0] 	    nominal_bit_time        ;

//TQ from MTQ maker
logic 	[CSR_WIDTH - 1 : 0] 	    divided_tq_time         ;
logic 	[CSR_WIDTH - 1 : 0] 	    divided_bpt_time        ;

logic 	[CSR_WIDTH - 1 : 0] 	    prescaler_counter_tq    ;
logic 	                            prescaler_clock_tq      ;
logic 	[CSR_WIDTH - 1 : 0] 	    prescaler_counter_bpt   ;
logic 	                            prescaler_clock_bpt     ;


//End of declaring local singals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of making bit time clk section
always_ff @(posedge clk)
begin
    if(!rst_n)
        begin
            nominal_bit_time <= 0;
        end
    else
        begin
            nominal_bit_time <=     csr_duration_sync_seg 
                                +   csr_duration_prop_seg 
                                +   csr_duration_phase_1_seg 
                                +   csr_duration_phase_2_seg;
        end
end
//End of making bit time clk section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of dividing by 2 prescaler values section
always_ff @(posedge clk)
begin
    if(!rst_n) begin
        divided_tq_time     <= '0;
        divided_bpt_time    <= '0;
    end
    else begin
        divided_tq_time     <= csr_prescaler_value >> 1;
        divided_bpt_time    <= nominal_bit_time >> 1;
    end
end
//End of dividing by 2 prescaler values section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving creation of the TQ from MTQ section
always_ff @(posedge clk)
begin
    if(!rst_n) begin
        prescaler_counter_tq    <= '0;
        prescaler_clock_tq      <= '0;
    end
    else begin
        if(prescaler_counter_tq == divided_tq_time - 1)begin
            prescaler_counter_tq    <= '0;
            prescaler_clock_tq      <= ~prescaler_clock_tq;
        end
        else begin
            prescaler_counter_tq    <= prescaler_counter_tq + 1;
        end
    end
end
//End of driving creation of the TQ from MTQ section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving creation of BPT from TQ section
always_ff @(posedge prescaler_clock_tq)
begin
    if(!rst_n) begin
        prescaler_counter_bpt   <= '0;
        prescaler_clock_bpt     <= '0;
    end
    else begin
        if(prescaler_counter_bpt == divided_bpt_time - 1)begin
            prescaler_counter_bpt   <= '0;
            prescaler_clock_bpt     <= ~prescaler_clock_bpt;
        end
        else begin
            prescaler_counter_bpt <= prescaler_counter_bpt + 1;
        end
    end
end
//End of driving creation of BPT from TQ section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule