//
// scandoubler.v
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2017-2021 Alexey Melnikov
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 

// TODO: Delay vsync one line

module scandoubler #(parameter LENGTH=768, parameter HALF_DEPTH=0)
(
	// system interface
	input             clk_vid,
	input             hq2x,

	// shifter video interface
	input             ce_pix,
	input             hs_in,
	input             vs_in,
	input             hb_in,
	input             vb_in,
	input  [DWIDTH:0] r_in,
	input  [DWIDTH:0] g_in,
	input  [DWIDTH:0] b_in,

	// output interface
	output            ce_pix_out,
	output reg        hs_out,
	output            vs_out,
	output            hb_out,
	output            vb_out,
	output [DWIDTH:0] r_out,
	output [DWIDTH:0] g_out,
	output [DWIDTH:0] b_out
);

localparam DWIDTH = HALF_DEPTH ? 3 : 5;

reg  [7:0] pix_len = 0;
wire [7:0] pl = pix_len + 1'b1;

reg  [7:0] pix_in_cnt = 0;
wire [7:0] pc_in = pix_in_cnt + 1'b1;
reg  [7:0] pixsz, pixsz2, pixsz4 = 0;
wire [DWIDTH:0] r_aux, g_aux, b_aux;

reg ce_x4i, ce_x1i;

