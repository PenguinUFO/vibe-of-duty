"""Generates prefabs/levels/chernobyl_shell.tscn: the shell of the Chernobyl map - a block of Soviet panel houses round
a yard with a statue, a grey winter day (FFA, 2-4 players), laid out from the owner's plan (Docs/chernobyl_plan.webp,
traced by tools/trace_chernobyl_plan.py into tools/chernobyl_plan.json). Read Docs/LEVEL_CHERNOBYL.md first; update
it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_chernobyl_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Spawns, cover props, the statue (PigStatue),
the environment, the sun - the hand-edited prefabs/levels/chernobyl.tscn, which instances this shell.

The plan at PLAN_SCALE m per pixel, its pixel ORIGIN_PX (the statue) at the origin; north (the plan's top) is -z.
- Houses: the traced rectangles, as tall as their house's storeys (HOUSES) - far over the mantle, nobody gets on a
  roof. Their faces get windows and floor seams (one MultiMesh each: thousands of panes, one draw call, no bodies).
- Houses 1 and 2 of the owner's plan (the long ones either side of the yard) are open (OPEN): the ground floor and the
  first floor up - rooms either side of a corridor, a stairwell at each end, doors and windows to the yard, a door in
  the ends that face a street; a balcony to each upper room on the yard face (BALCONY_*), the higher ones decoration.
  Their street faces are the map's edge: blank inside, panes outside.
  A barricade across each ground-floor corridor (BARRICADES), walls broken through (BREACHES).
- Walls: the plan's lines. On the edge of the map tall concrete fences (TALL_H) - nobody climbs out; inside, low
  brick walls (LOW_H) - cover to vault.
- A crawl hole under the fence south of house 2 (CRAWL_HOLES): crouched only.
- The yard: four snowy lawns, a basin round the pedestal (the statue stands on it - the scene's PigStatue), lanterns,
  firs, benches.
- Round the map: more panel houses, a Ferris wheel - scenery, out of reach.
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "chernobyl_shell.tscn")
PLAN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chernobyl_plan.json")

PLAN_SCALE = 0.16          # m per plan pixel: the yard ~18 x 21 m, a street ~5 m, the map ~92 x 144 m
ORIGIN_PX = (461, 507)     # the statue
STOREY = 3.0
ROOF_EXTRA = 0.6           # the roof's parapet over the top storey
# Houses by the plan's pixels (x0, x1, y0, y1) and storeys; a traced rectangle belongs to the first that holds its
# middle. "1" and "2" are the owner's (the long houses either side of the yard).
HOUSES = [
    ("1", (295, 380, 384, 620), 5),
    ("2", (540, 625, 384, 630), 5),
    ("NorthWest", (285, 510, 80, 282), 9),
    ("NorthEast", (575, 805, 95, 390), 9),
    ("NorthEastSmall", (560, 672, 240, 350), 5),
    ("North", (425, 545, 270, 430), 6),
    ("WestSmall", (285, 392, 282, 384), 4),
    ("South", (380, 500, 585, 745), 4),
    ("SouthWestSmall", (250, 360, 660, 770), 4),
    ("SouthEast", (410, 640, 730, 940), 9),
    ("SouthWest", (222, 385, 810, 985), 7),
]
TALL_H = 4.5               # the fences on the map's edge: over the mantle (2.8 m)
LOW_H = 1.0                # the low walls inside: cover, vaulted
WIN = (1.3, 1.5)           # a window pane (w, h), its sill SILL over the floor of its storey
SILL = 0.9
WIN_PITCH = 3.2            # m between windows along a face
SEAM_H = 0.14              # the floor seams between the storeys' panels
BALCONY_DEPTH = 1.3
BALCONY_RAIL = 1.0
BALCONY_BAY = 6.0          # partitions between the flats' balconies
# Houses 1 and 2 are open (the owner): their ground floor and the floor over it, OPEN_STOREYS - rooms, corridors,
# stairwells; solid over them. By name: the footprint (plan px), the yard's side (+1: east of the house), the ends with
# a street door (0: north, 1: south), the yard-side bays that are entrance halls, and the traced rectangles round the
# footprint kept solid (on the street face, and where they close the map off). Their other small rectangles (the
# plan's ragged outline) are dropped; walls of the plan inside a footprint too.
OPEN = {
    "1": ((304, 376, 392, 612), 1, (1,), (1,),
          [(308, 368, 388, 392), (312, 316, 384, 388), (300, 304, 416, 432), (300, 304, 396, 404),
           (300, 304, 500, 508), (300, 304, 604, 608)]),
    "2": ((548, 620, 392, 620), -1, (0, 1), (2,),
          [(620, 624, 408, 412), (580, 584, 624, 628), (576, 616, 620, 624)]),
}
OPEN_STOREYS = 2
SLAB = 0.25                # between the floors: the ground floor 2.75 m clear
OUTER_T = 0.3
INNER_T = 0.16             # partitions: over the head to the ceiling, nothing to stand on
CORRIDOR = 1.8
ROOMS = 4                  # a side, between the stairwells
STAIRWELL = 4.0            # m along the house at each end
FLIGHT_W = 1.4             # the flight along the end wall
FLIGHT_RUN = 4.6           # 3 m up over it: 33 degrees
RAIL_H = 1.3               # level_gen.RAIL
DOOR_W = 1.1
DOOR_H = 2.3
ENTRANCE = 1.8             # a hall's door to the yard
END_DOOR = (1.0, 2.6)      # the ends' street doors, u (by the yard face: the flight takes the street side)
WINDOW_W = 1.4
WINDOW_Y = (0.6, 2.5)      # the ground floor's: sill, top - the sill is climbed (the mantle), as on the killhouse
ROOM_LAMP = (0.9, 6.0)     # energy, range
# Barricades across the ground floor's corridor (the owner): by house, v of the pile's north face (just south of a
# street room's door, so the room is entered from the north half). Furniture to the ceiling's reach: nobody gets by -
# over the top there is less than a crouch (1.1 m) to the ceiling; bullets that pierce cover go through (penetrable).
BARRICADES = {"1": 23.4, "2": 13.7}
# Breaches in the open houses' inner walls (the owner cut them out of the shell in the editor; a regeneration wiped
# them, they were read back off his top-down shot): walls broken through, walked through standing. By house:
# (floor 0/1, wall, from, to) - wall ("cross", i, "yard"/"street"): the wall across the house at cuts[i] on that side
# of the corridor, from .. to in u; ("corridor", "yard"/"street"): the corridor's wall on that side, from .. to in v.
BREACHES = {
    "1": [(0, ("cross", 0, "street"), 9.3, 10.8), (0, ("cross", 1, "yard"), 1.0, 2.2),
          (0, ("cross", 2, "street"), 7.8, 10.3), (0, ("cross", 3, "yard"), 1.3, 3.7),
          (0, ("cross", 3, "street"), 7.3, 10.7), (0, ("cross", 4, "street"), 7.7, 10.5),
          (1, ("corridor", "yard"), 19.9, 21.8), (1, ("corridor", "street"), 15.0, 20.4),
          (1, ("cross", 0, "street"), 9.0, 10.9), (1, ("cross", 1, "street"), 7.1, 10.9),
          (1, ("cross", 2, "yard"), 0.8, 3.8), (1, ("cross", 2, "street"), 6.8, 8.7),
          (1, ("cross", 4, "street"), 8.3, 10.8)],
    "2": [(0, ("cross", 0, "yard"), 1.4, 3.4), (0, ("cross", 1, "yard"), 1.4, 4.4),
          (0, ("cross", 1, "street"), 8.3, 9.7), (0, ("cross", 2, "yard"), 0.7, 2.5),
          (0, ("cross", 2, "street"), 8.0, 10.3), (0, ("cross", 3, "yard"), 3.1, 4.4),
          (0, ("cross", 4, "street"), 7.3, 9.0),
          (1, ("corridor", "yard"), 8.4, 10.0), (1, ("corridor", "yard"), 20.6, 30.1),
          (1, ("corridor", "street"), 21.5, 23.0), (1, ("corridor", "street"), 24.1, 26.6),
          (1, ("corridor", "street"), 27.7, 29.1),
          (1, ("cross", 0, "street"), 8.0, 10.2), (1, ("cross", 1, "street"), 8.0, 10.2),
          (1, ("cross", 3, "yard"), 2.1, 4.7), (1, ("cross", 3, "street"), 6.8, 8.1)],
}
BREACH_MIN = 1.5           # m: a narrower one is widened round its middle (to the wall's ends at most)
BREACH_EDGE = 0.22         # the broken edges: a stub at the floor, a chunk hanging from the top - the middle is clear
RUBBLE = (0.42, 0.4, 0.37)
# Crawl holes under the fences (the owner): (x, z) on a fence's line; CRAWL_W wide, CRAWL_H high - crouched only.
CRAWL_HOLES = [(14.9, 21.6)]
CRAWL_W = 1.3
CRAWL_H = 1.25             # a crouch is 1.1 m
BASIN_PX = (447, 481, 488, 522)   # the ring round the pedestal
BASIN_H = 0.7
BASIN_T = 0.4
PEDESTAL = (1.8, 3.2)      # side, height over the plinth: over the mantle from it (the statue stands on top,
                           # the scene's PigStatue at PEDESTAL_TOP)
PEDESTAL_TOP = PEDESTAL[1] + 0.4
YARD_PX = (405, 520, 440, 575)    # the yard inside its low walls

ASPHALT = (0.3, 0.3, 0.29)
SNOW = (0.66, 0.67, 0.67)
PANEL = (0.52, 0.51, 0.49)     # concrete panels
PANEL_DARK = (0.44, 0.43, 0.41)
SEAM = (0.6, 0.59, 0.57)
GLASS = (0.07, 0.075, 0.08)
BRICK = (0.42, 0.36, 0.32)
FENCE = (0.48, 0.47, 0.45)
STONE = (0.38, 0.37, 0.36)
BANNER = (0.36, 0.16, 0.12)    # faded red cloth: rare, muted (Palette: no signal red on the scenery)
EMBLEM = (0.62, 0.5, 0.46)    # pale pig pink, faded
FIR = (0.2, 0.24, 0.23)        # dark blue-green grey: no olive on the scenery
BARK = (0.27, 0.23, 0.2)
SANDBAG = (0.45, 0.41, 0.34)
FIR_BASE = 1.9             # the lowest branches (over the head)
FIR_TIERS = 5
FIR_WIDTH = 2.9            # the lowest tier
STEEL = (0.3, 0.3, 0.3)
PLASTER = (0.5, 0.47, 0.43)    # the rooms' walls: faded whitewash
LINO = (0.36, 0.31, 0.27)      # the ground floor's linoleum
WOOD = (0.38, 0.29, 0.22)      # the barricades' furniture
MATTRESS = (0.4, 0.43, 0.49)    # blue-grey ticking: apart from the whitewash
DIRT = (0.26, 0.23, 0.2)       # dug under the fence

lv = Level([])
box = lv.box
random.seed(11)
crumble = random.Random(5)   # the breaches' own: more of them must not move the sandbags and the firs
windows = []   # (center, normal) - the MultiMesh of panes
seams = []     # (center, normal, length)


def mx(px):
    return (px - ORIGIN_PX[0]) * PLAN_SCALE


def mz(py):
    return (py - ORIGIN_PX[1]) * PLAN_SCALE


def house_of(rect):
    cx, cy = (rect[0] + rect[1]) / 2, (rect[2] + rect[3]) / 2
    for name, (x0, x1, y0, y1), storeys in HOUSES:
        if x0 <= cx < x1 and y0 <= cy < y1:
            return name, storeys
    return "House", 5


def face(a, b, fixed, axis, normal, y0, y1, storeys):
    """Windows and seams on a face from a to b along `axis` ("x": the face runs along x at z = fixed), facing `normal`
    (+1 / -1), exposed from y0 to y1."""
    length = b - a
    if length < 1.5:
        return
    n = max(1, int(length // WIN_PITCH))
    for s in range(storeys):
        floor = s * STOREY
        if floor + SILL < y0 - 0.01 or floor + SILL + WIN[1] > y1 + 0.01:
            continue
        for i in range(n):
            t = a + (i + 0.5) * length / n
            y = floor + SILL + WIN[1] / 2
            windows.append(((t, y, fixed) if axis == "x" else (fixed, y, t), axis, normal))
        if s > 0 and floor >= y0:
            seams.append((((a + b) / 2, floor, fixed) if axis == "x" else (fixed, floor, (a + b) / 2), axis, normal,
                          length))


# --- the houses ---------------------------------------------------------------------------------------------------------

plan = json.load(open(PLAN, encoding="utf-8"))
house_rects = []   # (name, storeys, rect, solid): solid False - an open house's footprint, built by open_house()
for rects in plan["buildings"]:
    for rect in rects:
        name, storeys = house_of(rect)
        if name not in OPEN:
            house_rects.append((name, storeys, rect, True))
for name, (footprint, _, _, _, keep) in OPEN.items():
    storeys = dict((n, s) for n, _, s in HOUSES)[name]
    house_rects.append((name, storeys, footprint, False))
    house_rects += [(name, storeys, rect, True) for rect in keep]
cells = {}   # (cx, cy) on the 4 px grid -> (height, storeys, the storeys from which the face gets panes)
for name, storeys, rect, solid in house_rects:
    h = storeys * STOREY + ROOF_EXTRA
    x0, x1, y0, y1 = rect
    if solid:
        box(name, mx(x0), mx(x1), 0.0, h, mz(y0), mz(y1), PANEL)
    for cx in range(x0 // 4, x1 // 4):
        for cy in range(y0 // 4, y1 // 4):
            cells[(cx, cy)] = (h, storeys, name if not solid else None)
# Faces: a cell's side where the neighbour is lower (or open), merged along rows / columns into runs. An open house's
# yard face and ends have real openings on its open storeys (no panes there); its street face is the map's edge -
# panes on a solid wall, as on the other houses.
for (dx, dy, axis, normal) in ((0, -1, "x", -1), (0, 1, "x", 1), (-1, 0, "z", -1), (1, 0, "z", 1)):
    runs = {}
    for (cx, cy), (h, storeys, open_name) in cells.items():
        other = cells.get((cx + dx, cy + dy), (0.0, 0, None))[0]
        if other < h:
            street = open_name and axis == "z" and normal == -OPEN[open_name][1]
            first = OPEN_STOREYS if open_name and not street else 0
            key = (cy if axis == "x" else cx, other, h, storeys, first)
            runs.setdefault(key, []).append(cx if axis == "x" else cy)
    for (line, other, h, storeys, first), along in runs.items():
        along.sort()
        start = prev = along[0]
        for v in along[1:] + [None]:
            if v is not None and v == prev + 1:
                prev = v
                continue
            low = max(other, first * STOREY)
            if axis == "x":
                fixed = mz((line + (1 if normal > 0 else 0)) * 4)
                face(mx(start * 4), mx((prev + 1) * 4), fixed, "x", normal, low, h, storeys)
            else:
                fixed = mx((line + (1 if normal > 0 else 0)) * 4)
                face(mz(start * 4), mz((prev + 1) * 4), fixed, "z", normal, low, h, storeys)
            if v is not None:
                start = prev = v


def bounds(house):
    rects = [r for n, _, r, _ in house_rects if n == house]
    return min(r[0] for r in rects), max(r[1] for r in rects), min(r[2] for r in rects), max(r[3] for r in rects)


class Frame:
    """An open house's own coordinates: u across from its yard face (0) to its street face (width), v along from its
    north end (0) to its south end (length)."""

    def __init__(self, name):
        (x0, x1, y0, y1), side, _, _, _ = OPEN[name]
        self.side = side   # +1: the yard is east of the house (x grows towards it), -1: west
        self.yard_x = mx(x1) if side > 0 else mx(x0)
        self.z0 = mz(y0)
        self.width = (x1 - x0) * PLAN_SCALE
        self.length = (y1 - y0) * PLAN_SCALE

    def x(self, u):
        return self.yard_x - self.side * u

    def box(self, name, u0, u1, y0, y1, v0, v1, color, penetrable=False):
        xa, xb = sorted((self.x(u0), self.x(u1)))
        box(name, xa, xb, y0, y1, self.z0 + v0, self.z0 + v1, color, penetrable=penetrable)

    def wall_u(self, name, v0, v1, u0, u1, y0, y1, holes, color):
        """A wall across v0 .. v1 (its thickness), running along u from u0 to u1, with holes [(u0, u1, y0, y1)]."""
        for a, b, c, d in pieces(u0, u1, y0, y1, holes):
            self.box(name, a, b, c, d, v0, v1, color)

    def wall_v(self, name, u0, u1, v0, v1, y0, y1, holes, color):
        """A wall across u0 .. u1, running along v from v0 to v1, with holes [(v0, v1, y0, y1)]."""
        for a, b, c, d in pieces(v0, v1, y0, y1, holes):
            self.box(name, u0, u1, c, d, a, b, color)

    def lamp(self, u, y, v):
        lv.lamp("RoomLamp", (self.x(u), y, self.z0 + v), energy=ROOM_LAMP[0], rng=ROOM_LAMP[1], shade=(0.4, 0.05, 0.4))


def pieces(a0, a1, y0, y1, holes):
    """A wall's face from a0 to a1 along, y0 to y1 up, cut round rectangular holes: the solid rectangles left."""
    out = []
    edges = sorted({a0, a1} | {v for h in holes for v in h[:2] if a0 < v < a1})
    for a, b in zip(edges, edges[1:]):   # a strip between the holes' edges: solid but where holes cross it
        y = y0
        for _, _, hy0, hy1 in sorted((h for h in holes if h[0] <= a and h[1] >= b), key=lambda h: h[2]):
            if hy0 > y:
                out.append((a, b, y, hy0))
            y = max(y, hy1)
        if y < y1:
            out.append((a, b, y, y1))
    return out


