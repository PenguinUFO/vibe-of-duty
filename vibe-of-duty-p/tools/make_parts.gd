extends SceneTree
## Generates the weapons' shaped parts as meshes for the scene generators (tools/make_<weapon>_blockout.py, which put
## them in the scene at the origin): prefabs/weapons/<weapon>_<part>_mesh.tres. Run from the Godot project folder:
##   godot --headless --path vibe-of-duty-p -s tools/make_parts.gd
##
## Two kinds of solid, flat-shaded (low poly, as the rest of the game):
## - a side profile (z, y) pushed out across the gun, its half width changing along z (the AK's stock thickens
##   towards the butt), the edges chamfered - stocks, grips, handguards, receivers;
## - a cross-section (x, y) pushed along the barrel - the AK dust cover's rounded top.
## Prefab space as the guns': +Y up, +Z towards the muzzle, metres; the parts are built in place.
## AK - after the AKM, from memory: the stock drops and deepens to the butt, the grip rakes back with a finger groove,
## the lower handguard swells under the palm. PDW - after the Parker-Hale photos (Docs/LOADOUT.md, "PDW"): the
## receiver's rounded nose, the grip raked in front and near upright behind, flaring at the bottom, the big oval
## trigger guard (the lower housing with the oval cut: a U whose top is the receiver), the long magazine well, the stock's U butt with a hollow back
## (one side's plate; folded, the stock turns round and the butt is in front). Luger - after the photos of a WE P08 6": the
## trigger guard's small round loop running into the raked grip frame, the walnut panels. ACR - after the owner's photos: the
## upper and the tall lower split at a slant, the long deep handguard (short with 10.5"), the MOE grip, the solid stock.
## MP7 - after the owner's photos: the one-block receiver with its sloping front, the L guard, the upright grip, the butt
## plate.

