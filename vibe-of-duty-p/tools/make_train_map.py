"""Generates prefabs/levels/train_shell.tscn: the shell of a wide double-decker train (FFA, 2-4 players) running
through a forest - car bodies, floors, walls, stairs, gangways, rails, the ground and the lamps.
Read Docs/LEVEL_TRAIN.md first (layout, the owner's decisions, how to check); update it with any change here.

Run from the repo:  python vibe-of-duty-p/tools/make_train_map.py
Re-running overwrites the shell, so tune it here, not in the editor. Everything else - props (seats, tables, cargo),
spawn points, environment, sun - is the owner's hand-edited prefabs/levels/train.tscn, which instances this shell.

The train stands still (physics, netcode and lag compensation stay simple); the forest, the track and the tunnels
move past it (scripts/game/train_scenery.gd, visual only). The train runs along Z, the locomotive at -Z.

Layout, front to back: locomotive (decor) | A passenger | B dining | C open cargo car | D sleeper + baggage.
A, B and D are closed double-deckers (~80% of the map) with rows of windows on both decks; C has no roof: a cargo
pit and a catwalk at upper-deck height linking B and D. Windows are 0.9 m tall, lower
than a crouching player (1.1 m), so nobody climbs out through them.

Doors are on the centre line (DOOR_X = 0): each deck is one sightline through the whole train - the owner's call,
it has its charm (a zigzag, DOOR_X 1.4, was tried and rejected). B and D are mirrored copies (m = -1): their stairs
stand the other way round, and with an offset DOOR_X each door stays opposite its stairs.

Nobody falls off by a misstep: every edge a player can walk to is walled or railed (1.1 m, above the jump height,
and the vault refuses a rail with a drop behind it). Only a deliberate running jump from a container top clears
the cargo car's sides - and the ground beside the track kills on landing (World.kill_height just above a
solid ground plane, so the body lands instead of falling through the scenery).
"""
import math
import os

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
DOOR_X = 0.0       # doors this far off the centre line, at opposite sides of each car (1.4: a zigzag)
STAIR_W, STAIR_RUN = 1.6, 6.0
RAIL = 1.1         # guard rail height: above the jump (~1.06 m)
C_SIDE = 1.5       # cargo car sides and ends, all one height

# Colours (Block materials are shared per colour). The owner's palette (Docs/AUTHOR.md; scripts/game/palette.gd):
# warm greys, the cars told apart by lightness and one rust car, not by hue. Olive is kept for pickups (ammo bags).
# These are albedos: the palette's dark hexes are what the lit frame should look like, not surface colours.
BODY = (0.48, 0.46, 0.42)     # car body: A passenger
BODY_B = (0.52, 0.37, 0.3)   # dining car: rust
BODY_D = (0.58, 0.56, 0.51)   # sleeper: lighter grey
FLOOR = (0.38, 0.36, 0.33)
ROOF_C = (0.32, 0.31, 0.3)
STEEL = (0.42, 0.42, 0.41)
UNDER = (0.16, 0.155, 0.15)
LOCO = (0.27, 0.27, 0.26)
LAMP_COLOR = (1.0, 0.72, 0.45)  # Palette.EMBER as light

# Render layers (project.godot): the lamps cast no shadows, so each lights only its own deck's blocks - plus the
# world (players, scenery) and the viewmodel. The upper floor slabs, gangway walls and stairs belong to both decks.
LAYER_WORLD, LAYER_VIEWMODEL, LAYER_LOWER, LAYER_UPPER = 1, 2, 4, 8
DECK_SPLIT = 3.15  # the middle of the upper floor slab

blocks = []   # (name, center, size, color, rot_x)
lights = []   # (name, position)
_names = {}


def uniq(name):
    n = _names.get(name, 0)
    _names[name] = n + 1
    return name if n == 0 else "%s%d" % (name, n)


def box(name, x0, x1, y0, y1, z0, z1, color, rot_x=0.0, m=1):
    """m = -1 mirrors the box across the centre line (x -> -x)."""
    if m < 0:
        x0, x1 = -x1, -x0
    blocks.append((uniq(name), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), color, rot_x))


# --- pieces ---------------------------------------------------------------------------------------------------------

