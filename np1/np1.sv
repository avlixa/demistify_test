//-------------------------------------------------------------------------------------------------
module np1
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	inout  wire       ps2kCk,
	inout  wire       ps2kDq,

	output wire       usdCs,
	output wire       usdCk,
	output wire       usdDo,
	input  wire       usdDi,

	output wire       sramUb,
	output wire       sramLb,
	output wire       sramOe,
	output wire       sramWe,
	inout  wire[15:0] sramDq,
	output wire[20:0] sramA,

	output wire       led,
	output wire       stm
);
//-------------------------------------------------------------------------------------------------

wire clock56;
wire clock16;
wire locked;

pll pll
(
	.inclk0  (clock50),
	.locked  (locked ),
	.c0      (clock56)  // 56 MHz
//	.c1      (clock16)  // 16 MHz
);

//-------------------------------------------------------------------------------------------------

wire spiDo;
wire spiDi;
wire spiSs2;
wire spiSs3;
wire spiSs4;
wire confD0;

wire ps2kOCk;
wire ps2kODq;

substitute_mcu #(.sysclk_frequency(560)) controller
(
	.clk          (clock56),
	.reset_in     (1'b1   ),
	.reset_out    (       ),
	.spi_cs       (usdCs  ),
	.spi_clk      (usdCk  ),
	.spi_mosi     (usdDo  ),
	.spi_miso     (usdDi  ),
	.spi_fromguest(spiDo  ),
	.spi_toguest  (spiDi  ),
	.spi_ss2      (spiSs2 ),
	.spi_ss3      (spiSs3 ),
	.spi_ss4      (spiSs4 ),
	.conf_data0   (confD0 ),
	.ps2k_clk_in  (ps2kCk ),
	.ps2k_dat_in  (ps2kDq ),
	.ps2k_clk_out (ps2kOCk),
	.ps2k_dat_out (ps2kODq),
	.rxd          (1'b0   ),
	.txd          (       )
);

assign ps2kCk = !ps2kOCk ? 1'b0 : 1'bZ;
assign ps2kDq = !ps2kODq ? 1'b0 : 1'bZ;

//-------------------------------------------------------------------------------------------------

localparam CONF_STR =
{
	"zx48;;",
	"O01,SCR,0,1,2,3;",
	"V,v1.0"
};

wire [10:0] ps2_key;
/*
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire [31:0] sd_lba;
wire        sd_ack_conf;
wire        sd_buff_wr;
wire [ 8:0] sd_buff_addr;
wire [ 7:0] sd_buff_din;
wire [ 7:0] sd_buff_dout;

wire [63:0] img_size;
wire        img_mounted;
*/
wire       ioctl_ce = ne7M0;
wire       ioctl_download;
wire       ioctl_wr;
wire[24:0] ioctl_addr;
wire[ 7:0] ioctl_dout;

wire [31:0] status;
wire [ 1:0] buttons;

mist_io #(.STRLEN($size(CONF_STR)>>3)) mist_io
(
	.clk_sys       (clock56 ),
	.conf_str      (CONF_STR),

	.SPI_SCK       (usdCk),
	.SPI_DO        (spiDo),
	.SPI_DI        (spiDi),
	.SPI_SS2       (spiSs2),
	.CONF_DATA0    (confD0),

	.ps2_key       (ps2_key),
/*
	.sd_rd         (sd_rd),
	.sd_wr         (sd_wr),
	.sd_ack        (sd_ack),
	.sd_lba        (sd_lba),
	.sd_ack_conf   (sd_ack_conf),
	.sd_buff_wr    (sd_buff_wr),
	.sd_buff_addr  (sd_buff_addr),
	.sd_buff_din   (sd_buff_din),
	.sd_buff_dout  (sd_buff_dout),
	
	.img_size      (img_size),
	.img_mounted   (img_mounted),
*/
	.ioctl_download(ioctl_download),
	.ioctl_ce      (ioctl_ce      ),
	.ioctl_wr      (ioctl_wr      ),
	.ioctl_addr    (ioctl_addr    ),
	.ioctl_dout    (ioctl_dout    ),

	.status        (status),
	.buttons       (buttons)
);

//-------------------------------------------------------------------------------------------------
/*
wire        sdclk;
wire        sdss = 1;
wire        sdmosi;
wire        sdmiso;

wire        vsdmiso;

//wire sd_cs   = sdss   |  vsd_sel;
//wire sd_sck  = sdclk  & ~vsd_sel;
//wire sd_mosi = sdmosi & ~vsd_sel;
wire sd_miso = 0;

assign sdmiso = vsd_sel ? vsdmiso : sd_miso;

reg vsd_sel = 0;
always @(posedge clock56) if(img_mounted) vsd_sel <= |img_size;

sd_card sd_card
(
	.clk_sys(clock56),
	.clk_spi(clock16),
	.reset(~locked),

	.sck(sdclk),
	.ss(sdss | ~vsd_sel),
	.mosi(sdmosi),
	.miso(vsdmiso),

	.sdhc(1'b1),

	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_lba(sd_lba),
	.sd_ack_conf(sd_ack_conf),

	.sd_buff_wr(sd_buff_wr),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_din(sd_buff_din),
	.sd_buff_dout(sd_buff_dout)
);

reg sd_act;

always @(posedge clock56) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= sdmosi;
	old_miso <= sdmiso;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if((old_mosi ^ sdmosi) || (old_miso ^ sdmiso)) timeout <= 0;
end
*/
//-------------------------------------------------------------------------------------------------

reg ne7M0;
reg[2:0] ce = 1;
always @(negedge clock56) if(locked) begin
	ce <= ce+1'd1;
	ne7M0 <= ~ce[0] & ~ce[1] & ~ce[2];
end

wire[2:0] border = 3'd0;

wire blank;
wire vsync, hsync;
wire r, g, b, i;

wire[ 7:0] d = sramDq[7:0];
wire[12:0] a;

video Video
(
	.clock  (clock56),
	.ce     (ne7M0  ),
	.model  (1'b0   ),
	.border (border ),
	.blank  (blank  ),
	.vsync  (vsync  ),
	.hsync  (hsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.d      (d      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire[5:0] ri = { blank ? 1'd0 : r, r, {4{ r&i }} };
wire[5:0] gi = { blank ? 1'd0 : g, g, {4{ g&i }} };
wire[5:0] bi = { blank ? 1'd0 : b, b, {4{ b&i }} };
wire[5:0] ro, go, bo;

osd #(.OSD_X_OFFSET(10), .OSD_Y_OFFSET(10), .OSD_COLOR(4)) osd
(
	.clk_sys(clock56),
	.ce     (ne7M0  ),
	.SPI_SCK(usdCk  ),
	.SPI_DI (spiDi  ),
	.SPI_SS3(spiSs3 ),
	.rotate (2'd0   ),
	.VSync  (vsync  ),
	.HSync  (hsync  ),
	.R_in   (ri     ),
	.G_in   (gi     ),
	.B_in   (bi     ),
	.R_out  (ro     ),
	.G_out  (go     ),
	.B_out  (bo     )
);

assign sync = { 1'b1, ~(hsync ^ vsync) };
assign rgb = { ro, go, bo };

//-------------------------------------------------------------------------------------------------

wire       iniBusy = ioctl_download && ioctl_addr[24:16] == 0;
wire       iniWr = ioctl_wr;
wire[ 7:0] iniD = ioctl_dout;
wire[15:0] iniA = ioctl_addr[15:0];

assign sramUb = 1'b1;
assign sramLb = 1'b0;
assign sramOe = iniBusy;
assign sramWe = iniBusy ? !iniWr : 1'b1;
assign sramDq = {2{ sramWe ? 8'bZ : iniD }};
assign sramA  = { 5'd0, iniBusy ? iniA : { 1'b0, status[1:0], a } };

//-------------------------------------------------------------------------------------------------

assign led = usdCs;
assign stm = 1'b0;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
