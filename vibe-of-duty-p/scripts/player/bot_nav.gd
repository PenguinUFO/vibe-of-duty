class_name BotNav
extends RefCounted
## Way-finding of the archetype bots (Docs/BOTS.md; PlayerBots._bot_arch_cmd): a navigation mesh baked from the
## level's static colliders when the bot's client has loaded the map, on a navigation map of its own. Nothing is
## stored with the level: whatever the owner moves in the scene is in the next launch's mesh.
## Flat maps only: the mesh's up is +Y (not the ring station).
## Not in the mesh: blocks that travel (a crane's load - Block.ride_offset_at): where they stood at the bake is no
## floor a minute later. Baked only round the spawn points (BOUNDS): a level's endless ground plane
## (WorldBoundaryShape3D) crashes the bake otherwise.
## Check: tools/nav_test.gd.

const CELL := 0.15           # m: the mesh's voxel
const AGENT_RADIUS := 0.3    # m: the path keeps this far from walls. Less than the body (PlayerBase.RADIUS): with
                            # 0.45 the mesh did not pass the plane's cockpit door and the dry dock's walkway stair
const MAX_CLIMB := CELL * 3   # m: a step walked up without a jump
const MAX_SLOPE := 46.0      # deg
const REPATH := 0.5          # s between path searches to the same goal
const REACH := 0.6           # m (flat) to a path point: it is passed
const ARRIVE := 1.5          # m from a way's end to its goal: the way reaches it
const BOUNDS := Vector3(30.0, 12.0, 30.0)  # m round the box of the spawn points that is baked

var _map: RID
var _region: RID
var _path := PackedVector3Array()
var _next := 0               # index of the path point it walks to
var _goal := Vector3.INF
var _age := 0.0              # s since the path was searched
var _ready := false
var polygons := 0            # of the baked mesh (0: nothing to walk on)
var reaches := false         # the path of the last next_point() ends at its goal (not at the nearest place to it)


## Bakes the mesh of `level` (blocks the frame while it bakes).
func build(level: Node) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.WORLD
	mesh.cell_size = CELL
	mesh.cell_height = CELL
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = PlayerBase.STAND_HEIGHT
	mesh.agent_max_climb = MAX_CLIMB
	mesh.agent_max_slope = MAX_SLOPE
	# Monotone, not the default watershed: that one tore the mesh on stairs stacked over stairs (the tower's core);
	# layers mends it too, but bakes the dry dock for 22 s.
	mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE
	var spawns := level.get_node_or_null("SpawnPoints")
	if spawns != null and spawns.get_child_count() > 0:
		var box := AABB((spawns.get_child(0) as Node3D).global_position, Vector3.ZERO)
		for spawn in spawns.get_children():
			box = box.expand((spawn as Node3D).global_position)
		mesh.filter_baking_aabb = AABB(box.position - BOUNDS, box.size + BOUNDS * 2.0)
	# The parser takes static bodies by their layer: the travelling blocks are off it while it reads the level.
	var movers := {}
	for node in level.find_children("*", "Block", true, false):
		var block := node as Block
		if block.ride_offset_at.is_valid():
			movers[block] = block.collision_layer
			block.collision_layer = 0
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, level)
	for block: Block in movers:
		block.collision_layer = movers[block]
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, CELL)
	NavigationServer3D.map_set_cell_height(_map, CELL)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	polygons = mesh.get_polygon_count()


## The point to walk to now on the way from `from` to `goal` (feet positions); `from` itself: no way or arrived.
func next_point(from: Vector3, goal: Vector3, delta: float) -> Vector3:
	_age += delta
	if _age >= REPATH or goal.distance_to(_goal) > 1.0:
		_age = 0.0
		_goal = goal
		_next = 0
		_path = way(from, goal)
		reaches = not _path.is_empty() and _path[_path.size() - 1].distance_to(goal) < ARRIVE
	while _next < _path.size():
		var to := _path[_next] - from
		if Vector2(to.x, to.z).length() > REACH or absf(to.y) > 1.5:
			return _path[_next]
		_next += 1
	return from


## The navigation server has taken the mesh in (a frame or a few after build()): a way() has come back with points.
func ready() -> bool:
	return _ready


## The whole way from `from` to `to` (empty: the mesh is not in yet). It ends at the mesh point nearest to `to`.
func way(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := NavigationServer3D.map_get_path(_map, from, to, true)
	_ready = _ready or not path.is_empty()
	return path


## Drops the path: the next call searches again.
func forget() -> void:
	_goal = Vector3.INF


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _region.is_valid():
			NavigationServer3D.free_rid(_region)
		if _map.is_valid():
			NavigationServer3D.free_rid(_map)
