class_name StationSky
extends Node3D
## Outside the ring station (seen through its caps' windows): stars and the Earth, turning round the drum's axis
## (along Z through this node) - the station spins, so from inside the sky does. Cosmetic, built at load.

const STARS := 500
const STAR_DISTANCE := 260.0     # inside the player camera's far plane (300 m)
const STAR_SIZE := 0.9
const SPIN := 0.12               # rad/s
const EARTH_RADIUS := 90.0
const EARTH_AT := Vector3(170.0, 0.0, 190.0)  # off the axis, past a cap: it comes round past the windows
const EARTH_COLOR := Color(0.16, 0.26, 0.42)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var quad := QuadMesh.new()
	quad.size = Vector2(STAR_SIZE, STAR_SIZE)
	var star := StandardMaterial3D.new()
	star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star.albedo_color = Color(0.9, 0.9, 0.86)
	quad.material = star
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = STARS
	for i in STARS:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var scale := rng.randf_range(0.4, 1.0)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * scale), dir * STAR_DISTANCE))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = multimesh
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)
	var sphere := SphereMesh.new()
	sphere.radius = EARTH_RADIUS
	sphere.height = EARTH_RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var earth := StandardMaterial3D.new()
	earth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	earth.albedo_color = EARTH_COLOR
	sphere.material = earth
	var globe := MeshInstance3D.new()
	globe.mesh = sphere
	globe.position = EARTH_AT
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(globe)


func _process(delta: float) -> void:
	rotate_z(SPIN * delta)
