        
module top_module();
    
    reg clk = 1'b0 ;
    always #5 clk = ~clk ;    
    reg tx_ena, tx_send, serial_out, tx_loaded, rx_ena, rx_rts, serial_in, rx_data_ack, write_req, TX_mem_FULL, mem_FULL ;
    reg [4:0] tx_config = 5'b0_1000 ;
    reg [4:0] rx_config = 5'b0_1000 ;
    reg [9:0] tx_word, write_word, rx_data, read_word ;
    reg [2:0] rx_status ;
    reg [1:0] tx_status ;
    
    initial `probe_start ;
    `probe(clk);
    `probe(tx_config);
    `probe(tx_ena);
    `probe(write_req);
    `probe(write_word);
    `probe(tx_loaded);
    `probe(tx_word);
    
    TX_memory_interface tx_mem_inst1( .clk(clk), .tx_ena(tx_ena), .rx_rts(rx_rts), .write_req(write_req), .tx_state(tx_status), .write_word(write_word), .tx_word(tx_word), .tx_loaded(tx_loaded), .mem_FULL(TX_mem_FULL) );
    uart_tx_wrapper tx_wrapper_inst1( .clk(clk), .tx_ena(tx_ena), .tx_loaded(tx_loaded), .tx_config(tx_config), .tx_word(tx_word), .rx_rts(rx_rts), .status(tx_status), .serial_out(serial_out));
    
    `probe(tx_status);
    `probe(serial_out);
    always@* begin
        serial_in = serial_out ;
    end
    
    `probe(rx_ena);
    `probe(rx_rts);
    `probe(serial_in);
    `probe(rx_config);
    `probe(rx_data);
    `probe(rx_data_ack);
    
    
    RX_memory_interface rx_mem_inst1( .clk(clk), .rx_ena(rx_ena), .read_req(1'b0), .rx_status(rx_status), .rx_word(rx_data), .read_word(read_word), .data_ack(rx_data_ack), .mem_FULL(mem_FULL) ) ;
    uart_rx_wrapper rx_wrapper_inst1( .clk(clk), .rx_ena(rx_ena), .serial_in(serial_in), .data_ack(rx_data_ack), .rx_config(rx_config), .rx_rts(rx_rts), .status(rx_status), .rx_data(rx_data)) ;
    
    `probe(rx_status);
    
    
    initial begin
        tx_ena = 1'b0 ;
        rx_ena = 1'b0 ;
        write_req = 1'b0 ;
        write_word = 10'b0 ;
        #30 tx_ena = 1'b1 ;
        rx_ena = 1'b1 ;
        write_req = 1'b1 ;
        write_word = 10'h09A ;
        #10 write_word = 10'h0A5 ;
        #10 write_word = 10'h0F7 ;
        #10 write_req = 1'b0 ;
        #700 ;
        #10 $finish ;
    end
    
endmodule
