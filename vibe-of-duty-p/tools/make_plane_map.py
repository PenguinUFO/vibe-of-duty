"""Generates prefabs/levels/plane_shell.tscn: the shell of a big cargo plane (An-124-like; FFA, 2-4 players) flying
above the clouds by day - the hold, the upper deck with the cockpit, stairs, portholes, the open rear ramp and the
outside of the plane (wings, tail), the lamps.
Read Docs/LEVEL_PLANE.md first (layout, the owner's decisions, how to check); update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_plane_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Everything else - cargo, seats, spawn points,
environment, sun - is the hand-edited prefabs/levels/plane.tscn, which instances this shell.

The plane stands still and the clouds move past it (scripts/game/sky_scenery.gd), like the train and its forest.
It flies along -Z: the nose at -Z, the open ramp at +Z.

Layout: the hold (6.4 x 4.4 m, 40 m long) runs the whole plane; over its front half is the upper deck (cockpit at
the nose, then the crew cabin), reached by two ramps in the hold, one by each side. Inside it is dark: a few dim
lamps, and the day comes in only through the portholes, the open paratroop door and the open ramp at the back.

Nobody falls out by a misstep: the ramp's end and the side door are closed by a plate 1.3 m tall (over the jump with a margin, see level_gen.RAIL;
thinner than 0.15 m, and the drop behind it is deep, so the vault refuses it; not bars - a lower bar is a foothold). Windows are 0.5-0.7 m tall,
lower than a crouching player (1.1 m).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level, RAIL, RAIL_T  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "plane_shell.tscn")

HW = 3.2           # hold inner half width
T = 0.3            # skin thickness
HOLD_H = 4.4       # hold ceiling
SLAB = 0.3
UPPER = HOLD_H + SLAB   # upper deck floor (4.7)
UPPER_H = 2.2           # upper deck ceiling above its floor
ROOF = UPPER + UPPER_H  # 6.9
HOLD_Z0, HOLD_Z1 = -22.0, 18.0   # hold: front wall's inner face .. the ramp hinge
RAMP_Z1 = 22.0                   # end of the lowered ramp (barred)
DECK_Z0, DECK_Z1 = -30.0, -4.0   # upper deck inner faces: windscreen .. aft wall
BULKHEAD_Z = -24.0               # cockpit / cabin
CHAMFER = 0.8                    # the hold's upper corners
PORT_Y, PORT_H, PORT_W = 2.0, 0.5, 0.5   # hold portholes
PORT_STEP = 5.0
DOOR_Z0, DOOR_Z1, DOOR_H = 10.0, 11.2, 1.9   # paratroop door, right side (the sun's side)
STAIR_W = 1.4
# Ramps up to the upper deck: (x0, x1, z at the floor, z at the upper deck).
STAIR_L = (-HW, -HW + STAIR_W, -13.5, -5.0)   # left, rising aft
STAIR_R = (HW - STAIR_W, HW, -11.0, -19.5)    # right, rising forward
DECK_SPLITS = [HOLD_H + SLAB / 2]             # TrainProps.deck_splits in plane.tscn

# Albedos (Docs/DESIGN.md "Графика": lighter than the frame's palette). Warm greys; the cabin a shade lighter.
SKIN = (0.46, 0.45, 0.42)        # hold walls and ceiling
RIB = (0.3, 0.29, 0.28)
FLOOR = (0.33, 0.31, 0.29)
CABIN = (0.55, 0.52, 0.47)       # upper deck walls
CABIN_FLOOR = (0.36, 0.34, 0.31)
STEEL = (0.42, 0.42, 0.41)
OUTSIDE = (0.62, 0.62, 0.6)      # the plane seen from outside (wings, tail, nose)
DARK = (0.16, 0.155, 0.15)

lv = Level(DECK_SPLITS)
box = lv.box


def hole_ranges(side):
    """z ranges along the wall on this side (+1 right, -1 left) taken by a stair."""
    s = STAIR_R if side > 0 else STAIR_L
    return [tuple(sorted((s[2], s[3])))]


def cut(z0, z1, holes):
    """[z0, z1] without the holes."""
    out, z = [], z0
    for a, b in sorted(holes):
        if a > z:
            out.append((z, min(a, z1)))
        z = max(z, b)
    if z < z1:
        out.append((z, z1))
    return [(a, b) for a, b in out if b - a > 0.01]


def hold_wall(side, z0, z1, door=None):
    """A hold side wall from z0 to z1 with a row of portholes (and the paratroop door: (z0, z1, height))."""
    xa, xb = sorted((side * HW, side * (HW + T)))
    box("HoldWallLow", xa, xb, 0.0, PORT_Y, z0, z1, SKIN)
    box("HoldWallHigh", xa, xb, PORT_Y + PORT_H, HOLD_H, z0, z1, SKIN)
    z = z0
    ports = [z0 + PORT_STEP / 2 + i * PORT_STEP for i in range(int((z1 - z0) // PORT_STEP))]
    for pz in ports:
        box("HoldWallPier", xa, xb, PORT_Y, PORT_Y + PORT_H, z, pz - PORT_W / 2, SKIN)
        z = pz + PORT_W / 2
    box("HoldWallPier", xa, xb, PORT_Y, PORT_Y + PORT_H, z, z1, SKIN)


# --- the hold --------------------------------------------------------------------------------------------------------

box("HoldFloor", -HW - T, HW + T, -SLAB, 0.0, HOLD_Z0 - T, HOLD_Z1, FLOOR)
box("Belly", -HW + 0.2, HW - 0.2, -1.8, -SLAB, HOLD_Z0 - T, HOLD_Z1 - 2.0, DARK)
box("FrontWall", -HW - T, HW + T, 0.0, HOLD_H, HOLD_Z0 - T, HOLD_Z0, SKIN)
for side in (1, -1):
    if side > 0:  # the paratroop door cuts the right wall in two
        hold_wall(side, HOLD_Z0, DOOR_Z0)
        hold_wall(side, DOOR_Z1, HOLD_Z1)
        xa, xb = HW, HW + T
        box("DoorLintel", xa, xb, DOOR_H, HOLD_H, DOOR_Z0, DOOR_Z1, SKIN)
        box("DoorBar", xb - RAIL_T, xb, 0.0, RAIL, DOOR_Z0, DOOR_Z1, STEEL)   # a plate across, at the outer face
    else:
        hold_wall(side, HOLD_Z0, HOLD_Z1)
    # The upper corners, cut at 45 degrees, except where a stair rises through them.
    for z0, z1 in cut(HOLD_Z0, HOLD_Z1, hole_ranges(side)):
        mid = (side * (HW - CHAMFER / 2), HOLD_H - CHAMFER / 2)
        out = 0.15 / math.sqrt(2)
        lv.rotated("Chamfer", (mid[0] + side * out, mid[1] + out, (z0 + z1) / 2),
                   (CHAMFER * math.sqrt(2), 0.3, z1 - z0), SKIN, rot_z=-side * math.pi / 4)
    # Ribs (frames) on the walls every 2.5 m, skipping the stairs.
    holes = hole_ranges(side)
    for i in range(int((HOLD_Z1 - HOLD_Z0) / 2.5) + 1):
        z = HOLD_Z0 + 1.25 + i * 2.5
        if z > HOLD_Z1 - 0.5 or any(a - 0.3 < z < b + 0.3 for a, b in holes) or DOOR_Z0 - 0.3 < z < DOOR_Z1 + 0.3:
            continue
        xa, xb = sorted((side * (HW - 0.12), side * HW))
        box("Rib", xa, xb, 0.3, HOLD_H - CHAMFER, z - 0.08, z + 0.08, RIB)
for i in range(int((HOLD_Z1 - HOLD_Z0) / 2.5) + 1):   # ceiling ribs, narrow enough to miss the stair holes
    z = HOLD_Z0 + 1.25 + i * 2.5
    if z < HOLD_Z1 - 0.5:
        box("CeilingRib", -HW + STAIR_W + 0.05, HW - STAIR_W - 0.05, HOLD_H - 0.12, HOLD_H, z - 0.08, z + 0.08, RIB)
# The hold's roof behind the upper deck.
box("HoldRoof", -HW - T, HW + T, HOLD_H, UPPER, DECK_Z1 + T, HOLD_Z1, SKIN)

# The lowered ramp: a floor beyond the hinge between the tail's sides, barred at its end.
box("Ramp", -HW, HW, -SLAB, 0.0, HOLD_Z1, RAMP_Z1, STEEL)
for side in (1, -1):
    xa, xb = sorted((side * HW, side * (HW + T)))
    box("RampSide", xa, xb, -SLAB, HOLD_H, HOLD_Z1, RAMP_Z1, SKIN)
# A solid plate, not bars: a lower bar would be a foothold to jump the top one from.
box("RampBar", -HW, HW, 0.0, RAIL, RAMP_Z1 - RAIL_T, RAMP_Z1, STEEL)
# The upper rear door, swung up under the tail.
lv.rotated("RearDoor", (0.0, UPPER + 2.4 * math.sin(math.radians(22)), HOLD_Z1 + 2.4 * math.cos(math.radians(22))),
           (2 * HW, 0.2, 4.8), OUTSIDE, rot_x=-math.radians(22))

# --- stairs ----------------------------------------------------------------------------------------------------------

for x0, x1, z_low, z_high in (STAIR_L, STAIR_R):
    lv.ramp("Stairs", x0, x1, 0.0, UPPER, z_low, z_high, STEEL)

# --- the upper deck --------------------------------------------------------------------------------------------------


def upper_slab(z0, z1, holes):
    """The upper deck floor over the full width, with stair holes [(x0, x1, za, zb)]."""
    xs = sorted({-HW - T, HW + T} | {h[0] for h in holes} | {h[1] for h in holes})
    for xa, xb in zip(xs, xs[1:]):
        for za, zb in cut(z0, z1, [(min(h[2], h[3]), max(h[2], h[3])) for h in holes if h[0] <= xa and h[1] >= xb]):
            box("DeckFloor", xa, xb, HOLD_H, UPPER, za, zb, CABIN_FLOOR)


upper_slab(DECK_Z0 - T, DECK_Z1 + T, [STAIR_L, STAIR_R])
box("DeckRoof", -HW - T, HW + T, ROOF, ROOF + SLAB, DECK_Z0 - T, DECK_Z1 + T, SKIN)
# Side walls with a row of small windows.
WIN_Y, WIN_H, WIN_STEP = UPPER + 0.95, 0.5, 2.5
for side in (1, -1):
    xa, xb = sorted((side * HW, side * (HW + T)))
    box("DeckWallLow", xa, xb, UPPER, WIN_Y, DECK_Z0, DECK_Z1, CABIN)
    box("DeckWallHigh", xa, xb, WIN_Y + WIN_H, ROOF, DECK_Z0, DECK_Z1, CABIN)
    z = DECK_Z0
    for i in range(int((DECK_Z1 - DECK_Z0) // WIN_STEP)):
        wz = DECK_Z0 + WIN_STEP / 2 + i * WIN_STEP
        box("DeckPier", xa, xb, WIN_Y, WIN_Y + WIN_H, z, wz - 0.25, CABIN)
        z = wz + 0.25
    box("DeckPier", xa, xb, WIN_Y, WIN_Y + WIN_H, z, DECK_Z1, CABIN)
box("DeckAftWall", -HW - T, HW + T, UPPER, ROOF, DECK_Z1, DECK_Z1 + T, CABIN)
# Cockpit windscreen: a band 0.7 m tall with mullions.
SCREEN_Y0, SCREEN_Y1 = UPPER + 0.9, UPPER + 1.6
box("Screen", -HW - T, HW + T, UPPER, SCREEN_Y0, DECK_Z0 - T, DECK_Z0, DARK)
box("Screen", -HW - T, HW + T, SCREEN_Y1, ROOF, DECK_Z0 - T, DECK_Z0, DARK)
for x in (-HW - T, -1.3, -0.07, 1.16, HW):
    box("Mullion", x, x + (T if abs(x) > 3 else 0.14), SCREEN_Y0, SCREEN_Y1, DECK_Z0 - T, DECK_Z0, DARK)
# Bulkhead between the cockpit and the cabin, with a door in the middle.
box("Bulkhead", -HW, -0.55, UPPER, ROOF, BULKHEAD_Z - 0.1, BULKHEAD_Z + 0.1, CABIN)
box("Bulkhead", 0.55, HW, UPPER, ROOF, BULKHEAD_Z - 0.1, BULKHEAD_Z + 0.1, CABIN)
box("BulkheadLintel", -0.55, 0.55, UPPER + 2.0, ROOF, BULKHEAD_Z - 0.1, BULKHEAD_Z + 0.1, CABIN)
# Rails round the stair holes on the upper deck (their open sides; the upper ends are where the stairs come out).
box("Rail", -HW + STAIR_W, -HW + STAIR_W + RAIL_T, UPPER, UPPER + RAIL, STAIR_L[2], STAIR_L[3] - 1.5, STEEL)
box("Rail", -HW, -HW + STAIR_W, UPPER, UPPER + RAIL, STAIR_L[2], STAIR_L[2] + RAIL_T, STEEL)
box("Rail", HW - STAIR_W - RAIL_T, HW - STAIR_W, UPPER, UPPER + RAIL, STAIR_R[3] + 1.5, STAIR_R[2], STEEL)
box("Rail", HW - STAIR_W, HW, UPPER, UPPER + RAIL, STAIR_R[2] - RAIL_T, STAIR_R[2], STEEL)

# --- outside: nose, hump, wings, engines, tail (unreachable decor) ---------------------------------------------------

box("Nose", -HW, HW, -1.8, HOLD_H, DECK_Z0 - T, HOLD_Z0 - T, OUTSIDE)
lv.rotated("NoseCone", (0.0, 1.0, DECK_Z0 - 1.6), (2 * HW - 0.6, 5.2, 3.0), OUTSIDE, rot_x=math.radians(-18))
box("Hump", -2.6, 2.6, UPPER, 6.0, DECK_Z1 + T, HOLD_Z1, OUTSIDE)
box("TailBoom", -1.6, 1.6, 6.0, 8.2, HOLD_Z1 - 4.0, HOLD_Z1 + 18.0, OUTSIDE)
box("Fin", -0.25, 0.25, 8.2, 17.0, HOLD_Z1 + 9.0, HOLD_Z1 + 17.0, OUTSIDE)
box("Stabilizer", -11.0, 11.0, 7.6, 8.0, HOLD_Z1 + 12.0, HOLD_Z1 + 16.5, OUTSIDE)
box("Wing", -32.0, 32.0, ROOF + SLAB, ROOF + SLAB + 0.6, -11.0, -3.0, OUTSIDE)   # a high wing, on the roof
for x in (-17.0, -9.0, 9.0, 17.0):
    box("Engine", x - 1.1, x + 1.1, 5.0, 6.9, -15.0, -7.5, OUTSIDE)
    box("Pylon", x - 0.2, x + 0.2, 6.9, ROOF + SLAB, -11.0, -8.0, OUTSIDE)
for side in (1, -1):   # landing gear fairings along the belly
    xa, xb = sorted((side * (HW + T), side * (HW + 1.1)))
    box("Sponson", xa, xb, -1.8, 0.6, -14.0, 6.0, OUTSIDE)

# --- lamps: few and dim (the hold is dark; daylight comes through the openings) --------------------------------------

for z in (-17.0, -5.0, 7.0):
    lv.lamp("HoldLamp", (0.0, HOLD_H - 0.45, z), energy=1.0, rng=8.0, shade=(0.5, 0.05, 0.25))
for z in (-27.0, -17.5, -8.0):
    lv.lamp("DeckLamp", (0.0, ROOF - 0.4, z), energy=0.8, rng=6.5, shade=(0.5, 0.05, 0.25))

KILL_HEIGHT = -15.0
lv.write(OUT, "PlaneShell")
print("deck_splits %s (Props), kill_height %g (World)" % ([round(s, 3) for s in DECK_SPLITS], KILL_HEIGHT))
