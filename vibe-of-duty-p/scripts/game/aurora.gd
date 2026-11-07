class_name Aurora
extends Node3D
## The night sky over the dry dock (Docs/LEVEL_DRYDOCK.md): stars and the northern lights, curtains of additive
## ribbons in a wide arc to the north (assets/shaders/aurora.gdshader). Cosmetic, built at load, nothing on a server
## without a screen. They light nothing: the light on the snow is the level's Sun and LevelMood.

const STARS := 700
const STAR_DISTANCE := 285.0     # inside the player camera's far plane (300 m)
const STAR_SIZE := 0.8
const SHADER := preload("res://assets/shaders/aurora.gdshader")
## Each curtain: distance from the origin (m), bearing of its middle and arc (deg; 0 north, 90 east), bottom and
## height (m), the wave of its line (m), strength.
const CURTAINS := [
	[255.0, -20.0, 130.0, 70.0, 130.0, 26.0, 0.8],
	[235.0, 35.0, 110.0, 95.0, 105.0, 20.0, 0.55],
	[270.0, -70.0, 90.0, 60.0, 110.0, 30.0, 0.45],
]
const STEPS := 96


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	_build_stars()
	for i in CURTAINS.size():
		_build_curtain(CURTAINS[i], float(i + 1))


func _build_curtain(c: Array, seed_value: float) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var radius: float = c[0]
	for i in STEPS + 1:
		var s := float(i) / STEPS
		var bearing := deg_to_rad(c[1] + (s - 0.5) * c[2])
		var r: float = radius + sin(s * 11.0 + seed_value) * c[5] + sin(s * 27.0 + seed_value * 2.0) * c[5] * 0.4
		var foot := Vector3(sin(bearing) * r, c[3], -cos(bearing) * r)
		vertices.append(foot)
		uvs.append(Vector2(s, 0.0))
		vertices.append(foot + Vector3.UP * c[4])
		uvs.append(Vector2(s, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("seed", seed_value)
	material.set_shader_parameter("strength", c[6])
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = mesh
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.custom_aabb = AABB(Vector3(-320.0, 0.0, -320.0), Vector3(640.0, 300.0, 640.0))
	add_child(ribbon)


func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var quad := QuadMesh.new()
	quad.size = Vector2(STAR_SIZE, STAR_SIZE)
	var star := StandardMaterial3D.new()
	star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star.albedo_color = Color(0.85, 0.88, 0.9)
	star.disable_fog = true
	quad.material = star
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = STARS
	for i in STARS:
		var dir := Vector3(rng.randfn(), absf(rng.randfn()) + 0.08, rng.randfn()).normalized()
		var size := rng.randf_range(0.35, 1.0)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), dir * STAR_DISTANCE))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = multimesh
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stars.custom_aabb = AABB(Vector3(-300.0, 0.0, -300.0), Vector3(600.0, 300.0, 600.0))
	add_child(stars)
