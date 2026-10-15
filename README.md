# Aleste 520EX for MiSTer

[Versión en español](README_es.md)

MiSTer port of the Aleste 520EX core (github.com/shaeon/aleste520ex, for MiST,
Poseidon, SiDi and Calypso). Inspired by hww's Aleste LX.

The core itself lives in the `rtl/aleste520ex` git submodule and is **not
modified** here: this repository only adds the MiSTer glue (`Aleste520EX.sv`),
the PLLs and the Quartus project around the `sys/` framework from
Template_MiSTer. Features, tools and documentation of the machine are in the
[aleste520ex README](https://github.com/shaeon/aleste520ex).

## Installation

- `Aleste520EX_YYYYMMDD.rbf` → `_Computer/` on the SD card.
- `games/Aleste520EX/boot.rom`: the system ROM (`sd/ALESTE.ROM` of the
  aleste520ex repository, renamed). **Without it nothing boots**: the CPU is
  held in reset until the ROM is loaded.
- `games/Aleste520EX/boot2.vhd` (optional): the CMOS with the SETUP settings
  (`sd/ALESTE.HD2`, or the blank `sd/ALESTE.CMO`, renamed). It is mounted at
  start-up and the core writes it back when SETUP changes the settings.
- `games/Aleste520EX/boot0.vhd` (optional): a disk mounted in drive A: at
  start-up (for example `sd/dsk/ALESTDOS_TIME.dsk` renamed, to boot
  MSX-DOS). Other disks (DSK/EDSK, raw MSX-DOS images) are mounted from the
  OSD.

## OSD

| Option | Notes |
|---|---|
| Mount Drive A: / B: | DSK, EDSK and raw MSX-DOS images |
| Load Tape | CDT/TZX (AMSTRAD mode), up to 4 MB |
| CPC boot | Aleste 520EX, AMSTRAD (as with SHIFT held), Aleste BIOS. Applied with *Reset & apply model* |
| CPU speed | 4 / 8 (turbo) / 16 MHz |
| Video | Aspect ratio, Scandoubler Fx (VGA), H/V centre |
| Audio & Tape | Mono / stereo ABC, tape sound, invert tape input, test tone |
| Hardware | Disk speed, one or two drives, CPC mice, AMX mouse on joystick 1, CMOS image |
| Developer | Reload ROM, raw RAM image, bus script (WBS) |

The tape input of the board (ADC: I/O board or the 3.5 mm input of the
analog board) works as a real tape recorder, as `AUDIO_IN` on the
Poseidon/SiDi. The real-time clock is set from the MiSTer clock.

## Differences from the MiST version

- Both videos are shown, chosen by the CPU mode as on MiST: the CPC-mode
  video (15 kHz, real CRTC timing) and the native Aleste LX video (720x480,
  31 kHz: native boot and the test files). MiSTer takes all the video through
  a single `CLK_VIDEO`, so the native video (27 MHz clock) is moved to the
  80 MHz CPC video clock by `rtl/native_resync.sv`, a one-line buffer locked
  to the input lines (a few pixels of delay). Scandoubler and scanlines only
  apply to the CPC video.
- *Scanlines* is replaced by MiSTer's *Scandoubler Fx*; *Aspect ratio* is new.
  The other options keep the same `status` bits as on MiST.
- File downloads are paced with `ioctl_wait` (one byte every `LOAD_GAP` cycles
  of the 54 MHz bus clock, about 1.7 MB/s), because the loader FIFO of the
  core has no full flag and the HPS can send much faster than the MiST SPI.
  If the user LED blinks fast after a load (FIFO overflow), raise `LOAD_GAP`
  in `Aleste520EX.sv`.

## SDRAM

The SDRAM controller (`sdram_wishbone`, 108 MHz, CL2) is inside the core; the
MiSTer glue adds two things so that it works on every MiSTer SDRAM module
(32, 64 and 128 MB):

- `SDRAM_CLK` is `clk_system` inverted (180°) through a DDR output register,
  as on the MiST boards, and `Aleste520EX.sdc` constrains the SDRAM pins with
  the chip timings, so the timing report checks both the commands/writes and
  the read capture. (A separate PLL output with an adjustable phase is
  planned.)
- On some MiSTer modules the DQM pins of the chip are wired to A11/A12 (which
  is why MiSTer cores set `{SDRAM_DQMH, SDRAM_DQML} = SDRAM_A[12:11]`). The core
  keeps the row address on A[12:11] after ACTIVE, so the glue puts the byte
  mask on A[12:11] in every command except ACTIVE and LOAD MODE, where those
  lines are address bits.

## Building

```
git clone --recursive https://github.com/shaeon/Aleste520EX_MiSTer.git
```

(`--recursive` is needed: aleste520ex brings in the aleste-lx submodule.) Open
`Aleste520EX.qpf` with Quartus 17.0 and compile. Before each compilation
`rtl/pre_flow.tcl` copies the palette tables (`*.mem`) from the submodule to
the project folder (Quartus looks for `$readmemh` files there) and then runs
the usual `sys/build_id.tcl`.

Clocks: `rtl/pll` gives 108/54/27 MHz in phase (SDRAM/arbiter, CPU and bus,
native video) and `rtl/pll_vid` gives 80 MHz for the CPC video, asynchronous
to the rest (`Aleste520EX.sdc`).

To update the core: commit and publish the change in aleste520ex first, then
`git -C rtl/aleste520ex pull` (or check out the tag) and commit the new
submodule pointer here. Nothing is ever patched inside `rtl/aleste520ex`.

## Licence

GPL v3, like aleste520ex (the `sys/` framework is GPL v2 or later).
