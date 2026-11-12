#!/bin/sh
# Build the MADS assembler from source and put the binary in tools/mads.
#
# MADS is not in Homebrew.  It is a single Pascal source file, so this
# fetches that file from the author's repository and compiles it with
# Free Pascal (brew install fpc).

set -e
cd "$(dirname "$0")"
TOOLS="$(pwd)"

command -v fpc >/dev/null 2>&1 || { echo "Free Pascal not found: brew install fpc" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -sSL -o "$TMP/mads.pas" \
    https://raw.githubusercontent.com/tebe6502/Mad-Assembler/master/mads.pas

( cd "$TMP" && fpc -Mdelphi -O3 mads.pas >/dev/null )
cp "$TMP/mads" "$TOOLS/mads"

"$TOOLS/mads" | head -1
