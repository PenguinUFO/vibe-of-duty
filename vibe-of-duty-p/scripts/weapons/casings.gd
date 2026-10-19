class_name Casings
extends MultiMeshInstance3D
## Spent brass flying out of the ejection port (WeaponView.flash): one MultiMesh for the whole scene, a fixed pool of
## casings reused round-robin (a 10 rounds/s rifle would otherwise create and free nodes all the time). Each casing
## flies out to the right with a spin, bounces off the level (short raycasts on the WORLD layer), comes to rest lying
## down and disappears after a few seconds. Cosmetic; not created without a screen.

const POOL := 64
const LIFETIME := 3.0
const GRAVITY := 9.8
const BOUNCE := 0.35         # share of the speed kept off a bounce
const REST_SPEED := 0.5      # slower than this on the ground: lies still
const RADIUS := 0.006
const LENGTH := 0.036

static var _instance: Casings

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _basis: Array[Basis] = []
var _spin: Array[Vector3] = []  # angular velocity (axis * rad/s)
var _life := PackedFloat32Array()
var _resting: Array[bool] = []
var _next := 0
var _query := PhysicsRayQueryParameters3D.new()


## Throws a casing out of the port at `port` (world); `right` / `up` / `back` are the gun's directions (world).
static func eject(context: Node, port: Vector3, right: Vector3, up: Vector3, back: Vector3) -> void:
	var pool := _pool(context)
	if pool:
		pool._eject(port, right * randf_range(2.2, 3.0) + up * randf_range(0.6, 1.1) + back * randf_range(0.2, 0.7))


static func _pool(context: Node) -> Casings:
	if DisplayServer.get_name() == "headless" or context == null or not context.is_inside_tree():
		return null
	var scene := context.get_tree().current_scene
	if scene == null:
		return null
	if not is_instance_valid(_instance) or not _instance.is_inside_tree() or _instance.get_parent() != scene:
		_instance = Casings.new()
		scene.add_child(_instance)
	return _instance


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS * 0.85  # the neck
	mesh.bottom_radius = RADIUS
	mesh.height = LENGTH
	mesh.radial_segments = 6
	mesh.rings = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.64, 0.26)
	material.metallic = 0.8
	material.roughness = 0.35
	mesh.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = POOL
	_pos.resize(POOL)
	_vel.resize(POOL)
	_life.resize(POOL)
	for i in POOL:
		_basis.append(Basis())
		_spin.append(Vector3.ZERO)
		_resting.append(false)
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	_query.collision_mask = Layers.WORLD
	top_level = true


func _eject(port: Vector3, velocity: Vector3) -> void:
	var i := _next
	_next = (_next + 1) % POOL
	_pos[i] = port
	_vel[i] = velocity
	_basis[i] = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	_spin[i] = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(15.0, 25.0)
	_life[i] = LIFETIME
	_resting[i] = false


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	var space := get_world_3d().direct_space_state
	for i in POOL:
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		if _life[i] <= 0.0:
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		if not _resting[i]:
			_vel[i] += Vector3.DOWN * GRAVITY * delta
			var to := _pos[i] + _vel[i] * delta
			_query.from = _pos[i]
			_query.to = to + Vector3.DOWN * RADIUS
			var hit := space.intersect_ray(_query)
			if hit.is_empty():
				_pos[i] = to
				var spin: Vector3 = _spin[i]
				if spin.length() > 0.001:
					_basis[i] = Basis(spin.normalized(), spin.length() * delta) * _basis[i]
			else:
				var normal: Vector3 = hit["normal"]
				_pos[i] = hit["position"] + normal * RADIUS
				_vel[i] = _vel[i].bounce(normal) * BOUNCE
				_spin[i] *= 0.6
				if _vel[i].length() < REST_SPEED and normal.y > 0.7:
					_resting[i] = true
					# Lying on its side, any way round.
					_basis[i] = Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5)
		# Fade out at the end by shrinking.
		var s := clampf(_life[i] / 0.3, 0.0, 1.0)
		multimesh.set_instance_transform(i, Transform3D(_basis[i].scaled(Vector3.ONE * s), _pos[i]))
