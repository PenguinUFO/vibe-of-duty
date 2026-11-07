extends Node
## Renders the leg augmentations (AugLegs: the "Прыг-Прыг"'s pneumatic hooves, the "Прыг-скок"'s blades) on a whole
## pig with a gun, standing, running fast and in a jump, from several sides, next to a plain pig for the height, to
## ../shots/legs_<kind>_<pose>_<view>.png:
##   Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_legs

const VIEWS := {  # name -> camera position (the pigs look along -Z)
	"side": Vector3(-3.2, 1.0, 0.0),
	"front": Vector3(0.6, 1.0, -3.4),
	"back": Vector3(-1.4, 1.2, 2.8),
	"close": Vector3(-1.1, 0.5, -0.9),
}
## name -> [velocity (mannequin frame, x right, z back), on the floor, the air jump kicked]
const POSES := {
	"stand": [Vector3.ZERO, true, false],
	"run": [Vector3(0.0, 0.0, -13.0), true, false],
	"jump": [Vector3(0.0, 4.0, -6.0), false, true],
}


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
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	root3d.add_child(floor_mesh)
	var bodies: Array[Mannequin] = []
	for at: float in [0.0, 1.1]:  # the augmented pig, a plain one beside it (the height)
		var body := Mannequin.new()
		body.position = Vector3(at, 0.0, 0.0)
		root3d.add_child(body)
		body.build(Mannequin.PALETTE[1])
		var weapon := WeaponView.new()
		weapon.top_level = true
		root3d.add_child(weapon)
		var index := WeaponDB.index_of("ak")
		weapon.set_weapon(index, WeaponDB.get_def(index))
		body.weapon = weapon
		body.def = weapon.def
		bodies.append(body)
	var cam := Camera3D.new()
	cam.fov = 35
	root3d.add_child(cam)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for kind: String in ["jet", "blades"]:
		bodies[0].set_legs(AugLegs.Kind.JET if kind == "jet" else AugLegs.Kind.BLADES)
		for pose: String in POSES:
			var spec: Array = POSES[pose]
			for view: String in VIEWS:
				var at: Vector3 = VIEWS[view]
				cam.look_at_from_position(at, Vector3(0.0, 0.3 if view == "close" else 0.85, 0.0))
				for i in 40:
					for body in bodies:
						body.animate(0.016, spec[0], spec[1])
					if spec[2] and i == 34:
						bodies[0].set_air_jump_ready(false)
						bodies[0].air_jump()
					for body in bodies:
						body.pose()
					await get_tree().process_frame
				get_tree().root.get_texture().get_image().save_png(dir.path_join("legs_%s_%s_%s.png" % [kind, pose, view]))
				bodies[0].set_air_jump_ready(true)
	get_tree().quit()
