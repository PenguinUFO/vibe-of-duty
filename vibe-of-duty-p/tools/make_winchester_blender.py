"""Builds the Winchester 1887 in Blender and exports it as a .glb (an experiment next to make_winchester_blockout.py).

Run:  blender.exe --background --python vibe-of-duty-p/tools/make_winchester_blender.py -- <out.glb>

The same side contours (the owner's photo, 2.026 mm a pixel), key points and node names as the blockout (its header):
"Lever", "Hammer", "Shell" are empties on their pivots, the materials are named after the blockout's keys (WeaponSkin
reads the names). Everything is written in prefab space (+Z the barrel, +Y up, +X the shooter's left) and turned into
Blender's on the way (B()); the glTF exporter's Y-up turns it back.
What Blender adds over the blockout: sections that change along a loft, real cuts (the breech block's well between the
receiver's walls, the hammer's slot, screw slots, the bore), bevels on every profile, smooth shading with sharp creases.
"""
import math
import os
import sys

import bmesh
import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = next((a for a in ARGS if not a.startswith("--")), os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "shots", "winchester_blender.glb"))

MATERIALS = {  # as make_winchester_blockout.py
    "steel": ((0.07, 0.075, 0.09), 0.6, 0.35),
    "steel_frame": ((0.2, 0.22, 0.26), 0.6, 0.4),
    "steel_panel": ((0.28, 0.3, 0.34), 0.6, 0.3),
    "steel_dark": ((0.03, 0.03, 0.035), 0.5, 0.5),
    "wood": ((0.34, 0.17, 0.09), 0.0, 0.6),
    "hull": ((0.62, 0.1, 0.08), 0.0, 0.5),
    "brass": ((0.62, 0.46, 0.2), 0.7, 0.35),
}
BORE_Y, BARREL_R, MUZZLE_Z, BREECH_Z = 0.073, 0.0115, 0.64, 0.11
TUBE_Y, TUBE_R, TUBE_END = 0.0446, 0.011, 0.502
PIVOT = (0.012, 0.07)       # (y, z)
HAMMER_PIN = (0.055, 0.04)
SHELL_PORT = (0.092, 0.07)
SIGHT_Y, CHEEK_Z, CHEEK_FRONT = 0.0895, 0.094, 0.1195
HW = 0.0195                 # the receiver's half width

# The side contours off the photo (make_parts.gd "winchester"): (z, bottom y, top y).
RECEIVER = [(-0.0284, 0.003, 0.0344), (-0.0243, -0.001, 0.0405), (-0.0162, -0.003, 0.0507), (-0.0061, -0.0041, 0.0628),
            (0.0041, -0.0041, 0.071), (0.0162, -0.0041, 0.075), (0.0365, -0.0041, 0.078), (0.0567, 0.0, 0.081),
            (0.077, 0.0101, 0.0828), (0.0972, 0.0182, 0.0822), (0.1135, 0.0294, 0.0815), (0.1195, 0.0314, 0.081)]
STOCK = [(-0.3627, -0.1317, -0.002, 0.021), (-0.3546, -0.1307, 0.003, 0.0209), (-0.3282, -0.1236, 0.0061, 0.0206),
         (-0.2472, -0.0952, 0.0091, 0.0196), (-0.1661, -0.0709, 0.0118, 0.0187), (-0.152, -0.0679, 0.0122, 0.0185),
         (-0.1479, -0.0658, 0.0111, 0.0184), (-0.1438, -0.0689, 0.0081, 0.0184), (-0.1357, -0.077, 0.0, 0.0183),
         (-0.1256, -0.0841, -0.002, 0.0182), (-0.1135, -0.081, -0.001, 0.018), (-0.1013, -0.0669, 0.0041, 0.0179),
         (-0.0851, -0.0486, 0.0101, 0.0177), (-0.0689, -0.0324, 0.0162, 0.0175), (-0.0547, -0.0203, 0.0223, 0.0173),
         (-0.0365, -0.0081, 0.0304, 0.0171), (-0.0284, -0.002, 0.0324, 0.017)]
