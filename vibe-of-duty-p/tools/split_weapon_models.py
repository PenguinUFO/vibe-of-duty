"""Splits the new weapon models (Docs/MODELS.md) into the parts WeaponView animates.

Run (Blender 4.3; FBX import breaks in 5.2 on lights, Docs/MODELS.md), from the repo root:
  "C:\\Program Files\\Blender Foundation\\Blender 4.3\\blender.exe" --background ^
      --python vibe-of-duty-p/tools/split_weapon_models.py -- ak mp7 luger

Every weapon: the game's GLB is imported (geometry and materials stay exactly as they are, so every
WeaponDef point - muzzle, sights, hands - keeps its place), the artist's source (models_incoming/
<id>/<zip>: bones and weights) is fitted onto it, every game vertex takes the dominant bone of its
nearest source vertex, and the mesh splits by bone into the tree WeaponView reads: "Bolt" (extras
"travel"), "Handle", "Mags/<id>_Mag_<n>", "Hammer", "Trigger", "Toggle/LinkRear|LinkFront|Breech",
"Lever", "Drum", "Shell" - plus the module variant groups of weapon_db.gd's model_variants
("Muzzle/...", "Stock/...", "Sights/...", "Foregrip/..."). Parts the sources lack (suppressor cans,
the RPK magazine, the TM08 snail, the board stock, shells) are built in the old blockouts'
dimensions (tools/make_*_blockout.py). Writes assets/models/<id>/<id>.glb.

The guns whose source has no bones (PDW, Contender, Striker - their meshes are separate objects in
the game GLB already) are only regrouped. Prints diagnostics: the fit's residual, every part's box.
"""
import json
import math
import os
import re
import struct
import sys
import subprocess
import zipfile

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils import kdtree

ARGS = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if not a.startswith("--")]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # the repo root
CACHE = os.path.join(os.environ.get("TEMP", "/tmp"), "vibe_split_src")
TAU = math.tau

# The blockouts' materials (tools/make_*_blockout.py): names WeaponSkin reads (metal/polymer/wood).
MATERIALS = {
    "steel": ((0.13, 0.13, 0.14), 0.55, 0.45),
    "steel_light": ((0.24, 0.24, 0.25), 0.6, 0.4),
    "steel_dark": ((0.07, 0.07, 0.075), 0.5, 0.5),
    "black": ((0.1, 0.1, 0.11), 0.55, 0.45),
    "polymer": ((0.08, 0.08, 0.085), 0.0, 0.75),
    "can": ((0.1, 0.1, 0.105), 0.4, 0.55),
    "mag": ((0.62, 0.27, 0.1), 0.0, 0.55),     # bakelite
    "wood": ((0.45, 0.24, 0.1), 0.0, 0.7),
    "hull": ((0.62, 0.1, 0.08), 0.0, 0.5),
    "brass": ((0.62, 0.46, 0.2), 0.7, 0.35),
    "rubber": ((0.05, 0.05, 0.05), 0.0, 0.85),   # the butt pads (tools/make_val_blockout.py)
    "tube": ((0.08, 0.08, 0.085), 0.5, 0.3),     # the CAR stock's glossy vinyl sleeve (tools/make_m16_blockout.py)
}


def G(p):
    """Game (glb) coords -> Blender's as the glTF importer lays them (Y-up turned into Z-up)."""
    return Vector((p[0], -p[2], p[1]))


def material(key):
    if key not in bpy.data.materials:
        colour, metallic, roughness = MATERIALS[key]
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        # The blockout colours are sRGB (a .tscn Color), Blender's inputs are linear.
        bsdf.inputs["Base Color"].default_value = (*(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
                                                     for c in colour), 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
    return bpy.data.materials[key]


# ------------------------------------------------------------------ the scene's bookkeeping

TREE = []   # every object that stays in the exported GLB


def keep(ob):
    TREE.append(ob)
    return ob


def fresh_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    del TREE[:]


# ------------------------------------------------------------------ source loading


def source_path(folder, zip_name, inner):
    """models_incoming/<folder>/<zip_name> -> the extracted <inner>, unzipped into a cache."""
    out = os.path.join(CACHE, folder)
    path = os.path.join(out, inner)
    if not os.path.exists(path):
        os.makedirs(out, exist_ok=True)
        with zipfile.ZipFile(os.path.join(ROOT, "models_incoming", folder, zip_name)) as z:
            z.extractall(out)
    return path


def load_file(path, game_obs):
    """Loads a source beside the game import: .blend appends, FBX/GLB import into the scene."""
    ext = os.path.splitext(path)[1].lower()
    if ext == ".blend":
        with bpy.data.libraries.load(path, link=False) as (data_from, data_to):
            data_to.objects = data_from.objects
        for ob in bpy.data.objects:
            if ob.users_scene is None or not ob.users_scene:
                try:
                    bpy.context.scene.collection.objects.link(ob)
                except RuntimeError:
                    pass
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o.type == "MESH" and o.users_scene and o not in game_obs]


def bake(obs):
    """Applies every modifier (armatures at their rest pose) and matrix_world into the meshes."""
    for ob in obs:
        for mod in list(ob.modifiers):
            try:
                bpy.context.view_layer.objects.active = ob
                bpy.ops.object.modifier_apply(modifier=mod.name)
            except RuntimeError:
                pass
    bpy.context.view_layer.update()
    for ob in obs:
        if ob.type != "MESH" or not ob.data.vertices:
            continue
        ob.data.transform(ob.matrix_world)
        ob.matrix_world = Matrix.Identity(4)


# ------------------------------------------------------------------ the fit


def umeyama(P, Q):
    cp, cq = P.mean(axis=0), Q.mean(axis=0)
    H = (P - cp).T @ (Q - cq)
    U, _S, Vt = np.linalg.svd(H)
    R = Vt.T @ U.T
    if np.linalg.det(R) < 0:
        Vt[-1] *= -1
        R = Vt.T @ U.T
    s = np.trace(R.T @ H) / max(((P - cp) ** 2).sum(), 1e-12)
    t = cq - R @ cp * s
    return R, s, t


def nearest(kd, pts):
    return np.array([kd.find(tuple(p))[1] for p in pts], dtype=np.int64)


def axis_rotations():
    """All 24 proper rotations that align the source's axes onto the game's (permutation x even signs)."""
    import itertools
    out = []
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((1.0, -1.0), repeat=3):
            m = np.zeros((3, 3))
            for row in range(3):
                m[row, perm[row]] = signs[row]
            if np.linalg.det(m) > 0:
                out.append(m)
    return out


def strip_suffix(name):
    """Blender's dedup suffix ("Material.011", appended on a name collision) back one level."""
    head, dot, tail = name.rpartition(".")
    return head if dot and tail.isdigit() and not name.endswith((".001", ".010")) or True else name


def centroids_of(obs):
    """Material name -> vertex cloud (all faces of that material), over every mesh."""
    acc = {}
    for ob in obs:
        me = ob.data
        per = {}
        for poly in me.polygons:
            mat = me.materials[poly.material_index] if me.materials and \
                poly.material_index < len(me.materials) else None
            per.setdefault(mat.name if mat else "?", []).extend(
                tuple(me.vertices[vi].co) for vi in poly.vertices)
        for name, pts in per.items():
            acc.setdefault(name, []).extend(pts)
    return {k: np.array(v) for k, v in acc.items()}


def fit_named(ga, sa, tag):
    """Rotation (uniform scale) + translation from the shared materials' centroids.

    Both dicts come from clean scenes, so the names match exactly.
    Returns (RM, t_vec) or None when fewer than 3 names are shared.
    """
    common = [n for n in sa if n in ga]
    if len(common) < 3:
        print("  %s: only %d shared material names (%s)" % (tag, len(common),
                                                            ", ".join(sorted(sa))[:80]))
        return None
    P = np.array([sa[n].mean(axis=0) for n in common])
    Q = np.array([ga[n].mean(axis=0) for n in common])
    R, s, t = umeyama(P, Q)
    res = np.linalg.norm(Q - (P @ R.T * s + t), axis=1)
    print("  %s: %d mats, scale %.5f, centroid resid mean %.6f max %.6f" % (
        tag, len(common), s, res.mean(), res.max()))
    if res.max() > 0.02 * max(abs(s), 1e-9):  # 2% of the stage's own scale (units differ per file)
        print("  %s: centroids do not correspond - rejecting" % tag)
        return None
    RM = Matrix((tuple(R[0] * s), tuple(R[1] * s), tuple(R[2] * s)))
    return RM, Vector(t)


def compose(fit2, fit1):
    """game <- skf <- src: (RM2, t2) then (RM1, t1)."""
    RM1, t1 = fit1
    RM2, t2 = fit2
    return RM1 @ RM2, RM1 @ t2 + t1


