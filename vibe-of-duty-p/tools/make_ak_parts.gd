extends SceneTree
## Generates the AK's shaped parts as meshes for tools/make_ak_blockout.py (which puts them in the scene at the
## origin): prefabs/weapons/ak_<part>_mesh.tres. Run from the Godot project folder:
##   godot --headless --path vibe-of-duty-p -s tools/make_ak_parts.gd
##
## Two kinds of solid, flat-shaded (low poly, as the rest of the game):
## - a side profile (z, y) pushed out across the gun, its half width changing along z (the stock thickens towards
##   the butt), the edges chamfered - stock, butt plate, pistol grip, handguards;
## - a cross-section (x, y) pushed along the barrel - the dust cover's rounded top.
## Prefab space as the rifle's: +Y up, +Z towards the muzzle, metres; the parts are built in place. Shapes after the
## AKM (from memory): the stock drops and deepens to the butt, the grip rakes back with a finger groove, the lower
## handguard swells under the palm.

const DIR := "res://prefabs/weapons/"
## name -> outline (z, y) in order round it, half width [z, hw] along z (linear between), chamfer.
const PROFILES := {
	"stock": {"points": [Vector2(-0.105, 0.062), Vector2(-0.374, 0.036), Vector2(-0.38, -0.086),
			Vector2(-0.15, -0.024), Vector2(-0.105, -0.004)],
			"width": [Vector2(-0.105, 0.017), Vector2(-0.38, 0.021)], "chamfer": 0.005},
	"butt_plate": {"points": [Vector2(-0.373, 0.038), Vector2(-0.386, 0.037), Vector2(-0.393, -0.088),
			Vector2(-0.379, -0.089)], "width": [Vector2(0.0, 0.0225)], "chamfer": 0.003},
	"grip": {"points": [Vector2(-0.03, 0.0), Vector2(-0.066, 0.0), Vector2(-0.099, -0.1), Vector2(-0.094, -0.11),
			Vector2(-0.068, -0.114), Vector2(-0.057, -0.075), Vector2(-0.05, -0.045), Vector2(-0.038, -0.018)],
			"width": [Vector2(0.0, 0.0155)], "chamfer": 0.004},
	"handguard_lower": {"points": [Vector2(0.27, 0.058), Vector2(0.27, 0.012), Vector2(0.29, 0.003),
			Vector2(0.33, -0.002), Vector2(0.39, 0.002), Vector2(0.42, 0.012), Vector2(0.42, 0.058)],
			"width": [Vector2(0.27, 0.0275), Vector2(0.42, 0.0285)], "chamfer": 0.008},
	"handguard_upper": {"points": [Vector2(0.3, 0.066), Vector2(0.3, 0.09), Vector2(0.31, 0.096),
			Vector2(0.40, 0.096), Vector2(0.41, 0.09), Vector2(0.41, 0.066)],
			"width": [Vector2(0.0, 0.021)], "chamfer": 0.008},
}
## name -> cross-section (x, y) in order round it, from z to z.
const SECTIONS := {
	"dust_cover": {"points": [Vector2(-0.022, 0.072), Vector2(-0.022, 0.08), Vector2(-0.016, 0.087),
			Vector2(0.0, 0.09), Vector2(0.016, 0.087), Vector2(0.022, 0.08), Vector2(0.022, 0.072)],
			"z": Vector2(-0.1, 0.235)},
}


func _initialize() -> void:
	for name: String in PROFILES:
		var p: Dictionary = PROFILES[name]
		_save(_profile_solid(PackedVector2Array(p["points"]), p["width"], p["chamfer"]), name)
	for name: String in SECTIONS:
		var s: Dictionary = SECTIONS[name]
		_save(_section_solid(PackedVector2Array(s["points"]), s["z"]), name)
	quit()


func _save(mesh: Mesh, name: String) -> void:
	var path := DIR + "ak_%s_mesh.tres" % name
	print("wrote %s (%s)" % [path, error_string(ResourceSaver.save(mesh, path))])


