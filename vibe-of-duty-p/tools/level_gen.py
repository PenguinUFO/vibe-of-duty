"""Shared by the level shell generators (tools/make_plane_map.py, tools/make_tower_map.py): boxes, lamps and markers,
written out as a shell scene of Blocks that a hand-edited level scene instances (like the train's shell, see
Docs/LEVEL_TRAIN.md). Not run by itself.

Decks: the lamps cast no shadows, so each lights only its own deck's blocks (render layers 3, 4, 5 - project.godot;
the props get theirs from TrainProps.deck_splits). A block centred within SLAB_BAND of a split - a floor slab -
belongs to both decks around it, and so does any block passed decks="all" (stairs, shafts through the floors).

Groups: blocks and lamps made while Level.group is set go under a Node3D of that name instead of Geometry / Lamps
(the lamps under <group>/Lamps) - a part a script moves as one (the tower's crane load). Their positions are the
level's, with the group node at the origin.
"""
import math

LAYER_WORLD, LAYER_VIEWMODEL = 1, 2
DECK_LAYERS = [4, 8, 16]
SLAB_BAND = 0.25
# Guard rail height. Not 1.1 m as on the train: at the top of a jump (feet ~1.06 m) the bottom of the capsule meets a
# 1.1 m edge at less than the floor angle (46 deg) and the player stands on the rail - bots walked off the tower so.
# Thinner than 0.15 m, so the vault refuses it.
RAIL = 1.3
RAIL_T = 0.08
LAMP_COLOR = (1.0, 0.86, 0.66)   # Palette.EMBER as light, as on the train


