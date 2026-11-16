"""The Desert Eagle from the owner's model: the game's parts and nodes, the magazine seated, the game's materials.

Run:  blender.exe --background --python vibe-of-duty-p/tools/make_deagle_glb.py -- <in.glb> <out.glb>

The owner's file (models_incoming/Desert eagle/, Sketchfab: Docs/MODELS.md) is a showcase: the gun with an empty
magazine in it, a loose .50 AE round, its case, an empty magazine and a full one standing about. The gun's parts are
the author's own meshes and empties (his names are Sketchfab's "Object_N"; his empties sit on the hammer's and the
trigger's pins). This script keeps the gun's parts, throws the showcase away and writes what WeaponView animates:
"Bolt" (the slide with the rear sight, the safety and the loaded-chamber dot; metadata "travel"), "Hammer", "Trigger",
"Mags/Deagle_Mag_7" (the full magazine, seated in the grip, its origin on its feed lips - WeaponView.mag_grip_point
counts 0.11 m down from it), and the frame, the barrel and the slide release in place.

Space: the file's is Blender's (the gun to +X, the shooter's left +Y, up +Z) and ten times life size (its glTF is in
decimetres); the game's is metres, the muzzle to +Z, up +Y, the shooter's left +X. The glTF exporter turns Blender's
B(p) = (x, -z, y) back into p, so every mesh is baked through TO_EXPORT once; from there on this script works in the
exporter's frame (its x the game's x, its z the game's y, its y the game's z reversed) and prints the game's numbers.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = os.path.abspath(ARGS[0])
OUT = os.path.abspath(ARGS[1])

# The file's Blender space -> the exporter's: a tenth of the size and the turn below (see the header).
TO_EXPORT = Matrix(((0.0, 0.1, 0.0, 0.0), (-0.1, 0.0, 0.0, 0.0), (0.0, 0.0, 0.1, 0.0), (0.0, 0.0, 0.0, 1.0)))
TRAVEL = 0.030       # m: the slide's run - what the 40 mm .50 AE case needs out of the chamber
FLOOR_SINK = 0.005   # m: the magazine's floor plate under the grip's bottom, as on the real thing

# The author's meshes by role. Thrown away: the loose round and its case (the game makes its own casings) and the two
# loose magazines standing about - the gun takes the full one (the file's empty one is a spare too).
PARTS = {
    "frame": ["Object_25"],
    "panels": ["Object_26"],
    "barrel": ["Object_16"],
    "front_sight": ["Object_17"],
    "slide": ["Object_19"],
    "rear_sight": ["Object_20"],
    "chamber_dot": ["Object_21"],
    "safety": ["Object_23"],
    "hammer": ["Object_28"],
    "trigger": ["Object_30"],
    "release": ["Object_32"],
    "mag_body": ["Object_12"],
    "mag_rounds": ["Object_13"],
    "mag_tips": ["Object_14"],
}
DROP = ["Object_4", "Object_5", "Object_7", "Object_9", "Object_10"]

# Material -> (sRGB colour, metallic, roughness). WeaponSkin reads the name: "polymer" is the fine grit, the rest the
# metal's mottling. The author's h-190 is black to the point of a hole in the dark, so the steel is lighter than his
# (a third of the way to the blockout's grey, which read).
MATERIALS = {
    "steel": ((0.40, 0.40, 0.42), 0.5, 0.42),
    "polymer": ((0.10, 0.10, 0.11), 0.0, 0.72),
    "mag": ((0.30, 0.30, 0.31), 0.5, 0.45),
    "brass": ((0.80, 0.64, 0.28), 0.85, 0.30),
    "copper": ((0.88, 0.48, 0.24), 0.90, 0.28),
    "red": ((0.62, 0.07, 0.06), 0.0, 0.5),  # the loaded-chamber mark on the safety
}
MAT_OF = {
    "frame": "steel", "panels": "polymer", "barrel": "steel", "front_sight": "steel", "slide": "steel",
    "rear_sight": "steel", "chamber_dot": "red", "safety": "steel", "hammer": "steel", "trigger": "steel",
    "release": "steel", "mag_body": "mag", "mag_rounds": "brass", "mag_tips": "copper",
}


def linear(c):
    """sRGB -> linear, what Blender's inputs want."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(key):
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    colour, metallic, roughness = MATERIALS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*(linear(c) for c in colour), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m