def open_house(name):
    """Houses 1 and 2 (the owner): the ground floor and the first floor up are open - rooms either side of a corridor,
    a stairwell at each end, doors and windows to the yard, balconies over it from the upper rooms. Over them the
    house is solid, as the others."""
    f = Frame(name)
    _, _, end_doors, halls, _ = OPEN[name]
    w, length = f.width, f.length
    top = OPEN_STOREYS * STOREY - SLAB          # the open part's ceiling
    h = dict((n, s) for n, _, s in HOUSES)[name] * STOREY + ROOF_EXTRA
    f.box(name, 0.0, w, top, h, 0.0, length, PANEL)
    upper = STOREY
    # The corridor: CORRIDOR wide, down the middle; the rooms: ROOMS a side between the stairwells.
    c0 = (w - CORRIDOR) / 2 - INNER_T
    c1 = (w + CORRIDOR) / 2 + INNER_T
    bay = (length - 2 * STAIRWELL) / ROOMS
    cuts = [STAIRWELL + i * bay for i in range(ROOMS + 1)]
    # The stairwells: a flight along each end wall, from the street side up to the yard side (it lands by the
    # corridor), a hole over it in the floor above, a rail along the hole.
    flight = (OUTER_T, OUTER_T + FLIGHT_W)
    s_hi, s_lo = c0 - 0.1, c0 - 0.1 + FLIGHT_RUN
    holes = []
    for end in (0, 1):
        v0, v1 = (flight if end == 0 else (length - flight[1], length - flight[0]))
        ramp_u(f, s_lo, s_hi, 0.0, upper, v0, v1)
        holes.append((s_hi, w - OUTER_T, v0, v1))
        rail_v = v1 if end == 0 else v0
        f.box("StairRail", s_hi, w - OUTER_T, upper, upper + RAIL_H, rail_v - 0.04, rail_v + 0.04, STEEL)
        f.lamp(w / 2, top - 0.45, (STAIRWELL / 2) if end == 0 else length - STAIRWELL / 2)
    # The floors: the ground floor's lino over the asphalt, the slab between the storeys (the stair holes cut).
    f.box("Floor", OUTER_T, w - OUTER_T, 0.0, 0.02, OUTER_T, length - OUTER_T, LINO)
    for u0, u1, v0, v1 in slab_pieces(OUTER_T, w - OUTER_T, OUTER_T, length - OUTER_T, holes):
        f.box("Slab", u0, u1, upper - SLAB, upper, v0, v1, PANEL_DARK)
    # The outer walls. The yard face: windows (the halls - a door) on the ground floor, a door and a window onto
    # each balcony upstairs; the street face is the map's edge - blank; the ends: a door where there is a street.
    yard_holes = []
    for i in range(ROOMS):
        a, b = cuts[i], cuts[i + 1]
        mid = (a + b) / 2
        if i in halls:
            yard_holes.append((mid - ENTRANCE / 2, mid + ENTRANCE / 2, 0.0, DOOR_H))
        else:
            for t in (0.27, 0.73):
                yard_holes.append((a + t * bay - WINDOW_W / 2, a + t * bay + WINDOW_W / 2) + WINDOW_Y)
        yard_holes.append((a + 0.3 * bay - DOOR_W / 2, a + 0.3 * bay + DOOR_W / 2, upper, upper + DOOR_H))
        yard_holes.append((a + 0.68 * bay - WINDOW_W / 2, a + 0.68 * bay + WINDOW_W / 2,
                           upper + WINDOW_Y[0] + 0.3, upper + WINDOW_Y[1]))
    for v in (STAIRWELL / 2, length - STAIRWELL / 2):   # the stairwells' windows, both floors
        yard_holes.append((v - WINDOW_W / 2, v + WINDOW_W / 2) + WINDOW_Y)
        yard_holes.append((v - WINDOW_W / 2, v + WINDOW_W / 2, upper + WINDOW_Y[0] + 0.3, upper + WINDOW_Y[1]))
    f.wall_v("Wall", 0.0, OUTER_T, 0.0, length, 0.0, top, yard_holes, PANEL)
    f.wall_v("Wall", w - OUTER_T, w, 0.0, length, 0.0, top, [], PANEL)
    for end in (0, 1):
        v0, v1 = (0.0, OUTER_T) if end == 0 else (length - OUTER_T, length)
        door = [(END_DOOR[0], END_DOOR[1], 0.0, DOOR_H)] if end in end_doors else []
        f.wall_u("Wall", v0, v1, OUTER_T, w - OUTER_T, 0.0, top, door, PANEL)
    # Inside, both floors: the corridor's walls with a door into every room, the walls between the rooms, the
    # stairwells' walls (the corridor runs into them open).
    for floor in (0.0, upper):
        y0, y1 = floor + (0.02 if floor == 0.0 else 0.0), floor + STOREY - SLAB
        level = 0 if floor == 0.0 else 1
        broken = [(wall, a, b) for fl, wall, a, b in BREACHES.get(name, []) if fl == level]
        for side, (w0, w1) in ((0, (c0, c0 + INNER_T)), (1, (c1 - INNER_T, c1))):
            doors = []
            for wall, a, b in broken:
                if wall == ("corridor", ("yard", "street")[side]):
                    doors += breach(f, "v", (w0 + w1) / 2, a, b, y0, y1, cuts[0], cuts[-1])
            for i in range(ROOMS):
                a, b = cuts[i], cuts[i + 1]
                if side == 0 and floor == 0.0 and i in halls:   # a hall: open to the corridor
                    doors.append((a + 0.6, b - 0.6, y0, y1))
                else:
                    d = a + (0.75 if (i + side) % 2 else 0.25) * bay
                    doors.append((d - DOOR_W / 2, d + DOOR_W / 2, y0, floor + DOOR_H))
            f.wall_v("RoomWall", w0, w1, cuts[0], cuts[-1], y0, y1, doors, PLASTER)
        for v in cuts:
            t0, t1 = (v - INNER_T, v) if v == cuts[0] else ((v, v + INNER_T) if v == cuts[-1] else
                                                             (v - INNER_T / 2, v + INNER_T / 2))
            i = cuts.index(v)
            for side, (a0, a1) in (("yard", (OUTER_T, c0)), ("street", (c1, w - OUTER_T))):
                holes = []
                for wall, a, b in broken:
                    if wall == ("cross", i, side):
                        holes += breach(f, "u", (t0 + t1) / 2, max(a, a0), min(b, a1), y0, y1, a0, a1)
                f.wall_u("RoomWall", t0, t1, a0, a1, y0, y1, holes, PLASTER)
        # Lamps: the corridor, and the street side's rooms (no windows: the street face is blank).
        for i in range(ROOMS):
            mid = (cuts[i] + cuts[i + 1]) / 2
            f.lamp((c1 + w - OUTER_T) / 2, floor + STOREY - SLAB - 0.45, mid)
            if i % 2 == 0:
                f.lamp(w / 2, floor + STOREY - SLAB - 0.45, cuts[i + 1])
    if name in BARRICADES:
        barricade(f, c0 + INNER_T, c1 - INNER_T, BARRICADES[name])
    balconies(f, cuts, dict((n, s) for n, _, s in HOUSES)[name])