always @(posedge clk_vid) begin :block_vid_sd
   reg old_ce, valid, hs;

	if(~&pix_len) pix_len <= pl;
	if(~&pix_in_cnt) pix_in_cnt <= pc_in;

	ce_x4i <= 0;
	ce_x1i <= 0;

	// use such odd comparison to place ce_x4 evenly if master clock isn't multiple of 4.
	if((pc_in == pixsz4) || (pc_in == pixsz2) || (pc_in == (pixsz2+pixsz4))) ce_x4i <= 1;

	old_ce <= ce_pix;
	if(~old_ce & ce_pix) begin
		if(valid & ~hb_in & ~vb_in) begin
			pixsz  <= pl;
			pixsz2 <= {1'b0,  pl[7:1]};
			pixsz4 <= {2'b00, pl[7:2]};
		end
		pix_len <= 0;
		valid <= 1;
	end

	hs <= hs_in;
	if((~hs & hs_in) || (pc_in >= pixsz)) begin
		ce_x4i <= 1;
		ce_x1i <= 1;
		pix_in_cnt <= 0;
	end

	if(hb_in | vb_in) valid <= 0;
end

reg req_line_reset;
reg [DWIDTH:0] r_d, g_d, b_d;
always @(posedge clk_vid) begin
	if(ce_x1i) begin
		req_line_reset <= hb_in;
		r_d <= r_in;
		g_d <= g_in;
		b_d <= b_in;
	end
end

//Hq2x #(.LENGTH(LENGTH), .HALF_DEPTH(HALF_DEPTH)) Hq2x
//(
//	.clk(clk_vid),
//
//	.ce_in(ce_x4i),
//	.inputpixel({b_d,g_d,r_d}),
//	.disable_hq2x(~hq2x),
//	.reset_frame(vb_in),
//	.reset_line(req_line_reset),
//
//	.ce_out(ce_x4o),
//	.read_y(sd_line),
//	.hblank(hbo[0]&hbo[8]),
//	.outpixel({b_out,g_out,r_out})
//);

reg  curbuf = 1'b0;
reg  prevbuf = 1'b0;
reg [3*(DWIDTH+1)-1:0] offsin, offsout;
wire reset_line, reset_frame;
assign reset_line = req_line_reset;
assign reset_frame = vb_in;
reg old_reset_line;
reg old_reset_frame;
wire hblank;
assign hblank = hbo[0]&hbo[8];

dpram_sd #(.ADDRWIDTH(10),.DATAWIDTH(3*(DWIDTH+1))) sdbuffer //buffer 1024 bytes
(
	.clock(clk_vid),
	.address_a({curbuf,offsin}),
	.data_a({b_d,g_d,r_d}),
	.wren_a(ce_x1i),
	.address_b({curbuf,offsout}),
	.wren_b(1'b0),
	.q_b({b_aux,g_aux,r_aux})
);

always @(posedge clk_vid) begin
   if(ce_x1i) begin //pixel in address
      old_reset_line  <= reset_line;
      offsin <= offsin + 1'd1;
      if(old_reset_line && ~reset_line) begin
         old_reset_frame <= reset_frame;
         offsin <= 1'b0;
         curbuf <= ~curbuf;
         prevbuf <= curbuf;
         if(old_reset_frame & ~reset_frame) begin
            curbuf <= 1'b0;
            prevbuf <= 1'b0;
         end
      end   
   end
   
   if(ce_x2o) begin //pixel out address
      if(~hblank & ~&offsout) offsout <= offsout + 1'd1;
      if(hblank) offsout <= 0;   
   end
end

//assign r_out = hblank? 0 : r_aux;
//assign g_out = hblank? 0 : g_aux;
//assign b_out = hblank? 0 : b_aux;
assign r_out = r_aux;
assign g_out = g_aux;
assign b_out = b_aux;


reg  [7:0] pix_out_cnt = 0;
wire [7:0] pc_out = pix_out_cnt + 1'b1;

reg ce_x4o, ce_x2o;

always @(posedge clk_vid) begin : block_x2o
	reg hs1;

	if(~&pix_out_cnt) pix_out_cnt <= pc_out;

	ce_x4o <= 0;
	ce_x2o <= 0;

	// use such odd comparison to place ce_x4 evenly if master clock isn't multiple of 4.
	if((pc_out == pixsz4) || (pc_out == pixsz2) || (pc_out == (pixsz2+pixsz4))) ce_x4o <= 1;
	if( pc_out == pixsz2) ce_x2o <= 1;

	hs1 <= hs_out;
	if((~hs1 & hs_out) || (pc_out >= pixsz)) begin
		ce_x2o <= 1;
		ce_x4o <= 1;
		pix_out_cnt <= 0;
	end
end

reg [1:0] sd_line = 2'b0;
reg [3:0] vbo = 4'b0;
reg [3:0] vso = 4'b0;
reg [8:0] hbo = 9'b0;

always @(posedge clk_vid) begin : block_sd
`ifdef DEBUG
   reg [31:0] hcnt = 32'b0;
	reg [30:0] sd_hcnt = 31'b0;
`else
	reg [31:0] hcnt;// = 32'b0;
	reg [30:0] sd_hcnt;// = 31'b0;
`endif
	reg [30:0] hs_start, hs_end;
	reg [30:0] hde_start, hde_end;

	reg hs2, hb; 
   
	if(ce_x4o) begin
		hbo[8:1] <= hbo[7:0];
	end

	// output counter synchronous to input and at twice the rate
	sd_hcnt <= sd_hcnt + 1'd1;
	if(sd_hcnt == hde_start) begin
		sd_hcnt <= 0;
		vbo[3:1] <= vbo[2:0];
	end

	if(sd_hcnt == hs_end) begin
		sd_line <= sd_line + 1'd1;
		if(&vbo[3:2]) sd_line <= 1;
		vso[3:1] <= vso[2:0];
	end

	if(sd_hcnt == hde_start)hbo[0] <= 0;
	if(sd_hcnt == hde_end)  hbo[0] <= 1;

	// replicate horizontal sync at twice the speed
	if(sd_hcnt == hs_end)   hs_out <= 0;
	if(sd_hcnt == hs_start) hs_out <= 1;

	hs2 <= hs_in;
	hb <= hb_in;

	hcnt <= hcnt + 1'd1;
	if(hb && !hb_in) begin
		hde_start <= hcnt[31:1];
		hbo[0] <= 0;
		hcnt <= 0;
		sd_hcnt <= 0;
		vbo <= {vbo[2:0],vb_in};
	end

	if(!hb && hb_in) hde_end <= hcnt[31:1];

	// falling edge of hsync indicates start of line
	if(hs2 && !hs_in) begin
		hs_end <= hcnt[31:1];
		vso[0] <= vs_in;
	end

	// save position of rising edge
	if(!hs2 && hs_in) hs_start <= hcnt[31:1];
end

assign vs_out = vso[3];
assign ce_pix_out = hq2x ? ce_x4o : ce_x2o;

//Compensate picture shift after HQ2x
assign vb_out = vbo[3];
assign hb_out = hbo[6];

endmodule
