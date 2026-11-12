#!/usr/bin/env python3
"""Draw the title-screen medfly and write it out as medfly/titlepic.asm.

The picture is a medfly looking straight at the camera.  It is 160 pixels
wide and 52 rows high (ANTIC mode D: each row is two scan lines, so pixels
come out roughly square).  Only the left half is drawn here; the right half
is its mirror image.

What goes where:
    playfield  colour 0   grey: head, legs, outlines
               colour 1   light grey: wing veins, bristles, eye highlights
               colour 2   red for the eyes; a display list interrupt turns
                          it orange lower down for the mouth
    player 0   the thorax, as a block of colour behind the bristles
    player 1   the face, showing through a hole left in the head
    players 2 and 3   the wings, behind their veins
    missiles   the four outer feet (the "fifth player", colour 3)

The players are only 8 fat pixels across, but the playfield is in front of
them, so wherever the playfield draws an edge the picture has a sharp one.

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
# wing: outline and two veins
for i in range(len(WING)):
    (x0, y0), (x1, y1) = WING[i], WING[(i + 1) % len(WING)]
    line(x0, y0, x1, y1, 2)
line(62, 10, 37, 7, 2)
line(62, 12, 45, 13, 2)

# thorax: bristles over where player 0 will be
for x, y0, y1 in [(68, 8, 12), (71, 5, 10), (75, 7, 13), (78, 4, 9)]:
    line(x, y0, x, y1, 2)

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
line(62, 20, 65, 17, 2)
line(62, 21, 63, 20, 2)
line(77, 24, 76, 29, 2)

# mouth: a proboscis with a pad on the end (colour 2 is orange down here)
for y in range(36, 44):
    for x in range(77, 80):
        pic[y][x] = 3
ellipse(CX, 44.5, 5, 2, 3)
line(75, 37, 73, 40, 2)

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


P0X, P1X, P2X, P3X = 64, 72, 32, 96
p0 = player(P0X, 4, lambda x, y: ((x - CX) / 15) ** 2 + ((y - 12) / 9.0) ** 2 <= 1)
p1 = player(P1X, 2, lambda x, y: y <= 36 and ((x - CX) / 8) ** 2 + ((y - 30) / 7.0) ** 2 <= 1)
p2 = player(P2X, 4, lambda x, y: inside(WING, x, y + 0.01))
p3 = player(P3X, 4, lambda x, y: inside(WING, W - 1 - x, y + 0.01))

FEET = [(14, 45), (30, 49), (128, 49), (144, 45)]      # missiles 0-3: x, top row
missiles = [0] * H
for m, (x, y) in enumerate(FEET):
    for row in (y, y + 1):
        missiles[row] |= 3 << (m * 2)

# --- write the include file ---------------------------------------------------
out = []
out.append("; Written by titlepic.py.  Change the picture there, not here.")
out.append("")
out.append("; Where the players and missiles go: 48 is the left edge of the playfield.")
for name, x in (("TP0X", P0X), ("TP1X", P1X), ("TP2X", P2X), ("TP3X", P3X)):
    out.append("%s    = %d" % (name, 48 + x))
out.append("TMISX   dta %s" % ",".join(str(48 + x) for x, _ in FEET))
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
for name, what, rows in (("TP0", "player 0: thorax", p0), ("TP1", "player 1: face", p1),
                         ("TP2", "player 2: left wing", p2), ("TP3", "player 3: right wing", p3),
                         ("TMIS", "missiles: feet", missiles)):
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
