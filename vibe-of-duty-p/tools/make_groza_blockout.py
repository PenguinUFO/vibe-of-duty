"""Generates prefabs/weapons/groza_blockout.tscn: a blockout of the OTs-14-1A Groza-1, 7.62x39, a bullpup on the
AKS-74U.

Run from the repo:  python vibe-of-duty-p/tools/make_groza_blockout.py   (overwrites the scene)
              or:  python vibe-of-duty-p/tools/make_groza_blockout.py --parts   (prints the profiles for
                   tools/make_parts.gd; paste them there and run it - the scene uses its meshes)

Docs/LOADOUT.md, "Гроза". Traced off the owner's photo Docs/groza/02_po_can.png (from the right on white, the PO 4x34
and the can on): 0.95 mm a pixel - the AK grip 111 mm tall (114 in the AK's model), the AKM magazine's 60 mm top
fills the well. The short barrel and its compensator after 06_short_left (scaled by the gun's length to the frame's
front), the muzzle grip after 07, 08. The photos' gun is the 9x39 OTs-14-4A (a straight magazine); the 7.62x39 one
takes the AK's curved magazines (01_drawing) - the AK's own meshes (tools/make_ak_mag.gd), the 30 and the RPK's 40,
here in black steel. The receiver and the frame dark grey paint, the barrel black; the wooden handguard, the plum grip.
- "Muzzle": Comp (the short barrel's compensator) / Can (the OTs-14-1A-03 suppressor) / Grip (the muzzle grip, its
  housing over the barrel's end - "Ствол с рукояткой"); the can and the grip never together.
- "Mags": Groza_Mag_30 / Groza_Mag_40.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin sits
at the top of the guard's hole by the trigger, metres; prefab +x is the shooter's left (the photo shows the right).
"Handle": the AK's charging handle on the right, riding the bolt; "Bolt": the carrier in the AK's ejection port by the
cheek. Key points used by WeaponDB (prefab space): printed by this script.
"""
import math
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "groza_blockout.tscn")

MATERIALS = {
    # Not all one black (it read as a silhouette, as the Mk 14's): the painted receiver and frame a dark grey, the
    # barrel and the small parts darker.
    "paint": ((0.16, 0.16, 0.17), 0.4, 0.55),         # albedo, metallic, roughness: receiver, butt, frame
    "black": ((0.1, 0.1, 0.11), 0.55, 0.45),          # barrel, compensator, sights, guard
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),        # pins, screws, levers
    "steel_dark": ((0.025, 0.025, 0.03), 0.5, 0.5),   # ports, slots, holes
    "steel_bright": ((0.36, 0.36, 0.38), 0.7, 0.35),  # the bolt carrier in the port
    "wood": ((0.5, 0.2, 0.08), 0.0, 0.6),             # the handguard (photos 02, 09: red-brown)
    "grip": ((0.2, 0.09, 0.08), 0.0, 0.6),            # the plum bakelite grip (WeaponSkin: polymer by name)
    "polymer": ((0.08, 0.08, 0.085), 0.0, 0.75),      # the muzzle grip
    "can": ((0.14, 0.13, 0.12), 0.4, 0.6),            # the suppressor's worn black (photo 02: browner than the gun)
    "mag_steel": ((0.12, 0.12, 0.125), 0.5, 0.5),     # the steel 7.62 magazine (a "mag" not named polymer: metal)
}
MESHES = ["body", "butt", "handle_rear", "handle_bar", "handle_front", "front", "grip", "guard", "trigger", "sling",
          "grip_housing", "fore_grip"]
AK_MESHES = {"mag": "ak_mag", "mag_rpk40": "ak_mag_rpk40"}  # the AK's magazines (tools/make_ak_mag.gd)
K = 0.00095           # m a pixel of photo 02
PX0 = (460, 205)      # the photo's pixel at the origin (the guard's hole, its top, at the trigger)


def P(x, y):
    """A photo pixel -> (z, y) in metres (the muzzle on the photo's right: +Z)."""
    return ((x - PX0[0]) * K, (PX0[1] - y) * K)


def Z(x):
    return P(x, 0)[0]


def Y(y):
    return P(0, y)[1]