NODES = {}  # a node's own place in the exporter's frame: a mesh under it is moved by its turns, about its origin


def empty(name, parent, location=Vector()):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_size = 0.02
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = location
    NODES[name] = Vector(location)
    return ob


def attach(ob, parent, name):
    """Keeps the mesh where it is (the game's space is baked into it) and puts it under `parent`: its own place, so a
    turn of the node turns the mesh about the node's origin."""
    ob.parent = parent
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.location = -NODES[parent.name]
    ob.name = name
    return ob


def named(ob, name):
    """A part that stays put under the scene's root."""
    ob.name = name
    return ob


def game(p):
    """The exporter's frame -> the game's."""
    return Vector((p.x, p.z, -p.y))


def to_export(p):
    """The game's frame -> the exporter's."""
    return Vector((p.x, -p.z, p.y))


def points(role, space="export"):
    """The role's vertices (every mesh of it)."""
    out = []
    for ob in PARTS_OBJ[role]:
        out += [game(ob.matrix_world @ v.co) if space == "game" else (ob.matrix_world @ v.co) for v in ob.data.vertices]
    return np.array([tuple(p) for p in out])


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene

missing = [name for names in PARTS.values() for name in names if name not in bpy.data.objects]
if missing:
    sys.exit("the file has no %s" % ", ".join(missing))
PARTS_OBJ = {role: [bpy.data.objects[name] for name in names] for role, names in PARTS.items()}

# The author's empties on the hammer's and the trigger's pins, read before his groups go.
HAMMER_PIN = game((TO_EXPORT @ bpy.data.objects["deagle hammer_8"].matrix_world).translation)
TRIGGER_PIN = game((TO_EXPORT @ bpy.data.objects["deagle trigga_9"].matrix_world).translation)

# The file's space into the meshes; his groups, empties and the showcase then go.
for ob in [o for o in scene.objects if o.type == "MESH"]:
    bake = TO_EXPORT @ ob.matrix_world
    ob.parent = None
    ob.matrix_basis = Matrix.Identity(4)
    ob.data.transform(bake)
for name in DROP:
    bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
for ob in [o for o in scene.objects if o.type == "EMPTY"]:
    bpy.data.objects.remove(ob, do_unlink=True)
bpy.context.view_layer.update()

# The magazine: a .50 AE one is a straight box and the file's is lying about, so its own axes come off its vertices -
# the longest spread is its height, the rounds' tips point forward, and the rounds sit in its top half. Turned to the
# game's: its height up (+z here), its rounds forward (-y here).
body = points("mag_body")
centre = body.mean(axis=0)
_eigenvalues, _eigenvectors = np.linalg.eigh(np.cov((body - centre).T))
height, length, thickness = _eigenvectors.T[2], _eigenvectors.T[1], _eigenvectors.T[0]
if height[2] < 0.0:
    height = -height
if (points("mag_tips").mean(axis=0) - points("mag_rounds").mean(axis=0)) @ length < 0.0:
    length = -length
thickness = np.cross(height, length)
mag_turn = Matrix((tuple(thickness), tuple(-length), tuple(height))).to_4x4()
for role in ("mag_body", "mag_rounds", "mag_tips"):
    for ob in PARTS_OBJ[role]:
        ob.data.transform(mag_turn)

# Seated: the floor plate FLOOR_SINK under the grip's bottom face, the box square between the front and the back strap.
frame = points("frame")
bottom = frame[:, 2].min()
foot = frame[frame[:, 2] < bottom + 0.004]
well = foot[:, 1].mean()
body = points("mag_body")
low, high = body.min(axis=0), body.max(axis=0)
seat = Vector((-(low[0] + high[0]) * 0.5, well - (low[1] + high[1]) * 0.5, bottom - FLOOR_SINK - low[2]))
for role in ("mag_body", "mag_rounds", "mag_tips"):
    for ob in PARTS_OBJ[role]:
        ob.data.transform(Matrix.Translation(seat))