def fit_stretch(A, B, iters=5):
    """A ~ M @ B where M turns the source onto the game's axes and stretches per axis.

    The stretch sits before the turn (along the source's axes) or after (along the game's);
    both orders are tried over every axis permutation x sign (det + 1), the scale and the
    translation fitted by least squares over the nearest pairs. Returns (RM, t_vec, res).
    """
    ca, cb = A.mean(axis=0), B.mean(axis=0)
    Bc = B - cb
    seeds = axis_rotations()
    # the principal axes too: a source whose root turn is not axis-aligned still lines up
    _wa, va = np.linalg.eigh(np.cov((A - ca).T))
    _wb, vb = np.linalg.eigh(np.cov(Bc.T))
    ba, bb = va[:, ::-1].T, vb[:, ::-1].T
    for flip in ((1, 1, 1), (1, -1, -1), (-1, 1, -1), (-1, -1, 1)):
        seeds.append(bb.T @ np.diag(flip) @ ba)
    best = None
    for R0 in seeds:
        BR = Bc @ R0.T
        for order in ("game", "src"):
            span = np.maximum(np.abs(BR).max(axis=0) * 2.0, 1e-9)
            s = (A.max(axis=0) - A.min(axis=0)) / span  # the spans' ratio: sane from the start
            t = ca - BR.mean(axis=0) * s
            for _ in range(iters):
                if order == "game":
                    moved = BR * s + t
                    near = nearest(build_kd(moved), A)
                    Pa, Qa = BR[near], A
                    pm, qm = Pa.mean(axis=0), Qa.mean(axis=0)
                    s = ((Pa - pm) * (Qa - qm)).sum(axis=0) / np.maximum(((Pa - pm) ** 2).sum(axis=0), 1e-12)
                    t = qm - pm * s
                else:
                    moved = (Bc * s) @ R0.T + t
                    near = nearest(build_kd(moved), A)
                    Qr = (A - t) @ R0  # every pair's game side, back in the source's axes
                    pm, qm = Bc[near].mean(axis=0), Qr.mean(axis=0)
                    s = ((Bc[near] - pm) * (Qr - qm)).sum(axis=0) / \
                        np.maximum(((Bc[near] - pm) ** 2).sum(axis=0), 1e-12)
                    t = A.mean(axis=0) - (Bc[near] * s).mean(axis=0) @ R0.T
            moved = ((Bc @ R0.T) * s + t) if order == "game" else (Bc * s) @ R0.T + t
            kd = build_kd(moved)
            sample = A[:min(len(A), 3000)]
            d = sample - moved[nearest(kd, sample)]
            score = np.linalg.norm(d, axis=1).mean()
            if best is None or score < best[0]:
                best = (score, R0.copy(), s.copy(), t.copy(), order)
    _score, R0, s, t, order = best
    moved = (Bc * s) @ R0.T + t if order == "src" else (Bc @ R0.T) * s + t
    kd = build_kd(moved)
    res = np.array([kd.find(tuple(p))[2] for p in A])
    R = Matrix((tuple(R0[0]), tuple(R0[1]), tuple(R0[2])))
    if order == "game":
        RM = Matrix.Diagonal(Vector(s)) @ R
    else:
        RM = R @ Matrix.Diagonal(Vector(s))
    t_vec = Vector(t) - RM @ Vector(cb)
    return RM, t_vec, res


def stretch_matrix(R0, s, t):
    """The per-axis-scale fit as a Blender 4x4 (verts in source space -> game space)."""
    m = np.eye(4)
    m[:3, :3] = (R0 * s).T   # rows: the scaled rotation
    m[:3, 3] = t
    return Matrix(m.tolist())


def fit_rigid(A, B):
    """A (game) ~ R @ B (source) * s + t: axis seeds, nearest-pair refinement (fallback)."""
    ca, cb = A.mean(axis=0), B.mean(axis=0)
    span_a = np.linalg.norm(A - ca, axis=1).mean()
    span_b = np.linalg.norm(B - cb, axis=1).mean()
    s0 = span_a / max(span_b, 1e-9)
    best = None
    for R0 in axis_rotations():
        B0 = (R0 @ (B - cb).T).T * s0
        t0 = ca - B0.mean(axis=0)
        moved = B0 + t0
        kd = build_kd(moved)
        sample = A[:min(len(A), 3000)]
        d = sample - moved[nearest(kd, sample)]
        score = np.linalg.norm(d, axis=1).mean()
        if best is None or score < best[0]:
            best = (score, R0, s0, t0)
    _score, R, s, t = best
    for _ in range(12):
        kd = build_kd(B @ R.T * s + t)
        R, s, t = umeyama(B[nearest(kd, A)], A)
    kd = build_kd(B @ R.T * s + t)
    res = np.array([kd.find(tuple(p))[2] for p in A])
    return R, s, t, res


def build_kd(pts):
    kd = kdtree.KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    return kd


# ------------------------------------------------------------------ splitting by bones


def source_points(src_obs, RM, t_vec):
    """Every source vertex (moved onto the game mesh) with its dominant bone."""
    pts, bones = [], []
    for ob in src_obs:
        names = [g.name for g in ob.vertex_groups]
        for v in ob.data.vertices:
            top, who = 0.0, ""
            for g in v.groups:
                if g.weight > top:
                    top, who = g.weight, names[g.group]
            pts.append(RM @ v.co + t_vec)
            bones.append(who)
    return build_kd(pts), bones


def split_by_bones(game_obs, kd, bones, roles):
    """Splits every game mesh by the dominant bone of its nearest source vertex.

    Returns {role: [mesh objects]} (world space, materials kept); the role "drop" deletes faces.
    """
    out = {}
    for ob in game_obs:
        me = ob.data
        labels = np.array([roles.get(bones[kd.find(v.co)[1]], "body") if bones[kd.find(v.co)[1]] else "body"
                            for v in me.vertices], dtype=object)
        face_role = np.zeros(len(me.polygons), dtype=object)
        for pi, poly in enumerate(me.polygons):
            votes = {}
            for vi in poly.vertices:
                votes[labels[vi]] = votes.get(labels[vi], 0) + 1
            face_role[pi] = max(votes, key=votes.get)
        for role in sorted(set(face_role)):
            if role == "drop":
                continue
            part = build_part(me, face_role == role)
            if part:
                out.setdefault(role, []).append(part)
        bpy.data.objects.remove(ob, do_unlink=True)
    return out


def build_part(me, face_mask):
    verts_map, nv, faces = {}, [], []
    for fi, poly in enumerate(me.polygons):
        if not face_mask[fi]:
            continue
        idxs = []
        for vi in poly.vertices:
            if vi not in verts_map:
                verts_map[vi] = len(nv)
                nv.append(me.vertices[vi].co.copy())
            idxs.append(verts_map[vi])
        faces.append((idxs, poly.material_index, poly.use_smooth))
    if not faces:
        return None
    new = bpy.data.meshes.new("part")
    new.from_pydata(nv, [], [f[0] for f in faces])
    for slot in me.materials:
        new.materials.append(slot)
    for i, f in enumerate(faces):
        new.polygons[i].material_index = f[1]
        new.polygons[i].use_smooth = f[2]
    new.validate()
    new.update()
    ob = bpy.data.objects.new("part", new)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------ the node tree


def empty(name, location, parent=None):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_size = 0.01
    ob.location = location
    bpy.context.scene.collection.objects.link(ob)
    if parent:
        ob.parent = parent
    return keep(ob)


def attach(ob, node, index):
    """A world-space mesh under `node`: a turn of the node turns the mesh about the node's origin."""
    ob.parent = node
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.location = -node.location
    ob.name = "%s_%d" % (ob.name.split(".")[0][:16], index)
    return keep(ob)


def group(name, parent=None):
    return empty(name, Vector((0, 0, 0)), parent)


def child_of(parent, name):
    """A named child: the children's order is alphabetical, not the creation's - never index it. Blender suffixes
    repeated names (Hider.001); write_glb strips them back off on export."""
    for ob in parent.children:
        if ob.name == name or (ob.name.startswith(name + ".") and ob.name[len(name) + 1:].isdigit()):
            return ob
    sys.exit("  no child %r under %s" % (name, parent.name))


# ------------------------------------------------------------------ generated shapes (game coords)


def tube(name, profile, x, y, mat, parent=None, segments=16, origin=None):
    """A lathe along the game +Z at (x, y): `profile` = [(radius, z_game), ...] closed by the ends."""
    at = origin if origin else (parent.location if parent else Vector((0, 0, 0)))
    verts, faces = [], []
    for r, z in profile:
        for i in range(segments):
            a = TAU * i / segments
            verts.append(at + G(Vector((x + r * math.cos(a), y + r * math.sin(a), z))))
    for k in range(len(profile) - 1):
        for i in range(segments):
            a, b = k * segments + i, k * segments + (i + 1) % segments
            c, d = (k + 1) * segments + (i + 1) % segments, (k + 1) * segments + i
            faces.append((a, b, c, d))
    for i in range(segments):  # end caps (flat: PSX)
        a, b = i, (i + 1) % segments
        last = (len(profile) - 1) * segments
        faces.append((a, b))
        faces.append((last + b, last + a))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    recalc(me)
    ob = bpy.data.objects.new(name, me)
    me.materials.append(material(mat) if isinstance(mat, str) else mat)
    bpy.context.scene.collection.objects.link(ob)
    if parent:
        ob.parent = parent
        ob.matrix_parent_inverse = Matrix.Identity(4)
    return keep(ob)


def box(name, x0, x1, y0, y1, z0, z1, mat, parent=None, origin=None, local=False):
    """A box in game coords (or the node's local Blender coords with `local`)."""
    at = Vector((0, 0, 0))
    if not local:
        at = origin if origin else (parent.location if parent else Vector((0, 0, 0)))
    corners = []
    for x in (x0, x1):
        for y in (y0, y1):
            for z in (z0, z1):
                corners.append(Vector((x, y, z)) if local else at + G(Vector((x, y, z))))
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(c) for c in corners], [], [
        (0, 2, 3, 1), (4, 5, 7, 6), (0, 4, 6, 2), (1, 3, 7, 5), (0, 1, 5, 4), (2, 6, 7, 3)])
    recalc(me)
    ob = bpy.data.objects.new(name, me)
    me.materials.append(material(mat) if isinstance(mat, str) else mat)
    bpy.context.scene.collection.objects.link(ob)
    if parent:
        ob.parent = parent
        ob.matrix_parent_inverse = Matrix.Identity(4)
    return keep(ob)


def prism(name, pts, hw, mat, x=0.0, parent=None):
    """A flat-sided prism: a (z, y) polygon swept across x -hw..+hw (PSX: flat end caps)."""
    verts, faces = [], []
    for sgn in (-1.0, 1.0):
        for z, y in pts:
            verts.append(tuple(G(Vector((x + sgn * hw, y, z)))))
    n = len(pts)
    for i in range(n):
        a, b = i, (i + 1) % n
        faces.append((a, b, n + b, n + a))
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(range(n, 2 * n)))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    recalc(me)
    ob = bpy.data.objects.new(name, me)
    me.materials.append(material(mat) if isinstance(mat, str) else mat)
    bpy.context.scene.collection.objects.link(ob)
    if parent:
        ob.parent = parent
        ob.matrix_parent_inverse = Matrix.Identity(4)
    return keep(ob)


