class_name Snowfall
extends GPUParticles3D
## Snow falling round the camera (the Chernobyl map's winter, Docs/LEVEL_CHERNOBYL.md): flakes are born in a box over
## whoever looks, wherever they are, and fall in the world (not with the camera). Cosmetic; nothing on a server
## without a screen. Flakes fall through roofs and balconies - the map is mostly open sky.

const AREA := Vector3(28.0, 1.0, 28.0)   # half extents of the box the flakes are born in
const HEIGHT := 14.0                      # m over the camera
const FALL := 1.4                         # m/s
const FLAKE := 0.05                       # m
const COLOR := Color(0.88, 0.89, 0.9)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	amount = 2400
	lifetime = HEIGHT * 1.6 / FALL
	preprocess = lifetime
	local_coords = false
	visibility_aabb = AABB(Vector3(-AREA.x - 5.0, -HEIGHT * 2.0, -AREA.z - 5.0),
			Vector3(AREA.x * 2.0 + 10.0, HEIGHT * 2.0 + 2.0, AREA.z * 2.0 + 10.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = AREA
	process.direction = Vector3.DOWN
	process.spread = 12.0
	process.initial_velocity_min = FALL * 0.8
	process.initial_velocity_max = FALL * 1.2
	process.gravity = Vector3(0.25, 0.0, 0.1)  # a light wind, no acceleration down: flakes drift
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 3.0
	process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * FLAKE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = COLOR
	quad.material = material
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position + Vector3.UP * HEIGHT
