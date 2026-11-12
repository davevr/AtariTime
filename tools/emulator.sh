#!/bin/sh
# Start the Atari800 emulator the way this project wants it; extra arguments
# are passed straight through.  Used by run.sh and tools/play.py.
#
# -config atari800.cfg   the project's own settings (a stock NTSC 48K Atari
#                        800), so nothing depends on ~/.atari800.cfg
# -800-rev altirra       the Altirra replacement OS built into the emulator
#
# The three proxy variables are there to stop a download.  When the built-in
# OS is selected, this emulator fetches a set of Atari's original ROM files
# from the internet on every start and saves them next to its config file.
# We don't want those, and there is no switch to turn it off, so the
# download is pointed at a port where nothing is listening.  It fails at
# once ("Downloading ROMs failed" in the log) and the emulator carries on
# with the built-in OS.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

all_proxy=http://127.0.0.1:9 \
https_proxy=http://127.0.0.1:9 \
http_proxy=http://127.0.0.1:9 \
exec atari800 -config "$ROOT/atari800.cfg" -no-autosave-config \
    -atari -800-rev altirra -ntsc -nobasic "$@"
