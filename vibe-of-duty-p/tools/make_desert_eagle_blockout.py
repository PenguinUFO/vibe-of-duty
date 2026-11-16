"""Generates prefabs/weapons/deagle_blockout.tscn: a blockout of the Desert Eagle Mark XIX, .50 AE, a 6" barrel.

Run from the repo:  python vibe-of-duty-p/tools/make_desert_eagle_blockout.py   (overwrites the scene)
The shaped parts (the slide, the barrel, the frame, the guard, the grip, the trigger, the hammer) are meshes made by
tools/make_parts.gd (prefabs/weapons/deagle_<part>_mesh.tres) - run that first if they change:
  PARTS_ONLY=deagle Godot_v4.7.2.exe --headless --path vibe-of-duty-p -s tools/make_parts.gd

A stand-in until the owner's model (Docs/MODELS.md), laid out to his reference photo of the silver gun as a clean
side view: the short slab slide at the rear with its serrations, the ambidextrous safety and the rear sight; the long
flat-sided barrel in front of it (fixed to the frame) with the slotted rail, the front sight and the port; the
frame's shallow dust cover out to 0.156 with its own rail under it; the compact square trigger guard; the big grip
with its palm swell under the beavertail's hooked tang. 273 mm long, 150 high. Built life size; the game draws it
bigger than life (WeaponDef.model_scale, as the Luger: in the two fists a real pistol reads as a toy).

Conventions as tools/make_luger_blockout.py (WeaponView expects them): the barrel points to +Z, +Y up, the origin
under the receiver at the trigger, metres. Groups: "Bolt" - the slide and what rides on it (its serrations, the
safety, the rear sight, the port), pulled back `travel` m on a shot and at the end of a reload; "Hammer" - the spur
on its pin, falling on a shot; "Mags/Deagle_Mag_7" - nodes named "*_Mag_*" so reloads take the magazine out (its node
sits 0.11 m over and 0.015 m behind where the hand holds it, WeaponView.mag_grip_point), the base plate and the body
inside the grip.

Key points used by WeaponDB (prefab space, life size): muzzle (0, 0.030, 0.172) - 2 mm out of the barrel's face;
rear sight (0, 0.0625, -0.070), the notch's ears' tops; front sight (0, 0.0625, 0.160), the blade's tip level with
them; the right palm (0, -0.045, -0.050) in the middle of the grip, the left (0, -0.075, -0.062) cupped under it; the
ejection port (-0.0148, 0.036, 0.000) on the right; the slide's travel 0.035.
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "prefabs", "weapons", "deagle_blockout.tscn")

MATERIALS = {
    # The owner's references are the silver gun (and a black one): a light steel shows the facets, and the game's
    # skin tints it anyway (WeaponSkin).
    "steel": ((0.38, 0.38, 0.40), 0.50, 0.38),       # albedo, metallic, roughness
    "steel_light": ((0.56, 0.56, 0.58), 0.70, 0.24), # the polished pins, levers and the muzzle's crown
    "grip": ((0.16, 0.16, 0.16), 0.0, 0.80),         # the rubber grip
    "mag": ((0.24, 0.24, 0.25), 0.45, 0.45),         # the magazine, the port's shadow, the bore
    "dot": ((0.85, 0.85, 0.80), 0.0, 0.55),          # the sights' white dots
    "red": ((0.55, 0.06, 0.05), 0.0, 0.55),          # the safety's loaded dot
}

MESHES = ["d_slide", "d_barrel", "d_frame", "d_guard", "d_grip", "d_panel", "d_trigger", "d_hammer"]
BORE_Y = 0.030
TOP, BOT = 0.0505, 0.0145  # the slide's top and bottom
HW = 0.0148                # the slide's half width
MUZZLE = 0.170             # the barrel's face
GRIP_RAKE = 19.0           # degrees back from vertical: the magazine's axis

parts = []  # (name, parent, kind, size/params, center, rot_x_deg, material)


def box(name, x0, x1, y0, y1, z0, z1, mat, rot_x=0.0, parent="."):
    x0, x1 = min(x0, x1), max(x0, x1)  # the right side is built with negative x: a box needs its size positive
    y0, y1 = min(y0, y1), max(y0, y1)
    z0, z1 = min(z0, z1), max(z0, z1)
    parts.append((name, parent, "box", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                  rot_x, mat))


def tube(name, radius, z0, z1, y, mat, x=0.0, parent="."):
    """A cylinder along the barrel."""
    parts.append((name, parent, "cyl", (radius, z1 - z0, radius), (x, y, (z0 + z1) / 2), 90.0, mat))


def disc(name, radius, x0, x1, y, z, mat, parent="."):
    """A cylinder across the gun (axis along X): pins, the safety's pivots, the medallions."""
    x0, x1 = min(x0, x1), max(x0, x1)
    parts.append((name, parent, "cylx", (radius, x1 - x0), ((x0 + x1) / 2, y, z), 0.0, mat))


