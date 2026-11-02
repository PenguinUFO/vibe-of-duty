extends Node
## Renders the "Гренадир"'s chest cannon (GrenadeCannon) on a whole pig holding a gun at the hip, from several sides,
## folded and mid-launch, to ../shots/cannon_<pose>_<view>.png - is it seen from outside, does the gun hide it:
##   Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_cannon
## SHOT_WEAPON=p90: another weapon (an id in WeaponDB; the AK by default).

const VIEWS := {  # name -> camera position (the pig looks along -Z, chest at ~1.3 m)
	"front": Vector3(0.0, 1.4, -2.4),
	"left": Vector3(-1.7, 1.5, -1.7),
	"right": Vector3(1.7, 1.5, -1.7),
	"close": Vector3(-0.35, 1.45, -0.9),
}
const POSES := {"folded": -1.0, "launch": 0.43}


func _ready() -> void:
	get_window().size = Vector2i(900, 900)
	var root3d := Node3D.new()
	get_tree().root.add_child(root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.125, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.62)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root3d.add_child(world_env)
	for light: Array in [[Vector3(0.6, 0.65, -0.55), Color(1.0, 0.94, 0.86), 1.6],
			[Vector3(-0.8, -0.15, -0.5), Color(0.7, 0.8, 1.0), 0.4], [Vector3(-0.6, 0.5, 0.8), Color(1.0, 0.62, 0.3), 1.2]]:
		var sun := DirectionalLight3D.new()
		sun.light_color = light[1]
		sun.light_energy = light[2]
		sun.transform = Transform3D(Basis.looking_at(-(light[0] as Vector3).normalized()), light[0])
		root3d.add_child(sun)
	var body := Mannequin.new()
	root3d.add_child(body)
	body.build(Mannequin.PALETTE[1])
	var weapon := WeaponView.new()
	weapon.top_level = true
	root3d.add_child(weapon)
	var id := OS.get_environment("SHOT_WEAPON")
	var index := WeaponDB.index_of(id if id != "" else "ak")
	weapon.set_weapon(index, WeaponDB.get_def(index))
	body.weapon = weapon
	body.def = weapon.def
	body.set_cannon(true)
	var cam := Camera3D.new()
	cam.fov = 35
	root3d.add_child(cam)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for pose: String in POSES:
		body.grenade = POSES[pose]
		for view: String in VIEWS:
			var at: Vector3 = VIEWS[view]
			cam.look_at_from_position(at, Vector3(0.0, 1.2 if view != "close" else 1.32, -0.1))
			for i in 4:
				body.animate(0.016, Vector3.ZERO)
				body.pose()
				await get_tree().process_frame
			get_tree().root.get_texture().get_image().save_png(dir.path_join("cannon_%s_%s.png" % [pose, view]))
	get_tree().quit()