def barricade(f, u0, u1, v):
    """Junk piled across the corridor from u0 to u1, its north face at v: a mattress stood up against a wardrobe laid
    down, a chest of drawers and crates on it, boards nailed across. Over 1.9 m: what is left to the ceiling (2.75 m)
    is less than a crouch."""
    w = u1 - u0
    for name, a, b, y0, y1, c, d, color in (
            ("Mattress", 0.02, 0.97, 0.0, 1.95, 0.0, 0.18, MATTRESS),
            ("Wardrobe", 0.0, 1.0, 0.0, 0.85, 0.18, 0.8, WOOD),
            ("Drawers", 0.06, 0.68, 0.85, 1.65, 0.24, 0.74, WOOD),
            ("Crate", 0.7, 0.97, 0.85, 1.4, 0.25, 0.75, WOOD),
            ("Crate", 0.15, 0.45, 1.65, 2.15, 0.3, 0.7, WOOD)):
        f.box(name, u0 + a * w, u0 + b * w, y0, y1, v + c, v + d, color, penetrable=True)   # wood and wadding
    for tilt, y in ((0.35, 0.7), (-0.3, 1.3)):   # boards across the mattress
        lv.rotated("Board", (f.x((u0 + u1) / 2), y, f.z0 + v - 0.03), (w + 0.2, 0.14, 0.04), WOOD, rot_z=tilt)


