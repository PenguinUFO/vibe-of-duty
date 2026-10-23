"""Generates prefabs/levels/tower_shell.tscn: the shell of the unfinished top of a skyscraper above the clouds, at
night (FFA, 2-4 players) - three floors in part poured, the concrete core with its stairs and lift shafts, columns,
a scaffold stair, guard rails, a tower crane, the far towers piercing the clouds, the work lamps.
Read Docs/LEVEL_TOWER.md first (layout, the owner's decisions, how to check); update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_tower_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Everything else - building materials, cover,
spawn points, environment, the moon - is the hand-edited prefabs/levels/tower.tscn, which instances this shell.

Layout (30 x 30 m, floors 4 m apart):
- L0 (y 0): the last floor poured whole. Its back part (z < 3) is under L1, dark and half walled with facade
  panels; its front (z > 3) is open to the sky, columns standing with rebar on top.
- L1 (y 4): poured over the back part only. Its open edge over L0's front is a 4 m drop (inside: no harm).
- L2 (y 8): one corner and the core's roof; the crane stands on the corner.
- The core (8 x 8, centre-left): switchback stairs L0 -> L1 -> L2, and two open lift shafts going down into the dark
  (railed: looking down is free, falling in is deliberate only).
- Other ways up: a scaffold stair L0 -> L1 (front left) and two piles of material under the slab edges to vault from
  (L0 -> L1 front right, L1 -> L2) - they are hand-placed props in tower.tscn.

Nobody falls off by a misstep: the building's edges are railed (a thin solid plate 1.3 m tall: over the jump, see
level_gen.RAIL; too thin to stand on, and the vault refuses it with the drop behind) or walled by full-height facade
panels. Jumping off a prop over the rail is the deliberate way down - keep props over 0.5 m tall 3 m from the edges.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level, RAIL, RAIL_T  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "tower_shell.tscn")

F = 15.0                  # half the footprint
FLOOR = [0.0, 4.0, 8.0]   # L0, L1, L2
SLAB = 0.3
L1_Z1 = 3.0               # L1 is poured over z -F .. L1_Z1
L2_X1, L2_Z1 = 0.0, -3.0  # L2: the corner x -F .. L2_X1, z -F .. L2_Z1 (and the core's roof)
CORE = (-4.0, 4.0, -6.0, 2.0)   # outer faces
CW = 0.3                         # core wall
CI = (CORE[0] + CW, CORE[1] - CW, CORE[2] + CW, CORE[3] - CW)   # inner faces: -3.7 .. 3.7, -5.7 .. 1.7
STAIRS_X1 = -0.3                 # the stairs take the core's left part, the shafts its right part (x 0 ..)
SHAFTS = (0.0, CI[1], CI[2], CI[3])
SHAFT_SPLIT = (-2.15, -1.85)     # the wall between the two shafts
STAIR_A = (CI[0], CI[0] + 1.6)   # up the left side (towards -z) to the half landing...
STAIR_B = (STAIRS_X1 - 1.6, STAIRS_X1)   # ...and back up the right side (towards +z)
LANDING_Z = CI[2] + 1.7          # the half landing: z CI[2] .. LANDING_Z
STAIR_HOLE = (CI[0], STAIRS_X1, CI[2], -0.3)   # open over the stairs in L1 and L2
DOOR_W, DOOR_H = 1.4, 2.3
COLUMNS = (-11.25, -3.75, 3.75, 11.25)
SHAFT_BOTTOM = -40.0
DECK_SPLITS = [FLOOR[1] - SLAB / 2, FLOOR[2] - SLAB / 2]   # TrainProps.deck_splits in tower.tscn
KILL_HEIGHT = -8.0

# Albedos (lighter than the frame - Docs/DESIGN.md "Графика"): concrete warm greys, steel, dark glass.
CONCRETE = (0.5, 0.48, 0.45)
SLAB_C = (0.44, 0.42, 0.39)
CORE_C = (0.4, 0.39, 0.37)
STEEL = (0.42, 0.42, 0.41)
REBAR = (0.36, 0.3, 0.26)
GLASS = (0.24, 0.26, 0.28)       # facade panels
BODY = (0.18, 0.18, 0.19)        # the tower below, the far towers
CRANE = (0.55, 0.5, 0.4)

lv = Level(DECK_SPLITS)
box = lv.box


def floor_y0(i):
    return FLOOR[i] - SLAB


def guard(axis, at, inward, y, a0, a1):
    """A railing along an edge: a solid plate RAIL tall, as on the train (bars with a gap between them were a
    foothold: a player stood on the lower bar and jumped the top one). Thin: neither stood on nor vaulted, with the
    drop behind it. axis "x": the edge runs along x at z = at; "z": along z at x = at. inward: +1/-1 towards the
    floor."""
    c = at + inward * RAIL_T / 2
    if axis == "x":
        box("Guard", a0, a1, y, y + RAIL, c - RAIL_T / 2, c + RAIL_T / 2, STEEL)
    else:
        box("Guard", c - RAIL_T / 2, c + RAIL_T / 2, y, y + RAIL, a0, a1, STEEL)


# --- floors ----------------------------------------------------------------------------------------------------------

shaft_hole = SHAFTS
lv.slab("Slab0", [(-F, F, -F, F)], [shaft_hole], floor_y0(0), FLOOR[0], SLAB_C)
lv.slab("Slab1", [(-F, F, -F, L1_Z1)], [shaft_hole, STAIR_HOLE], floor_y0(1), FLOOR[1], SLAB_C)
lv.slab("Slab2", [(-F, L2_X1, -F, L2_Z1), (CORE[0], CORE[1], L2_Z1, CORE[3]), (L2_X1, CORE[1], CORE[2], L2_Z1)],
        [STAIR_HOLE], floor_y0(2), FLOOR[2], SLAB_C)

# The tower below L0 (round the lift shafts, which go on down into the dark).
box("Tower", -F, SHAFTS[0], -600.0, -SLAB, -F, F, BODY, decks="all")
box("Tower", SHAFTS[1], F, -600.0, -SLAB, -F, F, BODY, decks="all")
box("Tower", SHAFTS[0], SHAFTS[1], -600.0, -SLAB, -F, SHAFTS[2], BODY, decks="all")
box("Tower", SHAFTS[0], SHAFTS[1], -600.0, -SLAB, SHAFTS[3], F, BODY, decks="all")
box("ShaftBottom", SHAFTS[0], SHAFTS[1], -600.0, SHAFT_BOTTOM, SHAFTS[2], SHAFTS[3], BODY, decks="all")
box("ShaftWall", SHAFTS[0], SHAFTS[1], SHAFT_BOTTOM, -SLAB, SHAFT_SPLIT[0], SHAFT_SPLIT[1], CORE_C, decks="all")

# --- the core --------------------------------------------------------------------------------------------------------


def wall_with_doors(axis, a0, a1, b0, b1, y0, y1, doors):
    """A wall along `axis` from a0 to a1, b0 .. b1 thick, with doors [(d0, d1)] cut in it."""
    a = a0
    for d0, d1 in sorted(doors) + [(a1, a1)]:
        if d0 > a:
            if axis == "x":
                box("CoreWall", a, d0, y0, y1, b0, b1, CORE_C)
            else:
                box("CoreWall", b0, b1, y0, y1, a, d0, CORE_C)
        if d1 > d0:
            if axis == "x":
                box("Lintel", d0, d1, y0 + DOOR_H, y1, b0, b1, CORE_C)
            else:
                box("Lintel", b0, b1, y0 + DOOR_H, y1, d0, d1, CORE_C)
        a = max(a, d1)


SHAFT_DOORS = [(-4.6, -3.2), (-0.6, 0.8)]
for i in (0, 1):
    y0, y1 = FLOOR[i], FLOOR[i + 1] - SLAB
    wall_with_doors("x", CORE[0], CORE[1], CI[3], CORE[3], y0, y1, [(-2.6, -1.2)])            # front: stairs door
    wall_with_doors("x", CORE[0], CORE[1], CORE[2], CI[2], y0, y1, [])                        # back
    wall_with_doors("z", CI[2], CI[3], CORE[0], CI[0], y0, y1, [(0.0, 1.4)])                  # left: stairs door
    wall_with_doors("z", CI[2], CI[3], CI[1], CORE[1], y0, y1, SHAFT_DOORS)                   # right: the shafts
    box("CoreWall", STAIRS_X1, SHAFTS[0], y0, y1, CI[2], CI[3], CORE_C)                       # stairs | shafts
    box("ShaftWall", SHAFTS[0], SHAFTS[1], y0, y1, SHAFT_SPLIT[0], SHAFT_SPLIT[1], CORE_C)
    box("StairWall", STAIR_A[1], STAIR_B[0], y0, y1, LANDING_Z, -0.3, CORE_C)                 # between the flights
    # A rail plate across each shaft door, at the outer face: looking down the shaft is free, falling in is not.
    for d0, d1 in SHAFT_DOORS:
        box("ShaftBar", CORE[1] - RAIL_T, CORE[1], y0, y0 + RAIL, d0, d1, STEEL)
    # Switchback stairs: up the left flight to the half landing, back up the right flight to the next floor.
    mid = FLOOR[i] + 2.0
    lv.ramp("Stairs", STAIR_A[0], STAIR_A[1], FLOOR[i], mid, -0.3, LANDING_Z, CONCRETE)
    box("Landing", CI[0], STAIRS_X1, mid - SLAB, mid, CI[2], LANDING_Z, CONCRETE, decks="all")
    lv.ramp("Stairs", STAIR_B[0], STAIR_B[1], mid, FLOOR[i + 1], LANDING_Z, -0.3, CONCRETE)
# On the core's roof (L2): rails round the stair well, and round the roof's edges but for a gap to drop to L1.
y2 = FLOOR[2]
guard("z", CI[0], -1, y2, CI[2], -0.3)
guard("z", STAIRS_X1, 1, y2, CI[2], -0.3)
guard("x", -0.3, 1, y2, CI[0], STAIR_A[1])
guard("x", CORE[3], -1, y2, CORE[0], CORE[1])
guard("z", CORE[1], -1, y2, CORE[2], -2.0)
guard("z", CORE[1], -1, y2, 0.0, CORE[3])
guard("z", CORE[0], 1, y2, L2_Z1, CORE[3])
guard("x", CORE[2], 1, y2, L2_X1, CORE[1])

# --- columns, rebar --------------------------------------------------------------------------------------------------


def inside_core(x, z):
    return CORE[0] - 0.5 < x < CORE[1] + 0.5 and CORE[2] - 0.5 < z < CORE[3] + 0.5


def column(x, z, y0, y1, rebar):
    box("Column", x - 0.3, x + 0.3, y0, y1, z - 0.3, z + 0.3, CONCRETE)
    if rebar:   # bars sticking up out of the top, waiting for the next pour
        for dx, dz in ((-0.2, -0.2), (0.2, -0.2), (-0.2, 0.2), (0.2, 0.2)):
            box("Rebar", x + dx - 0.02, x + dx + 0.02, y1, y1 + 0.9, z + dz - 0.02, z + dz + 0.02, REBAR)


for x in COLUMNS:
    for z in COLUMNS:
        if inside_core(x, z):
            continue
        under_l1 = z < L1_Z1
        column(x, z, FLOOR[0], FLOOR[1] - SLAB, rebar=not under_l1)
        if under_l1:
            under_l2 = x < L2_X1 and z < L2_Z1
            if under_l2:
                column(x, z, FLOOR[1], FLOOR[2] - SLAB, rebar=False)
            else:   # a stub: the next floor's column only started
                column(x, z, FLOOR[1], FLOOR[1] + 1.2, rebar=True)

# --- edges: facade panels and railings -------------------------------------------------------------------------------

# L0: the back part has some facade panels up to L1 (full height: nothing to climb); railings elsewhere.
PANEL_T = 0.25
panels = {  # edge -> [(from, to)] along it
    "back": [(-F, -5.0), (5.0, F)],         # z = -F
    "left": [(-F, -6.0)],                   # x = -F
    "right": [(-F, -9.0), (-3.0, L1_Z1)],   # x = F
}
for a0, a1 in panels["back"]:
    box("Facade", a0, a1, FLOOR[0], FLOOR[1] - SLAB, -F, -F + PANEL_T, GLASS)
for a0, a1 in panels["left"]:
    box("Facade", -F, -F + PANEL_T, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
for a0, a1 in panels["right"]:
    box("Facade", F - PANEL_T, F, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)


def gaps(a0, a1, taken):
    out, a = [], a0
    for t0, t1 in sorted(taken):
        if t0 > a:
            out.append((a, t0))
        a = max(a, t1)
    if a < a1:
        out.append((a, a1))
    return out


for a0, a1 in gaps(-F, F, panels["back"]):
    guard("x", -F, 1, FLOOR[0], a0, a1)
guard("x", F, -1, FLOOR[0], -F, F)
for a0, a1 in gaps(-F, F, panels["left"]):
    guard("z", -F, 1, FLOOR[0], a0, a1)
for a0, a1 in gaps(-F, F, panels["right"]):
    guard("z", F, -1, FLOOR[0], a0, a1)
# L1: railed all round its outer edges; its open edge over L0's front railed in parts (gaps to drop, the scaffold).
guard("x", -F, 1, FLOOR[1], -F, F)
guard("z", -F, 1, FLOOR[1], -F, L1_Z1)
guard("z", F, -1, FLOOR[1], -F, L1_Z1)
for a0, a1 in ((-F, -10.4), (-8.4, -1.0), (1.0, 6.0), (9.0, F)):
    guard("x", L1_Z1, -1, FLOOR[1], a0, a1)
# L2's corner: the building's edges railed; its inner edges over L1 in parts.
guard("x", -F, 1, FLOOR[2], -F, L2_X1)
guard("z", -F, 1, FLOOR[2], -F, L2_Z1)
guard("z", L2_X1, -1, FLOOR[2], -F, -9.0)
for a0, a1 in ((-F, -10.0), (-6.5, CORE[0])):
    guard("x", L2_Z1, -1, FLOOR[2], a0, a1)

# Scaffold stair from L0's front up to L1's open edge, posts under it.
SCAF = (-10.2, -8.6, 10.0, L1_Z1)   # x0, x1, z at L0, z at L1
lv.ramp("Scaffold", SCAF[0], SCAF[1], FLOOR[0], FLOOR[1], SCAF[2], SCAF[3], STEEL, thick=0.15)
for z in (4.5, 7.0, 9.5):
    h = FLOOR[1] * (SCAF[2] - z) / (SCAF[2] - SCAF[3]) - 0.1
    for x in (SCAF[0], SCAF[1] - 0.06):
        box("ScaffoldPost", x, x + 0.06, 0.0, h, z, z + 0.06, STEEL)

# --- the crane on L2's corner ----------------------------------------------------------------------------------------

MAST = (-12.5, -11.0)   # x and z of the mast's square
mx, mz = sum(MAST) / 2, sum(MAST) / 2
box("CraneMast", MAST[0], MAST[1], FLOOR[2], 38.0, MAST[0], MAST[1], CRANE)
box("CraneApex", mx - 0.4, mx + 0.4, 38.0, 45.0, mz - 0.4, mz + 0.4, CRANE)
box("CraneJib", MAST[0], 34.0, 38.0, 39.4, mz - 0.6, mz + 0.6, CRANE)
box("CraneCounterJib", -24.0, MAST[0], 38.2, 39.2, mz - 0.7, mz + 0.7, CRANE)
box("CraneWeight", -23.5, -20.0, 35.5, 38.2, mz - 0.9, mz + 0.9, BODY)
box("CraneCab", MAST[1], MAST[1] + 1.6, 35.4, 37.8, mz - 0.7, mz + 0.7, CRANE)
HOOK_X = 6.0
box("CraneTrolley", HOOK_X - 0.5, HOOK_X + 0.5, 37.6, 38.0, mz - 0.5, mz + 0.5, BODY)
box("CraneCable", HOOK_X - 0.03, HOOK_X + 0.03, 14.0, 37.6, mz - 0.03, mz + 0.03, BODY)
box("CraneLoad", HOOK_X - 1.6, HOOK_X + 1.6, 12.8, 14.0, mz - 1.2, mz + 1.2, REBAR)   # out of reach above L1
lv.marker("Beacons", "Beacon", (mx, 45.6, mz))
lv.marker("Beacons", "Beacon", (33.5, 39.9, mz))

# --- far towers piercing the clouds ----------------------------------------------------------------------------------

for x, z, top, w in ((-180, -260, 30, 34), (240, -120, -10, 40), (320, 210, 55, 30), (-300, 150, 5, 44),
                     (60, 420, 20, 36), (-110, 380, -30, 50)):
    box("FarTower", x - w / 2, x + w / 2, -600.0, top, z - w / 2, z + w / 2, BODY, decks="all")
    box("FarTowerTop", x - w / 4, x + w / 4, top, top + w * 0.4, z - w / 4, z + w / 4, BODY, decks="all")
    lv.marker("Beacons", "Beacon", (x, top + w * 0.4 + 1.0, z))

# --- work lamps: pools of light in the night -------------------------------------------------------------------------

HANGING = (0.5, 0.05, 0.25)
FLOOD = (0.4, 0.08, 0.4)


def pole_lamp(x, z, floor, height=3.0):
    y = FLOOR[floor]
    box("LampPole", x - 0.05, x + 0.05, y, y + height, z - 0.05, z + 0.05, STEEL)
    lv.lamp("WorkLamp", (x, y + height - 0.15, z), energy=2.2, rng=11.0, shade=FLOOD)


lv.lamp("WorkLamp", (-9.0, FLOOR[1] - SLAB - 0.45, -9.0), energy=1.6, rng=9.0, shade=HANGING)   # L0, under L1
lv.lamp("WorkLamp", (9.0, FLOOR[1] - SLAB - 0.45, -7.0), energy=1.6, rng=9.0, shade=HANGING)
pole_lamp(10.0, 6.0, 0)
pole_lamp(-5.0, 11.0, 0)
lv.lamp("StairLamp", (-2.0, FLOOR[1] - SLAB - 0.4, 0.7), energy=1.0, rng=6.0, shade=HANGING)    # the core's landings
lv.lamp("StairLamp", (-2.0, FLOOR[2] - SLAB - 0.4, 0.7), energy=1.0, rng=6.0, shade=HANGING)
pole_lamp(9.0, -9.0, 1)
pole_lamp(-11.0, 0.0, 1)
pole_lamp(-6.0, -9.0, 2)

lv.write(OUT, "TowerShell")
print("deck_splits %s (Props), kill_height %g (World)" % ([round(s, 3) for s in DECK_SPLITS], KILL_HEIGHT))
