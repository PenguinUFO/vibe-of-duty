"""Generates prefabs/levels/train.tscn: a wide double-decker train (FFA, 2-4 players) running through a forest.

Run from the repo:  python vibe-of-duty-p/tools/make_train_map.py
Re-running overwrites the scene, so tune the layout here, not in the editor.

The train stands still (physics, netcode and lag compensation stay simple); the forest, the track and the tunnels
move past it (scripts/game/train_scenery.gd, visual only). The train runs along Z, the locomotive at -Z.

Layout, front to back: locomotive (decor) | A passenger | B dining | C open cargo car | D sleeper + baggage.
A, B and D are closed double-deckers (~80% of the map) with rows of windows on both decks; C has no roof: a cargo
pit with containers and crates, and a catwalk at upper-deck height linking B and D. Windows are 0.9 m tall, lower
than a crouching player (1.1 m), so nobody climbs out through them; the open car and the roofs are the way off the
train - and the ground beside the track kills on landing (World.kill_height just above a solid ground plane, so the
body lands instead of falling through the scenery).
"""
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "prefabs", "levels", "train.tscn")

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

# Colours (Block materials are shared per colour). The owner's palette (Docs/AUTHOR.md; scripts/game/palette.gd):
# warm greys, the cars told apart by lightness and one rust car, not by hue. Olive is kept for pickups (ammo bags).
# These are albedos: the palette's dark hexes are what the lit frame should look like, not surface colours.
BODY = (0.48, 0.46, 0.42)     # car body: A passenger
BODY_B = (0.52, 0.37, 0.3)   # dining car: rust
BODY_D = (0.58, 0.56, 0.51)   # sleeper: lighter grey
FLOOR = (0.38, 0.36, 0.33)
ROOF_C = (0.32, 0.31, 0.3)
INNER = (0.66, 0.63, 0.57)    # partitions
SEAT = (0.36, 0.33, 0.29)
TABLE = (0.48, 0.33, 0.24)    # wood
CRATE = (0.56, 0.47, 0.36)
CONTAINER = (0.48, 0.31, 0.24)
CONTAINER2 = (0.4, 0.41, 0.41)
STEEL = (0.42, 0.42, 0.41)
UNDER = (0.16, 0.155, 0.15)
LOCO = (0.27, 0.27, 0.26)
LAMP_COLOR = (1.0, 0.72, 0.45)  # Palette.EMBER as light

blocks = []   # (name, center, size, color, rot_x)
lights = []   # (name, position)
spawns = []   # (name, position, yaw)
_names = {}


def uniq(name):
    n = _names.get(name, 0)
    _names[name] = n + 1
    return name if n == 0 else "%s%d" % (name, n)


def box(name, x0, x1, y0, y1, z0, z1, color, rot_x=0.0):
    blocks.append((uniq(name), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), color, rot_x))


# --- pieces ---------------------------------------------------------------------------------------------------------