BORE_Y = Y(174)       # the can's axis on photo 02
SIGHT_Y = Y(76)       # the irons: the rear leaf's ears' top, the front post's tip
FRAME_FRONT = 515     # px: the frame's front post, the barrel out of it
# The short barrel ahead of the frame (photo 06 x 1.049 - the gun's length to the frame there and here): the barrel's
# thick stub, the sleeve, the compensator.
STUB = (515, 533, 0.0115)
SLEEVE = (533, 564, 0.0105)
COMP = (564, 582, 0.0088)
CAN = ((517, 530, 0.0235), (530, 635, 0.0295), (635, 845, 0.0228))  # (from px, to px, radius): collar, front, body
EYE_IRON = 0.12       # m: the eye behind the rear leaf (the cheek forward on the receiver)

# Side profiles for tools/make_parts.gd, photo pixels round the outline: (points, half width(s) [(px, hw)], chamfer).
PROFILES = {
    # The receiver with the stock's shell round it: flat on top back to the butt plate, a step up under the frame's
    # rear post; the magazine well's mouth, the trigger group's rear behind it.
    "body": ([(48, 137), (278, 137), (283, 129), (345, 129), (345, 205), (285, 207), (212, 209), (200, 216),
              (60, 220), (48, 220)], [(0, 0.0165)], 0.003),
    # The butt plate: a deep box with rounded corners, wider than the receiver.
    "butt": ([(21, 138), (25, 132), (44, 131), (48, 136), (48, 262), (42, 269), (28, 270), (21, 263)],
             [(0, 0.022)], 0.004),
    # The carry frame: the rear post (the rear sight in its top), the bar - a channel, one wall each side - and the
    # front post down to the guard's front.
    "handle_rear": ([(323, 129), (323, 90), (329, 81), (352, 81), (352, 104), (348, 108), (348, 129)],
                    [(0, 0.009)], 0.0015),
    "handle_bar": ([(348, 86), (502, 86), (502, 103), (348, 104)], [(0, 0.0028)], 0.001),
    "handle_front": ([(499, 86), (501, 81), (515, 81), (516, 198), (511, 216), (503, 216), (501, 200), (501, 104),
                      (499, 104)], [(0, 0.009)], 0.0015),
    # The front lower body round the barrel under the handguard: the trigger's rod to the front grip runs in it.
    "front": ([(345, 153), (500, 153), (505, 158), (505, 197), (500, 203), (345, 203)], [(0, 0.0175)], 0.003),
    # The AK grip: raked back down to its foot.
    "grip": ([(380, 203), (445, 203), (445, 226), (437, 240), (426, 268), (415, 300), (410, 318), (400, 325),
              (372, 325), (358, 320), (356, 310), (365, 280), (373, 250), (378, 225)], [(0, 0.0155)], 0.005),
    # The thin guard from the grip's front round the trigger to the front post.
    "guard": ([(445, 203), (449, 229), (457, 237), (502, 237), (508, 230), (508, 203), (503, 203), (503, 227),
               (498, 232), (461, 232), (454, 227), (450, 203)], [(0, 0.0045)], 0.0012),
    "trigger": ([(456, 203), (462, 203), (467, 212), (475, 225), (474, 231), (467, 224), (459, 212)],
                [(0, 0.003)], 0.001),
    # The sling loop under the butt's front.
    "sling": ([(56, 220), (63, 220), (77, 262), (72, 268), (62, 268), (58, 262), (64, 262), (68, 263), (70, 259)],
              [(0, 0.002)], 0.0008),
    # The muzzle grip (photos 07, 08 x 1.088): the housing over the barrel's end, a hook down at its nose; the grip.
    "grip_housing": ([(537, 163), (661, 163), (667, 170), (667, 215), (661, 221), (652, 221), (648, 212), (648, 199),
                      (537, 199)], [(0, 0.016)], 0.003),
    "fore_grip": ([(582, 199), (627, 199), (626, 295), (621, 302), (588, 302), (583, 295)], [(0, 0.0155)], 0.005),
}


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
        print('\t\t\t\t\t"width": [%s], "chamfer": %g},' % (width, chamfer))
    v = lambda z, y: "Vector2(%g, %g)" % (round(z, 4), round(y, 4))
    print('\t"groza": {\n\t\t"profiles": {')
    for name, (points, widths, chamfer) in PROFILES.items():
        emit(name, [v(*P(*p)) for p in points],
             ", ".join("Vector2(%g, %g)" % (round(Z(px), 4), hw) for px, hw in widths), chamfer)
    print('\t\t},\n\t\t"sections": {},\n\t},')
    sys.exit()

