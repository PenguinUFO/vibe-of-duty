"""Generates prefabs/levels/killhouse_shell.tscn: the shell of a killhouse - rooms of block walls inside a tall hangar
with skylights, by day (FFA, 2-4 players), laid out from the owner's plan (measured at 12.5 px per metre, see
Docs/LEVEL_KILLHOUSE.md). Read Docs/LEVEL_KILLHOUSE.md first; update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_killhouse_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Cover props (cars, crates, the table), spawns,
environment, the sun - the hand-edited prefabs/levels/killhouse.tscn, which instances this shell.

One floor, x -17.25 .. 17.25, z -33.25 .. 33.25 (north, the plan's top, is -z). Walls (WALL_H) are over a standing
player's head and too high and too thin to climb (player_mantle.gd: MANTLE_MAX_HEIGHT, MANTLE_MIN_TOP). The two
platforms ("1" on the plan) are a storey up (PLATFORM_H, over the mantle): from them you see over the walls, their
walls are chest-high parapets. Under each is a room (the owner): a door on the stair's side, two windows opposite. The hatched boxes on the plan are solid, as high as the walls.

The hangar (the owner's reference: high outer walls, windows in the roof): long walls EAVES_H tall, a gable roof along
z on trusses (BAY apart) with a skylight in every bay on both slopes and glazing bars across it (the sun comes through
in stripes), a band of windows high in both gable ends. The openings are open, no glass: a pane would cast a shadow.
Lamps hang from beams along the ties.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "killhouse_shell.tscn")

HX, HZ = 17.25, 33.25     # the hangar's inner faces
EAVES_H = 12.0            # the long walls
RIDGE_RISE = 4.0          # the ridge over the eaves (along z, at x 0)
OUTER_T = 0.4
BAYS = 11                 # between the trusses (the end walls have one each)
BAY = 2 * HZ / BAYS
SKY_S = (4.0, 13.0)       # a skylight from .. to (m up the slope from the eaves)
SKY_BARS = 1.2            # glazing bars about this far apart across a skylight
SKY_FRAME = 0.6           # solid roof along the trusses on both sides of a skylight
GABLE_WIN = (6.0, 11.0)   # the gable ends' window band (y)
GABLE_MULLION = 2.5       # its mullions about this far apart
WALL_H = 3.0              # the rooms' walls: over the head, over the mantle (2.8 m)
WALL_T = 0.14             # thinner than MANTLE_MIN_TOP: their tops cannot be stood on
PLATFORM_H = 3.0          # the platforms' floor (the room under it 2.75 m clear); parapets PARAPET over it
PLATFORM_SLAB = 0.25
PARAPET = 1.0
ROOM_H = PLATFORM_H + PARAPET   # the rooms' walls under the platforms, parapets included
DOOR_H = 2.3
WINDOW_Y = (0.6, 2.6)     # the rooms' windows: sill, top - a jump takes you out (a standing player is 1.8 m)
SOLID_H = 3.0             # the hatched boxes (containers)
COUNTER_H = 1.0           # the counter by the south wall
LAMP_X = (-9.0, 9.0)      # the hanging lamps: two rows along z, one per bay
LAMP_Y = 8.0

FLOOR_C = (0.46, 0.45, 0.42)
OUTER_C = (0.55, 0.53, 0.49)
PLY = (0.56, 0.53, 0.47)  # cinder block (the name: the walls were plywood)
STEEL = (0.32, 0.32, 0.31)
TRUSS_C = (0.5, 0.5, 0.48)
ROOF_C = (0.45, 0.45, 0.44)
BOX_C = (0.42, 0.3, 0.24)  # rusty containers
WOOD = (0.48, 0.33, 0.24)

lv = Level([])
box = lv.box
SLOPE = math.atan2(RIDGE_RISE, HX)
SLOPE_LEN = math.hypot(HX, RIDGE_RISE)


def wall_x(z, x0, x1, h=WALL_H, name="Wall"):
    """A wall along x, its middle on z."""
    box(name, x0 - WALL_T / 2, x1 + WALL_T / 2, 0.0, h, z - WALL_T / 2, z + WALL_T / 2, PLY)


def wall_z(x, z0, z1, h=WALL_H, name="Wall"):
    """A wall along z, its middle on x."""
    box(name, x - WALL_T / 2, x + WALL_T / 2, 0.0, h, z0 - WALL_T / 2, z1 + WALL_T / 2, PLY)


def wall_x_open(z, x0, x1, holes, h=ROOM_H, name="RoomWall"):
    """A wall along x with openings [(xa, xb, ya, yb)] (left to right): pieces around each."""
    x = x0
    for xa, xb, ya, yb in holes:
        if xa > x:
            box(name, x - WALL_T / 2, xa, 0.0, h, z - WALL_T / 2, z + WALL_T / 2, PLY)
        if ya > 0.0:
            box(name, xa, xb, 0.0, ya, z - WALL_T / 2, z + WALL_T / 2, PLY)
        box(name, xa, xb, yb, h, z - WALL_T / 2, z + WALL_T / 2, PLY)
        x = xb
    box(name, x, x1 + WALL_T / 2, 0.0, h, z - WALL_T / 2, z + WALL_T / 2, PLY)


def platform(name, x0, x1, z0, z1):
    """A platform's floor over its room."""
    box(name, x0, x1, PLATFORM_H - PLATFORM_SLAB, PLATFORM_H, z0, z1, STEEL)


