class_name BotNav
extends RefCounted
## Way-finding of the archetype bots (Docs/BOTS.md; PlayerBots._bot_arch_cmd): a navigation mesh baked from the
## level's static colliders when the bot's client has loaded the map, on a navigation map of its own. Nothing is
## stored with the level: whatever the owner moves in the scene is in the next launch's mesh.
## The ring station (Gravity.is_ring): the mesh is baked of the ring rolled out flat - x: metres along the rim (0 at
## the bottom), y: height over the rim, z: across - with a copy each side of the seam; ways are found there and turned
## back into the world (_to_flat, _to_world).
## Not in the mesh: blocks that travel (a crane's load - Block.ride_offset_at): where they stood at the bake is no
## floor a minute later. Cargo that slides (the plane's LooseCargo, moved along x by PlaneBank) is in it where it
## stands now: the mesh is baked again (in the background) when it has moved. Baked only round the spawn points
## (BOUNDS): a level's endless ground plane (WorldBoundaryShape3D) crashes the bake otherwise.
## Check: tools/nav_test.gd.

const CELL := 0.15           # m: the mesh's voxel
const CELL_H := 0.05         # m: the voxel's height (fine: MAX_CLIMB is a few of them)
const AGENT_RADIUS := 0.3    # m: the path keeps this far from walls. Less than the body (PlayerBase.RADIUS): with
                            # 0.45 the mesh did not pass the plane's cockpit door and the dry dock's walkway stair
const MAX_CLIMB := 0.25      # m: a step walked up without a jump. The body has no step-up (its capsule rides up
                            # ~0.1 m): with 0.45 the way went onto the plane's stair ramps from the side and over low
                            # pallets - the bot ran along the edge. Not lower: a ramp's neighbouring cells differ by
                            # CELL * tan(slope), and the dry dock's boiler-house stairs, their feet at the wall, are
                            # reached only from the side - below 0.25 the walkway fell off the mesh.
const MAX_SLOPE := 46.0      # deg
const REPATH := 0.5          # s between path searches to the same goal
const REACH := 0.6           # m (flat) to a path point: it is passed
const ARRIVE := 1.5          # m from a way's end to its goal: the way reaches it
const AHEAD := 0.6           # m along the way past the point nearest to the bot it walks to: it keeps to the line
                            # (straight at the next point it cut corners onto a ramp's edge, the hold floor at its head)
const ABOVE := 0.5           # m above the feet the mesh may be where a way starts (off the mesh - on cargo, under
                            # a ceiling too low to be in it - the nearest point was the deck overhead)
const BOUNDS := Vector3(30.0, 12.0, 30.0)  # m round the box of the spawn points that is baked
const CARGO_MOVED := 0.15    # m a LooseCargo has slid since the bake: baked again...
const CARGO_CHECK := 0.5     # s ...checked this often
const RING_SPLIT := 0.05     # rad: a triangle's edge longer round the ring is split before it is rolled out (its
                            # straight chord bends: 1.3 m at R 26 sags 8 mm)

var _map: RID
var _region: RID
var _path := PackedVector3Array()
var _next := 0               # index of the path point it walks to
var _goal := Vector3.INF
var _age := 0.0              # s since the path was searched
var _ready := false
var polygons := 0            # of the baked mesh (0: nothing to walk on)
var reaches := false         # the path of the last next_point() ends at its goal (not at the nearest place to it)
var _settings: NavigationMesh  # the bake's settings (a copy of it is baked each time)
var _static := NavigationMeshSourceGeometryData3D.new()  # the level without its LooseCargo
var _cargo: Array[Dictionary] = []  # {node, source (parsed where it stood), x (its position.x then), baked (x in the mesh)}
var _cargo_check := 0.0
var _baking := false
var _ring_r := 0.0           # the ring's rim radius (0: a flat map)
var _ring_axis := 0.0        # the axis runs along Z through (0, this, 0)


