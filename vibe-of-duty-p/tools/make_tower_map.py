"""Generates prefabs/levels/tower_shell.tscn: the shell of the unfinished top of a skyscraper above the clouds, at
night (FFA, 2-4 players) - 60 x 30 m: the first tower (the west half, x -15 .. 15) and an east wing built on to it.
Read Docs/LEVEL_TOWER.md first (layout, the owner's decisions, how to check); update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_tower_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Props, spawns, environment, the moon - the
hand-edited prefabs/levels/tower.tscn, which instances this shell.

The west half: L0 (y 0) poured whole, L1 (y 4) over its back (z < 3), L2 (y 8) one corner and the core's roof; the
core (x -4 .. 4, z -6 .. 2) with switchback stairs and two open lift shafts; a scaffold stair; the crane on L2.

The east wing (floors 4 m apart, as in the west half):
- L0 (y 0): poured whole. Between the halves a strip x 15 .. 21 open to the sky (L1 does not cover it).
- L1 (y 4): poured over the whole wing (x 21 .. 45), dark, with half-built block partitions; two bridges across the
  strip join it to the west half's L1.
- L2 (y 8): the wing's back corner (x 27 .. 45, z < -3) and the second core's roof, joined.
- A second core (x 29 .. 37, z 0 .. 8) with the same stairs L0 -> L1 -> L2 and two more lift shafts.
- A goods hoist on the east facade (decor, out of reach).
The west half's edge at x 15 is inside the building now: its L0 rail is gone (its facade panels stay, as partitions),
its L1 rail is cut where the bridges land.

The rails are low (RAIL below, 0.8 m - the owner's call): a jump clears them, anybody can go over the edge. The
lift shafts' doors are open (the owner's call): walk in and you fall 40 m. The facade panels are full height.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level, RAIL_T  # noqa: E402

# Rails are low on purpose (the owner): a jump (apex ~1.06 m) clears them, so anybody can go over
# the edge. Thin: the vault still refuses them - it is a jump, not a climb. level_gen.RAIL (1.3 m) is the high one.
RAIL = 0.8

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "tower_shell.tscn")

F = 15.0                  # half the west half's footprint
E1 = 45.0                 # the east wing's far edge (x)
STRIP = (15.0, 21.0)      # x: open to the sky between the halves (no L1 over it)
FLOOR = [0.0, 4.0, 8.0]
SLAB = 0.3
L1_Z1 = 3.0               # the west half's L1 is poured over z -F .. L1_Z1
L2_X1, L2_Z1 = 0.0, -3.0  # the west half's L2 corner
EAST_L2 = (27.0, E1, -F, -3.0)   # the east wing's L2 corner
BRIDGES = [(-12.0, -10.5), (-2.0, -0.5)]   # z ranges of the bridges over the strip at L1
CW = 0.3
SHAFT_SPLIT_OFF = (-2.15, -1.85)
DOOR_W, DOOR_H = 1.4, 2.3
COLUMNS = (-11.25, -3.75, 3.75, 11.25)
EAST_COLUMNS = (18.75, 26.25, 33.75, 41.25)
SHAFT_BOTTOM = -40.0
DECK_SPLITS = [FLOOR[1] - SLAB / 2, FLOOR[2] - SLAB / 2]
KILL_HEIGHT = -8.0

CONCRETE = (0.5, 0.48, 0.45)
SLAB_C = (0.44, 0.42, 0.39)
CORE_C = (0.4, 0.39, 0.37)
BLOCKWORK = (0.47, 0.44, 0.4)    # the east wing's partitions, a shade warmer than the concrete
STEEL = (0.42, 0.42, 0.41)
REBAR = (0.36, 0.3, 0.26)
GLASS = (0.24, 0.26, 0.28)
BODY = (0.18, 0.18, 0.19)
CRANE = (0.55, 0.5, 0.4)

lv = Level(DECK_SPLITS)
box = lv.box


def floor_y0(i):
    return FLOOR[i] - SLAB


def guard(axis, at, inward, y, a0, a1):
    """A railing along an edge: a solid plate RAIL tall (bars with a gap between them were a
    foothold: a player stood on the lower bar and jumped the top one). axis "x": the edge runs along x at
    z = at; "z": along z at x = at. inward: +1/-1 towards the floor."""
    c = at + inward * RAIL_T / 2
    if axis == "x":
        box("Guard", a0, a1, y, y + RAIL, c - RAIL_T / 2, c + RAIL_T / 2, STEEL)
    else:
        box("Guard", c - RAIL_T / 2, c + RAIL_T / 2, y, y + RAIL, a0, a1, STEEL)


def gaps(a0, a1, taken):
    out, a = [], a0
    for t0, t1 in sorted(taken):
        if t0 > a:
            out.append((a, t0))
        a = max(a, t1)
    if a < a1:
        out.append((a, a1))
    return out


# --- the cores -------------------------------------------------------------------------------------------------------


class Core:
    """An 8 x 8 m core with its outer faces at x ox-4 .. ox+4, z oz-6 .. oz+2 (the west core: ox 0, oz 0):
    switchback stairs on the left, two lift shafts on the right."""

    def __init__(self, ox, oz):
        self.ox, self.oz = ox, oz
        self.outer = (ox - 4.0, ox + 4.0, oz - 6.0, oz + 2.0)
        o = self.outer
        self.inner = (o[0] + CW, o[1] - CW, o[2] + CW, o[3] - CW)
        i = self.inner
        self.stairs_x1 = ox - 0.3
        self.shafts = (ox, i[1], i[2], i[3])
        self.split = (oz + SHAFT_SPLIT_OFF[0], oz + SHAFT_SPLIT_OFF[1])
        self.stair_a = (i[0], i[0] + 1.6)
        self.stair_b = (self.stairs_x1 - 1.6, self.stairs_x1)
        self.landing_z = i[2] + 1.7
        self.stair_hole = (i[0], self.stairs_x1, i[2], oz - 0.3)
        self.shaft_doors = [(oz - 4.6, oz - 3.2), (oz - 0.6, oz + 0.8)]

    def contains(self, x, z):
        o = self.outer
        return o[0] - 0.5 < x < o[1] + 0.5 and o[2] - 0.5 < z < o[3] + 0.5

    def wall_with_doors(self, axis, a0, a1, b0, b1, y0, y1, doors):
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

    def build(self):
        o, i, ox, oz = self.outer, self.inner, self.ox, self.oz
        sh = self.shafts
        box("ShaftBottom", sh[0], sh[1], -600.0, SHAFT_BOTTOM, sh[2], sh[3], BODY, decks="all")
        box("ShaftWall", sh[0], sh[1], SHAFT_BOTTOM, -SLAB, self.split[0], self.split[1], CORE_C, decks="all")
        for f in (0, 1):
            y0, y1 = FLOOR[f], FLOOR[f + 1] - SLAB
            self.wall_with_doors("x", o[0], o[1], i[3], o[3], y0, y1, [(ox - 2.6, ox - 1.2)])
            self.wall_with_doors("x", o[0], o[1], o[2], i[2], y0, y1, [])
            self.wall_with_doors("z", i[2], i[3], o[0], i[0], y0, y1, [(oz + 0.0, oz + 1.4)])
            self.wall_with_doors("z", i[2], i[3], i[1], o[1], y0, y1, self.shaft_doors)
            box("CoreWall", self.stairs_x1, sh[0], y0, y1, i[2], i[3], CORE_C)
            box("ShaftWall", sh[0], sh[1], y0, y1, self.split[0], self.split[1], CORE_C)
            box("StairWall", self.stair_a[1], self.stair_b[0], y0, y1, self.landing_z, oz - 0.3, CORE_C)
            mid = FLOOR[f] + 2.0
            lv.ramp("Stairs", self.stair_a[0], self.stair_a[1], FLOOR[f], mid, oz - 0.3, self.landing_z, CONCRETE)
            box("Landing", i[0], self.stairs_x1, mid - SLAB, mid, i[2], self.landing_z, CONCRETE, decks="all")
            lv.ramp("Stairs", self.stair_b[0], self.stair_b[1], mid, FLOOR[f + 1], self.landing_z, oz - 0.3, CONCRETE)
        lv.lamp("StairLamp", (ox - 2.0, FLOOR[1] - SLAB - 0.4, oz + 0.7), energy=1.6, rng=7.0, shade=HANGING)
        lv.lamp("StairLamp", (ox - 2.0, FLOOR[2] - SLAB - 0.4, oz + 0.7), energy=1.6, rng=7.0, shade=HANGING)

    def roof_guards(self):
        """Rails round the stair well on the core's roof (L2)."""
        i, oz, y2 = self.inner, self.oz, FLOOR[2]
        guard("z", i[0], -1, y2, i[2], oz - 0.3)
        guard("z", self.stairs_x1, 1, y2, i[2], oz - 0.3)
        guard("x", oz - 0.3, 1, y2, i[0], self.stair_a[1])


