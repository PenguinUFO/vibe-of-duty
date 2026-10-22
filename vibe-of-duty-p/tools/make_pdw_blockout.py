"""Generates prefabs/weapons/pdw_blockout.tscn: a blockout of the Parker-Hale PDW (Bushman IDW), 9x19, late 1980s.

Run from the repo:  python vibe-of-duty-p/tools/make_pdw_blockout.py   (overwrites the scene)

Taken from the side photos (Docs/LOADOUT.md, "PDW"): a flat slab receiver with a top rail, a short threaded barrel, the
magazine well in front of the trigger guard (the left hand holds it), a pistol grip at the very rear, a frame stock
on two rods each side that slides forward along the gun (folded: the butt frame sits in front of the magazine well).
Scale ~1.2 mm per photo pixel, from the trigger guard; the width is guessed (no top view).

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres. Module variants (WeaponDef.model_variants) are groups whose children
are the options; WeaponView keeps the one the build picks: "Stock" (Extended / Folded), "Mags" (PDW_Mag_32 /
PDW_Mag_20, nodes named "*_Mag_*" so reloads slide them out), "Muzzle" (Thread / Suppressor).
Key points used by WeaponDB (prefab space): muzzle (0, 0.02, 0.236) - with the suppressor (0, 0.02, 0.38); rear
sight notch (0, 0.08, -0.115), front post tip (0, 0.08, 0.115), pistol grip (0, -0.065, -0.0925), magazine well
(0, -0.06, 0.087).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "pdw_blockout.tscn")

MATERIALS = {
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),   # albedo, metallic, roughness
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "grip": ((0.07, 0.07, 0.075), 0.0, 0.75),
    "mag": ((0.1, 0.1, 0.105), 0.4, 0.5),
}

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent="."):
    parts.append((name, parent, "cyl", (radius, z1 - z0), (x, y, (z0 + z1) / 2), 90.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))


# Receiver: a flat slab with the rail on top, a narrower nose and a lower frame tying the well, guard and grip.
box("Receiver", -0.022, 0.022, 0.0, 0.058, -0.138, 0.15, "steel")
box("Nose", -0.018, 0.018, 0.006, 0.048, 0.15, 0.168, "steel")
box("Rail", -0.012, 0.012, 0.058, 0.068, -0.126, 0.126, "steel_light")
for i in range(9):  # cross slots along the rail
    z = -0.11 + i * 0.0275
    box("RailSlot%d" % i, -0.0125, 0.0125, 0.064, 0.0685, z, z + 0.008, "steel")
box("LowerFrame", -0.018, 0.018, -0.02, 0.0, -0.126, 0.108, "steel")
box("MagWell", -0.02, 0.02, -0.096, 0.0, 0.066, 0.108, "steel")
box("MagRelease", 0.02, 0.025, -0.03, -0.015, 0.06, 0.07, "steel_light")
# Iron sights on the rail (the photos show none: a plain notch and post).
box("RearSightBase", -0.012, 0.012, 0.068, 0.08, -0.122, -0.108, "steel")
box("RearSightEarL", 0.003, 0.011, 0.08, 0.092, -0.12, -0.11, "steel")   # notch between the ears
box("RearSightEarR", -0.011, -0.003, 0.08, 0.092, -0.12, -0.11, "steel")
box("FrontSightPost", -0.0025, 0.0025, 0.068, 0.08, 0.112, 0.118, "steel_light")
box("FrontSightEarL", 0.008, 0.012, 0.068, 0.085, 0.108, 0.122, "steel")
box("FrontSightEarR", -0.012, -0.008, 0.068, 0.085, 0.108, 0.122, "steel")
# Trigger group and the pistol grip at the rear.
box("TriggerGuard", -0.006, 0.006, -0.054, -0.048, -0.04, 0.04, "steel")
box("TriggerGuardFront", -0.006, 0.006, -0.054, -0.02, 0.034, 0.04, "steel")
box("TriggerGuardRear", -0.006, 0.006, -0.054, -0.02, -0.046, -0.04, "steel")
box("Trigger", -0.004, 0.004, -0.035, -0.02, 0.0, 0.01, "steel_light")
box("Selector", 0.022, 0.027, 0.02, 0.034, -0.1, -0.07, "steel_light")
box("PistolGrip", -0.017, 0.017, -0.144, 0.0, -0.1335, -0.0575, "grip", rot_x=6.0)  # + tips the bottom back; top behind the guard
# Barrel with the thread for a suppressor.
tube("Barrel", 0.012, 0.15, 0.215, 0.02, "steel")
tube("Thread", 0.0095, 0.215, 0.236, 0.02, "steel_light")

# Muzzle variants: bare thread, or the suppressor screwed on.
node("Muzzle")
node("Thread", "Muzzle")
node("Suppressor", "Muzzle")
tube("Can", 0.021, 0.21, 0.38, 0.02, "mag", parent="Muzzle/Suppressor")
tube("CanCap", 0.017, 0.38, 0.385, 0.02, "steel", parent="Muzzle/Suppressor")

# Magazines: a straight double stack, 0.09 m of it inside the well. 32 rounds hang 0.16 m below it, 20 rounds 0.08 m.
node("Mags")
for name, below in (("PDW_Mag_32", 0.16), ("PDW_Mag_20", 0.08)):
    node(name, "Mags", (0.0, -0.096, 0.087))
    box("Body", -0.011, 0.011, -below, 0.09, -0.0165, 0.0165, "mag", parent="Mags/" + name)
    box("Floor", -0.013, 0.013, -below - 0.008, -below, -0.019, 0.019, "steel", parent="Mags/" + name)

# Stock: a frame on two rods each side (upper along the receiver, lower under the grip), a butt frame of two side
# bars and a bottom crossbar (no top bar: folded, it sits around the receiver's nose).
node("Stock")
for variant, butt_z, rod_z in (("Extended", -0.4, (-0.4, -0.12)), ("Folded", 0.11, (-0.14, 0.116))):
    node(variant, "Stock")
    p = "Stock/" + variant
    for side, x in (("L", 0.029), ("R", -0.029)):
        tube("RodUpper" + side, 0.005, rod_z[0], rod_z[1], 0.045, "steel_light", x=x, parent=p)
        tube("RodLower" + side, 0.005, rod_z[0], rod_z[1], -0.14, "steel_light", x=x, parent=p)
        box("ButtBar" + side, x - 0.005, x + 0.005, -0.152, 0.055, butt_z, butt_z + 0.012, "steel", parent=p)
    box("ButtCross", -0.034, 0.034, -0.152, -0.136, butt_z, butt_z + 0.012, "steel", parent=p)

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="PDW" type="Node3D"]\n']
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
