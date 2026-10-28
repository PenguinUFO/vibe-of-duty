"""Generates prefabs/levels/elysium_shell.tscn: the shell of Elysium - a round building floating over the clouds, by
day (FFA, 2-4 players): a garden in the middle round a column, a ring of rooms round it with a roof deck on top, an
outer terrace at the edge, and to the east a piece of island with an observatory, a skybridge to it from the roof.
In the style of the owner's references (a district of Olympus, Apex Legends), the plan our own (Docs/LEVEL_ELYSIUM.md).
Read Docs/LEVEL_ELYSIUM.md first; update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_elysium_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Cover props (crates, capsules, boulders,
benches), spawns, environment, the sun - the hand-edited prefabs/levels/elysium.tscn, which instances this shell.

The disc's centre is the origin; angles (THETA) run from +x (east, the island) towards +z (south); north is -z.
Round things are flat segments (rotated boxes): a ring of n segments is an n-gon.
  r 0 .. CORE           the column, up to the spire where the ribs meet
  r CORE .. GARDEN      the garden: grass, a ring of planters, trees
  r GARDEN .. ROOMS_IN  the promenade (wood), two stairs up to the roof along the rooms' inner wall
  r ROOMS_IN .. ROOMS_OUT  eight rooms in a ring (labs), doors to the garden, the terrace and each other; the roof
                        deck over them (ROOF_Y), its pods (climbable), the four ribs
  r ROOMS_OUT .. EDGE   the outer terrace, two stairs up to the roof; a low rail at the edge (a jump clears it -
                        the owner's call for all maps), below it the clouds: a fall is death (World.kill_height)
East of the disc the island (ISLAND polygon): a stone plaza, grass, trees, the observatory (OBS, two floors, an egg
of a dome over its roof), the skybridge from the roof deck to its upper floor.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "elysium_shell.tscn")

CORE = 3.5                # the column's inradius (an octagon)
GARDEN = 10.0             # the garden's outer edge (grass inside)
PLANTER_R = (6.6, 7.2)    # the ring of planters: chest-high cover, four gaps
PLANTER_H = 0.9
ROOMS_IN, ROOMS_OUT = 16.0, 26.0   # the rooms' walls (their middles)
EDGE = 33.0               # the terrace's edge
ROOMS = 8                 # rooms in the ring, the first centred on THETA 0 (east)
IN_SEGS, OUT_SEGS = 40, 64     # segments of the inner and outer walls (5 and 8 per room)
FLOOR_SEGS = 32           # the floor and the edge rail (the terrace's rim is a 32-gon)
WALL_T = 0.3
STOREY = 4.0              # the roof deck's top (and the observatory's upper floor)
SLAB = 0.25
CEIL = STOREY - SLAB      # the walls' tops under the slabs
DOOR_H = 2.5
WIN_Y = (0.9, 2.7)        # windows: sill, top (no glass - a pane would cast a shadow; a jump takes you through)
RAIL = 0.8                # low rails everywhere (the owner): a jump clears them
RAIL_T = 0.08
RADIAL_DOOR = (18.0, 19.6)     # the doors between the rooms: r from .. to (by the garden side - a ring corridor)
STAIR_LEN, STAIR_W = 8.0, 2.3  # the stairs up to the roof: ~27 deg
LANDING = 2.6             # the landing at a stair's top, along it
GARDEN_STAIRS = (20.0, 200.0)  # THETA of their middles (they rise towards +THETA), on radius GARDEN_STAIR_R
GARDEN_STAIR_R = 13.3
TERRACE_STAIRS = (90.0, 270.0)
TERRACE_STAIR_R = 29.2
PODS = (67.5, 157.5, 247.5, 337.5)  # THETA of the pods on the roof (radius POD_R): octagons, standing on one is a
POD_R, POD_SIZE, POD_H = 21.0, 3.6, 2.4  # third level (POD_H under the mantle's reach)
RIBS = (45.0, 135.0, 225.0, 315.0)  # the ribs over the roof, from its outer edge up to the spire
RIB_FOOT = 25.0
RIB_TOP_Y = 21.0          # where they meet the column's crown
CROWN_R = 14.0            # the ring beam joining the ribs (decoration, high over everything)
SPIRE_Y = 30.0
ISLAND_OPEN = 33.75       # the terrace has no rail within this many degrees of east (6 rail segments): it runs on to
# the island. The island's edge, from the disc's rim north of east round to its rim south of it.
ISLAND = [(27.44, -18.33), (34.0, -24.0), (48.0, -32.0), (70.0, -32.0), (82.0, -20.0),
          (82.0, 20.0), (70.0, 32.0), (48.0, 32.0), (34.0, 24.0), (27.44, 18.33)]
PLAZA_X = 38.0            # stone up to here, grass beyond
OBS = (52.0, 68.0, -8.0, 8.0)   # the observatory's walls (x0, x1, z0, z1, their middles)
OBS_STAIR = (55.0, 63.0, 5.45, 7.7)  # its stair along the south wall, rising east (x low, x high, z0, z1)
BRIDGE_Z = 1.5            # the skybridge: z -1.5 .. 1.5, from the roof deck (x ROOMS_OUT) to the observatory
BRIDGE_PILLARS = (36.0, 45.0)

WHITE = (0.84, 0.85, 0.86)
STONE = (0.74, 0.75, 0.76)
BLUE = (0.2, 0.32, 0.58)
LAB = (0.38, 0.42, 0.5)
WOOD = (0.6, 0.47, 0.34)
GRASS = (0.3, 0.5, 0.3)
SOIL = (0.4, 0.33, 0.27)
TRUNK = (0.33, 0.26, 0.22)
SAKURA = (0.84, 0.56, 0.7)
CYPRESS = (0.2, 0.37, 0.25)
STEEL = (0.45, 0.47, 0.5)
HULL = (0.6, 0.62, 0.65)
CLIFF = (0.5, 0.48, 0.45)
BANNER = (0.3, 0.24, 0.42)

lv = Level([STOREY - SLAB / 2])
box = lv.box


def pol(r, theta_deg):
    t = math.radians(theta_deg)
    return (r * math.cos(t), r * math.sin(t))


def seg(name, r0, r1, theta_deg, width, y0, y1, color, cx=0.0, cz=0.0, decks=None):
    """A box from radius r0 to r1 on the ray THETA (round (cx, cz)), `width` across it (tangentially)."""
    x, z = pol((r0 + r1) / 2, theta_deg)
    lv.rotated(name, (cx + x, (y0 + y1) / 2, cz + z), (r1 - r0, y1 - y0, width), color,
               rot_y=-math.radians(theta_deg), decks=decks)


def ring(name, r0, r1, a0, a1, n_full, y0, y1, color, skip=None, decks=None):
    """An annulus r0 .. r1 from THETA a0 to a1 in segments of a full n_full-gon (flat outer faces, overlapping a
    little inside). skip(theta) -> True leaves a segment out."""
    step = 360.0 / n_full
    width = 2 * r1 * math.sin(math.radians(step / 2)) + 0.04
    k = math.ceil(a0 / step - 1e-6)
    while (k + 1) * step <= a1 + 1e-6:
        mid = (k + 0.5) * step
        if not (skip and skip(mid % 360.0)):
            seg(name, r0, r1, mid, width, y0, y1, color, decks=decks)
        k += 1


def wedge(name, r_out, n, y0, y1, color):
    """A full disc as n wedges from the centre (overlapping there)."""
    width = 2 * r_out * math.sin(math.pi / n) + 0.04
    for k in range(n):
        seg(name, -0.05, r_out, (k + 0.5) * 360.0 / n, width, y0, y1, color)


def octagon(name, cx, cz, size, y0, y1, color):
    """An octagon `size` across the flats: two squares, one turned 45 deg."""
    lv.rotated(name, (cx, (y0 + y1) / 2, cz), (size, y1 - y0, size), color)
    lv.rotated(name, (cx, (y0 + y1) / 2, cz), (size, y1 - y0, size), color, rot_y=math.pi / 4)


def wall_ring(r, n, pattern, y0=0.0, y1=CEIL, lintel=WHITE, offset=0.0):
    """A wall round the centre at radius r in n segments; pattern(i) -> "S" solid, "W" window, "D" door, "O" open."""
    step = 360.0 / n
    width = 2 * (r + WALL_T / 2) * math.sin(math.radians(step / 2)) + 0.02
    for i in range(n):
        mid = offset + (i + 0.5) * step
        kind = pattern(i)
        a, b = r - WALL_T / 2, r + WALL_T / 2
        if kind == "S":
            seg("Wall", a, b, mid, width, y0, y1, WHITE)
        elif kind == "W":
            seg("Wall", a, b, mid, width, y0, y0 + WIN_Y[0], WHITE)
            seg("Lintel", a, b, mid, width, y0 + WIN_Y[1], y1, lintel)
            seg("Mullion", a, b, mid, 0.12, y0 + WIN_Y[0], y0 + WIN_Y[1], STEEL)
        elif kind == "D":
            seg("Lintel", a, b, mid, width, y0 + DOOR_H, y1, lintel)


def rail_ring(r, a0, a1, n_full, y, gaps=()):
    """A low rail along a circle (its segments' outer faces at r), leaving out the segments whose middle falls in a gap
    (a0, a1) of THETA."""
    def skip(t):
        return any(g0 <= t <= g1 or g0 <= t - 360 <= g1 or g0 <= t + 360 <= g1 for g0, g1 in gaps)
    ring("Rail", r - RAIL_T, r, a0, a1, n_full, y, y + RAIL, WHITE, skip=skip)


def rail_line(p0, p1, y, name="Rail"):
    """A low rail from p0 to p1 (x, z) standing on y."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dz)
    lv.rotated(name, ((p0[0] + p1[0]) / 2, y + RAIL / 2, (p0[1] + p1[1]) / 2), (length, RAIL, RAIL_T), WHITE,
               rot_y=-math.atan2(dz, dx))


def tilted(name, p_low, p_high, y_low, y_high, width, color, thick=0.25):
    """Stairs as a ramp between two points (x, z): its top surface meets both floors (as Level.ramp, any heading)."""
    dx, dz = p_high[0] - p_low[0], p_high[1] - p_low[1]
    run, rise = math.hypot(dx, dz), y_high - y_low
    angle = math.atan2(rise, run)
    cy = y_low + rise / 2 - thick / 2 / math.cos(angle)
    lv.rotated(name, ((p_low[0] + p_high[0]) / 2, cy, (p_low[1] + p_high[1]) / 2),
               (width, thick, math.hypot(run, rise)), color, rot_x=-angle, rot_y=math.atan2(dx, dz), decks="all")


def ring_stair(theta_mid, rc, reach_lo, reach_hi):
    """A straight stair tangent to the circle rc at THETA theta_mid, rising towards +THETA from the ground to the roof,
    and a landing past its top reaching from reach_lo to reach_hi across it (+: outwards). Returns the THETA range the
    landing spans (for the rail gap)."""
    t = math.radians(theta_mid)
    u = (math.cos(t), math.sin(t))
    d = (-math.sin(t), math.cos(t))
    c = (rc * u[0], rc * u[1])
    at = lambda a, b: (c[0] + d[0] * a + u[0] * b, c[1] + d[1] * a + u[1] * b)
    half = STAIR_LEN / 2
    tilted("Stair", at(-half, 0), at(half, 0), 0.0, STOREY, STAIR_W, STONE)
    for side in (-1, 1):  # its sides: thin stringers in blue
        p0, p1 = at(-half, side * STAIR_W / 2), at(half, side * STAIR_W / 2)
        tilted("Stringer", p0, p1, 0.1, STOREY + 0.1, 0.1, BLUE, thick=0.35)
    mid_a, mid_b = half + LANDING / 2, (reach_lo + reach_hi) / 2
    centre = at(mid_a, mid_b)
    lv.rotated("Landing", (centre[0], STOREY - SLAB / 2, centre[1]), (reach_hi - reach_lo, SLAB, LANDING), STONE,
               rot_y=-t)
    corners = [at(a, b) for a in (half, half + LANDING) for b in (reach_lo, reach_hi)]
    angles = [math.degrees(math.atan2(p[1], p[0])) for p in corners]
    return (min(angles), max(angles)) if max(angles) - min(angles) < 180 else (min(angles) + 360, max(angles))


def tree(x, z, h=4.5, crown=3.0):
    """A sakura: a trunk and a crown of three pink boxes (low-poly), its underside over a standing player's head."""
    box("Trunk", x - 0.18, x + 0.18, 0.0, h - 1.0, z - 0.18, z + 0.18, TRUNK)
    c = crown
    lv.rotated("Blossom", (x, h - 0.3, z), (c, 1.4, c), SAKURA, rot_y=0.4)
    lv.rotated("Blossom", (x + 0.4, h + 0.6, z - 0.3), (c * 0.7, 1.0, c * 0.7), SAKURA, rot_y=1.1)
    lv.rotated("Blossom", (x - 0.5, h - 0.6, z + 0.4), (c * 0.6, 0.8, c * 0.6), SAKURA, rot_y=0.7)


def cypress(x, z, h=6.0):
    box("Cypress", x - 0.45, x + 0.45, 0.0, h, z - 0.45, z + 0.45, CYPRESS)
    box("Cypress", x - 0.3, x + 0.3, h, h + 1.0, z - 0.3, z + 0.3, CYPRESS)


# --- the disc ----------------------------------------------------------------------------------------------------------

wedge("Floor", EDGE, FLOOR_SEGS, -2.0, 0.0, STONE)
ring("Grass", CORE - 0.2, GARDEN, 0, 360, 32, -0.05, 0.03, GRASS)
ring("Deck", GARDEN, ROOMS_IN, 0, 360, 48, -0.05, 0.02, WOOD)
ring("LabFloor", ROOMS_IN, ROOMS_OUT, 0, 360, 32, -0.05, 0.02, LAB)
ring("Hull", 0.0, 30.0, 0, 360, 16, -6.0, -2.0, HULL)          # the underside, sinking into the clouds
octagon("Hull", 0, 0, 44.0, -12.0, -6.0, HULL)
octagon("Hull", 0, 0, 28.0, -30.0, -12.0, HULL)
octagon("Hull", 0, 0, 14.0, -220.0, -30.0, HULL)

# The column: an octagon to the crown, banners on its faces, a cap over the roof deck, the spire.
octagon("Column", 0, 0, 2 * CORE, 0.0, RIB_TOP_Y, WHITE)
octagon("ColumnBand", 0, 0, 2 * CORE + 0.3, 3.0, 3.5, BLUE)
octagon("ColumnCap", 0, 0, 2 * CORE + 2.0, 7.0, 8.2, WHITE)
octagon("ColumnBand", 0, 0, 2 * CORE + 2.1, 7.6, 7.9, BLUE)
octagon("Crown", 0, 0, 2 * CORE + 2.6, RIB_TOP_Y - 1.0, RIB_TOP_Y + 1.0, WHITE)
octagon("Spire", 0, 0, 1.6, RIB_TOP_Y + 1.0, SPIRE_Y, WHITE)
octagon("Spire", 0, 0, 0.6, SPIRE_Y, SPIRE_Y + 4.0, BLUE)
for k in range(4):  # banners hang on four faces
    seg("Banner", CORE + 0.02, CORE + 0.08, 22.5 + 90 * k, 1.6, 3.7, 6.6, BANNER)
    seg("BannerBar", CORE + 0.02, CORE + 0.2, 22.5 + 90 * k, 2.0, 6.6, 6.75, STEEL)

# The garden: planters in a ring with four gaps (cover), trees between them and the promenade.
ring("Planter", PLANTER_R[0], PLANTER_R[1], 0, 360, 24, 0.0, PLANTER_H, WHITE,
     skip=lambda t: any(abs((t - g + 180) % 360 - 180) < 9 for g in (0, 90, 180, 270)))
ring("Soil", PLANTER_R[0] + 0.05, PLANTER_R[1] - 0.05, 0, 360, 24, PLANTER_H, PLANTER_H + 0.05, SOIL,
     skip=lambda t: any(abs((t - g + 180) % 360 - 180) < 9 for g in (0, 90, 180, 270)))
for k in range(6):
    tree(*pol(8.6, 30 + 60 * k))
for k in range(4):
    tree(*pol(5.2, 45 + 90 * k), h=3.6, crown=2.2)
for k in range(8):  # benches facing the column on the promenade's inner side
    if k in (0, 4):
        continue
    seg("Bench", GARDEN + 0.3, GARDEN + 0.8, 22.5 + 45 * k, 2.2, 0.0, 0.45, WOOD)

# --- the ring of rooms -------------------------------------------------------------------------------------------------

room_step = 360.0 / ROOMS
start = -room_step / 2


def inner_pattern(i):
    return "SWDWS"[i % 5]


def outer_pattern(i):
    room, j = divmod(i, OUT_SEGS // ROOMS)
    return ("SWSDSWWS" if room % 2 == 0 else "SWWSDSWS")[j]


wall_ring(ROOMS_IN, IN_SEGS, inner_pattern, offset=start)
wall_ring(ROOMS_OUT, OUT_SEGS, outer_pattern, lintel=BLUE, offset=start)
for k in range(ROOMS):  # the walls between the rooms, a door by the garden side
    t = start + k * room_step
    a, b = ROOMS_IN + WALL_T / 2, ROOMS_OUT - WALL_T / 2
    seg("RoomWall", a, RADIAL_DOOR[0], t, 0.25, 0.0, CEIL, WHITE)
    seg("RoomWall", RADIAL_DOOR[1], b, t, 0.25, 0.0, CEIL, WHITE)
    seg("RoomWall", RADIAL_DOOR[0], RADIAL_DOOR[1], t, 0.25, DOOR_H, CEIL, WHITE)
    seg("Stripe", RADIAL_DOOR[1], b, t, 0.27, 0.9, 1.1, BLUE)
for k in range(ROOMS):  # in each: a curved counter (cover), a lamp
    c = k * room_step
    ring("Counter", 21.6, 22.4, c - 9, c + 9, 64, 0.0, 1.0, STEEL)
    ring("CounterTop", 21.5, 22.5, c - 9, c + 9, 64, 1.0, 1.06, WHITE)
    x, z = pol(21.0, c)
    lv.lamp("RoomLamp", (x, CEIL - 0.3, z), energy=1.2, rng=6.5, shade=(0.8, 0.05, 0.8))

# The roof deck over them, its rails (gaps where the stairs land and the bridge leaves), pods, ribs.
ring("Roof", ROOMS_IN - WALL_T / 2, ROOMS_OUT + WALL_T / 2, 0, 360, OUT_SEGS, CEIL, STOREY, WHITE)
in_gaps = [ring_stair(t, GARDEN_STAIR_R, -STAIR_W / 2, 2.9) for t in GARDEN_STAIRS]
out_gaps = [ring_stair(t, TERRACE_STAIR_R, -4.6, STAIR_W / 2) for t in TERRACE_STAIRS]
bridge_gap = math.degrees(math.atan2(BRIDGE_Z + 0.2, ROOMS_OUT))
rail_ring(ROOMS_IN - WALL_T / 2 + RAIL_T, 0, 360, IN_SEGS, STOREY, in_gaps)
rail_ring(ROOMS_OUT + WALL_T / 2, 0, 360, OUT_SEGS, STOREY, out_gaps + [(-bridge_gap, bridge_gap)])
for t in PODS:
    x, z = pol(POD_R, t)
    octagon("Pod", x, z, POD_SIZE, STOREY, STOREY + POD_H - 0.3, WHITE)
    octagon("PodTop", x, z, POD_SIZE + 0.2, STOREY + POD_H - 0.3, STOREY + POD_H, BLUE)
for k in range(4):  # solar panels between the pods: knee-high cover
    t = 22.5 + 90 * k
    seg("Panel", 19.0, 23.0, t, 2.0, STOREY, STOREY + 0.7, BLUE)

n = 8
phi_top = math.acos(CORE / RIB_FOOT)
for t in RIBS:  # each an arc of an ellipse r = RIB_FOOT cos(phi), y = STOREY + rise sin(phi)
    rise = RIB_TOP_Y - STOREY
    pts = [(RIB_FOOT * math.cos(phi_top * i / n), STOREY + rise * math.sin(phi_top * i / n)) for i in range(n + 1)]
    for (r0, y0), (r1, y1) in zip(pts, pts[1:]):
        x, z = pol((r0 + r1) / 2, t)
        length = math.hypot(r0 - r1, y1 - y0) + 0.3
        lv.rotated("Rib", (x, (y0 + y1) / 2, z), (length, 0.9, 0.7), WHITE,
                   rot_z=math.atan2(y0 - y1, r0 - r1), rot_y=-math.radians(t))
    x, z = pol(RIB_FOOT, t)
    octagon("RibFoot", x, z, 1.6, STOREY, STOREY + 1.0, BLUE)
crown_y = STOREY + (RIB_TOP_Y - STOREY) * math.sin(math.acos(CROWN_R / RIB_FOOT))
ring("CrownRing", CROWN_R - 0.3, CROWN_R + 0.3, 0, 360, 12, crown_y - 0.3, crown_y + 0.3, WHITE)

# --- the terrace -------------------------------------------------------------------------------------------------------

rail_ring(EDGE, ISLAND_OPEN, 360 - ISLAND_OPEN, FLOOR_SEGS, 0.0)
for k in range(12):  # lamp posts along the edge (decoration: the lamps are the sun's job by day)
    t = 15 + 30 * k
    if abs((t + 180) % 360 - 180) < ISLAND_OPEN:
        continue
    x, z = pol(EDGE - 0.8, t)
    box("LampPost", x - 0.08, x + 0.08, 0.0, 3.2, z - 0.08, z + 0.08, STEEL)
    box("LampHead", x - 0.35, x + 0.35, 3.2, 3.3, z - 0.35, z + 0.35, WHITE)

# --- the island --------------------------------------------------------------------------------------------------------


def island_x(z):
    """The island's west and east edges at z (the west: the disc's rim inside the polygon's join)."""
    xs = []
    pts = ISLAND
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        if min(z0, z1) <= z <= max(z0, z1) and z0 != z1:
            xs.append(x0 + (x1 - x0) * (z - z0) / (z1 - z0))
    if abs(z) <= ISLAND[-1][1]:
        xs.append(math.sqrt(EDGE * EDGE - z * z) - 1.0)  # under the disc's rim, overlapping its floor (same stone)
    return min(xs), max(xs)


strips = {"Plaza": [], "Lawn": []}   # (z0, z1, x0, x1)
z = -32.0
while z < 32.0 - 1e-6:  # the ground in strips, each as wide as the island anywhere across it (teeth outside the rail):
    # 0.5 m where an edge runs slanted, 2 m where the plaza's edge is under the disc
    step = 2.0 if abs(z) < 16.0 and abs(z + 2.0) <= 16.0 else 0.5
    za, zb = z, z + step
    x0 = min(island_x(za)[0], island_x(zb)[0])
    x1 = max(island_x(za)[1], island_x(zb)[1])
    for name, a, b in (("Plaza", x0, min(PLAZA_X, x1)), ("Lawn", max(PLAZA_X, x0), x1)):
        if b > a:
            last = strips[name][-1] if strips[name] else None
            if last and abs(last[1] - za) < 1e-6 and abs(last[2] - a) < 1e-3 and abs(last[3] - b) < 1e-3:
                strips[name][-1] = (last[0], zb, a, b)   # the same across: one longer strip
            else:
                strips[name].append((za, zb, a, b))
    z += step
for name, color in (("Plaza", STONE), ("Lawn", GRASS)):
    for za, zb, a, b in strips[name]:
        box(name, a, b, -2.0, 0.0, za, zb, color)
for (x0, z0), (x1, z1) in zip(ISLAND, ISLAND[1:]):
    rail_line((x0, z0), (x1, z1), 0.0)
box("Path", PLAZA_X, OBS[0], -0.05, 0.02, -1.5, 1.5, STONE)          # paths across the lawn
box("Path", 58.5, 61.5, -0.05, 0.02, -31.0, OBS[2], STONE)
box("Path", 58.5, 61.5, -0.05, 0.02, OBS[3], 31.0, STONE)
box("Path", OBS[1], 81.0, -0.05, 0.02, -1.5, 1.5, STONE)
box("Cliff", 30.0, 78.0, -10.0, -2.0, -26.0, 26.0, CLIFF)           # its underside, sinking into the clouds
box("Cliff", 40.0, 72.0, -40.0, -10.0, -18.0, 18.0, CLIFF)
lv.rotated("Cliff", (56.0, -120.0, 2.0), (20.0, 160.0, 16.0), CLIFF, rot_y=0.5)
for x, z in ((42, -20), (52, -26), (74, -14), (76, 12), (52, 26), (42, 18)):
    tree(x, z)
for x, z in ((40.0, -9.0), (40.0, 9.0), (46.0, -12.0), (46.0, 12.0), (78.0, -4.0), (78.0, 4.0)):
    cypress(x, z)
for zs in (-1, 1):  # two pavilions on the lawn: a roof on four posts over a counter
    cz = zs * 21.0
    for px in (64.0, 70.0):
        for pz in (cz - 2.0, cz + 2.0):
            box("Post", px - 0.12, px + 0.12, 0.0, 2.8, pz - 0.12, pz + 0.12, STEEL)
    box("Canopy", 63.4, 70.6, 2.8, 3.0, cz - 2.6, cz + 2.6, WHITE)
    box("CanopyBand", 63.3, 70.7, 2.6, 2.8, cz - 2.65, cz + 2.65, BLUE)
    box("Kiosk", 65.0, 69.0, 0.0, 1.1, cz - 0.5, cz + 0.5, WHITE)

# --- the observatory ---------------------------------------------------------------------------------------------------

OX0, OX1, OZ0, OZ1 = OBS
T2 = WALL_T / 2
CX, CZ = (OX0 + OX1) / 2, (OZ0 + OZ1) / 2


def obs_wall_x(z, holes, y0):
    """A storey of a wall along x at z: holes [(xa, xb, ya, yb)] relative to the storey's floor y0."""
    x = OX0 - T2
    for xa, xb, ya, yb in holes:
        box("ObsWall", x, xa, y0, y0 + STOREY, z - T2, z + T2, WHITE)
        if ya > 0:
            box("ObsWall", xa, xb, y0, y0 + ya, z - T2, z + T2, WHITE)
        box("ObsLintel", xa, xb, y0 + yb, y0 + STOREY, z - T2, z + T2, BLUE)
        x = xb
    box("ObsWall", x, OX1 + T2, y0, y0 + STOREY, z - T2, z + T2, WHITE)


def obs_wall_z(x, holes, y0):
    z = OZ0 + T2
    for za, zb, ya, yb in holes:
        box("ObsWall", x - T2, x + T2, y0, y0 + STOREY, z, za, WHITE)
        if ya > 0:
            box("ObsWall", x - T2, x + T2, y0, y0 + ya, za, zb, WHITE)
        box("ObsLintel", x - T2, x + T2, y0 + yb, y0 + STOREY, za, zb, BLUE)
        z = zb
    box("ObsWall", x - T2, x + T2, y0, y0 + STOREY, z, OZ1 - T2, WHITE)


door = (0.0, DOOR_H)
win = WIN_Y
obs_wall_x(OZ0, [(54.0, 56.0) + win, (59.0, 61.0) + door, (64.0, 66.0) + win], 0.0)   # the ground floor
obs_wall_x(OZ1, [(54.5, 56.5) + win, (64.5, 66.5) + door], 0.0)   # the stair runs along it
obs_wall_z(OX0, [(-5.0, -3.0) + door, (2.0, 4.0) + win], 0.0)
obs_wall_z(OX1, [(-4.0, -2.0) + win, (-1.0, 1.0) + door, (2.0, 4.0) + win], 0.0)
obs_wall_x(OZ0, [(54.0, 56.0) + win, (59.0, 61.0) + win, (64.0, 66.0) + win], STOREY)   # upstairs
obs_wall_x(OZ1, [(54.0, 56.0) + win, (64.0, 66.0) + win], STOREY)
obs_wall_z(OX0, [(-5.0, -3.0) + win, (-BRIDGE_Z, BRIDGE_Z) + door, (3.0, 5.0) + win], STOREY)
obs_wall_z(OX1, [(-4.0, -2.0) + win, (2.0, 4.0) + win], STOREY)
box("ObsFloor", OX0, OX1, -0.05, 0.02, OZ0, OZ1, LAB)
hole = (OBS_STAIR[0] + 2.8, OBS_STAIR[1], OBS_STAIR[2] - 0.15, OZ1 - T2)   # over the stair's upper part (headroom)
lv.slab("ObsSlab", [(OX0 - T2, OX1 + T2, OZ0 - T2, OZ1 + T2)], [hole], CEIL, STOREY, WHITE)
lv.slab("ObsRoof", [(OX0 - T2, OX1 + T2, OZ0 - T2, OZ1 + T2)], [], 2 * STOREY - SLAB, 2 * STOREY, WHITE)
tilted("ObsStair", (OBS_STAIR[0], (OBS_STAIR[2] + OBS_STAIR[3]) / 2), (OBS_STAIR[1], (OBS_STAIR[2] + OBS_STAIR[3]) / 2),
       0.0, STOREY, OBS_STAIR[3] - OBS_STAIR[2], STONE)
box("Rail", hole[0] - RAIL_T, hole[0], STOREY, STOREY + RAIL, hole[2], hole[3], WHITE)           # round the hole
box("Rail", hole[0], hole[1], STOREY, STOREY + RAIL, hole[2] - RAIL_T, hole[2], WHITE)
box("Parapet", OX0 - T2, OX1 + T2, 2 * STOREY, 2 * STOREY + 1.0, OZ0 - T2, OZ0 + T2, WHITE)
box("Parapet", OX0 - T2, OX1 + T2, 2 * STOREY, 2 * STOREY + 1.0, OZ1 - T2, OZ1 + T2, WHITE)
box("Parapet", OX0 - T2, OX0 + T2, 2 * STOREY, 2 * STOREY + 1.0, OZ0, OZ1, WHITE)
box("Parapet", OX1 - T2, OX1 + T2, 2 * STOREY, 2 * STOREY + 1.0, OZ0, OZ1, WHITE)
# Downstairs the lab round a pillar: a square counter with gaps; upstairs desks.
box("ObsPillar", CX - 0.8, CX + 0.8, 0.0, CEIL, CZ - 0.8, CZ + 0.8, BLUE)
for sx, sz, w, d in ((0, -3, 4.0, 0.7), (0, 3, 4.0, 0.7), (-3, 0, 0.7, 4.0), (3, 0, 0.7, 4.0)):
    box("ObsCounter", CX + sx - w / 2, CX + sx + w / 2, 0.0, 1.0, CZ + sz - d / 2, CZ + sz + d / 2, STEEL)
for x0, z0, x1, z1 in ((54.0, -6.5, 57.0, -5.7), (63.0, -6.5, 66.0, -5.7), (64.5, -2.0, 65.3, 2.0), (55.5, 1.0, 58.5, 1.8)):
    box("ObsDesk", x0, x1, STOREY, STOREY + 1.0, z0, z1, STEEL)
for x, z, y in ((56.0, -4.0, CEIL - 0.3), (64.0, 3.0, CEIL - 0.3), (57.0, -3.0, 2 * STOREY - SLAB - 0.3),
                (63.0, 2.0, 2 * STOREY - SLAB - 0.3)):
    lv.lamp("ObsLamp", (x, y, z), energy=1.2, rng=6.5, shade=(0.8, 0.05, 0.8))
# The egg over the roof: octagons narrowing upwards, a blue band.
y = 2 * STOREY
for size, h, color in ((13.0, 2.0, WHITE), (12.4, 3.0, WHITE), (11.0, 0.6, BLUE), (10.6, 2.4, WHITE),
                       (8.4, 2.4, WHITE), (5.4, 1.6, WHITE), (2.4, 1.0, WHITE)):
    octagon("Dome", CX, CZ, size, y, y + h, color)
    y += h

# --- the skybridge -----------------------------------------------------------------------------------------------------

bx0, bx1 = ROOMS_OUT - 0.4, OX0 - T2
box("Bridge", bx0, bx1, CEIL, STOREY, -BRIDGE_Z, BRIDGE_Z, WHITE)
box("BridgeBand", bx0, bx1, CEIL - 0.35, CEIL, -BRIDGE_Z, BRIDGE_Z, BLUE)
for zs in (-1, 1):
    z_out = zs * BRIDGE_Z
    box("Rail", ROOMS_OUT + WALL_T / 2 + 0.2, bx1, STOREY, STOREY + RAIL, min(z_out, z_out - zs * RAIL_T),
        max(z_out, z_out - zs * RAIL_T), WHITE)
for x in BRIDGE_PILLARS:
    box("BridgePillar", x - 0.35, x + 0.35, 0.0, CEIL - 0.35, -0.35, 0.35, WHITE)

lv.write(OUT, "ElysiumShell")