parts = []
node_pos = {".": (0.0, 0.0, 0.0)}


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def pbox(name, x0, x1, px0, px1, py0, py1, mat, rot_x=0.0, parent="."):
    """A box over the photo's pixels px0..px1 (along the gun) and py0..py1, x0..x1 across."""
    box(name, x0, x1, Y(py0), Y(py1), Z(px0), Z(px1), mat, rot_x=rot_x, parent=parent)


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


def mesh(name, key, mat, parent=".", x=0.0, z=0.0, y=0.0):
    """A mesh built in place (make_parts.gd: prefab space), or one built round its own origin put at (x, y, z)."""
    parts.append((name, parent, "ext_mesh", key, (x, y, z), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0), meta=None):
    parts.append((name, parent, "node", meta, pos, 0.0, None))
    o = node_pos[parent]
    node_pos[name if parent == "." else parent + "/" + name] = (o[0] + pos[0], o[1] + pos[1], o[2] + pos[2])


def both(x0, x1):
    return (("L", x0, x1), ("R", -x1, -x0))


def slant(name, x0, x1, a, b, thick, mat, parent="."):
    """A bar across x0..x1 from photo pixel a to b (a lever on the side), `thick` px deep."""
    (za, ya), (zb, yb) = P(*a), P(*b)
    length = math.hypot(zb - za, yb - ya)
    angle = -math.degrees(math.atan2(yb - ya, zb - za))  # rot_x > 0 takes +z down
    cy, cz = (ya + yb) / 2, (za + zb) / 2
    h = thick * K / 2
    box(name, x0, x1, cy - h, cy + h, cz - length / 2, cz + length / 2, mat, rot_x=angle, parent=parent)


# --- the receiver in its shell, the butt plate (three slots on the right, as the photo; a pad), the sling loop.
mesh("Body", "body", "paint")
mesh("Butt", "butt", "paint")
mesh("SlingLoop", "sling", "steel", x=-0.012)
for i, (py0, py1) in enumerate(((154, 170), (180, 196), (206, 222))):
    pbox("ButtSlot%d" % i, -0.0222, -0.0226, 23, 29, py0, py1, "steel_dark")
pbox("ButtPad", -0.02, 0.02, 20, 21, 140, 262, "steel_dark")
# The top: the dust cover's edge along the receiver, its rear catch; the selector on the right, its long lever forward
# to the cheek (photo 02: from the pivot by the butt up to the receiver's front), the pins.
pbox("CoverEdge", -0.0167, 0.0167, 55, 278, 148, 151, "steel_dark")
pbox("CoverCatch", -0.008, 0.008, 48, 58, 135, 139, "black")
disc("SelectorPivot", 0.0062, -0.0165, -0.0195, Y(189), Z(110), "steel")
slant("SelectorLever", -0.0168, -0.0182, (110, 192), (222, 160), 5, "steel")
pbox("SelectorTip", -0.0168, -0.0195, 216, 228, 155, 163, "steel")
for side, x0, x1 in both(0.0165, 0.0178):
    for name, px, py in (("PinRear", 66, 180), ("PinStock", 70, 195), ("PinMid", 191, 192), ("PinWell", 315, 193),
                         ("PinFront", 333, 166)):
        disc(name + side, 0.0028, x0, x1, Y(py), Z(px), "steel")