const DIR := "res://prefabs/weapons/"
## weapon -> {profiles: name -> {points (z, y) in order round it, width [z, hw] along z (linear between), chamfer},
## sections: name -> {points (x, y) in order round it, z: from, to}}.
const PARTS := {
	"ak": {
		"profiles": {
			"stock": {"points": [Vector2(-0.105, 0.062), Vector2(-0.374, 0.036), Vector2(-0.38, -0.086),
					Vector2(-0.15, -0.024), Vector2(-0.105, -0.004)],
					"width": [Vector2(-0.105, 0.017), Vector2(-0.38, 0.021)], "chamfer": 0.005},
			"butt_plate": {"points": [Vector2(-0.373, 0.038), Vector2(-0.386, 0.037), Vector2(-0.393, -0.088),
					Vector2(-0.379, -0.089)], "width": [Vector2(0.0, 0.0225)], "chamfer": 0.003},
			"grip": {"points": [Vector2(-0.03, 0.0), Vector2(-0.066, 0.0), Vector2(-0.099, -0.1),
					Vector2(-0.094, -0.11), Vector2(-0.068, -0.114), Vector2(-0.057, -0.075),
					Vector2(-0.05, -0.045), Vector2(-0.038, -0.018)], "width": [Vector2(0.0, 0.0155)], "chamfer": 0.004},
			"handguard_lower": {"points": [Vector2(0.27, 0.058), Vector2(0.27, 0.012), Vector2(0.29, 0.003),
					Vector2(0.33, -0.002), Vector2(0.39, 0.002), Vector2(0.42, 0.012), Vector2(0.42, 0.058)],
					"width": [Vector2(0.27, 0.0275), Vector2(0.42, 0.0285)], "chamfer": 0.008},
			"handguard_upper": {"points": [Vector2(0.3, 0.066), Vector2(0.3, 0.09), Vector2(0.31, 0.096),
					Vector2(0.40, 0.096), Vector2(0.41, 0.09), Vector2(0.41, 0.066)],
					"width": [Vector2(0.0, 0.021)], "chamfer": 0.008},
		},
		"sections": {
			"dust_cover": {"points": [Vector2(-0.022, 0.072), Vector2(-0.022, 0.08), Vector2(-0.016, 0.087),
					Vector2(0.0, 0.09), Vector2(0.016, 0.087), Vector2(0.022, 0.08), Vector2(0.022, 0.072)],
					"z": Vector2(-0.1, 0.235)},
		},
	},
	"pdw": {
		"profiles": {
			"receiver": {"points": [Vector2(-0.138, -0.02), Vector2(0.105, -0.02), Vector2(0.112, -0.012),
					Vector2(0.168, -0.012), Vector2(0.168, 0.03), Vector2(0.163, 0.045), Vector2(0.152, 0.054),
					Vector2(0.13, 0.058), Vector2(-0.13, 0.058), Vector2(-0.138, 0.05)],
					"width": [Vector2(0.0, 0.022)], "chamfer": 0.004},
			"grip": {"points": [Vector2(-0.035, -0.018), Vector2(-0.045, -0.05), Vector2(-0.058, -0.072),
					Vector2(-0.06, -0.09), Vector2(-0.074, -0.112), Vector2(-0.091, -0.14), Vector2(-0.095, -0.148),
					Vector2(-0.134, -0.151), Vector2(-0.138, -0.145), Vector2(-0.132, -0.06), Vector2(-0.134, -0.018)],
					"width": [Vector2(0.0, 0.017)], "chamfer": 0.005},
			"guard": {"points": [Vector2(0.047, -0.016), Vector2(0.047, -0.046), Vector2(0.04, -0.054),
					Vector2(0.026, -0.057), Vector2(-0.02, -0.057), Vector2(-0.042, -0.054), Vector2(-0.05, -0.048),
					Vector2(-0.04, -0.016), Vector2(-0.034, -0.016), Vector2(-0.031, -0.036), Vector2(-0.022, -0.046),
					Vector2(-0.006, -0.05), Vector2(0.02, -0.05), Vector2(0.032, -0.044), Vector2(0.037, -0.032),
					Vector2(0.038, -0.016)], "width": [Vector2(0.0, 0.019)], "chamfer": 0.003},
			"well": {"points": [Vector2(0.047, 0.0), Vector2(0.105, 0.0), Vector2(0.105, -0.127),
					Vector2(0.109, -0.135), Vector2(0.043, -0.135), Vector2(0.047, -0.127)],
					"width": [Vector2(0.0, 0.02)], "chamfer": 0.003},
			"butt": {"points": [Vector2(-0.44, 0.058), Vector2(-0.47, 0.061), Vector2(-0.463, 0.0),
					Vector2(-0.462, -0.09), Vector2(-0.47, -0.155), Vector2(-0.44, -0.157)],
					"width": [Vector2(0.0, 0.006)], "chamfer": 0.002},
			"butt_folded": {"points": [Vector2(0.108, 0.058), Vector2(0.138, 0.061), Vector2(0.131, 0.0),
					Vector2(0.13, -0.09), Vector2(0.138, -0.155), Vector2(0.108, -0.157)],
					"width": [Vector2(0.0, 0.006)], "chamfer": 0.002},
		},
		"sections": {},
	},
	"acr": {
		"profiles": {
			# After the photos (0.613 mm a pixel of the right-side one, Docs/LOADOUT.md "ACR"): the upper's bottom runs
			# down to the front, where the handguard's back edge climbs at a slant to the rail.
			"upper": {"points": [Vector2(-0.106, 0.052), Vector2(-0.106, 0.086), Vector2(0.181, 0.086),
					Vector2(0.12, 0.026)], "width": [Vector2(0.0, 0.026)], "chamfer": 0.004},
			# The lower, tall, up to the upper's slanting edge; the magazine well shallow, with a lip.
			"lower": {"points": [Vector2(-0.106, 0.052), Vector2(0.12, 0.026), Vector2(0.124, 0.005),
					Vector2(0.12, -0.02), Vector2(0.124, -0.028), Vector2(0.046, -0.028), Vector2(0.049, -0.02),
					Vector2(0.049, 0.004), Vector2(-0.1, 0.004), Vector2(-0.112, 0.02)],
					"width": [Vector2(0.0, 0.024)], "chamfer": 0.004},
			# The enlarged trigger guard: a U whose top is the lower, sloping down to the front.
			"guard": {"points": [Vector2(0.049, 0.006), Vector2(0.049, -0.02), Vector2(0.04, -0.03),
					Vector2(0.02, -0.035), Vector2(-0.02, -0.035), Vector2(-0.035, -0.03), Vector2(-0.042, -0.02),
					Vector2(-0.04, 0.006), Vector2(-0.032, 0.006), Vector2(-0.03, -0.015), Vector2(-0.02, -0.026),
					Vector2(0.018, -0.027), Vector2(0.032, -0.022), Vector2(0.04, -0.012), Vector2(0.041, 0.006)],
					"width": [Vector2(0.0, 0.008)], "chamfer": 0.002},
			# The MOE grip: raked, a flared bottom.
			"grip": {"points": [Vector2(-0.035, 0.004), Vector2(-0.042, -0.02), Vector2(-0.06, -0.055),
					Vector2(-0.077, -0.084), Vector2(-0.081, -0.092), Vector2(-0.109, -0.09), Vector2(-0.112, -0.083),
					Vector2(-0.101, -0.04), Vector2(-0.094, 0.004)], "width": [Vector2(0.0, 0.016)], "chamfer": 0.004},
			# The handguard, deep and long (14.5" and 18"), short with the 10.5" barrel (as in the catalogue).
			"handguard": {"points": [Vector2(0.12, 0.026), Vector2(0.181, 0.086), Vector2(0.417, 0.086),
					Vector2(0.421, 0.078), Vector2(0.421, 0.03), Vector2(0.415, 0.02), Vector2(0.405, 0.016),
					Vector2(0.13, 0.016)], "width": [Vector2(0.0, 0.03)], "chamfer": 0.007},
			"handguard_short": {"points": [Vector2(0.12, 0.026), Vector2(0.181, 0.086), Vector2(0.35, 0.086),
					Vector2(0.354, 0.078), Vector2(0.354, 0.03), Vector2(0.348, 0.02), Vector2(0.338, 0.016),
					Vector2(0.13, 0.016)], "width": [Vector2(0.0, 0.03)], "chamfer": 0.007},
			# The stock, solid: the cheek riser on top, the butt, the bottom slanting up to the hinge. Folded: the same
			# turned round the hinge (z -0.108).
			"stock": {"points": [Vector2(-0.112, 0.02), Vector2(-0.17, 0.02), Vector2(-0.279, -0.05),
					Vector2(-0.29, -0.058), Vector2(-0.307, -0.055), Vector2(-0.307, 0.082), Vector2(-0.29, 0.082),
					Vector2(-0.262, 0.084), Vector2(-0.255, 0.094), Vector2(-0.112, 0.088)],
					"width": [Vector2(0.0, 0.02)], "chamfer": 0.005},
			"stock_folded": {"points": [Vector2(-0.104, 0.088), Vector2(0.039, 0.094), Vector2(0.046, 0.084),
					Vector2(0.074, 0.082), Vector2(0.091, 0.082), Vector2(0.091, -0.055), Vector2(0.074, -0.058),
					Vector2(0.063, -0.05), Vector2(-0.046, 0.02), Vector2(-0.104, 0.02)],
					"width": [Vector2(0.0, 0.02)], "chamfer": 0.005},
		},
		"sections": {},
	},
	"mp7": {
		"profiles": {
			# After the owner's photos of a Tokyo Marui MP7A1 (Docs/LOADOUT.md, "MP7"; 0.658 mm a pixel of the left
			# side): the receiver one block under the rail, its front sloping down to the chin under the barrel.
			"receiver": {"points": [Vector2(0.1263, 0.0658), Vector2(-0.1665, 0.0658), Vector2(-0.1717, 0.0619),
					Vector2(-0.1717, 0.0), Vector2(0.1546, 0.0), Vector2(0.1606, -0.0046), Vector2(0.1717, -0.0046),
					Vector2(0.1731, 0.0013), Vector2(0.1678, 0.0118), Vector2(0.1652, 0.0296), Vector2(0.1586, 0.0461),
					Vector2(0.152, 0.0592), Vector2(0.1263, 0.0592)], "width": [Vector2(0.0, 0.021)], "chamfer": 0.004},
			# The trigger guard: an L from the receiver down and back into the grip's front; its opening is a notch.
			"guard": {"points": [Vector2(0.0375, 0.0), Vector2(0.0375, -0.0145), Vector2(0.0322, -0.0237),
					Vector2(0.0243, -0.027), Vector2(-0.023, -0.027), Vector2(-0.023, -0.0211), Vector2(0.023, -0.0211),
					Vector2(0.0283, -0.0178), Vector2(0.0303, -0.0105), Vector2(0.0303, 0.0)],
					"width": [Vector2(0.0, 0.0045)], "chamfer": 0.001},
			# The grip, near upright, the magazine inside it; the front strap leaning forward to the bottom.
			"grip": {"points": [Vector2(-0.0224, 0.0013), Vector2(-0.0197, -0.0263), Vector2(-0.0178, -0.0592),
					Vector2(-0.0158, -0.0855), Vector2(-0.0151, -0.0974), Vector2(-0.0796, -0.098), Vector2(-0.0783, -0.0724),
					Vector2(-0.073, -0.0329), Vector2(-0.0691, 0.0013)], "width": [Vector2(0.0, 0.016)], "chamfer": 0.004},
			# The butt plate: thin at the top, its bottom swept back. The stock's rods carry it back 0.223 m.
			"butt": {"points": [Vector2(-0.1717, 0.0513), Vector2(-0.1994, 0.0461), Vector2(-0.2046, 0.0395),
					Vector2(-0.206, -0.0526), Vector2(-0.2007, -0.0592), Vector2(-0.1895, -0.0579), Vector2(-0.1862, -0.0461),
					Vector2(-0.1744, 0.0066)], "width": [Vector2(0.0, 0.02)], "chamfer": 0.004},
		},
		"sections": {},
	},
	"luger": {
		"profiles": {
			# After the photos of a WE P08 6" (Docs/LOADOUT.md, "Люгер"; 0.402 mm a pixel): the trigger guard's small round
			# loop and the grip frame in one outline, the guard's opening a notch up to the frame; thin at the guard,
			# the grip's width behind it; the back strap's hump under the frame's rear.
			"frame_lower": {"points": [Vector2(0.0185, 0.0107), Vector2(0.0205, 0.0027), Vector2(0.0185, -0.007),
					Vector2(0.0133, -0.0146), Vector2(0.0056, -0.019), Vector2(-0.0028, -0.0186), Vector2(-0.01, -0.0154),
					Vector2(-0.0229, -0.015), Vector2(-0.0362, -0.0371), Vector2(-0.0482, -0.058), Vector2(-0.0603, -0.0793),
					Vector2(-0.0595, -0.0858), Vector2(-0.0764, -0.0886), Vector2(-0.1013, -0.0898), Vector2(-0.1061, -0.0822),
					Vector2(-0.1053, -0.0745), Vector2(-0.0965, -0.052), Vector2(-0.0844, -0.0263), Vector2(-0.0764, -0.013),
					Vector2(-0.0732, -0.0038), Vector2(-0.0764, 0.0035), Vector2(-0.0844, 0.0083), Vector2(-0.0949, 0.0115),
					Vector2(-0.0056, 0.0107), Vector2(-0.0076, 0.0051), Vector2(-0.008, -0.0022), Vector2(-0.0056, -0.0102),
					Vector2(0.0, -0.015), Vector2(0.0072, -0.0154), Vector2(0.0137, -0.011), Vector2(0.0161, -0.0038),
					Vector2(0.0153, 0.0039), Vector2(0.0121, 0.0107)],
					"width": [Vector2(-0.02, 0.0125), Vector2(-0.008, 0.005)], "chamfer": 0.001},  # the loop is 4 mm: a bigger chamfer crosses it
			# The frame above them: thin under the barrel extension, the rounded nose in front.
			"frame_upper": {"points": [Vector2(-0.0965, 0.0212), Vector2(0.033, 0.0212), Vector2(0.0338, 0.0163),
					Vector2(0.0314, 0.0123), Vector2(0.0273, 0.0107), Vector2(-0.0949, 0.0107)],
					"width": [Vector2(0.0, 0.012)], "chamfer": 0.002},
			# The grip panels over the grip frame, a strap's width inside its outline.
			"grip_panels": {"points": [Vector2(-0.0141, 0.0083), Vector2(-0.0716, 0.0083), Vector2(-0.0732, -0.0038),
					Vector2(-0.0748, -0.013), Vector2(-0.0828, -0.0263), Vector2(-0.0945, -0.052), Vector2(-0.1021, -0.0681),
					Vector2(-0.1025, -0.0773), Vector2(-0.0973, -0.0842), Vector2(-0.0764, -0.0858), Vector2(-0.0627, -0.0834),
					Vector2(-0.0571, -0.0753), Vector2(-0.0462, -0.0564), Vector2(-0.0342, -0.0359), Vector2(-0.0221, -0.015),
					Vector2(-0.0153, -0.0022)], "width": [Vector2(0.0, 0.0155)], "chamfer": 0.004},
		},
		"sections": {},
	},
}


func _initialize() -> void:
	for weapon: String in PARTS:
		var profiles: Dictionary = PARTS[weapon]["profiles"]
		for name: String in profiles:
			var p: Dictionary = profiles[name]
			_save(_profile_solid(PackedVector2Array(p["points"]), p["width"], p["chamfer"]), weapon, name)
		var sections: Dictionary = PARTS[weapon]["sections"]
		for name: String in sections:
			var s: Dictionary = sections[name]
			_save(_section_solid(PackedVector2Array(s["points"]), s["z"]), weapon, name)
	quit()


func _save(mesh: Mesh, weapon: String, name: String) -> void:
	var path := DIR + "%s_%s_mesh.tres" % [weapon, name]
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
