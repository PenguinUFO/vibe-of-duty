extends Node
## Renders the first-person view (viewmodel weapon + arms) to ../shots/fp_<case>.png:
## Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_fp

const CASES := {  # [weapon, ads, punch progress, modules, reload progress]
	"hip": [0, 0.0, -1.0, []], "ads": [0, 1.0, -1.0, []], "punch": [0, 0.0, 0.27, []], "punch_back": [0, 0.0, 0.6, []],
	"pdw_hip": [1, 0.0, -1.0, []], "pdw_ads": [1, 1.0, -1.0, []],
	"pdw_mods": [1, 0.0, -1.0, ["pdw.stock.folded"]],
	"luger_hip": [2, 0.0, -1.0, []], "luger_ads": [2, 1.0, -1.0, []],
	"luger_khruger_hip": [2, 0.0, -1.0, ["luger.conversion.khruger"]], "luger_khruger_ads": [2, 1.0, -1.0, ["luger.conversion.khruger"]],
	"luger_mods": [2, 0.0, -1.0, ["luger.mag.32", "luger.stock.board"]],
	"luger_mods_ads": [2, 1.0, -1.0, ["luger.mag.32", "luger.stock.board"]],
	"pdw_compm": [1, 0.0, -1.0, ["pdw.sight.compm"]], "pdw_compm_ads": [1, 1.0, -1.0, ["pdw.sight.compm"]],
	"pdw_compm_half": [1, 0.6, -1.0, ["pdw.sight.compm"]], "ak_kobra_ads": [0, 1.0, -1.0, ["ak.sight.kobra"]],
	"ak_pbs": [0, 0.0, -1.0, ["ak.suppressor.on"]], "ak_pbs_ads": [0, 1.0, -1.0, ["ak.suppressor.on"]],
	"acr_hip": [3, 0.0, -1.0, []], "acr_ads": [3, 1.0, -1.0, []],
	"acr_acog_ads": [3, 1.0, -1.0, ["acr.sight.acog"]], "acr_acog_half": [3, 0.6, -1.0, ["acr.sight.acog"]],
	"acr_compm_ads": [3, 1.0, -1.0, ["acr.sight.compm"]], "pdw_acog_ads": [1, 1.0, -1.0, ["pdw.sight.acog"]],
	"mp7_compm_ads": [4, 1.0, -1.0, ["mp7.sight.compm"]], "mp7_acog_ads": [4, 1.0, -1.0, ["mp7.sight.acog"]],
	"acr_mods": [3, 0.0, -1.0, ["acr.suppressor.on", "acr.stock.collapsed"]],
	"acr_mods_ads": [3, 1.0, -1.0, ["acr.suppressor.on", "acr.stock.collapsed"]],
	"mp7_hip": [4, 0.0, -1.0, []], "mp7_ads": [4, 1.0, -1.0, []],
	"mp7_mods": [4, 0.0, -1.0, ["mp7.grip.folded", "mp7.suppressor.on", "mp7.sight.compm"]],
	"mp7_mods_ads": [4, 1.0, -1.0, ["mp7.grip.folded", "mp7.suppressor.on", "mp7.sight.compm"]],
	"mp7_collapsed_ads": [4, 1.0, -1.0, ["mp7.stock.collapsed"]],
	"contender_hip": [5, 0.0, -1.0, []], "contender_ads": [5, 1.0, -1.0, []],
	"contender_r10": [5, 0.0, -1.0, [], 0.1], "contender_r22": [5, 0.0, -1.0, [], 0.22],
	"contender_r30": [5, 0.0, -1.0, [], 0.3], "contender_r40": [5, 0.0, -1.0, [], 0.4],
	"contender_r50": [5, 0.0, -1.0, [], 0.5], "contender_r60": [5, 0.0, -1.0, [], 0.6],
	"contender_r75": [5, 0.0, -1.0, [], 0.75], "contender_r90": [5, 0.0, -1.0, [], 0.9],
	"winchester_hip": [6, 0.0, -1.0, []], "winchester_ads": [6, 1.0, -1.0, []],
	"winchester_r30": [6, 0.0, -1.0, [], 0.3], "winchester_r60": [6, 0.0, -1.0, [], 0.6],
	"winchester_r78": [6, 0.0, -1.0, [], 0.78],
	"mk14_hip": [7, 0.0, -1.0, []], "mk14_ads": [7, 1.0, -1.0, []], "mk14_r30": [7, 0.0, -1.0, [], 0.3],
	"mk14_compm_ads": [7, 1.0, -1.0, ["mk14.sight.compm"]], "mk14_acog_ads": [7, 1.0, -1.0, ["mk14.sight.acog"]],
	"p90_hip": [8, 0.0, -1.0, []], "p90_ads": [8, 1.0, -1.0, []], "p90_half": [8, 0.6, -1.0, []],
	"p90_r12": [8, 0.0, -1.0, [], 0.12], "p90_r22": [8, 0.0, -1.0, [], 0.22], "p90_r40": [8, 0.0, -1.0, [], 0.4],
	"p90_r62": [8, 0.0, -1.0, [], 0.62], "p90_r70": [8, 0.0, -1.0, [], 0.7], "p90_r85": [8, 0.0, -1.0, [], 0.85],
}


func _ready() -> void:
	var root3d := Node3D.new()
	get_tree().root.add_child(root3d)
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
		if OS.has_environment("SHOT_CASE") and not c.begins_with(OS.get_environment("SHOT_CASE")):
			continue
		var def := WeaponDB.make_def(CASES[c][0], CASES[c][3])
		view.set_weapon(CASES[c][0], def)
		cam.fov = lerpf(75.0, 75.0 * def.ads_fov_mult, CASES[c][1])  # the sights' zoom, as Player
		view.melee = CASES[c][2]
		arms.melee = CASES[c][2]
		var reload: float = CASES[c][4] if CASES[c].size() > 4 else -1.0
		arms.reload = reload
		if reload >= 0.0:
			view.flash(false)  # the shot before the reload: the hammer down
		for i in 30:
			view.update_pose(1.0 / 60.0, CASES[c][1], reload, -1.0, 0.0, 0.0, true, Vector2.ZERO, 0.0)
			arms.pose()
			await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png(dir.path_join("fp_%s.png" % c))
		# Inspection view: the same pose from the left and below, close up.
		var target := view.global_position
		inspect.look_at_from_position(target + Vector3(-0.45, -0.2, -0.15), target + Vector3(0, -0.03, -0.1))
		inspect.current = true
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png(dir.path_join("fp_%s_side.png" % c))
		cam.current = true
	get_tree().quit()