pbox("ReleasePlate", -0.0165, -0.0178, 52, 82, 185, 200, "steel")  # the takedown latch by the butt (photo 02)
# The magazine catch and the trigger's rear behind the well (the AK's group sits back here; its rod runs forward).
pbox("MagCatch", -0.007, 0.007, 183, 200, 210, 245, "black")
pbox("CatchLever", -0.003, 0.003, 191, 196, 245, 256, "steel")
# The AK's ejection port by the cheek, the carrier in it.
pbox("EjectionPort", -0.0165, -0.0172, 150, 215, 152, 166, "steel_dark")
node("Bolt", ".", meta={"travel": 0.05})
pbox("Carrier", -0.0163, -0.0169, 155, 214, 153, 165, "steel_bright", parent="Bolt")
pbox("CarrierKey", -0.0166, -0.0172, 170, 184, 155, 160, "steel_dark", parent="Bolt")
# The charging handle forward on the right, out of the receiver's top over the well, slanting up and back.
HANDLE = (-0.012, Y(132), Z(318))
node("Handle", ".", HANDLE)
slant("Stem", -0.006, -0.018, (325, 132), (316, 120), 5, "steel", parent="Handle")
pbox("Knob", -0.007, -0.019, 309, 320, 113, 122, "steel", parent="Handle")
# The front of the receiver: the frame's posts, the front lower body, the handguard on the gas tube between them.
mesh("Front", "front", "paint")
pbox("FrontPanel", -0.0175, -0.0180, 352, 498, 160, 196, "paint")   # the raised panel on each side (photo 02)
pbox("FrontPanelL", 0.0175, 0.0180, 352, 498, 160, 196, "paint")
disc("FrontScrew", 0.0025, -0.0175, -0.0185, Y(190), Z(468), "steel")
mesh("HandleRear", "handle_rear", "paint")
mesh("HandleFront", "handle_front", "paint")
for side, x in (("L", 0.0058), ("R", -0.0058)):
    mesh("HandleBar" + side, "handle_bar", "paint", x=x)
pbox("BarFloor", -0.0031, 0.0031, 352, 500, 96, 103, "paint")  # the channel's floor under the line of sight
for side, x0, x1 in both(0.009, 0.0102):
    disc("FrameScrew" + side, 0.0035, x0, x1, Y(95), Z(338), "steel")
    disc("FrontPostScrew" + side, 0.003, x0, x1, Y(126), Z(508), "steel")
tube("GasTube", 0.0085, Z(352), Z(500), Y(140), "black")
tube("HandguardRingRear", 0.0145, Z(352), Z(359), Y(140), "black")
tube("Handguard", 0.0128, Z(359), Z(482), Y(140), "wood", segments=14)
tube("HandguardRingFront", 0.0145, Z(482), Z(489), Y(140), "black")
# The rear sight in the rear post's top: the leaf's two ears with the notch, the range drum on the right (photo 09);
# the front sight in the front post's top: the post between its ears.
notch = 0.0018
for side, x0, x1 in both(notch, 0.0075):
    box("RearEar" + side, x0, x1, Y(81), SIGHT_Y, Z(330), Z(335), "black")
disc("RangeDrum", 0.0068, -0.009, -0.0125, Y(92), Z(342), "black")
disc("RangeDrumHub", 0.003, -0.0125, -0.0133, Y(92), Z(342), "steel")
# "ScopeCut": what the eye sees of it through the PO's window is cut (WeaponView._cut_window).
node("ScopeCut")
for side, x0, x1 in both(0.0042, 0.0072):
    box("FrontEar" + side, x0, x1, Y(81), Y(71), Z(503), Z(513), "black", parent="ScopeCut")
box("FrontPost", -0.0012, 0.0012, Y(81), SIGHT_Y, Z(507), Z(510), "black", parent="ScopeCut")
# The grip, the guard, the trigger.
mesh("Grip", "grip", "grip")
mesh("Guard", "guard", "black")
mesh("Trigger", "trigger", "black")
tube("Barrel", 0.0085, Z(345), Z(FRAME_FRONT), BORE_Y, "black")

# --- the muzzle: the short barrel's stub with its compensator; the suppressor (the stub under its collar); the muzzle
# grip over the stub.
node("Muzzle")
for state in ("Comp", "Can", "Grip"):
    node(state, "Muzzle")
tube("Stub", STUB[2], Z(STUB[0]), Z(STUB[1]), BORE_Y, "black", parent="Muzzle/Comp")
tube("Sleeve", SLEEVE[2], Z(SLEEVE[0]), Z(SLEEVE[1]), BORE_Y, "black", parent="Muzzle/Comp")
tube("Comp", COMP[2], Z(COMP[0]), Z(COMP[1]), BORE_Y, "black", parent="Muzzle/Comp")
for i in range(4):  # the compensator's grooves (photo 09)
    z = Z(COMP[0]) + 0.003 + i * 0.004
    tube("Groove%d" % i, COMP[2] + 0.0006, z, z + 0.0018, BORE_Y, "black", parent="Muzzle/Comp", segments=12)
