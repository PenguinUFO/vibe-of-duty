extends SceneTree
## Renders a map (SHOT_MAP, default the train) from a few views to ../shots/level_<view>.png and prints the GPU time of each view
## (vsync off, 1080p). Run windowed: Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_level.gd

const VIEWS := {"train": {  # train.tscn (cars along z, 20 m each: A from -42.1, B -20.7, C 0.7, D 22.1)
	"a_lower": [Vector3(0.3, 1.65, -40.0), Vector3(0.0, 1.2, -28.0)],
	"a_upper": [Vector3(-0.5, 4.95, -24.0), Vector3(0.5, 4.6, -36.0)],
	"b_lower": [Vector3(-1.0, 1.65, -19.5), Vector3(0.5, 1.0, -8.0)],
	"b_upper": [Vector3(0.0, 4.95, -19.0), Vector3(0.0, 4.6, -6.0)],
	"cargo": [Vector3(2.0, 4.95, 2.0), Vector3(-1.0, 1.0, 14.0)],
	"d_upper": [Vector3(-2.0, 4.95, 39.0), Vector3(1.5, 4.6, 28.0)],
	"outside": [Vector3(16.0, 3.5, -20.0), Vector3(0.0, 2.5, 0.0)],
	"window": [Vector3(0.5, 1.65, 31.0), Vector3(12.0, 0.5, 30.0)],
	"axis_up": [Vector3(0.0, 4.95, 21.8), Vector3(0.0, 4.6, -40.0)],  # from D's upper front door back along the train
	"axis_low": [Vector3(0.0, 1.65, -0.5), Vector3(0.0, 1.2, -40.0)],  # from C's lower front door into B and A
	"bot": [Vector3(0.0, 1.65, -24.0), Vector3(0.5, 1.0, -38.0)],  # readability of a player at ~14 m (Bot0)
}, "plane": {  # plane.tscn: hold z -22 .. 18, ramp to 22; upper deck (y 4.7) z -30 .. -4
	"hold_fwd": [Vector3(0.0, 1.65, 16.0), Vector3(0.0, 1.2, -20.0)],
	"hold_aft": [Vector3(0.5, 1.65, -12.0), Vector3(0.0, 1.0, 22.0)],
	"ramp": [Vector3(1.5, 1.65, 19.0), Vector3(-3.0, -5.0, 60.0)],
	"door": [Vector3(0.0, 1.65, 7.0), Vector3(4.0, 1.0, 11.0)],
	"deck": [Vector3(0.0, 6.35, -6.0), Vector3(0.0, 5.5, -28.0)],
	"cockpit": [Vector3(0.0, 6.35, -26.0), Vector3(0.0, 5.6, -40.0)],
	"outside": [Vector3(30.0, 12.0, 30.0), Vector3(0.0, 3.0, -5.0)],
}, "tower": {  # tower.tscn: 30 x 30 m, floors at y 0, 4, 8; the core x -4 .. 4, z -6 .. 2
	"l0_front": [Vector3(12.0, 1.65, 13.0), Vector3(-5.0, 2.0, -5.0)],
	"l0_back": [Vector3(12.0, 1.65, -2.0), Vector3(-12.0, 1.0, -12.0)],
	"l1": [Vector3(12.0, 5.65, 1.0), Vector3(-10.0, 6.0, -12.0)],
	"l2": [Vector3(-2.0, 9.65, -13.0), Vector3(20.0, 6.0, 20.0)],
	"edge": [Vector3(0.0, 1.65, 13.0), Vector3(0.0, -20.0, 80.0)],
	"shaft": [Vector3(6.0, 1.65, -3.9), Vector3(2.0, -5.0, -3.9)],
	"crane": [Vector3(10.0, 2.0, 10.0), Vector3(-11.0, 30.0, -11.0)],
	"outside": [Vector3(40.0, 15.0, 40.0), Vector3(0.0, 3.0, 0.0)],
}}
## Where the three puppet players stand, per map (readability checks).
const SPOTS := {
	"train": [Vector3(0.5, 0.05, -38), Vector3(-0.5, 3.35, -18), Vector3(-1.0, 0.05, 2.0)],
	"plane": [Vector3(0.5, 0.05, -10), Vector3(-0.5, 4.75, -18), Vector3(1.0, 0.05, 12)],
	"tower": [Vector3(5.0, 0.05, 5.0), Vector3(-6.0, 4.05, -8.0), Vector3(-9.0, 8.05, -10.0)],
}
const FRAMES := 120


func _initialize() -> void:
	await process_frame  # Settings applies vsync after the first frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var map := OS.get_environment("SHOT_MAP") if OS.has_environment("SHOT_MAP") else "train"
	var views: Dictionary = VIEWS[map]
	var level: Node = load("res://prefabs/levels/%s.tscn" % map).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var world = level.get_node("World")
	var scene: PackedScene = load("res://prefabs/player/player.tscn")
	var spots: Array = SPOTS[map]
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
		if scenery is TrainScenery and OS.has_environment("SHOT_TUNNEL"):  # a tunnel coming over the train: its centre at z -40 now
			var now: float = scenery._world.shared_time() if scenery._world else Time.get_ticks_usec() / 1e6
			scenery._tunnel_start = now - (-40.0 - scenery.TUNNEL_START) / scenery.speed
			scenery._last_time = now
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
