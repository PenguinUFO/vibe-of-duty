"""Generates prefabs/weapons/p90_blockout.tscn: a blockout of the FN P90 (Standard), 5.7x28, 263 mm barrel.

Run from the repo:  python vibe-of-duty-p/tools/make_p90_blockout.py   (overwrites the scene)
              or:  python vibe-of-duty-p/tools/make_p90_blockout.py --parts   (prints the profiles for
                   tools/make_parts.gd; paste them there and run it - the scene uses its meshes)

Docs/LOADOUT.md, "P90". After the owner's photos (2026-10-27): the left side on white (500 mm long, so 0.2864 mm a
pixel), the outlines traced off its silhouette; the others for the sight's front and back and the magazine. A bullpup:
the body - the butt, the thumb hole and the trigger hole through it, the hook in front for the support hand's fingers -
grey polymer; over its front the black housing of the integral ring sight (MC-10-80: no magnification, a ring and a
dot) - a box with a window through it (the eye looks through it: walls, top, bottom), a strap behind it over the
magazine, a short rail on each side, the top cover; the translucent 50-round magazine flat on top, its rounds lying
across in two rows; the cocking knobs on both sides under the sight, the slotted flash hider. The empties drop out of the
bottom behind the grip.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin sits
at the top of the trigger hole by the trigger, metres; prefab +x is the shooter's left. "Mags" holds "P90_Mag_50" (a
node named "*_Mag_*"), its origin on its front's bottom - the catch it tips up about for a reload (WeaponDef.mag_hinge).
"Handle": the two cocking knobs (WeaponView moves it back by hand at the end of a reload; it does not ride the bolt).
Key points used by WeaponDB (prefab space): bore y 0.0209; muzzle (0, 0.0209, 0.1678); the sight line y 0.0871 through
the window's back (z -0.0272) and front (z 0.1254); grip (0, -0.024, -0.038); support hand
(0, -0.024, 0.093); the left knob (0.034, 0.0163, 0.0768); the catch (0, 0.0361, 0.0825).
"""
import math
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "p90_blockout.tscn")

MATERIALS = {
    # The body a dark grey polymer, the sight's housing near black, the magazine smoked and see-through (WeaponSkin
    # leaves transparent ones as they are), its rounds copper.
    "polymer": ((0.14, 0.14, 0.145), 0.0, 0.7),       # albedo, metallic, roughness(, alpha)
    "housing": ((0.06, 0.06, 0.065), 0.0, 0.6),
    "steel": ((0.12, 0.12, 0.13), 0.55, 0.45),
    "steel_grey": ((0.3, 0.3, 0.31), 0.6, 0.45),      # the cocking rod, the knobs
    "steel_dark": ((0.02, 0.02, 0.025), 0.5, 0.5),    # cuts, slots, the bore
    "rubber": ((0.06, 0.06, 0.065), 0.0, 0.9),
    "mag": ((0.16, 0.14, 0.11), 0.0, 0.3, 0.85),      # smoked polymer: the rounds show through
    "mag_end": ((0.12, 0.12, 0.125), 0.0, 0.7),
    "round": ((0.42, 0.24, 0.11), 0.6, 0.45),
}
MESHES = ["body", "lower", "front", "strap", "optic_wall", "optic_top", "optic_bottom", "sight_front", "cover",
          "trigger"]
K = 0.5 / (1886 - 140)  # m a pixel: the photo's 1746 px are the gun's 500 mm
PX0 = (1300, 630)       # the photo's pixel at the origin (the trigger hole's top, at the trigger)


def P(x, y):
    """A photo pixel -> (z, y) in metres."""
    return ((x - PX0[0]) * K, (PX0[1] - y) * K)


def Z(x):
    return P(x, 0)[0]


def Y(y):
    return P(0, y)[1]


BORE_Y = Y(557)
MUZZLE_Z = Z(1886)
SIGHT_Y = Y(326)       # the window's middle: from 292 (under the top) to 360 (over the bottom)
REAR_Z = Z(1205)       # the window's back and front
FRONT_Z = Z(1738)
WALL_X = 0.0138        # the window's side walls round their middle, 1.6 mm wide (the window 26 mm across); the
                       # frame round the window a quarter as thick as at first (owner, 2026-10-27: twice halved)
HINGE = (0.0, Y(504), Z(1588))  # the magazine's front bottom: its catch