def roof_y(x):
    """The roof's underside over x."""
    return EAVES_H + RIDGE_RISE * (1.0 - abs(x) / HX)


def on_slope(name, side, s0, s1, z0, z1, thick, color, offset):
    """A box lying along one slope of the roof (side -1 west, +1 east): s0 .. s1 m up it from the eaves, z0 .. z1,
    its middle `offset` m above the roof's underside (negative: under it)."""
    s = (s0 + s1) / 2
    x = side * (HX - s * math.cos(SLOPE)) + side * math.sin(SLOPE) * offset
    y = EAVES_H + s * math.sin(SLOPE) + math.cos(SLOPE) * offset
    lv.rotated(name, (x, y, (z0 + z1) / 2), (s1 - s0, thick, z1 - z0), color, rot_z=-side * SLOPE)


# --- the hangar --------------------------------------------------------------------------------------------------------

box("Ground", -HX - OUTER_T, HX + OUTER_T, -0.3, 0.0, -HZ - OUTER_T, HZ + OUTER_T, FLOOR_C)
for side in (-1.0, 1.0):  # the long walls
    x0 = HX if side > 0 else -HX - OUTER_T
    box("Outer", x0, x0 + OUTER_T, 0.0, EAVES_H + 0.3, -HZ - OUTER_T, HZ + OUTER_T, OUTER_C)
for side in (-1.0, 1.0):  # the gable ends: solid, the window band, the gable over the eaves in steps up into the roof
    z0 = HZ if side > 0 else -HZ - OUTER_T
    z1 = z0 + OUTER_T
    box("End", -HX, HX, 0.0, GABLE_WIN[0], z0, z1, OUTER_C)
    box("End", -HX, HX, GABLE_WIN[1], EAVES_H, z0, z1, OUTER_C)
    n = round(2 * HX / GABLE_MULLION)
    for i in range(n + 1):
        x = -HX + i * 2 * HX / n
        box("Mullion", x - 0.15, x + 0.15, GABLE_WIN[0], GABLE_WIN[1], z0, z1, OUTER_C)
    mid = (GABLE_WIN[0] + GABLE_WIN[1]) / 2
    box("Transom", -HX, HX, mid - 0.1, mid + 0.1, z0, z1, OUTER_C)
    x = -HX
    while x < HX - 1e-6:
        box("Gable", x, x + 1.0, EAVES_H, roof_y(min(abs(x), abs(x + 1.0))) + 0.15, z0, z1, OUTER_C)
        x += 1.0

