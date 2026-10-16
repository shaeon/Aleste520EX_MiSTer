# Detalle de tiempos de la SDRAM de un proyecto ya compilado.
# Uso (en la carpeta del proyecto, despues de compilar):
#   quartus_sta -t tools/rutas_sdram.tcl
# Deja el detalle de las rutas peores en output_files/rutas_sdram.txt

project_open Aleste520EX -revision Aleste520EX
create_timing_netlist
read_sdc
update_timing_netlist

set clk_sys {*|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set f output_files/rutas_sdram.txt
file delete -force $f

# 1. Las 30 rutas peores que acaban en clk_system (de donde sale el -3,3 ns)
report_timing -setup -to_clock [get_clocks $clk_sys] -npaths 30 -detail summary -file $f -append
# 2. Las 3 peores con el detalle completo (retardos de reloj y de datos)
report_timing -setup -to_clock [get_clocks $clk_sys] -npaths 3 -detail full_path -file $f -append
# 3. Lecturas de la SDRAM (pines SDRAM_DQ -> registros)
report_timing -setup -from [get_ports {SDRAM_DQ[*]}] -npaths 5 -detail full_path -file $f -append
report_timing -hold  -from [get_ports {SDRAM_DQ[*]}] -npaths 5 -detail summary -file $f -append
# 4. Ordenes y escrituras hacia la SDRAM
report_timing -setup -to [get_ports {SDRAM_*}] -npaths 10 -detail summary -file $f -append
report_timing -hold  -to [get_ports {SDRAM_*}] -npaths 10 -detail summary -file $f -append
# 5. Excepciones aplicadas (para ver si el multiciclo de la lectura ha entrado)
report_exceptions -setup -file $f -append

delete_timing_netlist
project_close
