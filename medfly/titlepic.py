#!/usr/bin/env python3
"""Draw the title-screen medfly and write it out as medfly/titlepic.asm.

The picture is a medfly looking straight at the camera.  It is 160 pixels
wide and 52 rows high (ANTIC mode D: each row is two scan lines, so pixels
come out roughly square).  Only the left half is drawn here; the right half
is its mirror image.

What goes where -- eight colours on a black background, when a playfield
on its own has three:
    playfield  colour 0   grey: head, legs, wing veins, outlines
               colour 1   pale blue: the wings
               colour 2   red: the eyes
    missiles   colour 3   white: four bristles on the thorax (the missiles
                          used as a "fifth player")
    player 0   green: the patch on the thorax
    player 1   gold: the face, showing through a hole left in the head
    player 2   orange: the mouth
    player 3   blue-green: the thorax

The players and missiles are only a few fat pixels across, but the
playfield is in front of them, so wherever the playfield draws an edge the
picture has a sharp one.

Run it again after changing anything:   python3 medfly/titlepic.py
"""

import os

W, H = 160, 52
pic = [[0] * W for _ in range(H)]


def plot(x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < W and 0 <= y < H:
        pic[y][x] = c


def ellipse(cx, cy, rx, ry, c):
    for y in range(H):
        for x in range(W):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                pic[y][x] = c


def line(x0, y0, x1, y1, c, thick=1):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(steps + 1):
        t = i / steps
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for dx in range(thick):
            plot(x + dx, y, c)


def inside(poly, x, y):
    n, hit = len(poly), False
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


CX = 79.5                       # the line the picture is mirrored about
WING = [(63, 9), (63, 14), (48, 15), (35, 11), (32, 6), (42, 3), (58, 4)]

# --- left half, back to front ---------------------------------------------
# wing: filled, then its outline and two veins drawn over the top
for y in range(H):
    for x in range(80):
        if inside(WING, x, y + 0.01):
            pic[y][x] = 2
for i in range(len(WING)):
    (x0, y0), (x1, y1) = WING[i], WING[(i + 1) % len(WING)]
    line(x0, y0, x1, y1, 1)
line(62, 10, 37, 7, 1)
line(62, 12, 45, 13, 1)

# legs, hip - knee - foot
for (hx, hy), (kx, ky), (fx, fy) in [
        ((72, 35), (63, 42), (60, 50)),      # front
        ((62, 31), (44, 27), (32, 49)),      # middle
        ((59, 26), (36, 20), (16, 45))]:     # hind
    line(hx, hy, kx, ky, 1, 2)
    line(kx, ky, fx, fy, 1, 2)

# head, with a hole for the face
ellipse(CX, 25, 22, 11, 1)
ellipse(CX, 30, 6, 6, 0)

# eye, its highlight, and an antenna
ellipse(67, 24, 9, 9, 3)
line(62, 20, 65, 17, 1)
line(62, 21, 63, 20, 1)
line(77, 25, 76, 29, 3)

# two palps beside the mouth (the mouth itself is player 2)
line(75, 37, 73, 40, 1)

# --- mirror ---------------------------------------------------------------
for y in range(H):
    for x in range(80):
        pic[y][W - 1 - x] = pic[y][x]


# --- players and missiles ---------------------------------------------------
def player(x0, width, test):
    """8 bits per row, each `width` pixels wide, set where test(x, y)."""
    rows = []
    for y in range(H):
        bits = 0
        for b in range(8):
            if test(x0 + b * width + width / 2.0 - 0.5, y):
                bits |= 0x80 >> b
        rows.append(bits)
    return rows


def mouth(x, y):
    if 36 <= y <= 43:
        return 77 <= x <= 82                                    # proboscis
    return ((x - CX) / 6) ** 2 + ((y - 44.5) / 2.0) ** 2 <= 1   # pad


P0X, P1X, P2X, P3X = 72, 72, 72, 64
p0 = player(P0X, 2, lambda x, y: ((x - CX) / 7) ** 2 + ((y - 7.5) / 2.5) ** 2 <= 1)
p1 = player(P1X, 2, lambda x, y: y <= 35 and ((x - CX) / 8) ** 2 + ((y - 30) / 7.0) ** 2 <= 1)
p2 = player(P2X, 2, mouth)
p3 = player(P3X, 4, lambda x, y: ((x - CX) / 15) ** 2 + ((y - 12) / 9.0) ** 2 <= 1)

# Bristles.  A missile is a stripe 2 pixels wide, which is what a bristle
# is.  Missile m is bits 2m+1 and 2m of the missile byte.
BRISTLES = [(70, 8, 12), (75, 5, 11), (83, 5, 11), (88, 8, 12)]    # x, top, bottom
MISX = [x for x, _, _ in BRISTLES]
missiles = [0] * H
for m, (x, top, bottom) in enumerate(BRISTLES):
    for y in range(top, bottom + 1):
        missiles[y] |= 3 << (m * 2)

# --- write the include file ---------------------------------------------------
out = []
out.append("; Written by titlepic.py.  Change the picture there, not here.")
out.append("")
out.append("; Where the players and missiles go: 48 is the left edge of the playfield.")
for name, x in (("TP0X", P0X), ("TP1X", P1X), ("TP2X", P2X), ("TP3X", P3X)):
    out.append("%s    = %d" % (name, 48 + x))
out.append("TMISX   dta %s" % ",".join(str(48 + x) for x in MISX))
out.append("")
out.append("; The playfield picture: 52 rows of 40 bytes, 4 pixels to a byte.")
out.append("TPIC")
for y in range(H):
    row = []
    for b in range(40):
        v = 0
        for p in range(4):
            v = (v << 2) | pic[y][b * 4 + p]
        row.append("$%02X" % v)
    out.append("        dta " + ",".join(row[:20]) + "    ; row %d" % y)
    out.append("        dta " + ",".join(row[20:]))
for name, what, rows in (("TP0", "player 0: thorax patch", p0), ("TP1", "player 1: face", p1),
                         ("TP2", "player 2: mouth", p2), ("TP3", "player 3: thorax", p3),
                         ("TMIS", "missiles: bristles", missiles)):
    out.append("")
    out.append("; %s, one byte per row" % what)
    out.append(name)
    for y in range(H):
        bits = format(rows[y], "08b")
        out.append("        dta %%%s           ; %s" % (bits, bits.replace("0", ".").replace("1", "X")))

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "titlepic.asm"), "w") as f:
    f.write("\n".join(out) + "\n")

# a quick look at the playfield, for whoever is running this
for y in range(H):
    print("".join(".-+#"[c] for c in pic[y]))