def breach(f, along, line, a, b, y0, y1, lo=-1e9, hi=1e9):
    """A wall broken through from a to b along `along` ("u" or "v") on the wall's line (its middle, across): the holes
    for its wall - open floor to ceiling in the middle, ragged at the edges (a stub left at the floor, a chunk
    hanging from the top) - and rubble heaped at the edges, out of the way (no step-up: a lump in the gap would stop
    a walker): along the wall, within its length (lo .. hi), none at an edge where the wall meets another (it would
    roll into the corridor or a doorway)."""
    if b - a < BREACH_MIN:
        m = (a + b) / 2
        a, b = max(lo, m - BREACH_MIN / 2), min(hi, m + BREACH_MIN / 2)
    e = BREACH_EDGE
    holes = [(a + e, b - e, y0, y1)]
    for ea, eb in ((a, a + e), (b - e, b)):
        holes.append((ea, eb, y0 + crumble.uniform(0.25, 0.6), y1 - crumble.uniform(0.35, 0.8)))
    for edge, inward in ((a, 1), (b, -1)):   # rubble both sides of the wall, at the edges
        if min(abs(edge - lo), abs(edge - hi)) < 0.3:
            continue
        for face in (-1, 1):
            for _ in range(2):
                size = (crumble.uniform(0.16, 0.34), crumble.uniform(0.08, 0.2), crumble.uniform(0.16, 0.3))
                reach = math.hypot(size[0], size[2]) / 2   # turned any way: never into the clear middle
                t = edge + inward * crumble.uniform(-0.3, e - reach)
                t = min(max(t, lo + reach), hi - reach)
                c = line + face * crumble.uniform(0.08 + reach, 0.12 + reach)
                u, v = (t, c) if along == "u" else (c, t)
                lv.rotated("Rubble", (f.x(u), y0 + size[1] / 2 - 0.02, f.z0 + v), size, RUBBLE,
                           rot_x=crumble.uniform(-0.3, 0.3), rot_y=crumble.uniform(0, math.pi))
    return holes


