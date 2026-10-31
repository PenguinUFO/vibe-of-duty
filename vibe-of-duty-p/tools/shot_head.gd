extends Node
## Renders the pig's head (Mannequin.make_head) up close from six sides to ../shots/head_<view>.png, in the menu
## portrait's light (PigPortrait): Godot_v4.7.2.exe --path vibe-of-duty-p res://tools/run_tool.tscn -- --tool=shot_head
## SHOT_CHIP=1: with the "Инженер"'s chip.

const VIEWS := {  # name -> camera position (the head looks along -Z)
	"front": Vector3(0.0, 0.03, -0.75),
	"three_quarter": Vector3(0.5, 0.12, -0.55),
	"side": Vector3(0.75, 0.03, 0.0),
	"left": Vector3(-0.55, 0.1, -0.5),
	"top": Vector3(0.15, 0.7, -0.3),
	"back": Vector3(-0.4, 0.2, 0.6),
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
	var body := Mannequin.new()
	root3d.add_child(body)
	var head := Mannequin.make_head(body)
	body._parts["Head"] = head
	if OS.get_environment("SHOT_CHIP") == "1":
		body.set_chip(true)
	var cam := Camera3D.new()
	cam.fov = 30
	root3d.add_child(cam)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for view: String in VIEWS:
		cam.look_at_from_position(VIEWS[view], Vector3(0.0, 0.0, -0.03))
		for i in 3:
			await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png(dir.path_join("head_%s.png" % view))
	get_tree().quit()
