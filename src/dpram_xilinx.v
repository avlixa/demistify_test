
module dpram_sd #(parameter DATAWIDTH=8, ADDRWIDTH=8, NUMWORDS=1<<ADDRWIDTH, MEM_INIT_FILE="")
(
	input	                 clock,

	input	 [ADDRWIDTH-1:0] address_a,
	input	 [DATAWIDTH-1:0] data_a,
	input	                 wren_a,
	output [DATAWIDTH-1:0] q_a,

	input	 [ADDRWIDTH-1:0] address_b,
	input	 [DATAWIDTH-1:0] data_b,
	input	                 wren_b,
	output [DATAWIDTH-1:0] q_b
);

    // BRAM to implement a dual port (2**ADDRWIDTH)Bytes memory buffer
    reg [DATAWIDTH-1:0] vram[0:2**ADDRWIDTH-1];
    integer i;
    initial begin
        for (i=0;i<(2**ADDRWIDTH);i=i+1)
            vram[i] = 8'h00;
        if (MEM_INIT_FILE != "") $readmemh(MEM_INIT_FILE, vram);
        for (i=0; i < 4; i=i+1) $display("%d:%h",i,vram[i]);        
    end
    
    reg [DATAWIDTH-1:0] out_a, out_b;
 
     // BRAM manager
    always @(posedge clock) begin
       if (wren_a == 1'b1)
         vram[address_a] <= data_a;
       else 
         out_a <= vram[address_a];
         
       if (wren_b == 1'b1)
         vram[address_b] <= data_b;
       else
         out_b <= vram[address_b];
    end
    
    assign q_a = out_a;
    assign q_b = out_b;

endmodule
