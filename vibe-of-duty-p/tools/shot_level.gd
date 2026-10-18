extends SceneTree
## Renders the test level from a few views to ../shots/level_<view>.png and prints the GPU time of each view
## (vsync off, 1080p). Run windowed: Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_level.gd

const VIEWS := {  # name -> [camera position, look at]
	"spawn": [Vector3(0, 1.65, -34), Vector3(0, 1.4, 0)],
	"cover": [Vector3(-14, 1.65, 8), Vector3(6, 1.0, -14)],
	"high": [Vector3(30, 9, 30), Vector3(0, 0, 0)],
	"wall": [Vector3(18, 1.65, -30), Vector3(-10, 2.0, -40)],
}
const FRAMES := 120


func _initialize() -> void:
	await process_frame  # Settings applies vsync after the first frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var level: Node = load("res://prefabs/levels/test_level.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var world = level.get_node("World")
	var scene: PackedScene = load("res://prefabs/player/player.tscn")
	var spots := [Vector3(-8, 0.05, -20), Vector3(6, 0.05, -14), Vector3(0, 0.05, -8)]
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
	for view in VIEWS:
		cam.look_at_from_position(VIEWS[view][0], VIEWS[view][1])
		for i in 30:
			await process_frame
		var gpu := 0.0
		for i in FRAMES:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		print("%-6s gpu %.2f ms" % [view, gpu / FRAMES])
		root.get_texture().get_image().save_png(dir.path_join("level_%s%s.png" % [view, tag]))
	quit()
