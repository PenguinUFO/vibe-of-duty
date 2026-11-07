"""Generates prefabs/levels/drydock_shell.tscn: the shell of an abandoned northern submarine yard under the aurora. Our
own plan, not a copy of any game's map. Read Docs/LEVEL_DRYDOCK.md first; update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_drydock_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Containers, spawns, the environment, the moon -
the hand-edited prefabs/levels/drydock.tscn, which instances this shell.

North is -z, east +x. Land x -75 .. 45, z -55 .. 55 at y 0; the frozen sea x 45 .. 75 at ICE_Y. The dry dock runs
east through the middle to the lock gate, its floor at DOCK_Y; DockFlood fills and drains it on the server's clock.
The submarine lies in it on keel blocks: two decks inside, four compartments each. CraneBridge drives the group
TorpedoLoad along z across the workshop.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "drydock_shell.tscn")

LAND_X0, LAND_X1, LAND_Z = -75.0, 45.0, 55.0
SEA_X1 = 75.0
ICE_Y = -1.2
ICE_BOTTOM = -2.0
BASE_Y = -7.0             # the land's blocks reach down to here
DOCK_Y = -6.0
DOCK_X0, DOCK_Z = -37.5, 8.75
GATE_X0 = 42.5            # the gate's walkway x GATE_X0 .. LAND_X1
QUAY_X0, QUAY_Z = -42.5, 18.75
RAIL = 0.8                # low rails everywhere (the owner): a jump clears them
RAIL_T = 0.08
DOOR_H = 2.3
SILL = 1.0
WALL_T = 0.3
FENCE_H = 4.5             # over the mantle (2.8 m)

# The submarine: its pressure hull, compartments along x.
SUB_X0, SUB_X1 = -26.5, 29.5
BULKHEADS = (-12.5, 1.5, 15.5)
HULL_Z = 4.5              # outer face of the sides
FLAT_Z = 3.4              # where the chamfers meet the top and the bottom
Y_BOTTOM = -3.5
Y_SIDE0, Y_SIDE1 = -2.6, 1.9
Y_LOWER = -3.0            # floors
Y_UPPER = -0.4
Y_DECK = 2.4              # the outer deck
SLAB = 0.25
SUB_DOOR_W, SUB_DOOR_H = 1.4, 2.1
STAIR_W = 1.6
LOWER_RUN, UPPER_RUN = 4.4, 4.8
SIDE_DOORS = ((-1, -19.0), (1, -5.0), (-1, 8.5), (1, 22.5))   # (north -1 / south +1, x): a gangway to the quay each
BREACHES = ((-1, -19.0), (1, 8.5))                              # holes in the lower deck, a rubble ramp up from the dock
GANGWAY_W = 1.8
BREACH_W = 2.4

SNOW = (0.74, 0.78, 0.83)
SNOW_DIRT = (0.56, 0.59, 0.62)
ICE = (0.5, 0.62, 0.68)
ICE_RIDGE = (0.66, 0.75, 0.8)
CONCRETE = (0.45, 0.45, 0.44)
CONCRETE_D = (0.34, 0.34, 0.34)
BRICK = (0.42, 0.33, 0.29)
PANEL = (0.5, 0.49, 0.46)
HULL = (0.31, 0.32, 0.34)
HULL_LOW = (0.4, 0.27, 0.22)      # the red anti-fouling paint, gone brown
RUST = (0.4, 0.26, 0.19)
STEEL = (0.3, 0.31, 0.32)
TANK = (0.47, 0.46, 0.43)
WOOD = (0.4, 0.29, 0.21)
ROCK = (0.27, 0.29, 0.33)
FIR = (0.13, 0.19, 0.17)
BARK = (0.2, 0.15, 0.12)

lv = Level([-0.55, 3.2])  # the submarine's decks; lamps elsewhere reach everything (decks="all" in box below)
random.seed(11)
in_sub = False


def box(name, x0, x1, y0, y1, z0, z1, color):
    lv.box(name, x0, x1, y0, y1, z0, z1, color, None if in_sub else "all")


def rotated(name, center, size, color, **turn):
    lv.rotated(name, center, size, color, decks=None if in_sub else "all", **turn)


def slab(name, rects, holes, y0, y1, color):
    lv.slab(name, rects, holes, y0, y1, color, None if in_sub else "all")


def ramp_x(name, z0, z1, y_low, y_high, x_low, x_high, color, thick=0.25):
    """Stairs as a ramp along x, like Level.ramp along z."""
    run, rise = x_high - x_low, y_high - y_low
    angle = math.atan2(rise, abs(run))
    cy = y_low + rise / 2 - thick / 2 / math.cos(angle)
    rotated(name, ((x_low + x_high) / 2, cy, (z0 + z1) / 2), (math.hypot(run, rise), thick, z1 - z0), color,
            rot_z=angle if run > 0 else -angle)


def wall(name, axis, at, a0, a1, y0, y1, holes=(), color=CONCRETE, t=WALL_T):
    """A wall along axis ("x": at is its z; "z": at is its x) from a0 to a1, with holes [(a, b, ya, yb)]."""
    cuts = sorted({a0, a1} | {v for h in holes for v in h[:2] if a0 < v < a1})
    for a, b in zip(cuts, cuts[1:]):
        spans = [(y0, y1)]
        for h in holes:
            if h[0] <= a and h[1] >= b:
                spans = [s for sp in spans for s in ((sp[0], min(sp[1], h[2])), (max(sp[0], h[3]), sp[1])) if s[1] > s[0]]
        for ya, yb in spans:
            if axis == "x":
                box(name, a, b, ya, yb, at - t / 2, at + t / 2, color)
            else:
                box(name, at - t / 2, at + t / 2, ya, yb, a, b, color)


def door(c, w=1.6, y=0.0, h=DOOR_H):
    return (c - w / 2, c + w / 2, y, y + h)


def win(c, w=1.8, y=0.0):
    return (c - w / 2, c + w / 2, y + SILL, y + DOOR_H)


def house(name, x0, x1, z0, z1, h, north=(), south=(), west=(), east=(), color=CONCRETE, roof_holes=()):
    """Four walls and a flat roof (the floor is the land's)."""
    wall(name + "Wall", "x", z0, x0, x1, 0.0, h, north, color)
    wall(name + "Wall", "x", z1, x0, x1, 0.0, h, south, color)
    wall(name + "Wall", "z", x0, z0, z1, 0.0, h, west, color)
    wall(name + "Wall", "z", x1, z0, z1, 0.0, h, east, color)
    slab(name + "Roof", [(x0 - 0.3, x1 + 0.3, z0 - 0.3, z1 + 0.3)], roof_holes, h, h + 0.3, CONCRETE_D)


def rail_x(z, y, x0, x1, color=STEEL):
    box("Rail", x0, x1, y, y + RAIL, z - RAIL_T / 2, z + RAIL_T / 2, color)


def rail_z(x, y, z0, z1, color=STEEL):
    box("Rail", x - RAIL_T / 2, x + RAIL_T / 2, y, y + RAIL, z0, z1, color)


def octagon(name, x, z, r, y0, y1, color):
    """An eight-sided column: two squares, one turned 45 degrees."""
    s = 2 * r * math.cos(math.pi / 8)
    rotated(name, (x, (y0 + y1) / 2, z), (s, y1 - y0, s), color)
    rotated(name, (x, (y0 + y1) / 2, z), (s, y1 - y0, s), color, rot_y=math.pi / 4)


def fir(x, z, h):
    box("Trunk", x - 0.2, x + 0.2, 0.0, h * 0.4, z - 0.2, z + 0.2, BARK)
    for i in range(3):
        w = 3.6 * (1.0 - i / 3) + 0.5
        rotated("Fir", (x, h * (0.34 + 0.22 * i), z), (w, h * 0.27, w), FIR, rot_y=math.pi / 4 * (i % 2))


# --- the land ----------------------------------------------------------------------------------------------------------

WORKSHOP = (-37.5, 15.0, -47.5, -18.75)
HQ = (-70.0, -42.5, -47.5, -22.5)
PUMP = (-70.0, -42.5, -15.0, 15.0)
BARRACKS = (-70.0, -42.5, 22.5, 47.5)
STORES = (-37.5, -2.5, 18.75, 47.5)
BOILER = (3.75, 41.0, 18.75, 47.5)
QUAY = (QUAY_X0, LAND_X1, -QUAY_Z, QUAY_Z)
TRENCH_Z = 1.5
TRENCH_X0, TRENCH_FLAT = -57.0, -47.0     # the stair down from the pump house, then the tunnel

slab("Snow", [(LAND_X0, LAND_X1, -LAND_Z, LAND_Z)], [WORKSHOP, HQ, PUMP, BARRACKS, STORES, BOILER, QUAY], BASE_Y, 0.0, SNOW)
slab("Quay", [QUAY], [(DOCK_X0, LAND_X1, -DOCK_Z, DOCK_Z), (QUAY_X0, DOCK_X0, -TRENCH_Z, TRENCH_Z)], BASE_Y, 0.0, CONCRETE)
for rect in (WORKSHOP, HQ, BARRACKS, STORES, BOILER):
    box("Floor", rect[0], rect[1], BASE_Y, 0.0, rect[2], rect[3], CONCRETE_D)
slab("Floor", [PUMP], [(TRENCH_X0, PUMP[1], -TRENCH_Z, TRENCH_Z)], BASE_Y, 0.0, CONCRETE_D)
box("TunnelRoof", QUAY_X0, DOCK_X0, -3.3, 0.0, -TRENCH_Z, TRENCH_Z, CONCRETE)
box("TunnelFloor", TRENCH_X0, DOCK_X0, BASE_Y, DOCK_Y, -TRENCH_Z, TRENCH_Z, CONCRETE_D)
ramp_x("PumpStair", -TRENCH_Z, TRENCH_Z, DOCK_Y, 0.0, TRENCH_FLAT, TRENCH_X0, STEEL)

# --- the dock ----------------------------------------------------------------------------------------------------------

box("DockFloor", DOCK_X0, LAND_X1, BASE_Y, DOCK_Y, -DOCK_Z, DOCK_Z, CONCRETE_D)
box("Gate", GATE_X0, LAND_X1, DOCK_Y, 0.0, -DOCK_Z, DOCK_Z, RUST)
rail_z(GATE_X0 + 0.05, 0.0, -DOCK_Z, DOCK_Z)
rail_z(LAND_X1 - 0.05, 0.0, -DOCK_Z, DOCK_Z)
ramp_x("DockStair", -DOCK_Z, -DOCK_Z + 1.7, DOCK_Y, 0.0, GATE_X0 - 10.5, GATE_X0 - 0.5, STEEL)   # north wall, up east
ramp_x("DockStair", DOCK_Z - 1.7, DOCK_Z, DOCK_Y, 0.0, -24.0, -34.0, STEEL)                     # south wall, up west

# The quay edge's rails, with gaps at the gangways and the stair heads.
for side in (-1, 1):
    z = side * (DOCK_Z + 0.05)
    gaps = sorted([x for s, x in SIDE_DOORS if s == side] + ([GATE_X0 - 1.5] if side < 0 else [-33.5]))
    x = DOCK_X0
    for gap in gaps:
        half = GANGWAY_W / 2 + 0.3 if gap in [d[1] for d in SIDE_DOORS] else 1.5
        if gap - half > x:
            rail_x(z, 0.0, x, gap - half)
        x = gap + half
    if x < GATE_X0:
        rail_x(z, 0.0, x, GATE_X0)

for x in range(-24, 30, 8):   # the keel blocks the submarine lies on: you can run under it between them
    box("Keel", x - 0.9, x + 0.9, DOCK_Y, Y_BOTTOM, -2.2, 2.2, WOOD)

# --- the submarine -----------------------------------------------------------------------------------------------------

in_sub = True
SLOPE_LOW = math.atan2(Y_SIDE0 - Y_BOTTOM, HULL_Z - FLAT_Z)
SLOPE_TOP = math.atan2(Y_DECK - Y_SIDE1, HULL_Z - FLAT_Z)
length = SUB_X1 - SUB_X0
mid_x = (SUB_X0 + SUB_X1) / 2
compartments = [SUB_X0, *BULKHEADS, SUB_X1]

for side in (-1, 1):
    doors = [door(x, SUB_DOOR_W + 0.4, Y_UPPER, SUB_DOOR_H) for s, x in SIDE_DOORS if s == side]
    breaches = [(x - BREACH_W / 2, x + BREACH_W / 2, Y_LOWER, Y_UPPER - SLAB - 0.15) for s, x in BREACHES if s == side]
    wall("HullSide", "x", side * (HULL_Z - 0.15), SUB_X0, SUB_X1, Y_SIDE0, Y_SIDE1, doors + breaches, HULL)
    chamfer = math.hypot(HULL_Z - FLAT_Z, Y_SIDE0 - Y_BOTTOM)
    rotated("HullLow", (mid_x, (Y_SIDE0 + Y_BOTTOM) / 2, side * (HULL_Z + FLAT_Z) / 2), (length, 0.3, chamfer), HULL_LOW,
            rot_x=side * SLOPE_LOW)
    chamfer = math.hypot(HULL_Z - FLAT_Z, Y_DECK - Y_SIDE1)
    rotated("HullHigh", (mid_x, (Y_SIDE1 + Y_DECK) / 2 - 0.1, side * (HULL_Z + FLAT_Z) / 2), (length, 0.3, chamfer), HULL,
            rot_x=-side * SLOPE_TOP)

LOWER_STAIRS = ((SUB_X0 + 1.5, 1.6), (SUB_X1 - 1.5 - LOWER_RUN, -3.2))   # (x, z) of each stair's low west corner
HATCHES = ((-9.5, 0.2), (7.0, -1.8))                                      # the same, upper deck to the outer deck
slab("LowerFloor", [(SUB_X0, SUB_X1, -FLAT_Z - 0.5, FLAT_Z + 0.5)], [], Y_BOTTOM, Y_LOWER, HULL_LOW)
slab("UpperFloor", [(SUB_X0, SUB_X1, -HULL_Z + 0.3, HULL_Z - 0.3)],
     [(x, x + LOWER_RUN, z, z + STAIR_W) for x, z in LOWER_STAIRS], Y_UPPER - SLAB, Y_UPPER, STEEL)
slab("OuterDeck", [(SUB_X0, SUB_X1, -FLAT_Z - 0.2, FLAT_Z + 0.2)],
     [(x, x + UPPER_RUN, z, z + STAIR_W) for x, z in HATCHES], Y_DECK - 0.3, Y_DECK, HULL)
for i, (x, z) in enumerate(LOWER_STAIRS):
    low, high = (x + LOWER_RUN, x) if i == 0 else (x, x + LOWER_RUN)   # both climb towards the nearer end
    ramp_x("SubStair", z, z + STAIR_W, Y_LOWER, Y_UPPER, low, high, STEEL)
for x, z in HATCHES:
    ramp_x("HatchStair", z, z + STAIR_W, Y_UPPER, Y_DECK, x + UPPER_RUN, x, STEEL)

# Bulkheads: doors offset from one to the next, so no line runs the length of a deck.
for i, x in enumerate(BULKHEADS):
    up = 2.2 if i % 2 == 0 else -2.2
    wall("Bulkhead", "z", x, -HULL_Z + 0.3, HULL_Z - 0.3, Y_LOWER, Y_UPPER - SLAB,
         [door(-up, SUB_DOOR_W, Y_LOWER, SUB_DOOR_H)], STEEL, 0.2)
    wall("Bulkhead", "z", x, -HULL_Z + 0.3, HULL_Z - 0.3, Y_UPPER, Y_DECK - 0.3,
         [door(up, SUB_DOOR_W, Y_UPPER, SUB_DOOR_H)], STEEL, 0.2)
for x in (SUB_X0, SUB_X1):
    wall("EndBulkhead", "z", x, -HULL_Z, HULL_Z, Y_BOTTOM, Y_DECK, (), HULL, 0.3)

# What stands in the compartments: lanes 2.5 - 3 m wide round it.
for i in range(4):
    a, b = compartments[i], compartments[i + 1]
    c = (a + b) / 2
    # Lower deck: racks, over the head at the ends of a compartment, low in its middle.
    box("Rack", c - 3.5, c - 1.4, Y_LOWER, Y_LOWER + 1.9, -0.5, 0.5, STEEL)
    box("Rack", c + 1.4, c + 3.5, Y_LOWER, Y_LOWER + 1.9, -0.5, 0.5, STEEL)
    box("Rack", c - 0.8, c + 0.8, Y_LOWER, Y_LOWER + 1.0, -0.5, 0.5, RUST)
    # Upper deck: consoles along the sides, a low bench down the middle.
    side = 1 if i % 2 == 0 else -1   # the wall without this compartment's side door
    box("Console", c - 2.2, c + 2.2, Y_UPPER, Y_UPPER + 1.15, side * 3.9 - 0.45, side * 3.9 + 0.45, PANEL)
    mid = c + (0.0, 4.0, -4.0, 0.0)[i]   # clear of the hatch stairs
    box("Console", mid - 0.7, mid + 0.7, Y_UPPER, Y_UPPER + 1.15, -side * 0.6 - 0.45, -side * 0.6 + 0.45, RUST)
    lv.lamp("SubLamp", (c + 2.5, Y_LOWER + 2.05, 2.8), energy=0.9, rng=7.0, shade=(0.3, 0.05, 0.3))
    lv.lamp("SubLamp", (c - 2.5, Y_UPPER + 2.15, -2.6), energy=0.9, rng=7.0, shade=(0.3, 0.05, 0.3))

in_sub = False

for side, x in SIDE_DOORS:   # gangways from the quay to the upper deck's side doors
    z_hull, z_quay = side * HULL_Z, side * DOCK_Z
    lv.ramp("Gangway", x - GANGWAY_W / 2, x + GANGWAY_W / 2, Y_UPPER, 0.0, z_hull, z_quay, STEEL)
    for sx in (-1, 1):
        rail_z(x + sx * GANGWAY_W / 2, -0.2, min(z_hull, z_quay), max(z_hull, z_quay))
for side, x in BREACHES:     # rubble up from the dock into the lower deck
    lv.ramp("Rubble", x - BREACH_W / 2, x + BREACH_W / 2, DOCK_Y, Y_LOWER, side * (DOCK_Z - 0.3), side * HULL_Z, RUST, 0.6)

# Bow and stern: solid, narrowing in steps. The conning tower, masts, hatches' coamings, tail fins.
for x0, x1, half, y0, y1 in ((SUB_X0 - 2.5, SUB_X0, 3.8, Y_BOTTOM + 0.3, Y_DECK - 0.1),
                             (SUB_X0 - 4.0, SUB_X0 - 2.5, 2.6, Y_BOTTOM + 0.8, Y_DECK - 0.5),
                             (SUB_X0 - 5.0, SUB_X0 - 4.0, 1.2, Y_BOTTOM + 1.5, Y_DECK - 1.2),
                             (SUB_X1, SUB_X1 + 2.0, 3.4, Y_BOTTOM + 0.4, Y_DECK - 0.1),
                             (SUB_X1 + 2.0, SUB_X1 + 4.0, 2.0, Y_BOTTOM + 1.0, Y_DECK - 0.6),
                             (SUB_X1 + 4.0, SUB_X1 + 5.5, 0.9, Y_BOTTOM + 1.7, Y_DECK - 1.4)):
    box("HullEnd", x0, x1, y0, y1, -half, half, HULL)
box("Fin", SUB_X1 + 3.5, SUB_X1 + 5.5, -1.8, -1.4, -4.2, 4.2, HULL)
box("Fin", SUB_X1 + 4.3, SUB_X1 + 4.7, -3.8, 2.6, -0.2, 0.2, HULL)
TOWER = (-2.0, 5.0)
box("Tower", TOWER[0], TOWER[1], Y_DECK, Y_DECK + 3.8, -1.8, 1.8, HULL)
box("TowerTop", TOWER[0] + 0.5, TOWER[1] - 1.5, Y_DECK + 3.8, Y_DECK + 4.5, -1.3, 1.3, HULL)
for x, h in ((0.5, 8.0), (1.5, 9.5), (2.5, 7.4)):
    box("Mast", x - 0.1, x + 0.1, Y_DECK + 4.5, Y_DECK + h, -0.1, 0.1, STEEL)
for x, z in HATCHES:
    box("Coaming", x - 0.15, x, Y_DECK, Y_DECK + 0.3, z - 0.15, z + STAIR_W + 0.15, STEEL)
for x in (-22.0, -17.0, 13.0, 18.0, 23.0):   # low cover along the deck: silo lids, rusted shut
    box("Lid", x - 1.2, x + 1.2, Y_DECK, Y_DECK + 0.95, -1.2 if x % 2 else 0.0, 0.0 if x % 2 else 1.2, RUST)

# --- the workshop: a hall with a gallery, the torpedo goes across it ----------------------------------------------------

x0, x1, z0, z1 = WORKSHOP
HALL_H = 9.0
GALLERY_Y = 4.0
GALLERY_Z = -41.0
house("Workshop", x0, x1, z0, z1, HALL_H, color=BRICK,
      north=[door(-26.0), door(5.0), win(-14.0, 4.0, GALLERY_Y), win(-2.0, 4.0, GALLERY_Y)],
      south=[door(-28.0, 6.0, 0.0, 4.2), door(-1.0, 6.0, 0.0, 4.2), win(-16.0, 4.0, 0.0), win(10.0, 4.0, 0.0)],
      west=[door(-34.0), door(-25.0), win(-44.0, 1.8, GALLERY_Y)],
      east=[door(-34.0), door(-25.0), door(-44.0, 1.6, GALLERY_Y)],
      roof_holes=[(-6.0, 4.0, -34.0, -27.0), (-28.0, -24.0, -30.0, -24.0)])
slab("Gallery", [(x0, x1, z0, GALLERY_Z)], [], GALLERY_Y - 0.25, GALLERY_Y, STEEL)
rail_x(GALLERY_Z, GALLERY_Y, x0, -31.0)
rail_x(GALLERY_Z, GALLERY_Y, -29.0, 3.0)
rail_x(GALLERY_Z, GALLERY_Y, 5.0, x1)
for x in (-30.0, 4.0):   # stairs up to the gallery from the hall, along z
    lv.ramp("GalleryStair", x - 1.0, x + 1.0, 0.0, GALLERY_Y, GALLERY_Z + 6.5, GALLERY_Z, STEEL)
    rail_z(x - 1.0, 2.0, GALLERY_Z, GALLERY_Z + 3.0)
for a, b in ((-37.5, -24.0), (-23.0, -9.0), (-8.0, 15.0)):   # the store rooms under the gallery
    wall("Store", "x", GALLERY_Z, a, b, 0.0, GALLERY_Y - 0.25, [door((a + b) / 2)], BRICK)
wall("Store", "z", -23.5, z0, GALLERY_Z, 0.0, GALLERY_Y - 0.25, [door(-44.0)], BRICK)
wall("Store", "z", -8.5, z0, GALLERY_Z, 0.0, GALLERY_Y - 0.25, [door(-44.0)], BRICK)
for x in (-25.0, -13.0, 3.0):   # the crane's rails on columns down both long walls
    for z in (z0 + 0.5, z1 - 0.5):
        box("Column", x - 0.3, x + 0.3, 0.0, HALL_H, z - 0.3, z + 0.3, STEEL)
for x, z, w, d, h in ((-31.0, -28.0, 5.0, 3.0, 1.2), (-22.0, -33.0, 3.0, 5.0, 1.6), (-24.0, -23.5, 4.0, 2.0, 1.2),
                      (8.0, -30.0, 3.5, 7.0, 1.6), (9.0, -22.5, 4.0, 2.0, 1.2), (11.0, -37.0, 4.0, 3.0, 2.2)):
    box("Lathe", x - w / 2, x + w / 2, 0.0, h, z - d / 2, z + d / 2, RUST)
box("SnowHeap", -5.0, 3.0, 0.0, 0.5, -33.0, -28.0, SNOW)   # under the hole in the roof
lv.lamp("HallLamp", (-26.0, 3.2, -30.0), energy=1.4, rng=11.0, shade=(0.5, 0.05, 0.5))
lv.lamp("HallLamp", (8.0, 3.2, -26.0), energy=1.4, rng=11.0, shade=(0.5, 0.05, 0.5))
lv.lamp("GalleryLamp", (-11.0, GALLERY_Y + 2.4, -44.0), energy=1.0, rng=9.0, shade=(0.4, 0.05, 0.4))

# The moving load, built at its first stop (the north one; CraneBridge moves it along +z by `travel`).
TORPEDO_Z = -38.0
lv.group = "TorpedoLoad"
box("Torpedo", -12.0, -5.0, 0.55, 1.65, TORPEDO_Z - 0.55, TORPEDO_Z + 0.55, HULL)
box("TorpedoNose", -13.2, -12.0, 0.75, 1.45, TORPEDO_Z - 0.35, TORPEDO_Z + 0.35, RUST)
box("TorpedoTail", -5.0, -4.2, 0.85, 1.35, TORPEDO_Z - 0.25, TORPEDO_Z + 0.25, STEEL)
box("TorpedoFin", -5.0, -4.3, 0.55, 1.65, TORPEDO_Z - 0.05, TORPEDO_Z + 0.05, STEEL)
for x in (-11.0, -6.0):
    box("Sling", x - 0.04, x + 0.04, 1.65, 7.0, TORPEDO_Z - 0.04, TORPEDO_Z + 0.04, STEEL)
box("Bridge", x0 + 0.3, x1 - 0.3, 7.0, 7.6, TORPEDO_Z - 0.3, TORPEDO_Z + 0.3, (0.42, 0.36, 0.2))
lv.group = None

# --- the fuel yard ------------------------------------------------------------------------------------------------------

for x, z, r, h in ((26.5, -41.0, 4.6, 7.0), (37.0, -41.0, 4.6, 7.0), (37.0, -29.0, 3.4, 5.0)):
    octagon("Tank", x, z, r, 0.0, h, TANK)
    octagon("TankTop", x, z, r * 0.7, h, h + 0.5, TANK)
box("Pipe", 19.0, 42.0, 2.7, 3.1, -34.2, -33.8, RUST)
for x in (20.0, 26.0, 32.0):
    box("PipeLeg", x - 0.1, x + 0.1, 0.0, 2.7, -34.1, -33.9, STEEL)
box("Bund", 21.0, 31.0, 0.0, 1.05, -24.5, -23.9, CONCRETE)     # low walls round the yard: chest-high cover
box("Bund", 21.0, 21.6, 0.0, 1.05, -32.0, -24.5, CONCRETE)

# --- headquarters: two storeys round a hall ------------------------------------------------------------------------------

STOREY = 3.8
x0, x1, z0, z1 = HQ
house("Hq", x0, x1, z0, z1, 2 * STOREY, color=PANEL,
      north=[door(-56.0), win(-65.0), win(-48.0), win(-65.0, 1.8, STOREY), win(-56.0, 1.8, STOREY), win(-48.0, 1.8, STOREY)],
      south=[door(-62.0), door(-50.0), win(-56.0), win(-62.0, 1.8, STOREY), win(-50.0, 1.8, STOREY)],
      west=[win(-40.0), win(-30.0), win(-40.0, 1.8, STOREY), win(-30.0, 1.8, STOREY)],
      east=[door(-35.0), win(-42.0), win(-28.0), win(-42.0, 1.8, STOREY), win(-28.0, 1.8, STOREY)])
HALL = (-62.0, -50.0, -40.0, -30.0)
slab("HqFloor", [(x0, x1, z0, z1)], [HALL], STOREY - 0.25, STOREY, CONCRETE_D)
rail_x(HALL[2], STOREY, HALL[0] + 2.2, HALL[1])   # the stair comes up at its west end
rail_x(HALL[3], STOREY, HALL[0], HALL[1])
rail_z(HALL[1], STOREY, HALL[2], HALL[3] - 3.0)
lv.ramp("HqStair", HALL[0] + 0.1, HALL[0] + 2.1, 0.0, STOREY, HALL[2] + 7.0, HALL[2], STEEL)
wall("HqRoom", "z", HALL[0], z0, HALL[2], 0.0, STOREY - 0.25, [door(-44.0)], PANEL)
wall("HqRoom", "z", HALL[0], HALL[3], z1, 0.0, STOREY - 0.25, [door(-26.0)], PANEL)
wall("HqRoom", "z", HALL[1], z0, HALL[2], 0.0, STOREY - 0.25, [door(-44.0)], PANEL)
wall("HqRoom", "z", HALL[1], HALL[3], z1, 0.0, STOREY - 0.25, [door(-26.0)], PANEL)
wall("HqRoom", "x", -35.0, x0, HALL[0], STOREY, 2 * STOREY, [door(-65.0, 1.6, STOREY)], PANEL)
wall("HqRoom", "x", -35.0, HALL[1], x1, STOREY, 2 * STOREY, [door(-46.0, 1.6, STOREY)], PANEL)
box("Desk", -58.0, -54.0, 0.0, 1.05, -36.0, -34.5, WOOD)
box("Desk", -68.0, -64.0, 0.0, 1.05, -29.0, -27.5, WOOD)
box("Desk", -48.0, -44.5, STOREY, STOREY + 1.05, -43.0, -41.5, WOOD)
box("Desk", -68.0, -64.0, STOREY, STOREY + 1.05, -30.0, -28.5, WOOD)
lv.lamp("HqLamp", (-56.0, STOREY + 3.0, -35.0), energy=1.2, rng=10.0, shade=(0.4, 0.05, 0.4))

# --- the pump house: the stair down to the dock --------------------------------------------------------------------------

x0, x1, z0, z1 = PUMP
house("Pump", x0, x1, z0, z1, 6.0, color=BRICK,
      north=[door(-62.0), door(-48.0)], south=[door(-62.0), door(-48.0)], west=[door(-8.0), door(8.0)],
      east=[door(-9.0, 2.2), door(9.0, 2.2), win(-4.5, 2.0), win(4.5, 2.0)])
for side in (-1, 1):
    rail_x(side * TRENCH_Z, 0.0, TRENCH_X0, x1)
    box("Pump", -66.0, -60.0, 0.0, 2.3, side * 6.0 - 1.5, side * 6.0 + 1.5, RUST)
    box("PumpMotor", -60.0, -56.0, 0.0, 1.2, side * 6.0 - 0.9, side * 6.0 + 0.9, STEEL)
    box("PumpPipe", -56.0, x1 - 0.2, 0.3, 1.0, side * 6.0 - 0.35, side * 6.0 + 0.35, RUST)
box("Tank", -67.5, -63.0, 0.0, 1.8, -2.0, 2.0, TANK)
lv.lamp("PumpLamp", (-50.0, 4.2, 0.0), energy=1.4, rng=10.0, shade=(0.5, 0.05, 0.5))
lv.lamp("TunnelLamp", (-42.0, -3.8, 0.0), energy=1.0, rng=7.0, shade=(0.3, 0.05, 0.3))

# --- barracks: a corridor through two storeys of rooms ---------------------------------------------------------------------

x0, x1, z0, z1 = BARRACKS
CORRIDOR = (33.5, 36.5)
windows = [win(x) for x in (-65.0, -56.0, -47.5)] + [win(x, 1.8, STOREY) for x in (-65.0, -56.0, -47.5)]
house("Barracks", x0, x1, z0, z1, 2 * STOREY, color=PANEL, north=windows, south=windows,
      west=[door(35.0, 2.0)], east=[door(35.0, 2.0), door(35.0, 2.0, STOREY)])
STAIR_HOLE = (-69.0, -62.0, CORRIDOR[0] + 0.3, CORRIDOR[0] + 1.8)   # room past it at the top and along its side
slab("BarracksFloor", [(x0, x1, z0, z1)], [STAIR_HOLE], STOREY - 0.25, STOREY, CONCRETE_D)
ramp_x("BarracksStair", STAIR_HOLE[2], STAIR_HOLE[3], 0.0, STOREY, STAIR_HOLE[1], STAIR_HOLE[0], STEEL)
for y in (0.0, STOREY):
    h = STOREY - 0.25 if y == 0.0 else STOREY
    for z, doors in ((CORRIDOR[0], (-60.5, -51.5)), (CORRIDOR[1], (-65.0, -56.0, -47.5))):
        wall("Dorm", "x", z, x0, x1, y, y + h, [door(c, 1.4, y) for c in doors], PANEL)
    for x in (-61.0, -52.0):
        wall("Dorm", "z", x, z0, CORRIDOR[0], y, y + h, [door(25.0, 1.4, y)], PANEL)
        wall("Dorm", "z", x, CORRIDOR[1], z1, y, y + h, [door(45.0, 1.4, y)], PANEL)
    for x, z in ((-66.5, 26.0), (-56.5, 41.0), (-47.0, 28.0)):
        box("Bunk", x - 1.0, x + 1.0, y, y + 1.1, z - 2.2, z + 2.2, WOOD)
lv.lamp("BarracksLamp", (-56.0, 3.0, 35.0), energy=1.0, rng=8.0, shade=(0.4, 0.05, 0.2))
lv.lamp("BarracksLamp", (-50.0, STOREY + 3.0, 35.0), energy=1.0, rng=8.0, shade=(0.4, 0.05, 0.2))

# --- the stores: two halls of racks, the roof a firing line over the dock ----------------------------------------------------

x0, x1, z0, z1 = STORES
ROOF_Y = 6.0
house("Stores", x0, x1, z0, z1, ROOF_Y, color=CONCRETE,
      north=[door(-29.0, 4.0, 0.0, 3.4), door(-11.0, 4.0, 0.0, 3.4)], south=[door(-20.0, 3.0, 0.0, 3.0)],
      west=[door(25.0), door(41.0)], east=[door(25.0), door(41.0)])
wall("Stores", "z", -20.0, z0, z1, 0.0, ROOF_Y, [door(24.0, 2.0), door(33.0, 2.0), door(42.0, 2.0)], CONCRETE)
for x in (-34.0, -29.0, -24.5, -15.5, -11.0, -6.5):
    for z, half in ((25.0, 3.2), (33.5, 3.0), (41.5, 3.0)):
        box("Shelf", x - 0.5, x + 0.5, 0.0, 2.2, z - half, z + half, RUST if int(z) % 2 else WOOD)
for z in (z0, z1):
    rail_x(z, ROOF_Y + 0.3, x0, x1, CONCRETE)
rail_z(x0, ROOF_Y + 0.3, z0, z1, CONCRETE)
rail_z(x1, ROOF_Y + 0.3, z0, 34.4, CONCRETE)   # a gap at the landing
rail_z(x1, ROOF_Y + 0.3, 36.6, z1, CONCRETE)
lv.ramp("RoofStair", -2.2, 0.2, 0.0, ROOF_Y + 0.3, 47.0, 36.5, STEEL)   # outside, in the alley: up north
box("RoofLanding", -2.5, 0.2, ROOF_Y, ROOF_Y + 0.3, 34.5, 36.5, STEEL)
rail_z(0.2, ROOF_Y + 0.3, 34.5, 36.5)
rail_x(34.5, ROOF_Y + 0.3, -2.5, 0.2)
for x, z in ((-29.0, 25.0), (-14.0, 40.0)):
    box("Vent", x - 1.5, x + 1.5, ROOF_Y + 0.3, ROOF_Y + 1.35, z - 1.0, z + 1.0, STEEL)
lv.lamp("StoreLamp", (-28.0, 4.6, 33.0), energy=1.2, rng=9.0, shade=(0.4, 0.05, 0.4))
lv.lamp("StoreLamp", (-12.0, 4.6, 33.0), energy=1.2, rng=9.0, shade=(0.4, 0.05, 0.4))

# --- the boiler house: boilers in a hall, a walkway round them, the chimney ---------------------------------------------------

x0, x1, z0, z1 = BOILER
BOIL_H = 8.5
WALK_Y = 3.4
house("Boiler", x0, x1, z0, z1, BOIL_H, color=BRICK,
      north=[door(10.0, 3.0, 0.0, 3.0), door(34.0, 3.0, 0.0, 3.0), win(22.0, 6.0, WALK_Y)],
      south=[door(10.0), door(30.0), win(20.0, 4.0, WALK_Y)],
      west=[door(25.0), door(41.0), door(33.0, 1.6, WALK_Y)], east=[door(33.0)])
for i, x in enumerate((12.0, 22.5, 33.0)):
    box("BoilerDrum", x - 3.0, x + 3.0, 0.0, 3.6, 28.0, 38.0, RUST if i != 1 else STEEL)
    box("BoilerStack", x - 0.6, x + 0.6, 3.6, BOIL_H, 33.0 - 0.6, 33.0 + 0.6, STEEL)
slab("Walkway", [(x0, x1, 40.0, 42.5), (x0, x1, 23.5, 26.0), (x0, 8.0, 26.0, 40.0), (37.0, x1, 26.0, 40.0)], [],
     WALK_Y - 0.15, WALK_Y, STEEL)
rail_x(40.0, WALK_Y, 8.0, 37.0)
rail_x(26.0, WALK_Y, 8.0, 37.0)
rail_x(42.5, WALK_Y, x0, 16.0)
rail_x(42.5, WALK_Y, 18.5, x1)
rail_x(23.5, WALK_Y, x0, 24.0)
rail_x(23.5, WALK_Y, 26.5, x1)
lv.ramp("WalkStair", 16.0, 18.5, 0.0, WALK_Y, 47.0, 42.5, STEEL)   # both from under the walkway's far side
lv.ramp("WalkStair", 24.0, 26.5, 0.0, WALK_Y, 19.0, 23.5, STEEL)
lv.lamp("BoilerLamp", (17.5, 3.0, 45.0), energy=1.2, rng=9.0, shade=(0.4, 0.05, 0.4))
lv.lamp("BoilerLamp", (27.5, 3.0, 22.0), energy=1.2, rng=9.0, shade=(0.4, 0.05, 0.4))
lv.lamp("BoilerLamp", (6.0, WALK_Y + 3.0, 33.0), energy=1.0, rng=9.0, shade=(0.4, 0.05, 0.4))
octagon("Chimney", 44.0, 42.0, 2.0, 0.0, 30.0, BRICK)

# --- portal cranes on the quays (scenery you can run between the legs of) ---------------------------------------------------


def crane(x, z, boom_side):
    for sx in (-1, 1):
        for sz in (-1, 1):
            box("CraneLeg", x + sx * 2.6 - 0.35, x + sx * 2.6 + 0.35, 0.0, 7.0, z + sz * 2.6 - 0.35, z + sz * 2.6 + 0.35, RUST)
    box("CraneDeck", x - 3.0, x + 3.0, 7.0, 7.6, z - 3.0, z + 3.0, RUST)
    box("CraneCab", x - 1.8, x + 1.8, 7.6, 11.0, z - 1.8, z + 1.8, RUST)
    box("CraneMast", x - 0.5, x + 0.5, 11.0, 17.0, z - 0.5, z + 0.5, RUST)
    a = math.radians(35.0)
    rotated("CraneBoom", (x, 12.0 + 6.5 * math.sin(a), z + boom_side * 11.0 * math.cos(a)), (0.7, 0.7, 26.0), RUST,
            rot_x=boom_side * -a)


crane(14.0, -13.5, 1)
crane(-22.0, 13.5, -1)
for x in (-14.0, 33.0):   # lamp posts on the quays: "here", down to the dock
    for side in (-1, 1):
        px = x + side * 4.0
        box("LampPost", px - 0.08, px + 0.08, 0.0, 5.0, side * 12.0 - 0.08, side * 12.0 + 0.08, STEEL)
        lv.lamp("QuayLamp", (px, 4.8, side * 12.0), energy=1.0, rng=9.0, shade=(0.4, 0.06, 0.25))

# --- the frozen sea --------------------------------------------------------------------------------------------------------

PIER = (47.5, 53.5, 20.0, 55.0)
HOLES = [(60.0, 68.0, 8.0, 16.0), (49.0, 54.0, -30.0, -24.0), (62.0, 70.0, 30.0, 36.0)]   # thin ice: open water
slab("Ice", [(LAND_X1, SEA_X1, -LAND_Z, LAND_Z)], HOLES + [PIER], ICE_BOTTOM, ICE_Y, ICE)
box("Pier", PIER[0], PIER[1], ICE_BOTTOM, 0.0, PIER[2], PIER[3], CONCRETE)
box("Pier", LAND_X1, PIER[0], ICE_BOTTOM, 0.0, 44.0, 50.0, CONCRETE)   # joins the land past the boiler house
for z in (28.0, 38.0, 48.0):
    box("Bollard", 52.6, 53.2, 0.0, 0.9, z - 0.3, z + 0.3, STEEL)
box("PierShed", 48.0, 52.0, 0.0, 2.9, 32.0, 37.0, RUST)
rail_z(PIER[1] - 0.05, 0.0, PIER[2], PIER[3])
for z0, z1 in ((-12.0, -10.5), (11.0, 12.5)):   # steps from the sea up to the land, either side of the gate
    ramp_x("IceStep", z0, z1, ICE_Y, 0.0, LAND_X1 + 2.2, LAND_X1, CONCRETE)

SUB2 = (57.5, 65.5, -44.0, -5.0)    # the other boat, frozen in: hull you can climb, nothing inside
x0, x1, z0, z1 = SUB2
SUB2_DECK = 2.0
box("Hull2", x0, x1, ICE_Y, SUB2_DECK - 0.8, z0, z1, HULL)
box("Hull2", x0 + 1.0, x1 - 1.0, SUB2_DECK - 0.8, SUB2_DECK, z0, z1, HULL)
for z_a, z_b, inset in ((z0 - 1.6, z0, 1.6), (z0 - 2.8, z0 - 1.6, 3.0)):
    box("Hull2End", x0 + inset, x1 - inset, ICE_Y, SUB2_DECK - 0.6, z_a, z_b, HULL)
box("Tower2", x0 + 2.6, x1 - 2.6, SUB2_DECK, SUB2_DECK + 3.2, -28.0, -21.0, HULL)
box("Mast2", 61.4, 61.6, SUB2_DECK + 3.2, SUB2_DECK + 7.0, -25.1, -24.9, STEEL)
lv.ramp("IceRamp", x0 + 1.5, x1 - 1.5, ICE_Y, SUB2_DECK + 0.18, z1 + 5.0, z1 - 0.3, ICE_RIDGE, 0.5)   # its end into the hull: no gap
for x, z, w, d, h, turn in ((51.0, -8.0, 3.0, 5.0, 1.1, 20), (56.0, 10.0, 4.5, 2.5, 1.5, -30), (68.0, 23.0, 5.0, 3.0, 1.9, 40),
                            (58.0, 26.0, 2.5, 4.0, 1.0, 10), (70.0, -20.0, 3.5, 6.0, 2.2, -15), (50.0, -42.0, 4.0, 3.0, 1.5, 35),
                            (69.0, 2.0, 3.0, 3.0, 1.2, 55), (66.0, 45.0, 6.0, 3.0, 1.7, -25)):
    rotated("Floe", (x, ICE_Y + h / 2 - 0.1, z), (w, h + 0.2, d), ICE_RIDGE, rot_y=math.radians(turn), rot_z=math.radians(4))

# --- the edges: a fence on land, pressure ridges at sea, then only scenery -----------------------------------------------------

box("Fence", LAND_X0 - 0.3, LAND_X0, 0.0, FENCE_H, -LAND_Z, LAND_Z, CONCRETE_D)
for z in (-LAND_Z, LAND_Z):
    box("Fence", LAND_X0, LAND_X1, 0.0, FENCE_H, z - (0.3 if z < 0 else 0.0), z + (0.0 if z < 0 else 0.3), CONCRETE_D)
for z in range(-50, 55, 10):
    box("FencePost", LAND_X0 - 0.4, LAND_X0 + 0.15, 0.0, FENCE_H + 0.4, z - 0.15, z + 0.15, CONCRETE)
for x in range(-70, 45, 10):
    for side in (-1, 1):
        box("FencePost", x - 0.15, x + 0.15, 0.0, FENCE_H + 0.4, side * LAND_Z - 0.4, side * LAND_Z + 0.4, CONCRETE)
for z in range(-55, 55, 7):        # east: a wall of tilted ice, too high to climb
    h = random.uniform(5.0, 7.5)
    rotated("Ridge", (SEA_X1 + 0.8, ICE_Y + h / 2, z + 3.5), (3.6, h, 8.0), ICE_RIDGE, rot_y=random.uniform(-0.3, 0.3),
            rot_z=random.uniform(-0.08, 0.08))
for side in (-1, 1):
    for x in range(int(LAND_X1) + 2, int(SEA_X1) + 3, 7):
        h = random.uniform(5.0, 7.5)
        rotated("Ridge", (x + 2.0, ICE_Y + h / 2, side * (LAND_Z + 0.8)), (8.0, h, 3.6), ICE_RIDGE,
                rot_y=random.uniform(-0.3, 0.3), rot_x=random.uniform(-0.08, 0.08))

FAR = 290.0
box("FarSnow", -FAR, LAND_X0 - 0.3, -2.0, 0.0, -FAR, FAR, SNOW)
box("FarSnow", LAND_X0 - 0.3, LAND_X1 + 2.0, -2.0, 0.0, -FAR, -LAND_Z - 0.3, SNOW)
box("FarSnow", LAND_X0 - 0.3, LAND_X1 + 2.0, -2.0, 0.0, LAND_Z + 0.3, FAR, SNOW)
box("FarIce", SEA_X1 + 2.5, FAR, -2.0, ICE_Y, -FAR, FAR, ICE)
box("FarIce", LAND_X1 + 2.0, SEA_X1 + 2.5, -2.0, ICE_Y, -FAR, -LAND_Z - 2.5, ICE)
box("FarIce", LAND_X1 + 2.0, SEA_X1 + 2.5, -2.0, ICE_Y, LAND_Z + 2.5, FAR, ICE)
for x, z, w, d, h in ((-200.0, -160.0, 150.0, 90.0, 70.0), (-90.0, -210.0, 170.0, 80.0, 95.0), (70.0, -240.0, 200.0, 80.0, 60.0),
                      (-235.0, 20.0, 80.0, 190.0, 85.0), (-190.0, 205.0, 170.0, 80.0, 65.0), (-20.0, 235.0, 190.0, 70.0, 50.0)):
    for i, k in enumerate((1.0, 0.72, 0.42)):   # a mountain: dark, its top under snow
        box("Mountain", x - w * k / 2, x + w * k / 2, h * i / 3, h * (i + 1) / 3, z - d * k / 2, z + d * k / 2,
            ROCK if i < 2 else SNOW_DIRT)
for _ in range(26):   # firs round the fence, thicker to the west
    side = random.choice(("w", "w", "n", "s"))
    x, z = ((random.uniform(-125, -80), random.uniform(-90, 90)) if side == "w" else
            (random.uniform(-110, 30), random.choice((-1, 1)) * random.uniform(60, 95)))
    fir(x, z, random.uniform(7.0, 12.0))

lv.write(OUT, "DrydockShell", ground_y=-9.0)
