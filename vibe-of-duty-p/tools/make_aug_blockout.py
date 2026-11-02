"""Generates prefabs/weapons/aug_blockout.tscn: a blockout of the Steyr AUG, 5.56x45, bullpup.

Run from the repo:  python vibe-of-duty-p/tools/make_aug_blockout.py   (overwrites the scene)
              or:  python vibe-of-duty-p/tools/make_aug_blockout.py --parts   (prints the profiles for
                   tools/make_parts.gd; paste them there and run it - the scene uses its meshes)

Docs/LOADOUT.md, "AUG". Traced off the owner's photo Docs/aug/01_a1.webp (an A1 from the left on a light table, the
magazine out beside it): the gun 1982 px for its 790 mm (508 mm barrel). One olive polymer body - the butt, the grip,
the guard round the whole hand (its strut from the body's front down to the grip's foot), the magazine well behind the
grip; over its front the black receiver. The rest comes with the modules (owner, 2026-11-02):
- "Upper": A1 - the bridge with the integral 1.5x scope's knobs and emergency irons (the tube is SightModels'), A3 -
  a flat-top rail over the receiver, along the butt's top, with flip-up sights ("Upper/A3/Sights": Up / Down).
- "Barrel": B508 (full size) / B350 (Commando), each with its "Muzzle" (Hider / Can - one can for the 5.56 and the
  .300 BLK). The 508's "Front": Bare (A1: the Steyr grip folding on the barrel, "Grip": Unfolded / Folded) / Rail (A3:
  the handguard with rails, a tactical grip on its bottom rail, "Grip": On / Off); the 350's short rail block under
  the barrel with the tactical grip ("Grip": On / Off). The scene keeps them all, WeaponView drops the others.
- "Mags": AUG_Mag_30 / AUG_Mag_42 - curved, smoked brown, see-through only a little (owner, 2026-11-02, after the
  magazines' photos), the waffle bosses on the sides, the black base plate.

Conventions as tools/make_ak_blockout.py (WeaponView expects them): the barrel points to +Z, +Y is up, the origin sits
at the top of the guard's hole by the trigger, metres; prefab +x is the shooter's left (the photo's side). "Handle": the
charging handle on the left, riding the bolt. Key points used by WeaponDB (prefab space): printed by this script.
"""
import math
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "aug_blockout.tscn")

MATERIALS = {
    # The body olive (owner, 2026-11-02: always green), the metal black; the clear magazine (WeaponSkin leaves
    # transparent ones as they are) with brass rounds in it.
    "polymer": ((0.3, 0.32, 0.21), 0.0, 0.75),        # albedo, metallic, roughness(, alpha)
    "black": ((0.06, 0.06, 0.065), 0.4, 0.5),         # receiver, barrel, bridge, rails
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),
    "steel_dark": ((0.025, 0.025, 0.03), 0.5, 0.5),   # slots, holes, the bore
    "steel_bright": ((0.36, 0.36, 0.38), 0.7, 0.35),  # the guide rods under the receiver
    "grip": ((0.07, 0.07, 0.075), 0.0, 0.8),          # the tactical grip's black polymer
    "mag": ((0.24, 0.18, 0.1), 0.0, 0.3, 0.9),        # smoked brown polymer: the rounds barely show
    "mag_boss": ((0.3, 0.23, 0.13), 0.0, 0.3, 0.45),  # the waffle on it: a faint relief, not a pattern of its own
    "mag_end": ((0.05, 0.05, 0.05), 0.0, 0.7),
    "round": ((0.6, 0.42, 0.18), 0.6, 0.4),
}
MESHES = ["stock", "grip", "guard", "trigger", "receiver", "bridge_front", "bridge_rear", "bridge_rear_aimed",
          "upper_a3", "steyr_grip", "handguard", "mag_30", "mag_42", "mag_30_base", "mag_42_base"]
K = 0.79 / 1982       # m a pixel: the photo's 1982 px are the gun's 790 mm
PX0 = (975, 612)      # the photo's pixel at the origin (the guard's hole, its top, at the trigger)


def P(x, y):
    """A photo pixel -> (z, y) in metres (the muzzle on the photo's left: +Z)."""
    return ((PX0[0] - x) * K, (PX0[1] - y) * K)