PANEL = [(0.1135, 0.072), (0.0972, 0.0727), (0.077, 0.0733), (0.0567, 0.0715), (0.0365, 0.0685), (0.0162, 0.0655),
         (0.0041, 0.0615), (-0.0061, 0.0533), (-0.0162, 0.0412), (-0.0162, 0.001), (-0.0061, -0.0001), (0.0162, -0.0001),
         (0.0365, -0.0001), (0.0567, 0.004), (0.077, 0.0141), (0.0972, 0.0222), (0.1135, 0.0334)]
HAMMER = [(0.05, 0.058), (0.05, 0.0795), (0.044, 0.0812), (0.032, 0.0808), (0.02, 0.0826), (0.0125, 0.0822),
          (0.0115, 0.0805), (0.018, 0.0782), (0.03, 0.0768), (0.036, 0.071), (0.034, 0.058)]
LEVER_FRONT = [(0.0324, -0.0122), (-0.0324, -0.0122), (-0.0375, -0.0284), (-0.0314, -0.0466), (0.0, -0.0517),
               (0.0263, -0.0415), (0.0334, -0.0243)]
LEVER_REAR = [(-0.0344, -0.0152), (-0.0567, -0.0274), (-0.0851, -0.0507), (-0.1023, -0.075), (-0.1043, -0.0912),
              (-0.0932, -0.0993), (-0.079, -0.0962), (-0.0547, -0.0739), (-0.0334, -0.0496), (-0.0375, -0.0304)]

bpy.ops.wm.read_factory_settings(use_empty=True)
node_pos = {None: (0.0, 0.0, 0.0)}
nodes = {}


def B(p):
    """Prefab space -> Blender (the exporter turns Blender's Z-up back into Y-up: x, z, -y)."""
    return (p[0], -p[2], p[1])


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def resample(stations, steps, closed=False):
    """Catmull-Rom through the stations (tuples), `steps` pieces a span."""
    n = len(stations)
    out = []
    for i in range(n if closed else n - 1):
        p = [stations[(i + k) % n] if closed else stations[max(0, min(n - 1, i + k))] for k in (-1, 0, 1, 2)]
        for s in range(steps):
            t = s / steps
            out.append(tuple(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3)
                             for a, b, c, d in zip(*p)))
    if not closed:
        out.append(stations[-1])
    return out


def sect(z, yb, yt, hw, top, bot, k=6):
    """A cross section: a rectangle with elliptic corners, `top` / `bot` = (rx, ry)."""
    rxt, ryt = min(top[0], hw - 1e-4), top[1]
    rxb, ryb = min(bot[0], hw - 1e-4), bot[1]
    s = min(1.0, (yt - yb - 1e-4) / (ryt + ryb))
    ryt, ryb = ryt * s, ryb * s
    pts = [(hw - rxb + rxb * math.cos(-math.pi / 2 + math.pi / 2 * i / k), yb + ryb + ryb * math.sin(-math.pi / 2 + math.pi / 2 * i / k)) for i in range(k + 1)]
    pts += [(hw - rxt + rxt * math.cos(math.pi / 2 * i / k), yt - ryt + ryt * math.sin(math.pi / 2 * i / k)) for i in range(k + 1)]
    return [(x, y, z) for x, y in pts + [(-x, y) for x, y in reversed(pts)]]


def loft(bm, rings, closed=False, caps=True):
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    n, m = len(rings[0]), len(rings)
    for i in range(m if closed else m - 1):
        a, b = verts[i], verts[(i + 1) % m]
        for j in range(n):
            bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    if caps and not closed:
        bm.faces.new(verts[0])
        bm.faces.new(verts[-1])


def prism(bm, points, x0, x1):
    """A side profile ((z, y) points) pushed across the gun."""
    loft(bm, [[(x0, y, z) for z, y in points], [(x1, y, z) for z, y in points]])


