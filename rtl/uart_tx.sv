`timescale 1ns / 1ps

module uart_tx #(parameter int count = 8)(
    input logic clk,
    input logic rst,
    input logic start,
    input logic tick_baud,
    input logic [count-1:0] data_in);

    //state declaration using enum
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t current_state, next_state;

    //state registers
    always_ff @(posedge clk) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    //next state logic
    always_comb begin
        next_state = current_state; //default
        case (current_state)
            IDLE: begin
                if(start)
                    next_state = START;
                else next_state = IDLE;
            end
            START: begin
                if(tick_baud)
                    next_state = DATA;
            end
            DATA: begin
                if(countValue == count-1 && tick_baud)
                    next_state = STOP;
            end
            STOP: begin
                if(tick_baud)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    //counter for # of bits being transmitted
    logic [$clog2(count) - 1:0] countValue;
    always_ff @(posedge clk) begin
        if(rst)
            countValue <= 0;
        else if (current_state == DATA && tick_baud) begin
            if(countValue == count - 1) begin
                countValue <= 0;
            end else
                countValue <= countValue + 1;
        end
        else
            countValue <= 0;
    end
    
    //shift register logic to transmit data
    always_ff @(posedge clk) begin        
    end
    
endmodule
