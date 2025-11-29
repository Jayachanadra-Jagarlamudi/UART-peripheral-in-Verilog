///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART TX module
  - transmits the packet of data via the serial channel
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module tx_transmitter(
    input clk, rst, tx_send, rx_ready,
    input [7:0] packet_struct,
    input [15:0] tx_data,
    output tx_ready, tx_done,
    output reg serial_out
);
    parameter IDLE=0, START=1, DATA=2, PARITY=3, STOP=4 ;
    reg [3:0] bit_counter;
    reg [2:0] word_counter;
    reg [2:0] state;
    
    assign tx_ready = (state==IDLE) ;
    assign tx_done = (state==STOP) ;
    
    always@(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            bit_counter <= 4'b0 ;
            word_counter <= 3'b0 ;
        end
        else begin
            case(state)
                IDLE: begin
                    state <= tx_send ? START : IDLE ;
                    bit_counter <= 4'b0 ;
                    word_counter <= 3'b0 ;
                end
                START : begin
                    state <= rx_ready ? DATA : START ;
                end
                DATA : begin
                    state <= (bit_counter==packet_struct[3:0]) ? PARITY : DATA ;
                    bit_counter <= bit_counter + 1'b1 ;
                end
                PARITY : begin
                    state <= STOP ;
                end
                STOP : begin
                    state <= (word_counter == packet_struct[7:5]) ? IDLE : (rx_ready ? DATA : STOP) ;
                    bit_counter <= 4'b0 ;
                    word_counter <= word_counter + rx_ready ;
                end
            endcase
        end
    end
    
    always@(*) begin
        case(state)
            IDLE : serial_out = 1'b1 ;
            START : serial_out = 1'b0 ;
            DATA : serial_out = tx_data[bit_counter] ;
            PARITY : serial_out = ^tx_data ;
            STOP : serial_out = 1'b1 ;
        endcase
    end
    
endmodule

