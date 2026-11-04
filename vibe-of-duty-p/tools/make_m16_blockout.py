"""Generates prefabs/weapons/m16_blockout.tscn: a blockout of the M16A1 (Colt Model 603), 5.56x45, and its carbine
(Colt Model 653) as a barrel module.

Run from the repo:  python vibe-of-duty-p/tools/make_m16_blockout.py   (overwrites the scene)
              or:  python vibe-of-duty-p/tools/make_m16_blockout.py --parts   (prints the profiles for
                   tools/make_parts.gd; paste them there and run it - the scene uses its meshes)

Docs/LOADOUT.md, "M16A1". Traced off the owner's photo Docs/m16/01_603.png (a 603 from the right on white, a 20-round
magazine in): the gun 845 px for its 1006.6 mm (39.63", the birdcage on). The 653's parts after 05..08_653 (scaled by
its receiver), the HEL-E4A after 11..14_hel, the Colt 3x20 after 09..10_colt3x20 (its model is SightModels' "colt").
All black: the anodised receivers, the polymer furniture, the parkerised barrel.
- "Barrel": B508 (the 603's 20": the triangular handguard, the rifle's front sight base) / B368 (the 653's 14.5": the
  round ribbed handguard, the front sight base 140 mm further back - the whole front shorter by the 5.5"). Each has
  its "Muzzle" (Hider - the birdcage / Can - the HEL-E4A over the barrel's end, its collar ahead of the front sight)
  and its front sight "Front/ScopeCut" (in the Colt 3x20's view it stood under the reticle: WeaponView cuts what the
  eye sees of it through the scope's window).
- "Stock": A1 (fixed) / CAR (the 653's telescoping one on its tube; "Stock/CAR/Slide": Out / In, 75 mm).
- "Mags": M16_Mag_30 - the 30-round USGI (owner, 2026-11-02: the only magazine), curved at its foot.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin sits
at the top of the guard's hole by the trigger, metres; prefab +x is the shooter's left (the photo shows the right).
"Handle": the T charging handle at the upper's back, pulled by the hand (it does not ride the bolt); "Bolt": the
carrier in the ejection port, its cover open. Key points used by WeaponDB (prefab space): printed by this script.
"""
import math
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "m16_blockout.tscn")

MATERIALS = {
    # Not all one black (as the Mk 14's: it read as a silhouette): the anodised receivers a dark grey (photo 07), the
    # polymer and the parkerised steel darker.
    "alu": ((0.16, 0.16, 0.17), 0.4, 0.5),            # albedo, metallic, roughness: the anodised receivers
    "polymer": ((0.1, 0.1, 0.105), 0.0, 0.75),        # stock, grip, handguards
    "black": ((0.1, 0.1, 0.11), 0.55, 0.45),          # barrel, front sight base, hider, can, sights
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),        # pins, screws
    "steel_dark": ((0.025, 0.025, 0.03), 0.5, 0.5),   # ports, slots, holes
    "steel_bright": ((0.36, 0.36, 0.38), 0.7, 0.35),  # the bolt carrier in the port
    "tube": ((0.08, 0.08, 0.085), 0.5, 0.3),          # the CAR stock's glossy vinyl-coated tube and sleeve
    "rubber": ((0.04, 0.04, 0.04), 0.0, 0.9),
    "mag": ((0.2, 0.2, 0.21), 0.5, 0.55),          # the aluminium USGI magazine
}
MESHES = ["stock", "lower", "upper", "handle_rear", "handle_bar", "handle_front", "grip", "guard", "trigger", "handguard", "fsb_leg", "car_stock",
          "mag_30", "mag_30_base"]
K = 1.0066 / 845      # m a pixel: the photo's 845 px are the gun's 1006.6 mm
PX0 = (300, 296)      # the photo's pixel at the origin (the guard's hole, its top, at the trigger)


def P(x, y):
    """A photo pixel -> (z, y) in metres (the muzzle on the photo's right: +Z)."""
    return ((x - PX0[0]) * K, (PX0[1] - y) * K)


def Z(x):
    return P(x, 0)[0]


def Y(y):
    return P(0, y)[1]


