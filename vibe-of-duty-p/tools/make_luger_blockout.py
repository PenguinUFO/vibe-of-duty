"""Generates prefabs/weapons/luger_blockout.tscn: a blockout of the Luger P08 (Pistole Parabellum 1908), 9x19.

Run from the repo:  python vibe-of-duty-p/tools/make_luger_blockout.py   (overwrites the scene)
The trigger guard with the grip frame, and the grip panels, are meshes made by tools/make_parts.gd
(prefabs/weapons/luger_<part>_mesh.tres) - run that first if they change.

Docs/LOADOUT.md, "Люгер". A P08 with the artillery model's parts as modules: the barrel 100 mm (P08) / 150 mm (navy) /
200 mm (Lange Pistole 08: a tangent rear sight on the barrel, none on the toggle), the board stock on the grip's heel
lug, the TM08 "snail" drum (32 rounds, hangs left of the grip). Sizes from memory of the real gun (length 222 mm with
the 100 mm barrel, grip ~55 degrees to the bore), not measured from photos. Built life size; the game draws it
1.2 times bigger (WeaponDef.model_scale: life size, the two fists hid it).

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres. Module variants (WeaponDef.model_variants) are groups whose children
are the options: "Barrel" (B100 / B150 / B200), "Toggle/LinkRear/Sight" (Notch / Plain), "Stock" (None / Board),
"Mags" (Luger_Mag_8 / Luger_Mag_32: nodes named "*_Mag_*" so reloads take them out; a node sits 0.11 m above and
0.015 m behind where the hand holds it, WeaponView.mag_grip_point, so it is not where the magazine is).
The toggle: "Toggle/LinkRear" pivots on the frame, "Toggle/LinkFront" hangs from the knee, "Toggle/Breech" slides; the
links point along +Z from their node; WeaponView folds them up as the breech goes back (shots, reloads).
Key points used by WeaponDB (prefab space): muzzle (0, 0.03, 0.105 / 0.155 / 0.205); rear sight notch on the toggle
(0, 0.048, -0.098), on the 200 mm barrel (0, 0.049, 0.0905); front post tips (0, 0.05, muzzle - 0.008); grip
(0, -0.076, -0.111); toggle knobs (+-0.017, 0.042, -0.07).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "luger_blockout.tscn")

MATERIALS = {
    "steel": ((0.11, 0.11, 0.13), 0.6, 0.4),     # albedo, metallic, roughness (blued)
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "wood": ((0.36, 0.2, 0.1), 0.0, 0.7),
    "mag": ((0.1, 0.1, 0.105), 0.4, 0.5),
}

MESHES = ["frame_upper", "frame_lower", "grip_panels"]
BORE_Y = 0.03
GRIP_RAKE = 35.0  # degrees back from vertical (the bore to the grip ~55)

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent=".", radius_end=None):
    """A cylinder along the barrel; `radius_end` at z1 tapers it."""
    parts.append((name, parent, "cyl", (radius, z1 - z0, radius if radius_end is None else radius_end),
                  (x, y, (z0 + z1) / 2), 90.0, mat))


def disc(name, radius, x0, x1, y, z, mat, parent="."):
    """A cylinder across the gun (axis along X)."""
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent="."):
    parts.append((name, parent, "ext_mesh", key, (0.0, 0.0, 0.0), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))


def along_grip(top, dist):
    """The point `dist` m down the grip's axis from `top` (y, z)."""
    r = math.radians(GRIP_RAKE)
    return (top[0] - dist * math.cos(r), top[1] - dist * math.sin(r))


def grip_box(name, half_x, top, length, depth, mat, parent=".", start=0.0):
    """A box along the raked grip: from `start` to `start + length` down its axis, `depth` front to back."""
    y, z = along_grip(top, start + length / 2)
    parts.append((name, parent, "box", (2 * half_x, length, depth), (0.0, y, z), GRIP_RAKE, mat))  # + tips the bottom back (to -Z)


