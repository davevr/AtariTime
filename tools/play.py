#!/usr/bin/env python3
"""Run a game with scripted input and save a screenshot of the result.

    tools/play.py <game> [step ...]         -> build/<game>.png

Each step is  WHAT:FRAMES  (60 frames = 1 second).  WHAT is any of these
joined with '+':

    idle                      nothing held
    up down left right fire   joystick 1
    start select option       console keys
    key=NN                    keyboard key, as an emulator AKEY code
                              (decimal or 0x hex; 0x21 = space, 0x0c = return)

Example: wait 2 seconds, press START, hold right for a second, fire:

    tools/play.py mygame idle:120 start:5 idle:30 right:60 fire:5 idle:30

This exists so the games can be tested without a person at the keyboard.
macOS will not let a script type into the emulator window, so instead the
steps are written out as an Atari800 "-playback" input file, which the
emulator reads one frame at a time in place of the real joystick.
"""

import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

STICK_BITS = {"up": 1, "down": 2, "left": 4, "right": 8}      # 0 = pushed
CONSOLE_BITS = {"start": 1, "select": 2, "option": 4}         # 0 = pressed


def frame_lines(what):
    """The playback lines for one frame with the controls in `what` held."""
    stick, trig, consol, key = 15, 1, 7, -1
    for name in what.split("+"):
        if name == "idle":
            pass
        elif name in STICK_BITS:
            stick &= ~STICK_BITS[name]
        elif name == "fire":
            trig = 0
        elif name in CONSOLE_BITS:
            consol &= ~CONSOLE_BITS[name]
        elif name.startswith("key="):
            key = int(name[4:], 0)
        else:
            sys.exit("unknown control: " + name)
    # The order the emulator reads them in (src/input.c, INPUT_Frame):
    #   key code, shift, console  /  port 0 (sticks 1+2)  /  port 1 (sticks 3+4)
    #   / triggers 1-4 / screen checksum (ignored apart from a log message)
    return [
        "%d 0 %d" % (key, consol),
        "%d" % (0xF0 | stick),
        "255",
        "%d" % trig, "1", "1", "1",
        "00000000",
    ]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    game = sys.argv[1].rstrip("/")
    steps = sys.argv[2:] or ["idle:120"]

    lines = ["Atari800 event recording, version: 1", "0"]   # header, random seed
    frames = 0
    for step in steps:
        what, _, count = step.partition(":")
        count = int(count or 1)
        lines += frame_lines(what) * count
        frames += count

    # When the emulator runs off the end of a playback file it reads one
    # garbage frame with the trigger down.  So the file never ends while we
    # are watching: after the script comes ten seconds of nothing held, and
    # the screenshot is taken at the start of that.
    lines += frame_lines("idle") * 600

    build = os.path.join(ROOT, "build")
    subprocess.run([os.path.join(ROOT, "run.sh"), "-b", game], check=True)
    playback = os.path.join(build, game + ".playback")
    with open(playback, "w") as f:
        f.write("\n".join(lines) + "\n")

    # tools/winid.swift finds the emulator's window.  Compile it once; run
    # as a script it takes a second to start, which spoils the timing.
    finder = os.path.join(build, "winid")
    source = os.path.join(ROOT, "tools", "winid.swift")
    if not os.path.exists(finder) or os.path.getmtime(finder) < os.path.getmtime(source):
        subprocess.run(["swiftc", "-O", "-o", finder, source], check=True)

    emulator = subprocess.Popen(
        [os.path.join(ROOT, "tools", "emulator.sh"), "-nosound",
         "-playback", playback, "-playbacknoexit",
         "-run", os.path.join(build, game + ".xex")],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        # The script starts when the emulator does, and the emulator's window
        # appears at that moment.  So wait for the window, then for as long
        # as the script takes, and the picture is of the script's last step.
        window = ""
        for attempt in range(100):
            window = subprocess.run([finder], capture_output=True, text=True).stdout.strip()
            if window:
                break
            time.sleep(0.1)
        time.sleep(frames / 60.0)
        if not window:
            sys.exit("could not find the emulator window")
        shot = os.path.join(build, game + ".png")
        subprocess.run(["screencapture", "-x", "-o", "-l", window, shot], check=True)
        print(shot)
    finally:
        subprocess.run(["pkill", "-9", "-f", "atari800 -config " + ROOT])


if __name__ == "__main__":
    main()