def recalc(me):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()


def copy_transformed(ob, matrix, name):
    """A copy of `ob` with `matrix` (Blender space) baked into the mesh."""
    new_me = ob.data.copy()
    new_me.transform(matrix)
    new = bpy.data.objects.new(name, new_me)
    bpy.context.scene.collection.objects.link(new)
    return keep(new)


def stretch_copy(obs, origin_blender, direction_blender, factor, name):
    """A longer/shorter magazine: the meshes stretched `factor` along `direction` from `origin`."""
    out = []
    for i, ob in enumerate(obs):
        me = ob.data.copy()
        d = direction_blender.normalized()
        m = Matrix.Translation(origin_blender) @ Matrix.Translation(d * 0.0)
        verts = [v.co.copy() for v in me.vertices]
        for j, v in enumerate(verts):
            along = (v - origin_blender).dot(d)
            me.vertices[j].co = v + d * along * (factor - 1.0)
        new = bpy.data.objects.new("%s_%d" % (name, i), me)
        bpy.context.scene.collection.objects.link(new)
        out.append(new)
    return [keep(o) for o in out]


# ------------------------------------------------------------------ shared assembly pieces


def bolt_node(parts, travel, origin):
    node = empty("Bolt", G(origin))
    node["travel"] = travel
    for i, ob in enumerate(parts.get("bolt", [])):
        attach(ob, node, i)
    return node


def mag_node(group_parent, name, origin, meshes):
    n = empty(name, G(origin), group_parent)
    for i, ob in enumerate(meshes):
        attach(ob, n, i)
    return n


def handle_node(parts, origin, bone=None):
    if not parts.get("handle") and not bone:
        return None
    node = empty("Handle", G(origin))
    for i, ob in enumerate(parts.get("handle", [])):
        attach(ob, node, i)
    return node


def mags_group(parts, entries):
    """entries: [(role, node_name, origin_game)] - every mag node holds its meshes."""
    g = group("Mags")
    for role, name, origin in entries:
        if not parts.get(role):
            continue
        n = empty(name, G(origin), g)
        for i, ob in enumerate(parts[role]):
            attach(ob, n, i)
    return g


def root_static(parts, roles):
    """Small named parts straight under the model's root (Selector, Safety, MagRelease...)."""
    out = []
    for role in roles:
        for i, ob in enumerate(parts.get(role, [])):
            ob.name = "%s_%d" % (role, i) if len(parts[role]) > 1 else role
            keep(ob)
            out.append(ob)
    return out


def variant_group(name, children):
    """A group whose children are variant nodes; each holds its meshes (or is empty: a baked part)."""
    g = group(name)
    for child_name, meshes in children:
        n = empty(child_name, Vector((0, 0, 0)), g)
        for i, ob in enumerate(meshes or []):
            attach(ob, n, i)
    return g


def part_boxes(parts):
    for role in sorted(parts):
        pts = [tuple(v.co) for ob in parts[role] for v in ob.data.vertices]
        if not pts:
            print("  part %-18s (no vertices)" % role)
            continue
        a = np.array(pts)
        lo = Gi(Vector(a.min(axis=0)))
        hi = Gi(Vector(a.max(axis=0)))
        print("  part %-18s %-2d meshes  x %+.3f..%+.3f  y %+.3f..%+.3f  z %+.3f..%+.3f" % (
            role, len(parts[role]), lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))


def Gi(p):
    return Vector((p.x, p.z, -p.y))


# ------------------------------------------------------------------ the weapons

SRC = {  # weapon id -> (models_incoming folder, zip, the file inside)
    "ak": ("ak", "low-poly-ak-47-type-2.zip", "source/Ak47.blend"),
    "luger": ("luger", "low-poly-p08-luger.zip", "source/P08 Luger.blend"),
    "aug": ("aug", "low-poly-aug-a1.zip", "source/Aug A1.blend"),
    "striker": ("striker", "low-poly-armsel-striker.zip", "source/Armsel Striker.blend"),
    "groza": ("groza", "low-poly-ots-14-groza-1.zip", "source/Groza.fbx"),
    "val": ("val", "low-poly-as-val.zip", "source/AS VAL.fbx"),
    "mk14": ("mk14", "low-poly-mk14-ebr.zip", "source/M14 EBR.fbx"),
    "mp7": ("mp7", "low-poly-hk-mp7.zip", "source/HK MP7.fbx"),
    "p90": ("p90", "low-poly-fn-p90.zip", "source/FN P90.fbx"),
    "winchester": ("winchester", "low-poly-winchester-1887.zip", "source/Winchester 1887.fbx"),
    "m16": ("m16", "low-poly-m16.zip", "source/M16A1.fbx"),
}

SKF = {  # the Sketchfab-converted GLB the game's GLB came from (the fit's bridge; junk meshes drop)
    "ak": ("ak", "low-poly_ak-47_type_2.glb"),
    "luger": ("luger", "low-poly_p08_luger.glb"),
    "aug": ("aug", "low-poly_aug_a1.glb"),
    "groza": ("groza", "low-poly_ots-14_groza_1.glb"),
    "val": ("val", "low-poly_as_val.glb"),
    "mk14": ("mk14", "low-poly_mk14_ebr.glb"),
    "mp7": ("mp7", "low-poly_hk_mp7.glb"),
    "p90": ("p90", "low-poly_fn_p90.glb"),
    "winchester": ("winchester", "low-poly_winchester_1887.glb"),
    "m16": ("m16", "low-poly_m16.glb"),
}

# ------------------------------------------------------------------ per-weapon configs

# Bone -> role. Roles: "body" (root), "bolt", "handle", "trigger", "hammer", "lever",
# "toggle:LinkRear|LinkFront|Breech", "mag:<name>", "stock:<name>", "foregrip:<name>",
# "Selector"/"Safety"/... (a named static part), "drop" (the face goes away).
WEAPONS = {
    "ak": dict(src=SRC["ak"], travel=0.08, handle_empty=True, roles={
        "body": "body", "bolt": "bolt", "selector": "Selector", "mag release": "MagRelease",
        "mag": "mag:AK_Mag_30", "bullets": "mag:AK_Mag_30", "bullet": "drop"}),
    "pdw": dict(src=None, travel=0.045, handle_empty=True, regroup={
        "barrel_idw_0_001": "body", "boltcarrier_idw_0_001": "bolt",
        "charging_handle_idw_0_001": "bolt", "grip_safety_idw_0_001": "body",
        "mag_follower_idw_0_001": "mag:PDW_Mag_32", "magazine_idw_0_001": "mag:PDW_Mag_32",
        "magrelease_idw_0_001": "MagRelease", "rail_idw_0_001": "body", "reciever_idw_0_001": "body",
        "stock_idw_0_001": "stock:Extended", "supressor_idw_0_001": "muzzle:Suppressor",
        "trigger_idw_0_001": "trigger", "triggerfrontleft_idw_0_001": "body",
        "triggerguardright_idw_0_001": "body", "upper_idw_0_001": "body"}),
    "luger": dict(src=SRC["luger"], roles={
        "arm1": "toggle:LinkRear", "arm2": "toggle:LinkFront", "bolt": "toggle:Breech",
        "slide": "body", "safety": "Safety", "mag": "mag:Luger_Mag_8",
        "bullets": "mag:Luger_Mag_8", "bullet": "drop", "body": "body"}),
    "mp7": dict(src=SRC["mp7"], travel=0.04, roles={
        "body": "body", "bolt": "bolt", "charginghandle": "handle", "mag": "mag:MP7_Mag_40",
        "bullet": "drop", "boltrelease": "BoltRelease", "selector": "Selector",
        "stock": "stock:Extended", "foregrip": "foregrip:Unfolded"}),
    "contender": dict(src=None, regroup={
        "barrel_short": "break", "front_sights": "break", "rear_sights": "break",
        "handguard_pistol": "break", "body": "body", "grip_pistol": "body",
        "trigger_guard": "body", "hammer": "hammer", "trigger_contender": "trigger",
        "bullet": "round"}),
    "winchester": dict(src=SRC["winchester"], roles={
        "body": "body", "lever": "lever", "hammer": "hammer"}),
    "mk14": dict(src=SRC["mk14"], travel=0.09, resid_gate=0.008,   # the game's static parts
        # were nudged up to ~8 mm; the animated ones still refine to under 3 mm
        roles={
        "body": "body", "bolt": "bolt", "charginghandle": "handle",
        "mag": "mag:Mk14_Mag_20", "bullets": "mag:Mk14_Mag_20", "bullet": "drop",
        "boltrelease": "BoltRelease", "magrelease": "MagRelease", "safety": "Safety",
        "selector": "Selector", "stock": "body", "moving thing": "body"}),
    "p90": dict(src=SRC["p90"], travel=0.08, roles={
        "body": "body", "charginghandle": "handle", "bolt": "bolt",
        "mag": "mag:P90_Mag_50", "bullets": "mag:P90_Mag_50", "bullet": "drop",
        "selector": "Selector", "magrelease": "MagRelease"}),
    "aug": dict(src=SRC["aug"], travel=0.08, roles={
        "body": "body", "charginghandle": "handle", "bolt": "bolt",
        "mag": "mag:AUG_Mag_30", "bullet": "drop", "magrelease": "MagRelease",
        "trigger": "trigger", "safety": "Safety"}),
    "m16": dict(src=SRC["m16"], travel=0.08, roles={
        "body": "body", "charginghandle": "handle", "bolt": "bolt",
        "mag": "mag:M16_Mag_30", "bullets": "mag:M16_Mag_30", "bullet": "drop",
        "selector": "Selector", "boltrelease": "BoltRelease", "dustcover": "DustCover"}),
    "groza": dict(src=SRC["groza"], travel=0.08, handle_empty=True, roles={
        "body": "body", "bolt": "bolt", "mag": "mag:Groza_Mag_30",
        "bullets": "mag:Groza_Mag_30", "bullet": "drop", "magrelease": "MagRelease",
        "safety": "Safety"}),
    "val": dict(src=SRC["val"], travel=0.08, handle_empty=True, roles={
        "body": "body", "bolt": "bolt", "selector": "Selector", "safety": "Safety",
        "magrelease": "MagRelease", "mag": "mag:Val_Mag_20", "bullets": "mag:Val_Mag_20",
        "bullet": "drop"}),
    "striker": dict(src=None, regroup={
        "cylinder_021": "drum", "cube_032": "stock:Extended"}),
}

