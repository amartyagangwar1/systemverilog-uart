`timescale 1ns / 1ps

module baud_gen #(parameter int CLK_FREQ = 100000000, parameter int BAUD_RATE = 115200)
                 (input logic clk, input logic rst, output logic tick_baud);

    localparam int DIV = CLK_FREQ / BAUD_RATE; //Number of clock cycles per baud tick

    initial begin if (DIV < 1)
            $fatal("Invalid parameter combination");
    end

    localparam int CNT_WIDTH = (DIV > 1) ? $clog2(DIV): 1; //Number of minimum bits required to store the values from 0 till DIV-1

    logic [(CNT_WIDTH-1):0] count;

    always_ff @(posedge clk) begin
        if(rst) begin //Synchronous Reset
            count <= '0;
            tick_baud <= '0;
        end else if (count == (DIV-1)) begin
            count <= '0;
            tick_baud <= '1;
        end else begin
            count <= count + 1;
            tick_baud <= '0;
        end
    end

endmodule
