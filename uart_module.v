`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UART TX module
// The module is reponsible for transmission of given data and sets flags according to the internal state.
// The module would require an internal clock signal, an enable signal, a send signal for transmitting, an 
// acknowledgement bit for uploading the byte to send, the packet config register and the byte to send.
// The module would output the status register and UART serial signal.
// Refer to the FIFO module for explanation on packet config register and status register.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module uart_tx (
    input 		 	  clk, tx_ena, tx_send, load_ack,
    input 	   [22:0] packet_config,
    input 		[7:0] tx_byte,
    output reg [2:0] status,
    output reg	 	  serial_out);
    
    parameter IDLE=0, START=1, DATA=2, PARITY=3, STOP=4, LOAD=5 ;
    reg [15:0] ticks  = '0  ;
    reg [2:0]  state = IDLE ;
    reg [2:0]  counter = '0 ;
    
    always@(posedge clk) begin
        if (tx_ena) begin
            if (~|ticks | ~|state | state==LOAD) begin
                
                case(state)
                    IDLE  : state <= tx_send ? START : IDLE ;
                    START : state <= DATA ;
                    DATA  : begin
                        if (counter == {1'b1,packet_config[17:16]}) begin
                            counter <= '0 ;
                            state <= packet_config[19] ? PARITY : STOP ;
                        end else begin
                            state <= DATA ;
                            counter <= counter + 1'b1 ;
                        end
                    end
                    PARITY : state <= STOP ;
                    STOP   : begin
                        if (counter[0] == packet_config[18]) begin
                            state <= packet_config[21] ? LOAD : IDLE ;
                            counter <= '0 ;
                        end else begin
                            state <= STOP ;
                            counter <= counter + 1'b1 ;
                        end
                    end
                    LOAD : state <= load_ack ? IDLE : LOAD ;
                endcase                
            end
            if (~|state)
                ticks <= (tx_send) ? (|packet_config[15:0] ? 16'd1 : 16'd0) : 16'd0 ;
            else if (state==LOAD)
                ticks <= 16'd0 ;
            else 
                ticks <= (ticks==packet_config[15:0]) ? '0 : ticks + 1'b1 ;
        end
    end
    
    always@* begin
        case(state)
            IDLE   : serial_out = 1'b1 ;
            START  : serial_out = 1'b0 ;
            DATA   : serial_out = tx_byte[counter] ;
            PARITY : serial_out = ^tx_byte ^ packet_config[20] ;
            STOP   : serial_out = 1'b1 ;
            LOAD   : serial_out = packet_config[22] ;
        endcase
    end
    
    assign status[2] = (state==LOAD) ;
    assign status[1] = (state==IDLE) ;
    assign status[0] = (state!=IDLE) & (state!=LOAD) ;
    
endmodule

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UART RX module
// This module is responsible for translation of UART serial signal into full bytes and sets flags accordingly.
// The module would require an internal clock signal, an enable signal, a packet config register, a status 
// enable register, a status clear register, the serial input line and load acknowledgement.
// Refer to the testbench for explanation on packet config register and status register.
// The module would output the status register, received byte and ready to read signal.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module uart_rx (
    input 		 	  clk, rx_ena, serial_in, load_ack, err_ack,
    input 	   [22:0] packet_config,
    output reg  [5:0] status,
    output reg  [7:0] rx_byte );
   
    parameter IDLE=0, DATA=1, PARITY=2, PARITY_ERR=3, STOP=4, STOP_ERR=5, LOAD=6, LOAD_DET=7 ;
    reg [15:0] ticks  = '0  ;
    reg [2:0]  state = IDLE ;
    reg [2:0]  counter = '0 ;
    reg        bit_ack = 0  ;
    reg        bit_set = 0  ;   // to deal with Tx sampling out 0 when data loading
    
    always@ (posedge clk) begin
        if (rx_ena) begin
            if ((~|ticks) | ~|state | state==LOAD) begin
                case(state)
                    IDLE  : begin
                        state <= serial_in ? IDLE : DATA ;
                        bit_set <= '0 ;
                    end
                    DATA  : begin
                        if (counter=={1'b1,packet_config[17:16]}) begin
                            state <= packet_config[19] ? PARITY : STOP ;
                            counter <= 3'd0 ;
                        end
                        else begin
                            state <= DATA ;
                            counter <= counter + 3'd1 ;
                        end
                    end
                    PARITY : begin
                        if (packet_config[19])
                            state <= ((^rx_byte)^serial_in==packet_config[20]) ? STOP : PARITY_ERR ;
                        else
                            state <= STOP ;
                    end
                    PARITY_ERR : state <= err_ack ? IDLE : PARITY_ERR ;
                    STOP : begin
                        if (counter[0]==packet_config[18]) begin
                            state <= serial_in ? (packet_config[21] ? LOAD : LOAD_DET) : STOP_ERR ;
                            counter <= 3'd0 ;
                        end
                        else begin
                            state <= serial_in ? STOP : STOP_ERR ;
                            counter <= counter + 3'd1 ;
                        end
                    end
                    STOP_ERR : state <= err_ack ? (packet_config[21] ? LOAD : IDLE) : STOP_ERR ;
                    LOAD 	 : begin
                        if (~bit_set & ~serial_in)
                            bit_set <= 1'b1 ;
                        state <= bit_ack & (load_ack|~packet_config[21]) ? IDLE : LOAD ;
                    end
                    LOAD_DET : begin
                        state <= serial_in ? IDLE : LOAD ;
                        bit_set <= ~serial_in ;
                    end
                endcase
            end
            
            if (~|state)
                ticks <= serial_in ? 16'd0 : 16'd1 ;
            else 
                ticks <= (ticks==packet_config[15:0]) ? '0 : ticks + 1'b1 ;

        end
    end
    
    always@* begin
        case(state)
            IDLE : begin
                rx_byte = '0 ;
                bit_ack = '0 ;
            end
            DATA : begin
                if (~|ticks)
	                rx_byte[counter] = serial_in ;
            end
            LOAD : bit_ack = bit_ack ? bit_set : serial_in ;
        endcase
    end
    
    assign status[0] = state == PARITY_ERR ;
    assign status[1] = state == STOP_ERR   ;
    assign status[2] = (state == LOAD) & bit_set ;
    assign status[3] = state == LOAD ;
    assign status[4] = state == IDLE ;
    assign status[5] = (state!=IDLE)&(state!=LOAD)&(state!=LOAD_DET) ;

endmodule

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UART FIFO module
// This module incorporates an 8 byte FIFO buffer for the UART devices and also provides status registers to 
// monitor the current states of UART device and the FIFO. Both the transmitter and receiver are supported.
// The module would require an internal clock signal, an enable signal for both modules, write/read request
// for Tx/Rx modules, serial input line (for Rx module), byte to send, a packet config register.
// The module would output the serial output (from Tx module), a read acknowledgement register(from Rx), the byte
// received (from Rx module) and a status register.
// Refer to the testbench for explanation on packet config register and status register.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module uart_fifo (
    input clk, tx_ena, rx_ena, write_request, read_request, serial_in,
    input [7:0] tx_byte,
    input [22:0] packet_config,
    output serial_out,
    output reg read_ack,
    output reg [7:0] rx_byte,
    output [12:0] status
);
    initial read_ack = 1'b0;
    initial rx_byte = 8'd0 ;
    reg tx_send = 1'b0 	   ;
    reg rx_received = 1'b0 ;
    reg tx_load_ack = 1'b0 ;
    reg rx_load_ack = 1'b0 ;
    reg [7:0] out_byte, in_byte ;
    reg [2:0] tx_status		 ; 
    reg [5:0] rx_status 	 ;
    reg [1:0] w_address = '0 ;
    reg [1:0] r_address = '0 ;
    reg [7:0][7:0] FIFO ;
    reg tx_empty = 1'b1 ;
    reg rx_empty = 1'b1 ;
    always@(posedge clk) begin
        // tx FIFO logic
        if (tx_ena) begin
            if (write_request) begin
                tx_empty <= 1'b0 ;
                FIFO[{1'b0, w_address+(tx_empty?1'b0:1'b1)}] <= tx_byte ;
                w_address <= w_address + (tx_empty?1'b0:1'b1)  ;
            end
            else if (tx_status[2]) begin
                out_byte <= FIFO[0] ;
                tx_load_ack <= ~tx_empty ;
            end
            else if (tx_status[1]) begin
                if (~tx_load_ack)
                    out_byte <= FIFO[0] ;
                tx_send <= ~tx_empty ;
            end
            else if (tx_status[0] & tx_send) begin 
                tx_load_ack <= 1'b0 ;
                tx_send <= 1'b0 ;
                tx_empty <= (~|w_address) ;
                FIFO[3:0] <= FIFO[3:1] ;
                w_address <= w_address - (|w_address) ; 
            end
        end
        
        if (read_ack)
            read_ack = 1'b0 ;
        
        // rx FIFO logic
        if (rx_ena) begin
            if (rx_status[3] & rx_received) begin
                rx_received <= 1'b0 ;
                rx_load_ack <= 1'b1 ;
                rx_empty <= 1'b0 ;
                FIFO[{1'b1, r_address+(rx_empty?1'b0:1'b1)}] <= in_byte ;
                r_address <= r_address+(rx_empty?1'b0:1'b1) ;
            end
            else if (rx_status[4] & ~rx_load_ack & rx_received) begin
                rx_received <= 1'b0 ;
                rx_empty <= 1'b0 ;
                FIFO[{1'b1, r_address+(rx_empty?1'b0:1'b1)}] <= in_byte ;
                r_address <= r_address+(rx_empty?1'b0:1'b1) ;
            end
            else if (rx_status[5]) begin
                rx_load_ack <= 1'b0 ;
                rx_received <= 1'b1 ;
            end
            else if (read_request) begin
                rx_empty <= (~|r_address);
                FIFO[7:4] <= FIFO[7:5] ;
                rx_byte <= FIFO[4] ;
                read_ack <= 1'b1 ;
            end
        end
    end
       
    assign status[2:0] = tx_status ;
    assign status[8:3] = rx_status ;
    assign status[9] = &w_address  ;
    assign status[10] = tx_empty   ;
    assign status[11] = &r_address ;
    assign status[12] = rx_empty   ;
    
    uart_tx tx_inst (clk, tx_ena, tx_send, tx_load_ack, packet_config, out_byte, tx_status, serial_out) ;
    uart_rx rx_inst (clk, rx_ena, serial_in, rx_load_ack, 1'b0, packet_config, rx_status, in_byte)      ;

endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// The 23 bit packet configuration register can be breaken down into following parts:
// packet_config[15:0] is the clock divider, which dictates the UART module clock speed 
// (baud rate = input frequency / clock divider )
// packet_config[17:16] dictates the number of data bits sent per packet. (0 to 3 correspond to 5 to 8)
// packet_config[18] dictates the number of stop bits per packet. 0 for 1 stop bit and 1 for 2 stop bits.
// packet_config[19] is the parity enable bit. 0 for no parity and 1 for parity enable.
// packet_config[20] is the odd parity of the byte. 1 if the data frame has odd parity and 0 if not (if parity enabled)
// packet_config[21] is the break enable bit. 1 enables a data loading state after sending all the data (for Tx)
// packet_config[22] dictates which bit is sent by the TX during the loading state (if break enabled)
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// The 13-bit status register returns the status as following:
// status[2:0] is the tx_status register. status[0] indicates whether the Tx is transmitting, status[1] indicates if the Tx is
// idle and status[2] indicates if the Tx is in data loading state, if enabled.
// status[8:3] is the rx_status register. status[3] indicates if Rx detected a parity error(if parity enabled), status[4]
// indicates if Rx detects a stop bit error, status[5] indicates if Rx detected the Tx entering a loading state, status[6]
// indicates if Rx in the data loading state, status[7] indicates if Rx is in idle state and status[8] indicates if Rx is
// receiving the data.
// status[13:9] refers to the FIFO states. status[9] for Tx buffer being full, status[10] for Tx buffer being empty, status[11] 
// for Rx buffer being full and status[13] for Rx buffer being empty.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module top_module ();
    reg clk = 1'b0 ;
    always #5 clk = ~ clk ;
    initial `probe_start  ;
    reg w_req, r_req, serial, read_ack, tx_send, tx_load_ack;
    reg [7:0] tx_byte,rx_byte ;
    reg [12:0] status ;
    `probe(clk)	     ;
    `probe(w_req)    ;
    `probe(r_req)    ;
    `probe(tx_byte)  ;
    `probe(rx_byte)  ;
    `probe(serial)   ;
    `probe(status)   ;
    `probe(read_ack) ;
    
    initial begin
        r_req = 1'b0	  ;
        w_req = 1'b0      ;
        tx_byte = 8'haa   ;
        #10 w_req = 1'b1  ;
        #10 w_req = 1'b0  ;
        #250
        r_req = 1'b1 ;
        #10 r_req = 1'b0  ;
        #50 $finish      ;
    end
    uart_fifo inst1 (clk, 1'b1, 1'b1, w_req, r_req, serial, tx_byte, 23'h3b0000, serial, read_ack, rx_byte, status) ;
    
endmodule