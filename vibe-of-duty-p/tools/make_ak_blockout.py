"""Generates prefabs/weapons/ak_blockout.tscn: a blockout rifle after the AKM.

Run from the repo:  python vibe-of-duty-p/tools/make_ak_blockout.py   (overwrites the scene)
Shaped parts are meshes made by Godot tools - run those first if they change:
  tools/make_ak_mag.gd    -> prefabs/weapons/ak_mag_mesh.tres (the curved magazine)
  tools/make_ak_parts.gd  -> prefabs/weapons/ak_<part>_mesh.tres (stock, butt plate, grip, handguards, dust cover)

Conventions (as WeaponView expects): the barrel points to +Z, +Y is up, the origin sits under the receiver at the
trigger; prefab +x is the shooter's left. Units are metres; the rifle is ~0.96 m long. Module variants: group
"Muzzle" (Slant / Brake / PBS). The magazine is a node named "*_Mag_*" (WeaponView slides it out during reloads).
Key points used by WeaponDef (prefab space): muzzle (0, 0.045, 0.565), rear sight top (0, 0.112, 0.28), front sight
top (0, 0.11, 0.50), pistol grip (0, -0.055, -0.062), handguard bottom (0, 0.0, 0.35).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "ak_blockout.tscn")

MATERIALS = {
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),   # albedo, metallic, roughness
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "steel_dark": ((0.07, 0.07, 0.075), 0.5, 0.5),  # holes and slots read as dark
    "wood": ((0.45, 0.24, 0.1), 0.0, 0.7),
    "mag": ((0.62, 0.27, 0.1), 0.0, 0.55),
}
MESHES = ["mag", "stock", "butt_plate", "grip", "handguard_lower", "handguard_upper", "dust_cover"]

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, parent=".", x=0.0):
    parts.append((name, parent, "cyl", (radius, z1 - z0), (x, y, (z0 + z1) / 2), 90.0, mat))


def stud(name, radius, x0, x1, y, z, mat, parent="."):
    """A short cylinder across the gun (rivets, pins, the safety's pivot)."""
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "ext_mesh", key, pos, 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))


# Receiver: the stamped box, the dust cover with its three pressed ribs and the recoil spring's button at the back,
# rivets of the front and rear trunnions on both sides.
box("Receiver", -0.025, 0.025, 0.0, 0.072, -0.11, 0.25, "steel")
mesh("DustCover", "dust_cover", "steel_light")
for i, z in enumerate((0.02, 0.09, 0.16)):
    box("CoverRib%d" % i, -0.017, 0.017, 0.086, 0.0915, z, z + 0.012, "steel_light")
box("SpringButton", -0.006, 0.006, 0.074, 0.084, -0.113, -0.1, "steel_light")
for side, x0, x1 in (("L", 0.025, 0.027), ("R", -0.027, -0.025)):
    for i, (y, z) in enumerate(((0.012, 0.215), (0.012, 0.235), (0.032, 0.225), (0.05, 0.215), (0.05, 0.235),
                                (0.018, -0.09), (0.042, -0.09))):
        stud("Rivet%s%d" % (side, i), 0.0028, x0, x1, y, z, "steel_light")
