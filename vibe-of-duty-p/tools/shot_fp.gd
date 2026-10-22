extends SceneTree
## Renders the first-person view (viewmodel weapon + arms) to ../shots/fp_<case>.png:
## Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_fp.gd

const CASES := {"hip": [0, 0.0, -1.0], "ads": [0, 1.0, -1.0], "punch": [0, 0.0, 0.27], "punch_back": [0, 0.0, 0.6]}  # [weapon, ads, punch progress]


func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	root3d.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.6, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	root3d.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 75
	cam.position = Vector3(0, 1.65, 0)
	root3d.add_child(cam)
	var inspect := Camera3D.new()
	inspect.fov = 40
	inspect.near = 0.01
	root3d.add_child(inspect)
	cam.current = true
	var view := WeaponView.new()
	view.is_viewmodel = true
	cam.add_child(view)
	var arms := FirstPersonArms.new()
	cam.add_child(arms)
	arms.setup(int(OS.get_environment("SHOT_PEER")) if OS.has_environment("SHOT_PEER") else 0, view)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for c in CASES:
		view.set_weapon(CASES[c][0])
		view.melee = CASES[c][2]
		arms.melee = CASES[c][2]
		for i in 30:
			view.update_pose(1.0 / 60.0, CASES[c][1], -1.0, -1.0, 0.0, 0.0, true, Vector2.ZERO, 0.0)
			arms.pose()
			await process_frame
		get_root().get_texture().get_image().save_png(dir.path_join("fp_%s.png" % c))
		# Inspection view: the same pose from the left and below, close up.
		var target := view.global_position
		inspect.look_at_from_position(target + Vector3(-0.45, -0.2, -0.15), target + Vector3(0, -0.03, -0.1))
		inspect.current = true
		await process_frame
		await process_frame
		get_root().get_texture().get_image().save_png(dir.path_join("fp_%s_side.png" % c))
		cam.current = true
	quit()