## Bakes the mesh of `level` (blocks the frame while it bakes).
func build(level: Node) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.WORLD
	mesh.cell_size = CELL
	mesh.cell_height = CELL_H
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = PlayerBase.STAND_HEIGHT
	mesh.agent_max_climb = MAX_CLIMB
	mesh.agent_max_slope = MAX_SLOPE
	# Monotone, not the default watershed: that one tore the mesh on stairs stacked over stairs (the tower's core);
	# layers mends it too, but bakes the dry dock for 22 s.
	mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE
	if Gravity.is_ring():
		_ring_r = Gravity.ring_radius
		_ring_axis = Gravity.ring_axis_y
	var spawns := level.get_node_or_null("SpawnPoints")
	if spawns != null and spawns.get_child_count() > 0:
		var box := AABB(_to_flat((spawns.get_child(0) as Node3D).global_position), Vector3.ZERO)
		for spawn in spawns.get_children():
			box = box.expand(_to_flat((spawn as Node3D).global_position))
		box = AABB(box.position - BOUNDS, box.size + BOUNDS * 2.0)
		if _ring_r > 0.0:  # all round, and a ring further each way: a way across the seam is in one piece
			var round := TAU * _ring_r
			box.position.x = -round
			box.size.x = round * 2.0
		mesh.filter_baking_aabb = box
	_settings = mesh
	# The parser takes static bodies by their layer: the travelling blocks and the sliding cargo are off it while it
	# reads the level; each cargo is read on its own, to be put in where it stands at each bake.
	var off := {}
	for node in level.find_children("*", "Block", true, false):
		var block := node as Block
		if block.ride_offset_at.is_valid():
			off[block] = block.collision_layer
			block.collision_layer = 0
	var cargo_nodes := level.find_children("*", "LooseCargo", true, false)
	for cargo in cargo_nodes:
		for node in cargo.find_children("*", "CollisionObject3D", true, false):
			var body := node as CollisionObject3D
			if not off.has(body):
				off[body] = body.collision_layer
				body.collision_layer = 0
	NavigationServer3D.parse_source_geometry_data(mesh, _static, level)
	for body: CollisionObject3D in off:
		body.collision_layer = off[body]
	if _ring_r > 0.0:
		_static = _roll_out(_static, mesh.filter_baking_aabb)
	for cargo: Node3D in cargo_nodes:
		var source := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh, source, cargo)
		if source.has_data():
			_cargo.append({"node": cargo, "source": source, "x": cargo.position.x, "baked": cargo.position.x})
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, CELL)
	NavigationServer3D.map_set_cell_height(_map, CELL_H)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	var baked := _settings.duplicate() as NavigationMesh
	NavigationServer3D.bake_from_source_geometry_data(baked, _source())
	_baked(baked)


## The level's geometry with each LooseCargo where it stands now (moved along x from where it was read).
func _source() -> NavigationMeshSourceGeometryData3D:
	var source := NavigationMeshSourceGeometryData3D.new()
	source.merge(_static)
	for cargo in _cargo:
		var node: Node3D = cargo["node"]
		var shift: float = node.position.x - cargo["x"]
		cargo["baked"] = node.position.x
		var parsed: NavigationMeshSourceGeometryData3D = cargo["source"]
		var vertices := parsed.get_vertices()
		for i in range(0, vertices.size(), 3):
			vertices[i] += shift
		source.append_arrays(vertices, parsed.get_indices())
	return source


func _baked(mesh: NavigationMesh) -> void:
	_baking = false
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	polygons = mesh.get_polygon_count()
	forget()


## Cargo has slid since the last bake: bakes again in the background (the old mesh serves till then).
func _follow_cargo(delta: float) -> void:
	_cargo_check -= delta
	if _cargo.is_empty() or _baking or _cargo_check > 0.0:
		return
	_cargo_check = CARGO_CHECK
	for cargo in _cargo:
		if absf((cargo["node"] as Node3D).position.x - cargo["baked"]) > CARGO_MOVED:
			_baking = true
			var mesh := _settings.duplicate() as NavigationMesh
			NavigationServer3D.bake_from_source_geometry_data_async(mesh, _source(), _baked.call_deferred.bind(mesh))
			return


## The point to walk to now on the way from `from` to `goal` (feet positions); `from` itself: no way or arrived.
func next_point(from: Vector3, goal: Vector3, delta: float) -> Vector3:
	_follow_cargo(delta)
	var here := _to_flat(from)
	var there := _to_flat(goal, here.x)
	_age += delta
	if _age >= REPATH or there.distance_to(_goal) > 1.0:
		_age = 0.0
		_goal = there
		_next = 0
		_path = _way(_ground(here), there)
		reaches = not _path.is_empty() and _path[_path.size() - 1].distance_to(there) < ARRIVE
	while _next < _path.size():
		var to := _path[_next] - here
		if Vector2(to.x, to.z).length() > REACH or absf(to.y) > 1.5:
			return _to_world(_along(here))
		_next += 1
	return from


## AHEAD past the point of the way's leg to the next point nearest to `from` (flat), the next point at most.
func _along(from: Vector3) -> Vector3:
	var to := _path[_next]
	if _next == 0:
		return to
	var start := _path[_next - 1]
	var leg := Vector2(to.x - start.x, to.z - start.z)
	var length := leg.length()
	if length < 0.01:
		return to
	var done := Vector2(from.x - start.x, from.z - start.z).dot(leg) / length + AHEAD
	return to if done >= length else start.lerp(to, maxf(done, 0.0) / length)