def side_wall(x_inner, outward, z0, z1, deck_y, top_y, color, panoramic=False):
    """A side wall from deck_y to top_y with a row of windows."""
    xa, xb = sorted((x_inner, x_inner + outward * T))
    low, high = (0.9, 2.3) if panoramic else (WIN_LOW, WIN_HIGH)
    box("WallLow", xa, xb, deck_y, deck_y + low, z0, z1, color)
    box("WallHigh", xa, xb, deck_y + high, top_y, z0, z1, color)
    if panoramic:  # a transom across the tall windows: neither opening fits a crouching player
        box("Transom", xa, xb, deck_y + 1.5, deck_y + 1.65, z0, z1, color)
    # Pillars between the windows, evenly spread over the length.
    length = z1 - z0
    count = max(1, int((length - PILLAR) // (WIN_W + PILLAR)))
    pillar = (length - count * WIN_W) / (count + 1)
    z = z0
    for _ in range(count + 1):
        box("Pillar", xa, xb, deck_y + low, deck_y + high, z, z + pillar, color)
        z += pillar + WIN_W


def end_wall(z_face, inward, deck_y, top_y, color, door_x=None):
    """A car end wall (across the car) at z_face, with a door centred at door_x (None: no door)."""
    za, zb = sorted((z_face, z_face + inward * T))
    if door_x is None:
        box("EndWall", -W / 2, W / 2, deck_y, top_y, za, zb, color)
        return
    box("EndWall", -W / 2, door_x - DOOR_W / 2, deck_y, top_y, za, zb, color)
    box("EndWall", door_x + DOOR_W / 2, W / 2, deck_y, top_y, za, zb, color)
    box("Lintel", door_x - DOOR_W / 2, door_x + DOOR_W / 2, deck_y + DOOR_H, top_y, za, zb, color)


def ramp(x0, x1, z_low, z_high):
    """Stairs as a ramp from the lower deck (at z_low) up to the upper deck (at z_high)."""
    run = z_high - z_low
    rise = UPPER
    length = math.hypot(run, rise)
    angle = math.atan2(rise, abs(run))
    thick = 0.25
    cy = rise / 2 - thick / 2 / math.cos(angle)
    rot = -angle if run > 0 else angle   # rotation about X: negative tilts +Z upwards
    blocks.append((uniq("Stairs"), ((x0 + x1) / 2, cy, (z_low + z_high) / 2), (x1 - x0, thick, length), STEEL, rot))


def upper_floor(z0, z1, holes):
    """Upper deck slab over the inner width, with rectangular holes [(x0, x1, za, zb)] for the stairs."""
    # Split into strips along x at every hole edge, then cut each strip along z.
    xs = sorted({-HW, HW} | {h[0] for h in holes} | {h[1] for h in holes})
    for xa, xb in zip(xs, xs[1:]):
        cuts = sorted((h[2], h[3]) for h in holes if h[0] <= xa and h[1] >= xb)
        z = z0
        for za, zb in cuts:
            if za > z:
                box("UpperFloor", xa, xb, UPPER - SLAB, UPPER, z, za, FLOOR)
            z = zb
        if z < z1:
            box("UpperFloor", xa, xb, UPPER - SLAB, UPPER, z, z1, FLOOR)


def closed_car(z0, color, m=1, front_door=True, back_door=True, panoramic_upper=False):
    """A double-decker. Written for m = 1 (front stairs right, back stairs left, each door opposite its stairs:
    front door left, back door right); m = -1 is the mirror image."""
    z1 = z0 + L
    box("Underframe", -W / 2 + 0.5, W / 2 - 0.5, -1.3, -SLAB, z0 + 1.0, z1 - 1.0, UNDER)
    box("Floor", -W / 2, W / 2, -SLAB, 0.0, z0, z1, FLOOR)
    box("Roof", -W / 2, W / 2, ROOF, ROOF + SLAB, z0, z1, ROOF_C)
    mx = lambda xa, xb: (xa, xb) if m > 0 else (-xb, -xa)
    s1 = mx(HW - STAIR_W, HW) + (z0 + 1.2, z0 + 1.2 + STAIR_RUN)      # front stairs, rising backwards
    s2 = mx(-HW, -HW + STAIR_W) + (z1 - 1.2 - STAIR_RUN, z1 - 1.2)    # back stairs, rising forwards
    upper_floor(z0 + T, z1 - T, [s1, s2])
    ramp(s1[0], s1[1], s1[2], s1[3])
    ramp(s2[0], s2[1], s2[3], s2[2])
    # Guard rails along the stair holes on the upper deck (the open side of each hole).
    box("Rail", HW - STAIR_W - 0.1, HW - STAIR_W, UPPER, UPPER + RAIL, s1[2], s1[3], STEEL, m=m)
    box("Rail", -HW + STAIR_W, -HW + STAIR_W + 0.1, UPPER, UPPER + RAIL, s2[2], s2[3], STEEL, m=m)
    front_x = -DOOR_X * m if front_door else None
    back_x = DOOR_X * m if back_door else None
    for deck_y, top_y, pano in ((0.0, UPPER, False), (UPPER, ROOF + SLAB, panoramic_upper)):
        side_wall(HW, 1, z0, z1, deck_y, top_y, color, pano)
        side_wall(-HW, -1, z0, z1, deck_y, top_y, color, pano)
        end_wall(z0, 1, deck_y, top_y, color, front_x)
        end_wall(z1, -1, deck_y, top_y, color, back_x)
    lights.append((uniq("Lamp"), (0.0, UPPER - SLAB - 0.4, z0 + L / 2)))
    lights.append((uniq("Lamp"), (0.0, ROOF - 0.4, z0 + L / 2)))
    return z1


def gangway(z0, z1, x):
    """Covered walkway between two cars on both decks, centred at x (the doors' x)."""
    hw = DOOR_W / 2 + 0.15
    box("GangwayFloor", x - hw, x + hw, -SLAB, 0.0, z0, z1, FLOOR)
    box("GangwayFloor", x - hw, x + hw, UPPER - SLAB, UPPER, z0, z1, FLOOR)
    box("GangwayRoof", x - hw - T, x + hw + T, ROOF, ROOF + SLAB, z0, z1, ROOF_C)
    box("GangwayWall", x - hw - T, x - hw, -SLAB, ROOF, z0, z1, UNDER)
    box("GangwayWall", x + hw, x + hw + T, -SLAB, ROOF, z0, z1, UNDER)


# --- the train -------------------------------------------------------------------------------------------------------

TOTAL = 4 * L + 3 * GAP
z = -TOTAL / 2

# Locomotive (solid decor) in front of car A.
box("Loco", -W / 2 + 0.2, W / 2 - 0.2, -1.3, 5.2, z - 16.0, z - 1.5, LOCO)
box("LocoCab", -W / 2 + 0.2, W / 2 - 0.2, 5.2, 6.2, z - 6.0, z - 1.5, LOCO)

# A: passenger car (the props - seats, tables, cargo and so on - are hand-made in train.tscn).
a0 = z
z = closed_car(a0, BODY, front_door=False)

gangway(z, z + GAP, DOOR_X)
z += GAP

# B: dining car, mirrored; a panoramic upper deck.
b0 = z
z = closed_car(b0, BODY_B, m=-1, panoramic_upper=True)

gangway(z, z + GAP, -DOOR_X)
z += GAP

# C: open cargo car (no roof): a pit for the cargo, and a catwalk at upper-deck height joining B and D.
c0 = z
c1 = c0 + L
box("Underframe", -W / 2 + 0.5, W / 2 - 0.5, -1.3, -SLAB, c0 + 1.0, c1 - 1.0, UNDER)
box("Floor", -W / 2, W / 2, -SLAB, 0.0, c0, c1, FLOOR)
# Sides thinner than the vault's MANTLE_MIN_TOP (0.15 m): nobody climbs onto their top and steps off outside.
box("Side", HW, HW + 0.1, 0.0, C_SIDE, c0, c1, BODY)
box("Side", -HW - 0.1, -HW, 0.0, C_SIDE, c0, c1, BODY)
for zf, inward, door_x in ((c0, 1, -DOOR_X), (c1, -1, DOOR_X)):   # ends: a wall below, a rail along the landing
    za, zb = sorted((zf, zf + inward * 0.1))
    walk = DOOR_W / 2 + 0.15   # the opening is as wide as the gangway / platform, flush with its walls or rails
    box("CEnd", -W / 2, door_x - walk, 0.0, C_SIDE, za, zb, BODY)
    box("CEnd", door_x + walk, W / 2, 0.0, C_SIDE, za, zb, BODY)
    box("CEndRail", -HW, door_x - walk, UPPER, UPPER + RAIL, za, zb, STEEL)
    box("CEndRail", door_x + walk, HW, UPPER, UPPER + RAIL, za, zb, STEEL)
# Catwalk along the right side at upper-deck height, with a rail on the inner side (players may drop into the pit).
cw0, cw1 = HW - 1.4, HW
box("Catwalk", cw0, cw1, UPPER - 0.2, UPPER, c0, c1, STEEL)
box("CatwalkRail", cw0, cw0 + 0.08, UPPER, UPPER + RAIL, c0 + 1.5, c0 + 8.0, STEEL)
box("CatwalkRail", cw0, cw0 + 0.08, UPPER, UPPER + RAIL, c0 + 12.0, c1 - 1.5, STEEL)
box("CatwalkRail", cw1 - 0.08, cw1, UPPER, UPPER + RAIL, c0, c1, STEEL)
for zz in (c0 + 4.0, c0 + 10.0, c0 + 16.0):   # posts outside the car, against the side, up to the catwalk's top
    box("CatwalkPost", HW + 0.1, HW + 0.4, 0.0, UPPER, zz, zz + 0.3, STEEL)

# Landings across the car at both ends, at upper-deck height: from the upper doors of B and D onto the catwalk.
box("Landing", -HW, HW, UPPER - 0.2, UPPER, c0, c0 + 1.5, STEEL)
box("Landing", -HW, HW, UPPER - 0.2, UPPER, c1 - 1.5, c1, STEEL)
box("LandingRail", -HW, cw0, UPPER, UPPER + RAIL, c0 + 1.42, c0 + 1.5, STEEL)
box("LandingRail", -HW, cw0, UPPER, UPPER + RAIL, c1 - 1.5, c1 - 1.42, STEEL)
box("LandingRail", -HW, -HW + 0.08, UPPER, UPPER + RAIL, c0, c0 + 1.42, STEEL)   # the outer (left) edge
box("LandingRail", -HW, -HW + 0.08, UPPER, UPPER + RAIL, c1 - 1.42, c1, STEEL)
z = c1
# The C->D crossing is an open platform on both decks (railed, no walls: the cargo car feels open).
hwp = DOOR_W / 2 + 0.15
for y0, y1, col in ((-SLAB, 0.0, FLOOR), (UPPER - 0.2, UPPER, STEEL)):
    box("Platform", DOOR_X - hwp, DOOR_X + hwp, y0, y1, z, z + GAP, col)
    box("PlatformRail", DOOR_X - hwp - 0.08, DOOR_X - hwp, y1, y1 + RAIL, z, z + GAP, STEEL)
    box("PlatformRail", DOOR_X + hwp, DOOR_X + hwp + 0.08, y1, y1 + RAIL, z, z + GAP, STEEL)
z += GAP

# D: sleeper + baggage, mirrored.
d0 = z
z = closed_car(d0, BODY_D, m=-1, back_door=False)

TRAIN_Z0 = a0 - 16.0
TRAIN_Z1 = z

GROUND_Y = -1.45          # the scenery's ground (scripts/game/train_scenery.gd GROUND_Y)
KILL_HEIGHT = GROUND_Y + 0.25

# --- write the scene -------------------------------------------------------------------------------------------------

f = lambda v: "%g" % round(v, 4)


def block_nodes(items, parent):
    out = []
    for name, c, s, col, rot in items:
        cr, sr = math.cos(rot), math.sin(rot)
        out.append('\n[node name="%s" parent="%s" instance=ExtResource("2_block")]\n' % (name, parent))
        out.append("transform = Transform3D(1, 0, 0, 0, %s, %s, 0, %s, %s, %s, %s, %s)\n" % (f(cr), f(-sr), f(sr), f(cr), f(c[0]), f(c[1]), f(c[2])))
        out.append("size = Vector3(%s, %s, %s)\n" % tuple(map(f, s)))
        out.append("color = Color(%s, %s, %s, 1)\n" % tuple(map(f, col)))
        if rot or abs(c[1] - DECK_SPLIT) < 0.25:
            out.append("mesh_layers = %d\n" % (LAYER_LOWER | LAYER_UPPER))
        else:
            out.append("mesh_layers = %d\n" % (LAYER_LOWER if c[1] < DECK_SPLIT else LAYER_UPPER))
    return out


# The shell: the cars, the ground and the lamps.
out = ['[gd_scene format=3]\n\n[ext_resource type="PackedScene" path="res://prefabs/levels/block.tscn" id="2_block"]\n\n',
       '[sub_resource type="WorldBoundaryShape3D" id="ground_shape"]\n\n', '[node name="TrainShell" type="Node3D"]\n\n',
       '[node name="Geometry" type="Node3D" parent="."]\n']
out += block_nodes(blocks, "Geometry")
# Solid ground under the scenery's ground: whoever jumps off lands on it (and dies, see KILL_HEIGHT).
out.append('\n[node name="Ground" type="StaticBody3D" parent="."]\n')
out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)\n" % f(GROUND_Y))
out.append('\n[node name="Shape" type="CollisionShape3D" parent="Ground"]\nshape = SubResource("ground_shape")\n')
out.append('\n[node name="Lamps" type="Node3D" parent="."]\n')
for name, p in lights:
    out.append('\n[node name="%s" type="OmniLight3D" parent="Lamps"]\n' % name)
    out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n" % tuple(map(f, p)))
    out.append("light_color = Color(1, 0.86, 0.66, 1)\nlight_energy = 1.2\nomni_range = 9.0\nomni_attenuation = 1.4\n")
    deck = LAYER_LOWER if p[1] < DECK_SPLIT else LAYER_UPPER
    out.append("light_cull_mask = %d\n" % (LAYER_WORLD | LAYER_VIEWMODEL | deck))
open(OUT, "w", encoding="utf-8", newline="\n").write("".join(out))
print("wrote %s: %d blocks, %d lamps; train z %s .. %s (Scenery train_z0 / train_z1 in train.tscn), kill_height %s"
      % (OUT, len(blocks), len(lights), f(TRAIN_Z0), f(TRAIN_Z1), f(KILL_HEIGHT)))