# Ejection port on the right, under the cover's edge.
box("EjectionPort", -0.0262, -0.0248, 0.042, 0.068, 0.07, 0.17, "steel_dark")
# Rear sight: the block on the trunnion and the leaf with its slider; the U notch is between the leaf's two halves.
box("RearSightBase", -0.016, 0.016, 0.072, 0.1, 0.25, 0.3, "steel")
box("RearSightLeafL", -0.014, -0.004, 0.1, 0.118, 0.27, 0.282, "steel_light")   # leaf with a U notch in the middle
box("RearSightLeafR", 0.004, 0.014, 0.1, 0.118, 0.27, 0.282, "steel_light")
box("RearSightLeafBase", -0.014, 0.014, 0.1, 0.112, 0.27, 0.282, "steel_light")
box("RearSightSlider", -0.016, 0.016, 0.1, 0.108, 0.255, 0.268, "steel")
# Trigger group: the guard (bar and two legs), the trigger, the magazine catch behind the magazine.
box("TriggerGuard", -0.006, 0.006, -0.03, -0.024, -0.03, 0.06, "steel")
box("TriggerGuardFront", -0.006, 0.006, -0.03, 0.0, 0.054, 0.06, "steel")
box("TriggerGuardRear", -0.006, 0.006, -0.03, 0.0, -0.03, -0.024, "steel")
box("Trigger", -0.004, 0.004, -0.022, 0.0, 0.004, 0.014, "steel_light", rot_x=-10.0)
box("MagCatch", -0.007, 0.007, -0.03, 0.0, 0.044, 0.054, "steel_light")
# Safety lever on the right (prefab -x): a long flat lever from its pivot at the back to the tab in front.
stud("SafetyPivot", 0.006, -0.029, -0.025, 0.045, -0.085, "steel_light")
box("Safety", -0.0285, -0.025, 0.038, 0.05, -0.09, 0.11, "steel_light", rot_x=-3.0)
box("SafetyTab", -0.0295, -0.025, 0.024, 0.05, 0.1, 0.116, "steel_light")
# Barrel, gas block, gas tube, front sight, the cleaning rod under the barrel.
tube("Barrel", 0.011, 0.25, 0.545, 0.045, "steel")
# Muzzle variants (model_variants "Muzzle"): the AKM slant compensator, the AK-74 brake (DTK), the PBS-1 suppressor.
node("Muzzle")
node("Slant", "Muzzle")
node("Brake", "Muzzle")
node("PBS", "Muzzle")
tube("Comp", 0.015, 0.53, 0.565, 0.045, "steel_light", parent="Muzzle/Slant")
tube("Body", 0.013, 0.53, 0.6, 0.045, "steel_light", parent="Muzzle/Brake")    # muzzle 0.6
tube("Lip", 0.0145, 0.59, 0.6, 0.045, "steel", parent="Muzzle/Brake")
tube("Can", 0.0175, 0.53, 0.73, 0.045, "steel", parent="Muzzle/PBS")          # 35 x 200 mm; muzzle 0.73
tube("Clamp", 0.0195, 0.525, 0.55, 0.045, "steel_light", parent="Muzzle/PBS")
box("GasBlock", -0.016, 0.016, 0.03, 0.09, 0.43, 0.46, "steel")
tube("GasCollar", 0.016, 0.428, 0.462, 0.045, "steel")
tube("GasTube", 0.014, 0.29, 0.44, 0.078, "steel")
box("FrontSightBase", -0.012, 0.012, 0.045, 0.09, 0.49, 0.51, "steel")
tube("FrontSightCollar", 0.015, 0.488, 0.512, 0.045, "steel")
box("BayonetLug", -0.005, 0.005, 0.016, 0.03, 0.49, 0.512, "steel")
box("FrontSightPost", -0.0025, 0.0025, 0.09, 0.11, 0.497, 0.503, "steel_light")
box("FrontSightEarL", -0.013, -0.009, 0.085, 0.112, 0.494, 0.506, "steel")
box("FrontSightEarR", 0.009, 0.013, 0.085, 0.112, 0.494, 0.506, "steel")
tube("CleaningRod", 0.003, 0.4, 0.515, 0.024, "steel_light")
# Wood: handguards (held by steel ferrules), stock with its butt plate, pistol grip; a sling loop on the stock's left.
mesh("HandguardLower", "handguard_lower", "wood")
mesh("HandguardUpper", "handguard_upper", "wood")
for name, z0, z1 in (("FerruleRear", 0.258, 0.272), ("FerruleFront", 0.418, 0.432)):
    box(name, -0.0295, 0.0295, -0.001, 0.06, z0, z1, "steel")
mesh("Stock", "stock", "wood")
mesh("ButtPlate", "butt_plate", "steel")
box("SlingLoop", 0.019, 0.023, -0.07, -0.05, -0.34, -0.33, "steel", rot_x=-14.0)
mesh("PistolGrip", "grip", "wood")
# Curved magazine: one smooth swept mesh (tools/make_ak_mag.gd).
mag = "AK_Mag_01"
node(mag, ".", (0.0, 0.0, 0.085))
mesh("Body", "mag", "mag", parent=mag)

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="AK47" type="Node3D"]\n']
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
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/ak_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
