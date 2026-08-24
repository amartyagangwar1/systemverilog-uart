`timescale 1ns / 1ps

module uart_tx_tb();
    localparam int count      = 8;
    localparam int CLK_FREQ   = 1000000;
    localparam int BAUD_RATE  = 50000;
    localparam int DIV        = CLK_FREQ / BAUD_RATE; // 20 cycles/bit

    logic clk;
    logic rst;
    logic start;
    logic [count-1:0] data_in;
    logic tick_baud, tick_rx;
    logic tx;

    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) bg (
        .clk(clk), .rst(rst), .tick_baud(tick_baud), .tick_rx(tick_rx)
    );

    uart_tx #(.count(count)) dut (
        .clk(clk), .rst(rst), .start(start), .tick_baud(tick_baud),
        .data_in(data_in), .tx(tx)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // sample tx mid-bit (on tick_rx) and assemble the 10-bit frame:
    // start(0), b0..b7 (LSB first), stop(1)
    logic [9:0] frame;
    int bit_idx;
    logic sampling;

    always @(posedge clk) begin
        if (rst) begin
            bit_idx  <= 0;
            sampling <= 0;
        end else if (tick_rx && sampling) begin
            frame[bit_idx] <= tx;
            if (bit_idx == 9) begin
                sampling <= 0;
            end
            bit_idx <= bit_idx + 1;
        end
    end

    task automatic send_and_check(input logic [count-1:0] val);
        begin
            // sync start to a fresh baud period so the frame we sample
            // lines up with our own tick_rx mid-bit points
            @(posedge tick_baud);
            @(posedge clk);

            // settle a delta after the edge, not in the same timestep as
            // it, to avoid racing the DUT's always_ff sampling of start
            #1;
            bit_idx  = 0;
            sampling = 1;
            data_in  = val;
            start    = 1;
            @(posedge clk);
            #1;
            start = 0;

            wait (bit_idx == 10);
            @(posedge clk);

            if (frame[0] !== 1'b0)
                $fatal(1, "data 0x%0h: start bit wrong, got %b (expect 0)", val, frame[0]);
            if (frame[9] !== 1'b1)
                $fatal(1, "data 0x%0h: stop bit wrong, got %b (expect 1)", val, frame[9]);
            if (frame[8:1] !== val)
                $fatal(1, "data 0x%0h: payload wrong, got 0x%0h (frame b'%b)", val, frame[8:1], frame);

            $display("data_in: 0x%0h -> frame b'%b (start ok, stop ok, payload ok)", val, frame);
        end
    endtask

    // watchdog: a stuck DUT should fail loudly, not hang forever
    initial begin
        #100_000;
        $fatal(1, "WATCHDOG TIMEOUT - simulation did not complete in time");
    end

    initial begin
        rst   = 1;
        start = 0;
        data_in = '0;
        repeat(5) @(posedge clk);
        #1;
        rst = 0;
        repeat(2) @(posedge clk);

        // deliberately NOT bit-reversal palindromes (0xa5, 0x00, 0xff, 0x81,
        // 0x3c all read the same forwards and backwards) -- a palindrome
        // vector can't distinguish correct LSB-first framing from a
        // MSB-first bug, since both orderings decode a palindrome the same.
        send_and_check(8'hA5);
        send_and_check(8'h01); // asymmetric: reverse = 0x80
        send_and_check(8'h96); // asymmetric: reverse = 0x69
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h13); // asymmetric: reverse = 0xc8

        $display("PASSED");
        $finish;
    end
endmodule