def Z(x):
    return P(x, 0)[0]


def Y(y):
    return P(0, y)[1]


BORE_Y = Y(521.5)
MUZZLE = 3            # px: the hider's end
CUT = 396             # px the 350 mm barrel is shorter (158 mm)
CAN = 0.17            # m: the can, from the hider's base forward
RAIL_TOP = 396        # px: the A3 rail's top (30 mm over the butt's top, as on the photos)
SIGHT_IRON = Y(RAIL_TOP) + 0.018    # the A3 flip-ups' line
SCOPE_Y = 345         # px: the A1 scope's axis
GRIP_X = 632          # px: the support grip's middle (the Steyr one and the tactical ones alike)
EYE_X = 1515          # px: the eye at the cheek, ~75 mm behind the scope's eyepiece

# Side profiles for tools/make_parts.gd, photo pixels round the outline: (points, half width(s) [(px, hw)], chamfer).
PROFILES = {
    # The body: the front under the receiver, the butt with its toe and the magazine well's mouth, the guard's hole's
    # top; the grip and the guard are their own (narrower).
    "stock": ([(693, 569), (1022, 569), (1024, 520), (1029, 485), (1042, 471), (1880, 472), (1930, 477), (1962, 494),
               (1982, 520), (1986, 560), (1960, 653), (1940, 719), (1920, 799), (1905, 862), (1895, 878), (1880, 880),
               (1760, 877), (1735, 874), (1721, 864), (1716, 850), (1722, 839), (1738, 829), (1700, 786), (1673, 760),
               (1640, 738), (1600, 728), (1560, 717), (1540, 708), (1355, 678), (1342, 670), (1332, 656), (1320, 642),
               (1300, 633), (1260, 622), (1220, 615), (1180, 613), (1150, 613), (1017, 613), (970, 611), (900, 611),
               (845, 612), (800, 605), (760, 600), (720, 600), (700, 597), (693, 588)],
              [(693, 0.02), (1986, 0.027)], 0.005),
    "grip": ([(1017, 610), (1150, 610), (1146, 632), (1145, 650), (1150, 677), (1160, 689), (1170, 702), (1180, 718),
              (1190, 738), (1200, 767), (1207, 800), (1211, 840), (1208, 862), (1198, 872), (1130, 873), (1112, 860),
              (1112, 828), (1100, 799), (1080, 754), (1060, 712), (1045, 690), (1030, 682), (1020, 672), (1017, 640)],
             [(0, 0.015)], 0.004),
    # The guard's strut from the body's front down to the grip's foot, round the whole hand.
    "guard": ([(750, 578), (790, 610), (820, 627), (840, 650), (860, 673), (890, 717), (920, 751), (960, 802),
               (1000, 848), (1020, 861), (1040, 867), (1060, 869), (1100, 871), (1130, 872), (1125, 840), (1112, 830),
               (1100, 834), (1060, 840), (1040, 837), (1020, 828), (1000, 812), (960, 763), (940, 736), (920, 705),
               (895, 668), (872, 630), (860, 600), (820, 578)], [(0, 0.008)], 0.002),
    "trigger": ([(972, 611), (1003, 611), (1016, 625), (1015, 655), (1006, 670), (992, 668), (986, 645), (974, 624)],
                [(0, 0.005)], 0.0015),
    # The receiver over the body's front, its back into the butt.
    "receiver": ([(650, 560), (650, 494), (663, 488), (1030, 488), (1036, 567), (655, 567)], [(0, 0.0195)], 0.003),
    # The A1's bridge: the front post leaning back, the rear one curving into the butt's top; the scope's tube on them,
    # their tops just under it (SightModels' tube is see-through from the eye: nothing may stand inside it).
    "bridge_front": ([(700, 489), (752, 489), (854, 382), (787, 382)], [(0, 0.009)], 0.003),
    "bridge_rear": ([(1003, 489), (1006, 440), (1014, 400), (1025, 382), (1120, 382), (1085, 398), (1062, 420), (1048, 445), (1040, 470), (1038, 489)], [(0, 0.009)], 0.003),
    # The A3's upper: the receiver raised to the rail, the rail's riser back along the butt's top.
    "upper_a3": ([(652, 567), (652, 410), (662, 404), (1300, 404), (1305, 410), (1305, 471), (1036, 471), (1036, 567)],
                 [(0, 0.0175)], 0.003),
    # The Steyr folding grip (A1).
    "steyr_grip": ([(597, 603), (658, 603), (668, 640), (676, 700), (683, 760), (684, 835), (673, 857), (600, 858),
                    (588, 845), (591, 780), (596, 700)], [(0, 0.014)], 0.005),
    # The A3's handguard with rails round the 508 mm barrel (photos 08, 09).
    "handguard": ([(350, 404), (652, 404), (652, 592), (375, 592), (350, 580)], [(0, 0.021)], 0.003),
}


