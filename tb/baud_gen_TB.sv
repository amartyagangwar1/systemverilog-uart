`timescale 1ns / 1ps

module baud_gen_TB();

    parameter int CLK_FREQ = 100000000;
    parameter int BAUD_RATE = 115200;
    localparam int DIV = CLK_FREQ / BAUD_RATE;

    logic clk;
    logic rst;
    logic tick_baud;

    //instantiate dut
    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut (.clk(clk), .rst(rst), .tick_baud(tick_baud), .tick_rx(tick_rx));

    //generate clock to be 100 mhz or 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    //stimulus, reset system and then allow for enough run time to see clock pulses
    initial begin
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;

        #0.2ms
        //repeat (5000000000) @(posedge clk);
        // a stuck baud_gen (tick_baud never firing) would otherwise let
        // the cycle-spacing check below go completely unexercised and
        // silently report PASSED -- require a real minimum tick count too
        if (tick_count < 15)
            $fatal(1, "ERROR: only %0d tick_baud pulses seen in 0.2ms window, expected ~%0d",
                   tick_count, 200_000 / (DIV*10));
        $display("PASSED (%0d ticks observed)", tick_count);
        $finish;
    end


    int cycle_count;
    int tick_count;
    logic first_tick_seen;

    always @(posedge clk) begin
        if(rst) begin
            cycle_count <= 0;
            tick_count <= 0;
            first_tick_seen <=0;
        end else begin
            if(tick_baud) begin
                tick_count <= tick_count + 1;
                if(first_tick_seen) begin
                    //$display("TICK cycles %d, DIV %d", cycle_count, DIV);
                    if(cycle_count + 1 == DIV) begin
                        cycle_count <=0;
                        //$display("Cycle count correct");
                    end else begin
                        cycle_count <= 0;
                        $fatal(1, "ERROR, Cycles: %d, DIV: %d", cycle_count, DIV);
                    end
                end else begin
                    first_tick_seen <=1;
                    cycle_count <=0;
                end
            end else
                cycle_count <= cycle_count + 1;
        end
    end
endmodule
