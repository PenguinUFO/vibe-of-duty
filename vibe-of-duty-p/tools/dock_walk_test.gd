extends Node
## Checks the dry dock's walkable graph without bots (Docs/LEVEL_DRYDOCK.md): every spawn stands on a floor with head
## room, and from each spawn a flood fill over a 1 m grid of floors (steps up to 0.45 m between neighbours, the capsule
## fits) reaches the named places. Mantles and jumps do not count, so what it reaches, a walker reaches. Then the
## torpedo must move.
## Run windowed or headless: Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=dock_walk_test

const STEP := 0.5                 # m, the grid
const CLIMB := 0.45               # m of height between neighbours
const AREA := Rect2(-76.0, -56.0, 152.0, 112.0)
const PLACES := {
	"dock floor": Vector3(-20.0, -6.0, 6.5), "under the sub": Vector3(-20.0, -6.0, 0.0),
	"sub lower 1": Vector3(-19.5, -3.0, -2.0), "sub lower 4": Vector3(22.5, -3.0, 2.0),
	"sub upper 2": Vector3(-5.5, -0.4, -2.0), "sub upper 4": Vector3(22.5, -0.4, -2.0),
	"sub deck": Vector3(-15.0, 2.4, 0.0), "gate": Vector3(43.7, 0.0, 0.0), "ice": Vector3(52.0, -1.2, 0.0),
	"boat deck": Vector3(61.5, 2.0, -15.0), "pier": Vector3(50.5, 0.0, 30.0), "gallery": Vector3(-15.0, 4.0, -44.0),
	"hq up": Vector3(-66.0, 3.8, -42.0), "barracks up": Vector3(-47.0, 3.8, 35.0), "stores roof": Vector3(-25.0, 6.3, 32.0),
	"boiler walk": Vector3(6.0, 3.4, 33.0), "tunnel": Vector3(-42.0, -6.0, 0.0),
}

var _space: PhysicsDirectSpaceState3D
var _shape := CapsuleShape3D.new()


func _ready() -> void:
	var level: Node3D = load("res://prefabs/levels/drydock.tscn").instantiate()
	level.get_node("World").queue_free()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = level.get_world_3d().direct_space_state
	_shape.radius = 0.3
	_shape.height = 1.7
	var start := Vector3.ZERO
	for spawn: Node3D in level.get_node("SpawnPoints").get_children():
		var floors := _floors(spawn.global_position.x + 0.13, spawn.global_position.z + 0.07)
		var near := _nearest(floors, spawn.global_position.y)
		var ok := absf(near - spawn.global_position.y) < 0.2 and _fits(Vector3(spawn.global_position.x, near, spawn.global_position.z))
		print("spawn %s %s floor %.2f" % [spawn.name, "ok" if ok else "BAD", near])
		if spawn.name == &"SpawnWorkshopWest":
			start = Vector3(spawn.global_position.x + 0.13, near, spawn.global_position.z + 0.07)  # off the blocks' seams
	var seen := _fill(start)
	print("reached %d cells from %s" % [seen.size(), start])
	for place: String in PLACES:
		var p: Vector3 = PLACES[place]
		print("%s %s" % ["reached" if _seen_near(seen, p) else "NOT REACHED", place])
	for spawn: Node3D in level.get_node("SpawnPoints").get_children():
		if not _seen_near(seen, spawn.global_position):
			print("NOT REACHED spawn ", spawn.name)
	var load_node := level.get_node("Shell/TorpedoLoad") as Node3D
	var from := load_node.position.z
	await get_tree().create_timer(6.0).timeout
	print("torpedo %s: z %.2f -> %.2f" % ["moves" if load_node.position.z != from else "STANDS", from, load_node.position.z])
	get_tree().quit()


func _seen_near(seen: Dictionary, p: Vector3) -> bool:
	var key := _key(p.x, p.y, p.z)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if seen.has(key + Vector3i(dx, dy, dz)):
					return true
	return false


func _key(x: float, y: float, z: float) -> Vector3i:
	return Vector3i(roundi(x / STEP), roundi(y), roundi(z / STEP))


## Heights of the floors over (x, z), top down.
func _floors(x: float, z: float) -> Array[float]:
	var out: Array[float] = []
	var from := Vector3(x, 40.0, z)
	var exclude: Array[RID] = []
	for i in 12:
		var query := PhysicsRayQueryParameters3D.create(from, Vector3(x, -8.5, z), Layers.WORLD, exclude)
		query.hit_from_inside = false
		var hit := _space.intersect_ray(query)
		if hit.is_empty():
			break
		if (hit["normal"] as Vector3).y > 0.65:
			out.append((hit["position"] as Vector3).y)
		exclude.append(hit["rid"])
	return out


func _nearest(floors: Array[float], y: float) -> float:
	var best := INF
	for f in floors:
		if absf(f - y) < absf(best - y):
			best = f
	return best


func _fits(feet: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 1.0)
	query.collision_mask = Layers.WORLD
	return _space.intersect_shape(query, 1).is_empty()


func _fill(start: Vector3) -> Dictionary:
	var seen := {}
	var queue: Array[Vector3] = [start]
	seen[_key(start.x, start.y, start.z)] = true
	while not queue.is_empty():
		var p: Vector3 = queue.pop_back()
		for d: Vector2 in [Vector2(STEP, 0), Vector2(-STEP, 0), Vector2(0, STEP), Vector2(0, -STEP)]:
			var x := p.x + d.x
			var z := p.z + d.y
			if not AREA.has_point(Vector2(x, z)):
				continue
			for f in _floors(x, z):
				if absf(f - p.y) > CLIMB:
					continue
				var key := _key(x, f, z)
				if seen.has(key):
					continue
				var q := Vector3(x, f, z)
				if _fits(q):
					seen[key] = true
					queue.append(q)
	return seen