def mesh(name, key, mat, parent=".", pos=(0.0, 0.0, 0.0)):
    parts.append((name, parent, "ext_mesh", key, pos, 0.0, mat))


def node(name, parent=".", pos=(0.0, 0.0, 0.0), travel=None):
    parts.append((name, parent, "node", travel, pos, 0.0, None))


# The frame, its guard, the grip, the trigger; the barrel is the gun's own, fixed to the frame (only the slide moves).
mesh("Frame", "d_frame", "steel")
mesh("TriggerGuard", "d_guard", "steel")
mesh("Grip", "d_grip", "grip")
mesh("GripPanels", "d_panel", "grip")
mesh("Barrel", "d_barrel", "steel")
mesh("Trigger", "d_trigger", "steel_light")

# The rail on the barrel's top: a strip and its six teeth (the slots between them), the front sight on its end.
box("Rail", -0.0116, 0.0116, TOP, 0.0532, 0.058, 0.166, "steel")
for i in range(6):
    z = 0.060 + i * 0.0175
    box("RailTooth%d" % i, -0.0112, 0.0112, 0.0532, 0.0562, z, z + 0.0115, "steel")
# The front sight: a ramp on the rail, the blade's tip on the sights' line (0.0625), a white dot on its back.
box("FrontSightBase", -0.0064, 0.0064, 0.0532, 0.0575, 0.148, 0.166, "steel")
box("FrontSightBlade", -0.0026, 0.0026, 0.0575, 0.0625, 0.152, 0.166, "steel")
box("FrontSightDot", -0.0012, 0.0012, 0.0594, 0.0608, 0.1514, 0.1521, "dot")

# The muzzle: the polished crown ring round the dark bore.
tube("MuzzleCrown", 0.0086, 0.1690, 0.1702, BORE_Y, "steel_light")
tube("Bore", 0.0072, 0.1702, 0.1706, BORE_Y, "mag")

# The frame's under-rail: its strip and four teeth.
box("UnderRail", -0.0100, 0.0100, 0.0025, 0.0065, 0.068, 0.150, "mag")
for i in range(5):
    z = 0.071 + i * 0.017
    box("UnderRailTooth%d" % i, -0.0096, 0.0096, -0.0030, 0.0025, z, z + 0.0130, "mag")
# The takedown pin over the trigger, the slide stop's lever above the grip, the magazine's catch, the medallion.
disc("TakedownPin", 0.0050, 0.0124, 0.0141, 0.009, 0.020, "steel_light")
disc("SlideStopPin", 0.0045, 0.0130, 0.0143, 0.004, -0.012, "steel_light")
box("SlideStop", 0.0130, 0.0142, 0.0030, 0.0090, -0.038, -0.012, "steel_light")
disc("MagCatch", 0.0040, 0.0154, 0.0168, -0.010, -0.020, "steel_light")
for side, s in (("L", 1.0), ("R", -1.0)):
    disc("Medallion" + side, 0.0045, s * 0.0180, s * 0.0188, -0.045, -0.048, "steel")

# The hammer on its own node (WeaponView drops it on a shot, cocks it at the end of a reload): the pin at 0.002
# over the trigger and 0.076 back.
node("Hammer", pos=(0.0, 0.004, -0.074))
mesh("HammerSpur", "d_hammer", "mag", parent="Hammer")

# The slide: the bolt group (it cycles on shots and at the end of a reload; `travel` is read by WeaponView).
node("Bolt", travel=0.035)
mesh("Slide", "d_slide", "steel", parent="Bolt")
# The serrations: seven a side, chunky ribs a hair proud of the slab - at this art's flat shading a cut groove does
# not read, a rib does.
for side, s in (("L", 1.0), ("R", -1.0)):
    for i in range(9):
        z = -0.070 + i * 0.0038
        box("Serr%s%d" % (side, i), s * 0.0142, s * 0.0158, 0.018, 0.046, z, z + 0.0019, "steel", rot_x=-10.0,
            parent="Bolt")
# The rear sight: a base with the notch's two ears (their tops are the sights' line 0.0625) and two white dots.
box("RearSightBase", -0.0104, 0.0104, TOP, 0.0540, -0.070, -0.050, "steel", parent="Bolt")
box("RearSightEarL", 0.0030, 0.0104, 0.0540, 0.0625, -0.070, -0.054, "steel", parent="Bolt")
box("RearSightEarR", -0.0104, -0.0030, 0.0540, 0.0625, -0.070, -0.054, "steel", parent="Bolt")
box("RearSightDotL", 0.0048, 0.0062, 0.0558, 0.0572, -0.0705, -0.0700, "dot", parent="Bolt")
box("RearSightDotR", -0.0062, -0.0048, 0.0558, 0.0572, -0.0705, -0.0700, "dot", parent="Bolt")
# The ambidextrous safety: a pivot with its long arm along each side of the slide, its end rounded, the loaded dot.
for side, s in (("L", 1.0), ("R", -1.0)):
    disc("SafetyPivot" + side, 0.0072, s * 0.0142, s * 0.0172, 0.036, -0.044, "steel_light", parent="Bolt")
    box("SafetyArm" + side, s * 0.0146, s * 0.0168, 0.029, 0.040, -0.046, -0.020, "steel_light", parent="Bolt")
    disc("SafetyArmEnd" + side, 0.0058, s * 0.0146, s * 0.0168, 0.0345, -0.021, "steel_light", parent="Bolt")
    disc("SafetyDot" + side, 0.0018, s * 0.0149, s * 0.0151, 0.027, -0.052, "red", parent="Bolt")
