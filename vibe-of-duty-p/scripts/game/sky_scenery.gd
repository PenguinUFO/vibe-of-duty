class_name SkyScenery
extends Node3D
## The world above the clouds (the plane and the tower maps): the far sea of clouds is the sky shader's (sea_*
## parameters, assets/shaders/sky_clouds.gdshader), here are the near cloud puffs drifting past and the beacons.
## Purely visual and not built on a dedicated server.
## - The plane flies: the level stands still and the clouds move along +Z at `speed` (like the train's forest, the
##   map "runs" towards -Z). The sky's sea scrolls to match, as if it lay `sea_depth` m below.
## - Beacons: every Marker3D under a node named Beacons in the level gets a small glowing light with a halo, blinking
##   (the warning lights on the tops of the far towers).

@export var speed := 0.0               # m/s the clouds move along +Z (the plane's speed; the tower: a slow wind)
@export var sea_depth := 400.0         # m: how far below the sky's sea of clouds seems to lie (its scroll speed)
@export var puffs := 40                # near clouds, each a few balls
@export var puff_color := Color(0.85, 0.86, 0.88)
@export var puff_clear := 25.0         # no puffs closer to the level's axis (x = 0) than this
@export var puff_reach := 350.0        # ...nor farther than this
@export var puff_y := Vector2(-80.0, -10.0)  # height range of the puffs
@export var puff_size := Vector2(12.0, 40.0)  # radius range of a puff
@export var beacon_period := 2.0       # s per blink
@export var beacon_color := Color(1.0, 0.62, 0.35)

const SPAN := 900.0                    # puffs wrap round over z -SPAN .. SPAN; they shrink to nothing at the ends
const BALLS := 4                       # balls per puff

var _sky: ShaderMaterial
var _sea_offset := Vector2.ZERO
var _scroll := 0.0
var _multimesh: MultiMesh
var _bases: Array[Transform3D] = []    # each ball at scroll 0
var _beacons: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var world_env := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment.sky:
		_sky = world_env.environment.sky.sky_material as ShaderMaterial
		if _sky and _sky.get_shader_parameter("sea_offset") != null:  # null: the shader's default, zero
			_sea_offset = _sky.get_shader_parameter("sea_offset")
	_build_puffs()
	_build_beacons()


func _process(delta: float) -> void:
	_time += delta
	if speed != 0.0:
		_scroll += speed * delta
		if _sky:  # the sea's features move along +Z too: the offset goes the other way
			var scale: float = _sky.get_shader_parameter("sea_scale")
			_sky.set_shader_parameter("sea_offset", _sea_offset - Vector2(0.0, _scroll / sea_depth * scale))
		_place_puffs()
	var on := fmod(_time, beacon_period) < beacon_period * 0.35
	for beacon in _beacons:
		beacon.visible = on


func _exit_tree() -> void:
	if _sky:  # the material is shared with the next load of the scene
		_sky.set_shader_parameter("sea_offset", _sea_offset)


func _build_puffs() -> void:
	if puffs <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3907
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 10
	ball.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = puff_color
	material.roughness = 1.0
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP  # soft, cloud-like falloff
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ball.material = material
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = ball
	_multimesh.instance_count = puffs * BALLS
	for i in puffs:
		var side := -1.0 if i % 2 == 0 else 1.0
		var center := Vector3(side * rng.randf_range(puff_clear, puff_reach), rng.randf_range(puff_y.x, puff_y.y),
				rng.randf_range(-SPAN, SPAN))
		var radius := rng.randf_range(puff_size.x, puff_size.y)
		for k in BALLS:  # a flattened heap: a big ball in the middle, smaller ones around
			var r := radius * (1.0 if k == 0 else rng.randf_range(0.45, 0.75))
			var offset := Vector3.ZERO if k == 0 else Vector3(rng.randf_range(-1.0, 1.0) * radius,
					rng.randf_range(-0.1, 0.25) * radius, rng.randf_range(-1.0, 1.0) * radius)
			_bases.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.45, r)), center + offset))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_place_puffs()


## Every ball moved by the scroll, wrapped round, and shrunk towards the wrap so none pops in or out.
func _place_puffs() -> void:
	if _multimesh == null:
		return
	for i in _bases.size():
		var base := _bases[i]
		var z := wrapf(base.origin.z + _scroll, -SPAN, SPAN)
		var fade := clampf((SPAN - absf(z)) / (SPAN * 0.3), 0.0, 1.0)
		_multimesh.set_instance_transform(i, Transform3D(base.basis.scaled(Vector3.ONE * fade),
				Vector3(base.origin.x, base.origin.y, z)))


func _build_beacons() -> void:
	var markers := get_parent().find_child("Beacons", true, false)
	if markers == null:
		return
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = beacon_color * 2.5
	glow.disable_fog = true  # a light shines through the haze
	var bulb := SphereMesh.new()
	bulb.radius = 0.6
	bulb.height = 1.2
	bulb.radial_segments = 8
	bulb.rings = 4
	bulb.material = glow
	for marker in markers.get_children():
		if not marker is Node3D:
			continue
		var light := Node3D.new()
		add_child(light)
		light.global_position = (marker as Node3D).global_position
		var mesh := MeshInstance3D.new()
		mesh.mesh = bulb
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		light.add_child(mesh)
		var halo := Mood.halo(9.0, Color(beacon_color, 0.6))
		light.add_child(halo)
		_beacons.append(light)