for side in (-1.0, 1.0):  # the roof, per bay: solid at the eaves, the skylight with its bars, solid to the ridge
    for k in range(BAYS):
        za, zb = -HZ + k * BAY, -HZ + (k + 1) * BAY
        on_slope("Roof", side, -0.6, SKY_S[0], za, zb, 0.2, ROOF_C, 0.1)
        on_slope("Roof", side, SKY_S[1], SLOPE_LEN + 0.15, za, zb, 0.2, ROOF_C, 0.1)
        on_slope("Roof", side, SKY_S[0], SKY_S[1], za, za + SKY_FRAME, 0.2, ROOF_C, 0.1)
        on_slope("Roof", side, SKY_S[0], SKY_S[1], zb - SKY_FRAME, zb, 0.2, ROOF_C, 0.1)
        n = max(1, round((BAY - 2 * SKY_FRAME) / SKY_BARS))
        for i in range(1, n):
            z = za + SKY_FRAME + i * (BAY - 2 * SKY_FRAME) / n
            on_slope("GlazingBar", side, SKY_S[0], SKY_S[1], z - 0.05, z + 0.05, 0.12, STEEL, 0.06)

for k in range(BAYS + 1):  # the trusses: a rafter under each slope, a tie at the eaves, struts, a pilaster on each wall
    z = min(max(-HZ + k * BAY, -HZ + 0.25), HZ - 0.25)
    for side in (-1.0, 1.0):
        on_slope("Rafter", side, 0.0, SLOPE_LEN, z - 0.15, z + 0.15, 0.6, TRUSS_C, -0.3)
        box("Pilaster", min(side * HX, side * (HX - 0.35)), max(side * HX, side * (HX - 0.35)), 0.0, EAVES_H,
            z - 0.25, z + 0.25, TRUSS_C)
        for x in (6.0, 12.0):
            box("Strut", side * x - 0.1, side * x + 0.1, EAVES_H - 0.3, roof_y(x) - 0.3, z - 0.1, z + 0.1, TRUSS_C)
    box("Tie", -HX, HX, EAVES_H - 0.6, EAVES_H - 0.3, z - 0.12, z + 0.12, TRUSS_C)
for x in LAMP_X:  # the beams the lamps hang from, along the ties
    box("Purlin", x - 0.1, x + 0.1, EAVES_H - 0.8, EAVES_H - 0.6, -HZ, HZ, TRUSS_C)
for k in range(BAYS):
    z = -HZ + (k + 0.5) * BAY
    for x in LAMP_X:
        box("Cable", x - 0.015, x + 0.015, LAMP_Y + 0.2, EAVES_H - 0.8, z - 0.015, z + 0.015, STEEL)
        lv.lamp("Lamp", (x, LAMP_Y, z), energy=1.0, rng=12.0, shade=(0.5, 0.3, 0.5))

# --- the north end: a strip along the back wall, open to the middle between x -8.25 and 8 ----------------------------

wall_x(-26.5, -HX, -8.25)
wall_x(-26.5, 8.0, HX)

# The north platform: an L (the stair comes up into its foot from the north), a room under it - the door on the
# north, by the stair, two windows in the south wall.
platform("Platform", -1.5, 3.25, -23.75, -18.0)
platform("Platform", -4.0, -1.5, -21.0, -18.0)
lv.ramp("Stair", -4.0, -1.5, 0.0, PLATFORM_H, -26.0, -21.0, STEEL)
wall_x_open(-23.75, -1.5, 3.25, [(-1.0, 0.5, 0.0, DOOR_H)])
wall_z(3.25, -23.75, -18.0, ROOM_H, "RoomWall")
wall_z(-4.0, -26.0, -18.0, ROOM_H, "RoomWall")   # the stair's walls, then the room's
wall_z(-1.5, -26.0, -21.0, ROOM_H, "RoomWall")
wall_x_open(-18.0, -4.0, 3.25, [(-2.8, -1.2) + WINDOW_Y, (0.7, 2.3) + WINDOW_Y])
lv.lamp("RoomLamp", (0.9, PLATFORM_H - PLATFORM_SLAB - 0.15, -21.0), energy=0.8, rng=6.0, shade=(0.4, 0.05, 0.4))
wall_x(-18.0, -HX, -12.25)        # the line it stands on: a door, the wall, the room
wall_x(-18.0, -10.25, -4.0)
wall_x(-18.75, 3.25, 10.75)
wall_z(13.25, -22.0, -16.0)       # the T in the north-east
wall_x(-19.5, 13.25, HX)

