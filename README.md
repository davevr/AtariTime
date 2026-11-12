# AtariTime

Games I wrote in 6502 assembly for my Atari 800 around 1980, rebuilt from
memory. Third in a series with the CARDIAC and Heathkit ET-3400 simulators;
this time the machine already has good emulators, so the work is the games.

Target: a stock Atari 800, 48K, NTSC, one joystick in port 1.

## Build and run

```sh
./run.sh hello
```

assembles `hello/hello.asm` to `build/hello.xex` and starts it in the
emulator. `./run.sh -b hello` only builds. `./run.sh` with no name lists the
games.

In the emulator, joystick 1 is **W A S D** with **left Control** as the
trigger. F2 is OPTION, F3 SELECT, F4 START, F5 RESET, F1 the emulator's own
menu, F9 quits.

## Layout

| | |
|---|---|
| `<game>/<game>.asm` | one folder per game, each building to its own `.xex` |
| `include/atari.inc` | hardware registers and OS names: `COLPF0`, `HPOSP0`, `AUDF1`, `SDLSTL`, `VVBLKD` ... |
| `run.sh` | build one game and run it |
| `atari800.cfg` | the emulator's settings for this project |
| `tools/emulator.sh` | starts the emulator with those settings |
| `tools/play.py` | runs a game with scripted joystick/key input and saves a screenshot |
| `tools/install-mads.sh` | builds the assembler |
| `build/` | output: `.xex`, listing `.lst`, labels `.lab`, screenshots (not in git) |

## Setting up on a new Mac

```sh
brew install atari800 fpc
tools/install-mads.sh
```

- **Atari800** (7.2.1) is the emulator. It has the Altirra replacement OS
  built in, and this project always selects it (`-800-rev altirra`), so no
  Atari ROM files are needed.
- **MADS** (2.1.9) is the assembler. It is not in Homebrew; it is a single
  Pascal source file, which `tools/install-mads.sh` fetches from
  <https://github.com/tebe6502/Mad-Assembler> and compiles with Free Pascal
  into `tools/mads`.

One thing to know about this emulator version: when the built-in OS is
selected it tries, on every start, to download Atari's original ROMs from
the internet into a `rom` folder beside its config file. There is no option
to turn that off, so `tools/emulator.sh` blocks it (see the comment there).
Starting `atari800` by hand, outside these scripts, will do the download.

## Testing without a person at the keyboard

```sh
tools/play.py mygame idle:120 start:5 idle:30 right:60 fire:5 idle:30
```

builds the game, runs it while feeding it that input (60 frames = 1 second),
and saves a screenshot of the window to `build/mygame.png`. Run
`tools/play.py` with no arguments for the list of controls. It can show
that a game draws the right thing and reacts to input; it cannot judge
sound, or how the controls feel.

## How the source is written

The way it was written then: plain labels, comments that explain the
hardware tricks (display lists, player-missile graphics, display list
interrupts, vertical blank routines), and no macros hiding what the 6502 is
doing. MADS is used as a plain assembler: `org`, `icl`, `dta`, `run`.
