`timescale 1ns / 1ps

//count to 868 and then pulse tick_baud

module baud_gen(
    input logic clk,                                    //100 MHZ Clock from FPGA
    input logic rst,                                    //Reset Button 
    output logic tick_baud                              //One pulse every 100 MHZ / 115200 HZ or Clock Rate / Baud Rate = 868
    );
    
    logic [10:0] count = 0;                             //Need at least 2^10 bits or 1024 bits to count up to 868
    int cmp = 868;                                      //Value we are counting up to
    
    always_ff @(posedge clk) begin                      //Every clock tick we are incrementing the counter
        if(rst) begin                                   //If reset button active, change count and tick baud to 0 
            count <= 0;
            tick_baud <=0;
        end else if (count == (cmp-1)) begin            //If count is at 868 reset back to 0 and pulse tick_baud
            count <=0;
            tick_baud <=1;
        end else begin                                  //Regular count up
            count <= count + 1;
            tick_baud <= 0;
        end     
    end    
    
endmodule
