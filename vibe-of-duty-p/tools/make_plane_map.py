"""Generates prefabs/levels/plane_shell.tscn: the shell of a giant cargo plane flying above the clouds by day (FFA,
2-4 players) - a six-engined, twin-finned An-225-like plane stretched further than any real one: three decks, the
hold split into bays by bulkheads, the open rear ramp, the outside (wings, tail), the lamps.
Read Docs/LEVEL_PLANE.md first (layout, the owner's decisions, how to check); update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_plane_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Everything else - vehicles, cargo, seats, spawn
points, environment, sun - is the hand-edited prefabs/levels/plane.tscn, which instances this shell.

The plane stands still and the clouds move past it (scripts/game/sky_scenery.gd), like the train and its forest.
It flies along -Z: the nose at -Z, the open ramp at +Z.

Three decks:
- The belly (y -3, 2.7 m tall): a low, dark deck under the hold, cut in three by frames with doorways; three ramps
  down from the hold.
- The hold (y 0, 4.4 m tall, 80 m long): split into four bays by bulkheads with openings at alternating sides (no
  sightline down its length), vehicles in the bays (props). Two paratroop doors, the open ramp at the back.
- The upper deck (y 4.7) over the whole hold: cockpit, crew cabin, the rest room over the wing, the troop deck - rooms
  in a row with doorways between them; five stairs up from the hold.

The edges are low on purpose (the owner's call): the ramp's end and the doors are closed by a plate RAIL tall that a
jump clears - anybody can jump out. The doors are 3 m tall for it. Windows are 0.5 m tall, lower than a crouching
player.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level, RAIL_T  # noqa: E402

# Rails are low on purpose (the owner): a jump (apex ~1.06 m) clears them, so anybody can go over the edge. Thin: the
# vault still refuses them - it is a jump, not a climb. level_gen.RAIL (1.3 m) is the high one.
RAIL = 0.8

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "plane_shell.tscn")

HW = 4.2           # hold inner half width (the belly and the upper deck are as wide)
T = 0.3            # skin thickness
HOLD_H = 4.4       # hold ceiling
SLAB = 0.3
UPPER = HOLD_H + SLAB   # upper deck floor (4.7)
UPPER_H = 2.2
ROOF = UPPER + UPPER_H  # 6.9
BELLY = -3.0            # belly deck floor; its ceiling is the hold floor's underside (-0.3)
HOLD_Z0, HOLD_Z1 = -40.0, 40.0   # hold: front wall's inner face .. the ramp hinge
RAMP_Z1 = 44.0
DECK = (-50.0, 30.0)             # upper deck: windscreen .. aft wall (inner faces)
DECK_WALLS = [(-44.0, 0.55, 2.0), (-20.0, 0.7, 2.1), (5.0, 0.7, 2.1)]   # cross walls: z, doorway half width, height
BELLY_Z = (-36.0, 36.0)          # belly: front wall .. back wall (inner faces)
BELLY_FRAMES = [(-12.0, -1.6), (14.0, 1.6)]   # belly frames: z, doorway centre x (1.4 m wide, full height)
CHAMFER = 0.8
PORT_Y, PORT_H, PORT_W = 2.0, 0.5, 0.5
PORT_STEP = 5.0
DOOR_H = 3.0       # paratroop doors: a full jump over the low plate fits under the lintel (feet ~1.06 + 1.8 m)
DOORS = {-1: (2.0, 3.2), 1: (32.0, 33.2)}   # paratroop doors: side -> z range
STAIR_W = 1.4
# Stairs up to the upper deck (x0, x1, z at the hold floor, z at the deck), all along the walls.
STAIRS = [
    (-HW, -HW + STAIR_W, -30.0, -21.5),     # crew cabin, left, rising aft
    (HW - STAIR_W, HW, -27.0, -35.5),       # crew cabin, right, rising forward
    (HW - STAIR_W, HW, -14.0, -5.5),        # rest room, right, rising aft
    (-HW, -HW + STAIR_W, 10.0, 18.5),       # troop deck, left, rising aft
    (HW - STAIR_W, HW, 25.0, 16.5),         # troop deck, right, rising forward
]
# Ramps down to the belly (x0, x1, z at the belly floor, z at the hold floor).
BELLY_STAIRS = [
    (-HW, -HW + STAIR_W, 0.0, -6.0),        # left, going down aft
    (-HW, -HW + STAIR_W, 32.0, 26.0),       # left, going down aft
    (HW - STAIR_W, HW, -24.0, -18.0),       # right, going down forward
]
# Bulkheads across the hold: z, and the opening (x0, x1) - at alternating sides, so the hold has no long sightline.
BULKHEADS = [(-16.0, (-1.5, 1.5)), (5.0, (-HW, -1.2)), (25.5, (-0.8, HW))]
NET = (5.0, (-1.2, 0.8))         # a cargo net beside the second bulkhead's opening: shot through, not walked through
DECK_SPLITS = [-SLAB / 2, HOLD_H + SLAB / 2]   # TrainProps.deck_splits in plane.tscn

SKIN = (0.46, 0.45, 0.42)
RIB = (0.3, 0.29, 0.28)
FLOOR = (0.33, 0.31, 0.29)
BELLY_C = (0.38, 0.37, 0.35)     # the belly's walls, darker than the hold's
CABIN = (0.55, 0.52, 0.47)
TROOP = (0.5, 0.49, 0.45)
CABIN_FLOOR = (0.36, 0.34, 0.31)
STEEL = (0.42, 0.42, 0.41)
NET_C = (0.36, 0.33, 0.27)
OUTSIDE = (0.62, 0.62, 0.6)
DARK = (0.16, 0.155, 0.15)

lv = Level(DECK_SPLITS)
box = lv.box


def zr(s):
    return tuple(sorted((s[2], s[3])))


def wall_holes(side, stairs):
    return [zr(s) for s in stairs if (s[0] > 0) == (side > 0)]


def cut(z0, z1, holes):
    out, z = [], z0
    for a, b in sorted(holes):
        if a > z:
            out.append((z, min(a, z1)))
        z = max(z, b)
    if z < z1:
        out.append((z, z1))
    return [(a, b) for a, b in out if b - a > 0.01]


def hold_wall(side, z0, z1):
    xa, xb = sorted((side * HW, side * (HW + T)))
    box("HoldWallLow", xa, xb, 0.0, PORT_Y, z0, z1, SKIN)
    box("HoldWallHigh", xa, xb, PORT_Y + PORT_H, HOLD_H, z0, z1, SKIN)
    z = z0
    for i in range(int((z1 - z0) // PORT_STEP)):
        pz = z0 + PORT_STEP / 2 + i * PORT_STEP
        box("HoldWallPier", xa, xb, PORT_Y, PORT_Y + PORT_H, z, pz - PORT_W / 2, SKIN)
        z = pz + PORT_W / 2
    box("HoldWallPier", xa, xb, PORT_Y, PORT_Y + PORT_H, z, z1, SKIN)


def floor_slab(name, y0, y1, z0, z1, holes, color):
    """A floor over the full width from z0 to z1 with holes [(x0, x1, za, zb)]."""
    lv.slab(name, [(-HW - T, HW + T, z0, z1)], [(h[0], h[1]) + zr(h) for h in holes], y0, y1, color)


def stair_rails(s, y):
    """Rails round a stair hole in the floor at y (the ramp's high end): along the open side but the last 1.5 m (where
    the ramp is level with the floor), and across the low end."""
    x0, x1, z_low, z_high = s
    left = x0 < 0
    xr = (x1, x1 + RAIL_T) if left else (x0 - RAIL_T, x0)
    up = 1 if z_high > z_low else -1
    za, zb = sorted((z_low, z_high - up * 1.5))
    box("Rail", xr[0], xr[1], y, y + RAIL, za, zb, STEEL)
    ca, cb = sorted((z_low, z_low - up * RAIL_T))
    box("Rail", x0, x1, y, y + RAIL, ca, cb, STEEL)


# --- the belly -------------------------------------------------------------------------------------------------------

box("BellyFloor", -HW - T, HW + T, BELLY - SLAB, BELLY, BELLY_Z[0] - T, BELLY_Z[1] + T, FLOOR)
for side in (1, -1):
    xa, xb = sorted((side * HW, side * (HW + T)))
    box("BellyWall", xa, xb, BELLY, -SLAB, BELLY_Z[0], BELLY_Z[1], BELLY_C)
box("BellyEnd", -HW - T, HW + T, BELLY, -SLAB, BELLY_Z[0] - T, BELLY_Z[0], BELLY_C)
box("BellyEnd", -HW - T, HW + T, BELLY, -SLAB, BELLY_Z[1], BELLY_Z[1] + T, BELLY_C)
for z, dx in BELLY_FRAMES:   # frames across the belly, a doorway in each (the two at different sides)
    box("BellyFrame", -HW, dx - 0.7, BELLY, -SLAB, z - 0.15, z + 0.15, BELLY_C)
    box("BellyFrame", dx + 0.7, HW, BELLY, -SLAB, z - 0.15, z + 0.15, BELLY_C)
for x0, x1, z_low, z_high in BELLY_STAIRS:
    lv.ramp("BellyStairs", x0, x1, BELLY, 0.0, z_low, z_high, STEEL)
# Solid under the hold floor where there is no belly: the nose's and the tail's lower parts.
box("Keel", -HW - T, HW + T, -4.5, -SLAB, HOLD_Z0 - T, BELLY_Z[0] - T, DARK)
box("Keel", -HW - T, HW + T, -4.5, -SLAB, BELLY_Z[1] + T, HOLD_Z1, DARK)
box("Keel", -HW + 0.2, HW - 0.2, -4.5, BELLY - SLAB, BELLY_Z[0] - T, BELLY_Z[1] + T, DARK)

# --- the hold --------------------------------------------------------------------------------------------------------

floor_slab("HoldFloor", -SLAB, 0.0, HOLD_Z0 - T, HOLD_Z1, BELLY_STAIRS, FLOOR)
for s in BELLY_STAIRS:
    stair_rails(s, 0.0)
box("FrontWall", -HW - T, HW + T, 0.0, HOLD_H, HOLD_Z0 - T, HOLD_Z0, SKIN)
for side in (1, -1):
    d0, d1 = DOORS[side]
    hold_wall(side, HOLD_Z0, d0)
    hold_wall(side, d1, HOLD_Z1)
    xa, xb = sorted((side * HW, side * (HW + T)))
    box("DoorLintel", xa, xb, DOOR_H, HOLD_H, d0, d1, SKIN)
    oa, ob = sorted((side * (HW + T - RAIL_T), side * (HW + T)))
    box("DoorBar", oa, ob, 0.0, RAIL, d0, d1, STEEL)   # a plate across the door, at the outer face
    for z0, z1 in cut(HOLD_Z0, HOLD_Z1, wall_holes(side, STAIRS)):
        mid = (side * (HW - CHAMFER / 2), HOLD_H - CHAMFER / 2)
        out = 0.15 / math.sqrt(2)
        lv.rotated("Chamfer", (mid[0] + side * out, mid[1] + out, (z0 + z1) / 2),
                   (CHAMFER * math.sqrt(2), 0.3, z1 - z0), SKIN, rot_z=-side * math.pi / 4)
    holes = wall_holes(side, STAIRS + BELLY_STAIRS) + [(b[0] - 0.3, b[0] + 0.3) for b in BULKHEADS]
    for i in range(int((HOLD_Z1 - HOLD_Z0) / 2.5) + 1):
        z = HOLD_Z0 + 1.25 + i * 2.5
        if z > HOLD_Z1 - 0.5 or any(a - 0.3 < z < b + 0.3 for a, b in holes) or d0 - 0.3 < z < d1 + 0.3:
            continue
        xa, xb = sorted((side * (HW - 0.12), side * HW))
        box("Rib", xa, xb, 0.3, HOLD_H - CHAMFER, z - 0.08, z + 0.08, RIB)
for i in range(int((HOLD_Z1 - HOLD_Z0) / 2.5) + 1):
    z = HOLD_Z0 + 1.25 + i * 2.5
    if z < HOLD_Z1 - 0.5 and not any(abs(z - b[0]) < 0.4 for b in BULKHEADS):
        box("CeilingRib", -HW + STAIR_W + 0.05, HW - STAIR_W - 0.05, HOLD_H - 0.12, HOLD_H, z - 0.08, z + 0.08, RIB)
# Bulkheads: full height, an opening 3.6 m tall at one side (or the middle).
for z, (o0, o1) in BULKHEADS:
    if o0 > -HW:
        box("Bulkhead", -HW, o0, 0.0, HOLD_H, z - 0.15, z + 0.15, RIB)
    if o1 < HW:
        box("Bulkhead", o1, HW, 0.0, HOLD_H, z - 0.15, z + 0.15, RIB)
    box("BulkheadLintel", o0, o1, 3.6, HOLD_H, z - 0.15, z + 0.15, RIB)
box("CargoNet", NET[1][0], NET[1][1], 0.0, 3.6, NET[0] - 0.03, NET[0] + 0.03, NET_C)
box("HoldRoof", -HW - T, HW + T, HOLD_H, UPPER, DECK[1] + T, HOLD_Z1, SKIN)

box("Ramp", -HW, HW, -SLAB, 0.0, HOLD_Z1, RAMP_Z1, STEEL)
for side in (1, -1):
    xa, xb = sorted((side * HW, side * (HW + T)))
    box("RampSide", xa, xb, -SLAB, HOLD_H, HOLD_Z1, RAMP_Z1, SKIN)
box("RampBar", -HW, HW, 0.0, RAIL, RAMP_Z1 - RAIL_T, RAMP_Z1, STEEL)
lv.rotated("RearDoor", (0.0, UPPER + 2.4 * math.sin(math.radians(22)), HOLD_Z1 + 2.4 * math.cos(math.radians(22))),
           (2 * HW, 0.2, 4.8), OUTSIDE, rot_x=-math.radians(22))

for x0, x1, z_low, z_high in STAIRS:
    lv.ramp("Stairs", x0, x1, 0.0, UPPER, z_low, z_high, STEEL)

# --- the upper deck --------------------------------------------------------------------------------------------------


def deck_walls(z0, z1, color):
    """Side walls with a row of small windows."""
    win_y, win_h, step = UPPER + 0.95, 0.5, 2.5
    for side in (1, -1):
        xa, xb = sorted((side * HW, side * (HW + T)))
        box("DeckWallLow", xa, xb, UPPER, win_y, z0, z1, color)
        box("DeckWallHigh", xa, xb, win_y + win_h, ROOF, z0, z1, color)
        z = z0
        for i in range(int((z1 - z0) // step)):
            wz = z0 + step / 2 + i * step
            box("DeckPier", xa, xb, win_y, win_y + win_h, z, wz - 0.25, color)
            z = wz + 0.25
        box("DeckPier", xa, xb, win_y, win_y + win_h, z, z1, color)


def cross_wall(name, z0, z1, color, opening):
    """A wall across the plane at deck level; opening: (half width, height) of a doorway on the axis, or None."""
    if opening is None:
        box(name, -HW - T, HW + T, UPPER, ROOF, z0, z1, color)
        return
    hw, h = opening
    box(name, -HW - T, -hw, UPPER, ROOF, z0, z1, color)
    box(name, hw, HW + T, UPPER, ROOF, z0, z1, color)
    box(name + "Lintel", -hw, hw, UPPER + h, ROOF, z0, z1, color)


floor_slab("DeckFloor", HOLD_H, UPPER, DECK[0] - T, DECK[1] + T, STAIRS, CABIN_FLOOR)
box("DeckRoof", -HW - T, HW + T, ROOF, ROOF + SLAB, DECK[0] - T, DECK[1] + T, SKIN)
deck_walls(DECK[0], DECK_WALLS[1][0], CABIN)
deck_walls(DECK_WALLS[1][0], DECK[1], TROOP)
cross_wall("DeckAftWall", DECK[1], DECK[1] + T, TROOP, None)
for z, hw, h in DECK_WALLS:
    cross_wall("DeckWall", z - 0.1, z + 0.1, CABIN if z < DECK_WALLS[1][0] + 1 else TROOP, (hw, h))
SCREEN_Y0, SCREEN_Y1 = UPPER + 0.9, UPPER + 1.6
z0 = DECK[0]
box("Screen", -HW - T, HW + T, UPPER, SCREEN_Y0, z0 - T, z0, DARK)
box("Screen", -HW - T, HW + T, SCREEN_Y1, ROOF, z0 - T, z0, DARK)
for x in (-HW - T, -2.0, -0.07, 1.86, HW):
    box("Mullion", x, x + (T if abs(x) > 4 else 0.14), SCREEN_Y0, SCREEN_Y1, z0 - T, z0, DARK)
for s in STAIRS:
    stair_rails(s, UPPER)

# --- outside: nose, hump, wings, six engines, twin fins (unreachable decor) ------------------------------------------

box("Nose", -HW, HW, -4.5, HOLD_H, DECK[0] - T, HOLD_Z0 - T, OUTSIDE)
lv.rotated("NoseCone", (0.0, 0.0, DECK[0] - 2.0), (2 * HW - 0.8, 8.0, 3.6), OUTSIDE, rot_x=math.radians(-18))
box("Hump", -3.4, 3.4, UPPER, 6.4, DECK[1] + T, HOLD_Z1, OUTSIDE)
box("TailBoom", -2.0, 2.0, 6.4, 9.0, HOLD_Z1 - 4.0, HOLD_Z1 + 22.0, OUTSIDE)
box("Stabilizer", -15.0, 15.0, 8.6, 9.0, HOLD_Z1 + 14.0, HOLD_Z1 + 20.0, OUTSIDE)
for x in (-14.6, 14.6):   # twin fins at the stabilizer's tips
    box("Fin", x - 0.25, x + 0.25, 5.0, 18.0, HOLD_Z1 + 13.0, HOLD_Z1 + 21.0, OUTSIDE)
box("Wing", -46.0, 46.0, ROOF + SLAB, ROOF + SLAB + 0.7, -22.0, -6.0, OUTSIDE)
for x in (-31.0, -21.0, -12.0, 12.0, 21.0, 31.0):
    box("Engine", x - 1.2, x + 1.2, 4.9, 6.9, -27.0, -19.0, OUTSIDE)
    box("Pylon", x - 0.2, x + 0.2, 6.9, ROOF + SLAB, -22.0, -19.5, OUTSIDE)
for side in (1, -1):
    xa, xb = sorted((side * (HW + T), side * (HW + 1.3)))
    box("Sponson", xa, xb, -4.5, 0.6, -28.0, 22.0, OUTSIDE)

# --- lamps: few and dim ----------------------------------------------------------------------------------------------

for z in (-35.0, -24.0, -9.0, 0.0, 15.0, 33.0):
    lv.lamp("HoldLamp", (0.0, HOLD_H - 0.45, z), energy=1.0, rng=8.0, shade=(0.5, 0.05, 0.25))
for z in (-47.0, -38.0, -27.0, -12.0, -2.0, 12.0, 23.0):
    lv.lamp("DeckLamp", (0.0, ROOF - 0.4, z), energy=0.8, rng=6.5, shade=(0.5, 0.05, 0.25))
for z in (-28.0, -6.0, 6.0, 26.0):
    lv.lamp("BellyLamp", (0.0, -SLAB - 0.35, z), energy=0.7, rng=6.0, shade=(0.4, 0.05, 0.2))

KILL_HEIGHT = -15.0
lv.write(OUT, "PlaneShell")
print("deck_splits %s (Props), kill_height %g (World)" % ([round(s, 3) for s in DECK_SPLITS], KILL_HEIGHT))
