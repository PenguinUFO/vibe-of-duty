class_name WeaponPreview
extends SubViewportContainer
## The build editor's picture of the weapon (BuildPanel): its model with the build's modules - the suppressor, the
## folded stock, the big magazine, the Хрюгер's size and chrome - seen from the left side, the barrel to the left, in a
## small world of its own (a light, a grey backdrop). show_build redraws it on every change of the build; the camera
## frames the whole gun, whatever its size.

const SIZE := Vector2i(640, 300)
const MARGIN := 1.12  # the frame round the gun
const BACKDROP := Color(0.24, 0.24, 0.26)  # lighter than the panel: the black guns stand out

var _view := WeaponView.new()
var _camera := Camera3D.new()


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(SIZE) * 0.8
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -60.0, 0.0)
	light.light_energy = 1.3
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BACKDROP
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	viewport.add_child(env)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(_camera)
	viewport.add_child(_view)


## The weapon of `parts` (a sanitized build) with its modules.
func show_build(parts: Array) -> void:
	var index := WeaponDB.index_of(parts[0])
	_view.set_weapon(index, WeaponDB.make_def(index, PartDB.weapon_modules(parts)))
	_frame.call_deferred()  # the old model goes at the end of the frame


## Puts the camera on the gun's left (prefab +x: WeaponView turns the model round, so it is world -x) and zooms to fit.
func _frame() -> void:
	var box := AABB()
	var first := true
	for node in _view.find_children("*", "VisualInstance3D", true, false):
		var instance := node as VisualInstance3D
		if not instance.is_visible_in_tree() or _going(instance):
			continue
		var part := instance.global_transform * instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return
	var centre := box.get_center()
	_camera.look_at_from_position(centre + Vector3(-2.0, 0.0, 0.0), centre)
	_camera.size = maxf(box.size.y, box.size.z * float(SIZE.y) / float(SIZE.x)) * MARGIN


## True if `node` belongs to a model on its way out (the last weapon's, queued for deletion).
func _going(node: Node) -> bool:
	while node != _view and node != null:
		if node.is_queued_for_deletion():
			return true
		node = node.get_parent()
	return false