BORE_Y = Y(250)
SIGHT_Y = BORE_Y + 0.0635   # the irons 2.5" over the bore
CUT = 0.14            # m: the 653 - 14.5" for 20": its front sight base, barrel and muzzle that much further back
HIDER = 825           # px: the birdcage's back (the barrel's end)
MUZZLE = 872          # px: its front
CAN_BACK = 0.012      # m: the HEL's collar from the front sight base's front
CAN = (0.026, 0.018, 0.255)  # m: the collar, the cone, the body
CAN_R = (0.0115, 0.019)      # m: the collar's radius, the body's
STOCK_SLIDE = 0.075   # m: the CAR stock in to out
EYE_IRON = 0.09       # m: the eye behind the rear aperture (the cheek on the comb)
SCOPE_Y = 0.142       # m: the Colt 3x20's axis (over the rear sight's ears on the handle)
SCOPE_BACK = -0.07    # m: its eyepiece
EYE_SCOPE = 0.04      # m: the eye behind the eyepiece

# Side profiles for tools/make_parts.gd, photo pixels round the outline: (points, half width(s) [(px, hw)], chamfer).
PROFILES = {
    # The A1 stock: straight on top, the bottom line rising to the receiver; the butt plate is a box.
    "stock": ([(232, 241), (40, 238), (33, 241), (30, 247), (30, 333), (33, 341), (40, 344), (60, 338), (100, 322),
               (150, 304), (200, 288), (215, 284), (232, 282)], [(232, 0.017), (30, 0.021)], 0.006),
    # The lower: the magazine well's flared mouth, the guard's hole's top, the rear down into the grip.
    "lower": ([(232, 256), (394, 256), (398, 260), (398, 268), (395, 300), (395, 307), (337, 307), (337, 297),
               (288, 297), (272, 294), (258, 292), (246, 288), (236, 282), (232, 275)], [(0, 0.0165)], 0.003),
    # The upper: the charging handle's step at its back, the barrel nut's shoulder in front.
    "upper": ([(232, 256), (232, 240), (236, 237), (258, 237), (258, 229), (395, 229), (400, 233), (400, 256)],
              [(0, 0.0155)], 0.003),
    # The carry handle over its window, in three (as one outline round the window it would not triangulate): the rear
    # post up to the rear sight's ears (boxes), the bar thinning forward - one each side of the sight channel along
    # its top (the line of sight runs in it: the bar's back stands over the line), the front post.
    "handle_rear": ([(258, 230), (263, 214), (267, 206), (293, 206), (287, 209), (284, 218), (283, 230)],
                    [(0, 0.0095)], 0.0015),
    "handle_bar": ([(285, 193), (388, 203), (390, 208), (285, 206)], [(0, 0.0032)], 0.001),
    "handle_front": ([(386, 203), (395, 207), (399, 215), (399, 230), (392, 230), (392, 208), (386, 208)], [(0, 0.0095)],
                     0.0015),
    "grip": ([(258, 292), (287, 297), (284, 306), (279, 321), (273, 332), (267, 343), (261, 353), (256, 363),
              (253, 374), (249, 378), (238, 377), (224, 374), (213, 368), (213, 363), (222, 350), (232, 334), (243, 317),
              (250, 304)], [(0, 0.0145)], 0.005),
    # The thin guard from the well's foot back to the grip.
    "guard": ([(338, 304), (338, 321), (297, 321), (289, 316), (285, 306), (290, 305), (295, 312), (299, 316),
               (333, 316), (333, 304)], [(0, 0.006)], 0.0015),
    "trigger": ([(300, 297), (306, 297), (309, 303), (309, 310), (306, 314), (303, 313), (305, 307), (302, 301)],
                [(0, 0.003)], 0.001),
    # The front sight base's rear leg, up from the gas block to the ears' bridge.
    "fsb_leg": ([(684, 250), (694, 250), (711, 212), (702, 210)], [(0, 0.006)], 0.002),
}


# The 603's handguard (photos 01, 04): in section a triangle, its corners rounded - the ridge on top, widening down to
# the round bottom; deep at the delta ring, tapering to the front sight's cap. No rails, no ribs. (back, front): the
# top and the bottom (photo 01's px), the half width, the corners' radius. Lofted by make_parts.gd ("sections").
HG_Z = (419, 687)
HG = ((229, 278, 0.027, 0.011), (230, 262, 0.021, 0.008))
HG_ARC = 6            # segments round each corner


