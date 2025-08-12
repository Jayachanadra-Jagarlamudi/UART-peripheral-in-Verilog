///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART TX module
  - transmits the packet of data via the serial channel
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module uart_tx (
    input 		 	  	clk, tx_send, rx_rts,
    input		[4:0]	packet_config,
    input 		[13:0]	tx_data,
    output reg 	[1:0]	state,
    output reg	 	 	serial_out, done);
    
    parameter IDLE=0, START=1, DATA=2, STOP=3 ;
	reg [3:0]  counter ;
    
    
    always@(posedge clk) begin
		if(~tx_send) begin
			state <= IDLE ;
			counter <= 4'd0 ;
		end
		else begin
			case(state)
                IDLE  : state <= (tx_send&rx_rts) ? START : IDLE ;
				START : state <= DATA ;
				DATA  : begin
                    if ((counter+1'b1) == packet_config[3:0]) begin
						counter <= 4'd0 ;
						state <= STOP ;
					end else begin
						state <= DATA ;
						counter <= counter + 1'b1 ;
					end
				end
				STOP   : begin
                    if (counter[0] == packet_config[4]) begin
						state <= IDLE ;
						counter <= 4'd0 ;
					end else begin
						state <= STOP ;
						counter <= counter + 1'b1 ;
					end
				end
			endcase                
        end
    end
    
    always@* begin
        done = (state==STOP) ? ~(packet_config[4]^counter[0]) : 1'b0  ;			
        case(state)
            IDLE   : serial_out = 1'b1 ;
            START  : serial_out = 1'b0 ;
            DATA   : serial_out = tx_data[4'd13-counter] ;
            STOP   : serial_out = 1'b1 ;
        endcase
    end
    
endmodule


///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART TX module wrapper
  - interface between tx module and controller
  - encodes the data with SECDED code and sends it via the Tx module
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module uart_tx_wrapper (
    input 		 	  clk, tx_ena, tx_loaded, rx_rts,
    input 	   	[4:0] tx_config,
    input 		[9:0] tx_word,
	output reg	[1:0] status,
    output reg		  serial_out);
    
	
	wire [4:0] packet_config ;
 	reg [13:0] tx_coded_data ;
	reg tx_done, tx_send, tx_ready, tx_busy ;
	
    uart_tx tx_inst1(.clk(clk), .tx_send(tx_send), .rx_rts(rx_rts), .packet_config(packet_config), .tx_data(tx_coded_data), .state(status), .serial_out(serial_out), .done(tx_done)) ;
	
    `probe(status) ;
    `probe(packet_config) ;
    `probe(tx_done) ;
    `probe(tx_coded_data) ;
    
    always@(posedge clk) begin
        if(~tx_ena) begin
            tx_coded_data <= 14'b0 ;
            tx_send <= 1'b0 ;
            tx_ready <= 1'b0 ;
        end
        else begin
            tx_coded_data[13] <= tx_word[0] ^ tx_word[1] ^ tx_word[3] ^ tx_word[4] ^ tx_word[6] ^ tx_word[8] ;
			tx_coded_data[12] <= tx_word[0] ^ tx_word[2] ^ tx_word[3] ^ tx_word[5] ^ tx_word[6] ^ tx_word[9] ;
			tx_coded_data[11] <= tx_word[0] ;
			tx_coded_data[10] <= tx_word[1] ^ tx_word[2] ^ tx_word[3] ^ tx_word[7] ^ tx_word[8] ^ tx_word[9] ;
			tx_coded_data[9] <= tx_word[1] ;
			tx_coded_data[8] <= tx_word[2] ;
			tx_coded_data[7] <= tx_word[3] ;
			tx_coded_data[6] <= tx_word[4] ^ tx_word[5] ^ tx_word[6] ^ tx_word[7] ^ tx_word[8] ^ tx_word[9] ;
			tx_coded_data[5] <= tx_word[4] ;
			tx_coded_data[4] <= tx_word[5] ;
			tx_coded_data[3] <= tx_word[6] ;
			tx_coded_data[2] <= tx_word[7] ;
			tx_coded_data[1] <= tx_word[8] ;
			tx_coded_data[0] <= tx_word[9] ;
            tx_send <= tx_loaded ? 1'b1 : (tx_send & ~tx_done) ;
        end
    end
    
    
    assign packet_config[3:0] = tx_config[3:0] + 4'd2 + {3'd0, |tx_config[3:1]} + {3'd0, |tx_config[3:2]} ;
    assign packet_config[4] = tx_config[4] ;
    
endmodule
