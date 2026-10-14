//============================================================================
//  Aleste 520EX para MiSTer
//
//  Entidad emu: pegamento entre el marco de MiSTer (sys/) y el nucleo del
//  Aleste 520EX (rtl/aleste520ex, submodulo sin modificar; ver
//  rtl/aleste520ex/rtl/aleste_core.sv). Equivale a aleste_mist_top.sv de las
//  placas MiST, con hps_io en lugar de user_io/data_io y el video por
//  video_mixer/ascal.
//
//  Copyright (C) 2026 Shaeon (Carlos Palmero)
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program.  If not, see <https://www.gnu.org/licenses/>.
//============================================================================
`default_nettype wire

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Puertos que no usa este core /////////

assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////
// Menu
//
// Los bits de status son los de la version MiST (aleste_mist_top.sv) para
// que el nucleo reciba lo mismo. Cambios: Scanlines (2-3) ya no existe (lo
// sustituye Scandoubler Fx en 21-23) y Aspect ratio (121-122) es nuevo.
//
//   0      Reset                        13-14  CPC boot
//   4      Audio mono / estereo ABC     15     Mouse (CPC)
//   5      Disk speed                   16     AMX mouse
//   6      Floppy drives                17-18  CPU speed
//   7-9    H centre                     20     Tape sound
//   10-12  V centre                     21-23  Scandoubler Fx
//   25     Test tone                    27     Invert tape in
//   121-122 Aspect ratio
//
// Ficheros (ioctl_index[5:0]), como en MiST:
//   0  ROM del sistema (boot.rom, se carga sola)   2  guion de bus (WBS)
//   1  imagen de RAM en bruto (SCRBIN)             3  cinta (CDT/TZX)
// Imagenes (hps_io, VDNUM=3): 0 unidad A:, 1 unidad B:, 2 CMOS del SETUP.
// Al arrancar, el firmware monta solos boot0.vhd (A:) y boot2.vhd (CMOS) si
// estan en games/Aleste520EX/.
//////////////////////////////////////////////////////////////////

`include "build_id.v"
localparam CONF_STR = {
	"Aleste520EX;;",
	"-;",
	"S0,DSKIMG,Mount Drive A:;",
	"S1,DSKIMG,Mount Drive B:;",
	"F3,CDTTZX,Load Tape;",
	"-;",
	"O[14:13],CPC boot,Aleste 520EX,AMSTRAD (Shift),Aleste BIOS;",
	"O[18:17],CPU speed,4 MHz,8 MHz (turbo),16 MHz;",
	"-;",
	"P1,Video;",
	"P1-;",
	"P1O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[23:21],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1O[9:7],H centre,0,+8,+16,+24,-32,-24,-16,-8;",
	"P1O[12:10],V centre,0,+2,+4,+6,-8,-6,-4,-2;",
	"P2,Audio & Tape;",
	"P2-;",
	"P2O[4],Audio,Mono,Stereo ABC;",
	"P2O[20],Tape sound,Disabled,Enabled;",
	"P2O[27],Invert tape in,Off,On;",
	"P2O[25],Test tone,No,Yes;",
	"P3,Hardware;",
	"P3-;",
	"P3O[5],Disk speed,Original,Fast;",
	"P3O[6],Floppy drives,2,1;",
	"P3O[15],Mouse (CPC),Enabled,Disabled;",
	"P3O[16],AMX mouse,Disabled,Joystick 1;",
	"P3-;",
	"P3S2,CMOVHDHD2,Mount CMOS (setup);",
	"P4,Developer;",
	"P4-;",
	"P4F0,ROM,Reload ROM;",
	"P4F1,SCRBIN,Load RAM image;",
	"P4F2,WBS,Run bus script;",
	"-;",
	"R[0],Reset & apply model;",
	"J1,Fire 1,Fire 2;",
	"jn,A,B;",
	"V,v",`BUILD_DATE
};

///////////////////////   RELOJES   ///////////////////////////////
// Como en MiST: 108/54/27 MHz del mismo PLL y en fase (el nucleo los trata
// como sincronos entre si) y 80 MHz para el video del modo CPC en un PLL
// aparte (asincrono; el nucleo sincroniza todos los cruces).

wire clk_system, clk_bus, clk_pixel;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_system),   // 108 MHz
	.outclk_1(clk_bus),      //  54 MHz
	.outclk_2(clk_pixel),    //  27 MHz
	.locked(pll_locked)
);

wire clk_vid;
pll_vid pll_vid
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),      //  80 MHz
	.locked()
);

///////////////////////   HPS   ///////////////////////////////////

wire         forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;
wire  [24:0] ps2_mouse;
wire  [31:0] joystick_0;
wire  [64:0] RTC;
wire  [21:0] gamma_bus;

wire         ioctl_download;
wire  [15:0] ioctl_index;
wire         ioctl_wr;
wire  [26:0] ioctl_addr;
wire   [7:0] ioctl_dout;
reg          ioctl_wait = 0;

wire  [31:0] sd_lba;
wire   [2:0] sd_rd, sd_wr, sd_ack;
wire  [13:0] sd_buff_addr;
wire   [7:0] sd_buff_dout, sd_buff_din;
wire         sd_buff_wr;
wire   [2:0] img_mounted;
wire         img_readonly;
wire  [63:0] img_size;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(3)) hps_io
(
	.clk_sys(clk_bus),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(16'd0),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	.joystick_0(joystick_0),
	.RTC(RTC),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),

	// Las tres imagenes comparten LBA y buffer en el nucleo (como user_io de
	// MiST): la misma LBA y los mismos datos para las tres unidades.
	.sd_lba('{sd_lba, sd_lba, sd_lba}),
	.sd_blk_cnt('{6'd0, 6'd0, 6'd0}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din, sd_buff_din, sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size)
);

// Control de flujo de las descargas. mist_loader mete los bytes en una FIFO
// de 2048 entradas sin aviso de lleno; en MiST el SPI limita el ritmo, pero
// el HPS de MiSTer puede mandar mucho mas deprisa. Con ioctl_wait se deja
// como maximo un byte cada LOAD_GAP ciclos de clk_bus (54 MHz / 32 =
// 1,7 MB/s, del orden del SPI de MiST). Si el LED parpadea deprisa tras una
// carga (FIFO desbordada), subir LOAD_GAP.
localparam [5:0] LOAD_GAP = 6'd32;
reg [5:0] load_cnt = 0;
always @(posedge clk_bus) begin
	if (ioctl_wr) begin
		load_cnt   <= LOAD_GAP;
		ioctl_wait <= 1;
	end else if (load_cnt != 0) begin
		load_cnt   <= load_cnt - 1'd1;
		ioctl_wait <= (load_cnt != 1);
	end else
		ioctl_wait <= 0;
end

// Teclado: ps2_key[10] cambia con cada tecla; el nucleo espera un pulso por
// tecla, como el key_strobe de user_io.
reg key_strobe = 0;
reg key_toggle = 0;
always @(posedge clk_bus) begin
	key_toggle <= ps2_key[10];
	key_strobe <= (ps2_key[10] != key_toggle);
end

// Raton: ps2_mouse = {cambio, Y, X, flags} con los signos en los flags,
// igual que el paquete PS/2 que reparte user_io en MiST.
reg mouse_strobe = 0;
reg mouse_toggle = 0;
always @(posedge clk_bus) begin
	mouse_toggle <= ps2_mouse[24];
	mouse_strobe <= (ps2_mouse[24] != mouse_toggle);
end
wire [7:0] mouse_flags = ps2_mouse[7:0];
wire [8:0] mouse_x     = {ps2_mouse[4], ps2_mouse[15:8]};
wire [8:0] mouse_y     = {ps2_mouse[5], ps2_mouse[23:16]};

// Entrada de cinta por el ADC de la placa (I/O board / ADC de MiSTer)
wire tape_adc, tape_adc_act;
ltc2308_tape ltc2308_tape
(
	.reset(0),
	.clk(CLK_50M),
	.ADC_BUS(ADC_BUS),
	.dout(tape_adc),
	.active(tape_adc_act),
	.adc_sync(),
	.adc_data()
);

///////////////////////   NUCLEO   ////////////////////////////////

wire        cpu_legacy;
wire [11:0] nat_rgb;
wire        nat_hs, nat_vs, nat_hblank, nat_vblank;
wire        cpc_ce_pix, cpc_hs, cpc_vs, cpc_hblank, cpc_vblank, cpc_hires;
wire  [7:0] cpc_r, cpc_g, cpc_b;
wire [15:0] audio_l, audio_r;
wire        loader_busy, loader_overflow, loader_timeout;
wire        cpu_running, cpu_halted;
wire [15:0] sdram_dq_o;
wire        sdram_dq_oe;
wire  [1:0] sdram_dqm;

aleste_core core
(
	.clk_system(clk_system),
	.clk_bus(clk_bus),
	.clk_pixel(clk_pixel),
	.clk_vid(clk_vid),
	.pll_locked(pll_locked),
	.user_reset(RESET | status[0] | buttons[1]),
	.boot_mode(status[14:13]),

	.key_strobe(key_strobe),
	.key_pressed(ps2_key[9]),
	.key_extended(ps2_key[8]),
	.key_code(ps2_key[7:0]),
	.joystick(joystick_0[7:0]),
	.audio_stereo(status[4]),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index[7:0]),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.sdram_dq_i(SDRAM_DQ),
	.sdram_dq_o(sdram_dq_o),
	.sdram_dq_oe(sdram_dq_oe),
	.sdram_a(SDRAM_A),
	.sdram_ba(SDRAM_BA),
	.sdram_dqm(sdram_dqm),
	.sdram_ncs(SDRAM_nCS),
	.sdram_nras(SDRAM_nRAS),
	.sdram_ncas(SDRAM_nCAS),
	.sdram_nwe(SDRAM_nWE),
	.sdram_cke(SDRAM_CKE),

	// Video nativo del Aleste LX (720x480, clk_pixel): arranque nativo y
	// pruebas. Pasa a clk_vid con native_resync (ver VIDEO).
	.vga_rgb(nat_rgb),
	.vga_hs(nat_hs),
	.vga_vs(nat_vs),
	.vga_hblank(nat_hblank),
	.vga_vblank(nat_vblank),

	.cpc_ce_pix(cpc_ce_pix),
	.cpc_r(cpc_r),
	.cpc_g(cpc_g),
	.cpc_b(cpc_b),
	.cpc_hs(cpc_hs),
	.cpc_vs(cpc_vs),
	.cpc_hires(cpc_hires),
	.cpc_hblank(cpc_hblank),
	.cpc_vblank(cpc_vblank),

	.audio_l(audio_l),
	.audio_r(audio_r),

	.fdc_fast(status[5]),
	.fdc_one_drive(status[6]),
	.mouse_x(mouse_x),
	.mouse_y(mouse_y),
	.mouse_flags(mouse_flags),
	.mouse_strobe(mouse_strobe),
	.mist_rtc(RTC[63:0]),            // mismo formato que MiST (BCD, byte 7 = 40h)
	.cpc_mouse_en(~status[15]),
	.amx_mouse_en(status[16]),
	.cpu_turbo(status[18:17]),
	.video_h_off(status[9:7]),
	.video_v_off(status[12:10]),
	.tape_sound(status[20]),
	.tape_invert(status[27]),
	.tape_ext(tape_adc),
	.test_tone(status[25]),

	.img_mounted(img_mounted),
	.img_wp(img_readonly),
	.img_size(img_size[31:0]),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(|sd_ack),
	.sd_buff_addr(sd_buff_addr[8:0]),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.loader_busy(loader_busy),
	.loader_overflow(loader_overflow),
	.loader_timeout(loader_timeout),
	.sdram_refreshing(),
	.cpu_running(cpu_running),
	.cpu_halted(cpu_halted),
	.cpu_legacy(cpu_legacy)
);

///////////////////////   SDRAM   /////////////////////////////////

assign SDRAM_DQ   = sdram_dq_oe ? sdram_dq_o : 16'hZZZZ;
assign SDRAM_DQML = sdram_dqm[0];
assign SDRAM_DQMH = sdram_dqm[1];

// Reloj de la SDRAM: clk_system invertido, sacado por un registro DDR del
// propio pin (como en MiST y en el sdram.sv de los cores de MiSTer).
altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk_system),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

///////////////////////   VIDEO   /////////////////////////////////
// Dos videos, como en MiST, elegidos con cpu_legacy:
//  - Modo CPC (uso normal): 15 kHz con la temporizacion del CRTC, en clk_vid
//    (80 MHz). cpc_ce_pix es el pixel: 80/5 = 16 MHz en los modos del CPC y
//    80/6 = 13,33 MHz en la alta resolucion del 520EX; el doblador de MiSTer
//    mide el periodo del ce en cada linea, asi que admite los dos.
//  - Nativo del Aleste LX (arranque nativo y pruebas): 720x480 a 31 kHz en
//    clk_pixel. native_resync lo pasa a clk_vid con un bufer de una linea
//    enganchado a la entrada (pixel de 80/3 = 26,67 MHz, retraso de unos
//    pocos pixeles). Ya es de 31 kHz: con el se apaga el doblador.
// En MiSTer todo el video entra por un solo CLK_VIDEO, por eso no basta el
// multiplexor de pines de MiST.

wire       nat_ce;
wire [7:0] nat_r, nat_g, nat_b;
wire       nat_hs_o, nat_vs_o, nat_hb_o, nat_vb_o;

native_resync native_resync
(
	.clk_pixel(clk_pixel),
	.in_rgb(nat_rgb),
	.in_hs(nat_hs),
	.in_vs(nat_vs),
	.in_hblank(nat_hblank),
	.in_vblank(nat_vblank),

	.clk_vid(clk_vid),
	.ce_pix(nat_ce),
	.r(nat_r),
	.g(nat_g),
	.b(nat_b),
	.hs(nat_hs_o),
	.vs(nat_vs_o),
	.hblank(nat_hb_o),
	.vblank(nat_vb_o)
);

// Que video se muestra: el del CPC con la CPU en modo CPC, el nativo si no.
// Cambia muy pocas veces (al arrancar una ROM); el escalador se resincroniza.
reg [1:0] legacy_s;
always @(posedge clk_vid) legacy_s <= {legacy_s[0], cpu_legacy};
wire sel_cpc = legacy_s[1];

wire       vid_ce  = sel_cpc ? cpc_ce_pix : nat_ce;
wire [7:0] vid_r   = sel_cpc ? cpc_r      : nat_r;
wire [7:0] vid_g   = sel_cpc ? cpc_g      : nat_g;
wire [7:0] vid_b   = sel_cpc ? cpc_b      : nat_b;
wire       vid_hs  = sel_cpc ? cpc_hs     : nat_hs_o;
wire       vid_vs  = sel_cpc ? cpc_vs     : nat_vs_o;
wire       vid_hb  = sel_cpc ? cpc_hblank : nat_hb_o;
wire       vid_vb  = sel_cpc ? cpc_vblank : nat_vb_o;

wire [1:0] ar = status[122:121];
assign VIDEO_ARX = (!ar) ? 13'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 13'd3 : 13'd0;

wire [2:0] scale = status[23:21];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
assign VGA_SL = sel_cpc ? sl[1:0] : 2'd0;   // el nativo ya es de 31 kHz

assign CLK_VIDEO = clk_vid;

video_mixer #(.LINE_LENGTH(800), .GAMMA(1)) video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
	.ce_pix(vid_ce),

	.scandoubler(sel_cpc && (scale || forced_scandoubler)),
	.hq2x(scale == 1),
	.gamma_bus(gamma_bus),

	.R(vid_r),
	.G(vid_g),
	.B(vid_b),

	.HSync(vid_hs),
	.VSync(vid_vs),
	.HBlank(vid_hb),
	.VBlank(vid_vb),

	.HDMI_FREEZE(HDMI_FREEZE),
	.freeze_sync(),

	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE)
);

///////////////////////   AUDIO   /////////////////////////////////
// AY, MagicSound y cinta ya mezclados en el nucleo: 16 bits con signo.

assign AUDIO_L   = audio_l;
assign AUDIO_R   = audio_r;
assign AUDIO_S   = 1;
assign AUDIO_MIX = 0;

///////////////////////   LED   ///////////////////////////////////
// LED_USER como el LED de MiST: encendido mientras se carga, parpadeo rapido
// si hubo error del cargador (FIFO desbordada o escritura sin dispositivo),
// parpadeo lento con la CPU en HALT. LED_DISK: accesos a las imagenes.

reg [25:0] blink;
always @(posedge clk_bus) blink <= blink + 1'd1;

assign LED_USER = loader_busy
                | ((loader_overflow | loader_timeout) & blink[22])
                | (cpu_halted & blink[25]);

reg [20:0] disk_led;
always @(posedge clk_bus) begin
	if (|sd_ack) disk_led <= '1;
	else if (disk_led != 0) disk_led <= disk_led - 1'd1;
end
assign LED_DISK = {1'b0, |disk_led};

endmodule
