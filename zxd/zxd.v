//-------------------------------------------------------------------------------------------------
module zxd
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

	output wire       led
);
//-------------------------------------------------------------------------------------------------

wire ci;
IBUFG IBufg(.I(clock50), .O(ci));

wire bf, ck, co;
wire clock56;
wire locked;

DCM_SP #
(
	.CLKIN_PERIOD          (20.000),
	.CLKFX_DIVIDE          (25    ),
	.CLKFX_MULTIPLY        (28    )
)
Dcm0
(
	.RST                   (1'b0),
	.DSSEN                 (1'b0),
	.PSCLK                 (1'b0),
	.PSEN                  (1'b0),
	.PSINCDEC              (1'b0),
	.CLKIN                 (ci),
	.CLKFB                 (bf),
	.CLK0                  (ck),
	.CLK90                 (),
	.CLK180                (),
	.CLK270                (),
	.CLK2X                 (),
	.CLK2X180              (),
	.CLKFX                 (co),
	.CLKFX180              (),
	.CLKDV                 (),
	.PSDONE                (),
	.STATUS                (),
	.LOCKED                (locked)
);

BUFG BufgFb(.I(ck), .O(bf));
BUFG BufgCo(.I(co), .O(clock56));

reg ne7M0;
reg[2:0] ce = 1;
always @(negedge clock56) if(locked) begin
	ce <= ce+1'd1;
	ne7M0 <= ~ce[0] & ~ce[1] & ~ce[2];
end

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
	.spi_req      (       ),
	.spi_ack      (1'b1   ),
	.conf_data0   (confD0 ),
	.ps2k_clk_in  (ps2kCk ),
	.ps2k_dat_in  (ps2kDq ),
	.ps2k_clk_out (ps2kOCk),
	.ps2k_dat_out (ps2kODq),
	.ps2m_clk_in  (1'b1   ),
	.ps2m_dat_in  (1'b1   ),
	.ps2m_clk_out (       ),
	.ps2m_dat_out (       ),
	.joy1         (8'hFF  ),
	.joy2         (8'hFF  ),
	.joy3         (8'hFF  ),
	.joy4         (8'hFF  ),
	.buttons      (8'hFF  ),
	.c64_keys     (64'hFFFFFFFF),
	.rxd          (1'b0   ),
	.txd          (       ),
	.intercept    (       )
);

assign ps2kCk = !ps2kOCk ? 1'b0 : 1'bZ;
assign ps2kDq = !ps2kODq ? 1'b0 : 1'bZ;

BUFG BufgSD(.I(usdCk), .O(spiCk));

//-------------------------------------------------------------------------------------------------

localparam CONF_STR =
{
	"zx48;;",
	"O01,SCR,0,1,2,3;",
	"V,v1.0"
};

wire       ioctl_download;
wire[ 7:0] ioctl_index;
wire       ioctl_ce = 1'b1;
wire       ioctl_wr;
wire[24:0] ioctl_addr;
wire[ 7:0] ioctl_dout;

wire[31:0] status;

mist_io #(28) mist_io
(
	.clk_sys       (clock56 ),
	.conf_str      (CONF_STR),

	.SPI_SCK       (spiCk),
	.SPI_DO        (spiDo),
	.SPI_DI        (spiDi),
	.SPI_SS2       (spiSs2),
	.CONF_DATA0    (confD0),

	.ioctl_download(ioctl_download),
	.ioctl_index   (ioctl_index   ),
	.ioctl_ce      (ioctl_ce      ),
	.ioctl_wr      (ioctl_wr      ),
	.ioctl_addr    (ioctl_addr    ),
	.ioctl_dout    (ioctl_dout    ),

	.sd_conf       (1'b0),
	.sd_sdhc       (1'b0),
	.sd_lba        (32'd0),
	.sd_rd         (2'd0),
	.sd_wr         (2'd0),
	.sd_ack        (),
	.sd_ack_conf   (),
	.sd_buff_addr  (),
	.sd_buff_dout  (),
	.sd_buff_din   (8'd0),
	.sd_buff_wr    (),
	.img_mounted   (),
	.img_size      (),

	.ps2_kbd_clk   (),
	.ps2_kbd_data  (),
	.ps2_mouse_clk (),
	.ps2_mouse_data(),
	.ps2_key       (),
	.ps2_mouse     (),

	.status        (status),
	.buttons       (      ),
	.switches      (      ),

	.joystick_0       (   ),
	.joystick_1       (   ),
	.joystick_analog_0(   ),
	.joystick_analog_1(   ),

	.ypbpr              ( ),
	.scandoubler_disable( )
);

//-------------------------------------------------------------------------------------------------

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
	.SPI_SCK(spiCk  ),
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

wire       iniBusy = ioctl_download;
wire       iniWr = ioctl_wr;
wire[15:0] iniA = ioctl_addr[15:0];
wire[ 7:0] iniD = ioctl_dout;

assign sramUb = 1'b1;
assign sramLb = 1'b0;
assign sramOe = 1'b0;
assign sramWe = iniBusy ? !iniWr : 1'b1;
assign sramDq = sramWe ? 16'bZ : {2{ iniD }};
assign sramA  = { 5'd0, iniBusy ? iniA : { 1'b0, status[1:0], a } };

//-------------------------------------------------------------------------------------------------

assign led = ~usdCs;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