def hg_section(top, bottom, hw, r):
    """The rounded triangle (x, y) counter-clockwise: an inner triangle grown by `r` - the outline its offset."""
    top, bottom = Y(top), Y(bottom)
    corners = [(0.0, top - r), (-(hw - r), bottom + r), (hw - r, bottom + r)]
    out = []
    for i, c in enumerate(corners):
        prev, nxt = corners[i - 1], corners[(i + 1) % 3]
        e0 = (c[0] - prev[0], c[1] - prev[1])
        e1 = (nxt[0] - c[0], nxt[1] - c[1])
        a0 = math.atan2(-e0[0], e0[1])  # the edges' outward normals (dy, -dx) as angles; the arc between them
        a1 = math.atan2(-e1[0], e1[1])
        while a1 < a0:
            a1 += 2 * math.pi
        for k in range(HG_ARC + 1):
            a = a0 + (a1 - a0) * k / HG_ARC
            out.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    return out


HG_BACK, HG_FRONT = hg_section(*HG[0]), hg_section(*HG[1])


def hg_x(z, y):
    """The handguard's half width at (z, y): its section there, cut by the line at y."""
    t = min(max((z - Z(HG_Z[0])) / (Z(HG_Z[1]) - Z(HG_Z[0])), 0.0), 1.0)
    ring = [(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t) for a, b in zip(HG_BACK, HG_FRONT)]
    xs = [0.0]
    for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
        if (y0 - y) * (y1 - y) <= 0.0 and y0 != y1:
            xs.append(abs(x0 + (x1 - x0) * (y - y0) / (y1 - y0)))
    return max(xs)


def hg_height(z):
    t = min(max((z - Z(HG_Z[0])) / (Z(HG_Z[1]) - Z(HG_Z[0])), 0.0), 1.0)
    return (Y(HG[0][1]) + (Y(HG[1][1]) - Y(HG[0][1])) * t, Y(HG[0][0]) + (Y(HG[1][0]) - Y(HG[0][0])) * t)


# The magazine: the 30-round USGI, straight from its top in the well to the mouth and a little below, then curving
# forward along an arc; 60 mm front to back, 22 mm thick. Profiles in metres (z, y). 150 mm below the mouth.
MAG_FRONT, MAG_BACK = Z(391), Z(340)
MAG_MOUTH, MAG_TOP = Y(306), Y(262)
MAG_R = 0.42          # m: the centre line's radius (~25 mm forward at the foot)
MAG_STRAIGHT = 0.03   # m below the mouth before it curves
MAG_HW = 0.011
MAG_DEPTH = 0.15
MAG_CENTRE = ((MAG_FRONT + MAG_BACK) / 2 + MAG_R, MAG_MOUTH - MAG_STRAIGHT)


def mag_at(s, r):
    """The point `s` m down the magazine (along its centre line) at radius `r` from the arc's centre: straight for
    MAG_STRAIGHT, then on the arc."""
    if s <= MAG_STRAIGHT:
        return (MAG_CENTRE[0] - r, MAG_MOUTH - s)
    phi = (s - MAG_STRAIGHT) / MAG_R
    return (MAG_CENTRE[0] - r * math.cos(phi), MAG_CENTRE[1] - r * math.sin(phi))


def mag_angle(s):
    return 0.0 if s <= MAG_STRAIGHT else (s - MAG_STRAIGHT) / MAG_R


def mag_outline(depth, s0=0.0, steps=10):
    """The front edge down, the foot, the back edge up; from the mouth (s0 = 0) the straight top into the well too."""
    rf, rb = MAG_R - (MAG_FRONT - MAG_BACK) / 2, MAG_R + (MAG_FRONT - MAG_BACK) / 2
    ss = [s0 + (depth - s0) * i / steps for i in range(steps + 1)]
    if s0 < MAG_STRAIGHT < depth:
        ss = sorted(set(ss + [MAG_STRAIGHT]))
    front = [mag_at(s, rf) for s in ss]
    back = [mag_at(s, rb) for s in reversed(ss)]
    top = [(MAG_BACK, MAG_TOP), (MAG_FRONT, MAG_TOP)] if s0 == 0.0 else []
    return top + front + back


# The CAR stock (photos 05, 07): a sleeve over the receiver's extension tube, its top flat over the tube, under it at
# the back a web down to the butt plate's toe. Metres (dz back from the receiver's end, y); the slide moves it all.
TUBE_Y = BORE_Y - 0.004
TUBE_R = 0.0145
TUBE_LEN = 0.14         # inside the stock even slid in
CAR_TOP = TUBE_Y + TUBE_R + 0.004
CAR_UNDER = TUBE_Y - TUBE_R - 0.01
CAR_TOE = BORE_Y - 0.082
CAR_BACK = 0.226      # m: the butt plate's face behind the receiver's end, out (the photo's)
REAR = Z(232)         # the receivers' back

