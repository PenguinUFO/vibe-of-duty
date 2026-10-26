"""Generates prefabs/levels/tower_shell.tscn: the shell of the unfinished tops of two skyscrapers above the clouds, at
night (FFA, 2-4 players) - the west tower (x -15 .. 15) and the east tower (x 25 .. 49), a 10 m gap between them.
Read Docs/LEVEL_TOWER.md first (layout, the owner's decisions, how to check); update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_tower_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Props, spawns, environment, the moon, the crane's
schedule (CraneBridge) - the hand-edited prefabs/levels/tower.tscn, which instances this shell.

The west tower: L0 (y 0) poured whole, L1 (y 4) over its back (z < 3), L2 (y 8) one corner and the core's roof; the
core (x -4 .. 4, z -6 .. 2) with switchback stairs and two open lift shafts; a scaffold stair.

The east tower (floors 4 m apart, as in the west one):
- L0 (y 0): poured whole, dark (all under L1).
- L1 (y 4): poured whole, with half-built block partitions.
- L2 (y 8): the back corner (x 31 .. 49, z < -3) and the second core's roof, joined.
- A second core (x 33 .. 41, z 2 .. 10) with the same stairs L0 -> L1 -> L2 and two more lift shafts.
- A goods hoist on the east facade (decor, out of reach).

The gap (x 15 .. 25) is open down to the clouds: fall in and you die. Two ways across:
- the walkways (the owner's): one along the back facades, its mirror along the front ones, a floor below L0 (y -4).
  Out through a doorway at the west tower's west corner, down a flight along the facade, under the gap, along the
  east tower and up a flight to its L0 at its east corner (WALK).
- the crane's load - a two-storey corridor (L0 below, L1 above, a stair inside) hung from a tower crane that stands in the gap behind the
towers. The corridor docks against two doorways in each tower's facing edge (DOCKS) and now and then the crane carries
it to the other pair (scripts/game/crane_bridge.gd moves the CraneLoad node: the corridor, its lamps, the cable and
the trolley). Built here at the first dock.

The rails are low (RAIL below, 0.8 m - the owner's call): a jump clears them, anybody can go over the edge. The
lift shafts' doors are open (the owner's call): walk in and you fall 40 m. The facade panels are full height.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level, RAIL_T  # noqa: E402

# Rails are low on purpose (the owner): a jump (apex ~1.06 m) clears them, so anybody can go over
# the edge. Thin: the vault still refuses them - it is a jump, not a climb. level_gen.RAIL (1.3 m) is the high one.
RAIL = 0.8

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "tower_shell.tscn")

F = 15.0                  # half the west tower's footprint
E0, E1 = 25.0, 49.0       # the east tower's edges (x)
FLOOR = [0.0, 4.0, 8.0]
SLAB = 0.3
L1_Z1 = 3.0               # the west tower's L1 is poured over z -F .. L1_Z1
L2_X1, L2_Z1 = 0.0, -3.0  # the west tower's L2 corner
EAST_L2 = (31.0, E1, -F, -3.0)   # the east tower's L2 corner
DOCKS = [(-13.0, -9.0), (-2.0, 2.0)]   # z ranges of the doorways the corridor docks against (both towers, L0 and L1)
BRIDGE_X = (F + 0.1, E0 - 0.1)         # the corridor's ends
CW = 0.3
SHAFT_SPLIT_OFF = (-2.15, -1.85)
DOOR_W, DOOR_H = 1.4, 2.3
COLUMNS = (-11.25, -3.75, 3.75, 11.25)
EAST_COLUMNS = (30.25, 37.75, 45.25)
SHAFT_BOTTOM = -40.0
DECK_SPLITS = [FLOOR[1] - SLAB / 2, FLOOR[2] - SLAB / 2]
KILL_HEIGHT = -8.0
# The walkways a floor below L0, along the back facades (z < -F) and, mirrored, the front ones (z > F): x ranges.
WALK_Y = -4.0
WALK_W = 2.0                           # out from the facade
WALK_ENTRIES = [(-14.0, -12.0), (47.0, 48.8)]   # doorways out of L0 (west tower, east tower)
WALK_LANDING = (-F, -11.8, 47.0, E1)   # L0-level landings at both ends: west x0 .. x1, east x0 .. x1
WALK_FLIGHT = 8.0                      # the flights' run (4 m down: 27 degrees)

CONCRETE = (0.5, 0.48, 0.45)
SLAB_C = (0.44, 0.42, 0.39)
CORE_C = (0.4, 0.39, 0.37)
BLOCKWORK = (0.47, 0.44, 0.4)    # the east tower's partitions, a shade warmer than the concrete
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
    """The parts of a0 .. a1 not taken (ranges outside it are ignored)."""
    out, a = [], a0
    for t0, t1 in sorted(t for t in taken if t[1] > a0 and t[0] < a1):
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
west, east = Core(0.0, 0.0), Core(37.0, 8.0)
cores = (west, east)

# --- floors ----------------------------------------------------------------------------------------------------------

shafts = [c.shafts for c in cores]
lv.slab("Slab0", [(-F, F, -F, F), (E0, E1, -F, F)], shafts, floor_y0(0), FLOOR[0], SLAB_C)
lv.slab("Slab1", [(-F, F, -F, L1_Z1), (E0, E1, -F, F)],
        shafts + [west.stair_hole, east.stair_hole], floor_y0(1), FLOOR[1], SLAB_C)
wo, eo = west.outer, east.outer
lv.slab("Slab2", [(-F, L2_X1, -F, L2_Z1), (wo[0], wo[1], L2_Z1, wo[3]), (L2_X1, wo[1], wo[2], L2_Z1),
                  (EAST_L2[0], EAST_L2[1], EAST_L2[2], EAST_L2[3]), (eo[0], eo[1], EAST_L2[3], eo[3])],
        [west.stair_hole, east.stair_hole], floor_y0(2), FLOOR[2], SLAB_C)
# The towers below L0, round the lift shafts (which go on down into the dark).
lv.slab("Tower", [(-F, F, -F, F), (E0, E1, -F, F)], shafts, -600.0, -SLAB, BODY, decks="all")
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
for a0, a1 in ((EAST_L2[0], 32.0), (46.5, E1)):                # the corner's front edge over L1, in parts (the pile)
    guard("x", EAST_L2[3], -1, y2, a0, a1)
guard("z", EAST_L2[0], 1, y2, -F, -9.0)                        # the corner's west edge, in part

# --- columns, rebar --------------------------------------------------------------------------------------------------


def column(x, z, y0, y1, rebar):
    box("Column", x - 0.3, x + 0.3, y0, y1, z - 0.3, z + 0.3, CONCRETE)
    if rebar:
        for dx, dz in ((-0.2, -0.2), (0.2, -0.2), (-0.2, 0.2), (0.2, 0.2)):
            box("Rebar", x + dx - 0.02, x + dx + 0.02, y1, y1 + 0.9, z + dz - 0.02, z + dz + 0.02, REBAR)


def under_l1(x, z):
    return z < L1_Z1 if x < F else True


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
    "back": [(-F, WALK_ENTRIES[0][0]), (WALK_ENTRIES[0][1], -5.0), (5.0, F), (28.0, 40.0)],   # z = -F
    "left": [(-F, -6.0)],                           # x = -F
    "right": [(-8.5, -2.5)],                        # x = F, over the gap (not where the corridor docks)
    "gap": [(-7.5, -3.5), (5.0, F)],                # x = E0, over the gap
    "east": [(-F, -6.0), (6.0, F)],                 # x = E1
}
for a0, a1 in panels["back"]:
    box("Facade", a0, a1, FLOOR[0], FLOOR[1] - SLAB, -F, -F + PANEL_T, GLASS)
for a0, a1 in panels["left"]:
    box("Facade", -F, -F + PANEL_T, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
for a0, a1 in panels["right"]:
    box("Facade", F - PANEL_T, F, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
for a0, a1 in panels["gap"]:
    box("Facade", E0, E0 + PANEL_T, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
for a0, a1 in panels["east"]:
    box("Facade", E1 - PANEL_T, E1, FLOOR[0], FLOOR[1] - SLAB, a0, a1, GLASS)
# L0: railed where there is no panel; the doorways over the gap open.
for t0, t1 in ((-F, F), (E0, E1)):   # the walkways' doorways open
    for a0, a1 in gaps(t0, t1, panels["back"] + WALK_ENTRIES):
        guard("x", -F, 1, FLOOR[0], a0, a1)
    for a0, a1 in gaps(t0, t1, WALK_ENTRIES):
        guard("x", F, -1, FLOOR[0], a0, a1)
for a0, a1 in gaps(-F, F, panels["left"]):
    guard("z", -F, 1, FLOOR[0], a0, a1)
for a0, a1 in gaps(-F, F, panels["right"] + DOCKS):
    guard("z", F, -1, FLOOR[0], a0, a1)
for a0, a1 in gaps(-F, F, panels["gap"] + DOCKS):
    guard("z", E0, 1, FLOOR[0], a0, a1)
for a0, a1 in gaps(-F, F, panels["east"]):
    guard("z", E1, -1, FLOOR[0], a0, a1)
# L1, west tower: its outer edges, its open edge over L0's front in parts, its edge over the gap but for the doorways.
guard("x", -F, 1, FLOOR[1], -F, F)
guard("z", -F, 1, FLOOR[1], -F, L1_Z1)
for a0, a1 in ((-F, -10.4), (-8.4, -1.0), (1.0, 6.0), (9.0, F)):
    guard("x", L1_Z1, -1, FLOOR[1], a0, a1)
for a0, a1 in gaps(-F, L1_Z1, DOCKS):
    guard("z", F, -1, FLOOR[1], a0, a1)
# L1, east tower: the edges all round, the doorways over the gap open.
guard("x", -F, 1, FLOOR[1], E0, E1)
guard("x", F, -1, FLOOR[1], E0, E1)
guard("z", E1, -1, FLOOR[1], -F, F)
for a0, a1 in gaps(-F, F, DOCKS):
    guard("z", E0, 1, FLOOR[1], a0, a1)
# L2, west corner and east corner: the building's edges railed.
guard("x", -F, 1, FLOOR[2], -F, L2_X1)
guard("z", -F, 1, FLOOR[2], -F, L2_Z1)
guard("z", L2_X1, -1, FLOOR[2], -F, -9.0)
for a0, a1 in ((-F, -10.0), (-6.5, wo[0])):
    guard("x", L2_Z1, -1, FLOOR[2], a0, a1)
guard("x", -F, 1, FLOOR[2], EAST_L2[0], E1)
guard("z", E1, -1, FLOOR[2], -F, EAST_L2[3])

# --- the east tower's L1: half-built blockwork partitions ------------------------------------------------------------

y1 = FLOOR[1]
for x0, x1, z0, z1, h in ((29.0, 29.2, -11.0, -4.0, 2.6),     # a wall along z, a doorway's gap at its south end
                          (29.0, 32.5, -4.2, -4.0, 2.6),
                          (42.5, 45.5, -9.2, -9.0, 1.2),      # low walls: cover, not rooms
                          (43.0, 43.2, 2.0, 6.0, 1.2),
                          (28.0, 32.0, 9.8, 10.0, 2.6),
                          (31.8, 32.0, 10.0, 12.0, 2.6)):
    box("Blockwork", x0, x1, y1, y1 + h, z0, z1, BLOCKWORK)

# Scaffold stair from L0's front up to L1's open edge (the west tower's).
SCAF = (-10.2, -8.6, 10.0, L1_Z1)
lv.ramp("Scaffold", SCAF[0], SCAF[1], FLOOR[0], FLOOR[1], SCAF[2], SCAF[3], STEEL, thick=0.15)
for z in (4.5, 7.0, 9.5):
    h = FLOOR[1] * (SCAF[2] - z) / (SCAF[2] - SCAF[3]) - 0.1
    for x in (SCAF[0], SCAF[1] - 0.06):
        box("ScaffoldPost", x, x + 0.06, 0.0, h, z, z + 0.06, STEEL)

# --- the walkways a floor below L0 ----------------------------------------------------------------------------------


def x_flight(name, x_low, x_high, y_low, y_high, z0, z1, color, thick=0.25):
    """Stairs as a ramp along x: y_low at x_low up to y_high at x_high."""
    run, rise = abs(x_high - x_low), y_high - y_low
    angle = math.atan2(rise, run)
    lv.rotated(name, ((x_low + x_high) / 2, y_low + rise / 2 - thick / 2 / math.cos(angle), (z0 + z1) / 2),
               (math.hypot(run, rise), thick, z1 - z0), color, rot_z=angle if x_high > x_low else -angle, decks="all")


def x_rail_sloped(x_low, x_high, y_low, y_high, z):
    """A rail plate RAIL tall standing on a flight along x."""
    run, rise = abs(x_high - x_low), y_high - y_low
    angle = math.atan2(rise, run)
    lv.rotated("Guard", ((x_low + x_high) / 2, (y_low + y_high) / 2 + RAIL / 2, z),
               (math.hypot(run, rise), RAIL, RAIL_T), STEEL, rot_z=angle if x_high > x_low else -angle, decks="all")


wx0, wx1, ex0, ex1 = WALK_LANDING
flight_w = (wx1, wx1 + WALK_FLIGHT)      # down from the west landing, eastwards
flight_e = (ex0 - WALK_FLIGHT, ex0)      # up to the east landing
for side in (-1, 1):                     # -1 the back, +1 the front (its mirror)
    za, zb = sorted((side * F, side * (F + WALK_W)))
    outer = side * (F + WALK_W)
    box("WalkLanding", wx0, wx1, -SLAB, 0.0, za, zb, SLAB_C)
    box("WalkLanding", ex0, ex1, -SLAB, 0.0, za, zb, SLAB_C)
    x_flight("WalkStairs", flight_w[1], flight_w[0], WALK_Y, 0.0, za, zb, STEEL)
    x_flight("WalkStairs", flight_e[0], flight_e[1], WALK_Y, 0.0, za, zb, STEEL)
    box("Walkway", flight_w[1], flight_e[0], WALK_Y - SLAB, WALK_Y, za, zb, STEEL)
    # Rails: the outer edge all along, the ends, the inner edge over the gap.
    guard("x", outer, -side, 0.0, wx0, wx1)
    guard("x", outer, -side, 0.0, ex0, ex1)
    guard("x", outer, -side, WALK_Y, flight_w[1], flight_e[0])
    x_rail_sloped(flight_w[1], flight_w[0], WALK_Y, 0.0, outer - side * RAIL_T / 2)
    x_rail_sloped(flight_e[0], flight_e[1], WALK_Y, 0.0, outer - side * RAIL_T / 2)
    guard("z", wx0, 1, 0.0, za, zb)
    guard("z", ex1, -1, 0.0, za, zb)
    guard("x", side * F, side, WALK_Y, F, E0)
    # Underneath: brackets off the towers, girders along the span.
    for x in (-1.0, 7.0, 30.0, 37.0):
        box("WalkBracket", x - 0.15, x + 0.15, WALK_Y - 1.2, WALK_Y - SLAB, za, zb, STEEL)
    for z0, z1 in ((za, za + 0.2), (zb - 0.2, zb)):
        box("WalkGirder", F - 1.0, E0 + 1.0, WALK_Y - 0.9, WALK_Y - SLAB, z0, z1, CRANE)
    for x in (-2.0, 8.0, 20.0, 30.0, 38.0):   # on the towers' faces; over the gap on a post off the girder
        if F < x < E0:
            box("LampPole", x - 0.05, x + 0.05, WALK_Y, WALK_Y + 2.75, side * (F + 0.3) - 0.05, side * (F + 0.3) + 0.05,
                STEEL)
        lv.lamp("WalkLamp", (x, WALK_Y + 2.6, side * (F + 0.35)), energy=2.0, rng=8.0, shade=HANGING)

# --- the tower crane in the gap and its load, the goods hoist on the east facade -------------------------------------

# The crane stands in the gap behind the towers, its jib along z over the gap: the trolley runs along the jib and
# the load hangs under it, so the load moves along z only.
CX = (F + E0) / 2
MAST_Z = -19.5
JIB_Y = 39.0
box("CraneMast", CX - 0.75, CX + 0.75, -600.0, JIB_Y, MAST_Z - 0.75, MAST_Z + 0.75, CRANE, decks="all")
box("CraneApex", CX - 0.4, CX + 0.4, JIB_Y + 1.4, JIB_Y + 8.0, MAST_Z - 0.4, MAST_Z + 0.4, CRANE)
box("CraneJib", CX - 0.6, CX + 0.6, JIB_Y, JIB_Y + 1.4, MAST_Z, 26.0, CRANE)
box("CraneCounterJib", CX - 0.7, CX + 0.7, JIB_Y + 0.2, JIB_Y + 1.2, -33.0, MAST_Z, CRANE)
box("CraneWeight", CX - 0.9, CX + 0.9, JIB_Y - 2.5, JIB_Y + 0.2, -32.5, -29.0, BODY)
box("CraneCab", CX + 0.75, CX + 2.0, JIB_Y - 2.6, JIB_Y - 0.2, MAST_Z - 0.7, MAST_Z + 0.7, CRANE)
lv.marker("Beacons", "Beacon", (CX, JIB_Y + 8.6, MAST_Z))
lv.marker("Beacons", "Beacon", (CX, JIB_Y + 2.0, 26.0))

# The load: a two-storey corridor across the gap, at the first dock (crane_bridge.gd moves the whole group along z).
lv.group = "CraneLoad"
BX0, BX1 = BRIDGE_X
BZ0, BZ1 = DOCKS[0]
BZC = (BZ0 + BZ1) / 2
STAIR_Z1 = BZ0 + 1.4                # the stair runs along the -z wall...
STAIR_X = (17.0, 23.0)              # ...rising towards +x
HOLE_X0 = 19.0                      # the upper floor is open over the stair from here (headroom)
box("BridgeFloor", BX0, BX1, -SLAB, 0.0, BZ0, BZ1, SLAB_C)
lv.slab("BridgeDeck", [(BX0, BX1, BZ0, BZ1)], [(HOLE_X0, STAIR_X[1], BZ0, STAIR_Z1)], floor_y0(1), FLOOR[1], SLAB_C)
box("BridgeRoof", BX0, BX1, floor_y0(2), FLOOR[2], BZ0, BZ1, STEEL)
run, rise, thick = STAIR_X[1] - STAIR_X[0], FLOOR[1], 0.25
angle = math.atan2(rise, run)
lv.rotated("BridgeStairs", (sum(STAIR_X) / 2, rise / 2 - thick / 2 / math.cos(angle), (BZ0 + RAIL_T + STAIR_Z1) / 2),
           (math.hypot(run, rise), thick, STAIR_Z1 - BZ0 - RAIL_T), STEEL, rot_z=angle, decks="all")
guard("x", STAIR_Z1, 1, FLOOR[1], HOLE_X0, STAIR_X[1])     # round the stair's opening upstairs
guard("z", HOLE_X0, -1, FLOOR[1], BZ0, STAIR_Z1)
for f in (0, 1):
    y = FLOOR[f]
    top = FLOOR[f + 1] - SLAB
    for z0, z1 in ((BZ0, BZ0 + RAIL_T), (BZ1 - RAIL_T, BZ1)):   # the long sides: a parapet, windows, a beam
        box("BridgeParapet", BX0, BX1, y, y + RAIL, z0, z1, STEEL)
    for z0, z1 in ((BZ0, BZ0 + 0.2), (BZ1 - 0.2, BZ1)):
        box("BridgeBeam", BX0, BX1, y + 2.7, top, z0, z1, CRANE)
        for x in (BX0, (BX0 + BX1) / 2 - 0.1, BX1 - 0.2):
            box("BridgePost", x, x + 0.2, y, y + 2.7, z0, z1, CRANE)
lv.lamp("BridgeLamp", (BX0 + 2.5, floor_y0(1) - 0.45, BZ1 - 1.2), energy=2.0, rng=8.0, shade=HANGING)
lv.lamp("BridgeLamp", (BX1 - 2.5, floor_y0(2) - 0.45, BZ1 - 1.2), energy=2.0, rng=8.0, shade=HANGING)
# Rigging: a spreader over the roof, two slings, the cable up to the trolley on the jib.
box("Spreader", BX0 + 0.5, BX1 - 0.5, FLOOR[2] + 1.4, FLOOR[2] + 1.7, BZC - 0.2, BZC + 0.2, CRANE)
for x in (BX0 + 0.9, BX1 - 0.9):
    box("Sling", x - 0.03, x + 0.03, FLOOR[2], FLOOR[2] + 1.4, BZC - 0.03, BZC + 0.03, BODY)
box("CraneCable", CX - 0.03, CX + 0.03, FLOOR[2] + 1.7, JIB_Y - 0.4, BZC - 0.03, BZC + 0.03, BODY)
box("CraneTrolley", CX - 0.6, CX + 0.6, JIB_Y - 0.4, JIB_Y, BZC - 0.6, BZC + 0.6, BODY)
lv.group = None

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


# The west tower.
hanging_lamp(-9.0, -9.0, 0)
hanging_lamp(9.0, -7.0, 0)
pole_lamp(10.0, 6.0, 0)
pole_lamp(-5.0, 11.0, 0)
pole_lamp(9.0, -9.0, 1)
pole_lamp(-11.0, 0.0, 1)
pole_lamp(-6.0, -9.0, 2)
# The east tower: under L1 it is dark but for a few hanging lamps; L1 and L2 have their own.
hanging_lamp(28.0, -6.0, 0)
hanging_lamp(34.0, -10.0, 0)
hanging_lamp(45.0, 9.0, 0)
hanging_lamp(28.0, 6.0, 0)
hanging_lamp(35.0, -8.0, 1)
pole_lamp(45.0, 11.0, 1)
pole_lamp(28.0, -5.0, 1)
pole_lamp(45.0, -11.0, 2)

lv.write(OUT, "TowerShell")
print("deck_splits %s (Props), kill_height %g (World)" % ([round(s, 3) for s in DECK_SPLITS], KILL_HEIGHT))
print("crane load: travel %g m along z (CraneBridge)" % (DOCKS[1][0] - DOCKS[0][0]))
