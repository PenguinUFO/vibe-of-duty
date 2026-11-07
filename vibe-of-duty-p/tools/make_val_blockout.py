"""Generates prefabs/weapons/val_blockout.tscn: a blockout of the AS Val, 9x39, with the VSS Vintorez's wooden stock and
the SR-3 Vikhr's short barrel as its variants.

Run from the repo:  python vibe-of-duty-p/tools/make_val_blockout.py   (overwrites the scene)
              or:  python vibe-of-duty-p/tools/make_val_blockout.py --parts   (prints the profiles for
                   tools/make_parts.gd; paste them there and run it - the scene uses its meshes)

Docs/LOADOUT.md, "АС ВАЛ". Traced off the owner's photo Docs/val/02_val_stock_pair.webp (the upper gun, from the right on
white): 0.47 mm a pixel - 875 mm over 1855 px. The wooden stock off 08_vss_pso (the same scale; its pixels here are
the photo's less (5, 140): the guard's hole on the Val's). The short barrel off 07_vikhr_ground (0.63 mm a pixel), put
on the Val's receiver: its handguard, its front sight, its rear sight on the receiver, its threaded muzzle.
- "Barrel": Can (the Val's handguard, suppressor, sights) / Short (the Vikhr's).
- "Stock": Wire (the folding wire stock, the Val's grip) / Wood (the Vintorez's thumbhole stock, its own grip).
- "Mags": Val_Mag_20 / Val_Mag_10 / Val_Mag_30.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin sits
at the top of the guard's hole by the trigger, metres; prefab +x is the shooter's left (the photo shows the right).
"Handle": the charging handle in the port on the right, riding the bolt; "Bolt": the carrier in the port.
Key points used by WeaponDB (prefab space): printed by this script.
"""
import math
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "val_blockout.tscn")

MATERIALS = {
    "paint": ((0.15, 0.15, 0.16), 0.4, 0.55),         # albedo, metallic, roughness: the stamped receiver
    "black": ((0.08, 0.08, 0.09), 0.55, 0.45),        # the stock's tubes, sights, guard
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),        # pins, levers
    "steel_dark": ((0.025, 0.025, 0.03), 0.5, 0.5),   # ports, slots, grooves
    "steel_bright": ((0.36, 0.36, 0.38), 0.7, 0.35),  # the bolt carrier in the port
    "polymer": ((0.13, 0.115, 0.11), 0.0, 0.8),       # the rough brown-grey handguard (photo 02)
    "grip": ((0.13, 0.1, 0.09), 0.0, 0.7),            # the grip
    "mag": ((0.12, 0.085, 0.075), 0.0, 0.55),         # the plum polymer magazine
    "can": ((0.09, 0.09, 0.095), 0.4, 0.6),           # the suppressor
    "wood": ((0.62, 0.36, 0.14), 0.0, 0.6),           # the Vintorez's laminated stock (photo 08)
    "rubber": ((0.05, 0.05, 0.05), 0.0, 0.85),        # its perforated butt pad
}
K = 0.00047           # m a pixel of photo 02
PX0 = (815, 205)      # the photo's pixel at the origin (the guard's hole, its top, at the trigger)


def P(x, y):
    """A photo pixel -> (z, y) in metres (the muzzle on the photo's right: +Z)."""
    return ((x - PX0[0]) * K, (PX0[1] - y) * K)


def Z(x):
    return P(x, 0)[0]


def Y(y):
    return P(0, y)[1]


BORE_Y = Y(168)       # the can's axis on photo 02
SIGHT_Y = Y(99)       # the Val's irons: the rear leaf's ears' top, the front post's tip
SHORT_SIGHT_PY = 69   # the Vikhr's: 19 mm over the receiver (photo 07)
REAR_PX, FRONT_PX = 1262, 1878
SHORT_REAR_PX, SHORT_FRONT_PX = 970, 1304
EYE_Z = -0.16         # the eye over the stock, behind the receiver
MAG_REAR = [(922, 262), (930, 380), (945, 520)]   # the magazine's sides top to bottom, 20 rounds; the top in the well
MAG_FRONT = [(1047, 232), (1068, 400), (1085, 497)]
MAG_LENGTH = {"20": 1.0, "10": 0.72, "30": 1.4}   # by the 20's (photo 08: the 10; the 30 by the rounds)


