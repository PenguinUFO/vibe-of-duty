extends SceneTree
## Top-down plans of the maps for drawing edits on: each deck seen from straight above with everything over it cut
## away (an orthographic camera at the cut height), flat colours (unshaded), to ../shots/plan_<map>_<deck>.png (and
## _h: the same with every surface's height for its colour, to tell walls, cover, floor and drops apart; walls the
## cut goes through come out solid, as in a section) plus a
## .json beside it (the mapping to metres, the spawns on that deck) that tools/plan_overlay.py draws a grid from.
## Run windowed: Godot_v4.7.2.exe --path vibe-of-duty-p --script res://tools/shot_plan.gd  (PLAN_MAPS=train,plane)

const PX_PER_M := 30.0
## Per map: the area (x0, x1, z0, z1), whether z runs along the image (long maps), the decks: name -> [cut height,
## floor height].
const PLANS := {
	"train": {"area": [-4.0, 4.0, -104.0, 92.0], "along_z": true,
			"decks": {"lower": [2.95, 0.0], "upper": [6.25, 3.3], "roof": [40.0, 0.0]}},
	"plane": {"area": [-5.5, 5.5, -57.0, 46.0], "along_z": true,
			"decks": {"belly": [-0.35, -3.0], "hold": [3.4, 0.0], "upper": [6.2, 4.7]}},
	"plane_outside": {"map": "plane", "area": [-48.0, 48.0, -62.0, 62.0], "along_z": true,
			"decks": {"outside": [60.0, 0.0]}},
	"tower": {"area": [-18.0, 48.0, -18.0, 18.0], "along_z": false,
			"decks": {"walk": [-0.1, -4.0], "L0": [3.65, 0.0], "L1": [7.65, 4.0], "L2": [11.6, 8.0], "top": [80.0, 0.0]}},
	"killhouse": {"area": [-18.0, 18.0, -34.0, 34.0], "along_z": false,
			"decks": {"ground": [2.9, 0.0], "top": [40.0, 0.0]}},
}
const DEPTH := 60.0  # m the camera sees below the cut
const HEIGHT_SPAN := 20.0  # m of heights the _h pass encodes, centred on the floor
const HEIGHT_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float base;
uniform float span;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() { ALBEDO = vec3(FRONT_FACING ? clamp((world_y - base) / span, 0.0, 1.0) : 1.0); }  // inside: cut solid
"""


func _initialize() -> void:
	var only := OS.get_environment("PLAN_MAPS").split(",", false)
	var dir := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	RenderingServer.set_default_clear_color(Color(0.07, 0.08, 0.1))
	for key: String in PLANS:
		var plan: Dictionary = PLANS[key]
		var map: String = plan.get("map", key)
		if not only.is_empty() and not only.has(map):
			continue
		var level: Node = load("res://prefabs/levels/%s.tscn" % map).instantiate()
		for name in ["WorldEnvironment", "Sun", "Scenery"]:  # plain colours and background, no cloud puffs
			var node := level.get_node_or_null(name)
			if node:
				level.remove_child(node)
				node.free()
		root.add_child(level)
		await process_frame
		for node in level.find_children("*", "MeshInstance3D", true, false):  # a wall the cut goes through shows
			var mesh_node := node as MeshInstance3D                          # its inside: solid in section
			var materials: Array = [mesh_node.material_override]
			if mesh_node.mesh:
				for i in mesh_node.mesh.get_surface_count():
					materials.append(mesh_node.mesh.surface_get_material(i))
			for material in materials:
				if material is BaseMaterial3D and not _is_glow(mesh_node):
					(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		var area: Array = plan["area"]
		var along_z: bool = plan["along_z"]
		var width_m: float = (area[3] - area[2]) if along_z else (area[1] - area[0])
		var height_m: float = (area[1] - area[0]) if along_z else (area[3] - area[2])
		var view := SubViewport.new()
		view.size = Vector2i(roundi(width_m * PX_PER_M), roundi(height_m * PX_PER_M))
		view.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = height_m
		cam.near = 0.01
		cam.far = DEPTH
		view.add_child(cam)
		# Looking down. Long maps: +z to the right, +x up; the tower: +x to the right, -z up (north up).
		var basis := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)) if along_z \
				else Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
		var center := Vector3((area[0] + area[1]) * 0.5, 0.0, (area[2] + area[3]) * 0.5)
		for deck: String in plan["decks"]:
			var cut: float = plan["decks"][deck][0]
			var floor_y: float = plan["decks"][deck][1]
			var file := "plan_%s_%s" % [map, deck]
			cam.global_transform = Transform3D(basis, center + Vector3.UP * cut)
			for i in 8:
				await process_frame
			view.get_texture().get_image().save_png(dir.path_join(file + ".png"))
			# The heights (plan_overlay.py shades by them): every mesh its height for colour, the glows hidden.
			var height := ShaderMaterial.new()
			height.shader = Shader.new()
			height.shader.code = HEIGHT_SHADER
			height.set_shader_parameter("base", floor_y - HEIGHT_SPAN * 0.5)
			height.set_shader_parameter("span", HEIGHT_SPAN)
			var saved := {}
			for node in level.find_children("*", "GeometryInstance3D", true, false):
				var geometry := node as GeometryInstance3D
				saved[geometry] = [geometry.material_override, geometry.visible]
				geometry.visible = geometry.visible and not _is_glow(geometry)
				geometry.material_override = height
			RenderingServer.set_default_clear_color(Color.BLACK)
			for i in 8:
				await process_frame
			view.get_texture().get_image().save_png(dir.path_join(file + "_h.png"))
			RenderingServer.set_default_clear_color(Color(0.07, 0.08, 0.1))
			for geometry: GeometryInstance3D in saved:
				geometry.material_override = saved[geometry][0]
				geometry.visible = saved[geometry][1]
			var spawns := []
			for marker in level.get_node("SpawnPoints").get_children():
				var at := (marker as Node3D).global_position
				if at.y < cut and at.y > cut - 4.6:  # standing on this deck
					var facing := -(marker as Node3D).global_basis.z
					spawns.append({"name": String(marker.name), "x": at.x, "z": at.z, "fx": facing.x, "fz": facing.z})
			var meta := {"map": map, "deck": deck, "cut": cut, "floor": floor_y, "height_span": HEIGHT_SPAN,
					"area": area, "along_z": along_z,
					"px_per_m": PX_PER_M, "spawns": spawns}
			var json := FileAccess.open(dir.path_join(file + ".json"), FileAccess.WRITE)
			json.store_string(JSON.stringify(meta, "\t"))
			json.close()
			print("%s: %dx%d, %d spawns" % [file, view.size.x, view.size.y, spawns.size()])
		view.queue_free()
		level.queue_free()
		await process_frame
	quit()


## A lamp's halo or a beacon's glow: a billboard, nothing to stand on.
func _is_glow(geometry: GeometryInstance3D) -> bool:
	var mesh := (geometry as MeshInstance3D).mesh if geometry is MeshInstance3D else null
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	if geometry.material_override is BaseMaterial3D:
		material = geometry.material_override
	return material != null and (material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED
			or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
