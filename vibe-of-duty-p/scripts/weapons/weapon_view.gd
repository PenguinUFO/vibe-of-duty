class_name WeaponView
extends Node3D
## Visual of a held weapon: used as the first-person viewmodel (child of the camera) and as the
## third-person weapon of other players. The model scene points its barrel to +Z, so it sits in a
## pivot turned 180 degrees and the view's own forward is -Z like everything else in the game.
##
## Poses are purely procedural: hip/ADS blend, bob, sway,
## recoil kick, reload dip, equip raise and sprint lowering.

const FLASH_TIME := 0.04
const KICK_DECAY := 14.0
const SPRINT_OFFSET := Vector3(-0.06, -0.05, 0.02)
const ADS_KICK_CUT := .6  # share of the model kick removed at full ADS
const VIEWMODEL_SCALE := 0.8  # first-person guns are drawn a bit smaller than life (they sit very close to the eye)

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
var _drop := 0.0          # landing jolt, decays
var _handle: MeshInstance3D   # charging handle (WeaponDef.charging_handle), rides the bolt
var _handle_rest := Vector3.ZERO
var _cycle := 1.0         # time since the last shot, for the bolt cycle (s)
var bolt_pull := 0.0      # 0..1: the handle held back by hand (reloads)
var lowered := 0.0        # 0..1: the gun is lowered out of view (first person, vaulting)
var melee := -1.0         # hoof punch progress 0..1 (-1: none): the gun swings aside (first person)
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
	mat.albedo_color = Color(1.0, 0.74, 0.42)
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
	_handle = null
	if def.charging_handle.is_finite():
		# The blockout model has no moving parts: a small charging handle on the receiver's right side cycles with
		# every shot and is pulled by hand at the end of a reload.
		var handle_mesh := BoxMesh.new()
		handle_mesh.size = Vector3(0.022, 0.012, 0.02)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.32, 0.32, 0.34)
		material.metallic = 0.7
		material.roughness = 0.4
		handle_mesh.material = material
		_handle = MeshInstance3D.new()
		_handle.mesh = handle_mesh
		_handle_rest = def.charging_handle
		_handle.position = _handle_rest
		_model.add_child(_handle)
	if is_viewmodel:
		# First person: the gun hangs in front of the camera, its shadow would float on the ground.
		var meshes := _model.find_children("*", "GeometryInstance3D", true, false)
		if _model is GeometryInstance3D:
			meshes.append(_model)  # the prefab root is itself the gun mesh
		for mesh in meshes:
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The pivot is turned 180 degrees around Y: prefab (x, y, z) shows up at (-x, y, -z).
	var scale_factor := VIEWMODEL_SCALE if is_viewmodel else 1.0
	_pivot.scale = Vector3.ONE * scale_factor
	_muzzle.position = Vector3(-def.muzzle.x, def.muzzle.y, -def.muzzle.z) * scale_factor
	_hip_pos = def.hip_offset
	# Aim alignment: the eye sits on the line through the rear and front sight, `eye_relief` behind the rear sight,
	# so both sights line up at screen centre. Prefab (x, y, z) -> view (-x, y, -z) * scale. Every component of both
	# sight points matters.
	var rear := Vector3(-def.rear_sight.x, def.rear_sight.y, -def.rear_sight.z) * scale_factor
	var front := Vector3(-def.front_sight.x, def.front_sight.y, -def.front_sight.z) * scale_factor
	var eye := rear - (front - rear).normalized() * def.eye_relief
	_ads_pos = -eye


func _process(delta: float) -> void:
	_cycle += delta
	if _handle:
		# Bolt: slams back at once on a shot and runs forward again within 70 ms.
		var back := maxf(1.0 - _cycle / 0.07, bolt_pull) if _cycle < 0.07 else bolt_pull
		var def := WeaponDB.get_def(weapon_index)
		_handle.position = _handle_rest + Vector3(0.0, 0.0, -def.bolt_travel * back)
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
	_cycle = 0.0
	var def := WeaponDB.get_def(weapon_index)
	if def.ejection_port.is_finite() and is_visible_in_tree():
		var port := _pivot.global_transform * def.ejection_port
		var basis := _pivot.global_basis.orthonormalized()
		# Prefab axes: -x is the shooter's right, +z the muzzle.
		Casings.eject(self, port, -basis.x, basis.y, -basis.z)


## Where a hand holds the magazine (prefab space), or INF when the gun has none.
func mag_grip_point() -> Vector3:
	return _mag_rest + Vector3(0.0, -0.11, 0.015) if _mag else Vector3.INF


## Moves the magazine off its seat by `shift` (prefab space); third-person reloads (Mannequin).
func set_mag_shift(shift: Vector3) -> void:
	if _mag:
		_mag.position = _mag_rest + shift


## Landing: the gun dips and tips forward, then settles (`strength` ~ 1 for a normal jump).
func land_jolt(strength: float) -> void:
	_drop = minf(_drop + strength, 1.8)


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

	# Recoil kick (much weaker while aiming: the sights stay nearly still).
	var kick := _kick * (1.0 - ads * ADS_KICK_CUT)
	pos.z += kick * 0.03
	rot.x += kick * deg_to_rad(2.5)

	# Sprint pose.
	pos += SPRINT_OFFSET * sprint_blend
	rot.y += deg_to_rad(18.0) * sprint_blend
	rot.x -= deg_to_rad(6.0) * sprint_blend

	# Reload: the gun dips and cants (magazine well towards the left hand); the hand itself takes the magazine out
	# and racks the handle (FirstPersonArms, Mannequin.reload_hand).
	if reload_p >= 0.0:
		var dip := smoothstep(0.0, 0.12, reload_p) * (1.0 - smoothstep(0.88, 1.0, reload_p))
		pos += Vector3(-0.07, 0.05, 0.03) * dip  # up and in, so the magazine well comes into view
		rot.x += dip * deg_to_rad(8.0)
		rot.z -= dip * deg_to_rad(32.0)  # canted, the magazine towards the left hand and the middle of the screen
	bolt_pull = Mannequin.reload_bolt_pull(reload_p)

	# Hoof punch: the gun goes out to the right and down, out of the left hoof's way (Mannequin.punch_curve).
	var aside := Mannequin.punch_curve(melee).y
	pos += Vector3(0.07, -0.09, 0.04) * aside
	rot.y -= deg_to_rad(25.0) * aside
	rot.x -= deg_to_rad(18.0) * aside

	# Equip: raise from below.
	if equip_p >= 0.0:
		var lower := 1.0 - equip_p
		pos.y -= lower * 0.3
		rot.x -= lower * deg_to_rad(35.0)

	# Landing jolt, and lowered out of view (vaulting).
	_drop = lerpf(_drop, 0.0, 1.0 - exp(-7.0 * dt))
	pos.y -= _drop * 0.035 * (1.0 - ads * 0.6)
	rot.x -= _drop * deg_to_rad(4.0)
	pos += Vector3(0.02, -0.55, 0.1) * lowered
	rot.x -= deg_to_rad(50.0) * lowered

	# Wall avoidance: pull the weapon back when something is right in front of the camera.
	pos.z += retract

	position = pos
	rotation = rot