# --- the middle ---------------------------------------------------------------------------------------------------

wall_z(-13.5, -13.5, -8.5)        # the T in the west
wall_x(-11.5, -13.5, -8.5)
wall_x(-12.0, -2.5, 3.25)         # the T in the middle (its stem points north)
wall_z(-0.5, -13.75, -12.0)
box("Solid", -HX, -10.25, 0.0, SOLID_H, -6.25, -3.75, BOX_C)      # the hatched boxes
box("Solid", -2.5, 1.25, 0.0, SOLID_H, -3.75, 0.75, BOX_C)
lv.rotated("Solid", (-7.65, SOLID_H / 2, 2.9), (6.25, SOLID_H, 2.25), BOX_C, rot_y=-math.pi / 4)
wall_z(-14.0, 4.5, 11.5)          # the lone wall in the west
wall_x(11.0, -5.5, -1.75)         # the L
wall_z(-1.75, 11.0, 13.0)

# The two rooms on the east wall, doors north and south and between them.
wall_z(10.0, -10.75, 5.5)
wall_x(-10.75, 10.0, 13.25)
wall_x(-10.75, 15.0, HX)
wall_x(-9.75, 7.25, 10.0)
wall_x(-2.75, 10.0, 11.75)
wall_x(-2.75, 13.5, HX)
wall_x(5.5, 7.75, 13.25)
wall_x(5.5, 15.0, HX)

# --- the south end ------------------------------------------------------------------------------------------------

wall_x(16.0, -HX, -7.0)           # the room in the south-west, open to the east
wall_x(23.5, -HX, -8.25)

# The south platform: the north one turned round about (1.5, z) - x goes to 3 - x (its stair comes up from the south).
platform("Platform", -0.25, 7.0, 16.75, 19.75)
platform("Platform", -0.25, 4.5, 19.75, 22.75)
lv.ramp("Stair", 4.5, 7.0, 0.0, PLATFORM_H, 25.0, 19.75, STEEL)
wall_x(16.75, -2.0, -0.25)        # the line it stands on, the room in the middle
wall_x(16.75, 7.0, 9.5)
wall_x_open(16.75, -0.25, 7.0, [(0.7, 2.3) + WINDOW_Y, (4.2, 5.8) + WINDOW_Y])
wall_z(-0.25, 16.75, 22.75, ROOM_H, "RoomWall")
wall_x_open(22.75, -0.25, 4.5, [(2.5, 4.0, 0.0, DOOR_H)])
wall_z(4.5, 19.75, 25.0, ROOM_H, "RoomWall")    # the stair's walls
wall_z(7.0, 16.75, 25.0, ROOM_H, "RoomWall")
lv.lamp("RoomLamp", (2.1, PLATFORM_H - PLATFORM_SLAB - 0.15, 18.25), energy=0.8, rng=6.0, shade=(0.4, 0.05, 0.4))

wall_x(13.25, 12.25, HX)          # the east wall's stubs
wall_x(22.75, 9.5, HX)
wall_z(16.0, 25.5, HZ)            # the L in the south-east corner
wall_x(25.75, 14.25, 16.0)
box("Counter", -5.0, 11.5, 0.0, COUNTER_H, 30.75, 32.5, WOOD)     # the counter by the south wall

lv.write(OUT, "KillhouseShell")
