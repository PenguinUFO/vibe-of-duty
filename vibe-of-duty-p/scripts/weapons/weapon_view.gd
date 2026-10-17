class_name WeaponView
extends Node3D
## Visual of a held weapon: used as the first-person viewmodel (child of the camera) and as the
## third-person weapon of other players. The Synty prefab points its barrel to +Z, so it sits in a
## pivot turned 180 degrees and the view's own forward is -Z like everything else in the game.
##
## Poses are purely procedural (no arms, no animations in the pack): hip/ADS blend, bob, sway,
## recoil kick, reload dip, equip raise and sprint lowering.

const FLASH_TIME := 0.04
const KICK_DECAY := 14.0
const SPRINT_OFFSET := Vector3(-0.06, -0.05, 0.02)
const VIEWMODEL_SCALE := 0.7  # the pack's guns are big; shrink them in first person only

var weapon_index := -1
var is_viewmodel := false

var _pivot := Node3D.new()
var _model: Node3D
var _mag: Node3D
var _mag_rest := Vector3.ZERO
var _muzzle := Marker3D.new()
var _flash := MeshInstance3D.new()
var _flash_timer := 0.0
var _bob_time := 0.0
var _sway := Vector2.ZERO
var _kick := 0.0
var _hip_pos := Vector3.ZERO
var _ads_pos := Vector3.ZERO


func _init() -> void:
	_pivot.rotation.y = PI
	add_child(_pivot)
	add_child(_muzzle)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.05
	flash_mesh.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.35)
	flash_mesh.material = mat
	_flash.mesh = flash_mesh
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_muzzle.add_child(_flash)


func set_weapon(index: int) -> void:
	if index == weapon_index:
		return
	weapon_index = index
	if _model:
		_model.queue_free()
		_model = null
		_mag = null
	var def := WeaponDB.get_def(index)
	var scene: PackedScene = load(def.scene_path)
	_model = scene.instantiate()
	for body in _model.find_children("*", "CollisionObject3D", true, false):
		body.queue_free()
	for node in _model.find_children("*Flash*", "MeshInstance3D", true, false):
		node.visible = false
	for node in _model.find_children("*_Mag_*", "Node3D", true, false):
		_mag = node
		_mag_rest = node.position
	_pivot.add_child(_model)
	# The pivot is turned 180 degrees around Y: prefab (x, y, z) shows up at (-x, y, -z).
	var scale_factor := VIEWMODEL_SCALE if is_viewmodel else 1.0
	_pivot.scale = Vector3.ONE * scale_factor
	_muzzle.position = Vector3(-def.muzzle.x, def.muzzle.y, -def.muzzle.z) * scale_factor
	_hip_pos = def.hip_offset
	# Aim alignment: the eye sits at the height of the front sight (so its tip is at screen centre, just above
	# the rear sight) and `eye_relief` in front of the rear sight. Prefab (x, y, z) -> view (-x, y, -z) * scale.
	var rear := Vector3(-def.rear_sight.x, def.rear_sight.y, -def.rear_sight.z) * scale_factor
	var front := Vector3(-def.front_sight.x, def.front_sight.y, -def.front_sight.z) * scale_factor
	_ads_pos = -Vector3(0.0, front.y, rear.z + def.eye_relief)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash.visible = false


func muzzle_global_position() -> Vector3:
	return _muzzle.global_position


func flash() -> void:
	_flash_timer = FLASH_TIME
	_flash.visible = true
	_flash.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_flash.scale = Vector3.ONE * randf_range(0.7, 1.4)


## Recoil kick of the weapon model itself (not the camera).
func kick(strength: float = 1.0) -> void:
	_kick = minf(_kick + strength, 2.0)


## Updates the viewmodel pose. reload_p/equip_p are -1 when inactive, else 0..1.
func update_pose(dt: float, ads: float, reload_p: float, equip_p: float, sprint_blend: float,
		speed: float, on_floor: bool, look_delta: Vector2, retract: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-KICK_DECAY * dt))

	var pos := _hip_pos.lerp(_ads_pos, ads)
	var rot := Vector3.ZERO

	# Walking bob (weaker while aiming).
	if on_floor and speed > 0.5:
		_bob_time += dt * speed * 1.7
	var bob_amount := (1.0 - ads * 0.85) * clampf(speed / 5.0, 0.0, 1.4)
	pos += Vector3(cos(_bob_time * 0.5) * 0.008, absf(sin(_bob_time)) * 0.01, 0.0) * bob_amount

	# Sway: the weapon lags behind the view and settles back.
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * dt)) - look_delta * 0.12
	_sway = _sway.limit_length(0.06)
	pos += Vector3(_sway.x, -_sway.y, 0.0) * (1.0 - ads * 0.7)

	# Recoil kick.
	pos.z += _kick * 0.03
	rot.x += _kick * deg_to_rad(2.5)

	# Sprint pose.
	pos += SPRINT_OFFSET * sprint_blend
	rot.y += deg_to_rad(18.0) * sprint_blend
	rot.x -= deg_to_rad(6.0) * sprint_blend

	# Reload: dip and tilt, magazine drops out and comes back.
	if reload_p >= 0.0:
		var dip := sin(reload_p * PI)
		pos.y -= dip * 0.1
		rot.x -= dip * deg_to_rad(22.0)
		rot.z += dip * deg_to_rad(18.0)
		if _mag:
			var mag_offset := 0.0
			if reload_p > 0.2 and reload_p < 0.8:
				mag_offset = sin((reload_p - 0.2) / 0.6 * PI) * 0.25
			_mag.position = _mag_rest + Vector3(0.0, -mag_offset, 0.0)
	elif _mag:
		_mag.position = _mag_rest

	# Equip: raise from below.
	if equip_p >= 0.0:
		var lower := 1.0 - equip_p
		pos.y -= lower * 0.3
		rot.x -= lower * deg_to_rad(35.0)

	# Wall avoidance: pull the weapon back when something is right in front of the camera.
	pos.z += retract

	position = pos
	rotation = rot
