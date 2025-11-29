///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART RX module
  - receives the packet of data via the serial channel
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module rx_receiver(
    input clk, rst, data_ack, serial_in,
    input [7:0] packet_struct,
    output reg [15:0] rx_data,
    output reg rx_ready, data_ready, data_corrupted
);
    parameter IDLE=0, DATA=1, PARITY=2, STOP=3;
    reg [3:0] bit_counter;
    reg [2:0] word_counter;
    reg [1:0] state;
        
    always@(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            bit_counter <= 4'b0 ;
            word_counter <= 3'b0 ;
            data_corrupted <= 1'b0 ;
            data_ready <= 1'b0 ;
            rx_ready <= 1'b1 ;
        end
        else begin
            rx_ready <= ~(state==STOP) | data_ack ;
            case(state)
                IDLE: begin
                    state <= ~serial_in ? DATA : IDLE ;
                    bit_counter <= 4'b0 ;
                    word_counter <= 3'b0 ;
                end
                DATA : begin
                    state <= (bit_counter==packet_struct[3:0]) ? PARITY : DATA ;
                    bit_counter <= bit_counter + 1'b1 ;
                end
                PARITY : begin
                    state <= STOP ;
                    data_corrupted <= serial_in ^ ^rx_data ;
                    data_ready <= 1'b1 ;
                end
                STOP : begin
                    state <= data_ack ? ((word_counter == packet_struct[7:5]) ? IDLE : DATA) : STOP ;
                    bit_counter <= 4'b0 ;
                    word_counter <= word_counter + data_ack ;
                    data_corrupted <= data_ack ? 1'b0 : data_corrupted ;
                    data_ready <= ~data_ack ;
                end
            endcase
            
        end
    end
    
    always@(*) begin
        case(state)
            IDLE : rx_data = 16'b0 ;
            DATA : rx_data[bit_counter] = serial_in  ;
        endcase
    end
    
endmodule
