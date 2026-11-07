"""Generates prefabs/weapons/striker_blockout.tscn: a blockout of the Armsel Striker, 12 gauge, a 12-round drum, with the
Protecta Bulldog as its other body.

Run from the repo:  python vibe-of-duty-p/tools/make_striker_blockout.py   (overwrites the scene)
              or:  python vibe-of-duty-p/tools/make_striker_blockout.py --parts   (prints the profiles for
                   tools/make_parts.gd; paste them there and run it - the scene uses its meshes)

Docs/LOADOUT.md, "Armsel Striker". Traced off the owner's photos: the Striker off Docs/striker/01_striker_pair.png (the
upper gun, its left side, the stock out; 1.022 mm a pixel - the drum 138 mm across over 135 px, the whole gun ~785 mm,
the 12" barrel ~300 mm in front of the drum), the Bulldog off 06_bulldog.webp (its right side; 0.232 mm a pixel - the
same drum over 582 px). The two bodies share the drum: both photos are put on its middle. Left out (owner,
2026-11-07): the Bulldog's wire hook at the back and the channel in its side (07_bulldog_remove); the ejector rod
along the barrel and the winding key on the drum's front stay.
- "Body": Striker (the receiver, the folding stock, the 12" shroud) / Bulldog (the block receiver with its grip, no
  stock, the 7.8" shroud). "Body/Striker/Stock": Extended / Folded (over the top, the butt flat over the shroud).
- "Drum": the 12 chambers, the winding key on the front - its origin on the drum's axis: WeaponView turns it about
  +Z a chamber (30 degrees) a shot and a shell loaded.
- "Shell": a shell at the loading gate on the right (the chamber at 3 o'clock, seen from behind), its head back,
  shown while the left hand pushes it in.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin sits
at the Striker's trigger, on the receiver's bottom, metres; prefab +x is the shooter's left.
Key points used by WeaponDB (prefab space): printed by this script.
"""
import math
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "striker_blockout.tscn")

MATERIALS = {
    "black": ((0.1, 0.105, 0.12), 0.5, 0.5),           # albedo, metallic, roughness: the receivers, the strap's screws
    "polymer": ((0.07, 0.07, 0.075), 0.0, 0.75),       # the grips, the stock's butt
    "gunmetal": ((0.3, 0.3, 0.31), 0.6, 0.4),          # the Striker's shroud and stock arm (photo 01)
    "nickel": ((0.52, 0.49, 0.44), 0.7, 0.35),         # the Bulldog's shroud and strap (photo 06)
    "drum": ((0.46, 0.46, 0.45), 0.7, 0.35),           # the drum
    "steel": ((0.2, 0.2, 0.21), 0.6, 0.4),             # the rod, the hook, pins
    "steel_dark": ((0.025, 0.025, 0.03), 0.5, 0.5),    # bores, chambers, slots
    "hull": ((0.62, 0.1, 0.08), 0.0, 0.5),             # a shell's red plastic
    "brass": ((0.62, 0.46, 0.2), 0.7, 0.35),
}
KS = 0.001022         # m a pixel of photo 01 (the Striker)
KB = 0.000232         # m a pixel of photo 06 (the Bulldog)
DRUM_R = 0.068
DRUM_Z0, DRUM_Z1 = 0.026, 0.114   # its back and front faces
DRUM_Y = -0.0082      # its axis: under the Striker's receiver's bottom
CHAMBER_R = 0.054     # the chambers' circle; the top one is the bore
CHAMBER_HOLE = 0.0105
BORE_Y = DRUM_Y + CHAMBER_R
ZM = (DRUM_Z0 + DRUM_Z1) / 2


def S(x, y):
    """A pixel of photo 01 (the Striker, muzzle to the left) -> (z, y) in metres; the drum's middle at (355, 151)."""
    return (ZM + (355 - x) * KS, DRUM_Y + (151 - y) * KS)


def B(x, y):
    """A pixel of photo 06 (the Bulldog, muzzle to the right) -> (z, y); the drum's middle at (836, 686)."""
    return (ZM + (x - 836) * KB, DRUM_Y + (686 - y) * KB)


SZ = lambda x: S(x, 0)[0]
BZ = lambda x: B(x, 0)[0]
BY = lambda y: B(0, y)[1]
S_STRAP_TOP = S(0, 67)[1]
B_STRAP_TOP = BY(309)
NOTCH = 0.005             # the rear notch's ears over the strap's back (the photos show none: aimed over the bare
                          # strap the blade's tip, flush with it, was hidden behind it)
