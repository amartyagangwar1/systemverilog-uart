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
    
    // 2-flop synchronizer for rx: it's asynchronous (driven by an external
    // transmitter with no clock relationship to clk), so sampling it
    // directly into combinational/synchronous logic risks metastability.
    // Everything below reads rx_sync, never the raw rx pin. Resets to 1
    // (idle/mark) so a reset doesn't look like a start bit to the FSM.
    logic rx_meta, rx_sync;
    always_ff @(posedge clk) begin
        if(rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

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
    // START/DATA advance on tick_baud (not tick_rx) so these transitions land on
    // the same free-running pulses that bound TX's bit periods, keeping RX locked
    // to TX regardless of the phase the free-running counter is at when a frame
    // starts. tick_rx (mid-bit) is used only for the sampling instant below.
    always_comb begin
        next_state = current_state;
        case (current_state) 
            IDLE: begin
               if(rx_sync == 0)
                    next_state = START;
               end
            START: begin
                if(tick_baud)
                    next_state = DATA;
                end
            DATA: begin
                if(last_bit_sampled && tick_baud)
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

    // latches once the final bit's tick_rx sample has actually happened, so
    // DATA->STOP (gated on tick_baud) can't fire a period early using the
    // pending (not-yet-sampled) bit_count == count-1 value
    logic last_bit_sampled;
    always_ff @(posedge clk) begin
        if(rst || current_state != DATA) begin
            last_bit_sampled <= 0;
        end else if(bit_count == count - 1 && tick_rx) begin
            last_bit_sampled <= 1;
        end
    end

    //sampler
    logic[count-1: 0] rx_reg;
    always_ff @(posedge clk) begin
        if(rst) begin
            rx_reg <= '0;
        end else if (current_state == DATA && tick_rx) begin
            rx_reg[bit_count] <= rx_sync;
        end
    end         
    
    //data valid & data_out
    // count==1 has no rx_reg bits to fold in (count-2 would be a negative,
    // illegal part-select), so it needs its own branch, chosen at
    // elaboration time via generate rather than a runtime if -- a plain
    // if/else would still force rx_reg[count-2:0] to elaborate for count==1
    // even in a dead branch.
    generate
        if (count == 1) begin : gen_data_out_single_bit
            always_ff @(posedge clk) begin
                if(rst) begin
                    data_valid <= 0;
                    data_out <= 0;
                end else if(current_state == DATA && bit_count == count - 1 && tick_rx) begin
                    data_valid <= '1;
                    data_out <= rx_sync;
                end else begin
                    data_valid <= '0;
                end
            end
        end else begin : gen_data_out_multi_bit
            always_ff @(posedge clk) begin
                if(rst) begin
                    data_valid <= 0;
                    data_out <= 0;
                end else if(current_state == DATA && bit_count == count - 1 && tick_rx) begin
                    data_valid <= '1;
                    data_out <= {rx_sync, rx_reg[count-2:0]}; // top bit from rx_sync directly, rest from rx_reg
                end else begin
                    data_valid <= '0;
                end
            end
        end
    endgenerate
  
    
endmodule
