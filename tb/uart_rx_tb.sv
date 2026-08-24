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

    // settle a delta after the edge, not in the same timestep as it, to
    // avoid racing the DUT's always_ff sampling of rx
    task automatic drive_bit(input logic b);
        begin
            #1;
            rx = b;
            repeat(20) @(posedge clk);
        end
    endtask

    // data_valid pulses mid-way through the last data bit -- well before
    // the stop bit finishes driving -- so a wait() placed after driving the
    // whole frame would miss it (wait() only catches a future transition,
    // not one that already happened). Latch it independently in the
    // background instead of racing a sequential wait against the DUT.
    logic [count-1:0] captured_data;
    logic captured_valid;
    always @(posedge clk) begin
        if (rst)
            captured_valid <= 0;
        else if (data_valid) begin
            captured_data  <= data_out;
            captured_valid <= 1;
        end
    end

    task automatic send_and_check(input logic [count-1:0] val);
        begin
            captured_valid = 0;

            // sync the start bit to a fresh tick_baud period so our
            // manually driven bit boundaries land on the same free-running
            // counter phase the DUT's tick_baud/tick_rx are derived from
            @(posedge tick_baud);
            @(posedge clk);

            drive_bit(0); // start bit
            for (int i = 0; i < count; i++)
                drive_bit(val[i]); // LSB first
            drive_bit(1); // stop bit

            if (!captured_valid)
                $fatal(1, "data_valid never asserted for 0x%h", val);
            $display("data_out: 0x%h (expect 0x%h)", captured_data, val);
            if (captured_data !== val)
                $fatal(1, "data_out mismatch: got 0x%h, expect 0x%h", captured_data, val);
        end
    endtask

    // watchdog: a stuck DUT should fail loudly, not hang forever
    initial begin
        #100_000;
        $fatal(1, "WATCHDOG TIMEOUT - simulation did not complete in time");
    end

    initial begin
        rx  = 1; // idle
        rst = 1;
        repeat(5) @(posedge clk);
        #1;
        rst = 0;
        repeat(2) @(posedge clk);

        // deliberately NOT bit-reversal palindromes (0xa5 reads the same
        // forwards and backwards) -- a palindrome vector can't distinguish
        // correct LSB-first framing from a MSB-first bug, since both
        // orderings decode a palindrome the same way.
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