# Regroup-only weapons match meshes by their normalized name (dots and spaces to underscores) with
# these prefixes; anything unmatched stays "body". Written separately so the map stays readable.
REGROUP_PREFIX = {
    "contender": [("barrel_short", "break"), ("front_sights", "break"), ("rear_sights", "break"),
                  ("handguard_pistol", "break"), ("body", "body"), ("grip_pistol", "body"),
                  ("trigger_guard", "body"), ("hammer", "hammer"), ("trigger_contender", "trigger"),
                  ("bullet", "round")],
    "striker": [("cylinder_021", "drum"), ("cube_032", "stock:Extended")],
    "pdw": [],
}


def norm(name):
    return name.replace(".", "_").replace(" ", "_").replace("?", "").lower()


def regroup_parts(cfg, weapon_id):
    out = {}
    for ob in [o for o in bpy.data.objects if o.type == "MESH" and o.users_scene]:
        n = norm(ob.name)
        role = cfg.get("regroup", {}).get(n)
        if role is None:
            for prefix, want in REGROUP_PREFIX.get(weapon_id, []):
                if n.startswith(prefix):
                    role = want
                    break
        out.setdefault(role or "body", []).append(ob)
    return out


# ------------------------------------------------------------------ bone helpers


def bone_frames(src_obs):
    """{bone: (head, tail)} in the source's Blender space, read before the bake kills the modifier."""
    frames = {}
    for ob in src_obs:
        for mod in ob.modifiers:
            if mod.type == "ARMATURE" and mod.object:
                arm = mod.object
                for bone in arm.data.bones:
                    frames.setdefault(bone.name, (arm.matrix_world @ bone.head_local,
                                                   arm.matrix_world @ bone.tail_local))
                break
    return frames


def bone_map(frames, RM, t_vec):
    """The fitted transform onto the bones: {name: (head, tail)} in Blender space."""
    return {name: (RM @ head + t_vec, RM @ tail + t_vec) for name, (head, tail) in frames.items()}


# ------------------------------------------------------------------ positional cuts


def cut_boxes(obs, boxes):
    """(inside, outside): faces whose every vertex is inside one of the boxes (game coords)."""
    inside, outside = [], []
    for ob in obs:
        me = ob.data
        in_v = np.zeros(len(me.vertices), dtype=bool)
        for i, v in enumerate(me.vertices):
            p = Gi(v.co)
            for x0, x1, y0, y1, z0, z1 in boxes:
                if x0 <= p.x <= x1 and y0 <= p.y <= y1 and z0 <= p.z <= z1:
                    in_v[i] = True
                    break
        mask = np.array([all(in_v[vi] for vi in poly.vertices) for poly in me.polygons])
        hit, miss = build_part(me, mask), build_part(me, ~mask)
        if hit:
            inside.append(hit)
        if miss:
            outside.append(miss)
        bpy.data.objects.remove(ob, do_unlink=True)
    return inside, outside


def keep_root(parts, roles):
    """Named parts at the model's root (the body and the small bits)."""
    for role in roles:
        for i, ob in enumerate(parts.get(role, [])):
            ob.name = role if len(parts[role]) == 1 else "%s_%d" % (role, i)
            keep(ob)


def parts_leftover(parts):
    """Anything an assembler did not parent yet, kept at the root by its role name."""
    for role in parts:
        for i, ob in enumerate(parts[role]):
            if ob not in TREE:
                ob.name = role if len(parts[role]) == 1 else "%s_%d" % (role, i)
                keep(ob)


def shifted(obs, dz_game, dy_game=0.0, name="copy"):
    return [copy_transformed(ob, Matrix.Translation(G(Vector((0.0, dy_game, dz_game)))), name + str(i))
            for i, ob in enumerate(obs)]


def rotated_about(obs, pivot_game, axis, degrees, name="rot"):
    """Copies rotated about the game axis "X"/"Y" through `pivot_game` (game coords)."""
    at = G(pivot_game)
    axis_blender = "X" if axis == "X" else "Y"
    m = Matrix.Translation(at) @ Matrix.Rotation(math.radians(degrees), 4, axis_blender) @ Matrix.Translation(-at)
    return [copy_transformed(ob, m, name + str(i)) for i, ob in enumerate(obs)]


# ------------------------------------------------------------------ the assemblers


def assemble_ak(parts, bones):
    bolt_node(parts, 0.08, Gi(bones["bolt"][0]))
    mags = group("Mags")
    head, tail = bones["mag"]
    mag_node(mags, "AK_Mag_30", Gi(head), parts["mag:AK_Mag_30"])
    long = stretch_copy(parts["mag:AK_Mag_30"], head, tail - head, 1.32, "AK_Mag_40")
    n = empty("AK_Mag_40", G(Gi(head)), mags)
    for i, ob in enumerate(long):
        attach(ob, n, i)
    brake = variant_group("Muzzle", [("Brake", None), ("PBS", None)])
    # the devices cover the baked slant, as the blockouts' did over the barrel
    tube("BrakeBody", [(0.013, 0.53), (0.013, 0.60)], 0.0, 0.045, "steel_light", parent=child_of(brake, "Brake"))
    tube("BrakeLip", [(0.0145, 0.59), (0.0145, 0.60)], 0.0, 0.045, "steel", parent=child_of(brake, "Brake"))
    tube("PBSCan", [(0.0175, 0.53), (0.0175, 0.73)], 0.0, 0.045, "steel", parent=child_of(brake, "PBS"))
    tube("PBSClamp", [(0.0195, 0.525), (0.0195, 0.55)], 0.0, 0.045, "steel_light", parent=child_of(brake, "PBS"))
    keep_root(parts, ["body", "Selector", "MagRelease"])
    empty("Handle", G(Vector((0.0, -0.062, 0.13))))  # no fallback box: the real knob rides the bolt


def assemble_pdw(parts, bones):
    bolt_node(parts, 0.045, Vector((0.0, 0.012, -0.03)))
    mags = group("Mags")
    mag_node(mags, "PDW_Mag_32", Vector((0.0, 0.015, -0.022)), parts["mag:PDW_Mag_32"])
    muzzle = variant_group("Muzzle", [("Suppressor", parts["muzzle:Suppressor"]), ("Thread", None)])
    stock = variant_group("Stock", [("Extended", parts["stock:Extended"]), ("Folded", None)])
    # Folded: the whole stock turned round about the vertical - the butt in front of the magazine well
    for i, ob in enumerate(rotated_about(parts["stock:Extended"], Vector((0.0, 0.0, -0.12)), "Y", 180.0,
                                        "StockFolded")):
        attach(ob, child_of(stock, "Folded"), i)
    trigger = empty("Trigger", G(Vector((0.0, 0.012, -0.086))))
    for i, ob in enumerate(parts["trigger"]):
        attach(ob, trigger, i)
    keep_root(parts, ["body", "MagRelease"])
    empty("Handle", G(Vector((-0.026, -0.03, 0.09))))


def assemble_luger(parts, bones):
    toggle = group("Toggle")
    rear = empty("LinkRear", G(Gi(bones["arm1"][0])), toggle)
    front = empty("LinkFront", G(Gi(bones["arm2"][0])), toggle)
    breech = empty("Breech", G(Gi(bones["bolt"][0])), toggle)
    for i, ob in enumerate(parts["toggle:LinkRear"]):
        attach(ob, rear, i)
    for i, ob in enumerate(parts["toggle:LinkFront"]):
        attach(ob, front, i)
    for i, ob in enumerate(parts["toggle:Breech"]):
        attach(ob, breech, i)
    mags = group("Mags")
    mag_node(mags, "Luger_Mag_8", Gi(bones["mag"][0]), parts["mag:Luger_Mag_8"])
    snail = empty("Luger_Mag_32", G(Vector((0.0, -0.053, -0.080))), mags)
    build_snail(snail)
    stock = variant_group("Stock", [("None", None), ("Board", None)])
    build_board(child_of(stock, "Board"))
    keep_root(parts, ["body", "Safety"])


def build_snail(node):
    """The TM08 drum after make_luger_blockout.py: under the grip, across the gun."""
    yaw, pitch = math.radians(25.0), math.radians(25.0)
    ax = Vector((-math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)))
    sx = Vector((math.cos(yaw), 0.0, math.sin(yaw)))
    up = ax.cross(sx)
    snail = empty("Snail", G(Vector((0.03, -0.11, 0.015))), node)
    # local axes: game -> Blender
    conv = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    rot = conv @ Matrix((sx, up, ax)).transposed() @ conv.inverted()
    snail.rotation_euler = rot.to_euler()
    half = 0.018
    tube_local("Drum", 0.049, -half, half, "mag", snail)
    tube_local("FrontCap", 0.047, half, half + 0.0015, "steel_light", snail)
    tube_local("CentreScrew", 0.005, half + 0.0015, half + 0.004, "steel", snail)
    for i in range(20):  # the front ring's teeth
        a = TAU * i / 20
        r = 0.0502
        box_local("Tooth%d" % i, r * math.cos(a) - 0.0025, r * math.cos(a) + 0.0025,
                  r * math.sin(a) - 0.0012, r * math.sin(a) + 0.0012, half - 0.001, half + 0.002, "mag", snail)
    box_local("Chute", -0.043, -0.018, 0.026, 0.056, -half - 0.003, half - 0.006, "mag", snail)
    tube_local("RearPlate", 0.03, -half - 0.003, -half, "steel", snail)
    tube_local("Key", 0.011, -half - 0.012, -half - 0.003, "steel_light", snail)
    box_local("KeyArm", -0.005, 0.005, -0.04, 0.0, -half - 0.012, -half - 0.008, "steel_light", snail)
    tube_local("KeyKnob", 0.004, -half - 0.02, -half - 0.012, "steel_light", snail, x=-0.036)
    tube_local("Pivot", 0.005, -half - 0.009, -half - 0.003, "steel_light", snail, x=-0.03)
    # the neck into the grip (node-local: from the grip's top down past the heel)
    box_local("Neck", -0.006, 0.006, 0.0577, 0.0697, -0.048, 0.045, "mag", node)