HANGING = (0.5, 0.05, 0.25)
FLOOD = (0.4, 0.08, 0.4)
west, east = Core(0.0, 0.0), Core(33.0, 8.0)
cores = (west, east)

# --- floors ----------------------------------------------------------------------------------------------------------

shafts = [c.shafts for c in cores]
lv.slab("Slab0", [(-F, E1, -F, F)], shafts, floor_y0(0), FLOOR[0], SLAB_C)
lv.slab("Slab1", [(-F, F, -F, L1_Z1), (STRIP[1], E1, -F, F)] + [(STRIP[0], STRIP[1], a, b) for a, b in BRIDGES],
        shafts + [west.stair_hole, east.stair_hole], floor_y0(1), FLOOR[1], SLAB_C)
wo, eo = west.outer, east.outer
lv.slab("Slab2", [(-F, L2_X1, -F, L2_Z1), (wo[0], wo[1], L2_Z1, wo[3]), (L2_X1, wo[1], wo[2], L2_Z1),
                  (EAST_L2[0], EAST_L2[1], EAST_L2[2], EAST_L2[3]), (eo[0], eo[1], EAST_L2[3], eo[3])],
        [west.stair_hole, east.stair_hole], floor_y0(2), FLOOR[2], SLAB_C)
# The tower below L0, round the lift shafts (which go on down into the dark).
lv.slab("Tower", [(-F, E1, -F, F)], shafts, -600.0, -SLAB, BODY, decks="all")
for core in cores:
    core.build()