def along(line, t):
    """The point `t` of the way down a magazine's side; past 1 it goes on along the last stretch."""
    (x0, y0), (x1, y1), (x2, y2) = line
    k = (y1 - y0) / (y2 - y0)
    if t <= k:
        return (x0 + (x1 - x0) * t / k, y0 + (y1 - y0) * t / k)
    return (x1 + (x2 - x1) * (t - k) / (1 - k), y1 + (y2 - y1) * (t - k) / (1 - k))


def mag_outline(t):
    rear, front = along(MAG_REAR, t), along(MAG_FRONT, t)
    points = [MAG_REAR[0], MAG_FRONT[0], MAG_FRONT[1]]
    points += [front, (front[0] + 2, front[1] + 12), (rear[0] + 2, rear[1] + 12), rear, MAG_REAR[1]]
    return points


# Side profiles for tools/make_parts.gd, photo pixels round the outline: (points, half width(s) [(px, hw)], chamfer).
PROFILES = {
    # The receiver: the rounded cover, the front to the handguard, the well's slant, the guard's front post.
    "body": ([(662, 125), (672, 113), (692, 108), (1045, 112), (1045, 243), (920, 273), (907, 286), (889, 286),
              (885, 208), (662, 205)], [(0, 0.016)], 0.003),
    # The Val's handguard: square, deep at the back, the bottom rising to the barrel.
    "handguard": ([(1045, 112), (1236, 112), (1240, 118), (1240, 195), (1232, 205), (1045, 243)],
                  [(0, 0.0195)], 0.003),
    # The Vikhr's: long and low, a step down at the back, the nose round the barrel.
    "handguard_short": ([(1045, 112), (1318, 112), (1330, 122), (1332, 190), (1318, 205), (1270, 196), (1085, 196),
                         (1068, 232), (1045, 243)], [(0, 0.0195)], 0.005),
    "short_front": ([(1285, 112), (1298, 75), (1312, 75), (1322, 112)], [(0, 0.008)], 0.0015),
    "short_rear": ([(930, 108), (962, SHORT_SIGHT_PY), (978, SHORT_SIGHT_PY), (1005, 108)], [(0, 0.0028)], 0.001),
    "grip": ([(662, 205), (772, 205), (777, 282), (762, 285), (748, 340), (738, 400), (741, 425), (716, 436),
              (646, 421), (632, 400), (640, 358), (651, 313), (671, 265), (662, 235)], [(0, 0.0155)], 0.005),
    "guard": ([(772, 280), (905, 280), (905, 286), (772, 286)], [(0, 0.0045)], 0.0012),
    "trigger": ([(808, 205), (818, 205), (815, 240), (825, 262), (836, 276), (822, 270), (808, 250)],
                [(0, 0.003)], 0.001),
    # The wire stock's butt and the plate across its tubes.
    "wire_butt": ([(82, 200), (120, 200), (108, 392), (70, 392)], [(0, 0.012)], 0.002),
    "wire_plate": ([(315, 190), (365, 190), (380, 285), (335, 298)], [(0, 0.0035)], 0.001),
    # The wooden stock in five, round its two holes (a profile has none); the posts a bit thinner, into the beams.
    "wood_top": ([(87, 185), (495, 182), (525, 172), (565, 158), (635, 155), (662, 155), (662, 205), (640, 222),
                  (620, 241), (87, 241)], [(0, 0.0185)], 0.004),
    "wood_bottom": ([(80, 431), (595, 415), (600, 385), (200, 382), (80, 382)], [(0, 0.0185)], 0.004),
    "wood_rear": ([(87, 236), (175, 236), (157, 275), (157, 300), (185, 375), (200, 386), (80, 386)],
                  [(0, 0.018)], 0.002),
    "wood_mid": ([(335, 236), (477, 236), (465, 255), (445, 355), (470, 386), (330, 386), (345, 380), (360, 340),
                  (370, 275)], [(0, 0.018)], 0.002),
    "wood_grip": ([(640, 220), (730, 220), (770, 287), (745, 315), (730, 410), (737, 427), (725, 435), (617, 435),
                   (595, 415), (600, 380), (630, 370), (645, 290), (642, 265), (616, 236)], [(0, 0.0185)], 0.004),
    "wood_tang": ([(640, 205), (775, 205), (777, 284), (768, 284), (730, 220), (640, 220)], [(0, 0.0155)], 0.002),
    "wood_pad": ([(40, 190), (45, 185), (87, 185), (80, 431), (45, 430), (40, 420)], [(0, 0.02)], 0.004),
}
for rounds, t in MAG_LENGTH.items():
    PROFILES["mag" + rounds] = (mag_outline(t), [(0, 0.0145)], 0.003)