def tube_local(name, radius, z0, z1, mat, parent, x=0.0, y=0.0):
    """A lathe along the parent's local +Z (rotated nodes: the snail)."""
    verts, faces = [], []
    for z in (z0, z1):
        for i in range(16):
            a = TAU * i / 16
            verts.append((x + radius * math.cos(a), y + radius * math.sin(a), z))
    for i in range(16):
        a, b = i, (i + 1) % 16
        faces.append((a, b, 17 + b, 17 + a))
    for i in range(16):  # caps
        a, b = i, (i + 1) % 16
        faces.append((a, b))
        faces.append((17 + b, 17 + a))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    recalc(me)
    me.materials.append(material(mat))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.matrix_parent_inverse = Matrix.Identity(4)
    return keep(ob)


def box_local(name, x0, x1, y0, y1, z0, z1, mat, parent):
    return box(name, x0, x1, y0, y1, z0, z1, mat, parent=parent, local=True)


def build_board(node):
    """The holster stock after make_luger_blockout.py: a plank from the grip's heel to the butt."""
    heel_y, heel_z = -0.075, -0.100   # the new model's grip heel (the diagnostics box)
    zero = Vector((0.0, 0.0, 0.0))
    box("Fitting", -0.009, 0.009, heel_y - 0.01, heel_y + 0.012, heel_z - 0.035, heel_z - 0.006,
        "steel", parent=node, origin=zero)
    z0, z1 = heel_z - 0.035, -0.43
    for i in range(10):
        t0, t1 = i / 10.0, (i + 1) / 10.0
        top = heel_y + 0.012 + 0.03 * t1
        bottom = heel_y - 0.008 - 0.08 * t1
        box("Plank%d" % i, -0.015, 0.015, bottom, top, z0 + (z1 - z0) * t1, z0 + (z1 - z0) * t0,
            "wood", parent=node, origin=zero)
    box("ButtPlate", -0.016, 0.016, heel_y - 0.092, heel_y + 0.044, -0.436, -0.428, "steel",
        parent=node, origin=zero)


def assemble_mp7(parts, bones):
    bolt_node(parts, 0.04, Gi(bones["bolt"][0]))
    handle = empty("Handle", G(Gi(bones["charginghandle"][0])))
    for i, ob in enumerate(parts["handle"]):
        attach(ob, handle, i)
    mags = group("Mags")
    mag_node(mags, "MP7_Mag_40", Gi(bones["mag"][0]), parts["mag:MP7_Mag_40"])
    # the stock: out (the model's rest) or pushed home
    stock = group("Stock")
    out = empty("Extended", G(Gi(bones["stock"][0])), stock)
    for i, ob in enumerate(parts["stock:Extended"]):
        attach(ob, out, i)
    home = empty("Collapsed", G(Gi(bones["stock"][0])), stock)
    for i, ob in enumerate(shifted(parts["stock:Extended"], 0.223, name="StockCollapsed")):
        attach(ob, home, i)
    # the foregrip: down, or swung forward under the barrel
    grip = group("Foregrip")
    pivot = G(Gi(bones["foregrip"][0]))
    down = empty("Unfolded", pivot, grip)
    for i, ob in enumerate(parts["foregrip:Unfolded"]):
        attach(ob, down, i)
    fwd = empty("Folded", pivot, grip)
    for i, ob in enumerate(rotated_about(parts["foregrip:Unfolded"], Gi(bones["foregrip"][0]), "X", -90.0,
                                        "GripFolded")):
        attach(ob, fwd, i)
    # the sights fold flat under an optic
    boxes = [(-0.014, 0.014, 0.070, 0.110, -0.150, -0.098), (-0.014, 0.014, 0.070, 0.110, 0.083, 0.131)]
    inside, rest = cut_boxes(parts["body"], boxes)
    parts["body"] = rest
    sights = variant_group("Sights", [("Up", inside), ("Down", shifted(inside, 0.0, -0.018, "SightDown"))])
    # the can over the baked hider
    muzzle = variant_group("Muzzle", [("Hider", None), ("Can", None)])
    can = child_of(muzzle, "Can")
    tube("CanMount", [(0.009, 0.1698), (0.009, 0.1898)], 0.0, 0.0217, "steel", parent=can)
    tube("CanBody", [(0.016, 0.1898), (0.016, 0.3178)], 0.0, 0.0217, "polymer", parent=can)
    for i, z in enumerate((0.20, 0.215, 0.23, 0.245)):
        tube("CanGrip%d" % i, [(0.0165, z), (0.0165, z + 0.01)], 0.0, 0.0217, "steel", parent=can)
    tube("CanCap", [(0.014, 0.3178), (0.014, 0.3198)], 0.0, 0.0217, "steel_dark", parent=can)
    keep_root(parts, ["body", "BoltRelease", "Selector"])


def assemble_contender(parts, bones):
    hinge = Vector((0.0, 0.0149, 0.0231))
    break_node = empty("Break", G(hinge))
    for i, ob in enumerate(parts["break"]):
        attach(ob, break_node, i)
    # the round: the source's cartridge split at the case mouth - the nose is the "Bullet"
    round_node = empty("Round", G(Vector((0.0, 0.0438, -0.0083))), break_node)
    me = parts["round"][0].data
    cut = np.array([Gi(v.co).z > 0.049 for v in me.vertices])
    mask = np.array([all(cut[vi] for vi in poly.vertices) for poly in me.polygons])
    nose = build_part(me, mask)
    case = build_part(me, ~mask)
    bpy.data.objects.remove(parts["round"][0], do_unlink=True)
    bullet = empty("Bullet", Vector((0, 0, 0)), round_node)
    for i, ob in enumerate([nose]):
        attach(ob, bullet, i)
        ob.location = ob.location - round_node.location + bullet.location
    for i, ob in enumerate([case]):
        attach(ob, round_node, i)
    hammer = empty("Hammer", G(Vector((0.0, 0.032, -0.070))))
    for i, ob in enumerate(parts["hammer"]):
        attach(ob, hammer, i)
    trigger = empty("Trigger", G(Vector((0.0, -0.037, -0.006))))
    for i, ob in enumerate(parts["trigger"]):
        attach(ob, trigger, i)
    keep_root(parts, ["body"])


def assemble_winchester(parts, bones):
    lever = empty("Lever", G(Gi(bones["lever"][0])))
    for i, ob in enumerate(parts["lever"]):
        attach(ob, lever, i)
    hammer = empty("Hammer", G(Gi(bones["hammer"][0])))
    for i, ob in enumerate(parts["hammer"]):
        attach(ob, hammer, i)
    shell = empty("Shell", G(Vector((0.0, 0.092, 0.07))))
    tube("Hull", [(0.0102, -0.023), (0.0102, 0.044), (0.009, 0.047)], 0.0, 0.0, "hull", parent=shell)
    tube("Head", [(0.0112, -0.035), (0.0112, -0.0335), (0.0104, -0.0335), (0.0104, -0.023)], 0.0, 0.0,
         "brass", parent=shell)
    keep_root(parts, ["body"])


def assemble_mk14(parts, bones):
    bolt_node(parts, 0.09, Gi(bones["bolt"][0]))
    handle = empty("Handle", G(Gi(bones["charginghandle"][0])))
    for i, ob in enumerate(parts["handle"]):
        attach(ob, handle, i)
    mags = group("Mags")
    mag_node(mags, "Mk14_Mag_20", Gi(bones["mag"][0]), parts["mag:Mk14_Mag_20"])
    # the aperture cranked down under an optic; the front post gone under the ACOG
    rear = [(-0.012, 0.012, 0.068, 0.102, 0.006, 0.048)]
    front = [(-0.010, 0.010, 0.062, 0.102, 0.556, 0.598)]
    inside, rest = cut_boxes(parts["body"], rear)
    front_inside, parts["body"] = cut_boxes(rest, front)
    variant_group("Sights", [("Up", inside), ("Down", shifted(inside, 0.0, -0.022, "SightDown"))])
    variant_group("FrontSight", [("On", front_inside), ("Off", None)])
    keep_root(parts, ["body", "BoltRelease", "MagRelease", "Safety", "Selector"])


def assemble_p90(parts, bones):
    bolt_node(parts, 0.08, Gi(bones["bolt"][0]))
    handle = empty("Handle", G(Gi(bones["charginghandle"][0])))
    for i, ob in enumerate(parts["handle"]):
        attach(ob, handle, i)
    mags = group("Mags")
    mag_node(mags, "P90_Mag_50", Vector((0.0, 0.0361, 0.0825)), parts["mag:P90_Mag_50"])
    muzzle = variant_group("Muzzle", [("Hider", None), ("Can", None)])
    can = child_of(muzzle, "Can")
    tube("CanMount", [(0.0178, 0.144), (0.0178, 0.166)], 0.0, 0.0209, "steel", parent=can)
    tube("CanTube", [(0.0175, 0.166), (0.0175, 0.315)], 0.0, 0.0209, "can", parent=can)
    tube("CanCap", [(0.0175, 0.315), (0.0155, 0.318)], 0.0, 0.0209, "steel", parent=can)
    keep_root(parts, ["body", "Selector", "MagRelease"])


