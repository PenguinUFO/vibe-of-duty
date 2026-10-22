"""Generates prefabs/weapons/acr_blockout.tscn: a blockout of the Magpul Masada / Bushmaster ACR, 5.56 (2007-2010s).

Run from the repo:  python vibe-of-duty-p/tools/make_acr_blockout.py   (overwrites the scene)

From memory of the rifle, no photos at hand: a black aluminium upper with one long top rail over the receiver and the
handguard, a polymer lower, handguard and folding stock (flat dark earth), a STANAG magazine (PMAG), flip-up iron
sights at both ends of the rail, the non-reciprocating charging handle forward on the left (WeaponDef.charging_handle,
handle_reciprocates false), the stock folding to the right side.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres; prefab +x is the shooter's left. Module variants (model_variants):
"Barrel" (B105 / B145 / B185: 10.5", 14.5", 18"), each with its own "Muzzle" (Hider / Can) - so the suppressor
module names all three; "Stock" (Extended / Folded); "Mags" (ACR_Mag_30, a "*_Mag_*" node so reloads slide it out).
Key points used by WeaponDB (prefab space): bore y 0.05; muzzle with the flash hider z 0.297 / 0.398 / 0.487 + 0.055,
the suppressor + 0.17 instead; rear sight notch (0, 0.113, -0.12), front post tip (0, 0.113, 0.27); pistol grip
(0, -0.075, -0.0775); handguard bottom (0, -0.005, 0.22); charging handle (0.036, 0.062, 0.13).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "acr_blockout.tscn")

MATERIALS = {
    "black": ((0.08, 0.08, 0.085), 0.35, 0.5),   # albedo, metallic, roughness: anodised upper
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "fde": ((0.5, 0.42, 0.3), 0.0, 0.8),         # polymer, flat dark earth
    "rubber": ((0.06, 0.06, 0.06), 0.0, 0.9),
    "mag": ((0.09, 0.09, 0.095), 0.0, 0.7),
}
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


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))


# Upper: the receiver around the bore, one rail from the rear sight to the front sight, the ejection port on the right.
box("Upper", -0.026, 0.026, 0.015, 0.077, -0.17, 0.17, "black")
box("Rail", -0.011, 0.011, 0.077, 0.086, -0.165, 0.28, "black")
for i in range(16):  # cross slots along the rail
    z = -0.15 + i * 0.027
    box("RailSlot%d" % i, -0.0115, 0.0115, 0.082, 0.0865, z, z + 0.008, "steel")
box("EjectionPort", -0.0265, -0.025, 0.035, 0.065, 0.0, 0.07, "steel")
box("HandleSlot", 0.025, 0.0265, 0.055, 0.069, 0.04, 0.17, "steel")  # the handle's track (WeaponView adds the handle)
# Lower: the receiver, the magazine well in front of the trigger, the guard, ambidextrous controls.
box("Lower", -0.024, 0.024, -0.03, 0.015, -0.16, 0.11, "fde")
box("MagWell", -0.021, 0.021, -0.07, -0.03, 0.03, 0.105, "fde")
box("TriggerGuard", -0.006, 0.006, -0.051, -0.045, -0.035, 0.03, "fde")
box("TriggerGuardFront", -0.006, 0.006, -0.051, -0.03, 0.024, 0.03, "fde")
box("Trigger", -0.004, 0.004, -0.04, -0.03, -0.002, 0.008, "steel_light")
for side, x in (("L", 0.024), ("R", -0.03)):
    box("Selector" + side, x, x + 0.006, -0.012, 0.004, -0.06, -0.04, "steel_light")
    box("MagRelease" + side, x, x + 0.006, -0.025, -0.012, 0.015, 0.03, "steel_light")
    box("BoltCatch" + side, x, x + 0.006, -0.01, 0.01, 0.105, 0.12, "steel_light")
box("PistolGrip", -0.016, 0.016, -0.13, -0.02, -0.095, -0.06, "fde", rot_x=20.0)  # + tips the bottom back; top behind the guard
# Handguard: polymer, under the rail; the barrel comes out of its front.
box("Handguard", -0.028, 0.028, 0.0, 0.077, 0.17, 0.28, "fde")
box("HandguardLip", -0.025, 0.025, -0.008, 0.0, 0.17, 0.28, "fde")
# Flip-up sights on the rail (up): a notch between two ears at the rear, a post between two ears at the front.
box("RearSightBase", -0.012, 0.012, 0.086, 0.1, -0.13, -0.11, "black")
box("RearSightEarL", 0.003, 0.011, 0.1, 0.12, -0.125, -0.115, "black")
box("RearSightEarR", -0.011, -0.003, 0.1, 0.12, -0.125, -0.115, "black")
box("FrontSightBase", -0.012, 0.012, 0.086, 0.098, 0.26, 0.28, "black")
box("FrontSightPost", -0.0025, 0.0025, 0.098, 0.113, 0.267, 0.273, "steel_light")
box("FrontSightEarL", 0.008, 0.012, 0.098, 0.116, 0.262, 0.278, "black")
box("FrontSightEarR", -0.012, -0.008, 0.098, 0.116, 0.262, 0.278, "black")
box("StockHinge", -0.028, 0.024, 0.0, 0.07, -0.185, -0.17, "black")

# Barrels: each with its own muzzle group, the flash hider or the suppressor screwed on.
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
    tube("Can", 0.019, end - 0.01, end + CAN_LEN, BORE_Y, "black", parent=p + "/Muzzle/Can")
    tube("Cap", 0.015, end + CAN_LEN, end + CAN_LEN + 0.004, BORE_Y, "steel", parent=p + "/Muzzle/Can")

# Magazine: a STANAG box, 0.06 m of it in the well, the bottom curving forward (minus: the bottom goes forward).
node("Mags")
node("ACR_Mag_30", "Mags", (0.0, -0.07, 0.0715))  # tilted: its top edge stays inside the well
box("Body", -0.0115, 0.0115, -0.15, 0.06, -0.032, 0.032, "mag", rot_x=-6.0, parent="Mags/ACR_Mag_30")
box("Floor", -0.014, 0.014, -0.162, -0.15, -0.0245, 0.0475, "mag", rot_x=-6.0, parent="Mags/ACR_Mag_30")  # under the tilted body's bottom


# Stock: a comb along the top, a deeper butt with the pad, a strut from the butt up to the hinge. Folded, it swings
# around the hinge's vertical axis to lie along the right side (prefab -x), pointing forward.
def stock(p, fold):
    zz = (lambda z0, z1: (-0.34 - z1, -0.34 - z0)) if fold else (lambda z0, z1: (z0, z1))
    x0, x1 = (-0.068, -0.028) if fold else (-0.02, 0.02)
    sign = -1.0 if fold else 1.0
    box("Comb", x0, x1, 0.02, 0.07, *zz(-0.43, -0.185), "fde", parent=p)
    box("Butt", x0, x1, -0.07, 0.02, *zz(-0.43, -0.33), "fde", parent=p)
    box("Strut", x0 + 0.004, x1 - 0.004, -0.0425, -0.0225, *zz(-0.34, -0.175), "fde", rot_x=-19.5 * sign, parent=p)
    box("Pad", x0 - 0.002, x1 + 0.002, -0.075, 0.075, *zz(-0.447, -0.43), "rubber", parent=p)


node("Stock")
for variant, fold in (("Extended", False), ("Folded", True)):
    node(variant, "Stock")
    stock("Stock/" + variant, fold)

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
