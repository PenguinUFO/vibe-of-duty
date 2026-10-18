extends SceneTree
## Renders the third-person body to ../shots/<case>_<view>.png: Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot.gd

const CASES := {  # name -> [local velocity (x right, z back), aim pitch]
	"idle": [Vector3.ZERO, 0.0],
	"run_f": [Vector3(0, 0, -5.25), 0.0],
	"run_r": [Vector3(5.25, 0, 0), 0.0],
	"run_fl": [Vector3(-3.7, 0, -3.7), 0.0],
	"sprint": [Vector3(0, 0, -7.0), 0.0],
	"ads_idle": [Vector3.ZERO, 0.0, true],
	"ads_f": [Vector3(0, 0, -5.25), 0.0, true],
	"ads_r": [Vector3(5.25, 0, 0), 0.0, true],
	"ads_b": [Vector3(0, 0, 5.25), 0.0, true],
}
const VIEWS := {"front": Vector3(1.6, 1.4, -2.6), "side": Vector3(3.0, 1.3, 0.0), "left": Vector3(-1.8, 1.5, -1.8)}


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
	var only := OS.get_environment("SHOT_CASES").split(",", false)
	for c in CASES:
		if not only.is_empty() and not only.has(c):
			continue
		vis.set_aim_pitch(CASES[c][1])
		vis.set_ads(CASES[c].size() > 2 and CASES[c][2])
		for view in VIEWS:
			cam.look_at_from_position(VIEWS[view], Vector3(0, 1.0, 0))
			for i in 25:
				vis.update_motion(1.0 / 60.0, CASES[c][0])
				await process_frame
			get_root().get_texture().get_image().save_png(dir.path_join("%s_%s.png" % [c, view]))
	quit()
