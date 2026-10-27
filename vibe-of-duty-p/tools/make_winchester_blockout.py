"""Generates prefabs/weapons/winchester_blockout.tscn: a blockout of the Winchester Model 1887, 12 gauge, 22" barrel.

Run from the repo:  python vibe-of-duty-p/tools/make_winchester_blockout.py   (overwrites the scene)
The receiver, the stock and the fore-end are meshes made by tools/make_parts.gd
(prefabs/weapons/winchester_<part>_mesh.tres) - run that first if they change.

Docs/LOADOUT.md, "Winchester 1887". After the owner's photos (2026-10-27): the left side of a blued one with a 22"
barrel and the full-length tube (the modern Chiappa's proportions: 1003 mm long, 2.026 mm a pixel), the original's
receiver and lever for the shapes. A lever action with a rolling block: the barrel over the magazine tube, both in the
fore-end and tied by a band near the muzzle; the tall receiver with its top open behind the barrel when the lever is
down (shells go in there, the spent hull flies out there); the hammer on top; the lever's small front loop round the
trigger and the long rear loop for the fingers; the straight-gripped stock with a deep drop. No rear sight - a bead
up front, the receiver's top behind.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres; prefab +x is the shooter's left. Moving parts (WeaponView): "Lever" -
its origin on the pivot low in the receiver's front, turns about +X (rear down) after every shot and while loading;
"Hammer" - its origin on its pin, falls forward on a shot, the lever cocks it; "Shell" - a shell at the open top,
shown while the left hand pushes it in.
Key points used by WeaponDB (prefab space): bore y 0.073; muzzle (0, 0.073, 0.64); the sight line y 0.0895 over the
receiver's top (z 0.09) and the bead (z 0.625); lever pivot (0, 0.012, 0.07); the action's top (0, 0.092, 0.07);
wrist (0, -0.024, -0.061); fore-end (0, 0.028, 0.27).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "winchester_blockout.tscn")

MATERIALS = {
    "steel": ((0.07, 0.075, 0.09), 0.6, 0.35),      # albedo, metallic, roughness (blued)
    "steel_frame": ((0.2, 0.22, 0.26), 0.6, 0.4),   # the receiver: lighter, worn grey-blue in the photos
    "steel_dark": ((0.03, 0.03, 0.035), 0.5, 0.5),  # the bore, screw slots
    "wood": ((0.34, 0.17, 0.09), 0.0, 0.6),         # walnut
    "hull": ((0.62, 0.1, 0.08), 0.0, 0.5),          # the shell's red plastic
    "brass": ((0.62, 0.46, 0.2), 0.7, 0.35),
}
MESHES = ["receiver", "stock", "forend"]
K = 0.002026  # m a pixel of the side photo
PX0 = (318, 66)  # the photo's pixel at the origin (the trigger, the receiver's bottom); the muzzle is to the photo's left


def P(x, y):
    """A photo pixel -> (z, y) in metres."""
    return ((PX0[0] - x) * K, (PX0[1] - y) * K)


BORE_Y = 0.073
BARREL_R = 0.0115
MUZZLE_Z = 0.64
BREECH_Z = 0.11
TUBE_Y = 0.0446
TUBE_R = 0.011
TUBE_END = 0.502
PIVOT = (0.012, 0.07)       # (y, z): the lever's pivot
HAMMER_PIN = (0.055, 0.04)
SHELL_PORT = (0.092, 0.07)  # the open top, where the left hand thumbs a shell in

parts = []      # (name, parent, kind, size/params, center (absolute, rest pose), rot_x_deg, material)
node_pos = {".": (0.0, 0.0, 0.0)}  # node path -> its absolute position (rest pose; nothing turned)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def bar(name, a, b, half_x, thick, mat, parent="."):
    """A flat bar from photo pixel `a` to `b` (the lever's loops): `half_x` across the gun, `thick` in the side plane."""
    za, ya = P(*a)
    zb, yb = P(*b)
    length = math.hypot(zb - za, yb - ya) + thick  # overlapping at the corners
    angle = -math.degrees(math.atan2(yb - ya, zb - za))  # the scene writes the basis by rows: +rot_x tips +Z down
    parts.append((name, parent, "box", (2 * half_x, thick, length), (0.0, (ya + yb) / 2, (za + zb) / 2), angle, mat))


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


# Receiver, its screws, the trigger under it; the stock with its steel butt plate.
mesh("Receiver", "receiver", "steel_frame")
for side, x0, x1 in both(0.0195, 0.0205):
    for i, (px, py) in enumerate(((300, 58), (283, 62), (270, 44))):
        z, y = P(px, py)
        disc("Screw%s%d" % (side, i), 0.0028, x0, x1, y, z, "steel", )
    disc("PivotPin" + side, 0.0035, x0, x1, PIVOT[0], PIVOT[1], "steel")
box("Trigger", -0.003, 0.003, -0.022, -0.002, -0.004, 0.003, "steel", rot_x=-12.0)
mesh("Stock", "stock", "wood")
box("ButtPlate", -0.021, 0.021, -0.131, -0.003, -0.3667, -0.3627, "steel")

# Barrel over the magazine tube, the band tying them near the muzzle, the bead; the fore-end round both.
tube("Barrel", BARREL_R, BREECH_Z, MUZZLE_Z, BORE_Y, "steel", segments=16)
tube("Bore", 0.0093, MUZZLE_Z - 0.03, MUZZLE_Z + 0.0004, BORE_Y, "steel_dark")
tube("Tube", TUBE_R, BREECH_Z, TUBE_END, TUBE_Y, "steel", segments=14)
tube("TubeCap", TUBE_R + 0.0005, TUBE_END, TUBE_END + 0.008, TUBE_Y, "steel", segments=14)
box("Band", -0.0125, 0.0125, TUBE_Y - 0.007, BORE_Y + 0.006, TUBE_END + 0.004, TUBE_END + 0.016, "steel")
disc("BandScrew", 0.002, -0.013, 0.013, (TUBE_Y + BORE_Y) / 2, TUBE_END + 0.01, "steel_dark")
box("Bead", -0.002, 0.002, BORE_Y + BARREL_R - 0.001, 0.0895, MUZZLE_Z - 0.018, MUZZLE_Z - 0.014, "brass")
mesh("Forend", "forend", "wood")
for side, x0, x1 in both(0.0189, 0.0196):
    for i, z in enumerate((0.19, 0.33)):
        disc("ForendPin%s%d" % (side, i), 0.0022, x0, x1, 0.055, z, "steel")

# Hammer: on top behind the barrel, its spur back (cocked).
node("Hammer", ".", (0.0, HAMMER_PIN[0], HAMMER_PIN[1]))
box("Body", -0.0045, 0.0045, HAMMER_PIN[0] - 0.004, 0.084, 0.034, 0.05, "steel", parent="Hammer")
box("Spur", -0.004, 0.004, 0.08, 0.0855, 0.016, 0.04, "steel", rot_x=10.0, parent="Hammer")  # under the sight line
for i in range(3):  # the spur's checkering
    z = 0.019 + i * 0.006
    box("Knurl%d" % i, -0.0042, 0.0042, 0.0852, 0.0862, z, z + 0.002, "steel_dark", rot_x=10.0, parent="Hammer")

# Lever: the bar under the receiver from the pivot, the small front loop round the trigger, the long rear loop.
node("Lever", ".", (0.0, PIVOT[0], PIVOT[1]))
lv = "Lever"
disc("Boss", 0.006, -0.0085, 0.0085, PIVOT[0], PIVOT[1], "steel", parent=lv)
bar("Bar", (285, 64), (300, 68), 0.0085, 0.006, "steel", parent=lv)
front = [(298, 68), (334, 68), (337, 80), (331, 92), (313, 94), (301, 86), (298, 68)]
for i in range(len(front) - 1):
    bar("Front%d" % i, front[i], front[i + 1], 0.0045, 0.0045, "steel", parent=lv)
rear = [(334, 70), (354, 80), (376, 112), (371, 121), (359, 119), (340, 96), (333, 88)]
for i in range(len(rear) - 1):
    bar("Rear%d" % i, rear[i], rear[i + 1], 0.0045, 0.0045, "steel", parent=lv)

# The shell the left hand pushes into the open top: lying along the bore, the brass head to the rear.
node("Shell", ".", (0.0, SHELL_PORT[0], SHELL_PORT[1]))
tube("Hull", 0.0102, SHELL_PORT[1] - 0.023, SHELL_PORT[1] + 0.047, SHELL_PORT[0], "hull", parent="Shell")
tube("Head", 0.0106, SHELL_PORT[1] - 0.035, SHELL_PORT[1] - 0.023, SHELL_PORT[0], "brass", parent="Shell")

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Winchester" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    o = node_pos[parent]
    c = (c[0] - o[0], c[1] - o[1], c[2] - o[2])  # into the parent's space (nothing is turned at rest)
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
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/winchester_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
