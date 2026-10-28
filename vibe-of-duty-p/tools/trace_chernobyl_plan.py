"""Traces the owner's plan of the Chernobyl map (Docs/chernobyl_plan.webp) into tools/chernobyl_plan.json: the buildings,
the walls and fences as rectangles in the plan's pixels. tools/make_chernobyl_map.py builds the shell from it. Read
Docs/LEVEL_CHERNOBYL.md first.

Run from the repo (numpy and Pillow):  python vibe-of-duty-p/tools/trace_chernobyl_plan.py
Re-run only if the plan changes: the generator's constants (heights, scale) are tuned in the generator, not here.

The plan: buildings are filled blue-grey, walls and fences are thin mint lines, the ground is neutral grey.
- Buildings: the blue-grey fill plus its outline, on a 4 px grid (0.64 m), then cut into the fewest big rectangles.
- Walls: the lines away from any building, on a 2 px grid. A wall touching the outside is a boundary wall (tall);
  the rest are low walls (cover).
- Sealing: every gap between the playable ground and the outside (cracks between a building and a wall) is plugged -
  next to a building it becomes building, elsewhere boundary wall - so nobody walks off the map.
- The statue's basin in the middle and the car by the north-east building are left out: the generator and the scene
  make them by hand.
"""
import json
import os
from collections import deque

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PLAN = os.path.join(HERE, "..", "..", "Docs", "chernobyl_plan.webp")
OUT = os.path.join(HERE, "chernobyl_plan.json")
CENTRE_PX = (215, 240)        # a cell of the middle yard (2 px cells): the playable ground is what it reaches
BASIN_PX = (430, 500, 480, 536)   # x0, x1, y0, y1 (plan px): the statue's basin, by hand
CAR_PX = (640, 672, 370, 410)     # the car north-east of building 2: a prop in the scene


def dilate(m, it=1):
    for _ in range(it):
        o = m.copy()
        o[1:] |= m[:-1]
        o[:-1] |= m[1:]
        o[:, 1:] |= m[:, :-1]
        o[:, :-1] |= m[:, 1:]
        m = o
    return m


def erode(m, it=1):
    return ~dilate(~m, it)


def label(m):
    h, w = m.shape
    lab = np.zeros((h, w), int)
    n = 0
    for y, x in zip(*np.nonzero(m)):
        if lab[y, x]:
            continue
        n += 1
        lab[y, x] = n
        q = deque([(y, x)])
        while q:
            cy, cx = q.popleft()
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    q.append((ny, nx))
    return lab, n


def fill_holes(m):
    lab, n = label(~m)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    out = m.copy()
    for i in range(1, n + 1):
        if i not in border:
            out[lab == i] = True
    return out


def rectangles(m):
    """Cuts a mask into rectangles, the biggest first (largest rectangle in a histogram, row by row)."""
    m = m.copy()
    h, w = m.shape
    out = []
    while m.any():
        best, rect = 0, None
        hist = np.zeros(w, int)
        for y in range(h):
            hist = np.where(m[y], hist + 1, 0)
            stack = []
            for x in range(w + 1):
                cur = hist[x] if x < w else 0
                start = x
                while stack and stack[-1][1] >= cur:
                    s, hh = stack.pop()
                    if hh * (x - s) > best:
                        best, rect = hh * (x - s), (s, x, y - hh + 1, y + 1)
                    start = s
                stack.append((start, cur))
        x0, x1, y0, y1 = rect
        out.append(rect)
        m[y0:y1, x0:x1] = False
    return out


