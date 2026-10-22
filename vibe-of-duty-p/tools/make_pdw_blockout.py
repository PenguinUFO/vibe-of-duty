"""Generates prefabs/weapons/pdw_blockout.tscn: a blockout of the Parker-Hale PDW (Bushman IDW), 9x19, late 1980s.

Run from the repo:  python vibe-of-duty-p/tools/make_pdw_blockout.py   (overwrites the scene)
Shaped parts (receiver, grip, trigger guard, magazine well, the stock's butt) are meshes made by tools/make_parts.gd
(prefabs/weapons/pdw_<part>_mesh.tres) - run that first if they change.

Taken from the side photos (Docs/LOADOUT.md, "PDW"): a slab receiver with a rounded nose and a rail with cross slots
on top, a knurled barrel nut and a short threaded barrel; the long magazine well in front of the big oval trigger
guard (the left hand holds the well); the pistol grip at the very rear, raked in front, near upright behind, flaring
at the bottom; pins and the trigger housing's side plate around the guard; a light safety lever out of the grip's front below the guard; the
charging handle in a slot forward on the right. The stock: two side frames (top and bottom bars, a back bar with two
lugs) on rods, and a U butt with a hollow back. Extended, the frames run back from the grip and the butt is behind
them; folded, the whole stock is turned round - the butt in front of the magazine well, the frames' back bars just
behind it, the bars running back past the grip (as in the folded photo). Scale ~0.6 mm per pixel of the folded photo
(the rail 0.276 m); the width is guessed (no top view).

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres; prefab +x is the shooter's left. Module variants (model_variants):
"Stock" (Extended / Folded), "Mags" (PDW_Mag_32 / PDW_Mag_20, "*_Mag_*" nodes so reloads slide them out), "Muzzle"
(Thread / Suppressor). Key points used by WeaponDB (prefab space): muzzle (0, 0.02, 0.236) - with the suppressor
(0, 0.02, 0.385); rear sight's top (0, 0.086, -0.115), front post tip (0, 0.086, 0.115); pistol grip (0, -0.085,
-0.1); magazine well (0, -0.08, 0.076); charging handle (-0.026, 0.03, 0.09).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "pdw_blockout.tscn")

MATERIALS = {
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),   # albedo, metallic, roughness
    "steel_mid": ((0.17, 0.17, 0.18), 0.55, 0.45),  # the trigger housing's plate, the markings
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "steel_dark": ((0.06, 0.06, 0.065), 0.5, 0.5),  # slots and holes
    "grip": ((0.07, 0.07, 0.075), 0.0, 0.75),
    "mag": ((0.1, 0.1, 0.105), 0.4, 0.5),
}
MESHES = ["receiver", "grip", "guard", "well", "butt", "butt_folded"]
BORE_Y = 0.02

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent="."):
    parts.append((name, parent, "cyl", (radius, z1 - z0), (x, y, (z0 + z1) / 2), 90.0, mat))


def stud(name, radius, x0, x1, y, z, mat, parent="."):
    """A short cylinder across the gun (pins, rivets)."""
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "ext_mesh", key, pos, 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))


def both(x0, x1):
    """(side, x0, x1) on the left (+x) and mirrored on the right."""
    return (("L", x0, x1), ("R", -x1, -x0))


# Receiver: the slab with the rounded nose; the rail with its cross slots on top.
mesh("Receiver", "receiver", "steel")
box("Rail", -0.012, 0.012, 0.058, 0.068, -0.126, 0.126, "steel_light")
for i in range(9):
    z = -0.11 + i * 0.0275
    box("RailSlot%d" % i, -0.0125, 0.0125, 0.064, 0.0685, z, z + 0.008, "steel")
# Left side: the stamped markings at the front, the selector at the back. Right side: the charging handle's slot
# (WeaponView adds the handle). Both: the trigger housing's plate and its pins, the front sling pin.
box("Markings", 0.0218, 0.0228, 0.012, 0.042, 0.118, 0.152, "steel_mid")
box("Selector", 0.022, 0.027, 0.02, 0.034, -0.1, -0.07, "steel_light")
box("HandleSlot", -0.0228, -0.0218, 0.022, 0.038, 0.04, 0.105, "steel_dark")
for side, x0, x1 in both(0.0215, 0.0228):
    box("HousingPlate" + side, x0, x1, -0.019, 0.016, -0.06, 0.045, "steel_mid")
for side, x0, x1 in both(0.022, 0.0245):
    for i, (z, y) in enumerate(((0.06, 0.01), (0.01, 0.012), (-0.036, 0.008), (-0.034, -0.01), (0.066, -0.03))):
        stud("Pin%s%d" % (side, i), 0.0028, x0, x1, y, z, "steel_light")
    stud("SlingPin" + side, 0.004, x0, x1 + 0.001, 0.045, 0.155, "steel")
# Iron sights on the rail (the photos show none: a plain notch and post). The sight line over the ears' tops and the
# post's tip (y 0.086): the post in the middle of the notch, flush with its top; the front ears hide behind the rear.
box("RearSightBase", -0.012, 0.012, 0.068, 0.08, -0.122, -0.108, "steel")
box("RearSightEarL", 0.003, 0.011, 0.08, 0.086, -0.12, -0.11, "steel")   # notch between the ears
box("RearSightEarR", -0.011, -0.003, 0.08, 0.086, -0.12, -0.11, "steel")
box("FrontSightPost", -0.0025, 0.0025, 0.068, 0.086, 0.112, 0.118, "steel_light")
box("FrontSightEarL", 0.008, 0.012, 0.068, 0.086, 0.108, 0.122, "steel")
box("FrontSightEarR", -0.012, -0.008, 0.068, 0.086, 0.108, 0.122, "steel")
# Trigger group: the oval guard, the trigger, the light safety lever out of the grip's front under the guard, the magazine well with
# its release on the left; the grip.
mesh("TriggerGuard", "guard", "steel")
box("Trigger", -0.004, 0.004, -0.042, -0.016, -0.004, 0.006, "steel_light", rot_x=-12.0)
box("Safety", -0.005, 0.005, -0.086, -0.066, -0.066, -0.05, "steel_light")  # a lever out of the grip's front
mesh("MagWell", "well", "steel")
box("MagRelease", 0.02, 0.024, -0.03, -0.019, 0.06, 0.071, "steel_light")
mesh("PistolGrip", "grip", "grip")
# Barrel: the knurled nut against the receiver's nose, the barrel, the thread for a suppressor.
tube("BarrelNut", 0.0175, 0.168, 0.192, BORE_Y, "steel")
for i in range(4):
    z = 0.171 + i * 0.0055
    tube("Knurl%d" % i, 0.0186, z, z + 0.0025, BORE_Y, "steel")
tube("Barrel", 0.0085, 0.192, 0.215, BORE_Y, "steel")
tube("Thread", 0.0075, 0.215, 0.236, BORE_Y, "steel_light")

# Muzzle variants: bare thread, or the suppressor screwed on.
node("Muzzle")
node("Thread", "Muzzle")
node("Suppressor", "Muzzle")
tube("Can", 0.021, 0.21, 0.38, BORE_Y, "mag", parent="Muzzle/Suppressor")
tube("CanCap", 0.017, 0.38, 0.385, BORE_Y, "steel", parent="Muzzle/Suppressor")

# Magazines: a straight double stack, 0.125 m of it inside the well. 32 rounds hang 0.121 m below the well, 20 rounds
# 0.041 m; a rib down each side, the floor plate.
node("Mags")
for name, below in (("PDW_Mag_32", 0.121), ("PDW_Mag_20", 0.041)):
    p = "Mags/" + name
    node(name, "Mags", (0.0, -0.135, 0.076))
    box("Body", -0.011, 0.011, -below, 0.125, -0.0165, 0.0165, "mag", parent=p)
    for side, x0, x1 in both(0.011, 0.0125):
        box("Rib" + side, x0, x1, -below + 0.008, -0.004, -0.004, 0.004, "mag", parent=p)
    box("Floor", -0.013, 0.013, -below - 0.008, -below, -0.019, 0.019, "steel", parent=p)


# Stock: per side a frame - top and bottom bars (tubes the rods slide in), a back bar with two lugs - and the U butt
# (a plate each side, a cross bar at the bottom: folded, the magazine well and the receiver pass between them).
# `o` is the way from the frames to the butt (-1: back, extended; +1: forward, folded and turned round).
def stock(p, o, butt_inner, lug_outer, frame_end, butt_key):
    for side, x in (("L", 0.029), ("R", -0.029)):
        mesh("Butt" + side, butt_key, "steel", parent=p, pos=(x, 0.0, 0.0))
        for bar, y in (("Top", 0.039), ("Bottom", -0.137)):
            z0, z1 = sorted((lug_outer, frame_end))
            box("Bar%s%s" % (bar, side), x - 0.005, x + 0.005, y - 0.009, y + 0.009, z0, z1, "steel", parent=p)
            r0, r1 = sorted((butt_inner, frame_end))
            tube("Rod%s%s" % (bar, side), 0.0045, r0, r1, y, "steel_light", x=x, parent=p)
        z0, z1 = sorted((lug_outer, lug_outer - o * 0.022))
        box("BackBar" + side, x - 0.005, x + 0.005, -0.146, 0.048, z0, z1, "steel", parent=p)
        z0, z1 = sorted((lug_outer - o * 0.022, lug_outer - o * 0.034))
        inner = x - 0.009 if x > 0 else x + 0.009
        for i, (y0, y1) in enumerate(((-0.022, -0.006), (-0.064, -0.048))):
            box("Lug%s%d" % (side, i), min(x, inner), max(x, inner), y0, y1, z0, z1, "steel", parent=p)
    z0, z1 = sorted((butt_inner, butt_inner + o * 0.028))
    box("ButtCross", -0.035, 0.035, -0.157, -0.139, z0, z1, "steel", parent=p)


node("Stock")
node("Extended", "Stock")
stock("Stock/Extended", -1.0, -0.44, -0.34, -0.125, "butt")
node("Folded", "Stock")
stock("Stock/Folded", 1.0, 0.108, 0.072, -0.143, "butt_folded")

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="PDW" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
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
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(params[0]), f(params[0]), f(params[1]), 6 if kind == "cylx" else 10))
    if kind == "cylx":  # the cylinder's axis (local Y) across the gun
        xform = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %s, %s, %s)" % (f(c[0]), f(c[1]), f(c[2]))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/pdw_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
