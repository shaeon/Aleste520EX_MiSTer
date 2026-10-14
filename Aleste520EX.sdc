# Restricciones propias del core (las generales estan en sys/sys_top.sdc).

# El video del modo CPC sale de un PLL aparte (pll_vid, 80 MHz), asincrono con
# el resto: el nucleo sincroniza todos los cruces (rtl/cpc/cpc_video.sv). Un
# grupo solo = sin relacion con ningun otro reloj.
set_clock_groups -asynchronous -group [get_clocks {*|pll_vid|pll_vid_inst|altera_pll_i|*[*].*|divclk}]