def box(bm, x0, x1, y0, y1, z0, z1):
    prism(bm, [(z0, y0), (z1, y0), (z1, y1), (z0, y1)], x0, x1)


def lathe(bm, profile, y, x=0.0, segments=20, caps=True):
    """Rings round the barrel's direction: `profile` = (radius, z)."""
    loft(bm, [[(x + r * math.cos(2 * math.pi * i / segments), y + r * math.sin(2 * math.pi * i / segments), z)
               for i in range(segments)] for r, z in profile], caps=caps)


def disc(bm, radius, x0, x1, y, z, segments=12):
    """A cylinder across the gun."""
    loft(bm, [[(x, y + radius * math.cos(2 * math.pi * i / segments), z + radius * math.sin(2 * math.pi * i / segments))
               for i in range(segments)] for x in (x0, x1)])


def band(bm, points, thick, hw, chamfer=0.0012):
    """A flat band along a closed middle line in the side plane (the lever's loops)."""
    path = resample(points, 6, closed=True)
    n = len(path)
    rings = []
    for i, (z, y) in enumerate(path):
        tz, ty = path[(i + 1) % n][0] - path[i - 1][0], path[(i + 1) % n][1] - path[i - 1][1]
        length = math.hypot(tz, ty)
        nz, ny = -ty / length, tz / length
        t, c = thick / 2, chamfer
        ring = [(hw - c, t), (hw, t - c), (hw, -t + c), (hw - c, -t), (-hw + c, -t), (-hw, -t + c), (-hw, t - c), (-hw + c, t)]
        rings.append([(x, y + o * ny, z + o * nz) for x, o in ring])
    loft(bm, rings, closed=True)


