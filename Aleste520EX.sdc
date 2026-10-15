# Restricciones propias del core (las generales estan en sys/sys_top.sdc).

# ----------------------------------------------------------------------------
# Video del modo CPC
# ----------------------------------------------------------------------------
# Sale de un PLL aparte (pll_vid, 80 MHz), asincrono con el resto: el nucleo
# sincroniza todos los cruces (rtl/cpc/cpc_video.sv) y native_resync pasa el
# video nativo por una RAM de doble reloj. Un grupo solo = sin relacion con
# ningun otro reloj.
set_clock_groups -asynchronous -group [get_clocks {*|pll_vid|pll_vid_inst|altera_pll_i|*[*].*|divclk}]

# ----------------------------------------------------------------------------
# SDRAM
# ----------------------------------------------------------------------------
# Relojes del PLL principal (rtl/pll):
#   general[0]  clk_system 108 MHz (controlador de la SDRAM, dentro del nucleo)
#   general[3]  clk_sdram  108 MHz desfasado, sale al pin SDRAM_CLK por un
#               registro DDR (datain_h = 1, datain_l = 0: el pin copia el reloj)
set clk_sys   {*|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set clk_sdram {*|pll|pll_inst|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk}

create_generated_clock -name SDRAM_CLK -source [get_pins $clk_sdram] [get_ports {SDRAM_CLK}]

# Tiempos del chip (los mismos que en las placas MiST, valen para los chips de
# 32/64/128 MB de los modulos de MiSTer a 108 MHz con CL2):
#   entrada: tAC 6 ns + rutado (max), tOH (min)
#   salida:  tIS 1,5 ns (setup), tIH 0,8 ns (hold)
set_input_delay  -clock SDRAM_CLK -max 6.4  [get_ports {SDRAM_DQ[*]}]
set_input_delay  -clock SDRAM_CLK -min 3.2  [get_ports {SDRAM_DQ[*]}]
set_output_delay -clock SDRAM_CLK -max 1.5  [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_BA[*] SDRAM_DQML SDRAM_DQMH SDRAM_n* SDRAM_CKE}]
set_output_delay -clock SDRAM_CLK -min -0.8 [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_BA[*] SDRAM_DQML SDRAM_DQMH SDRAM_n* SDRAM_CKE}]

# Lectura: sdram_wishbone saca READ en el flanco N de clk_system y recoge el
# dato en N+4 (CL2). La palabra la lanza el flanco de SDRAM_CLK de N+2+fase,
# asi que la captura es el segundo flanco de clk_system tras el lanzamiento,
# no el primero (que es lo que TimeQuest supondria por defecto). Vale para
# cualquier desfase entre 0 y 360 grados.
set_multicycle_path -from [get_clocks {SDRAM_CLK}] -to [get_clocks $clk_sys] -setup -end 2
set_multicycle_path -from [get_clocks {SDRAM_CLK}] -to [get_clocks $clk_sys] -hold  -end 1