# The magazines: curved forward along an arc (its centre ahead of the well, at its mouth's height), straight above the
# mouth up into the well; 65 mm front to back, 25 mm thick. Profiles in metres (z, y). Below the mouth: the 30 165 mm,
# the 42 210 mm (the same arc, longer).
MAG_FRONT, MAG_BACK = Z(1362), Z(1525)
MAG_MOUTH, MAG_TOP = Y(680), Y(668)
MAG_R = 0.55          # m: the centre line's radius (~25 mm forward at the 30's foot)
MAG_HW = 0.0125
MAG_DEPTHS = {"30": 0.165, "42": 0.21}
MAG_CENTRE = ((MAG_FRONT + MAG_BACK) / 2 + MAG_R, MAG_MOUTH)


def mag_at(s, r):
    """The point `s` m down the arc (along its centre line) at radius `r` from the arc's centre."""
    phi = s / MAG_R
    return (MAG_CENTRE[0] - r * math.cos(phi), MAG_CENTRE[1] - r * math.sin(phi))


def mag_outline(depth, s0=0.0, steps=10):
    """The front edge down, the foot, the back edge up; from the mouth (s0 = 0) the straight top into the well too."""
    rf, rb = MAG_R - (MAG_FRONT - MAG_BACK) / 2, MAG_R + (MAG_FRONT - MAG_BACK) / 2
    front = [mag_at(s0 + (depth - s0) * i / steps, rf) for i in range(steps + 1)]
    back = [mag_at(s0 + (depth - s0) * i / steps, rb) for i in reversed(range(steps + 1))]
    top = [(MAG_BACK, MAG_TOP), (MAG_FRONT, MAG_TOP)] if s0 == 0.0 else []
    return top + front + back


# Looking through the scope (SightModels "swarovski": its tube see-through from the eye) the eye sees all in the cone
# from it through the eyepiece's bore (12.5 mm at 75 mm: slope 0.168; 0.19 with a margin). "Upper/A1/Aimed" - the
# rear bridge cut under that cone (the front one is all in it), no knobs, no emergency irons - stands in for "Upper/A1/Outside" while the
# eye is in the scope (WeaponView); outside the cone the two look the same.
SCOPE_CONE = 0.19


def under_cone(points):
    """The profile (photo px) clipped to under the cone's bottom line (Sutherland-Hodgman, one edge)."""
    f = lambda p: Y(p[1]) - (Y(SCOPE_Y) - SCOPE_CONE * (Z(p[0]) - Z(EYE_X)) - 0.001)
    out = []
    for i, a in enumerate(points):
        b = points[(i + 1) % len(points)]
        fa, fb = f(a), f(b)
        if fa <= 0.0:
            out.append(a)
        if (fa <= 0.0) != (fb <= 0.0):
            t = fa / (fa - fb)
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


PROFILES["bridge_rear_aimed"] = (under_cone(PROFILES["bridge_rear"][0]),) + PROFILES["bridge_rear"][1:]  # the front
# one is all in the cone

MAG_PROFILES = {}  # name -> (points (z, y) in metres, half width, chamfer)
for _n, _d in MAG_DEPTHS.items():
    MAG_PROFILES["mag_" + _n] = (mag_outline(_d), MAG_HW, 0.003)
    MAG_PROFILES["mag_%s_base" % _n] = (mag_outline(_d + 0.006, _d, 2), MAG_HW + 0.001, 0.002)