def material(key):
    if key not in bpy.data.materials:
        albedo, metal, rough = MATERIALS[key]
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        # The blockout's colours are sRGB (a .tscn Color), Blender's are linear.
        bsdf.inputs["Base Color"].default_value = (*(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in albedo), 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
    return bpy.data.materials[key]


def node(name, pos):
    empty = bpy.data.objects.new(name, None)
    empty.location = B(pos)
    bpy.context.scene.collection.objects.link(empty)
    node_pos[name] = pos
    nodes[name] = empty


def obj(name, bm, mat, parent=None, bevel=0.0, sharp=38.0, keep=True):
    """The bmesh (prefab space) as an object under `parent`; `bevel` chamfers its creases."""
    o = node_pos[parent]
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    for v in bm.verts:
        v.co = B((v.co.x - o[0], v.co.y - o[1], v.co.z - o[2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        mesh.materials.append(material(mat))
    if parent:
        ob.parent = nodes[parent]
    ob["sharp"] = sharp
    if bevel > 0.0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40.0)
        apply(ob, mod)
    return ob


def apply(ob, mod):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def cut(ob, cutter, operation="DIFFERENCE"):
    mod = ob.modifiers.new("bool", "BOOLEAN")
    mod.object = cutter
    mod.operation = operation
    mod.solver = "EXACT"
    apply(ob, mod)
    bpy.data.objects.remove(cutter, do_unlink=True)


def bm_new():
    return bmesh.new()


def rec_top(z):
    """The receiver's top line at z (straight between the photo's stations)."""
    for a, b in zip(RECEIVER, RECEIVER[1:]):
        if a[0] <= z <= b[0]:
            return lerp(a[2], b[2], (z - a[0]) / (b[0] - a[0]))
    return RECEIVER[-1][2]


# --- Receiver: the loft, the sight's cheeks joined on, the breech block's well cut between the walls.
bm = bm_new()
rings = []
for z, yb, yt in resample(RECEIVER, 4):
    rings.append(sect(z, yb, yt, HW, (0.005, 0.006), (0.004, 0.004), k=8))
loft(bm, rings)
receiver = obj("Receiver", bm, "steel_frame")

# The rear sight (the owner's photo, 2026-11-07): the receiver's front rises round the breech in two cheeks, a 7 mm slot
# between them; their shoulders round down to the walls, the front slopes to the barrel.
cheek = [(0.0035, 0.0815), (0.0035, SIGHT_Y), (0.0105, SIGHT_Y)]
cheek += [(0.0105 + 0.009 * math.sin(math.pi / 2 * i / 6), 0.0745 + 0.015 * math.cos(math.pi / 2 * i / 6)) for i in range(1, 7)]
cheek += [(HW, 0.066)]
section = [(-x, y) for x, y in reversed(cheek)] + cheek
front = [(x, y - 0.004 * smooth((y - 0.074) / (SIGHT_Y - 0.074))) for x, y in section]
front = [(x, max(y, 0.0795) if abs(x) < 0.004 else y) for x, y in front]
bm = bm_new()
loft(bm, [[(x, y, CHEEK_Z) for x, y in section], [(x, y, CHEEK_FRONT) for x, y in front]])
cut(receiver, obj("Cheeks", bm, None), "UNION")

# The breech block rolls between the walls: its well, then the block itself, a hair under the walls' tops, with the
# hammer's slot down its middle.
WELL = (0.016, CHEEK_Z)      # z
BLOCK_HW = 0.0118
bm = bm_new()
box(bm, -BLOCK_HW - 0.0005, BLOCK_HW + 0.0005, 0.05, 0.2, WELL[0], WELL[1])
cut(receiver, obj("Well", bm, None))
bm = bm_new()
loft(bm, [sect(z, 0.05, rec_top(z) - 0.0012, BLOCK_HW, (0.0015, 0.0015), (0.0005, 0.0005), k=3)
          for z in [WELL[0] + 0.0006 + (WELL[1] - WELL[0] - 0.001) * i / 12 for i in range(13)]])
block = obj("BreechBlock", bm, "steel")
bm = bm_new()
box(bm, -0.0056, 0.0056, 0.052, 0.2, 0.0, 0.056)
cut(block, obj("HammerSlot", bm, None))

bm = bm_new()
prism(bm, PANEL, -0.0205, 0.0205)
obj("Panel", bm, "steel_panel", bevel=0.0008)

# Screws with slots, the pivot's and the hammer's pins.
bm = bm_new()
slots = bm_new()
for sz, sy, r, angle in ((0.0365, 0.0162, 0.0028, 20.0), (0.0709, 0.0081, 0.0028, -35.0), (0.0972, 0.0446, 0.0028, 70.0),
                        (PIVOT[1], PIVOT[0], 0.0035, 0.0), (HAMMER_PIN[1], HAMMER_PIN[0], 0.0024, 50.0)):
    disc(bm, r, -0.0212, 0.0212, sy, sz, segments=14)
    dz, dy = math.cos(math.radians(angle)) * r * 0.85, math.sin(math.radians(angle)) * r * 0.85
    wz, wy = -dy / r * 0.0004, dz / r * 0.0004
    for x0, x1 in ((0.0209, 0.0214), (-0.0214, -0.0209)):
        prism(slots, [(sz - dz - wz, sy - dy - wy), (sz + dz - wz, sy + dy - wy), (sz + dz + wz, sy + dy + wy), (sz - dz + wz, sy - dy + wy)], x0, x1)
obj("Screws", bm, "steel")
obj("ScrewSlots", slots, "steel_dark")

bm = bm_new()
prism(bm, [(0.003, -0.002), (0.0035, -0.012), (0.001, -0.02), (-0.0035, -0.0235), (-0.0045, -0.0215), (-0.002, -0.017), (-0.0015, -0.01), (-0.004, -0.002)], -0.003, 0.003)
obj("Trigger", bm, "steel", bevel=0.0008)

# --- Stock: oval sections along the photo's contour; the steel butt plate.
bm = bm_new()
rings = []
for z, yb, yt, hw in resample(STOCK, 3):
    rings.append(sect(z, yb, yt, hw, (hw * 0.8, min(0.016, (yt - yb) * 0.3)), (hw * 0.8, min(0.016, (yt - yb) * 0.3)), k=6))
loft(bm, rings)
obj("Stock", bm, "wood")
bm = bm_new()
loft(bm, [sect(z, -0.1317 + dy, -0.002 - dy, 0.021 - dy, (0.017, 0.016), (0.017, 0.016), k=6)
          for z, dy in ((-0.3667, 0.0012), (-0.3655, 0.0), (-0.3622, 0.0))])
obj("ButtPlate", bm, "steel")

# --- Barrel (thicker at the breech, a real crown and bore), the magazine tube with its cap, the band, the bead.
bm = bm_new()
lathe(bm, [(0.0128, BREECH_Z - 0.004), (0.0128, BREECH_Z + 0.02), (BARREL_R, 0.165), (BARREL_R, MUZZLE_Z - 0.001),
           (BARREL_R - 0.001, MUZZLE_Z), (0.0096, MUZZLE_Z), (0.0093, MUZZLE_Z - 0.001), (0.0093, MUZZLE_Z - 0.035)], BORE_Y)
obj("Barrel", bm, "steel")
bm = bm_new()
lathe(bm, [(0.0092, MUZZLE_Z - 0.034), (0.0092, MUZZLE_Z - 0.005)], BORE_Y)  # a dark plug down the bore
obj("Bore", bm, "steel_dark")
bm = bm_new()
lathe(bm, [(TUBE_R, BREECH_Z), (TUBE_R, TUBE_END), (TUBE_R + 0.0006, TUBE_END), (TUBE_R + 0.0006, TUBE_END + 0.007),
           (TUBE_R - 0.0015, TUBE_END + 0.0085)], TUBE_Y, segments=18)
obj("Tube", bm, "steel")
bm = bm_new()
lathe(bm, [(0.0045, TUBE_END + 0.0084), (0.0045, TUBE_END + 0.0092)], TUBE_Y, segments=12)
obj("CapScrew", bm, "steel_dark")
bm = bm_new()
loft(bm, [sect(z, 0.0321 + d, 0.0855 - d, 0.0127 - d, (0.0126, 0.0127), (0.0126, 0.0127), k=8)
          for z, d in ((0.506, 0.0008), (0.507, 0.0), (0.517, 0.0), (0.518, 0.0008))])
obj("Band", bm, "steel")
bm = bm_new()
disc(bm, 0.002, -0.0131, 0.0131, (TUBE_Y + BORE_Y) / 2, 0.512)
obj("BandScrew", bm, "steel_dark")
bm = bm_new()  # the brass bead: a ball on a short stem, its top on the sight line
bead_r, bead_z = 0.0021, MUZZLE_Z - 0.016
loft(bm, [[(bead_r * math.sin(a) * math.cos(2 * math.pi * j / 10), SIGHT_Y - bead_r + bead_r * math.cos(a),
            bead_z + bead_r * math.sin(a) * math.sin(2 * math.pi * j / 10)) for j in range(10)]
          for a in [0.03] + [math.pi * i / 6 for i in range(1, 6)] + [math.pi - 0.03]])
loft(bm, [[(0.0011 * math.cos(2 * math.pi * j / 8), y, bead_z + 0.0011 * math.sin(2 * math.pi * j / 8)) for j in range(8)]
          for y in (BORE_Y + BARREL_R - 0.001, SIGHT_Y - bead_r)])
obj("Bead", bm, "brass", sharp=80.0)

# --- Fore-end: round the barrel and the tube, its front end rounded off; its pins.
bm = bm_new()
loft(bm, [sect(z, yb, yt, hw, (rt, rt), (rb, rb), k=8) for z, yb, yt, hw, rt, rb in (
    (0.1195, 0.0312, 0.076, 0.0182, 0.007, 0.016), (0.1215, 0.0304, 0.077, 0.019, 0.007, 0.016), (0.397, 0.0324, 0.077, 0.0185, 0.007, 0.016),
    (0.403, 0.0335, 0.0762, 0.0178, 0.007, 0.0155), (0.407, 0.036, 0.0735, 0.016, 0.007, 0.0145), (0.409, 0.04, 0.0695, 0.0135, 0.0065, 0.0125))])
obj("Forend", bm, "wood")
bm = bm_new()
for z in (0.19, 0.33):
    disc(bm, 0.0022, -0.0196, 0.0196, 0.055, z)
obj("ForendPins", bm, "steel")

# --- Hammer on its pin (cocked): the body in the block's slot, the wide checkered spur back over the receiver's hump.
node("Hammer", (0.0, HAMMER_PIN[0], HAMMER_PIN[1]))
bm = bm_new()
prism(bm, HAMMER, -0.0045, 0.0045)
obj("Body", bm, "steel_frame", parent="Hammer", bevel=0.001)
bm = bm_new()
prism(bm, [(0.031, 0.0806), (0.02, 0.0826), (0.0125, 0.0822), (0.0105, 0.0808), (0.0115, 0.0798), (0.02, 0.0806), (0.03, 0.079)], -0.0066, 0.0066)
obj("Spur", bm, "steel_frame", parent="Hammer", bevel=0.0008)
bm = bm_new()
for i in range(5):
    z = 0.0135 + 0.0034 * i
    y = lerp(0.0823, 0.0808, max(0.0, (z - 0.02) / 0.011)) if z > 0.02 else lerp(0.0822, 0.0826, (z - 0.0125) / 0.0075)
    box(bm, -0.0056, 0.0056, y - 0.0004, y + 0.0003, z - 0.0006, z + 0.0006)
obj("Knurl", bm, "steel_dark", parent="Hammer")

# --- Lever on its pivot: the boss, the bar under the receiver, the two loops.
node("Lever", (0.0, PIVOT[0], PIVOT[1]))
bm = bm_new()
disc(bm, 0.006, -0.0085, 0.0085, PIVOT[0], PIVOT[1], segments=14)
prism(bm, [(0.072, 0.007), (0.074, 0.0015), (0.034, -0.0075), (0.03, -0.0095), (0.029, -0.0145), (0.034, -0.0135), (0.066, -0.004)], -0.0085, 0.0085)
obj("Bar", bm, "steel", parent="Lever", bevel=0.0008)
bm = bm_new()
band(bm, LEVER_FRONT, 0.0046, 0.0042)
obj("Front", bm, "steel", parent="Lever")
bm = bm_new()
band(bm, LEVER_REAR, 0.0046, 0.0042)
obj("Rear", bm, "steel", parent="Lever")

# --- The shell the left hand pushes into the open top: the brass head to the rear, the crimp rounded.
node("Shell", (0.0, SHELL_PORT[0], SHELL_PORT[1]))
bm = bm_new()
lathe(bm, [(0.0102, SHELL_PORT[1] - 0.023), (0.0102, SHELL_PORT[1] + 0.044), (0.009, SHELL_PORT[1] + 0.047)], SHELL_PORT[0], segments=14)
obj("Hull", bm, "hull", parent="Shell")
bm = bm_new()
lathe(bm, [(0.0112, SHELL_PORT[1] - 0.035), (0.0112, SHELL_PORT[1] - 0.0335), (0.0104, SHELL_PORT[1] - 0.0335), (0.0104, SHELL_PORT[1] - 0.023)], SHELL_PORT[0], segments=14)
obj("Head", bm, "brass", parent="Shell")

# Smooth shading with sharp creases, then out.
tris = 0
for ob in bpy.context.scene.objects:
    if ob.type != "MESH":
        continue
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.set_sharp_from_angle(angle=math.radians(ob["sharp"]))
    del ob["sharp"]
    tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", export_apply=True, export_yup=True,
                          export_extras=False, export_cameras=False, export_lights=False, export_animations=False)
print("wrote %s: %d triangles" % (OUT, tris))
