"""Heat maps from the battle stats (Docs/STATS.md): where the living were ("pos" lines, every 2.5 s of a match) as heat,
the deaths on top - killed by a player (red), killed by the map (cyan: kill.cause), and the spawns (white rings).
Drawn over the top-down plans of tools/shot_plan.gd (../shots/plan_<map>_<deck>.png and .json); a point goes on every
deck it stands on (feet between that deck's floor and its cut). A map without a plan gets a metre grid (a line each
5 m, coordinates each 10 m) over the area the points cover.
Writes ../shots/heat/<map>_<deck>.png.
Run: python tools/stats_heatmap.py [stats files or folders] [--map=name]  (no paths: this PC's stats folder)"""
import glob
import json
import math
import os
import sys
from collections import defaultdict

from PIL import Image, ImageDraw, ImageFont

from stats_report import load

SHOTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "shots")
OUT = os.path.join(SHOTS, "heat")
PX_PER_M = 30.0      # plans without a plan file: the same scale as shot_plan.gd
CELL_M = 0.5         # heat cell
BLUR_M = 1.5         # heat spread (Gaussian radius)
FEET_BELOW = 0.6     # m under a deck's floor that still counts as on it (stairs, slopes)
HEAD_ROOM = 1.0      # m under the cut: feet higher than cut - this are over the deck, not on it
PLAN_DIM = 0.55      # the plan's brightness under the heat
DEATH = (252, 49, 0)       # Palette "signal"
MAP_DEATH = (90, 230, 255)
SPAWN = (235, 235, 235)
TEXT = (210, 220, 235)
GRID = (60, 70, 90)
GRID_MAJOR = (90, 105, 130)


def font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def heat_colour(v):
    """0..255 -> RGBA: transparent, through dark amber and orange to pale yellow."""
    t = v / 255.0
    stops = [(0.0, (120, 40, 10)), (0.35, (204, 135, 70)), (0.7, (252, 90, 20)), (1.0, (255, 235, 160))]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            rgb = tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
            return rgb + (round(230 * min(t / 0.35, 1.0)),)  # fades out at the edges
    return stops[-1][1] + (230,)


def gather(sessions, only):
    """map -> {pos: [(x, y, z)], deaths: [(x, y, z, by_map)], spawns: [(x, y, z)], files}."""
    maps = defaultdict(lambda: {"pos": [], "deaths": [], "spawns": [], "files": 0})
    for f, events in sessions:
        name = events[0]["map"]
        if only and name != only:
            continue
        m = maps[name]
        m["files"] += 1
        for e in events:
            if e["e"] == "pos":
                m["pos"] += [tuple(p) for p in e["at"].values()]
            elif e["e"] == "kill" and "v_pos" in e:
                m["deaths"].append(tuple(e["v_pos"]) + (e["gun"] == "self",))
            elif e["e"] == "spawn" and "pos" in e:
                m["spawns"].append(tuple(e["pos"]))
    return maps


def plans_of(name):
    """The plans of a map: [meta (+ "png")], or one auto plan over the points when it has none."""
    plans = []
    for path in sorted(glob.glob(os.path.join(SHOTS, f"plan_{name}_*.json"))):
        if path.endswith("_h.json"):
            continue
        with open(path, encoding="utf-8") as fh:
            meta = json.load(fh)
        meta["png"] = path[:-5] + ".png"
        plans.append(meta)
    return plans


def auto_plan(name, points):
    xs = [p[0] for p in points]
    zs = [p[2] for p in points]
    pad = 5.0
    area = [math.floor(min(xs) - pad), math.ceil(max(xs) + pad), math.floor(min(zs) - pad), math.ceil(max(zs) + pad)]
    return {"map": name, "deck": "all", "area": area, "along_z": area[3] - area[2] > 2 * (area[1] - area[0]),
            "px_per_m": PX_PER_M, "floor": -1e9, "cut": 1e9, "spawns": []}


def to_px(meta, x, z):
    a, s = meta["area"], meta["px_per_m"]
    if meta["along_z"]:  # +z to the right, +x up
        return (z - a[2]) * s, (a[1] - x) * s
    return (x - a[0]) * s, (z - a[2]) * s  # +x to the right, -z up


def on_deck(meta, p):
    return meta["floor"] - FEET_BELOW <= p[1] < meta["cut"] - HEAD_ROOM


def base_image(meta):
    a, s = meta["area"], meta["px_per_m"]
    w_m, h_m = (a[3] - a[2], a[1] - a[0]) if meta["along_z"] else (a[1] - a[0], a[3] - a[2])
    size = (round(w_m * s), round(h_m * s))
    if "png" in meta and os.path.exists(meta["png"]):
        img = Image.open(meta["png"]).convert("RGB").resize(size)
        return Image.eval(img, lambda c: round(c * PLAN_DIM)).convert("RGBA")
    img = Image.new("RGBA", size, (18, 20, 26, 255))
    draw = ImageDraw.Draw(img)
    small = font(12)
    for along in (False, True):  # lines across x, then across z
        lo, hi = (a[0], a[1]) if not along else (a[2], a[3])
        for v in range(math.ceil(lo / 5) * 5, math.floor(hi) + 1, 5):
            p0 = to_px(meta, v, a[2]) if not along else to_px(meta, a[0], v)
            p1 = to_px(meta, v, a[3]) if not along else to_px(meta, a[1], v)
            draw.line([p0, p1], fill=GRID_MAJOR if v % 10 == 0 else GRID, width=1)
            if v % 10 == 0:
                at = (p0[0] + 2, p0[1] + 2) if along else (p1[0] + 2, p1[1] - 16)  # the top edge is the legend's
                draw.text(at, f"{'z' if along else 'x'} {v}", fill=GRID_MAJOR, font=small)
    return img