## The mesh point a way from `at` (feet) starts at: the nearest one not above the feet. Up on cargo or anything off
## the mesh, the nearest may be the deck overhead: then the nearest to points further down.
func _ground(at: Vector3) -> Vector3:
	if NavigationServer3D.map_get_iteration_id(_map) == 0:  # not synchronized yet: queries fail
		return at
	var nearest := NavigationServer3D.map_get_closest_point(_map, at)
	for i in 7:
		var point := NavigationServer3D.map_get_closest_point(_map, at - Vector3(0.0, 0.5 * i, 0.0))
		if point.y <= at.y + ABOVE:
			return point
	return nearest


## The navigation server has taken the mesh in (a frame or a few after build()): a way() has come back with points.
func ready() -> bool:
	return _ready


## The whole way from `from` to `to` (empty: the mesh is not in yet). It ends at the mesh point nearest to `to`.
func way(from: Vector3, to: Vector3) -> PackedVector3Array:
	var here := _to_flat(from)
	var path := _way(here, _to_flat(to, here.x))
	for i in path.size():
		path[i] = _to_world(path[i])
	return path


func _way(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := NavigationServer3D.map_get_path(_map, from, to, true)
	_ready = _ready or not path.is_empty()
	return path


## `at` in the mesh's space: itself on a flat map; on the ring rolled out (x along the rim from the bottom, y over
## it, z across), x on the round of the ring nearest to `near_x`.
func _to_flat(at: Vector3, near_x := 0.0) -> Vector3:
	if _ring_r <= 0.0:
		return at
	var rel := Vector2(at.x, at.y - _ring_axis)
	var s := atan2(rel.x, -rel.y) * _ring_r
	var round := TAU * _ring_r
	s += roundf((near_x - s) / round) * round
	return Vector3(s, _ring_r - rel.length(), at.z)


func _to_world(flat: Vector3) -> Vector3:
	if _ring_r <= 0.0:
		return flat
	var angle := flat.x / _ring_r
	var r := _ring_r - flat.y
	return Vector3(r * sin(angle), _ring_axis - r * cos(angle), flat.z)


## The ring's geometry rolled out flat, with a copy a ring further each way along x; only what reaches into `box`.
func _roll_out(parsed: NavigationMeshSourceGeometryData3D, box: AABB) -> NavigationMeshSourceGeometryData3D:
	var vertices := parsed.get_vertices()
	var indices := parsed.get_indices()
	var pieces := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		var corners: Array[Vector3] = []
		for k in 3:
			var v := indices[i + k] * 3
			corners.append(Vector3(vertices[v], vertices[v + 1], vertices[v + 2]))
		_roll_triangle(corners[0], corners[1], corners[2], pieces, 0)
	var flat := PackedFloat32Array()
	var faces := PackedInt32Array()
	var round := TAU * _ring_r
	for i in range(0, pieces.size(), 3):
		for shift: float in [-round, 0.0, round]:
			var move := Vector3(shift, 0.0, 0.0)
			var tri := [pieces[i] + move, pieces[i + 1] + move, pieces[i + 2] + move]
			var tri_box := AABB(tri[0], Vector3.ZERO).expand(tri[1]).expand(tri[2])
			if not tri_box.grow(0.01).intersects(box):
				continue
			for v: Vector3 in tri:
				faces.append(faces.size())
				flat.append(v.x)
				flat.append(v.y)
				flat.append(v.z)
	var rolled := NavigationMeshSourceGeometryData3D.new()
	rolled.append_arrays(flat, faces)
	return rolled


## Splits a world triangle till no edge spans more than RING_SPLIT round the axis, and rolls the pieces out into
## `out` (each piece's corners on one side of the seam).
func _roll_triangle(a: Vector3, b: Vector3, c: Vector3, out: PackedVector3Array, depth: int) -> void:
	var fa := _to_flat(a)
	var fb := _to_flat(b, fa.x)
	var fc := _to_flat(c, fa.x)
	var spans := [absf(fa.x - fb.x), absf(fb.x - fc.x), absf(fc.x - fa.x)]
	var longest: float = spans.max()
	if longest > RING_SPLIT * _ring_r and depth < 12:
		match spans.find(longest):
			0:
				var m := (a + b) * 0.5
				_roll_triangle(a, m, c, out, depth + 1)
				_roll_triangle(m, b, c, out, depth + 1)
			1:
				var m := (b + c) * 0.5
				_roll_triangle(a, b, m, out, depth + 1)
				_roll_triangle(a, m, c, out, depth + 1)
			_:
				var m := (c + a) * 0.5
				_roll_triangle(a, b, m, out, depth + 1)
				_roll_triangle(m, b, c, out, depth + 1)
		return
	out.append(fa)
	out.append(fb)
	out.append(fc)


## Drops the path: the next call searches again.
func forget() -> void:
	_goal = Vector3.INF


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _region.is_valid():
			NavigationServer3D.free_rid(_region)
		if _map.is_valid():
			NavigationServer3D.free_rid(_map)