def hw_at(widths, px):
    if len(widths) == 1:
        return widths[0][1]
    (a, ha), (b, hb) = widths
    t = min(max((px - a) / (b - a), 0.0), 1.0)
    return ha + (hb - ha) * t


if "--parts" in sys.argv:
    v = lambda p: "Vector2(%g, %g)" % (round(P(*p)[0], 4), round(P(*p)[1], 4))
    print('\t"aug": {\n\t\t"profiles": {')
    for name, (points, widths, chamfer) in PROFILES.items():
        lines, line = [], "\t\t\t\"%s\": {\"points\": [" % name
        for i, p in enumerate(points):
            item = v(p) + (", " if i < len(points) - 1 else "]")
            if len(line) + len(item) > 116:
                lines.append(line.rstrip())
                line = "\t\t\t\t\t"
            line += item
        lines.append(line + ',')
        print("\n".join(lines))
        width = ", ".join("Vector2(%g, %g)" % (round(Z(px), 4), hw) for px, hw in widths)
        print('\t\t\t\t\t"width": [%s], "chamfer": %g},' % (width, chamfer))
    for name, (points, hw, chamfer) in MAG_PROFILES.items():
        lines, line = [], "\t\t\t\"%s\": {\"points\": [" % name
        for i, p in enumerate(points):
            item = "Vector2(%g, %g)" % (round(p[0], 4), round(p[1], 4)) + (", " if i < len(points) - 1 else "]")
            if len(line) + len(item) > 116:
                lines.append(line.rstrip())
                line = "\t\t\t\t\t"
            line += item
        lines.append(line + ',')
        print("\n".join(lines))
        print('\t\t\t\t\t"width": [Vector2(0, %g)], "chamfer": %g},' % (hw, chamfer))
    print('\t\t},\n\t\t"sections": {},\n\t},')
    sys.exit()

parts = []
node_pos = {".": (0.0, 0.0, 0.0)}


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot_x, mat))


def pbox(name, x0, x1, px0, px1, py0, py1, mat, parent="."):
    """A box over the photo's pixels px0..px1 (along the gun) and py0..py1, x0..x1 across."""
    box(name, x0, x1, Y(py0), Y(py1), Z(px0), Z(px1), mat, parent=parent)


def tube(name, radius, z0, z1, y, mat, x=0.0, parent=".", radius_end=None, segments=16):
    z0, z1 = sorted((z0, z1))
    parts.append((name, parent, "cyl", (radius, z1 - z0, radius if radius_end is None else radius_end, segments),
                  (x, y, (z0 + z1) / 2), 90.0, mat))


def ptube(name, radius, px0, px1, y, mat, x=0.0, parent=".", segments=16):
    tube(name, radius, Z(px0), Z(px1), y, mat, x=x, parent=parent, segments=segments)


def post(name, radius, y0, y1, z, mat, x=0.0, parent=".", segments=16):
    """A cylinder standing up (its axis along y)."""
    y0, y1 = sorted((y0, y1))
    parts.append((name, parent, "cyl", (radius, y1 - y0, radius, segments), (x, (y0 + y1) / 2, z), 0.0, mat))


def disc(name, radius, x0, x1, y, z, mat, parent="."):
    """A cylinder across the gun (its axis along x)."""
    x0, x1 = sorted((x0, x1))
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent=".", x=0.0):
    parts.append((name, parent, "ext_mesh", key, (x, 0.0, 0.0), 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0), rot_x=0.0):
    """A group node; `rot_x` turns it (and what is in it) about its own place."""
    parts.append((name, parent, "node", None, pos, rot_x, None))
    node_pos[name if parent == "." else parent + "/" + name] = pos


def both(x0, x1):
    return (("L", x0, x1), ("R", -x1, -x0))


# --- the body: butt, grip, guard, trigger; the safety's cross bolt over the grip, the bolt catch's plate, the magazine
# release behind the well, the ejection covers high on both sides (the shooter picks the side), a sling loop, screws.
mesh("Stock", "stock", "polymer")
mesh("Grip", "grip", "polymer")
mesh("Guard", "guard", "polymer")
mesh("Trigger", "trigger", "black")
for side, x0, x1 in both(0.0, 0.0215):
    pbox("Safety" + side, x0 if side == "R" else x1 - 0.0015, x1 + 0.002 if side == "L" else x0 - 0.002,
         1040, 1064, 584, 604, "black")
    pbox("Cover" + side, x1 + 0.0055 if side == "L" else x0 - 0.0055, x1 + 0.0065 if side == "L" else x0 - 0.0065,
         1330, 1560, 485, 508, "black")