def blur(grid, w, h, sigma):
    """Separable Gaussian blur of a row-major float grid (in floats: a lone point must not round away to 0)."""
    radius = math.ceil(3 * sigma)
    kernel = [math.exp(-(i * i) / (2 * sigma * sigma)) for i in range(-radius, radius + 1)]
    rows = [0.0] * (w * h)
    for j in range(h):
        for i in range(w):
            v = grid[j * w + i]
            if v:
                for k, weight in enumerate(kernel):
                    x = i + k - radius
                    if 0 <= x < w:
                        rows[j * w + x] += v * weight
    out = [0.0] * (w * h)
    for j in range(h):
        for i in range(w):
            v = rows[j * w + i]
            if v:
                for k, weight in enumerate(kernel):
                    y = j + k - radius
                    if 0 <= y < h:
                        out[y * w + i] += v * weight
    return out


def heat_layer(meta, size, points):
    cell = meta["px_per_m"] * CELL_M
    w, h = max(1, math.ceil(size[0] / cell)), max(1, math.ceil(size[1] / cell))
    counts = [0.0] * (w * h)
    for p in points:
        px, py = to_px(meta, p[0], p[2])
        i, j = int(px / cell), int(py / cell)
        if 0 <= i < w and 0 <= j < h:
            counts[j * w + i] += 1.0
    if not any(counts):
        return None
    density = blur(counts, w, h, BLUR_M / CELL_M)
    peak = max(density)
    grid = Image.new("L", (w, h))
    grid.putdata([round(255 * math.sqrt(v / peak)) for v in density])  # sqrt: the rare spots show too
    grid = grid.resize(size, Image.BICUBIC)
    lut = [heat_colour(v) for v in range(256)]
    return Image.merge("RGBA", [grid.point([c[k] for c in lut]) for k in range(4)])


def draw_one(name, meta, data):
    pos = [p for p in data["pos"] if on_deck(meta, p)]
    deaths = [d for d in data["deaths"] if on_deck(meta, d)]
    spawns = {(round(p[0]), round(p[2])) for p in data["spawns"] if on_deck(meta, p)}
    if not pos and not deaths:
        return None
    img = base_image(meta)
    heat = heat_layer(meta, img.size, pos)
    if heat is not None:
        img = Image.alpha_composite(img, heat)
    draw = ImageDraw.Draw(img)
    r = max(4, round(meta["px_per_m"] * 0.3))
    for x, z in spawns:
        px, py = to_px(meta, x, z)
        draw.ellipse([px - 2 * r, py - 2 * r, px + 2 * r, py + 2 * r], outline=SPAWN, width=2)
    for x, y, z, by_map in deaths:
        px, py = to_px(meta, x, z)
        if by_map:
            draw.rectangle([px - r, py - r, px + r, py + r], fill=MAP_DEATH)
        else:
            draw.line([px - r, py - r, px + r, py + r], fill=DEATH, width=3)
            draw.line([px - r, py + r, px + r, py - r], fill=DEATH, width=3)
    legend = (f"{name} {meta['deck']}: файлов {data['files']}, позиций {len(pos)}, "
              f"смертей {sum(1 for d in deaths if not d[3])} (×), от карты {sum(1 for d in deaths if d[3])} (■), "
              f"точек спавна {len(spawns)} (○)")
    big = font(16)
    box = draw.textbbox((8, 6), legend, font=big)
    draw.rectangle([box[0] - 4, box[1] - 3, box[2] + 4, box[3] + 3], fill=(0, 0, 0, 170))
    draw.text((8, 6), legend, fill=TEXT, font=big)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{name}_{meta['deck']}.png")
    img.convert("RGB").save(path)
    return path, len(pos), len(deaths)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = next((a[6:] for a in sys.argv if a.startswith("--map=")), "")
    maps = gather(load(args), only)
    if not maps:
        print("No stats files found")
        return
    for name, data in sorted(maps.items()):
        points = data["pos"] + [d[:3] for d in data["deaths"]]
        if not points:
            print(f"{name}: no positions (files before 2026-11-02 have no \"pos\" lines and no kill.v_pos before 10-31)")
            continue
        plans = plans_of(name)
        if not plans:
            print(f"{name}: no plan in shots/ - a grid instead (plans: tools/shot_plan.gd)")
            plans = [auto_plan(name, points)]
        for meta in plans:
            done = draw_one(name, meta, data)
            if done:
                print(f"{done[0]}: {done[1]} positions, {done[2]} deaths")


if __name__ == "__main__":
    main()