def assemble_aug(parts, bones):
    bolt_node(parts, 0.08, Gi(bones["bolt"][0]))
    handle = empty("Handle", G(Gi(bones["charginghandle"][0])))
    for i, ob in enumerate(parts["handle"]):
        attach(ob, handle, i)
    mags = group("Mags")
    head, tail = bones["mag"]
    mag_node(mags, "AUG_Mag_30", Gi(head), parts["mag:AUG_Mag_30"])
    n = empty("AUG_Mag_42", G(Gi(head)), mags)
    for i, ob in enumerate(stretch_copy(parts["mag:AUG_Mag_30"], head, tail - head, 1.4, "AUG_Mag_42")):
        attach(ob, n, i)
    trigger = empty("Trigger", G(Gi(bones["trigger"][0])))
    for i, ob in enumerate(parts["trigger"]):
        attach(ob, trigger, i)
    barrel = group("Barrel")
    b508 = empty("B508", Vector((0, 0, 0)), barrel)
    muzzle = variant_group("Muzzle", [("Hider", None), ("Can", None)])
    muzzle.parent = b508
    can = child_of(muzzle, "Can")
    tube("CanBody", [(0.019, 0.3474), (0.019, 0.5174)], 0.0, 0.0361, "black", parent=can)
    tube("CanCap", [(0.0175, 0.5174), (0.0175, 0.5187)], 0.0, 0.0361, "steel", parent=can)
    keep_root(parts, ["body", "MagRelease", "Safety"])


def assemble_m16(parts, bones):
    bolt_node(parts, 0.08, Gi(bones["bolt"][0]))
    handle = empty("Handle", G(Gi(bones["charginghandle"][0])))
    for i, ob in enumerate(parts["handle"]):
        attach(ob, handle, i)
    mags = group("Mags")
    mag_node(mags, "M16_Mag_30", Gi(bones["mag"][0]), parts["mag:M16_Mag_30"])

    # the model's px (tools/make_m16_blockout.py: the fitted model sits on the blockout's frame)
    K = 1.0066 / 845
    def pz(px):
        return (px - 300) * K
    def py(py_):
        return (296 - py_) * K
    bore = py(250)
    rear = pz(232)

    # the A1 stock off the receiver's back (the grip's back stays: the box stops at its top); the barrels: the
    # model's front from the delta ring out (the handle's post and the sight's ears clear the boxes)
    stock_inside, rest = cut_boxes(parts["body"], [(-0.033, 0.033, -0.062, 0.09, -0.34, -0.085)])
    barrel_inside, parts["body"] = cut_boxes(rest, [(-0.033, 0.033, -0.10, 0.13, 0.135, 0.70),
                                                    (-0.033, 0.033, -0.10, 0.078, 0.121, 0.135)])

    barrel = group("Barrel")
    b508 = empty("B508", Vector((0, 0, 0)), barrel)
    for i, ob in enumerate(barrel_inside):
        attach(ob, b508, i)
    muzzle = variant_group("Muzzle", [("Hider", None), ("Can", None)])   # the birdcage stays baked in B508
    muzzle.parent = b508
    can = child_of(muzzle, "Can")
    tube("HELCollar", [(0.0115, 0.515), (0.0115, 0.541)], 0.0, bore, "black", parent=can)
    tube("HELCone", [(0.0115, 0.541), (0.019, 0.559)], 0.0, bore, "black", parent=can)
    tube("HELBody", [(0.019, 0.559), (0.019, 0.8133)], 0.0, bore, "black", parent=can)

    # the B368 (the 653's 14.5"): the whole front generated off the blockout, 140 mm back; its own birdcage baked
    b368 = empty("B368", Vector((0, 0, 0)), barrel)
    fz = -0.14
    z = lambda px: pz(px) + fz
    tube("Nut", [(0.0185, z(398)), (0.0185, z(407))], 0.0, bore, "black", parent=b368)
    tube("DeltaRing", [(0.026, z(407)), (0.026, z(419))], 0.0, bore, "black", parent=b368)
    tube("Tube", [(0.0075, z(397)), (0.0075, z(872))], 0.0, bore, "black", parent=b368, segments=12)
    hz0, hz1 = z(419), z(687)
    tube("Handguard", [(0.0255, hz0), (0.024, hz1)], 0.0, bore - 0.003, "polymer", parent=b368, segments=12)
    for i in range(8):   # the round handguard's ribs
        zi = hz0 + 0.008 + i * (hz1 - hz0 - 0.016) / 8
        tube("Rib%d" % i, [(0.0268 - 0.0002 * i, zi), (0.0268 - 0.0002 * i, zi + 0.014)], 0.0, bore - 0.003,
             "polymer", parent=b368, segments=12)
    box("GasBlock", -0.011, 0.011, py(242), py(258), z(683), z(720), "black", parent=b368)
    box("BayonetLug", -0.004, 0.004, py(258), py(269), z(711), z(720), "black", parent=b368)
    box("CapRing", -0.0175, 0.0175, py(236), py(262), z(683), z(687), "black", parent=b368)
    prism("Leg", [(z(684), py(250)), (z(694), py(250)), (z(711), py(212)), (z(702), py(210))], 0.006, "black",
          parent=b368)
    box("Column", -0.0065, 0.0065, py(210), py(243), z(712), z(719), "black", parent=b368)
    box("Bridge", -0.0065, 0.0065, py(207), py(212), z(702), z(719), "black", parent=b368)
    for side, x0, x1 in (("L", 0.0028, 0.0065), ("R", -0.0065, -0.0028)):
        box("Ear" + side, x0, x1, py(193), py(207), z(705), z(719), "black", parent=b368)
    box("Post", -0.0012, 0.0012, py(207), bore + 0.0635, z(712), z(715), "black", parent=b368)
    box("PostTip", -0.0016, 0.0016, py(209), py(204), z(711), z(716), "black", parent=b368)
    tube("HiderBody", [(0.0095, z(825)), (0.0095, z(872))], 0.0, bore, "black", parent=b368)
    tube("HiderBase", [(0.0082, z(825) - 0.006), (0.0082, z(825))], 0.0, bore, "black", parent=b368)
    tube("HiderCrown", [(0.0075, z(872)), (0.0075, z(872) + 0.001)], 0.0, bore, "steel_dark", parent=b368)
    for side, x0, x1 in (("L", 0.0088, 0.0098), ("R", -0.0098, -0.0088)):
        box("HiderSlot" + side, x0, x1, bore - 0.0016, bore + 0.0016, z(825) + 0.009, z(872) - 0.004, "steel_dark",
            parent=b368)
    box("HiderSlotTop", -0.0016, 0.0016, bore + 0.0088, bore + 0.0098, z(825) + 0.009, z(872) - 0.004, "steel_dark",
        parent=b368)
    muzzle = variant_group("Muzzle", [("Hider", None), ("Can", None)])
    muzzle.parent = b368
    can = child_of(muzzle, "Can")
    tube("HELCollar", [(0.0115, z(720) + 0.0152), (0.0115, z(720) + 0.0412)], 0.0, bore, "black", parent=can)
    tube("HELCone", [(0.0115, z(720) + 0.0412), (0.019, z(720) + 0.0592)], 0.0, bore, "black", parent=can)
    tube("HELBody", [(0.019, z(720) + 0.0592), (0.019, 0.5414 + 0.1319)], 0.0, bore, "black", parent=can)

    # the stocks: the cut A1, and the CAR (the 653's telescoping one) generated off the blockout
    stock = variant_group("Stock", [("A1", stock_inside), ("CAR", None)])
    car = child_of(stock, "CAR")
    tube_y = bore - 0.004
    tube("Tube", [(0.0145, rear - 0.14), (0.0145, rear)], 0.0, tube_y, "tube", parent=car)
    tube("CastleNut", [(0.0175, rear - 0.01), (0.0175, rear)], 0.0, tube_y, "black", parent=car)
    box("EndPlate", -0.016, 0.016, tube_y - 0.018, tube_y + 0.012, rear - 0.004, rear, "black", parent=car)
    car_top = tube_y + 0.0145 + 0.004
    car_under = tube_y - 0.0145 - 0.01
    car_toe = bore - 0.082
    slide = group("Slide", car)
    out = empty("Out", Vector((0, 0, 0)), slide)
    sleeve = prism("Sleeve", [(rear - 0.085, car_top), (rear - 0.226, car_top), (rear - 0.226, car_toe),
                              (rear - 0.206, car_toe), (rear - 0.125, car_under), (rear - 0.085, car_under)],
                   0.018, "tube", parent=out)
    made = [sleeve,
            box("ButtPlate", -0.02, 0.02, car_toe - 0.002, car_top + 0.004, rear - 0.234, rear - 0.226, "rubber",
                parent=out),
            box("Lever", -0.004, 0.004, car_under - 0.022, car_under, rear - 0.17, rear - 0.115, "black", parent=out),
            box("LeverPin", -0.002, 0.002, car_under - 0.034, car_under - 0.02, rear - 0.165, rear - 0.16, "steel",
                parent=out),
            box("SlingLoop", -0.0025, 0.0025, car_top, car_top + 0.007, rear - 0.222, rear - 0.206, "steel",
                parent=out)]
    inn = empty("In", G(Vector((0.0, 0.0, 0.075))), slide)
    for i, ob in enumerate(shifted(made, 0.075, name="StockIn")):
        attach(ob, inn, i)
    keep_root(parts, ["body", "Selector", "BoltRelease", "DustCover"])



# The groza's muzzle grip (tools/make_groza_blockout.py, photos 07, 08 x 1.088): the blockout's photo pixels.
GROZA_K = 0.00095
GROZA_PX = (460, 205)   # the photo's pixel at the origin (the guard's hole's top, at the trigger)


def gpx(x, y):
    """A groza blockout photo pixel -> (z, y) game metres."""
    return ((x - GROZA_PX[0]) * GROZA_K, (GROZA_PX[1] - y) * GROZA_K)