S_SIGHT_Y = S_STRAP_TOP + NOTCH   # the sight lines: the ears' tops, the blades' tips
B_SIGHT_Y = B_STRAP_TOP + NOTCH
S_SHROUD_R, B_SHROUD_R = 0.0158, 0.0137
S_MUZZLE, B_MUZZLE = SZ(12), BZ(1840)
S_PLATE = (DRUM_Z1, SZ(303))      # the frame's front plate, holding the drum's axle
S_STRAP = (SZ(383), SZ(312))
B_STRAP = (BZ(697), BZ(990))
S_BLADE_Z = SZ(63)                # the blade's upright front edge (the slope faces the eye)
B_BLADE_Z = BZ(1655)              # the Bulldog's: upright at the back
HINGE = S(528, 108)               # the stock's hinge, the receiver's back top
SHELL_PORT = (-CHAMBER_R, DRUM_Y, DRUM_Z0 - 0.022)   # the shell's middle-ish: its front 25 mm in the chamber

# Side profiles for tools/make_parts.gd: (photo, pixels round the outline, half width, chamfer).
PROFILES = {
    # The Striker's receiver behind the drum, its top falling to the stock's hinge.
    "s_receiver": ("s", [(395, 74), (503, 74), (522, 90), (531, 108), (526, 136), (512, 152), (452, 152), (447, 143),
                         (395, 143)], 0.02, 0.003),
    "s_grip": ("s", [(455, 150), (512, 150), (514, 175), (522, 205), (528, 234), (522, 240), (481, 240), (475, 226),
                     (473, 202), (467, 182), (456, 168)], 0.016, 0.005),
    "s_guard": ("s", [(395, 143), (402, 143), (402, 177), (437, 177), (443, 166), (446, 150), (452, 150), (449, 170),
                      (441, 183), (395, 183)], 0.0045, 0.0012),
    "s_trigger": ("s", [(424, 143), (431, 143), (429, 158), (420, 174), (415, 175), (421, 158)], 0.003, 0.001),
    "s_foregrip": ("s", [(146, 113), (209, 113), (206, 140), (203, 160), (207, 205), (202, 209), (160, 209),
                         (156, 198), (160, 184), (155, 170), (158, 150), (155, 134), (150, 121)], 0.0155, 0.005),
    "s_arm": ("s", [(522, 98), (560, 116), (737, 119), (737, 143), (575, 143), (527, 137)], 0.009, 0.002),
    "s_butt": ("s", [(737, 114), (748, 97), (770, 93), (782, 100), (782, 200), (775, 211), (760, 211), (752, 195),
                     (740, 150)], 0.02, 0.005),
    # The Bulldog's block: the receiver and the grip in one, the guard's front post on the drum.
    "b_body": ("b", [(170, 330), (645, 330), (645, 600), (430, 600), (420, 688), (395, 700), (368, 725), (345, 770),
                     (333, 820), (340, 880), (330, 940), (340, 1000), (330, 1015), (105, 1015), (100, 960),
                     (105, 880), (125, 820), (160, 750), (180, 690), (185, 630), (165, 590), (150, 560),
                     (150, 350)], 0.021, 0.005),
    "b_guard": ("b", [(420, 685), (440, 690), (470, 742), (625, 742), (625, 600), (645, 600), (645, 760), (465, 760),
                      (430, 718)], 0.0045, 0.0012),
    "b_trigger": ("b", [(455, 605), (465, 605), (472, 650), (490, 700), (502, 716), (492, 714), (470, 682),
                        (455, 640)], 0.003, 0.001),
    # The frame's front: off the strap's end down round the barrel's breech, holding the drum's axle.
    "b_front": ("b", [(990, 309), (1025, 309), (1040, 322), (1048, 360), (1068, 384), (1080, 388), (1080, 482),
                      (1027, 482), (1027, 392), (990, 392)], 0.019, 0.003),
    "b_foregrip": ("b", [(1360, 478), (1645, 478), (1640, 510), (1600, 525), (1590, 560), (1595, 640), (1585, 720),
                         (1595, 800), (1590, 900), (1580, 925), (1385, 925), (1375, 900), (1385, 800), (1378, 700),
                         (1400, 600), (1400, 530), (1370, 510)], 0.0155, 0.005),
}
# Made in metres: the front blades (their tips on the sight lines), the folded stock.
BLADES = {
    "s_blade": [(S_BLADE_Z, BORE_Y + S_SHROUD_R - 0.002), (S_BLADE_Z, S_SIGHT_Y), (S_BLADE_Z - 0.007, S_SIGHT_Y),
                (S_BLADE_Z - 0.021, BORE_Y + S_SHROUD_R - 0.002)],
    "b_blade": [(B_BLADE_Z, BORE_Y + B_SHROUD_R - 0.002), (B_BLADE_Z, B_SIGHT_Y), (B_BLADE_Z + 0.008, B_SIGHT_Y),
                (B_BLADE_Z + 0.016, BORE_Y + B_SHROUD_R - 0.002)],
}
MESHES = list(PROFILES) + list(BLADES)


