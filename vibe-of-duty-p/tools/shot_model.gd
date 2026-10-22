extends SceneTree
## Renders a weapon model in side profile (barrel to the left; "_r" cases from the other side) to ../shots/model_<case>.png:
## Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_model.gd

const CASES := {  # name -> [weapon index, modules, bolt pulled back 0..1]
	"ak": [0, []],
	"ak_brake": [0, ["ak.muzzle.brake"]],
	"ak_pbs": [0, ["ak.muzzle.pbs"]],
	"pdw": [1, []],
	"pdw_folded": [1, ["pdw.stock.folded"]],
	"pdw_mods": [1, ["pdw.mag.20", "pdw.stock.folded", "pdw.muzzle.suppressor"]],
	"pdw_compm": [1, ["pdw.sight.compm"]],
	"luger": [2, []],
	"luger_open": [2, [], 1.0],
	"luger_150": [2, ["luger.barrel.150"]],
	"luger_mods": [2, ["luger.mag.32", "luger.stock.board", "luger.barrel.200"]],
	"acr": [3, []],
	"acr_r": [3, []],
	"acr_open": [3, [], 1.0],
	"acr_105_can": [3, ["acr.barrel.105", "acr.muzzle.suppressor"]],
	"acr_mods": [3, ["acr.barrel.185", "acr.muzzle.suppressor", "acr.stock.folded"]],
}


func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -60, 0)
	root3d.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.9, 0.9, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root3d.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.7
	root3d.add_child(cam)
	var view := WeaponView.new()
	root3d.add_child(view)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for c in CASES:
		view.set_weapon(CASES[c][0], WeaponDB.make_def(CASES[c][0], CASES[c][1]))
		view.bolt_pull = CASES[c][2] if CASES[c].size() > 2 else 0.0
		# The barrel points to -Z: seen from -X it is on the left of the picture.
		# "_r" cases: seen from the gun's right (+X here), the barrel on the right, as most photos.
		var side := 2.0 if c.ends_with("_r") else -2.0
		cam.look_at_from_position(Vector3(side, 0.0, -0.1), Vector3(0.0, 0.0, -0.1))
		await process_frame
		await process_frame
		get_root().get_texture().get_image().save_png(dir.path_join("model_%s.png" % c))
	quit()