def build_groza_grip():
    """The muzzle grip over the barrel's end: the housing with its nose hook, the fore grip, its ribs."""
    def prof(*px):
        return [gpx(x, y) for x, y in px]

    bore_y = gpx(0, 174)[1]
    out = [prism("Housing", prof((537, 163), (661, 163), (667, 170), (667, 215), (661, 221), (652, 221),
                                 (648, 212), (648, 199), (537, 199)), 0.016, "polymer"),
           prism("ForeGrip", prof((582, 199), (627, 199), (626, 295), (621, 302), (588, 302), (583, 295)),
                 0.0155, "polymer")]
    for i in range(5):   # the grip's ribs low down (photo 08)
        py = 262 + i * 7
        out.append(box("Rib%d" % i, -0.0162, 0.0162, gpx(0, py)[1], gpx(0, py + 3)[1],
                       gpx(583, 0)[0], gpx(626, 0)[0], "polymer"))
    out.append(tube("GripBore", [(0.0045, gpx(667, 0)[0]), (0.0045, gpx(667, 0)[0] + 0.0005)], 0.0, bore_y,
                    "steel_dark"))
    return out


def assemble_groza(parts, bones):
    bolt_node(parts, 0.08, Gi(bones["bolt"][0]))
    mags = group("Mags")
    head, tail = bones["mag"]
    mag_node(mags, "Groza_Mag_30", Gi(head), parts["mag:Groza_Mag_30"])
    n = empty("Groza_Mag_40", G(Gi(head)), mags)
    for i, ob in enumerate(stretch_copy(parts["mag:Groza_Mag_30"], head, tail - head, 1.32, "Groza_Mag_40")):
        attach(ob, n, i)
    muzzle = variant_group("Muzzle", [("Comp", None), ("Can", None), ("Grip", build_groza_grip())])
    can = child_of(muzzle, "Can")
    tube("CanCollar", [(0.0235, 0.116), (0.0235, 0.155)], 0.0, 0.0295, "can", parent=can)
    tube("CanBody", [(0.0295, 0.155), (0.0295, 0.30)], 0.0, 0.0295, "can", parent=can)
    tube("CanFront", [(0.0228, 0.30), (0.0228, 0.3678)], 0.0, 0.0295, "can", parent=can)
    keep_root(parts, ["body", "MagRelease", "Safety"])
    empty("Handle", G(Vector((-0.012, -0.0693, -0.1349))))


# The val's variants (tools/make_val_blockout.py): the blockout's photo pixels, 0.47 mm a pixel.
VAL_K = 0.00047
VAL_PX = (815, 205)    # the photo's pixel at the origin (the guard's hole's top, at the trigger)


def vpx(x, y):
    """A blockout photo pixel -> (z, y) game metres."""
    return ((x - VAL_PX[0]) * VAL_K, (VAL_PX[1] - y) * VAL_K)


def build_val_wood():
    """The Vintorez's thumbhole stock: the blockout's traced profiles as flat prisms, its pins across."""
    def prof(*px):
        return [vpx(x, y) for x, y in px]

    def ring(z, y, r, n=10):
        return [(z + r * math.cos(TAU * i / n), y + r * math.sin(TAU * i / n)) for i in range(n)]

    out = []
    for name, pts, hw, mat in (
            ("WoodTop", prof((87, 185), (495, 182), (525, 172), (565, 158), (635, 155), (662, 155), (662, 205),
                             (640, 222), (620, 241), (87, 241)), 0.0185, "wood"),
            ("WoodBottom", prof((80, 431), (595, 415), (600, 385), (200, 382), (80, 382)), 0.0185, "wood"),
            ("WoodRear", prof((87, 236), (175, 236), (157, 275), (157, 300), (185, 375), (200, 386), (80, 386)),
             0.018, "wood"),
            ("WoodMid", prof((335, 236), (477, 236), (465, 255), (445, 355), (470, 386), (330, 386), (345, 380),
                             (360, 340), (370, 275)), 0.018, "wood"),
            ("WoodGrip", prof((640, 220), (730, 220), (770, 287), (745, 315), (730, 410), (737, 427), (725, 435),
                              (617, 435), (595, 415), (600, 380), (630, 370), (645, 290), (642, 265), (616, 236)),
             0.0185, "wood"),
            ("Tang", prof((640, 205), (775, 205), (777, 284), (768, 284), (730, 220), (640, 220)), 0.0155, "black"),
            ("Pad", prof((40, 190), (45, 185), (87, 185), (80, 431), (45, 430), (40, 420)), 0.02, "rubber")):
        out.append(prism(name, pts, hw, mat))
    for name, py, px in (("PinTop", 170, 612), ("PinGrip", 250, 690)):
        for side, x in (("L", 0.0188), ("R", -0.0188)):
            out.append(prism(name + side, ring(vpx(px, 0)[0], vpx(0, py)[1], 0.0028), 0.0005, "steel", x=x))
    return out


def build_val_short():
    """The Vikhr's short barrel front, the blockout's dims: the handguard, the threaded muzzle, its own irons."""
    def prof(*px):
        return [vpx(x, y) for x, y in px]

    bore_y, sight_y = vpx(0, 168)[1], vpx(0, 69)[1]
    out = [prism("Handguard", prof((1045, 112), (1318, 112), (1330, 122), (1332, 190), (1318, 205), (1270, 196),
                                   (1085, 196), (1068, 232), (1045, 243)), 0.0195, "polymer")]
    for i in range(14):   # the row of finger slots
        px = 1185 + i * 9
        z0, z1 = vpx(px, 0)[0], vpx(px + 4, 0)[0]
        y0, y1 = sorted((vpx(0, 168)[1], vpx(0, 188)[1]))
        for side, x0, x1 in (("L", 0.0193, 0.0198), ("R", -0.0198, -0.0193)):
            out.append(box("Slot%d%s" % (i, side), x0, x1, y0, y1, z0, z1, "steel_dark"))
    for name, r, z0, z1, mat in (("Nose", 0.0125, vpx(1332, 0)[0], vpx(1350, 0)[0], "black"),
                                 ("Thread", 0.0095, vpx(1350, 0)[0], vpx(1406, 0)[0], "black"),
                                 ("Bore", 0.0045, vpx(1406, 0)[0], vpx(1406, 0)[0] + 0.0005, "steel_dark")):
        out.append(tube(name, [(r, z0), (r, z1)], 0.0, bore_y, mat))
    out.append(prism("FrontBase", prof((1285, 112), (1298, 75), (1312, 75), (1322, 112)), 0.008, "black"))
    for side, x0, x1 in (("L", 0.0042, 0.0072), ("R", -0.0072, -0.0042)):
        out.append(box("FrontEar" + side, x0, x1, vpx(0, 76)[1], vpx(0, 66)[1],
                       vpx(1296, 0)[0], vpx(1312, 0)[0], "black"))
    out.append(box("FrontPost", -0.0012, 0.0012, vpx(0, 76)[1], sight_y, vpx(1302, 0)[0], vpx(1306, 0)[0], "black"))
    for side, x in (("L", 0.0046), ("R", -0.0046)):   # the rear sight on the receiver: two plates, the notch between
        out.append(prism("RearEar" + side, prof((930, 108), (962, 69), (978, 69), (1005, 108)), 0.0028, "black", x=x))
    return out


def assemble_val(parts, bones):
    bolt_node(parts, 0.08, Gi(bones["bolt"][0]))
    mags = group("Mags")
    head, tail = bones["mag"]
    mag_node(mags, "Val_Mag_20", Gi(head), parts["mag:Val_Mag_20"])
    for name, factor in (("Val_Mag_10", 0.55), ("Val_Mag_30", 1.4)):
        n = empty(name, G(Gi(head)), mags)
        for i, ob in enumerate(stretch_copy(parts["mag:Val_Mag_20"], head, tail - head, factor, name)):
            attach(ob, n, i)
    # the front off the body: the handguard, the can, the sights (the Can barrel; the Vikhr's Short is generated,
    # its handguard's back face flush over the cut)
    can, parts["body"] = cut_boxes(parts["body"], [(-0.03, 0.03, -0.07, 0.06, 0.104, 0.60)])
    # the rear off the body: the wire stock with the Val's grip (the Vintorez's wooden one is generated; the guard
    # stays in the body: its band sits between the grip's two cut boxes)
    wire, rest = cut_boxes(parts["body"], [(-0.0135, 0.0135, -0.12, 0.032, -0.40, -0.0715),
                                           (-0.03, 0.03, -0.13, -0.046, -0.09, -0.014),
                                           (-0.03, 0.03, -0.046, -0.002, -0.09, -0.0295)])
    parts["body"] = rest
    variant_group("Barrel", [("Can", can), ("Short", build_val_short())])
    variant_group("Stock", [("Wire", wire), ("Wood", build_val_wood())])
    keep_root(parts, ["body", "Selector", "Safety", "MagRelease"])
    empty("Handle", G(Vector((-0.016, -0.0211, 0.1011))))


def assemble_striker(parts, bones):
    drum_pts = [tuple(v.co) for ob in parts["drum"] for v in ob.data.vertices]
    a = np.array(drum_pts)
    lo, hi = Gi(Vector(a.min(axis=0))), Gi(Vector(a.max(axis=0)))
    drum = empty("Drum", G(Vector((0.0, (lo.y + hi.y) / 2.0, (lo.z + hi.z) / 2.0))))
    for i, ob in enumerate(parts["drum"]):
        attach(ob, drum, i)
    body = group("Body")
    striker = empty("Striker", Vector((0, 0, 0)), body)
    stock_parts = parts.get("stock:Extended", [])
    for ob in [o for role, obs_ in parts.items() if role not in ("drum", "stock:Extended") for o in obs_]:
        if ob in TREE:
            continue
        ob.parent = striker
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.location = Vector((0, 0, 0))
        keep(ob)
    stock = group("Stock", striker)
    out = empty("Extended", Vector((0, 0, 0)), stock)
    for i, ob in enumerate(stock_parts):
        attach(ob, out, i)
    folded = empty("Folded", Vector((0, 0, 0)), stock)
    pts = [tuple(v.co) for ob in stock_parts for v in ob.data.vertices]
    b = np.array(pts)
    lo, hi = Gi(Vector(b.min(axis=0))), Gi(Vector(b.max(axis=0)))
    for i, ob in enumerate(rotated_about(stock_parts, Vector((0.0, hi.y - 0.004, hi.z)), "X", 180.0,
                                         "StockFolded")):
        attach(ob, folded, i)
    shell = empty("Shell", G(Vector((-0.054, -0.0082, 0.004))))
    tube("Hull", [(0.0102, 0.027), (0.0102, 0.064), (0.009, 0.067)], 0.0, 0.0, "hull", parent=shell)
    tube("Head", [(0.0112, 0.0), (0.0112, 0.0015), (0.0104, 0.0015), (0.0104, 0.027)], 0.0, 0.0,
         "brass", parent=shell)


