//-------------------------------------------------------------------------------------------------
module zx1
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 8:0] rgb,

	inout  wire       ps2kCk,
	inout  wire       ps2kDQ,

	output wire       sdcCs,
	output wire       sdcCk,
	output wire       sdcMosi,
	input  wire       sdcMiso,

	output wire       sramWe,
	inout  wire[ 7:0] sramDQ,
	output wire[20:0] sramA,

	output wire       led
);
//-------------------------------------------------------------------------------------------------

wire clock28;
clock clock(clock50, clock28, power);

reg[1:0] ce = 0;
wire ne14M = ~ce[0];
wire ne7M0 = ~ce[0] & ~ce[1];
always @(negedge clock28) if(power) ce <= ce+1'd1;

//-------------------------------------------------------------------------------------------------

wire spiCk = sdcCk;
wire spiSs2;
wire spiSs3;
wire spiSs4;
wire spiSsIo;
wire spiMosi;
wire spiMiso;

wire kbiCk = ps2kCk;
wire kbiDQ = ps2kDQ;
wire kboCk; assign ps2kCk = kboCk ? 1'bZ : kboCk;
wire kboDQ; assign ps2kDQ = kboDQ ? 1'bZ : kboDQ;

substitute_mcu #(.sysclk_frequency(280)) controller
(
	.clk          (clock28),
	.reset_in     (1'b1   ),
	.reset_out    (       ),
	.spi_cs       (sdcCs  ),
	.spi_clk      (sdcCk  ),
	.spi_mosi     (sdcMosi),
	.spi_miso     (sdcMiso),
	.spi_req      (       ),
	.spi_ack      (1'b1   ),
	.spi_ss2      (spiSs2 ),
	.spi_ss3      (spiSs3 ),
	.spi_ss4      (spiSs4 ),
	.conf_data0   (spiSsIo),
	.spi_toguest  (spiMosi),
	.spi_fromguest(spiMiso),
	.ps2k_clk_in  (kbiCk  ),
	.ps2k_dat_in  (kbiDQ  ),
	.ps2k_clk_out (kboCk  ),
	.ps2k_dat_out (kboDQ  ),
	.ps2m_clk_in  (1'b1   ),
	.ps2m_dat_in  (1'b1   ),
	.ps2m_clk_out (       ),
	.ps2m_dat_out (       ),
	.joy1         (8'hFF  ),
	.joy2         (8'hFF  ),
	.joy3         (8'hFF  ),
	.joy4         (8'hFF  ),
	.buttons      (8'hFF  ),
	.rxd          (1'b0   ),
	.txd          (       ),
	.intercept    (       ),
	.c64_keys     (64'hFFFFFFFF)
);

//BUFG BufgSD(.I(usdCk), .O(spiCk));

//-------------------------------------------------------------------------------------------------

localparam CONF_STR =
{
	"ZXKYP;;",
	"O01,SCR,0,1,2,3;"
};

wire[63:0] status;

user_io #(.STRLEN(23), .SD_IMAGES(1)) user_io
(
	.conf_str      (CONF_STR),
	.conf_chr      (        ),
	.conf_addr     (        ),
	.clk_sys       (clock28 ),
	.clk_sd        (clock28 ),
	.SPI_CLK       (spiCk   ),
	.SPI_SS_IO     (spiSsIo ),
	.SPI_MOSI      (spiMosi ),
	.SPI_MISO      (spiMiso ),
	.status        (status  ),
	.buttons       (),
	.switches      (),
	.key_code      (),
	.key_strobe    (),
	.key_pressed   (),
	.key_extended  (),
	.joystick_0    (),
	.joystick_1    (),
	.sd_rd         (),
	.sd_wr         (),
	.sd_sdhc       (),
	.sd_ack        (),
	.sd_conf       (),
	.sd_lba        (),
	.sd_ack_conf   (),
	.sd_buff_addr  (),
	.sd_din        (),
	.sd_dout       (),
	.sd_din_strobe (),
	.sd_dout_strobe(),
	.img_size      (),
	.img_mounted   (),
	.mouse_x       (),
	.mouse_y       (),
	.mouse_z       (),
	.mouse_idx     (),
	.mouse_flags   (),
	.mouse_strobe  (),
	.serial_data   (8'd0),
	.serial_strobe (1'd0),
	.rtc           (),
	.ypbpr         (),
	.no_csync      (),
	.core_mod      (),
	.joystick_2    (),
	.joystick_3    (),
	.joystick_4    (),
	.ps2_kbd_clk   (),
	.ps2_kbd_data  (),
	.ps2_kbd_clk_i (),
	.ps2_kbd_data_i(),
	.ps2_mouse_clk (),
	.ps2_mouse_data(),
	.ps2_mouse_clk_i(),
	.ps2_mouse_data_i(),
	.joystick_analog_0(),
	.joystick_analog_1(),
	.scandoubler_disable()
);

wire       ioctlB;
wire       ioctlW;
wire[24:0] ioctlA;
wire[ 7:0] ioctlQ;

data_io data_io
(
	.clk_sys       (clock28 ),
	.clkref_n      (1'b0    ),
	.SPI_SCK       (spiCk   ),
	.SPI_SS2       (spiSs2  ),
	.SPI_SS4       (spiSs4  ),
	.SPI_DI        (spiMosi ),
	.SPI_DO        (spiMiso ),
	.ioctl_index   (        ),
	.ioctl_upload  (        ),
	.ioctl_download(ioctlB  ),
	.ioctl_wr      (ioctlW  ),
	.ioctl_addr    (ioctlA  ),
	.ioctl_din     (        ),
	.ioctl_dout    (ioctlQ  ),
	.ioctl_fileext (        ),
	.ioctl_filesize(        )
);

//-------------------------------------------------------------------------------------------------
/*
wire       ramW = ioctlB ? ioctlW : 1'b0;
wire[14:0] ramA = ioctlB ? ioctlA[14:0] : { status[1:0], a };
wire[ 7:0] ramD = ioctlQ;
wire[ 7:0] ramQ;
ram #(32) ram(clock28, 1'b1, ramW, ramA, ramD, ramQ);
*/

assign sramWe = ioctlB ? !ioctlW : 1'b1;
assign sramDQ = sramWe ? 8'bZ : ioctlQ;
assign sramA = { 6'd0, ioctlB ? ioctlA[14:0] : { status[1:0], a } };

//-------------------------------------------------------------------------------------------------

wire[2:0] border = 3'd0;

wire blank;
wire vsync, hsync;
wire r, g, b, i;

wire[ 7:0] d = sramDQ;
wire[12:0] a;

video Video
(
	.clock  (clock28),
	.ce     (ne7M0  ),
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

wire[2:0] ri = { blank ? 1'd0 : r, r&i, r };
wire[2:0] gi = { blank ? 1'd0 : g, g&i, g };
wire[2:0] bi = { blank ? 1'd0 : b, b&i, b };
wire[2:0] ro, go, bo;

osd #(.OSD_X_OFFSET(10), .OSD_Y_OFFSET(10), .OSD_COLOR(4), .OSD_AUTO_CE(0)) osd
(
	.clk_sys(clock28),
	.ce     (ne14M  ),
	.SPI_SCK(spiCk  ),
	.SPI_DI (spiMosi),
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

//-------------------------------------------------------------------------------------------------

assign stdn = 2'b01;
assign sync = { 1'b1, ~(hsync ^ vsync) };
assign rgb = { ro, go, bo };

assign led = 1'b1;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