for side, x0, x1 in both(0.0255, 0.0272):
    pbox("CatchPlate" + side, x0, x1, 1290, 1342, 578, 602, "steel")
    disc("CatchButton" + side, 0.0025, x0, x1 + (0.0008 if side == "L" else -0.0008), Y(590), Z(1316), "steel_dark")
    disc("Screw%s0" % side, 0.0022, x0 + 0.0003, x1 + 0.0005, Y(668), Z(1555), "steel")
pbox("MagRelease", -0.009, 0.009, 1560, 1640, 705, 745, "black")
disc("SlingLoop", 0.0065, 0.0262, 0.0285, Y(610), Z(1842), "steel")
disc("SlingLoopHole", 0.0035, 0.0284, 0.029, Y(610), Z(1842), "steel_dark")
for side, x0, x1 in both(0.0255, 0.0275):
    disc("ButtScrew" + side, 0.002, x0, x1, Y(865), Z(1848), "steel")

# --- the receiver (both uppers): the guide rods along its bottom, the handle's slot on the left; the charging handle
# (olive, rides the bolt).
mesh("Receiver", "receiver", "black")
for side, x0, x1 in both(0.0193, 0.0199):
    pbox("Rod" + side, x0, x1, 700, 1015, 548, 566, "steel_bright")
pbox("HandleSlot", 0.0195, 0.0199, 663, 1000, 512, 526, "steel_dark")
HANDLE = (0.0, Y(505), Z(705))
node("Handle", ".", HANDLE)
pbox("Block", 0.0199, 0.031, 663, 748, 470, 541, "polymer", parent="Handle")
pbox("Hook", 0.021, 0.03, 735, 758, 456, 472, "polymer", parent="Handle")
pbox("Grip", 0.031, 0.034, 670, 742, 480, 530, "polymer", parent="Handle")

# --- "Upper": A1 - the bridge and the scope; A3 - the rail and its flip-up sights.
node("Upper")
node("A1", "Upper")
node("Outside", "Upper/A1")
out = "Upper/A1/Outside"
mesh("BridgeFront", "bridge_front", "black", parent=out)
mesh("BridgeRear", "bridge_rear", "black", parent=out)
sy = Y(SCOPE_Y)
# The scope's tube itself is SightModels' "swarovski" (see-through, the reticle in it - seen as the ACOG): px 805..1328.
post("KnobBase", 0.0062, sy + 0.0135, sy + 0.0175, Z(950), "black", parent=out)
post("KnobCap", 0.0056, sy + 0.0175, sy + 0.022, Z(950), "steel", parent=out, segments=6)  # the hex cap
post("KnobLow", 0.0048, sy - 0.0135, sy - 0.022, Z(950), "black", parent=out)
# The emergency irons on the scope's top: a notch at the back, a blade in front.
top = sy + 0.014
for side, x0, x1 in both(0.0012, 0.0045):
    box("NotchEar" + side, x0, x1, top - 0.001, top + 0.005, Z(1250), Z(1275), "black", parent=out)
box("Blade", -0.0008, 0.0008, top - 0.001, top + 0.0045, Z(860), Z(872), "black", parent=out)
node("Aimed", "Upper/A1")
mesh("BridgeRear", "bridge_rear_aimed", "black", parent="Upper/A1/Aimed")

node("A3", "Upper")
mesh("Upper", "upper_a3", "black", parent="Upper/A3")
rt, rb = Y(RAIL_TOP), Y(404)
box("Rail", -0.0105, 0.0105, rb, rt, Z(652), Z(1305), "black", parent="Upper/A3")
n_slots = int((Z(652) - Z(1305)) / 0.00523)
for i in range(n_slots):
    z = Z(1305) + 0.003 + i * 0.00523
    box("RailSlot%d" % i, -0.0107, 0.0107, rt - 0.0018, rt + 0.0003, z, z + 0.0025, "steel_dark", parent="Upper/A3")