def outline(photo, points):
    f = S if photo == "s" else B
    return [f(*p) for p in points]


if "--parts" in sys.argv:
    def emit(name, items, width, chamfer):
        lines, line = [], "\t\t\t\"%s\": {\"points\": [" % name
        for i, item in enumerate(items):
            item += ", " if i < len(items) - 1 else "]"
            if len(line) + len(item) > 116:
                lines.append(line.rstrip())
                line = "\t\t\t\t\t"
            line += item
        lines.append(line + ',')
        print("\n".join(lines))
        print('\t\t\t\t\t"width": [Vector2(0, %g)], "chamfer": %g},' % (width, chamfer))
    v = lambda z, y: "Vector2(%g, %g)" % (round(z, 4), round(y, 4))
    print('\t"striker": {\n\t\t"profiles": {')
    for name, (photo, points, width, chamfer) in PROFILES.items():
        emit(name, [v(*p) for p in outline(photo, points)], width, chamfer)
    for name, points in BLADES.items():
        emit(name, [v(*p) for p in points], 0.0015, 0.0005)
    print('\t\t},\n\t\t"sections": {},\n\t},')
    sys.exit()

parts = []
node_pos = {".": (0.0, 0.0, 0.0)}


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent=".", radius_end=None, segments=16):
    """A cylinder along the barrel; `radius_end` at z1 (a cone)."""
    if z0 > z1:
        z0, z1 = z1, z0
        radius, radius_end = (radius if radius_end is None else radius_end), radius
    parts.append((name, parent, "cyl", (radius, z1 - z0, radius if radius_end is None else radius_end, segments),
                  (x, y, (z0 + z1) / 2), 90.0, mat))


def disc(name, radius, x0, x1, y, z, mat, parent="."):
    """A cylinder across the gun (its axis along x)."""
    x0, x1 = sorted((x0, x1))
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent=".", x=0.0, y=0.0, z=0.0):
    """A mesh built in place (make_parts.gd: prefab space), or moved by (x, y, z)."""
    parts.append((name, parent, "ext_mesh", key, (x, y, z), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))
    o = node_pos[parent]
    node_pos[name if parent == "." else parent + "/" + name] = (o[0] + pos[0], o[1] + pos[1], o[2] + pos[2])


def both(x0, x1):
    return (("L", x0, x1), ("R", -x1, -x0))


def shroud(parent, z0, z1, radius, mat, slots, muzzle_z, cap_z, cap_r, rod_x):
    """The perforated shroud round the barrel, the knurled cap at the muzzle, the ejector rod on the right with its
    spring and hook."""
    tube("Shroud", radius, z0, z1, BORE_Y, mat, parent=parent, segments=16)
    tube("Cap", cap_r, cap_z, muzzle_z, BORE_Y, "black", parent=parent, segments=16)
    tube("Bore", 0.0093, muzzle_z - 0.02, muzzle_z + 0.0005, BORE_Y, "steel_dark", parent=parent)
    for i, (za, zb) in enumerate(slots):
        for side, x0, x1 in both(radius * 0.96, radius + 0.0006):
            box("Slot%d%s" % (i, side), x0, x1, BORE_Y - 0.0035, BORE_Y + 0.0035, za, zb, "steel_dark", parent=parent)
    tube("Rod", 0.0018, z0, cap_z - 0.012, BORE_Y - 0.005, "steel", x=rod_x, parent=parent, segments=8)
    tube("Spring", 0.003, z0 + 0.01, cap_z - 0.03, BORE_Y - 0.005, "steel_dark", x=rod_x, parent=parent, segments=8)
    box("Hook", rod_x - 0.003, rod_x + 0.004, BORE_Y - 0.011, BORE_Y + 0.002, cap_z - 0.018, cap_z - 0.01, "steel",
        parent=parent)


