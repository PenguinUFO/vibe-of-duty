"""Generates prefabs/weapons/mk14_blockout.tscn: a blockout of the Mk 14 Mod 1 EBR, 7.62x51, 18" barrel.

Run from the repo:  python vibe-of-duty-p/tools/make_mk14_blockout.py   (overwrites the scene)
The chassis, the handguard, the receiver, the grip and the butt pad are meshes made by tools/make_parts.gd
(prefabs/weapons/mk14_<part>_mesh.tres) - run that first if they change.

Docs/LOADOUT.md, "Mk 14". After the owner's pictures (2026-10-27): the left-side drawing of the Mod 1 with the stock
in (902 mm long, so 1.4 mm a pixel; the 18" barrel from the chamber over the magazine's front to the flash hider's
end), the photos for the details. An M14 action in a Sage EBR aluminium chassis: the receiver with the aperture rear
sight on top behind a long rail, the deep handguard with oval cuts and a short side rail, the gas cylinder under the
barrel to the front sight's block, the slotted flash hider; the 20-round box magazine, the pistol grip behind the
trigger guard, the stock on two rods with the cheek rest and the tall butt pad. All black anodised / parkerized.
The op-rod handle (the charging handle) is on the right: WeaponView adds it (WeaponDef.charging_handle).

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin
sits under the chassis at the trigger, metres; prefab +x is the shooter's left. "Sights": Up / Down (the aperture
cranked down under an optic), "FrontSight": On / Off (gone under the ACOG). "Mags" holds "Mk14_Mag_20" (a node
named "*_Mag_*" so reloads take it out; it sits 0.11 m above and 0.015 m behind where the hand holds it).
Key points used by WeaponDB (prefab space): bore y 0.063; muzzle (0, 0.063, 0.647); the sight line y 0.097 through the
rear aperture's middle (z 0.025) and the front post's tip (z 0.546); grip (0, -0.042, -0.067); handguard
(0, 0.003, 0.34); op-rod handle (-0.026, 0.05, 0.1).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "mk14_blockout.tscn")

MATERIALS = {
    # Not all one black (it read as a silhouette): the anodised chassis a dark grey, the parkerized action and barrel
    # darker, the flash hider grey as in the photos, the magazine a greenish black.
    "alu": ((0.16, 0.16, 0.17), 0.4, 0.5),           # albedo, metallic, roughness: the anodised chassis
    "steel": ((0.1, 0.1, 0.11), 0.55, 0.45),         # the parkerized action, barrel
    "steel_grey": ((0.34, 0.34, 0.35), 0.6, 0.45),   # the flash hider
    "steel_dark": ((0.025, 0.025, 0.03), 0.5, 0.5),  # cuts, slots, the bore
    "polymer": ((0.1, 0.1, 0.105), 0.0, 0.75),       # grip, cheek rest, butt
    "rubber": ((0.06, 0.06, 0.065), 0.0, 0.9),
    "mag": ((0.12, 0.13, 0.11), 0.5, 0.5),
}
MESHES = ["chassis", "handguard", "receiver", "grip", "butt"]
K = 0.0014       # m a pixel of the drawing
PX0 = (228, 80)  # the drawing's pixel at the origin (the trigger, the chassis's bottom)


def P(x, y):
    """A drawing pixel -> (z, y) in metres."""
    return ((x - PX0[0]) * K, (PX0[1] - y) * K)


def Z(x):
    return P(x, 0)[0]


def Y(y):
    return P(0, y)[1]


BORE_Y = 0.063
MUZZLE_Z = 0.647
HIDER_Z = 0.575  # the long slotted flash hider, 72 mm
CHAMBER_Z = 0.19  # the barrel out of the receiver's front (its chamber is inside)
SIGHT_Y = 0.097
REAR_Z = 0.025
FRONT_Z = 0.546
GAS_Y = 0.0371
RAIL_TOP = 0.0896

parts = []
node_pos = {".": (0.0, 0.0, 0.0)}


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def bar(name, a, b, half_x, thick, mat, parent="."):
    """A flat bar from drawing pixel `a` to `b`: `half_x` across the gun, `thick` in the side plane."""
    za, ya = P(*a)
    zb, yb = P(*b)
    length = math.hypot(zb - za, yb - ya) + thick
    angle = -math.degrees(math.atan2(yb - ya, zb - za))  # the scene writes the basis by rows: +rot_x tips +Z down
    parts.append((name, parent, "box", (2 * half_x, thick, length), (0.0, (ya + yb) / 2, (za + zb) / 2), angle, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent=".", radius_end=None, segments=12):
    parts.append((name, parent, "cyl", (radius, z1 - z0, radius if radius_end is None else radius_end, segments),
                  (x, y, (z0 + z1) / 2), 90.0, mat))


def disc(name, radius, x0, x1, y, z, mat, parent="."):
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent="."):
    parts.append((name, parent, "ext_mesh", key, (0.0, 0.0, 0.0), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))
    node_pos[name if parent == "." else parent + "/" + name] = pos


def both(x0, x1):
    return (("L", x0, x1), ("R", -x1, -x0))


# Chassis round the action, its lightening holes; the handguard with the oval cuts and the short side rail; the long
# top rail from the receiver to the handguard's front, its cross slots.
mesh("Chassis", "chassis", "alu")
mesh("Handguard", "handguard", "alu")
for side, x0, x1 in both(0.0255, 0.027):
    for i, px in enumerate((300, 310, 320, 345, 357)):
        disc("Hole%s%d" % (side, i), 0.0035, x0, x1, Y(62), Z(px), "steel_dark")
    disc("Bolt%s" % side, 0.006, x0, x1, Y(62), Z(333), "steel")
    box("Channel%s" % side, x0 - 0.0005, x1 - 0.0005, Y(65), Y(59), Z(260), Z(370), "steel_dark")  # the side channel
    for i, px in enumerate((210, 380)):
        disc("ChassisScrew%s%d" % (side, i), 0.0045, x0, x1 + 0.0005, Y(56), Z(px), "steel")
for side, x0, x1 in both(0.0285, 0.0295):
    for i, (px0, px1) in enumerate(((488, 503), (510, 525), (533, 548), (553, 566))):
        box("Oval%s%d" % (side, i), x0, x1, Y(38), Y(32), Z(px0), Z(px1), "steel_dark")
    for i, (px0, px1) in enumerate(((495, 510), (520, 535))):
        box("OvalLow%s%d" % (side, i), x0, x1, Y(65), Y(59), Z(px0), Z(px1), "steel_dark")
    for i, (px, py) in enumerate(((420, 34), (440, 34), (420, 46), (440, 46))):
        disc("Screw%s%d" % (side, i), 0.0018, x0, x1 + 0.0004, Y(py), Z(px), "steel")
    box("SideRail" + side, x0 if side == "L" else x0 - 0.004, x1 + 0.004 if side == "L" else x1, Y(56), Y(43), Z(515),
        Z(570), "alu")
for side, x0, x1 in both(0.0285, 0.031):  # the smooth cover panel on the handguard's rear half
    box("Panel" + side, x0, x1, Y(70), Y(28), Z(378), Z(482), "alu")
box("BottomRail", -0.0105, 0.0105, 0.001, 0.0075, Z(512), Z(570), "alu")
for i in range(5):
    z = Z(515) + i * 0.01
    box("BottomSlot%d" % i, -0.011, 0.011, 0.0005, 0.0035, z, z + 0.005, "steel_dark")
box("TopRail", -0.0105, 0.0105, RAIL_TOP - 0.006, RAIL_TOP, Z(265), Z(572), "alu")
box("RailMount", -0.012, 0.012, 0.064, RAIL_TOP - 0.005, Z(330), Z(372), "alu")  # the rail's foot on the receiver's front
for i in range(int((Z(570) - Z(268)) / 0.01)):
    z = Z(268) + i * 0.01
    box("RailSlot%d" % i, -0.011, 0.011, RAIL_TOP - 0.0025, RAIL_TOP + 0.0005, z, z + 0.005, "steel_dark")

# The action: the receiver, the aperture rear sight on its heel (a ring round the sight line, its knobs), the
# trigger guard and the trigger under the chassis.
mesh("Receiver", "receiver", "steel")
# "Sights": the aperture up on the sight line ("Up") or cranked all the way down under an optic ("Down": the ring's
# top under the rail's, out of the optic's view).
node("Sights")
for variant, drop in (("Up", 0.0), ("Down", 0.017)):
    node(variant, "Sights")
    sp = "Sights/" + variant
    line = SIGHT_Y - drop
    box("SightBase", -0.009, 0.009, Y(30), line - 0.009, REAR_Z - 0.008, REAR_Z + 0.006, "steel", parent=sp)
    for side, x0, x1 in both(0.003, 0.0085):  # the aperture: a ring, the hole 6 mm across
        box("Ring" + side, x0, x1, line - 0.009, line + 0.008, REAR_Z - 0.002, REAR_Z + 0.002, "steel", parent=sp)
    box("RingTop", -0.0085, 0.0085, line + 0.003, line + 0.008, REAR_Z - 0.002, REAR_Z + 0.002, "steel", parent=sp)
    box("RingBottom", -0.0085, 0.0085, line - 0.009, line - 0.003, REAR_Z - 0.002, REAR_Z + 0.002, "steel", parent=sp)
for side, x0, x1 in both(0.009, 0.014):
    disc("Knob" + side, 0.006, x0, x1, Y(30) + 0.006, REAR_Z, "steel")
box("OpRod", -0.019, -0.015, 0.046, 0.054, 0.1, Z(372), "steel")  # the op rod along the right, its handle: WeaponView
box("BoltTop", -0.008, 0.008, 0.0714, 0.077, 0.03, 0.085, "steel")  # the bolt's back in the receiver's top
guard = [(217, 80), (218, 92), (225, 99), (240, 100), (248, 94), (250, 82)]
for i in range(len(guard) - 1):
    bar("Guard%d" % i, guard[i], guard[i + 1], 0.004, 0.0035, "steel")
box("Trigger", -0.003, 0.003, Y(92), Y(80), -0.003, 0.004, "steel", rot_x=8.0)
box("Safety", -0.004, 0.004, Y(88), Y(80), Z(252), Z(256), "steel")

# Barrel, the gas cylinder under it to the front sight's block, the post between its ears, the slotted flash hider.
tube("Barrel", 0.0105, CHAMBER_Z, HIDER_Z, BORE_Y, "steel", radius_end=0.0095, segments=14)
tube("Hider", 0.0112, HIDER_Z, MUZZLE_Z, BORE_Y, "steel_grey", segments=12)
tube("Bore", 0.0045, MUZZLE_Z - 0.03, MUZZLE_Z + 0.0004, BORE_Y, "steel_dark")
for i in range(4):  # the four slots, open at the end
    a = i * math.pi / 2 + math.pi / 4
    x, y = 0.011 * math.cos(a), BORE_Y + 0.011 * math.sin(a)
    box("HiderSlot%d" % i, x - 0.0018, x + 0.0018, y - 0.0018, y + 0.0018, MUZZLE_Z - 0.045, MUZZLE_Z + 0.0005, "steel_dark")
tube("HiderRing", 0.0118, HIDER_Z, HIDER_Z + 0.012, BORE_Y, "steel_grey", segments=12)
tube("GasCylinder", 0.0075, Z(560), Z(632), GAS_Y, "steel")
tube("GasPlug", 0.0082, Z(632), Z(640), GAS_Y, "steel")
box("GasBlock", -0.0105, 0.0105, Y(60), Y(28), Z(600), Z(625), "steel")
# "FrontSight": the post with its ears on the gas block ("On"), or none ("Off": under the ACOG, whose 4x view had its
# tip at the bottom edge).
node("FrontSight")
node("On", "FrontSight")
node("Off", "FrontSight")
fs = "FrontSight/On"
box("FrontBase", -0.004, 0.004, Y(28), SIGHT_Y - 0.012, Z(612), Z(622), "steel", parent=fs)
box("FrontPost", -0.0013, 0.0013, SIGHT_Y - 0.013, SIGHT_Y, FRONT_Z - 0.0015, FRONT_Z + 0.0015, "steel", parent=fs)
for side, x0, x1 in both(0.0045, 0.0065):
    box("FrontEar" + side, x0, x1, SIGHT_Y - 0.013, SIGHT_Y - 0.002, FRONT_Z - 0.003, FRONT_Z + 0.003, "steel", parent=fs)

# Grip; the stock: two rods back from the chassis, the cheek rest over them, the butt pad.
mesh("Grip", "grip", "polymer")
for side, x0, x1 in both(0.0155, 0.0162):
    box("GripTexture" + side, x0, x1, Y(140), Y(95), Z(168), Z(192), "rubber", rot_x=12.0)
# The stock: the buffer housing out of the chassis, two thin rods to the butt, the cheek rest - a thin pad on two
# risers, its back curling up - and the skeleton butt with its holes and the rubber pad.
box("StockMount", -0.018, 0.018, Y(70), Y(50), Z(185), Z(205), "alu")
for i, py in enumerate((55, 66)):
    tube("Rod%d" % i, 0.0055, Z(90), Z(190), Y(py), "steel")
for i, px in enumerate((95, 165)):
    box("Riser%d" % i, -0.004, 0.004, Y(55), Y(44), Z(px), Z(px + 6), "steel")
box("Cheek", -0.016, 0.016, Y(44), Y(40), Z(85), Z(190), "polymer")
box("CheekCurl", -0.016, 0.016, Y(44), Y(40), Z(70), Z(88), "polymer", rot_x=20.0)
mesh("Butt", "butt", "polymer")
for side, x0, x1 in both(0.022, 0.0228):
    for i, (px, py) in enumerate(((62, 62), (62, 76), (64, 90), (66, 104), (68, 118), (80, 70), (78, 86))):
        disc("ButtHole%s%d" % (side, i), 0.0033 if i < 5 else 0.0045, x0, x1, Y(py), Z(px), "steel_dark")
box("Pad", -0.0235, 0.0235, Y(138), Y(52), Z(41), Z(47), "rubber")

# The 20-round magazine, its base a little forward.
node("Mags")
grip_at = (0.0, -0.075, 0.14)  # where the hand holds it, near the bottom
mag_node = (grip_at[0], grip_at[1] + 0.11, grip_at[2] - 0.015)
node("Mk14_Mag_20", "Mags", mag_node)
tilt = -7.0  # the bottom forward
top_y, bottom_y = Y(70), Y(140)
mz = (Z(300) + Z(352)) / 2
box("Body", -0.0125, 0.0125, bottom_y, top_y, mz - 0.034, mz + 0.034, "mag", rot_x=tilt, parent="Mags/Mk14_Mag_20")
for side, x in (("L", 0.0128), ("R", -0.0128)):  # the side ribs
    box("Rib" + side, x - 0.0008, x + 0.0008, bottom_y + 0.01, top_y - 0.01, mz - 0.012, mz - 0.006, "mag", rot_x=tilt,
        parent="Mags/Mk14_Mag_20")
box("Floor", -0.0135, 0.0135, bottom_y - 0.004, bottom_y + 0.002, mz - 0.036, mz + 0.036, "mag", rot_x=tilt,
    parent="Mags/Mk14_Mag_20")

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Mk14" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    o = node_pos[parent]
    c = (c[0] - o[0], c[1] - o[1], c[2] - o[2])  # into the parent's space (nothing is turned at rest)
    if kind == "cylx":
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
        top = params[2] if kind == "cyl" else params[0]
        segments = params[3] if kind == "cyl" else 8
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(top), f(params[0]), f(params[1]), segments))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/mk14_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