node("Sights", "Upper/A3")
node("Up", "Upper/A3/Sights")
node("Down", "Upper/A3/Sights")
# Front: a post between two ears on the rail's front; rear: a ring aperture with its drum on the right. Folded: flat.
sl = SIGHT_IRON
up, down = "Upper/A3/Sights/Up", "Upper/A3/Sights/Down"
box("FrontBase", -0.009, 0.009, rt, rt + 0.006, Z(700), Z(662), "black", parent=up)
for side, x0, x1 in both(0.0042, 0.007):
    box("FrontEar" + side, x0, x1, rt + 0.006, sl + 0.004, Z(690), Z(670), "black", parent=up)
box("FrontPost", -0.0011, 0.0011, rt + 0.006, sl, Z(684), Z(678), "black", parent=up)
box("RearBase", -0.009, 0.009, rt, rt + 0.006, Z(1290), Z(1232), "black", parent=up)
# The aperture 7 mm across (a ghost ring: the real one's ~2 mm hid the front post at the cheek's distance).
box("RearLeaf", -0.0075, 0.0075, rt + 0.006, sl - 0.0065, Z(1266), Z(1254), "black", parent=up)
for side, x0, x1 in both(0.0035, 0.0065):
    box("RearRing" + side, x0, x1, sl - 0.0065, sl + 0.0065, Z(1266), Z(1254), "black", parent=up)
box("RearRingTop", -0.0035, 0.0035, sl + 0.0035, sl + 0.0065, Z(1266), Z(1254), "black", parent=up)
box("RearRingBottom", -0.0035, 0.0035, sl - 0.0065, sl - 0.0035, Z(1266), Z(1254), "black", parent=up)
disc("RearDrum", 0.0075, -0.009, -0.016, rt + 0.006, Z(1262), "black", parent=up)
box("FrontBase", -0.009, 0.009, rt, rt + 0.006, Z(700), Z(662), "black", parent=down)
box("FrontFolded", -0.007, 0.007, rt + 0.006, rt + 0.0095, Z(700), Z(650), "black", parent=down)
box("RearBase", -0.009, 0.009, rt, rt + 0.006, Z(1290), Z(1232), "black", parent=down)
box("RearFolded", -0.0075, 0.0075, rt + 0.006, rt + 0.0095, Z(1300), Z(1245), "black", parent=down)
disc("RearDrum", 0.0075, -0.009, -0.016, rt + 0.006, Z(1262), "black", parent=down)


def muzzle(group, front):
    """The barrel's "Muzzle" group, the hider's end at photo pixel `front`: Hider (slotted) / Can."""
    node("Muzzle", group)
    g = group + "/Muzzle"
    node("Hider", g)
    node("Can", g)
    ptube("Body", 0.0098, front, front + 97, BORE_Y, "black", parent=g + "/Hider")
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        x, y = 0.0098 * math.cos(a), BORE_Y + 0.0098 * math.sin(a)
        box("Slot%d" % i, x - 0.0016, x + 0.0016, y - 0.0016, y + 0.0016, Z(front + 10), Z(front + 70), "steel_dark",
            parent=g + "/Hider")
    tube("Bore", 0.0034, Z(front) - 0.02, Z(front) + 0.0004, BORE_Y, "steel_dark", parent=g + "/Hider")
    base = Z(front + 97)
    tube("Body", 0.019, base, base + CAN, BORE_Y, "black", parent=g + "/Can", segments=20)
    tube("Cap", 0.0175, base + CAN, base + CAN + 0.004, BORE_Y, "steel", parent=g + "/Can", segments=20)
    tube("Bore", 0.004, base + CAN - 0.02, base + CAN + 0.0045, BORE_Y, "steel_dark", parent=g + "/Can")