def ramp_u(f, u_low, u_high, y_low, y_high, v0, v1, thick=0.25):
    """Stairs as a ramp along u, from y_low at u_low up to y_high at u_high (see Level.ramp)."""
    xa, xb = f.x(u_low), f.x(u_high)
    run, rise = xb - xa, y_high - y_low
    length = math.hypot(run, rise)
    angle = math.atan2(rise, abs(run))
    cy = y_low + rise / 2 - thick / 2 / math.cos(angle)
    rot = angle if run > 0 else -angle   # about Z: positive tilts +X upwards
    lv.rotated("Stair", ((xa + xb) / 2, cy, f.z0 + (v0 + v1) / 2), (length, thick, v1 - v0), STEEL, rot_z=rot,
               decks="all")


def slab_pieces(u0, u1, v0, v1, holes):
    """The rectangle u0 .. u1 x v0 .. v1 less the holes [(u0, u1, v0, v1)] (each spanning a band of v), in pieces."""
    out = []
    vs = sorted({v0, v1} | {v for hole in holes for v in hole[2:] if v0 < v < v1})
    for a, b in zip(vs, vs[1:]):
        cut = [hole for hole in holes if hole[2] <= a and hole[3] >= b]
        u = u0
        for hole in sorted(cut):
            if hole[0] > u:
                out.append((u, hole[0], a, b))
            u = max(u, hole[1])
        if u < u1:
            out.append((u, u1, a, b))
    return out


