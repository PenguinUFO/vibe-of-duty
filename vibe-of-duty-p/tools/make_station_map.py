"""Generates prefabs/levels/station_shell.tscn: the shell of the Carousel - a spinning drum of a space station (FFA,
2-4 players). The floor is the inside of its rim: up points at the axis (Gravity, RingGravity in the scene), you run
right round it, and a player across the drum stands upside down over your head. Docs/LEVEL_STATION.md - read it
first; update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_station_map.py
Re-running overwrites the shell, so tune it here, not in the editor. The spawns, the spindle's light, the stars and
the environment are in the hand-edited prefabs/levels/station.tscn, which instances this shell.

Everything is laid out unrolled: s - metres along the floor (round the drum, 0 at the bottom, at the origin), h -
height over the floor (towards the axis), z - across (the end caps at z = +-HALF_W). place() stands a box at (s, h, z)
in the local frame there (x along the floor, y up, z across); long things (arc) are flat pieces, each turned to its
own place on the rim, so the floor is a polygon of FLOOR_SEGS sides.
The drum's axis runs along Z through (0, R, 0); s = R * the angle round it (towards +x at the bottom).
  sectors (SECTORS, one every SECTOR m of s, 0 at the bottom):
  0 dock - containers, a gantry       1 housing A - two blocks, a bridge between their roofs
  2 greenhouse - trees, planters      3 plant (at the top) - tanks, a catwalk, pipe racks
  4 housing B - a block in the middle 5 canteen - a hall across the whole drum
Between the sectors, frames (pillars by the end caps, a beam across at FRAME_H). The end caps are walls up to the
spindle (r SPINDLE), with a ring of windows (WINDOWS) out to space.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "station_shell.tscn")

R = 26.0                  # the floor's distance from the axis (RingGravity.radius in the scene)
HALF_W = 12.0             # the end caps' inner faces: z = +-HALF_W
S = 2.0 * math.pi * R     # round the drum (m of s)
SECTORS = 6
SECTOR = S / SECTORS
FLOOR_SEGS = 72           # 5 degrees each
PIECE = 3.0               # longest flat piece of a wall or a slab along s (m)
FLOOR_T = 0.4
CAP_T = 0.4
SPINDLE = 3.0             # the end caps reach in to the spindle (drawn by the scene, r 2.6)
SPINDLE_R = 1.8           # the collider: an octagon of two squares, its corners (2.55 m) inside the drawn tube (2.6)
WINDOWS = (9.0, 15.0)     # the end caps' windows: h from .. to, every other piece of WINDOW_SEGS. Out of reach: the
# highest vault is 8 m (the container stack, 5.2, + 2.8); a roof by a cap reaches 6.65. Lower, and a sill lets you out.
WINDOW_SEGS = 36
FRAME_H = (8.0, 8.6)      # the frames' beams between the sectors (out of reach: a roof + a vault is 6.65 m)
STOREY = 3.6              # the housing blocks' walls; their roofs on top (ROOF_T), a roof terrace
ROOF_T = 0.25
ROOF = STOREY + ROOF_T
WALL_T = 0.3
DOOR = (1.3, 2.3)         # width, height
WINDOW = (1.6, 0.9, 2.3)  # width, sill, top (no glass: a jump takes you through)
RAIL = 0.8                # low rails, as on every map (the owner): a jump clears them
RAIL_T = 0.08
RAMP_W = 2.2

GREY = (0.6, 0.6, 0.58)          # floors, decks
GREY_D = (0.42, 0.42, 0.41)      # lanes, frames
WALL = (0.72, 0.71, 0.68)        # warm light grey: the housing, the caps
CAP = (0.5, 0.51, 0.53)
STEEL = (0.36, 0.38, 0.41)       # the plant, pipes, the gantry
BLUE = (0.22, 0.32, 0.5)         # the accent: stripes on the caps, containers
AMBER = (0.62, 0.45, 0.22)       # containers, the canteen's counter (dull, not the signal orange)
TEAL = (0.24, 0.42, 0.42)        # containers, tanks
GRASS = (0.3, 0.45, 0.28)
SOIL = (0.38, 0.31, 0.25)
BARK = (0.33, 0.25, 0.18)
LEAF = (0.26, 0.4, 0.25)
WOOD = (0.55, 0.43, 0.3)

L = Level([])  # one deck: every lamp lights everything (there are few)


def mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def world(s, h, z):
    """The world position of (s, h, z)."""
    a = s / R
    r = R - h
    return (r * math.sin(a), R - r * math.cos(a), z)


def put(name, center, rows, size, color):
    L.blocks.append((L.uniq(name), center, rows, size, color, L.layers_at(0.0), False, L.group))


def place(name, s, h, z, size, color, local=None):
    """A box centred at (s, h, z), size in the local frame there (x along the floor, y up, z across), turned by the
    `local` rotation (rows) in that frame."""
    frame = rot_z(s / R)
    put(name, world(s, h, z), frame if local is None else mul(frame, local), size, color)


def arc(name, s0, s1, h0, h1, z0, z1, color, piece=PIECE):
    """A block following the rim from s0 to s1, h0 .. h1 over the floor: flat pieces meeting at their outer (h0)
    side, overlapping a little further in."""
    n = max(1, math.ceil((s1 - s0) / piece - 1e-6))
    ds = (s1 - s0) / n
    length = 2.0 * (R - h0) * math.tan(ds / R / 2.0)
    for i in range(n):
        place(name, s0 + ds * (i + 0.5), (h0 + h1) / 2, (z0 + z1) / 2, (length, h1 - h0, z1 - z0), color)


def box(name, s0, s1, h0, h1, z0, z1, color):
    """A short block (one flat piece), e.g. a crate, a wall across the drum."""
    place(name, (s0 + s1) / 2, (h0 + h1) / 2, (z0 + z1) / 2, (s1 - s0, h1 - h0, z1 - z0), color)


def beam(name, s0, h0, s1, h1, z0, z1, thick, color):
    """A straight slab whose top runs from (s0, h0) to (s1, h1): a ramp along s (its ends exactly on the rim's
    heights there, whatever the curve between)."""
    a, b = world(s0, h0, 0.0), world(s1, h1, 0.0)
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    ang = math.atan2(dy, dx)
    nx, ny = -math.sin(ang), math.cos(ang)  # the slab's up
    c = ((a[0] + b[0]) / 2 - nx * thick / 2, (a[1] + b[1]) / 2 - ny * thick / 2, (z0 + z1) / 2)
    put(name, c, rot_z(ang), (length, thick, z1 - z0), color)


def ramp_s(name, s_low, s_high, h_high, z0, z1, color):
    """Stairs (a ramp) along s from the floor at s_low up to h_high at s_high, with the floor under its high end."""
    beam(name, s_low, 0.0, s_high, h_high, z0, z1, 0.25, color)


def ramp_z(name, s0, s1, z_low, z_high, h_high, color):
    """A ramp across the drum from the floor at z_low up to h_high at z_high."""
    run = z_high - z_low
    length = math.hypot(run, h_high)
    ang = math.atan2(h_high, abs(run))
    tilt = -ang if run > 0 else ang  # about x: negative lifts +z
    thick = 0.25
    place(name, (s0 + s1) / 2, h_high / 2 - thick / 2 / math.cos(ang), (z_low + z_high) / 2, (s1 - s0, thick, length),
          color, rot_x(tilt))


def octagon(name, s, h0, h1, z, size, color):
    """An upright octagonal prism (two squares, one turned 45 degrees), `size` across."""
    for turn in (0.0, math.pi / 4):
        place(name, s, (h0 + h1) / 2, z, (size, h1 - h0, size), color, rot_y(turn))


def lamp(name, s, h, z, energy=1.4, rng=8.0):
    L.lamp(name, world(s, h, z), energy, rng, (0.0, 0.0, 0.0))  # no Mood fixture: it would hang upright (+Y)
    place(name + "Fixture", s, h + 0.12, z, (0.6, 0.06, 0.25), (0.95, 0.9, 0.8))


# --- the drum ----------------------------------------------------------------------------------------------------

def drum():
    seg = S / FLOOR_SEGS
    for i in range(FLOOR_SEGS):
        s0 = -S / 2 + seg * i
        mid = s0 + seg / 2
        sector = round(mid / SECTOR) % SECTORS
        lane = GRASS if sector == 2 else GREY_D
        arc("Floor", s0, s0 + seg, -FLOOR_T, 0.0, -HALF_W - CAP_T, -8.0, GREY, seg)
        arc("Floor", s0, s0 + seg, -FLOOR_T, 0.0, -8.0, 8.0, lane, seg)
        arc("Floor", s0, s0 + seg, -FLOOR_T, 0.0, 8.0, HALF_W + CAP_T, GREY, seg)
    # The end caps: walls from the rim in to the spindle, windows in a ring out of reach.
    seg = S / WINDOW_SEGS
    for side in (-1, 1):
        z0, z1 = (HALF_W, HALF_W + CAP_T) if side > 0 else (-HALF_W - CAP_T, -HALF_W)
        for i in range(WINDOW_SEGS):
            s0 = -S / 2 + seg * i
            arc("Cap", s0, s0 + seg, 0.0, 1.2, z0, z1, CAP, seg)
            arc("CapStripe", s0, s0 + seg, 1.2, 1.5, z0, z1, BLUE, seg)  # a stripe at hand height along both caps
            arc("Cap", s0, s0 + seg, 1.5, WINDOWS[0], z0, z1, CAP, seg)
            if i % 2 == 1:
                arc("Cap", s0, s0 + seg, WINDOWS[0], WINDOWS[1], z0, z1, CAP, seg)
            arc("Cap", s0, s0 + seg, WINDOWS[1], R - SPINDLE, z0, z1, CAP, seg)
    # The spindle's collider (the scene draws it glowing, a little larger).
    for turn in (0.0, math.pi / 4):
        put("Spindle", (0.0, R, 0.0), rot_z(turn), (SPINDLE_R * 2, SPINDLE_R * 2, HALF_W * 2), GREY)
    # Frames between the sectors.
    for k in range(SECTORS):
        s = SECTOR * (k + 0.5)
        for z0, z1 in ((-HALF_W, -HALF_W + 0.8), (HALF_W - 0.8, HALF_W)):
            box("Frame", s - 0.4, s + 0.4, 0.0, FRAME_H[0], z0, z1, GREY_D)
        box("Frame", s - 0.4, s + 0.4, FRAME_H[0], FRAME_H[1], -HALF_W, HALF_W, GREY_D)


# --- pieces ------------------------------------------------------------------------------------------------------

def facade(name, s0, s1, z, pattern, color, h1=STOREY):
    """A wall along s at z (its middle) with openings, one cell per letter: S solid, W window, D door."""
    cell = (s1 - s0) / len(pattern)
    z0, z1 = z - WALL_T / 2, z + WALL_T / 2
    for i, kind in enumerate(pattern):
        a, b = s0 + cell * i, s0 + cell * (i + 1)
        if kind == "S":
            arc(name, a, b, 0.0, h1, z0, z1, color)
            continue
        width = DOOR[0] if kind == "D" else WINDOW[0]
        m0, m1 = (a + b) / 2 - width / 2, (a + b) / 2 + width / 2
        arc(name, a, m0, 0.0, h1, z0, z1, color)
        arc(name, m1, b, 0.0, h1, z0, z1, color)
        top = DOOR[1] if kind == "D" else WINDOW[2]
        arc(name, m0, m1, top, h1, z0, z1, color)
        if kind == "W":
            arc(name, m0, m1, 0.0, WINDOW[1], z0, z1, color)


def cross_wall(name, s, z0, z1, door_z, color, h1=STOREY):
    """A wall across the drum at s from z0 to z1, a door centred at door_z (None: none)."""
    t0, t1 = s - WALL_T / 2, s + WALL_T / 2
    if door_z is None:
        box(name, t0, t1, 0.0, h1, z0, z1, color)
        return
    d0, d1 = door_z - DOOR[0] / 2, door_z + DOOR[0] / 2
    box(name, t0, t1, 0.0, h1, z0, d0, color)
    box(name, t0, t1, 0.0, h1, d1, z1, color)
    box(name, t0, t1, DOOR[1], h1, d0, d1, color)


def rail_s(name, s0, s1, h, z):
    arc(name, s0, s1, h, h + RAIL, z - RAIL_T / 2, z + RAIL_T / 2, GREY_D)


def rail_z(name, s, h, z0, z1):
    box(name, s - RAIL_T / 2, s + RAIL_T / 2, h, h + RAIL, z0, z1, GREY_D)


def block(name, s0, s1, z_street, z_back, pattern, splits, ramp_dir, gaps=()):
    """A housing block from s0 to s1 between z_street (its facade on the street) and z_back (against a cap or
    another street), one storey, rooms split across at `splits` (doors by the facade). Its roof is a terrace (rails
    along the edges, open at `gaps` [(s0, s1)] on the street side: a bridge), up a ramp along s on the street side,
    off its s0 end (ramp_dir -1) or its s1 end (+1)."""
    side = 1 if z_back > z_street else -1
    facade(name + "Wall", s0, s1, z_street, pattern, WALL)
    if abs(z_back) < HALF_W - 0.1:
        facade(name + "Wall", s0, s1, z_back, "S" + "W" * (len(pattern) - 2) + "S", WALL)
    zs = sorted((z_street, z_back))
    for s in (s0, s1):
        cross_wall(name + "Wall", s, zs[0] - WALL_T / 2, zs[1] + WALL_T / 2, None, WALL)
    for s in splits:
        cross_wall(name + "Wall", s, zs[0], zs[1], z_street + side * 1.4, WALL)
    arc(name + "Roof", s0 - WALL_T / 2, s1 + WALL_T / 2, STOREY, ROOF, zs[0] - WALL_T / 2, zs[1] + WALL_T / 2, GREY)
    # Rails round the terrace: along the street edge (a gap where the ramp comes up) and the ends.
    ramp_len = ROOF / math.tan(math.radians(27.0))
    z_ramp = (z_street + side * 0.1, z_street + side * (0.1 + RAMP_W))
    zr = sorted(z_ramp)
    if ramp_dir > 0:
        ramp_s(name + "Ramp", s1 + ramp_len, s1 + WALL_T / 2, ROOF, zr[0], zr[1], GREY)
    else:
        ramp_s(name + "Ramp", s0 - ramp_len, s0 - WALL_T / 2, ROOF, zr[0], zr[1], GREY)
    edge_z = z_street - side * (WALL_T / 2 - RAIL_T / 2)
    cuts = [s0] + [v for g in sorted(gaps) for v in g] + [s1]
    for a, b in zip(cuts[0::2], cuts[1::2]):
        rail_s(name + "Rail", a, b, ROOF, edge_z)
    for s, opens in ((s0, ramp_dir < 0), (s1, ramp_dir > 0)):
        if opens:  # the ramp comes up here: rail only past it
            far = (zr[1], zs[1] + WALL_T / 2) if side > 0 else (zs[0] - WALL_T / 2, zr[0])
            rail_z(name + "Rail", s, ROOF, far[0], far[1])
        else:
            rail_z(name + "Rail", s, ROOF, zs[0], zs[1])
    if abs(z_back) < HALF_W - 0.1:
        rail_s(name + "Rail", s0, s1, ROOF, z_back + side * (WALL_T / 2 - RAIL_T / 2))
    lamp(name + "Lamp", (s0 + s1) / 2, STOREY - 0.2, (z_street + z_back) / 2)


def container(s, z, along_s=True, color=BLUE, h0=0.0):
    sx, sz = (6.0, 2.4) if along_s else (2.4, 6.0)
    box("Container", s - sx / 2, s + sx / 2, h0, h0 + 2.6, z - sz / 2, z + sz / 2, color)


def crate(s, z, size=1.2, h=1.2, h0=0.0, color=WOOD):
    box("Crate", s - size / 2, s + size / 2, h0, h0 + h, z - size / 2, z + size / 2, color)


def barrier(s0, s1, z):
    box("Barrier", s0, s1, 0.0, 0.9, z - 0.3, z + 0.3, GREY_D)


def tree(s, z, big=True):
    trunk = 2.8 if big else 2.3
    box("Trunk", s - 0.2, s + 0.2, 0.0, trunk, z - 0.2, z + 0.2, BARK)
    w = 3.4 if big else 2.4
    box("Crown", s - w / 2, s + w / 2, trunk - 0.3, trunk + 1.6, z - w / 2, z + w / 2, LEAF)
    box("Crown", s - w / 3, s + w / 3, trunk + 1.6, trunk + 2.4, z - w / 3, z + w / 3, LEAF)


def planter(s0, s1, z):
    box("Planter", s0, s1, 0.0, 0.9, z - 0.5, z + 0.5, SOIL)


# --- sectors -----------------------------------------------------------------------------------------------------

def dock(c):
    """0, the bottom: containers (some stacked: a vault takes you up), a gantry across, low barriers."""
    container(c - 9.0, -6.1)                  # a step up onto the stack beside it
    container(c - 9.0, -8.5, color=TEAL)
    container(c - 9.0, -8.5, color=BLUE, h0=2.6)
    container(c - 2.5, 6.5, color=AMBER)
    container(c + 5.5, -4.5, color=TEAL)
    container(c + 9.5, 8.0, color=BLUE)
    container(c + 2.0, -9.6, along_s=False, color=AMBER)
    crate(c - 5.0, 1.5)
    crate(c - 4.0, 2.0, h=0.9)
    crate(c + 1.0, 2.5, size=1.0, h=1.0)
    barrier(c - 12.0, c - 9.5, 2.0)
    barrier(c + 9.5, c + 12.0, -1.0)
    # The gantry: legs by the caps, a beam across over the containers.
    for z in (-10.8, 10.8):
        box("Gantry", c - 0.5, c + 0.5, 0.0, 6.6, z - 0.5, z + 0.5, STEEL)
    box("Gantry", c - 0.6, c + 0.6, 6.6, 7.4, -11.3, 11.3, STEEL)
    box("Hoist", c - 0.7, c + 0.7, 4.8, 6.6, 1.5, 2.9, STEEL)


def housing_a(c):
    """1: two blocks on either side of the street, overlapping in s, a bridge between their roofs."""
    block("BlockA1", c - 12.0, c + 2.0, 4.5, HALF_W, "WDWSDW", [c - 5.0], 1, [(c - 1.0, c + 1.0)])
    block("BlockA2", c - 2.0, c + 12.0, -4.5, -HALF_W, "WDSWDW", [c + 5.0], -1, [(c - 1.0, c + 1.0)])
    # The bridge across the street, from roof to roof (their overlap: s c - 2 .. c + 2).
    arc("Bridge", c - 1.0, c + 1.0, STOREY, ROOF, -4.5, 4.5, GREY)
    rail_z("BridgeRail", c - 1.0, ROOF, -4.4, 4.4)
    rail_z("BridgeRail", c + 1.0, ROOF, -4.4, 4.4)
    crate(c - 7.0, 0.5)
    crate(c + 8.5, 1.5, h=0.9)
    barrier(c + 3.5, c + 6.0, 2.5)


def greenhouse(c):
    """2: grass, trees (the crowns hide you from across the drum), planters, a pavilion."""
    for s, z, big in ((-10.0, -6.0, True), (-6.5, 6.5, True), (-1.5, -2.5, False), (3.0, 8.0, True),
                      (7.5, -6.5, True), (11.0, 3.0, False), (-11.5, 9.5, False), (5.0, 0.5, False)):
        tree(c + s, z, big)
    for s0, s1, z in ((-9.0, -3.0, 2.5), (1.0, 7.0, -2.5), (-4.0, 1.0, -8.5), (8.0, 12.0, 6.5)):
        planter(c + s0, c + s1, z)
    # The pavilion: a roof on four posts over a counter.
    p0, p1, z0, z1 = c - 4.0, c + 1.0, 5.0, 10.0
    for s in (p0, p1):
        for z in (z0, z1):
            box("Post", s - 0.15, s + 0.15, 0.0, 3.0, z - 0.15, z + 0.15, WOOD)
    box("PavilionRoof", p0 - 0.4, p1 + 0.4, 3.0, 3.25, z0 - 0.4, z1 + 0.4, WOOD)
    box("Counter", p0 + 1.0, p1 - 1.0, 0.0, 1.1, 7.0, 7.8, WOOD)


def plant(c):
    """3, at the top: tanks, a catwalk along the middle (a vault up, crates to step on), pipe racks."""
    for s, z in ((-8.0, -7.5), (-8.0, 7.5), (8.0, -7.5), (8.5, 7.0)):
        octagon("Tank", c + s, 0.0, 4.5, z, 3.6, TEAL)
        box("TankBand", c + s - 1.9, c + s + 1.9, 2.0, 2.3, z - 1.9, z + 1.9, STEEL)
    # The catwalk: 2.6 m up (a vault), 1.6 m wide, rails along both sides.
    k0, k1, top = c - 11.0, c + 11.0, 2.6
    arc("Catwalk", k0, k1, top - 0.2, top, -0.8, 0.8, STEEL)
    for s in (k0 + 1.0, c - 3.5, c + 3.5, k1 - 1.0):
        box("CatwalkPost", s - 0.15, s + 0.15, 0.0, top - 0.2, -0.15, 0.15, STEEL)
    rail_s("CatwalkRail", k0 + 2.0, k1 - 2.0, top, 0.76)
    rail_s("CatwalkRail", k0 + 2.0, k1 - 2.0, top, -0.76)
    crate(k0 - 0.8, 0.0, size=1.3, h=1.3)
    crate(k1 + 0.8, 0.0, size=1.3, h=1.3)
    # Pipe racks: a low pipe to hide behind, a high one overhead.
    for z in (-4.0, 4.0):
        arc("Pipe", c - 5.0, c + 5.0, 0.6, 1.1, z - 0.25, z + 0.25, STEEL)
        arc("Pipe", c - 5.0, c + 5.0, 2.9, 3.3, z - 0.2, z + 0.2, STEEL)
        for s in (c - 4.5, c + 4.5):
            box("PipePost", s - 0.12, s + 0.12, 0.0, 3.3, z - 0.12, z + 0.12, STEEL)
    lamp("PlantLamp", c, 5.2, 0.0, 1.6, 9.0)
    box("PlantLampMast", c - 0.1, c + 0.1, top, 5.1, -0.1, 0.1, STEEL)


def housing_b(c):
    """4: a block in the middle of the drum, alleys on both sides, a small block by a cap."""
    block("BlockB1", c - 9.0, c + 5.0, 4.0, -4.0, "WDWDSW", [c - 2.0], 1)
    block("BlockB2", c + 4.0, c + 11.5, -6.5, -HALF_W, "SWDW", [], -1)
    crate(c - 11.0, 8.0)
    crate(c - 10.0, 8.5, h=0.9, size=1.0)
    crate(c + 1.0, 8.5, size=1.4, h=1.4)
    barrier(c - 6.0, c - 3.5, 8.0)
    container(c + 10.0, 7.5, color=AMBER)


def canteen(c):
    """5: a hall across the whole drum, three doorways at each end; tables, a counter, pillars."""
    h0, h1 = c - 10.0, c + 10.0
    top = 4.6
    for s in (h0, h1):
        t0, t1 = s - WALL_T / 2, s + WALL_T / 2
        doors = (-7.5, 0.0, 7.5)
        edges = [-HALF_W] + [v for d in doors for v in (d - 1.5, d + 1.5)] + [HALF_W]
        for a, b in zip(edges[0::2], edges[1::2]):
            box("HallWall", t0, t1, 0.0, top, a, b, WALL)
        for d in doors:
            box("HallWall", t0, t1, 2.6, top, d - 1.5, d + 1.5, WALL)
    arc("HallRoof", h0 - WALL_T / 2, h1 + WALL_T / 2, top, top + 0.3, -HALF_W, HALF_W, GREY)
    for s in (c - 5.0, c + 5.0):
        for z in (-4.0, 4.0):
            box("Pillar", s - 0.35, s + 0.35, 0.0, top, z - 0.35, z + 0.35, GREY_D)
    for s in (c - 7.5, c - 2.5, c + 2.5, c + 7.5):
        for z in (-8.0, 8.0):
            box("Table", s - 1.2, s + 1.2, 0.0, 0.75, z - 0.5, z + 0.5, WOOD)
    box("Counter", c - 4.0, c + 4.0, 0.0, 1.1, -1.0, 1.0, AMBER)
    box("Kitchen", c - 2.0, c + 2.0, 0.0, 2.2, -11.6, -9.8, STEEL)
    lamp("HallLamp", c - 5.0, top - 0.2, 0.0)
    lamp("HallLamp", c + 5.0, top - 0.2, 0.0)


def build():
    drum()
    for k, fill in enumerate((dock, housing_a, greenhouse, plant, housing_b, canteen)):
        fill(SECTOR * k)


build()
L.write(OUT, "StationShell")