# Side profiles for tools/make_parts.gd, photo pixels round the outline: (points, half width, chamfer).
PROFILES = {
    # The body: the butt and everything over the holes, the magazine's bed on top.
    "body": ([(145, 442), (160, 431), (668, 431), (668, 504), (1600, 504), (1600, 630), (600, 630), (600, 828),
              (590, 845), (160, 846), (146, 836)], 0.0275, 0.005),
    # Under it from the butt to the grip: the thumb hole a notch in its top (the body closes it), the grip in front of it.
    "lower": ([(600, 630), (910, 630), (878, 642), (864, 654), (854, 666), (848, 678), (845, 690), (844, 702),
               (844, 714), (846, 726), (848, 738), (854, 750), (864, 762), (878, 774), (906, 788), (938, 787),
               (968, 774), (994, 762), (1020, 750), (1046, 738), (1064, 726), (1072, 714), (1078, 702), (1080, 690),
               (1080, 678), (1076, 666), (1070, 654), (1060, 642), (1038, 630), (1245, 630), (1245, 785), (1220, 789),
               (1180, 827), (1140, 858), (1100, 881), (1060, 896), (1020, 907), (960, 912), (860, 912), (840, 908),
               (820, 888), (780, 876), (740, 863), (700, 850), (660, 838), (640, 832), (620, 827)], 0.0265, 0.003),
    # The front: round the trigger hole's bottom and front, the support hand's place under the sight, the hook.
    "front": ([(1245, 766), (1430, 766), (1444, 756), (1455, 744), (1464, 720), (1460, 696), (1444, 672),
               (1420, 650), (1400, 632), (1600, 630), (1735, 615), (1735, 768), (1728, 775), (1684, 775),
               (1670, 712), (1650, 702), (1600, 699), (1582, 708), (1562, 797), (1540, 836), (1520, 860), (1500, 878),
               (1480, 890), (1460, 900), (1420, 910), (1310, 911), (1294, 902), (1293, 872), (1304, 860),
               (1300, 792), (1290, 786), (1245, 785)], 0.025, 0.003),
    # The sight's housing: the strap behind the window, over the magazine; its side walls (two, WALL_X out), top and
    # bottom; the front over the barrel; the top cover.
    "strap": ([(1135, 560), (1133, 505), (1190, 360), (1290, 360), (1290, 382), (1258, 398), (1256, 560)], 0.0285, 0.004),
    "optic_wall": ([(1190, 360), (1195, 300), (1205, 289), (1240, 288), (1320, 287), (1700, 289), (1738, 340),
                    (1738, 360)], 0.0008, 0.0003),
    "optic_top": ([(1200, 292), (1203, 289), (1240, 288), (1320, 287), (1700, 289), (1706, 292)], 0.013, 0.0005),
    "optic_bottom": ([(1290, 360), (1600, 360), (1600, 430), (1560, 430), (1540, 418), (1290, 382)], 0.0185, 0.003),
    "sight_front": ([(1600, 360), (1738, 360), (1738, 615), (1600, 615)], 0.0185, 0.004),
    "cover": ([(1335, 288), (1342, 275), (1628, 275), (1634, 289)], 0.0145, 0.002),
    # The trigger: a wide blade in the hole's back half.
    "trigger": ([(1252, 640), (1290, 640), (1330, 690), (1326, 724), (1300, 728), (1252, 700)], 0.006, 0.002),
}

if "--parts" in sys.argv:
    v = lambda p: "Vector2(%g, %g)" % (round(P(*p)[0], 4), round(P(*p)[1], 4))
    print('\t"p90": {\n\t\t"profiles": {')
    for name, (points, hw, chamfer) in PROFILES.items():
        lines, line = [], "\t\t\t\"%s\": {\"points\": [" % name
        for i, p in enumerate(points):
            item = v(p) + (", " if i < len(points) - 1 else "]")
            if len(line) + len(item) > 116:
                lines.append(line.rstrip())
                line = "\t\t\t\t\t"
            line += item
        lines.append(line + ',')
        print("\n".join(lines))
        print('\t\t\t\t\t"width": [Vector2(0.0, %g)], "chamfer": %g},' % (hw, chamfer))
    print('\t\t},\n\t\t"sections": {},\n\t},')
    sys.exit()