def barrel(group, front):
    """The barrel from the hider's base back to the receiver: the collar, the nut, the barrel, the jacket with the gas
    cylinder under it, the locking plate."""
    ptube("Collar", 0.0102, front + 97, front + 122, BORE_Y, "black", parent=group)
    if front + 190 < 519:
        ptube("Nut", 0.0098, front + 122, front + 187, BORE_Y, "black", parent=group, segments=6)
        ptube("Barrel", 0.0086, front + 187, 519, BORE_Y, "black", parent=group)
    ptube("Jacket", 0.0108, 519, 647, BORE_Y, "black", parent=group)
    ptube("Gas", 0.0035, 528, 612, Y(556), "black", parent=group)
    ptube("Regulator", 0.0048, 540, 560, Y(556), "steel", parent=group)
    pbox("Lock", -0.02, 0.02, 647, 663, 491, 597, "black", parent=group)


def tactical_grip(group):
    """The rail clamp and the ribbed grip under it (On), nothing (Off)."""
    node("Grip", group)
    node("On", group + "/Grip")
    node("Off", group + "/Grip")
    g = group + "/Grip/On"
    pbox("Clamp", -0.012, 0.012, GRIP_X - 35, GRIP_X + 35, 592, 607, "grip", parent=g)
    post("Body", 0.0165, Y(607), Y(828), Z(GRIP_X), "grip", parent=g, segments=12)
    for i, py in enumerate((650, 690, 730, 770, 810)):
        post("Rib%d" % i, 0.0176, Y(py), Y(py + 8), Z(GRIP_X), "grip", parent=g, segments=12)
    post("Cap", 0.0182, Y(826), Y(840), Z(GRIP_X), "grip", parent=g, segments=12)


def rail(name, px0, px1, py, down, parent):
    """A short rail under (down) or along the side: its body and slots."""
    y0, y1 = (Y(py), Y(py) - 0.004) if down else (Y(py), Y(py) + 0.004)
    box(name, -0.0105, 0.0105, y0, y1, Z(px0), Z(px1), "black", parent=parent)
    for i in range(int((Z(px0) - Z(px1)) / 0.00523)):
        z = Z(px1) + 0.003 + i * 0.00523
        yy = (y1 - 0.0003, y1 + 0.0018) if down else (y1 - 0.0018, y1 + 0.0003)
        box("%sSlot%d" % (name, i), -0.0107, 0.0107, yy[0], yy[1], z, z + 0.0025, "steel_dark", parent=parent)


# --- "Barrel": B508 / B350.
node("Barrel")
node("B508", "Barrel")
muzzle("Barrel/B508", MUZZLE)
barrel("Barrel/B508", MUZZLE)
node("Front", "Barrel/B508")
node("Bare", "Barrel/B508/Front")
bare = "Barrel/B508/Front/Bare"
pbox("Bracket", -0.012, 0.012, 605, 652, 545, 603, "black", parent=bare)
PIVOT = (0.0, Y(594), Z(625))
disc("Pivot", 0.004, -0.0135, 0.0135, PIVOT[1], PIVOT[2], "steel", parent=bare)
node("Grip", bare)
node("Unfolded", bare + "/Grip")
mesh("Body", "steyr_grip", "polymer", parent=bare + "/Grip/Unfolded")
node("Folded", bare + "/Grip", PIVOT, -90.0)  # its foot swung forward, under the barrel
mesh("Body", "steyr_grip", "polymer", parent=bare + "/Grip/Folded")
node("Rail", "Barrel/B508/Front")
hg = "Barrel/B508/Front/Rail"
mesh("Handguard", "handguard", "black", parent=hg)
box("TopRail", -0.0105, 0.0105, Y(404), Y(RAIL_TOP), Z(350), Z(652), "black", parent=hg)
for i in range(int((Z(350) - Z(652)) / 0.00523)):
    z = Z(652) + 0.003 + i * 0.00523
    box("TopSlot%d" % i, -0.0107, 0.0107, Y(RAIL_TOP) - 0.0018, Y(RAIL_TOP) + 0.0003, z, z + 0.0025, "steel_dark", parent=hg)
for side, x0, x1 in both(0.0205, 0.0215):
    for i in range(8):
        disc("Hole%s%d" % (side, i), 0.0055, x0, x1, Y(470), Z(395 + i * 32), "steel_dark", parent=hg)
    pbox("SideRail" + side, x1 if side == "L" else x0 - 0.004, x1 + 0.004 if side == "L" else x0, 400, 520, 515, 543,
         "black", parent=hg)
