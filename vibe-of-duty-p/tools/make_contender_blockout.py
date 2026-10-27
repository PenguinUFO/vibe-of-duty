"""Generates prefabs/weapons/contender_blockout.tscn: a blockout of the Thompson/Center Contender, .375 JDJ, 14" barrel.

Run from the repo:  python vibe-of-duty-p/tools/make_contender_blockout.py   (overwrites the scene)
The frame, the grip, the fore-end and the trigger guard are meshes made by tools/make_parts.gd
(prefabs/weapons/contender_<part>_mesh.tres) - run that first if they change.

Docs/LOADOUT.md, "Contender". After the owner's photos (2026-10-27) of a blued Contender with walnut: the left side
of a 14" round bull barrel, 0.826 mm a pixel (the barrel 431 px from the breech face to the muzzle). A single shot
that breaks open: the barrel hinges on a pin in the frame's front, the fore-end screwed under it goes with it; the
adjustable rear sight and the ramped front blade sit on the barrel; the hammer behind the standing breech, its spur
back; the trigger guard's rear spur is the lever that unlocks the barrel; the chunky raked grip with its finger shelf.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the frame at the trigger, metres; prefab +x is the shooter's left. Moving parts (WeaponView):
"Break" - the barrel with its sights, lug and fore-end; its origin on the hinge pin, it turns about +X (muzzle down)
for reloads; "Break/Round" - the cartridge in the chamber, its origin at the case head ("Bullet" hidden while it is
a spent case); "Hammer" - its origin on the hammer's pin, falls forward on a shot; "Trigger".
Key points used by WeaponDB (prefab space): bore y 0.0438; muzzle (0, 0.0438, 0.335); breech face z -0.019; hinge
(0, 0.0149, 0.0231); sight line y 0.069 over the rear notch (z 0.002) and the front blade's tip (z 0.314); grip
(0, -0.03, -0.054); fore-end's underside (0, 0.012, 0.17).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "contender_blockout.tscn")

MATERIALS = {
    "steel": ((0.07, 0.075, 0.09), 0.6, 0.35),     # albedo, metallic, roughness (blued)
    "steel_frame": ((0.17, 0.18, 0.21), 0.6, 0.4),  # the frame: lighter, grey-blue in the photos
    "steel_dark": ((0.03, 0.03, 0.035), 0.5, 0.5),  # the bore, slots
    "wood": ((0.36, 0.18, 0.09), 0.0, 0.6),        # walnut
    "brass": ((0.62, 0.46, 0.2), 0.7, 0.35),
    "lead": ((0.38, 0.38, 0.4), 0.3, 0.55),
}
MESHES = ["frame", "grip", "forend", "guard"]
K = 0.000826  # m a pixel of the side photo
PX0 = (160, 150)  # the photo's pixel at the origin (the trigger's pin, the frame's bottom)


def P(x, y):
    """A photo pixel -> (z, y) in metres."""
    return ((x - PX0[0]) * K, (PX0[1] - y) * K)


BORE_Y = 0.0438
BARREL_R = 0.0107       # 0.86" bull barrel
BREECH_Z = -0.019
MUZZLE_Z = 0.335
HINGE = (0.0149, 0.0231)  # (y, z): the pin in the frame's front, half way down under the barrel
HAMMER_PIN = (0.0347, -0.0264)
SIGHT_Y = 0.069
CASE_LEN = 0.053        # .375 JDJ: .444 Marlin necked down
BULLET_LEN = 0.022      # out of the case; 270 gr

parts = []      # (name, parent, kind, size/params, center (absolute, rest pose), rot_x_deg, material)
node_pos = {".": (0.0, 0.0, 0.0)}  # node path -> its absolute position (rest pose; nothing turned)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent=".", radius_end=None, segments=12):
    """A cylinder along the barrel; `radius_end` at z1 tapers it."""
    parts.append((name, parent, "cyl", (radius, z1 - z0, radius if radius_end is None else radius_end, segments),
                  (x, y, (z0 + z1) / 2), 90.0, mat))


def disc(name, radius, x0, x1, y, z, mat, parent="."):
    """A cylinder across the gun (axis along X)."""
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent="."):
    parts.append((name, parent, "ext_mesh", key, (0.0, 0.0, 0.0), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))
    node_pos[name if parent == "." else parent + "/" + name] = pos


def both(x0, x1):
    """(side, x0, x1) on the left (+x) and mirrored on the right."""
    return (("L", x0, x1), ("R", -x1, -x0))


# Frame: the box with the standing breech (the firing pin's hole in its face), the hinge pin's heads low in front, the
# trigger's and hammer's pins; the grip over its tang; the guard.
mesh("Frame", "frame", "steel_frame")
tube("FiringPin", 0.0016, BREECH_Z - 0.0006, BREECH_Z + 0.0002, BORE_Y, "steel_dark")
for side, x0, x1 in both(0.0115, 0.0125):
    disc("HingePin" + side, 0.0035, x0, x1, HINGE[0], HINGE[1], "steel")
    disc("TriggerPin" + side, 0.0022, x0, x1, P(0, 148)[1], P(161, 0)[0], "steel")
    disc("HammerPin" + side, 0.0025, x0, x1, HAMMER_PIN[0], HAMMER_PIN[1], "steel")
mesh("Grip", "grip", "wood")
mesh("TriggerGuard", "guard", "steel")
node("Trigger", ".", (0.0, -0.006, 0.0))
box("Blade", -0.003, 0.003, -0.032, -0.006, -0.002, 0.004, "steel", rot_x=-22.0, parent="Trigger")

# Hammer: on its pin behind the standing breech, the body up to the top and the spur back (cocked, as in the photo).
node("Hammer", ".", (0.0, HAMMER_PIN[0], HAMMER_PIN[1]))
box("Body", -0.004, 0.004, HAMMER_PIN[0] - 0.004, P(0, 82)[1], P(112, 0)[0], P(126, 0)[0], "steel", parent="Hammer")
box("Spur", -0.0035, 0.0035, P(0, 93)[1], P(0, 88)[1], P(86, 0)[0], P(114, 0)[0], "steel", rot_x=-6.0, parent="Hammer")
box("SpurPad", -0.0055, 0.0055, P(0, 95)[1], P(0, 88)[1], P(83, 0)[0], P(94, 0)[0], "steel", rot_x=-6.0, parent="Hammer")
for i in range(3):  # the pad's checkering
    z = P(84 + 3 * i, 0)[0]
    box("Knurl%d" % i, -0.0057, 0.0057, P(0, 89)[1], P(0, 88)[1] + 0.0004, z, z + 0.001, "steel_dark", rot_x=-6.0,
        parent="Hammer")

# Break: everything that drops when the barrel is opened - the barrel with its lug in the frame, the sights, the
# fore-end under it, the round in the chamber.
node("Break", ".", (0.0, HINGE[0], HINGE[1]))
b = "Break"
tube("Barrel", BARREL_R, BREECH_Z, MUZZLE_Z, BORE_Y, "steel", radius_end=BARREL_R - 0.0004, segments=16, parent=b)
tube("Bore", 0.0048, MUZZLE_Z - 0.03, MUZZLE_Z + 0.0004, BORE_Y, "steel_dark", parent=b)
tube("Chamber", 0.0066, BREECH_Z - 0.0004, BREECH_Z + 0.01, BORE_Y, "steel_dark", parent=b)  # around the rim
box("Lug", -0.008, 0.008, 0.008, BORE_Y - 0.006, 0.006, 0.036, "steel", parent=b)
disc("LugPin", 0.003, -0.0085, 0.0085, HINGE[0], HINGE[1], "steel_dark", parent=b)
box("Extractor", 0.004, 0.0095, BORE_Y - 0.009, BORE_Y - 0.004, BREECH_Z - 0.0002, BREECH_Z + 0.012, "steel", parent=b)
# The rear sight: a plate on the barrel, the leaf with its notch at the back; the sight line over the notch's floor
# level with the ears' tops (as the other guns: WeaponView puts the eye on the line through both tips).
box("RearBase", -0.006, 0.006, BORE_Y + BARREL_R - 0.001, 0.059, 0.002, 0.062, "steel", parent=b)
box("RearScrew", -0.0025, 0.0025, 0.059, 0.0605, 0.03, 0.035, "steel_dark", parent=b)
box("RearLeaf", -0.0085, 0.0085, 0.059, SIGHT_Y - 0.0045, 0.0, 0.005, "steel", parent=b)
for side, x0, x1 in both(0.0028, 0.0085):  # the notch wide enough to see light either side of the front blade
    box("RearEar" + side, x0, x1, SIGHT_Y - 0.0045, SIGHT_Y, 0.0, 0.005, "steel", parent=b)
# The front: a ramp on a band, the blade on it, the bead's flat face to the eye.
ramp0, ramp1 = P(489, 0)[0], MUZZLE_Z - 0.004
box("FrontBand", -0.005, 0.005, BORE_Y + BARREL_R - 0.001, 0.059, ramp0, ramp1, "steel", parent=b)
box("FrontRamp", -0.004, 0.004, 0.054, 0.0625, ramp0 + 0.01, P(535, 0)[0], "steel", rot_x=-9.0, parent=b)
box("FrontBlade", -0.0016, 0.0016, 0.058, SIGHT_Y, P(533, 0)[0], P(548, 0)[0], "steel", parent=b)
mesh("Forend", "forend", "wood", parent=b)
disc("ForendScrew", 0.003, -0.0165, 0.0165, P(0, 128)[1], P(300, 0)[0], "steel", parent=b)
# The round, its head at the breech face: the rim, the case, the shoulder and neck, the bullet (gone when spent).
node("Round", b, (0.0, BORE_Y, BREECH_Z))
r = b + "/Round"
tube("Rim", 0.0065, BREECH_Z, BREECH_Z + 0.0015, BORE_Y, "brass", parent=r)
tube("Case", 0.006, BREECH_Z + 0.0015, BREECH_Z + CASE_LEN - 0.01, BORE_Y, "brass", radius_end=0.0058, parent=r)
tube("Shoulder", 0.0058, BREECH_Z + CASE_LEN - 0.01, BREECH_Z + CASE_LEN - 0.006, BORE_Y, "brass", radius_end=0.0052,
     parent=r)
tube("Neck", 0.0052, BREECH_Z + CASE_LEN - 0.006, BREECH_Z + CASE_LEN, BORE_Y, "brass", parent=r)
tube("Primer", 0.0022, BREECH_Z - 0.0003, BREECH_Z, BORE_Y, "steel_dark", parent=r)
node("Bullet", r, (0.0, BORE_Y, BREECH_Z + CASE_LEN))
tube("Ogive", 0.0048, BREECH_Z + CASE_LEN, BREECH_Z + CASE_LEN + BULLET_LEN, BORE_Y, "lead", radius_end=0.002,
     parent=r + "/Bullet")

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Contender" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    o = node_pos[parent]
    c =(c[0] - o[0], c[1] - o[1], c[2] - o[2])  # into the parent's space (nothing is turned at rest)
    if kind == "cylx":  # the cylinder's Y axis turned onto X
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
        top = params[2] if kind == "cyl" else params[0]  # a CylinderMesh's top is +Y: turned onto +Z, the far end
        segments = params[3] if kind == "cyl" else 8
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(top), f(params[0]), f(params[1]), segments))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/contender_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