def cut(m, px0, px1, py0, py1, cell):
    m[py0 // cell:py1 // cell, px0 // cell:px1 // cell] = False


def main():
    im = np.asarray(Image.open(PLAN).convert("RGB")).astype(int)[::2, ::2]   # 2 px cells
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    line = (g > 140) & (g - r > 12)
    fill = (~line) & (b - r >= 9) & (g + b < 300)
    fill = dilate(erode(fill, 1), 1)       # specks in the fill (the plan's roof texture) out
    near = dilate(fill, 3)
    free_line = line & ~near               # the outline of a building is the building
    building = fill_holes(erode(dilate(fill | (line & near), 1), 1))
    lab, _ = label(~(building | free_line))
    ground = lab == lab[CENTRE_PX[1], CENTRE_PX[0]]
    outside = lab == lab[0, 0]
    h, w = ground.shape

    # Buildings on 4 px cells; the courtyards they enclose (no way in) are building too - not the slivers between a
    # line and a building, nor the basin.
    bx0, bx1, by0, by1 = (v // 2 for v in BASIN_PX)
    for i in set(np.unique(lab)) - {0, lab[0, 0], lab[CENTRE_PX[1], CENTRE_PX[0]]}:
        ys, xs = np.nonzero(lab == i)
        inside_basin = bx0 <= xs.mean() < bx1 and by0 <= ys.mean() < by1
        if len(ys) >= 100 and not inside_basin:
            building |= lab == i
    b4 = building[:h // 2 * 2, :w // 2 * 2].reshape(h // 2, 2, w // 2, 2).sum(axis=(1, 3)) >= 2
    b2 = np.repeat(np.repeat(b4, 2, 0), 2, 1)

    lines = free_line & ~b2
    cut(lines, *BASIN_PX, 2)
    cut(lines, *CAR_PX, 2)
    holes = fill_holes(lines) & ~lines     # small closed outlines (kiosks) are solid
    hl, hn = label(holes)
    for i in range(1, hn + 1):
        if (hl == i).sum() < 60:
            lines |= hl == i
    edge = dilate(outside, 5)
    tall = np.zeros_like(lines)
    low = np.zeros_like(lines)
    ll, ln = label(lines)
    for i in range(1, ln + 1):
        m = ll == i
        (tall if (m & edge).any() else low)[m] = True

    plug = dilate(ground | low, 1) & ~(ground | low) & ~b2 & ~tall
    cut(plug, *BASIN_PX, 2)
    cut(plug, *CAR_PX, 2)
    by_building = plug & dilate(b2, 2)
    tall |= plug & ~by_building
    b4 |= by_building.reshape(h // 2, 2, w // 2, 2).any(axis=(1, 3))
    cut(b4, *CAR_PX, 4)
    b2 = np.repeat(np.repeat(b4, 2, 0), 2, 1)
    low &= ~b2

    sealed, _ = label(~(b2 | tall))
    border = set(np.unique(np.concatenate([sealed[0], sealed[-1], sealed[:, 0], sealed[:, -1]])))
    assert sealed[CENTRE_PX[1], CENTRE_PX[0]] not in border, "the ground leaks out of the map"

    px = lambda rects, cell: [[int(v * cell) for v in rect] for rect in rects]
    data = {"buildings": [], "tall": [], "low": []}
    bl, bn = label(b4)
    for i in range(1, bn + 1):
        if (bl == i).sum() >= 4:
            data["buildings"].append(px(rectangles(bl == i), 4))
    for name, mask in (("tall", tall), ("low", low)):
        ml, mn = label(mask)
        for i in range(1, mn + 1):
            data[name] += px([rc for rc in rectangles(ml == i) if (rc[1] - rc[0]) * (rc[3] - rc[2]) >= 2], 2)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write('{"buildings": [\n%s\n],\n' % ",\n".join("  " + json.dumps(c) for c in data["buildings"]))
        f.write('"tall": %s,\n"low": %s}\n' % (json.dumps(data["tall"]), json.dumps(data["low"])))
    print("wrote %s: %d buildings (%d rects), %d tall, %d low" % (OUT, len(data["buildings"]),
          sum(len(c) for c in data["buildings"]), len(data["tall"]), len(data["low"])))


if __name__ == "__main__":
    main()
