`timescale 1ns / 1ps
module uart_rx_tb();
    localparam int count = 8;
    logic clk;
    logic rst;
    logic rx;
    logic tick_baud;
    logic tick_rx;
    logic [count-1:0] data_out;
    logic data_valid;

    uart_rx #(.count(count)) dut(
        .clk(clk), .rst(rst), .rx(rx),
        .tick_baud(tick_baud), .tick_rx(tick_rx),
        .data_out(data_out), .data_valid(data_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // baud gen - same as TX tb
    int cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt       <= 0;
            tick_baud <= 0;
            tick_rx   <= 0;
        end else begin
            tick_baud <= 0;
            tick_rx   <= 0;
            if(cnt == 19) begin
                tick_baud <= 1;
                cnt       <= 0;
            end else begin
                if(cnt == 9)
                    tick_rx <= 1;
                cnt <= cnt + 1;
            end
        end
    end

    // drive rx - manually serialize 0xA5 = 10100101
    // line: START(0) b0(1) b1(0) b2(1) b3(0) b4(0) b5(1) b6(0) b7(1) STOP(1)
    localparam logic [9:0] frame = 10'b1010100101; // STOP..b7..b0..START, check bit order
    initial begin
        rx  = 1; // idle
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        // send each bit, one baud period each (20 cycles)
        rx = 0;           // start bit
        repeat(20) @(posedge clk);
        rx = 1; repeat(20) @(posedge clk); // bit 0
        rx = 0; repeat(20) @(posedge clk); // bit 1
        rx = 1; repeat(20) @(posedge clk); // bit 2
        rx = 0; repeat(20) @(posedge clk); // bit 3
        rx = 0; repeat(20) @(posedge clk); // bit 4
        rx = 1; repeat(20) @(posedge clk); // bit 5
        rx = 0; repeat(20) @(posedge clk); // bit 6
        rx = 1; repeat(20) @(posedge clk); // bit 7
        rx = 1; repeat(20) @(posedge clk); // stop bit
    end

    initial begin
        wait(data_valid == 1);
        #1;
        $display("data_out: 0x%h (expect 0xa5)", data_out);
        $display("bit 0: %b (expect 1)", data_out[0]);
        $display("bit 1: %b (expect 0)", data_out[1]);
        $display("bit 2: %b (expect 1)", data_out[2]);
        $display("bit 3: %b (expect 0)", data_out[3]);
        $display("bit 4: %b (expect 0)", data_out[4]);
        $display("bit 5: %b (expect 1)", data_out[5]);
        $display("bit 6: %b (expect 0)", data_out[6]);
        $display("bit 7: %b (expect 1)", data_out[7]);
        $finish;
    end
endmodule