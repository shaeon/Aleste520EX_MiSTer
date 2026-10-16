# Aleste 520EX para MiSTer

[English version](README.md)

Port a MiSTer del core del Aleste 520EX (github.com/shaeon/aleste520ex, para
MiST, Poseidon, SiDi y Calypso). Inspirado en el Aleste LX de hww.

El núcleo está en el submódulo de git `rtl/aleste520ex` y aquí **no se
modifica**: este repositorio solo añade el pegamento de MiSTer
(`Aleste520EX.sv`), los PLL y el proyecto de Quartus alrededor del marco `sys/`
de Template_MiSTer. Las características, herramientas y documentación de la
máquina están en el [README de aleste520ex](https://github.com/shaeon/aleste520ex).

## Instalación

- `Aleste520EX_AAMMDD.rbf` → `_Computer/` en la SD.
- `games/Aleste520EX/boot.rom`: la ROM del sistema (`sd/ALESTE.ROM` del
  repositorio aleste520ex, renombrada). **Sin ella no arranca nada**: la CPU
  está en reset hasta que se carga la ROM.
- `games/Aleste520EX/boot2.vhd` (opcional): la CMOS con los ajustes del SETUP
  (`sd/ALESTE.HD2`, o la vacía `sd/ALESTE.CMO`, renombrada). Se monta al
  arrancar y el core la guarda cuando el SETUP cambia los ajustes.
- `games/Aleste520EX/boot0.vhd` (opcional): un disco que se monta en la
  unidad A: al arrancar (por ejemplo `sd/dsk/ALESTDOS_TIME.dsk` renombrado,
  para arrancar MSX-DOS). Los demás discos (DSK/EDSK, imágenes en bruto de
  MSX-DOS) se montan desde el OSD.

## OSD

| Opción | Notas |
|---|---|
| Mount Drive A: / B: | DSK, EDSK e imágenes en bruto de MSX-DOS |
| Load Tape | CDT/TZX (modo AMSTRAD), hasta 4 MB |
| CPC boot | Aleste 520EX, AMSTRAD (como con SHIFT pulsado), Aleste BIOS. Se aplica con *Reset & apply model* |
| CPU speed | 4 / 8 (turbo) / 16 MHz |
| Video | Relación de aspecto, Scandoubler Fx (VGA), centrado H/V |
| Audio & Tape | Mono / estéreo ABC, sonido de la cinta, invertir la entrada de cinta, tono de prueba |
| Hardware | Velocidad del disco, una o dos unidades, ratones de CPC, ratón AMX por el joystick 1, imagen de la CMOS |
| Developer | Recargar la ROM, imagen de RAM en bruto, guion de bus (WBS) |

La entrada de cinta de la placa (ADC: placa de E/S o la entrada de 3,5 mm de
la placa analógica) funciona como un magnetofón real, igual que `AUDIO_IN` en
la Poseidon y la SiDi. El reloj de tiempo real se pone en hora con el de
MiSTer.

## Diferencias con la versión de MiST

- Salen los dos vídeos, elegidos por el modo de la CPU como en MiST: el del
  modo CPC (15 kHz, temporización real del CRTC) y el nativo del Aleste LX
  (720x480 a 31 kHz: arranque nativo y ficheros de prueba). MiSTer recibe
  todo el vídeo por un solo `CLK_VIDEO`, así que el nativo (reloj de 27 MHz)
  pasa al reloj de 80 MHz del vídeo CPC con `rtl/native_resync.sv`, un búfer
  de una línea enganchado a las líneas de entrada (unos pocos píxeles de
  retraso). El doblador y las scanlines solo se aplican al vídeo CPC.
- *Scanlines* se sustituye por el *Scandoubler Fx* de MiSTer; *Aspect ratio*
  es nueva. Las demás opciones conservan los mismos bits de `status` que en
  MiST.
- Las descargas de ficheros van frenadas con `ioctl_wait` (un byte cada
  `LOAD_GAP` ciclos del reloj de bus de 54 MHz, unos 1,7 MB/s), porque la FIFO
  del cargador del núcleo no avisa de que está llena y el HPS puede mandar
  mucho más deprisa que el SPI de MiST. Si el LED de usuario parpadea deprisa
  después de una carga (FIFO desbordada), sube `LOAD_GAP` en `Aleste520EX.sv`.

## SDRAM

El controlador de la SDRAM (`sdram_wishbone`, 108 MHz, CL2) está dentro del
núcleo; el pegamento de MiSTer añade dos cosas para que funcione en todos los
módulos de SDRAM de MiSTer (32, 64 y 128 MB):

- `SDRAM_CLK` sale de una salida propia del PLL (`rtl/pll`, `outclk_3`,
  108 MHz, `phase_shift3` = 3472 ps = 135°) por un registro DDR, en vez del
  `clk_system` invertido de las placas MiST. `Aleste520EX.sdc` restringe los
  pines de la SDRAM con los tiempos del chip, así que el informe de tiempos
  comprueba las órdenes y escrituras y la captura de las lecturas. Para probar
  otro desfase, cambia `phase_shift3` en `rtl/pll/pll_0002.v` (pasos de 231 ps;
  4630 ps = 180° es el de MiST) y mira las holguras de `SDRAM_CLK` en el informe.
- En parte de los módulos de MiSTer las patas DQM del chip van a las líneas
  A11/A12 (por eso los cores de MiSTer ponen `{SDRAM_DQMH, SDRAM_DQML} =
  SDRAM_A[12:11]`). El núcleo deja la fila en A[12:11] después de ACTIVE, así
  que el pegamento pone la máscara de bytes en A[12:11] en todas las órdenes
  menos ACTIVE y LOAD MODE, donde esas líneas son dirección.

## Compilación

```
git clone --recursive https://github.com/shaeon/Aleste520EX_MiSTer.git
```

(Hace falta `--recursive`: aleste520ex trae a su vez el submódulo aleste-lx.)
Abre `Aleste520EX.qpf` con Quartus 17.0 y compila. Antes de cada compilación
`rtl/pre_flow.tcl` copia las tablas de la paleta (`*.mem`) del submódulo a la
carpeta del proyecto (Quartus busca ahí los ficheros de `$readmemh`) y luego
ejecuta el `sys/build_id.tcl` de siempre.

Relojes: `rtl/pll` da 108/54/27 MHz en fase (SDRAM y árbitro, CPU y bus, vídeo
nativo) y el reloj de la SDRAM y `rtl/pll_vid` da 80 MHz para el vídeo CPC, asíncrono con el resto
(`Aleste520EX.sdc`).

GitHub Actions (`.github/workflows/build.yml`) compila el core en cada `push`
con Quartus 17.0 (imagen Docker `raetro/quartus:17.0`) y guarda el `.rbf`, los
informes y el detalle de tiempos de la SDRAM (`tools/rutas_sdram.tcl`) como
resultado descargable en la pestaña *Actions*. Al subir una etiqueta `v*` crea
además una Release de GitHub con el `.rbf`.

Para actualizar el núcleo: primero se cambia y se publica en aleste520ex,
luego `git -C rtl/aleste520ex pull` (o se saca la etiqueta) y aquí se hace
commit del nuevo puntero del submódulo. Nunca se parchea nada dentro de
`rtl/aleste520ex`.

## Licencia

GPL v3, como aleste520ex (el marco `sys/` es GPL v2 o posterior).
