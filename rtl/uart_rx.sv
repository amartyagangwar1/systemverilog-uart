`timescale 1ns / 1ps

module uart_rx #(parameter int count = 8) (
    input logic clk,
    input logic rst,
    input logic rx,
    input logic tick_baud,
    input logic tick_rx,
    output logic [count-1 : 0] data_out,
    output logic data_valid
    );
    
    //states
    typedef enum logic[1:0] {IDLE, START, DATA, STOP} state_t;
    state_t current_state, next_state;
    
    //state registers 
    always_ff @(posedge clk) begin
        if(rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
      end 
    
    //state logic
    always_comb begin
        next_state = current_state;
        case (current_state) 
            IDLE: begin
               if(rx == 0) 
                    next_state = START;
               end
            START: begin
                if(tick_rx)
                    next_state = DATA;
                end
            DATA: begin
                if(bit_count == count-1 && tick_rx) 
                    next_state = STOP;
                end
            STOP: begin
                if(tick_baud)  
                    next_state = IDLE;
                end
            default:  next_state = IDLE; 
        endcase
    end         
    
    localparam int cw = (count <= 1) ? 1 : $clog2(count) - 1;   //counter for # of bits being transmitted 
    logic [cw:0] bit_count;
    
    always_ff @(posedge clk) begin  //bit counter for input placement
        if(rst) begin
            bit_count <=0;
        end else if(current_state == DATA && tick_rx) begin 
            if(bit_count == count - 1) begin
                bit_count <=0;
            end else
                bit_count <= bit_count + 1;
        end else if(current_state != DATA) begin
            bit_count <= 0;
        end
    end
    
    //sampler
    logic[count-1: 0] rx_reg;
    always_ff @(posedge clk) begin
        if(rst) begin
            rx_reg <= '0;
        end else if (current_state == DATA && tick_rx) begin
            rx_reg[bit_count] <= rx;
        end
    end         
    
    //data valid & data_out
    always_ff @(posedge clk) begin
        if(rst) begin
            data_valid <=0;
            data_out <= 0;
        end else if(current_state == DATA && bit_count == count -1 && tick_rx) begin
            data_valid <= '1;
    data_out <= {rx, rx_reg[count-2:0]}; // bit 7 from rx directly, rest from rx_reg
        end else begin
            data_valid <= '0; 
        end
     end
  
    
endmodule
