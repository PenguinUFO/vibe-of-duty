extends SceneTree
## Renders the third-person body to ../shots/*.png: Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot.gd

func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	root3d.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	root3d.add_child(env)
	var vis := PlayerVisual.new()
	root3d.add_child(vis)
	vis.setup(0, "T")
	vis.set_weapon(0)
	var cam := Camera3D.new()
	cam.fov = 35
	root3d.add_child(cam)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	vis.set_aim_pitch(float(OS.get_environment("SHOT_PITCH")) if OS.has_environment("SHOT_PITCH") else 0.0)
	var views := {"front": Vector3(1.6, 1.4, -2.6), "side": Vector3(3.0, 1.3, 0.0), "back": Vector3(-1.2, 1.6, 2.6)}
	for view in views:
		cam.look_at_from_position(views[view], Vector3(0, 1.0, 0))
		for i in 30:
			await process_frame
		get_root().get_texture().get_image().save_png(dir.path_join("%s.png" % view))
	quit()
