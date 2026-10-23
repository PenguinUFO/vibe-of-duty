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
var def: WeaponDef  # the weapon shown, with its owner's modules (the sight model and aim line)
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
var _toggle: Node3D       # a toggle lock (Luger): "Toggle" in the model, folded up as the breech goes back
var _toggle_hinge := Vector3.ZERO  # rest positions: the rear link's hinge, the knee, the breech block's pin
var _toggle_knee := Vector3.ZERO
var _toggle_pin := Vector3.ZERO
var _dot: Node3D          # a red dot sight's dot (SightModels), put on the aim line from the eye every pose
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


## `weapon_def`: the owner's weapon with their modules (Player.weapons.def_at); null: the base one.
func set_weapon(index: int, weapon_def: WeaponDef = null) -> void:
	if weapon_def == null:
		weapon_def = WeaponDB.get_def(index)
	if index == weapon_index and weapon_def == def:
		return
	var same_model := index == weapon_index and def != null and weapon_def.sight == def.sight \
			and weapon_def.model_variants == def.model_variants
	weapon_index = index
	def = weapon_def
	if same_model:
		return  # a new build with the same optic: only the numbers changed
	if _model:
		_model.queue_free()
		_model = null
		_mag = null
	var scene: PackedScene = load(def.scene_path)
	_model = scene.instantiate()
	for body in _model.find_children("*", "CollisionObject3D", true, false):
		body.queue_free()
	for group: String in def.model_variants:
		var holder := _model.get_node_or_null(group)
		for child in holder.get_children() if holder else []:
			if child.name != def.model_variants[group]:
				child.free()  # now: the magazine search below must not find the other one
	for node in _model.find_children("*Flash*", "MeshInstance3D", true, false):
		node.visible = false
	for node in _model.find_children("*_Mag_*", "Node3D", true, false):
		_mag = node
		_mag_rest = node.position
	var optic := SightModels.build(def.sight)
	_dot = null
	if optic:
		optic.position = def.sight_offset
		_model.add_child(optic)
		_dot = optic.get_node_or_null("Dot")
		if _dot and not is_viewmodel:
			_dot.visible = false  # lit only for the eye behind it
	_model.scale = Vector3.ONE * def.model_scale
	_pivot.add_child(_model)
	_handle = null
	_toggle = _model.get_node_or_null("Toggle")
	if _toggle:
		_toggle_hinge = _toggle.get_node("LinkRear").position
		_toggle_knee = _toggle.get_node("LinkFront").position
		_toggle_pin = _toggle.get_node("Breech").position
	elif def.charging_handle.is_finite():
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
		_handle_rest = def.charging_handle / def.model_scale  # in the model, which is scaled
		_handle.position = _handle_rest
		_model.add_child(_handle)
	WeaponSkin.apply(_model)
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
		var back := maxf(1.0 - _cycle / 0.07, bolt_pull) if _cycle < 0.07 and def.handle_reciprocates else bolt_pull
		_handle.position = _handle_rest + Vector3(0.0, 0.0, -def.bolt_travel * back)
	elif _toggle:
		_fold_toggle(maxf(1.0 - _cycle / 0.07, bolt_pull) if _cycle < 0.07 else bolt_pull)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash.visible = false


## The toggle with the breech block `back` (0..1) of bolt_travel back: the knee rises between the hinge and the pin.
func _fold_toggle(back: float) -> void:
	var pin := _toggle_pin - Vector3(0.0, 0.0, def.bolt_travel * back)
	var rear_len := _toggle_hinge.distance_to(_toggle_knee)
	var front_len := _toggle_knee.distance_to(_toggle_pin)
	var span := maxf(_toggle_hinge.distance_to(pin), absf(rear_len - front_len) + 0.0001)
	# The knee: on both links' circles (in the gun's side plane), the upper of the two crossings.
	var along := (rear_len * rear_len - front_len * front_len + span * span) / (2.0 * span)
	var up := sqrt(maxf(rear_len * rear_len - along * along, 0.0))
	var dir := (pin - _toggle_hinge) / span
	var knee := _toggle_hinge + dir * along + Vector3(0.0, dir.z, -dir.y) * up
	var rear_link := _toggle.get_node("LinkRear") as Node3D
	var front_link := _toggle.get_node("LinkFront") as Node3D
	rear_link.rotation.x = -atan2(knee.y - _toggle_hinge.y, knee.z - _toggle_hinge.z)  # the links lie along +Z
	front_link.position = knee
	front_link.rotation.x = -atan2(pin.y - knee.y, pin.z - knee.z)
	(_toggle.get_node("Breech") as Node3D).position = pin


func muzzle_global_position() -> Vector3:
	return _muzzle.global_position


## A shot: the bolt cycles and a casing flies; `show_flash` false (a suppressor): no flash.
func flash(show_flash := true) -> void:
	if show_flash:
		_flash_timer = FLASH_TIME
		_flash.visible = true
		_flash.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		_flash.scale = Vector3.ONE * randf_range(0.7, 1.4)
	_cycle = 0.0
	if def.ejection_port.is_finite() and is_visible_in_tree():
		var port := _pivot.global_transform * def.ejection_port
		var basis := _pivot.global_basis.orthonormalized()
		# Prefab axes: -x is the shooter's right, +z the muzzle.
		Casings.eject(self, port, -basis.x, basis.y, -basis.z)


## Where a hand holds the magazine (prefab space), or INF when the gun has none.
func mag_grip_point() -> Vector3:
	return (_mag_rest + Vector3(0.0, -0.11, 0.015)) * def.model_scale if _mag else Vector3.INF


## Moves the magazine off its seat by `shift` (prefab space); third-person reloads (Mannequin).
func set_mag_shift(shift: Vector3) -> void:
	if _mag:
		_mag.position = _mag_rest + shift / def.model_scale


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
	_aim_dot()


## A red dot is at infinity (a collimator): the eye sees it along the aim line wherever the eye is, so it goes where
## that line from the eye crosses the sight's glass - on a shot or a sway it shows where the gun points, not where the
## glass is - and is hidden when that is off the window (from the hip). First person only: others' dots are too small.
func _aim_dot() -> void:
	var camera := get_viewport().get_camera_3d() if _dot and is_viewmodel else null
	if camera == null:
		return
	var optic := _dot.get_parent() as Node3D
	var eye := optic.global_transform.affine_inverse() * camera.global_position
	var dir := (def.front_sight - def.rear_sight).normalized()
	var plane: float = optic.get_meta("dot_z")
	var through := eye + dir * ((plane - eye.z) / dir.z)
	var off := Vector2(through.x, through.y).distance_to(optic.get_meta("window_center"))
	_dot.visible = eye.z < plane and off <= float(optic.get_meta("window_radius"))
	_dot.position = through
	_dot.scale = Vector3.ONE * (eye.distance_to(through) * float(optic.get_meta("dot_angle")) / SightModels.DOT_RADIUS)