def balconies(f, cuts, storeys):
    """The gallery of balconies on an open house's yard face, a balcony to a room (partitions on the rooms' walls).
    The first floor's are walked onto from the rooms; the higher ones are decoration."""
    for s in range(1, storeys):
        y = s * STOREY
        f.box("Balcony", -BALCONY_DEPTH, 0.0, y - 0.2, y, cuts[0], cuts[-1], PANEL_DARK)
        f.box("BalconyRail", -BALCONY_DEPTH, -BALCONY_DEPTH + 0.12, y, y + BALCONY_RAIL, cuts[0], cuts[-1], PANEL_DARK)
        for v in cuts:
            f.box("BalconyWall", -BALCONY_DEPTH, 0.0, y, y + STOREY - 0.2, v - 0.06, v + 0.06, PANEL_DARK)
        for i in range(len(cuts) - 1):
            if random.random() < 0.4:   # sandbags on the rail of some
                bay = cuts[i + 1] - cuts[i]
                v = cuts[i] + random.uniform(0.3, 0.6) * bay
                f.box("Sandbags", -BALCONY_DEPTH + 0.12, -BALCONY_DEPTH + 0.62, y + BALCONY_RAIL,
                      y + BALCONY_RAIL + 0.45, v - 1.2, v + 1.2, SANDBAG)


for name in OPEN:
    open_house(name)


def banner(x, z, normal, top, width=3.0, height=9.0):
    """A long faded flag down a face that runs along x at z (facing +z or -z: `normal`), a pale pig snout on it - an
    oval of two boxes, one turned 45 degrees, and two nostrils (the AI's emblem: not approved, the owner may change it).
    """
    t = 0.06
    z0, z1 = sorted((z, z + normal * t))
    box("Banner", x - width / 2, x + width / 2, top - height, top, z0, z1, BANNER)
    f = z1 if normal > 0 else z0
    y = top - 2.6
    lv.rotated("Emblem", (x, y, f + normal * 0.02), (1.9, 1.3, 0.04), EMBLEM)
    lv.rotated("Emblem", (x, y, f + normal * 0.02), (1.3, 1.3, 0.04), EMBLEM, rot_z=math.pi / 4)
    for sx in (-0.4, 0.4):
        box("EmblemNostril", x + sx - 0.14, x + sx + 0.14, y - 0.25, y + 0.25, f + normal * 0.03 - 0.02,
            f + normal * 0.03 + 0.02, BANNER)


nb = bounds("NorthWest")
banner(mx(400), mz(nb[3]), 1, 9 * STOREY - 0.5)
sb = bounds("SouthEast")
banner(mx(560), mz(sb[2]), -1, 9 * STOREY - 0.5)
nb = bounds("North")
banner(mx(500), mz(nb[3]), 1, 6 * STOREY - 0.5, height=7.0)

# --- the ground, the walls ---------------------------------------------------------------------------------------------

box("Ground", -160.0, 160.0, -0.3, 0.0, -190.0, 190.0, ASPHALT)


def in_open(rect):
    return any(rect[0] < fx1 and rect[1] > fx0 and rect[2] < fy1 and rect[3] > fy0
               for (fx0, fx1, fy0, fy1), _, _, _, _ in OPEN.values())