# Frame: the lower frame with the trigger guard, side walls the toggle sits between, the hinge ears at the rear.
mesh("Frame", "frame_upper", "steel")  # the rounded nose under the barrel (tools/make_parts.gd)
box("FrameWallL", 0.009, 0.012, 0.02, 0.04, -0.11, -0.03, "steel")
box("FrameWallR", -0.012, -0.009, 0.02, 0.04, -0.11, -0.03, "steel")
box("HingeEars", -0.012, 0.012, 0.02, 0.046, -0.118, -0.1, "steel")
box("Receiver", -0.011, 0.011, 0.02, 0.042, -0.03, 0.065, "steel")  # the barrel extension
tube("BarrelShank", 0.011, 0.065, 0.08, BORE_Y, "steel")
box("SidePlate", 0.012, 0.0135, -0.012, 0.016, -0.03, 0.045, "steel_light")
box("Safety", 0.012, 0.016, -0.004, 0.012, -0.102, -0.086, "steel_light")
box("MagRelease", 0.012, 0.016, -0.032, -0.021, -0.048, -0.038, "steel_light")
box("TakedownLever", 0.012, 0.0145, 0.0, 0.012, 0.04, 0.056, "steel_light")  # front left of the frame
box("Trigger", -0.004, 0.004, -0.036, -0.015, -0.002, 0.008, "steel_light")
# Grip: raked far back, walnut panels over the frame, the stock lug at the heel.
GRIP_TOP = (-0.015, -0.068)
GRIP_LEN = 0.1
mesh("FrameLower", "frame_lower", "steel")  # the guard's loop and the grip frame (tools/make_parts.gd)
mesh("GripPanels", "grip_panels", "wood")
heel_y, heel_z = along_grip(GRIP_TOP, GRIP_LEN - 0.006)
heel_y, heel_z = heel_y + 0.017 * math.sin(math.radians(GRIP_RAKE)), heel_z - 0.017 * math.cos(math.radians(GRIP_RAKE))  # the back strap
box("StockLug", -0.006, 0.006, heel_y - 0.006, heel_y + 0.006, heel_z - 0.008, heel_z + 0.002, "steel")

# The toggle at rest: rear link from the hinge to the knee, front link from the knee to the breech block's pin.
node("Toggle")
node("LinkRear", "Toggle", (0.0, 0.04, -0.105))
box("Link", -0.009, 0.009, -0.006, 0.008, 0.0, 0.035, "steel", parent="Toggle/LinkRear")
for side, x0, x1 in (("L", 0.009, 0.021), ("R", -0.021, -0.009)):  # the knobs the hand racks
    disc("Knob" + side, 0.009, x0, x1, 0.002, 0.035, "steel_light", parent="Toggle/LinkRear")
node("Sight", "Toggle/LinkRear")
node("Notch", "Toggle/LinkRear/Sight")
node("Plain", "Toggle/LinkRear/Sight")
box("EarL", 0.0015, 0.006, 0.008, 0.016, 0.003, 0.011, "steel", parent="Toggle/LinkRear/Sight/Notch")
box("EarR", -0.006, -0.0015, 0.008, 0.016, 0.003, 0.011, "steel", parent="Toggle/LinkRear/Sight/Notch")
node("LinkFront", "Toggle", (0.0, 0.04, -0.07))
box("Link", -0.008, 0.008, -0.006, 0.008, 0.0, 0.04, "steel", parent="Toggle/LinkFront")
node("Breech", "Toggle", (0.0, 0.04, -0.03))
box("Block", -0.009, 0.009, -0.012, 0.008, 0.0, 0.035, "steel", parent="Toggle/Breech")