rail("BottomRail", 430, 650, 592, True, hg)
tactical_grip(hg)
node("B350", "Barrel")
muzzle("Barrel/B350", MUZZLE + CUT)
barrel("Barrel/B350", MUZZLE + CUT)
pbox("Block", -0.016, 0.016, 565, 652, 546, 592, "black", parent="Barrel/B350")
rail("BottomRail", 570, 650, 592, True, "Barrel/B350")
tactical_grip("Barrel/B350")

# --- "Mags": their origin at the well's mouth. The curved smoked body, the black base plate; on each side the waffle -
# three columns of square bosses down the arc under the smooth top; the top rounds in the lips.
WELL = (0.0, MAG_MOUTH, Z(1442))
node("Mags")
for n, depth in MAG_DEPTHS.items():
    mp = "Mags/AUG_Mag_" + n
    node("AUG_Mag_" + n, "Mags", WELL)
    mesh("Body", "mag_" + n, "mag", parent=mp)
    mesh("Base", "mag_%s_base" % n, "mag_end", parent=mp)
    for row in range(int((depth - 0.05) / 0.0145)):
        sm = 0.05 + (row + 0.5) * 0.0145
        phi = sm / MAG_R
        for col, r in enumerate((MAG_R - 0.0195, MAG_R, MAG_R + 0.0195)):
            z, y = mag_at(sm, r)
            for side, x0, x1 in both(MAG_HW - 0.0005, MAG_HW + 0.0012):
                box("Boss%s%d_%d" % (side, row, col), x0, x1, y - 0.0058, y + 0.0058, z - 0.0078, z + 0.0078, "mag_boss",
                    rot_x=-math.degrees(phi), parent=mp)
    for i, x in enumerate((-0.0045, 0.0045)):
        tube("Round%d" % i, 0.0045, MAG_BACK + 0.008, MAG_FRONT - 0.004, MAG_TOP - 0.004 - i * 0.006, "round", x=x,
             parent=mp, segments=8)

f = lambda v: "%g" % round(v, 5)
res = []
for key, spec in MATERIALS.items():
    albedo, metal, rough = spec[:3]
    alpha = spec[3] if len(spec) > 3 else 1.0
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\n%salbedo_color = Color(%s, %s, %s, %s)\nmetallic = %s\nroughness = %s\n'
               % (key, key, "transparency = 1\n" if alpha < 1.0 else "", f(albedo[0]), f(albedo[1]), f(albedo[2]),
                  f(alpha), f(metal), f(rough)))
nodes = ['[node name="AUG" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    o = node_pos[parent]
    c = (c[0] - o[0], c[1] - o[1], c[2] - o[2])  # into the parent's space (a turned group turns about its own place)
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
        segments = params[3] if kind == "cyl" else 12
        res.append('[sub_resource type="CylinderMesh" id="mesh_%d"]\nmaterial = SubResource("mat_%s")\ntop_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = %d\nrings = 1\n'
                   % (i, mat, f(top), f(params[0]), f(params[1]), segments))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/aug_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
v3 = lambda x, y, z: "Vector3(%s, %s, %s)" % (round(x, 4), round(y, 4), round(z, 4))
print("muzzle", v3(0, BORE_Y, Z(MUZZLE)), "muzzle 350", v3(0, BORE_Y, Z(MUZZLE + CUT)), "can +", round(CAN - 97 * K, 4))
print("scope rear", v3(0, sy, Z(1328)), "front", v3(0, sy, Z(805)), "eye relief", round(Z(1328) - Z(EYE_X), 4))
print("irons rear", v3(0, sl, Z(1260)), "front", v3(0, sl, Z(681)), "eye relief", round(Z(1260) - Z(EYE_X), 4))
print("rail top", round(Y(RAIL_TOP), 4), "eye z", round(Z(EYE_X), 4))
print("right hand", v3(0, Y(720), Z(1125)), "left hand", v3(0, Y(720), Z(GRIP_X)), "handle", v3(0.026, HANDLE[1], HANDLE[2]))
print("ejection", v3(-0.026, Y(515), Z(1400)), "well", v3(*WELL))
