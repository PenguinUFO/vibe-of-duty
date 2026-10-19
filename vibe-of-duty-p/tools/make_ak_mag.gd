extends SceneTree
## Generates prefabs/weapons/ak_mag_mesh.tres: the AK's curved magazine as one smooth mesh (used by
## tools/make_ak_blockout.py under the AK_Mag_01 node). Run from the Godot project folder:
##   godot --headless --path vibe-of-duty-p -s tools/make_ak_mag.gd
##
## The magazine is a chamfered rectangle (WIDTH across, DEPTH front to back) swept down a curve whose forward tilt
## grows evenly from ANGLE_TOP to ANGLE_BOTTOM, so it bends forward like the real banana magazine; the sides are
## smoothly shaded along the curve. A slightly larger floor plate closes the bottom. Prefab space as the rifle's:
## +Y up, +Z towards the muzzle; the origin is the middle of the magazine's top (where it seats in the receiver).

const OUT := "res://prefabs/weapons/ak_mag_mesh.tres"
const LENGTH := 0.215          # along the curve
const SEGMENTS := 12
const ANGLE_TOP := 5.0         # degrees the magazine leans forward at the top...
const ANGLE_BOTTOM := 34.0     # ...and at the bottom
const WIDTH := 0.028
const DEPTH_TOP := 0.06
const DEPTH_BOTTOM := 0.068
const CHAMFER := 0.004
const PLATE := 0.008           # floor plate thickness
const PLATE_GROW := 0.004      # how much it sticks out all round


func _initialize() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []  # [centre, along (down the magazine), forward normal, depth]
	var p := Vector3.ZERO
	var step := LENGTH / SEGMENTS
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var angle := deg_to_rad(lerpf(ANGLE_TOP, ANGLE_BOTTOM, t))
		rings.append([p, Vector3(0.0, -cos(angle), sin(angle)), Vector3(0.0, sin(angle), cos(angle)),
				lerpf(DEPTH_TOP, DEPTH_BOTTOM, t)])
		var mid := deg_to_rad(lerpf(ANGLE_TOP, ANGLE_BOTTOM, (i + 0.5) / SEGMENTS))
		p += Vector3(0.0, -cos(mid), sin(mid)) * step
	_sweep(st, rings, 0.0, false)
	# Floor plate: a short, slightly larger block at the bottom, flat-shaded.
	var last: Array = rings[rings.size() - 1]
	var plate_top := [last[0], last[1], last[2], last[3] + PLATE_GROW * 2.0]
	var plate_bottom := [last[0] + last[1] * PLATE, last[1], last[2], last[3] + PLATE_GROW * 2.0]
	_sweep(st, [plate_top, plate_bottom], PLATE_GROW, true)
	_cap(st, rings[0], 0.0, true)
	_cap(st, plate_top, PLATE_GROW, true)
	_cap(st, plate_bottom, PLATE_GROW, false)
	var mesh := st.commit()
	var err := ResourceSaver.save(mesh, OUT)
	print("wrote %s (%s)" % [OUT, error_string(err)])
	quit()


## The cross-section (x across, n forward), corners in order round the outline.
static func _profile(depth: float, grow: float) -> PackedVector2Array:
	var hw := WIDTH * 0.5 + grow
	var hn := depth * 0.5
	var c := CHAMFER
	return PackedVector2Array([Vector2(-hw + c, hn), Vector2(hw - c, hn), Vector2(hw, hn - c), Vector2(hw, -hn + c),
			Vector2(hw - c, -hn), Vector2(-hw + c, -hn), Vector2(-hw, -hn + c), Vector2(-hw, hn - c)])


static func _point(ring: Array, q: Vector2) -> Vector3:
	return (ring[0] as Vector3) + Vector3.RIGHT * q.x + (ring[2] as Vector3) * q.y


## Side walls between consecutive rings; each wall's normal follows the ring's frame (smooth along the curve).
static func _sweep(st: SurfaceTool, rings: Array, grow: float, flat: bool) -> void:
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var pa := _profile(a[3], grow)
		var pb := _profile(b[3], grow)
		for k in pa.size():
			var k2 := (k + 1) % pa.size()
			var edge := pa[k2] - pa[k]
			var out2 := Vector2(edge.y, -edge.x).normalized()  # outward in the profile plane
			var na := Vector3.RIGHT * out2.x + (a[2] as Vector3) * out2.y
			var nb := na if flat else Vector3.RIGHT * out2.x + (b[2] as Vector3) * out2.y
			_quad(st, _point(a, pa[k]), _point(a, pa[k2]), _point(b, pb[k2]), _point(b, pb[k]), na, na, nb, nb)


## A flat lid over a ring, facing up the magazine (`up`) or down it.
static func _cap(st: SurfaceTool, ring: Array, grow: float, up: bool) -> void:
	var prof := _profile(ring[3], grow)
	var normal: Vector3 = -(ring[1] as Vector3) if up else ring[1]
	var centre: Vector3 = ring[0]
	for k in prof.size():
		_tri(st, centre, _point(ring, prof[k]), _point(ring, prof[(k + 1) % prof.size()]), normal, normal, normal)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3,
		nc: Vector3, nd: Vector3) -> void:
	_tri(st, a, b, c, na, nb, nc)
	_tri(st, a, c, d, na, nc, nd)


## One triangle, wound so its front faces along the normals: (b - a) x (c - a) points out along them (checked on a
## render - the other way round Godot culls the outside and shows the inside of the magazine).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) < 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	for v in [[a, na], [b, nb], [c, nc]]:
		st.set_normal(v[1])
		st.add_vertex(v[0])
