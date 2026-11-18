"""Generates prefabs/levels/gigachurch_shell.tscn: the shell of the Gigachurch - a colossal cathedral rebuilt by the AI
as a TV megachurch for the pigs, at dusk (FFA / TDM, 2-8 players). Read Docs/LEVEL_GIGACHURCH.md first; update it with
any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_gigachurch_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Cover props (the stage gear, the organ console),
spawns, the sun and the rose window - the hand-edited prefabs/levels/gigachurch.tscn, which instances this shell.

The plan (north is -z, east +x; the altar is east):
  x -50 .. -42                the narthex (a low room), the choir loft over it at 6.5
  x -50 .. 18, z +-11         the nave, 18 m high, columns every 8 m; the 60 m sightline is open - the studio
                              wall that used to cut it is gone (owner, 2026-11-18)
  x -50 .. 18, z 11 .. 18     the side aisles; the second floor is the old gallery ceiling's top at 9.75 (the
                              low 6.5 gallery is gone), with a low 0.8 m sill as its bortik and the old
                              clerestory window band above it an open slot (owner, 2026-11-18); two catwalks
                              bridge the nave between the galleries (the upper loop)
  x -50 .. 18, z 18 .. 24     the chapel bands (6.5 m high, arches to the aisles); over each a sealed attic,
                              walled off from the transept arm by the gable at x 18
  x 18 .. 32, z -24 .. 24     the transept; the crossing dome is at (25, 0)
  x 32 .. 52, z -12 .. 12     the apse: the choir (0.6), the stage (1.2), the backstage (0.6), side corridors

The crypt is gone (owner, 2026-11-17): the game runs on two decks, the ground and the galleries. The outer
windows are sealed with stained glass (the clerestory band above the second floor's sill is an open slot now,
owner, 2026-11-18); since the dusk sun cannot enter physically, every pane gets a warm lamp just inside it -
the "sun through the glass" pools (GLASS_LIGHT).

The shell holds the architecture and the lamps; the level scene holds the furniture and the spawns.
Deck layers (Level.splits): the ground (6.375) and the gallery/upper (render layers 4/8); tall walls and columns
pass decks="all" so every deck's lamps light them.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from level_gen import Level  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "gigachurch_shell.tscn")

# --- plan --------------------------------------------------------------------------------------------------------------
WEST, EAST = -50.0, 52.0
NORTH, SOUTH = -24.0, 24.0
NARTHEX_E, NAVE_E, TRANSEPT_E = -42.0, 18.0, 32.0
NAVE_Z, AISLE_Z = 11.0, 18.0
APSE_N, APSE_S = -12.0, 12.0
WALL = 0.5

FLOOR = 0.0
GALLERY_Y, GALLERY_CEIL = 6.5, 9.5
CHAPEL_CEIL = 6.5
NAVE_CEIL = 18.0
STAGE_Y, CHOIR_Y, BACKSTAGE_CEIL = 1.2, 0.6, 4.2

RAIL, RAIL_T = 0.8, 0.08

# --- colours (albedo: lighter than the final frame, Docs/VISUAL.md) ----------------------------------------------------
STONE = (0.33, 0.32, 0.30)
STONE_D = (0.26, 0.25, 0.24)
STONE_L = (0.40, 0.38, 0.35)
FLOOR_C = (0.30, 0.29, 0.27)
COLUMN = (0.42, 0.39, 0.34)
WOOD = (0.48, 0.34, 0.23)
WOOD_D = (0.38, 0.27, 0.19)
IRON = (0.30, 0.30, 0.29)
GOLD = (0.62, 0.46, 0.16)
SCREEN = (0.10, 0.10, 0.11)
CARPET = (0.23, 0.10, 0.08)
WALL_C = (0.36, 0.35, 0.32)
LED_BLUE = (0.10, 0.30, 0.62)
# Stained glass (backlit from inside reads as glowing) and the tint of the "sun through the glass" lamp behind it:
# blue / ruby / amber.
GLASS = ((0.10, 0.14, 0.34), (0.42, 0.10, 0.09), (0.55, 0.36, 0.10))
GLASS_LIGHT = ((0.45, 0.60, 1.00), (1.00, 0.42, 0.34), (1.00, 0.74, 0.36))

lv = Level([GALLERY_Y - 0.125])
box = lv.box


def wall_x(name, z, x0, x1, y0, y1, color, t=WALL, holes=(), decks=None):
    """A wall along x at z, with holes [(xa, xb, ya, yb)] (absolute). Each y band is built separately and its
    overlapping holes are merged before the remaining wall segments are emitted."""
    ys = sorted({y0, y1} | {ya for _, _, ya, _ in holes} | {yb for _, _, _, yb in holes})
    for ya, yb in zip(ys, ys[1:]):
        if yb - ya < 1e-6:
            continue
        cuts = sorted((max(x0, xa), min(x1, xb)) for xa, xb, ha, hb in holes if ha < yb - 1e-6 and hb > ya + 1e-6)
        x = x0
        for xa, xb in cuts:
            if xb <= x + 1e-6:
                continue
            xa = max(xa, x)
            if xa > x + 1e-6:
                box(name, x, xa, ya, yb, z - t / 2, z + t / 2, color, decks)
            x = max(x, xb)
        if x < x1 - 1e-6:
            box(name, x, x1, ya, yb, z - t / 2, z + t / 2, color, decks)


def wall_z(name, x, z0, z1, y0, y1, color, t=WALL, holes=(), decks=None):
    """A wall along z at x, with holes [(za, zb, ya, yb)] (absolute); overlapping holes are split into y bands."""
    ys = sorted({y0, y1} | {ya for _, _, ya, _ in holes} | {yb for _, _, _, yb in holes})
    for ya, yb in zip(ys, ys[1:]):
        if yb - ya < 1e-6:
            continue
        cuts = sorted((max(z0, za), min(z1, zb)) for za, zb, ha, hb in holes if ha < yb - 1e-6 and hb > ya + 1e-6)
        z = z0
        for za, zb in cuts:
            if zb <= z + 1e-6:
                continue
            za = max(za, z)
            if za > z + 1e-6:
                box(name, x - t / 2, x + t / 2, ya, yb, z, za, color, decks)
            z = max(z, zb)
        if z < z1 - 1e-6:
            box(name, x - t / 2, x + t / 2, ya, yb, z, z1, color, decks)


def floor(name, x0, x1, z0, z1, y0, y1, color, holes=(), decks=None):
    lv.slab(name, [(x0, x1, z0, z1)], list(holes), y0, y1, color, decks)


def tilted(name, p_low, p_high, y_low, y_high, width, color, thick=0.25, decks="all"):
    """A slope from p_low to p_high (x, z): its top surface meets both floors (as Level.ramp, any heading)."""
    dx, dz = p_high[0] - p_low[0], p_high[1] - p_low[1]
    run, rise = math.hypot(dx, dz), y_high - y_low
    angle = math.atan2(rise, run)
    cy = y_low + rise / 2 - thick / 2 / math.cos(angle)
    lv.rotated(name, ((p_low[0] + p_high[0]) / 2, cy, (p_low[1] + p_high[1]) / 2),
               (width, thick, math.hypot(run, rise)), color, rot_x=-angle, rot_y=math.atan2(dx, dz), decks=decks)


# --- the ground ---------------------------------------------------------------------------------------------------------

floor("NarthexFloor", WEST, NARTHEX_E, -AISLE_Z, AISLE_Z, -0.5, 0.0, FLOOR_C)
box("NaveFloor", NARTHEX_E, NAVE_E, -0.5, 0.0, -NAVE_Z, NAVE_Z, FLOOR_C)
floor("AisleFloorS", NARTHEX_E, NAVE_E, NAVE_Z, AISLE_Z, -0.5, 0.0, FLOOR_C)
floor("AisleFloorN", NARTHEX_E, NAVE_E, -AISLE_Z, -NAVE_Z, -0.5, 0.0, FLOOR_C)
floor("ChapelFloorS", WEST, NAVE_E, AISLE_Z, SOUTH, -0.5, 0.0, FLOOR_C)
floor("ChapelFloorN", WEST, NAVE_E, NORTH, -AISLE_Z, -0.5, 0.0, FLOOR_C)
box("TranseptFloor", NAVE_E, TRANSEPT_E, -0.5, 0.0, NORTH, SOUTH, FLOOR_C)
# The apse is one solid 0.6 m platform from the steps' top; the stage sits on it at 1.2, the backstage and the
# side corridors are its 0.6 floor. A thinner slab here once buried the front steps and tore the nav mesh.
box("ApseFloor", TRANSEPT_E + 1.2, EAST, 0.0, CHOIR_Y, APSE_N, APSE_S, WOOD_D)


def rail_x(name, x, y, z0, z1, color=IRON):
    box(name, x - RAIL_T / 2, x + RAIL_T / 2, y, y + RAIL, z0, z1, color)


def rail_z(name, z, y, x0, x1, color=IRON):
    box(name, x0, x1, y, y + RAIL, z - RAIL_T / 2, z + RAIL_T / 2, color)


def glass_x(name, z, x0, x1, y0, y1, color):
    """A stained-glass pane filling a wall_x opening: 0.12 m thick, centred in the wall."""
    box(name, x0, x1, y0, y1, z - 0.06, z + 0.06, color, decks="all")


def glass_z(name, x, z0, z1, y0, y1, color):
    """The same for a wall_z opening at x."""
    box(name, x - 0.06, x + 0.06, y0, y1, z0, z1, color, decks="all")


# --- the west facade -----------------------------------------------------------------------------------------------

# The facade, 24 m high: one central 8 x 6 door and the rose-window opening (8 x 6).
for y0, y1, holes in ((0.0, 6.0, [(-4.0, 4.0, 0.0, 6.0)]),
                      (6.0, 11.5, []),
                      (11.5, 17.5, [(-4.0, 4.0, 11.5, 17.5)]),
                      (17.5, 24.0, [])):
    band = []
    for za, zb, ya, yb in holes:
        if ya < y1 and yb > y0:
            band.append((za, zb, y0, y1))
    wall_z("Facade", WEST - WALL / 2, NORTH, SOUTH, y0, y1, STONE_L, holes=band)
# The closed double-leaf entrance fills the 8 x 6 opening. These blocks also provide collision.
door_x0, door_x1 = WEST - WALL, WEST
box("MainDoorLeaf", door_x0, door_x1, 0.0, 6.0, -4.0, 0.0, WOOD_D)
box("MainDoorLeaf2", door_x0, door_x1, 0.0, 6.0, 0.0, 4.0, WOOD_D)
# Iron straps and a center handle make the two leaves legible from both sides.
for y in (0.8, 3.0, 5.2):
    for z0, z1 in ((-3.8, -0.15), (0.15, 3.8)):
        box("MainDoorStrap", door_x0 - 0.03, door_x1 + 0.03, y, y + 0.16, z0, z1, IRON)
box("MainDoorHandle", door_x0 - 0.06, door_x1 + 0.02, 2.8, 3.2, -0.18, 0.18, GOLD)
# The stepped parapet in front of the roof: it stands out 0.2 m, so no z-fighting with the wall.
for i in range(6):
    box("FacadeGable", WEST - WALL - 0.2, WEST - WALL, 18.0 + i * 0.9, 18.0 + (i + 1) * 0.9,
        -24.0 + i * 4.0, 24.0 - i * 4.0, STONE_L)
box("FacadeCornice", WEST - WALL - 0.45, WEST - WALL + 0.1, 17.6, 18.0, NORTH, SOUTH, STONE)
# Four pilasters give the west front a vertical rhythm without interrupting the central door. They stand flush
# with the facade's inner face and protrude into the narthex (owner, 2026-11-18: used to be six, outside; the
# +-22 pair is gone, +-10 moved to +-11 on the aisle walls' line).
for z in (-16.0, -11.0, 11.0, 16.0):
    box("FacadePilaster", WEST, WEST + 0.5, 0.0, 24.0, z - 0.5, z + 0.5, STONE)

# --- the outer walls ---------------------------------------------------------------------------------------------------

# The long outer walls of the nave and the transept, 18 m: the chapel-band windows and the transept's tall windows.
chapel_windows = [(x, x + 2.0, 2.5, 5.5) for x in range(-46, 17, 6)]
for z in (NORTH, SOUTH):
    holes = chapel_windows + [(20.0, 30.0, 8.0, 16.0)]
    wall_x("OuterWall", z, WEST, TRANSEPT_E, 0.0, NAVE_CEIL, WALL_C, holes=holes)
# Every outer window is sealed with stained glass (owner, 2026-11-17). The dusk sun cannot enter physically, so
# each pane gets a warm lamp in its own plane - no fixture, both decks - reading as light from the window, not a
# lamp under it (owner, 2026-11-18: "как будто из окна", the hanging fixtures below the windows are gone).
# Chapel windows alternate blue / ruby / amber; the tall transept windows are blue.
for i, (xa, xb, ya, yb) in enumerate(chapel_windows):
    glass_x("WindowGlass", NORTH, xa, xb, ya, yb, GLASS[i % 3])
    glass_x("WindowGlass", SOUTH, xa, xb, ya, yb, GLASS[i % 3])
    for z, inner in ((NORTH, 0.35), (SOUTH, -0.35)):
        lv.lamp("WindowGlow", ((xa + xb) / 2, (ya + yb) / 2, z + inner), energy=1.2, rng=8.0,
                shade=(0, 0, 0), color=GLASS_LIGHT[i % 3], decks="all")
for z, inner in ((NORTH, 0.35), (SOUTH, -0.35)):
    glass_x("WindowGlass", z, 20.0, 30.0, 8.0, 16.0, GLASS[0])
    lv.lamp("WindowGlow", (25.0, 12.0, z + inner), energy=1.5, rng=10.0, shade=(0, 0, 0),
            color=GLASS_LIGHT[0], decks="all")
# The chapel bands' ceilings; the wall between them and the galleries (with arches).
for z0, z1 in ((AISLE_Z, SOUTH), (NORTH, -AISLE_Z)):
    box("ChapelCeil", WEST, NAVE_E, CHAPEL_CEIL, CHAPEL_CEIL + 0.25, min(z0, z1), max(z0, z1), STONE_D)
# The transept's east walls (the apse opening between them) and the apse's outer walls.
for z0, z1 in ((NORTH, APSE_N), (APSE_S, SOUTH)):
    wall_z("TranseptEast", TRANSEPT_E - WALL / 2, z0, z1, 0.0, NAVE_CEIL, STONE_L,
           holes=[(z0 + 2.0, z1 - 2.0, 8.0, 16.0)])
    glass_z("WindowGlass", TRANSEPT_E - WALL / 2, z0 + 2.0, z1 - 2.0, 8.0, 16.0, GLASS[0])
    lv.lamp("WindowGlow", (TRANSEPT_E - WALL / 2 - 0.35, 12.0, (z0 + z1) / 2), energy=1.5, rng=10.0,
            shade=(0, 0, 0), color=GLASS_LIGHT[0], decks="all")
for z in (APSE_N, APSE_S):
    wall_x("ApseWall", z, TRANSEPT_E, EAST, 0.0, NAVE_CEIL, STONE_L,
           holes=[(36.0, 40.0, 8.0, 14.0), (44.0, 48.0, 8.0, 14.0)])
    for j, (xa, xb) in enumerate(((36.0, 40.0), (44.0, 48.0))):
        glass_x("WindowGlass", z, xa, xb, 8.0, 14.0, GLASS[(j + 1) % 3])
        lv.lamp("WindowGlow", ((xa + xb) / 2, 11.0, z + (0.35 if z < 0 else -0.35)), energy=1.4, rng=9.0,
                shade=(0, 0, 0), color=GLASS_LIGHT[(j + 1) % 3], decks="all")
wall_z("ApseEast", EAST + WALL / 2, APSE_N, APSE_S, 0.0, NAVE_CEIL + 4.0, STONE_L)

# --- the nave, the aisles and the galleries ----------------------------------------------------------------------------

# The carpet: one strip down the nave and the crossing (the crypt stairs that split it are gone).
box("Carpet", NARTHEX_E + 6.0, TRANSEPT_E, 0.001, 0.02, -3.0, 3.0, CARPET)

# The columns and the arcade: 8 columns, 7 bays; the gallery floor rests on them.
for i in range(8):
    x = -40.0 + i * 8.0
    for z in (-NAVE_Z, NAVE_Z):
        box("Column", x - 0.7, x + 0.7, 0.0, NAVE_CEIL, z - 0.7, z + 0.7, COLUMN, decks="all")
        box("ColumnBase", x - 0.9, x + 0.9, 0.0, 0.6, z - 0.9, z + 0.9, STONE_D, decks="all")
        box("ColumnCap", x - 0.9, x + 0.9, NAVE_CEIL - 0.7, NAVE_CEIL, z - 0.9, z + 0.9, STONE_L, decks="all")
    if i < 7:
        for z in (-NAVE_Z, NAVE_Z):
            box("Arcade", x + 0.7, x + 7.3, 7.6, 8.8, z - 0.35, z + 0.35, COLUMN, decks="all")
            box("Arcade", x + 0.7, x + 1.3, 6.5, 7.8, z - 0.35, z + 0.35, COLUMN, decks="all")
            box("Arcade", x + 6.7, x + 7.3, 6.5, 7.8, z - 0.35, z + 0.35, COLUMN, decks="all")
# The clerestory: the wall above the gallery. The window band is gone (owner, 2026-11-18) - the gap between the
# sill and the header is an open slot, so the second floor sees and shoots down the whole nave over its bortik.
# The sill itself follows his two marked blocks (_this): 0.8 m high, sitting on the deck, the full-bay pieces
# grown to 6.5 (they reach the column faces) and the catwalk-side pieces to 1.7. The sill is interrupted where
# a catwalk crosses the nave (the bridge floor continues the gallery); the glow lamps stay in the open slot.
BRIDGE_BAYS = {2: (-21.5, -18.5), 5: (2.5, 5.5)}  # bay index -> the catwalk's x range
for i in range(7):
    x0, x1 = -40.0 + i * 8.0 + 1.0, -40.0 + (i + 1) * 8.0 - 1.0
    for z in (-NAVE_Z, NAVE_Z):
        if i in BRIDGE_BAYS:
            bx0, bx1 = BRIDGE_BAYS[i]
            box("Clerestory", bx0 - 1.7, bx0, 9.75, 10.55, z - WALL / 2, z + WALL / 2, STONE_L, decks="all")
            box("Clerestory", bx1, bx1 + 1.7, 9.75, 10.55, z - WALL / 2, z + WALL / 2, STONE_L, decks="all")
        else:
            box("Clerestory", x0 - 0.25, x1 + 0.25, 9.75, 10.55, z - WALL / 2, z + WALL / 2, STONE_L, decks="all")
        box("Clerestory", x0, x1, 16.0, NAVE_CEIL, z - WALL / 2, z + WALL / 2, STONE_L, decks="all")
        lv.lamp("ClerestoryGlow", ((x0 + x1) / 2, 13.5, z + (-0.35 if z < 0 else 0.35)), energy=1.2, rng=9.0,
                shade=(0, 0, 0), color=GLASS_LIGHT[i % 3], decks="all")
for x0, x1 in ((NARTHEX_E, -39.0), (15.0, NAVE_E)):
    for z in (-NAVE_Z, NAVE_Z):
        box("Clerestory", x0, x1, 9.75, NAVE_CEIL, z - WALL / 2, z + WALL / 2, STONE_L, decks="all")
# The nave's ceiling and the transept's, with the crossing's hole for the dome.
floor("NaveCeiling", WEST, NAVE_E, -AISLE_Z, AISLE_Z, NAVE_CEIL, NAVE_CEIL + 0.4, STONE_D)
floor("TranseptCeiling", NAVE_E, TRANSEPT_E, NORTH, SOUTH, NAVE_CEIL, NAVE_CEIL + 0.4, STONE_D,
      holes=[(21.0, 29.0, -4.0, 4.0)])
floor("ApseCeiling", TRANSEPT_E, EAST, APSE_N, APSE_S, NAVE_CEIL, NAVE_CEIL + 0.4, STONE_D)

# The second floor is the old gallery ceiling's top (9.5..9.75): the low gallery at 6.5 is gone and the walkway now
# stands at the base of the clerestory partitions. Only the sill (9.75..11, 1.25 m) is left as a bortik - a crouched
# player hides behind it, a standing one shoots over it. Four 18 m stairs rise from the ground through holes in it.
for z0, z1, holes in (
        (NAVE_Z, AISLE_Z, [(-28.0, -24.0, 14.0, 17.0), (0.0, 4.0, 14.0, 17.0)]),
        (-AISLE_Z, -NAVE_Z, [(-28.0, -24.0, -17.0, -14.0), (0.0, 4.0, -17.0, -14.0)])):
    floor("GalleryFloor", NARTHEX_E, NAVE_E, z0, z1, GALLERY_CEIL, GALLERY_CEIL + 0.25, STONE_D, holes=holes)
# The outer wall above the chapel arcade; the nave side is the sill, not a wall.
for z in (-AISLE_Z, AISLE_Z):
    wall_x("GalleryOuter", z, WEST, NAVE_E, GALLERY_Y, NAVE_CEIL, STONE_L)
# The stair holes' rails: the drop is at the foot of each hole; the stair comes up at the other end.
for zc in (15.5, -15.5):
    for z in (zc - 1.5, zc + 1.5):
        rail_z("StairHoleRail", z, GALLERY_CEIL + 0.25, -28.0, -24.0)
        rail_z("StairHoleRail", z, GALLERY_CEIL + 0.25, 0.0, 4.0)
    rail_x("StairHoleRail", -28.0, GALLERY_CEIL + 0.25, zc - 1.5, zc + 1.5)
    rail_x("StairHoleRail", 4.0, GALLERY_CEIL + 0.25, zc - 1.5, zc + 1.5)
# The four stairs: 18 m ramps at 28 deg, against the outer walls, now all the way to the new floor. Sloped rails.
for zc in (15.5, -15.5):
    tilted("GalleryStairW", (NARTHEX_E, zc), (-24.0, zc), 0.0, GALLERY_CEIL + 0.25, 3.0, STONE)
    tilted("GalleryStairE", (NAVE_E, zc), (0.0, zc), 0.0, GALLERY_CEIL + 0.25, 3.0, STONE)
    for z in (zc - 1.55, zc + 1.55):
        tilted("GalleryStairRailW", (NARTHEX_E, z), (-24.0, z), 0.9, GALLERY_CEIL + 0.25 + 0.9, 0.1, IRON, thick=0.9)
        tilted("GalleryStairRailE", (NAVE_E, z), (0.0, z), 0.9, GALLERY_CEIL + 0.25 + 0.9, 0.1, IRON, thick=0.9)
# The ends of the walkway: over the transept and the choir loft.
for z0, z1 in ((NAVE_Z, AISLE_Z), (-AISLE_Z, -NAVE_Z)):
    rail_x("GalleryEndRail", NARTHEX_E, GALLERY_CEIL + 0.25, z0, z1)
    rail_x("GalleryEndRail", NAVE_E, GALLERY_CEIL + 0.25, z0, z1)
# The choir loft over the narthex: an isolated 6.5 m balcony with a low rail and no separate entrance.
floor("LoftFloor", WEST, NARTHEX_E, -AISLE_Z, AISLE_Z, GALLERY_Y - 0.25, GALLERY_Y, WOOD)
rail_x("LoftRail", NARTHEX_E, GALLERY_Y, -NAVE_Z, NAVE_Z)
# The gallery lamps, above the walkway (the old low gallery lamps are gone); cool studio fill light.
for x in (-34.0, -18.0, -2.0, 10.0):
    for z in (-14.5, 14.5):
        lv.lamp("GalleryLamp", (x, 12.0, z), energy=1.8, rng=9.0, shade=(0.35, 0.35, 0.35),
                color=(0.70, 0.80, 1.00))

# --- the studio: the LED wall and the nave catwalks ---------------------------------------------------------------------

# The studio wall is gone altogether (owner, 2026-11-18): the nave's full 60 m sightline is back - first the LED
# panel came off it, now the partition itself; the broadcast lives on the big screens around the level
# (scripts/game/on_air.gd). The column line at x -8 is open ground again.
# Two catwalks bridge the nave between the galleries, closing the upper loop (gallery N <-> gallery S); the
# clerestory sill is interrupted for them. Rails guard the long sides; the ends meet the gallery floors flush.
for bx0, bx1 in BRIDGE_BAYS.values():
    box("NaveBridge", bx0, bx1, 9.5, 9.75, -NAVE_Z, NAVE_Z, STONE_D)
    rail_x("BridgeRail", bx0, 9.75, -NAVE_Z, NAVE_Z)
    rail_x("BridgeRail", bx1, 9.75, -NAVE_Z, NAVE_Z)

# --- the chapel bands and the transept ---------------------------------------------------------------------------------

# The wall between the side aisles and the chapel bands: 0 .. 6.5, arches every 6 m.
for z in (-AISLE_Z, AISLE_Z):
    holes = [(x + 0.8, x + 4.6, 0.0, 4.6) for x in range(-46, 17, 6)]
    wall_x("ChapelArcade", z, WEST, NAVE_E, 0.0, CHAPEL_CEIL, STONE_L, holes=holes)
# The gables sealing the chapel attics' east ends (owner, 2026-11-18): above each chapel ceiling (6.75) the
# band's void would open into the transept arm's full height, so the arm's west face over z +-18..24 is walled
# up to the transept ceiling. He built the south one by hand (marked "wall_this"); the north one is its mirror.
for z0, z1 in ((-24.0, -18.0), (18.0, 24.0)):
    box("ChapelGable", 17.5, 18.0, 6.75, NAVE_CEIL, z0, z1, STONE_L, decks="all")
for z in (-21.0, 21.0):
    lv.lamp("TranseptLamp", (25.0, 5.0, z), energy=1.3, rng=9.0, shade=(0.5, 0.1, 0.5),
            color=(0.45, 0.60, 1.00))
# The crossing dome: a flat octagonal recess over the hole, a ring of segments round it.
for i in range(8):
    a = math.radians(i * 45.0 + 22.5)
    lv.rotated("DomeRing", (25.0 + 4.8 * math.cos(a), 19.0, 4.8 * math.sin(a)), (1.2, 2.0, 4.2), STONE_L,
               rot_y=-a, decks="all")
lv.rotated("DomeCap", (25.0, 20.2, 0.0), (8.0, 0.6, 8.0), STONE_D, decks="all")
lv.rotated("DomeCap", (25.0, 20.2, 0.0), (8.0, 0.6, 8.0), STONE_D, rot_y=math.pi / 4, decks="all")
lv.lamp("CrossingLamp", (25.0, 17.2, 0.0), energy=1.0, rng=10.0, shade=(0.35, 0.35, 0.35))

# --- the apse: the choir, the stage, the backstage and the side corridors ----------------------------------------------

# The choir platform (0.6) and the stage (1.2): ramps, not 0.4 m steps - the bots' nav mesh cannot stand on a step
# narrower than its agent (0.3 m radius), and the apse was cut off.
tilted("ChoirRamp", (TRANSEPT_E, 0.0), (TRANSEPT_E + 1.2, 0.0), 0.0, CHOIR_Y, APSE_S - APSE_N, WOOD_D)
tilted("StageRamp", (38.0, 0.0), (39.2, 0.0), CHOIR_Y, STAGE_Y, 18.0, WOOD_D)
box("Stage", 39.2, 46.0, 0.0, STAGE_Y, -9.0, 9.0, WOOD_D)
# The stage's and the backstage' side walls are gone (owner, 2026-11-18). They were never in the playfield:
# wall_z takes (x, z0, z1) but was fed the loop's z as x, so six slabs floated at x +-9, z 38..52 - outside
# the map, invisible in every view. The stage and the backstage now openly meet the side corridors at z +-9;
# the real apse boundary stays the outer wall at z +-12.
box("BackstageCeil", 46.0, EAST, BACKSTAGE_CEIL, BACKSTAGE_CEIL + 0.25, -9.0, 9.0, STONE_D)
box("CorridorCeilS", TRANSEPT_E + 1.2, EAST, BACKSTAGE_CEIL, BACKSTAGE_CEIL + 0.25, 9.0, 12.0, STONE_D)
box("CorridorCeilN", TRANSEPT_E + 1.2, EAST, BACKSTAGE_CEIL, BACKSTAGE_CEIL + 0.25, -12.0, -9.0, STONE_D)
# The stage's backdrop at x 46: 18 m high, a door to the backstage, a dark screen and its gold frame.
wall_z("StageBack", 46.0, -9.0, 9.0, STAGE_Y, NAVE_CEIL, STONE_D, holes=[(-2.0, 2.0, STAGE_Y, BACKSTAGE_CEIL)])
box("StageScreen", 45.85, 46.0, 5.0, 14.0, -6.0, 6.0, SCREEN, decks="all")
box("StageScreenFrame", 45.7, 45.9, 14.0, 14.5, -6.5, 6.5, GOLD, decks="all")
box("StageScreenFrame", 45.7, 45.9, 4.5, 5.0, -6.5, 6.5, GOLD, decks="all")
box("StageScreenFrame", 45.7, 45.9, 4.5, 14.5, -6.5, -6.0, GOLD, decks="all")
box("StageScreenFrame", 45.7, 45.9, 4.5, 14.5, 6.0, 6.5, GOLD, decks="all")
# The stage's truss and its lamps.
box("Truss", 39.2, 46.0, 13.0, 13.4, -9.0, 9.0, IRON, decks="all")
for x in (41.0, 44.0):
    for z in (-6.0, 6.0):
        box("TrussLeg", x - 0.1, x + 0.1, STAGE_Y, 13.0, z - 0.1, z + 0.1, IRON, decks="all")
for z in (-6.0, -2.0, 2.0, 6.0):
    lv.lamp("StageLamp", (42.5, 12.6, z), energy=1.8, rng=10.0, shade=(0.5, 0.1, 0.5), color=(1.00, 0.74, 0.36))
# The ramp from the backstage (0.6) to the stage door (1.2).
tilted("StageDoorRamp", (46.0, 0.0), (48.4, 0.0), STAGE_Y, CHOIR_Y, 4.0, WOOD_D)
for z in (-3.0, 3.0):
    lv.lamp("TokenLamp", (44.5, 3.0, z), energy=1.6, rng=7.0, shade=(0.5, 0.1, 0.5), color=(1.00, 0.74, 0.36))
lv.lamp("CorridorLampS", (40.0, 3.4, 10.5), energy=1.0, rng=7.0, shade=(0.35, 0.35, 0.35))
lv.lamp("CorridorLampN", (40.0, 3.4, -10.5), energy=1.0, rng=7.0, shade=(0.35, 0.35, 0.35))
lv.lamp("BackstageLamp", (49.0, 3.6, 0.0), energy=1.2, rng=7.0, shade=(0.35, 0.35, 0.35))

# --- the nave's lamps, the organ, the roof ------------------------------------------------------------------------------

for x in (-34.0, -18.0, -2.0, 10.0):
    box("Cable", x - 0.02, x + 0.02, 6.1, NAVE_CEIL, -0.02, 0.02, IRON)
    lv.lamp("NaveLamp", (x, 5.9, 0.0), energy=1.7, rng=13.0, shade=(0.5, 0.1, 0.5))
for x in (-38.0, -26.0, -14.0, -2.0, 10.0):
    for z in (-21.0, 21.0):
        lv.lamp("ChapelLamp", (x, 5.4, z), energy=1.2, rng=7.0, shade=(0.35, 0.35, 0.35),
                color=GLASS_LIGHT[1])
lv.lamp("LoftLamp", (WEST + 3.0, GALLERY_Y + 3.0, 0.0), energy=1.6, rng=9.0, shade=(0.45, 0.1, 0.5))
# The narthex stays lit from inside now that the street is gone and the entrance is closed.
for z in (-8.0, 8.0):
    lv.lamp("NarthexLamp", (WEST + 4.0, 3.5, z), energy=1.4, rng=7.0, shade=(0.35, 0.35, 0.35))

# The organ: a bank of pipes against the west wall of the loft, from 6.5 to 11.
for i in range(9):
    z = -8.0 + i * 2.0
    h = 2.5 + (i % 3) * 0.7
    box("OrganPipe", WEST + 0.6, WEST + 1.4, GALLERY_Y, GALLERY_Y + h, z - 0.35, z + 0.35, IRON)
box("OrganBase", WEST + 0.4, WEST + 2.0, GALLERY_Y, GALLERY_Y + 1.2, -9.0, 9.0, WOOD_D)

# The exterior trim is gone (owner, 2026-11-18): the decorative roofs, ridges and buttresses never showed from
# the playfield - the interior ceilings (NaveCeiling, ChapelCeil and the rest) are the real lid; above them the
# flat slab tops now face the sky. The crossing's dome ring and cap stay.
# The pilasters inside the chapel bands now sit in the middle of the gaps between the windows (they used to
# stand on the windows' west edges and clip them); every 12 m, aligned with the buttress rhythm.
for x in (-48.0, -36.0, -24.0, -12.0, 0.0, 12.0):
    for z in (NORTH + WALL / 2, SOUTH - WALL / 2):
        box("Pilaster", x - 0.35, x + 0.35, 0.0, CHAPEL_CEIL, z - 0.35, z + 0.35, STONE_D)

lv.write(OUT, "GigachurchShell")
print("gigachurch shell: %d blocks, %d lamps" % (len(lv.blocks), len(lv.lights)))
