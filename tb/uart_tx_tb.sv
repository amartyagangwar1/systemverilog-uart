`timescale 1ns / 1ps

module uart_tx_tb();

    localparam int count = 8;
    logic clk;
    logic rst;
    logic start;
    logic tick_baud;
    logic [count-1:0] data_in;
    logic tx;

    uart_tx #(.count(count)) dut(.clk(clk), .rst(rst), .start(start), .tick_baud(tick_baud), .data_in(data_in), .tx(tx));

    initial clk = 0;
    always #5 clk = ~clk;

    //fake tick gen to test
    int cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
            tick_baud <= 0;
        end else begin
            if(cnt == 19) begin
                tick_baud <=1;
                cnt <=0;
            end else begin
                tick_baud <=0;
                cnt <= cnt + 1;

            end
        end
    end

    initial begin
        start = 0;
        data_in = '0;
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;

        data_in = 8'hA5;
        repeat (1) @(posedge clk);

        start = 1;
        repeat (1) @(posedge clk);
        start = 0;
    end

    int k;
    logic [9:0] observed;

int k;
logic [9:0] observed;
always @(posedge clk) begin
    if (rst) begin
        k <= 0;
        observed <= '0;
    end else if (tick_baud && k < 10) begin
        #1;
        observed[k] <= tx;
        k <= k + 1;

        if (k == 9) begin
            $display("Start bit, %b", observed[0]);
            $display("0, %b", observed[1]);
            $display("1, %b", observed[2]);
            $display("2, %b", observed[3]);
            $display("3, %b", observed[4]);
            $display("4, %b", observed[5]);
            $display("5, %b", observed[6]);
            $display("6, %b", observed[7]);
            $display("7, %b", observed[8]);
            $display("Stop bit, %b", observed[9]);
            $finish;
        end
    end
end
endmodule