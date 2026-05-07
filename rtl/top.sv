`timescale 1ns / 1ps

module top #(parameter int count = 8) (
    input logic clk,
    input logic rst,
    input logic start,
    input logic [count-1:0] data_in,
    output logic [count-1:0] data_out,
    output logic data_valid
);

    wire tick_baud;
    wire tick_rx;
    wire tx_wire;

    baud_gen bg_inst(.clk(clk), .rst(rst), .tick_baud(tick_baud), .tick_rx(tick_rx));
    uart_tx #(.count(count)) tx_inst(.clk(clk), .rst(rst), .start(start), .tick_baud(tick_baud), .data_in(data_in), .tx(tx_wire));
    uart_rx #(.count(count)) rx_inst(.clk(clk), .rst(rst), .rx(tx_wire), .tick_baud(tick_baud), .tick_rx(tick_rx), .data_out(data_out), .data_valid(data_valid));

endmodule
