# Se ejecuta antes de cada compilacion (PRE_FLOW_SCRIPT_FILE en el .qsf).
#
# 1. Copia a la carpeta del proyecto las tablas .mem de la paleta: Quartus
#    busca los $readmemh relativos a la carpeta del proyecto, no a la del
#    fuente, y sin ellas la paleta sale a cero (pantalla negra). Son las del
#    submodulo, sin copias en el repositorio: si cambian alli, se recogen
#    solas.
# 2. Sigue con el script normal del marco (sys/build_id.tcl: build_id.v y
#    jtag.cdf).

foreach f [concat [glob -nocomplain rtl/aleste520ex/aleste-lx/src/components/video/palette/*.mem] \
                  [glob -nocomplain rtl/aleste520ex/rtl/*.mem]] {
	file copy -force $f .
	post_message "Copiado [file tail $f]"
}

source sys/build_id.tcl
