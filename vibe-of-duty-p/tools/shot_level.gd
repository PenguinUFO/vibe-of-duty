extends SceneTree
## Renders a map (SHOT_MAP, default the train) from a few views to ../shots/level_<view>.png and prints the GPU time of each view
## (vsync off, 1080p). Run windowed: Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_level.gd

const VIEWS := {  # train.tscn (cars along z, 20 m each: A from -42.1, B -20.7, C 0.7, D 22.1)
	"a_lower": [Vector3(0.3, 1.65, -40.0), Vector3(0.0, 1.2, -28.0)],
	"a_upper": [Vector3(-0.5, 4.95, -24.0), Vector3(0.5, 4.6, -36.0)],
	"b_lower": [Vector3(-1.0, 1.65, -19.5), Vector3(0.5, 1.0, -8.0)],
	"b_upper": [Vector3(0.0, 4.95, -19.0), Vector3(0.0, 4.6, -6.0)],
	"cargo": [Vector3(2.0, 4.95, 2.0), Vector3(-1.0, 1.0, 14.0)],
	"d_upper": [Vector3(2.0, 4.95, 39.0), Vector3(1.5, 4.6, 28.0)],
	"outside": [Vector3(16.0, 3.5, -20.0), Vector3(0.0, 2.5, 0.0)],
	"window": [Vector3(2.3, 1.65, 32.0), Vector3(12.0, 0.5, 30.0)],
}
const FRAMES := 120


func _initialize() -> void:
	await process_frame  # Settings applies vsync after the first frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var map := OS.get_environment("SHOT_MAP") if OS.has_environment("SHOT_MAP") else "train"
	var views: Dictionary = VIEWS
	var level: Node = load("res://prefabs/levels/%s.tscn" % map).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var world = level.get_node("World")
	var scene: PackedScene = load("res://prefabs/player/player.tscn")
	var spots := [Vector3(0.5, 0.05, -38), Vector3(-0.5, 3.35, -18), Vector3(-1.0, 0.05, 2.0)]
	for i in 3:
		var p = scene.instantiate()
		p.control = 2  # puppet
		p.peer_id = 20 + i
		p.player_name = "Bot%d" % i
		p.world = world
		level.get_node("Players").add_child(p)
		world.players[p.peer_id] = p
		p.teleport(Transform3D(Basis.IDENTITY, spots[i]))
	for id in world.players.keys():  # the host's own player would take over the camera and HUD
		if world.players[id].is_local:
			world.players[id].queue_free()
			world.players.erase(id)
	if world.hud:
		world.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 75
	level.add_child(cam)
	cam.current = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var tag := OS.get_environment("SHOT_TAG")
	for hide in OS.get_environment("SHOT_HIDE").split(",", false):  # cost experiments: hide nodes by path
		var node := level.get_node_or_null(hide) as Node3D
		if node:
			node.visible = false
	var scenery := level.get_node_or_null("Scenery")
	for view in views:
		if scenery and OS.has_environment("SHOT_TUNNEL"):  # park a tunnel over the train
			scenery._tunnel.visible = true
			scenery._tunnel_z = -40.0
			scenery._next_tunnel = 999.0
		cam.look_at_from_position(views[view][0], views[view][1])
		for i in 30:
			await process_frame
		var gpu := 0.0
		for i in FRAMES:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		print("%-8s gpu %.2f ms" % [view, gpu / FRAMES])
		root.get_texture().get_image().save_png(dir.path_join("level_%s%s.png" % [view, tag]))
	quit()
