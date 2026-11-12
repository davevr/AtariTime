#!/bin/sh
# Build one game and run it in the emulator.
#
#   ./run.sh hello          assemble hello/hello.asm -> build/hello.xex, then run it
#   ./run.sh -b hello       build only, don't start the emulator
#
# Each game lives in its own folder, with the main source file named after
# the folder: <game>/<game>.asm.  The listing (build/<game>.lst) and label
# table (build/<game>.lab) are written next to the .xex.

set -e
cd "$(dirname "$0")"

BUILD_ONLY=0
if [ "$1" = "-b" ]; then
    BUILD_ONLY=1
    shift
fi

GAME="${1%/}"
if [ -z "$GAME" ]; then
    echo "usage: ./run.sh [-b] <game>" >&2
    echo "games:" >&2
    for f in */; do
        g="${f%/}"
        [ -f "$g/$g.asm" ] && echo "  $g" >&2
    done
    exit 1
fi

SRC="$GAME/$GAME.asm"
if [ ! -f "$SRC" ]; then
    echo "no such source file: $SRC" >&2
    exit 1
fi

# MADS: use the one on the PATH, else the one built by tools/install-mads.sh
if command -v mads >/dev/null 2>&1; then
    MADS=mads
elif [ -x tools/mads ]; then
    MADS=tools/mads
else
    echo "mads not found.  Run tools/install-mads.sh first." >&2
    exit 1
fi

mkdir -p build
XEX="build/$GAME.xex"

# -i: where to look for icl files    -l: listing    -t: label table
"$MADS" "$SRC" -i:include -i:"$GAME" -o:"$XEX" -l:"build/$GAME.lst" -t:"build/$GAME.lab"

[ "$BUILD_ONLY" = 1 ] && exit 0

# tools/emulator.sh holds the emulator settings: a stock NTSC Atari 800
# with 48K and the built-in Altirra OS (no Atari ROMs needed).
exec tools/emulator.sh -run "$XEX"