body = points("mag_body")
MAG_TOP = Vector((0.0, well, body[:, 2].max()))  # the feed lips, the exporter's frame

# What WeaponDB has to know, in the game's space (before the tree renames the meshes).
allparts = np.array([p for role in PARTS for p in points(role, "game").tolist()])
barrel = points("barrel", "game")
muzzle_face = barrel[barrel[:, 2] > barrel[:, 2].max() - 0.002]
rear = points("rear_sight", "game")
front = points("front_sight", "game")
print("gun     x %+.3f..%+.3f  y %+.3f..%+.3f  z %+.3f..%+.3f" % (
    allparts[:, 0].min(), allparts[:, 0].max(), allparts[:, 1].min(), allparts[:, 1].max(),
    allparts[:, 2].min(), allparts[:, 2].max()))
print("muzzle  %s  (x, y, z)" % (tuple(round(v, 4) for v in muzzle_face.mean(axis=0)),))
print("sights  rear %s  front %s  (x, y, z)" % (
    (0.0, round(rear[:, 1].max(), 4), round(rear[:, 2].mean(), 4)),
    (0.0, round(front[:, 1].max(), 4), round(front[:, 2].mean(), 4))))
print("grip    bottom y %+.4f  well middle z %+.4f  (game)" % (points("frame", "game")[:, 1].min(),
                                                              -float(well)))
print("pins    hammer %s  trigger %s  (game)" % (
    tuple(round(v, 4) for v in HAMMER_PIN), tuple(round(v, 4) for v in TRIGGER_PIN)))
print("mag     node %s  floor plate y %+.4f  (game)" % (
    tuple(round(v, 4) for v in game(MAG_TOP)), float(body[:, 2].min())))

# The tree, as the other weapons': the parts at the glTF scene's top (Godot's root then holds them directly, so
# WeaponView finds "Bolt" by name, not two levels down). "Bolt" runs back with every shot - the slide, the rear sight,
# the safety and the chamber dot with it - the hammer falls, the trigger goes back, the magazine comes off its catch.
named(PARTS_OBJ["frame"][0], "Frame")
named(PARTS_OBJ["panels"][0], "GripPanels")
named(PARTS_OBJ["barrel"][0], "Barrel")
named(PARTS_OBJ["front_sight"][0], "FrontSight")
named(PARTS_OBJ["release"][0], "SlideRelease")
bolt = empty("Bolt", None)
bolt["travel"] = TRAVEL
attach(PARTS_OBJ["slide"][0], bolt, "Slide")
attach(PARTS_OBJ["rear_sight"][0], bolt, "RearSight")
attach(PARTS_OBJ["safety"][0], bolt, "Safety")
attach(PARTS_OBJ["chamber_dot"][0], bolt, "ChamberDot")
hammer = empty("Hammer", None, to_export(HAMMER_PIN))
attach(PARTS_OBJ["hammer"][0], hammer, "HammerBody")
trigger = empty("Trigger", None, to_export(TRIGGER_PIN))
attach(PARTS_OBJ["trigger"][0], trigger, "TriggerBlade")
mags = empty("Mags", None)
seated = empty("Deagle_Mag_7", mags, MAG_TOP)
attach(PARTS_OBJ["mag_body"][0], seated, "MagBody")
attach(PARTS_OBJ["mag_rounds"][0], seated, "MagRounds")
attach(PARTS_OBJ["mag_tips"][0], seated, "MagTips")

for role, key in MAT_OF.items():
    for ob in PARTS_OBJ[role]:
        ob.data.materials.clear()
        ob.data.materials.append(material(key))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True, export_extras=True,
                          export_cameras=False, export_lights=False, export_animations=False)
print("wrote %s" % OUT)