## A side profile pushed across the gun: the two flat sides (the outline inset by the chamfer), the chamfer bands
## and the edge band all round.
static func _profile_solid(points: PackedVector2Array, width: Array, chamfer: float) -> Mesh:
	if _area(points) < 0.0:
		points.reverse()  # counter-clockwise in (z, y): the outward normal of an edge (dz, dy) is (dy, -dz)
	var inset := _inset(points, chamfer)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		var tris := Geometry2D.triangulate_polygon(inset)
		for i in range(0, tris.size(), 3):
			var a := inset[tris[i]]
			var b := inset[tris[i + 1]]
			var c := inset[tris[i + 2]]
			_tri(st, _at(a, side * _hw(width, a.x)), _at(b, side * _hw(width, b.x)), _at(c, side * _hw(width, c.x)),
					Vector3(side, 0.0, 0.0))
	var n := points.size()
	for k in n:
		var k2 := (k + 1) % n
		var edge := points[k2] - points[k]
		var out := Vector3(0.0, -edge.x, edge.y).normalized()
		for side in [1.0, -1.0]:  # chamfer: from the side's inset outline to the edge band
			var a := _at(inset[k], side * _hw(width, inset[k].x))
			var b := _at(inset[k2], side * _hw(width, inset[k2].x))
			var c := _at(points[k2], side * (_hw(width, points[k2].x) - chamfer))
			var d := _at(points[k], side * (_hw(width, points[k].x) - chamfer))
			_quad(st, a, b, c, d, (out + Vector3(side, 0.0, 0.0)).normalized())
		_quad(st, _at(points[k], _hw(width, points[k].x) - chamfer), _at(points[k2], _hw(width, points[k2].x) - chamfer),
				_at(points[k2], chamfer - _hw(width, points[k2].x)), _at(points[k], chamfer - _hw(width, points[k].x)), out)
	return st.commit()


## A cross-section pushed along the barrel from z.x to z.y: its sides and the two end caps.
static func _section_solid(points: PackedVector2Array, z: Vector2) -> Mesh:
	if _area(points) < 0.0:
		points.reverse()  # counter-clockwise in (x, y): the outward normal of an edge (dx, dy) is (dy, -dx)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	for k in n:
		var a := points[k]
		var b := points[(k + 1) % n]
		var edge := b - a
		_quad(st, Vector3(a.x, a.y, z.x), Vector3(b.x, b.y, z.x), Vector3(b.x, b.y, z.y), Vector3(a.x, a.y, z.y),
				Vector3(edge.y, -edge.x, 0.0).normalized())
	var tris := Geometry2D.triangulate_polygon(points)
	for end in [z.x, z.y]:
		for i in range(0, tris.size(), 3):
			var a := points[tris[i]]
			var b := points[tris[i + 1]]
			var c := points[tris[i + 2]]
			_tri(st, Vector3(a.x, a.y, end), Vector3(b.x, b.y, end), Vector3(c.x, c.y, end),
					Vector3(0.0, 0.0, -1.0 if end == z.x else 1.0))
	return st.commit()


## A profile point (z, y) at x.
static func _at(p: Vector2, x: float) -> Vector3:
	return Vector3(x, p.y, p.x)


## Half width at z: linear between the [z, hw] keys, held beyond the ends.
static func _hw(width: Array, z: float) -> float:
	if width.size() == 1:
		return (width[0] as Vector2).y
	var a: Vector2 = width[0]
	var b: Vector2 = width[1]
	return lerpf(a.y, b.y, clampf((z - a.x) / (b.x - a.x), 0.0, 1.0))


static func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for k in points.size():
		var a := points[k]
		var b := points[(k + 1) % points.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


## The outline moved `by` inwards, a mitred corner for each (counter-clockwise outline; the corners stay matched).
static func _inset(points: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for k in n:
		var e1 := (points[k] - points[(k - 1 + n) % n]).normalized()
		var e2 := (points[(k + 1) % n] - points[k]).normalized()
		var n1 := Vector2(-e1.y, e1.x)  # inward normals
		var n2 := Vector2(-e2.y, e2.x)
		var mid := (n1 + n2).normalized()
		out.append(points[k] + mid * minf(by / maxf(mid.dot(n1), 0.2), by * 3.0))
	return out


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(st, a, b, c, outward)
	_tri(st, a, c, d, outward)


## One flat triangle facing `outward`. Godot shows the side the vertices go clockwise round: (b - a) x (c - a)
## points into the solid (checked on a render - the other way the stock showed its inside).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-14:
		return
	if normal.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	else:
		normal = -normal
	normal = normal.normalized()
	for v in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)