MAG_PROFILES = {  # name -> (points (z, y) in metres, half width, chamfer)
    "mag_30": (mag_outline(MAG_DEPTH), MAG_HW, 0.003),
    "mag_30_base": (mag_outline(MAG_DEPTH + 0.007, MAG_DEPTH, 2), MAG_HW + 0.0015, 0.002),
    "car_stock": ([(REAR - 0.085, CAR_TOP), (REAR - CAR_BACK, CAR_TOP), (REAR - CAR_BACK, CAR_TOE),
                   (REAR - CAR_BACK + 0.02, CAR_TOE), (REAR - 0.125, CAR_UNDER), (REAR - 0.085, CAR_UNDER)], 0.018, 0.004),
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
        if width:  # a profile (a section's own keys follow it)
            print('\t\t\t\t\t"width": [%s], "chamfer": %g},' % (width, chamfer))
    v = lambda z, y: "Vector2(%g, %g)" % (round(z, 4), round(y, 4))
    print('\t"m16": {\n\t\t"profiles": {')
    for name, (points, widths, chamfer) in PROFILES.items():
        emit(name, [v(*P(*p)) for p in points],
             ", ".join("Vector2(%g, %g)" % (round(Z(px), 4), hw) for px, hw in widths), chamfer)
    for name, (points, hw, chamfer) in MAG_PROFILES.items():
        emit(name, [v(*p) for p in points], "Vector2(0, %g)" % hw, chamfer)
    print('\t\t},\n\t\t"sections": {')
    emit("handguard", [v(*p) for p in HG_BACK], "", 0)
    items = [v(*p) for p in HG_FRONT]
    lines, line = [], '\t\t\t\t\t"end_points": ['
    for i, item in enumerate(items):
        item += ", " if i < len(items) - 1 else "],"
        if len(line) + len(item) > 116:
            lines.append(line.rstrip())
            line = "\t\t\t\t\t"
        line += item
    print("\n".join(lines + [line]))
    print('\t\t\t\t\t"z": Vector2(%g, %g)},' % (round(Z(HG_Z[0]), 4), round(Z(HG_Z[1]), 4)))
    print('\t\t},\n\t},')
    sys.exit()

parts = []
node_pos = {".": (0.0, 0.0, 0.0)}


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def slab(name, centre, size, rot_z, mat, parent="."):
    """A box of `size` (x, y, z) at `centre`, turned `rot_z` radians round the barrel's axis (a face on a slope)."""
    parts.append((name, parent, "box", size, centre, ("z", rot_z), mat))


def pbox(name, x0, x1, px0, px1, py0, py1, mat, parent="."):
    """A box over the photo's pixels px0..px1 (along the gun) and py0..py1, x0..x1 across."""
    box(name, x0, x1, Y(py0), Y(py1), Z(px0), Z(px1), mat, parent=parent)


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


def mesh(name, key, mat, parent=".", x=0.0, z=0.0):
    parts.append((name, parent, "ext_mesh", key, (x, 0.0, z), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "node", None, pos, 0.0, None))
    o = node_pos[parent]
    node_pos[name if parent == "." else parent + "/" + name] = (o[0] + pos[0], o[1] + pos[1], o[2] + pos[2])


def both(x0, x1):
    return (("L", x0, x1), ("R", -x1, -x0))


# --- the lower: grip, guard, trigger; the pins, the magazine release (right), the selector and the bolt catch (left).
mesh("Lower", "lower", "alu")
mesh("Grip", "grip", "polymer")
mesh("Guard", "guard", "alu")
mesh("Trigger", "trigger", "black")
for side, x0, x1 in both(0.0165, 0.018):
    disc("TakedownPin" + side, 0.0028, x0, x1, Y(269), Z(258), "steel")
    disc("PivotPin" + side, 0.0028, x0, x1, Y(266), Z(392), "steel")
    disc("HammerPin" + side, 0.0022, x0, x1, Y(281), Z(274), "steel")
    disc("TriggerPin" + side, 0.0022, x0, x1, Y(285), Z(297), "steel")
disc("MagRelease", 0.0045, -0.0165, -0.0188, Y(282), Z(326), "black")
for name, py in (("FenceTop", 275), ("FenceBottom", 289)):
    pbox(name, -0.0165, -0.019, 319, 334, py - 1, py + 1, "alu")
disc("SelectorHub", 0.0055, 0.0165, 0.0195, Y(272), Z(268), "black")
pbox("Selector", 0.0185, 0.0198, 252, 270, 268, 275, "black")
pbox("BoltCatch", 0.0165, 0.0185, 322, 338, 262, 274, "black")
for side, x0, x1 in both(0.0165, 0.018):  # the well's flared mouth, a lip each side
    pbox("WellLip" + side, x0, x1, 337, 395, 302, 307, "alu")

# --- the upper: the ejection port on the right with the bolt carrier and the open cover under it, the forward assist
# behind it; the carry handle with the A1 rear sight (a flip aperture between two ears, the windage drum on the right);
# the T charging handle at the back, under the handle's rear.
mesh("Upper", "upper", "alu")
mesh("CarryHandleRear", "handle_rear", "alu")
mesh("CarryHandleFront", "handle_front", "alu")
for side, x in (("L", 0.0063), ("R", -0.0063)):
    mesh("CarryHandleBar" + side, "handle_bar", "alu", x=x)
pbox("SightChannel", -0.0031, 0.0031, 293, 388, 206, 209, "alu")  # the channel's floor, 10 mm under the line
pbox("EjectionPort", -0.0155, -0.0162, 325, 385, 240, 252, "steel_dark")
parts.append(("Bolt", ".", "node", {"travel": 0.04}, (0.0, 0.0, 0.0), 0.0, None))
node_pos["Bolt"] = (0.0, 0.0, 0.0)
pbox("Carrier", -0.0153, -0.0159, 330, 386, 241, 251, "steel_bright", parent="Bolt")
pbox("CarrierKey", -0.0156, -0.0161, 352, 364, 243, 246, "steel_dark", parent="Bolt")
pbox("Cover", -0.0168, -0.0176, 325, 387, 253, 266, "black")
pbox("CoverHinge", -0.0158, -0.0172, 325, 387, 252, 254, "steel")
pbox("CoverDeflector", -0.0158, -0.0198, 386, 392, 238, 248, "alu")
tube("ForwardAssist", 0.0058, Z(222), Z(262), Y(247), "alu", x=-0.0185)
tube("ForwardAssistKnob", 0.0072, Z(222), Z(230), Y(247), "black", x=-0.0185)
for side, x0, x1 in both(0.0155, 0.0165):
    disc("UpperPin" + side, 0.0025, x0, x1, Y(240), Z(388), "steel")
# The rear sight: the ears up from the handle's back, the aperture between them (a 6 mm hole - the real short-range
# one is ~5 mm; from the cheek the post must show in it), the windage drum on the right.
for side, x0, x1 in both(0.0035, 0.0095):
    pbox("RearEar" + side, x0, x1, 266, 287, 190, 206.5, "alu")
hole = 0.003
pbox("ApertureBase", -0.0035, 0.0035, 274, 278, 200, 206.5, "black")
box("ApertureBottom", -0.0035, 0.0035, Y(200), SIGHT_Y - hole, Z(275), Z(277), "black")
box("ApertureTop", -0.0035, 0.0035, SIGHT_Y + hole, SIGHT_Y + 0.0075, Z(275), Z(277), "black")
for side, x0, x1 in both(hole, 0.0035):
    box("ApertureSide" + side, x0, x1, SIGHT_Y - hole, SIGHT_Y + hole, Z(275), Z(277), "black")
disc("WindageDrum", 0.0068, -0.0095, -0.0125, Y(201), Z(277), "black")
disc("WindageDrumHub", 0.003, -0.0125, -0.0133, Y(201), Z(277), "steel")
for side, x0, x1 in both(0.0095, 0.0105):
    disc("HandleScrew" + side, 0.0035, x0, x1, Y(214), Z(388), "steel")  # the mount's hole at the front post
HANDLE = (0.0, Y(232), Z(246))
node("Handle", ".", HANDLE)
pbox("Shaft", -0.0045, 0.0045, 236, 262, 229, 236, "alu", parent="Handle")
pbox("Latch", -0.0115, 0.0115, 236, 244, 228, 236, "alu", parent="Handle")
pbox("LatchTip", 0.0115, 0.0135, 238, 244, 228, 234, "alu", parent="Handle")

# --- the A1 stock or the CAR stock on its tube.
node("Stock")
node("A1", "Stock")
mesh("Body", "stock", "polymer", parent="Stock/A1")
pbox("ButtPlate", -0.0215, 0.0215, 25, 30, 237, 345, "black", parent="Stock/A1")
pbox("TrapDoor", -0.012, 0.012, 24, 25, 262, 300, "steel_dark", parent="Stock/A1")
pbox("SlingSwivelBase", -0.004, 0.004, 44, 64, 337, 342, "black", parent="Stock/A1")
pbox("SlingSwivel", -0.002, 0.002, 40, 70, 342, 347, "steel", parent="Stock/A1")
node("CAR", "Stock")
tube("Tube", TUBE_R, REAR - TUBE_LEN, REAR, TUBE_Y, "tube", parent="Stock/CAR")
tube("CastleNut", TUBE_R + 0.003, REAR - 0.01, REAR, TUBE_Y, "black", parent="Stock/CAR")
box("EndPlate", -0.016, 0.016, TUBE_Y - 0.018, TUBE_Y + 0.012, REAR - 0.004, REAR, "black", parent="Stock/CAR")
node("Slide", "Stock/CAR")
for length, ahead in (("Out", 0.0), ("In", STOCK_SLIDE)):
    s = "Stock/CAR/Slide/" + length
    node(length, "Stock/CAR/Slide", (0.0, 0.0, ahead))
    mesh("Sleeve", "car_stock", "tube", parent=s, z=ahead)
    box("ButtPlate", -0.02, 0.02, CAR_TOE - 0.002, CAR_TOP + 0.004, REAR - CAR_BACK - 0.008 + ahead, REAR - CAR_BACK + ahead,
        "rubber", parent=s)
    # the lock's lever under the sleeve, slanting down to the toe
    box("Lever", -0.004, 0.004, CAR_UNDER - 0.022, CAR_UNDER, REAR - 0.17 + ahead, REAR - 0.115 + ahead, "black",
        rot_x=-18.0, parent=s)
    box("LeverPin", -0.002, 0.002, CAR_UNDER - 0.034, CAR_UNDER - 0.02, REAR - 0.165 + ahead, REAR - 0.16 + ahead, "steel",
        parent=s)
    box("SlingLoop", -0.0025, 0.0025, CAR_TOP, CAR_TOP + 0.007, REAR - CAR_BACK + 0.004 + ahead,
        REAR - CAR_BACK + 0.02 + ahead, "steel", parent=s)


# --- the barrels: the nut and the delta ring, the handguard, the front sight base with its ears and post, the bayonet
# lug and the sling swivel; the birdcage or the HEL-E4A.
def front_sight(p, fz):
    """The front sight base, `fz` m shifted (0 for the 603's): its gas block round the barrel, the bayonet lug, the
    swivel; "Front/ScopeCut" with the leg, the ears and the post."""
    box("GasBlock", -0.011, 0.011, Y(258), Y(242), Z(683) + fz, Z(720) + fz, "black", parent=p)
    box("BayonetLug", -0.004, 0.004, Y(269), Y(258), Z(711) + fz, Z(720) + fz, "black", parent=p)
    box("SwivelRivet", -0.006, 0.006, Y(260), Y(257), Z(690) + fz, Z(700) + fz, "black", parent=p)
    box("Swivel", -0.0015, 0.0015, Y(268), Y(260), Z(686) + fz, Z(706) + fz, "steel", rot_x=20.0, parent=p)
    box("CapRing", -0.0175, 0.0175, Y(262), Y(236), Z(683) + fz, Z(687) + fz, "black", parent=p)
    node("Front", p)
    q = p + "/Front/ScopeCut"  # what the eye sees of it through the Colt's window is cut (WeaponView._cut_window)
    node("ScopeCut", p + "/Front")
    mesh("Leg", "fsb_leg", "black", parent=q, z=fz)
    box("Column", -0.0065, 0.0065, Y(243), Y(210), Z(712) + fz, Z(719) + fz, "black", parent=q)
    box("Bridge", -0.0065, 0.0065, Y(212), Y(207), Z(702) + fz, Z(719) + fz, "black", parent=q)
    for side, x0, x1 in both(0.0028, 0.0065):
        box("Ear" + side, x0, x1, Y(207), Y(193), Z(705) + fz, Z(719) + fz, "black", parent=q)
    box("Post", -0.0012, 0.0012, Y(207), SIGHT_Y, Z(712) + fz, Z(715) + fz, "black", parent=q)
    box("PostTip", -0.0016, 0.0016, Y(209), Y(204), Z(711) + fz, Z(716) + fz, "black", parent=q)  # the detent's collar


def muzzle(p, end):
    """The birdcage on the barrel's end at `end` (m), or the HEL-E4A from just ahead of the front sight base over it."""
    node("Muzzle", p)
    node("Hider", p + "/Muzzle")
    node("Can", p + "/Muzzle")
    h = p + "/Muzzle/Hider"
    length = (MUZZLE - HIDER) * K
    tube("Body", 0.0095, end, end + length, BORE_Y, "black", parent=h)
    tube("Base", 0.0082, end - 0.006, end, BORE_Y, "black", parent=h)
    for side, x0, x1 in both(0.0088, 0.0098):  # the slots: left, right, top (the A1's bottom is open too: not seen)
        box("Slot" + side, x0, x1, BORE_Y - 0.0016, BORE_Y + 0.0016, end + 0.009, end + length - 0.004, "steel_dark", parent=h)
    box("SlotTop", -0.0016, 0.0016, BORE_Y + 0.0088, BORE_Y + 0.0098, end + 0.009, end + length - 0.004, "steel_dark", parent=h)
    tube("Crown", 0.0075, end + length, end + length + 0.001, BORE_Y, "steel_dark", parent=h)
    c = p + "/Muzzle/Can"
    return c


def can(c, back):
    """The HEL-E4A: the collar clamped on the barrel (three screws), the cone, the long body, the end cap."""
    collar, cone, body = CAN
    tube("Collar", CAN_R[0], back, back + collar, BORE_Y, "black", parent=c)
    for i, a in enumerate((90, 210, 330)):
        r = math.radians(a)
        x, y = math.cos(r) * CAN_R[0], math.sin(r) * CAN_R[0]
        box("Screw%d" % i, x - 0.0018, x + 0.0018, BORE_Y + y - 0.0018, BORE_Y + y + 0.0018, back + 0.012, back + 0.016,
            "steel", parent=c)
    tube("Cone", CAN_R[0], back + collar, back + collar + cone, BORE_Y, "black", parent=c, radius_end=CAN_R[1])
    z0 = back + collar + cone
    tube("Body", CAN_R[1], z0, z0 + body, BORE_Y, "black", parent=c, segments=20)
    for i, a in enumerate((30, 150, 270)):  # the body's own three screws round its back
        r = math.radians(a)
        x, y = math.cos(r) * CAN_R[1], math.sin(r) * CAN_R[1]
        box("BodyScrew%d" % i, x - 0.002, x + 0.002, BORE_Y + y - 0.002, BORE_Y + y + 0.002, z0 + 0.008, z0 + 0.012,
            "steel", parent=c)
    tube("EndCap", CAN_R[1] - 0.002, z0 + body, z0 + body + 0.002, BORE_Y, "black", parent=c)
    tube("Bore", 0.003, z0 + body + 0.002, z0 + body + 0.0025, BORE_Y, "steel_dark", parent=c)
    return z0 + body + 0.002


node("Barrel")
ends = {}
for name, fz in (("B508", 0.0), ("B368", -CUT)):
    p = "Barrel/" + name
    node(name, "Barrel")
    end = Z(HIDER) + fz
    tube("Nut", 0.0185, Z(398), Z(407), BORE_Y, "black", parent=p)
    tube("DeltaRing", 0.026, Z(407), Z(419), BORE_Y, "black", parent=p)
    tube("Tube", 0.0075, Z(397), end, BORE_Y, "black", parent=p, segments=12)
    if name == "B508":
        mesh("Handguard", "handguard", "polymer", parent=p)
        for i in range(10):  # the vents high on each side under the ridge (photo 01's notches along the top edge,
            # 03, 04): dark slabs laid on the slope
            z = Z(462 + 22.5 * i)
            bottom, top = hg_height(z)
            y0, y1 = bottom + (top - bottom) * 0.66, bottom + (top - bottom) * 0.8
            x0, x1 = hg_x(z, y0), hg_x(z, y1)
            tilt = math.atan2(x0 - x1, y1 - y0)  # the side leans in going up
            for side, sx in (("L", 1.0), ("R", -1.0)):
                centre = (sx * ((x0 + x1) / 2 - 0.0002), (y0 + y1) / 2, z)
                slab("Vent%s%d" % (side, i), centre, (0.0012, math.hypot(x0 - x1, y1 - y0), 0.012), sx * tilt,
                     "steel_dark", parent=p)
    else:
        # The round CAR handguard, ribbed: a row of raised pads round it, 8 along.
        hz0, hz1 = Z(419), Z(687) + fz
        tube("Handguard", 0.0255, hz0, hz1, BORE_Y - 0.003, "polymer", parent=p, radius_end=0.024, segments=12)
        for i in range(8):
            z = hz0 + 0.008 + i * (hz1 - hz0 - 0.016) / 8
            tube("Rib%d" % i, 0.0268 - 0.0002 * i, z, z + 0.014, BORE_Y - 0.003, "polymer", parent=p, segments=12)
    front_sight(p, fz)
    c = muzzle(p, end)
    ends[name] = (end + (MUZZLE - HIDER) * K, can(c, Z(720) + fz + CAN_BACK))

# --- "Mags": the origin at the well's mouth. The aluminium body, the floor plate, two ribs down each side; the top
# round in the lips.
WELL = (0.0, MAG_MOUTH, (MAG_FRONT + MAG_BACK) / 2)
node("Mags")
mp = "Mags/M16_Mag_30"
node("M16_Mag_30", "Mags", WELL)
mesh("Body", "mag_30", "mag", parent=mp)
mesh("Base", "mag_30_base", "black", parent=mp)
for col, r in enumerate((MAG_R - 0.014, MAG_R + 0.012)):
    for row in range(6):
        sm = 0.006 + (row + 0.5) * (MAG_DEPTH - 0.012) / 6
        z, y = mag_at(sm, r)
        for side, x0, x1 in both(MAG_HW - 0.0005, MAG_HW + 0.0008):
            box("Rib%s%d_%d" % (side, row, col), x0, x1, y - 0.0125, y + 0.0125, z - 0.0018, z + 0.0018, "mag",
                rot_x=-math.degrees(mag_angle(sm)), parent=mp)
tube("Round", 0.0029, MAG_BACK + 0.006, MAG_FRONT - 0.012, MAG_TOP - 0.003, "steel_bright", x=0.003, parent=mp, segments=8)

f = lambda v: "%g" % round(v, 5)
res = []
for key, spec in MATERIALS.items():
    albedo, metal, rough = spec[:3]
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="M16" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    o = node_pos[parent]
    if kind != "node":
        c = (c[0] - o[0], c[1] - o[1], c[2] - o[2])  # into the parent's space
    if kind == "cylx":
        xform = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %s, %s, %s)" % (f(c[0]), f(c[1]), f(c[2]))
    else:
        if isinstance(rot, tuple):  # ("z", radians): a slab turned round the barrel's axis
            cr, sr = math.cos(rot[1]), math.sin(rot[1])
            xform = "Transform3D(%s, %s, 0, %s, %s, 0, 0, 0, 1, %s, %s, %s)" % (f(cr), f(-sr), f(sr), f(cr), f(c[0]), f(c[1]), f(c[2]))
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
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/m16_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
v3 = lambda x, y, z: "Vector3(%s, %s, %s)" % (round(x, 4), round(y, 4), round(z, 4))
for name, (hider, can_end) in ends.items():
    print(name, "muzzle", v3(0, BORE_Y, hider), "can", v3(0, BORE_Y, can_end), "can +", round(can_end - hider, 4))
print("irons rear", v3(0, SIGHT_Y, Z(276)), "front", v3(0, SIGHT_Y, Z(713.5)), "eye relief", EYE_IRON)
print("scope rear", v3(0, SCOPE_Y, SCOPE_BACK), "eye relief", EYE_SCOPE, "front post b508/b368 z", round(Z(713.5), 4),
      round(Z(713.5) - CUT, 4))
print("right hand", v3(0, Y(330), Z(245)), "left hand 508", v3(0, Y(272), Z(540)),
      "368", v3(0, BORE_Y - 0.003 - 0.0255, Z(540) - CUT))
print("ejection", v3(-0.016, Y(246), Z(355)), "handle", v3(0, HANDLE[1], HANDLE[2]), "well", v3(*WELL))
