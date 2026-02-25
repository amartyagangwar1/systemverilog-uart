`timescale 1ns / 1ps

module baud_gen_TB();

    //tb signals
    logic clk;
    logic rst;
    logic tick_baud;
    
    //instantiate dut
    baud_gen dut(.clk(clk), .rst(rst), .tick_baud(tick_baud));
    
    //generate clock to be 100 mhz or 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;
    
    //stimulus, reset system and then allow for enough run time to see clock pulses
    initial begin
        rst = 1;
        #20;
        rst = 0;
        
        #2000;
        $stop;
    end
endmodule