MESHES = list(PROFILES)


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
    print('\t"val": {\n\t\t"profiles": {')
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


def rod(name, points, radius, mat, parent="."):
    """Tubes through these photo pixels."""
    for i in range(len(points) - 1):
        (za, ya), (zb, yb) = P(*points[i]), P(*points[i + 1])
        length = math.hypot(zb - za, yb - ya) + radius
        theta = math.degrees(math.atan2(zb - za, yb - ya))  # a cylinder's axis: (0, cos, sin)
        parts.append(("%s%d" % (name, i), parent, "cyl", (radius, length, radius, 10),
                      (0.0, (ya + yb) / 2, (za + zb) / 2), theta, mat))


# --- the receiver: the cover's seam, the port with the carrier, the handle, the safety's long lever, the pins.
mesh("Body", "body", "paint")
for side, x0, x1 in both(0.0158, 0.0164):
    pbox("CoverSeam" + side, x0, x1, 665, 900, 160, 163, "steel_dark")
    pbox("LowerSeam" + side, x0, x1, 662, 885, 203, 205, "steel_dark")
pbox("Port", -0.0158, -0.0166, 905, 1012, 133, 162, "steel_dark")
node("Bolt", ".", meta={"travel": 0.05})
pbox("Carrier", -0.0156, -0.0168, 912, 1008, 137, 158, "steel_bright", parent="Bolt")
HANDLE = (-0.016, Y(160), Z(1030))
node("Handle", ".", HANDLE)
pbox("Stem", -0.0155, -0.022, 1022, 1040, 155, 165, "steel", parent="Handle")
pbox("Knob", -0.021, -0.027, 1020, 1042, 147, 172, "steel", parent="Handle")
disc("SafetyPivot", 0.0062, -0.0158, -0.0192, Y(187), Z(770), "steel")
slant("SafetyLever", -0.0158, -0.0178, (770, 187), (900, 160), 9, "steel")
slant("SafetyFinger", -0.0158, -0.0178, (880, 164), (905, 156), 7, "steel")
for side, x0, x1 in both(0.0158, 0.0172):
    for name, px, py in (("PinRear", 680, 190), ("PinMid", 870, 225), ("PinWell", 905, 262), ("PinFront", 1032, 195)):
        disc(name + side, 0.0028, x0, x1, Y(py), Z(px), "steel")
for i, px in enumerate((760, 830, 985)):  # the cover's stamped ribs across its top
    pbox("CoverRib%d" % i, -0.0135, 0.0135, px, px + 6, 106, 110, "paint")
mesh("Guard", "guard", "black")
mesh("Trigger", "trigger", "black")
slant("MagCatch", -0.003, 0.003, (893, 286), (884, 306), 5, "steel")

# --- "Barrel": the Val's handguard, suppressor and irons; the Vikhr's short front.
node("Barrel")
for state in ("Can", "Short"):
    node(state, "Barrel")
