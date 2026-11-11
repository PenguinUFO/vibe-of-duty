class_name BotNav
extends RefCounted
## Way-finding of the archetype bots (Docs/BOTS.md; PlayerBots._bot_arch_cmd): a navigation mesh baked from the
## level's static colliders when the bot's client has loaded the map, on a navigation map of its own. Nothing is
## stored with the level: whatever the owner moves in the scene is in the next launch's mesh.
## Flat maps only: the mesh's up is +Y (not the ring station).

const CELL := 0.15           # m: the mesh's voxel
const AGENT_RADIUS := 0.45   # m: the path keeps this far from walls (the body is PlayerBase.RADIUS)
const MAX_CLIMB := 0.45      # m: a step walked up without a jump
const MAX_SLOPE := 46.0      # deg
const REPATH := 0.5          # s between path searches to the same goal
const REACH := 0.6           # m (flat) to a path point: it is passed

var _map: RID
var _region: RID
var _path := PackedVector3Array()
var _next := 0               # index of the path point it walks to
var _goal := Vector3.INF
var _age := 0.0              # s since the path was searched


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
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, level)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, CELL)
	NavigationServer3D.map_set_cell_height(_map, CELL)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	if Game.net_log:
		print("[NAV] baked: %d polygons" % mesh.get_polygon_count())


## The point to walk to now on the way from `from` to `goal` (feet positions); `from` itself: no way or arrived.
func next_point(from: Vector3, goal: Vector3, delta: float) -> Vector3:
	_age += delta
	if _age >= REPATH or goal.distance_to(_goal) > 1.0:
		_age = 0.0
		_goal = goal
		_next = 0
		_path = PackedVector3Array()
		if NavigationServer3D.map_get_iteration_id(_map) > 0:  # the server has taken the region in
			_path = NavigationServer3D.map_get_path(_map, from, goal, true)
	while _next < _path.size():
		var to := _path[_next] - from
		if Vector2(to.x, to.z).length() > REACH or absf(to.y) > 1.5:
			return _path[_next]
		_next += 1
	return from


## Drops the path: the next call searches again.
func forget() -> void:
	_goal = Vector3.INF


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _region.is_valid():
			NavigationServer3D.free_rid(_region)
		if _map.is_valid():
			NavigationServer3D.free_rid(_map)