for side, x0, x1 in both(COMP[2] - 0.0005, COMP[2] + 0.0004):
    box("Port" + side, x0, x1, BORE_Y - 0.002, BORE_Y + 0.002, Z(COMP[0]) + 0.004, Z(COMP[1]) - 0.003, "steel_dark",
        parent="Muzzle/Comp")
tube("Crown", 0.004, Z(COMP[1]), Z(COMP[1]) + 0.0008, BORE_Y, "steel_dark", parent="Muzzle/Comp")
for i, (px0, px1, r) in enumerate(CAN):
    tube(("Collar", "Front", "Body")[i], r, Z(px0), Z(px1), BORE_Y, "can", parent="Muzzle/Can", segments=20)
tube("EndCap", CAN[2][2] - 0.003, Z(CAN[2][1]), Z(CAN[2][1]) + 0.002, BORE_Y, "can", parent="Muzzle/Can", segments=20)
tube("CanBore", 0.0045, Z(CAN[2][1]) + 0.002, Z(CAN[2][1]) + 0.0025, BORE_Y, "steel_dark", parent="Muzzle/Can")
tube("Stub", STUB[2], Z(STUB[0]), Z(537), BORE_Y, "black", parent="Muzzle/Grip")
mesh("Housing", "grip_housing", "polymer", parent="Muzzle/Grip")
mesh("ForeGrip", "fore_grip", "polymer", parent="Muzzle/Grip")
for i in range(5):  # the grip's ribs low down (photo 08)
    py = 262 + i * 7
    pbox("Rib%d" % i, -0.0162, 0.0162, 583, 626, py, py + 3, "polymer", parent="Muzzle/Grip")
tube("GripBore", 0.0045, Z(667), Z(667) + 0.0005, BORE_Y, "steel_dark", parent="Muzzle/Grip")

# --- "Mags": the AK's curved magazines (their origin: the top's middle), in the well behind the grip.
WELL = (0.0, Y(207), Z(249))
node("Mags")
for name, key in (("Groza_Mag_30", "mag"), ("Groza_Mag_40", "mag_rpk40")):
    node(name, "Mags", WELL)
    mesh("Body", key, "mag_steel", parent="Mags/" + name, x=WELL[0], y=WELL[1], z=WELL[2])

f = lambda v: "%g" % round(v, 5)
res = []
for key, spec in MATERIALS.items():
    albedo, metal, rough = spec[:3]
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Groza" type="Node3D"]\n']
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
        extra = "".join("metadata/%s = %s\n" % (k, f(v)) for k, v in (params or {}).items())
        nodes.append('\n[node name="%s" type="Node3D" parent="%s"]\ntransform = %s\n%s' % (name, parent, xform, extra))
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
        segments = params[3] if kind == "cyl" else 12
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(top), f(params[0]), f(params[1]), segments))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/groza_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    ext += "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/%s_mesh.tres" id="%s"]\n' % (path, key)
                   for key, path in AK_MESHES.items())
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
v3 = lambda x, y, z: "Vector3(%s, %s, %s)" % (round(x, 4), round(y, 4), round(z, 4))
print("muzzle comp", v3(0, BORE_Y, Z(COMP[1])), "can", v3(0, BORE_Y, Z(CAN[2][1]) + 0.002), "grip", v3(0, BORE_Y, Z(667)))
print("irons rear", v3(0, SIGHT_Y, Z(332.5)), "front", v3(0, SIGHT_Y, Z(508.5)), "eye relief", EYE_IRON)
print("right hand", v3(0, Y(262), Z(405)), "left hand", v3(0.02, Y(185), Z(470)), "fore grip", v3(0, Y(250), Z(604)))
print("ejection", v3(-0.017, Y(159), Z(185)), "handle", v3(*HANDLE), "well", v3(*WELL))
print("frame bar top", round(Y(86), 4), "handle rear z", round(Z(323), 4), "front post z", round(Z(515), 4))