C = "Barrel/Can"
mesh("Handguard", "handguard", "polymer", parent=C)
tube("Ring", 0.0145, Z(1240), Z(1258), BORE_Y, "black", parent=C, segments=20)
tube("Tube", 0.0168, Z(1258), Z(1488), BORE_Y, "can", parent=C, segments=20)
tube("Collar", 0.0176, Z(1488), Z(1500), BORE_Y, "black", parent=C, segments=20)
tube("Body", 0.0185, Z(1500), Z(1825), BORE_Y, "can", parent=C, segments=20)
tube("Front", 0.0168, Z(1825), Z(1925), BORE_Y, "black", parent=C, segments=20)
tube("EndCap", 0.0145, Z(1925), Z(1925) + 0.002, BORE_Y, "black", parent=C, segments=20)
tube("Bore", 0.0055, Z(1925) + 0.002, Z(1925) + 0.0025, BORE_Y, "steel_dark", parent=C)
# The rear sight on the can's back: its base, the sector leaf running forward, the notch in the knobbed slider at its
# back - the highest point (photo 02), the knobs out to the sides, clear of the line of sight.
pbox("SightBase", -0.0075, 0.0075, 1245, 1375, 125, 133, "black", parent=C)
pbox("SliderPost", -0.006, 0.006, 1250, 1275, 108, 126, "black", parent=C)
slant("Leaf", -0.0065, 0.0065, (1262, 112), (1356, 111), 6, "black", parent=C)
pbox("LeafFoot", -0.0065, 0.0065, 1340, 1362, 113, 126, "black", parent=C)
notch = 0.0018
for side, x0, x1 in both(notch, 0.0075):
    box("RearEar" + side, x0, x1, Y(112), SIGHT_Y, Z(REAR_PX - 4), Z(REAR_PX + 4), "black", parent=C)
for side, x0, x1 in both(0.0075, 0.0095):
    disc("SliderKnob" + side, 0.0055, x0, x1, Y(107), Z(REAR_PX), "steel", parent=C)
# The front sight on the can's nose: the base, the post between its ears.
pbox("FrontBase", -0.0075, 0.0075, 1845, 1892, 125, 133, "black", parent=C)
for side, x0, x1 in both(0.0042, 0.0072):
    box("FrontEar" + side, x0, x1, Y(127), Y(96), Z(FRONT_PX - 8), Z(FRONT_PX + 8), "black", parent=C)
box("FrontPost", -0.0012, 0.0012, Y(127), SIGHT_Y, Z(FRONT_PX - 2), Z(FRONT_PX + 2), "black", parent=C)

S = "Barrel/Short"
mesh("Handguard", "handguard_short", "polymer", parent=S)
for i in range(14):  # the row of finger slots
    px = 1185 + i * 9
    for side, x0, x1 in both(0.0193, 0.0198):
        pbox("Slot%d%s" % (i, side), x0, x1, px, px + 4, 168, 188, "steel_dark", parent=S)
tube("Nose", 0.0125, Z(1332), Z(1350), BORE_Y, "black", parent=S)
tube("Thread", 0.0095, Z(1350), Z(1406), BORE_Y, "black", parent=S)
tube("Bore", 0.0045, Z(1406), Z(1406) + 0.0005, BORE_Y, "steel_dark", parent=S)
mesh("FrontBase", "short_front", "black", parent=S)
for side, x0, x1 in both(0.0042, 0.0072):
    box("FrontEar" + side, x0, x1, Y(76), Y(SHORT_SIGHT_PY - 3), Z(SHORT_FRONT_PX - 8), Z(SHORT_FRONT_PX + 8), "black",
        parent=S)
box("FrontPost", -0.0012, 0.0012, Y(76), Y(SHORT_SIGHT_PY), Z(SHORT_FRONT_PX - 2), Z(SHORT_FRONT_PX + 2), "black",
    parent=S)
for side, x in (("L", 0.0046), ("R", -0.0046)):  # the rear sight on the receiver: two plates, the notch between
    mesh("RearEar" + side, "short_rear", "black", parent=S, x=x)

# --- "Stock": the wire stock with the Val's grip; the Vintorez's wooden one, its grip in it.
node("Stock")
for state in ("Wire", "Wood"):
    node(state, "Stock")