parts = []
node_pos = {".": (0.0, 0.0, 0.0)}


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent=".", radius_end=None, segments=12):
    parts.append((name, parent, "cyl", (radius, z1 - z0, radius if radius_end is None else radius_end, segments),
                  (x, y, (z0 + z1) / 2), 90.0, mat))


def post(name, radius, y0, y1, z, mat, x=0.0, parent=".", segments=16):
    """A cylinder standing up (its axis along y)."""
    parts.append((name, parent, "cyl", (radius, y1 - y0, radius, segments), (x, (y0 + y1) / 2, z), 0.0, mat))


def disc(name, radius, x0, x1, y, z, mat, parent="."):
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent=".", x=0.0):
    parts.append((name, parent, "ext_mesh", key, (x, 0.0, 0.0), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))
    node_pos[name if parent == "." else parent + "/" + name] = pos


def both(x0, x1):
    return (("L", x0, x1), ("R", -x1, -x0))


# The body, the lower round the thumb hole and the grip, the front with the hook; the butt's rubber pad, the sling
# slot under it, the screws on both sides; the trigger and the safety's dial under it; the ejection chute in the
# bottom behind the grip.
mesh("Body", "body", "polymer")
mesh("Lower", "lower", "polymer")
mesh("Front", "front", "polymer")
box("Pad", -0.0262, 0.0262, Y(843), Y(440), Z(140), Z(150), "rubber")
box("SlingSlot", -0.008, 0.008, Y(846) - 0.0005, Y(842), Z(222), Z(310), "steel_dark")
box("Chute", -0.009, 0.009, Y(852) - 0.0005, Y(846), Z(675), Z(765), "steel_dark")
for side, x0, x1 in both(0.0262, 0.028):
    for i, (px, py) in enumerate(((210, 528), (425, 512), (585, 770), (330, 797), (1150, 662), (1083, 822),
                                  (875, 840), (1408, 840))):
        disc("Screw%s%d" % (side, i), 0.0018, x0, x1, Y(py), Z(px), "steel")
    disc("Pin" + side, 0.0055, x0, x1 + 0.0008, Y(535), Z(740), "polymer")  # the boss under the magazine's back
    box("Catch" + side, x0 + 0.001 if side == "L" else x0 - 0.003, x1 + 0.003 if side == "L" else x1 - 0.001,
        Y(500), Y(462), Z(598), Z(690), "mag_end")  # the magazine's catch, a tab each side
mesh("Trigger", "trigger", "steel")
post("Safety", 0.0106, Y(752), Y(735), Z(1305), "steel_dark")

# The sight's housing: strap, the window's walls, top and bottom, the front over the barrel, the top cover; a short rail
# on each side, the adjuster's knob in front of it; the window's glass front and back (WeaponView's sight model draws
# the ring: SightModels "ring").
mesh("Strap", "strap", "housing")
for side, x in (("L", WALL_X), ("R", -WALL_X)):
    mesh("Wall" + side, "optic_wall", "housing", x=x)
mesh("OpticTop", "optic_top", "housing")
mesh("OpticBottom", "optic_bottom", "housing")
mesh("SightFront", "sight_front", "housing")
mesh("Cover", "cover", "housing")
for side, x0, x1 in both(0.0146, 0.0161):
    box("Rail" + side, x0, x1, Y(345), Y(293), Z(1395), Z(1580), "housing")
    for i in range(6):
        z = Z(1405) + i * 0.0085
        box("RailSlot%s%d" % (side, i), x0 - 0.0005 if side == "R" else x0, x1 + 0.0005 if side == "L" else x1,
            Y(345) - 0.0005, Y(293) + 0.0005, z, z + 0.004, "steel_dark")
    disc("Adjuster" + side, 0.0055, x0, x0 + 0.003 if side == "L" else x0 + 0.002, Y(318), Z(1645), "steel")
box("SideSlotL", WALL_X + 0.0005, WALL_X + 0.001, Y(358), Y(334), Z(1210), Z(1300), "steel_dark")
box("SideSlotR", -WALL_X - 0.001, -WALL_X - 0.0005, Y(358), Y(334), Z(1210), Z(1300), "steel_dark")

# Under the magazine in front: the housing's lower edge, the cocking channel each side with its rod; the knobs ("Handle").
for side, x0, x1 in both(0.0275, 0.0305):
    box("Ledge" + side, x0, x1, Y(548), Y(504), Z(1256), Z(1600), "housing")
    box("Channel" + side, x0, x1, Y(598), Y(548), Z(1256), Z(1600), "steel_dark")
    tube("Rod" + side, 0.0035, Z(1260), Z(1596), Y(573), "steel_grey", x=(x0 + x1) / 2)