# --- "Drum": shared by both bodies; its origin on its axis, turned about +Z by WeaponView.
node("Drum", ".", (0.0, DRUM_Y, ZM))
tube("Can", DRUM_R, DRUM_Z0, DRUM_Z1, DRUM_Y, "drum", parent="Drum", segments=28)
for i, z in enumerate((DRUM_Z0 + 0.004, DRUM_Z1 - 0.004)):  # the rims
    tube("Rim%d" % i, DRUM_R + 0.0012, z - 0.0015, z + 0.0015, DRUM_Y, "drum", parent="Drum", segments=28)
for k in range(12):
    a = k * math.tau / 12
    x, y = CHAMBER_R * math.sin(a), DRUM_Y + CHAMBER_R * math.cos(a)
    tube("Chamber%dB" % k, CHAMBER_HOLE, DRUM_Z0 - 0.0006, DRUM_Z0 + 0.002, y, "steel_dark", x=x, parent="Drum", segments=10)
    tube("Chamber%dF" % k, CHAMBER_HOLE * 0.85, DRUM_Z1 - 0.002, DRUM_Z1 + 0.0006, y, "steel_dark", x=x, parent="Drum",
         segments=10)
# The winding key on the axis in front: the hub through the frame, the wing, the knurled wheel. Turns with the drum.
tube("KeyHub", 0.0065, DRUM_Z1, DRUM_Z1 + 0.013, DRUM_Y, "black", parent="Drum", segments=10)
box("KeyWing", -0.006, 0.006, DRUM_Y - 0.0225, DRUM_Y + 0.0225, DRUM_Z1 + 0.011, DRUM_Z1 + 0.024, "polymer", parent="Drum")
tube("KeyWheel", 0.011, DRUM_Z1 + 0.024, DRUM_Z1 + 0.031, DRUM_Y, "polymer", parent="Drum", segments=14)

# --- "Shell": the shell at the gate, along the bore, the brass head back.
node("Shell", ".", SHELL_PORT)
tube("Hull", 0.0102, SHELL_PORT[2] - 0.023, SHELL_PORT[2] + 0.047, SHELL_PORT[1], "hull", x=SHELL_PORT[0], parent="Shell")
tube("Head", 0.0106, SHELL_PORT[2] - 0.035, SHELL_PORT[2] - 0.023, SHELL_PORT[1], "brass", x=SHELL_PORT[0], parent="Shell")

node("Body")
for state in ("Striker", "Bulldog"):
    node(state, "Body")

# --- the Striker: the receiver, the strap over the drum, the frame's front plate, the shroud, the foregrip, the stock.
T = "Body/Striker"
mesh("Receiver", "s_receiver", "black", parent=T)
mesh("Grip", "s_grip", "polymer", parent=T)
mesh("Guard", "s_guard", "black", parent=T)
mesh("Trigger", "s_trigger", "steel", parent=T)
box("Strap", -0.019, 0.019, DRUM_Y + DRUM_R - 0.001, S_STRAP_TOP, S_STRAP[0], S_STRAP[1], "black", parent=T)
for side, x0, x1 in both(0.002, 0.007):
    box("RearEar" + side, x0, x1, S_STRAP_TOP - 0.001, S_SIGHT_Y, S_STRAP[0], S_STRAP[0] + 0.008, "black", parent=T)
for side, x0, x1 in both(0.019, 0.0205):
    for i, px in enumerate((331, 373)):
        disc("Screw%s%d" % (side, i), 0.0035, x0, x1, S(0, 73)[1], SZ(px), "steel", parent=T)
    disc("Pin" + side, 0.004, x0 + 0.001, x1 + 0.001, S(0, 151)[1], SZ(426), "steel", parent=T)
box("Plate", -0.016, 0.016, DRUM_Y - 0.012, S_STRAP_TOP - 0.004, S_PLATE[0], S_PLATE[1], "black", parent=T)
shroud(T, S_PLATE[1], SZ(45), S_SHROUD_R, "gunmetal", [(SZ(px1), SZ(px0)) for px0, px1 in
       ((70, 95), (118, 145), (167, 195), (215, 242), (263, 290))], S_MUZZLE, SZ(45), 0.0165, -(S_SHROUD_R + 0.004))
mesh("Blade", "s_blade", "black", parent=T)
mesh("Foregrip", "s_foregrip", "polymer", parent=T)
node("Stock", T, (0.0, HINGE[1], HINGE[0]))
for state in ("Extended", "Folded"):
    node(state, T + "/Stock")