# --- guards on the cores' roofs and L2's inner edges -----------------------------------------------------------------

y2 = FLOOR[2]
west.roof_guards()
guard("x", wo[3], -1, y2, wo[0], wo[1])
guard("z", wo[1], -1, y2, wo[2], -2.0)
guard("z", wo[1], -1, y2, 0.0, wo[3])
guard("z", wo[0], 1, y2, L2_Z1, wo[3])
guard("x", wo[2], 1, y2, L2_X1, wo[1])
east.roof_guards()
guard("x", eo[3], -1, y2, eo[0], eo[1])                        # the core roof's front
guard("z", eo[0], 1, y2, EAST_L2[3], eo[3])                    # its left side
guard("z", eo[1], -1, y2, EAST_L2[3], eo[3] - 4.0)             # its right side, a gap at the front to drop
for a0, a1 in ((EAST_L2[0], 28.0), (42.5, E1)):                # the corner's front edge over L1, in parts (the pile)
    guard("x", EAST_L2[3], -1, y2, a0, a1)
guard("z", EAST_L2[0], 1, y2, -F, -9.0)                        # the corner's west edge, in part

# --- columns, rebar --------------------------------------------------------------------------------------------------


def column(x, z, y0, y1, rebar):
    box("Column", x - 0.3, x + 0.3, y0, y1, z - 0.3, z + 0.3, CONCRETE)
    if rebar:
        for dx, dz in ((-0.2, -0.2), (0.2, -0.2), (-0.2, 0.2), (0.2, 0.2)):
            box("Rebar", x + dx - 0.02, x + dx + 0.02, y1, y1 + 0.9, z + dz - 0.02, z + dz + 0.02, REBAR)


def under_l1(x, z):
    return z < L1_Z1 if x < F else x > STRIP[1]


def under_l2(x, z):
    return (x < L2_X1 and z < L2_Z1) or (EAST_L2[0] < x and z < EAST_L2[3])


for x in COLUMNS + EAST_COLUMNS:
    for z in COLUMNS:
        if any(c.contains(x, z) for c in cores):
            continue
        covered = under_l1(x, z)
        column(x, z, FLOOR[0], FLOOR[1] - SLAB, rebar=not covered)
        if covered:
            if under_l2(x, z):
                column(x, z, FLOOR[1], FLOOR[2] - SLAB, rebar=False)
            else:
                column(x, z, FLOOR[1], FLOOR[1] + 1.2, rebar=True)

# --- edges: facade panels and railings -------------------------------------------------------------------------------

PANEL_T = 0.25
panels = {
    "back": [(-F, -5.0), (5.0, F), (24.0, 36.0)],   # z = -F
    "left": [(-F, -6.0)],                           # x = -F
    "right": [(-F, -9.0), (-3.0, L1_Z1)],           # x = F: inside now, partitions
    "east": [(-F, -6.0), (6.0, F)],                 # x = E1
}
for a0, a1 in panels["back"]:
    box("Facade", a0, a1, FLOOR[0], FLOOR[1] - SLAB, -F, -F + PANEL_T, GLASS)
