"""Finishes the top-down plans of tools/shot_plan.gd for drawing edits on: the floor dimmed, cover as it is, anything
taller than cover brighter and outlined, a metre grid (a line each 5 m, coordinates each 10 m), the spawns (a dot
with the facing and a number, the names in the legend). Long maps are cut into rows of at most ROW_M metres.
Reads ../shots/plan_<map>_<deck>{,_h}.png and .json, writes ../shots/plans/<map>_<deck>.png.
Run: python tools/plan_overlay.py  (after shot_plan.gd)"""
import glob
import json
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SHOTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "shots")
OUT = os.path.join(SHOTS, "plans")
ROW_M = 100.0
MARGIN = 34          # px around the plan for the coordinates
LOW = 0.25           # m over the floor: an obstacle...
HIGH = 1.2           # ...more than cover (a crouching player is 1.1 m)
DROP = 0.5           # m under the floor: a hole, a stair down, the edge
FLOOR_DIM = 0.6      # the floor's brightness
DROP_DIM = 0.3
TALL_LIFT = 1.3      # taller than cover
GRID = (90, 120, 160)
GRID_MAJOR = (120, 160, 210)
TEXT = (210, 220, 235)
SPAWN = (90, 230, 255)


def font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def srgb_to_linear(v):
    c = v / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def shade(full, heights, meta):
    """Floor dimmed, holes darker, cover as it is, taller than cover brighter with a dark outline."""
    base = meta["floor"] - meta["height_span"] / 2
    above = [base + srgb_to_linear(v) * meta["height_span"] - meta["floor"] for v in range(256)]
    level = heights.getchannel("R")
    obstacle = level.point([255 if h > LOW else 0 for h in above])
    tall = level.point([255 if h > HIGH else 0 for h in above])
    drop = level.point([255 if h < -DROP else 0 for h in above])
    dim = full.point(lambda v: int(v * FLOOR_DIM))
    out = Image.composite(full, dim, obstacle)
    out = Image.composite(full.point(lambda v: int(v * DROP_DIM)), out, drop)
    out = Image.composite(full.point(lambda v: min(255, int(v * TALL_LIFT + 12))), out, tall)
    edge = tall.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 0 else 0)
    out.paste((15, 15, 18), mask=edge)
    return out


def finish(base):
    meta = json.load(open(base + ".json", encoding="utf-8"))
    full = Image.open(base + ".png").convert("RGB")
    heights = base + "_h.png"
    plan = shade(full, Image.open(heights).convert("RGB"), meta) \
        if os.path.exists(heights) and meta["deck"] not in ("roof", "top", "outside") else full
    ppm = meta["px_per_m"]
    x0, x1, z0, z1 = meta["area"]
    along_z = meta["along_z"]

    def to_px(x, z):  # world -> plan pixels
        if along_z:   # +z to the right, +x up
            return (z - z0) * ppm, (x1 - x) * ppm
        return (x - x0) * ppm, (z - z0) * ppm   # +x to the right, -z up

    # Horizontal axis: z (long maps) or x; vertical: x or z.
    h_lo, h_hi = (z0, z1) if along_z else (x0, x1)
    v_lo, v_hi = (x0, x1) if along_z else (z0, z1)
    draw = ImageDraw.Draw(plan)
    small = font(13)
    for m in range(int(h_lo // 5 * 5), int(h_hi) + 1, 5):
        if m < h_lo:
            continue
        px = (m - h_lo) * ppm
        draw.line([(px, 0), (px, plan.height)], fill=GRID_MAJOR if m % 10 == 0 else GRID, width=1)
    for m in range(int(v_lo // 5 * 5), int(v_hi) + 1, 5):
        if m < v_lo:
            continue
        py = (v_hi - m) * ppm if along_z else (m - v_lo) * ppm
        draw.line([(0, py), (plan.width, py)], fill=GRID_MAJOR if m % 10 == 0 else GRID, width=1)
    if along_z:  # the side coordinate (x) is repeated along the plan, every 20 m
        for m in range(int(h_lo // 20 * 20), int(h_hi) + 1, 20):
            for v in range(int(v_lo // 5 * 5), int(v_hi) + 1, 5):
                if v_lo <= v <= v_hi and m >= h_lo:
                    draw.text(((m - h_lo) * ppm + 3, (v_hi - v) * ppm + 1), "x%+d" % v, fill=TEXT, font=small)

    # Spawns.
    legend = []
    r = 0.4 * ppm
    for i, s in enumerate(meta["spawns"], 1):
        cx, cy = to_px(s["x"], s["z"])
        fx, fy = to_px(s["x"] + s["fx"] * 1.2, s["z"] + s["fz"] * 1.2)
        draw.line([(cx, cy), (fx, fy)], fill=SPAWN, width=3)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SPAWN, outline=(0, 0, 0))
        draw.text((cx, cy), str(i), fill=(0, 0, 0), font=font(int(r * 1.3)), anchor="mm")
        legend.append("%d %s (x %.1f, z %.1f)" % (i, s["name"].replace("Spawn", ""), s["x"], s["z"]))

    # Rows: a long plan cut into pieces of at most ROW_M, stacked, each with its coordinates above.
    total_m = h_hi - h_lo
    rows = max(1, int(-(-total_m // ROW_M))) if plan.width > 4 * plan.height else 1
    row_m = total_m / rows
    title = font(20)
    head = 34 + 18 * ((len(legend) + 2) // 3)
    row_h = plan.height + MARGIN
    out = Image.new("RGB", (int(row_m * ppm) + 2 * MARGIN, head + rows * row_h + MARGIN // 2), (12, 13, 16))
    od = ImageDraw.Draw(out)
    axes = "z to the right (nose / loco at the left), +x up" if along_z else "x to the right, -z up"
    od.text((MARGIN, 8), "%s - %s   (cut at y %.2f; %s; grid 5 m)" % (meta["map"], meta["deck"], meta["cut"], axes),
            fill=TEXT, font=title)
    for i, line in enumerate(legend):
        od.text((MARGIN + (i % 3) * 330, 36 + 18 * (i // 3)), line, fill=SPAWN, font=font(14))
    for k in range(rows):
        a = int(round(k * row_m * ppm))
        b = int(round((k + 1) * row_m * ppm))
        top = head + k * row_h + MARGIN
        out.paste(plan.crop((a, 0, b, plan.height)), (MARGIN, top))
        for m in range(int(h_lo // 10 * 10), int(h_hi) + 1, 10):
            px = (m - h_lo) * ppm
            if a <= px <= b and m >= h_lo:
                od.text((MARGIN + px - a, top - 4), ("z %d" if along_z else "x %d") % m, fill=TEXT, font=small,
                        anchor="mb")
        if not along_z:
            for m in range(int(v_lo // 10 * 10), int(v_hi) + 1, 10):
                if m >= v_lo:
                    od.text((MARGIN - 4, top + (m - v_lo) * ppm), "z %d" % m, fill=TEXT, font=small, anchor="rm")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "%s_%s.png" % (meta["map"], meta["deck"]))
    out.save(path)
    print(path, out.size)


for json_path in sorted(glob.glob(os.path.join(SHOTS, "plan_*.json"))):
    finish(json_path[:-5])
