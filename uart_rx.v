///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART RX module
  - receives the packet of data via the serial channel
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module uart_rx (
    input 				clk, serial_in, rx_receive,
    input		[4:0] 	packet_config,
    output reg  [1:0] 	status,
    output reg  [13:0] 	rx_data,
	output reg			done );
   
    parameter IDLE=0, DATA=1, STOP=2, STOP_ERR=3 ;
	reg [1:0] state ;
	reg [3:0] counter ;
    
    always@ (posedge clk) begin
        if (~rx_receive) begin
			state <= IDLE ;
			status <= IDLE ;
			counter <= 4'd0 ;
		end
        else begin
			case(state)
				IDLE  : begin
					state <= serial_in ? IDLE : DATA ;
					status <= serial_in ? IDLE : DATA ;
				end
				DATA  : begin
                    if ((counter+1'b1)==packet_config[3:0]) begin
						state <= STOP ;
						status <= STOP ;
						counter <= 4'd0 ;
					end
					else begin
						state <= DATA ;
						status <= DATA ;
						counter <= counter + 4'd1 ;
					end
				end
				STOP : begin
					if (counter[0]==packet_config[4]) begin
						state <= IDLE ;
						status <= serial_in ? IDLE : STOP_ERR ;
						counter <= 4'd0 ;
					end
					else begin
						state <= STOP ;
						status <= serial_in ? STOP : STOP_ERR ;
						counter <= 4'd1 ;
					end
				end
			endcase
        end
    end
    
    always@(*) begin
		done = (state==STOP) ? ~(packet_config[4]^counter[0]) : 1'b0  ;	
        if(~rx_receive)
            rx_data = '0 ;
        else begin
            if(state==DATA)
                rx_data[4'd13-counter] = serial_in ;
            else
                rx_data = rx_data ;
        end
    end
 
endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART RX module wrapper
  - interface between rx module and controller
  - receives the data from Rx module and verifies with SECDED
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module uart_rx_wrapper (
    input 		 	  clk, rx_ena, serial_in, data_ack,
    input 	   	[4:0] rx_config,
	output reg	[2:0] status,
    output reg  [9:0] rx_data,
    output reg		  rx_rts
);
    
    reg [3:0] syndrome ;
    reg [1:0] state;
    reg done, rx_receive ;
	reg [1:0] rx_status ;
	reg [13:0] rx_word_in ;
	reg [4:0] packet_config ;
    reg [9:0] rx_corrected_data ;
    
	uart_rx rx_inst1( .clk(clk), .serial_in(serial_in), .rx_receive(rx_receive), .packet_config(packet_config), .status(rx_status), .rx_data(rx_word_in), .done(done) );
	
    `probe(state) ;
    `probe(rx_word_in) ;
    `probe(packet_config) ;
    `probe(rx_status) ;
    `probe(done) ;
    `probe(syndrome) ;
    
    always@(posedge clk) begin
        if(~rx_ena) begin
            rx_corrected_data <= 10'b0 ;
            syndrome <= 4'd0 ;
			state <= 2'd0 ;
			rx_receive <= 1'b0 ;
        end
        else begin
            case(state)
                2'd2 : begin
                    rx_receive <= 1'b0 ;
                    state <= data_ack ? 2'd0 : 2'd2 ;
                end
                2'd1: begin
                    rx_receive <= 1'b0 ;
                    state <= 2'd2 ;
                    rx_corrected_data[0] <= rx_word_in[11] ^ (syndrome[0] & syndrome[1]) ;
                    rx_corrected_data[1] <= rx_word_in[9] ^ (syndrome[0] & syndrome[2]) ;
                    rx_corrected_data[2] <= rx_word_in[8] ^ (syndrome[1] & syndrome[2])  ;
                    rx_corrected_data[3] <= rx_word_in[7] ^ (syndrome[0] & syndrome[1] & syndrome[2])  ;
                    rx_corrected_data[4] <= rx_word_in[5] ^ (syndrome[0] & syndrome[3])  ;
                    rx_corrected_data[5] <= rx_word_in[4] ^ (syndrome[1] & syndrome[3])  ;
                    rx_corrected_data[6] <= rx_word_in[3] ^ (syndrome[0] & syndrome[1] & syndrome[3])  ;
                    rx_corrected_data[7] <= rx_word_in[2] ^ (syndrome[2] & syndrome[3])  ;
                    rx_corrected_data[8] <= rx_word_in[1] ^ (syndrome[0] & syndrome[2] & syndrome[3])  ;
                    rx_corrected_data[9] <= rx_word_in[0] ^ (syndrome[1] & syndrome[2] & syndrome[3])  ;
				end
				2'd0 : begin
                    rx_receive <= 1'b1 ;
                    syndrome[0] <= rx_word_in[13] ^ rx_word_in[11] ^ rx_word_in[9] ^ rx_word_in[7] ^ rx_word_in[5] ^ rx_word_in[3] ^ rx_word_in[1] ;
                    syndrome[1] <= rx_word_in[12] ^ rx_word_in[11] ^ rx_word_in[8] ^ rx_word_in[7] ^ rx_word_in[4] ^ rx_word_in[3] ^ rx_word_in[0] ;
                    syndrome[2] <= (|rx_config[3:1]) & (rx_word_in[10] ^ rx_word_in[9] ^ rx_word_in[8] ^ rx_word_in[7] ^ rx_word_in[2] ^ rx_word_in[1] ^ rx_word_in[0]) ;
                    syndrome[3] <= (|rx_config[3:2]) & (rx_word_in[6] ^ rx_word_in[5] ^ rx_word_in[4] ^ rx_word_in[3] ^ rx_word_in[2] ^ rx_word_in[1] ^ rx_word_in[0]) ; 
                    state <= {1'b0, done};
				end
            endcase
        end
    end
	
    always@* begin
        case(rx_config[3:0])
            4'd4 : rx_data = rx_corrected_data & 10'h00f ;
            4'd5 : rx_data = rx_corrected_data & 10'h01f ;
            4'd6 : rx_data = rx_corrected_data & 10'h03f ;
            4'd7 : rx_data = rx_corrected_data & 10'h07f ;
            4'd8 : rx_data = rx_corrected_data & 10'h0ff ;
        endcase
        
        if(~rx_ena)
            rx_rts = 1'b1 ;
        else begin
            case(state)
                2'd0 : rx_rts = 1'b1 ;
                2'd1 : rx_rts = 1'b0 ;
                2'd2 : rx_rts = 1'b0 ;
            endcase
        end
    end
    
	always@* begin
        if(state==2'd0) begin
			status = {1'b0, rx_status} ;
		end
		else begin
			if ( (syndrome==4'b1000) | (syndrome==4'b0100) | (syndrome==4'b0010) | (syndrome==4'b0001) )
				status = 3'b100 ;
			else
				status = 3'b111 ;
		end
	end
    
    assign packet_config[3:0] = rx_config[3:0] + 4'd2 + {3'd0, |rx_config[3:1]} + {3'd0, |rx_config[3:2]} ;
    assign packet_config[4] = rx_config[4] ;
    
endmodule
