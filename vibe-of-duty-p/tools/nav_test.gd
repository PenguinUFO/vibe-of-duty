extends Node
## Checks the bots' navigation mesh (BotNav, Docs/BOTS.md) on the maps without bots: bake time, and for every pair of
## spawn points whether the way from one reaches the other (ends within 1.5 m of it). A pair with no way: the mesh is
## torn somewhere between them (a step too high, a door too narrow, a stair too steep).
##   Godot_v4.7.2.exe --headless --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=nav_test
## Env: NAV_MAPS=elysium,tower (default: every match map), NAV_VERBOSE=1 (every broken pair with where its way ends).


func _ready() -> void:
	var maps: Array[String] = Game.list_maps()
	if OS.get_environment("NAV_MAPS") != "":
		maps.clear()
		for base in OS.get_environment("NAV_MAPS").split(","):
			maps.append(Game.MAPS_DIR.path_join(base + ".tscn"))
	for path in maps:
		await _check(path)
	get_tree().quit()


func _check(path: String) -> void:
	var level: Node3D = load(path).instantiate()
	level.get_node("World").queue_free()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nav := BotNav.new()
	var start := Time.get_ticks_msec()
	nav.build(level)
	var bake_ms := Time.get_ticks_msec() - start
	for i in 300:  # the navigation server takes the region in a frame or a few later
		await get_tree().physics_frame
		nav.way(Vector3.ZERO, Vector3.ZERO)
		if nav.ready():
			break
	var spawns: Array[Node] = level.get_node("SpawnPoints").get_children()
	var broken := 0
	var pairs := 0
	var off_mesh := 0
	var bad_spawns := {}
	for a: Node3D in spawns:
		var here := nav.way(a.global_position, a.global_position)
		if here.is_empty() or here[here.size() - 1].distance_to(a.global_position) > 1.5:
			off_mesh += 1
			if OS.get_environment("NAV_VERBOSE") != "":
				print("  off the mesh: %s %s -> %s" % [a.name, a.global_position, here[here.size() - 1] if not here.is_empty() else "none"])
		for b: Node3D in spawns:
			if a == b:
				continue
			pairs += 1
			var way := nav.way(a.global_position, b.global_position)
			if way.is_empty() or way[way.size() - 1].distance_to(b.global_position) > BotNav.ARRIVE:
				broken += 1
				bad_spawns[a.name] = int(bad_spawns.get(a.name, 0)) + 1
				if OS.get_environment("NAV_VERBOSE") != "":
					print("  no way: %s -> %s, ends at %s" % [a.name, b.name, way[way.size() - 1] if not way.is_empty() else "none"])
	print("[NAV] %-10s bake %5d ms, polygons %6d, spawns %2d (off the mesh %d), broken pairs %d / %d %s" % [
			path.get_file().get_basename(), bake_ms, nav.polygons, spawns.size(), off_mesh, broken, pairs, bad_spawns])
	level.queue_free()
	await get_tree().process_frame
