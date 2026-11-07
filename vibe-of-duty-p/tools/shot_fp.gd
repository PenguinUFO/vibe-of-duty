extends Node
## Renders the first-person view (viewmodel weapon + arms) to ../shots/fp_<case>.png:
## Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_fp

const CASES := {  # [weapon, ads, punch progress, modules, reload progress, grenade launch progress, sprint 0..1,
	# look delta every frame (a sharp turn: the sway), the "Хрях-бабах" counting]
	"bomb_hip": [0, 0.0, -1.0, [], -1.0, -1.0, 0.0, Vector2.ZERO, true],
	"bomb_ads": [0, 1.0, -1.0, [], -1.0, -1.0, 0.0, Vector2.ZERO, true],
	"bomb_acog_ads": [3, 1.0, -1.0, ["acr.sight.acog"], -1.0, -1.0, 0.0, Vector2.ZERO, true],
	"bomb_luger_akimbo": [2, 0.0, -1.0, ["luger.akimbo.on"], -1.0, -1.0, 0.0, Vector2.ZERO, true],
	"hip": [0, 0.0, -1.0, []], "grenade": [0, 0.0, -1.0, [], -1.0, 0.43], "grenade_back": [0, 0.0, -1.0, [], -1.0, 0.75], "ads": [0, 1.0, -1.0, []], "punch": [0, 0.0, 0.27, []], "punch_back": [0, 0.0, 0.6, []],
	"pdw_hip": [1, 0.0, -1.0, []], "pdw_ads": [1, 1.0, -1.0, []],
	"pdw_mods": [1, 0.0, -1.0, ["pdw.stock.folded"]],
	"luger_hip": [2, 0.0, -1.0, []], "luger_ads": [2, 1.0, -1.0, []],
	"luger_khruger_hip": [2, 0.0, -1.0, ["luger.conversion.khruger"]], "luger_khruger_ads": [2, 1.0, -1.0, ["luger.conversion.khruger"]],
	"luger_mods": [2, 0.0, -1.0, ["luger.mag.32", "luger.stock.board"]],
	"luger_snail_hip": [2, 0.0, -1.0, ["luger.mag.32"]], "luger_snail_ads": [2, 1.0, -1.0, ["luger.mag.32"]], "luger_snail_reload": [2, 0.0, -1.0, ["luger.mag.32"], 0.35],
	"luger_mods_ads": [2, 1.0, -1.0, ["luger.mag.32", "luger.stock.board"]],
	"luger_akimbo": [2, 0.0, -1.0, ["luger.akimbo.on"]],
	"luger_akimbo_snail": [2, 0.0, -1.0, ["luger.akimbo.on", "luger.mag.32"]],
	"luger_akimbo_grenade": [2, 0.0, -1.0, ["luger.akimbo.on"], -1.0, 0.43],
	"luger_akimbo_sprint": [2, 0.0, -1.0, ["luger.akimbo.on"], -1.0, -1.0, 1.0],
	"mp7_akimbo": [4, 0.0, -1.0, ["mp7.stock.collapsed", "mp7.suppressor.on", "mp7.akimbo.on"]],
	"pdw_akimbo": [1, 0.0, -1.0, ["pdw.stock.folded", "pdw.akimbo.on"]],
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
	"p90_can_hip": [8, 0.0, -1.0, ["p90.suppressor.on"]], "p90_can_ads": [8, 1.0, -1.0, ["p90.suppressor.on"]],
	"p90_hip": [8, 0.0, -1.0, []], "p90_ads": [8, 1.0, -1.0, []], "p90_half": [8, 0.6, -1.0, []],
	"p90_r12": [8, 0.0, -1.0, [], 0.12], "p90_r22": [8, 0.0, -1.0, [], 0.22], "p90_r40": [8, 0.0, -1.0, [], 0.4],
	"p90_r62": [8, 0.0, -1.0, [], 0.62], "p90_r70": [8, 0.0, -1.0, [], 0.7], "p90_r85": [8, 0.0, -1.0, [], 0.85],
	"aug_hip": [9, 0.0, -1.0, []], "aug_half": [9, 0.6, -1.0, []], "aug_r30": [9, 0.0, -1.0, [], 0.3],
	"aug_r60": [9, 0.0, -1.0, [], 0.6], "aug_r75": [9, 0.0, -1.0, [], 0.75], "aug_r85": [9, 0.0, -1.0, [], 0.85],
	"aug_tac_hip": [9, 0.0, -1.0, ["aug.suppressor.blk", "aug.sight.compm", "aug.grip.off"]],
	"aug_tac_ads": [9, 1.0, -1.0, ["aug.suppressor.blk", "aug.sight.compm", "aug.grip.off"]],
	"aug_com_hip": [9, 0.0, -1.0, ["aug.barrel.b350", "aug.sight.iron"]],
	"aug_com_ads": [9, 1.0, -1.0, ["aug.barrel.b350", "aug.sight.iron"]],
	"aug_ads": [9, 1.0, -1.0, []], "aug_ads_sway": [9, 1.0, -1.0, [], -1.0, -1.0, 0.0, Vector2(40.0, 12.0)],
	"aug_acog_ads": [9, 1.0, -1.0, ["aug.sight.acog"]],
	"aug_acog_hip": [9, 0.0, -1.0, ["aug.sight.acog"]],
	"m16_hip": [10, 0.0, -1.0, []], "m16_ads": [10, 1.0, -1.0, []], "m16_half": [10, 0.6, -1.0, []],
	"m16_r30": [10, 0.0, -1.0, [], 0.3], "m16_r60": [10, 0.0, -1.0, [], 0.6], "m16_r85": [10, 0.0, -1.0, [], 0.85],
	"m16_colt_hip": [10, 0.0, -1.0, ["m16.sight.colt"]], "m16_colt_ads": [10, 1.0, -1.0, ["m16.sight.colt"]],
	"m16_colt_half": [10, 0.6, -1.0, ["m16.sight.colt"]],
	"m16_napalm_hip": [10, 0.0, -1.0, ["m16.barrel.b368", "m16.suppressor.hel", "m16.stock.collapsed"]],
	"m16_napalm_ads": [10, 1.0, -1.0, ["m16.barrel.b368", "m16.suppressor.hel", "m16.stock.collapsed"]],
	"m16_653_colt_ads": [10, 1.0, -1.0, ["m16.barrel.b368", "m16.sight.colt"]],
	"groza_hip": [11, 0.0, -1.0, []], "groza_ads": [11, 1.0, -1.0, []], "groza_half": [11, 0.6, -1.0, []],
	"groza_r30": [11, 0.0, -1.0, [], 0.3], "groza_r60": [11, 0.0, -1.0, [], 0.6],
	"groza_kit_hip": [11, 0.0, -1.0, ["groza.suppressor.on"]], "groza_kit_ads": [11, 1.0, -1.0, ["groza.suppressor.on"]],
	"groza_grip_hip": [11, 0.0, -1.0, ["groza.grip.on"]],
	"groza_po_hip": [11, 0.0, -1.0, ["groza.sight.po"]], "groza_po_ads": [11, 1.0, -1.0, ["groza.sight.po"]],
	"groza_po_half": [11, 0.6, -1.0, ["groza.sight.po"]],
	"val_hip": [12, 0.0, -1.0, []], "val_ads": [12, 1.0, -1.0, []], "val_half": [12, 0.6, -1.0, []],
	"val_r30": [12, 0.0, -1.0, [], 0.3], "val_r60": [12, 0.0, -1.0, [], 0.6],
	"val_short_hip": [12, 0.0, -1.0, ["val.barrel.short"]], "val_short_ads": [12, 1.0, -1.0, ["val.barrel.short"]],
	"val_wood_hip": [12, 0.0, -1.0, ["val.stock.wood"]], "val_wood_ads": [12, 1.0, -1.0, ["val.stock.wood"]],
	"val_po_hip": [12, 0.0, -1.0, ["val.sight.po"]], "val_po_ads": [12, 1.0, -1.0, ["val.sight.po"]],
	"val_short_po_ads": [12, 1.0, -1.0, ["val.barrel.short", "val.sight.po"]],
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
	if OS.has_environment("SHOT_WALL"):  # something to go out of focus round an optic's window (ScopeBlur)
		var wall := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(60.0, 40.0)
		wall.mesh = quad
		wall.position = Vector3(0.0, 1.65, -14.0)
		var checker := NoiseTexture2D.new()
		checker.noise = FastNoiseLite.new()
		checker.noise.frequency = 0.08
		checker.noise.fractal_octaves = 1
		checker.noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		checker.width = 1024
		checker.height = 1024
		var paint := StandardMaterial3D.new()
		paint.albedo_texture = checker
		wall.material_override = paint
		root3d.add_child(wall)
		await checker.changed
	var cam := Camera3D.new()
	cam.fov = Settings.fov
	cam.position = Vector3(0, 1.65, 0)
	root3d.add_child(cam)
	var inspect := Camera3D.new()
	inspect.fov = 40
	inspect.near = 0.01
	root3d.add_child(inspect)
	cam.current = true
	var space := ViewmodelSpace.new()
	cam.add_child(space)
	var view := WeaponView.new()
	view.is_viewmodel = true
	space.add_child(view)
	var left_view := WeaponView.new()  # akimbo (a module with "akimbo" in the case's)
	left_view.is_viewmodel = true
	left_view.mirrored = true
	space.add_child(left_view)
	var arms := FirstPersonArms.new()
	space.add_child(arms)
	arms.setup(int(OS.get_environment("SHOT_PEER")) if OS.has_environment("SHOT_PEER") else 0, view)
	arms.left_weapon = left_view
	if OS.has_environment("SHOT_CYBER"):  # the "Руки-Хрюки"
		arms.set_cyber(true)
	var cannon := GrenadeCannon.new()
	cannon.set_barrel_only()
	space.add_child(cannon)
	var bomb := PlayerView.make_bomb_view(cam)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for c in CASES:
		if OS.has_environment("SHOT_CASE") and not c.begins_with(OS.get_environment("SHOT_CASE")):
			continue
		var def := WeaponDB.make_def(CASES[c][0], CASES[c][3])
		view.set_weapon(CASES[c][0], def)
		left_view.visible = def.akimbo
		view.akimbo = def.akimbo
		left_view.akimbo = true
		var sprint: float = CASES[c][6] if CASES[c].size() > 6 else 0.0
		var look: Vector2 = CASES[c][7] if CASES[c].size() > 7 else Vector2.ZERO
		if def.akimbo:
			left_view.set_weapon(CASES[c][0], def)
		cam.fov = lerpf(Settings.fov, Settings.fov * def.ads_fov_mult, CASES[c][1])  # the sights' zoom, as Player
		space.fit(cam.fov, view.view_fov(CASES[c][1]))
		view.melee = CASES[c][2]
		arms.melee = CASES[c][2]
		var reload: float = CASES[c][4] if CASES[c].size() > 4 else -1.0
		arms.reload = reload
		var grenade: float = CASES[c][5] if CASES[c].size() > 5 else -1.0
		view.grenade = grenade
		arms.grenade = grenade
		PlayerView.pose_cannon_view(cannon, grenade)
		var counting: bool = CASES[c][8] if CASES[c].size() > 8 else false
		bomb.arm(1.5 if counting else -1.0)
		PlayerView.pose_bomb_view(bomb, cam.fov, counting, 1.0)
		if reload >= 0.0:
			view.flash(false)  # the shot before the reload: the hammer down
		for i in 30:
			view.update_pose(1.0 / 60.0, CASES[c][1], reload, -1.0, sprint, 0.0, true, look, 0.0)
			left_view.grenade = grenade
			left_view.update_pose(1.0 / 60.0, 0.0, -1.0, -1.0, sprint, 0.0, true, Vector2.ZERO, 0.0)
			arms.pose()
			await get_tree().process_frame
		space.blur.follow(view, cam, CASES[c][1])
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png(dir.path_join("fp_%s.png" % c))
		space.blur.visible = false
		# Inspection view: the same pose from the left and below, close up.
		var target := view.global_position
		inspect.look_at_from_position(target + Vector3(-0.45, -0.2, -0.15), target + Vector3(0, -0.03, -0.1))
		inspect.current = true
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png(dir.path_join("fp_%s_side.png" % c))
		cam.current = true
	get_tree().quit()