E = T + "/Stock/Extended"
mesh("Arm", "s_arm", "gunmetal", parent=E)
mesh("Butt", "s_butt", "polymer", parent=E, )
disc("HingePin", 0.006, -0.012, 0.012, HINGE[1], HINGE[0], "steel", parent=E)
# Folded: up off the hinge and forward over the receiver and the strap, the butt flat over the shroud.
F = T + "/Stock/Folded"
top = S_SIGHT_Y + 0.001
box("Riser", -0.009, 0.009, HINGE[1] - 0.008, top + 0.012, HINGE[0] - 0.012, HINGE[0] + 0.012, "gunmetal", parent=F)
box("Arm", -0.009, 0.009, top, top + 0.012, HINGE[0] - 0.012, HINGE[0] + 0.255, "gunmetal", parent=F)
box("Butt", -0.02, 0.02, top + 0.002, top + 0.016, HINGE[0] + 0.24, HINGE[0] + 0.355, "polymer", parent=F)
disc("HingePin", 0.006, -0.012, 0.012, HINGE[1], HINGE[0], "steel", parent=F)

# --- the Bulldog: the block body, the strap, the front, the short shroud, the foregrip.
G = "Body/Bulldog"
mesh("Body", "b_body", "black", parent=G)
mesh("Guard", "b_guard", "black", parent=G)
mesh("Trigger", "b_trigger", "steel", parent=G)
box("Strap", -0.019, 0.019, DRUM_Y + DRUM_R - 0.001, B_STRAP_TOP, B_STRAP[0], B_STRAP[1], "nickel", parent=G)
for side, x0, x1 in both(0.002, 0.007):
    box("RearEar" + side, x0, x1, B_STRAP_TOP - 0.001, B_SIGHT_Y, B_STRAP[0], B_STRAP[0] + 0.008, "black", parent=G)
for side, x0, x1 in both(0.019, 0.0205):
    for i, px in enumerate((757, 935)):
        disc("Screw%s%d" % (side, i), 0.0065, x0, x1, BY(350), BZ(px), "black", parent=G)
    disc("Pin" + side, 0.006, x0 + 0.002, x1 + 0.002, BY(640), BZ(365), "steel", parent=G)
    disc("RearPin" + side, 0.0055, x0 + 0.002, x1 + 0.002, BY(410), BZ(180), "steel", parent=G)
mesh("Front", "b_front", "black", parent=G)
shroud(G, BZ(1080), BZ(1700), B_SHROUD_R, "nickel", [(BZ(px0), BZ(px1)) for px0, px1 in
       ((1170, 1260), (1365, 1450), (1560, 1650))], B_MUZZLE, BZ(1700), 0.0145, -(B_SHROUD_R + 0.004))
mesh("Blade", "b_blade", "nickel", parent=G)
mesh("Foregrip", "b_foregrip", "polymer", parent=G)

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Striker" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    o = node_pos[parent]
    if kind != "node":
        c = (c[0] - o[0], c[1] - o[1], c[2] - o[2])  # into the parent's space
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
        top_r = params[2] if kind == "cyl" else params[0]
        segments = params[3] if kind == "cyl" else 12
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(top_r), f(params[0]), f(params[1]), segments))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/striker_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
v3 = lambda x, y, z: "Vector3(%s, %s, %s)" % (round(x, 4), round(y, 4), round(z, 4))
print("bore y", round(BORE_Y, 4), "drum y", round(DRUM_Y, 4), "shell port", v3(*SHELL_PORT))
print("striker muzzle", v3(0, BORE_Y, S_MUZZLE), "rear", v3(0, S_SIGHT_Y, S_STRAP[0] + 0.004), "front", v3(0, S_SIGHT_Y, S_BLADE_Z - 0.0035))
print("bulldog muzzle", v3(0, BORE_Y, B_MUZZLE), "rear", v3(0, B_SIGHT_Y, B_STRAP[0] + 0.004), "front", v3(0, B_SIGHT_Y, B_BLADE_Z + 0.004))
print("striker right", v3(0, *reversed(S(492, 200))), "left", v3(0, *reversed(S(181, 160))))
print("bulldog right", v3(0, *reversed(B(228, 800))), "left", v3(0, *reversed(B(1490, 660))))
print("folded top", round(S_SIGHT_Y + 0.013, 4), "hinge", v3(0, HINGE[1], HINGE[0]))