node("Handle", ".", (0.0, Y(573), Z(1568)))
for side, x in (("L", 1), ("R", -1)):
    disc("Knob" + side, 0.0075, x * 0.03 if x > 0 else -0.038, 0.038 if x > 0 else -0.03, Y(573), Z(1568),
         "steel_grey", parent="Handle")

# Barrel: the nut out of the sight's front, the flash hider with its rings and slots.
tube("Nut", 0.0085, Z(1735), Z(1768), BORE_Y, "steel")
tube("Hider", 0.0104, Z(1768), MUZZLE_Z, BORE_Y, "steel", segments=14)
for i, px in enumerate((1785, 1800)):
    tube("HiderRing%d" % i, 0.0108, Z(px), Z(px + 6), BORE_Y, "steel")
for i in range(4):
    a = i * math.pi / 2 + math.pi / 4
    x, y = 0.0104 * math.cos(a), BORE_Y + 0.0104 * math.sin(a)
    box("HiderSlot%d" % i, x - 0.0016, x + 0.0016, y - 0.0016, y + 0.0016, Z(1818), Z(1855), "steel_dark")
tube("Bore", 0.0032, MUZZLE_Z - 0.02, MUZZLE_Z + 0.0004, BORE_Y, "steel_dark")

# The magazine flat on top, its origin on the catch at its front's bottom: the smoked body, the grey ends, 50 rounds
# lying across in two staggered rows (5.7x28: 40 mm long, 7.9 mm across the rim).
node("Mags")
node("P90_Mag_50", "Mags", HINGE)
mp = "Mags/P90_Mag_50"
box("Body", -0.0245, 0.0245, Y(504), Y(432), Z(696), Z(1576), "mag", parent=mp)
box("BackEnd", -0.0245, 0.0245, Y(504), Y(432), Z(668), Z(696), "mag_end", parent=mp)
box("FrontEnd", -0.0245, 0.0245, Y(504), Y(436), Z(1576), Z(1590), "mag_end", parent=mp)
for row, py in enumerate((452, 484)):
    for i in range(25):
        z = Z(708) + (i + 0.5 * row) * (Z(1560) - Z(708)) / 25.5
        disc("Round%d_%d" % (row, i), 0.0036, -0.02, 0.02, Y(py), z, "round", parent=mp)

f = lambda v: "%g" % round(v, 5)
res = []
for key, spec in MATERIALS.items():
    albedo, metal, rough = spec[:3]
    alpha = spec[3] if len(spec) > 3 else 1.0
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\n%salbedo_color = Color(%s, %s, %s, %s)\nmetallic = %s\nroughness = %s\n'
               % (key, key, "transparency = 1\n" if alpha < 1.0 else "", f(albedo[0]), f(albedo[1]), f(albedo[2]),
                  f(alpha), f(metal), f(rough)))
nodes = ['[node name="P90" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    o = node_pos[parent]
    c = (c[0] - o[0], c[1] - o[1], c[2] - o[2])  # into the parent's space (nothing is turned at rest)
    if kind == "cylx":
        xform = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %s, %s, %s)" % (f(c[0]), f(c[1]), f(c[2]))
    else:
        rr = math.radians(rot)
        cr, sr = math.cos(rr), math.sin(rr)
        xform = "Transform3D(1, 0, 0, 0, %s, %s, 0, %s, %s, %s, %s, %s)" % (f(cr), f(-sr), f(sr), f(cr), f(c[0]), f(c[1]), f(c[2]))
    if kind == "node":
        nodes.append('\n[node name="%s" type="Node3D" parent="%s"]\ntransform = %s\n' % (name, parent, xform))
        continue
    if kind == "ext_mesh":
        nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = ExtResource("%s")\n'
                     'surface_material_override/0 = SubResource("mat_%s")\n' % (name, parent, xform, params, mat))
        continue
    if kind == "box":
        res.append('[sub_resource type="BoxMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\nsize = Vector3(%s, %s, %s)\n'
                   % (i, mat, f(params[0]), f(params[1]), f(params[2])))
    else:
        top = params[2] if kind == "cyl" else params[0]
        segments = params[3] if kind == "cyl" else 8
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(top), f(params[0]), f(params[1]), segments))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/p90_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