# Barrels: 100 / 150 / 200 mm from the breech face (z 0.005), a front post at the muzzle; the 200 mm one carries the
# tangent rear sight ahead of the receiver.
node("Barrel")
for name, muzzle in (("B100", 0.105), ("B150", 0.155), ("B200", 0.205)):
    node(name, "Barrel")
    p = "Barrel/" + name
    tube("Tube", 0.0095, 0.08, muzzle, BORE_Y, "steel", parent=p, radius_end=0.0072)  # tapering to the muzzle
    box("FrontBase", -0.004, 0.004, BORE_Y + 0.006, BORE_Y + 0.011, muzzle - 0.016, muzzle - 0.002, "steel", parent=p)
    box("FrontPost", -0.0015, 0.0015, BORE_Y + 0.011, 0.05, muzzle - 0.012, muzzle - 0.004, "steel_light", parent=p)
    if name == "B200":
        box("TangentBase", -0.009, 0.009, BORE_Y + 0.006, 0.049, 0.082, 0.1, "steel", parent=p)
        box("TangentEarL", 0.0015, 0.008, 0.049, 0.058, 0.086, 0.095, "steel", parent=p)
        box("TangentEarR", -0.008, -0.0015, 0.049, 0.058, 0.086, 0.095, "steel", parent=p)

# Stock: none, or the board (the holster) on the heel lug: a plank widening to the butt.
node("Stock")
node("None", "Stock")
node("Board", "Stock")
box("Fitting", -0.009, 0.009, heel_y - 0.01, heel_y + 0.012, heel_z - 0.035, heel_z - 0.006, "steel", parent="Stock/Board")
z0, z1 = heel_z - 0.035, -0.43
for i in range(10):  # the plank in steps: its top rises a little, its bottom drops to the butt
    t0, t1 = i / 10.0, (i + 1) / 10.0
    top = heel_y + 0.012 + 0.03 * t1
    bottom = heel_y - 0.008 - 0.08 * t1
    box("Plank%d" % i, -0.015, 0.015, bottom, top, z0 + (z1 - z0) * t1, z0 + (z1 - z0) * t0, "wood", parent="Stock/Board")
box("ButtPlate", -0.016, 0.016, heel_y - 0.092, heel_y + 0.044, -0.436, -0.428, "steel", parent="Stock/Board")

# Magazines, both into the grip: the 8-round box (only its wooden base shows) and the TM08 snail - a neck up the grip,
# the drum below and left of it, its winding key on the left face.
node("Mags")
base_y, base_z = along_grip(GRIP_TOP, GRIP_LEN)
node("Luger_Mag_8", "Mags", (0.0, base_y + 0.11, base_z - 0.015))
mag_top = (GRIP_TOP[0] - base_y - 0.11, GRIP_TOP[1] - base_z + 0.015)  # the grip's top in the node's space
grip_box("Body", 0.006, mag_top, 0.095, 0.022, "mag", parent="Mags/Luger_Mag_8", start=0.008)
grip_box("Base", 0.011, mag_top, 0.014, 0.03, "wood", parent="Mags/Luger_Mag_8", start=GRIP_LEN - 0.001)
drum_y, drum_z = base_y - 0.03, base_z + 0.05  # forward of the grip, under the trigger guard's rear
node("Luger_Mag_32", "Mags", (0.0, drum_y + 0.11, drum_z - 0.015))
local = lambda y, z: (y - drum_y - 0.11, z - drum_z + 0.015)
mag_top = local(*GRIP_TOP)
grip_box("Neck", 0.006, mag_top, GRIP_LEN + 0.02, 0.022, "mag", parent="Mags/Luger_Mag_32", start=0.008)
dy, dz = local(drum_y, drum_z)
disc("Drum", 0.048, -0.006, 0.04, dy, dz, "mag", parent="Mags/Luger_Mag_32")
disc("Key", 0.012, 0.04, 0.05, dy, dz, "steel_light", parent="Mags/Luger_Mag_32")
box("KeyArm", 0.044, 0.05, dy - 0.004, dy + 0.004, dz - 0.03, dz, "steel_light", parent="Mags/Luger_Mag_32")

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Luger" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    if kind == "cylx":  # the cylinder's Y axis turned onto X
        xform = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %s, %s, %s)" % (f(c[0]), f(c[1]), f(c[2]))
    else:
        r = math.radians(rot)
        cr, sr = math.cos(r), math.sin(r)
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
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = 12\nrings = 1\n'
                   % (i, mat, f(params[2] if len(params) > 2 else params[0]), f(params[0]), f(params[1])))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/luger_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
