extends SceneTree
## Rendering benchmark. Run it windowed (not --headless) from the project folder:
##   Godot_v4.7.2.exe --path . --script res://tools/bench.gd [-- --quick]
## It loads the test level with four players, renders with vsync off and prints CPU/GPU frame times
## and draw statistics for a set of quality configurations.

const WARMUP_FRAMES := 150
const MEASURE_FRAMES := 240

var _level: Node
var _sun: DirectionalLight3D
var _viewport: Viewport


func _initialize() -> void:
	await process_frame  # autoloads (Settings applies vsync) are ready after the first frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = load("res://prefabs/levels/test_level.tscn").instantiate()
	root.add_child(_level)
	await process_frame
	await process_frame
	_setup_scene()
	_viewport = root
	RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)

	var configs := [
		{"name": "default 720p", "size": Vector2i(1280, 720)},
		{"name": "default 1080p", "size": Vector2i(1920, 1080)},
		{"name": "1080p no shadows", "size": Vector2i(1920, 1080), "shadows": false},
		{"name": "1080p shadow 1024 / 40m", "size": Vector2i(1920, 1080), "shadow_size": 1024, "shadow_dist": 40.0},
		{"name": "1080p no AA", "size": Vector2i(1920, 1080), "fxaa": false},
		{"name": "1080p scale 0.75 (FSR1)", "size": Vector2i(1920, 1080), "scale": 0.75},
		{"name": "1080p scale 0.67 (FSR1)", "size": Vector2i(1920, 1080), "scale": 0.67},
		{"name": "1080p low (no shadows, scale 0.75)", "size": Vector2i(1920, 1080), "shadows": false, "scale": 0.75},
	]
	if "--env" in OS.get_cmdline_user_args():
		configs = [
			{"name": "1080p default", "size": Vector2i(1920, 1080)},
			{"name": "1080p ambient=color (not sky)", "size": Vector2i(1920, 1080), "ambient_color": true},
			{"name": "1080p sky radiance 64", "size": Vector2i(1920, 1080), "radiance": 64},
			{"name": "1080p sky mode incremental", "size": Vector2i(1920, 1080), "sky_mode": Sky.PROCESS_MODE_INCREMENTAL},
			{"name": "1080p sky mode realtime", "size": Vector2i(1920, 1080), "sky_mode": Sky.PROCESS_MODE_REALTIME},
			{"name": "1080p background = flat color", "size": Vector2i(1920, 1080), "flat_bg": true, "ambient_color": true},
			{"name": "1080p tonemap linear", "size": Vector2i(1920, 1080), "tonemap": Environment.TONE_MAPPER_LINEAR},
			{"name": "1080p flat bg + no shadows + no AA", "size": Vector2i(1920, 1080), "flat_bg": true, "ambient_color": true, "shadows": false, "fxaa": false},
		]
	if "--ab" in OS.get_cmdline_user_args():
		var base := {"size": Vector2i(1920, 1080)}
		configs = []
		for round in 2:
			configs.append(base.merged({"name": "A default (sky ambient, FXAA, shadows)"}))
			configs.append(base.merged({"name": "B ambient=color", "ambient_color": true}))
			configs.append(base.merged({"name": "C B + flat background", "ambient_color": true, "flat_bg": true}))
			configs.append(base.merged({"name": "D C + no AA", "ambient_color": true, "flat_bg": true, "fxaa": false}))
			configs.append(base.merged({"name": "E D + no shadows", "ambient_color": true, "flat_bg": true, "fxaa": false, "shadows": false}))
			configs.append(base.merged({"name": "F D + scale 0.67 FSR", "ambient_color": true, "flat_bg": true, "fxaa": false, "scale": 0.67}))
	if "--quick" in OS.get_cmdline_user_args():
		configs = configs.slice(0, 3)
	print("Nodes in tree: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("Renderer: %s  Adapter: %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	for config in configs:
		await _run(config)
	quit()


func _setup_scene() -> void:
	var world = _level.get_node("World")
	var me = world.players[1]
	me.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -34)))
	var scene: PackedScene = load("res://prefabs/player/player.tscn")
	var spots := [Vector3(-8, 0.05, -20), Vector3(6, 0.05, -14), Vector3(0, 0.05, -8)]
	for i in 3:
		var p = scene.instantiate()
		p.control = 2  # puppet
		p.peer_id = 20 + i
		p.player_name = "Bot%d" % i
		p.world = world
		_level.get_node("Players").add_child(p)
		world.players[p.peer_id] = p
		p.teleport(Transform3D(Basis.IDENTITY, spots[i]))
		p.weapons.index = i
	_sun = _level.get_node("Sun")


func _apply(config: Dictionary) -> void:
	var size: Vector2i = config["size"]
	DisplayServer.window_set_size(size)
	root.size = size
	_sun.shadow_enabled = config.get("shadows", true)
	var shadow_size: int = config.get("shadow_size", 2048)
	RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)
	_sun.directional_shadow_max_distance = config.get("shadow_dist", 70.0)
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if config.get("fxaa", true) else Viewport.SCREEN_SPACE_AA_DISABLED
	var env: Environment = _level.get_node("WorldEnvironment").environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if config.get("ambient_color", false) else Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.background_mode = Environment.BG_COLOR if config.get("flat_bg", false) else Environment.BG_SKY
	env.background_color = Color(0.5, 0.65, 0.85)
	env.tonemap_mode = config.get("tonemap", Environment.TONE_MAPPER_FILMIC)
	if env.sky:
		env.sky.radiance_size = config.get("radiance", Sky.RADIANCE_SIZE_256)
		env.sky.process_mode = config.get("sky_mode", Sky.PROCESS_MODE_AUTOMATIC)
	var scale: float = config.get("scale", 1.0)
	root.scaling_3d_scale = scale
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR


func _run(config: Dictionary) -> void:
	_apply(config)
	for i in WARMUP_FRAMES:
		await process_frame
	var wall: Array[float] = []
	var cpu := 0.0
	var gpu := 0.0
	var script_ms := 0.0
	var physics_ms := 0.0
	var last := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append((now - last) / 1000.0)
		last = now
		var rid := root.get_viewport_rid()
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		script_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	wall.sort()
	var avg := 0.0
	for t in wall:
		avg += t
	avg /= wall.size()
	print("%-36s [%dx%d] frame avg %.2f ms (%.0f fps)  p99 %.2f  | render cpu %.2f ms  gpu %.2f ms  | script _process %.2f ms  _physics %.2f ms | draw calls %d  objects %d  tris %dk" % [
		config["name"], root.size.x, root.size.y, avg, 1000.0 / avg, wall[int(wall.size() * 0.99)], cpu / MEASURE_FRAMES, gpu / MEASURE_FRAMES, script_ms / MEASURE_FRAMES, physics_ms / MEASURE_FRAMES,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
