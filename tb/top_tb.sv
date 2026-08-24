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

    task automatic send_and_check(input logic [7:0] val, input int gap_cycles);
        begin
            // settle stimulus a delta after the clock edge, never in the
            // same timestep as it -- avoids racing the DUT's own always_ff
            // sampling of start/data_in on that same edge
            #1;
            data_in = val;
            start = 1;
            @(posedge clk);
            #1;
            start = 0;

            wait(data_valid == 1);
            #1;
            $display("data_in: 0x%h -> data_out: 0x%h", val, data_out);
            if (data_out !== val)
                $fatal(1, "mismatch: sent 0x%h, got 0x%h", val, data_out);

            repeat(gap_cycles) @(posedge clk);
        end
    endtask

    // watchdog: a stuck DUT should fail loudly, not hang forever
    initial begin
        #(20_000_000);
        $fatal(1, "WATCHDOG TIMEOUT - simulation did not complete in time");
    end

    //test
    initial begin
        rst = 1;
        start = 0;
        data_in = 8'h00;
        repeat(5) @(posedge clk);

        #1;
        rst = 0;
        repeat(2) @(posedge clk);

        // generously-spaced frames. NOTE: values are deliberately NOT
        // bit-reversal palindromes (0xa5, 0x00, 0xff, 0x81, 0x3c all read
        // the same forwards and backwards) -- a palindrome test vector
        // can't distinguish LSB-first framing from a MSB-first bug, since
        // both orderings decode a palindrome identically.
        send_and_check(8'hA5, 3*868);
        send_and_check(8'h01, 3*868); // asymmetric: reverse = 0x80
        send_and_check(8'h96, 3*868); // asymmetric: reverse = 0x69
        send_and_check(8'h00, 3*868);
        send_and_check(8'hFF, 3*868);
        send_and_check(8'h13, 3*868); // asymmetric: reverse = 0xc8

        // Tighter back-to-back frames at gaps that are deliberately NOT
        // multiples of the baud period (868 cycles), so each frame's start
        // bit lands at a genuinely different phase of the free-running
        // baud counter -- this is what actually exercises the phase-
        // independence fix in uart_rx (RX's START/DATA transitions used to
        // be keyed off a free-running tick that was never resynchronized
        // to the actual start-bit edge, causing wrong data or a full
        // deadlock depending on that phase; see uart_rx.sv). A gap that IS
        // an exact multiple of 868, like the 3*868 used above, re-tests
        // the *same* phase every time and would NOT have caught that bug.
        //
        // The floor here (~1400 cycles) is NOT an RX limitation -- it's
        // because uart_tx exposes no busy/ready output, so a start pulse
        // issued before TX has actually returned to IDLE (which, measured
        // from data_valid, takes a bit more than one baud period: the rest
        // of the final data bit plus the full stop bit) is silently
        // dropped with no error indication. Verified empirically: gaps
        // below ~1300-1400 cycles drop the pulse and hang; this is a
        // separate, real caller-discipline requirement, not something this
        // test is trying to cover.
        send_and_check(8'hA5, 1900);
        send_and_check(8'h01, 2311);
        send_and_check(8'h96, 2737);
        send_and_check(8'h00, 1900);
        send_and_check(8'hFF, 2311);
        send_and_check(8'h13, 2737);

        $display("PASSED");
        $finish;
    end

endmodule
    