for a0, a1 in panels["left"]:
    box("Facade", -F, -F + PANEL_T, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
for a0, a1 in panels["right"]:
    box("Facade", F - PANEL_T, F, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
for a0, a1 in panels["east"]:
    box("Facade", E1 - PANEL_T, E1, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
# L0: railed where there is no panel.
for a0, a1 in gaps(-F, E1, panels["back"]):
    guard("x", -F, 1, FLOOR[0], a0, a1)
guard("x", F, -1, FLOOR[0], -F, E1)
for a0, a1 in gaps(-F, F, panels["left"]):
    guard("z", -F, 1, FLOOR[0], a0, a1)
for a0, a1 in gaps(-F, F, panels["east"]):
    guard("z", E1, -1, FLOOR[0], a0, a1)
# L1, west half: its outer edges, its open edge over L0's front in parts, its east edge over the strip but for the
# bridges (and a gap to drop).
guard("x", -F, 1, FLOOR[1], -F, F)
guard("z", -F, 1, FLOOR[1], -F, L1_Z1)
for a0, a1 in ((-F, -10.4), (-8.4, -1.0), (1.0, 6.0), (9.0, F)):
    guard("x", L1_Z1, -1, FLOOR[1], a0, a1)
for a0, a1 in gaps(-F, L1_Z1, BRIDGES + [(-7.0, -5.0)]):
    guard("z", F, -1, FLOOR[1], a0, a1)
# L1, east wing: the building's edges all round; its west edge over the strip but for the bridges and a gap.
guard("x", -F, 1, FLOOR[1], STRIP[1], E1)
guard("x", F, -1, FLOOR[1], STRIP[1], E1)
guard("z", E1, -1, FLOOR[1], -F, F)
for a0, a1 in gaps(-F, F, BRIDGES + [(5.0, 7.0)]):
    guard("z", STRIP[1], 1, FLOOR[1], a0, a1)
for a0, a1 in BRIDGES:   # the bridges' sides: railed (4 m down to the strip, but a bridge is no place to stand)
    guard("x", a0, 1, FLOOR[1], STRIP[0], STRIP[1])
    guard("x", a1, -1, FLOOR[1], STRIP[0], STRIP[1])
# L2, west corner and east corner: the building's edges railed.
guard("x", -F, 1, FLOOR[2], -F, L2_X1)
guard("z", -F, 1, FLOOR[2], -F, L2_Z1)
guard("z", L2_X1, -1, FLOOR[2], -F, -9.0)
for a0, a1 in ((-F, -10.0), (-6.5, wo[0])):
    guard("x", L2_Z1, -1, FLOOR[2], a0, a1)
guard("x", -F, 1, FLOOR[2], EAST_L2[0], E1)
guard("z", E1, -1, FLOOR[2], -F, EAST_L2[3])

# --- the east wing's L1: half-built blockwork partitions -------------------------------------------------------------

y1 = FLOOR[1]
for x0, x1, z0, z1, h in ((25.0, 25.2, -11.0, -4.0, 2.6),     # a wall along z, a doorway's gap at its south end
                          (25.0, 28.5, -4.2, -4.0, 2.6),
                          (38.5, 41.5, -9.2, -9.0, 1.2),      # low walls: cover, not rooms
                          (39.0, 39.2, 2.0, 6.0, 1.2),
                          (24.0, 28.0, 9.8, 10.0, 2.6),
                          (27.8, 28.0, 10.0, 12.0, 2.6)):
    box("Blockwork", x0, x1, y1, y1 + h, z0, z1, BLOCKWORK)

# Scaffold stair from L0's front up to L1's open edge (the west half's).
SCAF = (-10.2, -8.6, 10.0, L1_Z1)
lv.ramp("Scaffold", SCAF[0], SCAF[1], FLOOR[0], FLOOR[1], SCAF[2], SCAF[3], STEEL, thick=0.15)
for z in (4.5, 7.0, 9.5):
    h = FLOOR[1] * (SCAF[2] - z) / (SCAF[2] - SCAF[3]) - 0.1
    for x in (SCAF[0], SCAF[1] - 0.06):
        box("ScaffoldPost", x, x + 0.06, 0.0, h, z, z + 0.06, STEEL)
# A second scaffold stair in the strip, up its east side to the east wing's L1 (against the gap in its rail).
SCAF2 = (19.4, 21.0, 12.5, 7.0)   # x0, x1, z at L0, z at L1 (at the gap 5 .. 7)
lv.ramp("Scaffold", SCAF2[0], SCAF2[1], FLOOR[0], FLOOR[1], SCAF2[2], SCAF2[3], STEEL, thick=0.15)
for z in (8.0, 10.0, 12.0):
    h = FLOOR[1] * (SCAF2[2] - z) / (SCAF2[2] - SCAF2[3]) - 0.1
    for x in (SCAF2[0], SCAF2[1] - 0.06):
        box("ScaffoldPost", x, x + 0.06, 0.0, h, z, z + 0.06, STEEL)
box("ScaffoldDeck", SCAF2[0], SCAF2[1], FLOOR[1] - 0.15, FLOOR[1], 5.0, SCAF2[3], STEEL)
guard("z", SCAF2[0], 1, FLOOR[1], 5.0, SCAF2[3] + 0.5)   # its open side towards the strip

# --- the crane on the west L2 corner, the goods hoist on the east facade ---------------------------------------------

MAST = (-12.5, -11.0)
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
box("CraneLoad", HOOK_X - 1.6, HOOK_X + 1.6, 12.8, 14.0, mz - 1.2, mz + 1.2, REBAR)
lv.marker("Beacons", "Beacon", (mx, 45.6, mz))
lv.marker("Beacons", "Beacon", (33.5, 39.9, mz))
# The hoist: a mast standing off the east facade, its cage parked well above L2.
HX = (E1 + 1.2, E1 + 2.0)
for z0 in (-1.8, 1.0):
    box("HoistMast", HX[0], HX[1], -600.0, 22.0, z0, z0 + 0.8, CRANE, decks="all")
box("HoistCage", E1 + 1.0, E1 + 4.0, 15.0, 17.6, -1.8, 1.8, STEEL)
box("HoistTie", E1, HX[0], 10.0, 10.3, -1.4, 1.4, STEEL)
lv.marker("Beacons", "Beacon", (E1 + 1.6, 22.8, 0.0))

# --- far towers piercing the clouds ----------------------------------------------------------------------------------

for x, z, top, w in ((-180, -260, 30, 34), (240, -120, -10, 40), (320, 210, 55, 30), (-300, 150, 5, 44),
                     (60, 420, 20, 36), (-110, 380, -30, 50)):
    box("FarTower", x - w / 2, x + w / 2, -600.0, top, z - w / 2, z + w / 2, BODY, decks="all")
    box("FarTowerTop", x - w / 4, x + w / 4, top, top + w * 0.4, z - w / 4, z + w / 4, BODY, decks="all")
    lv.marker("Beacons", "Beacon", (x, top + w * 0.4 + 1.0, z))

# --- work lamps ------------------------------------------------------------------------------------------------------


def pole_lamp(x, z, floor, height=3.0):
    y = FLOOR[floor]
    box("LampPole", x - 0.05, x + 0.05, y, y + height, z - 0.05, z + 0.05, STEEL)
    lv.lamp("WorkLamp", (x, y + height - 0.15, z), energy=3.2, rng=13.0, shade=FLOOD)


def hanging_lamp(x, z, floor):
    lv.lamp("WorkLamp", (x, FLOOR[floor + 1] - SLAB - 0.45, z), energy=2.4, rng=10.0, shade=HANGING)


# The west half.
hanging_lamp(-9.0, -9.0, 0)
hanging_lamp(9.0, -7.0, 0)
pole_lamp(10.0, 6.0, 0)
pole_lamp(-5.0, 11.0, 0)
pole_lamp(9.0, -9.0, 1)
pole_lamp(-11.0, 0.0, 1)
pole_lamp(-6.0, -9.0, 2)
# The east wing: under L1 it is dark but for a few hanging lamps; L1 and L2 have their own.
pole_lamp(17.0, 0.0, 0)
hanging_lamp(30.0, -10.0, 0)
hanging_lamp(41.0, 9.0, 0)
hanging_lamp(24.0, 6.0, 0)
hanging_lamp(31.0, -8.0, 1)
pole_lamp(41.0, 11.0, 1)
pole_lamp(24.0, -1.0, 1)
pole_lamp(41.0, -11.0, 2)

lv.write(OUT, "TowerShell")
print("deck_splits %s (Props), kill_height %g (World)" % ([round(s, 3) for s in DECK_SPLITS], KILL_HEIGHT))
