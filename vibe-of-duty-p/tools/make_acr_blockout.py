"""Generates prefabs/weapons/acr_blockout.tscn: a blockout of the Magpul Masada / Bushmaster / Remington ACR, 5.56.

Run from the repo:  python vibe-of-duty-p/tools/make_acr_blockout.py   (overwrites the scene)
Shaped parts (upper, lower, trigger guard, grip, handguards, stock) are meshes made by tools/make_parts.gd
(prefabs/weapons/acr_<part>_mesh.tres) - run that first if they change.

After the owner's photos (a coyote 14.5" from the right, Remington's catalogue of the four configurations, a black one
with a red dot and a can): all coyote - the anodised upper and the polymer - with a black barrel, muzzle brake,
ejection cover and butt pad. The upper and the tall lower meet on a line falling to the front; the deep handguard's
back edge climbs at a slant to the rail, one row of long slots above and one of short ones below, a short black side
rail at its front (the 10.5" has a short handguard without it); one rail over all of it with flip-up sights at both
ends; the long black ejection cover on the right, the non-reciprocating charging handle on the left under the rail
(WeaponDef.charging_handle, handle_reciprocates false); the big trigger guard, the MOE grip, a PMAG with its window;
the solid stock with the cheek riser, folding to the right side.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the receiver at the trigger, metres; prefab +x is the shooter's left. Module variants (model_variants):
"Barrel" (B105 / B145 / B185: 10.5", 14.5", 18", each with its handguard), each with its own "Muzzle" (Brake / Can) -
so the suppressor module names all three; "Stock" (Extended / Folded); "Mags" (ACR_Mag_30, a "*_Mag_*" node so
reloads slide it out). Key points used by WeaponDB (prefab space): bore y 0.05; muzzle with the brake
z 0.38 / 0.481 / 0.57 + 0.067, the suppressor + 0.17 instead; rear sight's top (0, 0.113, -0.05), front post tip
(0, 0.113, 0.31); pistol grip (0, -0.04, -0.076); handguard bottom (0, 0.015, 0.29); charging handle (0.03, 0.083, 0.2).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "acr_blockout.tscn")

MATERIALS = {
    "fde": ((0.58, 0.48, 0.33), 0.0, 0.8),      # albedo, metallic, roughness: all the coyote (the Cerakote upper too)
    "black": ((0.07, 0.07, 0.075), 0.4, 0.5),   # barrel, brake, ejection cover, side rail
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),
    "steel_dark": ((0.04, 0.04, 0.045), 0.5, 0.5),  # slots, ports
    "rubber": ((0.06, 0.06, 0.06), 0.0, 0.9),
    "mag": ((0.55, 0.46, 0.32), 0.0, 0.75),     # coyote PMAG
    "window": ((0.12, 0.11, 0.1), 0.0, 0.3),
}
MESHES = ["upper", "lower", "guard", "grip", "handguard", "handguard_short", "stock", "stock_folded"]
BORE_Y = 0.05
CHAMBER_Z = 0.113
BARRELS = (("B105", 0.267, "handguard_short", 0.354), ("B145", 0.368, "handguard", 0.421),
           ("B185", 0.457, "handguard", 0.421))  # 10.5", 14.5", 18" from the chamber; the handguard and its front
BRAKE_LEN = 0.067
CAN_LEN = 0.17

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


# Upper: coyote, one rail from the hinge to the front sight, the long black ejection cover on the right, the charging
# handle's slot on the left under the rail (on the upper, then on the wider handguard).
mesh("Upper", "upper", "fde")
box("Rail", -0.011, 0.011, 0.086, 0.095, -0.095, 0.345, "fde")
for i in range(17):  # cross slots along the rail
    z = -0.088 + i * 0.0254
    box("RailSlot%d" % i, -0.0115, 0.0115, 0.091, 0.0955, z, z + 0.009, "steel_dark")
box("EjectionCover", -0.0275, -0.0255, 0.048, 0.071, 0.006, 0.113, "black")
box("CoverHinge", -0.0285, -0.0265, 0.069, 0.072, 0.008, 0.111, "black")
box("HandleSlotUpper", 0.0255, 0.0265, 0.077, 0.084, 0.12, 0.175, "steel_dark")
box("HandleSlotGuard", 0.0295, 0.0305, 0.077, 0.084, 0.175, 0.24, "steel_dark")  # WeaponView adds the handle
# The hinge coyote, black only on its sides: in the sights the camera's near plane cuts the stock open and its back
# face fills the bottom of the view (black, it was a wall).
box("Hinge", -0.021, 0.021, 0.024, 0.074, -0.118, -0.104, "fde")
for side, x0, x1 in both(0.021, 0.022):
    box("HingeSide" + side, x0, x1, 0.024, 0.074, -0.118, -0.104, "black")
for side, x0, x1 in both(0.026, 0.028):  # pins: the hinge's, the barrel's lock, the lower's two
    cylx("HingePin" + side, 0.004, x0 - 0.006, x1 - 0.006, 0.062, -0.111, "steel")
    cylx("LockPin" + side, 0.0035, x0, x1, 0.06, 0.1, "steel")
for side, x0, x1 in both(0.024, 0.0255):
    cylx("RearPin" + side, 0.0035, x0, x1, 0.03, -0.09, "steel")
    cylx("FrontPin" + side, 0.0035, x0, x1, 0.012, 0.11, "steel")

# Lower: the tall receiver, the magazine well with its textured patch, the big trigger guard, the MOE grip;
# ambidextrous selector, magazine release and bolt catch.
mesh("Lower", "lower", "fde")
mesh("TriggerGuard", "guard", "fde")
mesh("PistolGrip", "grip", "fde")
box("Trigger", -0.0035, 0.0035, -0.02, 0.004, 0.0, 0.007, "black", rot_x=-12.0)
for side, x0, x1 in both(0.024, 0.0255):
    box("WellPatch" + side, x0, x1, -0.022, 0.0, 0.07, 0.112, "fde")
for side, x0, x1 in both(0.024, 0.028):
    cylx("SelectorHub" + side, 0.006, x0, x1, 0.022, -0.04, "black")
    box("Selector" + side, x0, x1, 0.019, 0.025, -0.06, -0.04, "black")
    box("MagRelease" + side, x0, x1, -0.022, -0.006, 0.043, 0.05, "black")
    box("BoltCatch" + side, x0, x1, 0.008, 0.02, 0.1, 0.112, "black")

# Flip-up sights (up), all tops at the sight line (y 0.113): the post stands in the middle of the rear's wide notch, its
# tip flush with the ears' tops, light on both sides of it; the front's ears (wider than the notch) hide behind the
# rear's ears.
box("RearSightBase", -0.012, 0.012, 0.095, 0.099, -0.07, -0.04, "black")
box("RearSightLeaf", -0.008, 0.008, 0.099, 0.104, -0.056, -0.05, "black")  # the notch's bottom
for side, x0, x1 in both(0.003, 0.008):
    box("RearSightEar" + side, x0, x1, 0.104, 0.113, -0.056, -0.05, "black")
box("FrontSightBase", -0.012, 0.012, 0.095, 0.099, 0.295, 0.335, "black")
box("FrontSightPost", -0.002, 0.002, 0.099, 0.113, 0.307, 0.313, "black")
for side, x0, x1 in both(0.008, 0.012):
    box("FrontSightEar" + side, x0, x1, 0.099, 0.113, 0.303, 0.317, "black")

# Barrels: each with its handguard (slots, the black side rail on the long one, the gas regulator's knob at its front)
# and its own muzzle group, the brake (ports) or the suppressor (black, gripping rings, as the third photo).
node("Barrel")
for name, length, guard, front in BARRELS:
    p = "Barrel/" + name
    end = CHAMBER_Z + length
    node(name, "Barrel")
    mesh("Handguard", guard, "fde", parent=p)
    slots_low = 5 if guard == "handguard" else 4
    for side, x0, x1 in both(0.0295, 0.0305):
        for i in range(slots_low):
            z = 0.196 + i * 0.033
            box("LowSlot%s%d" % (side, i), x0, x1, 0.025, 0.035, z, z + 0.02, "steel_dark", parent=p)
        for i, z in enumerate((0.25, 0.29, 0.33) if guard == "handguard" else (0.25, 0.29)):
            box("HighSlot%s%d" % (side, i), x0, x1, 0.052, 0.058, z, z + 0.028, "steel_dark", parent=p)
    if guard == "handguard":
        for side, x0, x1 in both(0.0295, 0.035):
            box("SideRail" + side, x0, x1, 0.045, 0.066, 0.362, 0.408, "black", parent=p)
            for i in range(3):
                z = 0.367 + i * 0.013
                box("SideRailSlot%s%d" % (side, i), x1 - 0.003 if side == "L" else x0 - 0.0005,
                    x1 + 0.0005 if side == "L" else x0 + 0.003, 0.044, 0.067, z, z + 0.006, "steel_dark", parent=p)
    tube("GasKnob", 0.008, front, front + 0.012, 0.072, "black", parent=p)
    box("GasLever", -0.002, 0.002, 0.072, 0.088, front + 0.006, front + 0.012, "black", parent=p)
    tube("Tube", 0.0095, front - 0.02, end, BORE_Y, "black", parent=p)
    node("Muzzle", p)
    node("Brake", p + "/Muzzle")
    node("Can", p + "/Muzzle")
    b = p + "/Muzzle/Brake"
    tube("Body", 0.0105, end, end + BRAKE_LEN, BORE_Y, "black", parent=b)
    for i in range(3):  # rings between the ports
        z = end + 0.012 + i * 0.019
        tube("Ring%d" % i, 0.0115, z, z + 0.006, BORE_Y, "black", parent=b)
    for i in range(2):
        z = end + 0.021 + i * 0.019
        for side, x0, x1 in both(0.0098, 0.0112):
            box("Port%s%d" % (side, i), x0, x1, BORE_Y - 0.004, BORE_Y + 0.004, z, z + 0.008, "steel_dark", parent=b)
    tube("Crown", 0.009, end + BRAKE_LEN, end + BRAKE_LEN + 0.001, BORE_Y, "steel_dark", parent=b)
    c = p + "/Muzzle/Can"
    tube("Mount", 0.012, end, end + 0.025, BORE_Y, "black", parent=c)
    tube("Can", 0.019, end + 0.025, end + CAN_LEN, BORE_Y, "black", parent=c)
    for i in range(4):  # the gripping rings round its back half
        z = end + 0.03 + i * 0.022
        tube("Grip%d" % i, 0.0198, z, z + 0.014, BORE_Y, "steel", parent=c)
    tube("Cap", 0.017, end + CAN_LEN, end + CAN_LEN + 0.002, BORE_Y, "steel_dark", parent=c)

# Magazine: a coyote PMAG, the top in the well, tilted (minus: the bottom goes forward); its window on the right,
# the ribs round the lower part and the floor plate's lip.
node("Mags")
node("ACR_Mag_30", "Mags", (0.0, -0.028, 0.085))
p = "Mags/ACR_Mag_30"
TILT = -6.0
MAG_Y0, MAG_Y1 = -0.123, 0.06
mid = (MAG_Y0 + MAG_Y1) / 2
ts, tc = math.sin(math.radians(TILT)), math.cos(math.radians(TILT))


def magbox(name, x0, x1, h0, h1, z0, z1, mat):
    """A box in the tilted body's frame: h along its height from the body's middle, z along its depth."""
    h, z = (h0 + h1) / 2, (z0 + z1) / 2
    parts.append((name, p, "box", (x1 - x0, h1 - h0, z1 - z0), ((x0 + x1) / 2, mid + tc * h - ts * z, ts * h + tc * z),
                  TILT, mat))


magbox("Body", -0.0115, 0.0115, MAG_Y0 - mid, MAG_Y1 - mid, -0.032, 0.032, "mag")
magbox("Window", -0.0122, -0.0112, -0.065, 0.005, -0.026, -0.021, "window")
for i in range(4):
    h = MAG_Y0 - mid + 0.012 + i * 0.011
    magbox("Rib%d" % i, -0.0125, 0.0125, h, h + 0.004, -0.032, 0.032, "mag")
magbox("Floor", -0.014, 0.014, MAG_Y0 - mid - 0.01, MAG_Y0 - mid, -0.035, 0.036, "mag")

# Stock: solid, the cheek riser on top, the black butt pad, the sling slot and the QD socket near the butt, the
# length buttons. Folded, it swings round the hinge's vertical axis to lie along the right side (prefab -x).
node("Stock")
node("Extended", "Stock")
s = "Stock/Extended"
mesh("Body", "stock", "fde", parent=s)
box("Pad", -0.021, 0.021, -0.059, 0.083, -0.321, -0.307, "rubber", parent=s)
for side, x0, x1 in both(0.0195, 0.0205):
    box("SlingSlot" + side, x0, x1, -0.035, -0.005, -0.296, -0.29, "steel_dark", parent=s)
    cylx("QD" + side, 0.005, x0, x1 + 0.0005, 0.06, -0.29, "black", parent=s)
    box("Button" + side, x0, x1 + 0.001, 0.05, 0.068, -0.2, -0.185, "fde", parent=s)
node("Folded", "Stock")
s = "Stock/Folded"
mesh("Body", "stock_folded", "fde", parent=s, pos=(-0.048, 0.0, 0.0))
box("Pad", -0.069, -0.027, -0.059, 0.083, 0.091, 0.105, "rubber", parent=s)

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
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(params[0]), f(params[0]), f(params[1]), 8 if kind == "cylx" else 12))
    if kind == "cylx":  # the cylinder's axis (local Y) across the gun
        xform = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %s, %s, %s)" % (f(c[0]), f(c[1]), f(c[2]))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/acr_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