W = "Stock/Wire"
mesh("Grip", "grip", "grip", parent=W)
pbox("Hinge", -0.013, 0.013, 625, 662, 155, 215, "black", parent=W)
disc("Spring", 0.0075, -0.012, 0.012, Y(190), Z(610), "steel", parent=W)
rod("TopTube", [(625, 178), (540, 185), (118, 200)], 0.0042, "black", parent=W)
rod("LowerTube", [(625, 222), (500, 228), (370, 290), (185, 365), (105, 372)], 0.0042, "black", parent=W)
rod("Loop", [(545, 170), (560, 158), (610, 155), (620, 165), (600, 178)], 0.0016, "steel", parent=W)
mesh("Butt", "wire_butt", "black", parent=W)
mesh("Plate", "wire_plate", "black", parent=W)
disc("PlateLatch", 0.004, -0.0065, 0.0065, Y(248), Z(350), "steel", parent=W)
D = "Stock/Wood"
for name in ("top", "bottom", "rear", "mid", "grip"):
    mesh("Wood" + name.capitalize(), "wood_" + name, "wood", parent=D)
mesh("Tang", "wood_tang", "black", parent=D)
mesh("Pad", "wood_pad", "rubber", parent=D)
for side, x0, x1 in both(0.0183, 0.0193):
    disc("PinTop" + side, 0.0028, x0, x1, Y(170), Z(612), "steel", parent=D)
    disc("PinGrip" + side, 0.0028, x0, x1, Y(250), Z(690), "steel", parent=D)

# --- "Mags": the straight polymer magazines, their grooves in two staggered rows on each side.
WELL = (0.0, Y(258), Z(985))
node("Mags")
for rounds, t in MAG_LENGTH.items():
    name = "Val_Mag_" + rounds
    node(name, "Mags", WELL)
    parent = "Mags/" + name
    mesh("Body", "mag" + rounds, "mag", parent=parent)
    n = int(t * 11)
    for i in range(n):
        at = (i + 1.5) / (n + 2) * t + 0.08
        rear, front = along(MAG_REAR, at), along(MAG_FRONT, at)
        a = 0.14 if i % 2 else 0.3
        b = 0.68 if i % 2 else 0.86
        pa = (rear[0] + (front[0] - rear[0]) * a, rear[1] + (front[1] - rear[1]) * a)
        pb = (rear[0] + (front[0] - rear[0]) * b, rear[1] + (front[1] - rear[1]) * b)
        for side, x0, x1 in both(0.0143, 0.0149):
            slant("Groove%d%s" % (i, side), x0, x1, pa, pb, 3, "steel_dark", parent=parent)

f = lambda v: "%g" % round(v, 5)
res = []
for key, spec in MATERIALS.items():
    albedo, metal, rough = spec[:3]
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Val" type="Node3D"]\n']
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
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/val_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
v3 = lambda x, y, z: "Vector3(%s, %s, %s)" % (round(x, 4), round(y, 4), round(z, 4))
print("muzzle can", v3(0, BORE_Y, Z(1925) + 0.002), "short", v3(0, BORE_Y, Z(1406)))
print("irons rear", v3(0, SIGHT_Y, Z(REAR_PX)), "front", v3(0, SIGHT_Y, Z(FRONT_PX)), "eye relief", round(Z(REAR_PX) - EYE_Z, 4))
print("short irons rear", v3(0, Y(SHORT_SIGHT_PY), Z(SHORT_REAR_PX)), "front", v3(0, Y(SHORT_SIGHT_PY), Z(SHORT_FRONT_PX)),
      "eye relief", round(Z(SHORT_REAR_PX) - EYE_Z, 4))
print("right hand", v3(0, Y(320), Z(700)), "wood", v3(0, Y(330), Z(680)), "left hand", v3(0, Y(232), Z(1150)),
      "short", v3(0, Y(205), Z(1200)))
print("ejection", v3(-0.017, Y(148), Z(955)), "handle", v3(*HANDLE), "well", v3(*WELL), "cover top", round(Y(108), 4))
