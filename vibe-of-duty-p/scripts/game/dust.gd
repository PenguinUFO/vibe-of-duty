class_name Dust
extends MultiMeshInstance3D
## Puffs of dust kicked up by landings, slides and falling bodies: one MultiMesh for the whole scene with a fixed pool
## of low-poly puffs reused round-robin. A puff drifts out and up, swells and fades. Cosmetic; not created without a
## screen.

const POOL := 96
const COLOR := Color(0.78, 0.74, 0.66)

static var _instance: Dust

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _size := PackedFloat32Array()     # final radius
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()     # 0 = free
var _spin := PackedFloat32Array()
var _next := 0


## A ring of puffs at `pos` (world, on the ground): `strength` ~ 1 for a normal landing, more for a hard one.
static func burst(context: Node, pos: Vector3, strength: float) -> void:
	var pool := _pool(context)
	if pool == null:
		return
	var count := clampi(roundi(4.0 + strength * 4.0), 3, 14)
	var offset := randf() * TAU
	var frame := Gravity.frame(pos)
	for k in count:
		var angle := offset + TAU * k / count
		var out := frame * Vector3(cos(angle), 0.0, sin(angle))
		pool._puff(pos + out * 0.15, out * randf_range(0.8, 1.4) * (0.6 + strength * 0.5) + frame.y * randf_range(0.2, 0.6),
				randf_range(0.18, 0.3) * (0.7 + strength * 0.3), randf_range(0.6, 0.9))


## One puff behind something sliding along the ground at `pos` (world) with velocity `velocity`.
static func trail(context: Node, pos: Vector3, velocity: Vector3) -> void:
	var pool := _pool(context)
	if pool == null:
		return
	var up := Gravity.up(pos)
	var side := velocity.cross(up).normalized() * randf_range(-0.6, 0.6)
	pool._puff(pos, -velocity * 0.15 + side + up * randf_range(0.3, 0.6), randf_range(0.15, 0.25),
			randf_range(0.5, 0.8))


static func _pool(context: Node) -> Dust:
	if DisplayServer.get_name() == "headless" or context == null or not context.is_inside_tree():
		return null
	var scene := context.get_tree().current_scene
	if scene == null:
		return null
	if not is_instance_valid(_instance) or not _instance.is_inside_tree() or _instance.get_parent() != scene:
		_instance = Dust.new()
		scene.add_child(_instance)
	return _instance


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 1.0
	mesh.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = POOL
	for array in [_pos, _vel]:
		array.resize(POOL)
	for array in [_size, _age, _life, _spin]:
		array.resize(POOL)
	for i in POOL:
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		multimesh.set_instance_color(i, Color(COLOR, 0.0))
	top_level = true


func _puff(pos: Vector3, velocity: Vector3, size: float, life: float) -> void:
	var i := _next
	_next = (_next + 1) % POOL
	_pos[i] = pos
	_vel[i] = velocity
	_size[i] = size
	_age[i] = 0.0
	_life[i] = life
	_spin[i] = randf() * TAU


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	for i in POOL:
		if _life[i] <= 0.0:
			continue
		_age[i] += delta
		var t := _age[i] / _life[i]
		if t >= 1.0:
			_life[i] = 0.0
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		_vel[i] *= exp(-3.0 * delta)  # air drag
		_pos[i] += _vel[i] * delta
		var radius := _size[i] * (0.35 + 0.65 * sqrt(t))
		var basis := Basis(Vector3.UP, _spin[i]).scaled(Vector3(1.0, 0.7, 1.0) * radius)
		multimesh.set_instance_transform(i, Transform3D(basis, _pos[i]))
		multimesh.set_instance_color(i, Color(COLOR, 0.45 * (1.0 - t) * minf(t * 8.0, 1.0)))
