extends SceneTree
## Close-ups of an optic on its gun (SightModels) from four sides to ../shots/sight_<case>_<view>.png:
## Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_sight.gd   (SHOT_CASE=pdw_compm: only that case)

const CASES := {  # name -> [weapon index, modules, the optic's middle in prefab space]
	"ak_kobra": [0, ["ak.sight.kobra"], Vector3(0.0, 0.12, 0.06)],
	"pdw_compm": [1, ["pdw.sight.compm"], Vector3(0.0, 0.09, 0.0)],
	"acr_acog": [3, ["acr.sight.acog"], Vector3(0.0, 0.115, 0.0)],
	"acr_compm": [3, ["acr.sight.compm"], Vector3(0.0, 0.115, 0.0)],
	"pdw_acog": [1, ["pdw.sight.acog"], Vector3(0.0, 0.09, 0.0)],
	"mp7_compm": [4, ["mp7.sight.compm"], Vector3(0.0, 0.09, 0.0)],
	"mp7_acog": [4, ["mp7.sight.acog"], Vector3(0.0, 0.09, 0.0)],
	"mk14_compm": [7, ["mk14.sight.compm"], Vector3(0.0, 0.11, 0.13)],
	"mk14_acog": [7, ["mk14.sight.acog"], Vector3(0.0, 0.11, 0.13)],
}
## Camera offsets from the optic in prefab space (+x the gun's left, +z the muzzle): left front, right rear, left,
## right, from behind along the aim line.
const VIEWS := {
	"left_front": Vector3(0.22, 0.12, 0.2), "right_rear": Vector3(-0.22, 0.1, -0.2), "left": Vector3(0.3, 0.0, 0.0),
	"right": Vector3(-0.3, 0.0, 0.0), "back": Vector3(0.0, 0.03, -0.35),
}


func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -40, 0)
	root3d.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.9, 0.9, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root3d.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.near = 0.01
	root3d.add_child(cam)
	var view := WeaponView.new()
	root3d.add_child(view)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for c in CASES:
		if OS.has_environment("SHOT_CASE") and OS.get_environment("SHOT_CASE") != c:
			continue
		view.set_weapon(CASES[c][0], WeaponDB.make_def(CASES[c][0], CASES[c][1]))
		await process_frame
		var model: Node3D = view._model
		for v in VIEWS:
			var basis := model.global_transform.basis  # the prefab's axes in the world (WeaponView turns it round)
			var target: Vector3 = model.global_transform * CASES[c][2]
			cam.look_at_from_position(target + basis * VIEWS[v], target)
			await process_frame
			await process_frame
			get_root().get_texture().get_image().save_png(dir.path_join("sight_%s_%s.png" % [c, v]))
	quit()
