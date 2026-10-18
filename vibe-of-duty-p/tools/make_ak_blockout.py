"""Generates prefabs/weapons/ak_blockout.tscn: a blockout rifle inspired by the AK-47.

Run from the repo:  python vibe-of-duty-p/tools/make_ak_blockout.py   (overwrites the scene)

Conventions (as WeaponView expects): the barrel points to +Z, +Y is up, the origin sits under the receiver at the
trigger. Units are metres; the rifle is ~0.93 m long. The magazine is a node named "*_Mag_*" (WeaponView slides it
out during reloads). Key points used by WeaponDef (prefab space): muzzle (0, 0.045, 0.565), rear sight top
(0, 0.112, 0.28), front sight top (0, 0.11, 0.50), pistol grip (0, -0.055, -0.045), handguard bottom (0, 0.0, 0.35).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "ak_blockout.tscn")

MATERIALS = {
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),   # albedo, metallic, roughness
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "wood": ((0.45, 0.24, 0.1), 0.0, 0.7),
    "mag": ((0.62, 0.27, 0.1), 0.0, 0.55),
}

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, parent="."):
    parts.append((name, parent, "cyl", (radius, z1 - z0), (0.0, y, (z0 + z1) / 2), 90.0, mat))


# Receiver and dust cover.
box("Receiver", -0.025, 0.025, 0.0, 0.072, -0.11, 0.25, "steel")
box("DustCover", -0.022, 0.022, 0.072, 0.088, -0.1, 0.235, "steel_light")
box("RearSightBase", -0.016, 0.016, 0.072, 0.1, 0.25, 0.3, "steel")
box("RearSightLeafL", -0.014, -0.004, 0.1, 0.118, 0.27, 0.282, "steel_light")   # leaf with a U notch in the middle
box("RearSightLeafR", 0.004, 0.014, 0.1, 0.118, 0.27, 0.282, "steel_light")
box("RearSightLeafBase", -0.014, 0.014, 0.1, 0.112, 0.27, 0.282, "steel_light")
box("TriggerGuard", -0.006, 0.006, -0.03, -0.024, -0.03, 0.06, "steel")
box("Trigger", -0.004, 0.004, -0.024, 0.0, 0.0, 0.012, "steel_light")
box("Selector", 0.025, 0.031, 0.03, 0.045, -0.02, 0.1, "steel_light")
# Barrel, gas block, gas tube, muzzle, front sight.
tube("Barrel", 0.011, 0.25, 0.545, 0.045, "steel")
tube("MuzzleBrake", 0.015, 0.53, 0.565, 0.045, "steel_light")
box("GasBlock", -0.016, 0.016, 0.03, 0.09, 0.43, 0.46, "steel")
tube("GasTube", 0.014, 0.3, 0.44, 0.078, "steel")
box("FrontSightBase", -0.012, 0.012, 0.045, 0.09, 0.49, 0.51, "steel")
box("FrontSightPost", -0.0025, 0.0025, 0.09, 0.11, 0.497, 0.503, "steel_light")
box("FrontSightEarL", -0.013, -0.009, 0.085, 0.112, 0.494, 0.506, "steel")
box("FrontSightEarR", 0.009, 0.013, 0.085, 0.112, 0.494, 0.506, "steel")
# Wood: handguards, stock, pistol grip.
box("HandguardLower", -0.028, 0.028, 0.002, 0.058, 0.27, 0.42, "wood")
box("HandguardUpper", -0.022, 0.022, 0.064, 0.094, 0.3, 0.41, "wood")
box("Stock", -0.021, 0.021, -0.045, 0.045, -0.37, -0.1, "wood", rot_x=-7.0)
box("StockComb", -0.019, 0.019, 0.045, 0.06, -0.3, -0.11, "wood", rot_x=-7.0)
box("ButtPlate", -0.023, 0.023, -0.06, 0.05, -0.39, -0.37, "steel", rot_x=-7.0)
box("PistolGrip", -0.016, 0.016, -0.11, 0.0, -0.065, -0.03, "wood", rot_x=-18.0)
# Curved magazine: three segments, each turned a little more forward.
mag = "AK_Mag_01"
parts.append((mag, ".", "node", None, (0.0, 0.0, 0.085), 0.0, None))
for i, (y0, angle, dz) in enumerate([(0.0, 6.0, 0.0), (-0.07, 16.0, 0.012), (-0.135, 27.0, 0.035)]):
    parts.append(("Segment%d" % i, mag, "box", (0.028, 0.075, 0.062), (0.0, y0 - 0.035, dz), angle, "mag"))

f = lambda v: "%g" % round(v, 5)
res = []
for i, (key, (albedo, metal, rough)) in enumerate(MATERIALS.items()):
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="AK47" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    r = math.radians(rot)
    cr, sr = math.cos(r), math.sin(r)
    xform = "Transform3D(1, 0, 0, 0, %s, %s, 0, %s, %s, %s, %s, %s)" % (f(cr), f(-sr), f(sr), f(cr), f(c[0]), f(c[1]), f(c[2]))
    if kind == "node":
        nodes.append('\n[node name="%s" type="Node3D" parent="%s"]\ntransform = %s\n' % (name, parent, xform))
        continue
    if kind == "box":
        res.append('[sub_resource type="BoxMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\nsize = Vector3(%s, %s, %s)\n'
                   % (i, mat, f(params[0]), f(params[1]), f(params[2])))
    else:
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = 10\nrings = 1\n'
                   % (i, mat, f(params[0]), f(params[0]), f(params[1])))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    out.write("[gd_scene format=3]\n\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
