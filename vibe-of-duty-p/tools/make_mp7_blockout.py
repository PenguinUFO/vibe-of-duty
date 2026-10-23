"""Generates prefabs/weapons/mp7_blockout.tscn: a blockout of the Heckler & Koch MP7A1, 4.6x30 (2001-).

Run from the repo:  python vibe-of-duty-p/tools/make_mp7_blockout.py   (overwrites the scene)
Shaped parts (receiver, trigger guard, grip, butt plate) are meshes made by tools/make_parts.gd
(prefabs/weapons/mp7_<part>_mesh.tres) - run that first if they change.

After the owner's photos of a Tokyo Marui MP7A1 (airsoft, the real gun's proportions): 415 mm long with the stock in,
so 0.658 mm a pixel of the left-side photo. All black polymer: the receiver one block under a full-length rail, its
front sloping down to a chin under the barrel; short side rails up front, the flip-up sights at both ends of the rail;
the folding foregrip under the front; the L trigger guard into the near upright grip; the magazine in the grip
(40 rounds: well below it); the butt plate on two rods; the ambidextrous selector lever over the grip; the
charging handle at the rear under the rail (WeaponView adds it: WeaponDef.charging_handle, handle_reciprocates false);
the birdcage flash hider.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres; prefab +x is the shooter's left. Module variants (model_variants):
"Stock" (Collapsed / Extended), "Foregrip" (Unfolded / Folded), "Muzzle" (Hider / Can), "Sights" (Up / Down: folded
flat under an optic), "Mags" (MP7_Mag_20 / 30 / 40: "*_Mag_*" nodes so reloads slide them out; a node sits 0.11 m
above and 0.015 m behind where the hand holds it, WeaponView.mag_grip_point).
Key points used by WeaponDB (prefab space): bore y 0.0217; muzzle with the hider (0, 0.0217, 0.2106), with the can
z 0.318; sight line over the rear ears' tops and the front post's tip, y 0.104, rear (z -0.132), front (z 0.108);
pistol grip (0, -0.045, -0.047); foregrip (0, -0.05, 0.124); charging handle (0, 0.058, -0.18).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "mp7_blockout.tscn")

MATERIALS = {
    "polymer": ((0.075, 0.075, 0.08), 0.0, 0.75),  # albedo, metallic, roughness
    "rail": ((0.1, 0.1, 0.105), 0.45, 0.5),        # the aluminium rails
    "steel": ((0.12, 0.12, 0.13), 0.55, 0.45),
    "steel_dark": ((0.04, 0.04, 0.045), 0.5, 0.5),  # slots, ports
    "rubber": ((0.06, 0.06, 0.065), 0.0, 0.9),     # the grip's and foregrip's texture
    "mag": ((0.1, 0.1, 0.1), 0.0, 0.5),            # smoked translucent polymer (opaque here)
}
MESHES = ["receiver", "guard", "grip", "butt"]
BORE_Y = 0.0217
HIDER = (0.1678, 0.2106)
CAN_LEN = 0.15
SIGHT_Y = 0.104      # the sight line: the rear ears' tops and the front post's tip
RAIL_TOP = 0.0711
PIVOT = (-0.0046, 0.125)  # the foregrip's hinge (y, z)
STOCK_TRAVEL = 0.223      # 415 -> 638 mm
MAG_TILT = -10.7          # the bottom forward
MAG_TOP = -0.003          # inside the grip

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent="."):
    parts.append((name, parent, "cyl", (radius, z1 - z0), (x, y, (z0 + z1) / 2), 90.0, mat))


def cylx(name, radius, x0, x1, y, z, mat, parent="."):
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "ext_mesh", key, pos, 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))


def both(x0, x1):
    """(side, x0, x1) on the left (+x) and mirrored on the right."""
    return (("L", x0, x1), ("R", -x1, -x0))


# Receiver: the rail with its cross slots, the oval vents, the short side rails up front, the ejection port on the
# right, the ambidextrous selector over the grip.
mesh("Receiver", "receiver", "polymer")
box("Rail", -0.011, 0.011, 0.0658, RAIL_TOP, -0.1665, 0.1263, "rail")
for i in range(11):
    z = -0.155 + i * 0.0254
    box("RailSlot%d" % i, -0.0115, 0.0115, 0.0685, RAIL_TOP + 0.0005, z, z + 0.01, "steel_dark")
for side, x0, x1 in both(0.0205, 0.0215):
    for i, (z0, z1, y0, y1) in enumerate(((0.071, 0.086, 0.054, 0.06), (0.096, 0.111, 0.054, 0.06),
                                          (-0.07, -0.058, 0.042, 0.048), (-0.115, -0.103, 0.042, 0.048))):
        box("Vent%s%d" % (side, i), x0, x1, y0, y1, z0, z1, "steel_dark")
for side, x0, x1 in both(0.021, 0.025):
    box("SideRail" + side, x0, x1, 0.0164, 0.0395, 0.0474, 0.148, "rail")
    for i in range(6):
        z = 0.054 + i * 0.016
        box("SideSlot%s%d" % (side, i), x0 - 0.0005 if side == "R" else x1 - 0.002, x0 + 0.002 if side == "R" else x1 + 0.0005,
            0.0164, 0.0395, z, z + 0.007, "steel_dark")
box("EjectionPort", -0.0215, -0.0205, 0.032, 0.048, -0.005, 0.035, "steel_dark")
for side, x0, x1 in both(0.021, 0.025):
    cylx("SelectorHub" + side, 0.006, x0, x1, 0.0263, -0.0678, "polymer")
    box("Selector" + side, x0, x1, 0.018, 0.025, -0.069, -0.027, "polymer", rot_x=14.0)  # the lever, forward and down
# Guard, trigger, grip with its textured panels.
mesh("TriggerGuard", "guard", "polymer")
mesh("PistolGrip", "grip", "polymer")
box("Trigger", -0.003, 0.003, -0.016, 0.004, -0.003, 0.004, "steel", rot_x=-10.0)
for side, x0, x1 in both(0.0158, 0.0168):
    box("GripPanel" + side, x0, x1, -0.085, -0.02, -0.066, -0.026, "rubber")

# Flip-up sights: up (iron sights) or folded flat (under an optic). Up, all tops on the sight line: in the sights the
# front post stands in the middle of the rear notch, flush with its ears; the front ears (outside the notch's angle)
# hide behind the rear ears.
node("Sights")
node("Up", "Sights")
s = "Sights/Up"
box("RearBase", -0.012, 0.012, RAIL_TOP, 0.076, -0.147, -0.109, "polymer", parent=s)
box("RearLeaf", -0.009, 0.009, 0.076, 0.097, -0.135, -0.129, "polymer", parent=s)
for side, x0, x1 in both(0.0025, 0.009):
    box("RearEar" + side, x0, x1, 0.097, SIGHT_Y, -0.135, -0.129, "polymer", parent=s)
box("FrontBase", -0.012, 0.012, RAIL_TOP, 0.076, 0.087, 0.126, "polymer", parent=s)
box("FrontPost", -0.002, 0.002, 0.076, SIGHT_Y, 0.105, 0.111, "steel", parent=s)
for side, x0, x1 in both(0.0075, 0.0105):
    box("FrontEar" + side, x0, x1, 0.076, SIGHT_Y, 0.102, 0.114, "polymer", parent=s)
node("Down", "Sights")
s = "Sights/Down"
box("RearBase", -0.012, 0.012, RAIL_TOP, 0.076, -0.147, -0.109, "polymer", parent=s)
box("RearLeaf", -0.009, 0.009, 0.076, 0.08, -0.146, -0.118, "polymer", parent=s)
box("FrontBase", -0.012, 0.012, RAIL_TOP, 0.076, 0.087, 0.126, "polymer", parent=s)
box("FrontLeaf", -0.0105, 0.0105, 0.076, 0.08, 0.09, 0.118, "polymer", parent=s)

# Foregrip: on its hinge under the front, down (unfolded) or forward under the barrel (folded); the ridges on its
# back, the hinge's button.
cylx("ForegripHinge", 0.006, -0.013, 0.013, PIVOT[0], PIVOT[1], "polymer")
node("Foregrip")
node("Unfolded", "Foregrip", (0.0, PIVOT[0], PIVOT[1]))
box("Grip", -0.012, 0.012, -0.092, 0.0, -0.018, 0.0165, "polymer", parent="Foregrip/Unfolded")
for i in range(5):
    y = -0.088 + i * 0.006
    box("Ridge%d" % i, -0.011, 0.011, y, y + 0.003, -0.021, -0.017, "rubber", parent="Foregrip/Unfolded")
cylx("Button", 0.005, -0.0135, 0.0135, -0.006, 0.0, "steel", parent="Foregrip/Unfolded")
node("Folded", "Foregrip", (0.0, PIVOT[0], PIVOT[1]))
box("Grip", -0.012, 0.012, -0.034, 0.0, 0.0, 0.085, "polymer", parent="Foregrip/Folded")

# Barrel and muzzle: the birdcage hider (its slots) or the can (gripping rings), screwed on in its place.
tube("Barrel", 0.0055, 0.15, HIDER[0], BORE_Y, "steel")
node("Muzzle")
node("Hider", "Muzzle")
tube("Cage", 0.0075, HIDER[0], HIDER[1], BORE_Y, "steel", parent="Muzzle/Hider")
for i in range(3):
    z = HIDER[0] + 0.012 + i * 0.009
    tube("Ring%d" % i, 0.0079, z, z + 0.003, BORE_Y, "steel", parent="Muzzle/Hider")
for side, x0, x1 in both(0.0068, 0.008):
    box("Slot" + side, x0, x1, BORE_Y - 0.002, BORE_Y + 0.002, HIDER[0] + 0.012, HIDER[1] - 0.004, "steel_dark",
        parent="Muzzle/Hider")
node("Can", "Muzzle")
tube("Mount", 0.009, HIDER[0], HIDER[0] + 0.02, BORE_Y, "steel", parent="Muzzle/Can")
tube("Can", 0.016, HIDER[0] + 0.02, HIDER[0] + CAN_LEN, BORE_Y, "polymer", parent="Muzzle/Can")
for i in range(4):
    z = HIDER[0] + 0.03 + i * 0.018
    tube("Grip%d" % i, 0.0165, z, z + 0.01, BORE_Y, "steel", parent="Muzzle/Can")
tube("Cap", 0.014, HIDER[0] + CAN_LEN, HIDER[0] + CAN_LEN + 0.002, BORE_Y, "steel_dark", parent="Muzzle/Can")

# Stock: the butt plate against the receiver (collapsed) or 0.223 m back on its two rods.
node("Stock")
node("Collapsed", "Stock")
mesh("Butt", "butt", "polymer", parent="Stock/Collapsed")
node("Extended", "Stock")
mesh("Butt", "butt", "polymer", parent="Stock/Extended", pos=(0.0, 0.0, -STOCK_TRAVEL))
for side, x in (("L", 0.014), ("R", -0.014)):
    tube("Rod" + side, 0.0045, -0.1717 - STOCK_TRAVEL, -0.165, 0.032, "steel", x=x, parent="Stock/Extended")

# Magazines in the grip: 20 (flush with the grip's bottom), 30, 40 rounds; the floor plate.
node("Mags")
for rounds, bottom in ((20, -0.1), (30, -0.14), (40, -0.183)):
    axis_z = lambda y: -0.0454 - (y + 0.09) * 0.159  # the magazine's middle line, front to back (from the photo)
    nx, ny, nz = 0.0, bottom + 0.11, axis_z(bottom) - 0.015
    name = "MP7_Mag_%d" % rounds
    p = "Mags/" + name
    node(name, "Mags", (nx, ny, nz))
    length = (MAG_TOP - bottom) / math.cos(math.radians(MAG_TILT))
    yc = (MAG_TOP + bottom) / 2
    parts.append(("Body", p, "box", (0.022, length, 0.044), (0.0, yc - ny, axis_z(yc) - nz), MAG_TILT, "mag"))
    yf = bottom - 0.003
    parts.append(("Floor", p, "box", (0.026, 0.006, 0.05), (0.0, yf - ny, axis_z(yf) - nz), MAG_TILT, "mag"))

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="MP7" type="Node3D"]\n']
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
                   % (i, mat, f(params[0]), f(params[0]), f(params[1]), 8 if kind == "cylx" else 12))
    if kind == "cylx":  # the cylinder's axis (local Y) across the gun
        xform = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %s, %s, %s)" % (f(c[0]), f(c[1]), f(c[2]))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/mp7_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