for x0, x1, y0, y1 in plan["tall"]:
    xa, xb, za, zb = mx(x0), mx(x1), mz(y0), mz(y1)
    hole = next(((hx, hz) for hx, hz in CRAWL_HOLES if xa <= hx <= xb and za <= hz <= zb), None)
    if hole is None:
        box("Fence", xa, xb, 0.0, TALL_H, za, zb, FENCE)
        continue
    along_x = xb - xa > zb - za
    c = hole[0] if along_x else hole[1]
    for a, b, c0, c1 in pieces(xa if along_x else za, xb if along_x else zb, 0.0, TALL_H,
                               [(c - CRAWL_W / 2, c + CRAWL_W / 2, 0.0, CRAWL_H)]):
        if along_x:
            box("Fence", a, b, c0, c1, za, zb, FENCE)
        else:
            box("Fence", xa, xb, c0, c1, a, b, FENCE)
    # The dug-out ground either side.
    if along_x:
        box("Dug", c - CRAWL_W / 2 - 0.2, c + CRAWL_W / 2 + 0.2, 0.0, 0.015, za - 0.8, zb + 0.8, DIRT)
    else:
        box("Dug", xa - 0.8, xb + 0.8, 0.0, 0.015, c - CRAWL_W / 2 - 0.2, c + CRAWL_W / 2 + 0.2, DIRT)
for x0, x1, y0, y1 in (r for r in plan["low"] if not in_open(r)):
    box("LowWall", mx(x0), mx(x1), 0.0, LOW_H, mz(y0), mz(y1), BRICK)

# --- the yard -------------------------------------------------------------------------------------------------------

yx0, yx1, yz0, yz1 = mx(YARD_PX[0]) + 0.6, mx(YARD_PX[1]) - 0.6, mz(YARD_PX[2]) + 0.6, mz(YARD_PX[3]) - 0.6
path = 1.4   # the paths across the yard, half width
for (a, b) in ((yx0, -path), (path, yx1)):
    for (c, d) in ((yz0, -path), (path, yz1)):
        box("Lawn", a, b, 0.0, 0.03, c, d, SNOW)
bx0, bx1, bz0, bz1 = mx(BASIN_PX[0]), mx(BASIN_PX[1]), mz(BASIN_PX[2]), mz(BASIN_PX[3])
box("Basin", bx0, bx1, 0.0, BASIN_H, bz0, bz0 + BASIN_T, STONE)
box("Basin", bx0, bx1, 0.0, BASIN_H, bz1 - BASIN_T, bz1, STONE)
box("Basin", bx0, bx0 + BASIN_T, 0.0, BASIN_H, bz0 + BASIN_T, bz1 - BASIN_T, STONE)
box("Basin", bx1 - BASIN_T, bx1, 0.0, BASIN_H, bz0 + BASIN_T, bz1 - BASIN_T, STONE)
px, pz = (bx0 + bx1) / 2, (bz0 + bz1) / 2
box("Plinth", px - 1.4, px + 1.4, 0.0, 0.4, pz - 1.4, pz + 1.4, STONE)
box("Pedestal", px - PEDESTAL[0] / 2, px + PEDESTAL[0] / 2, 0.4, PEDESTAL_TOP, pz - PEDESTAL[0] / 2,
    pz + PEDESTAL[0] / 2, STONE)
box("PedestalCap", px - 1.05, px + 1.05, PEDESTAL_TOP - 0.2, PEDESTAL_TOP, pz - 1.05, pz + 1.05, STONE)
# The plan's line off the basin's south-east corner: sandbags.
lv.rotated("Sandbags", (mx(491), 0.35, mz(526)), (3.6, 0.7, 0.6), SANDBAG, rot_y=-math.atan2(10, 20))
for sx in (-1, 1):   # lanterns at the basin's corners, lit warm and dim (a day)
    for sz in (-1, 1):
        x, z = px + sx * 4.2, pz + sz * 4.2
        box("LanternPost", x - 0.07, x + 0.07, 0.0, 3.0, z - 0.07, z + 0.07, STEEL)
        box("Lantern", x - 0.2, x + 0.2, 3.0, 3.5, z - 0.2, z + 0.2, STEEL)
        lv.lamp("Lantern", (x, 3.25, z), energy=0.8, rng=7.0, shade=(0.3, 0.4, 0.3))


def fir(x, z, h=8.0):
    """A low-poly fir: a trunk and FIR_TIERS tiers of boxes, narrowing up, every other one turned 45 degrees; the
    lowest over a standing player's head."""
    box("Trunk", x - 0.16, x + 0.16, 0.0, h * 0.5, z - 0.16, z + 0.16, BARK)
    tier = (h - FIR_BASE) / FIR_TIERS
    for i in range(FIR_TIERS):
        w = FIR_WIDTH * (1.0 - i / FIR_TIERS) + 0.4
        lv.rotated("Fir", (x, FIR_BASE + (i + 0.5) * tier, z), (w, tier * 1.15, w), FIR, rot_y=math.pi / 4 * (i % 2))


for sx in (-1, 1):   # a fir in each lawn, benches along the paths
    for sz in (-1, 1):
        fir(px + sx * 6.0, pz + sz * 6.2, 8.5 + random.uniform(-1.0, 1.0))
        x = px + sx * 2.2
        box("Bench", x - 0.25, x + 0.25, 0.0, 0.45, pz + sz * 7.5 - 0.9, pz + sz * 7.5 + 0.9, BARK)
for fx, fy in ((395, 300), (560, 210), (250, 650), (420, 930)):   # firs in the streets (on open ground)
    fir(mx(fx), mz(fy), 9.0 + random.uniform(-1.5, 1.5))

# --- round the map: more houses, a Ferris wheel ------------------------------------------------------------------------


def backdrop(x, z, w, d, storeys):
    h = storeys * STOREY + ROOF_EXTRA
    box("FarHouse", x - w / 2, x + w / 2, 0.0, h, z - d / 2, z + d / 2, PANEL)
    face(x - w / 2, x + w / 2, z - d / 2, "x", -1, 0.0, h, storeys)
    face(x - w / 2, x + w / 2, z + d / 2, "x", 1, 0.0, h, storeys)
    face(z - d / 2, z + d / 2, x - w / 2, "z", -1, 0.0, h, storeys)
    face(z - d / 2, z + d / 2, x + w / 2, "z", 1, 0.0, h, storeys)


