class_name BuildStage
extends SubViewportContainer
## The build editor's centre (BuildPanel, Docs/LOADOUT.md "Экран сборки"): the whole pig (Mannequin) standing in a small
## world of its own, holding the build's weapon across the chest (Mannequin.present) with its modules on it. The camera
## frames the whole body, or comes in on the weapon while `close` is on (the pointer or the gamepad's focus on the
## weapon column); it glides between the two. The organs do not change the body (owner, 2026-10-31), but the
## "Инженер"'s chip shows on the head.

const FOV := 30.0
const BODY_CENTRE := Vector3(0.0, 0.93, 0.0)  # mannequin space: the middle of the standing body...
const BODY_HEIGHT := 2.05                      # ...and the height framed round it
const MARGIN := 1.02                           # the frame round the weapon
const VIEW_DIR := Vector3(0.28, 0.12, -1.0)    # from the target to the camera: in front, a little to the pig's right
const GLIDE := 7.0                             # 1/s: how fast the camera follows
const BACKDROP := Color(0.13, 0.125, 0.12)

var close := false

var _viewport := SubViewport.new()
var _camera := Camera3D.new()
var _mannequin := Mannequin.new()
var _weapon := WeaponView.new()
var _target := BODY_CENTRE   # where the camera looks now...
var _distance := 0.0         # ...and from how far
var _weapon_box := AABB()    # mannequin space, of the weapon as held
var _box_dirty := true


func _init() -> void:
	stretch = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKDROP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	# As the menu's portrait (PigPortrait): a warm key from the upper left, a cool low fill, an orange rim from behind.
	_light(Vector3(-0.6, 0.65, -0.55), Color(1.0, 0.94, 0.86), 1.5, true)
	_light(Vector3(0.8, -0.1, -0.5), Color(0.7, 0.8, 1.0), 0.4)
	_light(Vector3(0.6, 0.5, 0.8), Color(1.0, 0.62, 0.3), 2.2)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(6.0, 6.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = BACKDROP.lightened(0.08)
	floor_material.roughness = 1.0
	floor_mesh.material = floor_material
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	_viewport.add_child(floor_node)

	_camera.fov = FOV
	_viewport.add_child(_camera)
	_viewport.add_child(_mannequin)
	_mannequin.build(Mannequin.PALETTE[0])
	_mannequin.present = 1.0
	_weapon.top_level = true  # placed by the mannequin
	_viewport.add_child(_weapon)
	_mannequin.weapon = _weapon


## The weapon of `parts` (a sanitized build) with its modules, in the pig's hands.
func show_build(parts: Array) -> void:
	var index := WeaponDB.index_of(parts[0])
	_weapon.set_weapon(index, WeaponDB.make_def(index, PartDB.weapon_modules(parts)))
	_mannequin.def = _weapon.def
	_mannequin.set_chip(parts.has(PartDB.ENGINEER))
	_box_dirty = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_mannequin.animate(delta, Vector3.ZERO)
	_mannequin.pose()
	if _box_dirty:
		_box_dirty = not _measure_weapon()
	var aspect := size.x / maxf(size.y, 1.0)
	var target := BODY_CENTRE
	var height := BODY_HEIGHT
	if close and _weapon_box.size != Vector3.ZERO:
		target = _weapon_box.get_center()
		height = maxf(_weapon_box.size.y, maxf(_weapon_box.size.x, _weapon_box.size.z) / aspect) * MARGIN
	var distance := height * 0.5 / tan(deg_to_rad(FOV) * 0.5)
	if _distance == 0.0:
		_target = target
		_distance = distance
	var t := 1.0 - exp(-GLIDE * delta)
	_target = _target.lerp(target, t)
	_distance = lerpf(_distance, distance, t)
	_camera.look_at_from_position(_target + VIEW_DIR.normalized() * _distance, _target)


## The held weapon's box in mannequin space; false while the last model is still on its way out.
func _measure_weapon() -> bool:
	var box := AABB()
	var first := true
	var to_local := _mannequin.global_transform.affine_inverse()
	for node in _weapon.find_children("*", "VisualInstance3D", true, false):
		var instance := node as VisualInstance3D
		if _going(instance):
			return false
		if not instance.is_visible_in_tree():
			continue
		var part := to_local * instance.global_transform * instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return false
	_weapon_box = box
	return true


## True if `node` belongs to a model on its way out (the last weapon's, queued for deletion).
func _going(node: Node) -> bool:
	while node != _weapon and node != null:
		if node.is_queued_for_deletion():
			return true
		node = node.get_parent()
	return false


## A directional light shining from `from` (a direction towards the light).
func _light(from: Vector3, color: Color, energy: float, shadow := false) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadow
	light.transform = Transform3D(Basis.looking_at(-from.normalized()), from)
	_viewport.add_child(light)