class Level:
    def __init__(self, splits):
        self.splits = list(splits)   # heights between the decks, lowest first
        self.blocks = []             # (name, center, basis rows, size, color, layers, penetrable, group)
        self.lights = []             # (name, position, energy, range, shade size, group)
        self.markers = {}            # group name -> [(name, position)]
        self.group = None            # blocks and lamps made now go under this node (see the module's doc)
        self._names = {}

    def uniq(self, name):
        n = self._names.get(name, 0)
        self._names[name] = n + 1
        return name if n == 0 else "%s%d" % (name, n)

    def deck_of(self, y):
        return sum(1 for s in self.splits if y >= s)

    def layers_at(self, y, decks=None):
        if decks == "all":
            return sum(DECK_LAYERS[: len(self.splits) + 1])
        for i, s in enumerate(self.splits):
            if abs(y - s) < SLAB_BAND:
                return DECK_LAYERS[i] | DECK_LAYERS[i + 1]
        return DECK_LAYERS[self.deck_of(y)]

    def box(self, name, x0, x1, y0, y1, z0, z1, color, decks=None, penetrable=False):
        c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        self.blocks.append((self.uniq(name), c, ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (x1 - x0, y1 - y0, z1 - z0), color,
                            self.layers_at(c[1], decks), penetrable, self.group))

    def rotated(self, name, center, size, color, rot_x=0.0, rot_z=0.0, decks=None):
        """A box turned rot_x about X, then rot_z about Z (radians)."""
        cx, sx = math.cos(rot_x), math.sin(rot_x)
        cz, sz = math.cos(rot_z), math.sin(rot_z)
        rx = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
        rz = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))
        rows = tuple(tuple(sum(rz[i][k] * rx[k][j] for k in range(3)) for j in range(3)) for i in range(3))
        self.blocks.append((self.uniq(name), center, rows, size, color, self.layers_at(center[1], decks), False,
                            self.group))

    def slab(self, name, rects, holes, y0, y1, color, decks=None):
        """A floor over rects [(x0, x1, z0, z1)] (not overlapping) with rectangular holes [(x0, x1, z0, z1)]."""
        for rx0, rx1, rz0, rz1 in rects:
            xs = sorted({rx0, rx1} | {v for h in holes for v in h[:2] if rx0 < v < rx1})
            for xa, xb in zip(xs, xs[1:]):
                cuts = sorted((max(h[2], rz0), min(h[3], rz1)) for h in holes
                              if h[0] <= xa and h[1] >= xb and h[2] < rz1 and h[3] > rz0)
                z = rz0
                for za, zb in cuts:
                    if za > z:
                        self.box(name, xa, xb, y0, y1, z, za, color, decks)
                    z = max(z, zb)
                if z < rz1:
                    self.box(name, xa, xb, y0, y1, z, rz1, color, decks)

    def ramp(self, name, x0, x1, y_low, y_high, z_low, z_high, color, thick=0.25):
        """Stairs as a ramp from (y_low at z_low) up to (y_high at z_high); its top surface meets both floors."""
        run, rise = z_high - z_low, y_high - y_low
        length = math.hypot(run, rise)
        angle = math.atan2(rise, abs(run))
        cy = y_low + rise / 2 - thick / 2 / math.cos(angle)
        rot = -angle if run > 0 else angle   # rotation about X: negative tilts +Z upwards
        self.rotated(name, ((x0 + x1) / 2, cy, (z_low + z_high) / 2), (x1 - x0, thick, length), color, rot_x=rot,
                     decks="all")

    def rail_x(self, x, y, z0, z1, color, name="Rail"):
        """A guard rail along Z at x (its inner face), standing on y."""
        self.box(name, x - RAIL_T / 2, x + RAIL_T / 2, y, y + RAIL, z0, z1, color)

    def rail_z(self, z, y, x0, x1, color, name="Rail"):
        self.box(name, x0, x1, y, y + RAIL, z - RAIL_T / 2, z + RAIL_T / 2, color)

    def lamp(self, name, pos, energy=1.2, rng=9.0, shade=(0.7, 0.05, 0.3)):
        self.lights.append((self.uniq(name), pos, energy, rng, shade, self.group))

    def marker(self, group, name, pos):
        self.markers.setdefault(group, []).append((self.uniq(name), pos))

    # --- output ------------------------------------------------------------------------------------------------------

    def write(self, path, root_name, ground_y=None):
        f = lambda v: "%g" % round(v, 4)
        out = ['[gd_scene format=3]\n\n[ext_resource type="PackedScene" path="res://prefabs/levels/block.tscn" id="2_block"]\n\n']
        if ground_y is not None:
            out.append('[sub_resource type="WorldBoundaryShape3D" id="ground_shape"]\n\n')
        out.append('[node name="%s" type="Node3D"]\n\n[node name="Geometry" type="Node3D" parent="."]\n' % root_name)
        groups = []
        for item in self.blocks + self.lights:
            if item[-1] is not None and item[-1] not in groups:
                groups.append(item[-1])
        for group in groups:
            out.append('\n[node name="%s" type="Node3D" parent="."]\n' % group)
            if any(light[-1] == group for light in self.lights):
                out.append('\n[node name="Lamps" type="Node3D" parent="%s"]\n' % group)
        for name, c, r, s, col, layers, pen, group in self.blocks:
            out.append('\n[node name="%s" parent="%s" instance=ExtResource("2_block")]\n' % (name, group or "Geometry"))
            # Transform3D(basis rows..., origin): Godot writes the basis row by row (as make_train_map.py does).
            flat = [v for row in r for v in row]
            out.append("transform = Transform3D(%s, %s, %s, %s)\n" % (", ".join(map(f, flat)), f(c[0]), f(c[1]), f(c[2])))
            out.append("size = Vector3(%s, %s, %s)\n" % tuple(map(f, s)))
            out.append("color = Color(%s, %s, %s, 1)\n" % tuple(map(f, col)))
            out.append("mesh_layers = %d\n" % layers)
            if pen:
                out.append("penetrable = true\n")
        if ground_y is not None:  # whoever falls lands on it (and dies: World.kill_height is just above)
            out.append('\n[node name="Ground" type="StaticBody3D" parent="."]\n')
            out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)\n" % f(ground_y))
            out.append('\n[node name="Shape" type="CollisionShape3D" parent="Ground"]\nshape = SubResource("ground_shape")\n')
        out.append('\n[node name="Lamps" type="Node3D" parent="."]\n')
        for name, p, energy, rng, shade, group in self.lights:
            parent = group + "/Lamps" if group else "Lamps"
            out.append('\n[node name="%s" type="OmniLight3D" parent="%s"]\n' % (name, parent))
            out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n" % tuple(map(f, p)))
            out.append("light_color = Color(%s, %s, %s, 1)\n" % tuple(map(f, LAMP_COLOR)))
            out.append("light_energy = %s\nlight_specular = 0.0\nomni_range = %s\nomni_attenuation = 1.4\n" % (f(energy), f(rng)))
            out.append("light_cull_mask = %d\n" % (LAYER_WORLD | LAYER_VIEWMODEL | DECK_LAYERS[self.deck_of(p[1])]))
            out.append("metadata/shade = Vector3(%s, %s, %s)\n" % tuple(map(f, shade)))
        for group, items in self.markers.items():
            out.append('\n[node name="%s" type="Node3D" parent="."]\n' % group)
            for name, p in items:
                out.append('\n[node name="%s" type="Marker3D" parent="%s"]\n' % (name, group))
                out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n" % tuple(map(f, p)))
        open(path, "w", encoding="utf-8", newline="\n").write("".join(out))
        print("wrote %s: %d blocks, %d lamps" % (path, len(self.blocks), len(self.lights)))