for x, z, w, d, s in ((-62, -40, 14, 60, 12), (-70, 35, 60, 14, 9), (-55, 95, 14, 50, 14), (60, 40, 14, 70, 9),
                      (45, 100, 50, 14, 12), (-15, -110, 60, 14, 9), (70, -110, 14, 40, 16), (-75, -110, 30, 14, 9),
                      (0, 120, 40, 14, 9), (85, -20, 14, 40, 12)):
    backdrop(x, z, w, d, s)

WHEEL = (40.0, 32.0, -140.0)  # centre: north, over the fence of the north yard; it faces the yard
WHEEL_R = 24.0
yaw = math.atan2(WHEEL[0], WHEEL[2])   # its plane square to the line to the yard


def on_wheel(u, v):
    """A point of the wheel's plane (u across, v up from the centre) in the level."""
    return (WHEEL[0] + u * math.cos(yaw), WHEEL[1] + v, WHEEL[2] - u * math.sin(yaw))


for i in range(24):
    a = 2 * math.pi * (i + 0.5) / 24
    seg = 2 * WHEEL_R * math.sin(math.pi / 24) + 0.05
    lv.rotated("WheelRim", on_wheel(WHEEL_R * math.cos(a), WHEEL_R * math.sin(a)), (0.25, seg, 0.25), STEEL,
               rot_z=a, rot_y=yaw)
for i in range(8):
    a = 2 * math.pi * i / 8
    lv.rotated("WheelSpoke", on_wheel(WHEEL_R / 2 * math.cos(a), WHEEL_R / 2 * math.sin(a)), (WHEEL_R, 0.12, 0.12),
               STEEL, rot_z=a, rot_y=yaw)
for i in range(12):
    a = 2 * math.pi * i / 12
    u, v = WHEEL_R * math.cos(a), WHEEL_R * math.sin(a) - 1.2
    lv.rotated("WheelCar", on_wheel(u, v), (1.4, 1.5, 1.4), BRICK, rot_y=yaw)
for s in (-1, 1):   # the legs: an A from the hub to the ground
    lean = math.atan2(WHEEL_R * 0.45, WHEEL[1])
    lv.rotated("WheelLeg", on_wheel(s * WHEEL_R * 0.225, -WHEEL[1] / 2), (0.4, WHEEL[1] / math.cos(lean), 0.4), STEEL,
               rot_z=s * lean, rot_y=yaw)

# --- write: the shell, then the panes and seams as MultiMeshes ---------------------------------------------------------

lv.write(OUT, "ChernobylShell")


def multimesh(rid, mesh_id, items, size_of):
    """[sub_resource] text of a MultiMesh: one instance per item, its transform from size_of(item) -> (basis rows,
    origin)."""
    floats = []
    for item in items:
        rows, origin = size_of(item)
        for r, o in zip(rows, origin):
            floats += [r[0], r[1], r[2], o]
    f = lambda v: "%g" % round(v, 4)
    return ('[sub_resource type="MultiMesh" id="%s"]\ntransform_format = 1\nmesh = SubResource("%s")\n'
            'instance_count = %d\nbuffer = PackedFloat32Array(%s)\n\n' % (rid, mesh_id, len(items), ", ".join(map(f, floats))))


def pane(item):
    (x, y, z), axis, normal = item
    out = 0.03 * normal
    if axis == "x":   # the face runs along x: the pane is WIN[0] along x
        return ((WIN[0], 0, 0), (0, WIN[1], 0), (0, 0, 0.1)), (x, y, z + out)
    return ((0.1, 0, 0), (0, WIN[1], 0), (0, 0, WIN[0])), (x + out, y, z)


def seam(item):
    (x, y, z), axis, normal, length = item
    out = 0.04 * normal
    if axis == "x":
        return ((length, 0, 0), (0, SEAM_H, 0), (0, 0, 0.12)), (x, y, z + out)
    return ((0.12, 0, 0), (0, SEAM_H, 0), (0, 0, length)), (x + out, y, z)


text = open(OUT, encoding="utf-8").read()
subs = ('[sub_resource type="StandardMaterial3D" id="glass_mat"]\nalbedo_color = Color(%g, %g, %g, 1)\nroughness = 0.3\n\n'
        '[sub_resource type="BoxMesh" id="pane_mesh"]\nmaterial = SubResource("glass_mat")\nsize = Vector3(1, 1, 1)\n\n'
        '[sub_resource type="StandardMaterial3D" id="seam_mat"]\nalbedo_color = Color(%g, %g, %g, 1)\nroughness = 1.0\n\n'
        '[sub_resource type="BoxMesh" id="seam_mesh"]\nmaterial = SubResource("seam_mat")\nsize = Vector3(1, 1, 1)\n\n'
        % (GLASS + SEAM))
subs += multimesh("panes", "pane_mesh", windows, pane) + multimesh("seams", "seam_mesh", seams, seam)
head, rest = text.split("[node name=", 1)
nodes = ('\n[node name="Windows" type="MultiMeshInstance3D" parent="."]\nmultimesh = SubResource("panes")\n'
         'cast_shadow = 0\n\n[node name="Seams" type="MultiMeshInstance3D" parent="."]\nmultimesh = SubResource("seams")\n'
         'cast_shadow = 0\n')
open(OUT, "w", encoding="utf-8", newline="\n").write(head + subs + "[node name=" + rest + nodes)
print("%d panes, %d seams" % (len(windows), len(seams)))