def side_wall(x_inner, outward, z0, z1, deck_y, top_y, color, panoramic=False):
    """A side wall from deck_y to top_y with a row of windows."""
    xa, xb = sorted((x_inner, x_inner + outward * T))
    low, high = (0.9, 2.3) if panoramic else (WIN_LOW, WIN_HIGH)
    box("WallLow", xa, xb, deck_y, deck_y + low, z0, z1, color)
    box("WallHigh", xa, xb, deck_y + high, top_y, z0, z1, color)
    # Pillars between the windows, evenly spread over the length.
    length = z1 - z0
    count = max(1, int((length - PILLAR) // (WIN_W + PILLAR)))
    pillar = (length - count * WIN_W) / (count + 1)
    z = z0
    for _ in range(count + 1):
        box("Pillar", xa, xb, deck_y + low, deck_y + high, z, z + pillar, color)
        z += pillar + WIN_W


def end_wall(z_face, inward, deck_y, top_y, color, door=True):
    """A car end wall (across the car) at z_face, optionally with a centred door."""
    za, zb = sorted((z_face, z_face + inward * T))
    if not door:
        box("EndWall", -W / 2, W / 2, deck_y, top_y, za, zb, color)
        return
    box("EndWall", -W / 2, -DOOR_W / 2, deck_y, top_y, za, zb, color)
    box("EndWall", DOOR_W / 2, W / 2, deck_y, top_y, za, zb, color)
    box("Lintel", -DOOR_W / 2, DOOR_W / 2, deck_y + DOOR_H, top_y, za, zb, color)


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


def closed_car(z0, color, front_door=True, back_door=True, panoramic_upper=False):
    z1 = z0 + L
    box("Underframe", -W / 2 + 0.5, W / 2 - 0.5, -1.3, -SLAB, z0 + 1.0, z1 - 1.0, UNDER)
    box("Floor", -W / 2, W / 2, -SLAB, 0.0, z0, z1, FLOOR)
    box("Roof", -W / 2, W / 2, ROOF, ROOF + SLAB, z0, z1, ROOF_C)
    s1 = (HW - STAIR_W, HW, z0 + 1.2, z0 + 1.2 + STAIR_RUN)          # front stairs, right side, rising backwards
    s2 = (-HW, -HW + STAIR_W, z1 - 1.2 - STAIR_RUN, z1 - 1.2)        # back stairs, left side, rising forwards
    upper_floor(z0 + T, z1 - T, [s1, s2])
    ramp(s1[0], s1[1], s1[2], s1[3])
    ramp(s2[0], s2[1], s2[3], s2[2])
    # Guard rails along the stair holes on the upper deck (the open side of each hole).
    box("Rail", s1[0] - 0.1, s1[0], UPPER, UPPER + 1.0, s1[2], s1[3], STEEL)
    box("Rail", s2[1], s2[1] + 0.1, UPPER, UPPER + 1.0, s2[2], s2[3], STEEL)
    for deck_y, top_y, pano in ((0.0, UPPER, False), (UPPER, ROOF + SLAB, panoramic_upper)):
        side_wall(HW, 1, z0, z1, deck_y, top_y, color, pano)
        side_wall(-HW, -1, z0, z1, deck_y, top_y, color, pano)
        end_wall(z0, 1, deck_y, top_y, color, front_door)
        end_wall(z1, -1, deck_y, top_y, color, back_door)
    lights.append((uniq("Lamp"), (0.0, UPPER - SLAB - 0.4, z0 + L / 2)))
    lights.append((uniq("Lamp"), (0.0, ROOF - 0.4, z0 + L / 2)))
    return z1


def gangway(z0, z1):
    """Covered walkway between two cars on both decks."""
    hw = DOOR_W / 2 + 0.15
    box("GangwayFloor", -hw, hw, -SLAB, 0.0, z0, z1, FLOOR)
    box("GangwayFloor", -hw, hw, UPPER - SLAB, UPPER, z0, z1, FLOOR)
    box("GangwayRoof", -hw - T, hw + T, ROOF, ROOF + SLAB, z0, z1, ROOF_C)
    box("GangwayWall", -hw - T, -hw, -SLAB, ROOF, z0, z1, UNDER)
    box("GangwayWall", hw, hw + T, -SLAB, ROOF, z0, z1, UNDER)


# --- the train -------------------------------------------------------------------------------------------------------

TOTAL = 4 * L + 3 * GAP
z = -TOTAL / 2

# Locomotive (solid decor) in front of car A.
box("Loco", -W / 2 + 0.2, W / 2 - 0.2, -1.3, 5.2, z - 16.0, z - 1.5, LOCO)
box("LocoCab", -W / 2 + 0.2, W / 2 - 0.2, 5.2, 6.2, z - 6.0, z - 1.5, LOCO)

# A: passenger car. Lower deck: seat rows on both sides of the aisle; upper deck: rows too, plus luggage stacks.
a0 = z
z = closed_car(a0, BODY, front_door=False)
for i in range(6):
    zz = a0 + 8.5 + i * 1.8
    if zz > a0 + L - 8.5:
        break
    box("Seat", -HW, -0.8, 0.0, 1.0, zz, zz + 0.45, SEAT)
    box("Seat", 0.8, HW, 0.0, 1.0, zz, zz + 0.45, SEAT)
for i in range(4):
    zz = a0 + 8.0 + i * 1.8
    box("Seat", -HW + STAIR_W, -0.8, UPPER, UPPER + 1.0, zz, zz + 0.45, SEAT)
    box("Seat", 0.8, HW, UPPER, UPPER + 1.0, zz + 0.9, zz + 1.35, SEAT)
box("Luggage", -HW + STAIR_W, -HW + STAIR_W + 1.0, UPPER, UPPER + 1.6, a0 + 3.0, a0 + 4.2, CRATE)
box("Luggage", HW - 1.2, HW, UPPER, UPPER + 1.2, a0 + L - 4.5, a0 + L - 3.3, CRATE)
spawns.append(("SpawnA_low", (0.0, 0.05, a0 + 3.5), math.pi))      # facing back along the car
spawns.append(("SpawnA_up", (0.0, UPPER + 0.05, a0 + L - 3.0), 0.0))

gangway(z, z + GAP)
z += GAP

# B: dining car. Lower deck: tables in two rows and a bar counter; upper deck: panoramic lounge with partitions.
b0 = z
z = closed_car(b0, BODY_B, panoramic_upper=True)
for i in range(3):
    zz = b0 + 8.0 + i * 2.6
    box("Table", -HW + 0.2, -HW + 1.2, 0.0, 0.85, zz, zz + 1.0, TABLE)
    box("Table", HW - 1.2, HW - 0.2, 0.0, 0.85, zz + 1.3, zz + 2.3, TABLE)
box("Bar", -0.4, 0.4, 0.0, 1.1, b0 + 3.0, b0 + 6.5, TABLE)
box("Partition", -HW + STAIR_W, -0.7, UPPER, ROOF, b0 + 9.0, b0 + 9.25, INNER)   # rooms on the upper deck, door in the middle
box("Partition", 0.7, HW - STAIR_W, UPPER, ROOF, b0 + 11.5, b0 + 11.75, INNER)
box("Sofa", 0.9, HW - 0.2, UPPER, UPPER + 0.8, b0 + 13.5, b0 + 14.5, SEAT)
box("Sofa", -HW + STAIR_W + 0.2, -0.9, UPPER, UPPER + 0.8, b0 + 5.5, b0 + 6.5, SEAT)
spawns.append(("SpawnB_up", (0.0, UPPER + 0.05, b0 + 4.0), math.pi))

gangway(z, z + GAP)
z += GAP

# C: open cargo car (no roof). A pit with containers and crates; a catwalk at upper-deck height joins B and D.
c0 = z
c1 = c0 + L
box("Underframe", -W / 2 + 0.5, W / 2 - 0.5, -1.3, -SLAB, c0 + 1.0, c1 - 1.0, UNDER)
box("Floor", -W / 2, W / 2, -SLAB, 0.0, c0, c1, FLOOR)
box("Side", HW, W / 2, 0.0, 1.4, c0, c1, BODY)
box("Side", -W / 2, -HW, 0.0, 1.4, c0, c1, BODY)
box("Container", -HW + 0.1, -HW + 2.6, 0.0, 2.6, c0 + 2.0, c0 + 8.0, CONTAINER)
box("Container", -0.4, 2.0, 0.0, 2.6, c0 + 11.5, c0 + 17.5, CONTAINER2)
box("Crate", 0.4, 1.6, 0.0, 1.2, c0 + 4.0, c0 + 5.2, CRATE)
box("Crate", -HW + 0.1, -HW + 1.3, 0.0, 1.2, c0 + 9.0, c0 + 10.2, CRATE)
box("Crate", -HW + 0.1, -HW + 1.3, 1.2, 2.4, c0 + 9.0, c0 + 10.2, CRATE)
box("Crate", 2.2, HW, 0.0, 1.2, c0 + 14.0, c0 + 15.2, CRATE)
# Catwalk along the right side at upper-deck height, with a low rail on the inner side (players may drop into the pit).
cw0, cw1 = HW - 1.4, HW
box("Catwalk", cw0, cw1, UPPER - 0.2, UPPER, c0, c1, STEEL)
box("CatwalkRail", cw0, cw0 + 0.08, UPPER, UPPER + 1.0, c0 + 1.5, c0 + 8.0, STEEL)
box("CatwalkRail", cw0, cw0 + 0.08, UPPER, UPPER + 1.0, c0 + 12.0, c1 - 1.5, STEEL)
box("CatwalkRail", cw1 - 0.08, cw1, UPPER, UPPER + 1.0, c0, c1, STEEL)
for zz in (c0 + 4.0, c0 + 10.0, c0 + 16.0):
    box("CatwalkPost", cw0 + 0.4, cw0 + 0.7, 0.0, UPPER - 0.2, zz, zz + 0.3, STEEL)
spawns.append(("SpawnC", (-1.0, 0.05, c0 + 10.5), math.pi / 2))

# Landings across the car at both ends, at upper-deck height: from the upper doors of B and D onto the catwalk.
box("Landing", -HW, HW, UPPER - 0.2, UPPER, c0, c0 + 1.5, STEEL)
box("Landing", -HW, HW, UPPER - 0.2, UPPER, c1 - 1.5, c1, STEEL)
box("LandingRail", -HW, cw0, UPPER, UPPER + 1.0, c0 + 1.42, c0 + 1.5, STEEL)
box("LandingRail", -HW, cw0, UPPER, UPPER + 1.0, c1 - 1.5, c1 - 1.42, STEEL)
z = c1
# The C->D crossing is an open platform on both decks (no walls: the cargo car feels open).
hwp = DOOR_W / 2 + 0.15
box("Platform", -hwp, hwp, -SLAB, 0.0, z, z + GAP, FLOOR)
box("Platform", -hwp, hwp, UPPER - 0.2, UPPER, z, z + GAP, STEEL)
z += GAP

# D: sleeper + baggage. Lower deck: baggage shelves and crates; upper deck: sleeper compartments off a side corridor.
d0 = z
z = closed_car(d0, BODY_D, back_door=False)
for i in range(3):
    zz = d0 + 8.0 + i * 1.6
    box("Shelf", HW - 0.9, HW, 0.0, 2.2, zz, zz + 0.8, STEEL)
box("Crate", -HW + 0.2, -HW + 1.4, 0.0, 1.2, d0 + 9.0, d0 + 10.2, CRATE)
box("Crate", -1.0, 0.2, 0.0, 1.2, d0 + 12.5, d0 + 13.7, CRATE)
box("Crate", -1.0, 0.2, 1.2, 2.4, d0 + 12.5, d0 + 13.7, CRATE)
# Compartments: walls across the car from the left wall to the corridor, door gaps on the corridor side.
corridor_x = 1.0
box("CorridorWall", corridor_x, corridor_x + 0.15, UPPER, ROOF, d0 + 8.0, d0 + 9.2, INNER)
box("CorridorWall", corridor_x, corridor_x + 0.15, UPPER, ROOF, d0 + 10.4, d0 + 11.4, INNER)
box("CorridorWall", corridor_x, corridor_x + 0.15, UPPER, ROOF, d0 + 12.6, d0 + 13.0, INNER)
for zz in (d0 + 8.0, d0 + 11.4):
    box("Compartment", -HW + STAIR_W, corridor_x, UPPER, ROOF, zz, zz + 0.15, INNER)
box("Bunk", -HW + STAIR_W + 0.1, corridor_x - 0.2, UPPER, UPPER + 0.6, d0 + 8.6, d0 + 9.6, SEAT)
spawns.append(("SpawnD_low", (0.0, 0.05, d0 + L - 3.5), 0.0))
spawns.append(("SpawnD_up", (-1.0, UPPER + 0.05, d0 + 3.5), math.pi))  # x clear of the front stair hole (right side)

TRAIN_Z0 = a0 - 16.0
TRAIN_Z1 = z

GROUND_Y = -1.45          # the scenery's ground (scripts/game/train_scenery.gd GROUND_Y)
KILL_HEIGHT = GROUND_Y + 0.25

# Scene header (resources, sky with its clouds, environment) and the WorldEnvironment + Sun nodes.
HEAD = r'''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/net/world.gd" id="1_world"]
[ext_resource type="PackedScene" path="res://prefabs/levels/block.tscn" id="2_block"]
[ext_resource type="Shader" path="res://assets/shaders/sky_clouds.gdshader" id="3_sky"]

[ext_resource type="Script" path="res://scripts/game/train_scenery.gd" id="4_scenery"]

[sub_resource type="ShaderMaterial" id="sky_mat"]
shader = ExtResource("3_sky")
shader_parameter/cloud_offset = Vector2(-3.4, 5.2)
shader_parameter/cloud_coverage = 0.56

[sub_resource type="Sky" id="sky"]
sky_material = SubResource("sky_mat")

[sub_resource type="Environment" id="env"]
background_mode = 2
sky = SubResource("sky")
ambient_light_source = 3
ambient_light_color = Color(0.62, 0.6, 0.57, 1)
ambient_light_sky_contribution = 0.45
ambient_light_energy = 0.75
tonemap_mode = 4
tonemap_exposure = 1.15
tonemap_white = 8.0
fog_enabled = true
fog_light_color = Color(0.72, 0.77, 0.83, 1)
fog_density = 0.0035
fog_aerial_perspective = 0.6
fog_sky_affect = 0.0
adjustment_enabled = true
adjustment_contrast = 1.08
adjustment_saturation = 1.15
'''

ENV_AND_SUN = r'''[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(-0.7660, -0.3957, 0.5065, 0.0000, 0.7880, 0.6157, -0.6428, 0.4716, -0.6037, 0, 12, 0)
light_color = Color(1, 0.92, 0.8, 1)
light_energy = 2.2
shadow_enabled = true
shadow_bias = 0.05
shadow_blur = 1.5
directional_shadow_mode = 1
directional_shadow_max_distance = 60.0
'''

# --- write the scene -------------------------------------------------------------------------------------------------

head = HEAD
env_and_sun = ENV_AND_SUN

f = lambda v: "%g" % round(v, 4)
out = []
out.append(head.rstrip("\n") + "\n\n" + '[sub_resource type="WorldBoundaryShape3D" id="ground_shape"]\n\n')
out.append('[node name="Train" type="Node3D"]\n\n')
out.append(env_and_sun)
out.append('[node name="Geometry" type="Node3D" parent="."]\n')
for name, c, s, col, rot in blocks:
    cr, sr = math.cos(rot), math.sin(rot)
    out.append('\n[node name="%s" parent="Geometry" instance=ExtResource("2_block")]\n' % name)
    out.append("transform = Transform3D(1, 0, 0, 0, %s, %s, 0, %s, %s, %s, %s, %s)\n" % (f(cr), f(-sr), f(sr), f(cr), f(c[0]), f(c[1]), f(c[2])))
    out.append("size = Vector3(%s, %s, %s)\n" % tuple(map(f, s)))
    out.append("color = Color(%s, %s, %s, 1)\n" % tuple(map(f, col)))
# Solid ground under the scenery's ground: whoever jumps off lands on it (and dies, see KILL_HEIGHT).
out.append('\n[node name="Ground" type="StaticBody3D" parent="."]\n')
out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)\n" % f(GROUND_Y))
out.append('\n[node name="Shape" type="CollisionShape3D" parent="Ground"]\nshape = SubResource("ground_shape")\n')
out.append('\n[node name="Lamps" type="Node3D" parent="."]\n')
for name, p in lights:
    out.append('\n[node name="%s" type="OmniLight3D" parent="Lamps"]\n' % name)
    out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n" % tuple(map(f, p)))
    out.append("light_color = Color(1, 0.86, 0.66, 1)\nlight_energy = 1.2\nomni_range = 9.0\nomni_attenuation = 1.4\n")
out.append('\n[node name="SpawnPoints" type="Node3D" parent="."]\n')
for name, p, yaw in spawns:
    c, s = math.cos(yaw), math.sin(yaw)
    out.append('\n[node name="%s" type="Marker3D" parent="SpawnPoints"]\n' % name)
    out.append("transform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)\n" % (f(c), f(s), f(-s), f(c), f(p[0]), f(p[1]), f(p[2])))
out.append('\n[node name="Scenery" type="Node3D" parent="."]\nscript = ExtResource("4_scenery")\n')
out.append("train_z0 = %s\ntrain_z1 = %s\n" % (f(TRAIN_Z0), f(TRAIN_Z1)))
out.append('\n[node name="Players" type="Node3D" parent="."]\n')
out.append('\n[node name="World" type="Node" parent="."]\nscript = ExtResource("1_world")\nkill_height = %s\n' % f(KILL_HEIGHT))
open(OUT, "w", encoding="utf-8", newline="\n").write("".join(out))
print("wrote %s: %d blocks, %d lamps, %d spawns, train %.1f m" % (OUT, len(blocks), len(lights), len(spawns), TRAIN_Z1 - TRAIN_Z0))
