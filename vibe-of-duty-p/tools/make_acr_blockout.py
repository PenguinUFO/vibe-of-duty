"""Generates prefabs/weapons/acr_blockout.tscn: a blockout of the Magpul Masada / Bushmaster ACR, 5.56 (2007-2010s).

Run from the repo:  python vibe-of-duty-p/tools/make_acr_blockout.py   (overwrites the scene)
Shaped parts (upper, lower, trigger guard, grip, handguard, stock) are meshes made by tools/make_parts.gd
(prefabs/weapons/acr_<part>_mesh.tres) - run that first if they change.

From memory of the rifle, no photos at hand: a black aluminium upper bevelled at the back, with one long top rail over
the receiver and the handguard; a polymer (flat dark earth) lower with the flared magazine well, an angular trigger
guard and an AR grip with a finger bump; the polymer handguard with vent slots, short side rails and the two-position
gas regulator's knob at its front; flip-up iron sights at both ends of the rail; the non-reciprocating charging
handle forward on the left (WeaponDef.charging_handle, handle_reciprocates false); a STANAG magazine (PMAG, ridged at
the bottom); the A2 flash hider with its slots; the Magpul skeleton stock with a triangular hole, folding to the
right side.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres; prefab +x is the shooter's left. Module variants (model_variants):
"Barrel" (B105 / B145 / B185: 10.5", 14.5", 18"), each with its own "Muzzle" (Hider / Can) - so the suppressor
module names all three; "Stock" (Extended / Folded); "Mags" (ACR_Mag_30, a "*_Mag_*" node so reloads slide it out).
Key points used by WeaponDB (prefab space): bore y 0.05; muzzle with the flash hider z 0.297 / 0.398 / 0.487 + 0.055,
the suppressor + 0.17 instead; rear sight notch (0, 0.113, -0.12), front post tip (0, 0.113, 0.27); pistol grip
(0, -0.08, -0.085); handguard bottom (0, -0.012, 0.22); charging handle (0.036, 0.062, 0.13).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "acr_blockout.tscn")

MATERIALS = {
    "black": ((0.08, 0.08, 0.085), 0.35, 0.5),   # albedo, metallic, roughness: anodised upper
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "steel_dark": ((0.05, 0.05, 0.055), 0.5, 0.5),  # slots and vents
    "fde": ((0.5, 0.42, 0.3), 0.0, 0.8),         # polymer, flat dark earth
    "rubber": ((0.06, 0.06, 0.06), 0.0, 0.9),
    "mag": ((0.09, 0.09, 0.095), 0.0, 0.7),
}
MESHES = ["upper", "lower", "guard", "grip", "handguard", "stock_top", "stock_strut", "stock_top_folded",
          "stock_strut_folded"]
BORE_Y = 0.05
CHAMBER_Z = 0.03
BARRELS = (("B105", 0.267), ("B145", 0.368), ("B185", 0.457))  # 10.5", 14.5", 18" from the chamber
HIDER_LEN = 0.055
CAN_LEN = 0.17

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent="."):
    parts.append((name, parent, "cyl", (radius, z1 - z0), (x, y, (z0 + z1) / 2), 90.0, mat))


def mesh(name, key, mat, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "ext_mesh", key, pos, 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))


def both(x0, x1):
    """(side, x0, x1) on the left (+x) and mirrored on the right."""
    return (("L", x0, x1), ("R", -x1, -x0))


# Upper: the receiver bevelled at the back, one rail from the rear sight to the front sight, the ejection port on the
# right, the charging handle's track on the left.
mesh("Upper", "upper", "black")
box("Rail", -0.011, 0.011, 0.077, 0.086, -0.165, 0.28, "black")
for i in range(16):  # cross slots along the rail
    z = -0.15 + i * 0.027
    box("RailSlot%d" % i, -0.0115, 0.0115, 0.082, 0.0865, z, z + 0.008, "steel")
box("EjectionPort", -0.0265, -0.0255, 0.035, 0.063, 0.0, 0.07, "steel_dark")
box("HandleSlot", 0.0255, 0.0265, 0.055, 0.069, 0.04, 0.17, "steel_dark")  # the handle's track (WeaponView adds the handle)
# Lower: the receiver and the magazine well, the trigger guard, the grip; ambidextrous controls.
mesh("Lower", "lower", "fde")
mesh("TriggerGuard", "guard", "fde")
mesh("PistolGrip", "grip", "fde")
box("Trigger", -0.004, 0.004, -0.042, -0.03, -0.002, 0.008, "steel_light", rot_x=-10.0)
for side, x0, x1 in both(0.024, 0.0275):
    box("Selector" + side, x0, x1, -0.014, 0.002, -0.07, -0.05, "steel_light")
    box("MagRelease" + side, x0, x1, -0.025, -0.012, 0.015, 0.03, "steel_light")
    box("BoltCatch" + side, x0, x1, -0.012, 0.008, 0.112, 0.124, "steel_light")
    box("Pins" + side, x0 - 0.0005, x0 + 0.002, -0.004, 0.004, -0.14, -0.13, "black")  # the takedown pin's head
# Handguard: polymer under the rail, vent slots and short side rails, the gas regulator's knob above the barrel.
mesh("Handguard", "handguard", "fde")
for side, x0, x1 in both(0.0275, 0.0285):
    for i in range(3):
        z = 0.19 + i * 0.026
        box("Vent%s%d" % (side, i), x0, x1, 0.0, 0.016, z, z + 0.016, "steel_dark")
for side, x0, x1 in both(0.0275, 0.034):
    box("SideRail" + side, x0, x1, 0.03, 0.044, 0.2, 0.275, "black")
    for i in range(5):
        z = 0.205 + i * 0.014
        box("SideRailSlot%s%d" % (side, i), x1 - 0.0045, x1 + 0.0005, 0.029, 0.045, z, z + 0.006, "steel")
tube("GasRegulator", 0.009, 0.29, 0.302, 0.067, "steel_light")
box("RegulatorTab", -0.002, 0.002, 0.067, 0.081, 0.296, 0.302, "steel_light")
# Flip-up sights on the rail (up): a notch between two ears at the rear, a post between two ears at the front.
box("RearSightBase", -0.012, 0.012, 0.086, 0.1, -0.13, -0.11, "black")
box("RearSightEarL", 0.003, 0.011, 0.1, 0.12, -0.125, -0.115, "black")
box("RearSightEarR", -0.011, -0.003, 0.1, 0.12, -0.125, -0.115, "black")
box("FrontSightBase", -0.012, 0.012, 0.086, 0.098, 0.26, 0.28, "black")
box("FrontSightPost", -0.0025, 0.0025, 0.098, 0.113, 0.267, 0.273, "steel_light")
box("FrontSightEarL", 0.008, 0.012, 0.098, 0.116, 0.262, 0.278, "black")
box("FrontSightEarR", -0.012, -0.008, 0.098, 0.116, 0.262, 0.278, "black")
box("StockHinge", -0.028, 0.024, 0.0, 0.07, -0.185, -0.17, "black")

# Barrels: each with its own muzzle group, the A2 flash hider (slots round its top) or the suppressor screwed on.
node("Barrel")
for name, length in BARRELS:
    p = "Barrel/" + name
    end = CHAMBER_Z + length
    node(name, "Barrel")
    tube("Tube", 0.009, 0.28, end, BORE_Y, "steel", parent=p)
    node("Muzzle", p)
    node("Hider", p + "/Muzzle")
    node("Can", p + "/Muzzle")
    tube("Cage", 0.011, end, end + HIDER_LEN, BORE_Y, "steel", parent=p + "/Muzzle/Hider")
    for i, (x0, x1, y0, y1) in enumerate(((-0.003, 0.003, 0.0105, 0.0115), (0.0095, 0.0115, 0.002, 0.008),
                                          (-0.0115, -0.0095, 0.002, 0.008))):
        box("Slot%d" % i, x0, x1, BORE_Y + y0, BORE_Y + y1, end + 0.02, end + 0.048, "steel_dark", parent=p + "/Muzzle/Hider")
    tube("Can", 0.019, end - 0.01, end + CAN_LEN, BORE_Y, "black", parent=p + "/Muzzle/Can")
    tube("Cap", 0.015, end + CAN_LEN, end + CAN_LEN + 0.004, BORE_Y, "steel", parent=p + "/Muzzle/Can")

# Magazine: a STANAG box, 0.06 m of it in the well, the bottom curving forward (minus: the bottom goes forward); the
# PMAG's ridges round its lower part and the floor plate's lip.
node("Mags")
node("ACR_Mag_30", "Mags", (0.0, -0.078, 0.0715))  # tilted: its top edge stays inside the well
p = "Mags/ACR_Mag_30"
box("Body", -0.0115, 0.0115, -0.142, 0.068, -0.032, 0.032, "mag", rot_x=-6.0, parent=p)
tilt_s, tilt_c = math.sin(math.radians(-6.0)), math.cos(math.radians(-6.0))
for i in range(3):  # each ridge where the tilted body puts that height (the body turns about its middle, y -0.037)
    h = -0.12 + i * 0.012 + 0.037
    parts.append(("Ridge%d" % i, p, "box", (0.025, 0.005, 0.066), (0.0, -0.037 + tilt_c * h, tilt_s * h), -6.0, "mag"))
box("Floor", -0.014, 0.014, -0.154, -0.142, -0.0245, 0.0475, "mag", rot_x=-6.0, parent=p)  # under the tilted body's bottom


# Stock: the skeleton (comb and butt, the strut down to the hinge, the triangular hole between) with its rubber pad. Folded, it
# swings round the hinge's vertical axis to lie along the right side (prefab -x), pointing forward.
node("Stock")
node("Extended", "Stock")
mesh("Top", "stock_top", "fde", parent="Stock/Extended")
mesh("Strut", "stock_strut", "fde", parent="Stock/Extended")
box("Pad", -0.022, 0.022, -0.077, 0.07, -0.452, -0.44, "rubber", parent="Stock/Extended")
node("Folded", "Stock")
mesh("Top", "stock_top_folded", "fde", parent="Stock/Folded", pos=(-0.048, 0.0, 0.0))
mesh("Strut", "stock_strut_folded", "fde", parent="Stock/Folded", pos=(-0.048, 0.0, 0.0))
box("Pad", -0.07, -0.026, -0.077, 0.07, 0.1, 0.112, "rubber", parent="Stock/Folded")

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="ACR" type="Node3D"]\n']
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
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = 10\nrings = 1\n'
                   % (i, mat, f(params[0]), f(params[0]), f(params[1])))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/acr_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
