"""Generates prefabs/levels/train_shell.tscn: the shell of a wide double-decker train (FFA, 2-4 players) running
through a forest - eight cars: bodies, floors, walls, stairs, gangways, rails, the ground and the lamps.
Read Docs/LEVEL_TRAIN.md first (layout, the owner's decisions, how to check); update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_train_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Props, spawns, environment - the hand-edited
prefabs/levels/train.tscn, which instances this shell. The train stands still; the forest, the track and the
tunnels move past it (scripts/game/train_scenery.gd). The train runs along Z, the locomotive at -Z.

Front to back:  locomotive | A passenger | B dining | C open cargo | E mail | F flatcar | G staff | D sleeper |
H observation, with an open balcony at the tail.
- E (mail): no upper floor in the middle - a hall the full height of the car, galleries along both walls at the upper
  deck's height, a bridge across the middle, landings at both ends; a ramp in each half of the hall.
- F (flatcar): open like C, but a ring - catwalks along both sides and landings at both ends at upper-deck height
  round a pit with a tarpaulined vehicle in it (its top is the way back up to the catwalks).
- G (staff): a closed double-decker with one stair in the middle of the car instead of two at the ends: the lower
  deck's sightline through the train stops at it.
- H (observation): the panoramic upper deck of B, one stair; behind it an open balcony on the lower deck.
- A, B, D: double-deckers with stairs at both ends (B and D mirrored, B's upper deck panoramic); C: an open cargo car,
  a pit and a catwalk along its right side. The dead ends are A's front and the balcony.

Rails here are low (RAIL below, 0.8 m - the owner's call): a jump clears them, anybody can go over the edge. The open
cars' sides are 1.5 m. Doors are on the centre line: each deck is one sightline through the closed cars (the owner's
call).
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
OUT = os.path.join(ROOT, "prefabs", "levels", "train_shell.tscn")

W = 6.0            # outer width of a car
T = 0.25           # wall thickness
HW = W / 2 - T     # inner half width
L = 20.0           # car length
GAP = 1.4          # gangway length between cars
SLAB = 0.3
UPPER = 3.3        # upper deck floor height
ROOF = 6.3         # roof slab bottom
WIN_LOW, WIN_HIGH = 1.1, 2.0   # window band (0.9 m: a crouching player is 1.1 m)
WIN_W, PILLAR = 1.6, 0.8
DOOR_W, DOOR_H = 1.4, 2.3
STAIR_W, STAIR_RUN = 1.6, 6.0
C_SIDE = 1.5       # open cars' sides and ends, all one height
WALK = DOOR_W / 2 + 0.15   # half width of a gangway / platform
DECK_SPLIT = 3.15

# Albedos (scripts/game/palette.gd keeps the frame's palette; these are lighter surface colours): a shade per car - warm greys, told apart by lightness.
BODY = (0.48, 0.46, 0.42)
BODY_B = (0.52, 0.37, 0.3)
BODY_D = (0.58, 0.56, 0.51)
BODY_E = (0.4, 0.39, 0.36)    # mail: dark grey
BODY_G = (0.45, 0.38, 0.33)   # staff: brownish
BODY_H = (0.54, 0.52, 0.48)
FLOOR = (0.38, 0.36, 0.33)
ROOF_C = (0.32, 0.31, 0.3)
STEEL = (0.42, 0.42, 0.41)
UNDER = (0.16, 0.155, 0.15)
LOCO = (0.27, 0.27, 0.26)

lv = Level([DECK_SPLIT])


def box(name, x0, x1, y0, y1, z0, z1, color, m=1, decks=None):
    """m = -1 mirrors the box across the centre line (x -> -x)."""
    if m < 0:
        x0, x1 = -x1, -x0
    lv.box(name, x0, x1, y0, y1, z0, z1, color, decks=decks)


def rail_z(z, y, x0, x1, inward, name="Rail"):
    """A rail plate across the car at z (inward: +1/-1, the side it stands on)."""
    za, zb = sorted((z, z + inward * RAIL_T))
    box(name, x0, x1, y, y + RAIL, za, zb, STEEL)


def rail_x(x, y, z0, z1, inward, name="Rail"):
    xa, xb = sorted((x, x + inward * RAIL_T))
    box(name, xa, xb, y, y + RAIL, z0, z1, STEEL)


# --- pieces ----------------------------------------------------------------------------------------------------

def side_wall(x_inner, outward, z0, z1, deck_y, top_y, color, panoramic=False):
    xa, xb = sorted((x_inner, x_inner + outward * T))
    low, high = (0.9, 2.3) if panoramic else (WIN_LOW, WIN_HIGH)
    box("WallLow", xa, xb, deck_y, deck_y + low, z0, z1, color)
    box("WallHigh", xa, xb, deck_y + high, top_y, z0, z1, color)
    if panoramic:  # a transom across the tall windows: neither opening fits a crouching player
        box("Transom", xa, xb, deck_y + 1.5, deck_y + 1.65, z0, z1, color)
    length = z1 - z0
    count = max(1, int((length - PILLAR) // (WIN_W + PILLAR)))
    pillar = (length - count * WIN_W) / (count + 1)
    z = z0
    for _ in range(count + 1):
        box("Pillar", xa, xb, deck_y + low, deck_y + high, z, z + pillar, color)
        z += pillar + WIN_W


def end_wall(z_face, inward, deck_y, top_y, color, door):
    za, zb = sorted((z_face, z_face + inward * T))
    if not door:
        box("EndWall", -W / 2, W / 2, deck_y, top_y, za, zb, color)
        return
    box("EndWall", -W / 2, -DOOR_W / 2, deck_y, top_y, za, zb, color)
    box("EndWall", DOOR_W / 2, W / 2, deck_y, top_y, za, zb, color)
    box("Lintel", -DOOR_W / 2, DOOR_W / 2, deck_y + DOOR_H, top_y, za, zb, color)


def stairs(x0, x1, z_low, z_high, m=1):
    if m < 0:
        x0, x1 = -x1, -x0
    lv.ramp("Stairs", x0, x1, 0.0, UPPER, z_low, z_high, STEEL)


def upper_floor(z0, z1, holes, m=1):
    """Upper deck slab over the inner width, with holes [(x0, x1, za, zb)] (written for m = 1)."""
    if m < 0:
        holes = [(-h[1], -h[0], h[2], h[3]) for h in holes]
    lv.slab("UpperFloor", [(-HW, HW, z0, z1)], holes, UPPER - SLAB, UPPER, FLOOR)


def body(z0, color, front_door=(True, True), back_door=(True, True), panoramic_upper=False):
    """Floor, roof, the walls with windows and the end walls (doors per deck: (lower, upper)) of a closed car."""
    z1 = z0 + L
    box("Underframe", -W / 2 + 0.5, W / 2 - 0.5, -1.3, -SLAB, z0 + 1.0, z1 - 1.0, UNDER)
    box("Floor", -W / 2, W / 2, -SLAB, 0.0, z0, z1, FLOOR)
    box("Roof", -W / 2, W / 2, ROOF, ROOF + SLAB, z0, z1, ROOF_C)
    for i, (deck_y, top_y, pano) in enumerate(((0.0, UPPER, False), (UPPER, ROOF + SLAB, panoramic_upper))):
        side_wall(HW, 1, z0, z1, deck_y, top_y, color, pano)
        side_wall(-HW, -1, z0, z1, deck_y, top_y, color, pano)
        end_wall(z0, 1, deck_y, top_y, color, front_door[i])
        end_wall(z1, -1, deck_y, top_y, color, back_door[i])
    return z1


def lamps(z0, lower=True, upper=True):
    if lower:
        lv.lamp("Lamp", (0.0, UPPER - SLAB - 0.4, z0 + L / 2), energy=1.2, rng=9.0)
    if upper:
        lv.lamp("Lamp", (0.0, ROOF - 0.4, z0 + L / 2), energy=1.2, rng=9.0)


def closed_car(z0, color, m=1, front_door=True, back_door=True, panoramic_upper=False):
    """A, B, D: stairs at both ends (front stairs right, back stairs left for m = 1)."""
    z1 = body(z0, color, (front_door,) * 2, (back_door,) * 2, panoramic_upper)
    s1 = (HW - STAIR_W, HW, z0 + 1.2, z0 + 1.2 + STAIR_RUN)      # front stairs, rising backwards
    s2 = (-HW, -HW + STAIR_W, z1 - 1.2 - STAIR_RUN, z1 - 1.2)    # back stairs, rising forwards
    upper_floor(z0 + T, z1 - T, [s1, s2], m)
    stairs(s1[0], s1[1], s1[2], s1[3], m)
    stairs(s2[0], s2[1], s2[3], s2[2], m)
    box("Rail", HW - STAIR_W - RAIL_T, HW - STAIR_W, UPPER, UPPER + RAIL, s1[2], s1[3], STEEL, m=m)
    box("Rail", -HW + STAIR_W, -HW + STAIR_W + RAIL_T, UPPER, UPPER + RAIL, s2[2], s2[3], STEEL, m=m)
    lamps(z0)
    return z1


def gangway(z0, z1):
    """Covered walkway between two closed cars on both decks."""
    box("GangwayFloor", -WALK, WALK, -SLAB, 0.0, z0, z1, FLOOR)
    box("GangwayFloor", -WALK, WALK, UPPER - SLAB, UPPER, z0, z1, FLOOR)
    box("GangwayRoof", -WALK - T, WALK + T, ROOF, ROOF + SLAB, z0, z1, ROOF_C)
    box("GangwayWall", -WALK - T, -WALK, -SLAB, ROOF, z0, z1, UNDER)
    box("GangwayWall", WALK, WALK + T, -SLAB, ROOF, z0, z1, UNDER)


def platform(z0, z1):
    """An open crossing on both decks, railed, no walls (next to an open car)."""
    for y0, y1, col in ((-SLAB, 0.0, FLOOR), (UPPER - 0.2, UPPER, STEEL)):
        box("Platform", -WALK, WALK, y0, y1, z0, z1, col)
        rail_x(-WALK, y1, z0, z1, -1, "PlatformRail")
        rail_x(WALK, y1, z0, z1, 1, "PlatformRail")


def open_car_base(c0, color):
    """Floor, thin sides and ends of an open car; returns its end. The ends: a wall below C_SIDE with an opening as
    wide as the platform, and at upper-deck height a landing across the car railed on its pit side."""
    c1 = c0 + L
    box("Underframe", -W / 2 + 0.5, W / 2 - 0.5, -1.3, -SLAB, c0 + 1.0, c1 - 1.0, UNDER)
    box("Floor", -W / 2, W / 2, -SLAB, 0.0, c0, c1, FLOOR)
    # Sides thinner than the vault's MANTLE_MIN_TOP (0.15 m): nobody climbs onto their top and steps off outside.
    box("Side", HW, HW + 0.1, 0.0, C_SIDE, c0, c1, color)
    box("Side", -HW - 0.1, -HW, 0.0, C_SIDE, c0, c1, color)
    for zf, inward in ((c0, 1), (c1, -1)):
        za, zb = sorted((zf, zf + inward * 0.1))
        box("End", -W / 2, -WALK, 0.0, C_SIDE, za, zb, color)
        box("End", WALK, W / 2, 0.0, C_SIDE, za, zb, color)
        rail_z(zf, UPPER, -HW, -WALK, inward, "EndRail")
        rail_z(zf, UPPER, WALK, HW, inward, "EndRail")
    return c1


# --- C: open cargo car ---------------------------------------------------------------------------------------------

def car_c(c0):
    c1 = open_car_base(c0, BODY)
    cw0 = HW - 1.4
    box("Catwalk", cw0, HW, UPPER - 0.2, UPPER, c0, c1, STEEL)
    rail_x(cw0, UPPER, c0 + 1.5, c0 + 8.0, 1, "CatwalkRail")
    rail_x(cw0, UPPER, c0 + 12.0, c1 - 1.5, 1, "CatwalkRail")
    rail_x(HW, UPPER, c0, c1, -1, "CatwalkRail")
    for zz in (c0 + 4.0, c0 + 10.0, c0 + 16.0):
        box("CatwalkPost", HW + 0.1, HW + 0.4, 0.0, UPPER, zz, zz + 0.3, STEEL)
    for zl, za, zb in ((c0, c0, c0 + 1.5), (c1, c1 - 1.5, c1)):
        box("Landing", -HW, HW, UPPER - 0.2, UPPER, za, zb, STEEL)
        edge = zb if zl == c0 else za
        rail_z(edge, UPPER, -HW, cw0, -1 if zl == c0 else 1, "LandingRail")
        rail_x(-HW, UPPER, za, zb, 1, "LandingRail")   # the outer (left) edge
    return c1


# --- E: mail car - a full-height hall with galleries -----------------------------------------------------------------

GAL = 1.3   # gallery width


def car_e(e0):
    e1 = body(e0, BODY_E)
    land0, land1 = e0 + T + 2.0, e1 - T - 2.0      # inner edges of the end landings
    mid = e0 + L / 2
    br0, br1 = mid - 0.75, mid + 0.75               # the bridge across the middle
    gx = HW - GAL                                   # galleries' inner edges at +-gx
    holes = [(-gx, gx, land0, br0), (-gx, gx, br1, land1)]
    upper_floor(e0 + T, e1 - T, holes)
    # A ramp in each half of the hall: the front one along the left gallery up to the front landing, the back one
    # along the right gallery up to the back landing.
    ra = (-gx, -gx + 1.4)
    rb = (gx - 1.4, gx)
    lv.ramp("Stairs", ra[0], ra[1], 0.0, UPPER, land0 + STAIR_RUN, land0, STEEL)
    lv.ramp("Stairs", rb[0], rb[1], 0.0, UPPER, land1 - STAIR_RUN, land1, STEEL)
    # Rails round the holes, with gaps to drop into the hall (3.3 m, inside: no harm).
    rail_z(land0, UPPER, ra[1], gx, -1)                # front landing, beside the ramp's top
    rail_z(land1, UPPER, -gx, rb[0], 1)
    rail_z(br0, UPPER, -gx, gx, 1)                     # the bridge's sides
    rail_z(br1, UPPER, -gx, gx, -1)
    rail_x(-gx, UPPER, land0, br0, -1)                 # the left gallery along the front ramp
    rail_x(-gx, UPPER, br1 + 2.5, land1, -1)
    rail_x(gx, UPPER, land0, br0 - 2.5, 1)
    rail_x(gx, UPPER, br1, land1, 1)                   # the right gallery along the back ramp
    lv.lamp("Lamp", (0.0, UPPER - 0.6, mid - 4.5), energy=1.2, rng=9.0)    # the hall: hung low, under the galleries
    lv.lamp("Lamp", (0.0, UPPER - 0.6, mid + 4.5), energy=1.2, rng=9.0)
    lv.lamp("Lamp", (0.0, ROOF - 0.4, mid), energy=1.2, rng=10.0)
    return e1


# --- F: flatcar - a ring of catwalks round a pit ---------------------------------------------------------------------

FCW = 1.2   # catwalk width


def car_f(f0):
    f1 = open_car_base(f0, BODY_E)
    cx = HW - FCW
    for side in (1, -1):
        xa, xb = sorted((side * cx, side * HW))
        box("Catwalk", xa, xb, UPPER - 0.2, UPPER, f0 + 1.5, f1 - 1.5, STEEL)
        rail_x(side * HW, UPPER, f0, f1, -side, "CatwalkRail")
        # The inner rail has a gap in the middle, over the vehicle (whose top is the way back up).
        rail_x(side * cx, UPPER, f0 + 1.5, f0 + 6.5, side, "CatwalkRail")
        rail_x(side * cx, UPPER, f1 - 6.5, f1 - 1.5, side, "CatwalkRail")
        for zz in (f0 + 4.0, f0 + 10.0, f0 + 16.0):
            xa, xb = sorted((side * (HW + 0.1), side * (HW + 0.4)))
            box("CatwalkPost", xa, xb, 0.0, UPPER, zz, zz + 0.3, STEEL)
    for zl, za, zb in ((f0, f0, f0 + 1.5), (f1, f1 - 1.5, f1)):
        box("Landing", -HW, HW, UPPER - 0.2, UPPER, za, zb, STEEL)
        edge, inward = (zb, -1) if zl == f0 else (za, 1)
        rail_z(edge, UPPER, -cx, -WALK, inward, "LandingRail")    # the opening in the middle: drop into the pit
        rail_z(edge, UPPER, WALK, cx, inward, "LandingRail")
    return f1


# --- G: staff car - one stair in the middle --------------------------------------------------------------------------

def car_g(g0):
    g1 = body(g0, BODY_G)
    mid = g0 + L / 2
    s = (-0.8, 0.8, mid - 3.0, mid + 3.0)           # rising aft along the centre line
    upper_floor(g0 + T, g1 - T, [s])
    lv.ramp("Stairs", s[0], s[1], 0.0, UPPER, s[2], s[3], STEEL)
    rail_x(s[0], UPPER, s[2], s[3] - 1.5, -1)
    rail_x(s[1], UPPER, s[2], s[3] - 1.5, 1)
    rail_z(s[2], UPPER, s[0], s[1], -1)
    lv.lamp("Lamp", (0.0, UPPER - SLAB - 0.4, mid - 6.0), energy=1.2, rng=9.0)
    lv.lamp("Lamp", (0.0, UPPER - SLAB - 0.4, mid + 6.0), energy=1.2, rng=9.0)
    lv.lamp("Lamp", (0.0, ROOF - 0.4, mid), energy=1.2, rng=10.0)
    return g1


# --- H: observation car with an open balcony -------------------------------------------------------------------------

BALCONY = 2.5


def car_h(h0):
    h1 = body(h0, BODY_H, back_door=(True, False), panoramic_upper=True)
    s = (HW - STAIR_W, HW, h0 + 1.2, h0 + 1.2 + STAIR_RUN)   # front stairs, rising backwards (right side)
    upper_floor(h0 + T, h1 - T, [s])
    lv.ramp("Stairs", s[0], s[1], 0.0, UPPER, s[2], s[3], STEEL)
    rail_x(s[0], UPPER, s[2], s[3], -1)
    lamps(h0)
    # The balcony: a floor behind the car on the lower deck, railed on three sides, roofed by an awning.
    b1 = h1 + BALCONY
    box("Underframe", -W / 2 + 0.5, W / 2 - 0.5, -1.3, -SLAB, h1, b1 - 0.5, UNDER)
    box("Balcony", -W / 2, W / 2, -SLAB, 0.0, h1, b1, FLOOR)
    rail_x(-W / 2, 0.0, h1, b1, 1, "BalconyRail")
    rail_x(W / 2, 0.0, h1, b1, -1, "BalconyRail")
    rail_z(b1, 0.0, -W / 2, W / 2, -1, "BalconyRail")
    box("Awning", -W / 2, W / 2, UPPER - 0.2, UPPER, h1, b1, ROOF_C)
    for x in (-W / 2, W / 2 - 0.12):
        box("AwningPost", x, x + 0.12, RAIL, UPPER - 0.2, b1 - 0.12, b1, STEEL)
    return b1


# --- the train -------------------------------------------------------------------------------------------------------

CARS = 8
TOTAL = CARS * L + (CARS - 1) * GAP
z = -TOTAL / 2

box("Loco", -W / 2 + 0.2, W / 2 - 0.2, -1.3, 5.2, z - 16.0, z - 1.5, LOCO)
box("LocoCab", -W / 2 + 0.2, W / 2 - 0.2, 5.2, 6.2, z - 6.0, z - 1.5, LOCO)

starts = {}
starts["A"] = z
z = closed_car(z, BODY, front_door=False)
gangway(z, z + GAP); z += GAP
starts["B"] = z
z = closed_car(z, BODY_B, m=-1, panoramic_upper=True)
gangway(z, z + GAP); z += GAP
starts["C"] = z
z = car_c(z)
platform(z, z + GAP); z += GAP
starts["E"] = z
z = car_e(z)
platform(z, z + GAP); z += GAP
starts["F"] = z
z = car_f(z)
platform(z, z + GAP); z += GAP
starts["G"] = z
z = car_g(z)
gangway(z, z + GAP); z += GAP
starts["D"] = z
z = closed_car(z, BODY_D, m=-1)
gangway(z, z + GAP); z += GAP
starts["H"] = z
z = car_h(z)

TRAIN_Z0 = starts["A"] - 16.0
TRAIN_Z1 = z
GROUND_Y = -1.45          # the scenery's ground (scripts/game/train_scenery.gd GROUND_Y)
KILL_HEIGHT = GROUND_Y + 0.25

lv.write(OUT, "TrainShell", ground_y=GROUND_Y)
print("cars start at %s" % {k: round(v, 2) for k, v in starts.items()})
print("train z %g .. %g (Scenery train_z0 / train_z1), kill_height %g (World)" % (TRAIN_Z0, TRAIN_Z1, KILL_HEIGHT))
