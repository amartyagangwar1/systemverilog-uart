`timescale 1ns / 1ps

module top_tb();

    logic clk;
    logic rst;
    logic start;
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic data_valid;


    //clk
    initial clk = 0;
    always #5 clk = ~clk;

    //instantiate top
    top dut(.clk(clk), .rst(rst), .start(start), .data_in(data_in), .data_out(data_out), .data_valid(data_valid));

    //test
    initial begin
        rst = 1;
        start = 0;
        data_in = 8'hA5;
        repeat(5) @(posedge clk);
        
        rst = 0;
        repeat(2) @(posedge clk);
        
        start = 1;
        repeat(1) @(posedge clk);
        
        start = 0;

        wait(data_valid == 1);
        #1;
        $display("data_out: 0x%h (expect 0xa5)", data_out);
        $finish;
    end

endmodule
    