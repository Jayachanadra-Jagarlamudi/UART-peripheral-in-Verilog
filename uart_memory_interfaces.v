///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART TX buffer interface
  - retrieves data from TX memory if present and signals the TX module to send
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module FIFO_autoreader_with_ecc(
	input clk, rst, load_begin, fifo_read,
	input [15:0] start_addr,
	input [3:0] addr_inc,
	input [6:0] data_struct, // [0:1] = #bytes per line, [6:3] = #lines to copy
	input [63:0] data_in,
	output mem_read_req,
	output reg [15:0] read_addr,
	output reg [15:0] data_out,
	output fifo_full, fifo_empty
);
	
	reg [11:0] FIFO [0:31] ;
	reg [5:0] wptr, rptr, ptr_jump;
	reg [2:0] byte_counter ;
	reg [3:0] word_counter; 
	reg [1:0] fifo_state;
	reg [63:0] read_data ;
	
	always@(posedge clk) begin
		read_data <= data_in ;
		ptr_jump <= (5'b1 << data_struct[1:0]) - 1'b1 ;
		if(rst) begin
			wptr <= 6'b0 ;
			rptr <= 6'b0 ;
			word_counter <= 4'b0 ;
			read_addr <= 16'b0 ;
			data_out <= 12'b0 ;
			fifo_state <= 2'b0 ;
		end
		else begin
			case(fifo_state) // FIFO WRITING FROM MEM FSM
				2'b00 : begin // IDLE
					fifo_state <= load_begin ? 2'b01 : 2'b00 ;
					word_counter <= 4'b0 ;
					read_addr <= start_addr ;
				end
				2'b01 : begin // DATA READ REQ
					byte_counter <= 3'b0 ;
					read_addr <= read_addr + addr_inc ;
					word_counter <= word_counter + {3'b0,~fifo_full} ;
					fifo_state <= fifo_full ? 2'b10 : 2'b11 ;
				end
				2'b10 : begin // WAIT FOR FIFO TO NOT BE FULL
					fifo_state <= fifo_full ? 2'b10 : 2'b11 ;
				end
				2'b11 : begin // READ DATA FROM MEM
					wptr <= wptr + 1'b1 ;
					byte_counter <= byte_counter + 1'b1 ;
					fifo_state <= (byte_counter==ptr_jump[3:0]) ? ( (word_counter==data_struct[6:2]) ? 2'b00 : 2'b01) : 2'b11 ;
					FIFO[wptr] <= {^(read_data[7:0] & 8'hDA), ^(read_data[7:0] & 8'hB6), read_data[7], ^(read_data[7:0] & 8'h71), read_data[6:4], ^(read_data[7:0] & 8'h0f), read_data[3:0]} ;
				end
			endcase
			
			// FIFO WRITING TO TX MODULE FSM
			rptr <= rptr + ~fifo_empty & fifo_read ;
			data_out <= {3'b0, FIFO[rptr]} ;
		end
	end
		
	assign fifo_full = ( {~rptr[5],rptr[4:0]} <= (wptr+ptr_jump) ) ;
    assign fifo_empty = ( wptr == rptr ) ;
	assign mem_read_req = (fifo_state == 2'b01) & ~fifo_full ;
	
endmodule
