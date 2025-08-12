///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART TX buffer interface
  - retrieves data from TX memory if present and signals the TX module to send
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module TX_memory_interface(
    input				clk, tx_ena, write_req, rx_rts,
    input reg	[1:0]	tx_state,
    input reg	[9:0]	write_word,
    output reg	[9:0]	tx_word,
    output reg			tx_loaded,
    output				mem_FULL
);
    reg [15:0][9:0] TX_mem ;
    reg [3:0] TX_mem_addr ;
    wire mem_EMPTY ;
    reg tx_load_count ;
    
    `probe(TX_mem[3:0]);
    `probe(TX_mem_addr);
    `probe(mem_EMPTY);
        
    assign mem_EMPTY = ~|TX_mem_addr ;
    assign mem_FULL = &TX_mem_addr ;
    
    always@(posedge clk) begin
        if(~tx_ena) begin
            TX_mem <= 160'b0 ;
            tx_loaded <= 1'b0 ;
            TX_mem_addr <= 4'd0 ;
            tx_word <= 10'b0 ;
            tx_load_count <= 1'b0 ;
        end
        else begin
            if(write_req) begin
                TX_mem[TX_mem_addr] <= write_word;
                TX_mem_addr <= TX_mem_addr + 4'b1 ;
                tx_loaded <= tx_load_count ? tx_loaded : 1'b0 ;
                tx_load_count <= 1'b0 ;
            end
            else begin
                if(~mem_EMPTY & ~|tx_state & ~tx_loaded & rx_rts) begin
                    tx_word <= TX_mem[TX_mem_addr-1'b1] ;
                    TX_mem_addr <= TX_mem_addr - 1'b1 ;
                    tx_loaded <= 1'b1 ;
                    tx_load_count <= 1'b1 ;
                end
                else begin
                    tx_loaded <= tx_load_count ? tx_loaded : 1'b0 ;
                    tx_load_count <= 1'b0 ;
                end
            end
        end
    end
    
endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 UART RX buffer interface
  - retrieves data from RX module if present and stores in FIFO
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

module RX_memory_interface(
    input				clk, rx_ena, read_req,
    input reg	[2:0]	rx_status,
    input reg	[9:0]	rx_word,
    output reg	[9:0]	read_word,
    output reg			data_ack,
    output				mem_FULL
);
    reg [15:0][15:0] RX_mem ;
    reg [3:0] RX_mem_addr ;
    wire mem_EMPTY ;
    reg rx_data_ready, rx_data_ready_pre ;
    
    `probe(RX_mem[3:0]);
    `probe(RX_mem_addr);
    `probe(mem_EMPTY);
        
    assign mem_EMPTY = ~|RX_mem_addr ;
    assign mem_FULL = &RX_mem_addr ;
    
    always@(posedge clk) begin
        rx_data_ready_pre <= (rx_status == 2'd2) ;
        rx_data_ready <= (rx_data_ready_pre) ;
        if(~rx_ena) begin
            RX_mem <= 160'b0 ;
            RX_mem_addr <= 4'd0 ;
            data_ack <= 1'b0 ;
        end
        else begin
            if(read_req) begin
                read_word <= RX_mem[RX_mem_addr - 4'b1] ;
                RX_mem_addr <= RX_mem_addr - 4'b1 ;
                data_ack <= 1'b0 ;
            end
            else begin
                if(~mem_FULL & rx_data_ready) begin
                    RX_mem[RX_mem_addr] <= {6'b0, rx_word} ;
                    RX_mem_addr <= RX_mem_addr + 1'b1 ;
                    data_ack <= 1'b1 ;
                end
                else begin
                    data_ack <= 1'b0 ;
                end
            end
        end
    end
    
endmodule
