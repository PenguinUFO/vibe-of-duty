extends SceneTree
## Renders a map (SHOT_MAP, default the train) from a few views to ../shots/level_<view>.png and prints the GPU time of each view
## (vsync off, 1080p); SHOT_MOOD=1 - in the PSX style's lighting (Mood, without its dither); SHOT_BANK=s - the plane's
## bank and cargo as at that time; SHOT_DAY=f - the killhouse's day at that share of the match (0..1, with SHOT_MOOD).
## Run windowed: Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_level.gd

const VIEWS := {"plane": {  # plane.tscn: hold z -40 .. 40 (bulkheads at -16, 5, 25.5), ramp to 44; deck y 4.7 z -50 .. 30; belly y -3
	"hold_fwd": [Vector3(0.5, 1.65, -38.0), Vector3(0.0, 1.2, -16.0)],
	"tank": [Vector3(-3.0, 1.65, -3.0), Vector3(0.0, 1.0, -14.0)],
	"heli": [Vector3(-2.0, 1.65, 6.0), Vector3(0.5, 1.5, 20.0)],
	"hold_aft": [Vector3(2.5, 1.65, 27.0), Vector3(0.0, 1.0, 44.0)],
	"ramp": [Vector3(1.5, 1.65, 41.0), Vector3(-3.0, -5.0, 82.0)],
	"belly": [Vector3(0.0, -1.35, -34.0), Vector3(0.0, -1.6, -12.0)],
	"deck": [Vector3(0.0, 6.35, -21.0), Vector3(0.0, 5.5, -44.0)],
	"deck_long": [Vector3(0.0, 6.35, 28.0), Vector3(0.0, 5.5, -50.0)],  # 78 m along the upper deck: past the shadows' reach?
	"troop": [Vector3(0.0, 6.35, 6.0), Vector3(0.0, 5.5, 29.0)],
	"cockpit": [Vector3(0.0, 6.35, -46.0), Vector3(0.0, 5.6, -60.0)],
	"outside": [Vector3(50.0, 18.0, 50.0), Vector3(0.0, 3.0, -5.0)],
}, "train": {  # train.tscn: A -84.9, B -63.5, C -42.1, E -20.7, F 0.7, G 22.1, D 43.5, H 64.9 (+20 each)
	"e_hall": [Vector3(1.5, 1.65, -19.0), Vector3(-0.5, 3.0, -4.0)],
	"e_gallery": [Vector3(2.2, 4.95, -18.5), Vector3(-2.0, 3.5, -3.0)],
	"f_ring": [Vector3(2.2, 4.95, 1.8), Vector3(-1.5, 2.5, 18.0)],
	"g_low": [Vector3(0.5, 1.65, 23.0), Vector3(0.0, 1.5, 40.0)],
	"h_upper": [Vector3(0.0, 4.95, 66.5), Vector3(0.0, 4.6, 84.0)],
	"balcony": [Vector3(1.0, 1.65, 82.0), Vector3(0.0, 1.0, 100.0)],
	"outside": [Vector3(18.0, 5.0, 0.0), Vector3(0.0, 2.5, 20.0)],
	"axis_up": [Vector3(0.0, 4.95, 63.4), Vector3(0.0, 4.6, -80.0)],
	"from_c": [Vector3(0.0, 5.0, -23.0), Vector3(0.0, 3.0, -100.0)],  # from C's landing to the front: B and A far off
	"roofs": [Vector3(-1.0, 8.4, -84.0), Vector3(0.5, 6.6, -40.0)],  # standing on A's roof: the hatches, B's roof, C
	"ledges": [Vector3(13.0, 7.0, -78.0), Vector3(3.0, 4.0, -62.0)],  # A and B's right side: the ledges, their doors
}, "tower": {  # tower.tscn: the west tower (x -15 .. 15), the gap (15 .. 25) with the crane's corridor, the east tower (25 .. 49)
	"l0_front": [Vector3(12.0, 1.65, 13.0), Vector3(-5.0, 2.0, -5.0)],
	"east_l0": [Vector3(47.0, 1.65, 13.0), Vector3(29.0, 1.5, -10.0)],
	"far_under": [Vector3(48.0, 5.65, 14.0), Vector3(-14.0, 1.0, -14.0)],  # the west tower under L1, ~65 m off
	"gap": [Vector3(12.0, 5.65, 2.5), Vector3(24.0, 4.0, -11.0)],  # the corridor docked, from the west L1
	"bridge": [Vector3(15.6, 5.65, -9.8), Vector3(30.0, 5.5, -10.5)],  # inside it, upstairs
	"bridge_low": [Vector3(15.6, 1.65, -10.0), Vector3(30.0, 1.5, -10.0)],  # downstairs, the stair on the left
	"east_l1": [Vector3(47.0, 5.65, 13.0), Vector3(26.0, 5.5, -12.0)],
	"east_l2": [Vector3(48.0, 9.65, -14.0), Vector3(32.0, 8.0, 5.0)],
	"crane": [Vector3(55.0, 24.0, 32.0), Vector3(20.0, 18.0, -8.0)],
	"hoist": [Vector3(34.0, 10.0, 0.0), Vector3(50.0, 17.0, 0.0)],
	"far_towers": [Vector3(-17.0, 9.65, -17.0), Vector3(-140.0, -230.0, -220.0)],  # no cut ends: they sink in the clouds
	"edge_down": [Vector3(50.5, 5.65, 6.0), Vector3(64.0, -300.0, 0.0)],  # straight down past the hoist and the body
	"outside": [Vector3(79.0, 20.0, 40.0), Vector3(19.0, 3.0, 0.0)],
	"walk_entry": [Vector3(-13.0, 1.65, -13.6), Vector3(-3.0, -3.5, -16.5)],  # the walkways a floor below L0
	"walk": [Vector3(-2.0, -2.35, -16.0), Vector3(40.0, -2.0, -16.0)],
	"walk_out": [Vector3(20.0, 6.0, -26.0), Vector3(20.0, -3.0, -15.0)],
}, "killhouse": {  # killhouse.tscn: x -17.25 .. 17.25, z -33.25 .. 33.25; platforms (y 3, rooms under them) north x -4 .. 3, south x 0 .. 7
	"north": [Vector3(-14.0, 1.65, -30.0), Vector3(2.0, 1.0, -20.0)],
	"middle": [Vector3(-12.0, 1.65, -9.0), Vector3(4.0, 1.0, 4.0)],
	"from_platform": [Vector3(2.0, 4.65, -19.0), Vector3(0.0, 1.0, 5.0)],
	"room": [Vector3(2.5, 1.65, -23.0), Vector3(-2.0, 1.3, -18.0)],  # under the north platform, to its windows
	"room_door": [Vector3(-3.0, 1.65, -30.0), Vector3(0.5, 1.5, -22.0)],
	"east_rooms": [Vector3(14.0, 1.65, -14.0), Vector3(16.0, 1.0, 4.0)],
	"south": [Vector3(13.0, 1.65, 29.0), Vector3(-6.0, 1.0, 18.0)],
	"hall": [Vector3(-15.0, 1.65, 30.0), Vector3(2.0, 8.0, -10.0)],  # up into the roof
	"outside": [Vector3(45.0, 30.0, 60.0), Vector3(0.0, 6.0, 0.0)],
}}
## Where the three puppet players stand, per map (readability checks).
const SPOTS := {
	"plane": [Vector3(0.5, 0.05, -30), Vector3(-0.5, 4.75, -30), Vector3(0.0, -2.95, -20)],
	"train": [Vector3(0.5, 0.05, -81.0), Vector3(2.0, 3.35, -14.0), Vector3(2.2, 0.05, 4.0)],
	"tower": [Vector3(29.0, 0.05, 5.0), Vector3(39.0, 4.05, -5.0), Vector3(44.0, 8.05, -12.0)],
	"killhouse": [Vector3(-6.0, 0.05, 6.0), Vector3(1.0, 3.05, -21.0), Vector3(15.0, 0.05, -7.0)],
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
	cam.far = 300.0  # as the player's camera (prefabs/player/player.tscn); a level's SkyScenery may push it out
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
	var sun := level.get_node("Sun") as DirectionalLight3D  # shadows as Settings.apply_sun gives them at high quality
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	var shadow := OS.get_environment("SHOT_SHADOW").split(",", false)  # experiments: splits (2/4), distance, atlas px, blur
	if shadow.size() == 4:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if shadow[0] == "4" 				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = float(shadow[1])
		RenderingServer.directional_shadow_atlas_set_size(int(shadow[2]), true)
		sun.shadow_blur = float(shadow[3])
	if OS.has_environment("SHOT_MOOD"):  # the PSX style's lighting (Mood; the dither post-process is not applied)
		Mood.apply(level, (level.get_node("WorldEnvironment") as WorldEnvironment).environment,
				level.get_node("Sun") as DirectionalLight3D, true)
		for i in 3:
			await physics_frame
	var bank = level.get_node_or_null("Bank")  # PlaneBank, untyped: naming its class would compile it before the autoloads
	if bank and OS.has_environment("SHOT_BANK"):  # the plane's schedule read at this time (s): its bank, the cargo
		bank.time_override = float(OS.get_environment("SHOT_BANK"))
		for i in 3:
			await physics_frame
	var day = level.get_node_or_null("DayCycle")  # DayCycle, untyped like the bank
	if day and OS.has_environment("SHOT_DAY"):  # the day read at this share of the match (0..1; needs SHOT_MOOD)
		day.time_override = float(OS.get_environment("SHOT_DAY"))
		day._apply(day.time_override)
		for i in 3:
			await physics_frame
	var crane = level.get_node_or_null("Crane")  # CraneBridge, untyped like the bank
	if crane and OS.has_environment("SHOT_CRANE"):  # the crane's schedule read at this time (s): where its load is
		crane.time_override = float(OS.get_environment("SHOT_CRANE"))
		for i in 3:
			await physics_frame
	var scenery := level.get_node_or_null("Scenery")
	var only := OS.get_environment("SHOT_VIEWS").split(",", false)  # just these views
	for view in views:
		if not only.is_empty() and not only.has(view):
			continue
		if scenery is TrainScenery and OS.has_environment("SHOT_TUNNEL"):  # a tunnel coming over the train: its centre at z -40 now
			var now: float = scenery._world.shared_time() if scenery._world else Time.get_ticks_usec() / 1e6
			scenery._tunnel_start = now - (-40.0 - scenery.TUNNEL_START) / scenery.speed
			scenery._last_time = now
		cam.look_at_from_position(views[view][0], views[view][1])
		for i in 30:
			await process_frame
		if bank:  # the player's camera leans with the bank
			cam.look_at_from_position(views[view][0], views[view][1])
			cam.rotate_object_local(Vector3.BACK, bank.lean())
		var gpu := 0.0
		for i in FRAMES:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		print("%-8s gpu %.2f ms" % [view, gpu / FRAMES])
		root.get_texture().get_image().save_png(dir.path_join("level_%s%s.png" % [view, tag]))
	quit()