ASSEMBLE = {
    "ak": assemble_ak, "pdw": assemble_pdw, "luger": assemble_luger, "mp7": assemble_mp7,
    "contender": assemble_contender, "winchester": assemble_winchester, "mk14": assemble_mk14,
    "p90": assemble_p90, "aug": assemble_aug, "m16": assemble_m16, "groza": assemble_groza,
    "val": assemble_val, "striker": assemble_striker,
}


# ------------------------------------------------------------------ build


def purge(scene_objects):
    """The stage's objects and their orphaned data go, so the next import keeps clean names."""
    for ob in scene_objects:
        try:
            bpy.data.objects.remove(ob, do_unlink=True)
        except RuntimeError:
            pass
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


def dominant_bones_of(obs):
    """Per source vertex: the heaviest vertex group's name ("" if none), aligned with the cloud."""
    bones = []
    for ob in obs:
        names = [g.name for g in ob.vertex_groups]
        for v in ob.data.vertices:
            top, who = 0.0, ""
            for g in v.groups:
                if g.weight > top:
                    top, who = g.weight, names[g.group]
            bones.append(who)
    return bones


def vertex_materials(obs):
    """Per vertex: the name of the material most of its faces wear ("" when bare)."""
    out = []
    for ob in obs:
        me = ob.data
        votes = [{} for _ in me.vertices]
        for poly in me.polygons:
            mat = me.materials[poly.material_index] if me.materials and \
                poly.material_index < len(me.materials) else None
            name = mat.name if mat else ""
            for vi in poly.vertices:
                votes[vi][name] = votes[vi].get(name, 0) + 1
        out += [max(v, key=v.get) if v else "" for v in votes]
    return out


def game_original(weapon_id, game_path):
    """The committed GLB: a rebuild must never take the build's own output as its input."""
    orig = os.path.join(CACHE, "%s_orig.glb" % weapon_id)
    os.makedirs(CACHE, exist_ok=True)
    rel = os.path.relpath(game_path, ROOT).replace("\\", "/")
    with open(orig, "wb") as f:
        if subprocess.run(["git", "show", "HEAD:" + rel], stdout=f, cwd=ROOT).returncode != 0:
            sys.exit("  no committed original for %s (%s)" % (weapon_id, rel))
    return orig


def dedupe_glb(path):
    """Blender suffixes repeated node names (the second Muzzle becomes Muzzle.001); Godot wants the plain names
    back (the DB's variant paths) and allows duplicates in different parents. Strips a suffix when the stripped
    name is free among the node's siblings."""
    with open(path, "rb") as f:
        data = f.read()
    jlen, = struct.unpack("<I", data[12:16])
    js = json.loads(data[20:20 + jlen])
    nodes = js.get("nodes", [])
    parented = set(i for n in nodes for i in n.get("children", []))

    def walk(i, sibs):
        name = nodes[i].get("name", "")
        m = re.match(r"^(.*)\.(\d+)$", name)
        if m and m.group(1) not in sibs:
            name = m.group(1)
            nodes[i]["name"] = name
        sibs.add(name)
        child_sibs = set()
        for c in nodes[i].get("children", []):
            walk(c, child_sibs)

    for i in range(len(nodes)):
        if i not in parented:
            walk(i, set())
    out = json.dumps(js, separators=(",", ":")).encode()
    out += b" " * ((4 - len(out) % 4) % 4)
    with open(path, "wb") as f:
        f.write(data[:8])
        f.write(struct.pack("<I", 20 + len(out) + len(data[20 + jlen:])))
        f.write(struct.pack("<II", len(out), 0x4E4F534A))
        f.write(out)
        f.write(data[20 + jlen:])


def build(weapon_id):
    cfg = WEAPONS[weapon_id]
    print("[%s]" % weapon_id)
    fresh_scene()
    folder = weapon_id if weapon_id != "m16" else "m16_tastytony"
    game_path = os.path.join(ROOT, "vibe-of-duty-p", "assets", "models", folder, weapon_id + ".glb")
    A = None
    bones = {}

    if cfg.get("src"):
        # the source first, in a clean scene: its names (and the bone frames) stay pristine
        src_obs = load_file(source_path(*cfg["src"]), [])
        frames = bone_frames(src_obs)
        bake(src_obs)
        src_pts = [v.co.copy() for ob in src_obs for v in ob.data.vertices]
        src_bones = dominant_bones_of(src_obs)
        src_mat = vertex_materials(src_obs)   # read before the objects go
        sb = centroids_of(src_obs)
        purge([o for o in bpy.data.objects if o.users_scene])

        # the Sketchfab GLB between them: the game's geometry came from it (junk meshes drop)
        skf_obs = load_file(os.path.join(ROOT, "models_incoming", *SKF[weapon_id]), [])
        skf_obs = [o for o in skf_obs if o.data.materials and any(o.data.materials)]
        bake(skf_obs)
        sa = centroids_of(skf_obs)
        C = np.array([tuple(v.co) for ob in skf_obs for v in ob.data.vertices])
        fit2 = fit_named(sa, sb, "skf<-src")
        purge([o for o in bpy.data.objects if o.users_scene])

        # the game GLB (from the commit: a rebuild must not read the build's own output)
        bpy.ops.import_scene.gltf(filepath=game_original(weapon_id, game_path))
        game_obs = [o for o in bpy.data.objects if o.type == "MESH" and o.users_scene]
        bake(game_obs)
        A = np.array([tuple(v.co) for ob in game_obs for v in ob.data.vertices])

        RM = t_vec = None
        if fit2:
            RM1, t1, res1 = fit_stretch(A, C)   # game <- skf (the clouds; the material names differ)
            print("  game<-skf: resid mean %.6f  p95 %.6f" % (res1.mean(), np.percentile(res1, 95)))
            if np.percentile(res1, 95) <= 0.0025:
                RM, t_vec = compose(fit2, (RM1, t1))
        if RM is None:
            RM, t_vec, res = fit_stretch(A, np.array([tuple(p) for p in src_pts]))
            print("  stretch fit: resid mean %.6f  p95 %.6f" % (res.mean(), np.percentile(res, 95)))
        # verify on the vertices: every game vertex must sit on a transformed source vertex
        moved = [RM @ p + t_vec for p in src_pts]
        # per-material refinement: the game's parts were nudged; each material gets its own
        # correction when it fits well (the names may be scrambled - the check decides)
        game_mat = vertex_materials(game_obs)
        shared = sorted((set(src_mat) & set(game_mat)) - {""})
        refined = 0
        for m in shared:
            gi = [i for i, mm in enumerate(game_mat) if mm == m]
            si = [i for i, mm in enumerate(src_mat) if mm == m]
            if len(gi) < 24 or len(si) < 24:
                continue
            Q = A[gi]
            P0 = np.array([tuple(moved[i]) for i in si])
            # iterate: nearest pairs tighten as the part's own fit closes in
            Pm, t2, s2, R2 = P0, np.zeros(3), 1.0, np.eye(3)
            for _ in range(4):
                near = nearest(build_kd(Q), Pm)
                R2, s2, t2 = umeyama(P0, Q[near])
                Pm = P0 @ R2.T * s2 + t2
            res2 = np.linalg.norm(Q[near] - Pm, axis=1)
            if np.percentile(res2, 95) > 0.004:
                continue
            for k, i in enumerate(si):
                moved[i] = Vector(Pm[k])
            refined += 1
        kd = build_kd(moved)
        res0 = np.array([kd.find(v.co)[2] for ob in game_obs for v in ob.data.vertices])
        print("  vertex resid: mean %.6f  p95 %.6f  max %.6f  (%d of %d materials refined)" % (
            res0.mean(), np.percentile(res0, 95), res0.max(), refined, len(shared)))
        if np.percentile(res0, 95) > cfg.get("resid_gate", 0.0025):
            sys.exit("  vertex resid too loose - aborting")
        bones = bone_map(frames, RM, t_vec)
        parts = split_by_bones(game_obs, kd, src_bones, cfg["roles"])
    else:
        bpy.ops.import_scene.gltf(filepath=game_original(weapon_id, game_path))
        game_obs = [o for o in bpy.data.objects if o.type == "MESH" and o.users_scene]
        bake(game_obs)
        parts = regroup_parts(cfg, weapon_id)
        for ob in game_obs:
            if ob.name in ("Icosphere",) or (ob.data.materials and not any(ob.data.materials)):
                bpy.data.objects.remove(ob, do_unlink=True)
                parts = regroup_parts(cfg, weapon_id)

    part_boxes(parts)
    ASSEMBLE[weapon_id](parts, bones)
    parts_leftover(parts)

    # everything but the tree goes; the GLB out
    for ob in list(bpy.data.objects):
        if ob not in TREE and ob.users_scene:
            bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.export_scene.gltf(filepath=game_path, export_format="GLB", export_apply=True, export_yup=True,
                              export_extras=True, export_cameras=False, export_lights=False,
                              export_animations=False)
    dedupe_glb(game_path)
    print("  wrote %s (%d parts)" % (game_path, len(TREE)))
    del TREE[:]


if __name__ == "__main__":
    for weapon_id in (ARGS or [w for w in WEAPONS]):
        if weapon_id in WEAPONS:
            build(weapon_id)
        else:
            print("no weapon %r (have: %s)" % (weapon_id, ", ".join(WEAPONS)))