# The ejection port on the slide's right: the dark opening with its lips, as if the chamber shows through it.
box("Port", -0.01490, -0.01470, 0.026, 0.046, -0.020, 0.014, "mag", parent="Bolt")
box("PortLipTop", -0.01505, -0.01475, 0.0460, 0.0475, -0.022, 0.016, "steel", parent="Bolt")
box("PortLipBottom", -0.01505, -0.01475, 0.0245, 0.0262, -0.022, 0.016, "steel", parent="Bolt")
box("PortLipFront", -0.01505, -0.01475, 0.0245, 0.0475, 0.014, 0.0158, "steel", parent="Bolt")
box("PortLipRear", -0.01505, -0.01475, 0.0245, 0.0475, -0.022, -0.0202, "steel", parent="Bolt")

# The magazine: its base plate at the heel, the body inside the grip; the node 0.11 m over and 0.015 behind the base.
node("Mags")
node("Deagle_Mag_7", "Mags", (0.0, 0.040, -0.070))
# The body along the grip's axis: the plate at the node's (0, -0.128, 0.010), its top at the magazine well's roof.
parts.append(("MagBody", "Mags/Deagle_Mag_7", "box", (0.024, 0.094, 0.040), (0.0, -0.084, 0.025), GRIP_RAKE, "mag"))
parts.append(("MagFollower", "Mags/Deagle_Mag_7", "box", (0.020, 0.006, 0.034), (0.0, -0.045, 0.039), GRIP_RAKE,
              "steel_light"))
# The base plate flat under the grip's heel with its little front lip.
parts.append(("BasePlate", "Mags/Deagle_Mag_7", "box", (0.030, 0.0075, 0.046), (0.0, -0.128, 0.010), 0.0, "mag"))
parts.append(("BaseLip", "Mags/Deagle_Mag_7", "box", (0.026, 0.0070, 0.008), (0.0, -0.128, 0.036), 0.0, "mag"))

f = lambda v: "%g" % round(v, 5)
res = []
for key, (albedo, metal, rough) in MATERIALS.items():
    res.append('[sub_resource type="StandardMaterial3D" id="mat_%s"]\nresource_name = "%s"\nalbedo_color = Color(%s, %s, %s, 1)\nmetallic = %s\nroughness = %s\n'
               % (key, key, f(albedo[0]), f(albedo[1]), f(albedo[2]), f(metal), f(rough)))
nodes = ['[node name="Deagle" type="Node3D"]\n']
for i, (name, parent, kind, params, c, rot, mat) in enumerate(parts):
    if kind == "cylx":  # the cylinder's Y axis turned onto X
        xform = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %s, %s, %s)" % (f(c[0]), f(c[1]), f(c[2]))
    else:
        rr = math.radians(rot)
        cr, sr = math.cos(rr), math.sin(rr)
        xform = "Transform3D(1, 0, 0, 0, %s, %s, 0, %s, %s, %s, %s, %s)" % (f(cr), f(-sr), f(sr), f(cr), f(c[0]), f(c[1]), f(c[2]))
    if kind == "node":
        nodes.append('\n[node name="%s" type="Node3D" parent="%s"]\ntransform = %s\n' % (name, parent, xform))
        if params is not None:  # travel: how far the slide goes back
            nodes.append("metadata/travel = %s\n" % f(params))
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
                   % (i, mat, f(params[2] if len(params) > 2 else params[0]), f(params[0]), f(params[1]), 16))
    nodes.append('\n[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("mesh_%d")\n' % (name, parent, xform, i))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    ext = "".join('[ext_resource type="ArrayMesh" path="res://prefabs/weapons/deagle_%s_mesh.tres" id="%s"]\n' % (m, m) for m in MESHES)
    out.write("[gd_scene format=3]\n\n" + ext + "\n" + "\n".join(res) + "\n" + "".join(nodes))
print("wrote %s: %d parts" % (OUT, len(parts)))
print("muzzle (0, %s, 0.172), rear sight (0, 0.0625, -0.070), front sight (0, 0.0625, 0.160)" % f(BORE_Y))



